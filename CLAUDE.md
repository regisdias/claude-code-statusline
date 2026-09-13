# claude-code-statusline

A Claude Code status line in two implementations: `statusline-command.sh` (Linux, WSL, macOS, Git Bash)
and `statusline-command.ps1` (native Windows, PowerShell 5.1+). Public repository.

## The central rule: both implementations print the same thing

For the same payload, the shell and the PowerShell side return **the same bytes**. A format change lands
in both in the same commit.

```bash
bash scripts/testar.sh
```

Runs every payload in `scripts/payloads/` through both implementations, diffs the bytes and checks the
`.ps1` BOM. Without `pwsh` installed it tests the shell side only and says so. It is the same command CI
runs.

## Map of the repository

| Path | What it is |
|---|---|
| `statusline-command.sh` / `.ps1` | The two implementations — the product |
| `install.sh` | The one-line installer the README points at (Linux, WSL, macOS, Git Bash) |
| `scripts/payloads/` | Test payloads: green, yellow, red, no limits, empty, invalid |
| `scripts/testar.sh` | Cross-implementation comparison + the BOM guard |
| `scripts/testar-instalador.sh` | Installer suite; needs the network, skips itself without it |
| `scripts/gerar-svg.py` | Generates the README images from the real output |
| `scripts/gerar-social-preview.py` | Generates the 1280x640 share card (uploaded to GitHub by hand) |
| `assets/` | **Generated.** Do not edit by hand — see below |
| `README.md` / `README.pt-BR.md` | English is the front door; content lands in both |
| `hooks/ccsl-update-check.{sh,ps1}` | Update notice — **opt-in**, the only component that uses the network |
| `.github/` | CI, issue and pull request templates |

The `branch/*` cases in `scripts/testar.sh` build their `.git/HEAD` fixtures at run time: git refuses to
track a path containing `.git`.

## Documentation lives in two places

- **README (English and pt-BR):** installing and using. This is what an outsider reads.
- **Vault (`claude-code-statusline-vault/`):** why things are the way they are, and what is still open.

A content change in the README lands in **both** files — neither is generated from the other.

## `assets/` is generated

`assets/demo.svg` and `assets/demo-fallback.svg` come from:

```bash
python3 scripts/gerar-svg.py             # regenerate
python3 scripts/gerar-svg.py --verificar # what CI runs
```

Changed the bar's format? Regenerate and commit it in the same change. `--verificar` ignores the reset
clock and the `x` coordinates — without that it would fail every midnight.

`assets/social-preview.png` comes from `scripts/gerar-social-preview.py` (needs `npx`, rasterises with
sharp-cli). GitHub has no API for it: upload it by hand under Settings → General.

## Known traps

- The `.ps1` has to stay **UTF-8 with BOM**: without it, PowerShell 5.1 reads the file as ANSI and the
  script does not compile. Check with `head -c3 statusline-command.ps1 | xxd -p` (must be `efbbbf`).
  `.gitattributes` keeps the file at CRLF for the same reason — do not normalise it.
- **PowerShell variables are case-insensitive:** `$reset` and `$RESET` are the same one. Never name a
  local that differs from a constant only by case.
- A new payload field may only be used once both implementations support it, and always with
  degradation: a missing field must not break the bar, and an error must never become a stack trace in
  the terminal.
- No dependency that boots a runtime on every render: the target is ~50 ms per execution.
- **The branch does not come in the payload.** Claude Code sends `workspace.repo` (host/owner/name) and
  `worktree.branch` (worktree sessions only). The branch comes from reading `.git/HEAD` directly —
  `git branch --show-current` would be an exec per render. Both implementations must handle the same
  cases: `.git` as a directory and as a file (`gitdir:`), detached HEAD (short sha), a trailing CR, and
  walking up from a subdirectory.
- **The bar wraps itself at `$COLUMNS`**, which Claude Code sets before running the command. It breaks
  only **between** segments. `${#s}` counts **bytes** outside a UTF-8 locale and the status line often
  runs with no `LANG` — so the width is measured by folding each known glyph (`█ ░ │ ↑ ·`) to one ASCII
  character before counting, and the branch icon to the width `jq` computed. Do not replace that with a
  plain `${#s}`.
- **`gerar-svg.py` pins `COLUMNS=999`**, or the README image would come out differently on every
  machine.
- **The segment order comes from `ccsl.order` in `settings.json`**, read in the **same** `jq` call via
  `--slurpfile` — no second process per render. A missing key, an empty list, an unknown name or broken
  JSON all fall back to the default order; the bar never goes blank because of configuration.
- **The branch carries the word `git`, not a glyph.** `⎇` (U+2387) is drawn as the Option key on macOS,
  and real git icons require a Nerd Font. Anyone who wants an icon sets `ccsl.branch_icon`. Do not put a
  glyph back in the default — the reasoning is in `decisoes/rotulo-da-branch-em-texto.md`.
- **The separator is uniform (`│`).** Do not reintroduce a spacing exception between segments: that is
  exactly what made reordering impossible.
- **`case`, not an associative array**, in the assembly: macOS still ships bash 3.2.
- **The bar makes no network call and writes nothing, and `SECURITY.md` promises that in writing.** The
  update hook does both; it is opt-in and runs once per session, and the bar only ever **reads** the
  cache. Do not move that boundary.
- **`CCSL_VERSION` exists in both implementations** and is bumped in the same commit that stamps the
  version in `CHANGELOG.md`. CI fails if the three disagree.
- **`seq` does not belong on the render path:** the BSD one infers direction, and `seq 1 0` prints
  `1 0`, which already widened a full bar on macOS. Padding with `printf` and substituting has no edge
  case.
- **Numbers are formatted in the C locale (`export LC_ALL=C` at the top of the `.sh`).** `awk` and
  bash's `printf` format by `LC_NUMERIC`: under `pt_BR` the cost became `$12,00` and a fractional
  percentage became `0%` (#27). The `.ps1` does the same with `InvariantCulture`. Do not format a number
  outside those two guarantees.
- CI lints with `shellcheck --severity=warning`. Suppress only with a comment explaining why.

## The project vault

Decisions and open items are documented in the Obsidian vault at `claude-code-statusline-vault/`,
versioned alongside the code. **Single entry point: `claude-code-statusline-vault/Home.md`.**

- **Read the Home** before deciding anything or entering an area you do not know. A mechanical task
  (adjusting text, running a test, fixing a reported error) does not need the vault.
- **What goes in each folder:** `pendentes/` (one note per open item, resolved ones in
  `pendentes/arquivo/`), `decisoes/`, `arquitetura/`, `guias/`, `bugs-fixes/`, `planos/` (with
  `arquivo/`), `roadmap/`, `reunioes/`, `_assets/`.
- **Open-item format:** `tipo: pendente`, `status: aberto|fazendo|resolvido`, `data: YYYY-MM-DD` and an
  optional `prazo`. On resolving: `status: resolvido`, a line saying how it was resolved, and `git mv`
  into `pendentes/arquivo/` in the same commit.

  Folder names and these frontmatter values stay in Portuguese on purpose: they are the contract with
  the maintainer's cross-project vault tooling, which greps for exactly these strings. Everything a
  person reads — titles, prose, tables — is in English.
- **A vault change is committed and pushed** (`docs(vault): …`) without waiting to be asked.
- **What does not go in the vault:** session narration, anything `git log` already tells, secrets, and
  nothing personal — the repository is public.

`claude-code-statusline-vault/.obsidian/` stays out of git (each person's local configuration).

## Git

**Nothing goes straight into `main`.** Work moves upward:

```
feat/12-short-description  →  develop  →  stg  →  main
```

| Branch | What it is |
|---|---|
| `main` | Production. The README installs with `curl .../main/install.sh`, so whatever lands here is what people get. Protected: pull request and green CI required. |
| `stg` | Staging: the release candidate before promotion. Protected the same way. |
| `develop` | Integration. Finished work accumulates here between releases. |
| `feat/…` `fix/…` `docs/…` `ci/…` | One task each, branched off `develop`. |

- **Task branch name:** `<type>/<issue number>-<short-description>`, with `<type>` matching the
  Conventional Commits type the work will use. Open the issue first — the number is what ties the two
  together.
- **Semantic versioning:** `fix/…` bumps the patch, `feat/…` the minor. Tags are cut from `main` only.
- **English in everything, except `README.pt-BR.md`.** Commit messages, release titles and bodies, pull
  requests, issues, the default README, the bar's labels, installer output, templates, this file and the
  whole vault. Commits follow Conventional Commits. The reasoning is in
  `claude-code-statusline-vault/decisoes/readme-em-ingles-e-arquivos-de-comunidade.md`.

  The exceptions are structural, not editorial: vault folder names and the frontmatter values the
  maintainer's tooling greps for. History before v1.1.0 stays as it is.
- Code is committed and pushed only when the maintainer asks; a vault change follows the rule above.
- `CHANGELOG.md` is updated under **Unreleased** in the same pull request as the change.
