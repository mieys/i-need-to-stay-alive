# PANEL DOKUSU 3. set + menü bulanıklığı yakalaması - GİZLİ masaüstünde (pencere görünmez). Önce: python gen_panel_doku3.py
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/proto_20261116/panel_doku3/run.ps1 [-Set "simdi,r1,r2,r3,r4"] [-Scenes "room_browser"] [-Extra]
# Diğer menüler: run.ps1 -Script doku3_diger_capture.gd [-Part "dis,ic"]  -> out/diger/, sonra python ozet_diger.py
param([string]$Set = "simdi,r1,r2,r3,r4", [string]$Scenes = "room_browser,character_select", [switch]$Extra, [string]$Script = "doku3_capture.gd", [string]$Part = "dis,ic")
$ErrorActionPreference = 'Stop'
$env:CAP_SET = $Set
$env:CAP_SCENES = $Scenes
$env:CAP_EXTRA = $(if ($Extra) { "1" } else { "0" })
$env:CAP_PART = $Part
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
$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --resolution 1920x1080 --log-file `"$log`" -s tools/proto_20261116/panel_doku3/$Script" -WorkDir $proj -TimeoutSec 600
Write-Output "cikis $code"
Select-String -Path $log -Pattern 'SHOT|GRAIN|SCRIPT ERROR|Parse Error|ERROR' | ForEach-Object { Write-Output "  $($_.Line)" }
