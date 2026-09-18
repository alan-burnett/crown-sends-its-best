#!/usr/bin/env bash
# Run headless Godot and show its output.
#
# The Windows build has no console wrapper, so it is a GUI-subsystem binary and
# prints nothing to a terminal unless its output is redirected to a file. This
# wrapper hides that, and keeps the exit code, so the same command works locally
# and in CI.
set -uo pipefail

GODOT_BIN="${GODOT_BIN:-}"
if [[ -z "$GODOT_BIN" ]]; then
  for candidate in \
    "$(command -v godot || true)" \
    "$(command -v godot4 || true)" \
    "/c/Users/${USER:-${USERNAME:-nobody}}/Downloads/Godot_v4.7.1-stable_win64.exe" \
    "$HOME/Downloads/Godot_v4.7.1-stable_win64.exe"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then GODOT_BIN="$candidate"; break; fi
  done
fi

if [[ -z "$GODOT_BIN" ]]; then
  echo "Godot not found. Set GODOT_BIN to the executable." >&2
  exit 127
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Streamed through a file rather than run directly, because the Windows build
# is a GUI-subsystem binary and writes nothing to an attached terminal. Tailing
# it as it goes means a hang shows where it hung instead of printing nothing.
OUT="$(mktemp)"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" "$@" >"$OUT" 2>&1 &
GODOT_PID=$!
tail -n +1 -f --pid="$GODOT_PID" "$OUT" 2>/dev/null &
TAIL_PID=$!
wait "$GODOT_PID"
STATUS=$?
wait "$TAIL_PID" 2>/dev/null
rm -f "$OUT"
exit $STATUS
