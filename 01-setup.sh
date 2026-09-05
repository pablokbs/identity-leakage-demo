#!/usr/bin/env bash
# Prepare the reusable repository for one demo take.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=00-config.sh
source "$SCRIPT_DIR/00-config.sh"

parse_common_args "$@"
set -- ${COMMON_ARGS[@]+"${COMMON_ARGS[@]}"}
[[ $# -eq 0 ]] || die_l \
  "unexpected argument: $1" \
  "argumento inesperado: $1"

banner "$(localized \
  "01 — Prepare classic protection and an unapproved PR" \
  "01 — Preparar protección clásica y un PR sin aprobación")"

safety_gate

section_l 1 "Verify the reusable demo repository" "Verificar el repositorio reutilizable"
note_l \
  "The repository and collaborators are one-time prerequisites; this script never creates or deletes them." \
  "El repositorio y los colaboradores se preparan una sola vez; este script nunca los crea ni los elimina."
gh_api_no_body GET "/repos/$OWNER/$REPO" "$TEST_ORG_GH_TOKEN" \
  || die_l \
    "repository $OWNER/$REPO does not exist; create and initialize it before the demo" \
    "el repositorio $OWNER/$REPO no existe; crealo e inicializalo antes de la demo"
ok_l "reusing repository $OWNER/$REPO" "reutilizando el repositorio $OWNER/$REPO"

ensure_collaborator() {
  local handle="$1" role="$2"
  if is_collaborator "$OWNER" "$REPO" "$handle" "$TEST_ORG_GH_TOKEN"; then
    ok_l "$handle is an active collaborator ($role)" "$handle es un colaborador activo ($role)"
    return 0
  fi
  if has_pending_invitation "$OWNER" "$REPO" "$handle" "$TEST_ORG_GH_TOKEN"; then
    die_l \
      "$handle still has a pending invitation ($role); accept it before the demo" \
      "$handle todavía tiene una invitación pendiente ($role); aceptala antes de la demo"
  fi
  die_l \
    "$handle is not an active collaborator with the expected $role role" \
    "$handle no es un colaborador activo con el rol esperado $role"
}

section_l 2 "Verify the two identities" "Verificar las dos identidades"
say_l \
  "The Admin and Writer accounts must already have accepted access to the repository." \
  "Las cuentas Admin y Writer ya deben haber aceptado el acceso al repositorio."
ensure_collaborator "$ADMIN_HANDLE" admin
ensure_collaborator "$WRITER_HANDLE" push
show_link_l "$(access_url "$OWNER" "$REPO")" \
  "Open repository access in GitHub" \
  "Abrir el acceso al repositorio en GitHub"
present_pause_l

section_l 3 "Apply classic branch protection" "Aplicar branch protection clásica"
say_l \
  "The rule requires one approving review, but administrators are not explicitly included. That implicit exception is the vulnerable state." \
  "La regla exige una aprobación, pero no incluye explícitamente a los administradores. Esa excepción implícita es el estado vulnerable."
note_l \
  "Removing any ruleset left by a previous take" \
  "Eliminando cualquier ruleset que haya quedado de una corrida anterior"
delete_rulesets_by_name "$OWNER" "$REPO" "main-protection" "$TEST_ORG_GH_TOKEN"
apply_classic_protection "$OWNER" "$REPO" "$TEST_ORG_GH_TOKEN"
show_link_l "$(branches_url "$OWNER" "$REPO")" \
  "Inspect classic branch protection" \
  "Ver la branch protection clásica"
present_pause_l

section_l 4 "Create an unapproved pull request" "Crear un pull request sin aprobación"
note_l "Closing leftover PRs from previous takes" "Cerrando PRs abiertos de corridas anteriores"
close_open_prs "$OWNER" "$REPO" "$TEST_ORG_GH_TOKEN"
note_l "Creating a feature branch and a trivial change" "Creando una rama y un cambio trivial"
create_demo_pr "$OWNER" "$REPO" "$TEST_ORG_GH_TOKEN" "demo/unapproved-change"
PR_NUMBER="$DEMO_PR_NUMBER"
BRANCH="$DEMO_PR_BRANCH"
wait_for_pr "$OWNER" "$REPO" "$PR_NUMBER" "$TEST_ORG_GH_TOKEN"

ok_l "PR #$PR_NUMBER is open on branch $BRANCH" "el PR #$PR_NUMBER está abierto desde la rama $BRANCH"
note_l \
  "The PR is intentionally NOT approved. The classic rule should stop ordinary writers, but not an exempt Admin identity." \
  "El PR está intencionalmente SIN aprobar. La regla clásica debería frenar a un Writer, pero no a una identidad Admin exceptuada."

echo ""
ok_l "setup complete" "setup completo"
echo "  repo:   $OWNER/$REPO"
echo "  branch: $BRANCH"
echo "  PR:     #$PR_NUMBER"
show_link_l "$(pr_url "$OWNER" "$REPO" "$PR_NUMBER")" \
  "Open the unapproved PR in GitHub" \
  "Abrir el PR sin aprobación en GitHub"
show_next_l "make attack-admin"
