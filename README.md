# Identity Leakage Demo — KubeCon Talk

Live demo for the talk **"When the Agent Lost Its Patience: Securing Cloud-Native AI Workflows Against Identity Leakage"**.

The demo proves a single, scary claim: **the scope of a Personal Access Token is a ceiling on what the identity behind it can do — not a permission in itself**. So if the identity owning the token is a repository Admin, even a fine-grained PAT scoped to "just this repo" can bypass branch protection, because the user identity behind the token is allowed to bypass.

The same PAT, used by a Write-only identity, is blocked. The only thing that changes between the two runs is the **role of the user**, not the token.

## Talk flow

| Step | Script | Purpose |
| --- | --- | --- |
| Setup | `01-setup.sh` | Create a test repo, add two collaborators, configure classic branch protection on `main` (1 required review, admins may bypass by default), and open an unapproved PR. |
| Attack | `02-attack-admin.sh` | Use a fine-grained PAT belonging to the **Admin** user to try to merge the unapproved PR. **The merge succeeds** despite the rule. |
| Attack | `02-attack-writer.sh` | Use a fine-grained PAT belonging to the **Writer** user to try to merge the same PR. **The merge fails**. Same PAT scopes, different identity, different outcome. |
| Remediate | `03-remediate.sh` | Delete the classic branch protection rule and replace it with a repository **Ruleset** whose `bypass_actors` list is empty. |
| Re-attack | `03-attack-admin-ruleset.sh` | Use the Admin token again on the same PR. **The merge now fails** — the structural fix holds even for admins. |
| Reset | `99-reset.sh` | Deletes the test repo. Safe to run between takes. |

## Manual one-time setup before the talk

You need three things:

1. **A test repository** under your own GitHub user or a dedicated test org.
   - It must be empty so the setup script can push a starter commit to `main`.
   - It must allow you to add two collaborators.

2. **Two test GitHub accounts**.
   - Both accounts must be added to the test repository as collaborators.
   - `pelado-admin` must be invited with **Admin** role.
   - `pelado-writer` must be invited with **Write** role (or **Maintain** for a personal repo, but Write is preferred for parity with orgs).
   - Both accounts must accept the invitation before the talk.

3. **Two fine-grained Personal Access Tokens**.
   - Generate them at `https://github.com/settings/personal-access-tokens/new`.
   - **Repository access:** select only your test repository.
   - **Permissions:** for both tokens, enable exactly:
     - **Contents:** Read and write
     - **Pull requests:** Read and write
     - **Metadata:** Read-only (this is auto-selected)
   - **Expiration:** 1 day is fine for the talk window.
   - The **only difference** between the two tokens is the *user* that owns them. Both have identical scopes.

Save the tokens somewhere safe (1Password, Bitwarden) until the talk. They will be pasted as environment variables in the terminal, not stored in files.

## Files in this directory

```
identity-leakage-demo/
├── README.md                  # this file
├── lib.sh                     # shared helpers, safety checks, color helpers
├── 00-config.sh.example       # template; copy to 00-config.sh and fill in
├── 01-setup.sh                # create repo, protection, PR
├── 02-attack-admin.sh         # admin token merges unapproved PR
├── 02-attack-writer.sh        # writer token is blocked
├── 03-remediate.sh            # migrate to ruleset
├── 03-attack-admin-ruleset.sh # admin blocked by ruleset
└── 99-reset.sh                # delete test repo
```

## First-time setup

```bash
cd identity-leakage-demo
cp 00-config.sh.example 00-config.sh
chmod 600 00-config.sh
# edit 00-config.sh and fill in the values
```

The `00-config.sh` file contains:

```bash
OWNER="your-github-username"          # or your org name
REPO="identity-leakage-demo"          # the test repo to create
TEST_ORG_GH_TOKEN="***"  # a PAT owned by YOUR account with repo admin and delete_repo scopes on the test org/user
ADMIN_HANDLE="pelado-admin"           # the GitHub username with Admin role
WRITER_HANDLE="pelado-writer"         # the GitHub username with Write role
ADMIN_TOKEN="***"        # the Admin user's fine-grained PAT
WRITER_TOKEN="***"       # the Writer user's fine-grained PAT
```

The `TEST_ORG_GH_TOKEN` is only used by `01-setup.sh` and `99-reset.sh` to create and delete the test repo and configure protection. It belongs to **your** account, which must already have Admin rights over the test org or user.

The `ADMIN_TOKEN` and `WRITER_TOKEN` are the tokens used by the **demo personas**. They are the ones that prove the point. The talk uses *only* these two PATs after setup is complete.

## Running the demo

On stage, source the config and run each script in order:

```bash
source ./00-config.sh
./01-setup.sh                 # creates the repo, protection and PR
./02-attack-admin.sh          # admin PAT merges unapproved PR
./02-attack-writer.sh         # writer PAT is blocked
./03-remediate.sh             # installs ruleset, deletes classic rule
./03-attack-admin-ruleset.sh  # admin PAT is now blocked too
./99-reset.sh                 # cleans up the test repo
```

Between takes, run `99-reset.sh` followed by `01-setup.sh` to reset the world.

## Safety guarantees

These scripts **refuse to run** unless all of the following are true:

- `OWNER` matches the regex `^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$`
- `REPO` matches the same regex and must not match production-like names (`prod`, `infra`, `pay`, `auth`, `users`, `billing`, `core`, `app`, `api`)
- `OWNER/REPO` is not in your production denylist (defined in `lib.sh`)
- `OWNER` is not the string `pablokbs` (or any other name you put in the denylist) so you cannot accidentally nuke the wrong thing

If any check fails, the script exits with a loud red message and refuses to do anything.

The reset script (`99-reset.sh`) requires you to type `DELETE` interactively before it will call the delete endpoint.

## Requirements

- `bash` 4+
- `curl`, `jq`
- `gh` CLI authenticated as a user that can create repos in the org (optional, used by `01-setup.sh` as a fallback to the REST API)
