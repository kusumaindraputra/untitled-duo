#!/usr/bin/env python3
"""Generate game music tracks from tools/audio-gen/music_manifest.json via ElevenLabs /v1/music.

Usage:
  ELEVENLABS_API_KEY=sk_... python3 tools/audio-gen/generate_music.py [options]
  python3 tools/audio-gen/generate_music.py --api-key sk_... [options]

Options:
  --dry-run            Print the plan; make no API calls.
  --only EVENT[,EVENT] Generate only the named events (e.g. mus_combat_floor).
  --force              Re-generate even if the output file already exists.
  --out DIR            Output directory (default: assets/audio/music).
"""
import argparse
import json
import os
import sys
import time
import urllib.request
import urllib.error

MAX_RETRIES = 5

API_URL = "https://api.elevenlabs.io/v1/music"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = os.path.join(REPO_ROOT, "tools", "audio-gen", "music_manifest.json")


def load_tracks():
    with open(MANIFEST, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data["tracks"]


def generate_one(api_key, track, out_dir):
    body = json.dumps({
        "prompt": track["prompt"],
        "duration_seconds": track.get("duration_seconds"),
    }).encode("utf-8")
    last_err = None
    for attempt in range(MAX_RETRIES):
        req = urllib.request.Request(API_URL, data=body, method="POST")
        req.add_header("xi-api-key", api_key)
        req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=180) as resp:
                audio = resp.read()
            out_path = os.path.join(out_dir, track["file"] + ".mp3")
            with open(out_path, "wb") as f:
                f.write(audio)
            return out_path, len(audio)
        except urllib.error.HTTPError as ex:
            if ex.code == 429 or ex.code >= 500:
                last_err = ex
                wait = 2 ** attempt
                print(f"    retry {attempt + 1}/{MAX_RETRIES} ({track['event']}): HTTP {ex.code}, waiting {wait}s")
                time.sleep(wait)
                continue
            raise
    raise last_err


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--api-key", default=os.environ.get("ELEVENLABS_API_KEY"))
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--only", default="")
    p.add_argument("--force", action="store_true")
    p.add_argument("--out", default=os.path.join(REPO_ROOT, "assets", "audio", "music"))
    args = p.parse_args()

    tracks = load_tracks()

    if args.only:
        wanted = {s.strip() for s in args.only.split(",") if s.strip()}
        tracks = [t for t in tracks if t["event"] in wanted]
        if not tracks:
            print(f"No manifest tracks matched --only={args.only}", file=sys.stderr)
            return 2

    total_sec = sum(t.get("duration_seconds", 30) for t in tracks)
    print(f"Plan: {len(tracks)} track(s), {total_sec:.0f}s total.")

    if args.dry_run:
        for t in tracks:
            print(f"  - {t['event']:<24} {t.get('duration_seconds', 30):>3}s  {t['file']}.mp3")
        return 0

    if not args.api_key:
        print("ERROR: no API key. Set ELEVENLABS_API_KEY or pass --api-key.", file=sys.stderr)
        return 1

    os.makedirs(args.out, exist_ok=True)
    ok, skipped, failed = 0, 0, 0
    for t in tracks:
        out_path = os.path.join(args.out, t["file"] + ".mp3")
        if os.path.exists(out_path) and not args.force:
            print(f"  skip (exists): {t['event']}")
            skipped += 1
            continue
        try:
            path, nbytes = generate_one(args.api_key, t, args.out)
            print(f"  ok: {t['event']:<24} -> {os.path.relpath(path, REPO_ROOT)} ({nbytes // 1024} KB)")
            ok += 1
        except urllib.error.HTTPError as ex:
            detail = ex.read().decode("utf-8", "replace")[:300]
            print(f"  FAIL: {t['event']} -> HTTP {ex.code}: {detail}", file=sys.stderr)
            failed += 1
        except Exception as ex:  # noqa: BLE001
            print(f"  FAIL: {t['event']} -> {ex}", file=sys.stderr)
            failed += 1

    print(f"\nDone. ok={ok} skipped={skipped} failed={failed}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
