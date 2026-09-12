---
tipo: pendente
status: resolvido
data: 2026-09-12
codigo: CCS-3
---

# Rótulos da barra em português, num projeto de README em inglês

**Resolvida em 2026-09-12: os rótulos foram traduzidos.** `semana` → `week`, `· reseta` → `· resets`,
`sessão $` → `session $` e `aguardando...` → `waiting...`, nas duas implementações no mesmo commit.

A statusline desenhava `semana`, `sessão` e `reseta` em português, enquanto o README, o `install.sh` e
os templates de issue estão em inglês — a decisão registrada em
[[../decisoes/readme-em-ingles-e-arquivos-de-comunidade]]. Para quem chega de fora, três palavras numa
língua que não lê no meio de uma barra em inglês pareciam bug, não escolha.

## O que pesou na escolha

| Opção | Custo |
|---|---|
| **Traduzir** ← escolhida | Muda a barra de quem já instalou; entra nas duas implementações no mesmo commit |
| Deixar como está | Continua estranho para quem não fala português |
| Tornar configurável por variável de ambiente | Dobra os casos de teste de paridade; conflita com "sem dependência, sem custo por desenho" |

Decidiu-se traduzir justamente por ser cedo: o repositório tinha acabado de ganhar a primeira tag, e
mudança que aparece na barra de todo mundo custa mais quanto mais gente instalou.

A opção configurável foi descartada porque dobraria a matriz de paridade — cada payload teria de ser
comparado nos dois idiomas, nas duas implementações — para resolver um problema que a tradução resolve
de vez.

## O que mudou junto

- `statusline-command.sh` e `.ps1`: só as strings de saída. Os nomes internos (`semana_part`,
  `custo_part`, `$partes`) continuam em português, como o resto do código.
- `assets/demo.svg`, `assets/demo-fallback.svg` e `assets/social-preview.png` regerados.
- A linha de exemplo e as tabelas dos dois READMEs, o `CONTRIBUTING` e os templates de issue.

## O que **não** mudou, e continua em aberto

O formato da data do reset semanal: `18/09 05:00` é `dd/mm`. Num projeto de porta de entrada em inglês,
isso é ambíguo para quem lê `mm/dd` — `18/09` é 18 de setembro aqui e uma data inválida lá, mas
`05/09` passaria como 5 de setembro sem ninguém perceber. Algo como `18 Sep 05:00` não tem ambiguidade
em lugar nenhum, e custa dois caracteres a mais na barra.

Ficou de fora porque não é rótulo, é formato — e mexer nisso pede o mesmo cuidado de paridade
(`%d/%m %H:%M` no shell, `'dd/MM HH:mm'` no PowerShell) que a tradução acabou de exigir.
