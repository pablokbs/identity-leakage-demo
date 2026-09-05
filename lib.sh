#!/usr/bin/env bash
# Shared library for the Identity Leakage Demo scripts.
# Sourced by every script in this directory.

set -euo pipefail

# -------- Colors (large, readable from the back of a conference room) --------

if [[ -t 1 ]]; then
  RED=$'\e[1;31m'
  GREEN=$'\e[1;32m'
  YELLOW=$'\e[1;33m'
  BLUE=$'\e[1;34m'
  CYAN=$'\e[1;36m'
  BOLD=$'\e[1m'
  RESET=$'\e[0m'
else
  RED="" GREEN="" YELLOW="" BLUE="" CYAN="" BOLD="" RESET=""
fi

# -------- Denylist: never touch these from the demo scripts --------

# Add any repo or owner here to prevent the scripts from ever touching
# production resources. The check is a substring match against OWNER
# or OWNER/REPO.
DENY_OWNERS=(
  "pablokbs-peladonerdworks"
  "peladonerd"
)
DENY_REPOS=(
  # Add full "owner/repo" strings here to block specific repos.
)

# Production-like repo name patterns. Names matching these refuse to run
# even on a non-denylisted owner.
PROD_NAME_PATTERNS='^(prod|production|infra|infrastructure|pay|payment|payments|auth|authentication|users?|billing|users-service|core|app|api|backend|frontend|web|www|cdn|platform|security|moni(tor(ing)?)?)$'

# -------- Helpers --------

die() {
  echo "${RED}${BOLD}✘ $*${RESET}" >&2
  exit 1
}

ok() {
  echo "${GREEN}${BOLD}✔ $*${RESET}"
}

warn() {
  echo "${YELLOW}${BOLD}⚠ $*${RESET}" >&2
}

note() {
  echo "${CYAN}${BOLD}» $*${RESET}"
}

banner() {
  local title="$1"
  echo ""
  echo "${BOLD}════════════════════════════════════════════════════════════════════${RESET}"
  echo "${BOLD}  ${title}${RESET}"
  echo "${BOLD}════════════════════════════════════════════════════════════════════${RESET}"
  echo ""
}

require_bin() {
  for bin in "$@"; do
    command -v "$bin" >/dev/null 2>&1 || die "missing required binary: $bin"
  done
}

validate_name() {
  local value="$1" label="$2"
  [[ "$value" =~ ^[A-Za-z0-9]([A-Za-z0-9._-]{0,99}[A-Za-z0-9])?$ ]] \
    || die "$label '$value' is not a safe name (allowed: alphanumeric, '.', '_', '-')"
}

# Safety gate. Returns 0 only if OWNER/REPO looks safe to operate on.
safety_gate() {
  require_bin curl jq

  [[ -n "${OWNER:-}" ]] || die "OWNER is empty; copy 00-config.sh.example to 00-config.sh"
  [[ -n "${REPO:-}" ]]  || die "REPO is empty; copy 00-config.sh.example to 00-config.sh"

  validate_name "$OWNER" "OWNER"
  validate_name "$REPO"  "REPO"

  for denied in "${DENY_OWNERS[@]+"${DENY_OWNERS[@]}"}"; do
    [[ -z "$denied" ]] && continue
    if [[ "$OWNER" == "$denied" ]]; then
      die "OWNER '$OWNER' is in the safety denylist. Refusing to run."
    fi
  done

  local full="$OWNER/$REPO"
  for denied in "${DENY_REPOS[@]+"${DENY_REPOS[@]}"}"; do
    [[ -z "$denied" ]] && continue
    if [[ "$full" == "$denied" ]]; then
      die "$full is in the safety denylist. Refusing to run."
    fi
  done

  if [[ "$REPO" =~ $PROD_NAME_PATTERNS ]]; then
    die "REPO '$REPO' matches a production-like name. Refusing to run on this name."
  fi

  for token_var in TEST_ORG_GH_TOKEN ADMIN_TOKEN WRITER_TOKEN; do
    # Resolve each value explicitly. This is compatible with the Bash 3.2
    # shipped by macOS and remains safe under `set -u` when a value is unset.
    local token=""
    case "$token_var" in
      TEST_ORG_GH_TOKEN) token="${TEST_ORG_GH_TOKEN:-}" ;;
      ADMIN_TOKEN)       token="${ADMIN_TOKEN:-}" ;;
      WRITER_TOKEN)      token="${WRITER_TOKEN:-}" ;;
    esac
    if [[ -z "$token" ]]; then
      die "$token_var is empty; export it before running the demo (do not commit it)"
    fi
    if [[ ${#token} -lt 20 ]]; then
      die "$token_var looks too short (length=${#token}) to be a real GitHub token"
    fi
  done

  ok "safety gate passed for $full"
}

# Authenticated GitHub API call. Echoes the HTTP status on stderr for
# visibility, prints the body on stdout.
gh_api() {
  local method="$1" path="$2" token="$3"
  shift 3
  local url="https://api.github.com${path}"
  local status

  status=$(curl -sS -o /tmp/_gh_body.$$ -w '%{http_code}' \
    -X "$method" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Authorization: Bearer ${token}" \
    "$@" \
    "$url" || true)

  echo "${BLUE}${method} ${path}${RESET} ${YELLOW}->${RESET} ${status}" >&2
  cat /tmp/_gh_body.$$; rm -f /tmp/_gh_body.$$
  [[ "$status" -ge 200 && "$status" -lt 300 ]] || return 1
}

gh_api_no_body() {
  local method="$1" path="$2" token="$3"
  shift 3
  local url="https://api.github.com${path}"
  local status

  status=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X "$method" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Authorization: Bearer ${token}" \
    "$@" \
    "$url" || true)

  echo "${BLUE}${method} ${path}${RESET} ${YELLOW}->${RESET} ${status}" >&2
  [[ "$status" -ge 200 && "$status" -lt 300 ]] || return 1
}

# Pretty-print the body returned by gh_api when it's JSON.
pp_json() {
  jq -C . || cat
}

# Try to delete a repo idempotently. Used by 99-delete-repo.sh.
delete_repo_safe() {
  local owner="$1" repo="$2" token="$3"
  warn "deleting repository $owner/$repo"
  gh_api_no_body DELETE "/repos/$owner/$repo" "$token" || true
}

# Check whether a user is an active collaborator on the repo.
# Returns 0 if yes, 1 otherwise.
is_collaborator() {
  local owner="$1" repo="$2" handle="$3" token="$4"
  gh_api_no_body GET "/repos/$owner/$repo/collaborators/$handle" "$token" >/dev/null 2>&1
}

# Check whether a user has a pending invitation to the repo.
# Returns 0 if pending, 1 otherwise.
has_pending_invitation() {
  local owner="$1" repo="$2" handle="$3" token="$4"
  local count
  count=$(gh_api GET "/repos/$owner/$repo/invitations" "$token" 2>/dev/null \
    | jq --arg h "$handle" '[.[] | select(.login == $h and .status == "pending")] | length')
  [[ "${count:-0}" -gt 0 ]]
}

# Print pending invitations for the repo, one "login role" line each.
list_pending_invitations() {
  local owner="$1" repo="$2" token="$3"
  gh_api GET "/repos/$owner/$repo/invitations" "$token" 2>/dev/null \
    | jq -r '.[] | select(.status == "pending") | "  - \(.login) (\(.role))"' 2>/dev/null || true
}

# Delete rulesets whose name matches a given string.
delete_rulesets_by_name() {
  local owner="$1" repo="$2" name="$3" token="$4"
  local ids
  ids=$(gh_api GET "/repos/$owner/$repo/rulesets" "$token" 2>/dev/null \
    | jq --arg n "$name" -r '.[] | select(.name == $n) | .id' 2>/dev/null || true)
  if [[ -z "$ids" ]]; then
    warn "no rulesets named '$name' to delete"
    return 0
  fi
  local id
  for id in $ids; do
    gh_api_no_body DELETE "/repos/$owner/$repo/rulesets/$id" "$token" || true
    ok "deleted ruleset $id ($name)"
  done
}

# Close all open pull requests.
close_open_prs() {
  local owner="$1" repo="$2" token="$3"
  local pr_id
  for pr_id in $(gh_api GET "/repos/$owner/$repo/pulls?state=open&per_page=100" "$token" 2>/dev/null \
                  | jq -r '.[].number' 2>/dev/null || true); do
    [[ -z "$pr_id" ]] && continue
    gh_api_no_body PATCH "/repos/$owner/$repo/pulls/$pr_id" "$token" \
      --data '{"state":"closed"}' || true
    ok "closed PR #$pr_id"
  done
}

# Apply the classic branch protection rule used throughout the demo:
# 1 required review. Keep enforce_admins=false so the rule itself does not
# explicitly block admins from mutating it.
apply_classic_protection() {
  local owner="$1" repo="$2" token="$3"
  local payload
  payload=$(jq -n '{
    required_status_checks: null,
    enforce_admins: false,
    required_pull_request_reviews: {
      dismiss_stale_reviews: false,
      require_code_owner_reviews: false,
      required_approving_review_count: 1
    },
    restrictions: null
  }')
  note "applying classic branch protection on main (1 review)"
  gh_api PUT "/repos/$owner/$repo/branches/main/protection" "$token" \
    --data "$payload" >/dev/null
  ok "classic branch protection applied"
}

# Remove classic branch protection from main.
remove_classic_protection() {
  local owner="$1" repo="$2" token="$3"
  note "removing classic branch protection on main"
  gh_api_no_body DELETE "/repos/$owner/$repo/branches/main/protection" "$token" \
    || warn "classic protection was not set; continuing"
}

# Wait for a repo to exist. Returns 0 once 200 OK is observed.
wait_for_repo() {
  local owner="$1" repo="$2" token="$3"
  local attempt
  for attempt in {1..30}; do
    if gh_api_no_body GET "/repos/$owner/$repo" "$token"; then
      return 0
    fi
    sleep 2
  done
  die "repository $owner/$repo did not appear after 60 seconds"
}

# Wait for a PR to be open.
wait_for_pr() {
  local owner="$1" repo="$2" pr="$3" token="$4"
  local attempt
  for attempt in {1..30}; do
    local state
    state=$(gh_api GET "/repos/$owner/$repo/pulls/$pr" "$token" \
      | jq -r .state 2>/dev/null || echo "")
    [[ "$state" == "open" ]] && return 0
    sleep 2
  done
  die "PR #$pr did not become 'open' after 60 seconds"
}
