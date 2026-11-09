# Karakter ustu can/kalkan cubugu prototipleri (ust_bar_capture.gd, 2026-11-08, oyuna bagli DEGIL) - GIZLI masaustunde, APPDATA yalitilir.
#   powershell -ExecutionPolicy Bypass -File tools/proto_20261108/ust_bar/ust_bar_run.ps1 [-Only "simdi,A,B,C,D"]
# Sonra: python -I tools/proto_20261108/ust_bar/ust_bar_sayfa.py  -> out/ozet.png
param([string]$Only = "", [int]$TimeoutSec = 240)
. "$PSScriptRoot\..\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$out = Join-Path $PSScriptRoot "out"
New-Item -ItemType Directory -Force $out | Out-Null
$tmp = Join-Path $env:TEMP "ust_bar_cap"
New-Item -ItemType Directory -Force $tmp | Out-Null
$appName = "Temiz S$([char]0x00FC)r$([char]0x00FC)m"
$realUser = Join-Path $env:APPDATA "Godot\app_userdata\$appName"
$fakeRoot = Join-Path $tmp "appdata"
$fakeUser = Join-Path $fakeRoot "Godot\app_userdata\$appName"
New-Item -ItemType Directory -Force $fakeUser | Out-Null
if (Test-Path $realUser) {
	Get-ChildItem $realUser -Filter "*.cfg" -File | ForEach-Object { Copy-Item $_.FullName (Join-Path $fakeUser $_.Name) -Force }
	foreach ($d in "vulkan", "shader_cache") {
		if ((Test-Path (Join-Path $realUser $d)) -and -not (Test-Path (Join-Path $fakeUser $d))) {
			robocopy (Join-Path $realUser $d) (Join-Path $fakeUser $d) /E /NFL /NDL /NJH /NJS /NP | Out-Null
		}
	}
}
$log = Join-Path $tmp "log.txt"
if (Test-Path $log) { Remove-Item $log -Force }
$env:UB_OUT = $out
$env:UB_ONLY = $Only
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$log`" -s res://tools/proto_20261108/ust_bar/ust_bar_capture.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
} finally {
	$env:APPDATA = $savedAppData
	$env:UB_ONLY = ""
}
"exit=$code"
Get-Content $log | Select-String "UB |SCRIPT ERROR|Parse Error|ust_bar" | Select-Object -First 30
