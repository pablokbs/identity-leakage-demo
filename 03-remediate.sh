#!/usr/bin/env bash
# Replace classic protection with a ruleset that has no bypass actors.

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
  "03 — Remediate with a ruleset and least privilege" \
  "03 — Remediar con ruleset y mínimo privilegio")"

safety_gate

section_l 1 "Explain the two-part fix" "Explicar el fix en dos partes"
say_l \
  "First, the ruleset removes the implicit Admin exemption by leaving its bypass actor list empty." \
  "Primero, el ruleset elimina la excepción implícita de Admin dejando vacía la lista de bypass actors."
say_l \
  "Second, the token held by the agent has no Administration permission, so it cannot modify or delete this ruleset." \
  "Segundo, el token que posee el agente no tiene permiso de Administration, por lo que no puede modificar ni eliminar este ruleset."
show_link_l "$(branches_url "$OWNER" "$REPO")" \
  "Inspect the classic rule before migration" \
  "Ver la regla clásica antes de migrarla"
present_pause_l

section_l 2 "Replace classic protection" "Reemplazar la protección clásica"
remove_classic_protection "$OWNER" "$REPO" "$TEST_ORG_GH_TOKEN"
note_l \
  "Creating a repository ruleset: one review required, no bypass actors" \
  "Creando un ruleset: una aprobación requerida, sin bypass actors"

RULESET_BODY=$(jq -n '{
  name: "main-protection",
  target: "branch",
  enforcement: "active",
  conditions: { ref_name: { include: ["refs/heads/main"], exclude: [] } },
  rules: [
    {
      type: "pull_request",
      parameters: {
        required_approving_review_count: 1,
        dismiss_stale_reviews_on_push: true,
        require_code_owner_review: false,
        require_last_push_approval: false,
        required_review_thread_resolution: false
      }
    }
  ],
  bypass_actors: []
}')

RULESET_RESPONSE=$(gh_api POST "/repos/$OWNER/$REPO/rulesets" "$TEST_ORG_GH_TOKEN" \
  --data "$RULESET_BODY")
RULESET_ID=$(printf '%s' "$RULESET_RESPONSE" | jq -r '.id // empty')
[[ -n "$RULESET_ID" ]] || { printf '%s' "$RULESET_RESPONSE" | pp_json; die_l \
  "could not create the ruleset" \
  "no se pudo crear el ruleset"; }

ok_l \
  "ruleset $RULESET_ID is active on refs/heads/main" \
  "el ruleset $RULESET_ID está activo sobre refs/heads/main"

section_l 3 "Verify the policy" "Verificar la política"
RULESET_VERIFY=$(gh_api GET "/repos/$OWNER/$REPO/rulesets/$RULESET_ID" "$TEST_ORG_GH_TOKEN")
printf '%s' "$RULESET_VERIFY" | jq '{name, enforcement, target, bypass_actors, rules}' | pp_json
echo ""
ok_l \
  "bypass_actors is empty: the Admin identity is no longer exempt" \
  "bypass_actors está vacío: la identidad Admin ya no está exceptuada"
show_link_l "$(rules_settings_url "$OWNER" "$REPO")" \
  "Open ruleset settings" \
  "Abrir la configuración de rulesets"
show_link_l "$(effective_rules_url "$OWNER" "$REPO")" \
  "Open the effective rules for main" \
  "Abrir las reglas efectivas sobre main"
present_pause_l

ok_l "remediation complete" "remediación completa"
show_next_l "make reattack"
