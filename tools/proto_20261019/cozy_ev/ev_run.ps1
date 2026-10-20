# Cozy ev yakalama betiklerini GIZLI masaustunde kosar (hidden_launch.ps1), APPDATA yalitilir (agac_run.ps1 ile ayni duzen).
#   powershell -ExecutionPolicy Bypass -File tools/proto_20261019/cozy_ev/ev_run.ps1 -Script ev_kapi_capture.gd -Label once
# Betik KAP_DIR ortam degiskenine PNG yazar: tools/proto_20261019/out/ev/<Label>
param([string]$Script = "ev_derinlik_capture.gd", [string]$Label = "once", [string]$Env = "", [int]$TimeoutSec = 180)
. "$PSScriptRoot\..\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$tmp = Join-Path $env:TEMP "ev_cap"
New-Item -ItemType Directory -Force $tmp | Out-Null
$out = Join-Path $PSScriptRoot "..\out\ev\$Label"
New-Item -ItemType Directory -Force $out | Out-Null
$out = (Resolve-Path $out).Path
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
$env:KAP_DIR = $out
foreach ($kv in ($Env -split ';')) { if ($kv -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] } }
$log = Join-Path $tmp "log.txt"
if (Test-Path $log) { Remove-Item $log -Force }
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$log`" -s res://tools/proto_20261019/cozy_ev/$Script"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Host "kod=$code out=$out"
} finally {
	$env:APPDATA = $savedAppData
}
Get-Content $log | Select-String "KAP|ERROR|SCRIPT" | Select-Object -First 30
