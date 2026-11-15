# Potpourri dagitim paketi: dosya denetimi, (istege bagli) imzalama, yerel Defender taramasi, zip + SHA256.
#   powershell -ExecutionPolicy Bypass -File tools/dagitim/paketle.ps1
#   ... -Pfx "C:\yol\sertifika.pfx"      (sifre: $env:IMZA_SIFRE ortam degiskeni)
# Export'u kullanici Godot'tan alir (CLAUDE.md); bu betik export ETMEZ, hazir klasoru paketler.
# Madde 609. Dosya bilerek yalniz ASCII (Windows PowerShell 5.1 BOM'suz dosyada Turkce karakteri bozar).
param(
  [string]$Klasor = "$env:USERPROFILE\Desktop\pc versiyon",
  [string]$Cikti = "",
  [string]$Pfx = "",
  [string]$ZamanDamgasi = "http://timestamp.digicert.com",
  [switch]$TaramaYok,
  [switch]$Uzerine,
  [switch]$KorumasizIzin
)
$ErrorActionPreference = "Stop"
$kok = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

# 1) Oyunun calismasi icin sart olan dosyalar (GDExtension DLL'leri exe icine gomulemez).
$gerekli = @(
  "Potpourri.exe",
  "EOSSDK-Win64-Shipping.dll",
  "libeosg.windows.template_release.x86_64.dll",
  "libenemyworld.windows.template_release.x86_64.dll",
  "xaudio2_9redist.dll"
)
$eksik = @($gerekli | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Klasor $_)) })
if ($eksik.Count -gt 0) {
  Write-Host ("EKSIK DOSYA: " + ($eksik -join ", ")) -ForegroundColor Red
  exit 1
}

# 1b) Kaynak koruma denetimi (madde 613 ek 3): exe'nin gomulu PCK dizini SIFRELI olmali. Sifresiz exe'de oyunun kendi betik yollari duz yazi
#     gorunur (GDRE gibi araclar betikleri tek tikla acar). Korumasiz exe dagitima girmesin: korumali export = "Windows Desktop (Korumali)" ayari.
#     (Desen oyuna ozel olmali: "res://project.binary" Godot'un kendi kodunda da gecer, sifreli exe'de de bulunur - denenmis yanlis desen.)
if (-not $KorumasizIzin) {
  $desen = "res://scripts/game_manager.gd"
  $latin = [System.Text.Encoding]::GetEncoding(28591)
  $acik = $false
  $fs = [System.IO.File]::OpenRead((Join-Path $Klasor "Potpourri.exe"))
  try {
    $tampon = New-Object byte[] (16MB)
    $kuyruk = ""
    while (($n = $fs.Read($tampon, 0, $tampon.Length)) -gt 0) {
      $s = $kuyruk + $latin.GetString($tampon, 0, $n)
      if ($s.Contains($desen)) { $acik = $true; break }
      $kuyruk = $s.Substring([math]::Max(0, $s.Length - $desen.Length))
    }
  } finally { $fs.Dispose() }
  if ($acik) {
    Write-Host "KORUMASIZ EXE: Potpourri.exe icindeki PCK sifreli degil (kaynak kod acik)." -ForegroundColor Red
    Write-Host "Godot > Proje > Disa Aktar > 'Windows Desktop (Korumali)' ile yeniden export alin (tools/godot_sablon/OKU-BENI.md)." -ForegroundColor Yellow
    Write-Host "Bilerek korumasiz paketlemek icin: -KorumasizIzin" -ForegroundColor DarkGray
    exit 4
  }
  Write-Host "Kaynak koruma: PCK sifreli (res:// dizini okunamiyor)" -ForegroundColor Green
}

# 2) Artik dosyalar (~RF....TMP gibi Windows/Defender kalintilari) pakete girmez.
$hepsi = @(Get-ChildItem -LiteralPath $Klasor -File)
$atlanan = @($hepsi | Where-Object { $_.Name -match '^~RF|\.tmp$' })
$dosyalar = @($hepsi | Where-Object { $_.Name -notmatch '^~RF|\.tmp$' })
foreach ($a in $atlanan) { Write-Host ("atlandi (kalinti): " + $a.Name) -ForegroundColor DarkGray }
$ikili = @($dosyalar | Where-Object { $_.Extension -in ".exe", ".dll" })

# 3) Istege bagli imzalama (yalniz zaten gecerli imzasi olmayanlar).
if ($Pfx) {
  $st = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe" -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | Select-Object -First 1
  if (-not $st) { throw "signtool.exe bulunamadi (Windows SDK kurulu olmali)." }
  if (-not $env:IMZA_SIFRE) { throw "IMZA_SIFRE ortam degiskeni bos." }
  foreach ($d in $ikili) {
    if ((Get-AuthenticodeSignature -LiteralPath $d.FullName).Status -eq "Valid") { continue }
    & $st.FullName sign /f $Pfx /p $env:IMZA_SIFRE /fd SHA256 /tr $ZamanDamgasi /td SHA256 /d "Potpourri" $d.FullName
    if ($LASTEXITCODE -ne 0) { throw ("imzalama basarisiz: " + $d.Name) }
    Write-Host ("imzalandi: " + $d.Name) -ForegroundColor Green
  }
}
foreach ($d in $ikili) {
  $durum = (Get-AuthenticodeSignature -LiteralPath $d.FullName).Status
  Write-Host ("imza  {0,-52} {1}" -f $d.Name, $durum)
}

# 4) Yerel Defender taramasi (bulut/yukleme YOK, karantina YOK): bu makinede temiz mi?
if (-not $TaramaYok) {
  $mp = Get-ChildItem "$env:ProgramData\Microsoft\Windows Defender\Platform\*\MpCmdRun.exe" -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | Select-Object -First 1
  if (-not $mp) { $mp = Get-Item "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -ErrorAction SilentlyContinue }
  if ($mp) {
    $bulunan = @()
    foreach ($d in $ikili) {
      & $mp.FullName -Scan -ScanType 3 -File $d.FullName -DisableRemediation | Out-Null
      if ($LASTEXITCODE -ne 0) { $bulunan += $d.Name }
    }
    if ($bulunan.Count -gt 0) {
      Write-Host ("DEFENDER ISARETLEDI: " + ($bulunan -join ", ")) -ForegroundColor Red
      Write-Host "Yanlis pozitifse: https://www.microsoft.com/en-us/wdsi/filesubmission" -ForegroundColor Yellow
      exit 2
    }
    Write-Host "Defender (yerel): tehdit yok" -ForegroundColor Green
  } else {
    Write-Host "Defender CLI bulunamadi, tarama atlandi" -ForegroundColor Yellow
  }
}

# 5) Zip: icinde tek "Potpourri" klasoru (kullanici indirilenler klasorune dagitmasin) + kurulum notu.
$surum = "x"
$m = Select-String -LiteralPath (Join-Path $kok "export_presets.cfg") -Pattern 'application/file_version="([^"]*)"' | Select-Object -First 1
if ($m) { $surum = $m.Matches[0].Groups[1].Value }
if (-not $Cikti) { $Cikti = Join-Path (Split-Path $Klasor -Parent) ("Potpourri_" + $surum + ".zip") }
if ((Test-Path -LiteralPath $Cikti) -and -not $Uzerine) {
  Write-Host ("Zaten var: " + $Cikti + "  (uzerine yazmak icin -Uzerine)") -ForegroundColor Red
  exit 3
}
if (Test-Path -LiteralPath $Cikti) { Remove-Item -LiteralPath $Cikti }

$notu = @"
POTPOURRI - KURULUM NOTU

1) Zip'i bir klasore TAMAMEN cikarin. Tum dosyalar (Potpourri.exe ve yanindaki
   .dll dosyalari) ayni klasorde kalmali; yoksa oyun acilmaz veya cok oyunculuda kapanir.

2) Windows "bilgisayarinizi korudu" (SmartScreen) uyarisi gosterirse:
   "Ek bilgi" -> "Yine de calistir".
   Oyun henuz dijital olarak imzali olmadigi icin Windows bu uyariyi gosterebilir.

3) Uyari hic cikmasin isterseniz: indirdiginiz zip'e sag tik -> Ozellikler ->
   "Engellemeyi kaldir" -> Uygula, SONRA zip'i cikarin.
"@
$notu = $notu -replace "`r?`n", "`r`n"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($Cikti, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  foreach ($d in $dosyalar) {
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $d.FullName, ("Potpourri/" + $d.Name), [System.IO.Compression.CompressionLevel]::Optimal)
  }
  $e = $zip.CreateEntry("Potpourri/OKU-BENI.txt")
  $w = New-Object System.IO.StreamWriter($e.Open(), (New-Object System.Text.UTF8Encoding($true)))
  $w.Write($notu)
  $w.Close()
} finally {
  $zip.Dispose()
}

$boyut = [math]::Round((Get-Item -LiteralPath $Cikti).Length / 1MB, 1)
$hash = (Get-FileHash -LiteralPath $Cikti -Algorithm SHA256).Hash
Write-Host ""
Write-Host ("HAZIR: " + $Cikti + "  (" + $boyut + " MB, " + $dosyalar.Count + " dosya)") -ForegroundColor Green
Write-Host ("SHA256: " + $hash)
Write-Host "Not: her export yeni hash = Windows itibari sifirlanir; kucuk duzeltmeleri toplayip seyrek surum cikarin."
