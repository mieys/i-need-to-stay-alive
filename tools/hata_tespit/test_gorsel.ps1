<#
  gorsel_kaydet.ps1 testi (Discord'a yazmaz; yalniz -Ag ile Discord CDN'den bir genel gorsel indirir).
    powershell -ExecutionPolicy Bypass -File tools/hata_tespit/test_gorsel.ps1 [-Ag]
  Not: dosya bilerek sadece ASCII (Windows PowerShell 5.1).
#>
param([switch]$Ag)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "gorsel_kaydet.ps1")

$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("gorsel_test_" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null
$imgDir = Join-Path $tmpRoot "ekler"
$fail = 0
function Check([bool]$ok, [string]$name) {
  if ($ok) { Write-Output ("TAMAM  " + $name) } else { Write-Output ("HATA   " + $name); $script:fail++ }
}

# 1x1 PNG, gercek JPEG basligi, WebP basligi (yalniz imza testi icin yeterli bayt)
$png = [Convert]::FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")
$jpg = [byte[]](0xFF, 0xD8, 0xFF, 0xE0, 0, 16, 0x4A, 0x46, 0x49, 0x46, 0, 1, 1, 0)
$webp = [Text.Encoding]::ASCII.GetBytes("RIFF....WEBPVP8 ....")
$html = [Text.Encoding]::ASCII.GetBytes("<html><script>alert(1)</script></html>")

function New-Dl([byte[]]$bytes) {
  $b = $bytes
  return { param($u, $dest) [IO.File]::WriteAllBytes($dest, $b) }.GetNewClosure()
}
function New-Att([string]$url, [string]$ct, [int64]$size, [string]$fn = "ekran.png") {
  return [pscustomobject]@{ url = $url; content_type = $ct; size = $size; filename = $fn }
}
$cdn = "https://cdn.discordapp.com/attachments/1/2/ekran.png?ex=1"

# Imza + adres kurallari
Check ((Get-ImageKind $png) -eq "png") "PNG imzasi taninir"
Check ((Get-ImageKind $jpg) -eq "jpg") "JPEG imzasi taninir"
Check ((Get-ImageKind $webp) -eq "webp") "WebP imzasi taninir"
Check ((Get-ImageKind $html) -eq "") "HTML gorsel sayilmaz"
Check ((Get-ImageKind ([byte[]](1, 2, 3))) -eq "") "kisa/bozuk veri gorsel sayilmaz"
Check (Test-DiscordImageUrl $cdn) "cdn.discordapp.com kabul"
Check (Test-DiscordImageUrl "https://media.discordapp.net/attachments/1/2/a.png") "media.discordapp.net kabul"
Check (-not (Test-DiscordImageUrl "https://example.com/a.png")) "baska site reddedilir"
Check (-not (Test-DiscordImageUrl "https://cdn.discordapp.com.evil.com/a.png")) "ad taklidi (.com.evil.com) reddedilir"
Check (-not (Test-DiscordImageUrl "https://cdn.discordapp.com@evil.com/a.png")) "@ tuzagi reddedilir"
Check (-not (Test-DiscordImageUrl "http://cdn.discordapp.com/a.png")) "http (sifresiz) reddedilir"
Check (-not (Test-DiscordImageUrl "file:///C:/Windows/win.ini")) "file:// reddedilir"

# Indirme akisi (sahte indirici)
$m1 = [pscustomobject]@{ id = "1568200000000000001"; attachments = @((New-Att $cdn "image/png" 1000)) }
$r = @(Save-MessageImages $m1 $imgDir (New-Dl $png))
Check ($r.Count -eq 1 -and $r[0] -eq "ekler/1568200000000000001_1.png" -and (Test-Path (Join-Path $imgDir "1568200000000000001_1.png"))) "PNG kaydedilir, yol ekler/<id>_1.png"

$m2 = [pscustomobject]@{ id = "1568200000000000002"; attachments = @((New-Att "https://example.com/a.png" "image/png" 1000)) }
Check (@(Save-MessageImages $m2 $imgDir (New-Dl $png)).Count -eq 0) "Discord disi adres indirilmez"

$m3 = [pscustomobject]@{ id = "1568200000000000003"; attachments = @((New-Att $cdn "text/plain" 1000 "not.txt")) }
Check (@(Save-MessageImages $m3 $imgDir (New-Dl $png)).Count -eq 0) "gorsel olmayan tur indirilmez"

$m4 = [pscustomobject]@{ id = "1568200000000000004"; attachments = @((New-Att $cdn "image/png" 6000000)) }
Check (@(Save-MessageImages $m4 $imgDir (New-Dl $png)).Count -eq 0) "5 MB ustu indirilmez"

$m5 = [pscustomobject]@{ id = "1568200000000000005"; attachments = @((New-Att $cdn "image/png" 1000)) }
$r5 = @(Save-MessageImages $m5 $imgDir (New-Dl $html) 6>$null)
Check ($r5.Count -eq 0) "png diye gelen HTML reddedilir (imza)"
Check (@(Get-ChildItem $imgDir -Filter "_indiriliyor_*").Count -eq 0) "reddedilen dosyanin gecici kopyasi kalmaz"
Check (@(Get-ChildItem $imgDir -Filter "1568200000000000005*").Count -eq 0) "reddedilen HTML diske kalmaz"

$atts = @(1..5 | ForEach-Object { New-Att $cdn "image/png" 1000 })
$m6 = [pscustomobject]@{ id = "1568200000000000006"; attachments = $atts }
$r6 = @(Save-MessageImages $m6 $imgDir (New-Dl $png))
Check ($r6.Count -eq 3 -and $r6[2] -eq "ekler/1568200000000000006_3.png") "mesaj basina en cok 3 gorsel"

$m7 = [pscustomobject]@{ id = "1568200000000000007"; attachments = @((New-Att $cdn "image/jpeg" 1000 "a.jpg")) }
$r7 = @(Save-MessageImages $m7 $imgDir (New-Dl $jpg))
Check ($r7.Count -eq 1 -and $r7[0].EndsWith(".jpg")) "JPEG uzantisi imzadan gelir"

$m8 = [pscustomobject]@{ id = "../../kotu"; attachments = @((New-Att $cdn "image/png" 1000)) }
Check (@(Save-MessageImages $m8 $imgDir (New-Dl $png)).Count -eq 0) "sayisal olmayan mesaj kimligi (yol kacisi) reddedilir"

$m9 = [pscustomobject]@{ id = "1568200000000000009"; attachments = @() }
Check (@(Save-MessageImages $m9 $imgDir (New-Dl $png)).Count -eq 0) "eksiz mesaj bos doner"

# Eski dosya temizligi
$old = Join-Path $imgDir "eski.png"
[IO.File]::WriteAllBytes($old, $png)
(Get-Item $old).LastWriteTime = (Get-Date).AddDays(-40)
Remove-OldImages $imgDir 30
Check (-not (Test-Path $old)) "30 gunden eski gorsel silinir"
Check (Test-Path (Join-Path $imgDir "1568200000000000001_1.png")) "yeni gorsel silinmez"

# Gercek indirme (istege bagli): Discord'un genel varsayilan avatari
if ($Ag) {
  $m10 = [pscustomobject]@{ id = "1568200000000000010"; attachments = @((New-Att "https://cdn.discordapp.com/embed/avatars/0.png" "image/png" 1000)) }
  $r10 = @(Save-MessageImages $m10 $imgDir)
  Check ($r10.Count -eq 1 -and (Get-ImageKind ([IO.File]::ReadAllBytes((Join-Path $imgDir "1568200000000000010_1.png")))) -eq "png") "gercek Discord CDN indirmesi (genel avatar) PNG olarak gelir"
}

Remove-Item -Recurse -Force $tmpRoot -ErrorAction SilentlyContinue
Write-Output ("SONUC: hata sayisi = " + $fail)
if ($fail -gt 0) { exit 1 } else { exit 0 }
