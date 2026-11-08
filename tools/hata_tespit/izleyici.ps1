<#
  Hata-tespit YEREL IZLEYICI (madde 420). Windows Gorev Zamanlayici her dakika calistirir (izleyici_gizli.vbs ile).
    1) discord_cek.ps1 ile kanali yoklar (yapay zeka KULLANMAZ, ucretsiz) -> son satir "BEKLEYEN: N".
    2) N > 0 ve son mesajdan -SessizDakika gectiyse (ya da en eski bekleyen mesaj -EnFazlaBekleDakika'dan eskiyse)
       Claude CLI'yi `claude -p` ile YALNIZ OKUMA yetkisiyle baslatir (docs/hata_tespit/izleyici_gorevi.md).
       Model sonucu JSON verir; BU BETIK dogrular, defter/rapor dosyalarini yazar, sablonlu Discord yanitlarini
       discord_yaz.ps1 ile gonderir ve islenen_id.txt'yi ilerletir (modelin yazma/komut/Discord yetkisi YOK).
  Maliyet: CLAUDE.md + otomatik hafiza yuklenmez (CLAUDE_CODE_DISABLE_CLAUDE_MDS/AUTO_MEMORY), kosu basina ~0,1-0,3 USD.
  Sinirlar: saatte en cok -SaatteEn analiz; basarisiz analizden sonra 10 / 30 dk, art arda 3. basarisizlikta 6 saat;
  analiz -ZamanAsimiDakika'da oldurulur.
  Test: -KuruCalisma (karar verir, baslatmaz); -SonucDosyasi <json> [-DocsDir <klasor>] [-YanitDeneme] (modeli atlar, sonucu uygular).
  Kayit: docs/hata_tespit/ham/izleyici.log (git'e girmez). Not: dosya sadece ASCII (Windows PowerShell 5.1).
#>
param(
  [switch]$KuruCalisma,
  [double]$SessizDakika = 0.5,
  [int]$EnFazlaBekleDakika = 5,
  [int]$SaatteEn = 8,
  [int]$ZamanAsimiDakika = 25,
  [string]$DocsDir = "",
  [string]$SonucDosyasi = "",
  [switch]$YanitDeneme
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if (-not $DocsDir) { $DocsDir = Join-Path $root "docs\hata_tespit" }
$ham = Join-Path $DocsDir "ham"
New-Item -ItemType Directory -Force -Path $ham | Out-Null
$logFile = Join-Path $ham "izleyici.log"
$lockFile = Join-Path $ham "izleyici.kilit"
$runsFile = Join-Path $ham "izleyici_calismalar.txt"
$failFile = Join-Path $ham "izleyici_basarisiz.txt"
$processedFile = Join-Path $ham "islenen_id.txt"
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Log([string]$m) {
  $line = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + " " + $m
  [IO.File]::AppendAllText($logFile, $line + "`n", $utf8)
  Write-Output $line
}
function ParseUtc([string]$s) {
  return [datetime]::Parse($s.Trim(), [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal)
}
function LogOnce([string]$key, [string]$m, [int]$minutes = 10) {
  $f = Join-Path $ham ("izleyici_" + $key + ".txt")
  if (Test-Path $f) {
    $last = ParseUtc (Get-Content -Raw $f)
    if (((Get-Date).ToUniversalTime() - $last).TotalMinutes -lt $minutes) { return }
  }
  [IO.File]::WriteAllText($f, (Get-Date).ToUniversalTime().ToString("o"), $utf8)
  Log $m
}
function Get-Pending {
  $processed = [uint64]0
  if (Test-Path $processedFile) {
    $p = (Get-Content -Raw $processedFile).Trim()
    if ($p -match '^\d+$') { $processed = [uint64]$p }
  }
  $minId = [uint64]::MaxValue
  $maxId = [uint64]0
  $ids = New-Object System.Collections.Generic.List[string]
  $lines = New-Object System.Collections.Generic.List[string]
  $raw = Join-Path $ham "mesajlar.jsonl"
  if (Test-Path $raw) {
    foreach ($ln in [IO.File]::ReadLines($raw, $utf8)) {
      if ($ln -match '^\{"id":"(\d+)"') {
        $idText = $Matches[1]
        $v = [uint64]$idText
        if ($v -gt $processed) {
          $ids.Add($idText)
          $lines.Add($ln)
          if ($v -lt $minId) { $minId = $v }
          if ($v -gt $maxId) { $maxId = $v }
        }
      }
    }
  }
  return [pscustomobject]@{ Count = $ids.Count; MinId = $minId; MaxId = $maxId; Ids = $ids; Lines = $lines }
}
function Snowflake-Ms([uint64]$id) {
  return ([int64]($id -shr 22)) + 1420070400000
}
# Basarisiz analiz kaydi: "zaman|bekleme_dk|art_arda_sayi". Art arda 3. basarisizlikta 6 saat beklenir (kota korumasi).
function Set-Fail([int]$baseWait) {
  $n = 1
  if (Test-Path $failFile) {
    $pp = (Get-Content -Raw $failFile).Trim() -split '\|'
    if ($pp.Count -gt 2) { $n = [int]$pp[2] + 1 }
  }
  $wait = $baseWait
  if ($n -ge 3) { $wait = 360 }
  [IO.File]::WriteAllText($failFile, (Get-Date).ToUniversalTime().ToString("o") + "|" + $wait + "|" + $n, $utf8)
  return $wait
}

# Modelin JSON sonucunu dogrular ve uygular (dosyalar + sablonlu yanitlar + islenen_id). Hata verirse FIRLATIR.
function Apply-Result([string]$resultText, $pd) {
  $a = $resultText.IndexOf("{")
  $b = $resultText.LastIndexOf("}")
  if ($a -lt 0 -or $b -le $a) { throw "sonuc JSON degil" }
  $res = $resultText.Substring($a, $b - $a + 1) | ConvertFrom-Json
  if ($res.tum_mesajlar_islendi -ne $true) { throw "model tum mesajlari islemedigini bildirdi" }
  $defter = [string]$res.defter_md
  if ($defter.Length -lt 50 -or $defter.Length -gt 30000 -or -not $defter.TrimStart().StartsWith("# Hata/denge defteri")) { throw "defter_md gecersiz" }
  $rapor = [string]$res.rapor_ek_md
  if ($rapor.Length -lt 10 -or $rapor.Length -gt 20000) { throw "rapor_ek_md gecersiz" }
  $replies = @(@($res.yanitlar) | Where-Object { $_ })
  if ($replies.Count -gt 3) { throw "3'ten fazla yanit istendi" }
  foreach ($r in $replies) {
    if ($pd.Ids -notcontains [string]$r.reply_to) { throw ("yanit hedefi bekleyen mesaj degil: " + $r.reply_to) }
    if (@("dogrulandi", "bilgi_gerekli", "durum") -notcontains [string]$r.sablon) { throw "bilinmeyen sablon" }
  }

  # Dosyalar
  $defterFile = Join-Path $DocsDir "defter.md"
  if (Test-Path $defterFile) { Copy-Item $defterFile ($defterFile + ".bak") -Force }
  [IO.File]::WriteAllText($defterFile, $defter.TrimEnd() + "`n", $utf8)
  $day = (Get-Date).ToString("yyyy-MM-dd")
  $rf = Join-Path $DocsDir ("rapor_" + $day + ".md")
  $head = ""
  if (-not (Test-Path $rf)) { $head = "# Rapor " + $day + "`n`n" }
  [IO.File]::AppendAllText($rf, $head + "## Izleyici kosusu " + (Get-Date).ToString("HH:mm") + "`n" + $rapor.Trim() + "`n`n", $utf8)

  # Sablonlu yanitlar (betik dogrular; hata verirse yalniz o yanit atlanir)
  $yaz = Join-Path $PSScriptRoot "discord_yaz.ps1"
  $sent = 0
  foreach ($r in $replies) {
    $pr = @{ ReplyTo = [string]$r.reply_to; Sablon = [string]$r.sablon; DocsDir = $DocsDir }
    if ($r.sablon -eq "dogrulandi") { $pr.Konu = [string]$r.konu }
    elseif ($r.sablon -eq "bilgi_gerekli") { $pr.Bilgi = @(@($r.bilgi) | ForEach-Object { [string]$_ }) }
    if ($YanitDeneme) { $pr.DryRun = $true }
    try {
      $o = @(& $yaz @pr 2>&1 | ForEach-Object { "$_" })
      $c = $LASTEXITCODE
    } catch {
      $o = @($_.Exception.Message)
      $c = 99
    }
    if ($c -eq 0) { $sent++; Log ("Yanit: " + $r.sablon + " -> " + ($o | Select-Object -First 1)) | Out-Null }
    else { Log ("Yanit ATLANDI (" + $r.sablon + ", cikis " + $c + "): " + ($o | Select-Object -First 1)) | Out-Null }
  }

  # En son: islenen_id ilerler (defter + rapor yazildiktan sonra)
  [IO.File]::WriteAllText($processedFile, [string]$pd.MaxId, $utf8)
  return [pscustomobject]@{ Ozet = ([string]$res.ozet); Yanit = $sent }
}

# Log boyutu sinirli
if ((Test-Path $logFile) -and ((Get-Item $logFile).Length -gt 300KB)) {
  $keep = Get-Content -Tail 400 -Encoding UTF8 $logFile
  [IO.File]::WriteAllText($logFile, (($keep -join "`n") + "`n"), $utf8)
}

# TEST: hazir bir sonuc dosyasini uygula (modeli atla)
if ($SonucDosyasi) {
  $pdt = Get-Pending
  if ($pdt.Count -eq 0) { Log "TEST: bekleyen mesaj yok"; exit 0 }
  try {
    $rt = Apply-Result (Get-Content -Raw -Encoding UTF8 $SonucDosyasi) $pdt
    Log ("TEST uygulandi: " + $pdt.Count + " mesaj, " + $rt.Yanit + " yanit. Ozet: " + $rt.Ozet)
  } catch {
    Log ("TEST uygulanamadi: " + $_.Exception.Message)
  }
  exit 0
}

# Analiz suruyorsa (kilit) hicbir sey yapma; eski kilidi temizle
if (Test-Path $lockFile) {
  $age = ((Get-Date) - (Get-Item $lockFile).LastWriteTime).TotalMinutes
  if ($age -lt ($ZamanAsimiDakika + 10)) { exit 0 }
  Remove-Item $lockFile -Force
}

# 1) Kanali yokla (ucretsiz)
$prevPref = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "discord_cek.ps1") -OutDir $ham 2>&1 | ForEach-Object { "$_" }
$code = $LASTEXITCODE
$ErrorActionPreference = $prevPref
if ($code -ne 0) {
  LogOnce "cek_hata" ("Discord yoklamasi basarisiz (cikis " + $code + "): " + (($out | Select-Object -First 2) -join " | "))
  exit 0
}
$pending = -1
foreach ($l in $out) { if ($l -match '^BEKLEYEN:\s*(\d+)') { $pending = [int]$Matches[1] } }
if ($pending -lt 0) { LogOnce "cek_hata" "BEKLEYEN satiri okunamadi"; exit 0 }
if ($pending -eq 0) { exit 0 }

# 2) Oyuncular yazmayi birakti mi? (snowflake zamani = mesajin gercek zamani)
$pd = Get-Pending
$nowMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$quiet = ($nowMs - (Snowflake-Ms $pd.MaxId)) / 60000.0
$waited = ($nowMs - (Snowflake-Ms $pd.MinId)) / 60000.0
if ($quiet -lt $SessizDakika -and $waited -lt $EnFazlaBekleDakika) { exit 0 }

# 3) Sinirlar
if (Test-Path $failFile) {
  $parts = (Get-Content -Raw $failFile).Trim() -split '\|'
  $failAt = ParseUtc $parts[0]
  $wait = 10
  if ($parts.Count -gt 1) { $wait = [int]$parts[1] }
  if (((Get-Date).ToUniversalTime() - $failAt).TotalMinutes -lt $wait) { exit 0 }
}
$recent = 0
if (Test-Path $runsFile) {
  foreach ($ln in [IO.File]::ReadLines($runsFile, $utf8)) {
    if ($ln.Trim() -and (((Get-Date).ToUniversalTime() - (ParseUtc $ln)).TotalHours -lt 1)) { $recent++ }
  }
}
if ($recent -ge $SaatteEn) { LogOnce "saatlik" ("Saatlik analiz siniri (" + $SaatteEn + ") doldu; bekleyen " + $pd.Count) 30; exit 0 }

if ($KuruCalisma) {
  Log ("KURU: analiz baslatilirdi (bekleyen " + $pd.Count + ", son mesajdan " + [int]$quiet + " dk, en eski " + [int]$waited + " dk, bu saatte " + $recent + " analiz)")
  exit 0
}

# 4) Claude CLI: yolu bul (onbellekli) + giris yapilmis mi
$exe = $null
$cache = Join-Path $ham "claude_yolu.txt"
if (Test-Path $cache) {
  $c = (Get-Content -Raw $cache).Trim()
  if ($c -and (Test-Path $c)) { $exe = $c }
}
if (-not $exe) {
  $base = Join-Path $env:LOCALAPPDATA "Claude-Data"
  $cand = Get-ChildItem -Path $base -Recurse -Depth 6 -Filter claude.exe -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -like "*\claude-code\*" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($cand) { $exe = $cand.FullName; [IO.File]::WriteAllText($cache, $exe, $utf8) }
}
if (-not $exe) { LogOnce "cli_yok" "claude.exe bulunamadi (Claude uygulamasi kurulu mu?)" 30; exit 0 }
$ErrorActionPreference = "Continue"
$st = & $exe auth status 2>&1 | ForEach-Object { "$_" }
$ErrorActionPreference = $prevPref
if (($st -join " ") -notmatch '"loggedIn":\s*true') {
  LogOnce "giris_yok" "Claude CLI'da giris yapilmamis (claude auth login); bekleyen mesajlar var" 30
  exit 0
}

# 5) Analizi baslat (modelin yalniz okuma yetkisi var)
[IO.File]::WriteAllText($lockFile, (Get-Date).ToString("o"), $utf8)
[IO.File]::AppendAllText($runsFile, (Get-Date).ToUniversalTime().ToString("o") + "`n", $utf8)
[IO.File]::WriteAllText((Join-Path $ham "bekleyen.jsonl"), (($pd.Lines -join "`n") + "`n"), $utf8)
$env:CLAUDE_CODE_DISABLE_CLAUDE_MDS = "1"
$env:CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1"
$cliArgs = '-p "docs/hata_tespit/izleyici_gorevi.md dosyasini oku ve harfiyen uygula." --permission-mode dontAsk --no-session-persistence --output-format json --allowedTools "Read" "Grep" "Glob"'
$outFile = Join-Path $ham "izleyici_son.txt"
$errFile = Join-Path $ham "izleyici_son_hata.txt"
Log ("Analiz basliyor (bekleyen " + $pd.Count + ", son mesajdan " + [int]$quiet + " dk)")
$problem = $null
$summary = ""
$cost = ""
try {
  $p = Start-Process -FilePath $exe -ArgumentList $cliArgs -WorkingDirectory $root -RedirectStandardOutput $outFile -RedirectStandardError $errFile -WindowStyle Hidden -PassThru
  $null = $p.Handle
  if (-not $p.WaitForExit($ZamanAsimiDakika * 60000)) {
    try { $p.Kill() } catch { }
    $problem = "zaman asimi (" + $ZamanAsimiDakika + " dk)"
  } elseif ($p.ExitCode -ne 0) {
    $problem = "cikis kodu " + $p.ExitCode
  }
  if (-not $problem) {
    $outer = (Get-Content -Raw -Encoding UTF8 $outFile) | ConvertFrom-Json
    $cost = [string]$outer.total_cost_usd
    if ($outer.is_error -eq $true) { throw ("model hatasi: " + [string]$outer.result) }
    $applied = Apply-Result ([string]$outer.result) $pd
    $summary = $applied.Ozet
    if ($summary.Length -gt 300) { $summary = $summary.Substring(0, 300) + "..." }
    $summary = ($summary -replace '\s+', ' ') + " (yanit " + $applied.Yanit + ")"
  }
} catch {
  $problem = "sonuc islenemedi/baslatilamadi: " + $_.Exception.Message
} finally {
  Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}

$after = Get-Pending
if ($problem) {
  $w = Set-Fail 10
  Log ("Analiz SORUNLU: " + $problem + "; kalan bekleyen " + $after.Count + " (" + $w + " dk beklenecek)")
} elseif ($after.Count -gt 0) {
  $w = Set-Fail 30
  Log ("Analiz bitti ama " + $after.Count + " mesaj ISLENMEMIS kaldi; " + $w + " dk beklenecek. Ozet: " + $summary)
} else {
  if (Test-Path $failFile) { Remove-Item $failFile -Force }
  Log ("Analiz tamam, bekleyen 0, maliyet " + $cost + " USD. Ozet: " + $summary)
}
