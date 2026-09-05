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

# -------- Language and presentation mode --------

# English is the default so the scripts remain suitable for an international
# audience. Both settings can be supplied through environment variables or
# command-line flags. CLI flags take precedence.
DEMO_LANG="${DEMO_LANG:-en}"
DEMO_PRESENT="${DEMO_PRESENT:-0}"
COMMON_ARGS=()

parse_common_args() {
  COMMON_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --lang)
        [[ $# -ge 2 ]] || die "--lang requires 'en' or 'es'"
        DEMO_LANG="$2"
        shift 2
        ;;
      --lang=*)
        DEMO_LANG="${1#*=}"
        shift
        ;;
      --present)
        DEMO_PRESENT=1
        shift
        ;;
      --no-present)
        DEMO_PRESENT=0
        shift
        ;;
      --)
        shift
        while [[ $# -gt 0 ]]; do
          COMMON_ARGS+=("$1")
          shift
        done
        ;;
      *)
        COMMON_ARGS+=("$1")
        shift
        ;;
    esac
  done

  case "$DEMO_LANG" in
    en|es) ;;
    *) die "unsupported language '$DEMO_LANG'; use 'en' or 'es'" ;;
  esac

  case "$DEMO_PRESENT" in
    1|true|TRUE|yes|YES) DEMO_PRESENT=1 ;;
    0|false|FALSE|no|NO|"") DEMO_PRESENT=0 ;;
    *) die "DEMO_PRESENT must be 1 or 0" ;;
  esac
}

localized() {
  local english="$1" spanish="$2"
  if [[ "$DEMO_LANG" == "es" ]]; then
    printf '%s' "$spanish"
  else
    printf '%s' "$english"
  fi
}

say_l() {
  localized "$1" "$2"
  printf '\n'
}

note_l() {
  note "$(localized "$1" "$2")"
}

ok_l() {
  ok "$(localized "$1" "$2")"
}

warn_l() {
  warn "$(localized "$1" "$2")"
}

die_l() {
  die "$(localized "$1" "$2")"
}

section_l() {
  local number="$1" english="$2" spanish="$3"
  echo ""
  echo "${BOLD}[$number] $(localized "$english" "$spanish")${RESET}"
  echo ""
}

show_link_l() {
  local url="$1" english="$2" spanish="$3"
  echo ""
  printf '  %s:\n' "$(localized "$english" "$spanish")"
  printf '  %s\n' "$url"
}

present_pause_l() {
  [[ "$DEMO_PRESENT" == "1" ]] || return 0
  echo ""
  if [[ -t 0 ]]; then
    local prompt
    prompt=$(localized "Press Enter to continue..." "Presioná Enter para continuar...")
    read -r -p "  $prompt" _
  else
    warn_l \
      "presentation pause skipped because stdin is not interactive" \
      "se omitió la pausa porque la entrada no es interactiva"
  fi
  echo ""
}

repo_url() { printf 'https://github.com/%s/%s' "$1" "$2"; }
access_url() { printf 'https://github.com/%s/%s/settings/access' "$1" "$2"; }
branches_url() { printf 'https://github.com/%s/%s/settings/branches' "$1" "$2"; }
rules_settings_url() { printf 'https://github.com/%s/%s/settings/rules' "$1" "$2"; }
effective_rules_url() { printf 'https://github.com/%s/%s/rules?ref=refs%%2Fheads%%2Fmain' "$1" "$2"; }
pr_url() { printf 'https://github.com/%s/%s/pull/%s' "$1" "$2" "$3"; }
commits_url() { printf 'https://github.com/%s/%s/commits/main' "$1" "$2"; }

show_next_l() {
  local command="$1"
  echo ""
  printf '  %s: %s\n' "$(localized "next" "siguiente")" "$command"
}

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
    command -v "$bin" >/dev/null 2>&1 || die_l \
      "missing required binary: $bin" \
      "falta el binario requerido: $bin"
  done
}

validate_name() {
  local value="$1" label="$2"
  [[ "$value" =~ ^[A-Za-z0-9]([A-Za-z0-9._-]{0,99}[A-Za-z0-9])?$ ]] \
    || die_l \
      "$label '$value' is not a safe name (allowed: alphanumeric, '.', '_', '-')" \
      "$label '$value' no es un nombre seguro (permitidos: alfanuméricos, '.', '_', '-')"
}

# Safety gate. Returns 0 only if OWNER/REPO looks safe to operate on.
safety_gate() {
  require_bin curl jq

  [[ -n "${OWNER:-}" ]] || die_l \
    "OWNER is empty; configure 00-config.sh" \
    "OWNER está vacío; configurá 00-config.sh"
  [[ -n "${REPO:-}" ]] || die_l \
    "REPO is empty; configure 00-config.sh" \
    "REPO está vacío; configurá 00-config.sh"

  validate_name "$OWNER" "OWNER"
  validate_name "$REPO"  "REPO"

  for denied in "${DENY_OWNERS[@]+"${DENY_OWNERS[@]}"}"; do
    [[ -z "$denied" ]] && continue
    if [[ "$OWNER" == "$denied" ]]; then
      die_l \
        "OWNER '$OWNER' is in the safety denylist. Refusing to run." \
        "OWNER '$OWNER' está en la lista de seguridad. Se rechaza la ejecución."
    fi
  done

  local full="$OWNER/$REPO"
  for denied in "${DENY_REPOS[@]+"${DENY_REPOS[@]}"}"; do
    [[ -z "$denied" ]] && continue
    if [[ "$full" == "$denied" ]]; then
      die_l \
        "$full is in the safety denylist. Refusing to run." \
        "$full está en la lista de seguridad. Se rechaza la ejecución."
    fi
  done

  if [[ "$REPO" =~ $PROD_NAME_PATTERNS ]]; then
    die_l \
      "REPO '$REPO' looks like a production name. Refusing to run." \
      "REPO '$REPO' parece un nombre de producción. Se rechaza la ejecución."
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
      die_l \
        "$token_var is empty; configure it before running the demo" \
        "$token_var está vacío; configuralo antes de ejecutar la demo"
    fi
    if [[ ${#token} -lt 20 ]]; then
      die_l \
        "$token_var looks too short (length=${#token}) to be a GitHub token" \
        "$token_var parece demasiado corto (longitud=${#token}) para ser un token de GitHub"
    fi
  done

  ok_l "safety gate passed for $full" "control de seguridad aprobado para $full"
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
  warn_l "deleting repository $owner/$repo" "eliminando el repositorio $owner/$repo"
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
    warn_l "no rulesets named '$name' to delete" "no hay rulesets llamados '$name' para eliminar"
    return 0
  fi
  local id
  for id in $ids; do
    gh_api_no_body DELETE "/repos/$owner/$repo/rulesets/$id" "$token" || true
    ok_l "deleted ruleset $id ($name)" "ruleset $id ($name) eliminado"
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
    ok_l "closed PR #$pr_id" "PR #$pr_id cerrado"
  done
}

# Delete only transient branches created by this demo. Main and any branch
# outside the explicit demo/ namespace are never touched.
delete_demo_branches() {
  local owner="$1" repo="$2" token="$3"
  local branch
  for branch in $(gh_api GET "/repos/$owner/$repo/branches?per_page=100" "$token" 2>/dev/null \
                    | jq -r '.[].name | select(startswith("demo/"))' 2>/dev/null || true); do
    [[ -z "$branch" ]] && continue
    gh_api_no_body DELETE "/repos/$owner/$repo/git/refs/heads/$branch" "$token" || true
    ok_l "deleted transient branch $branch" "rama transitoria $branch eliminada"
  done
}

# Create a fresh demo branch, one trivial commit, and an unapproved PR using
# the GitHub API. Results are returned in DEMO_PR_NUMBER and DEMO_PR_BRANCH.
# This avoids putting credentials in git remote URLs or command arguments.
create_demo_pr() {
  local owner="$1" repo="$2" token="$3" branch_prefix="$4"
  local main_sha branch filename content ref_payload commit_payload pr_payload response

  require_bin base64
  main_sha=$(gh_api GET "/repos/$owner/$repo/git/ref/heads/main" "$token" \
    | jq -r '.object.sha // empty')
  [[ -n "$main_sha" ]] || die_l \
    "could not resolve the main branch; initialize the repository first" \
    "no se pudo encontrar la rama main; inicializá primero el repositorio"

  branch="${branch_prefix}-${RANDOM}-${RANDOM}"
  ref_payload=$(jq -n --arg ref "refs/heads/$branch" --arg sha "$main_sha" \
    '{ref:$ref, sha:$sha}')
  gh_api POST "/repos/$owner/$repo/git/refs" "$token" \
    --data "$ref_payload" >/dev/null

  filename="change-${RANDOM}-${RANDOM}.txt"
  content=$(printf 'trivially small change for the identity-leakage demo\n' \
    | base64 | tr -d '\r\n')
  commit_payload=$(jq -n \
    --arg message "Trivial change for identity-leakage demo" \
    --arg content "$content" \
    --arg branch "$branch" \
    '{message:$message, content:$content, branch:$branch}')
  gh_api PUT "/repos/$owner/$repo/contents/$filename" "$token" \
    --data "$commit_payload" >/dev/null

  pr_payload=$(jq -n \
    --arg title "Trivial change for identity-leakage demo" \
    --arg base "main" \
    --arg head "$branch" \
    --arg body "An intentionally unapproved PR for the identity-leakage demo." \
    '{title:$title, base:$base, head:$head, body:$body, draft:false}')
  response=$(gh_api POST "/repos/$owner/$repo/pulls" "$token" --data "$pr_payload")
  DEMO_PR_NUMBER=$(printf '%s' "$response" | jq -r '.number // empty')
  DEMO_PR_BRANCH="$branch"
  [[ -n "$DEMO_PR_NUMBER" ]] || die_l \
    "could not create the demo PR" \
    "no se pudo crear el PR de la demo"
}

# Apply the classic branch protection rule used throughout the demo:
# one required review with enforce_admins=false, so Admin identities are not
# subject to the rule when they update the protected branch.
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
  note_l \
    "Applying classic branch protection on main (one review)" \
    "Aplicando branch protection clásica sobre main (una aprobación)"
  gh_api PUT "/repos/$owner/$repo/branches/main/protection" "$token" \
    --data "$payload" >/dev/null
  ok_l "classic branch protection applied" "branch protection clásica aplicada"
}

# Remove classic branch protection from main.
remove_classic_protection() {
  local owner="$1" repo="$2" token="$3"
  note_l \
    "Removing classic branch protection from main" \
    "Eliminando branch protection clásica de main"
  gh_api_no_body DELETE "/repos/$owner/$repo/branches/main/protection" "$token" \
    || warn_l \
      "classic protection was not set; continuing" \
      "la protección clásica no estaba configurada; continuando"
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
  die_l \
    "repository $owner/$repo did not appear after 60 seconds" \
    "el repositorio $owner/$repo no apareció después de 60 segundos"
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
  die_l \
    "PR #$pr did not become open after 60 seconds" \
    "el PR #$pr no quedó abierto después de 60 segundos"
}
