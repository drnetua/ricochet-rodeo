#!/usr/bin/env python3
"""2D-асети рівня з рефів FLUX: прибирає світлий фон, ріже аркуші на окремі спрайти, стискає.

  python3 tools/assets/prep_2d.py 01 [--src source_assets/gen/01-wild-west/refs]

Результат — assets/textures/<рівень>/: backdrop.jpg, coin_face.png, cowboy_cutout.png,
grass_N.png, hud_plaque.png, hud_bullet.png, hud_crosshair.png, sticker_*.png.
Потрібні pillow, numpy, scipy.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ROOT, load_manifest  # noqa: E402


def key_background(im: Image.Image, tol: int = 30, enclosed: bool = False) -> Image.Image:
    """Прозорим стає фон, з'єднаний з краями кадру (світлі місця всередині об'єкта лишаються).
    enclosed=True — також фон, затиснутий усередині (між стеблинами трави, у кільці прицілу)."""
    a = np.asarray(im.convert("RGB")).astype(np.int32)
    h, w = a.shape[:2]
    e = max(4, w // 60)
    bg_row = np.median(np.concatenate([a[:, :e], a[:, -e:]], axis=1), axis=1)
    diff = np.abs(a - bg_row[:, None, :]).sum(axis=2)
    near = diff < tol * 3
    lab, _ = ndimage.label(near)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bgmask = near if enclosed else np.isin(lab, list(border))
    # М'який край: альфа росте з відстанню від фону.
    dist = ndimage.distance_transform_edt(~bgmask)
    alpha = np.clip(dist / 2.0, 0, 1) * 255
    rgba = np.dstack([a.astype(np.uint8), alpha.astype(np.uint8)])
    return Image.fromarray(rgba, "RGBA")


def pieces(rgba: Image.Image, min_frac: float = 0.002, close: int = 6) -> list[tuple[int, int, int, int]]:
    """Рамки окремих об'єктів на аркуші, зліва направо, зверху вниз."""
    al = np.asarray(rgba)[:, :, 3] > 40
    m = ndimage.binary_closing(al, iterations=close)
    lab, n = ndimage.label(m)
    boxes = []
    for sl in ndimage.find_objects(lab):
        y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
        if (y1 - y0) * (x1 - x0) >= min_frac * al.size:
            boxes.append((x0, y0, x1, y1))
    rows: list = []
    for b in sorted(boxes, key=lambda b: b[1]):
        for r in rows:
            if abs(r[0][1] - b[1]) < (b[3] - b[1]) * 0.5:
                r.append(b)
                break
        else:
            rows.append([b])
    return [b for r in rows for b in sorted(r, key=lambda b: b[0])]


def save_piece(rgba: Image.Image, box, dst: Path, max_px: int, pad: int = 6) -> None:
    x0, y0, x1, y1 = box
    p = _drop_edge_scraps(rgba.crop((max(0, x0 - pad), max(0, y0 - pad), x1 + pad, y1 + pad)))
    p.thumbnail((max_px, max_px), Image.LANCZOS)
    p.save(dst, optimize=True)


def _drop_edge_scraps(p: Image.Image) -> Image.Image:
    """Прибирає дрібні шматки сусідніх об'єктів, що заскочили в кроп з краю."""
    a = np.asarray(p).copy()
    al = a[:, :, 3] > 20
    lab, n = ndimage.label(al)
    if n < 2:
        return p
    sizes = ndimage.sum(al, lab, range(1, n + 1))
    big = sizes.max()
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    for i in edge:
        if sizes[i - 1] < big * 0.05:
            a[lab == i, 3] = 0
    return Image.fromarray(a, "RGBA")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("level")
    ap.add_argument("--src")
    args = ap.parse_args()
    m = load_manifest(args.level)
    src = Path(args.src) if args.src else m["_gen"] / "refs"
    out = ROOT / "assets" / "textures" / m["_dir"].name.split("-")[0]
    out.mkdir(parents=True, exist_ok=True)

    def ref(aid: str) -> Image.Image:
        for ext in ("png", "jpg", "webp"):
            p = src / f"{aid}_main.{ext}"
            if p.exists():
                return Image.open(p)
        raise FileNotFoundError(aid)

    # Бекдроп: 4K по ширині, JPEG.
    bd = ref("backdrop").convert("RGB")
    bd.thumbnail((4096, 4096), Image.LANCZOS)
    bd.save(out / "backdrop.jpg", quality=90)

    # Монета: квадрат по колу, 512.
    coin = ref("coin").convert("RGB")
    s = min(coin.size)
    coin = coin.crop(((coin.width - s) // 2, (coin.height - s) // 2, (coin.width + s) // 2, (coin.height + s) // 2))
    coin = coin.resize((512, 512), Image.LANCZOS).convert("RGBA")
    yy, xx = np.mgrid[0:512, 0:512]
    inside = ((xx - 255.5) ** 2 + (yy - 255.5) ** 2) <= 250.0 ** 2
    coin.putalpha(Image.fromarray((inside * 255).astype(np.uint8)))
    coin.save(out / "coin_face.png", optimize=True)

    # Картонний ковбой.
    cb = key_background(ref("cowboy_cutout"))
    bx = pieces(cb, min_frac=0.05)
    save_piece(cb, max(bx, key=lambda b: (b[2] - b[0]) * (b[3] - b[1])), out / "cowboy_cutout.png", 1024)

    # Трава: перші 8 кущиків.
    gr = key_background(ref("ground_decals"), tol=22, enclosed=True)
    for i, b in enumerate(pieces(gr, min_frac=0.003)[:8]):
        save_piece(gr, b, out / f"grass_{i}.png", 256)

    # HUD: табличка, набій, приціл (зліва направо).
    hud = key_background(ref("hud"))
    hud_enc = key_background(ref("hud"), tol=22, enclosed=True)
    names = ["hud_plaque", "hud_bullet", "hud_crosshair"]
    hb = sorted(pieces(hud, min_frac=0.003), key=lambda b: b[0])
    for name, b in zip(names, hb):
        save_piece(hud_enc if name == "hud_crosshair" else hud, b, out / f"{name}.png", 768 if name == "hud_plaque" else 256)

    # Стікери: RICOCHET!, +50$, x2 (верхній ряд), CHAIN, OOPS! (нижній).
    st = key_background(ref("stickers"))
    names = ["sticker_ricochet", "sticker_plus50", "sticker_x2", "sticker_chain", "sticker_oops"]
    for name, b in zip(names, pieces(st, min_frac=0.004, close=10)):
        save_piece(st, b, out / f"{name}.png", 512)

    for p in sorted(out.iterdir()):
        if p.suffix not in (".png", ".jpg"):
            continue
        print(f"{p.name:24} {Image.open(p).size} {p.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
