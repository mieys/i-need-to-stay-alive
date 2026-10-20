# Pençe hızlı vuruş yakalaması (pence_hizli_capture.gd) - GİZLİ masaüstünde. -Rate: saldırı hızı katı (6 = üst sınır).
#   powershell -ExecutionPolicy Bypass -File tools/proto_20261019/pence_hizli_run.ps1 -Rate 6
param([double]$Rate = 6, [int]$TimeoutSec = 180)
. "$PSScriptRoot\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$tmp = Join-Path $env:TEMP "pence_hizli_cap"
New-Item -ItemType Directory -Force $tmp | Out-Null
$out = Join-Path $tmp ("kareler_" + [int]$Rate)
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null
$appName = "Temiz S$([char]0x00FC)r$([char]0x00FC)m"
$realUser = Join-Path $env:APPDATA "Godot\app_userdata\$appName"
$fakeRoot = Join-Path $tmp "appdata"
$fakeUser = Join-Path $fakeRoot "Godot\app_userdata\$appName"
New-Item -ItemType Directory -Force $fakeUser | Out-Null
if (Test-Path $realUser) {
	Get-ChildItem $realUser -Filter "*.cfg" -File | ForEach-Object { Copy-Item $_.FullName (Join-Path $fakeUser $_.Name) -Force }
}
$env:AC_DIR = $out
$env:BC_RATE = "$Rate"
$log = Join-Path $tmp "log.txt"
if (Test-Path $log) { Remove-Item $log -Force }
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1280x720 --audio-driver Dummy --log-file `"$log`" -s res://tools/proto_20261019/pence_hizli_capture.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Host "kod=$code kareler=$out"
} finally {
	$env:APPDATA = $savedAppData
}
Get-Content $log | Select-String "RATE|BITTI|ERROR" | Select-Object -First 12
