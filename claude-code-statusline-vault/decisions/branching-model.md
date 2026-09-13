---
type: decision
date: 2026-09-12
---

# main → stg → develop → task branch

## Decision

Nothing goes straight into `main`. Work moves upward:

```
feat/1-git-branch-in-bar  →  develop  →  stg  →  main
```

| Branch | Role |
|---|---|
| `main` | Production. The README installs with `curl .../main/install.sh`. Protected: pull request and green CI required. |
| `stg` | Staging: the release candidate before promotion. Protected the same way. |
| `develop` | Integration. Finished work accumulates here between releases. |
| `<type>/<issue>-<description>` | One task each, branched off `develop`. |

Task branch name: `<type>/<issue number>-<short-description>`, with `<type>` matching the Conventional
Commits type the work will use — `feat/1-git-branch-in-bar` produces `feat: …` and a minor bump. The
issue comes first; the number is what ties the two together.

## Why

Up to v1.1.0 everything was committed straight to `main`. It worked because this is a one-person
project, but the repository is public: whoever looks at the history sees how the project is run, and
committing directly to the production branch does not give the right impression — nor does it give CI a
chance to stop anything first.

What the separation buys, in practice:

- **A protected `main`** means `main` does not break by accident. Since there is no artefact between the
  commit and whoever installs, a broken push is a broken install immediately.
- **`stg` existing** gives the release candidate somewhere to sit without blocking `develop`.
- **A branch per task** makes the pull request the unit of review, with CI running on the isolated diff.

## Consequences

- CI runs on `push` to `main`, `stg` and `develop`, and on `pull_request` for all three.
- Protection enabled on `main` and `stg`: pull request required, checks green. `develop` was left open,
  otherwise every working adjustment would become a pull request.
- **Zero required approvals**, because GitHub does not let anyone approve their own pull request and
  this is a one-person project. That is the honest weak point of the arrangement: the pull request
  documents and CI blocks, but review by another person only happens when another person shows up.
- Tags are cut from `main` only, and the `CHANGELOG` is updated under `Unreleased` in the same pull
  request as the change.

## Linear history stays **off** on main and stg

It looks counterintuitive in a repository trying to look well kept, but `required_linear_history`
forbids merge commits — and in a promotion chain that breaks everything.

With linear history required, `develop → stg` would have to be a *squash* or a *rebase*. Both rewrite
SHAs: `stg` would receive new commits, different from `develop`'s, and the two would diverge forever.
The next promotion would bring `develop`'s entire history again, as if it were new.

A merge commit is precisely what keeps `develop`, `stg` and `main` on one lineage: each promotion is a
clean merge, because the tip of one is always an ancestor of the other.

Linear history still applies to the **task branch**, which enters `develop` squashed — one commit per
task, and `develop` is not protected.

**`strict` is off too**, for the same family of reason. "Require branches to be up to date before
merging" means `develop` is permanently behind `stg` by exactly the promotion merge commits, so every
cycle would demand a back-merge just to satisfy the checker. Verified before switching it off that the
divergence was topology and not content: `git diff develop...stg` came back empty.

See also [[ci-on-push-and-pull-request]].
