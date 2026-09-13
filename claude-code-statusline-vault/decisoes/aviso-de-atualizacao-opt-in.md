---
tipo: decisao
data: 2026-09-12
---

# O aviso de atualização é opt-in, e mora fora da barra

## Decisão

Existe aviso de versão nova, mas **desligado até a pessoa ligar**, e a checagem vive num hook de
`SessionStart` — nunca no script da barra.

| | Statusline | Hook de update |
|---|---|---|
| Rede | nunca | uma requisição, no máximo 1x por 24h |
| Escrita em disco | nunca | um arquivo de cache |
| Roda | a cada desenho | uma vez por sessão |

A barra só **lê** o cache. Quem busca e grava é o hook.

## Por que não pode ser como o `oh-my-zsh`

O pedido original foi "avisar tipo o ZSH, que você aperta Y e ele atualiza". **Isso não é possível**, e
por dois motivos diferentes:

1. **Statusline não é interativa.** É um comando cujo stdout é desenhado. Não há entrada de teclado.
2. **Hook também não é.** Confirmado na documentação do Claude Code: nenhum evento de hook aceita
   entrada do usuário. O `SessionStart` imprime e pronto.

O mais próximo honesto é: avisar e entregar a linha pronta para copiar. Foi o que foi feito.

## Por que opt-in, e não ligado por padrão

O `SECURITY.md` dizia, por escrito, que os scripts **nunca abrem conexão de rede e nunca escrevem em
disco**. Isso não é detalhe: é o que permite a alguém instalar um script de terceiro no `~/.claude` sem
auditar muita coisa.

Ligar a checagem por padrão significaria fazer requisição na máquina de todo mundo que instala, sem
pedir — e reescrever aquela promessa. Opt-in mantém a frase verdadeira para quem não pediu nada.

A separação barra/hook é o que faz a promessa continuar verdadeira **mesmo para quem ligou**: a
statusline em si segue sem rede e sem escrita nos dois casos. O `SECURITY.md` ganhou uma seção
descrevendo exatamente o que o hook faz.

## Detalhes que custaram tempo

**`Get-Date -UFormat %s` está errado no PowerShell 5.1.** Devolve a hora local como se fosse epoch —
três horas de diferença aqui. Os dois hooks gravam o mesmo arquivo de cache, e quem usa Claude Code no
Windows e no WSL compartilha `~/.claude`: os dois discordariam sobre a janela de 24h. Usar
`[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()` resolve e funciona no 5.1 e no 7.

**Marcador é arquivo, não variável de ambiente.** O ambiente que a statusline recebe não é
confiavelmente o shell da pessoa. Arquivo é determinístico e funciona igual nas duas implementações.

**`CCSL_VERSION` nas duas implementações**, bumpado junto com o carimbo do `CHANGELOG`. Um job de CI
reprova se os três discordarem — senão o aviso mente sobre o que está instalado.

Veja também [[branch-vem-do-git-head]] e [[duas-implementacoes-shell-e-powershell]].
