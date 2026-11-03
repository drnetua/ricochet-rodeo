#!/usr/bin/env python3
"""Конвеєр рівня одним скриптом: рефи → Meshy → чистка в Blender, з кешем і логом витрат.

  python3 tools/assets/level.py 01 --step refs     [--only crate,cactus] [--group env] [--force] [--dry-run]
  python3 tools/assets/level.py 01 --step meshy    [--only ...] [--method M|S] [--dry-run]
  python3 tools/assets/level.py 01 --step clean    [--only ...] [--method M|S|use]
  python3 tools/assets/level.py 01 --step status   # що вже згенеровано
  python3 tools/assets/level.py 01 --step cost     # фактичні витрати з логу

Кроки refs і meshy платні, але кешовані: повторний запуск пропускає готове.
Крок clean шукає модуль bpy, інакше Blender (BLENDER=/шлях або /Applications/Blender.app).
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from common import cost_summary, load_manifest, select_assets  # noqa: E402
from refs import existing, views_for  # noqa: E402


def blender_cmd() -> list[str]:
    try:
        import bpy  # noqa: F401

        return [sys.executable, str(HERE / "clean_blender.py")]
    except ImportError:
        pass
    for b in (os.environ.get("BLENDER"), shutil.which("blender"), "/Applications/Blender.app/Contents/MacOS/Blender"):
        if b and Path(b).exists():
            return [b, "-b", "--factory-startup", "-P", str(HERE / "clean_blender.py"), "--"]
    sys.exit("❌ Нема ні модуля bpy, ні Blender. Встанови Blender або: pip install bpy")


def status(m: dict, args) -> None:
    gen = m["_gen"]
    out = Path(__file__).resolve().parents[2] / "assets" / "models" / m["_dir"].name.split("-")[0]
    print(f"{'id':16} {'метод':6} {'рефи':14} {'meshy':10} {'glb':4}")
    for a in select_assets(m, args.only, args.group):
        vs = views_for(m, a)
        have = sum(1 for v in vs if existing(gen / "refs", a["id"], v))
        meths = a.get("methods") or [a.get("method")]
        aid = a["id"]
        marks = []
        for mm in meths:
            if mm in ("M", "S"):
                done = (gen / "meshy" / f"{aid}_{mm}.glb").exists()
                marks.append(mm + ("✔" if done else "·"))
        mesh = " ".join(marks)
        glb = "✔" if (out / f"{a['id']}.glb").exists() else "·"
        print(f"{a['id']:16} {'/'.join(map(str, meths)):6} {have}/{len(vs):<12} {mesh:10} {glb}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("level")
    ap.add_argument("--step", required=True, choices=["refs", "meshy", "clean", "status", "cost"])
    args, rest = ap.parse_known_args()
    m = load_manifest(args.level)
    if args.step in ("status", "cost"):
        ap2 = argparse.ArgumentParser()
        ap2.add_argument("--only")
        ap2.add_argument("--group")
        a2 = ap2.parse_args(rest)
        if args.step == "status":
            status(m, a2)
        else:
            for k, v in cost_summary(m).items():
                print(f"{k}: {v:.2f}" if "USD" in k else f"{k}: {v:.0f}")
        return
    if args.step == "refs":
        cmd = [sys.executable, str(HERE / "refs.py"), args.level, *rest]
    elif args.step == "meshy":
        cmd = [sys.executable, str(HERE / "meshy.py"), args.level, *rest]
    else:
        cmd = [*blender_cmd(), args.level, *rest]
    sys.exit(subprocess.call(cmd))


if __name__ == "__main__":
    main()
