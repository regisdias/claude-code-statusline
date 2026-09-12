---
tipo: decisao
data: 2026-09-12
---

# README em inglês na porta de entrada, e o pacote de comunidade

## Decisão

O `README.md` é **em inglês**; o português vive no `README.pt-BR.md`, com seletor de idioma no topo dos
dois. Antes era um arquivo só, com as duas línguas em sequência.

Junto entraram os arquivos que o GitHub reconhece e exibe sozinho: `CONTRIBUTING.md`, `SECURITY.md`,
`CODE_OF_CONDUCT.md`, `CHANGELOG.md`, `.github/ISSUE_TEMPLATE/` e `.github/PULL_REQUEST_TEMPLATE.md`.

## Por quê

O público do projeto é quem usa Claude Code, e esse público é majoritariamente internacional — quem
chega pela busca do GitHub ou por um link não lê português. Um README bilíngue num arquivo só resolvia
isso, mas ao custo de dobrar o comprimento: quem chega tem de rolar por uma língua que não lê para achar
a seção de instalação.

O pacote de comunidade não é burocracia: o GitHub monta o *community profile* a partir desses arquivos e
usa a presença deles em ranqueamento e nos avisos que mostra a quem abre uma issue. Os templates de
issue também filtram na entrada as três perguntas que se repetiriam — versão do Claude Code, o payload
que reproduz, e se o `.ps1` manteve o BOM.

## Os rótulos da barra acompanharam

`semana`, `sessão` e `reseta` viraram `week`, `session` e `resets` pouco depois — a barra é a primeira
coisa que a pessoa vê, e três palavras em português no meio dela liam como bug. A história está em
[[../pendentes/arquivo/2026-09-12-rotulos-da-barra-em-portugues]].

## As mensagens de commit também são em inglês

Decidido em 2026-09-12, depois da v1.2.0. Antes a regra era PT-BR.

**Por quê:** num repositório público o `git log` é documentação. É para onde alguém vai quando quer
saber por que uma linha é como é — e este projeto tem várias dessas: o `seq` do BSD, o BOM do
PowerShell, o `read` que devolve erro mas preenche a variável. Esse raciocínio estava escrito numa
língua que a maior parte de quem lê o repositório não fala, enquanto README, rótulos da barra,
instalador e templates já estavam em inglês. O log era a última superfície fora do padrão.

**O histórico anterior fica como está.** Reescrever significaria trocar todos os SHA já publicados nas
releases, nos PRs e nos links do CHANGELOG, para retraduzir commit que ninguém vai reler.

**O formato não muda:** Conventional Commits do mesmo jeito, só a língua.

## O que ficou em português mesmo assim

- **Este vault inteiro.** É a documentação de trabalho de quem mantém, não superfície de visitante.
- **As mensagens que o `scripts/testar.sh` imprime:** ferramenta interna, lida por quem desenvolve.
- **As mensagens do `install.sh` são em inglês**, porque ele é a porta de entrada citada no README.

## Consequência

Mudança de conteúdo no README entra nos **dois** arquivos. Não há geração automática de um a partir do
outro: são textos irmãos, mantidos à mão.
