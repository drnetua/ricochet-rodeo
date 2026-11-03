# Конвеєр асетів рівня

Концепт → рефи FLUX 3 → Meshy → чистка в Blender → Godot. Що генеруємо — `art/levels/<рівень>/assets.yaml`.

```
python3 tools/assets/level.py 01 --step refs  --dry-run   # план і ціна
python3 tools/assets/level.py 01 --step refs              # рефи FLUX 3 (OpenRouter)
python3 tools/assets/level.py 01 --step meshy             # моделі Meshy
python3 tools/assets/level.py 01 --step clean             # чистка → assets/models/01/*.glb
python3 tools/assets/level.py 01 --step status            # що готово
python3 tools/assets/level.py 01 --step cost              # фактичні витрати
```

Фільтри: `--only crate,cactus`, `--group env`, для meshy/clean ще `--method M|S`.
Перегенерація одного асета: `--only <id> --force` (стара версія рефу лишається з суфіксом `.old…`).

- Ключі — у `.env` (див. `.env.example`): `OPENROUTER_API_KEY`, `MESHY_API_KEY`.
- Кеш і сирі файли — `source_assets/gen/<рівень>/` (не в git): `refs/`, `meshy/`, `costs.jsonl`.
  Повторний запуск нічого не платить двічі; id задачі Meshy пишеться одразу, тож перерваний запуск дочікується тієї ж задачі.
- У git: маніфест, відібрані рефи (`art/levels/<рівень>/refs/`), рендери перевірки (`art/levels/<рівень>/renders/`),
  чисті моделі (`assets/models/<рівень>/`, Git LFS).
- Залежності: Python 3.10+, `requests`, `pyyaml`, `pillow`; для clean — модуль `bpy` 5.2 (Python 3.13) або Blender 5.x.

Методи Meshy: **M** — multi-image (meshy-7.1, види front/side/back), **S** — Smart Topology (meshy-t2.5, вид front34).
Пілот проганяє обидва (`methods: [M, S]`), кращий записуємо в `use`.

Скриншот з гри без людини (для порівняння з концептом):
```
godot --path . --script tools/godot/screenshot.gd -- shot.png res://scenes/main.tscn 120
```
