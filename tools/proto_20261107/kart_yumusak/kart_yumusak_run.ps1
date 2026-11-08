# YUMUSAK KART prototipleri A-D (kart_yumusak_proto.gd, 2026-11-07) - GIZLI masaustunde (hidden_launch.ps1), APPDATA yalitilir.
#   powershell -ExecutionPolicy Bypass -File tools/proto_20261107/kart_yumusak/kart_yumusak_run.ps1 [-Only "A,B"]
# Sonunda ozet.py out/ozet.png'yi kurar.
param([string]$Only = "", [int]$TimeoutSec = 300)
. "$PSScriptRoot\..\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$out = Join-Path $PSScriptRoot "out"
New-Item -ItemType Directory -Force $out | Out-Null
$gdignore = Join-Path $out ".gdignore"
if (-not (Test-Path $gdignore)) { New-Item -ItemType File $gdignore | Out-Null }
$tmp = Join-Path $env:TEMP "kart_yumusak_cap"
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
$env:KART_YUMUSAK_ONLY = $Only
$env:KART_YUMUSAK_DIR = $out
$log = Join-Path $tmp "log.txt"
if (Test-Path $log) { Remove-Item $log -Force }
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$log`" -s res://tools/proto_20261107/kart_yumusak/kart_yumusak_proto.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Host "kod=$code"
} finally {
	$env:APPDATA = $savedAppData
}
Get-Content $log -Encoding UTF8 | Select-String "SHOT|VERI|!!|ERROR|SCRIPT|Parse" | Select-Object -First 60
python -I (Join-Path $PSScriptRoot "ozet.py") $out
