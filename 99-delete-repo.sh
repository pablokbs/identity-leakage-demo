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

parse_common_args "$@"
set -- ${COMMON_ARGS[@]+"${COMMON_ARGS[@]}"}
[[ $# -eq 0 ]] || die_l "unexpected argument: $1" "argumento inesperado: $1"

banner "$(localized "99 — Permanently delete repository" "99 — Eliminar permanentemente el repositorio")"

safety_gate

note_l \
  "This will permanently delete $OWNER/$REPO" \
  "Esto eliminará permanentemente $OWNER/$REPO"
echo ""
if [[ "$DEMO_LANG" == "es" ]]; then
  echo "    repositorio: $OWNER/$REPO"
  echo "    branch protection: también será eliminada"
  echo "    rulesets: también serán eliminados"
  echo "    pull requests: también serán eliminados"
else
  echo "    repository: $OWNER/$REPO"
  echo "    branch protection: also deleted"
  echo "    rulesets: also deleted"
  echo "    pull requests: also deleted"
fi
echo ""
say_l \
  "  Are you sure? Type DELETE (uppercase) to continue." \
  "  ¿Estás seguro? Escribí DELETE en mayúsculas para continuar."
say_l \
  "  Press Enter alone to abort." \
  "  Presioná solamente Enter para cancelar."
echo ""

read -r -p "  > " CONFIRM
[[ "$CONFIRM" == "DELETE" ]] || { warn_l "aborted by user" "cancelado por el usuario"; exit 0; }

delete_repo_safe "$OWNER" "$REPO" "$TEST_ORG_GH_TOKEN"
ok_l "$OWNER/$REPO deleted" "$OWNER/$REPO eliminado"

note_l \
  "Repository destroyed. Recreate and initialize it manually before setup." \
  "Repositorio eliminado. Crealo e inicializalo manualmente antes del setup."
