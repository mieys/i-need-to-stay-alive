# YÜKLEME EKRANI prototipleri (madde 366) - A/B harita çekimleri GİZLİ masaüstünde (pencere görünmez, tools/fps_micro/hidden_launch.ps1).
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/proto_20261023/yukleme/yukleme_run.ps1 ; sonra python tools/proto_20261023/yukleme/yukleme_proto.py
$ErrorActionPreference = 'Stop'
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
. "$proj\tools\fps_micro\hidden_launch.ps1"
New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot 'out') | Out-Null
$gdi = Join-Path $PSScriptRoot 'out\.gdignore'
if (-not (Test-Path $gdi)) { New-Item -ItemType File $gdi | Out-Null }
$log = Join-Path $PSScriptRoot 'out\capture_log.txt'
$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --log-file `"$log`" -s tools/proto_20261023/yukleme/yukleme_capture.gd" -WorkDir $proj -TimeoutSec 400
Write-Output "cikis $code"
Select-String -Path $log -Pattern 'VIS|SHOT|SCRIPT ERROR' | ForEach-Object { Write-Output "  $($_.Line)" }
