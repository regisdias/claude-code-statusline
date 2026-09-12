# Contributing

Thanks for taking the time. This is a small project with one hard rule, and it shapes everything else.

## The rule: both implementations print the same bytes

`statusline-command.sh` and `statusline-command.ps1` must produce **identical output for the same
payload** — same spacing, same separators, same colors, same wording. A format change lands in both in
the same commit, never in one alone.

Run the check before opening a PR:

```bash
bash scripts/testar.sh
```

It feeds every payload in `scripts/payloads/` to both implementations, diffs the bytes, and verifies the
`.ps1` still carries its UTF-8 BOM. Without `pwsh` installed it checks the shell side only and says so —
CI runs the full comparison on every PR.

## Getting set up

```bash
git clone https://github.com/regisdias/claude-code-statusline.git
cd claude-code-statusline
bash statusline-command.sh < scripts/payloads/verde.json   # see it render
bash scripts/testar.sh                                     # see it pass
```

You need `jq` and `awk`. For the PowerShell half, install `pwsh`
([PowerShell on Linux](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux)).

## Constraints worth knowing

These are not style preferences — each one comes from a bug that already happened.

- **The `.ps1` must stay UTF-8 with BOM.** Without the BOM, Windows PowerShell 5.1 reads the file as ANSI
  and the block characters break the parser. Check with
  `head -c3 statusline-command.ps1 | od -An -tx1` → must be `ef bb bf`. The `.gitattributes` keeps the
  file at CRLF for the same reason; don't normalize it.
- **PowerShell variables are case-insensitive.** `$reset` and `$RESET` are the same variable. Never name
  a local that differs from a constant only by case.
- **Every payload field is optional.** A missing field drops its own segment and leaves the rest intact.
  An error never becomes a stack trace in someone's terminal — the worst case is `aguardando...`.
- **No new runtime dependency.** The statusline is redrawn constantly; anything that spawns a process or
  boots a runtime per render is out. The target is around 50 ms per execution.
- **A new payload field may only be used once both implementations support it.**

## Regenerating the README images

`assets/demo.svg` and `assets/demo-fallback.svg` are generated from the script's real output — nothing in
them is hand-drawn. After any format change:

```bash
python3 scripts/gerar-svg.py
```

Commit the regenerated SVGs along with the change.

## Pull requests

- One topic per PR.
- Say which platforms you tested on (Linux, WSL, macOS, Windows PowerShell 5.1, PowerShell 7).
- Include a before/after of the rendered line when you touch the output format.
- Commit messages are in Portuguese, following the existing log (`docs(vault): …`, and so on). English is
  fine too if that's what you're comfortable with — the maintainer will adjust on merge.

## Reporting bugs

Use the [bug report template](https://github.com/regisdias/claude-code-statusline/issues/new?template=bug_report.yml).
The payload that reproduces it is the single most useful thing you can attach — grab it with:

```bash
cat > ~/.claude/capturar.sh <<'EOF'
#!/usr/bin/env bash
tee ~/payload-statusline.json | bash ~/.claude/statusline-command.sh
EOF
chmod +x ~/.claude/capturar.sh
```

Point `statusLine.command` at `capturar.sh` for one render, then **redact the file before posting it** —
it carries your cost and usage numbers.

## Security

Found something exploitable? Don't open an issue — see [SECURITY.md](SECURITY.md).
