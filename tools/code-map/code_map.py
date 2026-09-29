#!/usr/bin/env python3
"""Map the GDScript code in src/: autoloads, class references, preloads and signals.

Reads every .gd and .tscn file under the source folder plus the [autoload] block of
project.godot, and writes a Markdown report (with Mermaid diagrams) and optionally JSON.
Static text analysis only: no Godot, no LLM, standard library only.

Usage:
    python3 tools/code-map/code_map.py                      # writes docs/architecture/code-map.md
    python3 tools/code-map/code_map.py --json out.json      # also writes the raw data
    python3 tools/code-map/code_map.py --stdout             # prints the report instead
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

LARGE_FILE_LINES = 800
TOP_N = 20

RE_CLASS_NAME = re.compile(r"^\s*class_name\s+(\w+)", re.M)
RE_EXTENDS = re.compile(r"^\s*extends\s+([\w\"./:]+)", re.M)
RE_SIGNAL = re.compile(r"^\s*signal\s+(\w+)", re.M)
RE_RES_LOAD = re.compile(r"\b(?:preload|load)\(\s*\"(res://[^\"]+)\"")
RE_IDENT = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\b")
RE_EMIT = re.compile(r"(?:\b([A-Za-z_][\w.]*)\.)?\b(\w+)\.emit\(")
RE_EMIT_STR = re.compile(r"emit_signal\(\s*&?\"(\w+)\"")
RE_CONNECT = re.compile(r"(?:\b([A-Za-z_][\w.]*)\.)?\b(\w+)\.connect\(")
RE_CONNECT_STR = re.compile(r"\bconnect\(\s*&?\"(\w+)\"")
RE_TSCN_CONN = re.compile(r"^\[connection signal=\"(\w+)\"", re.M)
RE_AUTOLOAD = re.compile(r"^(\w+)=\"\*?(res://[^\"]+)\"", re.M)
RE_STRING_NAME = re.compile(r"&\"(\w+)\"")


def strip_comments_and_strings(src: str) -> tuple[str, str]:
    """Return (code without comments, code without comments and string contents).

    The first keeps string literals so preload paths and emit_signal("x") stay readable;
    the second blanks them so identifiers inside strings are not counted as references.
    """
    no_comments, no_strings = [], []
    for line in src.splitlines():
        keep, blank = [], []
        quote = None
        i = 0
        while i < len(line):
            c = line[i]
            if quote:
                keep.append(c)
                if c == "\\" and i + 1 < len(line):
                    keep.append(line[i + 1])
                    i += 2
                    continue
                if c == quote:
                    quote = None
                    blank.append(c)
            elif c in "\"'":
                quote = c
                keep.append(c)
                blank.append(c)
            elif c == "#":
                break
            else:
                keep.append(c)
                blank.append(c)
            i += 1
        no_comments.append("".join(keep))
        no_strings.append("".join(blank))
    return "\n".join(no_comments), "\n".join(no_strings)


def read_autoloads(project_file: Path) -> dict[str, str]:
    """Return {AutoloadName: res:// path} from project.godot."""
    if not project_file.exists():
        return {}
    text = project_file.read_text(encoding="utf-8")
    block = re.search(r"^\[autoload\]\s*$(.*?)(?=^\[|\Z)", text, re.M | re.S)
    if not block:
        return {}
    return {name: path for name, path in RE_AUTOLOAD.findall(block.group(1))}


def res_path(root: Path, path: Path) -> str:
    return "res://" + path.relative_to(root).as_posix()


def analyse(root: Path, src_dir: Path) -> dict:
    autoloads = read_autoloads(root / "project.godot")
    autoload_by_path = {p: n for n, p in autoloads.items()}

    files: dict[str, dict] = {}
    for gd in sorted(src_dir.rglob("*.gd")):
        rp = res_path(root, gd)
        raw = gd.read_text(encoding="utf-8")
        code, bare = strip_comments_and_strings(raw)
        cls = RE_CLASS_NAME.search(bare)
        ext = RE_EXTENDS.search(code)
        files[rp] = {
            "path": rp,
            "lines": raw.count("\n") + 1,
            "class_name": cls.group(1) if cls else None,
            "autoload": autoload_by_path.get(rp),
            "extends": ext.group(1).strip('"') if ext else None,
            "signals": sorted(set(RE_SIGNAL.findall(bare))),
            "_code": code,
            "_bare": bare,
        }

    class_to_file = {f["class_name"]: p for p, f in files.items() if f["class_name"]}
    known_names = set(autoloads) | set(class_to_file)

    # Signals: which file declares each name. A name declared in several files is ambiguous.
    declared_in: dict[str, list[str]] = defaultdict(list)
    for p, f in files.items():
        for s in f["signals"]:
            declared_in[s].append(p)

    def owner_of(signal: str, qualifier: str | None, here: str) -> str | None:
        """Best guess at the file that declares `signal` for a use in file `here`."""
        owners = declared_in.get(signal)
        if not owners:
            return None
        if qualifier:
            head = qualifier.split(".")[0]
            target = autoloads.get(head) or class_to_file.get(head)
            if target in owners:
                return target
        elif here in owners:
            return here
        return owners[0] if len(owners) == 1 else None

    emits: dict[tuple[str, str], set[str]] = defaultdict(set)
    connects: dict[tuple[str, str], set[str]] = defaultdict(set)
    # Indirect uses the scan cannot resolve to an emit or a connect: the signal passed as a
    # value (`_button(..., restart_pressed)`) or named as a StringName (`&"perfect_dodged"`).
    indirect: dict[tuple[str, str], set[str]] = defaultdict(set)

    for p, f in files.items():
        refs = set(RE_IDENT.findall(f["_bare"])) & known_names
        refs.discard(f["class_name"])
        refs.discard(f["autoload"])
        f["uses_autoloads"] = sorted(r for r in refs if r in autoloads)
        f["uses_classes"] = sorted(r for r in refs if r in class_to_file and r not in autoloads)
        f["loads"] = sorted({m for m in RE_RES_LOAD.findall(f["_code"]) if m.endswith(".gd")})

        for qual, sig in RE_EMIT.findall(f["_bare"]):
            owner = owner_of(sig, qual or None, p)
            if owner:
                emits[(owner, sig)].add(p)
        for sig in RE_EMIT_STR.findall(f["_code"]):
            owner = owner_of(sig, None, p)
            if owner:
                emits[(owner, sig)].add(p)
        for qual, sig in RE_CONNECT.findall(f["_bare"]):
            owner = owner_of(sig, qual or None, p)
            if owner:
                connects[(owner, sig)].add(p)
        for sig in RE_CONNECT_STR.findall(f["_code"]):
            owner = owner_of(sig, None, p)
            if owner:
                connects[(owner, sig)].add(p)
        for sig in RE_STRING_NAME.findall(f["_code"]):
            owner = owner_of(sig, None, p)
            if owner:
                indirect[(owner, sig)].add(p)
        for sig in f["signals"]:
            as_value = re.compile(r"(?<![.\w])" + sig + r"\b(?!\s*[.(:])")
            decl = re.compile(r"^\s*signal\s+" + sig + r"\b")
            if any(as_value.search(line) and not decl.match(line) for line in f["_bare"].splitlines()):
                indirect[(p, sig)].add(p)

    for tscn in sorted(src_dir.rglob("*.tscn")):
        rp = res_path(root, tscn)
        for sig in RE_TSCN_CONN.findall(tscn.read_text(encoding="utf-8")):
            owners = declared_in.get(sig)
            if owners and len(owners) == 1:
                connects[(owners[0], sig)].add(rp)

    # Fan-in: how many other files reference this file (by class_name, autoload name or load).
    fan_in: dict[str, set[str]] = defaultdict(set)
    for p, f in files.items():
        for name in f["uses_autoloads"]:
            fan_in[autoloads[name]].add(p)
        for name in f["uses_classes"]:
            fan_in[class_to_file[name]].add(p)
        for target in f["loads"]:
            if target in files and target != p:
                fan_in[target].add(p)

    for p, f in files.items():
        f["fan_out"] = len(set(f["uses_autoloads"]) | set(f["uses_classes"]) | set(f["loads"]))
        f["fan_in"] = len(fan_in.get(p, ()))
        del f["_code"], f["_bare"]

    signals = []
    for s, owners in sorted(declared_in.items()):
        for owner in owners:
            signals.append({
                "signal": s,
                "declared_in": owner,
                "ambiguous": len(owners) > 1,
                "emitted_in": sorted(emits.get((owner, s), ())),
                "connected_in": sorted(connects.get((owner, s), ())),
                "indirect_in": sorted(indirect.get((owner, s), ())),
            })

    graph = {n: files[p]["uses_autoloads"] for n, p in autoloads.items() if p in files}
    return {"autoloads": autoloads, "files": files, "signals": signals, "autoload_cycles": cycles(graph)}


def cycles(graph: dict[str, list[str]]) -> list[list[str]]:
    """Strongly connected components with more than one node (Tarjan), sorted."""
    index: dict[str, int] = {}
    low: dict[str, int] = {}
    stack: list[str] = []
    on_stack: set[str] = set()
    found: list[list[str]] = []

    def visit(v: str) -> None:
        index[v] = low[v] = len(index)
        stack.append(v)
        on_stack.add(v)
        for w in graph.get(v, []):
            if w not in index:
                visit(w)
                low[v] = min(low[v], low[w])
            elif w in on_stack:
                low[v] = min(low[v], index[w])
        if low[v] == index[v]:
            comp = []
            while True:
                w = stack.pop()
                on_stack.discard(w)
                comp.append(w)
                if w == v:
                    break
            if len(comp) > 1:
                found.append(sorted(comp))

    for v in sorted(graph):
        if v not in index:
            visit(v)
    return sorted(found)


def short(path: str) -> str:
    return path.removeprefix("res://src/")


def render_markdown(data: dict) -> str:
    files = data["files"]
    autoloads = data["autoloads"]
    signals = data["signals"]
    out: list[str] = []
    w = out.append

    total_lines = sum(f["lines"] for f in files.values())
    w("# Code Map\n")
    w("> Generated by `tools/code-map/code_map.py`. Do not edit by hand: re-run the script.")
    w("> Static text analysis of `src/` (comments and strings ignored), so treat counts as a")
    w("> guide, not a proof. Tests are not included.\n")
    w("## Summary\n")
    w("| Metric | Value |")
    w("|--------|-------|")
    w(f"| GDScript files | {len(files)} |")
    w(f"| Lines | {total_lines:,} |")
    w(f"| Autoloads | {len(autoloads)} |")
    w(f"| Files with `class_name` | {sum(1 for f in files.values() if f['class_name'])} |")
    w(f"| Signals declared | {len(signals)} |")
    w(f"| Files over {LARGE_FILE_LINES} lines | {sum(1 for f in files.values() if f['lines'] > LARGE_FILE_LINES)} |")
    w("")

    # Autoloads
    w("## Autoloads\n")
    w("Who uses each global singleton. High \"used by\" means a change there ripples widely;")
    w("autoload-to-autoload arrows are hidden coupling between globals.\n")
    w("| Autoload | File | Lines | Used by (files) | Uses autoloads |")
    w("|----------|------|------:|----------------:|----------------|")
    for name, path in autoloads.items():
        f = files.get(path)
        if not f:
            w(f"| {name} | `{path}` (outside src) | | | |")
            continue
        users = sum(1 for g in files.values() if name in g["uses_autoloads"])
        w(f"| {name} | `{short(path)}` | {f['lines']} | {users} | {', '.join(f['uses_autoloads']) or '—'} |")
    w("")
    w("```mermaid")
    w("graph LR")
    for name, path in autoloads.items():
        f = files.get(path)
        for dep in (f or {}).get("uses_autoloads", []):
            w(f"  {name} --> {dep}")
    w("```\n")
    w("### Cycles between autoloads\n")
    if data["autoload_cycles"]:
        w("Autoloads that depend on each other, directly or through others. Each group has to")
        w("be loaded, tested and reasoned about together; break a cycle with a signal or by")
        w("passing the dependency in.\n")
        for comp in data["autoload_cycles"]:
            w(f"- {' ↔ '.join(comp)}")
    else:
        w("None.")
    w("")

    # Large files
    w(f"## Large files (over {LARGE_FILE_LINES} lines)\n")
    w("Refactor candidates. Fan-out = autoloads, classes and scripts this file depends on;")
    w("fan-in = files that depend on it. A large file with high fan-in is risky to split;")
    w("one with high fan-out is doing too many jobs.\n")
    w("| File | Lines | Fan-out | Fan-in | Signals declared |")
    w("|------|------:|--------:|-------:|-----------------:|")
    for f in sorted(files.values(), key=lambda f: (-f["lines"], f["path"])):
        if f["lines"] > LARGE_FILE_LINES:
            w(f"| `{short(f['path'])}` | {f['lines']} | {f['fan_out']} | {f['fan_in']} | {len(f['signals'])} |")
    w("")

    # Coupling
    w(f"## Most depended-on files (top {TOP_N} by fan-in)\n")
    w("| File | Fan-in | Lines |")
    w("|------|-------:|------:|")
    for f in sorted(files.values(), key=lambda f: (-f["fan_in"], f["path"]))[:TOP_N]:
        w(f"| `{short(f['path'])}` | {f['fan_in']} | {f['lines']} |")
    w("")
    w(f"## Files with the most dependencies (top {TOP_N} by fan-out)\n")
    w("| File | Fan-out | Autoloads used | Lines |")
    w("|------|--------:|----------------|------:|")
    for f in sorted(files.values(), key=lambda f: (-f["fan_out"], f["path"]))[:TOP_N]:
        w(f"| `{short(f['path'])}` | {f['fan_out']} | {', '.join(f['uses_autoloads']) or '—'} | {f['lines']} |")
    w("")

    # Signals
    plain = [s for s in signals if not s["ambiguous"]]
    never_connected = [s for s in plain if not s["connected_in"] and not s["indirect_in"]]
    never_emitted = [s for s in plain if not s["emitted_in"] and not s["indirect_in"]]
    w("## Signals\n")
    w("Signals declared in `src/`, where they are emitted and where they are connected")
    w("(`.connect()` in scripts or `[connection]` in `.tscn`). A signal name declared in more")
    w("than one file is marked ambiguous and left out of the checks below. A signal passed as a")
    w("value or named as `&\"name\"` counts as an indirect use and is also left out.\n")
    w(f"### Never connected in src ({len(never_connected)})\n")
    w("Dead signals, or listened to only by tests or through a variable the scan cannot follow.\n")
    for s in never_connected:
        w(f"- `{s['signal']}` in `{short(s['declared_in'])}`")
    w("")
    w(f"### Never emitted ({len(never_emitted)})\n")
    w("Declared but no `.emit()` found: dead, or emitted through a path the scan cannot follow.\n")
    for s in never_emitted:
        w(f"- `{s['signal']}` in `{short(s['declared_in'])}`")
    w("")
    w("<details><summary>All signals</summary>\n")
    w("| Signal | Declared in | Emitted in | Connected in | Indirect use in |")
    w("|--------|-------------|------------|--------------|-----------------|")
    for s in signals:
        flag = " (ambiguous)" if s["ambiguous"] else ""
        em = ", ".join(short(p) for p in s["emitted_in"]) or "—"
        co = ", ".join(short(p) for p in s["connected_in"]) or "—"
        ind = ", ".join(short(p) for p in s["indirect_in"]) or "—"
        w(f"| `{s['signal']}`{flag} | `{short(s['declared_in'])}` | {em} | {co} | {ind} |")
    w("\n</details>\n")

    # Per-file dependency list
    w("## Per-file dependencies\n")
    w("<details><summary>Every file</summary>\n")
    w("| File | Lines | Autoloads | Classes | Loads |")
    w("|------|------:|-----------|---------|-------|")
    for f in sorted(files.values(), key=lambda f: f["path"]):
        w(
            f"| `{short(f['path'])}` | {f['lines']} | {', '.join(f['uses_autoloads']) or '—'} | "
            f"{', '.join(f['uses_classes']) or '—'} | {', '.join(short(p) for p in f['loads']) or '—'} |"
        )
    w("\n</details>")
    return "\n".join(out) + "\n"


def main(argv: list[str] | None = None) -> int:
    root_default = Path(__file__).resolve().parents[2]
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", type=Path, default=root_default, help="Godot project root")
    ap.add_argument("--src", default="src", help="source folder under the root")
    ap.add_argument("--out", type=Path, default=None, help="Markdown output path")
    ap.add_argument("--json", type=Path, default=None, help="also write raw data as JSON")
    ap.add_argument("--stdout", action="store_true", help="print the report, write no file")
    args = ap.parse_args(argv)

    root = args.root.resolve()
    data = analyse(root, root / args.src)
    report = render_markdown(data)

    if args.stdout:
        sys.stdout.write(report)
    else:
        out = args.out or root / "docs" / "architecture" / "code-map.md"
        out.write_text(report, encoding="utf-8")
        print(f"wrote {out.relative_to(root) if out.is_relative_to(root) else out}")
    if args.json:
        args.json.write_text(json.dumps(data, indent=2, sort_keys=True), encoding="utf-8")
        print(f"wrote {args.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
