# Buyuk test: tum kipleri SIRAYLA kosturur (ayni anda iki Godot kosusu baslatma - gecici dosyalar ortak).
#   powershell -ExecutionPolicy Bypass -File tools/buyuk_test/run_all.ps1 -Label tam1
param([string]$Label = "tam1")
$run = Join-Path $PSScriptRoot "run.ps1"
$t0 = Get-Date
foreach ($step in @(
		@{ m = "data"; t = 300 },
		@{ m = "wt"; t = 1800 },
		@{ m = "ch"; t = 1500 },
		@{ m = "crowd"; t = 900 },
		@{ m = "cw"; t = 3000 })) {
	$s = Get-Date
	& powershell -ExecutionPolicy Bypass -File $run -Mode $step.m -Label $Label -TimeoutSec $step.t
	Write-Host ("{0} bitti: {1:N0} sn" -f $step.m, ((Get-Date) - $s).TotalSeconds)
}
Write-Host ("HEPSI BITTI: {0:N0} sn" -f ((Get-Date) - $t0).TotalSeconds)
