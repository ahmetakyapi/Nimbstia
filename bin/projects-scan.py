#!/usr/bin/python3
"""Scan git working copies directly under ~/Projects and stream NDJSON to stdout.

Usage: projects-scan.py [root [name ...]]   (names limit the scan to those folders, e.g. after a pull)

Phase 1 (cheap, ~1 s): one "base" line per repo (branch/sha, last commit, ahead/behind, mtime).
Phase 2 (slow, stats every tracked file): one "dirty" line per repo, most recently touched first.
Last line: {"type":"done", ...}. Read-only: only runs git with --no-optional-locks.
"""
import json
import os
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.abspath(os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/Projects"))
ONLY = set(sys.argv[2:])
GIT = "/usr/bin/git"
TIMEOUT = 30
OUT_LOCK = threading.Lock()
ENV = dict(os.environ, GIT_TERMINAL_PROMPT="0", LC_ALL="C")


def emit(obj):
    line = json.dumps(obj, ensure_ascii=False)
    with OUT_LOCK:
        sys.stdout.write(line + "\n")
        sys.stdout.flush()


def git(path, *args):
    try:
        r = subprocess.run(
            [GIT, "--no-optional-locks", "-c", "core.preloadindex=false", "-C", path] + list(args),
            capture_output=True, text=True, timeout=TIMEOUT, errors="replace", env=ENV,
        )
        return r.returncode, r.stdout
    except Exception:
        return 1, ""


def base(name):
    path = os.path.join(ROOT, name)
    dotgit = os.path.join(path, ".git")
    if not os.path.isdir(path) or not os.path.lexists(dotgit):
        return None
    p = {
        "name": name, "path": path, "worktree": os.path.isfile(dotgit),
        "branch": None, "sha": None, "ahead": None, "behind": None,
        "ct": None, "subject": None, "mtime": None,
    }
    try:
        p["mtime"] = int(os.stat(path).st_mtime)
    except OSError:
        pass
    rc, out = git(path, "log", "-1", "--format=%h%x1f%ct%x1f%s")
    if rc == 0 and out.count("\x1f") == 2:
        sha, ct, subj = out.rstrip("\n").split("\x1f", 2)
        p["sha"], p["subject"] = sha, subj
        try:
            p["ct"] = int(ct)
        except ValueError:
            pass
    rc, out = git(path, "symbolic-ref", "-q", "--short", "HEAD")
    if rc == 0:
        p["branch"] = out.strip() or None
        rc, out = git(path, "rev-list", "--left-right", "--count", "@{u}...HEAD")
        if rc == 0:
            try:
                behind, ahead = out.split()
                p["ahead"], p["behind"] = int(ahead), int(behind)
            except ValueError:
                pass
    emit({"type": "base", "p": p})
    return p


def dirty(p):
    rc, out = git(p["path"], "status", "--porcelain")
    n = len(out.splitlines()) if rc == 0 else None
    emit({"type": "dirty", "path": p["path"], "dirty": n})


def main():
    try:
        names = sorted(n for n in os.listdir(ROOT) if not n.startswith("."))
        if ONLY:
            names = [n for n in names if n in ONLY]
    except OSError:
        names = []
    with ThreadPoolExecutor(max_workers=10) as ex:
        found = [p for p in ex.map(base, names) if p]
    found.sort(key=lambda p: -(max(p["ct"] or 0, p["mtime"] or 0)))
    emit({"type": "phase", "count": len(found)})
    with ThreadPoolExecutor(max_workers=8) as ex:
        list(ex.map(dirty, found))
    emit({"type": "done", "scanned": int(time.time()), "count": len(found)})


main()
