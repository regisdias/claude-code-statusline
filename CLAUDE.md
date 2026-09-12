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
| `assets/` | **Gerado.** Não editar à mão — veja abaixo |
| `README.md` / `README.pt-BR.md` | Inglês é a porta de entrada; conteúdo entra nos dois |
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

## Armadilhas conhecidas

- O `.ps1` tem de ficar em **UTF-8 com BOM**: sem BOM, o PowerShell 5.1 lê como ANSI e o script não
  compila. Conferir com `head -c3 statusline-command.ps1 | xxd -p` (tem de ser `efbbbf`). O
  `.gitattributes` mantém o arquivo em CRLF pelo mesmo motivo — não normalizar.
- **Variável em PowerShell não distingue maiúscula:** `$reset` e `$RESET` são a mesma. Não crie local que
  difira de uma constante só pela caixa.
- Campo novo do payload só pode ser usado se existir nas duas implementações, e sempre com degradação:
  campo ausente não pode quebrar a barra, e erro nunca vira stack trace no terminal.
- Nada de dependência que suba runtime a cada desenho da barra: o alvo é ~50 ms por execução.
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

- Branch `main`. Mensagens de commit em PT-BR.
- Commit e push de código só a pedido de quem mantém o repositório; mudança no vault segue a regra acima.
- A `main` é a produção: o README instala com `curl .../main/install.sh | bash`. Push quebrado é
  instalação quebrada — por isso o CI roda em push e PR.
