# ARAYUZ TASMA YOKLAMASI kosturucu (tasma_yoklama.gd) - BASSIZ (pencere yok), APPDATA yalitilir (gercek ayar/kayit dosyalari bozulmaz).
#   powershell -ExecutionPolicy Bypass -File tools/arayuz_tasma/run.ps1 [-Langs "tr,en"] [-Env "TASMA_SKIP_GAME=1"] [-TimeoutSec 900]
# Cikti: tools/arayuz_tasma/out/yoklama.log (motor hatalari dahil) + out/rapor.txt (yalniz TASMA satirlari).
param([string]$Langs = "", [string]$Env = "", [int]$TimeoutSec = 900)
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$outDir = Join-Path $PSScriptRoot "out"
New-Item -ItemType Directory -Force $outDir | Out-Null
$log = Join-Path $outDir "yoklama.log"
if (Test-Path $log) { Remove-Item $log -Force }
$appName = "Temiz S$([char]0x00FC)r$([char]0x00FC)m"
$realUser = Join-Path $env:APPDATA "Godot\app_userdata\$appName"
$fakeRoot = Join-Path $env:TEMP "arayuz_tasma_appdata"
$fakeUser = Join-Path $fakeRoot "Godot\app_userdata\$appName"
New-Item -ItemType Directory -Force $fakeUser | Out-Null
if (Test-Path $realUser) { Get-ChildItem $realUser -Filter "*.cfg" -File | ForEach-Object { Copy-Item $_.FullName (Join-Path $fakeUser $_.Name) -Force } }
$env:TASMA_LANGS = $Langs
foreach ($kv in ($Env -split ';')) { if ($kv -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] } }
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	$p = Start-Process -FilePath $godot -ArgumentList @("--headless", "--path", "`"$proj`"", "--resolution", "1920x1080", "--audio-driver", "Dummy",
		"--log-file", "`"$log`"", "-s", "res://tools/arayuz_tasma/tasma_yoklama.gd") -NoNewWindow -PassThru `
		-RedirectStandardOutput (Join-Path $outDir "stdout.txt") -RedirectStandardError (Join-Path $outDir "stderr.txt")
	if (-not $p.WaitForExit($TimeoutSec * 1000)) { $p.Kill(); "ZAMAN ASIMI" }
} finally { $env:APPDATA = $savedAppData }
$lines = Get-Content $log -Encoding UTF8 -ErrorAction SilentlyContinue
$lines | Where-Object { $_ -match '^TASMA' } | Set-Content (Join-Path $outDir "rapor.txt") -Encoding UTF8
$lines | Where-Object { $_ -match '^TASMA_(EKRANLAR|SAYI|HATA)' }
