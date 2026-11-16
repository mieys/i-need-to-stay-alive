# KUM FIRTINASI gorunum prototipi (firtina_capture.gd, 2026-11-15) - GIZLI masaustunde (hidden_launch.ps1), APPDATA yalitilir.
#   powershell -ExecutionPolicy Bypass -File tools/proto_20261115/kum_firtinasi/run.ps1 [-Only "simdi,A,B,C"] [-Offset "0,0"] [-Script gercek_capture.gd]
param([string]$Only = "", [string]$Offset = "", [string]$Script = "firtina_capture.gd", [int]$TimeoutSec = 240)
. "$PSScriptRoot\..\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$out = Join-Path $PSScriptRoot "out"
New-Item -ItemType Directory -Force $out | Out-Null
$tmp = Join-Path $env:TEMP "kum_firtina_cap"
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
$env:KUM_DIR = $out
$env:KUM_ONLY = $Only
$env:KUM_OFFSET = $Offset
$env:HARITA = "col"
$log = Join-Path $tmp "log.txt"
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	if (Test-Path $log) { Remove-Item $log -Force }
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$log`" -s res://tools/proto_20261115/kum_firtinasi/$Script"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Host "kod=$code"
	Get-Content $log | Select-String "SHOT|SCRIPT ERROR|Parse Error|SHADER ERROR|kum_proto|firtina_capture|gercek_capture|HUD layer|SONUC|KATMAN|kum_firtinasi|weather_sandstorm" | Select-Object -First 30
} finally {
	$env:APPDATA = $savedAppData
	$env:HARITA = ""
	$env:KUM_ONLY = ""
	$env:KUM_OFFSET = ""
}
