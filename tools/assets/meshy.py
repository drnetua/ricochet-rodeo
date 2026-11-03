#!/usr/bin/env python3
"""Моделі Meshy з рефів FLUX: M — multi-image (3 види), S — Smart Topology (1 вид).

  python3 tools/assets/meshy.py 01                 # усі 3D-асети рівня
  python3 tools/assets/meshy.py 01 --only crate --method S
  python3 tools/assets/meshy.py 01 --dry-run       # що піде в Meshy і скільки кредитів

Кеш: id задачі пишеться в source_assets/gen/<рівень>/meshy/<id>_<M|S>.task.json одразу після
створення, тож перерваний запуск продовжує чекати ту саму задачу, а не платить удруге.
Результат: <id>_<M|S>.glb і прев'ю <id>_<M|S>_<вид>.png поруч.
"""
from __future__ import annotations

import argparse
import base64
import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import die, load_manifest, log_cost, need_key, select_assets  # noqa: E402
from refs import existing  # noqa: E402

BASE = "https://api.meshy.ai/openapi/v1/"
CREDITS = {"M": 30, "M_hero": 35, "S": 15}


def methods_of(a: dict, forced: str | None) -> list[str]:
    meth = a.get("methods") or [a.get("method")]
    meth = [x for x in meth if x in ("M", "S")]
    if forced:
        meth = [x for x in meth if x == forced]
    return meth


def data_uri(p: Path) -> str:
    mime = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "webp": "image/webp"}[p.suffix[1:].lower()]
    return f"data:{mime};base64,{base64.b64encode(p.read_bytes()).decode()}"


def build_body(m: dict, a: dict, method: str) -> tuple[str, dict]:
    cfg = m["meshy"][method]
    body = dict(cfg["body"])
    refs_dir = m["_gen"] / "refs"
    imgs = []
    for v in cfg["views"]:
        p = existing(refs_dir, a["id"], v)
        if p is None:
            raise FileNotFoundError(f"нема рефу {a['id']}_{v} — спершу refs")
        imgs.append(p)
    if method == "M":
        body["image_urls"] = [data_uri(p) for p in imgs]
    else:
        body["image_url"] = data_uri(imgs[0])
    tris = int(a.get("tris", 0))
    if tris:
        lo, hi = (100, 30000) if method == "S" else (100, 300000)
        body["target_polycount"] = max(lo, min(hi, tris))
    body.update(a.get("meshy_body") or {})
    if method == "S":
        # Smart Topology: геометрія фіксована, текстури — стандартні 2K.
        body.pop("geometry_resolution", None)
        body.pop("texture_resolution", None)
    return cfg["endpoint"], body


def _req(method: str, url: str, key: str, **kw):
    import requests

    for attempt in range(6):
        r = requests.request(method, url, headers={"Authorization": f"Bearer {key}"}, timeout=120, **kw)
        if r.status_code == 429 and attempt < 5:
            time.sleep(10 * (attempt + 1))
            continue
        return r
    return r


def download(url: str, dst: Path) -> None:
    import requests

    with requests.get(url, stream=True, timeout=300) as r:
        r.raise_for_status()
        tmp = dst.with_suffix(dst.suffix + ".part")
        with open(tmp, "wb") as f:
            for chunk in r.iter_content(1 << 20):
                f.write(chunk)
        tmp.replace(dst)


def run_one(m: dict, a: dict, method: str, key: str, force: bool) -> str:
    out = m["_gen"] / "meshy"
    out.mkdir(parents=True, exist_ok=True)
    name = f"{a['id']}_{method}"
    glb = out / f"{name}.glb"
    state_p = out / f"{name}.task.json"
    if glb.exists() and not force:
        return f"= {name}.glb (кеш)"
    state = json.loads(state_p.read_text()) if state_p.exists() else {}
    if force or state.get("status") in ("FAILED", "CANCELED"):
        state = {}
    endpoint = state.get("endpoint")
    if not state.get("id"):
        endpoint, body = build_body(m, a, method)
        r = _req("POST", BASE + endpoint, key, json=body)
        if r.status_code not in (200, 202):
            raise RuntimeError(f"Meshy {r.status_code}: {r.text[:400]}")
        state = {"id": r.json()["result"], "endpoint": endpoint, "status": "PENDING", "created": time.strftime("%Y-%m-%d %H:%M:%S"),
                 "body": {k: v for k, v in body.items() if k not in ("image_url", "image_urls")}}
        state_p.write_text(json.dumps(state, indent=2))
    # Чекаємо результат.
    t0 = time.time()
    while True:
        r = _req("GET", BASE + f"{endpoint}/{state['id']}", key)
        if r.status_code != 200:
            raise RuntimeError(f"Meshy poll {r.status_code}: {r.text[:300]}")
        task = r.json()
        st = task.get("status")
        if st in ("SUCCEEDED", "FAILED", "CANCELED"):
            break
        if time.time() - t0 > 1800:
            raise TimeoutError(f"{name}: задача {state['id']} довше 30 хв, перезапусти — продовжить чекати")
        time.sleep(10)
    state["status"] = st
    state_p.write_text(json.dumps(state, indent=2))
    if st != "SUCCEEDED":
        raise RuntimeError(f"{name}: {st} {task.get('task_error')}")
    credits = int(task.get("consumed_credits") or 0)
    log_cost(m, "meshy", a["id"], f"{method} {endpoint}", credits, "credits", {"task": state["id"]})
    for v, url in (task.get("thumbnail_urls") or {}).items():
        try:
            download(url, out / f"{name}_{v}.png")
        except Exception:  # noqa: BLE001
            pass
    download(task["model_urls"]["glb"], glb)
    state["consumed_credits"] = credits
    state["finished"] = time.strftime("%Y-%m-%d %H:%M:%S")
    state_p.write_text(json.dumps(state, indent=2))
    mb = glb.stat().st_size / 1e6
    return f"+ {name}.glb {mb:.1f} MB, {credits} кредитів, {time.time() - t0:.0f} с"


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("level")
    ap.add_argument("--only")
    ap.add_argument("--group")
    ap.add_argument("--method", choices=["M", "S"])
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--jobs", type=int, default=5, help="скільки задач Meshy одночасно")
    args = ap.parse_args()

    m = load_manifest(args.level)
    jobs = []
    for a in select_assets(m, args.only, args.group):
        if a.get("texture_only"):
            continue
        for mm in methods_of(a, args.method):
            jobs.append((a, mm))
    if not jobs:
        die("нема 3D-асетів для Meshy в цьому виборі")
    out = m["_gen"] / "meshy"
    todo = [(a, mm) for a, mm in jobs if args.force or not (out / f"{a['id']}_{mm}.glb").exists()]
    est = sum(CREDITS["M_hero" if (mm == "M" and (a.get("meshy_body") or {}).get("texture_resolution") == "4k") else mm] for a, mm in todo)
    print(f"Задач: {len(todo)} нових з {len(jobs)}, ≈ {est} кредитів")
    if args.dry_run:
        for a, mm in todo:
            print(f"  · {a['id']}_{mm}")
        return
    key = need_key("MESHY_API_KEY")
    bal = _req("GET", BASE + "balance", key).json().get("balance")
    print(f"Баланс Meshy: {bal}")
    if bal is not None and bal < est:
        die(f"кредитів замало: треба ≈{est}, є {bal}")
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=args.jobs) as ex:
        futs = {ex.submit(run_one, m, a, mm, key, args.force): f"{a['id']}_{mm}" for a, mm in jobs}
        for f in as_completed(futs):
            try:
                print(f"✔ {f.result()}", flush=True)
            except Exception as e:  # noqa: BLE001
                print(f"✘ {futs[f]}: {e}", flush=True)
    bal2 = _req("GET", BASE + "balance", key).json().get("balance")
    print(f"Готово за {time.time() - t0:.0f} с. Баланс Meshy: {bal2}")


if __name__ == "__main__":
    main()
