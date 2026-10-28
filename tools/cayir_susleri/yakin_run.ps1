# BAŞLANGIÇ ÇAYIRI SÜSLERİ (madde 383) gerçek çizici yakalaması - GİZLİ masaüstünde (pencere görünmez, tools/fps_micro/hidden_launch.ps1).
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/cayir_susleri/yakin_run.ps1   -> tools/cayir_susleri/out/gercek/*.png
$ErrorActionPreference = 'Stop'
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
. "$proj\tools\fps_micro\hidden_launch.ps1"
New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot 'out') | Out-Null
$log = Join-Path $PSScriptRoot 'out\yakin_log.txt'
$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --resolution 1920x1080 --log-file `"$log`" -s tools/cayir_susleri/yakin_capture.gd" -WorkDir $proj -TimeoutSec 400
Write-Output "cikis $code"
Select-String -Path $log -Pattern 'SHOT|SCRIPT ERROR' | ForEach-Object { Write-Output "  $($_.Line)" }
