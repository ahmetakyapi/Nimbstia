#!/usr/bin/env python3
"""Today's development numbers for the Nimbstia hub, printed as one JSON object.

- commits / lines added / lines deleted: today's commits by you across every git repository directly
  under ~/Projects (all branches). The same commit in several clones or worktrees is counted once.
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


def repo_commits(path, since, who):
    args = ["git", "--no-optional-locks", "-C", path, "log", "--all", "--no-merges", f"--since={since}",
            "--pretty=format:@%H%x09%ct%x09%s", "--shortstat"]
    for a in who:
        args.append(f"--author={a}")
    out = run(args)
    commits = {}
    cur = None
    for line in (out or "").splitlines():
        line = line.strip()
        if line.startswith("@"):
            sha, _, rest = line[1:].partition("\t")
            ct, _, subject = rest.partition("\t")
            cur = sha
            commits[cur] = (0, 0, subject, int(ct or 0), path)
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


def git_stats(org=None):
    since = dt.datetime.now().replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
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
    seen = {}
    with cf.ThreadPoolExecutor(max_workers=6) as ex:  # gentle on the CPU; runs in the background
        for commits in ex.map(lambda p: repo_commits(p, since, who), repos):
            seen.update(commits)  # same SHA from several clones is counted once
    latest = sorted(seen.items(), key=lambda kv: kv[1][3], reverse=True)[:30]
    items = []
    for sha, (ins, dels, subject, ct, path) in latest:
        owner, repo = web.get(path, (None, None))
        items.append({"sha": sha[:10], "subject": subject, "t": ct, "added": ins, "deleted": dels,
                      "owner": owner or "", "repo": repo or os.path.basename(path),
                      "url": f"https://github.com/{owner}/{repo}/commit/{sha}" if owner else ""})
    return {
        "list": items,
        "commits": len(seen),
        "added": sum(v[0] for v in seen.values()),
        "deleted": sum(v[1] for v in seen.values()),
        "repos": len(repos),
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
    today = dt.date.today().isoformat()
    scope = ["--owner", org] if org else []
    fields = "number,title,url,repository,isDraft,updatedAt,createdAt,author"
    opened = gh_json(["search", "prs"] + scope + ["--author", "@me", "--created", f">={today}", "--json", fields, "--limit", "50"])
    mine = gh_json(["search", "prs"] + scope + ["--author", "@me", "--state", "open", "--json", fields, "--limit", "30", "--sort", "updated"])
    review = gh_json(["search", "prs"] + scope + ["--review-requested", "@me", "--state", "open", "--json", fields, "--limit", "30", "--sort", "updated"])
    if opened is None and mine is None and review is None:
        return None
    return {
        "openedToday": len(opened or []),
        "opened": [pr_item(p) for p in (opened or [])],
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
