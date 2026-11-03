"""Спільне для конвеєра асетів: шляхи, маніфест рівня, ключі, кеш і лог витрат.

Генерація (refs, meshy) пише лише в source_assets/gen/<рівень>/ — ця папка в .gitignore
і є кешем: повторний запуск нічого не платить двічі. У git потрапляють відібрані
рефи (art/levels/<рівень>/refs/) і чисті моделі (assets/models/<рівень>/).
"""
from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def die(msg: str) -> None:
    print(f"❌ {msg}", file=sys.stderr)
    sys.exit(1)


def load_env() -> None:
    """Підхоплює ключі з .env у корені репо (якщо їх ще нема в оточенні)."""
    env = ROOT / ".env"
    if not env.exists():
        return
    for line in env.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def need_key(name: str) -> str:
    load_env()
    v = os.environ.get(name, "")
    if not v:
        die(f"{name} нема в .env")
    return v


def find_level_dir(level: str) -> Path:
    """'01' або '01-wild-west' → art/levels/01-wild-west."""
    base = ROOT / "art" / "levels"
    for d in sorted(base.glob(f"{level}*")):
        if (d / "assets.yaml").exists():
            return d
    die(f"не знайшов art/levels/{level}*/assets.yaml")
    raise SystemExit


def load_manifest(level: str) -> dict:
    import yaml

    d = find_level_dir(level)
    m = yaml.safe_load((d / "assets.yaml").read_text())
    m["_dir"] = d
    m["_gen"] = ROOT / "source_assets" / "gen" / d.name
    return m


def select_assets(m: dict, only: str | None, groups: str | None = None) -> list[dict]:
    items = m["assets"]
    if only:
        want = {x.strip() for x in only.split(",") if x.strip()}
        unknown = want - {a["id"] for a in items}
        if unknown:
            die(f"нема в маніфесті: {', '.join(sorted(unknown))}")
        items = [a for a in items if a["id"] in want]
    if groups:
        g = {x.strip() for x in groups.split(",")}
        items = [a for a in items if a.get("group") in g]
    return items


def log_cost(m: dict, service: str, asset: str, what: str, amount: float, unit: str, extra: dict | None = None) -> None:
    """Пише фактичну витрату в source_assets/gen/<рівень>/costs.jsonl."""
    m["_gen"].mkdir(parents=True, exist_ok=True)
    rec = {"t": time.strftime("%Y-%m-%d %H:%M:%S"), "service": service, "asset": asset, "what": what, "amount": amount, "unit": unit}
    if extra:
        rec.update(extra)
    with open(m["_gen"] / "costs.jsonl", "a") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")


def cost_summary(m: dict) -> dict:
    p = m["_gen"] / "costs.jsonl"
    tot: dict = {}
    if p.exists():
        for line in p.read_text().splitlines():
            r = json.loads(line)
            key = f'{r["service"]} ({r["unit"]})'
            tot[key] = tot.get(key, 0) + float(r["amount"])
    return tot
