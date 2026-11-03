#!/usr/bin/env python3
"""Ріже сирі звуки з MusicGPT на ігрові варіації і генерує маніфест для Godot.

  python3 tools/audio/slice_sfx.py --src source_assets/audio_raw --project .

Що робить:
  * SFX: декодує mp3/wav, знаходить окремі звуки за тишею, ріже, нормалізує гучність
    за категорією, додає фейди, пише моно WAV 16-bit у audio/sfx/<key>_NN.wav.
  * Ембієнт і музика: безшовна петля (кросфейд кінця в початок), OGG Vorbis.
  * Пише scripts/fx/audio_manifest.gd зі списком файлів для кожного ключа.

Потрібні: python3 + numpy, ffmpeg з libvorbis.
"""
import argparse
import hashlib
import subprocess
import wave
from pathlib import Path

import numpy as np

SR = 44100
HOP = 0.01          # крок огинаючої, с
ST_WIN = 0.05       # вікно «короткочасної гучності», с
PEAK_LIMIT_DB = -1.0
MAX_VARIATIONS = 8

# Ключ гри → як різати.
#   mode: split   — кожен звук серії окремо
#         longest — найдовший звук у файлі
#         whole   — від першого до останнього звуку
#         first / last / middle — перший, останній або середні звуки серії
#         tail    — останні `length` секунд активної частини
#   target — короткочасна гучність, dBFS (50 мс RMS-максимум)
SFX = {
    "revolver_shot":      dict(src="sfx_gun_revolver_shot", mode="split", min_len=0.15, max_len=0.9, target=-8),
    "rifle_shot":         dict(src="sfx_gun_rifle_shot", mode="split", min_len=0.2, max_len=1.0, target=-7),
    "reload_open":        dict(src="sfx_gun_revolver_reload", mode="first", max_len=0.4, target=-16),
    "reload_insert":      dict(src="sfx_gun_revolver_reload", mode="middle", min_len=0.02, max_len=0.3, target=-18),
    "reload_close":       dict(src="sfx_gun_revolver_reload", mode="last", max_len=0.5, target=-14),
    "lever_cycle":        dict(src="sfx_gun_lever_cycle", mode="split", min_len=0.08, max_len=0.45, target=-14),
    "dry_click":          dict(src="sfx_gun_dry_click", mode="split", min_len=0.02, max_len=0.2, target=-16),
    "gun_twirl":          dict(src="sfx_gun_twirl", mode="tail", length=1.0, target=-16),
    "ricochet":           dict(src="sfx_ricochet", mode="split", min_len=0.4, max_len=1.2, target=-13),
    "hit_coin":           dict(src="sfx_hit_coin", mode="split", min_len=0.2, max_len=0.22, drop_over=1.5, target=-14),
    "hit_bone":           dict(src="sfx_hit_bone", mode="split", min_len=0.03, max_len=0.35, target=-11),
    "hit_wood":           dict(src="sfx_hit_wood", mode="split", min_len=0.05, max_len=0.4, target=-11),
    "hit_anvil":          dict(src="sfx_hit_anvil", mode="split", min_len=0.2, max_len=0.7, target=-10),
    "hit_gong":           dict(src="sfx_hit_gong", mode="split", min_len=0.3, max_len=1.8, target=-11),
    "hit_rubber_chicken": dict(src="sfx_hit_rubber_chicken", mode="split", min_len=0.1, max_len=0.8, target=-12),
    "glass_bottle":       dict(src="sfx_glass_bottle", mode="split", min_len=0.2, max_len=1.0, target=-11),
    "glass_window":       dict(src="sfx_glass_window", mode="longest", max_len=2.4, target=-10),
    "slowmo":             dict(src="sfx_slowmo", mode="longest", min_len=1.0, max_len=1.2, target=-14),
    "combo_break":        dict(src="sfx_combo_break", mode="whole", max_len=2.8, target=-12),
    "combo_up":           dict(src="sfx_combo_up", mode="longest", max_len=0.9, target=-14),
    "civilian_oops":      dict(src="sfx_civilian_oops", mode="split", min_len=0.5, max_len=2.0, target=-11),
    "civilian_hic":       dict(src="sfx_civilian_hic", mode="split", min_len=0.15, max_len=0.8, target=-12),
    "star":               dict(src="sfx_star", mode="longest", max_len=0.9, target=-14),
    "cash":               dict(src="sfx_cash", mode="split", min_len=0.3, max_len=0.8, target=-14),
    "crowd_ooh":          dict(src="sfx_crowd_ooh", mode="whole", max_len=4.5, target=-14),
    "land_dirt":          dict(src="sfx_land_dirt", mode="split", min_len=0.15, max_len=0.6, target=-14),
    "level_complete":     dict(src="sfx_level_complete", mode="whole", max_len=8.0, target=-12),
    "saloon_doors":       dict(src="sfx_saloon_doors", mode="split", min_len=1.0, max_len=2.5, target=-16),
    "shop_buy":           dict(src="sfx_shop_buy", mode="split", min_gap=0.35, min_len=0.4, max_len=1.5, target=-13),
    "target_bullseye":    dict(src="sfx_target_bullseye", mode="whole", max_len=1.6, target=-11),
    "throw_whoosh":       dict(src="sfx_throw_whoosh", mode="split", min_len=0.2, max_len=0.9, target=-15),
    "ui_click":           dict(src="sfx_ui_click", mode="split", min_len=0.03, max_len=0.3, target=-16),
}

LOOPS = {
    # вихідна тека, префікс джерела, кросфейд (с), RMS dBFS
    "amb": dict(src="amb_wildwest_loop", out="audio/amb", xfade=2.0, rms=-28.0),
    "music_gameplay": dict(src="mus_wildwest_gameplay", out="audio/music", xfade=3.0, rms=-18.0),
    "music_shop": dict(src="mus_shop", out="audio/music", xfade=3.0, rms=-18.0),
}


def decode(path: Path, channels: int = 1) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-ac", str(channels), "-ar", str(SR), "-f", "f32le", "-"],
        capture_output=True, check=True,
    ).stdout
    x = np.frombuffer(raw, dtype=np.float32).copy()
    return x.reshape(-1, channels) if channels > 1 else x


def envelope_db(x: np.ndarray) -> np.ndarray:
    hop = int(SR * HOP)
    n = len(x) // hop
    frames = x[: n * hop].reshape(n, hop)
    return 20 * np.log10(np.sqrt(np.mean(frames ** 2, axis=1) + 1e-12))


def find_segments(x: np.ndarray, rel_db=32.0, min_gap=0.12):
    env = envelope_db(x)
    thr = max(env.max() - rel_db, -62.0)
    active = env > thr
    segs, i, n = [], 0, len(active)
    while i < n:
        if active[i]:
            j = i
            while j < n and active[j]:
                j += 1
            segs.append([i * HOP, j * HOP])
            i = j
        else:
            i += 1
    merged = []
    for s in segs:
        if merged and s[0] - merged[-1][1] < min_gap:
            merged[-1][1] = s[1]
        else:
            merged.append(s)
    return merged


def with_tails(segs, total):
    """Додає пре-рол 10 мс і хвіст до 120 мс, не залазячи на наступний звук."""
    out = []
    for k, (a, b) in enumerate(segs):
        nxt = segs[k + 1][0] - 0.01 if k + 1 < len(segs) else total
        out.append((max(0.0, a - 0.01), min(b + 0.12, nxt, total)))
    return out


def short_term_db(x: np.ndarray) -> float:
    w = int(SR * ST_WIN)
    if len(x) <= w:
        return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)
    sq = np.convolve(x ** 2, np.ones(w) / w, mode="valid")
    return 20 * np.log10(np.sqrt(sq.max()) + 1e-12)


def finish(x: np.ndarray, target_db: float, truncated: bool, fade_in: float = 0.004) -> np.ndarray:
    x = x.astype(np.float64)
    gain_db = target_db - short_term_db(x)
    peak = np.max(np.abs(x)) + 1e-12
    gain_db = min(gain_db, PEAK_LIMIT_DB - 20 * np.log10(peak))
    x *= 10 ** (gain_db / 20)
    fi = min(int(SR * fade_in), len(x) // 4)
    fo = min(int(SR * (0.12 if truncated else 0.025)), len(x) // 3)
    if fi > 0:
        x[:fi] *= np.linspace(0, 1, fi)
    if fo > 0:
        x[-fo:] *= np.linspace(1, 0, fo)
    return x


def cut(x, a, b, max_len):
    truncated = (b - a) > max_len
    b = min(b, a + max_len)
    return x[int(a * SR): int(b * SR)], truncated


def slices_for_file(x: np.ndarray, cfg: dict):
    total = len(x) / SR
    segs = find_segments(x, min_gap=cfg.get("min_gap", 0.12))
    if not segs:
        return []
    tails = with_tails(segs, total)
    mode = cfg["mode"]
    min_len, max_len = cfg.get("min_len", 0.0), cfg.get("max_len", 99.0)
    raw = []
    if mode == "split":
        drop_over = cfg.get("drop_over", 99.0)
        for (a, b), (ta, tb) in zip(segs, tails):
            if min_len <= b - a <= drop_over:
                raw.append((ta, tb))
    elif mode == "longest":
        k = int(np.argmax([b - a for a, b in segs]))
        if segs[k][1] - segs[k][0] >= min_len:
            raw.append(tails[k])
    elif mode == "whole":
        raw.append((tails[0][0], tails[-1][1]))
    elif mode == "first":
        raw.append(tails[0])
    elif mode == "last":
        if len(segs) > 1:
            raw.append(tails[-1])
    elif mode == "middle":
        for (a, b), t in zip(segs[1:-1], tails[1:-1]):
            if min_len <= b - a <= max_len:
                raw.append(t)
    elif mode == "tail":
        end = tails[-1][1]
        raw.append((max(tails[0][0], end - cfg["length"]), end))
    out = []
    for a, b in raw:
        piece, truncated = cut(x, a, b, max_len)
        if len(piece) < int(SR * 0.02):
            continue
        fade_in = 0.08 if mode == "tail" else 0.004
        out.append(finish(piece, cfg["target"], truncated, fade_in))
    return out


def write_wav(path: Path, x: np.ndarray) -> None:
    pcm = np.clip(x, -1.0, 1.0)
    pcm = (pcm * 32767).astype("<i2")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def write_ogg(path: Path, x: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", str(x.shape[1]), "-i", "-",
         "-c:a", "libvorbis", "-q:a", "5", str(path)],
        input=x.astype(np.float32).tobytes(), check=True,
    )


def seamless_loop(x: np.ndarray, xfade: float, rms_db: float) -> np.ndarray:
    """Обрізає тишу по краях і зшиває кінець з початком кросфейдом."""
    mono = x.mean(axis=1)
    segs = find_segments(mono, rel_db=45.0, min_gap=1.0)
    a, b = segs[0][0], segs[-1][1]
    y = x[int(a * SR): int(b * SR)].astype(np.float64)
    f = int(SR * xfade)
    head, tail = y[:f], y[-f:]
    ramp = np.linspace(0, 1, f)[:, None]
    looped = y[:-f].copy()
    looped[:f] = head * ramp + tail * (1 - ramp)
    gain_db = rms_db - 20 * np.log10(np.sqrt(np.mean(looped ** 2)) + 1e-12)
    gain_db = min(gain_db, PEAK_LIMIT_DB - 20 * np.log10(np.max(np.abs(looped)) + 1e-12))
    return looped * 10 ** (gain_db / 20)


def numbered(src_dir: Path, prefix: str):
    files = []
    for p in sorted(src_dir.iterdir()):
        if p.suffix.lower() not in (".mp3", ".wav", ".ogg") or p.name.startswith("._"):
            continue
        stem = p.stem
        if stem == prefix or (stem.startswith(prefix) and stem[len(prefix):].isdigit()):
            files.append(p)
    return files


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, type=Path)
    ap.add_argument("--project", required=True, type=Path)
    args = ap.parse_args()
    proj = args.project
    sfx_dir = proj / "audio" / "sfx"
    for old in sfx_dir.glob("*.wav"):
        old.unlink()
    manifest_sfx = {}
    for key, cfg in SFX.items():
        per_file, seen = [], set()
        for p in numbered(args.src, cfg["src"]):
            x = decode(p)
            h = hashlib.md5(np.round(x * 1000).astype(np.int32).tobytes()).hexdigest()
            if h in seen:  # MusicGPT інколи віддає дві однакові варіації
                continue
            seen.add(h)
            per_file.append(slices_for_file(x, cfg))
        # По черзі з кожного файлу — щоб варіації були різноманітні.
        chosen, k = [], 0
        while len(chosen) < MAX_VARIATIONS and any(k < len(s) for s in per_file):
            for s in per_file:
                if k < len(s) and len(chosen) < MAX_VARIATIONS:
                    chosen.append(s[k])
            k += 1
        paths = []
        for i, x in enumerate(chosen, 1):
            rel = f"audio/sfx/{key}_{i:02d}.wav"
            write_wav(proj / rel, x)
            paths.append("res://" + rel)
        manifest_sfx[key] = paths
        lens = [round(len(x) / SR, 2) for x in chosen]
        print(f"{key:20s} {len(chosen)} var  {lens}")
    manifest_amb, manifest_music = [], {}
    for name, cfg in LOOPS.items():
        for i, p in enumerate(numbered(args.src, cfg["src"]), 1):
            y = seamless_loop(decode(p, channels=2), cfg["xfade"], cfg["rms"])
            if name == "amb":
                rel = f"{cfg['out']}/amb_wildwest_{i:02d}.ogg"
                manifest_amb.append("res://" + rel)
            else:
                rel = f"{cfg['out']}/{cfg['src']}.ogg"
                manifest_music[name.removeprefix("music_")] = "res://" + rel
            write_ogg(proj / rel, y)
            print(f"{rel:40s} {len(y) / SR:6.1f} s")
    lines = [
        "extends RefCounted",
        "## Згенеровано tools/audio/slice_sfx.py — не редагувати вручну.",
        "",
        "const SFX := {",
    ]
    for key, paths in manifest_sfx.items():
        joined = ", ".join(f'"{p}"' for p in paths)
        lines.append(f'\t"{key}": [{joined}],')
    lines += ["}", "", "const AMB := ["]
    lines += [f'\t"{p}",' for p in manifest_amb]
    lines += ["]", "", "const MUSIC := {"]
    lines += [f'\t"{k}": "{v}",' for k, v in manifest_music.items()]
    lines += ["}", ""]
    (proj / "scripts" / "fx" / "audio_manifest.gd").write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
