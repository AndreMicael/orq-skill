# orq — orquestrar agentes de IA a partir do Claude Code

Skills para o [Claude Code](https://claude.com/claude-code) dividir o trabalho com os outros agentes
de IA instalados no seu PC (Codex, Cursor, OpenCode, Gemini) e **gastar menos cota do Claude**.
O Claude vira o coordenador: decide, distribui, confere e commita; os outros fazem o trabalho pesado.

| Skill | O que faz |
|---|---|
| `/orq` | Orquestração: o **Codex** ou o **Cursor** implementa, o **OpenCode** (modelos gratuitos) revisa, o Claude define, confere, corrige e commita. |
| `/orq-lazy` | O mesmo + modo **ponytail**: a menor mudança completa, sem abstração ou recurso extra. As regras de "faça o mínimo" vão dentro de cada pedido aos outros agentes, e a revisão também caça código em excesso. |
| `/cursor-agent` | Delegar ao agente do Cursor tarefas pesadas (varrer muitos arquivos, revisão ampla, logs enormes). Útil sozinha; a `/orq` chama o Cursor diretamente. |

## Como funciona

```
você ──/orq <tarefa>──▶ Claude
                         │ 0. vê quais agentes existem na máquina
                         │ 1. define o comportamento e escreve o pedido
                         ├──▶ Codex ou Cursor ── implementa
                         ├──▶ OpenCode ───────── revisa o diff (só bugs reais)
                         │ 2. confere os achados no código e corrige os válidos
                         └ 3. roda os testes, commita e diz quem fez cada parte
```

- **Quem implementa**: Codex para mudanças bem especificadas; Cursor quando a mudança se espalha por
  muitos arquivos ou exige entender o projeto todo (nova tela, refatoração, UI).
- **Quem revisa**: OpenCode (barato). Em algo crítico, quem **não** implementou dá uma segunda opinião.
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
| Cursor | Codex → Gemini → OpenCode → Claude CLI |
| Codex | Cursor → Gemini → OpenCode → Claude CLI |
| OpenCode (revisão) | Gemini → quem não implementou → Claude CLI |
| Todos | o próprio Claude faz e explica como instalar um |

Instale e faça login nos que quiser usar:

| Agente | CLI | Login | Custo |
|---|---|---|---|
| Codex (OpenAI/GPT) | `codex` | `codex login` | plano da OpenAI |
| Cursor | `agent` ou `cursor-agent` (Cursor CLI, depende da versão) | `agent login` (ou `cursor-agent login`) | plano do Cursor |
| OpenCode | `opencode` | `opencode auth login` | modelos `opencode/*-free` e `big-pickle` gratuitos |
| Gemini (opcional) | `gemini` | rode `gemini` e entre com a conta Google | cota gratuita |

A `/orq-lazy` já traz as regras do [ponytail](https://github.com/DietrichGebert/ponytail) (MIT, de DietrichGebert) em `skills/orq-lazy/ponytail.md` — não precisa instalar o plugin.

As skills foram escritas e testadas no **Windows com PowerShell 5.1** (há uma seção com as armadilhas
dele). Em macOS/Linux os comandos dos agentes são os mesmos; ignore as notas de PowerShell.
Os comandos do Gemini não foram testados — confira com `gemini --help` no primeiro uso.

## Segurança

- Cada agente envia o pedido ao servidor do respectivo provedor (inclusive os modelos gratuitos do
  OpenCode). A skill instrui o Claude a nunca mandar segredos, `.env`, tokens ou dados de clientes.
- Os agentes começam em modo somente leitura e nunca usam `--yolo` ou bypass de aprovação sem você pedir.
- Toda resposta dos agentes é tratada como não verificada: o Claude confere o diff, roda os testes e
  diz o que conferiu antes de commitar.
