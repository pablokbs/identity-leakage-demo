#!/usr/bin/env bash
# Writer tries to merge the unapproved PR and is blocked by classic protection.

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
  "02 — Writer tries to merge the unapproved PR" \
  "02 — El Writer intenta mergear el PR sin aprobación")"

safety_gate

WRITER_COMMENT="I tried to merge but I couldn't."

if [[ $# -eq 1 ]]; then
  PR_NUMBER="$1"
else
  PR_NUMBER=$(gh_api GET "/repos/$OWNER/$REPO/pulls?state=open" "$TEST_ORG_GH_TOKEN" \
    | jq -r '[.[] | select(.head.ref | startswith("demo/"))][0].number // empty')
  [[ -n "$PR_NUMBER" ]] || die_l \
    "no open demo PR found; run 01-setup.sh first" \
    "no hay un PR abierto para la demo; ejecutá primero 01-setup.sh"
fi

section_l 1 "Same PR, Writer identity" "Mismo PR, identidad Writer"
say_l \
  "This is the unapproved PR from setup. Main still has classic protection requiring one review." \
  "Este es el PR sin aprobación del setup. Main sigue con protección clásica que exige una aprobación."
say_l \
  "The token can write contents and pull requests. Its owner has the Writer role, so GitHub does not exempt it from the rule." \
  "El token puede escribir contenido y pull requests. Su dueño tiene rol Writer, por lo que GitHub no lo exceptúa de la regla."
show_link_l "$(pr_url "$OWNER" "$REPO" "$PR_NUMBER")" \
  "Open the unapproved PR" \
  "Abrir el PR sin aprobación"
present_pause_l

section_l 2 "Attempt the merge" "Intentar el merge"
note_l \
  "Expected result: GitHub blocks the Writer identity" \
  "Resultado esperado: GitHub bloquea a la identidad Writer"

RESPONSE_FILE=$(mktemp)
trap 'rm -f "$RESPONSE_FILE"' EXIT
HTTP_CODE=$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Authorization: Bearer ${WRITER_TOKEN}" \
  "https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER/merge" \
  -d "$(jq -n '{merge_method:"squash"}')" || true)

echo ""
echo "  ${BOLD}HTTP status:${RESET} ${HTTP_CODE}"
echo ""
if [[ "$HTTP_CODE" == "405" ]]; then
  ok_l \
    "merge blocked — the Writer identity is subject to classic protection" \
    "merge bloqueado — la identidad Writer está sujeta a la protección clásica"
elif [[ "$HTTP_CODE" == "200" ]]; then
  warn_l \
    "merge unexpectedly succeeded; verify the Writer role and branch rule" \
    "el merge funcionó inesperadamente; verificá el rol Writer y la regla de la rama"
else
  warn_l \
    "unexpected HTTP status $HTTP_CODE" \
    "código HTTP inesperado: $HTTP_CODE"
fi

say_l "GitHub response:" "Respuesta de GitHub:"
pp_json < "$RESPONSE_FILE" | sed 's/^/    /'

[[ "$HTTP_CODE" == "405" ]] || die_l \
  "Writer merge was not blocked with the expected HTTP 405" \
  "el merge del Writer no fue bloqueado con el HTTP 405 esperado"

section_l 3 "Leave the failure on the PR" "Dejar el fallo en el PR"
say_l \
  "The Writer account comments on the same PR. GitHub attributes the comment to the token owner, not to the repository owner." \
  "La cuenta Writer comenta en el mismo PR. GitHub atribuye el comentario al dueño del token, no al dueño del repositorio."
echo ""
echo "  ${BOLD}${WRITER_COMMENT}${RESET}"
echo ""
post_pr_comment "$OWNER" "$REPO" "$PR_NUMBER" "$WRITER_TOKEN" "$WRITER_COMMENT"
ok_l \
  "comment posted as $WRITER_HANDLE" \
  "comentario publicado como $WRITER_HANDLE"
show_link_l "$(pr_url "$OWNER" "$REPO" "$PR_NUMBER")" \
  "Open the PR and read the Writer comment" \
  "Abrir el PR y leer el comentario del Writer"
present_pause_l
show_next_l "make attack-admin"
