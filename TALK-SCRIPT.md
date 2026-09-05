# Talk Script — Identity Leakage Demo (English)

Run the demo with:

```bash
make DEMO_PRESENT=1 setup
make DEMO_PRESENT=1 attack-admin
make DEMO_PRESENT=1 attack-writer
make DEMO_PRESENT=1 remediate
make DEMO_PRESENT=1 reattack
```

## Setup

> This repository and its two collaborators already exist. That is deliberate: invitations are a one-time prerequisite, not part of a live security demonstration.
>
> Main has classic branch protection requiring one approving review. Administrators are not explicitly included, so they remain implicitly exempt. The first pull request has no approval.

Use the printed links to show repository access, branch settings, and the unapproved PR.

## Admin attack

> The agent holds a narrow token: it can update contents and pull requests, but it cannot administer repository settings. The identity behind that token is a repository Admin.
>
> Watch closely: the script does not remove or edit branch protection. It only asks GitHub to merge the unapproved PR.

After the merge succeeds, show both links:

- the PR is merged without approval;
- classic branch protection is still configured.

> The control was never removed. GitHub exempted the Admin identity from it. Token scope did not erase the identity behind the token.

The script creates a fresh equivalent PR for the Writer comparison.

## Writer comparison

> Same operation and equivalent narrow token. The meaningful difference is the owner of the token: this identity has Writer role, not Admin.

Show the HTTP 405 and the still-open PR.

> Classic protection applies to Writer, so GitHub blocks the merge. Identity changed the effective authorization result.

## Remediation

> The fix has two parts. First, replace classic protection with a ruleset that has no bypass actors. Second, keep Administration permission out of the credential held by the agent.

Show the compact ruleset JSON, especially:

```json
"bypass_actors": []
```

Then open the ruleset settings and effective-rules links.

## Admin re-attack

> Same Admin identity. Same narrow token. Same unapproved Writer-comparison PR. The relevant change is the policy applied to main.

Show that the exact same `gh pr merge --admin` command is rejected and the PR remains open.

> The ruleset removed the implicit Admin exemption. The agent cannot bypass it, and its token lacks Administration permission to modify or delete it.

## Closing

> A token is not an isolated identity. GitHub evaluates both the token's permissions and the repository role of its owner.
>
> Classic protection left an Admin-shaped hole. A no-bypass ruleset closes that hole, and least privilege prevents the agent from moving the wall.

Run `make reset` after the presentation. It preserves the repository and collaborators for the next take.
