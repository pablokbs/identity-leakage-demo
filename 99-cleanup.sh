#!/usr/bin/env bash
# 99-cleanup.sh
# Resets the demo state WITHOUT deleting the repository.
# Closes open PRs, removes classic branch protection, and deletes the
# demo ruleset. Safe to run between takes so the repo can be reused.
#
# If you really want to destroy the repo, use 99-delete-repo.sh instead.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=00-config.sh
source "$SCRIPT_DIR/00-config.sh"

banner "99 — Cleanup demo state (repo is preserved)"

safety_gate

note "closing open pull requests on $OWNER/$REPO"
close_open_prs "$OWNER" "$REPO" "$TEST_ORG_GH_TOKEN"

note "removing classic branch protection on main"
gh_api_no_body DELETE "/repos/$OWNER/$REPO/branches/main/protection" "$TEST_ORG_GH_TOKEN" \
  || warn "classic protection was not set; continuing"

note "deleting demo rulesets"
delete_rulesets_by_name "$OWNER" "$REPO" "main-protection" "$TEST_ORG_GH_TOKEN"

echo ""
ok "cleanup complete — $OWNER/$REPO is ready for another demo take"
echo ""
echo "  next: ./01-setup.sh"
echo "        (or: make setup)"
