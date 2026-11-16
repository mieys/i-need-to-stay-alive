# ATEŞ BÖCEĞİ GECE ÇEKİMİ (madde 761): tools/ates_bocegi/gece_cekim.gd'yi GİZLİ masaüstünde (pencere görünmez) koşar, APPDATA yalıtılır.
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/ates_bocegi/gece_cekim.ps1 -Noktalar "ad:x,y;ad2:x,y" (ayak, dünya px)
param([string]$Harita = "ana", [string]$Noktalar = "", [string]$Out = "", [int]$TimeoutSec = 500)
$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
if ($Out -eq "") { $Out = Join-Path $PSScriptRoot "out" }
New-Item -ItemType Directory -Force $Out | Out-Null
$tmp = Join-Path $env:TEMP "ates_bocegi_cekim"
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
$env:HARITA = $Harita
$env:CAP_OUT = $Out
$env:CAP_NOKTALAR = $Noktalar
$log = Join-Path $tmp "log_$Harita.txt"
if (Test-Path $log) { Remove-Item $log -Force }
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$log`" -s res://tools/ates_bocegi/gece_cekim.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Host "kod=$code"
} finally {
	$env:APPDATA = $savedAppData
	Remove-Item Env:HARITA -ErrorAction SilentlyContinue
}
Get-Content $log | Select-String "ATESBOCEK|SCRIPT ERROR|Parse Error" | Select-Object -First 10
