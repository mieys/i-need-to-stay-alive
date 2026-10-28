# DERİN ORMAN kuzey prototipini gerçek çizicide yakalar - GİZLİ masaüstünde (pencere görünmez, tools/fps_micro/hidden_launch.ps1).
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/proto_20261021/derin_orman/kuzey_run.ps1 [-Variants simdi,a,b]
# Önce: python tools/proto_20261021/derin_orman/kuzey_zone.py ; sonra: python tools/proto_20261021/derin_orman/kuzey_sheet.py
# Çıktı: out/<çeşit>/base_<çekim>.png + char_<çekim>.png + meta_<çekim>.txt
param([string[]]$Variants = @('simdi', 'a', 'b'))
$ErrorActionPreference = 'Stop'
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$out = Join-Path $PSScriptRoot 'out'
. "$proj\tools\fps_micro\hidden_launch.ps1"
$Variants = @($Variants | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' })   # -File ile 'a,b' tek metin gelir
$env:KZ_ZONE = (Join-Path $out 'kuzey_zone.txt')
foreach ($v in $Variants) {
	$env:KZ_VARIANT = $v
	$env:KZ_OUT = (Join-Path $out $v)
	New-Item -ItemType Directory -Force $env:KZ_OUT | Out-Null
	$log = Join-Path $out "log_$v.txt"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --resolution 960x540 --log-file `"$log`" -s tools/proto_20261021/derin_orman/kuzey_capture.gd" -WorkDir $proj -TimeoutSec 240
	$shot = Select-String -Path $log -Pattern 'SHOT|SCRIPT ERROR|ERROR|olu agac|basilan' | ForEach-Object { $_.Line }
	Write-Output "$v -> cikis $code"
	$shot | Select-Object -First 12 | ForEach-Object { Write-Output "  $_" }
}
