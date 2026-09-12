# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Nothing yet.

## [1.2.0] — 2026-09-12

### Added

- **The current git branch, at the start of the line** ([#1](https://github.com/regisdias/claude-code-statusline/issues/1)).
  Read live from `.git/HEAD` on every render, so it follows a `git checkout` mid-session, and dropped
  entirely outside a git repository.

  Claude Code does not send the branch in the payload — `workspace.repo` carries host/owner/name, and
  `worktree.branch` exists only inside a worktree session — and the documented approach is
  `git branch --show-current`. That is an exec of git per render, against this project's no-subprocess
  rule. Reading `.git/HEAD` costs a file open: 0.1 ms against 1.35 ms, and nothing spawned.

  Handled: branch names containing a slash, detached HEAD (short sha), `.git` as a file pointing at a
  worktree or submodule, a `HEAD` written with CRLF, a `HEAD` with no trailing newline, and
  walking up from a subdirectory.
- Branch fixtures in `scripts/testar.sh` covering all six of those cases plus the outside-a-repo one,
  so the two implementations are compared on them too.

### Changed

- CI now runs on `develop` and `stg` as well as `main`, following the branching model documented in
  `CONTRIBUTING.md`.

## [1.1.0] — 2026-09-12

### Changed

- **The bar's labels are in English.** `semana` → `week`, `· reseta` → `· resets`, `sessão $` →
  `session $`, and `aguardando...` → `waiting...`. The three Portuguese words sat in a line that is
  otherwise English, and read as a bug rather than a choice to anyone who does not speak it. The
  rendered line is the only thing that changed — no payload field, no colour, no spacing.

## [1.0.0] — 2026-09-12

First tagged release. `main` was already installable before this point, so anything below that reads
like a fix was a fix to what people could already `curl`.

### Added

- `statusline-command.sh` — statusline for Linux, WSL, macOS and Git Bash, reading the plan's 5-hour
  block and weekly limit straight from the payload's `rate_limits` rather than estimating from cost.
- `statusline-command.ps1` — same output, byte for byte, for Claude Code running natively on Windows,
  with no dependency beyond Windows PowerShell 5.1.
- Four segments — context window, 5-hour block, weekly limit and session cost — each dropping out on
  its own when the corresponding payload field is absent. A malformed payload renders `waiting...`
  rather than a stack trace.
- Colour thresholds: green to 60%, yellow to 85%, red above.
- `install.sh` — one-line installer for Linux, WSL, macOS and Git Bash. Downloads the script, wires up
  `settings.json` (with a backup, and never clobbering an existing `statusLine`) and prints a preview.
- `scripts/testar.sh` — runs every payload through both implementations and diffs the bytes, plus a
  guard that the `.ps1` still carries its UTF-8 BOM.
- `scripts/payloads/` — six fixtures covering the green, yellow and red thresholds, a plan with no rate
  limits, an empty payload and malformed input.
- `scripts/gerar-svg.py` and `scripts/gerar-social-preview.py` — the README images and the GitHub social
  card, both rendered from the script's real output.
- Continuous integration on every push and pull request: ShellCheck, PSScriptAnalyzer, the UTF-8 BOM
  guard, the cross-implementation comparison on Ubuntu **and macOS**, a real Windows PowerShell 5.1
  render, and a check that the README images still match the current output.
- `README.pt-BR.md`, with the English README as the default and a language switcher on both.
- `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, issue and pull request templates.

### Fixed

- **A full bar rendered 12 blocks wide instead of 10 on macOS.** `make_bar` drew with `seq`, and BSD
  `seq` infers its direction from the operands: `seq 1 0` prints `1` and `0` where GNU `seq` prints
  nothing, so any bar at 100% picked up two extra `░`. It now pads with `printf` and substitutes the
  spaces, which has no such edge case — and drops six subprocesses per render along the way.
- `statusline-command.ps1` no longer trips `PSAvoidUsingEmptyCatchBlock`. The `catch` around the
  console encoding is still deliberate: a terminal that refuses UTF-8 is no reason to stop drawing.

[Unreleased]: https://github.com/regisdias/claude-code-statusline/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/regisdias/claude-code-statusline/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/regisdias/claude-code-statusline/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/regisdias/claude-code-statusline/releases/tag/v1.0.0
