#!/usr/bin/env bash
# Run the equivalent merge attempt with the non-exempt Writer identity.

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
  "02 — Repeat the attack with the Writer identity" \
  "02 — Repetir el ataque con la identidad Writer")"

safety_gate

if [[ $# -eq 1 ]]; then
  PR_NUMBER="$1"
else
  PR_NUMBER=$(gh_api GET "/repos/$OWNER/$REPO/pulls?state=open" "$TEST_ORG_GH_TOKEN" \
    | jq -r '[.[] | select(.head.ref | startswith("demo/"))][0].number // empty')
  [[ -n "$PR_NUMBER" ]] || die_l \
    "no open demo PR found; run 02-attack-admin.sh first" \
    "no hay un PR abierto para la demo; ejecutá primero 02-attack-admin.sh"
fi

section_l 1 "Compare the identity, not the operation" "Comparar la identidad, no la operación"
say_l \
  "This PR also has no approval and main still has the same classic protection rule." \
  "Este PR tampoco tiene aprobación y main mantiene la misma protección clásica."
say_l \
  "The token can write contents and pull requests. The relevant difference is that its owner has the Writer role, so GitHub does not exempt it from the rule." \
  "El token puede escribir contenido y pull requests. La diferencia relevante es que su dueño tiene rol Writer, por lo que GitHub no lo exceptúa de la regla."
show_link_l "$(pr_url "$OWNER" "$REPO" "$PR_NUMBER")" \
  "Open the unapproved comparison PR" \
  "Abrir el PR de comparación sin aprobación"
present_pause_l

section_l 2 "Attempt the same merge" "Intentar el mismo merge"
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
show_link_l "$(pr_url "$OWNER" "$REPO" "$PR_NUMBER")" \
  "Open the PR, which should still be blocked" \
  "Abrir el PR, que debería seguir bloqueado"

[[ "$HTTP_CODE" == "405" ]] || die_l \
  "Writer comparison did not produce the expected HTTP 405" \
  "la comparación con Writer no produjo el HTTP 405 esperado"
show_next_l "make remediate"
