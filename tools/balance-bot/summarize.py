#!/usr/bin/env python3
"""Summarises balance bot reports (ADR-0051): run length and boss fight times.

Usage: python3 tools/balance-bot/summarize.py build/balance-bot/run_*.json
"""
import json
import statistics
import sys

BOSS = 3  # DungeonGraph.ROOM_TYPE_BOSS
# A stall is a room the bot could not finish (it cannot find a last enemy; a player
# would). The bot waits stall_sec before clearing it, so that wait is taken off the
# estimate and a player's search time is put back instead.
PLAYER_SEARCH_SEC = 5.0


def player_sec(r: dict) -> float:
    return r["est_player_sec"] - r.get("stalls", 0) * (r.get("stall_sec", 20.0) - PLAYER_SEARCH_SEC)


def fmt(sec: float) -> str:
    return f"{int(sec // 60)}:{int(sec % 60):02d}"


def main(paths: list[str]) -> None:
    runs = []
    for p in paths:
        try:
            with open(p) as f:
                runs.append(json.load(f))
        except (OSError, json.JSONDecodeError) as e:
            print(f"skip {p}: {e}")
    if not runs:
        print("no reports")
        return
    print(f"{'seed':>4} {'outcome':>8} {'floor':>5} {'rooms':>5} {'bot':>6} {'player~':>7} {'dmg':>5} {'bosses (s)':<24}")
    for r in sorted(runs, key=lambda r: r["seed"]):
        bosses = " ".join(f"F{b['floor']}:{b['combat_sec']:.0f}" for b in r.get("boss_fights", []))
        print(f"{r['seed']:>4} {r['outcome']:>8} {r['floor_reached']:>5} {r['rooms']:>5} "
              f"{fmt(r['sim_sec']):>6} {fmt(player_sec(r)):>7} {r['damage_taken']:>5} {bosses:<24} stalls={r.get('stalls', 0)}")
    wins = [r for r in runs if r["win"]]
    if wins:
        est = [player_sec(r) for r in wins]
        print(f"\nfull runs: {len(wins)}/{len(runs)}  est. player time median {fmt(statistics.median(est))}"
              f"  range {fmt(min(est))}-{fmt(max(est))}")
    by_floor: dict[int, list[float]] = {}
    room_floor: dict[int, list[float]] = {}
    for r in runs:
        for room in r.get("room_log", []):
            bucket = by_floor if room["type"] == BOSS else room_floor
            bucket.setdefault(room["floor"], []).append(room["combat_sec"])
    for fl in sorted(room_floor):
        v = room_floor[fl]
        print(f"floor {fl}: room fight median {statistics.median(v):.0f}s over {len(v)} rooms")
    for fl in sorted(by_floor):
        v = by_floor[fl]
        print(f"floor {fl}: boss fight median {statistics.median(v):.0f}s (n={len(v)}, {min(v):.0f}-{max(v):.0f}s)")


if __name__ == "__main__":
    main(sys.argv[1:])
