# Karakter tanitim klipleri (karakter_klip_capture.gd) - GIZLI masaustunde (hidden_launch.ps1), APPDATA yalitilir (fps_micro/run.ps1 ile ayni).
#   powershell -ExecutionPolicy Bypass -File tools/proto_20261114/karakter_klip/karakter_klip_run.ps1 -Out <klasor> [-Env "KK_MODE=survey;KK_MAPS=ana,kis"]
param([string]$Out, [string]$Env = "", [int]$TimeoutSec = 1800)
. "$PSScriptRoot\..\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$tmp = Join-Path $env:TEMP "karakter_klip_cap"
New-Item -ItemType Directory -Force $tmp | Out-Null
New-Item -ItemType Directory -Force $Out | Out-Null
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
$env:KK_DIR = $Out
foreach ($kv in ($Env -split ';')) { if ($kv -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] } }
$log = Join-Path $tmp "log.txt"
if (Test-Path $log) { Remove-Item $log -Force }
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --fixed-fps 30 --audio-driver Dummy --log-file `"$log`" -s res://tools/proto_20261114/karakter_klip/karakter_klip_capture.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Host "kod=$code"
} finally {
	$env:APPDATA = $savedAppData
}
Get-Content $log | Select-String "SHOT|RECT|CL |PC |MC |POSE|NAMES|CLIP|BOOT|BITTI|SCRIPT ERROR|Parse Error" | Select-Object -First 120
