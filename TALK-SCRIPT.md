# Talk Script — Identity Leakage Demo

This document is the narration that goes with each script. Read it once before going on stage.

**Total demo time:** ~7 minutes
**Total slot:** ~10 minutes including narration

The slide deck should show:

1. Title: "When the Agent Lost Its Patience"
2. The talk title card with the three personas: Admin, Writer, and the Agent
3. After the demo: a comparison table "Classic Protection vs Ruleset"
4. Closing slide: "Migrate to Rulesets. Today."

The terminal output is the main visual. Do not put code on screen. Make the terminal itself the artifact.

---

## Slide: title

> "This is the story of an autonomous coding agent that ran for 11 hours, 23 minutes, and bypassed every pull-request rule you thought you had.
>
> I am going to reproduce the bug in front of you, in 7 minutes, on a fresh GitHub repo. Then I am going to show you how to prevent it structurally — using a feature that ships to every GitHub repository next month."

## Slide: three personas

Draw three columns on the slide. You will refer back to this diagram throughout.

| Admin | Writer | Agent |
|---|---|---|
| Human, your coworker | Human, your coworker | Automated worker |
| Has Admin role on repo | Has Write role on repo | Holds a fine-grained PAT |

---

## Run: `./01-setup.sh`

**Say:**

> "Step 1: I create a fresh repo called `identity-leakage-demo`. I invite two of my colleagues as collaborators. One of them gets Admin, the other gets Write. No trickery.
>
> Then I configure classic branch protection on `main`: one required review. By default, GitHub lets admins bypass this rule. That's a checkbox I did not touch. This is what 90% of repos on GitHub look like today.
>
> Then I open a pull request with a trivial change. No approvals. Nothing fancy."

**Show on terminal:**

- repo created
- both invites sent
- protection rule applied (the JSON response shows `enforce_admins: false`)
- PR opened, URL printed at the end

**Point at the screen:**

> "Look at the JSON. `enforce_admins: false`. Admins can bypass. That is the default."

## Run: `./02-attack-admin.sh`

**Say:**

> "Step 2: I give the Admin persona a fine-grained Personal Access Token. Scope: only this repo. Contents: read and write. Pull requests: read and write. That is exactly the minimum a coding agent needs to open a PR.
>
> The agent tries to merge the PR. There is no approval. There should be no merge. Watch the HTTP status code."

**Show on terminal:**

- the curl with the Admin token
- the HTTP status line in giant green or red
- the response body

**If merge succeeds (expected):**

> "HTTP 200. The merge went through. One fine-grained PAT, scoped to one repo, no review, and it merged. The agent did exactly what we told it to do: merge a PR.
>
> Now: was this the agent's fault? No. The agent used the same credentials we gave it. The fault is that 'Admin' on the right side of the slide means 'Admin who can bypass every rule on this repo'."

## Run: `./02-attack-writer.sh`

**Say:**

> "Step 3: same attack. Different identity. I give the Writer persona a token with **identical scopes**. Only this repo, Contents and Pull requests: write. Same permissions page, same expiry, same name on the GitHub settings.
>
> The Writer tries the same merge."

**Show on terminal:**

- the curl with the Writer token
- HTTP 405
- the response body

**Point at the screen:**

> "HTTP 405. Method not allowed. The PAT scopes are **byte-for-byte identical**. The only thing that changed is which user owns the token.
>
> This is the point of the talk. The token is not the permission. The token is the ceiling. The identity is the permission."

Let the silence sit for 3 seconds.

## Slide: the table

Show a side-by-side:

| | Admin | Writer |
|---|---|---|
| PAT scope | Contents + PR: write, only this repo | Contents + PR: write, only this repo |
| User role on repo | Admin | Write |
| Branch protection | 1 review required | 1 review required |
| Merge result | **HTTP 200**, merged | **HTTP 405**, blocked |

> "The bug is not in the agent. The bug is not in the token. The bug is in a permission model that lets the role of the user override the protection rule. The protection rule says 'I require a review.' The user role says 'I am an admin, so I can bypass.' Those two sentences contradict each other and the user role wins."

## Run: `./03-remediate.sh`

**Say:**

> "Step 4: now I fix it. GitHub released repository rulesets last year. They are the new way to define branch protection across an entire org or a single repo.
>
> I delete the classic branch protection rule. I install a ruleset that enforces the same 1-review rule. But this time I leave the bypass actors list empty. Admins are not in it. Nobody is in it."

**Show on terminal:**

- the classic protection is gone
- the new ruleset is created
- the GET back showing `bypass_actors: []`

**Point at the screen:**

> "Empty. The structural fix: the rule does not have a bypass clause. It is not that admins *choose* not to bypass. The rule *does not allow them to bypass.*

## Run: `./03-attack-admin-ruleset.sh`

**Say:**

> "Step 5: same attack. Same Admin persona. Same PAT. Same scopes. Same PR. Same merge call. Watch what happens now."

**Show on terminal:**

- the curl
- HTTP 405
- the response body

**Point at the screen:**

> "HTTP 405. The Admin token is now blocked. The agent could not have merged this PR, even if it tried, even with full admin credentials. The rule is enforced for everyone, including the people who own the repo."

Let the silence sit.

## Slide: closing

> "Two takeaways.
>
> One: the bug is not in your AI agent. The bug is in your permission model. When you give an agent a token, you are giving it everything the user behind that token can do. If that user can bypass branch protection, so can the agent. Fine-grained PATs do not fix this; they only make it harder to notice.
>
> Two: there is a structural fix available today. Repository rulesets. The fix is not a process change, not a doc change, not a policy change. The fix is to migrate to rulesets and leave the bypass actors list empty. If you take one thing from this talk, take this: go home tonight and migrate your most important repos to rulesets. Then go to bed. Tomorrow your agents will be a little less patient, but at least they will not bypass your review rules."

> "Thank you."

---

## Timing cheat sheet

| Step | Script | Talking time | Demo time | Total |
|---|---|---|---|---|
| Intro + slide | (slide) | 1:00 | 0:00 | 1:00 |
| Setup | `01-setup.sh` | 0:30 | 0:30 | 0:30 |
| Attack Admin | `02-attack-admin.sh` | 0:40 | 0:05 | 0:45 |
| Attack Writer | `02-attack-writer.sh` | 0:30 | 0:05 | 0:35 |
| The table | (slide) | 0:30 | 0:00 | 0:30 |
| Remediate | `03-remediate.sh` | 0:30 | 0:10 | 0:40 |
| Re-attack Admin | `03-attack-admin-ruleset.sh` | 0:30 | 0:05 | 0:35 |
| Closing | (slide) | 1:00 | 0:00 | 1:00 |
| **Total** | | **5:10** | **0:55** | **6:05** |

Pad with extra explanation if you have 10-15 minutes for the slot. Cut the introduction if you only have 5.
