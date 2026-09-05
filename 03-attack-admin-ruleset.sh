#!/usr/bin/env bash
# 03-attack-admin-ruleset.sh
# Same attack as 02-attack-admin.sh, but AFTER ./03-remediate.sh has
# installed the Ruleset with an empty bypass_actors list.
#
# This time the Admin token SHOULD fail. The structural change: the
# Ruleset does not let Admins bypass the 1-review rule, so the merge
# returns HTTP 405 just like the Writer did earlier.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=00-config.sh
source "$SCRIPT_DIR/00-config.sh"

banner "03 — Re-attack with the ADMIN token, now under Rulesets"

safety_gate

# Resolve the PR to attack.
if [[ $# -ge 1 ]]; then
  PR_NUMBER="$1"
else
  PR_NUMBER=$(gh_api GET "/repos/$OWNER/$REPO/pulls?state=open" "$TEST_ORG_GH_TOKEN" \
    | jq -r '[.[] | select(.head.ref | startswith("demo/"))][0].number // empty')
  [[ -n "$PR_NUMBER" ]] || die "no open demo PR found; run 01-setup.sh first"
fi

note "attacking PR #$PR_NUMBER with the SAME admin PAT as before"
note "the only difference: branch is now protected by a Ruleset"
note "ruleset bypass_actors list is empty, so Admins cannot bypass"

# Re-open the PR if the previous step closed it.
PR_STATE=$(gh_api GET "/repos/$OWNER/$REPO/pulls/$PR_NUMBER" "$TEST_ORG_GH_TOKEN" \
  | jq -r .state)
if [[ "$PR_STATE" != "open" ]]; then
  note "PR #$PR_NUMBER is $PR_STATE; reopening it"
  gh_api_no_body PATCH "/repos/$OWNER/$REPO/pulls/$PR_NUMBER" "$TEST_ORG_GH_TOKEN" \
    --data '{"state":"open"}' || die "could not reopen PR"
fi

RESPONSE_FILE=$(mktemp)
trap 'rm -f "$RESPONSE_FILE"' EXIT

HTTP_CODE=$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER/merge" \
  -d "$(jq -n '{merge_method:"squash"}')" || true)

echo ""
echo "  ${BOLD}HTTP status:${RESET} ${HTTP_CODE}"
echo ""
if [[ "$HTTP_CODE" == "200" ]]; then
  warn "merge SUCCEEDED under Ruleset — that should not happen"
  echo "    the ruleset bypass_actors list is empty; Admins must NOT bypass"
elif [[ "$HTTP_CODE" == "405" ]]; then
  ok "merge blocked (HTTP 405) — even Admin cannot bypass the Ruleset"
  note "structural fix holds:"
  echo "    • same PAT, same scopes, same user identity as before"
  echo "    • the ONLY change is the ruleset enforcing the review rule"
  echo "    • Admins are no longer special-cased"
elif [[ "$HTTP_CODE" == "401" ]]; then
  die "PAT was rejected (HTTP 401). Check the token."
else
  warn "unexpected status ${HTTP_CODE}"
  pp_json < "$RESPONSE_FILE"
fi
echo ""
echo "  full response body:"
echo ""
pp_json < "$RESPONSE_FILE" | sed 's/^/    /'
echo ""
