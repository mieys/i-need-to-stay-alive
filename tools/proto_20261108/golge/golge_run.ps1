# GOLGE acik/kapali ornekleri (golge_capture.gd, 2026-11-08) - GIZLI masaustunde, APPDATA yalitilir (gercek ayar/kayit bozulmaz).
# Sonra: python -I tools/proto_20261108/golge/golge_sayfa.py
. "$PSScriptRoot\..\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$tmp = Join-Path $env:TEMP "golge_capture"
$out = Join-Path $PSScriptRoot "out"
New-Item -ItemType Directory -Force $out | Out-Null
$log = Join-Path $out "golge_log.txt"
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
if (Test-Path $log) { Remove-Item $log -Force }
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$log`" -s res://tools/proto_20261108/golge/golge_capture.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec 600
} finally {
	$env:APPDATA = $savedAppData
}
"exit=$code"
Get-Content $log | Select-String "GOLGE|SCRIPT ERROR|Parse Error"
