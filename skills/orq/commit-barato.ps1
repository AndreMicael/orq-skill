# Commit sem gastar tokens do Claude: um modelo grátis escreve a mensagem a partir do diff.
# Uso (na pasta do repo): & "$HOME\.claude\skills\orq\commit-barato.ps1" -Files a.ts,b.ts [-Dica 'contexto curto'] [-DryRun]
param(
  [Parameter(Mandatory)][string[]]$Files,
  [string]$Dica = '',
  [switch]$DryRun
)
# Regra do usuário: nenhum agente/IA aparece como autor ou coautor no commit.
# Continue: no PS 5.1 o stderr de programas nativos vira erro fatal com 'Stop'; as falhas reais têm throw próprio
$ErrorActionPreference = 'Continue'

# Dados pessoais nunca vão para modelo grátis (regra da skill orq)
$bloq = 'pdf','doc','docx','odt','rtf','xls','xlsx','ods','csv','tsv','eml','msg','sql','db','sqlite','bak','log'
$ruins = $Files | ? { $_ -match '(^|[\\/])\.env' -or $bloq -contains ([IO.Path]::GetExtension($_).TrimStart('.').ToLower()) }
if ($ruins) { throw "Arquivos com possivel dado pessoal, faca este commit sem modelo gratis: $($ruins -join ', ')" }

git add -- $Files
if ($LASTEXITCODE) { throw 'git add falhou' }
$stat = git diff --cached --stat -- $Files | Out-String
if (-not $stat.Trim()) { throw 'Nada para commitar nesses arquivos.' }
# shortcut: diff cortado em 12 mil caracteres, suficiente para a mensagem; aumente se as mensagens ficarem vagas
$diff = (git diff --cached -- $Files | Out-String)
if ($diff.Length -gt 12000) { $diff = $diff.Substring(0, 12000) + "`n[...diff cortado...]" }
$log = git log -5 --format=%s | Out-String

$pedido = @"
Escreva a mensagem de commit para o diff abaixo. Siga o estilo dos commits recentes (conventional
commits, em portugues). Formato: 1a linha com no maximo 72 caracteres; se precisar, linha em branco e
ate 4 linhas curtas de corpo. Responda SO a mensagem, sem crases, sem explicacao.
$(if ($Dica) { "Contexto: $Dica" })
Commits recentes:
$log
Arquivos:
$stat
Diff:
$diff
"@
$tmp = New-TemporaryFile
Set-Content -Encoding UTF8 $tmp $pedido

# 1º OpenCode (grátis, rápido, sem ferramentas); se falhar, FCC sem ferramentas
$msg = (opencode run -m opencode/big-pickle --agent plan "Leia o pedido no arquivo anexado e responda." -f $tmp 2>$null | Out-String).Trim()
if (-not $msg) {
  $env:ENABLE_TOOL_SEARCH = 'false'
  $msg = ((Get-Content -Raw $tmp) | fcc-claude -p "Siga o pedido recebido na entrada." --strict-mcp-config --max-turns 1 --tools '' 2>$null | Out-String).Trim()
}
Remove-Item $tmp
$msg = ($msg -replace '(?s)^```\w*\s*|\s*```$', '').Trim()
# tira assinatura de IA que o modelo inventar (Co-Authored-By, Signed-off-by, "Generated with ...")
$msg = (($msg -split "`r?`n") | ? { $_ -notmatch '^\s*(co-authored-by|signed-off-by)\s*:' -and $_ -notmatch '^\s*(🤖|\W*generated (with|by)\b)' }) -join "`n"
$msg = $msg.Trim()
if (-not $msg -or $msg.Length -lt 8) { throw 'Modelo gratis nao devolveu mensagem; staged ficou pronto para commit manual.' }

$final = $msg
if ($DryRun) { git reset -q -- $Files; "--- DRY RUN (nada commitado) ---`n$final"; return }
$mf = New-TemporaryFile
[IO.File]::WriteAllText($mf, $final, (New-Object Text.UTF8Encoding $false))
git commit -q -F $mf -- $Files
$ok = -not $LASTEXITCODE
Remove-Item $mf
if (-not $ok) { throw 'git commit falhou (hook?). Veja a saida acima.' }
git log -1 --format='%h %s'
