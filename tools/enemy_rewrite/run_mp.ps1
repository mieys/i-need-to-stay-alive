# Yaratık yeniden yazımı - iki süreçli çok oyunculu test (bkz. mp_runner.gd başı).
#   powershell -File tools/enemy_rewrite/run_mp.ps1 [-N 60] [-Tier 3] [-Secs 20] [-Port 7791] [-Net lan|epic]
# Çıktı: iki sürecin MP satırları + host'un MP_RESULT satırı. Ham kayıtlar %TEMP%\enemy_rewrite_mp\ altında.
param(
	[int]$EnemyWorld = 1,
	[int]$N = 60,
	[int]$Tier = 3,
	[int]$Secs = 20,
	[int]$Port = 7791,
	[int]$TimeoutSec = 240,
	[string]$Net = "lan"
)
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$dir = Join-Path $env:TEMP "enemy_rewrite_mp"
New-Item -ItemType Directory -Force $dir | Out-Null
Remove-Item (Join-Path $dir "*") -Force -ErrorAction SilentlyContinue
$env:MP_DIR = $dir; $env:MP_PORT = "$Port"; $env:MP_N = "$N"; $env:MP_TIER = "$Tier"; $env:MP_SECS = "$Secs"; $env:MP_NET = $Net; $env:MP_TAG = "EW" + (Get-Random -Maximum 99999)
$env:ENEMY_WORLD = "$EnemyWorld"
$common = @("--headless", "--path", "`"$proj`"", "-s", "res://tools/enemy_rewrite/mp_runner.gd")
$env:MP_ROLE = "host"
$h = Start-Process -FilePath $godot -ArgumentList $common -NoNewWindow -PassThru -RedirectStandardOutput "$dir\host_out.txt" -RedirectStandardError "$dir\host_err.txt"
Start-Sleep -Milliseconds 1500
$env:MP_ROLE = "client"
$c = Start-Process -FilePath $godot -ArgumentList $common -NoNewWindow -PassThru -RedirectStandardOutput "$dir\client_out.txt" -RedirectStandardError "$dir\client_err.txt"
foreach ($p in @($h, $c)) { if (-not $p.WaitForExit($TimeoutSec * 1000)) { $p.Kill(); Write-Output "RUN_MP: zaman aşımı" } }
foreach ($r in "host", "client") {
	Get-Content "$dir\$($r)_out.txt", "$dir\$($r)_err.txt" -Encoding UTF8 -ErrorAction SilentlyContinue |
		Select-String -Pattern "^MP|SCRIPT ERROR|ERROR:|Invalid|Nonexistent" | Where-Object { $_.Line -notmatch "invalid UID|resources still in use|ObjectDB" } |
		ForEach-Object { "[$r] $($_.Line)" }
}
