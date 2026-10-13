#!/usr/bin/env bash
# Headless test run that also fails on GDScript runtime errors (a runtime error
# aborts a test method silently, so the runner alone cannot see it).
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="$(mktemp)"
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . -s tests/run_tests.gd "$@" 2>&1 | tee "$OUT" | grep -v "ObjectDB instances were leaked\|resources still in use\|at: cleanup\|at: clear"
status=${PIPESTATUS[0]}
if grep -q "SCRIPT ERROR\|Compile Error\|Parse Error" "$OUT"; then
  echo "script errors found" >&2
  status=1
fi
rm -f "$OUT"
exit "$status"
