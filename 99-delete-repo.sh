#!/usr/bin/env bash
# 99-delete-repo.sh
# Permanently deletes the test repository. Idempotent: a missing repo
# is not an error. Requires interactive confirmation by typing DELETE.
#
# For normal between-takes cleanup that KEEPS the repo, use 99-cleanup.sh.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=00-config.sh
source "$SCRIPT_DIR/00-config.sh"

banner "99 — Delete repository"

safety_gate

note "this will permanently delete $OWNER/$REPO"
echo ""
echo "    repository: $OWNER/$REPO"
echo "    branch protection rules: also gone"
echo "    rulesets: also gone"
echo "    pull requests: also gone"
echo ""
echo "  Are you sure? Type the word DELETE (uppercase) to continue."
echo "  Press Enter alone to abort."
echo ""

read -r -p "  > " CONFIRM
[[ "$CONFIRM" == "DELETE" ]] || { warn "aborted by user"; exit 0; }

delete_repo_safe "$OWNER" "$REPO" "$TEST_ORG_GH_TOKEN"
ok "$OWNER/$REPO deleted"

note "repo destroyed. To recreate: ./01-setup.sh"
