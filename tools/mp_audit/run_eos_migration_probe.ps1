# Epic P2P host devri bağlantı ölçümü (bkz. eos_migration_probe.gd). Kullanım:
#   powershell -ExecutionPolicy Bypass -File tools/mp_audit/run_eos_migration_probe.ps1 [-NewSock same|diff] [-BDelay 0] [-Retry 5] [-CloseOld 1]
param([string]$NewSock = "same", [double]$BDelay = 0, [double]$Retry = 5, [int]$CloseOld = 1, [int]$Pause = 0, [int]$Always = 0, [int]$TimeoutSec = 240)
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$dir = Join-Path $env:TEMP "lilslayers_mp_audit\eosmigprobe"
New-Item -ItemType Directory -Force $dir | Out-Null
Remove-Item (Join-Path $dir "*") -Force -ErrorAction SilentlyContinue
$env:MP_DIR = $dir; $env:MP_NEWSOCK = $NewSock; $env:MP_B_DELAY = "$BDelay"; $env:MP_RETRY = "$Retry"; $env:MP_CLOSE_OLD = "$CloseOld"; $env:MP_PAUSE = "$Pause"; $env:MP_ALWAYS = "$Always"
$runner = "res://tools/mp_audit/eos_migration_probe.gd"
$args0 = @("--headless", "--path", "`"$proj`"")
$procs = @()
foreach ($r in @("h", "b", "c")) {
	$env:MP_ROLE = $r; $env:LILSLAYERS_UID = "uidmigprobe$r"
	$procs += Start-Process -FilePath $godot -ArgumentList ($args0 + @("--log-file", "`"$dir\$r.log`"", "-s", $runner)) -NoNewWindow -PassThru -RedirectStandardOutput "$dir\${r}_out.txt" -RedirectStandardError "$dir\${r}_err.txt"
	Start-Sleep -Milliseconds 1200
}
foreach ($p in $procs) { if (-not $p.WaitForExit($TimeoutSec * 1000)) { $p.Kill(); Write-Output "RUN: zaman asimi" } }
Get-Content "$dir\h_out.txt", "$dir\b_out.txt", "$dir\c_out.txt" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String -Pattern "^MPR" | ForEach-Object { $_.Line }
"Cikti: $dir"
