# claude-code-statusline

Statusline do Claude Code em duas implementações: `statusline-command.sh` (Linux, WSL, macOS, Git Bash)
e `statusline-command.ps1` (Windows nativo, PowerShell 5.1+). O repositório é público e a documentação de
instalação e uso é o [README](README.md), que é bilíngue.

## Regra central: as duas implementações têm a mesma saída

Para o mesmo payload, o shell e o PowerShell devolvem **os mesmos bytes**. Mudança de formato entra nas
duas no mesmo commit, e o teste de comparação roda antes de publicar — o passo a passo está em
`claude-code-statusline-vault/guias/testar-local.md`.

Antes de publicar, rode também os quatro payloads (completo, sem `rate_limits`, `{}` e texto inválido).

## Armadilhas conhecidas

- O `.ps1` tem de ficar em **UTF-8 com BOM**: sem BOM, o PowerShell 5.1 lê como ANSI e o script não
  compila. Conferir com `head -c3 statusline-command.ps1 | xxd -p` (tem de ser `efbbbf`).
- **Variável em PowerShell não distingue maiúscula:** `$reset` e `$RESET` são a mesma. Não crie local que
  difira de uma constante só pela caixa.
- Campo novo do payload só pode ser usado se existir nas duas implementações, e sempre com degradação:
  campo ausente não pode quebrar a barra, e erro nunca vira stack trace no terminal.
- Nada de dependência que suba runtime a cada desenho da barra: o alvo é ~50 ms por execução.

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
