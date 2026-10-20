# Saklanma çalılığı prototiplerini (madde 274) gerçek çizicide yakalar - GİZLİ masaüstünde (pencere görünmez, tools/fps_micro/hidden_launch.ps1).
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/proto_20261019/calilik_run.ps1 [-Tags simdi,a,b,c,d] [-Pick 0]
#   simdi = şu anki harita/saklanma_calilik.png; diğerleri = tools/proto_20261019/out/calilik/atlas_<tag>.png
# Çıktı: tools/proto_20261019/out/calilik/oyun_<tag>_p<pick>.png; -Walk: hışırtı kareleri out/calilik/walk_<tag>/ (GIF: calilik_sheet.py)
param([string[]]$Tags = @('simdi', 'a', 'b', 'c', 'd'), [int]$Pick = 0, [switch]$Walk)
$ErrorActionPreference = 'Stop'
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$out = Join-Path $PSScriptRoot 'out\calilik'
New-Item -ItemType Directory -Force $out | Out-Null
. "$proj\tools\fps_micro\hidden_launch.ps1"
$Tags = @($Tags | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' })   # -File ile 'a,b' tek metin gelir
foreach ($t in $Tags) {
	if ($t -eq 'simdi') { $env:CALI_ATLAS = '' } else { $env:CALI_ATLAS = (Join-Path $out "atlas_$t.png") }
	$env:CALI_OUT = (Join-Path $out "oyun_${t}_p$Pick.png")
	$env:CALI_WALK = ''
	if ($Walk) { $env:CALI_WALK = '1'; $env:CALI_OUT = (Join-Path $out "walk_$t") }
	$env:CALI_PICK = "$Pick"
	$log = Join-Path $out "log_$t.txt"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --resolution 1280x720 --log-file `"$log`" -s tools/proto_20261019/calilik_capture.gd" -WorkDir $proj -TimeoutSec 180
	$shot = Select-String -Path $log -Pattern 'SHOT|SCRIPT ERROR|atlas degisti' | ForEach-Object { $_.Line }
	Write-Output "$t -> cikis $code; $shot"
}
