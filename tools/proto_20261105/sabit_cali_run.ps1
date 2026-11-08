# Sabit genis cali dogrulamasi (gizli masaustu). Cikti: tools/proto_20261105/out/ + log
$proj = Resolve-Path "$PSScriptRoot\..\.."
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
. "$proj\tools\fps_micro\hidden_launch.ps1"
$log = "$PSScriptRoot\out\sabit_cali_log.txt"
New-Item -ItemType Directory -Force "$PSScriptRoot\out" | Out-Null
$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --log-file `"$log`" -s res://tools/proto_20261105/sabit_cali_capture.gd" -WorkDir $proj -TimeoutSec 300
"exit=$code"
Get-Content $log | Select-String "SABIT_CALI|ERROR|SHADER"
