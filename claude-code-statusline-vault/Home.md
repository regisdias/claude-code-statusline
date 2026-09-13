---
type: home
updated: 2026-09-13
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
| How the script works inside | [[architecture/how-the-status-line-works]] |
| Why there are two implementations | [[decisions/two-implementations-shell-and-powershell]] |
| Why usage comes from the payload rather than estimated cost | [[decisions/plan-usage-comes-from-the-payload]] |
| Which language goes where | [[decisions/english-and-the-community-files]] |
| Why CI runs on push and pull request | [[decisions/ci-on-push-and-pull-request]] |
| Branching model: main → stg → develop → task | [[decisions/branching-model]] |
| Why the branch comes from `.git/HEAD` and not from `git` | [[decisions/branch-from-git-head]] |
| Why the update notice is opt-in and lives outside the bar | [[decisions/opt-in-update-notice]] |
| How the segment order is configured | [[decisions/configurable-segment-order]] |
| Why the bar wraps itself | [[decisions/wrap-to-terminal-width]] |
| Why the bar warns about pace, and when it stays quiet | [[decisions/pace-projection]] |
| Why the branch says `git` rather than a glyph | [[decisions/branch-label-as-text]] |
| Testing without opening Claude Code | [[guides/testing-locally]] |
| Regenerating the README images | [[guides/regenerating-readme-images]] |
| Validating on a Mac | [[guides/validating-on-macos]] |
| PowerShell traps that already cost us | [[bugs-fixes/2026-09-12-powershell-bom-and-variable-collision]] |
| Why a full bar came out crooked on macOS | [[bugs-fixes/2026-09-12-bsd-seq-widened-the-full-bar-on-macos]] |
| Why the cost read `$12,00` on a Mac set to Portuguese | [[bugs-fixes/2026-09-13-comma-locale-broke-the-numbers]] |

## Open items

None.

Resolved ones live in `pending/archive/` — the most recent is
[[pending/archive/2026-09-13-branch-glyph-on-macos|swapping `⎇` for `git`]] (CCS-4), which closed
alongside [[pending/archive/2026-09-12-confirm-on-macos|validating on macOS]] (CCS-1).

## What is generated, not written by hand

| File | Comes from |
|---|---|
| `assets/demo.svg`, `assets/demo-fallback.svg` | `python3 scripts/generate-svg.py`, from the script's real output |
| `assets/social-preview.png` | `python3 scripts/generate-social-preview.py` — the GitHub share card |

Changed the bar's format? Regenerate and commit it in the same change — CI fails if they fall behind.

## Vault structure

Folder names stay in Portuguese: they are the contract with the maintainer's cross-project vault
tooling, which greps for exactly these strings. Everything a person reads is in English.

| Folder | What goes in |
|---|---|
| `pending/` | One note per open item; `arquivo/` holds the resolved ones |
| `decisions/` | The standing decision and the reason for it |
| `architecture/` | How the script works and where the data comes from |
| `guides/` | How-to: testing, publishing, debugging |
| `bugs-fixes/` | Problem found, cause and fix |
| `plans/` | Execution plans; `arquivo/` for finished ones |
| `roadmap/` | What is intended to be added |
| `meetings/` | Minutes, if any |
| `_assets/` | Images used by the notes |
