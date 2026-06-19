#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: rename_current_branch.sh [--dry-run] [--remote <name>] [--allow-default-branch] <new-branch-name>

Renames the currently checked out Git branch locally and remotely.

Options:
  --dry-run                 Print the commands without changing anything
  --remote <name>           Remote to use. Defaults to upstream remote, origin, or the only configured remote
  --allow-default-branch    Allow renaming the remote default branch
  -h, --help                Show this help
USAGE
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

print_cmd() {
  printf '+'
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '\n'
}

run() {
  print_cmd "$@"
  if [[ "$dry_run" -eq 0 ]]; then
    "$@"
  fi
}

remote_branch_exists() {
  local branch_name="$1"
  git ls-remote --exit-code --heads "$remote" "$branch_name" >/dev/null 2>&1
}

dry_run=0
allow_default_branch=0
remote_arg=""
new_branch=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=1
      ;;
    --remote)
      shift
      [[ $# -gt 0 ]] || die "--remote requires a value"
      remote_arg="$1"
      ;;
    --allow-default-branch)
      allow_default_branch=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      [[ -z "$new_branch" ]] || die "Only one new branch name can be provided"
      new_branch="$1"
      ;;
  esac
  shift
done

while [[ $# -gt 0 ]]; do
  [[ -z "$new_branch" ]] || die "Only one new branch name can be provided"
  new_branch="$1"
  shift
done

[[ -n "$new_branch" ]] || die "New branch name is required"
[[ "$new_branch" != -* ]] || die "New branch name cannot start with '-'"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not inside a Git work tree"

old_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" || die "HEAD is detached; checkout a branch before renaming"

[[ "$old_branch" != "$new_branch" ]] || die "Current branch is already named '$new_branch'"

git check-ref-format --branch "$new_branch" >/dev/null || die "Invalid branch name: $new_branch"

if git show-ref --verify --quiet "refs/heads/$new_branch"; then
  die "Local branch already exists: $new_branch"
fi

tracked_remote="$(git config --get "branch.$old_branch.remote" || true)"
tracked_merge="$(git config --get "branch.$old_branch.merge" || true)"

if [[ -n "$remote_arg" ]]; then
  remote="$remote_arg"
elif [[ -n "$tracked_remote" && "$tracked_remote" != "." ]]; then
  remote="$tracked_remote"
elif git remote get-url origin >/dev/null 2>&1; then
  remote="origin"
else
  remote_count="$(git remote | sed '/^$/d' | wc -l | tr -d ' ')"
  if [[ "$remote_count" == "1" ]]; then
    remote="$(git remote)"
  else
    die "Unable to infer remote; pass --remote <name>"
  fi
fi

git remote get-url "$remote" >/dev/null 2>&1 || die "Remote does not exist: $remote"

old_remote_branch="$old_branch"
if [[ -n "$tracked_merge" && -z "$remote_arg" ]]; then
  old_remote_branch="${tracked_merge#refs/heads/}"
elif [[ -n "$tracked_merge" && "$tracked_remote" == "$remote" ]]; then
  old_remote_branch="${tracked_merge#refs/heads/}"
fi

if remote_branch_exists "$new_branch"; then
  die "Remote branch already exists: $remote/$new_branch"
fi

old_remote_exists=0
if remote_branch_exists "$old_remote_branch"; then
  old_remote_exists=1
fi

remote_default="$(git remote show "$remote" 2>/dev/null | sed -n 's/^[[:space:]]*HEAD branch: //p' | head -n 1 || true)"
if [[ -z "$remote_default" ]]; then
  local_remote_default="$(git symbolic-ref --quiet --short "refs/remotes/$remote/HEAD" 2>/dev/null || true)"
  remote_default="${local_remote_default#${remote}/}"
fi

if [[ "$allow_default_branch" -eq 0 && -n "$remote_default" && "$old_remote_branch" == "$remote_default" ]]; then
  die "Refusing to rename remote default branch '$remote/$old_remote_branch'. Re-run with --allow-default-branch only after explicit confirmation"
fi

printf 'Renaming current branch locally and remotely\n'
printf '  local:  %s -> %s\n' "$old_branch" "$new_branch"
printf '  remote: %s/%s -> %s/%s\n' "$remote" "$old_remote_branch" "$remote" "$new_branch"

run git push -u "$remote" "HEAD:refs/heads/$new_branch"
run git branch -m "$old_branch" "$new_branch"

if [[ "$old_remote_exists" -eq 1 && "$old_remote_branch" != "$new_branch" ]]; then
  run git push "$remote" --delete "$old_remote_branch"
else
  printf 'Old remote branch not found, skipping remote delete: %s/%s\n' "$remote" "$old_remote_branch"
fi

printf 'Done\n'
