# PvPvE takım kampı gerçek çizici görüntüsü - GİZLİ masaüstünde (pencere görünmez, tools/fps_micro/hidden_launch.ps1), kullanıcı verisi yalıtılır.
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/pvp/kamp_goruntu.ps1 [-Harita ana] [-Out <klasör>]
param(
	[string]$Harita = "ana",
	[string]$Out = "",
	[int]$TimeoutSec = 300
)
$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
if ($Out -eq "") { $Out = Join-Path $PSScriptRoot "out" }
New-Item -ItemType Directory -Force $Out | Out-Null
$tmp = Join-Path $env:TEMP "pvp_kamp_goruntu"
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
$env:MOD = "pvp"
$env:HARITA = $(if ($Harita -eq "ana") { "" } else { $Harita })
$env:CAP_OUT = $Out
$log = Join-Path $Out "kamp_log.txt"
if (Test-Path $log) { Remove-Item $log -Force }
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$log`" -s res://tools/pvp/kamp_goruntu.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Output "cikis $code"
} finally {
	$env:APPDATA = $savedAppData
	$env:MOD = ""
	$env:HARITA = ""
}
if (Test-Path $log) { Get-Content $log | Select-String -Pattern "^CAP |PvP üs|SCRIPT ERROR|ERROR:" | Where-Object { $_ -notmatch "invalid UID|leaked|still in use" } | Select-Object -First 30 }
