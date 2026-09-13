---
tipo: home
atualizado: 2026-09-13
---

# claude-code-statusline

Statusline do [Claude Code](https://claude.com/claude-code) que mostra a janela de contexto e o **uso
real do plano** — bloco de 5 horas e limite semanal — lendo `rate_limits` do payload que o próprio
Claude Code entrega para a statusline. São os mesmos números do `/usage`.

Repositório público, licença MIT. A instalação e o uso ficam no README ([inglês](../README.md) ·
[português](../README.pt-BR.md)); aqui mora o porquê das decisões e o que está em aberto.

## Por onde começar

| Tema | Nota |
|---|---|
| Como o script funciona por dentro | [[arquitetura/como-a-statusline-funciona]] |
| Por que existem duas implementações | [[decisoes/duas-implementacoes-shell-e-powershell]] |
| Por que o uso vem do payload, e não de custo estimado | [[decisoes/uso-do-plano-vem-do-payload]] |
| Que idioma vai em quê — README, rótulos, **mensagens de commit** | [[decisoes/readme-em-ingles-e-arquivos-de-comunidade]] |
| Por que o CI roda em push e PR | [[decisoes/ci-em-push-e-pr]] |
| Fluxo de branches: main → stg → develop → tarefa | [[decisoes/fluxo-de-branches]] |
| Por que a branch sai do `.git/HEAD`, e não do `git` | [[decisoes/branch-vem-do-git-head]] |
| Por que o aviso de atualização é opt-in e vive fora da barra | [[decisoes/aviso-de-atualizacao-opt-in]] |
| Como a ordem dos trechos é configurada | [[decisoes/ordem-dos-trechos-configuravel]] |
| Por que a barra se quebra sozinha | [[decisoes/quebra-na-largura-do-terminal]] |
| Testar sem abrir o Claude Code | [[guias/testar-local]] |
| Regerar as imagens do README | [[guias/regenerar-imagens-do-readme]] |
| **Validar num Mac** (fecha a CCS-1) | [[guias/validar-no-macos]] |
| Armadilhas do PowerShell que já custaram caro | [[bugs-fixes/2026-09-12-powershell-bom-e-colisao-de-variavel]] |
| Por que a barra cheia saía torta no macOS | [[bugs-fixes/2026-09-12-seq-do-bsd-alargava-a-barra-cheia-no-macos]] |
| Por que o custo saía `$12,00` num Mac em português | [[bugs-fixes/2026-09-13-locale-com-virgula-quebrava-os-numeros]] |

## Pendências

- [[pendentes/2026-09-12-confirmar-no-macos|Confirmar no macOS]] — `fazendo`: rodada num Mac de verdade, achou
  o bug do locale (#27); espera a CCS-4
- [[pendentes/2026-09-13-glifo-da-branch-no-macos|O `⎇` não lê como git no macOS]] — `aberto`: parece a
  tecla Option; escolher outro glifo ou um rótulo

Resolvidas ficam em `pendentes/arquivo/` — a mais recente é
[[pendentes/arquivo/2026-09-12-rotulos-da-barra-em-portugues|a tradução dos rótulos da barra]].

## O que é gerado, e não escrito à mão

| Arquivo | Vem de |
|---|---|
| `assets/demo.svg`, `assets/demo-fallback.svg` | `python3 scripts/gerar-svg.py`, a partir da saída real do script |
| `assets/social-preview.png` | `python3 scripts/gerar-social-preview.py` — o card de compartilhamento do GitHub |

Mudou o formato da barra? Regere e commite junto — o CI reprova se ficarem para trás.

## Estrutura do vault

| Pasta | O que entra |
|---|---|
| `pendentes/` | Uma nota por pendência; `arquivo/` guarda as resolvidas |
| `decisoes/` | Decisão vigente e o motivo dela |
| `arquitetura/` | Como o script funciona e de onde vêm os dados |
| `guias/` | How-to: testar, publicar, depurar |
| `bugs-fixes/` | Problema encontrado, causa e correção |
| `planos/` | Planos de execução; `arquivo/` para os concluídos |
| `roadmap/` | O que se pretende adicionar |
| `reunioes/` | Atas, se houver |
| `_assets/` | Imagens das notas |
