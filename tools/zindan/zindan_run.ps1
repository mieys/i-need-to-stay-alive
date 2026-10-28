# ZİNDAN yakalaması (madde 373) - GİZLİ masaüstünde (pencere görünmez, tools/fps_micro/hidden_launch.ps1), kullanıcı verisi yalıtılır (APPDATA geçici).
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/zindan/zindan_run.ps1 -Id kemik_mahzeni -Mode tur [-Env "ZC_TIER=6;ZC_HOUR=300"]
param(
	[string]$Id = "kemik_mahzeni",
	[string]$Mode = "tur",
	[string]$Env = "",
	[int]$TimeoutSec = 300
)
$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$tmp = Join-Path $env:TEMP "zindan_zc"
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
$env:ZC_ID = $Id
$env:ZC_MODE = $Mode
foreach ($kv in ($Env -split ';')) { if ($kv -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] } }
$log = Join-Path $PSScriptRoot "out\zc_$Id.txt"
New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot "out\oyun") | Out-Null
if (Test-Path $log) { Remove-Item $log -Force }
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$log`" -s res://tools/zindan/zindan_capture.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Output "cikis $code"
} finally {
	$env:APPDATA = $savedAppData
}
if (Test-Path $log) {
	Select-String -Path $log -Pattern '^ZC |SCRIPT ERROR|Parse Error|ERROR: ' | Select-Object -First 60 | ForEach-Object { Write-Output "  $($_.Line)" }
}
