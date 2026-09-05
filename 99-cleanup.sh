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

parse_common_args "$@"
set -- ${COMMON_ARGS[@]+"${COMMON_ARGS[@]}"}
[[ $# -eq 0 ]] || die_l "unexpected argument: $1" "argumento inesperado: $1"

banner "$(localized \
  "99 — Clean demo state (repository is preserved)" \
  "99 — Limpiar la demo (el repositorio se conserva)")"

safety_gate

section_l 1 "Close leftover pull requests" "Cerrar pull requests pendientes"
note_l \
  "Closing open pull requests on $OWNER/$REPO" \
  "Cerrando pull requests abiertos en $OWNER/$REPO"
close_open_prs "$OWNER" "$REPO" "$TEST_ORG_GH_TOKEN"
note_l \
  "Deleting transient demo branches" \
  "Eliminando ramas transitorias de la demo"
delete_demo_branches "$OWNER" "$REPO" "$TEST_ORG_GH_TOKEN"

section_l 2 "Remove demo protection rules" "Eliminar las reglas de protección de la demo"
note_l \
  "Removing classic branch protection from main" \
  "Eliminando branch protection clásica de main"
gh_api_no_body DELETE "/repos/$OWNER/$REPO/branches/main/protection" "$TEST_ORG_GH_TOKEN" \
  || warn_l \
    "classic protection was not set; continuing" \
    "la protección clásica no estaba configurada; continuando"

note_l "Deleting demo rulesets" "Eliminando rulesets de la demo"
delete_rulesets_by_name "$OWNER" "$REPO" "main-protection" "$TEST_ORG_GH_TOKEN"

echo ""
ok_l \
  "cleanup complete — the repository and collaborators were preserved" \
  "limpieza completa — el repositorio y los colaboradores fueron conservados"
show_link_l "$(repo_url "$OWNER" "$REPO")" \
  "Open the reusable repository" \
  "Abrir el repositorio reutilizable"
show_next_l "make setup"
