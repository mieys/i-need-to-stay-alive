# FRAGMAN SAHNE 1 (cölde, 16:9): sahne1.gd - host (Sovalye) + c1 (Talon) BASSIZ, viewer (Buyucu Kiz) gizli masaustunde pencereli, 1920x1080.
#   powershell -ExecutionPolicy Bypass -File tools/tanitim/sahne1.ps1 [-End 34]
# Cikti: $env:TEMP\tanitim_cap\sahne1\ (kareler\sahne\*.jpg, zaman.json, ses.wav, <rol>.log, sig_*.txt)
param(
	[int]$End = 34, [int]$Port = 7833, [int]$TimeoutSec = 420
)
. "$PSScriptRoot\..\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$out = Join-Path $env:TEMP "tanitim_cap\sahne1"
if (Test-Path $out) { Get-ChildItem $out -Force | Where-Object { $_.Name -notlike "scout_*" -and $_.Name -ne "probe.log" } | Remove-Item -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null
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
# rol -> karakter, ad, silahlar (Sovalye 7, Talon 1, Buyucu Kiz 4)
$roles = @(
	@{ role = "host"; ch = "7"; nm = "Kaan"; wp = "kalkan,mizrak" },
	@{ role = "c1"; ch = "1"; nm = "Deniz"; wp = "uzunkilic,topuz,pence" }
)
$viewer = @{ role = "viewer"; ch = "4"; nm = "Ece"; wp = "buz_asasi,fire_staff" }
$env:LILSLAYERS_UNLOCK_ALL = "1"
$env:HARITA = "col"
$env:TN_DIR = $out
$env:CO_PORT = "$Port"; $env:SAHNE_END = "$End"
if ($env:SAHNE_NOZOOM -eq "1") { Write-Host "NOZOOM acik" }
$saved = $env:APPDATA
$procs = @()
try {
	foreach ($r in $roles) {
		$env:CO_ROLE = $r.role; $env:CO_CHAR = $r.ch; $env:CO_NAME = $r.nm; $env:CO_WEAPONS = $r.wp; $env:LILSLAYERS_UID = "uidsh$($r.role)"
		$env:APPDATA = New-FakeAppData $r.role
		$log = Join-Path $out "$($r.role).log"
		$procs += Start-Process -FilePath $godot -ArgumentList @("--headless", "--path", "`"$proj`"", "--log-file", "`"$log`"", "-s", "res://tools/tanitim/sahne1.gd") -NoNewWindow -PassThru -RedirectStandardOutput (Join-Path $out "$($r.role).out")
		Start-Sleep -Milliseconds 1500
	}
	$env:CO_ROLE = $viewer.role; $env:CO_CHAR = $viewer.ch; $env:CO_NAME = $viewer.nm; $env:CO_WEAPONS = $viewer.wp; $env:LILSLAYERS_UID = "uidshviewer"
	$env:APPDATA = New-FakeAppData "viewer"
	$vlog = Join-Path $out "viewer.log"
	$argLine = "--path `"$proj`" --windowed --resolution 960x540 --audio-driver Dummy --log-file `"$vlog`" -s res://tools/tanitim/sahne1.gd"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
	Write-Host "viewer kod=$code"
} finally {
	$env:APPDATA = $saved
	Remove-Item Env:HARITA -ErrorAction SilentlyContinue
	foreach ($p in $procs) { if (-not $p.HasExited) { if (-not $p.WaitForExit(20000)) { $p.Kill() } } }
}
foreach ($r in "host", "c1", "viewer") {
	$l = Join-Path $out "$r.log"
	if (Test-Path $l) { Get-Content $l | Select-String "^SH\[|SCRIPT ERROR|ERROR:" | Select-Object -Last 14 }
}
