#!/usr/bin/env python3
"""Development numbers for the Nimbstia hub and Repostia, printed as one JSON object.

- commits / lines added / lines deleted: your commits across every git repository directly under
  ~/Projects that are on a remote branch (refs/remotes, as of the last fetch). Local-only commits and
  commits a force-push removed do not count; a reverted commit and its revert both drop out. The same commit in several clones or worktrees is counted once. The top-level
  numbers are today's; `periods` has today / this week (from Monday) / this month, and `days` one entry
  per calendar day of the last HISTORY_DAYS days. Every commit of that range is also written to
  HISTORY_FILE for Repostia's day-by-day history (read on demand, too big for the hub payload).
- PRs: via the GitHub CLI (`gh`), if it is installed and logged in — PRs you opened today, your open
  PRs and the PRs waiting for your review.
- `--org NAME` limits both to one GitHub organisation: only repositories whose origin points at
  github.com/NAME count, and PR searches use `--owner NAME`.
Read-only; every git/gh call has a timeout so a slow network never blocks the hub.
"""
import concurrent.futures as cf
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.expanduser("~/Projects")
TIMEOUT = 20
# Commits before today hardly change, so they are cached and only today is re-read on every run.
CACHE_DIR = os.path.expanduser("~/Library/Caches/nimbstia")
PAST_MAX_AGE = 3600  # also bounds how long a commit removed by a force-push can linger in the past days
CACHE_VERSION = "remotes-3"
HISTORY_DAYS = 90
HISTORY_FILE = os.path.join(CACHE_DIR, "dev-stats-history.json")
REVERT_RE = re.compile(r"This reverts commit ([0-9a-f]{40})")


def run(args, cwd=None, timeout=TIMEOUT):
    try:
        r = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.stdout if r.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def authors():
    """Every identity that counts as 'me': global git name/email plus the GitHub noreply address."""
    names = set()
    for key in ("user.name", "user.email"):
        v = run(["git", "config", "--global", key])
        if v and v.strip():
            names.add(v.strip())
    return sorted(names)


def repo_commits(path, since, who, until=None):
    """sha -> (added, deleted, subject, commit time, repo path, sha this commit reverts or "").
    Only commits reachable from remote-tracking branches: what was pushed and is still there."""
    base = ["git", "--no-optional-locks", "-C", path, "log", "--remotes", "--no-merges", f"--since={since}"]
    if until:
        base.append(f"--until={until}")
    for a in who:
        base.append(f"--author={a}")
    reverts = {}
    for line in (run(base + ["--grep=This reverts commit", "--format=%H%x09%b%x1e"]) or "").split("\x1e"):
        sha, _, body = line.strip().partition("\t")
        m = REVERT_RE.search(body)
        if sha and m:
            reverts[sha] = m.group(1)
    out = run(base + ["--pretty=format:@%H%x09%ct%x09%s", "--shortstat"])
    commits = {}
    cur = None
    for line in (out or "").splitlines():
        line = line.strip()
        if line.startswith("@"):
            sha, _, rest = line[1:].partition("\t")
            ct, _, subject = rest.partition("\t")
            cur = sha
            commits[cur] = (0, 0, subject, int(ct or 0), path, reverts.get(cur, ""))
        elif cur and "changed" in line:
            ins = dels = 0
            for part in line.split(","):
                part = part.strip()
                if "insertion" in part:
                    ins = int(part.split()[0])
                elif "deletion" in part:
                    dels = int(part.split()[0])
            commits[cur] = (ins, dels) + commits[cur][2:]
    return commits


def origin_repo(path):
    """(owner, name) of the repository's GitHub origin remote, or (None, None)."""
    url = run(["git", "-C", path, "remote", "get-url", "origin"], timeout=5) or ""
    m = re.search(r"github\.com[:/]([^/]+)/([^/\s]+?)(?:\.git)?/?$", url.strip())
    return (m.group(1), m.group(2)) if m else (None, None)


def cached(name, since, until, max_age, org, who, nrepos, collect):
    """Commits in [since, until) from CACHE_DIR/dev-stats-<name>.json, re-read when stale or the range moved."""
    path = os.path.join(CACHE_DIR, f"dev-stats-{name}.json")
    key = "|".join([CACHE_VERSION, since, until, org or "", ",".join(who), str(nrepos)])
    try:
        with open(path) as f:
            c = json.load(f)
        if c.get("key") == key and dt.datetime.now().timestamp() - c.get("at", 0) < max_age:
            return {sha: tuple(v) for sha, v in c["commits"].items()}
    except (OSError, ValueError, KeyError, TypeError):
        pass
    found = collect(since, until)
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(path + ".tmp", "w") as f:
            json.dump({"key": key, "at": int(dt.datetime.now().timestamp()), "commits": found}, f)
        os.replace(path + ".tmp", path)
    except OSError:
        pass
    return found


def period_starts():
    """Local midnight of today, this Monday and the first of this month."""
    today = dt.datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    return {"day": today, "week": today - dt.timedelta(days=today.weekday()), "month": today.replace(day=1)}


def commit_item(sha, ins, dels, subject, ct, path, web):
    owner, repo = web.get(path, (None, None))
    return {"sha": sha[:10], "subject": subject, "t": ct, "added": ins, "deleted": dels,
            "owner": owner or "", "repo": repo or os.path.basename(path),
            "url": f"https://github.com/{owner}/{repo}/commit/{sha}" if owner else ""}


def git_stats(org=None):
    starts = period_starts()
    first = min(list(starts.values()) + [starts["day"] - dt.timedelta(days=HISTORY_DAYS - 1)])
    since = first.isoformat()
    who = authors()
    repos, web = [], {}
    if os.path.isdir(ROOT):
        for name in os.listdir(ROOT):
            p = os.path.join(ROOT, name)
            if os.path.exists(os.path.join(p, ".git")):
                owner, repo = origin_repo(p)
                if org and (owner or "").lower() != org.lower():
                    continue
                repos.append(p)
                web[p] = (owner, repo)
    def collect(since_, until_=None):
        found = {}
        with cf.ThreadPoolExecutor(max_workers=6) as ex:  # gentle on the CPU; runs in the background
            for commits in ex.map(lambda p: repo_commits(p, since_, who, until_), repos):
                found.update(commits)  # same SHA from several clones is counted once
        return found

    today_iso = starts["day"].isoformat()
    # Older days change least: cached for a day; the last week for an hour; today is always re-read.
    recent = min(starts["week"], starts["day"] - dt.timedelta(days=7))
    past = {}
    for name, lo, hi, max_age in (("old", first, recent, 24 * 3600), ("recent", recent, starts["day"], PAST_MAX_AGE)):
        if lo < hi:
            past.update(cached(name, lo.isoformat(), hi.isoformat(), max_age, org, who, len(repos), collect))
    seen = dict(past)
    seen.update(collect(today_iso))
    # A revert and the commit it undoes cancel out: neither counts. A revert of older work drops too.
    undone = {v[5] for v in seen.values() if v[5]}
    seen = {sha: v for sha, v in seen.items() if not v[5] and sha not in undone}
    ordered = sorted(seen.items(), key=lambda kv: kv[1][3], reverse=True)
    periods = {}
    for key, start in starts.items():
        t0 = int(start.timestamp())
        part = [(sha, v) for sha, v in ordered if v[3] >= t0]
        periods[key] = {
            "commits": len(part),
            "added": sum(v[0] for _, v in part),
            "deleted": sum(v[1] for _, v in part),
            "repos": len({v[4] for _, v in part}),
            "list": [commit_item(sha, *v[:5], web) for sha, v in part[:30]],
        }
    # One bucket per local calendar day from the earliest period start through today.
    days, d = {}, first.date()
    while d <= starts["day"].date():
        days[d.isoformat()] = {"d": d.isoformat(), "commits": 0, "added": 0, "deleted": 0}
        d += dt.timedelta(days=1)
    for _, (ins, dels, _s, ct, *_rest) in ordered:
        b = days.get(dt.datetime.fromtimestamp(ct).date().isoformat())
        if b:
            b["commits"] += 1
            b["added"] += ins
            b["deleted"] += dels
    try:
        tmp = HISTORY_FILE + ".tmp"
        with open(tmp, "w") as f:
            json.dump({"at": int(dt.datetime.now().timestamp()), "since": first.date().isoformat(),
                       "commits": [commit_item(sha, *v[:5], web) for sha, v in ordered]}, f, ensure_ascii=False)
        os.replace(tmp, HISTORY_FILE)
    except OSError:
        pass
    today = periods["day"]
    return {
        "list": today["list"],
        "commits": today["commits"],
        "added": today["added"],
        "deleted": today["deleted"],
        "repos": len(repos),
        "periods": periods,
        "days": list(days.values()),
    }


def gh_json(args):
    gh = shutil.which("gh") or "/opt/homebrew/bin/gh"
    if not os.path.exists(gh):
        return None
    out = run([gh] + args, timeout=TIMEOUT)
    try:
        return json.loads(out) if out else None
    except ValueError:
        return None


def pr_item(p):
    repo = (p.get("repository") or {}).get("nameWithOwner") or (p.get("repository") or {}).get("name") or ""
    author = (p.get("author") or {}).get("login") or ""
    return {"title": p.get("title", ""), "url": p.get("url", ""), "repo": repo.split("/")[-1],
            "owner": repo.split("/")[0] if "/" in repo else "", "number": p.get("number"),
            "draft": bool(p.get("isDraft")), "author": author, "created": p.get("createdAt", "")}


def gh_stats(org=None):
    starts = period_starts()
    first = min(starts.values()).date().isoformat()
    scope = ["--owner", org] if org else []
    fields = "number,title,url,repository,isDraft,updatedAt,createdAt,author"
    # PRs opened since the earliest period start; split into today / week / month below.
    opened = gh_json(["search", "prs"] + scope + ["--author", "@me", "--created", f">={first}", "--json", fields,
                                                  "--limit", "100", "--sort", "created"])
    mine = gh_json(["search", "prs"] + scope + ["--author", "@me", "--state", "open", "--json", fields, "--limit", "30", "--sort", "updated"])
    review = gh_json(["search", "prs"] + scope + ["--review-requested", "@me", "--state", "open", "--json", fields, "--limit", "30", "--sort", "updated"])
    if opened is None and mine is None and review is None:
        return None
    def created_local(p):
        try:
            return dt.datetime.fromisoformat(p.get("createdAt", "").replace("Z", "+00:00")).astimezone().replace(tzinfo=None)
        except ValueError:
            return None
    by_period = {}
    for key, start in starts.items():
        by_period[key] = [pr_item(p) for p in (opened or []) if (created_local(p) or start) >= start]
    return {
        "openedToday": len(by_period["day"]),
        "opened": by_period["day"],
        "openedPeriods": by_period,
        "open": [pr_item(p) for p in (mine or [])],
        "review": [pr_item(p) for p in (review or [])],
    }


def main():
    org = None
    if "--org" in sys.argv[1:-1]:
        org = sys.argv[sys.argv.index("--org") + 1].strip() or None
    with cf.ThreadPoolExecutor(max_workers=2) as ex:
        g = ex.submit(git_stats, org)
        h = ex.submit(gh_stats, org)
        out = {"git": g.result(), "gh": h.result(), "org": org, "at": int(dt.datetime.now().timestamp())}
    print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
