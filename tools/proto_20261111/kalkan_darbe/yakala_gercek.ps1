# Kalkan darbe prototipi - GERCEK HEDEFTEN hasar (oyuna bagli DEGIL): gercek Main + gercek yaratiklar, GIZLI masaustunde,
# APPDATA yalitilir (gercek kayitlar bozulmaz).
# Kullanim: powershell -ExecutionPolicy Bypass -File tools/proto_20261111/kalkan_darbe/yakala_gercek.ps1 [-Shield shield_standart] [-Variants "suan,a,b,c,d"] [-Tag "_gercek"] [-Roster "zombie1,ork1,iskelet2,lich1"]
# Sonra: python -I tools/proto_20261111/kalkan_darbe/gif.py shield_standart_gercek
param([string]$Shield = "shield_standart", [string]$Variants = "suan,a,b,c,d", [string]$Tag = "_gercek", [string]$Roster = "", [int]$Rec = 180)
. "$PSScriptRoot\..\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$out = Join-Path $PSScriptRoot ("out\" + $Shield + $Tag)
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out | Out-Null
$tmp = Join-Path $env:TEMP "kalkan_darbe"
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
$env:KD_DIR = $out
$env:KD_SHIELD = $Shield
$env:KD_VARIANTS = $Variants
$env:KD_ROSTER = $Roster
$env:KD_REC = "$Rec"
$log = Join-Path $out "yakala.log"
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --fixed-fps 30 --log-file `"$log`" -s res://tools/proto_20261111/kalkan_darbe/yakala_gercek.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec 600
	Write-Host "kod $code"
} finally {
	$env:APPDATA = $savedAppData
}
