# Yeni evcillerin (madde 509) gerçek çizicide yakalaması - GİZLİ masaüstünde (kullanıcı pencere görmez).
#   powershell -ExecutionPolicy Bypass -File tools/proto_20261109/evcil_run.ps1 -Out <klasör>
param([string]$Out = "$PSScriptRoot\out")
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
New-Item -ItemType Directory -Force $Out | Out-Null
. "$proj\tools\fps_micro\hidden_launch.ps1"
$env:EVCIL_CAP_DIR = $Out
$log = Join-Path $Out "evcil_capture.log"
$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --log-file `"$log`" -s res://tools/proto_20261109/evcil_capture.gd" -WorkDir $proj -TimeoutSec 120
Write-Output "cikis=$code"
if (Test-Path $log) { Get-Content $log -Encoding UTF8 | Select-String "SLIME|MENZIL|t=|BITTI|ERROR|SCRIPT" | Select-Object -First 40 }
