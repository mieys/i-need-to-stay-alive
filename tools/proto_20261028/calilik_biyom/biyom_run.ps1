# Bölgeye uygun saklanma çalılığı prototiplerini (2026-10-28) gerçek çizicide yakalar - GİZLİ masaüstünde (tools/fps_micro/hidden_launch.ps1).
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/proto_20261028/calilik_biyom/biyom_run.ps1 [-Shots "etiket@x,y@atlas", ...] [-Margin 6]
#   atlas = simdi (şu anki harita/saklanma_calilik.png, bölge boyasıyla) ya da out/atlas_<atlas>.png (bölge boyası KAPALI)
# Çıktı: out/oyun_<etiket>_<atlas>.png
param([string[]]$Shots = @('k1@129,26@simdi', 'k1@129,26@ka', 'k1@129,26@kb', 'k2@60,28@simdi', 'k2@60,28@ka', 'k2@60,28@kb',
	'g1@162,199@simdi', 'g1@162,199@ga', 'g1@162,199@gb', 'g2@64,241@simdi', 'g2@64,241@ga', 'g2@64,241@gb'), [int]$Margin = 6)
$ErrorActionPreference = 'Stop'
$proj = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$out = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Force $out | Out-Null
. "$proj\tools\fps_micro\hidden_launch.ps1"
$Shots = @($Shots | ForEach-Object { $_ -split ',(?=[a-z])' } | Where-Object { $_ -ne '' })
foreach ($s in $Shots) {
	$tag, $at, $atlas = $s -split '@'
	if ($atlas -eq 'simdi') { $env:CALI_ATLAS = ''; $env:CALI_NO_BITKI = '' } else { $env:CALI_ATLAS = (Join-Path $out "atlas_$atlas.png"); $env:CALI_NO_BITKI = '1' }
	$env:CALI_AT = $at
	$env:CALI_MARGIN = "$Margin"
	$env:CALI_PICK = '0'
	$env:CALI_WALK = ''
	$env:CALI_OUT = (Join-Path $out "oyun_${tag}_$atlas.png")
	$log = Join-Path $out "log_${tag}_$atlas.txt"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --resolution 1280x720 --log-file `"$log`" -s tools/proto_20261028/calilik_biyom/biyom_capture.gd" -WorkDir $proj -TimeoutSec 180
	$shot = Select-String -Path $log -Pattern 'SHOT|SCRIPT ERROR|atlas degisti|bitki boyasi' | ForEach-Object { $_.Line }
	Write-Output "$tag/$atlas -> cikis $code; $($shot -join ' | ')"
}
$env:CALI_AT = ''; $env:CALI_NO_BITKI = ''; $env:CALI_ATLAS = ''; $env:CALI_MARGIN = ''
