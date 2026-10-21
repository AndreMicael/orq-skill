---
name: orq
description: Distribuir partes de uma tarefa entre os outros agentes instalados no PC — Codex (OpenAI/GPT), OpenCode (modelos gratuitos), Cursor (CLI `agent`) e outra sessão do Claude CLI — e consolidar as respostas. Use quando a tarefa se beneficia de uma segunda opinião de outro modelo, de rodar análises em paralelo, ou de gastar a cota de outro provedor em trabalho pesado ou repetitivo; ou quando o usuário pedir "usa o codex", "pergunta pro gpt", "manda pro opencode", "orquestra os agentes", /orq. Para a versão enxuta (mudança mínima, estilo ponytail), use /orq-lazy.
argument-hint: "Tarefa e, se quiser, qual agente (ex.: \"revisão do PR com codex e opencode\")"
user-invocable: true
---

# Orquestrar os agentes do PC

Você (Claude) é o orquestrador: quebra a tarefa, escolhe quem faz cada parte, manda pedidos
autossuficientes, confere e consolida. Os outros agentes não veem esta conversa e não decidem
nada sozinhos — a decisão final é sua e do usuário.

Todos foram testados neste PC (PowerShell) com saída não interativa.

## Passo 0: quais agentes existem nesta máquina

Antes de delegar, descubra uma vez por sessão quais CLIs estão instaladas e use só essas:

```powershell
foreach ($c in 'codex','opencode','agent','cursor-agent','gemini','claude') {
  "{0,-13} {1}" -f $c, [bool](Get-Command $c -ErrorAction SilentlyContinue) }
```
No Windows, prefira essa versão em PowerShell: o Cursor CLI é um `.ps1` que o bash (Git Bash) não
enxerga. Em macOS/Linux: `for c in codex opencode agent cursor-agent gemini claude; do printf '%-13s ' $c; command -v $c >/dev/null && echo True || echo False; done`

O Cursor CLI pode aparecer como `agent` ou `cursor-agent` — use o nome que existir nos comandos abaixo.
Se faltar um agente, troque pelo substituto e avise o usuário em uma linha qual foi usado:

| Falta | Papel dele | Substituto, nesta ordem |
|---|---|---|
| Cursor | implementar mudança ampla / varrer o projeto | Codex (`-s workspace-write`) → Gemini CLI → OpenCode sem `--agent plan` → Claude CLI |
| Codex | implementar mudança bem especificada / segunda opinião | Cursor → Gemini CLI → OpenCode → Claude CLI |
| OpenCode | revisão barata / resumos | Gemini CLI (cota gratuita) → quem **não** implementou (Codex ↔ Cursor) → Claude CLI |
| Todos | — | Faça você mesmo e diga como instalar ao menos um (ver README da skill) |

Com um único agente disponível: ele implementa e você (Claude) revisa o diff.

**Gemini CLI** (opcional, cota gratuita do Google): `gemini -p "<pedido>"` na pasta do projeto; para
permitir edição, `--approval-mode auto_edit`. Os nomes das opções mudam entre versões — confira com
`gemini --help` antes do primeiro uso (não testado na máquina onde esta skill foi escrita).

## Quem faz o quê

| Agente | Cota | Bom para | Comando (somente leitura) |
|---|---|---|---|
| **Codex** (GPT) | OpenAI | Segunda opinião em código: caçar bugs, revisar diff, pensar casos de borda e testes | `codex exec -s read-only -C <pasta> -o <arquivo.txt> "<pedido>"` |
| **OpenCode** | Modelos gratuitos (`opencode/*-free`, `opencode/big-pickle`) | Trabalho barato e em volume: resumir, classificar, rascunhos, inventários simples | `opencode run --agent plan -m opencode/big-pickle --dir <pasta> "<pedido>" 2>$null` |
| **Cursor** (`agent`) | Cursor | Varrer muitos arquivos, revisão ampla do projeto ou de UI, logs enormes, implementar features médias que tocam vários arquivos (lê o projeto inteiro sozinho) | `agent -p --trust --mode ask --workspace <pasta> --output-format text "<pedido>"` |
| **Claude CLI** | Anthropic (a mesma desta sessão) | Só para isolar contexto em paralelo; para gastar menos cota, prefira os outros | `claude -p --permission-mode plan "<pedido>"` |

Notas de cada um:

- **Codex**: a resposta final sai limpa no arquivo de `-o`; leia com `Get-Content <arquivo> -Raw`.
  Fora de repositório git, acrescente `--skip-git-repo-check`. Modelo específico: `-m <modelo>`.
  Continuar a mesma conversa: `codex exec resume --last "<pergunta seguinte>"`.
- **OpenCode**: `--agent plan` é o agente de leitura; o padrão (`build`) edita arquivos. Os logs vão
  para o stderr (por isso `2>$null`); a resposta fica no stdout. Ver modelos: `opencode models`.
  Continuar a sessão: `--continue` ou `--session <id>`.
- **Cursor**: `agent` é um script PowerShell (`agent.ps1`), então rode pelo PowerShell. `--mode ask`
  é só leitura; `--trust` evita a pergunta de confiar na pasta; outro repo junto: `--add-dir <pasta>`.
  O shell dele às vezes bloqueia `node --test` — se ele disser isso, rode você os testes.
  Continuar a sessão: `--output-format json` devolve `session_id`; depois
  `agent -p --trust --mode ask --resume <session_id> "<pergunta seguinte>"`.
  Erro de login: peça ao usuário `! agent login`. Detalhes: skill `cursor-agent`.
- **Claude CLI**: `--permission-mode plan` impede edições.

## Edição

Padrão é só leitura. Só libere edição se o usuário autorizou nesta conversa, e em um agente por
vez no mesmo repositório (dois editando juntos geram conflito):

- Codex: `-s workspace-write` no lugar de `-s read-only`.
- OpenCode: tire `--agent plan`.
- Cursor: tire `--mode ask`.
- Claude CLI: tire `--permission-mode plan`.

Nunca use `--dangerously-bypass-approvals-and-sandbox`, `--yolo`, `--force` ou equivalentes sem o
usuário pedir.

## Como orquestrar

1. **Quebre a tarefa** em partes independentes e escolha o agente de cada uma pela tabela.
   Tarefa pequena (1–3 arquivos que você já leu) não vale delegar: faça você.
2. **Escreva cada pedido autossuficiente**: objetivo em uma frase, stack e pastas relevantes, o que
   analisar e o que **não** mexer, e o formato da resposta ("no máximo 20 linhas, em português;
   cada achado com `arquivo:linha` e uma frase; sem colar código inteiro").
3. **Rode em paralelo** os que forem independentes: um comando por chamada com
   `run_in_background`, timeout de pelo menos 300000 ms, e espere as notificações — não fique
   consultando.
4. **Segunda opinião**: para algo crítico (bug difícil, revisão antes de merge), mande o mesmo
   pedido a dois agentes de provedores diferentes e compare. Onde concordam, a confiança sobe; onde
   divergem, verifique você mesmo no código.
5. **Confira antes de afirmar**: trate toda resposta como não verificada. Confira por amostragem os
   `arquivo:linha` citados. Se algum agente editou, rode `git diff --stat`, leia o diff e rode
   lint/tsc.
6. **Consolide para o usuário**: diga qual agente fez cada parte, o que você conferiu e onde houve
   divergência.

## Fluxo padrão para implementar

1. Claude define o comportamento (regras, segurança, o que não mexer) e grava o pedido num arquivo
   do scratchpad.
2. **Quem implementa**: **Codex** (`-s workspace-write`) para mudanças bem especificadas; **Cursor**
   (sem `--mode ask`) quando a mudança espalha por muitos arquivos ou exige entender o projeto todo
   (ex.: nova view, refatoração ampla, UI). Um por vez no mesmo repo.
3. **Quem revisa**: **OpenCode** procura só bugs reais no `git diff` (barato). Para algo crítico,
   peça também a segunda opinião de quem **não** implementou (Codex ↔ Cursor).
4. Claude confere os achados no código, corrige os válidos (poucas linhas), testa e commita.

## Armadilhas do PowerShell 5.1

- Aspas duplas dentro do pedido quebram o argumento passado ao `codex`/`agent` ("unknown option").
  Grave o pedido num arquivo e passe `(Get-Content -Raw -Encoding UTF8 <arquivo>) -replace '"', "'"`.
- Pipe de texto do PowerShell 5.1 para programas nativos (ex.: `git credential fill`) pode chegar
  corrompido; use `cmd /c "programa < arquivo"` com arquivo UTF-8 sem BOM.

## Nunca envie

Segredos, `.env`, tokens, certificados, dados reais de clientes (CPF, contratos, valores) ou
conteúdo que o usuário não autorizou sair da máquina. Cada agente manda o pedido para o servidor
do respectivo provedor — os modelos gratuitos do OpenCode inclusive.
