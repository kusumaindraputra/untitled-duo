#!/usr/bin/env bash
# Runs the balance bot (ADR-0051) for several seeds in parallel and summarises them.
# Usage: tools/balance-bot/run_bot.sh [runs] [jobs] [extra bot flags...]
#   tools/balance-bot/run_bot.sh 8 4 --god
# Needs `godot` (4.6) on PATH and an imported project (godot --headless --import).
set -euo pipefail
RUNS="${1:-6}"
JOBS="${2:-3}"
shift 2 || true
OUT="${BOT_OUT:-build/balance-bot}"
mkdir -p "$OUT"
seq 1 "$RUNS" | xargs -P "$JOBS" -I{} sh -c \
	"timeout 1800 godot --headless --fixed-fps 60 --path . res://tools/balance-bot/BalanceBot.tscn -- \
	--seed={} --out=\"$(pwd)/$OUT/run_{}.json\" $* > \"$OUT/run_{}.log\" 2>&1 || true"
python3 tools/balance-bot/summarize.py "$OUT"/run_*.json
