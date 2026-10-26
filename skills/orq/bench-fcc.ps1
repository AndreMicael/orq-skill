# Benchmark dos modelos do FCC por tipo de tarefa. Grava fcc-ranking.md ao lado deste script.
# Uso: powershell -NoProfile -File bench-fcc.ps1 [-Models 'anthropic/x/y','...'] [-TimeoutSec 240]
# Usa só arquivos de teste gerados aqui (nenhum dado do projeto sai da máquina).
param(
  [string[]]$Models = @(
    'anthropic/open_router/nvidia/nemotron-3-ultra-550b-a55b:free',
    'anthropic/open_router/nvidia/nemotron-3-super-120b-a12b:free',
    'anthropic/open_router/poolside/laguna-s-2.1:free',
    'anthropic/open_router/cohere/north-mini-code:free',
    'anthropic/nvidia_nim/z-ai/glm-5.3',
    'anthropic/nvidia_nim/z-ai/glm-5.3-flash',
    'anthropic/nvidia_nim/deepseek-ai/deepseek-v4.1-flash',
    'anthropic/nvidia_nim/minimaxai/minimax-m3.1-flash',
    'anthropic/groq/qwen/qwen3.8-27b'
  ),
  [int]$TimeoutSec = 240
)
$ErrorActionPreference = 'Stop'
$out = Join-Path $PSScriptRoot 'fcc-ranking.md'
$fx = Join-Path $env:TEMP "fcc-bench-$PID"
New-Item -ItemType Directory -Force $fx | Out-Null
1..7 | ForEach-Object { Set-Content "$fx\nota$_.txt" ("item $_" + $(if ($_ -in 2,5,6) { "`nTODO-X revisar" } else { '' })) }
@'
def media(valores):
    total = 0
    for i in range(1, len(valores)):
        total += valores[i]
    return total / len(valores)
'@ | Set-Content "$fx\calc.py"

# tipo -> pedido e checagem da resposta
$tasks = [ordered]@{
  varredura = @{ p = 'Quais arquivos desta pasta contem o texto TODO-X? Responda so os nomes separados por virgula.'
                 ok = { param($r) $n = [regex]::Matches($r, 'nota\d') | % Value | Sort-Object -Unique; ($n -join ',') -eq 'nota2,nota5,nota6' } }
  bug       = @{ p = 'Leia calc.py. Em qual numero de linha esta o bug? Responda so o numero.'
                 ok = { param($r) $r -match '\b3\b' } }
  texto     = @{ p = 'Sem usar ferramentas, extraia do texto a seguir um JSON {"cidade":...,"ano":...} e responda so o JSON: A fabrica foi aberta em Cuiaba no ano de 1987 e fechou em 2003.'
                 ok = { param($r) $r -match 'Cuiab' -and $r -match '1987' -and $r -notmatch '2003"?\s*}' } }
}

$jobs = foreach ($m in $Models) {
  Start-Job -ArgumentList $m, $fx, $TimeoutSec, ($tasks.Keys -join '|'), (($tasks.Values | % { $_.p }) -join '|||') {
    param($m, $fx, $to, $keys, $prompts)
    Set-Location $fx; $env:ENABLE_TOOL_SEARCH = 'false'
    $k = $keys -split '\|'; $ps = $prompts -split '\|\|\|'
    for ($i = 0; $i -lt $k.Count; $i++) {
      $t = [Diagnostics.Stopwatch]::StartNew()
      $inner = Start-Job -ArgumentList $m, $fx, $ps[$i] { param($m, $fx, $p) Set-Location $fx; $env:ENABLE_TOOL_SEARCH = 'false'
        fcc-claude -p --model $m --permission-mode plan --strict-mcp-config --max-turns 6 --output-format json $p 2>$null | Out-String }
      $raw = if (Wait-Job $inner -Timeout $to) { Receive-Job $inner } else { Stop-Job $inner; $null }
      $res = ''; $tok = 0; $err = 'timeout'
      if ($raw) { try { $j = $raw | ConvertFrom-Json; $res = "$($j.result)"; $tok = [int]$j.usage.input_tokens + [int]$j.usage.output_tokens; $err = if ($j.is_error) { 'erro' } else { '' } } catch { $err = 'erro' } }
      [pscustomobject]@{ model = $m; tipo = $k[$i]; secs = [int]$t.Elapsed.TotalSeconds; tokens = $tok; err = $err; resp = $res }
    }
  }
}
$rows = $jobs | Wait-Job | Receive-Job
# limpa workers que sobraram de timeouts
Get-CimInstance Win32_Process | ? { $_.CommandLine -match 'strict-mcp-config' -and $_.CommandLine -match 'max-turns 6' } | % { Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }
foreach ($r in $rows) { $r | Add-Member ok ($r.err -eq '' -and [bool](& $tasks[$r.tipo].ok $r.resp)) }

$md = @("# Ranking dos modelos do FCC", "", "Gerado por bench-fcc.ps1 em $(Get-Date -Format 'yyyy-MM-dd HH:mm'). Ordem: acertou, depois mais rapido.", "")
foreach ($k in $tasks.Keys) {
  $md += "## $k", "", "| # | Modelo | Acertou | Segundos | Tokens | Falha |", "|---|---|---|---|---|---|"
  $n = 0
  $rows | ? tipo -eq $k | Sort-Object @{e = { -not $_.ok } }, secs | % { $n++; $md += "| $n | ``$($_.model)`` | $(if ($_.ok) {'sim'} else {'nao'}) | $($_.secs) | $($_.tokens) | $($_.err) |" }
  $md += ''
}
$md | Set-Content -Encoding UTF8 $out
Remove-Item -Recurse -Force $fx
$md -join "`n"
