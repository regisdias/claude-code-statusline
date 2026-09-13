---
type: guide
date: 2026-09-13
---

# Validating on macOS — step by step

Written to close [[../pending/archive/2026-09-12-confirm-on-macos|CCS-1]], now resolved; still the
way to validate any change on a Mac. Done on a real Mac, not on a runner: CI covers the rest.

**What only a Mac answers:** whether the glyphs draw on screen, and whether the reset time comes out
right in a timezone that is not UTC. The GitHub runner has no screen and runs in UTC.

## 1. Before starting

```bash
brew install jq
```

The terminal has to be in UTF-8 — in Terminal.app that is Settings → Profiles → Advanced → Text
encoding. Without it the blocks come out as question marks and you diagnose a bug that does not exist.

> **Mind the bash.** macOS's `/bin/bash` is version **3.2**, from 2007, because of the bash 4 licence.
> The script's shebang is `#!/usr/bin/env bash`, so it picks the first `bash` on the PATH — which may be
> Homebrew's (5.x) rather than the system one. **Both have to work**, and the diagnostic below runs both
> on purpose.

## 2. Install the way anyone else would

Do not run it from the clone. What matters is the path an outsider walks:

```bash
curl -fsSL https://raw.githubusercontent.com/regisdias/claude-code-statusline/main/install.sh | bash
```

Expected: the three `✓` lines, and a preview of the bar.

## 3. The diagnostic, in one paste

Run this **inside the clone** and send the whole output to Claude:

```bash
bash -c '
R=$(mktemp -d); mkdir -p "$R/.git"; printf "ref: refs/heads/main\n" > "$R/.git/HEAD"
C=$(mktemp -d)
P=$(jq -nc --arg d "$R" --argjson t "$(date +%s)" "{
  model:{display_name:\"Opus 5 (1M context)\"}, cost:{total_cost_usd:12.3456},
  workspace:{current_dir:\$d},
  context_window:{used_percentage:33,context_window_size:1000000,current_usage:{input_tokens:330000}},
  rate_limits:{five_hour:{used_percentage:41,resets_at:(\$t+7200)},
               seven_day:{used_percentage:11,resets_at:(\$t+259200)}}}")

echo "== ENVIRONMENT =="
sw_vers 2>/dev/null | tr "\n" " " || echo "(no sw_vers: not macOS)"; echo
echo "bash on PATH  : $(bash --version | head -1)"
echo "system bash   : $(/bin/bash --version | head -1)"
if date --version >/dev/null 2>&1; then echo "date          : GNU, $(date --version | head -1)"
else echo "date          : BSD (no --version) — the path this guide exists to exercise"; fi
echo "timezone      : $(date +%Z%z)  |  locale: ${LANG:-unset}"
echo "jq            : $(jq --version)"
echo "TERM          : $TERM  |  TERM_PROGRAM: ${TERM_PROGRAM:-?}"

echo; echo "== BAR, bash on PATH =="
printf "%s" "$P" | CLAUDE_CONFIG_DIR=$C bash statusline-command.sh; echo
echo; echo "== BAR, /bin/bash 3.2 =="
printf "%s" "$P" | CLAUDE_CONFIG_DIR=$C /bin/bash statusline-command.sh; echo

echo; echo "== FULL BAR (the BSD seq case) =="
printf "%s" "$P" | jq -c ".rate_limits.five_hour.used_percentage=100" \
  | CLAUDE_CONFIG_DIR=$C bash statusline-command.sh; echo

echo; echo "== CONFIGURED ORDER =="
printf "{\"ccsl\":{\"order\":[\"ctx\",\"branch\"]}}\n" > "$C/settings.json"
printf "%s" "$P" | CLAUDE_CONFIG_DIR=$C bash statusline-command.sh; echo
rm -f "$C/settings.json"

echo; echo "== NARROW TERMINAL (the wrap) =="
printf "%s" "$P" | COLUMNS=60 CLAUDE_CONFIG_DIR=$C bash statusline-command.sh; echo

echo; echo "== FRACTIONAL NUMBERS UNDER YOUR LOCALE =="
printf "%s" "$P" | jq -c ".rate_limits.five_hour.used_percentage=84.7" \
  | CLAUDE_CONFIG_DIR=$C bash statusline-command.sh; echo

echo; echo "== FIRST BYTES OF THE LINE (what the script emitted, not what you see) =="
printf "%s" "$P" | CLAUDE_CONFIG_DIR=$C bash statusline-command.sh \
  | sed "s/\x1b\[[0-9]*m//g" | head -c 24 | xxd
echo "expected: 67 69 74 20 = \"git \", then \"main\""
echo "reference for the others: $(printf "█░│↑" | xxd | head -1)"
'
```

## 4. What to look at, and what each thing means

| Check | Right | Wrong means |
|---|---|---|
| **The two bashes** | identical output | incompatibility with bash 3.2 — a bug, and a serious one: it is the Mac's default bash |
| **`git` before the branch** | the word | anything else: a `ccsl.branch_icon` in your real `settings.json` does not reach here — the diagnostic uses an empty config |
| **`█` and `░`** | solid and light blocks | a box or `?`: terminal not in UTF-8 |
| **`│`** | a thin vertical bar | same |
| **Bar width** | always **10** blocks, including at 100% | 12 blocks = the `seq` bug came back |
| **`resets HH:MM`** | two hours from now, on **your** clock | wrong or blank = BSD `date -r` |
| **`18/09 05:00`** | three days from now | same |
| **The wrap at 60 columns** | several rows, nothing cut | one long row = `COLUMNS` did not arrive |
| **`84.7` renders as `85%`** | `85%` | `0%` or a comma in the cost = the locale fix regressed |

**The distinction that matters for glyphs:** if the bytes are right (compare with the reference line) but
the screen shows `?`, the problem is the terminal font — the script is correct. Only the reverse is our
bug.

> Up to v1.5.0 the branch carried the `⎇` glyph, and this table checked it. On the Mac it read as the
> Option key, and it became `git` — see [[../decisions/branch-label-as-text]].

## 5. Closing an open item

- **All correct:** the note becomes `status: resolved`, gains a line saying which macOS and which
  terminal it was verified on, and moves with `git mv` into `pending/archive/` in the same commit.
- **Only one glyph comes out wrong:** open a note of its own — that is how `⎇` became `git` (CCS-4).
- **Any other divergence:** a new issue with the full diagnostic output, and the original note stays
  open until it is resolved.

See also [[testing-locally]].
