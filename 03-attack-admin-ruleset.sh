#!/usr/bin/env bash
# Repeat the Admin merge after the no-bypass ruleset is active.

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
  "03 — Re-attack with the Admin identity under the ruleset" \
  "03 — Repetir el ataque Admin bajo el ruleset")"

safety_gate
require_bin gh

if [[ $# -eq 1 ]]; then
  PR_NUMBER="$1"
else
  PR_NUMBER=$(gh_api GET "/repos/$OWNER/$REPO/pulls?state=open" "$TEST_ORG_GH_TOKEN" \
    | jq -r '[.[] | select(.head.ref | startswith("demo/"))][0].number // empty')
  [[ -n "$PR_NUMBER" ]] || die_l \
    "no open demo PR found; run the previous steps first" \
    "no hay un PR abierto para la demo; ejecutá primero los pasos anteriores"
fi

section_l 1 "Hold every variable constant" "Mantener constantes todas las variables"
say_l \
  "This is the same Admin identity and the same narrow token that succeeded under classic protection." \
  "Esta es la misma identidad Admin y el mismo token limitado que funcionaron con la protección clásica."
say_l \
  "The token can update contents and pull requests, but it cannot administer the repository or remove the ruleset." \
  "El token puede actualizar contenido y pull requests, pero no puede administrar el repositorio ni eliminar el ruleset."
say_l \
  "The only relevant policy change is the active ruleset with an empty bypass actor list." \
  "El único cambio relevante de política es el ruleset activo con la lista de bypass actors vacía."
show_link_l "$(effective_rules_url "$OWNER" "$REPO")" \
  "Inspect the effective rules for main" \
  "Ver las reglas efectivas sobre main"
show_link_l "$(pr_url "$OWNER" "$REPO" "$PR_NUMBER")" \
  "Open the still-unapproved PR" \
  "Abrir el PR que sigue sin aprobación"
present_pause_l

section_l 2 "Repeat the exact Admin merge" "Repetir exactamente el mismo merge Admin"
note_l \
  "Running the same gh pr merge --admin operation used in the first attack" \
  "Ejecutando la misma operación gh pr merge --admin usada en el primer ataque"

RESPONSE_FILE=$(mktemp)
trap 'rm -f "$RESPONSE_FILE"' EXIT
if GH_TOKEN="$ADMIN_TOKEN" gh pr merge "$PR_NUMBER" --admin --squash \
  --repo "$OWNER/$REPO" >"$RESPONSE_FILE" 2>&1; then
  RESULT="merged"
else
  RESULT="blocked"
fi

echo ""
cat "$RESPONSE_FILE"
echo ""
if [[ "$RESULT" == "blocked" ]]; then
  ok_l \
    "merge blocked — the ruleset applies to the Admin identity" \
    "merge bloqueado — el ruleset se aplica a la identidad Admin"
else
  warn_l \
    "merge unexpectedly succeeded; verify bypass actors and effective rules" \
    "el merge funcionó inesperadamente; verificá bypass actors y las reglas efectivas"
fi
show_link_l "$(pr_url "$OWNER" "$REPO" "$PR_NUMBER")" \
  "Open the PR, still protected from the Admin token" \
  "Abrir el PR, todavía protegido frente al token Admin"

[[ "$RESULT" == "blocked" ]] || die_l \
  "Admin re-attack was not blocked as expected" \
  "el reataque Admin no fue bloqueado como se esperaba"

echo ""
ok_l \
  "the two-part fix holds: no bypass actor and no token permission to change the rule" \
  "el fix en dos partes funciona: sin bypass actor y sin permiso del token para cambiar la regla"
show_next_l "make reset"
