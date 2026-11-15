# Melek E + dostun kalkan baloncugu prototipi (oyuna bagli DEGIL): gercek cizicide yakalama, GIZLI masaustunde (pencere cikmaz).
# Kullanim: powershell -ExecutionPolicy Bypass -File tools/proto_20261111/melek_e_kalkan/yakala.ps1 [-Shield shield_standart|shield_enerji|shield_kale|shield_savas] [-Variants "c,c1,c2,c3,c4" -Tag "_c"]
# Sonra: python -I tools/proto_20261111/melek_e_kalkan/gif.py  -> out/karsilastirma.gif + out/ozet.png
param([string]$Shield = "shield_standart", [string]$Variants = "suan,a,b,c", [string]$Tag = "")
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
. "$proj\tools\fps_micro\hidden_launch.ps1"
$out = Join-Path $PSScriptRoot ("out\" + $Shield + $Tag)
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out | Out-Null
$env:ME_DIR = $out
$env:ME_SHIELD = $Shield
$env:ME_VARIANTS = $Variants
$godot = "C:\Users\perva\Desktop\Arşiv\Godot_v4.7.2-stable_win64.exe"
$log = Join-Path $out "yakala.log"
$code = Invoke-GodotHidden -Exe $godot -ArgLine ('--path "' + $proj + '" --resolution 1920x1080 --fixed-fps 30 --log-file "' + $log + '" -s res://tools/proto_20261111/melek_e_kalkan/yakala.gd') -WorkDir $proj -TimeoutSec 240
Write-Host "kod $code"
