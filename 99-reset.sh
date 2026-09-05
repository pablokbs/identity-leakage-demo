#!/usr/bin/env bash
# 99-reset.sh
# Deletes the test repository. Idempotent: a missing repo is not an
# error. Requires interactive confirmation by typing DELETE.
#
# Between takes the recommended workflow is:
#   ./99-reset.sh && ./01-setup.sh
# so the next run starts from a clean world.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=00-config.sh
source "$SCRIPT_DIR/00-config.sh"

banner "99 — Reset: delete test repository"

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

note "next: ./01-setup.sh to recreate the world for another take"
