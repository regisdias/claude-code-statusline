---
tipo: bug-fix
data: 2026-09-12
---

# PowerShell: arquivo sem BOM e colisão de variável

Dois problemas que só apareceram ao rodar a versão `.ps1` no **PowerShell 5.1 de verdade**. Nenhum dos
dois aparece na leitura do código.

## 1. Sem BOM, o PowerShell 5.1 lê o arquivo como ANSI

**Sintoma:** erro de parser logo na primeira execução.

```
A cadeia de caracteres não tem o terminador: '
TerminatorExpectedAtEndOfString
```

**Causa:** o Windows PowerShell 5.1 assume ANSI quando o arquivo não tem BOM. Os bytes UTF-8 do
separador `│` viram caracteres soltos, um deles quebra a aspa simples e o script inteiro deixa de
compilar. O PowerShell 7 lê UTF-8 sem BOM e não sofre disso.

**Correção:** gravar o `.ps1` em **UTF-8 com BOM**. Com BOM, as duas versões do PowerShell funcionam.

**Cuidado permanente:** editor que salve sem BOM quebra o script de novo. O README avisa, e vale conferir
depois de qualquer edição:

```bash
head -c3 statusline-command.ps1 | xxd -p   # tem de ser efbbbf
```

## 2. Variável do PowerShell não distingue maiúscula de minúscula

**Sintoma:** a cor não fechava e a hora vazava para o meio da linha:

```
5h [32m[████░░░░░░]06:20 41% · reseta 06:20
```

**Causa:** `$reset` (hora do reset) e `$RESET` (código ANSI que encerra a cor) são **a mesma variável**.
Atribuir a hora apagou o código ANSI, que então foi impresso como texto no lugar dele.

**Correção:** renomear a variável local para `$quandoReseta`.

**Regra que fica:** em PowerShell, nome de variável que só difere por caixa é o mesmo nome. Constantes em
maiúscula (`$RESET`, `$GREEN`) precisam de nomes locais visivelmente diferentes, não só em caixa.

## Como os dois foram pegos

Rodando o script pelo `powershell.exe` do Windows a partir do WSL, com quatro payloads diferentes — ver
[[../guias/testar-local]]. Revisão de código não pegaria nenhum dos dois.
