# Gök ışığı + yansıma prototiplerini (2026-11-16) gerçek çizicide yakalar - GİZLİ masaüstünde (pencere görünmez, tools/fps_micro/hidden_launch.ps1).
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/proto_20261116/gok_isik/gok_isik_run.ps1 [-Tags "simdi@150,A@150,B@150,C@150"] [-Frames 48] [-Spot "358,2421"] [-Kesif "x,y;x,y"] [-IsikX 150] [-DikDebug]
# Çıktı: tools/proto_20261116/gok_isik/out/kare/<etiket>_t<saat>/f_###.png (GIF: gok_isik_sayfa.py), -Kesif: out/kesif/kesif_<i>.png
param([string]$Tags = 'simdi@150,A@150,B@150,C@150', [int]$Frames = 48, [string]$Spot = '', [string]$Kesif = '', [string]$IsikX = '', [switch]$DikDebug, [int]$TimeoutSec = 900)
$ErrorActionPreference = 'Stop'
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$out = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Force $out | Out-Null
. "$proj\tools\fps_micro\hidden_launch.ps1"
$env:GI_TAGS = $Tags
$env:GI_FRAMES = "$Frames"
$env:GI_SPOT = $Spot
$env:GI_KESIF = $Kesif
$env:GI_ISIK_X = $IsikX
$env:GI_DIK_DEBUG = ''
if ($DikDebug) { $env:GI_DIK_DEBUG = '1' }
$env:GI_OUT = (Join-Path $out 'kare')
if ($Kesif -ne '') { $env:GI_OUT = (Join-Path $out 'kesif') }
$log = Join-Path $out 'log.txt'
$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --resolution 1920x1080 --log-file `"$log`" -s tools/proto_20261116/gok_isik/gok_isik_capture.gd" -WorkDir $proj -TimeoutSec $TimeoutSec
Select-String -Path $log -Pattern 'SHOT|pencere|isik_ekran|dik gruplar|SCRIPT ERROR|SHADER ERROR|ERROR: |Parse Error' | Select-Object -First 50 | ForEach-Object { $_.Line }
Write-Output "cikis $code"
