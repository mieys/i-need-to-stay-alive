# SADE SU prototipleri A-D (su_sade_capture.gd, 2026-11-06) - GIZLI masaustunde (hidden_launch.ps1). Sonra: python -I su_sade_sayfa.py
# Ortam degiskenleri (SU_ONLY / SU_SPOT / SU_FRAMES) bu betigi cagirmadan once ayarlanir; Godot surecine gecer.
$proj = Resolve-Path "$PSScriptRoot\..\..\.."
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
. "$proj\tools\fps_micro\hidden_launch.ps1"
$log = "$PSScriptRoot\out\su_sade_log.txt"
New-Item -ItemType Directory -Force "$PSScriptRoot\out" | Out-Null
$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --log-file `"$log`" --windowed --resolution 480x270 -s res://tools/proto_20261106/su_sade/su_sade_capture.gd" -WorkDir $proj -TimeoutSec 600
"exit=$code"
Get-Content $log | Select-String "SU_SADE|ERROR|SHADER"
