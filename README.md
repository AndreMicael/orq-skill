# orq — orquestrar agentes de IA a partir do Claude Code

Skills para o [Claude Code](https://claude.com/claude-code) dividir o trabalho com os outros agentes
de IA instalados no seu PC (Codex, Cursor, OpenCode, Gemini e o próprio Claude Code rodando em modelos
gratuitos via [Free Claude Code](https://github.com/Alishahryar1/free-claude-code)) e **gastar menos cota do Claude**.
O Claude vira o coordenador: decide, distribui, confere e commita; os outros fazem o trabalho pesado.

| Skill | O que faz |
|---|---|
| `/orq` | Orquestração: o **Codex** ou o **Cursor** implementa, o **OpenCode** ou o **FCC** (modelos gratuitos) revisa, o Claude define, confere e corrige; o commit sai por um modelo gratuito. |
| `/orq-lazy` | O mesmo + modo **ponytail**: a menor mudança completa, sem abstração ou recurso extra. As regras de "faça o mínimo" vão dentro de cada pedido aos outros agentes, e a revisão também caça código em excesso. |
| `/cursor-agent` | Delegar ao agente do Cursor tarefas pesadas (varrer muitos arquivos, revisão ampla, logs enormes). Útil sozinha; a `/orq` chama o Cursor diretamente. |

## Como funciona

```
você ──/orq <tarefa>──▶ Claude
                         │ 0. vê quais agentes existem na máquina
                         │ 1. define o comportamento e escreve o pedido
                         ├──▶ Codex ou Cursor ── implementa
                         ├──▶ OpenCode / FCC ─── revisa o diff (só bugs reais)
                         │ 2. confere os achados no código e corrige os válidos
                         ├ 3. roda os testes e diz quem fez cada parte
                         └──▶ commit-barato ──── modelo grátis escreve a mensagem e commita
```

- **Quem implementa**: Codex para mudanças bem especificadas; Cursor quando a mudança se espalha por
  muitos arquivos ou exige entender o projeto todo (nova tela, refatoração, UI).
- **Quem revisa**: OpenCode (barato). Em algo crítico, quem **não** implementou dá uma segunda opinião.
- **Modelo do FCC**: o Claude escolhe sozinho, por tipo de tarefa (varredura, bug, texto), o modelo
  mais bem colocado no ranking gerado pelo `bench-fcc.ps1` (veja abaixo).
- **Dados pessoais**: modelos gratuitos fazem só código. Documentos, planilhas, dumps, `.env` e texto com
  CPF, endereço etc. nunca vão para eles; no FCC a leitura desses arquivos é bloqueada na ferramenta.
- **Commit sem gastar o Claude**: `commit-barato.ps1` manda o diff a um modelo gratuito, que escreve a
  mensagem; o script commita só os arquivos da tarefa. O commit sai **só no seu nome**, sem
  `Co-Authored-By` ou "Generated with" de nenhuma IA.
- **Tokens**: no fim, o Claude mostra uma tabela com os tokens gastos por cada IA (o dele próprio aparece com `/cost`).
- **Tarefa pequena** (1–3 arquivos que o Claude já leu): ele faz sozinho — delegar custaria mais.
- O padrão dos agentes é **somente leitura**; só editam quando você autoriza na conversa, e um por vez no mesmo repositório.

## Exemplos

```text
/orq adicionar botão de excluir feature no painel
/orq revisar o PR atual com codex e opencode
/orq onde esse erro de login é tratado? usa o cursor
/orq-lazy corrigir o cálculo do desconto sem mexer no resto
```

## Instalar

Copie as pastas de `skills/` para `~/.claude/skills/`:

```powershell
# Windows (PowerShell)
git clone https://github.com/AndreMicael/orq-skill
Copy-Item -Recurse -Force orq-skill\skills\* "$env:USERPROFILE\.claude\skills\"
```

```bash
# macOS / Linux
git clone https://github.com/AndreMicael/orq-skill
cp -r orq-skill/skills/* ~/.claude/skills/
```

Abra uma nova sessão do Claude Code e digite `/orq` ou `/orq-lazy` seguido da tarefa.

### Atualizar

```powershell
cd orq-skill; git pull
Copy-Item -Recurse -Force skills\* "$env:USERPROFILE\.claude\skills\"   # macOS/Linux: cp -r skills/* ~/.claude/skills/
```

## Pré-requisitos

**Não precisa ter todos os agentes.** A `/orq` verifica quais existem na máquina e troca o que
faltar pelo substituto, avisando qual usou:

| Falta | Quem assume, nesta ordem |
|---|---|
| Cursor | Codex → Gemini → OpenCode → FCC → Claude CLI |
| Codex | Cursor → Gemini → OpenCode → FCC → Claude CLI |
| OpenCode (revisão) | Gemini → quem não implementou → FCC → Claude CLI |
| Todos | o próprio Claude faz e explica como instalar um |

Instale e faça login nos que quiser usar:

| Agente | CLI | Login | Custo |
|---|---|---|---|
| Codex (OpenAI/GPT) | `codex` | `codex login` | plano da OpenAI |
| Cursor | `agent` ou `cursor-agent` (Cursor CLI, depende da versão) | `agent login` (ou `cursor-agent login`) | plano do Cursor |
| OpenCode | `opencode` | `opencode auth login` | modelos `opencode/*-free` e `big-pickle` gratuitos |
| Gemini (opcional) | `gemini` | rode `gemini` e entre com a conta Google | cota gratuita |
| FCC (opcional) | `fcc-claude` | chaves dos provedores no painel do FCC | modelos gratuitos (NVIDIA NIM, OpenRouter, Groq…) |

A `/orq-lazy` já traz as regras do [ponytail](https://github.com/DietrichGebert/ponytail) (MIT, de DietrichGebert) em `skills/orq-lazy/ponytail.md` — não precisa instalar o plugin.

As skills foram escritas e testadas no **Windows com PowerShell 5.1** (há uma seção com as armadilhas
dele). Em macOS/Linux os comandos dos agentes são os mesmos; ignore as notas de PowerShell.
Os comandos do Gemini não foram testados — confira com `gemini --help` no primeiro uso.

## FCC (Free Claude Code)

O [FCC](https://github.com/Alishahryar1/free-claude-code) é um proxy local que faz o Claude Code rodar em
modelos gratuitos. A `/orq` o usa como mais um agente (`fcc-claude`), com os modelos que você configurar.

1. Instale o FCC e cadastre as chaves dos provedores no painel (`http://127.0.0.1:8082/admin`).
   Em **Model Config**, escolha um modelo padrão e adicione **Fallback Models** de outros provedores.
2. Gere o ranking uma vez (até ~12 min); ele testa os modelos em três tipos de tarefa com arquivos de
   teste próprios (nada do seu projeto sai da máquina) e grava `fcc-ranking.md` ao lado da skill:
   ```powershell
   & "$env:USERPROFILE\.claude\skills\orq\bench-fcc.ps1"
   # outros modelos: -Models 'anthropic/<provedor>/<modelo>','...'
   ```
   A `/orq` refaz o ranking sozinha se ele tiver mais de 14 dias.
3. Pronto: `/orq revisar o diff com o fcc`. O Claude escolhe o modelo pelo ranking, tenta o próximo se
   falhar e, por último, o padrão do painel.

Testado com FCC 6.18 e Claude Code 2.1. A skill passa `ENABLE_TOOL_SEARCH=false` e `--strict-mcp-config`
porque, sem isso, o FCC 6.18 recusa as requisições (erro 422). O worker do FCC roda sem conectores MCP.

## Segurança

- Cada agente envia o pedido ao servidor do respectivo provedor (inclusive os modelos gratuitos do
  OpenCode e do FCC). A skill instrui o Claude a nunca mandar segredos, `.env`, tokens ou dados de clientes.
- **Modelos gratuitos só recebem código.** Provedores gratuitos podem guardar o que recebem, então
  documentos, planilhas, e-mails, dumps, logs de produção e dados pessoais ficam com o Claude (ou com
  Codex/Cursor, se você autorizar). No FCC, a leitura de `pdf`, `docx`, `xlsx`, `csv`, `sql`, `.env` etc.,
  o shell e a busca por conteúdo ficam bloqueados (`--disallowedTools`); o `commit-barato.ps1` recusa
  esses arquivos. O OpenCode não tem bloqueio técnico: a regra vale por instrução.
- Os agentes começam em modo somente leitura e nunca usam `--yolo` ou bypass de aprovação sem você pedir.
- Toda resposta dos agentes é tratada como não verificada: o Claude confere o diff, roda os testes e
  diz o que conferiu antes de commitar.

## Créditos

- **[ponytail](https://github.com/DietrichGebert/ponytail)** — © 2026 DietrichGebert, licença MIT.
  As regras do modo lazy em [`skills/orq-lazy/ponytail.md`](skills/orq-lazy/ponytail.md) são uma
  cópia sem alterações da skill `ponytail` (v5.2.0). A licença original está em
  [`skills/orq-lazy/LICENSE-ponytail`](skills/orq-lazy/LICENSE-ponytail). Se gostar, instale e apoie
  o projeto original.
- **Agentes orquestrados**: [Claude Code](https://claude.com/claude-code) (Anthropic),
  [Codex CLI](https://github.com/openai/codex) (OpenAI), [Cursor CLI](https://cursor.com/cli),
  [OpenCode](https://opencode.ai), [Gemini CLI](https://github.com/google-gemini/gemini-cli) (Google) e
  [Free Claude Code](https://github.com/Alishahryar1/free-claude-code) (Alishahryar1, AGPL-3.0; usado como
  programa externo, nenhum código dele está neste repositório).
  Este projeto não é afiliado a nenhum deles; os nomes pertencem aos respectivos donos.
- Skills `orq`, `orq-lazy` e `cursor-agent`: [AndreMicael](https://github.com/AndreMicael), escritas com o Claude Code.
