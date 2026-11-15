# Hadime kara delik prototipleri yakalamasi (kara_delik_capture.gd) - GIZLI masaustunde (hidden_launch.ps1), APPDATA yalitilir.
#   powershell -ExecutionPolicy Bypass -File tools/proto_20261111/kara_delik/kara_delik_run.ps1 [-Env "KD_CODES=now,A;KD_NIGHT=1"]
# Ham kareler %TEMP%\kara_delik_cap\<Sub> (varsayilan oyun; depoya girmez). Yaratikli: -Sub yaratik -Env "KD_CODES=D;KD_MOBS=14;KD_WALK=0"; birlestirme: python -I tools/proto_20261111/kara_delik/kara_delik_gif.py
param([string]$Env = "", [int]$TimeoutSec = 240, [string]$Sub = "oyun")
. "$PSScriptRoot\..\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$tmp = Join-Path $env:TEMP "kara_delik_cap"
New-Item -ItemType Directory -Force $tmp | Out-Null
$out = Join-Path $tmp $Sub
New-Item -ItemType Directory -Force $out | Out-Null
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
$env:KD_SHEETS = (Join-Path $PSScriptRoot "out\sheets")
$env:KD_CODES = ""
foreach ($kv in ($Env -split ';')) { if ($kv -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] } }
# yalniz bu aracin ham kare klasoru, yalniz yeniden cekilen kodlar (KD_CODES bossa hepsi; zamanlar.json kod kod birlesir)
if ($env:KD_CODES) {
	foreach ($c in ($env:KD_CODES -split ',')) { Get-ChildItem $out -Filter "$($c)_*.png" -File -ErrorAction SilentlyContinue | Remove-Item -Force }
} else {
	Get-ChildItem $out -Filter "*.png" -File -ErrorAction SilentlyContinue | Remove-Item -Force
}
$log = Join-Path $tmp "log.txt"
if (Test-Path $log) { Remove-Item $log -Force }
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$log`" -s res://tools/proto_20261111/kara_delik/kara_delik_capture.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Host "kod=$code"
} finally {
	$env:APPDATA = $savedAppData
}
Get-Content $log | Select-String "SHOT|OLCU|BITTI|ERROR|SCRIPT|MOBS" | Select-Object -First 60
