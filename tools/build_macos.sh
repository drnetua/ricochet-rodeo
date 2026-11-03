#!/usr/bin/env bash
# Build Ricochet Rodeo for macOS from the command line.
#
# Uses the "macOS" preset in export_presets.cfg: ad-hoc signature, no Apple
# certificate, no notarization. Good for running on this Mac.
#
# Usage:
#   tools/build_macos.sh            release build, then open the game
#   tools/build_macos.sh --debug    debug build (prints errors to the console)
#   OPEN=0 tools/build_macos.sh     build only, don't launch
#   GODOT=/path/to/Godot tools/build_macos.sh   use another Godot binary
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PRESET="${PRESET:-macOS}"
OUT="$ROOT/export/macos/Ricochet Rodeo.app"
MODE="--export-release"
[[ "${1:-}" == "--debug" ]] && MODE="--export-debug"

die() { echo "❌ $*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "Run this on macOS."
[[ -x "$GODOT" ]] || die "Godot not found at $GODOT (set GODOT=/path/to/Godot)."
grep -q "name=\"$PRESET\"" "$ROOT/export_presets.cfg" 2>/dev/null \
  || die "Preset \"$PRESET\" not found in export_presets.cfg."

# e.g. "4.7.stable.official.abc123" -> "4.7.stable", "4.7.1.stable.official" -> "4.7.1.stable"
GODOT_VER="$("$GODOT" --version | head -1 | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?\.[a-z0-9]+)\..*/\1/')"
TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/$GODOT_VER/macos.zip"
[[ -f "$TEMPLATES" ]] || die "Export templates $GODOT_VER are missing.
   In Godot: Editor → Manage Export Templates → Download and Install."

echo "▶ Godot $GODOT_VER, preset \"$PRESET\" ($MODE)"
mkdir -p "$(dirname "$OUT")"
rm -rf "$OUT"

# Import new or changed assets first (models, sounds) so the export is complete.
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

"$GODOT" --headless --path "$ROOT" "$MODE" "$PRESET" "$OUT"
[[ -d "$OUT" ]] || die "Export failed: $OUT was not created (see the log above)."

codesign --verify --deep --strict "$OUT" || die "Signature check failed."
# Locally built apps carry no quarantine flag; clear it anyway in case the
# folder came from a download or AirDrop.
xattr -dr com.apple.quarantine "$OUT" 2>/dev/null || true

echo "✅ Built: $OUT ($(du -sh "$OUT" | cut -f1))"
[[ "${OPEN:-1}" == "1" ]] && open "$OUT"
exit 0
