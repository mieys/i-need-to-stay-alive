# Çok oyunculu senkron denetimi - iki GERÇEK süreç (host + istemci, başsız LAN). Kullanım:
#   powershell -ExecutionPolicy Bypass -File tools/mp_audit/run_audit.ps1 [-Mode sync|rejoin|security|migration|revive|dog|minotaur|underground|bosscatchup] [-Secs 40] [-N 70]
# Çıktı: %TEMP%\lilslayers_mp_audit\<mod>\{host,client}.json + özet. Karşılaştırma: python tools/mp_audit/sync_audit_compare.py <klasör> (sync modu).
#   sync   : host = Assasin, istemci = Vampir; yaratıklar + yetenekler + dükkan alımı; her 1 sn'de gerçek durum vs diğer tarafın kuklası, yaratık/drop sayıları,
#            ENet trafiği. rejoin : istemci 12. sn'de düşer, 2 sn sonra aynı kimlikle geri katılır; yakalama (yaratık/drop/silah/seviye) karşılaştırılır.
param([string]$Mode = "sync", [int]$Secs = 40, [int]$N = 70, [int]$Port = 7797, [int]$TimeoutSec = 240, [string]$Net = "lan", [string]$Kill = "crash")
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$dir = Join-Path $env:TEMP "lilslayers_mp_audit\$Mode$Net"
New-Item -ItemType Directory -Force $dir | Out-Null
Remove-Item (Join-Path $dir "*") -Force -ErrorAction SilentlyContinue
$runner = if ($Mode -eq "rejoin") { "res://tools/mp_audit/rejoin_audit.gd" } elseif ($Mode -eq "security") { "res://tools/mp_audit/security_audit.gd" } elseif ($Mode -eq "migration") { "res://tools/mp_audit/migration_audit.gd" } elseif ($Mode -eq "revive") { "res://tools/mp_audit/revive_audit.gd" } elseif ($Mode -eq "dog") { "res://tools/mp_audit/dog_audit.gd" } elseif ($Mode -eq "minotaur") { "res://tools/mp_audit/minotaur_audit.gd" } elseif ($Mode -eq "underground") { "res://tools/mp_audit/underground_audit.gd" } elseif ($Mode -eq "bosscatchup") { "res://tools/mp_audit/boss_catchup_audit.gd" } else { "res://tools/mp_audit/sync_audit.gd" }
$env:MP_NET = $Net; $env:MP_TAG = "MPA" + (Get-Random -Maximum 99999); $env:MP_DIR = $dir; $env:MP_PORT = "$Port"; $env:MP_SECS = "$Secs"; $env:MP_N = "$N"
$args0 = @("--headless", "--path", "`"$proj`"")
$env:MP_KILL = $Kill
$env:MP_ROLE = "host"; $env:LILSLAYERS_UID = "uidhost0001"
$h = Start-Process -FilePath $godot -ArgumentList ($args0 + @("--log-file", "`"$dir\host.log`"", "-s", $runner)) -NoNewWindow -PassThru -RedirectStandardOutput "$dir\host_out.txt" -RedirectStandardError "$dir\host_err.txt"
Start-Sleep -Milliseconds 1500
$env:MP_KILL = $Kill
$env:MP_ROLE = $(if ($Mode -eq "migration") { "b" } else { "client" }); $env:LILSLAYERS_UID = "uidclient0002"
$c = Start-Process -FilePath $godot -ArgumentList ($args0 + @("--log-file", "`"$dir\client.log`"", "-s", $runner)) -NoNewWindow -PassThru -RedirectStandardOutput "$dir\client_out.txt" -RedirectStandardError "$dir\client_err.txt"
$procs = @($h, $c)
$roles = @("host", $(if ($Mode -eq "migration") { "b" } else { "client" }))
if ($Mode -eq "migration") {
	## 3. süreç: ikinci istemci "c" (host düşünce yeni host'a bağlanan). Yeni host "b" olur (ilk katılan).
	$env:MP_ROLE = "c"; $env:LILSLAYERS_UID = "uidclient0003"
	$c2 = Start-Process -FilePath $godot -ArgumentList ($args0 + @("--log-file", "`"$dir\c.log`"", "-s", $runner)) -NoNewWindow -PassThru -RedirectStandardOutput "$dir\c_out.txt" -RedirectStandardError "$dir\c_err.txt"
	$procs += $c2; $roles += "c"
}
if ($Mode -eq "security") {
	## 3. süreç: oyun BAŞLADIKTAN sonra bağlanan yabancı (kendi bayrak dosyasını bekler, bkz. security_audit.gd)
	$env:MP_ROLE = "stranger"; $env:LILSLAYERS_UID = "uidstranger03"
	$st = Start-Process -FilePath $godot -ArgumentList ($args0 + @("--log-file", "`"$dir\stranger.log`"", "-s", $runner)) -NoNewWindow -PassThru -RedirectStandardOutput "$dir\stranger_out.txt" -RedirectStandardError "$dir\stranger_err.txt"
	$procs += $st; $roles += "stranger"
}
foreach ($p in $procs) { if (-not $p.WaitForExit($TimeoutSec * 1000)) { $p.Kill(); Write-Output "RUN: zaman asimi" } }
foreach ($r in $roles) {
	Get-Content "$dir\$($r)_out.txt", "$dir\$($r)_err.txt" -Encoding UTF8 -ErrorAction SilentlyContinue |
		Select-String -Pattern "^MP|SCRIPT ERROR|ERROR:|Invalid|Nonexistent|Assertion|Parse Error" | Where-Object { $_.Line -notmatch "invalid UID|resources still in use|ObjectDB" } |
		ForEach-Object { "[$r] $($_.Line)" } | Select-Object -First 25
}
"Çıktı klasörü: $dir"
