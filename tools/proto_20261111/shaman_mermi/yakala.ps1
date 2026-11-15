# Shaman Q/E mermi prototipleri (madde 562): gercek cizicide sahne yakalama, GIZLI masaustunde (pencere cikmaz).
# Kullanim: powershell -ExecutionPolicy Bypass -File tools/proto_20261111/shaman_mermi/yakala.ps1 -Mode bos|suan
param([string]$Mode = "bos")
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
. "$proj\tools\fps_micro\hidden_launch.ps1"
$out = Join-Path $PSScriptRoot "out\yakala_$Mode"
New-Item -ItemType Directory -Force $out | Out-Null
Get-ChildItem $out -Filter *.png -ErrorAction SilentlyContinue | Remove-Item -Force
$env:SM_DIR = $out
$env:SM_MODE = $Mode
$godot = "C:\Users\perva\Desktop\Arşiv\Godot_v4.7.2-stable_win64.exe"
$log = Join-Path $out "yakala.log"
$code = Invoke-GodotHidden -Exe $godot -ArgLine ('--path "' + $proj + '" --log-file "' + $log + '" -s res://tools/proto_20261111/shaman_mermi/sahne_yakala.gd') -WorkDir $proj -TimeoutSec 180
Write-Host "kod $code"
