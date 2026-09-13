<!--
Thanks for the PR. Keep it to one topic, and delete whatever doesn't apply.
-->

## What this changes

<!-- One or two sentences. Link the issue it closes, if there is one. -->

Closes #

## Rendered output

<!-- Only if you touched the format. Paste the line before and after. -->

```
before:
after:
```

## Checks

- [ ] `bash scripts/test.sh` passes
- [ ] The change landed in **both** `statusline-command.sh` and `statusline-command.ps1`
- [ ] `statusline-command.ps1` still starts with the UTF-8 BOM (`head -c3 statusline-command.ps1 | od -An -tx1` → `ef bb bf`)
- [ ] No new runtime dependency, and nothing that spawns a process per render
- [ ] A missing payload field still drops only its own segment — no stack trace in the terminal
- [ ] README images regenerated (`python3 scripts/generate-svg.py`) if the output format changed
- [ ] `CHANGELOG.md` updated under **Unreleased**

## Tested on

<!-- Check what you actually ran it on. -->

- [ ] Linux
- [ ] WSL
- [ ] macOS
- [ ] Windows PowerShell 5.1
- [ ] PowerShell 7
