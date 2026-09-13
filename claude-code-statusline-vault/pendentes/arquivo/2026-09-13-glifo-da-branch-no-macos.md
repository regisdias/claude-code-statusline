---
tipo: pendente
status: resolvido
data: 2026-09-13
codigo: CCS-4
---

# `⎇` does not read as git on macOS

**Resolved on 2026-09-13: a text label with a configurable icon** (#35). The bar shows `git main`, and
`ccsl.branch_icon` swaps the word for an icon. The reasoning is in
[[../../decisoes/rotulo-da-branch-em-texto]].

Came out of [[2026-09-12-confirmar-no-macos|CCS-1]], by the path [[../../guias/validar-no-macos]]
anticipates: "only the glyph comes out wrong".

## What was seen

In the Claude Code bar in **Terminal.app** (macOS 15.6), the glyph **draws** — it is not a `?` or a box,
and the bytes are `e2 8e 87`, the right ones. But it does not suggest a branch: it looks like the
**Option key symbol**, inverted. In WSL (Windows Terminal) the same character looks like a forking
arrow, which is the effect issue #11 wanted.

It is not a font bug, nor a script bug. U+2387 is called *ALTERNATIVE KEY SYMBOL*: it really is a
keyboard symbol. The Mac's font draws what the name says; Windows' draws the reading that git prompts
popularised. **The problem is the choice of glyph**, and it fails precisely on the platform whose key
symbol people recognise.

## Options

| Option | Example | For | Against |
|---|---|---|---|
| Keep `⎇` | `⎇ main` | nothing changes | reads as the Option key on the Mac |
| Text label | `branch main` / `git main` | matches the other segments (`ctx`, `5h`, `week`, `session`); zero font risk | wider |
| Powerline/Nerd font glyph (U+E0A0) | ` main` | it is the "real" branch icon | private use area: without the font it is a box for almost everyone |
| Another Unicode character (`⑂` U+2442) | `⑂ main` | suggests a fork | worse font coverage than `⎇`; needs another round on Mac and Windows |
| Configurable | `ccsl.branch_icon` | everyone picks | one more key, and the default still has to be decided |

Any change lands in both implementations, regenerates `assets/`, and touches `testar.sh` (which strips
the `⎇ ` prefix in section 3) and the `--configure` menu.

## How it was resolved

The combination of rows 2 and 5 was chosen: `git` as the default label, with a configurable icon.
