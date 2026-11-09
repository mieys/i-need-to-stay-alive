# Tanitim videosu cekimi (tanitim_capture.gd) - GIZLI masaustunde (hidden_launch.ps1), APPDATA yalitilir (yildirim_video_run.ps1 ile ayni).
# Godot Movie Maker: --write-movie (MJPEG + PCM AVI, sabit kare/sn). Kok viewport 1080x1920 (pencere 540x960, ekrana sigar).
#   powershell -ExecutionPolicy Bypass -File tools/tanitim/cek.ps1 -Plan dunya [-Env "TN_CHAR=4;TN_ZOOM=2.5"]
# Cikti: $env:TEMP\tanitim_cap\<plan>\ (cekim.avi + cekimler.json + log.txt). Sonra: python -I tools/tanitim/kurgu.py
param([string]$Plan = "deneme", [string]$Env = "", [int]$Fps = 60, [int]$TimeoutSec = 1500,
	[string]$Script = "res://tools/tanitim/tanitim_capture.gd", [string]$Res = "540x960")
. "$PSScriptRoot\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$tmp = Join-Path $env:TEMP "tanitim_cap\$Plan"
New-Item -ItemType Directory -Force $tmp | Out-Null
$avi = Join-Path $tmp "cekim.avi"
if (Test-Path $avi) { Remove-Item $avi -Force }
$kareler = Join-Path $tmp "kareler"
if (Test-Path $kareler) { Remove-Item $kareler -Recurse -Force }
$appName = "Temiz S$([char]0x00FC)r$([char]0x00FC)m"
$realUser = Join-Path $env:APPDATA "Godot\app_userdata\$appName"
$fakeRoot = Join-Path $env:TEMP "tanitim_cap\appdata"
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
$env:TN_DIR = $tmp
$env:TN_PLAN = $Plan
$env:TN_FPS = "$Fps"
foreach ($kv in ($Env -split ';')) { if ($kv -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] } }
$log = Join-Path $tmp "log.txt"
if (Test-Path $log) { Remove-Item $log -Force }
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution $Res --write-movie `"$avi`" --fixed-fps $Fps --log-file `"$log`" -s $Script"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Host "kod=$code"
} finally {
	$env:APPDATA = $savedAppData
}
Get-Content $log | Select-String "^TN |SCRIPT ERROR|ERROR:" | Select-Object -Last 80
if (Test-Path $avi) { Write-Host ("AVI " + [math]::Round((Get-Item $avi).Length / 1MB, 1) + " MB") }
