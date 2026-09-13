---
tipo: decisao
data: 2026-09-13
---

# A ordem é a configuração

## Decisão

Uma lista só decide **quais** trechos aparecem e **em que ordem**. Trecho fora da lista não desenha.

```json
{ "ccsl": { "order": ["branch", "ctx", "5h", "session"] } }
```

Sem chave separada de "escondidos", sem booleano por trecho. Tirar a `week` é tirá-la da lista.

## Onde mora, e por que não num arquivo próprio

No `settings.json` do próprio Claude Code, chave `ccsl` no topo.

A objeção óbvia era custo: ler um segundo arquivo significaria uma segunda chamada ao `jq` por desenho,
contra a regra de nenhum subprocesso. **O `--slurpfile` derruba isso** — o `jq` lê o payload pela
entrada padrão e o `settings.json` na mesma invocação:

```bash
jq -r --slurpfile cfg "$settings_json" "$CONSULTA"
```

Chave desconhecida no `settings.json` foi **verificada na prática**, não suposta: a documentação não diz
nada sobre validação de schema, então rodei `claude --settings <arquivo com a chave ccsl> --print` e o
Claude Code aceitou sem aviso.

## Degradação

Config ausente, lista vazia, nome que ninguém reconhece, entrada que não é string, ou `settings.json`
quebrado na mão: tudo cai na ordem padrão completa. Para o JSON quebrado, o `jq` falha e o shell
**repete a chamada sem o arquivo** — um processo a mais só no caso quebrado, e a barra não vai junto.

## O custo aceito: separador uniforme

O `model` virou trecho próprio, para poder mover e sumir. Só que ele era grudado no `ctx` por dois
espaços, não pelo `│`. Reordenar com duas regras de separação não fecha, então tudo passou a usar `│`:

```
antes:   ⎇ main  │  Opus 5 (1M context)  ctx [███░░░░░░░] 33%
depois:  ⎇ main  │  Opus 5 (1M context)  │  ctx [███░░░░░░░] 33%
```

Muda a barra de quem não configurou nada, sem opt-out. Foi decisão consciente e está no `CHANGELOG`
como mudança visível.

## Armadilhas que custaram tempo

**Campo vazio no início do TSV some.** O `read -r` com `IFS=$'\t'` trata tab como espaço em branco, e
campo vazio no começo **colapsa**, deslocando todos os outros. Por isso o padrão da ordem é aplicado
dentro do próprio `jq`, para aquele campo nunca sair vazio. Era isso que o código original evitava sem
dizer, ao começar pelo `display_name`, que nunca é vazio.

**`case`, não array associativo.** O macOS ainda traz bash 3.2, que não tem.

**O `.ps1` muda de fim de linha ao trocar de branch.** O `.gitattributes` força CRLF no working tree, e
o checkout aplica isso. Script que edita o arquivo tem de normalizar antes e restaurar depois, senão
nenhum `replace` multilinha casa.

## O configurador

`ccsl-install.sh --configure` não guarda texto de exemplo: ele **roda a statusline instalada** uma vez
por trecho para montar o menu, e de novo para a prévia. O que você aprova é o que você vai ver.

Lê do `/dev/tty` quando existe — assim funciona mesmo com o instalador vindo por `curl | bash`, onde a
entrada padrão é o próprio script — e cai para stdin quando não existe, o que de quebra torna tudo
scriptável e testável.

Veja também [[aviso-de-atualizacao-opt-in]] e [[duas-implementacoes-shell-e-powershell]].
