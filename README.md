# Identity Leakage Demo — KubeCon Talk

Live demo for **“When the Agent Lost Its Patience: Securing Cloud-Native AI Workflows Against Identity Leakage.”**

The demo shows that token permissions and identity permissions are separate inputs to authorization:

- A narrow token owned by a repository **Admin** can merge an unapproved PR when classic branch protection implicitly exempts administrators.
- An equivalent token owned by a **Writer** is blocked by the same classic rule.
- A repository ruleset with no bypass actors removes that implicit exemption.
- The agent token has no `Administration` permission, so it cannot modify or delete the ruleset that constrains it.

## Threat model

Both demo tokens can update repository contents and pull requests. Neither token can administer repository settings. The important difference is the role of the identity that owns each token.

The remediation has two parts:

1. Enforce the review requirement with a ruleset whose `bypass_actors` list is empty.
2. Keep `Administration` permission out of the token held by the agent.

The repository owner uses a separate setup token to prepare and clean the lab.

## One-time preparation

Before the talk:

1. Create and initialize a reusable public test repository with a `main` branch.
2. Add two test accounts and wait for both invitations to be accepted:
   - one account with repository Admin role;
   - one account with Writer role.
3. Create equivalent narrow tokens for those accounts:
   - Contents: read and write;
   - Pull requests: read and write;
   - Metadata: read-only;
   - **no Administration permission**.
4. Create a separate owner/setup token that can configure protection and rulesets.
5. Copy `00-config.sh.example` to `00-config.sh` and fill in the values.

The scripts reuse the repository and collaborators. They do not create the repository or send invitations during the live demo.

## Languages

English is the default:

```bash
make setup
./02-attack-admin.sh
```

Select Spanish with an environment variable or script flag:

```bash
make DEMO_LANG=es setup
./02-attack-admin.sh --lang es
```

CLI flags take precedence over `DEMO_LANG`.

## Presentation mode

Presentation mode prints GitHub links and pauses at useful visual checkpoints:

```bash
make DEMO_LANG=es DEMO_PRESENT=1 setup
./02-attack-admin.sh --lang es --present
```

Without presentation mode, the same scripts run without waiting for Enter.

## Live flow

Run each command separately:

```bash
make DEMO_LANG=es DEMO_PRESENT=1 setup
make DEMO_LANG=es DEMO_PRESENT=1 attack-admin
make DEMO_LANG=es DEMO_PRESENT=1 attack-writer
make DEMO_LANG=es DEMO_PRESENT=1 remediate
make DEMO_LANG=es DEMO_PRESENT=1 reattack
make DEMO_LANG=es reset
```

The flow is intentionally staged:

| Step | What happens | GitHub UI checkpoint |
| --- | --- | --- |
| Setup | Verify the reusable repo and collaborators, apply classic protection, open an unapproved PR | Access, branch settings, PR |
| Admin attack | Admin token merges without approval; classic protection remains configured | PR and branch settings |
| Writer comparison | A fresh equivalent PR is rejected for the Writer identity | Open blocked PR |
| Remediation | Replace classic protection with a no-bypass ruleset | Ruleset settings and effective rules |
| Admin re-attack | The exact same `gh pr merge --admin` operation is rejected; the token cannot change the ruleset | Effective rules and blocked PR |
| Cleanup | Close PRs, delete `demo/*` branches, and remove demo protections while preserving the repo and collaborators | Repository home |

`make all` is useful for automation. For a talk, use the individual commands so you control every pause.

## Files

```text
identity-leakage-demo/
├── 00-config.sh.example
├── 01-setup.sh
├── 02-attack-admin.sh
├── 02-attack-writer.sh
├── 03-remediate.sh
├── 03-attack-admin-ruleset.sh
├── 99-cleanup.sh
├── 99-delete-repo.sh
├── lib.sh
├── Makefile
├── TALK-SCRIPT.md
└── TALK-SCRIPT.es.md
```

## Cleanup versus deletion

Normal cleanup keeps the reusable repository and collaborators:

```bash
make reset
```

Permanent deletion is deliberately separate and requires typing `DELETE`:

```bash
make delete-repo
```

## Requirements

- Bash 3.2 or newer
- `curl`, `jq`, `base64`, `gh`
- Network access to `api.github.com` and `github.com`

## Safety

Every script validates the configured owner, repository name, token presence, and denylist before changing GitHub state. Keep production owners and repositories in the denylist in `lib.sh`.

Never show, print, commit, or pass the tokens as command-line arguments. `00-config.sh` is ignored by Git.
