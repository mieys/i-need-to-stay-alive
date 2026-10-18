# FX ısınma listesini yeniden üretir: scripts/fx_warmup_list.gd (bkz. scripts/fx_warmup.gd).
#   VARSAYILAN: oyun kullanicinin GORMEDIGI ayri bir Windows masaustunde calisir (fps_micro/hidden_launch.ps1; pencere ekrana cikmaz). Gorunur pencere: -Visible -AllowWindow.
#   powershell -ExecutionPolicy Bypass -File tools/gen_fx_warmup_list.ps1 [-Chars "12,14"] [-Weapons "yay,dagger"] [-NoWrite] [-Replace]
# tools/fx_warmup_collect.gd her karakterin Q/E/R yeteneğine ve her silahın ilk ateşine basar; Godot --verbose günlüğünden o anlarda diskten OKUNAN
# kaynaklar ("Loading resource: res://...") listelenir. Yeni yetenek / silah / efekt ekleyince bir kez koş ve çıkan dosyayı commit et.
# Varsayılan: MEVCUT listeyle BİRLEŞTİRİR (rastgele seçimler - örn. Cadı R iksirleri, dünya olayı sesleri - koşular arasında değişir; liste yalnız büyür, kısmi koşu -Chars/-Weapons güvenli).
#   -Replace: sıfırdan yazar (silinen/adı değişen kaynaklar gider; kısmi koşuyla KULLANMA).
# Koşu yalıtılır: APPDATA geçici klasöre çevrilir -> gerçek meta.cfg / records.cfg / kayıtlar bozulmaz. ~10-15 dk sürer (pencere açar).
param(
	[string]$Chars = "",
	[string]$Weapons = "",
	[int]$TimeoutSec = 1800,
	[switch]$NoWrite,
	[switch]$Replace,
	[switch]$Visible,
	[switch]$AllowWindow
)
if ($Visible -and -not $AllowWindow) {
	Write-Host "DURDU: -Visible gercek bir oyun PENCERESI acar ve kullanicinin ekraninda one cikar (kullanici 2026-10-03 ve 2026-10-18'de sikayet etti)."
	Write-Host "Kullanicidan izin alindiysa -Visible -AllowWindow ver; yoksa bayraksiz calistir (gorunmez masaustu)."
	exit 2
}
. "$PSScriptRoot\fps_micro\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..").Path
$tmp = Join-Path $env:TEMP "fx_warmup_collect"
New-Item -ItemType Directory -Force $tmp | Out-Null
$out = Join-Path $tmp "collect_out.txt"
$err = Join-Path $tmp "collect_err.txt"
if ($Chars -ne "") { $env:FXW_CHARS = $Chars } else { Remove-Item env:FXW_CHARS -ErrorAction SilentlyContinue }
if ($Weapons -ne "") { $env:FXW_WEAPONS = $Weapons } else { Remove-Item env:FXW_WEAPONS -ErrorAction SilentlyContinue }
$env:FXW_COLLECT = "1" # scripts/fx_warmup.gd arka plan yuklemesini kapatir (yoksa listedekiler gunlukte gorunmez, liste kuculur)
$savedAppData = $env:APPDATA
$env:APPDATA = Join-Path $tmp "appdata"
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
try {
	if ($Visible) {
		$p = Start-Process -FilePath $godot -ArgumentList @("--path", "`"$proj`"", "--windowed", "--resolution", "1920x1080", "--verbose", "-s", "res://tools/fx_warmup_collect.gd") -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
		if (-not $p.WaitForExit($TimeoutSec * 1000)) { $p.Kill(); Write-Host "ZAMAN ASIMI - kismi cikti kullaniliyor" }
	} else {
		if (Test-Path $out) { Remove-Item $out -Force }
		$argLine = "--path `"$proj`" --windowed --resolution 1920x1080 --verbose --audio-driver Dummy --log-file `"$out`" -s res://tools/fx_warmup_collect.gd"
		$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
		if ($code -eq -2) { Write-Host "ZAMAN ASIMI - kismi cikti kullaniliyor" } elseif ($code -lt 0) { Write-Host "GIZLI MASAUSTU HATASI kod=$code" }
	}
} finally {
	$env:APPDATA = $savedAppData
}
$paths = New-Object System.Collections.Generic.HashSet[string]
$inside = $false
$marks = 0
foreach ($l in (Get-Content $out -Encoding UTF8)) {
	if ($l -match '^FXW MARK ') { $inside = $true; $marks++; continue }
	if ($l -match '^FXW END') { $inside = $false; continue }
	if ($inside -and $l -match '^Loading resource: (res://\S+) remapped') {
		$r = $Matches[1]
		if ($r -notmatch '^res://\.godot/') { [void]$paths.Add($r) }
	}
}
$sorted = @($paths) | Sort-Object
Write-Host ("{0} isaret, {1} kaynak" -f $marks, $sorted.Count)
$partial = ($Chars -ne "" -or $Weapons -ne "")
if ($NoWrite -or $marks -eq 0) { $sorted; return }
if ($Replace -and $partial) { Write-Host "-Replace kismi kosuyla kullanilmaz (listeyi ezer)"; $sorted; return }
$dst = Join-Path $proj "scripts\fx_warmup_list.gd"
if (-not $Replace -and (Test-Path $dst)) {
	$union = New-Object System.Collections.Generic.HashSet[string]
	foreach ($r in $sorted) { [void]$union.Add($r) }
	foreach ($l in (Get-Content $dst -Encoding UTF8)) { if ($l -match '^\s*"(res://[^"]+)",?\s*$') { [void]$union.Add($Matches[1]) } }
	$sorted = @($union) | Sort-Object
	Write-Host ("mevcut listeyle birlestirildi: {0} kaynak" -f $sorted.Count)
}
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("extends RefCounted")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## OTOMATİK ÜRETİLDİ - elle düzenleme. Yenilemek için: powershell -ExecutionPolicy Bypass -File tools/gen_fx_warmup_list.ps1")
[void]$sb.AppendLine("## Karakter yeteneklerinin ve silahların İLK kullanımında diskten okunan kaynaklar (ses örnekleri, doku sayfaları, SpriteFrames, FX sahneleri/betikleri).")
[void]$sb.AppendLine("## scripts/fx_warmup.gd bunları oyun açılırken kare başına kısa bir bütçeyle yükleyip TUTAR; ilk kullanımda ~10-40 ms'lik takılma olmaz.")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("const PATHS: Array[String] = [")
foreach ($r in $sorted) { [void]$sb.AppendLine("`t`"$r`",") }
[void]$sb.AppendLine("]")
[System.IO.File]::WriteAllText($dst, $sb.ToString().Replace("`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "yazildi: $dst"
