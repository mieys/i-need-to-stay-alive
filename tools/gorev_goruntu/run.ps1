# YENİ GÖREVLER gerçek çizici yakalaması (madde 496) - GİZLİ masaüstünde (pencere görünmez, tools/fps_micro/hidden_launch.ps1).
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/gorev_goruntu/run.ps1 [-Harita batik_nekropol]   -> tools/gorev_goruntu/out/*.png
param([string]$Harita = "", [string]$Script = "gorev_capture.gd")
$ErrorActionPreference = 'Stop'
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
. "$proj\tools\fps_micro\hidden_launch.ps1"
$out = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Force $out | Out-Null
$env:CAP_OUT = $out
if ($Harita -ne "") { $env:HARITA = $Harita } else { Remove-Item env:HARITA -ErrorAction SilentlyContinue }
## Kullanıcının kayıtları/ayarları etkilenmesin (buyuk_test ile aynı yalıtım)
$env:APPDATA = Join-Path $out 'appdata'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$tag = $(if ($Harita -ne "") { $Harita } else { "ana" })
$log = Join-Path $out "log_$tag.txt"
$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --resolution 1920x1080 --log-file `"$log`" -s tools/gorev_goruntu/$Script" -WorkDir $proj -TimeoutSec 300
Write-Output "cikis $code"
Select-String -Path $log -Pattern 'SHOT|SCRIPT ERROR' | ForEach-Object { Write-Output "  $($_.Line)" }
