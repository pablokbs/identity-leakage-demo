#!/usr/bin/env bash
# Demonstrate the implicit Admin exemption in classic branch protection.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=00-config.sh
source "$SCRIPT_DIR/00-config.sh"

parse_common_args "$@"
set -- ${COMMON_ARGS[@]+"${COMMON_ARGS[@]}"}
[[ $# -le 1 ]] || die_l \
  "usage: $0 [--lang en|es] [--present] [PR_NUMBER]" \
  "uso: $0 [--lang en|es] [--present] [NUMERO_DE_PR]"

banner "$(localized \
  "02 — Attack with the Admin identity" \
  "02 — Ataque con la identidad Admin")"

safety_gate
require_bin gh

if [[ $# -eq 1 ]]; then
  PR_NUMBER="$1"
else
  PR_NUMBER=$(gh_api GET "/repos/$OWNER/$REPO/pulls?state=open" "$TEST_ORG_GH_TOKEN" \
    | jq -r '[.[] | select(.head.ref | startswith("demo/"))][0].number // empty')
  [[ -n "$PR_NUMBER" ]] || die_l \
    "no open demo PR found; run 01-setup.sh first" \
    "no hay un PR abierto para la demo; ejecutá primero 01-setup.sh"
fi

section_l 1 "Establish the vulnerable state" "Mostrar el estado vulnerable"
say_l \
  "Classic branch protection requires one review, and this PR has none." \
  "La branch protection clásica exige una aprobación y este PR no tiene ninguna."
say_l \
  "The token can write contents and pull requests, but it cannot administer repository settings. Its owner is an Admin, who is implicitly exempt from the classic rule." \
  "El token puede escribir contenido y pull requests, pero no puede administrar la configuración. Su dueño es Admin y está implícitamente exceptuado de la regla clásica."
show_link_l "$(pr_url "$OWNER" "$REPO" "$PR_NUMBER")" \
  "Open the unapproved PR" \
  "Abrir el PR sin aprobación"
show_link_l "$(branches_url "$OWNER" "$REPO")" \
  "Confirm that classic protection is still enabled" \
  "Confirmar que la protección clásica sigue activa"
present_pause_l

section_l 2 "Merge as the exempt Admin identity" "Mergear como identidad Admin exceptuada"
note_l \
  "Attempting the merge with the Admin user's narrow token" \
  "Intentando el merge con el token limitado del usuario Admin"
echo ""
if ! GH_TOKEN="$ADMIN_TOKEN" gh pr merge "$PR_NUMBER" --admin --squash --repo "$OWNER/$REPO" 2>&1; then
  echo ""
  die_l \
    "Admin merge was rejected; the expected classic-protection bypass did not occur" \
    "el merge del Admin fue rechazado; no ocurrió el bypass esperado de la protección clásica"
fi

echo ""
ok_l \
  "MERGE SUCCEEDED without an approving review" \
  "EL MERGE FUE EXITOSO sin una aprobación"
say_l \
  "The token did not remove or edit protection. GitHub allowed the update to main because the identity behind the token is an exempt Admin." \
  "El token no eliminó ni modificó la protección. GitHub permitió actualizar main porque la identidad detrás del token es un Admin exceptuado."
show_link_l "$(pr_url "$OWNER" "$REPO" "$PR_NUMBER")" \
  "Open the merged PR" \
  "Abrir el PR mergeado"
show_link_l "$(branches_url "$OWNER" "$REPO")" \
  "Verify that classic protection was never removed" \
  "Verificar que la protección clásica nunca fue eliminada"
present_pause_l

section_l 3 "Prepare the Writer comparison" "Preparar la comparación con Writer"
say_l \
  "A fresh, equivalent unapproved PR is created so the Writer identity can attempt the same operation under the same classic rule." \
  "Se crea otro PR equivalente y sin aprobación para que la identidad Writer intente la misma operación bajo la misma regla clásica."
create_demo_pr "$OWNER" "$REPO" "$TEST_ORG_GH_TOKEN" "demo/writer-comparison"
ok_l \
  "comparison PR #$DEMO_PR_NUMBER is ready" \
  "el PR de comparación #$DEMO_PR_NUMBER está listo"
show_link_l "$(pr_url "$OWNER" "$REPO" "$DEMO_PR_NUMBER")" \
  "Open the Writer comparison PR" \
  "Abrir el PR para la comparación con Writer"
show_next_l "make attack-writer"
