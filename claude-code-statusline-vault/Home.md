---
tipo: home
atualizado: 2026-09-12
---

# claude-code-statusline

Statusline do [Claude Code](https://claude.com/claude-code) que mostra a janela de contexto e o **uso
real do plano** — bloco de 5 horas e limite semanal — lendo `rate_limits` do payload que o próprio
Claude Code entrega para a statusline. São os mesmos números do `/usage`.

Repositório público, licença MIT. A instalação e o uso ficam no [README](../README.md), que é bilíngue;
aqui mora o porquê das decisões e o que está em aberto.

## Por onde começar

| Tema | Nota |
|---|---|
| Como o script funciona por dentro | [[arquitetura/como-a-statusline-funciona]] |
| Por que existem duas implementações | [[decisoes/duas-implementacoes-shell-e-powershell]] |
| Por que o uso vem do payload, e não de custo estimado | [[decisoes/uso-do-plano-vem-do-payload]] |
| Testar sem abrir o Claude Code | [[guias/testar-local]] |
| Armadilhas do PowerShell que já custaram caro | [[bugs-fixes/2026-09-12-powershell-bom-e-colisao-de-variavel]] |

## Pendências

- [[pendentes/2026-09-12-confirmar-no-macos|Confirmar no macOS]] — o caminho `date -r` nunca rodou num Mac

Resolvidas ficam em `pendentes/arquivo/`.

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
