# Epic P2P bağlantı gecikmesi ölçümü (bkz. eos_connect_probe.gd). Kullanım:
#   powershell -ExecutionPolicy Bypass -File tools/mp_audit/run_eos_probe.ps1 -SDelay 3 -Retry 5 [-Mode fresh|lobby]
param([double]$SDelay = 0, [double]$Retry = 0, [string]$Mode = "fresh", [int]$TimeoutSec = 200)
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$dir = Join-Path $env:TEMP "lilslayers_mp_audit\eosprobe"
New-Item -ItemType Directory -Force $dir | Out-Null
Remove-Item (Join-Path $dir "*") -Force -ErrorAction SilentlyContinue
$env:MP_DIR = $dir; $env:MP_S_DELAY = "$SDelay"; $env:MP_RETRY = "$Retry"; $env:MP_MODE = $Mode; $env:MP_TAG = "PRB" + (Get-Random -Maximum 99999)
$runner = "res://tools/mp_audit/eos_connect_probe.gd"
$args0 = @("--headless", "--path", "`"$proj`"")
$env:MP_ROLE = "server"; $env:LILSLAYERS_UID = "uidprobes001"
$s = Start-Process -FilePath $godot -ArgumentList ($args0 + @("--log-file", "`"$dir\server.log`"", "-s", $runner)) -NoNewWindow -PassThru -RedirectStandardOutput "$dir\server_out.txt" -RedirectStandardError "$dir\server_err.txt"
Start-Sleep -Milliseconds 1200
$env:MP_ROLE = "client"; $env:LILSLAYERS_UID = "uidprobec002"
$c = Start-Process -FilePath $godot -ArgumentList ($args0 + @("--log-file", "`"$dir\client.log`"", "-s", $runner)) -NoNewWindow -PassThru -RedirectStandardOutput "$dir\client_out.txt" -RedirectStandardError "$dir\client_err.txt"
foreach ($p in @($s, $c)) { if (-not $p.WaitForExit($TimeoutSec * 1000)) { $p.Kill(); Write-Output "RUN: zaman asimi" } }
Get-Content "$dir\server_out.txt", "$dir\client_out.txt" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String -Pattern "^PROBE" | ForEach-Object { $_.Line }
"Cikti: $dir"
