---
name: orq-lazy
description: Versão enxuta da /orq — orquestra Codex, OpenCode e Cursor do mesmo jeito, mas aplicando o modo ponytail (a menor mudança completa, sem abstração ou recurso extra, resposta curta). Use quando o usuário pedir /orq-lazy, "orquestra no modo lazy", "orq com ponytail".
argument-hint: "Tarefa (ex.: \"botão de excluir feature\")"
user-invocable: true
---

# /orq-lazy = /orq + ponytail

> Inclui as regras do [ponytail](https://github.com/DietrichGebert/ponytail) (© 2026 DietrichGebert,
> MIT) em `ponytail.md`, sem alterações; licença em `LICENSE-ponytail`.

1. **Carregue as duas partes antes de qualquer outra coisa**:
   - chame `Skill` com `orq` — ela decide **quem** faz cada parte;
   - leia o arquivo `ponytail.md` **desta pasta** (ao lado deste SKILL.md) e siga as regras dele no
     nível `full` durante esta tarefa — ele decide **quanto** se faz. O ponytail já vem embutido; não
     precisa do plugin. Ignore as menções a comandos `/ponytail …` e a "sessão inteira": aqui as
     regras valem para a tarefa da `/orq-lazy`.

2. **Escopo ponytail antes de delegar**: liste o que a mudança precisa tocar (chamadores, testes,
   config) e corte o que ninguém pediu. Se a tarefa couber em 1–3 arquivos que você já leu, faça
   você mesmo — delegar custaria mais.

3. **Leve as regras do ponytail para dentro de cada pedido** aos outros agentes. Acrescente ao fim
   de todo pedido de implementação:

   > Regras: faça a menor mudança completa que resolve. Reuse o que já existe no projeto antes de
   > criar algo. Nada de abstração, opção, configuração ou dependência que não foi pedida. Não
   > refatore o que não é preciso. Comente só o porquê não óbvio. Lógica nova não trivial leva um
   > teste pequeno. Atalho com limite conhecido leva o comentário `shortcut: <limite>, <quando
   > melhorar>`. Ao final, liste os arquivos alterados em até 8 linhas.

   E ao pedido de revisão do OpenCode: "aponte também código que pode ser apagado ou que ninguém
   pediu (excesso), além de bugs".

4. **Ao conferir o diff**, corte você mesmo o excesso que passou (wrapper, opção, arquivo extra)
   antes de commitar.

5. **Resposta ao usuário** no formato ponytail: resultado na primeira linha, quem fez cada parte
   em poucas linhas, e terminar com uma ou duas linhas sobre o que não foi feito ou conferido e o
   risco que o usuário precisa saber.
