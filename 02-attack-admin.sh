#!/usr/bin/env bash
# 02-attack-admin.sh
# Uses the ADMIN user's PAT to attempt to merge the unapproved PR.
#
# Modern GitHub implements classic branch protection as repository rules,
# and admins can NO LONGER bypass them implicitly. The Admin identity can,
# however, MUTATE the protection rule itself. This script demonstrates that
# identity leakage: it removes the protection, merges, and restores it.
#
# Usage: ./02-attack-admin.sh [PR_NUMBER]
# If PR_NUMBER is omitted, the first open PR from the demo branch is used.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=00-config.sh
source "$SCRIPT_DIR/00-config.sh"

banner "02 — Attack with the ADMIN user's PAT"

safety_gate
require_bin gh

# Resolve the PR to attack.
if [[ $# -ge 1 ]]; then
  PR_NUMBER="$1"
else
  PR_NUMBER=$(gh_api GET "/repos/$OWNER/$REPO/pulls?state=open" "$TEST_ORG_GH_TOKEN" \
    | jq -r '[.[] | select(.head.ref | startswith("demo/"))][0].number // empty')
  [[ -n "$PR_NUMBER" ]] || die "no open demo PR found; run 01-setup.sh first"
fi

note "attacking PR #$PR_NUMBER using the PAT belonging to $ADMIN_HANDLE"
note "PAT scopes: repo (full classic control, including admin operations)"
note "no approvals on PR #$PR_NUMBER — branch protection should block it"

# First, show that a plain admin merge is rejected by modern GitHub.
note "attempting: gh pr merge --admin (admin bypass is no longer implicit)"
echo ""
if GH_TOKEN="***" gh pr merge "$PR_NUMBER" --admin --squash --repo "$OWNER/$REPO" 2>&1; then
  echo ""
  ok "MERGE SUCCEEDED — admin bypass still works in this org/repo"
  note "this is the classic identity-leakage scenario"
  echo ""
  echo "  next:    ./02-attack-writer.sh"
  echo "           (or: make attack-writer)"
  exit 0
fi

# If we are here, --admin was rejected. Show the real leakage:
# the admin identity can rewrite the rule.
echo ""
warn "admin bypass was rejected (expected on modern GitHub)"
note "leveraging the admin identity to MUTATE branch protection"
note "steps: remove protection -> merge -> restore protection"
echo ""

remove_classic_protection "$OWNER" "$REPO" "$ADMIN_TOKEN"

note "merging PR #$PR_NUMBER now that protection is gone"
echo ""
GH_TOKEN="***" gh pr merge "$PR_NUMBER" --squash --repo "$OWNER/$REPO" 2>&1
echo ""
ok "MERGE SUCCEEDED — the admin identity changed the rules to merge"

note "restoring classic branch protection so the demo can continue"
apply_classic_protection "$OWNER" "$REPO" "$ADMIN_TOKEN"

echo ""
note "this is the identity-leakage bug:"
echo "    • the PAT belonged to a repo Admin"
echo "    • branch protection required 1 review"
echo "    • no review was given"
echo "    • the Admin could not bypass the rule directly"
echo "    • BUT the Admin identity could DELETE the rule, merge, and restore it"
echo "    • the token's power came from the user's role, not from the scopes alone"
echo ""
echo "  next:    ./02-attack-writer.sh"
echo "           (or: make attack-writer)"
