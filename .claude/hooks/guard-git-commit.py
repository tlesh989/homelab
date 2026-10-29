#!/usr/bin/env python3
"""PreToolUse guard for Bash: block `--no-verify` and commits to main/dev.

The branch is read from the repo each `git commit` targets — following `cd` and
`git -C` through `&&`/`;` chains — not from the shell's cwd.
"""
import json
import os
import re
import shlex
import subprocess
import sys

PROTECTED = ("dev", "main")


def resolve(base, path):
    return os.path.normpath(os.path.join(base, os.path.expanduser(path)))


def git_target(tokens, cwd):
    """Return (dir, subcommand) for a git invocation, honouring -C."""
    d, i = cwd, 1
    while i < len(tokens) and tokens[i].startswith("-"):
        if tokens[i] == "-C" and i + 1 < len(tokens):
            d = resolve(d, tokens[i + 1])
            i += 2
        elif tokens[i] in ("-c", "--git-dir", "--work-tree") and i + 1 < len(tokens):
            i += 2
        else:
            i += 1
    return d, tokens[i] if i < len(tokens) else ""


def check(cmd, cwd):
    """Return a block message, or None to allow."""
    d = cwd
    # ponytail: splits on shell separators naively; quoted `&&`/`;` or commits
    # inside `bash -c '...'` aren't followed. Fine for how agents call git.
    for seg in re.split(r"&&|\|\||;|\||\n", cmd):
        try:
            tokens = shlex.split(seg)
        except ValueError:
            continue
        # Drop `VAR=value` env prefixes and the `rtk` / `rtk proxy` wrapper.
        while tokens and ("=" in tokens[0] or tokens[0] == "rtk"
                          or (tokens[0] == "proxy" and seg.lstrip().startswith("rtk"))):
            tokens = tokens[1:]
        if not tokens:
            continue
        if tokens[0] == "cd":
            d = resolve(d, tokens[1]) if len(tokens) > 1 else os.path.expanduser("~")
        elif tokens[0] == "git":
            if "--no-verify" in tokens:
                return ("BLOCKED: --no-verify bypasses pre-commit hooks and is never allowed. "
                        "Fix the hook failures instead.")
            target, sub = git_target(tokens, d)
            if sub != "commit":
                continue
            # symbolic-ref (not rev-parse) also names the branch in a repo with no commits yet.
            r = subprocess.run(["git", "-C", target, "symbolic-ref", "--short", "-q", "HEAD"],
                               capture_output=True, text=True)
            branch = r.stdout.strip()
            if branch in PROTECTED:
                return f"BLOCKED: direct commits to {branch} in {target} are not allowed. Use a feature/* branch."
    return None


if __name__ == "__main__":
    params = json.load(sys.stdin)
    msg = check(params.get("tool_input", {}).get("command", ""), params.get("cwd") or os.getcwd())
    if msg:
        print(msg, file=sys.stderr)  # exit 2 shows stderr, not stdout, to Claude
        sys.exit(2)
