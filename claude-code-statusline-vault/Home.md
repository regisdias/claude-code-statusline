---
tipo: home
atualizado: 2026-09-13
---

# claude-code-statusline

A [Claude Code](https://claude.com/claude-code) status line showing the context window and your **real
plan usage** — the 5-hour block and the weekly limit — by reading `rate_limits` from the payload Claude
Code hands to the status line. The same numbers as `/usage`.

Public repository, MIT licence. Installing and using it are covered in the README
([English](../README.md) · [Portuguese](../README.pt-BR.md)); this is where the reasoning behind the
decisions lives, and what is still open.

## Where to start

| Topic | Note |
|---|---|
| How the script works inside | [[arquitetura/como-a-statusline-funciona]] |
| Why there are two implementations | [[decisoes/duas-implementacoes-shell-e-powershell]] |
| Why usage comes from the payload rather than estimated cost | [[decisoes/uso-do-plano-vem-do-payload]] |
| Which language goes where | [[decisoes/readme-em-ingles-e-arquivos-de-comunidade]] |
| Why CI runs on push and pull request | [[decisoes/ci-em-push-e-pr]] |
| Branching model: main → stg → develop → task | [[decisoes/fluxo-de-branches]] |
| Why the branch comes from `.git/HEAD` and not from `git` | [[decisoes/branch-vem-do-git-head]] |
| Why the update notice is opt-in and lives outside the bar | [[decisoes/aviso-de-atualizacao-opt-in]] |
| How the segment order is configured | [[decisoes/ordem-dos-trechos-configuravel]] |
| Why the bar wraps itself | [[decisoes/quebra-na-largura-do-terminal]] |
| Why the branch says `git` rather than a glyph | [[decisoes/rotulo-da-branch-em-texto]] |
| Testing without opening Claude Code | [[guias/testar-local]] |
| Regenerating the README images | [[guias/regenerar-imagens-do-readme]] |
| Validating on a Mac | [[guias/validar-no-macos]] |
| PowerShell traps that already cost us | [[bugs-fixes/2026-09-12-powershell-bom-e-colisao-de-variavel]] |
| Why a full bar came out crooked on macOS | [[bugs-fixes/2026-09-12-seq-do-bsd-alargava-a-barra-cheia-no-macos]] |
| Why the cost read `$12,00` on a Mac set to Portuguese | [[bugs-fixes/2026-09-13-locale-com-virgula-quebrava-os-numeros]] |

## Open items

None.

Resolved ones live in `pendentes/arquivo/` — the most recent is
[[pendentes/arquivo/2026-09-13-glifo-da-branch-no-macos|swapping `⎇` for `git`]] (CCS-4), which closed
alongside [[pendentes/arquivo/2026-09-12-confirmar-no-macos|validating on macOS]] (CCS-1).

## What is generated, not written by hand

| File | Comes from |
|---|---|
| `assets/demo.svg`, `assets/demo-fallback.svg` | `python3 scripts/gerar-svg.py`, from the script's real output |
| `assets/social-preview.png` | `python3 scripts/gerar-social-preview.py` — the GitHub share card |

Changed the bar's format? Regenerate and commit it in the same change — CI fails if they fall behind.

## Vault structure

Folder names stay in Portuguese: they are the contract with the maintainer's cross-project vault
tooling, which greps for exactly these strings. Everything a person reads is in English.

| Folder | What goes in |
|---|---|
| `pendentes/` | One note per open item; `arquivo/` holds the resolved ones |
| `decisoes/` | The standing decision and the reason for it |
| `arquitetura/` | How the script works and where the data comes from |
| `guias/` | How-to: testing, publishing, debugging |
| `bugs-fixes/` | Problem found, cause and fix |
| `planos/` | Execution plans; `arquivo/` for finished ones |
| `roadmap/` | What is intended to be added |
| `reunioes/` | Minutes, if any |
| `_assets/` | Images used by the notes |
