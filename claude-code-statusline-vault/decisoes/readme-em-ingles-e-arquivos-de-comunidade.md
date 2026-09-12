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

## O que ficou em português mesmo assim

- **As mensagens do `scripts/testar.sh`** e os comentários deste vault: são ferramenta interna.
- **As mensagens do `install.sh` são em inglês**, porque ele é a porta de entrada citada no README.

## Consequência

Mudança de conteúdo no README entra nos **dois** arquivos. Não há geração automática de um a partir do
outro: são textos irmãos, mantidos à mão.
