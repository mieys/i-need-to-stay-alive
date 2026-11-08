# Multiplayer savas gorsel karmasa olcumu (mp_clutter.gd). Host + istemci BASSIZ, izleyici (viewer) GIZLI masaustunde pencereli, gercek renderer.
#   powershell -ExecutionPolicy Bypass -File tools/buyuk_test/mp_clutter.ps1 -Label ags1 [-Chars "4,12,10"] [-Tier 8] [-N 70] [-Secs 70] [-Solo]
# -Solo: yalniz izleyici, ayni karakter/silahlar, tek oyunculu (cok oyunculu artisi ayirmak icin taban).
# Cikti: tools/buyuk_test/out/<Label>/{host,client,viewer}.log + viewer/*.jpg + flick_viewer.csv
param(
	[string]$Label = "ags1",
	[string]$Chars = "4,12,10",
	[string]$Weapons = "fire_staff,uzunkilic,tabanca;yay,buz_asasi,topuz;lightning_staff,pence,arcane",
	[int]$Tier = 8, [int]$N = 70, [int]$Secs = 70, [int]$Port = 7811, [int]$TimeoutSec = 400,
	[switch]$Solo
)
. "$PSScriptRoot\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$outRoot = Join-Path $PSScriptRoot "out\$Label"
$outDir = Join-Path $outRoot "viewer"
New-Item -ItemType Directory -Force $outDir | Out-Null
Get-ChildItem $outDir -File -ErrorAction SilentlyContinue | Remove-Item -Force
$ch = $Chars -split ","
$wp = $Weapons -split ";"
$appName = "Temiz S$([char]0x00FC)r$([char]0x00FC)m"
$realUser = Join-Path $env:APPDATA "Godot\app_userdata\$appName"
$tmp = Join-Path $env:TEMP "buyuk_test"
function New-FakeAppData($role) {
	$root = Join-Path $tmp "mpc_appdata_$role"
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
$env:BT_OUT = $outDir
$env:MP_PORT = "$Port"; $env:MP_SECS = "$Secs"; $env:MP_N = "$N"; $env:MP_TIER = "$Tier"
$env:MP_PLAYERS = $(if ($Solo) { "1" } else { "3" })
$saved = $env:APPDATA
$procs = @()
try {
	if (-not $Solo) {
		$i = 0
		foreach ($role in "host", "client") {
			$env:MP_ROLE = $role; $env:MP_CHAR = $ch[$i]; $env:MP_WEAPONS = $wp[$i]; $env:LILSLAYERS_UID = "uidmpc$role"
			$env:APPDATA = New-FakeAppData $role
			$log = Join-Path $outRoot "$role.log"
			$procs += Start-Process -FilePath $godot -ArgumentList @("--headless", "--path", "`"$proj`"", "--log-file", "`"$log`"", "-s", "res://tools/buyuk_test/mp_clutter.gd") -NoNewWindow -PassThru
			Start-Sleep -Milliseconds 1500
			$i++
		}
	}
	$role = $(if ($Solo) { "solo" } else { "viewer" })
	$env:MP_ROLE = $role; $env:MP_CHAR = $ch[2]; $env:MP_WEAPONS = $wp[2]; $env:LILSLAYERS_UID = "uidmpcviewer"
	$env:APPDATA = New-FakeAppData "viewer"
	$vlog = Join-Path $outRoot "viewer.log"
	if (Test-Path $vlog) { Remove-Item $vlog -Force }
	$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$vlog`" -s res://tools/buyuk_test/mp_clutter.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Host "viewer kod=$code"
} finally {
	$env:APPDATA = $saved
	foreach ($p in $procs) { if (-not $p.HasExited) { if (-not $p.WaitForExit(20000)) { $p.Kill() } } }
}
