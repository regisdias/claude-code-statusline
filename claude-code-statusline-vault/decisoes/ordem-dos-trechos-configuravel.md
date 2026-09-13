---
tipo: decisao
data: 2026-09-13
---

# The order is the configuration

## Decision

One list decides both **which** segments appear and **in what order**. A segment not in the list does
not render.

```json
{ "ccsl": { "order": ["branch", "ctx", "5h", "session"] } }
```

No separate "hidden" key, no boolean per segment. Dropping `week` means dropping it from the list.

## Where it lives, and why not in a file of its own

In Claude Code's own `settings.json`, under a top-level `ccsl` key.

The obvious objection was cost: reading a second file would mean a second `jq` call per render, against
the no-subprocess rule. **`--slurpfile` removes it** — `jq` reads the payload from standard input and
`settings.json` from the flag, in the same invocation:

```bash
jq -r --slurpfile cfg "$settings_json" "$CONSULTA"
```

That Claude Code tolerates an unknown key in `settings.json` was **verified, not assumed**: the
documentation says nothing about schema validation, so it was tested with
`claude --settings <file with the ccsl key> --print`, which ran without a warning.

## Degradation

A missing key, an empty list, a name nobody recognises, an entry that is not a string, or a
`settings.json` broken by hand: all fall back to the full default order. For the broken JSON, `jq` fails
and the shell **retries the call without the file** — one extra process in the broken case only, and the
bar does not go down with it.

## The accepted cost: a uniform separator

`model` became a segment of its own, so it can be moved and removed. But it used to be glued to `ctx` by
two spaces rather than the `│`. Reordering does not work with two spacing rules, so everything uses `│`
now:

```
before:  ⎇ main  │  Opus 5 (1M context)  ctx [███░░░░░░░] 33%
after:   ⎇ main  │  Opus 5 (1M context)  │  ctx [███░░░░░░░] 33%
```

It changes the bar for anyone who configured nothing, with no opt-out. It was a deliberate decision and
is in the `CHANGELOG` as a visible change.

## Traps that cost time

**A leading empty field in the TSV disappears.** `read -r` with `IFS=$'\t'` treats tab as whitespace, so
an empty first field **collapses**, shifting every other field left. That is why the order default is
applied inside `jq` itself, so that field can never come out empty. It is what the original code was
quietly avoiding by starting with `display_name`, which is never empty.

**`case`, not an associative array.** macOS still ships bash 3.2, which has none.

**The `.ps1` changes line endings when you switch branches.** `.gitattributes` forces CRLF in the
working tree and checkout applies it. A script that edits the file has to normalise first and restore
afterwards, or no multi-line replacement matches.

## The configurator

`ccsl-install.sh --configure` keeps no sample text: it **runs the installed status line** once per
segment to build the menu, and again for the preview. What you approve is what you will see.

It reads from `/dev/tty` when there is one — which is what makes it work with the installer arriving
through `curl | bash`, where standard input is the script itself — and falls back to stdin when there is
not, which as a side effect makes the whole thing scriptable and testable.

See also [[aviso-de-atualizacao-opt-in]] and [[duas-implementacoes-shell-e-powershell]].
