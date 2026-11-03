#!/usr/bin/env python3
"""Рефи FLUX 3 (OpenRouter) для асетів рівня: концепт на вході — стиль тягнеться з нього.

  python3 tools/assets/refs.py 01                    # усі асети рівня
  python3 tools/assets/refs.py 01 --only crate,cactus
  python3 tools/assets/refs.py 01 --dry-run          # що згенерує і скільки коштує
  python3 tools/assets/refs.py 01 --only crate --force   # перегенерувати (стара версія лишається з суфіксом)

Види ланцюжком: спершу front34 (кроп + концепт), далі решта видів з front34 першим референсом,
щоб форма збігалась. Результат: source_assets/gen/<рівень>/refs/<id>_<вид>.<ext>.
"""
from __future__ import annotations

import argparse
import base64
import io
import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ROOT, die, load_manifest, log_cost, need_key, select_assets  # noqa: E402

API = "https://openrouter.ai/api/v1/images"
PRICE = {"768": 0.041, "1K": 0.048, "1.5K": 0.07, "2K": 0.10, "4K": 0.607}


def views_for(m: dict, a: dict) -> list[str]:
    """Які види потрібні асету: front34 завжди (якір), плюс види методів Meshy."""
    meth = a.get("methods") or [a.get("method", "S")]
    if "2D" in meth or a.get("texture_only"):
        return ["main"]
    out = ["front34"]
    for mm in meth:
        for v in m["meshy"].get(mm, {}).get("views", []):
            if v not in out:
                out.append(v)
    return out


def _data_url(img, fmt: str = "JPEG", min_side: int = 0) -> str:
    from PIL import Image

    im = img.convert("RGB")
    if min_side and min(im.size) < min_side:
        k = min_side / min(im.size)
        im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, fmt, quality=92)
    mime = "image/jpeg" if fmt == "JPEG" else "image/png"
    return f"data:{mime};base64,{base64.b64encode(buf.getvalue()).decode()}"


def concept_refs(m: dict, a: dict, anchor: Path | None = None) -> tuple[list[str], str]:
    """[якір-вид] + кроп об'єкта (якщо є) + увесь концепт. Повертає (data-url'и, пояснення для промпту)."""
    from PIL import Image

    cid = str(a.get("concept", "01"))
    concept = Image.open(ROOT / m["concepts"][cid])
    urls, note = [], []
    if anchor is not None:
        urls.append(_data_url(Image.open(anchor)))
        note.append("Image 1 shows the object itself.")
    if a.get("crop"):
        urls.append(_data_url(concept.crop(tuple(a["crop"])), min_side=768))
        note.append(f"Image {len(urls)} is a crop of the game concept art showing this object.")
    urls.append(_data_url(concept))
    note.append(f"Image {len(urls)} is the full game concept art: match its art style.")
    return urls, " ".join(note)


def build_request(m: dict, a: dict, view: str, anchor: Path | None) -> dict:
    cfg = m["refs"]
    style = m["style"].strip()
    urls, note = concept_refs(m, a, anchor)
    obj = a["prompt"].strip()
    vt = (a.get("views_override") or {}).get(view) or m["views"].get(view, "")
    meth = a.get("methods") or [a.get("method", "S")]
    body = {"model": cfg["model"], "resolution": cfg["resolution"], "aspect_ratio": cfg["aspect_ratio"]}
    if "2D" in meth:
        body["resolution"] = a.get("resolution", cfg["resolution"])
        body["aspect_ratio"] = a.get("aspect_ratio", cfg["aspect_ratio"])
        prompt = f"{obj}. {style} {note}"
    elif a.get("texture_only"):
        prompt = (f"{obj}, perfectly top-down orthographic view, the face fills the whole square frame edge to edge, "
                  f"flat even lighting, no background visible. {style} {note}")
    elif anchor is None:
        prompt = f"{m['ref_rules'].strip()} The object: {obj}. View: {vt}. {style} {note}"
    else:
        prompt = (f"The exact same object as in image 1 — identical shape, proportions, materials, colours and details — "
                  f"now shown in a {vt}. {m['ref_rules'].strip()} {style} {note}")
    body["prompt"] = prompt
    body["input_references"] = [{"type": "image_url", "image_url": {"url": u}} for u in urls]
    return body


def call_flux(body: dict, key: str) -> tuple[bytes, str, float]:
    import requests

    for attempt in range(4):
        r = requests.post(API, json=body, headers={"Authorization": f"Bearer {key}"}, timeout=300)
        if r.status_code in (429, 500, 502, 503, 504) and attempt < 3:
            time.sleep(5 * (attempt + 1))
            continue
        if r.status_code != 200:
            raise RuntimeError(f"OpenRouter {r.status_code}: {r.text[:400]}")
        d = r.json()
        item = d["data"][0]
        mt = item.get("media_type", "image/png")
        ext = {"image/png": "png", "image/jpeg": "jpg", "image/webp": "webp"}.get(mt, "png")
        cost = float((d.get("usage") or {}).get("cost") or 0.0)
        return base64.b64decode(item["b64_json"]), ext, cost
    raise RuntimeError("OpenRouter: вичерпано спроби")


def existing(out_dir: Path, aid: str, view: str) -> Path | None:
    for ext in ("png", "jpg", "webp"):
        p = out_dir / f"{aid}_{view}.{ext}"
        if p.exists():
            return p
    return None


def run_asset(m: dict, a: dict, key: str, force: bool, dry: bool) -> list[str]:
    out_dir = m["_gen"] / "refs"
    out_dir.mkdir(parents=True, exist_ok=True)
    log = []
    anchor = None
    for view in views_for(m, a):
        have = existing(out_dir, a["id"], view)
        if have and not force:
            log.append(f"  = {have.name} (кеш)")
            if view == "front34":
                anchor = have
            continue
        body = build_request(m, a, view, anchor if view not in ("front34", "main") else None)
        if dry:
            log.append(f"  · {a['id']}_{view} [{body['resolution']}, {body['aspect_ratio']}, refs {len(body['input_references'])}]")
            if view == "front34":
                anchor = out_dir / f"{a['id']}_front34.png"  # для підрахунку
            continue
        if have and force:
            stamp = time.strftime("%H%M%S")
            have.rename(have.with_name(f"{have.stem}.old{stamp}{have.suffix}"))
        img, ext, cost = call_flux(body, key)
        p = out_dir / f"{a['id']}_{view}.{ext}"
        p.write_bytes(img)
        (out_dir / f"{a['id']}_{view}.prompt.txt").write_text(body["prompt"])
        log_cost(m, "openrouter", a["id"], f"flux {view} {body['resolution']}", cost, "USD")
        log.append(f"  + {p.name} ${cost:.3f}")
        if view == "front34":
            anchor = p
    return log


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("level")
    ap.add_argument("--only", help="id через кому")
    ap.add_argument("--group", help="група: hero, throwable, target, env, 2d")
    ap.add_argument("--force", action="store_true", help="перегенерувати навіть якщо є в кеші")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--jobs", type=int, default=4)
    args = ap.parse_args()

    m = load_manifest(args.level)
    items = select_assets(m, args.only, args.group)
    if args.dry_run:
        n, usd = 0, 0.0
        for a in items:
            for v in views_for(m, a):
                if existing(m["_gen"] / "refs", a["id"], v) and not args.force:
                    continue
                res = a.get("resolution", m["refs"]["resolution"]) if v == "main" else m["refs"]["resolution"]
                n += 1
                usd += PRICE.get(res, 0.07)
        for a in items:
            print(f"{a['id']}: {', '.join(views_for(m, a))}")
        print(f"\nНових зображень: {n}, ≈ ${usd:.2f}")
        return
    key = need_key("OPENROUTER_API_KEY")
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=args.jobs) as ex:
        futs = {ex.submit(run_asset, m, a, key, args.force, False): a["id"] for a in items}
        for f in as_completed(futs):
            aid = futs[f]
            try:
                print(f"✔ {aid}\n" + "\n".join(f.result()), flush=True)
            except Exception as e:  # noqa: BLE001
                print(f"✘ {aid}: {e}", flush=True)
    print(f"Готово за {time.time() - t0:.0f} с")


if __name__ == "__main__":
    main()
