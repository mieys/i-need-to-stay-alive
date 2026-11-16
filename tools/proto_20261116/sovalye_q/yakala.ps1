# Sovalye Q efekti (madde 740) gercek cizicide yakalama, GIZLI masaustunde (pencere cikmaz).
# Kullanim: powershell -ExecutionPolicy Bypass -File tools/proto_20261116/sovalye_q/yakala.ps1
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
. "$proj\tools\fps_micro\hidden_launch.ps1"
$out = Join-Path $PSScriptRoot "out\kareler"
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out | Out-Null
$env:SQ_DIR = $out
$godot = "C:\Users\perva\Desktop\Arşiv\Godot_v4.7.2-stable_win64.exe"
$log = Join-Path $out "yakala.log"
$code = Invoke-GodotHidden -Exe $godot -ArgLine ('--path "' + $proj + '" --resolution 1920x1080 --fixed-fps 30 --log-file "' + $log + '" -s res://tools/proto_20261116/sovalye_q/yakala.gd') -WorkDir $proj -TimeoutSec 180
Write-Host "kod $code"
