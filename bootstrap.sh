#!/bin/bash
# Clones (or refreshes) the source repository described in ~/.agent-secrets/source.json into
# ./agent, using the token in ~/.agent-secrets/source-token, then runs the source's own
# setup-session.sh, if one sits next to its start document.
# Prints READY and the start document, or NOT READY and why.
set -uo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
dir="$root/agent"
secrets="$HOME/.agent-secrets"
fail() { echo "NOT READY: $*" >&2; exit 1; }

# A link and token kept in the environment's variables stand in for pasting them.
if [ -n "${AGENT_START_LINK:-}" ] && [ -n "${AGENT_SOURCE_TOKEN:-}" ]; then
  mkdir -p "$secrets" && chmod 700 "$secrets"
  python3 "$root/parse-link.py" "$AGENT_START_LINK" > "$secrets/source.json" || fail "AGENT_START_LINK is not a link this launcher understands"
  printf '%s' "$AGENT_SOURCE_TOKEN" > "$secrets/source-token"
  chmod 600 "$secrets"/*
fi

[ -s "$secrets/source.json" ] || fail "no source saved yet (see CLAUDE.md, step 2)"
[ -s "$secrets/source-token" ] || fail "no access token saved yet (see CLAUDE.md, step 2)"
read -r url branch entry < <(python3 -c "
import json; s = json.load(open('$secrets/source.json'))
print(s['url'], s.get('branch') or '-', s.get('entry') or 'README.md')") || fail "source.json is unreadable"
auth="AUTHORIZATION: basic $(printf ':%s' "$(cat "$secrets/source-token")" | base64 | tr -d '\n')"

branch_args=(); [ "$branch" != "-" ] && branch_args=(--branch "$branch")
if [ -d "$dir/.git" ]; then
  [ "$branch" = "-" ] && branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD)
  git -C "$dir" -c http.extraheader="$auth" fetch -q origin "$branch" \
    || fail "could not refresh branch $branch: the token was rejected, or it cannot read this repository"
  # The session may have commits of its own here, so bring the remote in rather than
  # resetting to it.
  if [ "$(git -C "$dir" rev-parse --abbrev-ref HEAD)" = "$branch" ]; then
    git -C "$dir" rebase -q --autostash FETCH_HEAD \
      || { git -C "$dir" rebase --abort; fail "agent/ has local changes that clash with branch $branch; commit or resolve them, then run this again"; }
  else
    [ -z "$(git -C "$dir" status --porcelain)" ] || fail "agent/ has uncommitted changes; commit them before switching to branch $branch"
    git -C "$dir" checkout -q -B "$branch" FETCH_HEAD
  fi
else
  git -c http.extraheader="$auth" clone -q --depth 50 ${branch_args[@]+"${branch_args[@]}"} "$url" "$dir" \
    || fail "could not clone the repository: the token was rejected, it cannot read this repository, or the branch does not exist"
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD)
fi
git -C "$dir" config user.name "Cloud Agent"
git -C "$dir" config user.email "cloud-agent@noreply.invalid"
[ -f "$dir/$entry" ] || fail "the start document $entry is not in the repository on branch $branch"

entry_dir="$(dirname "$dir/$entry")"
if [ -x "$entry_dir/setup-session.sh" ]; then
  log="$HOME/.agent-setup.log"
  if "$entry_dir/setup-session.sh" > "$log" 2>&1; then
    cat "$log"
  else
    rc=$?
    echo "--- last lines of $log:" >&2; tail -n 25 "$log" >&2
    fail "the repository's setup-session.sh failed (exit $rc); its full output is in $log"
  fi
fi
echo "READY: agent/ on $branch @ $(git -C "$dir" rev-parse --short HEAD). Start document: agent/$entry"
