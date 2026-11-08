# Ruh hali gorunus PROTOTIPLERI (oyuna bagli DEGIL) - GIZLI masaustunde, APPDATA yalitilir.
#   powershell -ExecutionPolicy Bypass -File tools/proto_20261107/ruh_hali/ruh_proto_run.ps1 [-Chars "2,6"]
# Cikti kareleri: tools/proto_20261107/ruh_hali/out/proto/*.png ; birlestirme: python -I tools/proto_20261107/ruh_hali/ruh_proto_gif.py
param([string]$Chars = "2,6", [int]$TimeoutSec = 400)
. "$PSScriptRoot\..\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$out = Join-Path $PSScriptRoot "out\proto"
New-Item -ItemType Directory -Force $out | Out-Null
Remove-Item (Join-Path $out "*.png") -ErrorAction SilentlyContinue
$appName = "Temiz S$([char]0x00FC)r$([char]0x00FC)m"
$realUser = Join-Path $env:APPDATA "Godot\app_userdata\$appName"
$fakeRoot = Join-Path $env:TEMP "ruh_hali_appdata"
$fakeUser = Join-Path $fakeRoot "Godot\app_userdata\$appName"
New-Item -ItemType Directory -Force $fakeUser | Out-Null
if (Test-Path $realUser) {
	Get-ChildItem $realUser -Filter "*.cfg" -File | ForEach-Object { Copy-Item $_.FullName (Join-Path $fakeUser $_.Name) -Force }
}
$log = Join-Path $out "run.log"
$env:RH_OUT = $out
$env:RH_CHARS = $Chars
$saved = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$log`" -s res://tools/proto_20261107/ruh_hali/ruh_proto_capture.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Host "kod=$code"
} finally {
	$env:APPDATA = $saved
}
