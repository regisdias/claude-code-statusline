---
tipo: decisao
data: 2026-09-13
---

# A barra se quebra sozinha, na largura do terminal

## Decisão

A barra distribui os trechos em quantas linhas o terminal precisar, cortando **só entre trechos**. Sem
configuração: em janela larga continua uma linha.

A largura vem do `COLUMNS`, que o Claude Code define antes de rodar o comando — está na documentação:

> Claude Code captures your script's output instead of connecting it directly to the terminal, so
> `tput cols` and language-level width detection cannot read the terminal size from inside the script.
> Read the `COLUMNS` and `LINES` environment variables instead.

Cada `\n` na saída vira uma linha na tela. `COLUMNS` ausente ou não numérico: uma linha só, o
comportamento antigo.

## Por que não foi configuração manual

A alternativa era estender o `ccsl.order` com listas aninhadas, uma por linha. Foi descartada: quem
configura não sabe a largura da janela de quem lê — nem da própria janela dez minutos depois. Layout
fixo continua quebrando feio em terminal estreito, que era o problema original.

Truncar o nome da branch também foi descartado. O gatilho do pedido foi justamente branch comprida:
esconder o fim do nome resolveria a estética e destruiria a informação.

## A armadilha que custou caro: `${#s}` conta bytes

Fora de locale UTF-8, `${#s}` no bash conta **bytes**, e a statusline roda sem `LANG` com frequência.
Medido:

| Locale | `${#s}` da mesma linha |
|---|---|
| `C.UTF-8` | 31 |
| `C` ou sem `LANG` | **55** |

`█` tem 3 bytes. Quebrar por esse número erraria toda a conta.

A saída foi dobrar cada glifo que a barra emite (`█ ░ │ ⎇ ↑ ·`) para um caractere ASCII antes de contar.
Substituição casa os mesmos bytes nos dois locales, então a conta fica certa em qualquer um — e sem
subprocesso. Nome de branch ou de modelo com acento ainda superestima, o que só quebra um pouco cedo
demais; nunca esconde nada.

O PowerShell não tem esse problema: `.Length` conta unidades UTF-16, uma por glifo.

## A outra armadilha: `` `e `` é PowerShell 6+

Para medir, é preciso tirar os códigos ANSI. O regex `` "`e\[[0-9;]*m" `` **não casa nada no PowerShell
5.1** — o escape `` `e `` só existe do 6 em diante, e falha em silêncio. Resultado: os códigos entravam
na contagem e as duas implementações quebravam em pontos diferentes. Usar `[char]27` resolve.

É a mesma família do `"\u{2387}"` que já tinha mordido antes. **Sintaxe nova de PowerShell é sempre
suspeita neste projeto**, porque o alvo é o 5.1 que vem no Windows.

## Trecho maior que o terminal

Fica sozinho na linha e transborda. Quebrar dentro de um trecho esconderia justamente o que se quer ler.
O teste cobre isso explicitamente: linha pode passar da largura **se** tiver um trecho só.

## Consequência para as imagens do README

O `scripts/gerar-svg.py` fixa `COLUMNS=999`. Sem isso a imagem sairia diferente conforme a janela de
quem gerou, e o job `README images are current` acusaria diferença a cada máquina.

Veja também [[ordem-dos-trechos-configuravel]].
