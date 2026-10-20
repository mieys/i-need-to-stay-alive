# Yildirim Asasi ses videosu yakalamasi (yildirim_video_capture.gd) - GIZLI masaustunde (hidden_launch.ps1), APPDATA yalitilir
# (cicek_run.ps1 ile ayni). Godot Movie Maker: --write-movie (MJPEG + PCM AVI, sabit 60 kare/sn), 1280x720.
#   powershell -ExecutionPolicy Bypass -File tools/proto_20261019/yildirim_video_run.ps1 [-Env "YV_X=3616;YV_Y=2000"]
# Sonra: python tools/proto_20261019/yildirim_video.py  (4 ses surumu + MP4)
param([string]$Env = "", [int]$TimeoutSec = 600)
. "$PSScriptRoot\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$tmp = Join-Path $env:TEMP "yildirim_video_cap"
New-Item -ItemType Directory -Force $tmp | Out-Null
$out = Join-Path $PSScriptRoot "out\yildirim_video"
New-Item -ItemType Directory -Force $out | Out-Null
$avi = Join-Path $tmp "yakalama.avi"
if (Test-Path $avi) { Remove-Item $avi -Force }
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
$env:YV_DIR = $tmp
foreach ($kv in ($Env -split ';')) { if ($kv -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] } }
$log = Join-Path $tmp "log.txt"
if (Test-Path $log) { Remove-Item $log -Force }
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1280x720 --write-movie `"$avi`" --fixed-fps 60 --log-file `"$log`" -s res://tools/proto_20261019/yildirim_video_capture.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Host "kod=$code"
} finally {
	$env:APPDATA = $savedAppData
}
Get-Content $log | Select-String "EV |TIK|BITTI|HATA|ERROR|SCRIPT ERROR" | Select-Object -First 60
if (Test-Path $avi) { Write-Host ("AVI " + [math]::Round((Get-Item $avi).Length / 1MB, 1) + " MB") }
