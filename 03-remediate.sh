#!/usr/bin/env bash
# 03-remediate.sh
# Deletes the classic branch protection rule on main and installs a
# repository Ruleset that enforces the same 1-review rule but with an
# EMPTY bypass_actors list. The structural change: admins no longer
# get a free pass.
#
# After this runs, ./03-attack-admin-ruleset.sh should be blocked.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=00-config.sh
source "$SCRIPT_DIR/00-config.sh"

banner "03 — Remediate: classic protection -> Ruleset with empty bypass"

safety_gate

note "removing classic branch protection on main"
gh_api_no_body DELETE "/repos/$OWNER/$REPO/branches/main/protection" "$TEST_ORG_GH_TOKEN" \
  || warn "classic protection was not set; continuing"

note "creating repository ruleset: 1 review, no bypass actors"
RULESET_BODY=$(jq -n '{
  name: "main-protection",
  target: "branch",
  enforcement: "active",
  conditions: { ref_name: { include: ["refs/heads/main"], exclude: [] } },
  rules: [
    {
      type: "pull_request",
      parameters: {
        required_approving_review_count: 1,
        dismiss_stale_reviews_on_push: true,
        require_code_owner_review: false,
        require_last_push_approval: false,
        required_review_thread_resolution: false
      }
    }
  ],
  bypass_actors: []
}')

RULESET_RESPONSE=$(gh_api POST "/repos/$OWNER/$REPO/rulesets" "$TEST_ORG_GH_TOKEN" \
  --data "$RULESET_BODY")

RULESET_ID=$(echo "$RULESET_RESPONSE" | jq -r '.id // empty')
[[ -n "$RULESET_ID" ]] || { echo "$RULESET_RESPONSE" | pp_json; die "could not create ruleset"; }

ok "ruleset $RULESET_ID installed for refs/heads/main"
echo "$RULESET_RESPONSE" | pp_json
echo ""
note "verify there are no bypass actors:"
gh_api GET "/repos/$OWNER/$REPO/rulesets/$RULESET_ID" "$TEST_ORG_GH_TOKEN" \
  | jq '.bypass_actors' | pp_json
echo ""
ok "remediation complete"
echo "  next: ./03-attack-admin-ruleset.sh"
