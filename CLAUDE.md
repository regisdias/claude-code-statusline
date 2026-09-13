# claude-code-statusline

Statusline do Claude Code em duas implementações: `statusline-command.sh` (Linux, WSL, macOS, Git Bash)
e `statusline-command.ps1` (Windows nativo, PowerShell 5.1+). Repositório público.

## Regra central: as duas implementações têm a mesma saída

Para o mesmo payload, o shell e o PowerShell devolvem **os mesmos bytes**. Mudança de formato entra nas
duas no mesmo commit.

```bash
bash scripts/testar.sh
```

Roda todos os payloads de `scripts/payloads/` nas duas implementações, compara byte a byte e confere o
BOM do `.ps1`. Sem `pwsh` instalado, testa só o lado shell e avisa. É o mesmo comando do CI.

## Mapa do repositório

| Caminho | O que é |
|---|---|
| `statusline-command.sh` / `.ps1` | As duas implementações — o produto |
| `install.sh` | Instalador de uma linha citado no README (Linux, WSL, macOS, Git Bash) |
| `scripts/payloads/` | Payloads de teste: verde, amarelo, vermelho, sem limites, vazio, inválido |
| `scripts/testar.sh` | Comparação das duas implementações + guarda do BOM |
| `scripts/gerar-svg.py` | Gera as imagens do README a partir da saída real |
| `scripts/gerar-social-preview.py` | Gera o card 1280x640 de compartilhamento (upload manual no GitHub) |
| `scripts/testar.sh` (branch/*) | Fixtures de `.git/HEAD` criadas na hora — git não versiona caminho com `.git` |
| `assets/` | **Gerado.** Não editar à mão — veja abaixo |
| `README.md` / `README.pt-BR.md` | Inglês é a porta de entrada; conteúdo entra nos dois |
| `hooks/ccsl-update-check.{sh,ps1}` | Aviso de atualização — **opt-in**, o único componente que usa rede |
| `.github/` | CI, templates de issue e de PR |

## Documentação em dois lugares diferentes

- **README (inglês e pt-BR):** instalar e usar. É o que a pessoa de fora lê.
- **Vault (`claude-code-statusline-vault/`):** por que as coisas são como são, e o que está em aberto.

Mudança de conteúdo no README entra nos **dois** arquivos — não há geração automática de um a partir do
outro.

## `assets/` é gerado

`assets/demo.svg` e `assets/demo-fallback.svg` saem de:

```bash
python3 scripts/gerar-svg.py             # regerar
python3 scripts/gerar-svg.py --verificar # o que o CI roda
```

Mexeu no formato da barra? Regere e commite junto. O `--verificar` ignora a hora do reset e as
coordenadas `x` — sem isso ele falharia toda meia-noite.

O `assets/social-preview.png` sai do `scripts/gerar-social-preview.py` (precisa de `npx`, usa o
sharp-cli para rasterizar). O GitHub não tem API para ele: sobe à mão em Settings → General.

## Armadilhas conhecidas

- O `.ps1` tem de ficar em **UTF-8 com BOM**: sem BOM, o PowerShell 5.1 lê como ANSI e o script não
  compila. Conferir com `head -c3 statusline-command.ps1 | xxd -p` (tem de ser `efbbbf`). O
  `.gitattributes` mantém o arquivo em CRLF pelo mesmo motivo — não normalizar.
- **Variável em PowerShell não distingue maiúscula:** `$reset` e `$RESET` são a mesma. Não crie local que
  difira de uma constante só pela caixa.
- Campo novo do payload só pode ser usado se existir nas duas implementações, e sempre com degradação:
  campo ausente não pode quebrar a barra, e erro nunca vira stack trace no terminal.
- Nada de dependência que suba runtime a cada desenho da barra: o alvo é ~50 ms por execução.
- **A branch não vem no payload.** O Claude Code manda `workspace.repo` (host/owner/name) e
  `worktree.branch` (só em sessão de worktree). A branch sai da leitura direta do `.git/HEAD` — `git
  branch --show-current` seria um exec por desenho. As duas implementações têm de tratar igual: `.git`
  como diretório e como arquivo (`gitdir:`), HEAD solto (sha curto), CR no fim da linha e walk-up.
- **A barra se quebra sozinha no `$COLUMNS`**, que o Claude Code define antes de rodar o comando. Quebra
  só **entre** trechos. `${#s}` conta **bytes** fora de locale UTF-8 e a statusline costuma rodar sem
  `LANG` — por isso a largura é medida dobrando cada glifo conhecido (`█ ░ │ ⎇ ↑ ·`) para um caractere
  ASCII antes de contar. Não troque por `${#s}` direto.
- **O `gerar-svg.py` fixa `COLUMNS=999`**, senão a imagem do README sairia diferente em cada máquina.
- **A ordem dos trechos vem do `ccsl.order` no `settings.json`**, lido na **mesma** chamada do `jq` via
  `--slurpfile` — nada de segundo processo por desenho. Config ausente, vazia, com nome desconhecido ou
  com JSON quebrado cai na ordem padrão; a barra nunca fica em branco por causa de config.
- **O separador é uniforme (`│`).** Não recrie exceção de espaçamento entre trechos: foi exatamente o
  que impedia reordenar.
- **`case`, não array associativo**, na montagem: o macOS ainda traz bash 3.2.
- **A barra não faz rede nem escreve em disco, e isso é promessa escrita no `SECURITY.md`.** Quem faz
  as duas coisas é o hook de update, que é opt-in e roda uma vez por sessão; a barra só **lê** o cache.
  Não mova essa fronteira.
- **`CCSL_VERSION` existe nas duas implementações** e é bumpado no mesmo commit que carimba a versão no
  `CHANGELOG.md`. O CI reprova se os três discordarem.
- **`seq` não entra no caminho de desenho:** o do BSD infere direção e `seq 1 0` imprime `1 0`, o que já
  alargou a barra cheia no macOS. Preencher com `printf` e substituir não tem caso de borda.
- O lint do CI é `shellcheck --severity=warning`. Supressão só com comentário explicando o porquê.

## Vault do projeto

A documentação de decisões e pendências é o vault Obsidian em `claude-code-statusline-vault/`,
versionado junto com o código. **Entrada única: `claude-code-statusline-vault/Home.md`.**

- **Leia a Home** antes de decidir algo ou entrar numa área que não conhece. Tarefa mecânica (ajustar
  texto, rodar teste, corrigir erro apontado) não precisa abrir o vault.
- **O que entra em cada pasta:** `pendentes/` (uma nota por pendência, resolvidas em
  `pendentes/arquivo/`), `decisoes/`, `arquitetura/`, `guias/`, `bugs-fixes/`, `planos/` (com `arquivo/`),
  `roadmap/`, `reunioes/`, `_assets/`.
- **Formato de pendência:** `tipo: pendente`, `status: aberto|fazendo|resolvido`, `data: AAAA-MM-DD` e
  `prazo` opcional. Ao resolver: `status: resolvido`, uma linha dizendo como foi resolvida e `git mv`
  para `pendentes/arquivo/` no mesmo commit.
- **Mudança no vault é commitada e empurrada** (`docs(vault): …`) sem esperar pedido.
- **Não entra no vault:** relato de sessão, o que o `git log` já conta, segredo e nada pessoal — o
  repositório é público.

`claude-code-statusline-vault/.obsidian/` fica fora do git (configuração local de cada um).

## Git

**Nada entra direto na `main`.** O fluxo é de baixo para cima:

```
feat/12-short-description  →  develop  →  stg  →  main
```

| Branch | O que é |
|---|---|
| `main` | Produção. O README instala com `curl .../main/install.sh`, então o que entra aqui é o que as pessoas recebem. Protegida: exige PR e CI verde. |
| `stg` | Homologação: candidata a release antes de subir. Protegida igual. |
| `develop` | Integração. O trabalho pronto acumula aqui entre releases. |
| `feat/…` `fix/…` `docs/…` `ci/…` | Uma tarefa cada, saindo da `develop`. |

- **Nome da branch de tarefa:** `<tipo>/<número da issue>-<descrição-curta-em-inglês>`, com o `<tipo>`
  igual ao do Conventional Commits que o trabalho vai usar. Abre a issue primeiro — o número é o que
  amarra os dois.
- **Versionamento semântico:** `fix/…` sobe o patch, `feat/…` sobe o minor. Tag só sai da `main`.
- **Mensagens de commit em inglês**, no padrão Conventional Commits. O repositório é público e o
  `git log` é a única superfície de leitura que ainda estava em português — o porquê está em
  `claude-code-statusline-vault/decisoes/readme-em-ingles-e-arquivos-de-comunidade.md`. O histórico
  anterior fica como está; a regra vale daqui para a frente.
- Commit e push de código só a pedido de quem mantém o repositório; mudança no vault segue a regra acima.
- O `CHANGELOG.md` é atualizado em **Unreleased** no mesmo PR da mudança.
