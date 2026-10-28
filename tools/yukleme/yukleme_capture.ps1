# YÜKLEME EKRANI "Mühürlü Kapı" (madde 370) - Kemik Mahzeni arka plan çekimi GİZLİ masaüstünde (pencere görünmez,
# tools/fps_micro/hidden_launch.ps1). Harita değişince yeniden çek, sonra: python tools/gen_yukleme_bg.py ; Godot --headless --import
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/yukleme/yukleme_capture.ps1 [-Onizle]
#   -Onizle: çekim yerine gerçek yükleme ekranını kurup cekim/onizle_*.png yazar (yukleme_onizle.gd)
param([switch]$Onizle)
$ErrorActionPreference = 'Stop'
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
. "$proj\tools\fps_micro\hidden_launch.ps1"
$cekim = Join-Path $PSScriptRoot 'cekim'
New-Item -ItemType Directory -Force $cekim | Out-Null
$gdi = Join-Path $cekim '.gdignore'
if (-not (Test-Path $gdi)) { New-Item -ItemType File $gdi | Out-Null }
$log = Join-Path $cekim 'log.txt'
$script = if ($Onizle) { 'tools/yukleme/yukleme_onizle.gd' } else { 'tools/yukleme/yukleme_capture.gd' }
$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --log-file `"$log`" -s $script" -WorkDir $proj -TimeoutSec 300
Write-Output "cikis $code"
Select-String -Path $log -Pattern 'CEKIM|ONIZLE|SCRIPT ERROR|ERROR' | ForEach-Object { Write-Output "  $($_.Line)" }
Remove-Item $log -ErrorAction SilentlyContinue
