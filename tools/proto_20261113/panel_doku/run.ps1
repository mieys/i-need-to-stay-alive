# PANEL DOKUSU prototip yakalaması - GİZLİ masaüstünde (pencere görünmez). Önce: python gen_panel_doku.py
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/proto_20261113/panel_doku/run.ps1 [-Set "e,f,g,h"]   -> out/*.png
# 2. set için önce: python gen_panel_doku2.py
# -Opak: hepsi opak pencere zeminiyle (çıktı doku_<x>_opak.png)
# -Script oyunda_capture.gd: oyuna alınmış dokuyu (pixel_box.gd) oda/karakter/lobi ekranında yakalar
param([string]$Set = "a,b,c,d", [switch]$Opak, [string]$Script = "panel_doku_capture.gd")
$ErrorActionPreference = 'Stop'
$env:CAP_SET = $Set
$env:CAP_OPAK = $(if ($Opak) { "1" } else { "0" })
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
. "$proj\tools\fps_micro\hidden_launch.ps1"
$out = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Force $out | Out-Null
$env:CAP_OUT = $out
$env:CAP_TILES = Join-Path $out 'tiles'
## Kullanıcının kayıtları/ayarları etkilenmesin
$env:APPDATA = Join-Path $out 'appdata'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$log = Join-Path $out "log.txt"
$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --resolution 1920x1080 --log-file `"$log`" -s tools/proto_20261113/panel_doku/$Script" -WorkDir $proj -TimeoutSec 240
Write-Output "cikis $code"
Select-String -Path $log -Pattern 'SHOT|KUTU|SCRIPT ERROR|Parse Error|ERROR' | ForEach-Object { Write-Output "  $($_.Line)" }
