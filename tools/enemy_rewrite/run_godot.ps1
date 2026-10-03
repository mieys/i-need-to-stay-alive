# Yaratık yeniden yazımı - Godot'u headless çalıştırıp çıktıyı dosyaya ve ekrana yazar (PLAN §6).
#   powershell -File tools/enemy_rewrite/run_godot.ps1 -Script res://tools/enemy_rewrite/compile_check.gd
#   powershell -File tools/enemy_rewrite/run_godot.ps1 -Import
#   powershell -File tools/enemy_rewrite/run_godot.ps1 -Script res://tools/enemy_rewrite/bench_world.gd -Env "BENCH_N=1000;BENCH_MODE=check"
param(
	[string]$Script = "",
	[switch]$Import,
	[string]$Env = "",
	[string]$Extra = "",
	[int]$TimeoutSec = 600
)
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$out = Join-Path $env:TEMP "enemy_rewrite_godot_out.txt"
$err = Join-Path $env:TEMP "enemy_rewrite_godot_err.txt"
foreach ($kv in ($Env -split ';')) { if ($kv -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] } }
$gargs = @("--headless", "--path", "`"$proj`"")
if ($Import) { $gargs += "--import" }
if ($Script -ne "") { $gargs += @("-s", $Script) }
if ($Extra -ne "") { $gargs += $Extra }
$p = Start-Process -FilePath $godot -ArgumentList $gargs -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
if (-not $p.WaitForExit($TimeoutSec * 1000)) { $p.Kill(); Write-Output "RUN_GODOT: zaman aşımı ($TimeoutSec s)" }
Get-Content $out -Encoding UTF8
$e = Get-Content $err -Encoding UTF8
if ($e) { Write-Output "---- stderr ----"; $e }
