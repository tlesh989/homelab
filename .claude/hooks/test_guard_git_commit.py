#!/usr/bin/env python3
"""Self-check for guard-git-commit.py: python3 .claude/hooks/test_guard_git_commit.py"""
import importlib.util
import os
import subprocess
import tempfile

spec = importlib.util.spec_from_file_location(
    "guard", os.path.join(os.path.dirname(__file__), "guard-git-commit.py"))
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

with tempfile.TemporaryDirectory() as tmp:
    main_repo, feat_repo = os.path.join(tmp, "on-main"), os.path.join(tmp, "on-feat")
    for repo, branch in ((main_repo, "main"), (feat_repo, "feature/x")):
        subprocess.run(["git", "init", "-q", "-b", branch, repo], check=True)

    cases = [
        (feat_repo, "git commit -m x", False),
        (main_repo, "git commit -m x", True),
        (feat_repo, f"cd {main_repo} && git commit -m x", True),
        (main_repo, f"cd {feat_repo} && git commit -am x && git push", False),
        (feat_repo, f"rtk git -C {main_repo} commit -m x", True),
        (main_repo, "GIT_EDITOR=true git commit --amend", True),
        (main_repo, "git status && echo 'git commit'", False),
        (feat_repo, "git push --no-verify", True),
    ]
    for cwd, cmd, blocked in cases:
        assert (guard.check(cmd, cwd) is not None) == blocked, (cwd, cmd)

print(f"ok: {len(cases)} cases")
