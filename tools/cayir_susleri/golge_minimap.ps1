# BAŞLANGIÇ ÇAYIRI SÜSLERİ (madde 383): bake sonrası gölge maskeleri + minimap - GİZLİ masaüstünde (pencere görünmez, tools/fps_micro/hidden_launch.ps1).
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/cayir_susleri/golge_minimap.ps1 ; sonra python tools/bake_map_shadows.py <yazdırılan klasör> + --headless --import
$ErrorActionPreference = 'Stop'
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
. "$proj\tools\fps_micro\hidden_launch.ps1"
New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot 'out') | Out-Null
$log1 = Join-Path $PSScriptRoot 'out\golge_log.txt'
$code1 = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --resolution 1280x720 --log-file `"$log1`" -s tools/bake_map_shadows.gd" -WorkDir $proj -TimeoutSec 600
Write-Output "golge cikis $code1"
$log2 = Join-Path $PSScriptRoot 'out\minimap_log.txt'
$code2 = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --windowed --resolution 1280x720 --log-file `"$log2`" -s tools/bake_minimap.gd" -WorkDir $proj -TimeoutSec 600
Write-Output "minimap cikis $code2"
