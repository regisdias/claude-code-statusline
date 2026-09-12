---
tipo: decisao
data: 2026-09-12
---

# O uso do plano vem do payload, não de custo estimado

**Decisão:** a barra lê `rate_limits.five_hour` e `rate_limits.seven_day` do payload que o Claude Code
entrega para a statusline. Nada de estimar consumo a partir das transcrições locais.

## Por quê

A abordagem comum — e a que este projeto substituiu — soma os tokens do bloco atual lendo os arquivos
de transcrição, converte em dólar pela tabela pública da API e divide por um teto configurado à mão:

```
% da barra = custo estimado em USD ÷ teto calibrado
```

Três problemas, todos observados na prática:

1. **A conta passa de 100%** quando o teto está abaixo da cota real. Foi o que motivou o projeto: a
   barra marcava 112% enquanto o `/usage` mostrava 41%.
2. **Sessão longa infla a estimativa.** Leitura de cache pesa pouco na cota e muito na conta em dólar:
   uma sessão com 124 milhões de tokens lidos de cache estimava US$ 100 de consumo.
3. **O teto precisa de recalibração manual** sempre que muda a mistura de modelos usada.

O payload resolve os três: a porcentagem vem do servidor, é a mesma do `/usage` e não depende de tabela
de preço nem de calibragem.

## Custo

O campo `rate_limits` existe a partir do Claude Code **2.1.251**. Em versão anterior o script mostra só
a barra de contexto, sem quebrar — é a degradação aceita.

O custo em dólar não sumiu: a barra mostra `.cost.total_cost_usd`, que é o custo **desta conversa** e
vem pronto no payload. É informação de sessão, não medidor de cota.
