#!/bin/bash
# Opens a sealed block (openssl CMS, PEM) read on stdin with the private key in
# AGENT_UNSEAL_KEY (the key's PEM, base64 on one line), and saves each name=value line
# inside it as ~/.agent-secrets/<name>. Prints the names it saved, never the values.
set -euo pipefail
umask 077
secrets="$HOME/.agent-secrets"
fail() { echo "NOT READY: $*" >&2; exit 1; }
[ -n "${AGENT_UNSEAL_KEY:-}" ] || fail "AGENT_UNSEAL_KEY is not set in this environment."
mkdir -p "$secrets"
key="$secrets/.unseal-key.pem"
trap 'rm -f "$key"' EXIT
printf '%s' "$AGENT_UNSEAL_KEY" | openssl base64 -d -A > "$key"

plain=$(sed -n '/-----BEGIN CMS-----/,/-----END CMS-----/p' \
  | openssl cms -decrypt -inform PEM -inkey "$key" 2>/dev/null) \
  || fail "the sealed block would not open: it was copied wrongly, or it was sealed for a different key."

saved=()
while IFS= read -r line; do
  name=${line%%=*}
  [[ $line == *=* && $name =~ ^[a-z0-9-]+$ ]] || continue
  printf '%s' "${line#*=}" > "$secrets/$name"
  saved+=("$name")
done <<< "$plain"
[ ${#saved[@]} -gt 0 ] || fail "the sealed block opened but holds nothing to save."
echo "READY: saved ${saved[*]} in ~/.agent-secrets."
