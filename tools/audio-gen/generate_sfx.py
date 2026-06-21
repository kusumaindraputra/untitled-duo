#!/usr/bin/env python3
"""Generate game SFX from tools/audio-gen/sfx_manifest.json via the ElevenLabs Sound Effects API.

Usage:
  ELEVENLABS_API_KEY=sk_... python3 tools/audio-gen/generate_sfx.py [options]
  python3 tools/audio-gen/generate_sfx.py --api-key sk_... [options]

Options:
  --dry-run            Print the plan and estimated credit cost; make no API calls.
  --only EVENT[,EVENT] Generate only the named events (e.g. sfx_spell_cast).
  --force              Re-generate even if the output file already exists.
  --out DIR            Output directory (default: assets/audio/sfx).

Cost: 40 credits/second when duration is specified (ElevenLabs Sound Effects v2).
Outputs mp3_44100_128 — imported natively by Godot 4.
"""
import argparse
import json
import os
import sys
import time
import urllib.request
import urllib.error

MAX_RETRIES = 5

API_URL = "https://api.elevenlabs.io/v1/sound-generation"
OUTPUT_FORMAT = "mp3_44100_128"
CREDITS_PER_SECOND = 40
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = os.path.join(REPO_ROOT, "tools", "audio-gen", "sfx_manifest.json")


def load_events():
    with open(MANIFEST, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data["events"], data.get("_api", {})


def estimate_credits(events):
    return sum(e.get("duration_seconds", 1.0) for e in events) * CREDITS_PER_SECOND


def generate_one(api_key, event, out_dir, model_id):
    body = json.dumps({
        "text": event["prompt"],
        "model_id": model_id,
        "duration_seconds": event.get("duration_seconds"),
        "prompt_influence": event.get("prompt_influence", 0.3),
        "loop": event.get("loop", False),
    }).encode("utf-8")
    url = f"{API_URL}?output_format={OUTPUT_FORMAT}"
    last_err = None
    for attempt in range(MAX_RETRIES):
        req = urllib.request.Request(url, data=body, method="POST")
        req.add_header("xi-api-key", api_key)
        req.add_header("Content-Type", "application/json")
        req.add_header("Accept", "audio/mpeg")
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                audio = resp.read()
            out_path = os.path.join(out_dir, event["file"] + ".mp3")
            with open(out_path, "wb") as f:
                f.write(audio)
            return out_path, len(audio)
        except urllib.error.HTTPError as ex:
            # Retry transient server-side conditions (429 busy, 5xx); re-raise client errors.
            if ex.code == 429 or ex.code >= 500:
                last_err = ex
                wait = 2 ** attempt
                print(f"    retry {attempt + 1}/{MAX_RETRIES} ({event['event']}): HTTP {ex.code}, waiting {wait}s")
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
    p.add_argument("--out", default=os.path.join(REPO_ROOT, "assets", "audio", "sfx"))
    args = p.parse_args()

    events, api_cfg = load_events()
    model_id = api_cfg.get("model_id", "eleven_text_to_sound_v2")

    if args.only:
        wanted = {s.strip() for s in args.only.split(",") if s.strip()}
        events = [e for e in events if e["event"] in wanted]
        if not events:
            print(f"No manifest events matched --only={args.only}", file=sys.stderr)
            return 2

    print(f"Plan: {len(events)} event(s), est. {estimate_credits(events):.0f} credits "
          f"({sum(e.get('duration_seconds', 1.0) for e in events):.1f}s @ {CREDITS_PER_SECOND} cr/s).")

    if args.dry_run:
        for e in events:
            print(f"  - {e['event']:<26} {e.get('duration_seconds', 1.0):>4.1f}s  {e['file']}.mp3")
        return 0

    if not args.api_key:
        print("ERROR: no API key. Set ELEVENLABS_API_KEY or pass --api-key.", file=sys.stderr)
        return 1

    os.makedirs(args.out, exist_ok=True)
    ok, skipped, failed = 0, 0, 0
    for e in events:
        out_path = os.path.join(args.out, e["file"] + ".mp3")
        if os.path.exists(out_path) and not args.force:
            print(f"  skip (exists): {e['event']}")
            skipped += 1
            continue
        try:
            path, nbytes = generate_one(args.api_key, e, args.out, model_id)
            print(f"  ok: {e['event']:<26} -> {os.path.relpath(path, REPO_ROOT)} ({nbytes//1024} KB)")
            ok += 1
        except urllib.error.HTTPError as ex:
            detail = ex.read().decode("utf-8", "replace")[:300]
            print(f"  FAIL: {e['event']} -> HTTP {ex.code}: {detail}", file=sys.stderr)
            failed += 1
        except Exception as ex:  # noqa: BLE001
            print(f"  FAIL: {e['event']} -> {ex}", file=sys.stderr)
            failed += 1

    print(f"\nDone. ok={ok} skipped={skipped} failed={failed}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
