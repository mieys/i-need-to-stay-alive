# BALANS RAPORU (2026-10-11): oyunun yazdigi koşu kayitlarini (balance_log.gd -> kosular.jsonl) okuyup docs/balans/rapor.md uretir.
#   powershell -ExecutionPolicy Bypass -File tools/balans_rapor.ps1 [-Girdi <klasor>,...] [-Rev N] [-MinKosu 3] [-MinSure 60]
# Okunan yerler: %APPDATA%\Godot\app_userdata\Temiz Sürüm\balans\*.jsonl (kendi + host'ta toplanan arkadas kayitlari),
#   docs\balans\gelen\*.jsonl (arkadasin elle yolladigi dosyalar) ve -Girdi ile verilenler. Ayni run_id bir kez sayilir.
# Varsayilan: yalnizca EN SON BALANCE_REV (balance_log.gd) - eski denge verisi yeni dengeyi yaniltmasin. -Rev ile baska revizyon.
param(
	[string[]]$Girdi = @(),
	[int]$Rev = -1,
	[int]$MinKosu = 3,
	[double]$MinSure = 60,
	[string]$Out = ""
)
$ErrorActionPreference = "Stop"
$proj = (Resolve-Path "$PSScriptRoot\..").Path
if ($Out -eq "") { $Out = Join-Path $proj "docs\balans\rapor.md" }
$gelen = Join-Path $proj "docs\balans\gelen"
New-Item -ItemType Directory -Force $gelen | Out-Null
$dirs = @((Join-Path $env:APPDATA "Godot\app_userdata\Temiz Sürüm\balans"), $gelen) + $Girdi

$all = New-Object System.Collections.ArrayList
$seen = @{}
$files = 0
foreach ($d in $dirs) {
	if (-not (Test-Path $d)) { continue }
	foreach ($f in (Get-ChildItem $d -Filter *.jsonl -File)) {
		$files++
		foreach ($line in (Get-Content $f.FullName -Encoding UTF8)) {
			if ($line.Trim() -eq "") { continue }
			try { $r = $line | ConvertFrom-Json } catch { continue }
			if (-not $r.run_id -or $seen.ContainsKey($r.run_id)) { continue }
			$seen[$r.run_id] = 1
			[void]$all.Add($r)
		}
	}
}
if ($all.Count -eq 0) { Write-Host "Hic koşu kaydi yok. Once oyunu oyna (koşu >= 30 sn) ya da arkadasinin kosular.jsonl dosyasini $gelen klasorune koy."; exit 0 }

$maxRev = ($all | Measure-Object -Property rev -Maximum).Maximum
if ($Rev -lt 0) { $Rev = [int]$maxRev }
$runs = @($all | Where-Object { [int]$_.rev -eq $Rev -and [double]$_.time -ge $MinSure })
$other = $all.Count - $runs.Count
$o = New-Object System.Collections.Generic.List[string]
function P([string]$s) { $o.Add($s) }
function Med($xs) { $a = @($xs | Sort-Object); if ($a.Count -eq 0) { return 0.0 }; $m = [int][math]::Floor($a.Count / 2); if ($a.Count % 2) { return [double]$a[$m] } else { return ([double]$a[$m - 1] + [double]$a[$m]) / 2 } }
function Avg($xs) { $a = @($xs); if ($a.Count -eq 0) { return 0.0 }; return ($a | Measure-Object -Average).Average }
function F1($x) { return ([double]$x).ToString("0.0", [Globalization.CultureInfo]::InvariantCulture) }
function F2($x) { return ([double]$x).ToString("0.00", [Globalization.CultureInfo]::InvariantCulture) }
function Props($obj) { if ($null -eq $obj) { return @() } else { return @($obj.PSObject.Properties) } }

if ($runs.Count -eq 0) { Write-Host "Revizyon $Rev icin $MinSure sn'den uzun koşu yok (toplam kayit: $($all.Count))."; exit 0 }

P "# Balans raporu"
P ""
P ("Uretildi: {0} | Revizyon: {1} | Analiz edilen koşu: {2} (baska revizyon/kisa koşu: {3}) | Oyuncu: {4} | Dosya: {5}" -f (Get-Date -Format "yyyy-MM-dd HH:mm"), $Rev, $runs.Count, $other, (@($runs | ForEach-Object { $_.player } | Sort-Object -Unique).Count), $files)
P ""
P "> Kucuk orneklem uyarisi: **az veri** isaretli satirlar $MinKosu koşudan azdir, yorumlama. Silah hasari yalniz etiketli kaynaklari (silahlar) kapsar; yetenek hasari "s:" kaynaklari (asagida "Yetenek hasari"), efsun/etiketsiz hasar **diger** altindadir."
P ""

# ---- Karakterler ----
$flags = New-Object System.Collections.Generic.List[string]
$overallTier = Avg ($runs | ForEach-Object { [double]$_.tier })
$charRows = @()
foreach ($g in ($runs | Group-Object char_name)) {
	$rs = @($g.Group)
	$dps = Avg ($rs | ForEach-Object { [double]$_.dealt / [math]::Max(1.0, [double]$_.time) })
	$charRows += [pscustomobject]@{
		Ad = $g.Name; N = $rs.Count
		Tier = Avg ($rs | ForEach-Object { [double]$_.tier }); MaxTier = ($rs | Measure-Object -Property tier -Maximum).Maximum
		Sure = Avg ($rs | ForEach-Object { [double]$_.time }); Kill = Avg ($rs | ForEach-Object { [double]$_.kills })
		Dps = $dps; Taken = Avg ($rs | ForEach-Object { [double]$_.taken / [math]::Max(1.0, [double]$_.time) })
		Zafer = @($rs | Where-Object { $_.victory }).Count
	}
}
$medDps = Med ($charRows | Where-Object { $_.N -ge $MinKosu } | ForEach-Object { $_.Dps })
P "## Karakterler"
P ""
P "| Karakter | Koşu | Ort. kademe | En yuksek | Ort. sure (dk) | Ort. kill | Hasar/sn | Alinan/sn | Zafer | Not |"
P "|---|---|---|---|---|---|---|---|---|---|"
foreach ($c in ($charRows | Sort-Object Tier -Descending)) {
	$note = ""
	if ($c.N -lt $MinKosu) { $note = "az veri" }
	else {
		$ratio = if ($medDps -gt 0) { $c.Dps / $medDps } else { 1 }
		if ($ratio -ge 1.5) { $note = "HASARI YUKSEK (x$(F2 $ratio) medyan)"; $flags.Add("Karakter **$($c.Ad)**: hasar/sn medyanin x$(F2 $ratio) kati.") }
		elseif ($ratio -le 0.6) { $note = "hasari dusuk (x$(F2 $ratio))"; $flags.Add("Karakter **$($c.Ad)**: hasar/sn medyanin x$(F2 $ratio) kati (zayif olabilir).") }
		if ($c.Tier - $overallTier -ge 1.5) { $note += " ILERLEME YUKSEK"; $flags.Add("Karakter **$($c.Ad)**: ortalama kademe $(F1 $c.Tier) (genel $(F1 $overallTier)).") }
		elseif ($overallTier - $c.Tier -ge 1.5) { $note += " ilerleme dusuk"; $flags.Add("Karakter **$($c.Ad)**: ortalama kademe $(F1 $c.Tier) (genel $(F1 $overallTier)) - zayif olabilir.") }
	}
	P ("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} |" -f $c.Ad, $c.N, (F1 $c.Tier), $c.MaxTier, (F1 ($c.Sure / 60)), (F1 $c.Kill), (F1 $c.Dps), (F1 $c.Taken), $c.Zafer, $note.Trim())
}
P ""

# ---- Silahlar ----
$wAgg = @{}
foreach ($r in $runs) {
	$time = [math]::Max(1.0, [double]$r.time)
	$first = $true
	foreach ($w in @($r.weapons)) {
		$k = [string]$w.k
		if ($k -eq "") { continue }
		if (-not $wAgg.ContainsKey($k)) { $wAgg[$k] = [pscustomobject]@{ K = $k; N = 0; Dmg = 0.0; Time = 0.0; Hits = 0; Crits = 0; Start = 0; StartTier = 0.0 } }
		$a = $wAgg[$k]
		$row = $null
		foreach ($p in (Props $r.by_src)) { if ($p.Name -eq "w:$k") { $row = $p.Value } }
		$a.N++; $a.Time += $time
		if ($row) { $a.Dmg += [double]$row[0]; $a.Hits += [int]$row[1]; $a.Crits += [int]$row[2] }
		if ($first) { $a.Start++; $a.StartTier += [double]$r.tier; $first = $false }
	}
}
$wRows = @($wAgg.Values | ForEach-Object { $_ | Add-Member -PassThru -NotePropertyName Dps -NotePropertyValue ($_.Dmg / $_.Time) })
$medW = Med ($wRows | Where-Object { $_.N -ge $MinKosu } | ForEach-Object { $_.Dps })
P "## Silahlar"
P ""
P "Hasar/sn = silahin o koşularda verdigi etiketli hasar / koşu suresi. **Onyargi:** silahin ne zaman alindigi kayitli degil, sahip olunan tum sure sayilir (gec alinan silah olduğundan dusuk gorunur). Esik yalniz yon gosterir."
P ""
P "| Silah | Koşu | Hasar/sn | Medyana oran | Kritik % | Baslangic silahi iken ort. kademe | Not |"
P "|---|---|---|---|---|---|---|"
foreach ($w in ($wRows | Sort-Object Dps -Descending)) {
	$ratio = if ($medW -gt 0) { $w.Dps / $medW } else { 1 }
	$crit = if ($w.Hits -gt 0) { 100.0 * $w.Crits / $w.Hits } else { 0 }
	$st = if ($w.Start -gt 0) { F1 ($w.StartTier / $w.Start) } else { "-" }
	$note = ""
	if ($w.N -lt $MinKosu) { $note = "az veri" }
	elseif ($ratio -ge 1.6) { $note = "COK GUCLU?"; $flags.Add("Silah **$($w.K)**: hasar/sn medyanin x$(F2 $ratio) kati.") }
	elseif ($ratio -le 0.5) { $note = "zayif?"; $flags.Add("Silah **$($w.K)**: hasar/sn medyanin x$(F2 $ratio) kati (zayif olabilir).") }
	P ("| {0} | {1} | {2} | x{3} | {4} | {5} | {6} |" -f $w.K, $w.N, (F1 $w.Dps), (F2 $ratio), (F1 $crit), $st, $note)
}
P ""

# ---- Yetenekler (s:<karakter>_<yetenek> / s:evo_<evrim alani>) ----
$sAgg = @{}
foreach ($r in $runs) {
	$time = [math]::Max(1.0, [double]$r.time)
	foreach ($p in (Props $r.by_src)) {
		if (-not $p.Name.StartsWith("s:")) { continue }
		$key = $r.char_name + "|" + $p.Name.Substring(2)
		if (-not $sAgg.ContainsKey($key)) { $sAgg[$key] = [pscustomobject]@{ Char = [string]$r.char_name; Ad = $p.Name.Substring(2); N = 0; Dmg = 0.0; Time = 0.0; Hits = 0; Crits = 0; Dealt = 0.0 } }
		$a = $sAgg[$key]
		$a.N++; $a.Time += $time; $a.Dmg += [double]$p.Value[0]; $a.Hits += [int]$p.Value[1]; $a.Crits += [int]$p.Value[2]; $a.Dealt += [double]$r.dealt
	}
}
P "## Yetenek hasari"
P ""
P "Q/E/R, pasifler, evrimler, evcil hayvan/totem/golem hasari. Kaynak adi = s:<karakter>_<yetenek> (evrim alanlari s:evo_<alan>). **Pay %** = o yetenegin, onu kullanan koşulardaki toplam hasarin payi."
P ""
P "| Karakter | Yetenek | Koşu | Hasar/sn | Pay % | Vurus | Kritik % |"
P "|---|---|---|---|---|---|---|"
foreach ($a in ($sAgg.Values | Sort-Object Char, { -$_.Dmg })) {
	$share = if ($a.Dealt -gt 0) { 100.0 * $a.Dmg / $a.Dealt } else { 0 }
	$crit = if ($a.Hits -gt 0) { 100.0 * $a.Crits / $a.Hits } else { 0 }
	P ("| {0} | {1} | {2} | {3} | {4} | {5} | {6} |" -f $a.Char, $a.Ad, $a.N, (F1 ($a.Dmg / $a.Time)), (F1 $share), $a.Hits, (F1 $crit))
	if ($a.N -ge $MinKosu -and $share -ge 60) { $flags.Add("Yetenek **$($a.Char)/$($a.Ad)**: karakterin hasarinin %$(F1 $share)'i tek yetenekten.") }
}
if ($sAgg.Count -eq 0) { P "(Henuz yetenek etiketli kayit yok - yeni surumle oynanan koşular gerekir.)" }
P ""

# ---- Hasar kaynaklari / kapsama ----
$srcTotal = @{}
foreach ($r in $runs) { foreach ($p in (Props $r.by_src)) { if (-not $srcTotal.ContainsKey($p.Name)) { $srcTotal[$p.Name] = 0.0 }; $srcTotal[$p.Name] += [double]$p.Value[0] } }
$sumAll = ($srcTotal.Values | Measure-Object -Sum).Sum
P "## Hasar kaynaklari (tum koşular)"
P ""
P "| Kaynak | Toplam hasar | Pay % |"
P "|---|---|---|"
foreach ($k in ($srcTotal.Keys | Sort-Object { -$srcTotal[$_] } | Select-Object -First 15)) { P ("| {0} | {1} | {2} |" -f $k, (F1 $srcTotal[$k]), (F1 (100.0 * $srcTotal[$k] / [math]::Max(1.0, $sumAll)))) }
$dig = if ($srcTotal.ContainsKey("diger")) { 100.0 * $srcTotal["diger"] / [math]::Max(1.0, $sumAll) } else { 0 }
P ""
P ("Etiketsiz (**diger**) hasar payi: %{0}. Yetenekler artik s: etiketli; kalan diger = efsun/etiketsiz kaynak (yuksekse yeni bir take_damage cagrisini etiketle)." -f (F1 $dig))
P ""

# ---- Kademe duvari ve olum sebebi ----
$dead = @($runs | Where-Object { $_.dead })
P "## Ölüm kademeleri ve sebepleri"
P ""
P ("Ölen koşu: {0} / {1}. (Menuden cikilan koşular 'ölmedi' sayilir.)" -f $dead.Count, $runs.Count)
P ""
P "| Kademe | Ölüm | Pay % | En sık öldüren |"
P "|---|---|---|---|"
foreach ($g in ($dead | Group-Object tier | Sort-Object { [int]$_.Name })) {
	$top = ($g.Group | Group-Object killer | Sort-Object Count -Descending | Select-Object -First 2 | ForEach-Object { "$($_.Name) ($($_.Count))" }) -join ", "
	P ("| {0} | {1} | {2} | {3} |" -f $g.Name, $g.Count, (F1 (100.0 * $g.Count / [math]::Max(1, $dead.Count))), $top)
	if ($dead.Count -ge 5 -and $g.Count / $dead.Count -ge 0.35) { $flags.Add("Kademe **$($g.Name)**: ölümlerin %$(F1 (100.0 * $g.Count / $dead.Count))'i burada (duvar olabilir).") }
}
P ""
$takenAgg = @{}
foreach ($r in $runs) { foreach ($p in (Props $r.taken_by)) { if (-not $takenAgg.ContainsKey($p.Name)) { $takenAgg[$p.Name] = 0.0 }; $takenAgg[$p.Name] += [double]$p.Value } }
$takenSum = ($takenAgg.Values | Measure-Object -Sum).Sum
P "### Alinan hasarin kaynagi (yaratik ailesi)"
P ""
P "| Yaratık | Alınan hasar | Pay % |"
P "|---|---|---|"
foreach ($k in ($takenAgg.Keys | Sort-Object { -$takenAgg[$_] } | Select-Object -First 12)) { P ("| {0} | {1} | {2} |" -f $k, (F1 $takenAgg[$k]), (F1 (100.0 * $takenAgg[$k] / [math]::Max(1.0, $takenSum)))) }
P ""

# ---- Esyalar ----
$itemAgg = @{}
foreach ($r in $runs) { foreach ($it in (@($r.items) | Sort-Object -Unique)) { if ($it) { if (-not $itemAgg.ContainsKey($it)) { $itemAgg[$it] = New-Object System.Collections.ArrayList }; [void]$itemAgg[$it].Add([double]$r.tier) } } }
P "## Eşyalar (sahip olunan koşu vs olmayan ortalama kademe)"
P ""
P "| Eşya | Koşu | Ort. kademe (sahip) | Ort. kademe (olmayan) | Fark |"
P "|---|---|---|---|---|"
$iRows = @()
foreach ($k in $itemAgg.Keys) {
	$n = $itemAgg[$k].Count
	if ($n -lt $MinKosu -or ($runs.Count - $n) -lt $MinKosu) { continue }
	$with = Avg $itemAgg[$k]
	$sumWith = ($itemAgg[$k] | Measure-Object -Sum).Sum
	$without = (($runs | ForEach-Object { [double]$_.tier } | Measure-Object -Sum).Sum - $sumWith) / ($runs.Count - $n)
	$iRows += [pscustomobject]@{ K = $k; N = $n; With = $with; Without = $without; D = $with - $without }
}
foreach ($i in ($iRows | Sort-Object D -Descending)) { P ("| {0} | {1} | {2} | {3} | {4} |" -f $i.K, $i.N, (F1 $i.With), (F1 $i.Without), (F2 $i.D)) }
if ($iRows.Count -eq 0) { P "| (yeterli veri yok) | | | | |" }
P ""
P "> Esya 'sebep' degil 'iyi koşunun gostergesi' de olabilir (iyi koşular daha cok esya alir) - fark buyukse yine de bakmaya deger."
P ""

# ---- Olum zamani, kalkan, evcil hayvan, edinme zamani (rev 15+ kayitlari; eski kayitlarda alanlar yok) ----
$withDeath = @($runs | Where-Object { $null -ne $_.death_t -and [double]$_.death_t -ge 0 })
P "## Ölüm zamanı (kalıcı ölümün koşu dakikası)"
P ""
if ($withDeath.Count -eq 0) { P "(Bu revizyonda ölüm zamanı kayıtlı koşu yok.)" } else {
	P "| Karakter | Koşu | Ort. ölüm (dk) | Ort. ölüm kademesi | Ort. yere düşüş |"
	P "|---|---|---|---|---|"
	foreach ($g in ($withDeath | Group-Object char_name | Sort-Object Name)) {
		$dt = $g.Group | ForEach-Object { [double]$_.death_t / 60.0 }
		$dk = $g.Group | ForEach-Object { [double]$_.death_tier }
		$dn = $g.Group | ForEach-Object { @($_.downs).Count }
		P ("| {0} | {1} | {2} | {3} | {4} |" -f $g.Name, $g.Count, (F1 (Avg $dt)), (F1 (Avg $dk)), (F1 (Avg $dn)))
	}
	## Takım içi sıra: aynı zamanda biten koşularda ilk düşenden son düşene kaç sn geçti (çöküş hızı).
	$byTeam = $withDeath | Where-Object { $_.team -gt 1 } | Group-Object { [math]::Round([double]$_.time) }
	foreach ($tg in ($byTeam | Where-Object { $_.Count -ge 2 })) {
		$ts = @($tg.Group | ForEach-Object { [double]$_.death_t } | Sort-Object)
		P ""
		P ("Takım ({0} kişi, koşu {1} dk): ilk ölüm {2} dk, son ölüm {3} dk -> çöküş {4} sn." -f $tg.Count, (F1 ([double]$tg.Name / 60.0)), (F1 ($ts[0] / 60.0)), (F1 ($ts[-1] / 60.0)), (F1 ($ts[-1] - $ts[0])))
	}
}
P ""
$withShield = @($runs | Where-Object { $_.shield })
P "## Kalkan türü"
P ""
if ($withShield.Count -eq 0) { P "(Kalkan türü kayıtlı koşu yok.)" } else {
	P "| Kalkan | Koşu | Ort. kademe | Ort. alınan/sn | Ort. geliştirme |"
	P "|---|---|---|---|---|"
	foreach ($g in ($withShield | Group-Object shield | Sort-Object Name)) {
		$tk = $g.Group | ForEach-Object { [double]$_.taken / [math]::Max(1.0, [double]$_.time) }
		$up = $g.Group | ForEach-Object { (@($_.shield_ups) | Measure-Object -Sum).Sum }
		P ("| {0} | {1} | {2} | {3} | {4} |" -f $g.Name, $g.Count, (F1 (Avg ($g.Group | ForEach-Object { [double]$_.tier }))), (F1 (Avg $tk)), (F1 (Avg $up)))
	}
}
P ""
$withPet = @($runs | Where-Object { $null -ne $_.pet })
P "## Evcil hayvan"
P ""
if ($withPet.Count -eq 0) { P "(Evcil hayvan kayıtlı koşu yok.)" } else {
	P "| Evcil | Koşu | Ort. kademe | Ort. hasar/sn |"
	P "|---|---|---|---|"
	foreach ($g in ($withPet | Group-Object { if ($_.pet) { $_.pet } else { "(yok)" } } | Sort-Object Name)) {
		P ("| {0} | {1} | {2} | {3} |" -f $g.Name, $g.Count, (F1 (Avg ($g.Group | ForEach-Object { [double]$_.tier }))), (F1 (Avg ($g.Group | ForEach-Object { [double]$_.dealt / [math]::Max(1.0, [double]$_.time) }))))
	}
}
P ""
$gotW = @{}
foreach ($r in $runs) { foreach ($e in @($r.got_weapons)) { if ($e -and $e.Count -ge 2) { $k = [string]$e[0]; if (-not $gotW.ContainsKey($k)) { $gotW[$k] = New-Object System.Collections.ArrayList }; [void]$gotW[$k].Add([double]$e[1] / 60.0) } } }
P "## Silah edinme zamanı"
P ""
if ($gotW.Count -eq 0) { P "(Edinme zamanı kayıtlı koşu yok.)" } else {
	P "Çözünürlük ~5 sn. Edinme sayısı = kaç kopya alındığı (aynı silahı birden çok almak dahil)."
	P ""
	P "| Silah | Edinilen | Ort. edinme (dk) | En erken (dk) |"
	P "|---|---|---|---|"
	foreach ($k in ($gotW.Keys | Sort-Object)) { P ("| {0} | {1} | {2} | {3} |" -f $k, $gotW[$k].Count, (F1 (Avg $gotW[$k])), (F1 (($gotW[$k] | Measure-Object -Minimum).Minimum))) }
}
P ""

# ---- Altin ve asist (rev 45+ kayitlari: gold_kill / gold_assist / sup_sent; eski kayitlarda alanlar yok) ----
$gRuns = @($runs | Where-Object { $null -ne $_.gold_kill })
P "## Altın ve asist"
P ""
if ($gRuns.Count -eq 0) { P "(Altın/asist kaydı olan koşu yok.)" } else {
	P "Altın = yaratık öldürme altını (yere düşmez, anında verilir). Asist = çok oyunculuda öldürmeden önceki 8 sn içinde hasar/destek verip aldığın pay (hasar / destek / ikisi). Destek gönderilen = arkadaşa can/kalkan/buff bildirimi sayısı."
	P ""
	P "| Karakter | Koşu (takım>1) | Ort. kill altını | Ort. asist sayısı | Ort. asist altını | Asist payı % | Hasar/Destek/İkisi (adet) | Destek gönderilen/dk |"
	P "|---|---|---|---|---|---|---|---|"
	foreach ($g in ($gRuns | Group-Object char_name | Sort-Object Name)) {
		$rs = @($g.Group)
		$mp = @($rs | Where-Object { [int]$_.team -gt 1 })
		$killG = Avg ($rs | ForEach-Object { [double]$_.gold_kill[1] })
		$aN = 0.0; $aG = 0.0; $nd = 0; $ns = 0; $nb = 0
		foreach ($r in $mp) {
			foreach ($p in (Props $r.gold_assist)) {
				$aN += [double]$p.Value[0]; $aG += [double]$p.Value[1]
				if ($p.Name -eq "dmg") { $nd += [int]$p.Value[0] } elseif ($p.Name -eq "sup") { $ns += [int]$p.Value[0] } else { $nb += [int]$p.Value[0] }
			}
		}
		$n = [math]::Max(1, $mp.Count)
		$mpKill = if ($mp.Count -gt 0) { Avg ($mp | ForEach-Object { [double]$_.gold_kill[1] }) } else { 0.0 }
		$share = if ($mp.Count -gt 0 -and ($aG / $n + $mpKill) -gt 0) { 100.0 * ($aG / $n) / ($aG / $n + $mpKill) } else { 0.0 }
		$supRate = if ($mp.Count -gt 0) { Avg ($mp | ForEach-Object { [double]$_.sup_sent / [math]::Max(1.0, [double]$_.time / 60.0) }) } else { 0.0 }
		P ("| {0} | {1} ({2}) | {3} | {4} | {5} | {6} | {7}/{8}/{9} | {10} |" -f $g.Name, $rs.Count, $mp.Count, (F1 $killG), (F1 ($aN / $n)), (F1 ($aG / $n)), (F1 $share), $nd, $ns, $nb, (F1 $supRate))
	}
}
P ""

# ---- Ozet uyarilar ----
$head = New-Object System.Collections.Generic.List[string]
$head.Add("## Öne çıkanlar")
$head.Add("")
if ($flags.Count -eq 0) { $head.Add("- Esik asan bir sey yok (ya da veri az).") } else { foreach ($f in $flags) { $head.Add("- $f") } }
$head.Add("")
$idx = 4
$o.InsertRange($idx, $head)

New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
$o | Out-File -FilePath $Out -Encoding utf8
Write-Host "Rapor yazildi: $Out ($($runs.Count) koşu, $($flags.Count) uyari)"
