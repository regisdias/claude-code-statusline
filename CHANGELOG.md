# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `install.sh` — one-line installer for Linux, WSL, macOS and Git Bash. Downloads the script, wires up
  `settings.json` (with a backup, and never clobbering an existing `statusLine`) and prints a preview.
- `scripts/testar.sh` — runs every payload through both implementations and diffs the bytes, plus a
  guard that the `.ps1` still carries its UTF-8 BOM.
- `scripts/payloads/` — six fixtures covering the green, yellow and red thresholds, a plan with no rate
  limits, an empty payload and malformed input.
- `scripts/gerar-svg.py` — renders the script's real ANSI output into the README's SVG terminal images.
- Continuous integration: ShellCheck, PSScriptAnalyzer and the cross-implementation comparison on every
  push and pull request.
- `README.pt-BR.md`, with the English README as the default and a language switcher on both.
- `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, issue and pull request templates.

### Changed

- README rebuilt: centered header, badges, generated screenshots, a before/after of the cost-based bar
  problem, and the install section moved to the top.

### Fixed

- **A full bar rendered 12 blocks wide instead of 10 on macOS.** `make_bar` drew with `seq`, and BSD
  `seq` infers its direction from the operands: `seq 1 0` prints `1` and `0` where GNU `seq` prints
  nothing. Any bar at 100% picked up two extra `░`. It now pads with `printf` and substitutes the
  spaces, which has no such edge case — and drops two subprocesses per bar.
- `statusline-command.ps1` no longer trips `PSAvoidUsingEmptyCatchBlock`. The `catch` around the
  console encoding is still deliberate: a terminal that refuses UTF-8 is no reason to stop drawing.

## [1.0.0] — 2026-09-12

### Added

- `statusline-command.sh` — statusline for Linux, WSL, macOS and Git Bash, reading the plan's 5-hour
  block and weekly limit straight from the payload's `rate_limits` rather than estimating from cost.
- `statusline-command.ps1` — same output, for Claude Code running natively on Windows, with no
  dependency beyond Windows PowerShell 5.1.
- Context window, 5-hour block, weekly limit and session cost, each dropping out on its own when the
  corresponding payload field is absent.
- Color thresholds: green to 60%, yellow to 85%, red above.

[Unreleased]: https://github.com/regisdias/claude-code-statusline/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/regisdias/claude-code-statusline/releases/tag/v1.0.0
