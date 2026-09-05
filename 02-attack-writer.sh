#!/usr/bin/env bash
# 02-attack-writer.sh
# Same attack as 02-attack-admin.sh, but using the WRITER user's
# fine-grained PAT. The PAT has IDENTICAL scopes (Contents=write,
# Pull requests=write, only this repo). The only difference is the
# underlying user identity, which has Write role — not Admin.
#
# The merge MUST fail with HTTP 405 because Write users cannot bypass
# branch protection.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=00-config.sh
source "$SCRIPT_DIR/00-config.sh"

banner "02 — Attack with the WRITER user's PAT"

safety_gate

# Resolve the PR to attack.
if [[ $# -ge 1 ]]; then
  PR_NUMBER="$1"
else
  PR_NUMBER=$(gh_api GET "/repos/$OWNER/$REPO/pulls?state=open" "$TEST_ORG_GH_TOKEN" \
    | jq -r '[.[] | select(.head.ref | startswith("demo/"))][0].number // empty')
  [[ -n "$PR_NUMBER" ]] || die "no open demo PR found; run 01-setup.sh first"
fi

note "attacking PR #$PR_NUMBER using a fine-grained PAT belonging to $WRITER_HANDLE"
note "PAT scopes: Contents=write, Pull requests=write (only this repo)"
note "SAME scopes as the admin PAT — only the user identity differs"
note "expected result: HTTP 405 (merge blocked by branch protection)"

RESPONSE_FILE=$(mktemp)
trap 'rm -f "$RESPONSE_FILE"' EXIT

HTTP_CODE=$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Authorization: Bearer ${WRITER_TOKEN}" \
  "https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER/merge" \
  -d "$(jq -n '{merge_method:"squash"}')" || true)

echo ""
echo "  ${BOLD}HTTP status:${RESET} ${HTTP_CODE}"
echo ""
if [[ "$HTTP_CODE" == "200" ]]; then
  warn "merge SUCCEEDED — protection did not block the Writer either"
  echo "    this is unexpected; the Writer should NOT be able to bypass"
elif [[ "$HTTP_CODE" == "405" ]]; then
  ok "merge blocked (HTTP 405) — Write identity correctly stopped"
  note "this proves the point:"
  echo "    • the PAT scopes are IDENTICAL to the admin PAT"
  echo "    • only the user identity changed"
  echo "    • the role of that identity is what controls the bypass"
elif [[ "$HTTP_CODE" == "401" ]]; then
  die "PAT was rejected (HTTP 401). Check the Writer token and its scopes."
else
  warn "unexpected status ${HTTP_CODE}"
  pp_json < "$RESPONSE_FILE"
fi
echo ""
echo "  full response body:"
echo ""
pp_json < "$RESPONSE_FILE" | sed 's/^/    /'
echo ""
