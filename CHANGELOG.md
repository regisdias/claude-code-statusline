# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **The branch segment reads `git main` instead of `⎇ main`**
  ([#35](https://github.com/regisdias/claude-code-statusline/issues/35)). On macOS, U+2387 is drawn as
  the Option key symbol, not as a branch — it is literally *ALTERNATIVE KEY SYMBOL*. There is no standard
  Unicode glyph for git, and the real icons need a Nerd Font, so the default is now a word, like every
  other segment.

### Added

- **`ccsl.branch_icon`** replaces the `git` label: `"\ue0a0"` for the Powerline icon with a Nerd Font,
  `"⎇"` for the old look, `""` for the bare branch name. Read in the same `jq` call as `ccsl.order`.
  The wrap counts the icon in columns — one per code point, two outside the BMP — so the shell, which
  counts bytes, and PowerShell break at the same place. Control characters and backslashes are dropped.
  `--configure` previews with your own icon.

### Fixed

- `ccsl-install.sh --configure` exited silently when `settings.json` was missing: under `set -e`, a
  failing `jq` inside an assignment ended the script before the menu.

## [1.5.0] — 2026-09-13

### Added

- **The bar wraps to the terminal width**
  ([#28](https://github.com/regisdias/claude-code-statusline/issues/28)). A long branch name used to
  push the tail of the line off screen; now the segments are packed into as many rows as the window
  needs, breaking only *between* them so nothing is cut. Nothing to configure, and a wide terminal still
  gets one line.

  Claude Code sets `COLUMNS` before running the command, which is where the width comes from. Missing or
  non-numeric means one line, as before. A segment wider than the whole terminal takes a row of its own
  and overflows — splitting inside one would hide what you are trying to read.

  The measurement had to be locale-proof: `${#s}` counts *bytes* when the locale is not UTF-8, and the
  status line often runs with no `LANG`. The same line measures 31 under `C.UTF-8` and 55 under `C`,
  because `█` is three bytes. Folding each glyph to one ASCII character before counting gets the right
  answer either way, with no subprocess.

## [1.4.1] — 2026-09-13

### Fixed

- **Session cost and plan limits came out wrong under a comma-decimal locale**
  ([#27](https://github.com/regisdias/claude-code-statusline/issues/27)). With `LANG=pt_BR.UTF-8` or
  `de_DE.UTF-8`, `awk` read `12.3456` as `12` and bash's `printf` rejected `84.7`, so the bar showed
  `session $12,00` and a `0%` plan limit whenever the percentage was fractional. The shell script now
  formats numbers in the C locale, and `testar.sh` renders under `pt_BR` and `de_DE` and compares with
  the C output. The PowerShell side already used `InvariantCulture` and was never affected.

## [1.4.0] — 2026-09-13

### Added

- **Choose which segments appear, and in what order**
  ([#19](https://github.com/regisdias/claude-code-statusline/issues/19)). One list does both jobs — a
  segment left out of `ccsl.order` does not render.

  ```json
  { "ccsl": { "order": ["branch", "ctx", "5h", "session"] } }
  ```

  `ccsl-install.sh --configure` lists the segments *as your own status line draws them*, takes the
  numbers in the order you want, previews the result and saves on confirmation. It reads from
  `/dev/tty`, so it works even when the installer arrived through `curl | bash`, and falls back to
  stdin, which makes it scriptable.

  The config lives in Claude Code's `settings.json` under a top-level `ccsl` key — verified empirically
  that Claude Code accepts an unknown top-level key. It costs no extra process on the render path:
  `jq --slurpfile` reads the payload and the settings file in the same invocation.
- A normal install now keeps a copy of the installer at `~/.claude/ccsl-install.sh`.

### Changed

- **The separator is uniform.** `model` became a segment of its own so it can be moved or removed, and
  it used to be glued to `ctx` with two spaces rather than the `│`. Reordering only makes sense with one
  rule, so everything is `│`-separated now:

  ```
  before:  ⎇ main  │  Opus 5 (1M context)  ctx [███░░░░░░░] 33%
  after:   ⎇ main  │  Opus 5 (1M context)  │  ctx [███░░░░░░░] 33%
  ```

  This changes the bar for everyone, with no opt-out short of configuring an order.

### Fixed

- The README told people to run `~/.claude/install.sh` for the update-check flags, but the installer
  never put itself there. It does now, as `ccsl-install.sh`, and both READMEs point at the real path.

## [1.3.0] — 2026-09-12

### Added

- **An optional update notice** ([#13](https://github.com/regisdias/claude-code-statusline/issues/13)),
  off unless you run `install.sh --enable-update-check`. A `SessionStart` hook asks GitHub for the
  latest release at most once a day and says so at the top of the session; the bar carries a `↑1.3.0`
  segment until you update.

  A status line cannot be interactive, so there is no "press Y" — what it gives you is the line to copy.

  The check is split from the bar deliberately: the hook makes the request and writes the cache, the bar
  only reads it. So `SECURITY.md`'s claim that the status line opens no network connection and writes
  nothing stays literally true whether the check is on or off.
- `CCSL_VERSION` in both implementations, with a CI job that fails when the two drift from each other or
  from the newest version in this file.

### Changed

- **The branch segment is marked with `⎇`** ([#11](https://github.com/regisdias/claude-code-statusline/issues/11)).
  Bare, `main` could be read as a model, a profile or a session name. U+2387 is one column wide, so it
  does not disturb the alignment an emoji would. Fonts without the glyph render it as `?` — display
  only, and now in the troubleshooting table.

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

[Unreleased]: https://github.com/regisdias/claude-code-statusline/compare/v1.5.0...HEAD
[1.5.0]: https://github.com/regisdias/claude-code-statusline/compare/v1.4.1...v1.5.0
[1.4.1]: https://github.com/regisdias/claude-code-statusline/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/regisdias/claude-code-statusline/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/regisdias/claude-code-statusline/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/regisdias/claude-code-statusline/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/regisdias/claude-code-statusline/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/regisdias/claude-code-statusline/releases/tag/v1.0.0
