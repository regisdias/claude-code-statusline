---
tipo: decisao
data: 2026-09-12
---

# main → stg → develop → branch de tarefa

## Decisão

Nada entra direto na `main`. O trabalho sobe de baixo para cima:

```
feat/1-git-branch-in-bar  →  develop  →  stg  →  main
```

| Branch | Papel |
|---|---|
| `main` | Produção. O README instala com `curl .../main/install.sh`. Protegida: exige PR e CI verde. |
| `stg` | Homologação: candidata a release antes de subir. Protegida igual. |
| `develop` | Integração. O pronto acumula aqui entre releases. |
| `<tipo>/<issue>-<descrição>` | Uma tarefa cada, saindo da `develop`. |

Nome da branch de tarefa: `<tipo>/<número da issue>-<descrição-curta-em-inglês>`, com o `<tipo>` igual
ao do Conventional Commits que o trabalho vai usar — `feat/1-git-branch-in-bar` gera `feat: …` e bump
minor. A issue vem antes; o número é o que amarra os dois.

## Por quê

Até a v1.1.0 tudo foi commitado direto na `main`. Funcionava por ser projeto de uma pessoa, mas o
repositório é público: quem olha o histórico vê como o projeto é tocado, e commit direto na branch de
produção não passa a impressão certa — nem dá chance de o CI barrar antes.

O que a separação compra, na prática:

- **`main` protegida** significa que a `main` não quebra por descuido. Como não há artefato entre o
  commit e quem instala, push quebrado é instalação quebrada na hora.
- **`stg` existir** dá um lugar para a release candidata ficar sem travar a `develop`.
- **Branch por tarefa** deixa o PR ser a unidade de revisão, com o CI rodando no diff isolado.

## Consequências

- O CI passou a rodar em `push` para `main`, `stg` e `develop`, e em `pull_request` para as três.
- Proteção ligada em `main` e `stg`: PR obrigatório e checks verdes. A `develop` ficou livre, senão
  cada ajuste de trabalho viraria PR.
- **Zero aprovações obrigatórias**, porque o GitHub não deixa ninguém aprovar o próprio PR e o projeto
  é de uma pessoa. É o ponto fraco honesto deste arranjo: o PR documenta e o CI barra, mas revisão de
  outra pessoa só acontece quando aparecer outra pessoa.
- Tag sai só da `main`, e o `CHANGELOG` é atualizado em `Unreleased` no mesmo PR da mudança.

## Histórico linear fica **desligado** na main e na stg

Parece contraintuitivo num repositório que quer parecer caprichado, mas `required_linear_history`
proíbe merge commit — e numa cadeia de promoção isso quebra tudo.

Com histórico linear obrigatório, `develop → stg` teria de ser *squash* ou *rebase*. Os dois reescrevem
SHA: a `stg` receberia commits novos, diferentes dos da `develop`, e as duas divergiriam para sempre. A
promoção seguinte traria o histórico inteiro da `develop` de novo, como se fosse novidade.

Merge commit é justamente o que mantém `develop`, `stg` e `main` na mesma linhagem: cada promoção é um
merge limpo, porque o topo de uma é sempre ancestral da outra.

O histórico linear continua valendo para a **branch de tarefa**, que entra na `develop` com squash — aí
sim, um commit por tarefa, e a `develop` não é protegida.

Veja também [[ci-em-push-e-pr]].
