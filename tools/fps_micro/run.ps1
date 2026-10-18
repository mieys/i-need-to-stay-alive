# FPS mikro ölçüm koşturucusu (bkz. tools/fps_micro/fps_micro.gd başlığı).
#   VARSAYILAN: oyun kullanicinin GORMEDIGI ayri bir Windows masaustunde calisir (hidden_launch.ps1; pencere ekrana cikmaz, odak calmaz, GPU normal).
#   Gorunur pencere (-Visible) kullanicinin ekraninda one cikar ve rahatsiz eder (sikayet 2026-10-03, 2026-10-18): -AllowWindow da ister, once kullanicidan izin al.
#   powershell -ExecutionPolicy Bypass -File tools/fps_micro/run.ps1 -Mode micro_crowd -Env "PG_N=200;PG_FIGHT=1" [-Out sonuc.txt] [-Extra "--verbose"]
# Kullanıcı verisi YALITILIR: APPDATA geçici klasöre çevrilir (ayar dosyaları + Vulkan/shader önbelleği kopyalanır), gerçek meta.cfg / records.cfg / balans kayıtları
# bozulmaz (önceki turda ölçüm koşuları gerçek kayıtlara yazmıştı). Oyun açıkken ölçme. Çıktı: -Out dosyasında "PG ..." satırları.
param(
	[string]$Mode = "micro_crowd",
	[string]$Env = "",
	[string]$Out = "",
	[int]$TimeoutSec = 600,
	[string]$Extra = "",
	[switch]$Visible,
	[switch]$AllowWindow
)
if ($Visible -and -not $AllowWindow) {
	Write-Host "DURDU: -Visible gercek bir oyun PENCERESI acar ve kullanicinin ekraninda one cikar (kullanici 2026-10-03 ve 2026-10-18'de sikayet etti)."
	Write-Host "Kullanicidan izin alindiysa -Visible -AllowWindow ver; yoksa bayraksiz calistir (gorunmez masaustu)."
	exit 2
}
. "$PSScriptRoot\hidden_launch.ps1"
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$tmp = Join-Path $env:TEMP "fps_micro"
New-Item -ItemType Directory -Force $tmp | Out-Null
if ($Out -eq "") { $Out = Join-Path $tmp "$Mode.txt" }
$errf = $Out + ".err"
$appName = "Temiz S$([char]0x00FC)r$([char]0x00FC)m"
$realUser = Join-Path $env:APPDATA "Godot\app_userdata\$appName"
$fakeRoot = Join-Path $tmp "appdata"
$fakeUser = Join-Path $fakeRoot "Godot\app_userdata\$appName"
New-Item -ItemType Directory -Force $fakeUser | Out-Null
if (Test-Path $realUser) {
	Get-ChildItem $realUser -Filter "*.cfg" -File | ForEach-Object { Copy-Item $_.FullName (Join-Path $fakeUser $_.Name) -Force }
	foreach ($d in "vulkan", "shader_cache") {
		if ((Test-Path (Join-Path $realUser $d)) -and -not (Test-Path (Join-Path $fakeUser $d))) {
			robocopy (Join-Path $realUser $d) (Join-Path $fakeUser $d) /E /NFL /NDL /NJH /NJS /NP | Out-Null
		}
	}
}
$env:PG_MODE = $Mode
foreach ($kv in ($Env -split ';')) { if ($kv -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] } }
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
$gargs = @("--path", "`"$proj`"", "--windowed", "--resolution", "1920x1080")
if ($Extra -ne "") { $gargs += ($Extra -split " ") }
$gargs += @("-s", "res://tools/fps_micro/fps_micro.gd")
try {
	if ($Visible) {
		$p = Start-Process -FilePath $godot -ArgumentList $gargs -NoNewWindow -PassThru -RedirectStandardOutput $Out -RedirectStandardError $errf
		if (-not $p.WaitForExit($TimeoutSec * 1000)) { $p.Kill(); Add-Content $Out "PG TIMEOUT" }
	} else {
		$argLine = ($gargs + @("--audio-driver", "Dummy", "--log-file", "`"$Out`"")) -join " "
		if (Test-Path $Out) { Remove-Item $Out -Force }
		$code = Invoke-GodotHidden -Exe $godot -ArgLine $argLine -WorkDir $proj -TimeoutSec $TimeoutSec
		if ($code -eq -2) { Add-Content $Out "PG TIMEOUT" } elseif ($code -lt 0) { Add-Content $Out "PG HIDDENFAIL kod=$code" }
	}
} finally {
	$env:APPDATA = $savedAppData
}
Get-Content $Out -Encoding UTF8 | Select-String "^PG " | ForEach-Object { $_.Line }
