#!/usr/bin/env bash
# Runs the GUT suite headless. Exit code is non-zero if any test fails.
# Usage: ./run_tests.sh [extra GUT args, e.g. -gselect=test_step_order]
set -euo pipefail
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"

# Make sure class_name caches and imports exist (needed on a fresh clone).
"$GODOT" --headless --path . --import >/dev/null 2>&1

"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@"
