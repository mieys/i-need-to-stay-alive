# tests/test_*.gd dosyalarını tek tek (ayrı süreçte) koşar, test başına sonuç çıkarır (bkz. run_tests.gd).
#   powershell -File tools/enemy_rewrite/run_tests.ps1 [-Filter "*enemy*"] [-EnemyWorld 0|1] [-Out <özet dosyası>]
#   -EnemyWorld verilmezse ENEMY_WORLD ayarlanmaz: enemy_world_config.gd USE_ENEMY_WORLD (2026-10-03'ten beri true) geçerli.
# Çıktı: "FAIL <dosya>::<test>: <ilk hata>" satırları + sonda "TESTS_SUMMARY files=.. ran=.. failed_tests=.. crashed_files=..".
# Bilinen gürültü yok sayılır: invalid UID uyarıları, ObjectDB/RID sızıntıları, _spawn_floating_text current_scene artığı.
param(
	[string]$Filter = "test_*.gd",
	[int]$EnemyWorld = -1,
	[string]$Out = "",
	[int]$TimeoutSec = 180
)
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$tmp = Join-Path $env:TEMP "enemy_rewrite_tests"
New-Item -ItemType Directory -Force $tmp | Out-Null
if ($EnemyWorld -ge 0) { $env:ENEMY_WORLD = "$EnemyWorld" } else { Remove-Item env:ENEMY_WORLD -ErrorAction SilentlyContinue }
$files = Get-ChildItem (Join-Path $proj "tests") -Filter $Filter | Sort-Object Name
$ran = 0; $failed = @(); $crashed = @()
foreach ($f in $files) {
	$env:TEST_FILE = "res://tests/$($f.Name)"
	$o = Join-Path $tmp "out.txt"; $e = Join-Path $tmp "err.txt"
	## --log-file: testler kullanıcının oyun günlüklerini (%APPDATA%\Godot\app_userdata\<proje>\logs, son 10 dosya) döndürüp ezmesin
	## (2026-10-06: ekransız test koşuları kullanıcının gerçek oyun günlüklerini silmişti).
	$tlog = Join-Path $tmp "godot_test_run.log"
	$p = Start-Process -FilePath $godot -ArgumentList @("--headless", "--path", "`"$proj`"", "--log-file", "`"$tlog`"", "-s", "res://tools/enemy_rewrite/run_tests.gd") -NoNewWindow -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
	if (-not $p.WaitForExit($TimeoutSec * 1000)) { $p.Kill(); $crashed += "$($f.Name) (zaman aşımı)"; continue }
	$lines = Get-Content $e -Encoding UTF8
	$cur = ""; $done = $false; $bad = @{}
	foreach ($l in $lines) {
		if ($l -match '^RUN (.+)$') { $cur = $Matches[1]; continue }
		if ($l -match '^TESTFILE_DONE \S+ (\d+)') { $ran += [int]$Matches[1]; $done = $true; continue }
		if ($l -match 'Assertion failed|SCRIPT ERROR|Parse Error') {
			if ($l -match 'current_scene' -or $l -match 'invalid UID') { continue }
			$key = if ($cur -ne "") { $cur } else { $f.Name + "::(yükleme)" }
			if (-not $bad.ContainsKey($key)) { $bad[$key] = $l.Trim() }
		}
	}
	foreach ($k in $bad.Keys) { $failed += "$k : $($bad[$k])" }
	if (-not $done) { $crashed += $f.Name }
}
$failed | ForEach-Object { "FAIL $_" }
$crashed | ForEach-Object { "CRASH $_" }
$summary = "TESTS_SUMMARY ew=$EnemyWorld files=$($files.Count) ran=$ran failed_tests=$($failed.Count) crashed_files=$($crashed.Count)"
$summary
if ($Out -ne "") { (@($summary) + ($failed | ForEach-Object { "FAIL $_" }) + ($crashed | ForEach-Object { "CRASH $_" })) | Set-Content -Path $Out -Encoding UTF8 }
