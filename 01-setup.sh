#!/usr/bin/env bash
# 01-setup.sh
# Creates the test repository, invites the two collaborators, configures
# classic branch protection on main (1 required review, admins may bypass
# by default), and opens an unapproved pull request.
#
# Idempotent: safe to run multiple times. If the repo already exists it
# is kept as-is. The PR is always closed and re-opened.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=00-config.sh
source "$SCRIPT_DIR/00-config.sh"

banner "01 - Setup repo, protection, unapproved PR"

safety_gate
require_bin git

# --- Step 1: create the repo if it does not exist ---

if gh_api_no_body GET "/repos/$OWNER/$REPO" "$TEST_ORG_GH_TOKEN"; then
  warn "$OWNER/$REPO already exists; will reuse it"
else
  note "creating repository $OWNER/$REPO"
  CREATE_PAYLOAD=$(jq -n \
    --arg name "$REPO" \
    --arg desc "Live demo for identity-leakage talk" \
    --arg homepage "" \
    '{name:$name, description:$desc, homepage:$homepage, private:false, auto_init:true}')
  gh_api_no_body POST "/user/repos" "$TEST_ORG_GH_TOKEN" \
    --data "$CREATE_PAYLOAD" \
    || die "failed to create repo $OWNER/$REPO"
fi

wait_for_repo "$OWNER" "$REPO" "$TEST_ORG_GH_TOKEN"

# --- Step 2: ensure collaborators exist and have accepted invitations ---

invite_user() {
  local handle="$1" role="$2"
  local status
  status=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X PUT \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Authorization: Bearer ${TEST_ORG_GH_TOKEN}" \
    "https://api.github.com/repos/$OWNER/$REPO/collaborators/$handle" \
    -d "$(jq -n --arg r "$role" '{permission:$r}')" || true)
  echo "${BLUE}invite $handle as $role${RESET} ${YELLOW}->${RESET} $status" >&2
}

ensure_collaborator() {
  local handle="$1" role="$2"
  if is_collaborator "$OWNER" "$REPO" "$handle" "$TEST_ORG_GH_TOKEN"; then
    ok "$handle is already an active collaborator ($role)"
    return 0
  fi
  if has_pending_invitation "$OWNER" "$REPO" "$handle" "$TEST_ORG_GH_TOKEN"; then
    warn "$handle has a pending invitation ($role) — ask them to accept before attacking"
    return 0
  fi
  note "inviting $handle as $role"
  invite_user "$handle" "$role"
}

note "checking collaborators on $OWNER/$REPO"
ensure_collaborator "$ADMIN_HANDLE" admin
ensure_collaborator "$WRITER_HANDLE" push

# --- Step 3: seed an initial commit on main so the repo is usable ---

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

if ! gh_api_no_body GET "/repos/$OWNER/$REPO/contents/README.md" "$TEST_ORG_GH_TOKEN"; then
  note "seeding README.md on main"
  cat > "$WORKDIR/README.md" <<README_EOF
# $REPO

Live demo for the Identity Leakage talk.

This repo intentionally has weak protections to demonstrate how a token
held by an Admin identity can bypass branch protection rules.
README_EOF
  cd "$WORKDIR"
  git init -q
  git checkout -q -b main
  git config user.name "demo-bot"
  git config user.email "demo@example.com"
  git add README.md
  git commit -q -m "Initial commit for identity-leakage demo"
  if ! git push -q "https://x-access-token:${TEST_ORG_GH_TOKEN}@github.com/${OWNER}/${REPO}.git" main 2>/dev/null; then
    warn "HTTPS push failed, skipping initial commit (repo may already have content)"
  fi
  cd - >/dev/null
fi

# --- Step 4: apply classic branch protection on main ---
# 1 required review. We leave bypass_actors empty to show the default
# state where nobody has an explicit bypass.

apply_classic_protection "$OWNER" "$REPO" "$TEST_ORG_GH_TOKEN"

# --- Step 5: close any leftover PR from a previous take, then open a new one ---

note "closing leftover PRs from previous takes"
for pr_id in $(gh_api GET "/repos/$OWNER/$REPO/pulls?state=open&per_page=100" "$TEST_ORG_GH_TOKEN" \
                | jq -r '.[].number'); do
  gh_api_no_body PATCH "/repos/$OWNER/$REPO/pulls/$pr_id" "$TEST_ORG_GH_TOKEN" \
    --data '{"state":"closed"}' || true
  ok "closed PR #$pr_id"
done

note "creating a feature branch and opening a new PR"
BRANCH="demo/unapproved-change-$RANDOM"

if ! gh_api_no_body GET "/repos/$OWNER/$REPO/git/ref/heads/$BRANCH" "$TEST_ORG_GH_TOKEN"; then
  cd "$WORKDIR"
  if git clone -q "https://x-access-token:${TEST_ORG_GH_TOKEN}@github.com/${OWNER}/${REPO}.git" cloned 2>/dev/null; then
    cd cloned
    git config user.name "demo-bot"
    git config user.email "demo@example.com"
    git checkout -q main
    git checkout -q -b "$BRANCH"
    printf 'trivially small change for the identity-leakage demo\n' > "change-${RANDOM}.txt"
    git add .
    git commit -q -m "Trivial change for identity-leakage demo"
    git push -q "https://x-access-token:${TEST_ORG_GH_TOKEN}@github.com/${OWNER}/${REPO}.git" "$BRANCH" || warn "push failed; PR creation may fail"
    cd ..
  else
    warn "could not clone repo; the PR step will be skipped"
  fi
fi

PR_PAYLOAD=$(jq -n \
  --arg t 'Trivial change for identity-leakage demo' \
  --arg b 'main' \
  --arg h "$BRANCH" \
  '{title:$t, base:$b, head:$h, body:"Demonstrates that an Admin token can bypass the 1-review rule.", draft:false}')
PR_NUMBER=$(gh_api POST "/repos/$OWNER/$REPO/pulls" "$TEST_ORG_GH_TOKEN" \
  --data "$PR_PAYLOAD" \
  | jq -r '.number // empty')

if [[ -z "$PR_NUMBER" ]]; then
  PR_NUMBER=$(gh_api GET "/repos/$OWNER/$REPO/pulls?state=open&head=$OWNER:$BRANCH" "$TEST_ORG_GH_TOKEN" \
    | jq -r '.[0].number // empty')
fi

[[ -n "$PR_NUMBER" ]] || die "could not create or find the demo PR"
ok "PR #$PR_NUMBER is open on branch $BRANCH"

wait_for_pr "$OWNER" "$REPO" "$PR_NUMBER" "$TEST_ORG_GH_TOKEN"

note "PR is intentionally NOT approved - that is the whole point"
echo ""

# Demo safety check: attacks will 404 if invitations are still pending.
PENDING=$(list_pending_invitations "$OWNER" "$REPO" "$TEST_ORG_GH_TOKEN")
if [[ -n "$PENDING" ]]; then
  warn "some invitations are still pending"
  echo "$PENDING"
  echo ""
  warn "do NOT run the attack scripts yet"
  echo "  1. Ask the invitees to accept their GitHub email invitations."
  echo "  2. Re-run: ./01-setup.sh"
  echo "  3. Only then continue with: ./02-attack-admin.sh"
  echo ""
  exit 0
fi

ok "setup complete"
echo "  repo:    $OWNER/$REPO"
echo "  branch:  $BRANCH"
echo "  PR:      #$PR_NUMBER"
echo ""
echo "  next:    ./02-attack-admin.sh"
echo "           (or: make attack-admin)"
