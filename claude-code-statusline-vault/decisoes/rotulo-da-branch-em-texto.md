---
tipo: decisao
data: 2026-09-13
---

# A branch leva a palavra `git`, com ícone opcional

## Decisão

O trecho da branch é `git main` por padrão. Quem quiser um ícone define `ccsl.branch_icon` no
`settings.json` — tipicamente `"\ue0a0"`, o ícone de branch do Powerline, para quem tem Nerd Font.
Issue #35, e substitui o `⎇` que a #11 tinha introduzido.

## Por quê

O `⎇` foi escolhido na #11 por ser Unicode de verdade e ter uma coluna. No Windows Terminal ele parece
uma bifurcação. **No macOS parece a tecla Option** — visto na tela, no Terminal.app, durante a
[[../pendentes/arquivo/2026-09-12-confirmar-no-macos|CCS-1]].

Não é defeito de fonte. O U+2387 se chama *ALTERNATIVE KEY SYMBOL*, e no Mac quem o desenha é a Lucida
Grande, a mesma fonte do `⌥`. O Mac desenha o que o nome diz.

As alternativas, conferidas na [[../pendentes/arquivo/2026-09-13-glifo-da-branch-no-macos|CCS-4]]:

- **Não existe glifo Unicode padrão para git.** Os ícones que todo prompt usa — `U+E0A0` do Powerline,
  `U+F418` e `U+E725` das Nerd Fonts — ficam na área de uso privado. Sem a fonte, viram quadrado; no
  Mac de teste, até com uma Nerd Font instalada, porque o perfil do terminal não a usava.
- **Outros Unicode** (`⑂` U+2442, `ᚠ`) têm cobertura pior e não são reconhecíveis como git.
- **Os prompts populares sem dependência de fonte usam palavra ou nada**: `git:(main)` no robbyrussell,
  só `main` no Pure.

Uma palavra é o único padrão que se lê igual em todo terminal, e combina com os outros trechos, que já
são rótulos (`ctx`, `5h`, `week`, `session`). O ícone configurável devolve o visual a quem tem a fonte.

## Como funciona

- **Mesma chamada do `jq`** que lê o `ccsl.order` — nenhum processo a mais por desenho. O campo vai por
  último no TSV como `<largura>:<ícone>`, que nunca é vazio: `""` é um ícone válido, e campo vazio
  colapsaria no `read` com `IFS` de tab.
- **A largura é calculada, não medida.** Desde o [[../bugs-fixes/2026-09-13-locale-com-virgula-quebrava-os-numeros|fix do locale]]
  o shell roda em `LC_ALL=C` e conta bytes. Um ícone configurado é desconhecido, então não dá para
  listá-lo na dobra de glifos da [[quebra-na-largura-do-terminal]]: o `jq` conta uma coluna por code
  point, duas fora do BMP, e o shell dobra o ícone para essa quantidade de `#`. É exatamente o que o
  `.Length` do PowerShell dá, porque um caractere fora do BMP são duas unidades UTF-16.
- **Controle e barra invertida são descartados** nas duas implementações. O shell imprime com `%b`, e um
  valor de config não pode injetar escape na barra.
- Valor que não é string (número, `null`, objeto) vale como ausente: `git`.

O `testar.sh` cobre os valores (seção 8) e a quebra exatamente no limite com um ícone de 3 bytes e um
emoji de 4 — confirmado vermelho sem a dobra do ícone.

## Custo

Muda a barra padrão de todo mundo — daí versão minor. Quem gostava do `⎇` volta a ele com uma linha.
