---
tipo: decisao
data: 2026-09-12
---

# CI runs on push and pull request, not only on `workflow_dispatch`

## Decision

`.github/workflows/ci.yml` triggers on `push` to `main`, `stg` and `develop`, on `pull_request`, and on
`workflow_dispatch`.

## Why

The general rule is to enable automatic CI only once `main` is in production, so the early phase of many
commits and pushes between developers does not get stuck. Here `main` **already is production**: the
README tells people to install with

```bash
curl -fsSL .../main/install.sh | bash
```

Everyone who installs pulls `main`'s `HEAD` directly. There is no published artefact between the commit
and the user, so a broken push is a broken install immediately — exactly the case where automatic CI
pays for itself.

The project is also a one-person one: there is no problem of workflows queueing for a runner.

## What CI covers

| Job | What it guarantees |
|---|---|
| `shellcheck` | Lints every shell script, `warning` severity |
| `powershell` | PSScriptAnalyzer on the `.ps1` files, errors and warnings |
| `versao` | `CCSL_VERSION` agrees across both implementations and the changelog |
| `bom` | The `.ps1` files kept their UTF-8 BOM — the trap in [[../bugs-fixes/2026-09-12-powershell-bom-e-colisao-de-variavel]] |
| `paridade` | `scripts/testar.sh` on Ubuntu **and macOS** — the only place the `date -r` path really runs |
| `windows` | Renders every payload on real Windows PowerShell 5.1 |
| `instalador` | `scripts/testar-instalador.sh`, pointed at the branch under test |
| `imagens` | The README images still match the current output |

The macOS `paridade` job is what caught the BSD `seq` bug, and later a byte-counting bug in the test
harness itself. Neither would have appeared without running on a real BSD.

## Consequence

A pull request from outside runs without secrets and does not need any: no job uses a credential.
`permissions` is set to `contents: read`.
