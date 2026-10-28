# AĞ SONDASI çalıştırıcı (madde 349) - iki gerçek başsız süreç (host + istemci, LAN/ENet), isteğe bağlı UDP vekil (gecikme/jitter/kayıp).
# Kullanım (örnekler; hepsi yaklaşık 80-100 sn sürer, AYNI ANDA iki koşu başlatma):
#   powershell -ExecutionPolicy Bypass -File tools/mp_audit/net_probe/run_net_probe.ps1 -N 250 -Fight 1 -Tag temiz
#   ... -OneWayMs 30 -JitterMs 15 -LossPct 2 -Tag kayip2        (RTT ~60 ms, +-15 ms jitter, %2 kayıp, iki yönde)
#   ... -FpsHost 12 -Tag host12     (zayıf host: Engine.max_fps)     ... -FpsHost 12 -Steps 5 -Tag host12_adim5 (max_physics_steps_per_frame)
# Çıktı: %TEMP%\lilslayers_net_probe\<Tag>\{host,client}.json + rapor (net_probe_report.py). Açılış sahnesi atlanır (bkz. net_probe.gd başlığı).
param([int]$N = 150, [int]$Secs = 20, [string]$Tag = "x", [int]$Port = 7871, [int]$ProxyPort = 7872,
	[double]$OneWayMs = -1, [double]$JitterMs = 0, [double]$LossPct = 0, [int]$FpsHost = 0, [int]$FpsClient = 0, [int]$Steps = 0, [int]$Fight = 0)
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$runner = "res://tools/mp_audit/net_probe/net_probe.gd"
$dir = Join-Path $env:TEMP "lilslayers_net_probe\$Tag"
New-Item -ItemType Directory -Force $dir | Out-Null
Remove-Item (Join-Path $dir "*") -Force -ErrorAction SilentlyContinue
$env:LILSLAYERS_UNLOCK_ALL = "1" ## Ruh Mağazası kilitleri (madde 121) silah alımını engellemesin
$env:MP_DIR = $dir; $env:MP_PORT = "$Port"; $env:MP_SECS = "$Secs"; $env:MP_N = "$N"; $env:MP_FIGHT = "$Fight"; $env:MP_STEPS = "$Steps"
$proxy = $null
if ($OneWayMs -ge 0) {
	$env:MP_JOIN_PORT = "$ProxyPort"
	$proxy = Start-Process -FilePath "python" -ArgumentList @("-I", "`"$PSScriptRoot\udp_proxy.py`"", "$ProxyPort", "$Port", "$OneWayMs", "$JitterMs", "$LossPct", "7") -NoNewWindow -PassThru -RedirectStandardOutput "$dir\proxy_out.txt" -RedirectStandardError "$dir\proxy_err.txt"
	Start-Sleep -Milliseconds 800
} else {
	$env:MP_JOIN_PORT = "$Port"
}
$args0 = @("--headless", "--path", "`"$proj`"")
$env:MP_ROLE = "host"; $env:LILSLAYERS_UID = "uidhost0001"; $env:MP_FPS = "$FpsHost"
$h = Start-Process -FilePath $godot -ArgumentList ($args0 + @("--log-file", "`"$dir\host.log`"", "-s", $runner)) -NoNewWindow -PassThru -RedirectStandardOutput "$dir\host_out.txt" -RedirectStandardError "$dir\host_err.txt"
Start-Sleep -Milliseconds 1500
$env:MP_ROLE = "client"; $env:LILSLAYERS_UID = "uidclient0002"; $env:MP_FPS = "$FpsClient"
$c = Start-Process -FilePath $godot -ArgumentList ($args0 + @("--log-file", "`"$dir\client.log`"", "-s", $runner)) -NoNewWindow -PassThru -RedirectStandardOutput "$dir\client_out.txt" -RedirectStandardError "$dir\client_err.txt"
foreach ($p in @($h, $c)) { if (-not $p.WaitForExit(300000)) { $p.Kill(); Write-Output "RUN: zaman asimi" } }
if ($proxy -ne $null) { try { $proxy.Kill() } catch {} }
Get-Content "$dir\host_out.txt", "$dir\client_out.txt" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String -Pattern "PROBE" | ForEach-Object { $_.Line }
if (Test-Path "$dir\host.json") { & python -I -X utf8 "$PSScriptRoot\net_probe_report.py" $dir }
"Cikti klasoru: $dir"
