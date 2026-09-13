---
tipo: pendente
status: resolvido
data: 2026-09-12
codigo: CCS-3
---

# The bar's labels were in Portuguese, in an English-README project

**Resolved on 2026-09-12: the labels were translated.** `semana` → `week`, `· reseta` → `· resets`,
`sessão $` → `session $` and `aguardando...` → `waiting...`, in both implementations in the same commit.

The status line drew `semana`, `sessão` and `reseta` in Portuguese while the README, `install.sh` and
the issue templates were in English — the decision recorded in
[[../../decisoes/readme-em-ingles-e-arquivos-de-comunidade]]. To someone arriving from outside, three
words in a language they do not read, in the middle of an English bar, looked like a bug rather than a
choice.

## What decided it

| Option | Cost |
|---|---|
| **Translate** ← chosen | Changes the bar for anyone who already installed; lands in both implementations in the same commit |
| Leave it | Stays strange for anyone who does not speak Portuguese |
| Make it configurable by environment variable | Doubles the parity test matrix; conflicts with "no dependency, no cost per render" |

Translating won precisely because it was early: the repository had just gained its first tag, and a
change that shows up in everyone's bar costs more the more people have installed.

The configurable option was dropped because it would have doubled the parity matrix — every payload
compared in two languages, in two implementations — to solve a problem translation solves outright.

## What changed with it

- `statusline-command.sh` and `.ps1`: the output strings only. Internal names (`semana_part`,
  `custo_part`, `$partes`) stayed in Portuguese, like the rest of the code.
- `assets/demo.svg`, `assets/demo-fallback.svg` and `assets/social-preview.png` regenerated.
- The example line and the tables in both READMEs, `CONTRIBUTING` and the issue templates.

## What did **not** change, and is still open

The weekly reset's date format: `18/09 05:00` is `dd/mm`. In a project whose front door is English, that
is ambiguous to anyone reading `mm/dd` — `18/09` is 18 September here and an invalid date there, but
`05/09` would pass as 5 September without anyone noticing. Something like `18 Sep 05:00` is unambiguous
everywhere, and costs two more characters in the bar.

It was left out because it is not a label, it is a format — and touching it demands the same parity care
(`%d/%m %H:%M` in the shell, `'dd/MM HH:mm'` in PowerShell) that the translation had just required.
