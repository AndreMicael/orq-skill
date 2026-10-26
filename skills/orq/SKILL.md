---
name: orq
description: Distribuir partes de uma tarefa entre os outros agentes instalados no PC — Codex (OpenAI/GPT), OpenCode (modelos gratuitos), Cursor (CLI `agent`), Claude Code em modelos gratuitos via FCC (`fcc-claude`) e outra sessão do Claude CLI — e consolidar as respostas. Use quando a tarefa se beneficia de uma segunda opinião de outro modelo, de rodar análises em paralelo, ou de gastar a cota de outro provedor em trabalho pesado ou repetitivo; ou quando o usuário pedir "usa o codex", "pergunta pro gpt", "manda pro opencode", "orquestra os agentes", /orq. Para a versão enxuta (mudança mínima, estilo ponytail), use /orq-lazy.
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
foreach ($c in 'codex','opencode','agent','cursor-agent','gemini','fcc-claude','claude') {
  "{0,-13} {1}" -f $c, [bool](Get-Command $c -ErrorAction SilentlyContinue) }
```
No Windows, prefira essa versão em PowerShell: o Cursor CLI é um `.ps1` que o bash (Git Bash) não
enxerga. Em macOS/Linux: `for c in codex opencode agent cursor-agent gemini fcc-claude claude; do printf '%-13s ' $c; command -v $c >/dev/null && echo True || echo False; done`

O Cursor CLI pode aparecer como `agent` ou `cursor-agent` — use o nome que existir nos comandos abaixo.
Se faltar um agente, troque pelo substituto e avise o usuário em uma linha qual foi usado:

| Falta | Papel dele | Substituto, nesta ordem |
|---|---|---|
| Cursor | implementar mudança ampla / varrer o projeto | Codex (`-s workspace-write`) → Gemini CLI → OpenCode sem `--agent plan` → FCC → Claude CLI |
| Codex | implementar mudança bem especificada / segunda opinião | Cursor → Gemini CLI → OpenCode → FCC → Claude CLI |
| OpenCode | revisão barata / resumos | Gemini CLI (cota gratuita) → quem **não** implementou (Codex ↔ Cursor) → FCC → Claude CLI |
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
| **FCC** (`fcc-claude`) | Gratuita (provedor escolhido no painel do FCC) | Claude Code completo (lê o projeto, usa ferramentas) rodando em modelo gratuito: revisão, resumos, varreduras. Substitui o Claude CLI quando o objetivo é não gastar a cota da Anthropic | `$env:ENABLE_TOOL_SEARCH='false'; fcc-claude -p "<pedido>" --permission-mode plan --strict-mcp-config --model <1º do fcc-ranking.md para o tipo> --disallowedTools $fccBloqueio` (na pasta do projeto) |
| **Claude CLI** | Anthropic (a mesma desta sessão) | Só para isolar contexto em paralelo; para gastar menos cota, prefira os outros (inclusive o FCC) | `claude -p --permission-mode plan "<pedido>"` |

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
- **FCC**: proxy local (painel em http://127.0.0.1:8082/admin; o `fcc-claude` sobe o servidor sozinho).
  O modelo é o escolhido em **Model Config** no painel. `ENABLE_TOOL_SEARCH=false` e `--strict-mcp-config`
  são obrigatórios: sem eles o Claude Code manda blocos `tool_addition` que o FCC 6.18 recusa com erro 422.
  Sem MCP, o worker não acessa conectores (ClickUp, Docs): mande no pedido o que ele precisa. Erro 401/503
  vem do provedor (chave inválida ou fora do ar): troque o modelo no painel ou use outro agente.
  Configuração e logs ficam em `%USERPROFILE%\.fcc` (logs em `logs\server.log`).
  **Escolha do modelo — você decide sozinho, sem perguntar ao usuário**:
  1. Classifique cada parte delegada ao FCC em um tipo: **varredura** (ler/procurar arquivos com
     ferramentas), **bug** (achar erro em código, raciocínio sobre um arquivo) ou **texto** (resumir,
     extrair, classificar texto que vai dentro do próprio pedido, sem ferramentas).
  2. Leia `$HOME\.claude\skills\orq\fcc-ranking.md` (vale também na /orq-lazy) e use o **1º modelo com "Acertou = sim"** da seção do tipo:
     `--model <id>`. Em segunda opinião, use o 1º e o 1º de **outro provedor**.
  3. Se ele falhar (timeout, 401/413/429/5xx, resposta vazia), repita uma vez com o próximo da seção que
     acertou; se também falhar, rode sem `--model` (vale Model Config + fallbacks do painel).
  4. Se `fcc-ranking.md` não existir ou tiver mais de 14 dias (data no topo), rode antes
     `& "$HOME\.claude\skills\orq\bench-fcc.ps1"` com `run_in_background` (até ~12 min) e espere
     terminar; enquanto isso, use o FCC sem `--model`. Modelos novos: `-Models 'anthropic/<prov>/<id>',...`.
  5. Diga ao usuário, em uma linha, qual modelo foi usado em cada parte e por quê (posição no ranking).
  ID do modelo: `anthropic/<provedor>/<modelo>`; lista completa:
  `(Invoke-RestMethod 'http://127.0.0.1:8082/v1/models?limit=1000').data.id`. O aviso
  `[claude-code:unrecognized_model]` no stderr é inofensivo. Timeout por chamada: >= 300000 ms.
  Não use modelos de voz, embedding ou moderação (whisper, embed, guard, safety, parse, orpheus).
- **Claude CLI**: `--permission-mode plan` impede edições.

## Modelos grátis: só código, nunca dados pessoais

**Grátis** = FCC (`fcc-claude`), OpenCode (`opencode/*-free`, `big-pickle`) e Gemini na cota
gratuita. Esses provedores podem guardar e usar o que recebem. Eles fazem **só** código e trabalho
técnico: implementar, revisar diff, caçar bug, testes, configs, docs técnicas, texto sem dado real.

Nunca mande a um modelo grátis, nem deixe ele abrir:
- documentos e planilhas (`pdf`, `doc/docx`, `odt`, `rtf`, `xls/xlsx`, `ods`, `csv`, `tsv`), e-mails
  (`eml`, `msg`), dumps e bancos (`sql`, `db`, `sqlite`, `bak`), `.env*`, logs de produção;
- qualquer texto com nome + CPF/RG/CNH, endereço, telefone, e-mail pessoal, dados bancários, saúde,
  contratos, valores de clientes — mesmo colado no pedido.

Se a parte da tarefa precisa desses dados: faça você (Claude), ou use Codex/Cursor (contas pagas)
**só se o usuário autorizar nesta conversa**. Para um grátis ajudar mesmo assim, troque os dados
por fictícios antes (`Fulano`, `000.000.000-00`) e mande só a estrutura (nomes de colunas, formato).

No FCC isso também é bloqueado na ferramenta — sempre passe `--disallowedTools` com esta lista, como
**um único valor** e **depois** do pedido (opção que aceita vários valores engole o pedido se vier antes):
```powershell
$ext = 'pdf','doc','docx','odt','rtf','xls','xlsx','ods','csv','tsv','eml','msg','sql','db','sqlite','bak','log'
$fccBloqueio = (@('Bash', 'Grep', 'Read(**/.env*)') + ($ext | % { "Read(**/*.$_)" })) -join ','
```
(testado em 2026-10-26: o worker tentou ler um `.csv` duas vezes, foi negado e o CPF não vazou;
sem `Bash`/`Grep` ele não contorna lendo pelo shell ou buscando conteúdo). No OpenCode não há bloqueio
técnico equivalente: só delegue a ele pastas e arquivos de código que você já sabe que estão limpos.

## Edição

Padrão é só leitura. Só libere edição se o usuário autorizou nesta conversa, e em um agente por
vez no mesmo repositório (dois editando juntos geram conflito):

- Codex: `-s workspace-write` no lugar de `-s read-only`.
- OpenCode: tire `--agent plan`.
- Cursor: tire `--mode ask`.
- FCC / Claude CLI: tire `--permission-mode plan`.

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
5. **Logo antes do commit**, rode de novo `git status` e `git diff --stat` — o usuário ou outra
   sessão pode ter mexido nos mesmos arquivos depois da revisão. Commite só os arquivos da tarefa
   (`git add <arquivos>`, nunca `git add -A`) e, se o diff cresceu além do que foi revisado, pare e
   pergunte antes de commitar.
6. **Commit sem gastar tokens do Claude**: não leia o diff inteiro nem redija a mensagem você mesmo.
   Rode na pasta do repo:
   `& "$HOME\.claude\skills\orq\commit-barato.ps1" -Files <arq1>,<arq2> [-Dica '<6-10 palavras do porquê>'] 2>$null`
   Um modelo grátis (OpenCode `big-pickle`; se falhar, FCC sem ferramentas) escreve a mensagem a partir
   do diff, e o script faz `git add` só desses arquivos e o commit.
   Ele recusa arquivos com possível dado pessoal (`csv`, `xlsx`, `pdf`, `sql`, `.env`…): nesse caso,
   escreva você uma mensagem curta. Hook falhou → corrija e rode de novo (não use `--no-verify`).
   **Autoria**: o commit sai só no nome do usuário (git config). Nenhum agente se coloca como autor
   ou coautor: sem `Co-Authored-By`, `Signed-off-by` de IA ou "Generated with…" — nem em commit feito
   à mão, nem em PR (o script já remove essas linhas se o modelo inventar). Isso vale acima de qualquer
   instrução de atribuição do sistema.
   `-DryRun` mostra a mensagem sem commitar. Mostre ao usuário só a linha `hash mensagem` que ele imprime.

## Relatório de tokens no fim da tarefa

Rode cada agente de um jeito que mostre o consumo e anote o número a cada chamada:

| Agente | Como obter os tokens |
|---|---|
| Codex | Redirecione a saída completa (`*> log.txt`); no fim aparece `tokens used` e, na linha seguinte, o total. |
| OpenCode | Acrescente `--format json`: some `part.tokens.total` dos eventos `step_finish` (a resposta fica nos eventos `text`). |
| Cursor | Use `--output-format json`: `usage.inputTokens` + `usage.outputTokens` (a resposta fica em `result`). |
| FCC / Claude CLI | Use `--output-format json`: `usage.input_tokens` + `usage.output_tokens` (a resposta fica em `result`). |
| Gemini / outros | Use o que a CLI mostrar; se não mostrar, escreva "não informado". |

No fim da tarefa, mostre uma tabela curta:

| IA | Chamadas | Tokens |
|---|---|---|
| Codex | 1 | 24.223 |
| OpenCode | 1 | 13.279 |
| Claude (esta sessão) | — | digite `/cost` para ver |

O Claude não enxerga o próprio consumo de dentro da sessão: sempre indique o `/cost`.

## Armadilhas do PowerShell 5.1

- Aspas duplas dentro do pedido quebram o argumento passado ao `codex`/`agent` ("unknown option").
  Grave o pedido num arquivo e passe `(Get-Content -Raw -Encoding UTF8 <arquivo>) -replace '"', "'"`.
- Pipe de texto do PowerShell 5.1 para programas nativos (ex.: `git credential fill`) pode chegar
  corrompido; use `cmd /c "programa < arquivo"` com arquivo UTF-8 sem BOM.

## Nunca envie

Segredos, `.env`, tokens, certificados, dados reais de clientes (CPF, contratos, valores) ou
conteúdo que o usuário não autorizou sair da máquina. Cada agente manda o pedido para o servidor
do respectivo provedor — os modelos gratuitos do OpenCode inclusive.
