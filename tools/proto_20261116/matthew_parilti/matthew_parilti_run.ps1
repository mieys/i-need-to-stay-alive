# Matthew simsek efektleri hafif parilti A/B yakalamasi (matthew_parilti_capture.gd) - GIZLI masaustunde (hidden_launch.ps1), APPDATA yalitilir.
#   powershell -ExecutionPolicy Bypass -File tools/proto_20261116/matthew_parilti/matthew_parilti_run.ps1
#   -Mode arcane: Buyucu Arcane Patlama A/B (madde 739) -> out/arcane.png
param([int]$TimeoutSec = 120, [string]$Mode = "")
. "$PSScriptRoot\..\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$tmp = Join-Path $env:TEMP "matthew_parilti_cap"
New-Item -ItemType Directory -Force $tmp | Out-Null
$out = Join-Path $PSScriptRoot "out"
New-Item -ItemType Directory -Force $out | Out-Null
$env:MP_DIR = $out
$env:MP_MODE = $Mode
$log = Join-Path $tmp "log.txt"
if (Test-Path $log) { Remove-Item $log -Force }
$savedAppData = $env:APPDATA
$env:APPDATA = Join-Path $tmp "appdata"
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$log`" -s res://tools/proto_20261116/matthew_parilti/matthew_parilti_capture.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Host "kod=$code"
} finally {
	$env:APPDATA = $savedAppData
}
Get-Content $log | Select-String "SHOT|BITTI|ERROR|SHADER" | Select-Object -First 40
