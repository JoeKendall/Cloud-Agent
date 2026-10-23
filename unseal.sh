#!/bin/bash
# Saves credentials that arrived in the first message, read on stdin, as files in
# ~/.agent-secrets/<name>, one per name=value line. They come in one of two blocks:
#   -----BEGIN CMS----- ... -----END CMS-----                  sealed (openssl CMS, PEM), opened
#                                                             with AGENT_UNSEAL_KEY (the key's
#                                                             PEM, base64 on one line)
#   -----BEGIN CREDENTIALS----- ... -----END CREDENTIALS----- plain name=value lines
# Prints the names it saved, never the values.
set -euo pipefail
umask 077
secrets="$HOME/.agent-secrets"
fail() { echo "NOT READY: $*" >&2; exit 1; }
input=$(cat)
mkdir -p "$secrets"

if grep -q -- '-----BEGIN CMS-----' <<< "$input"; then
  [ -n "${AGENT_UNSEAL_KEY:-}" ] || fail "AGENT_UNSEAL_KEY is not set in this environment."
  key="$secrets/.unseal-key.pem"
  trap 'rm -f "$key"' EXIT
  printf '%s' "$AGENT_UNSEAL_KEY" | openssl base64 -d -A > "$key"
  plain=$(sed -n '/-----BEGIN CMS-----/,/-----END CMS-----/p' <<< "$input" \
    | openssl cms -decrypt -inform PEM -inkey "$key" 2>/dev/null) \
    || fail "the sealed block would not open: it was copied wrongly, or it was sealed for a different key."
elif grep -q -- '-----BEGIN CREDENTIALS-----' <<< "$input"; then
  plain=$(sed -n '/-----BEGIN CREDENTIALS-----/,/-----END CREDENTIALS-----/{//!p;}' <<< "$input")
else
  fail "no sealed or credentials block found."
fi

saved=()
while IFS= read -r line; do
  line=${line%$'\r'}
  name=${line%%=*}
  [[ $line == *=* && $name =~ ^[a-z0-9-]+$ ]] || continue
  value=${line#*=}
  value=${value#"${value%%[![:space:]]*}"}; value=${value%"${value##*[![:space:]]}"}
  printf '%s' "$value" > "$secrets/$name"
  saved+=("$name")
done <<< "$plain"
[ ${#saved[@]} -gt 0 ] || fail "the block holds nothing to save."
echo "READY: saved ${saved[*]} in ~/.agent-secrets."
