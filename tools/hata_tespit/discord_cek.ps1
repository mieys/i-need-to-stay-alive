<#
  Discord #hata-tespit kanalindaki YENI mesajlari ceker ve docs/hata_tespit/ham/mesajlar.jsonl dosyasina ekler.
  Sadece OKUR (bot mesaj atmaz). Ham mesajlar kisisel veri icerir -> docs/hata_tespit/ham/ git'e girmez.

  Kullanim:
    powershell -ExecutionPolicy Bypass -File tools/hata_tespit/discord_cek.ps1
    powershell -ExecutionPolicy Bypass -File tools/hata_tespit/discord_cek.ps1 -ChannelId 123456789012345678 -MaxPages 5

  Gerekenler (kullanici duzeyi ortam degiskeni ya da bu surecin ortami):
    DISCORD_BOT_TOKEN   bot token'i (ASLA repoya / sohbete yazma)
    DISCORD_CHANNEL_ID  #hata-tespit kanal ID'si (ya da -ChannelId)

  Imleç: docs/hata_tespit/ham/son_id.txt (en son cekilen mesaj ID'si). Silersen bastan ceker.
  Not: dosya bilerek sadece ASCII (Windows PowerShell 5.1 BOM'suz dosyayi ANSI okur).
#>
param(
  [string]$ChannelId = "",
  [int]$MaxPages = 20,
  [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-Setting([string]$name) {
  $v = [Environment]::GetEnvironmentVariable($name, "Process")
  if (-not $v) { $v = [Environment]::GetEnvironmentVariable($name, "User") }
  return $v
}

function Fail([string]$msg, [int]$code) {
  [Console]::Error.WriteLine("hata_tespit: " + $msg)
  exit $code
}

$token = Get-Setting "DISCORD_BOT_TOKEN"
if (-not $token) { Fail "DISCORD_BOT_TOKEN ayarli degil (kullanici ortam degiskeni olarak tanimla)." 2 }
if (-not $ChannelId) { $ChannelId = Get-Setting "DISCORD_CHANNEL_ID" }
if (-not $ChannelId) { Fail "Kanal ID yok: -ChannelId ver ya da DISCORD_CHANNEL_ID tanimla." 2 }
if ($ChannelId -notmatch '^\d{15,22}$') { Fail "Kanal ID sayisal olmali (Gelistirici Modu > Kanal ID'sini kopyala)." 2 }

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if (-not $OutDir) { $OutDir = Join-Path $root "docs\hata_tespit\ham" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$outFile = Join-Path $OutDir "mesajlar.jsonl"
$stateFile = Join-Path $OutDir "son_id.txt"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$cursor = "0"
if (Test-Path $stateFile) {
  $c = (Get-Content -Raw $stateFile).Trim()
  if ($c -match '^\d+$') { $cursor = $c }
}

$headers = @{ Authorization = "Bot $token"; "User-Agent" = "DiscordBot (hata-tespit-toplayici, 1.0)" }
$newCount = 0
$emptyContent = 0
$humanCount = 0

for ($page = 0; $page -lt $MaxPages; $page++) {
  $url = "https://discord.com/api/v10/channels/$ChannelId/messages?limit=100&after=$cursor"
  $batch = $null
  for ($try = 0; $try -lt 5; $try++) {
    try {
      $batch = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
      break
    } catch {
      $resp = $_.Exception.Response
      $status = 0
      if ($resp) { $status = [int]$resp.StatusCode }
      if ($status -eq 429) { Start-Sleep -Seconds (2 + $try * 2); continue }
      if ($status -eq 401) { Fail "401: token gecersiz (Reset Token yaptiysan yenisini tanimla)." 3 }
      if ($status -eq 403) { Fail "403: bot bu kanali goremiyor (kanal izinlerine botu ekle: Kanallari Gor + Mesaj Gecmisini Oku)." 3 }
      if ($status -eq 404) { Fail "404: kanal bulunamadi (ID yanlis ya da bot sunucuda degil)." 3 }
      throw
    }
  }
  if ($null -eq $batch) { Fail "Discord surekli hiz siniri dondu; sonra tekrar dene." 4 }
  $batch = @($batch)
  if ($batch.Count -eq 0) { break }

  # Discord yeniden eskiye verir; eskiden yeniye sirala (id = snowflake)
  $sorted = @($batch | Sort-Object { [uint64]$_.id })
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($m in $sorted) {
    if ($m.author.bot -eq $true) { continue }
    $humanCount++
    if ([string]::IsNullOrEmpty($m.content) -and (-not $m.attachments -or @($m.attachments).Count -eq 0)) { $emptyContent++ }
    $ts = $m.timestamp
    if ($ts -is [datetime]) { $ts = $ts.ToUniversalTime().ToString("o") }
    $react = 0
    if ($m.reactions) { foreach ($r in @($m.reactions)) { $react += [int]$r.count } }
    $name = $m.author.global_name
    if (-not $name) { $name = $m.author.username }
    $rec = [ordered]@{
      id         = [string]$m.id
      ts         = [string]$ts
      author_id  = [string]$m.author.id
      author     = [string]$name
      content    = [string]$m.content
      reply_to   = [string]$m.message_reference.message_id
      reactions  = $react
      attachments = @(@($m.attachments) | Where-Object { $_ } | ForEach-Object { [string]$_.url })
    }
    $lines.Add(($rec | ConvertTo-Json -Compress -Depth 4))
    $newCount++
  }
  if ($lines.Count -gt 0) {
    [IO.File]::AppendAllText($outFile, (($lines -join "`n") + "`n"), $utf8)
  }
  $cursor = [string]($sorted[-1].id)
  [IO.File]::WriteAllText($stateFile, $cursor, $utf8)
  if ($batch.Count -lt 100) { break }
}

Write-Output ("hata_tespit: {0} yeni mesaj eklendi (imlec {1})." -f $newCount, $cursor)

# ISLENMEMIS mesajlar: mesajlar.jsonl'da, islenen_id.txt'deki ID'den buyuk ID'li satirlar.
# (Mesajlar baska biri/onceki kosu tarafindan zaten cekilmis olabilir; karar bu sayiya gore verilir.)
$processedFile = Join-Path $OutDir "islenen_id.txt"
$processed = [uint64]0
if (Test-Path $processedFile) {
  $p = (Get-Content -Raw $processedFile).Trim()
  if ($p -match '^\d+$') { $processed = [uint64]$p }
}
$pending = 0
if (Test-Path $outFile) {
  foreach ($ln in [IO.File]::ReadLines($outFile, $utf8)) {
    if ($ln -match '^\{"id":"(\d+)"') {
      if ([uint64]$Matches[1] -gt $processed) { $pending++ }
    }
  }
}
Write-Output ("BEKLEYEN: {0}" -f $pending)
if ($humanCount -gt 0 -and $emptyContent -eq $humanCount) {
  Write-Warning "Tum mesajlar bos geldi: Developer Portal > Bot > Message Content Intent acik mi?"
}
