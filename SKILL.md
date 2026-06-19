---
name: rename-branch
description: Rename the currently checked out Git branch to a requested new branch name both locally and on its remote. Use when the user asks to rename the current branch, selected branch, checked-out branch, or active branch locally and remotely, including updating upstream tracking and deleting the old remote branch after the new remote branch is pushed.
---

# Rename Branch

## Workflow

Use `scripts/rename_current_branch.sh` for the actual rename whenever possible. It handles the fragile ordering and guardrails:

1. Verify the workspace is a Git repository and HEAD is attached to a branch
2. Validate the requested new branch name with Git
3. Infer the remote from the current branch upstream, then `origin`, then a single configured remote
4. Refuse the rename if the target local branch or target remote branch already exists
5. Refuse remote default branch renames unless the user explicitly confirms that risk
6. Push the current HEAD to the new remote branch and set upstream tracking
7. Rename the local branch
8. Delete the old remote branch only after the new remote branch push succeeds

## Commands

From the target repository root or any path inside it:

```bash
/path/to/rename-branch/scripts/rename_current_branch.sh new-branch-name
```

Pass a remote when the repository has multiple remotes or the requested remote is not the upstream remote:

```bash
/path/to/rename-branch/scripts/rename_current_branch.sh --remote origin new-branch-name
```

Preview the commands without changing branches:

```bash
/path/to/rename-branch/scripts/rename_current_branch.sh --dry-run new-branch-name
```

If the current branch is the remote default branch, ask the user for explicit confirmation before using:

```bash
/path/to/rename-branch/scripts/rename_current_branch.sh --allow-default-branch new-branch-name
```

## Agent Guidance

Before running the script, state the current branch, target branch name, and remote that will be used. If the user did not provide a new name, ask for it.

Prefer a dry run first when the repository has multiple remotes, unclear upstream tracking, or when the current branch name is `main`, `master`, `trunk`, `develop`, or a release branch.

Do not manually delete the old remote branch before confirming the new remote branch was pushed successfully. Git has no atomic remote rename operation, so the safe sequence is push new first, then delete old.

After the script completes, verify with:

```bash
git branch --show-current
git status --short --branch
git ls-remote --heads <remote> <old-branch> <new-branch>
```
