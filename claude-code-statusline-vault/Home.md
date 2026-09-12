---
tipo: home
atualizado: 2026-09-12
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
| Por que o README é em inglês e o que mais o GitHub espera | [[decisoes/readme-em-ingles-e-arquivos-de-comunidade]] |
| Por que o CI roda em push e PR | [[decisoes/ci-em-push-e-pr]] |
| Testar sem abrir o Claude Code | [[guias/testar-local]] |
| Regerar as imagens do README | [[guias/regenerar-imagens-do-readme]] |
| Armadilhas do PowerShell que já custaram caro | [[bugs-fixes/2026-09-12-powershell-bom-e-colisao-de-variavel]] |

## Pendências

- [[pendentes/2026-09-12-confirmar-no-macos|Confirmar no macOS]] — `fazendo`: o CI cobre o `date -r`,
  falta um terminal de Mac de verdade
- [[pendentes/2026-09-12-rotulos-da-barra-em-portugues|Rótulos da barra em português]] — `semana` e
  `sessão` numa barra de projeto em inglês

Resolvidas ficam em `pendentes/arquivo/`.

## O que é gerado, e não escrito à mão

| Arquivo | Vem de |
|---|---|
| `assets/demo.svg`, `assets/demo-fallback.svg` | `python3 scripts/gerar-svg.py`, a partir da saída real do script |

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
