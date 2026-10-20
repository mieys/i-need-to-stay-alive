# Gün ışığı + sisli hava prototiplerini (madde 282) gerçek çizicide yakalar - GİZLİ masaüstünde (pencere görünmez, tools/fps_micro/hidden_launch.ps1).
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/proto_20261019/gunes_sis/gunes_sis_run.ps1 [-Tags simdi,A,B,C,D] [-Frames 36] [-Spot "2912,1390"] [-Explore]
# Çıktı: tools/proto_20261019/gunes_sis/out/kare/<etiket>/f_###.png (GIF: gunes_sis_sayfa.py), -Explore: out/kesif/nokta_<i>.png
param([string]$Tags = 'simdi,A,B,C,D', [int]$Frames = 36, [string]$Spot = '', [switch]$Explore, [int]$TimeoutSec = 600)
$ErrorActionPreference = 'Stop'
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$out = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Force $out | Out-Null
. "$proj\tools\fps_micro\hidden_launch.ps1"
$env:GS_TAGS = $Tags
$env:GS_FRAMES = "$Frames"
$env:GS_SPOT = $Spot
$env:GS_EXPLORE = ''
$env:GS_OUT = (Join-Path $out 'kare')
if ($Explore) { $env:GS_EXPLORE = '1'; $env:GS_OUT = (Join-Path $out 'kesif') }
$log = Join-Path $out 'log.txt'
$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --resolution 1280x720 --log-file `"$log`" -s tools/proto_20261019/gunes_sis/gunes_sis_capture.gd" -WorkDir $proj -TimeoutSec $TimeoutSec
Select-String -Path $log -Pattern 'SHOT|NOKTA|maske|SCRIPT ERROR|SHADER ERROR|ERROR: ' | Select-Object -First 40 | ForEach-Object { $_.Line }
Write-Output "cikis $code"
