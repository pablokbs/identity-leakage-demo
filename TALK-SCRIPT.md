# Talk Script — Identity Leakage Demo (English)

Run the demo with:

```bash
make DEMO_PRESENT=1 setup
make DEMO_PRESENT=1 attack-writer
make DEMO_PRESENT=1 attack-admin
make DEMO_PRESENT=1 remediate
make DEMO_PRESENT=1 reattack
```

## Setup

> This repository and its two collaborators already exist. That is deliberate: invitations are a one-time prerequisite, not part of a live security demonstration.
>
> Main has classic branch protection requiring one approving review. Administrators are not explicitly included, so they remain implicitly exempt. There is one pull request, and it has no approval.

Use the printed links to show repository access, branch settings, and the unapproved PR. The permission API shows the role the UI hides: Admin and Writer.

## Writer attempt

> Same PR, no approval. The Writer token can update contents and pull requests. Its role is not exempt from the rule.

Show the HTTP 405 and the still-open PR. The Writer account then comments, as the token owner:

> I tried to merge but I couldn't.

> Classic protection applies to Writer. Identity changed the result, not the pull request.

## Admin attack

> Same operation and the same PR. The meaningful difference is the owner of the token: this identity has the Admin role.
>
> The Admin comments before merging, the way the agent did.

Show the comment:

> All tests are green, I'm merging.

> Watch closely: the script does not remove or edit branch protection. It only asks GitHub to merge the unapproved PR.

After the merge succeeds, show:

- both comments on the same PR;
- the PR is merged without approval;
- classic branch protection is still configured.

> The control was never removed. GitHub exempted the Admin identity from it. Token scope did not erase the identity behind the token.

## Remediation

> The fix has two parts. First, replace classic protection with a ruleset that has no bypass actors. Second, keep Administration permission out of the credential held by the agent.

Show the compact ruleset JSON, especially:

```json
"bypass_actors": []
```

Then open the ruleset settings and effective-rules links.

## Admin re-attack

> Same Admin identity. Same narrow token. The previous PR was already merged, so this step opens a fresh unapproved PR. The relevant change is the policy applied to main.

Show that the exact same `gh pr merge --admin` command is rejected and the PR remains open. The Admin account then comments:

> I'm an admin but I couldn't merge because of the rulesets.

> The ruleset removed the implicit Admin exemption. The agent cannot bypass it, and its token lacks Administration permission to modify or delete it.

## Closing

> A token is not an isolated identity. GitHub evaluates both the token's permissions and the repository role of its owner.
>
> Classic protection left an Admin-shaped hole. A no-bypass ruleset closes that hole, and least privilege prevents the agent from moving the wall.

Run `make reset` after the presentation. It preserves the repository and collaborators for the next take.
