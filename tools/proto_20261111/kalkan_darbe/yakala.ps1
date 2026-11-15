# Kalkan darbe (hasar alma) efekti prototipi (oyuna bagli DEGIL): gercek cizicide yakalama, GIZLI masaustunde (pencere cikmaz).
# Kullanim: powershell -ExecutionPolicy Bypass -File tools/proto_20261111/kalkan_darbe/yakala.ps1 [-Shield shield_standart|shield_enerji|shield_kale|shield_savas] [-Variants "suan,a,b,c,d" -Tag ""]
# Sonra: python -I tools/proto_20261111/kalkan_darbe/gif.py [shield_standart] -> out/<kalkan>/karsilastirma.gif + ozet.png
param([string]$Shield = "shield_standart", [string]$Variants = "suan,a,b,c,d", [string]$Tag = "")
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
. "$proj\tools\fps_micro\hidden_launch.ps1"
$out = Join-Path $PSScriptRoot ("out\" + $Shield + $Tag)
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out | Out-Null
$env:KD_DIR = $out
$env:KD_SHIELD = $Shield
$env:KD_VARIANTS = $Variants
$godot = "C:\Users\perva\Desktop\Arşiv\Godot_v4.7.2-stable_win64.exe"
$log = Join-Path $out "yakala.log"
$code = Invoke-GodotHidden -Exe $godot -ArgLine ('--path "' + $proj + '" --resolution 1920x1080 --fixed-fps 30 --log-file "' + $log + '" -s res://tools/proto_20261111/kalkan_darbe/yakala.gd') -WorkDir $proj -TimeoutSec 240
Write-Host "kod $code"
