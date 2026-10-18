# SUREC DUZEYI A/B: iki ayri oyun surecini ortam degiskeniyle (oyundaki bir olcum anahtari) ardisik kosturur, "phases" pencerelerinin kare / p95 / render-CPU ortalamasini yazar.
#   powershell -ExecutionPolicy Bypass -File tools/fps_micro/proc_ab.ps1 -EnvA "MAP_QUAD_OFF=1" -EnvB "MAP_QUAD_OFF=0" -Rounds 4
# Neden: tek surecte "kopya katman" / kare-kare A/B yanilttirabiliyor (madde 272); oyuna giren bir degisikligin tek guvenilir hakemi budur. A = eski (anahtar kapali), B = yeni.
# Oyun kodunda anahtar OS.get_environment("...") ile okunmali (ornek: fx_warmup.gd FXW_COLLECT). Varsayilan gorunmez masaustu (gorunur pencere acmaz).
param(
	[string]$EnvA = "",
	[string]$EnvB = "",
	[string]$Base = "PG_N=200;PG_SETTLE=20;PG_SWEEP=phases",
	[int]$Rounds = 4,
	[int]$TimeoutSec = 400
)
if ($EnvA -eq "" -or $EnvB -eq "") { Write-Host "Kullanim: -EnvA 'ANAHTAR=eski' -EnvB 'ANAHTAR=yeni' [-Rounds 4]"; exit 2 }
$run = Join-Path $PSScriptRoot "run.ps1"
$tmp = Join-Path $env:TEMP "fps_micro"
New-Item -ItemType Directory -Force $tmp | Out-Null
$rows = @()
for ($i = 1; $i -le $Rounds; $i++) {
	foreach ($side in @("A", "B")) {
		$e = if ($side -eq "A") { $EnvA } else { $EnvB }
		$out = Join-Path $tmp "proc_ab_${i}_$side.txt"
		$lines = & powershell -ExecutionPolicy Bypass -File $run -Mode draw_sweep -Env "$Base;$e" -TimeoutSec $TimeoutSec -Out $out | Select-String "PG PHASES frame="
		$w = 0
		foreach ($l in $lines) {
			if ($l.Line -match "frame=([\d.]+) p95=([\d.]+) rcpu=([\d.]+)") {
				$w++
				if ($w -gt 1) { $rows += [pscustomobject]@{ side = $side; round = $i; frame = [double]$Matches[1]; p95 = [double]$Matches[2]; rcpu = [double]$Matches[3] } } # ilk pencere isinma
			}
		}
		Write-Host "tamam: tur $i $side ($e)"
	}
}
foreach ($side in @("A", "B")) {
	$g = @($rows | Where-Object { $_.side -eq $side })
	if ($g.Count -eq 0) { Write-Host "$side : veri yok"; continue }
	"{0}: kare={1:N2} ms  p95={2:N2}  render-CPU={3:N2} ms  (pencere n={4})" -f $side, ($g | Measure-Object frame -Average).Average, ($g | Measure-Object p95 -Average).Average, ($g | Measure-Object rcpu -Average).Average, $g.Count
}
for ($i = 1; $i -le $Rounds; $i++) {
	$a = @($rows | Where-Object { $_.side -eq "A" -and $_.round -eq $i }); $b = @($rows | Where-Object { $_.side -eq "B" -and $_.round -eq $i })
	if ($a.Count -gt 0 -and $b.Count -gt 0) {
		"tur {0}: kare A={1:N2} B={2:N2} ({3:+0.00;-0.00}) | render-CPU A={4:N2} B={5:N2} ({6:+0.00;-0.00})" -f $i, ($a | Measure-Object frame -Average).Average, ($b | Measure-Object frame -Average).Average, (($b | Measure-Object frame -Average).Average - ($a | Measure-Object frame -Average).Average), ($a | Measure-Object rcpu -Average).Average, ($b | Measure-Object rcpu -Average).Average, (($b | Measure-Object rcpu -Average).Average - ($a | Measure-Object rcpu -Average).Average)
	}
}
