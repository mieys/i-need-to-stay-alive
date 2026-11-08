# Buyuk test 2. tur, 2. parca: data (ride_ kontrolu), select, dock, crowd (XP kilitli). Env gecilmez (bos -Env arguman olarak kaybolur).
param([string]$Label = "tam2")
$run = Join-Path $PSScriptRoot "run.ps1"
$t0 = Get-Date
foreach ($step in @(@{ m = "data"; t = 300 }, @{ m = "select"; t = 300 }, @{ m = "dock"; t = 900 }, @{ m = "crowd"; t = 900 })) {
	$s = Get-Date
	& powershell -ExecutionPolicy Bypass -File $run -Mode $step.m -Label $Label -TimeoutSec $step.t
	Write-Host ("{0} bitti: {1:N0} sn" -f $step.m, ((Get-Date) - $s).TotalSeconds)
}
Write-Host ("HEPSI BITTI: {0:N0} sn" -f ((Get-Date) - $t0).TotalSeconds)
