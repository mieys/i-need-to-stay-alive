# Harita anahtari gorsel kontrolu (anahtar_capture.gd, madde 605) - GIZLI masaustunde (hidden_launch.ps1), APPDATA yalitilir (ruh_komple_run.ps1 ile ayni).
#   powershell -ExecutionPolicy Bypass -File tools/anahtar_gorsel/anahtar_run.ps1 [-Out <klasor>]   (varsayilan cikti: %TEMP%\anahtar_gorsel)
param([string]$Out = "", [int]$TimeoutSec = 240)
. "$PSScriptRoot\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
if ($Out -eq "") { $Out = Join-Path $env:TEMP "anahtar_gorsel" }
New-Item -ItemType Directory -Force $Out | Out-Null
$tmp = Join-Path $env:TEMP "anahtar_cap"
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
$env:ANAHTAR_DIR = $Out
$log = Join-Path $tmp "log.txt"
if (Test-Path $log) { Remove-Item $log -Force }
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$log`" -s res://tools/anahtar_gorsel/anahtar_capture.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Host "kod=$code"
} finally {
	$env:APPDATA = $savedAppData
}
Get-Content $log | Select-String "SHOT|!!|ERROR|SCRIPT|Parse" | Select-Object -First 40
Write-Host "Cikti: $Out"
