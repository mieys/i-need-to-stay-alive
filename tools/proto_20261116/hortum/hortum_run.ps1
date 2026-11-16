# Madde 728: Büyücü hortumu (C Toz Şeytanı) gerçek çizici yakalaması, GİZLİ masaüstünde (pencere görünmez).
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/proto_20261116/hortum/hortum_run.ps1   -> tools/proto_20261116/hortum/out/oyun_*.png
$ErrorActionPreference = 'Stop'
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
. "$proj\tools\fps_micro\hidden_launch.ps1"
$out = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Force $out | Out-Null
$env:HR_CAP_DIR = $out
$log = Join-Path $out 'oyun_log.txt'
$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --resolution 1920x1080 --log-file `"$log`" -s tools/proto_20261116/hortum/hortum_capture.gd" -WorkDir $proj -TimeoutSec 180
Write-Output "cikis $code"
Select-String -Path $log -Pattern 'SHOT|SCRIPT ERROR|BITTI' | ForEach-Object { Write-Output "  $($_.Line)" }
