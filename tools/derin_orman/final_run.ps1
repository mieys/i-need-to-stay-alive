# DERİN ORMAN son görünüm yakalaması (madde 360) - GİZLİ masaüstünde (pencere görünmez, tools/fps_micro/hidden_launch.ps1).
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/derin_orman/final_run.ps1 ; sonra python tools/derin_orman/final_sheet.py
$ErrorActionPreference = 'Stop'
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
. "$proj\tools\fps_micro\hidden_launch.ps1"
$log = Join-Path $PSScriptRoot 'out\final_log.txt'
$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --log-file `"$log`" -s tools/derin_orman/final_capture.gd" -WorkDir $proj -TimeoutSec 400
Write-Output "cikis $code"
Select-String -Path $log -Pattern 'SHOT|SCRIPT ERROR' | ForEach-Object { Write-Output "  $($_.Line)" }
