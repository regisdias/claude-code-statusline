---
type: decision
date: 2026-09-13
---

# The branch carries the word `git`, with an optional icon

## Decision

The branch segment is `git main` by default. Anyone who wants an icon sets `ccsl.branch_icon` in
`settings.json` — typically `""`, the Powerline branch icon, for those with a Nerd Font.
Issue #35, replacing the `⎇` that #11 had introduced.

## Why

`⎇` was chosen in #11 for being real Unicode and one column wide. In Windows Terminal it looks like a
fork. **On macOS it looks like the Option key** — seen on screen, in Terminal.app, during
[[../pending/archive/2026-09-12-confirm-on-macos|CCS-1]].

It is not a font defect. U+2387 is named *ALTERNATIVE KEY SYMBOL*, and on the Mac it is drawn by Lucida
Grande, the same font behind `⌥`. The Mac draws what the name says.

The alternatives, checked in [[../pending/archive/2026-09-13-branch-glyph-on-macos|CCS-4]]:

- **There is no standard Unicode glyph for git.** The icons every prompt uses — Powerline's `U+E0A0`,
  the Nerd Fonts' `U+F418` and `U+E725` — sit in the private use area. Without the font they become a
  box; on the test Mac, even with a Nerd Font installed, because the terminal profile was not using it.
- **Other Unicode candidates** (`⑂` U+2442, `ᚠ`) have worse coverage and are not recognisable as git.
- **The popular prompts with no font dependency use a word or nothing**: `git:(main)` in robbyrussell,
  just `main` in Pure.

A word is the only default that reads the same in every terminal, and it matches the other segments,
which are already labels (`ctx`, `5h`, `week`, `session`). The configurable icon gives the look back to
whoever has the font.

## How it works

- **The same `jq` call** that reads `ccsl.order` — no extra process per render. The field goes last in
  the TSV as `<width>:<icon>`, which is never empty: `""` is a valid icon, and an empty field would
  collapse in `read` with a tab `IFS`.
- **The width is computed, not measured.** Since the
  [[../bugs-fixes/2026-09-13-comma-locale-broke-the-numbers|locale fix]] the shell runs under
  `LC_ALL=C` and counts bytes. A configured icon is unknown, so it cannot be listed in the glyph folding
  of [[wrap-to-terminal-width]]: `jq` counts one column per code point, two outside the BMP, and
  the shell folds the icon to that many `#`. That is exactly what PowerShell's `.Length` gives, because
  a character outside the BMP is two UTF-16 units.
- **Control characters and backslashes are discarded** in both implementations. The shell prints with
  `%b`, and a configuration value must not be able to inject an escape into the bar.
- A value that is not a string (a number, `null`, an object) counts as absent: `git`.

`test.sh` covers the values (section 8) and the wrap exactly at the boundary, with a 3-byte icon and a
4-byte emoji — confirmed red without the icon folding.

## Cost

It changes the default bar for everyone, hence a minor version. Anyone who liked `⎇` gets it back with
one line.
