DEMO_LANG ?= en
DEMO_PRESENT ?= 0
export DEMO_LANG DEMO_PRESENT

.PHONY: help help-es all setup attack-admin attack-writer remediate reattack reset delete-repo clean check

ifeq ($(DEMO_LANG),es)
HELP_TITLE = Demo de Identity Leakage - comandos
HELP_SETUP = Preparar protección clásica y un PR sin aprobación.
HELP_ADMIN = Ejecutar el ataque con la identidad Admin.
HELP_WRITER = Repetir el ataque con la identidad Writer.
HELP_REMEDIATE = Migrar a un ruleset sin bypass actors.
HELP_REATTACK = Repetir el ataque Admin bajo el ruleset.
HELP_RESET = Limpiar el estado sin eliminar el repositorio.
HELP_DELETE = ELIMINAR permanentemente el repositorio de prueba.
HELP_CHECK = Validar la sintaxis de todos los scripts.
HELP_FLOW = Flujo recomendado para la demo en vivo
HELP_LANG = Idioma: DEMO_LANG=es o --lang es al ejecutar un script.
HELP_PRESENT = Pausas: DEMO_PRESENT=1 o --present al ejecutar un script.
else
HELP_TITLE = Identity Leakage Demo - commands
HELP_SETUP = Prepare classic protection and an unapproved PR.
HELP_ADMIN = Run the attack with the Admin identity.
HELP_WRITER = Repeat the attack with the Writer identity.
HELP_REMEDIATE = Migrate to a ruleset with no bypass actors.
HELP_REATTACK = Repeat the Admin attack under the ruleset.
HELP_RESET = Clean demo state without deleting the repository.
HELP_DELETE = PERMANENTLY delete the test repository.
HELP_CHECK = Validate the syntax of every script.
HELP_FLOW = Recommended live-demo flow
HELP_LANG = Language: DEMO_LANG=es or --lang es on individual scripts.
HELP_PRESENT = Pauses: DEMO_PRESENT=1 or --present on individual scripts.
endif

help:
	@echo "$(HELP_TITLE)"
	@echo ""
	@echo "  make setup          $(HELP_SETUP)"
	@echo "  make attack-admin   $(HELP_ADMIN)"
	@echo "  make attack-writer  $(HELP_WRITER)"
	@echo "  make remediate      $(HELP_REMEDIATE)"
	@echo "  make reattack       $(HELP_REATTACK)"
	@echo "  make reset          $(HELP_RESET)"
	@echo "  make delete-repo    $(HELP_DELETE)"
	@echo "  make check          $(HELP_CHECK)"
	@echo ""
	@echo "$(HELP_LANG)"
	@echo "$(HELP_PRESENT)"
	@echo ""
	@echo "$(HELP_FLOW):"
	@echo "  make DEMO_LANG=$(DEMO_LANG) DEMO_PRESENT=1 setup"
	@echo "  make DEMO_LANG=$(DEMO_LANG) DEMO_PRESENT=1 attack-admin"
	@echo "  make DEMO_LANG=$(DEMO_LANG) DEMO_PRESENT=1 attack-writer"
	@echo "  make DEMO_LANG=$(DEMO_LANG) DEMO_PRESENT=1 remediate"
	@echo "  make DEMO_LANG=$(DEMO_LANG) DEMO_PRESENT=1 reattack"
	@echo "  make DEMO_LANG=$(DEMO_LANG) reset"

help-es:
	@$(MAKE) --no-print-directory DEMO_LANG=es help

check:
	@for f in lib.sh 01-setup.sh 02-attack-admin.sh 02-attack-writer.sh 03-remediate.sh 03-attack-admin-ruleset.sh 99-cleanup.sh 99-delete-repo.sh; do \
		bash -n "$$f" && echo "  ok $$f" || exit 1; \
	done

setup:
	./01-setup.sh

attack-admin:
	./02-attack-admin.sh

attack-writer:
	./02-attack-writer.sh

remediate:
	./03-remediate.sh

reattack:
	./03-attack-admin-ruleset.sh

reset:
	./99-cleanup.sh

delete-repo:
	./99-delete-repo.sh

clean:
	rm -f /tmp/_gh_body.* ./*.log
	@echo "local temporary files removed"

all: setup attack-admin attack-writer remediate reattack
