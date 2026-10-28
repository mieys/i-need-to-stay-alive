# Donmuş kare yakalaması (gizli masaüstü; madde 371). Kullanım: powershell -ExecutionPolicy Bypass -File tools/fps_micro/donmus_run.ps1 -Out <klasör>
param([Parameter(Mandatory = $true)][string]$Out)
$ErrorActionPreference = 'Stop'
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
. "$proj\tools\fps_micro\hidden_launch.ps1"
$log = Join-Path $env:TEMP 'donmus_log.txt'
if (Test-Path $log) { Remove-Item $log -Force }
New-Item -ItemType Directory -Force $Out | Out-Null
$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --resolution 1920x1080 --audio-driver Dummy --log-file `"$log`" -s res://tools/fps_micro/donmus_kare.gd -- `"$Out`"" -WorkDir $proj -TimeoutSec 400
"cikis $code"
Select-String -Path $log -Pattern '^DONMUS|SCRIPT ERROR|Parse Error' | ForEach-Object { $_.Line }
