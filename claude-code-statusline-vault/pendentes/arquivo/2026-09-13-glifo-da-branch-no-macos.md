---
tipo: pendente
status: resolvido
data: 2026-09-13
codigo: CCS-4
---

# O `⎇` não lê como git no macOS

**Resolvida em 2026-09-13: rótulo em texto com ícone configurável** (#35). A barra mostra `git main`, e
`ccsl.branch_icon` troca a palavra por um ícone. O porquê está em
[[../../decisoes/rotulo-da-branch-em-texto]].

Saiu da [[2026-09-12-confirmar-no-macos|CCS-1]], pelo caminho que o [[../../guias/validar-no-macos]] prevê:
"só o `⎇` sai errado".

## O que foi visto

Na barra do Claude Code no **Terminal.app** (macOS 15.6), o glifo **desenha** — não é `?` nem
quadrado, e os bytes são `e2 8e 87`, os certos. Mas ele não lembra uma branch: parece o **símbolo da
tecla Option**, invertido. No WSL (Windows Terminal) o mesmo caractere parece uma setinha que bifurca,
que é o efeito que a issue #11 queria.

Não é bug de fonte nem do script. O U+2387 se chama *ALTERNATIVE KEY SYMBOL*: é, de fato, um símbolo de
teclado. A fonte do Mac desenha o que o nome diz; a do Windows desenha a leitura que os prompts de git
popularizaram. **O problema é a escolha do glifo**, e ela falha justamente na plataforma cujo símbolo
de tecla as pessoas reconhecem.

## Opções

| Opção | Exemplo | A favor | Contra |
|---|---|---|---|
| Manter `⎇` | `⎇ main` | nada muda | lê como tecla Option no Mac |
| Rótulo em texto | `branch main` / `git main` | igual aos outros trechos (`ctx`, `5h`, `week`, `session`); zero risco de fonte | mais largo |
| Glifo de fonte Powerline/Nerd (U+E0A0) | ` main` | é o ícone de branch "de verdade" | área de uso privado: sem a fonte instalada vira quadrado para quase todo mundo |
| Outro Unicode (ex.: `⑂` U+2442) | `⑂ main` | lembra bifurcação | cobertura de fonte pior que a do `⎇`; precisa de nova rodada em Mac e Windows |
| Configurável | `ccsl.branch_icon` | cada um escolhe | mais uma chave, e o padrão ainda precisa ser decidido |

Qualquer mudança entra nas duas implementações, regera `assets/`, e muda o `testar.sh` (que tira o
prefixo `⎇ ` na seção 3) e o menu do `--configure`.

## Para resolver

Decidir a opção, registrar em `decisoes/`, e só então implementar. Enquanto estiver aberta, a CCS-1
também fica.

Escolhida a combinação das linhas 2 e 5: rótulo `git` por padrão, ícone configurável.
