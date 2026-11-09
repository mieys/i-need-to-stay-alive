# KARA BATAKLIK gerçek çizici turu - GİZLİ masaüstünde (pencere görünmez, tools/fps_micro/hidden_launch.ps1), kullanıcı verisi yalıtılır.
# tools/harita_secimi/harita_tur.gd'yi HARITA=bataklik ile koşar: verilen hücrelere ışınlanıp görüntü alır.
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/bataklik/bataklik_tur.ps1 -Noktalar "kamp:139,198;gol:138,120" [-Saat 450] [-Tam]
#   suya giren ayak: -Betik res://tools/bataklik/su_ayak_capture.gd (SA_BASLA / SA_BITIS / SA_BEKLE ortam değişkenleri, çıktı out/su_ayak_*.png)
param(
	[string]$Noktalar = "kamp:139,198",
	[string]$Saat = "",
	[string]$Out = "",
	[string]$Gizle = "",
	[switch]$Tam,
	[string]$Betik = "res://tools/harita_secimi/harita_tur.gd",
	[int]$TimeoutSec = 400
)
$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
if ($Out -eq "") { $Out = Join-Path $PSScriptRoot "out\tur" }
New-Item -ItemType Directory -Force $Out | Out-Null
$tmp = Join-Path $env:TEMP "bataklik_tur"
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
$env:HARITA = "bataklik"
$env:CAP_OUT = $Out
$env:CAP_NOKTALAR = $Noktalar
$env:CAP_SAAT = $Saat
$env:CAP_GIZLE = $Gizle
$env:CAP_TAM = $(if ($Tam) { "1" } else { "" })
$log = Join-Path $Out "tur_log.txt"
if (Test-Path $log) { Remove-Item $log -Force }
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$log`" -s $Betik"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Output "cikis $code"
} finally {
	$env:APPDATA = $savedAppData
	$env:HARITA = ""
}
if (Test-Path $log) { Get-Content $log | Select-String -Pattern "^CAP |^SA |SCRIPT ERROR|ERROR:" | Where-Object { $_ -notmatch "invalid UID|leaked|still in use" } | Select-Object -First 30 }
