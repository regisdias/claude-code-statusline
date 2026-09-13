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

## A regra é por categoria: inglês em toda superfície pública

Decidido em 2026-09-12, depois da v1.2.0. Antes a regra era PT-BR.

| Superfície | Idioma |
|---|---|
| README padrão (`README.md`) | inglês — o `README.pt-BR.md` existe ao lado |
| Rótulos da barra | inglês |
| Saída do `install.sh` | inglês |
| Mensagem de commit | inglês, Conventional Commits |
| **Título e corpo de release** | **inglês** |
| PR e issue | inglês |
| Templates de issue e PR | inglês |
| Este vault | português |
| Mensagens do `scripts/testar.sh` | português |

**A regra foi formulada estreita demais na primeira vez**, e custou: ela dizia "mensagens de commit", e
as sete releases saíram em português — quatro delas depois da regra existir. Release é mais visível que
commit: é o que aparece na home do repositório e no feed de quem dá watch. Ver a [issue #39](https://github.com/regisdias/claude-code-statusline/issues/39).

A pergunta para superfície nova é **"quem lê isso é de fora?"**, não "a regra citou esta superfície?".

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
