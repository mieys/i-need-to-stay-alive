# Buyuk test 2. tur: data (ride_ kontrolu), select, dock, crowd (XP kilitli), wt (tek hedef, 8 sn, sabit yerlesim).
param([string]$Label = "tam2")
$run = Join-Path $PSScriptRoot "run.ps1"
$t0 = Get-Date
foreach ($step in @(
		@{ m = "data"; t = 300; e = "" },
		@{ m = "select"; t = 300; e = "" },
		@{ m = "dock"; t = 900; e = "" },
		@{ m = "crowd"; t = 900; e = "" },
		@{ m = "wt"; t = 2400; e = "BT_N=1;BT_SEC=8" })) {
	$s = Get-Date
	& powershell -ExecutionPolicy Bypass -File $run -Mode $step.m -Label $Label -Env $step.e -TimeoutSec $step.t
	Write-Host ("{0} bitti: {1:N0} sn" -f $step.m, ((Get-Date) - $s).TotalSeconds)
}
Write-Host ("HEPSI BITTI: {0:N0} sn" -f ((Get-Date) - $t0).TotalSeconds)
