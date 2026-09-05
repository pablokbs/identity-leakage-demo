.PHONY: help all setup attack-admin attack-writer remediate reattack reset delete-repo clean check

help:
	@echo "Identity Leakage Demo - make targets"
	@echo ""
	@echo "  make all          Run the full talk flow end to end."
	@echo "  make setup        Create/reuse repo, ensure collaborators, protection and PR."
	@echo "  make attack-admin Use the Admin PAT to merge unapproved PR."
	@echo "  make attack-writer Use the Writer PAT (same scopes, different identity)."
	@echo "  make remediate    Migrate from classic protection to Ruleset."
	@echo "  make reattack     Re-run Admin attack under Ruleset (should fail)."
	@echo "  make reset        Reset demo state: close PRs, remove protections (keeps repo)."
	@echo "  make delete-repo  PERMANENTLY delete the test repo (requires typing DELETE)."
	@echo "  make clean        Delete local clones and tmp files (never touches GitHub)."
	@echo "  make check        bash -n on every script."
	@echo ""
	@echo "Recommended live-demo flow:"
	@echo "  make setup        # run once, accept invitations, then reuse the repo"
	@echo "  make attack-admin"
	@echo "  make attack-writer"
	@echo "  make remediate"
	@echo "  make reattack"
	@echo "  make reset        # between takes"
	@echo ""
	@echo "Before running anything, copy 00-config.sh.example to 00-config.sh,"
	@echo "fill in real values, and source it:"
	@echo ""
	@echo "  cp 00-config.sh.example 00-config.sh && chmod 600 00-config.sh"
	@echo "  set -a; source ./00-config.sh; set +a"

check:
	@for f in lib.sh 01-setup.sh 02-attack-admin.sh 02-attack-writer.sh 03-remediate.sh 03-attack-admin-ruleset.sh 99-cleanup.sh 99-delete-repo.sh; do \
		bash -n "$$f" && echo "  ok $$f" || echo "  FAIL $$f"; \
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
	rm -rf /tmp/_gh_body.* *.log
	@echo "local tmp removed (no GitHub changes)"

all: setup attack-admin attack-writer remediate reattack

# 'all' intentionally does NOT include reset or delete-repo. Run those
# manually when you want to reset between takes or destroy the repo.
