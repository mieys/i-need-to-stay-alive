# Sovalye E "Koruma Bariyeri" prototipi (oyuna bagli DEGIL): gercek cizicide yakalama, GIZLI masaustunde (pencere cikmaz).
# Kullanim: powershell -ExecutionPolicy Bypass -File tools/proto_20261111/sovalye_bariyer/yakala.ps1 [-Variants "suan,a,b,c,d"]
# Once: python -I tools/proto_20261111/sovalye_bariyer/bariyer_proto.py ; sonra: python -I tools/proto_20261111/sovalye_bariyer/gif.py
param([string]$Variants = "suan,a,b,c,d")
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
. "$proj\tools\fps_micro\hidden_launch.ps1"
$out = Join-Path $PSScriptRoot "out\kareler"
New-Item -ItemType Directory -Force $out | Out-Null
foreach ($v in $Variants.Split(",")) { $d = Join-Path $out $v; if (Test-Path $d) { Remove-Item -Recurse -Force $d } }
$env:SB_DIR = $out
$env:SB_VARIANTS = $Variants
$godot = "C:\Users\perva\Desktop\Arşiv\Godot_v4.7.2-stable_win64.exe"
$log = Join-Path $out "yakala.log"
$code = Invoke-GodotHidden -Exe $godot -ArgLine ('--path "' + $proj + '" --resolution 1920x1080 --fixed-fps 30 --log-file "' + $log + '" -s res://tools/proto_20261111/sovalye_bariyer/yakala.gd') -WorkDir $proj -TimeoutSec 240
Write-Host "kod $code"
