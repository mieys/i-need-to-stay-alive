# Tirpan "Kara Hasat" gercek cizici yakalamasi (madde 512): GIZLI masaustunde (pencere cikmaz), kareler -> GIF.
#   powershell -ExecutionPolicy Bypass -File tools/proto_20261109/tirpan_capture.ps1
. "$PSScriptRoot\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$cap = Join-Path $env:TEMP "tirpan_cap"
if (Test-Path $cap) { Remove-Item -Recurse -Force $cap }
New-Item -ItemType Directory -Force $cap | Out-Null
$env:BC_CAP_DIR = $cap
$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --resolution 1280x720 --audio-driver Dummy -s res://tools/proto_20261109/tirpan_capture.gd" -WorkDir $proj -TimeoutSec 120
Write-Host "kod=$code kare=$((Get-ChildItem $cap -Filter *.png).Count)"
python -I "$PSScriptRoot\tirpan_capture_gif.py" $cap (Join-Path $PSScriptRoot "out\tirpan\oyunda.gif")
