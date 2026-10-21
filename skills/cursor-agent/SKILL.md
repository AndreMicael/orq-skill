---
name: cursor-agent
description: Delegar ao agente do Cursor (CLI `agent`) tarefas que gastariam muitos tokens do Claude — varrer muitos arquivos, revisar o projeto inteiro, ler logs ou saídas enormes, resumir documentação longa, edições mecânicas em massa. Use por conta própria quando perceber que a tarefa vai consumir muito contexto, ou quando o usuário pedir "usa o cursor", "manda pro cursor", /cursor-agent.
argument-hint: "Tarefa para o Cursor (ex.: \"revise a landing e diga se o mask do mobile está ok\")"
user-invocable: true
---

# Delegar ao agente do Cursor

O Cursor gasta a cota do Cursor, não a do Claude. Você (Claude) monta o pedido, o Cursor faz o
trabalho pesado e devolve só a conclusão. Você confere e decide.

## Quando delegar

- **Sim**: ler/varrer muitos arquivos para achar algo; revisão ampla de código ou UI; resumir logs,
  PDFs ou docs grandes; inventário ("liste todas as rotas e quem chama cada uma"); edições
  repetitivas em muitos arquivos.
- **Não**: tarefa pequena (1–3 arquivos que você já leu); decisões de arquitetura, regra de
  negócio, dinheiro ou segurança (o Cursor pode levantar dados, a decisão é sua e do usuário);
  qualquer coisa que envolva segredos, `.env` ou dados reais de clientes.

## Como chamar (PowerShell)

Leitura (padrão — o Cursor não altera nada):

```powershell
agent -p --trust --mode ask --output-format text @'
<pedido>
'@
```

Edição (só se o usuário já autorizou o Cursor a mexer nos arquivos nesta conversa):

```powershell
agent -p --trust @'
<pedido>
'@
```

- Rode no diretório do projeto (ou passe `--workspace <caminho>`). Outro repositório junto:
  `--add-dir <caminho>`.
- Tarefas longas: use `run_in_background` e espere a notificação; não fique consultando.
- Timeout de pelo menos 300000 ms.
- Nunca use `--force`/`--yolo` (libera qualquer comando de shell) sem o usuário pedir.

## Conversa em vários turnos

O modo interativo (TUI) não funciona aqui, mas dá para continuar a mesma sessão do Cursor,
que já tem o contexto lido, sem reenviar tudo:

```powershell
$r = agent -p --trust --mode ask --output-format json @'
<primeiro pedido>
'@ | ConvertFrom-Json
$r.result       # resposta
$r.session_id   # guarde para os próximos turnos

agent -p --trust --mode ask --output-format text --resume <session_id> "<pergunta seguinte>"
```

Use quando a primeira resposta precisar de aprofundamento ("detalhe o achado 3",
"agora corrija só isso") — mais barato que o Claude reler os arquivos.

## Como escrever o pedido

O Cursor não vê esta conversa. O pedido precisa ser autossuficiente e pedir uma resposta curta:

1. Objetivo em uma frase e o contexto mínimo (stack, pastas relevantes).
2. O que exatamente analisar ou alterar, e o que **não** mexer.
3. Formato da resposta: "no máximo 20 linhas, em português; cada achado com `arquivo:linha` e
   uma frase; sem colar código inteiro".
4. Para edição: "faça só a menor mudança; ao final liste os arquivos alterados".

## Depois da resposta

- Trate o resultado como não verificado: confira por amostragem os `arquivo:linha` citados
  (Grep/Read só nesses trechos) antes de afirmar algo ao usuário.
- Se o Cursor editou: rode `git diff --stat` e leia o diff antes de seguir. Rode lint/tsc se o
  projeto tiver.
- Ao responder ao usuário, diga que a análise veio do Cursor e o que você conferiu.
- Se `agent` falhar com erro de login, peça ao usuário para rodar `! agent login`.
