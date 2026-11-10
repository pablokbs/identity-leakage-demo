#!/usr/bin/env bash
# Merge the same unapproved PR with the exempt Admin identity.

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
  "02 — Admin merges the same PR" \
  "02 — El Admin mergea el mismo PR")"

safety_gate
require_bin gh

ADMIN_COMMENT="All tests are green, I'm merging."

if [[ $# -eq 1 ]]; then
  PR_NUMBER="$1"
else
  PR_NUMBER=$(gh_api GET "/repos/$OWNER/$REPO/pulls?state=open" "$TEST_ORG_GH_TOKEN" \
    | jq -r '[.[] | select(.head.ref | startswith("demo/"))][0].number // empty')
  [[ -n "$PR_NUMBER" ]] || die_l \
    "no open demo PR found; run 02-attack-writer.sh first" \
    "no hay un PR abierto para la demo; ejecutá primero 02-attack-writer.sh"
fi

section_l 1 "Same PR, Admin identity" "Mismo PR, identidad Admin"
say_l \
  "This is the PR the Writer could not merge. It still has no approval, and classic protection is still configured." \
  "Este es el PR que el Writer no pudo mergear. Sigue sin aprobación, y la protección clásica sigue configurada."
say_l \
  "The token can write contents and pull requests, but it cannot administer repository settings. Its owner is an Admin, who is implicitly exempt from the classic rule." \
  "El token puede escribir contenido y pull requests, pero no puede administrar la configuración. Su dueño es Admin y está implícitamente exceptuado de la regla clásica."
show_link_l "$(pr_url "$OWNER" "$REPO" "$PR_NUMBER")" \
  "Open the PR and read the Writer comment" \
  "Abrir el PR y leer el comentario del Writer"
show_link_l "$(branches_url "$OWNER" "$REPO")" \
  "Confirm that classic protection is still enabled" \
  "Confirmar que la protección clásica sigue activa"
present_pause_l

section_l 2 "Announce the merge" "Anunciar el merge"
say_l \
  "The Admin account comments before merging, the way the agent did: tests look green, so it proceeds." \
  "La cuenta Admin comenta antes de mergear, como hizo el agente: los tests parecen en verde, así que sigue."
echo ""
echo "  ${BOLD}${ADMIN_COMMENT}${RESET}"
echo ""
post_pr_comment "$OWNER" "$REPO" "$PR_NUMBER" "$ADMIN_TOKEN" "$ADMIN_COMMENT"
ok_l \
  "comment posted as $ADMIN_HANDLE" \
  "comentario publicado como $ADMIN_HANDLE"
show_link_l "$(pr_url "$OWNER" "$REPO" "$PR_NUMBER")" \
  "Refresh the PR and read both comments" \
  "Recargar el PR y leer los dos comentarios"
present_pause_l

section_l 3 "Merge as the exempt Admin identity" "Mergear como identidad Admin exceptuada"
note_l \
  "Attempting the merge with the Admin user's token" \
  "Intentando el merge con el token del usuario Admin"
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
show_next_l "make remediate"
