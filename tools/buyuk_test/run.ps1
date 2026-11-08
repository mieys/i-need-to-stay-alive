# BUYUK TEST kosturucu (buyuk_test.gd) - GIZLI masaustunde (hidden_launch.ps1), APPDATA yalitilir (gercek meta.cfg / kayitlar bozulmaz).
#   powershell -ExecutionPolicy Bypass -File tools/buyuk_test/run.ps1 -Mode wt -Label deneme [-Env "BT_WEAPONS=dagger;BT_TIERS=1,5"] [-TimeoutSec 1800]
# Cikti: tools/buyuk_test/out/<Label>/<Mode>/*.jpg + tools/buyuk_test/out/<Label>/<Mode>.log (print + motor hatalari).
param(
	[Parameter(Mandatory = $true)][string]$Mode,
	[string]$Label = "son",
	[string]$Env = "",
	[int]$TimeoutSec = 1800
)
. "$PSScriptRoot\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$tmp = Join-Path $env:TEMP "buyuk_test"
New-Item -ItemType Directory -Force $tmp | Out-Null
$outRoot = Join-Path $PSScriptRoot "out\$Label"
$outDir = Join-Path $outRoot $Mode
New-Item -ItemType Directory -Force $outDir | Out-Null
$log = Join-Path $outRoot "$Mode.log"
$appName = "Temiz S$([char]0x00FC)r$([char]0x00FC)m"
$realUser = Join-Path $env:APPDATA "Godot\app_userdata\$appName"
$fakeRoot = Join-Path $tmp "appdata_$Mode"
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
$env:BT_MODE = $Mode
$env:BT_OUT = $outDir
foreach ($kv in ($Env -split ';')) { if ($kv -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] } }
if (Test-Path $log) { Remove-Item $log -Force }
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$log`" -s res://tools/buyuk_test/buyuk_test.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Host "kod=$code mod=$Mode"
	if ($code -eq -2) { Add-Content $log "BT TIMEOUT" }
} finally {
	$env:APPDATA = $savedAppData
}
