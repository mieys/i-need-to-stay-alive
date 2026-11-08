# Yukleme ekrani v3 prototipleri (yukleme_v3_proto.gd, 2026-11-06, madde 408) - GIZLI masaustunde (hidden_launch.ps1), APPDATA yalitilir (fps_micro/run.ps1 ile ayni).
#   powershell -ExecutionPolicy Bypass -File tools/proto_20261106/yukleme_v3/yukleme_v3_run.ps1 [-Only "A,B"] ; sonra python tools/proto_20261106/yukleme_v3/yukleme_v3_ozet.py
#   -Script yukleme_v3_oyun.gd : OYUNDAKİ yükleme ekranının gerçek akışı (madde 411) -> out/oyun/
param([string]$Only = "", [int]$TimeoutSec = 240, [string]$Script = "yukleme_v3_proto.gd")
. "$PSScriptRoot\..\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$tmp = Join-Path $env:TEMP "yukleme_v3_cap"
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
$env:YUKLEME_ONLY = $Only
$log = Join-Path $tmp "log.txt"
if (Test-Path $log) { Remove-Item $log -Force }
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$log`" -s res://tools/proto_20261106/yukleme_v3/$Script"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Host "kod=$code"
} finally {
	$env:APPDATA = $savedAppData
}
Get-Content $log | Select-String "SHOT|DATA|HIDE|KEEP|!!|ERROR|SCRIPT" | Select-Object -First 60
