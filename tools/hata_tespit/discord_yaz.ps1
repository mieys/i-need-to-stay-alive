<#
  #hata-tespit kanalinda BIR mesaja SABLONLU kisa yanit yazar (docs/hata_tespit/sablonlar.json).
  Serbest metin YOK: yanit = sablon + (temizlenmis kisa konu | sabit bilgi etiketleri).

  Kullanim:
    powershell -ExecutionPolicy Bypass -File tools/hata_tespit/discord_yaz.ps1 -ReplyTo <mesaj_id> -Sablon dogrulandi -Konu "kisa konu"
    powershell -ExecutionPolicy Bypass -File tools/hata_tespit/discord_yaz.ps1 -ReplyTo <mesaj_id> -Sablon bilgi_gerekli -Bilgi esya_turu,slot,uyari_metni
    powershell -ExecutionPolicy Bypass -File tools/hata_tespit/discord_yaz.ps1 -ReplyTo <mesaj_id> -Sablon durum
    ... -DryRun   (gondermez, metni yazdirir)

  Guvenlik: etiket/baglanti atmaz (allowed_mentions bos), yalniz mesajlar.jsonl'da gorulmus mesaja yanit,
  ayni mesaja ayni sablon bir kez, saatte en cok 5 / gunde en cok 20 yanit. Kayit: docs/hata_tespit/giden.jsonl
  (mesaj icerigi/yazar adi YOK). Bot "Mesaj Gonder" iznine sahip olmali.
  Cikis kodlari: 2 = parametre/ayar, 3 = Discord reddetti, 4 = sinir/tekrar kurali.
  Not: dosya bilerek sadece ASCII (Windows PowerShell 5.1); Turkce metin sablonlar.json'da (UTF-8).
#>
param(
  [Parameter(Mandatory = $true)][string]$ReplyTo,
  [Parameter(Mandatory = $true)][ValidateSet("dogrulandi", "bilgi_gerekli", "durum")][string]$Sablon,
  [string]$Konu = "",
  [string[]]$Bilgi = @(),
  [string]$ChannelId = "",
  [string]$DocsDir = "",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Fail([string]$msg, [int]$code) {
  Write-Output ("hata_tespit_yaz: HATA: " + $msg)
  exit $code
}
function Get-Setting([string]$name) {
  $v = [Environment]::GetEnvironmentVariable($name, "Process")
  if (-not $v) { $v = [Environment]::GetEnvironmentVariable($name, "User") }
  return $v
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if (-not $DocsDir) { $DocsDir = Join-Path $root "docs\hata_tespit" }
$utf8 = New-Object System.Text.UTF8Encoding($false)

if ($ReplyTo -notmatch '^\d{15,22}$') { Fail "ReplyTo sayisal mesaj ID'si olmali." 2 }
if (-not $ChannelId) { $ChannelId = Get-Setting "DISCORD_CHANNEL_ID" }
if ($ChannelId -notmatch '^\d{15,22}$') { Fail "Kanal ID yok/gecersiz (DISCORD_CHANNEL_ID)." 2 }

# Sablonlar
$tplFile = Join-Path $DocsDir "sablonlar.json"
if (-not (Test-Path $tplFile)) { Fail "sablonlar.json yok." 2 }
$tpl = (Get-Content -Raw -Encoding UTF8 $tplFile) | ConvertFrom-Json

# Yalniz gorulmus bir mesaja yanit
$rawFile = Join-Path $DocsDir "ham\mesajlar.jsonl"
$seen = $false
if (Test-Path $rawFile) {
  foreach ($ln in [IO.File]::ReadLines($rawFile, $utf8)) {
    if ($ln.StartsWith('{"id":"' + $ReplyTo + '"')) { $seen = $true; break }
  }
}
if (-not $seen) { Fail "ReplyTo mesaji ham/mesajlar.jsonl'da yok; yalniz toplanmis mesaja yanit verilir." 2 }

# Metni kur
if ($Sablon -eq "dogrulandi") {
  $k = $Konu
  $k = [regex]::Replace($k, '(?i)https?\S*', '')
  $k = [regex]::Replace($k, '[@<>`*_~|\[\]\(\)/\\#:]', ' ')
  $k = ([regex]::Replace($k, '\s+', ' ')).Trim()
  if ($k.Length -gt 90) { $k = $k.Substring(0, 90).Trim() + "..." }
  if ($k.Length -lt 3) { Fail "-Konu gerekli (en az 3 karakter, kisa ve duz metin)." 2 }
  $text = $tpl.dogrulandi.Replace("{konu}", $k)
} elseif ($Sablon -eq "durum") {
  $text = [string]$tpl.durum
} else {
  $labels = @()
  $expanded = @()
  foreach ($b in $Bilgi) { $expanded += ($b -split ',') }
  foreach ($b in $expanded) {
    $b = $b.Trim()
    if (-not $b) { continue }
    $lab = $tpl.bilgi_etiketleri.PSObject.Properties[$b]
    if (-not $lab) { Fail ("Bilinmeyen bilgi anahtari: " + $b + " (sablonlar.json bilgi_etiketleri)") 2 }
    $labels += [string]$lab.Value
  }
  if ($labels.Count -lt 1) { Fail "-Bilgi en az bir anahtar icermeli." 2 }
  $text = $tpl.bilgi_gerekli.Replace("{bilgi}", ($labels -join ", "))
}
if ($text.Length -gt 600) { Fail "Metin cok uzun." 2 }

# Tekrar + hiz siniri
$ledger = Join-Path $DocsDir "giden.jsonl"
$now = (Get-Date).ToUniversalTime()
$lastHour = 0
$lastDay = 0
if (Test-Path $ledger) {
  foreach ($ln in [IO.File]::ReadLines($ledger, $utf8)) {
    if (-not $ln.Trim()) { continue }
    $r = $ln | ConvertFrom-Json
    if ($r.reply_to -eq $ReplyTo -and $r.sablon -eq $Sablon) { Fail "Bu mesaja bu sablon zaten gonderilmis." 4 }
    $t = [datetime]::Parse([string]$r.ts, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal)
    if ($Sablon -eq "durum" -and $r.sablon -eq "durum" -and ($now - $t).TotalMinutes -lt 30) { Fail "Durum yaniti en cok 30 dakikada bir." 4 }
    if (($now - $t).TotalHours -lt 1) { $lastHour++ }
    if (($now - $t).TotalHours -lt 24) { $lastDay++ }
  }
}
if ($lastHour -ge 5) { Fail "Saatlik sinir (5) doldu." 4 }
if ($lastDay -ge 20) { Fail "Gunluk sinir (20) doldu." 4 }

if ($DryRun) {
  Write-Output "KURU CALISMA (gonderilmedi):"
  Write-Output $text
  exit 0
}

$token = Get-Setting "DISCORD_BOT_TOKEN"
if (-not $token) { Fail "DISCORD_BOT_TOKEN ayarli degil." 2 }
$headers = @{ Authorization = "Bot $token"; "User-Agent" = "DiscordBot (hata-tespit-toplayici, 1.0)" }
$body = @{
  content = $text
  message_reference = @{ message_id = $ReplyTo; fail_if_not_exists = $false }
  allowed_mentions = @{ parse = @() }
} | ConvertTo-Json -Compress -Depth 5
$bytes = $utf8.GetBytes($body)

$sent = $null
for ($try = 0; $try -lt 3; $try++) {
  try {
    $sent = Invoke-RestMethod -Uri "https://discord.com/api/v10/channels/$ChannelId/messages" -Method Post -Headers $headers -ContentType "application/json; charset=utf-8" -Body $bytes
    break
  } catch {
    $resp = $_.Exception.Response
    $status = 0
    if ($resp) { $status = [int]$resp.StatusCode }
    if ($status -eq 429) { Start-Sleep -Seconds (2 + $try * 2); continue }
    if ($status -eq 401) { Fail "401: token gecersiz." 3 }
    if ($status -eq 403) { Fail "403: bot bu kanala yazamiyor (Mesaj Gonder izni yok; yeni izinle yeniden yetkilendir)." 3 }
    if ($status -eq 404) { Fail "404: kanal bulunamadi." 3 }
    throw
  }
}
if ($null -eq $sent) { Fail "Discord hiz siniri; sonra tekrar dene." 4 }

$rec = [ordered]@{
  ts       = $now.ToString("o")
  reply_to = $ReplyTo
  sablon   = $Sablon
  sent_id  = [string]$sent.id
}
[IO.File]::AppendAllText($ledger, (($rec | ConvertTo-Json -Compress) + "`n"), $utf8)
Write-Output ("GONDERILDI sent_id={0} (sablon {1})" -f $sent.id, $Sablon)
