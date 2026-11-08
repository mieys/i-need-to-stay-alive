# OYUN ICI ARAYUZ prototipleri (hud_capture.gd, 2026-11-08) - GIZLI masaustunde (hidden_launch.ps1), APPDATA yalitilir.
#   powershell -ExecutionPolicy Bypass -File tools/proto_20261108/hud_yeni/run.ps1 [-Only "simdi,A,B,C,D"]
param([string]$Only = "simdi,A,B,C,D", [int]$TimeoutSec = 180)
. "$PSScriptRoot\..\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$out = Join-Path $PSScriptRoot "out"
New-Item -ItemType Directory -Force $out | Out-Null
$tmp = Join-Path $env:TEMP "hud_yeni_cap"
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
$env:HUDY_DIR = $out
$log = Join-Path $tmp "log.txt"
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	foreach ($p in $Only.Split(",")) {
		$env:HUD_PROTO = if ($p -eq "simdi") { "" } else { $p }
		if (Test-Path $log) { Remove-Item $log -Force }
		$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$log`" -s res://tools/proto_20261108/hud_yeni/hud_capture.gd"
		$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
		Write-Host "$p kod=$code"
		Get-Content $log | Select-String "SHOT|SCRIPT ERROR|Parse Error|hud_proto|hud_capture" | Select-Object -First 25
	}
} finally {
	$env:APPDATA = $savedAppData
	$env:HUD_PROTO = ""
}
