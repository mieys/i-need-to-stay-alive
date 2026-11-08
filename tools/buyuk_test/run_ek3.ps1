# Buyuk test 3. tur: crowd (takim XP kilidi) + yakin dovus silahlari (yakin hedef, surukleme olcumu).
$run = Join-Path $PSScriptRoot "run.ps1"
& powershell -ExecutionPolicy Bypass -File $run -Mode crowd -Label tam2 -TimeoutSec 900
& powershell -ExecutionPolicy Bypass -File $run -Mode wt -Label tam2_yakin -Env "BT_WEAPONS=dagger,pence,topuz,uzunkilic,mizrak,kalkan;BT_N=1;BT_SEC=8;BT_RMIN=45;BT_RMAX=70" -TimeoutSec 1200
Write-Host "HEPSI BITTI"
