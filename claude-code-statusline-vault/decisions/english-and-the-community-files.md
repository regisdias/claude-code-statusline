---
type: decision
date: 2026-09-12
updated: 2026-09-13
---

# English at the front door, and the community file set

## Decision

`README.md` is **in English**; Portuguese lives in `README.pt-BR.md`, with a language switcher at the
top of both. It used to be one file with the two languages in sequence.

Alongside it came the files GitHub recognises and surfaces on its own: `CONTRIBUTING.md`,
`SECURITY.md`, `CODE_OF_CONDUCT.md`, `CHANGELOG.md`, `.github/ISSUE_TEMPLATE/` and
`.github/PULL_REQUEST_TEMPLATE.md`.

## Why

The project's audience is people using Claude Code, and that audience is mostly international — whoever
arrives from GitHub search or a link does not read Portuguese. A bilingual README in one file solved
that, but at the cost of doubling its length: a newcomer had to scroll past a language they do not read
to find the install section.

The community set is not bureaucracy: GitHub assembles the *community profile* from those files and uses
their presence in ranking and in the notices it shows whoever opens an issue. The issue templates also
filter, at the door, the three questions that would otherwise repeat — the Claude Code version, the
payload that reproduces it, and whether the `.ps1` kept its BOM.

## The bar's labels followed

`semana`, `sessão` and `reseta` became `week`, `session` and `resets` shortly after — the bar is the
first thing a person sees, and three Portuguese words in the middle of it read as a bug. The story is in
[[../pending/archive/2026-09-12-bar-labels-in-portuguese]].

## The rule is by category: English everywhere except `README.pt-BR.md`

| Surface | Language |
|---|---|
| Default README (`README.md`) | English — `README.pt-BR.md` sits beside it |
| The bar's labels | English |
| `install.sh` output | English |
| Commit messages | English, Conventional Commits |
| Release titles and bodies | English |
| Pull requests and issues | English |
| Issue and pull request templates | English |
| `CLAUDE.md` | English |
| **This vault** | **English** |
| What the test scripts print | English |
| `README.pt-BR.md` | Portuguese — the only one |

Two structural exceptions, which are not editorial: **vault folder names** (`decisions/`, `pending/`,
`guides/`…) and the **frontmatter values** the maintainer's cross-project vault tooling greps for
(`type: pending`, `status: open|fazendo|resolvido`). Renaming those would break tooling outside this
repository for no reader benefit. Everything a person reads inside the files is English.

## It took two tries to state the rule correctly

The first version said "commit messages are in English", and listed what stayed Portuguese: the vault,
and the test output. **Releases were in neither list**, so nothing contradicted writing them in
Portuguese — and seven of them went out that way, four written after the rule existed. A release is more
visible than a commit: it is what shows on the repository home page and in the feed of anyone watching.
See [issue #39](https://github.com/regisdias/claude-code-statusline/issues/39).

The lesson is about how rules are written, not about this rule: **state the category, not the example.**
A rule that enumerates surfaces creates a blind spot for every surface it did not think of. The question
for a new one is "does someone outside read this?", not "did the rule name this surface?".

The second try then went further and took the vault with it: the maintainer's call, on the grounds that
a public repository has no half-public documentation.

## Why the log matters

In a public repository `git log` is documentation. It is where someone goes to find out why a line is
the way it is — and this project has several of those: BSD `seq`, the PowerShell BOM, `read` returning
an error while still filling the variable. That reasoning was written in a language most readers of the
repository do not speak.

**History stays as it is.** Rewriting it would change every SHA already published in the releases, the
pull requests and the CHANGELOG links, to retranslate commits nobody will read again. The seven release
notes *were* rewritten, since editing them changes no SHA.

## Consequence

A content change in the README lands in **both** files. Neither is generated from the other: they are
sibling texts, maintained by hand.
