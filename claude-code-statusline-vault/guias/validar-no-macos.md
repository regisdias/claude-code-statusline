---
tipo: guia
data: 2026-09-13
---

# Validar no macOS — passo a passo

Nasceu para fechar a [[../pendentes/arquivo/2026-09-12-confirmar-no-macos|CCS-1]], já resolvida; continua valendo para validar qualquer mudança num Mac. Feito num Mac de verdade, não
em runner: o CI já cobre o resto.

**O que só um Mac responde:** se os glifos desenham na tela, e se a hora do reset sai certa num fuso
que não é UTC. O runner do GitHub não tem tela e roda em UTC.

## 1. Antes de começar

```bash
brew install jq
```

O terminal precisa estar em UTF-8 — no Terminal.app é Settings → Profiles → Advanced → Text encoding.
Sem isso os blocos saem como interrogação e você diagnostica um bug que não existe.

> **Atenção ao bash.** O `/bin/bash` do macOS é a versão **3.2**, de 2007, por causa da licença do
> bash 4. O script tem shebang `#!/usr/bin/env bash`, então pega o primeiro `bash` do PATH — que pode
> ser o do Homebrew (5.x) em vez do do sistema. **Os dois precisam funcionar**, e o diagnóstico abaixo
> roda nos dois de propósito.

## 2. Instalar como um usuário qualquer

Não rode do clone. O que interessa é o caminho que uma pessoa de fora percorre:

```bash
curl -fsSL https://raw.githubusercontent.com/regisdias/claude-code-statusline/main/install.sh | bash
```

Esperado: as três linhas de `✓`, e uma prévia da barra desenhada.

## 3. O diagnóstico, numa colada só

Rode isto **dentro do clone** e mande a saída inteira para o Claude:

```bash
bash -c '
R=$(mktemp -d); mkdir -p "$R/.git"; printf "ref: refs/heads/main\n" > "$R/.git/HEAD"
C=$(mktemp -d)
P=$(jq -nc --arg d "$R" --argjson t "$(date +%s)" "{
  model:{display_name:\"Opus 5 (1M context)\"}, cost:{total_cost_usd:12.3456},
  workspace:{current_dir:\$d},
  context_window:{used_percentage:33,context_window_size:1000000,current_usage:{input_tokens:330000}},
  rate_limits:{five_hour:{used_percentage:41,resets_at:(\$t+7200)},
               seven_day:{used_percentage:11,resets_at:(\$t+259200)}}}")

echo "== AMBIENTE =="
sw_vers 2>/dev/null | tr "\n" " " || echo "(sw_vers ausente: nao e macOS)"; echo
echo "bash do PATH : $(bash --version | head -1)"
echo "bash sistema : $(/bin/bash --version | head -1)"
if date --version >/dev/null 2>&1; then echo "date         : GNU, $(date --version | head -1)"
else echo "date         : BSD (sem --version) — e o caminho que a CCS-1 quer ver"; fi
echo "fuso         : $(date +%Z%z)  |  locale: ${LANG:-nao-definido}"
echo "jq           : $(jq --version)"
echo "TERM         : $TERM  |  TERM_PROGRAM: ${TERM_PROGRAM:-?}"

echo; echo "== BARRA, bash do PATH =="
printf "%s" "$P" | CLAUDE_CONFIG_DIR=$C bash statusline-command.sh; echo
echo; echo "== BARRA, /bin/bash 3.2 =="
printf "%s" "$P" | CLAUDE_CONFIG_DIR=$C /bin/bash statusline-command.sh; echo

echo; echo "== BARRA CHEIA (o caso do bug do seq) =="
printf "%s" "$P" | jq -c ".rate_limits.five_hour.used_percentage=100" \
  | CLAUDE_CONFIG_DIR=$C bash statusline-command.sh; echo

echo; echo "== ORDEM CONFIGURADA =="
printf "{\"ccsl\":{\"order\":[\"ctx\",\"branch\"]}}\n" > "$C/settings.json"
printf "%s" "$P" | CLAUDE_CONFIG_DIR=$C bash statusline-command.sh; echo
rm -f "$C/settings.json"

echo; echo "== BYTES DO INICIO DA LINHA (o que o script emitiu, nao o que voce ve) =="
printf "%s" "$P" | CLAUDE_CONFIG_DIR=$C bash statusline-command.sh \
  | sed "s/\x1b\[[0-9]*m//g" | head -c 24 | xxd
echo "esperado: 67 69 74 20 = \"git \", depois \"main\""
echo "referencia dos outros: $(printf "█░│↑" | xxd | head -1)"
'
```

## 4. O que olhar, e o que cada coisa significa

| Conferir | Certo | Errado significa |
|---|---|---|
| **Os dois bash** | saída idêntica | incompatibilidade com o bash 3.2 — é bug, e grave: é o bash padrão do Mac |
| **`git` antes da branch** | a palavra | outra coisa: um `ccsl.branch_icon` no seu `settings.json` real não entra aqui — o diagnóstico usa config vazia |
| **`█` e `░`** | blocos sólidos e claros | quadrado ou `?`: terminal fora de UTF-8 |
| **`│`** | barra vertical fina | idem |
| **Largura da barra** | sempre **10** blocos, inclusive em 100% | 12 blocos = o bug do `seq` voltou |
| **`resets HH:MM`** | hora daqui a 2h, no **seu** relógio | hora errada ou em branco = o `date -r` do BSD |
| **`18/09 05:00`** | data daqui a 3 dias | idem |

**A distinção que importa nos glifos:** se os bytes estão certos (compare com a linha de referência)
mas a tela mostra `?`, o problema é a fonte do terminal — o script está correto. Só o contrário é bug
nosso.

> Até a v1.5.0 a branch levava o glifo `⎇`, e esta tabela conferia ele. No Mac ele lia como a tecla
> Option, e virou `git` — veja [[../decisoes/rotulo-da-branch-em-texto]].

## 5. Fechando a pendência

- **Tudo certo:** a CCS-1 vira `status: resolvido`, ganha uma linha dizendo em que macOS e em que
  terminal foi verificado, e vai por `git mv` para `pendentes/arquivo/` no mesmo commit.
- **Só um glifo sai errado:** abre pendência própria — foi assim que o `⎇` virou `git` (CCS-4).
- **Qualquer outra divergência:** issue nova com a saída completa do diagnóstico, e a CCS-1 continua
  aberta até resolver.

Veja também [[testar-local]].
