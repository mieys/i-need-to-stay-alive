# Tanitim CO-OP sahnesi (tanitim_coop.gd): host + c1 + c2 BASSIZ, viewer GIZLI masaustunde pencereli istemci (dikey 1080x1920 kayit,
# gercek zamanli JPG kareler + zaman.json + ses.wav). mp_clutter.ps1 (madde 425) duzeni; her rol ayri sahte APPDATA.
#   powershell -ExecutionPolicy Bypass -File tools/tanitim/coop.ps1 [-Secs 40] [-RecFrom 10] [-RecSecs 14]
# Cikti: $env:TEMP\tanitim_cap\coop\ (kareler\coop\*.jpg, zaman.json, ses.wav, <rol>.log)
param(
	[string]$Chars = "7,4,2,10",
	[string]$Names = "Kaan,Deniz,Arda,Ece",
	[string]$Weapons = "kalkan,mizrak;fire_staff,lightning_staff;buz_asasi,pompali;gokkusagi,yay",
	[int]$Tier = 7, [int]$N = 45, [int]$Secs = 40, [int]$RecFrom = 10, [int]$RecSecs = 14, [int]$Port = 7833, [int]$TimeoutSec = 400
)
. "$PSScriptRoot\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$out = Join-Path $env:TEMP "tanitim_cap\coop"
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null
$ch = $Chars -split ","; $nm = $Names -split ","; $wp = $Weapons -split ";"
$appName = "Temiz S$([char]0x00FC)r$([char]0x00FC)m"
$realUser = Join-Path $env:APPDATA "Godot\app_userdata\$appName"
function New-FakeAppData($role) {
	$root = Join-Path $env:TEMP "tanitim_cap\appdata_$role"
	$user = Join-Path $root "Godot\app_userdata\$appName"
	New-Item -ItemType Directory -Force $user | Out-Null
	if (Test-Path $realUser) {
		Get-ChildItem $realUser -Filter "*.cfg" -File | ForEach-Object { Copy-Item $_.FullName (Join-Path $user $_.Name) -Force }
		foreach ($d in "vulkan", "shader_cache") {
			if ((Test-Path (Join-Path $realUser $d)) -and -not (Test-Path (Join-Path $user $d))) {
				robocopy (Join-Path $realUser $d) (Join-Path $user $d) /E /NFL /NDL /NJH /NJS /NP | Out-Null
			}
		}
	}
	return $root
}
$env:LILSLAYERS_UNLOCK_ALL = "1"
$env:TN_DIR = $out
$env:CO_PORT = "$Port"; $env:CO_SECS = "$Secs"; $env:CO_N = "$N"; $env:CO_TIER = "$Tier"; $env:CO_PLAYERS = "4"
$env:CO_REC_FROM = "$RecFrom"; $env:CO_REC_SECS = "$RecSecs"
$saved = $env:APPDATA
$procs = @()
try {
	$i = 0
	foreach ($role in "host", "c1", "c2") {
		$env:CO_ROLE = $role; $env:CO_CHAR = $ch[$i]; $env:CO_NAME = $nm[$i]; $env:CO_WEAPONS = $wp[$i]; $env:LILSLAYERS_UID = "uidtn$role"
		$env:APPDATA = New-FakeAppData $role
		$log = Join-Path $out "$role.log"
		$procs += Start-Process -FilePath $godot -ArgumentList @("--headless", "--path", "`"$proj`"", "--log-file", "`"$log`"", "-s", "res://tools/tanitim/tanitim_coop.gd") -NoNewWindow -PassThru
		Start-Sleep -Milliseconds 1500
		$i++
	}
	$env:CO_ROLE = "viewer"; $env:CO_CHAR = $ch[3]; $env:CO_NAME = $nm[3]; $env:CO_WEAPONS = $wp[3]; $env:LILSLAYERS_UID = "uidtnviewer"
	$env:APPDATA = New-FakeAppData "viewer"
	$vlog = Join-Path $out "viewer.log"
	$argLine = "--path `"$proj`" --windowed --resolution 960x540 --audio-driver Dummy --log-file `"$vlog`" -s res://tools/tanitim/tanitim_coop.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Host "viewer kod=$code"
} finally {
	$env:APPDATA = $saved
	foreach ($p in $procs) { if (-not $p.HasExited) { if (-not $p.WaitForExit(20000)) { $p.Kill() } } }
}
foreach ($r in "host", "c1", "c2", "viewer") {
	$l = Join-Path $out "$r.log"
	if (Test-Path $l) { Get-Content $l | Select-String "^CO\[|SCRIPT ERROR" | Select-Object -Last 6 }
}
