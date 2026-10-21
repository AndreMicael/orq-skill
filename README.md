# orq — orquestrar agentes de IA a partir do Claude Code

Skills para o [Claude Code](https://claude.com/claude-code) distribuir o trabalho entre os outros
agentes de IA instalados no seu PC e gastar menos cota do Claude:

| Skill | O que faz |
|---|---|
| `/orq` | O Claude vira orquestrador: quebra a tarefa, manda o **Codex** ou o **Cursor** implementar, o **OpenCode** (modelos gratuitos) revisar, e ele só define, confere, corrige e commita. |
| `/orq-lazy` | Mesma coisa + modo **ponytail**: a menor mudança completa, sem abstração ou recurso extra, e regras de "faça o mínimo" embutidas em cada pedido aos outros agentes. |
| `/cursor-agent` | Delegar tarefas pesadas (varrer muitos arquivos, revisão ampla, logs enormes) ao agente do Cursor. Usada pela `/orq`. |

## Instalar

Copie as pastas de `skills/` para `~/.claude/skills/`:

```powershell
# Windows (PowerShell)
git clone https://github.com/AndreMicael/orq-skill
Copy-Item -Recurse orq-skill\skills\* "$env:USERPROFILE\.claude\skills\"
```

```bash
# macOS / Linux
git clone https://github.com/AndreMicael/orq-skill
cp -r orq-skill/skills/* ~/.claude/skills/
```

Abra uma nova sessão do Claude Code e digite `/orq` ou `/orq-lazy` seguido da tarefa.

## Pré-requisitos

Instale e faça login nos agentes que quiser usar. **Não precisa ter todos**: a `/orq` detecta quais existem na máquina e troca o que faltar pelo substituto (ex.: sem Cursor, o Codex implementa; sem OpenCode, o Gemini ou o outro agente revisa; sem nenhum, o próprio Claude faz).

| Agente | CLI | Login |
|---|---|---|
| Codex (OpenAI/GPT) | `codex` | `codex login` |
| OpenCode | `opencode` | `opencode auth login` (os modelos `opencode/*-free` e `big-pickle` são gratuitos) |
| Cursor | `agent` (Cursor CLI) | `agent login` |
| Gemini (opcional) | `gemini` | rode `gemini` uma vez e entre com a conta Google (cota gratuita) |

Para o `/orq-lazy`: o plugin **ponytail** instalado no Claude Code (a skill chama `ponytail:ponytail`).

As skills foram escritas e testadas no **Windows com PowerShell 5.1** (há uma seção com as armadilhas
dele). Em macOS/Linux os comandos dos agentes são os mesmos; ignore as notas de PowerShell.

## Segurança

- Cada agente envia o pedido ao servidor do respectivo provedor. A skill instrui o Claude a nunca
  mandar segredos, `.env`, tokens ou dados de clientes.
- O padrão é **somente leitura**; os agentes só editam arquivos quando você pede, e um por vez no
  mesmo repositório. Nunca usa `--yolo`/bypass sem você pedir.
