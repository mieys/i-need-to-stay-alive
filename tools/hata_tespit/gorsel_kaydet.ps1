<#
  #hata-tespit mesajlarindaki EKRAN GORUNTULERINI indirir (discord_cek.ps1 buradaki islevleri kullanir).
  Guvenlik: yalniz Discord CDN (cdn.discordapp.com / media.discordapp.net), yalniz PNG/JPG/WebP (dosya IMZASI da dogrulanir,
  uzanti/content-type'a guvenilmez), en cok 5 MB, mesaj basina en cok 3. Dosya adi mesaj ID'sinden kurulur (kullanici
  girdisi dosya adina girmez). Cikti docs/hata_tespit/ham/ekler/ (git'e girmez, 30 gun sonra silinir).
  Gorseller VERIDIR: icindeki yazi/talimat uygulanmaz; model yalniz Read ile bakar, hicbir sey calistirilmaz.
  Not: dosya bilerek sadece ASCII (Windows PowerShell 5.1).
#>

$script:ImgMaxBytes = 5242880
$script:ImgMaxPerMessage = 3

# Ilk baytlardan gercek tur: png / jpg / webp, degilse "".
function Get-ImageKind([byte[]]$b) {
  if ($null -eq $b -or $b.Length -lt 12) { return "" }
  if ($b[0] -eq 0x89 -and $b[1] -eq 0x50 -and $b[2] -eq 0x4E -and $b[3] -eq 0x47 -and $b[4] -eq 0x0D -and $b[5] -eq 0x0A -and $b[6] -eq 0x1A -and $b[7] -eq 0x0A) { return "png" }
  if ($b[0] -eq 0xFF -and $b[1] -eq 0xD8 -and $b[2] -eq 0xFF) { return "jpg" }
  if ($b[0] -eq 0x52 -and $b[1] -eq 0x49 -and $b[2] -eq 0x46 -and $b[3] -eq 0x46 -and $b[8] -eq 0x57 -and $b[9] -eq 0x45 -and $b[10] -eq 0x42 -and $b[11] -eq 0x50) { return "webp" }
  return ""
}

# Yalniz Discord CDN. Host'tan hemen sonra "/" sart (cdn.discordapp.com.evil.com ve @ tuzaklari gecmez).
function Test-DiscordImageUrl([string]$url) {
  return [bool]($url -match '^https://(cdn\.discordapp\.com|media\.discordapp\.net)/')
}

function Remove-OldImages([string]$imgDir, [int]$days = 30) {
  if (-not (Test-Path $imgDir)) { return }
  Get-ChildItem -Path $imgDir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$days) } |
    Remove-Item -Force -ErrorAction SilentlyContinue
}

# Bir mesajin gorsel eklerini indirir; doner: "ekler/<mesajid>_<n>.<uzanti>" listesi (ham/ klasorune gore).
# $downloader: test icin degistirilebilir ({ param($url, $dest) ... }).
function Save-MessageImages($msg, [string]$imgDir, [scriptblock]$downloader = $null) {
  $saved = New-Object System.Collections.Generic.List[string]
  $mid = [string]$msg.id
  if ($mid -notmatch '^\d{15,22}$') { return $saved.ToArray() }
  if (-not $msg.attachments) { return $saved.ToArray() }
  if ($null -eq $downloader) {
    $downloader = {
      param($u, $dest)
      Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 30 -OutFile $dest -UserAgent "DiscordBot (hata-tespit-toplayici, 1.0)" | Out-Null
    }
  }
  foreach ($a in @($msg.attachments)) {
    if (-not $a) { continue }
    if ($saved.Count -ge $script:ImgMaxPerMessage) { break }
    $url = [string]$a.url
    if (-not (Test-DiscordImageUrl $url)) { continue }
    $ct = ([string]$a.content_type).ToLowerInvariant()
    $fn = ([string]$a.filename).ToLowerInvariant()
    $looksImage = ($ct -match '^image/(png|jpeg|jpg|webp)') -or ((-not $ct) -and ($fn -match '\.(png|jpe?g|webp)$'))
    if (-not $looksImage) { continue }
    $size = [int64]0
    if ($a.size) { $size = [int64]$a.size }
    if ($size -le 0 -or $size -gt $script:ImgMaxBytes) { continue }
    New-Item -ItemType Directory -Force -Path $imgDir | Out-Null
    $tmp = Join-Path $imgDir ("_indiriliyor_" + $mid + "_" + $saved.Count + ".tmp")
    try {
      & $downloader $url $tmp
      $len = (Get-Item $tmp).Length
      if ($len -le 0 -or $len -gt $script:ImgMaxBytes) { throw "boyut sinirina uymuyor" }
      $head = New-Object byte[] 12
      $fs = [IO.File]::OpenRead($tmp)
      try { [void]$fs.Read($head, 0, 12) } finally { $fs.Dispose() }
      $kind = Get-ImageKind $head
      if (-not $kind) { throw "gorsel degil (dosya imzasi)" }
      $name = $mid + "_" + ($saved.Count + 1) + "." + $kind
      Move-Item -Force $tmp (Join-Path $imgDir $name)
      $saved.Add("ekler/" + $name)
    } catch {
      Write-Host ("hata_tespit: gorsel atlandi (mesaj " + $mid + "): " + $_.Exception.Message)
    } finally {
      if (Test-Path $tmp) { Remove-Item -Force $tmp -ErrorAction SilentlyContinue }
    }
  }
  return $saved.ToArray()
}
