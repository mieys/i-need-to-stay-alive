# ANA MENÜ "Nehir Kenarı Kampı" - ana haritadan dünya pikselinde kadraj yakalaması, GİZLİ masaüstünde (pencere görünmez).
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/proto_20261115/kamp_menu/kamp_run.ps1 [-Shots "ad:x,y:w,h|..."] [-Script menu_capture.gd]
#   -> tools/proto_20261115/kamp_menu/out/<ad>.png
param([string]$Shots = "", [string]$Script = "kamp_capture.gd")
$ErrorActionPreference = 'Stop'
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
. "$proj\tools\fps_micro\hidden_launch.ps1"
New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot 'out') | Out-Null
if ($Shots -ne "") { $env:KAMP_SHOTS = $Shots }
$log = Join-Path $PSScriptRoot 'out\kamp_log.txt'
$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --resolution 1920x1080 --log-file `"$log`" -s tools/proto_20261115/kamp_menu/$Script" -WorkDir $proj -TimeoutSec 400
Write-Output "cikis $code"
Select-String -Path $log -Pattern 'SHOT|SCRIPT ERROR' | ForEach-Object { Write-Output "  $($_.Line)" }
