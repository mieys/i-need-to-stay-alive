# Efekt pişirici sürücüsü (madde 215): .\tools\fx_bake.ps1 <ad> <res://scenes/fx_x.tscn> <süre sn> [texel=1.0] [view=400] [fps=20]
# Godot penceresi açar (gerçek çizici gerek), ~10 sn. Sonra: Godot --headless --path . --import (yeni PNG için .import).
param([string]$Name, [string]$Scene, [double]$Dur, [double]$Texel = 1.0, [int]$View = 400, [int]$Fps = 20)
$godot = (Get-ChildItem "C:/Users/perva/Desktop/Ar*iv/Godot_v4.7.2-stable_win64.exe").FullName
$tmp = Join-Path $env:TEMP "fxbake_$Name"
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
$env:BAKE_SCENE = $Scene; $env:BAKE_DUR = "$Dur"; $env:BAKE_FPS = "$Fps"; $env:BAKE_TEXEL = "$Texel"; $env:BAKE_VIEW = "$View"; $env:BAKE_OUT = $tmp
$proj = Split-Path -Parent $PSScriptRoot
$p = Start-Process -FilePath $godot -ArgumentList @("--path", "`"$proj`"", "--windowed", "--resolution", "$($View)x$($View)", "--fixed-fps", "$Fps", "-s", "tools/fx_bake_capture.gd") -RedirectStandardOutput "$tmp.out.txt" -RedirectStandardError "$tmp.err.txt" -PassThru -NoNewWindow -WorkingDirectory $proj
$p | Wait-Process -Timeout 120
if (-not $p.HasExited) { $p.Kill() }
Select-String -Path "$tmp.out.txt" -Pattern "CAPTURED|SCRIPT ERROR" | ForEach-Object { $_.Line }
python (Join-Path $PSScriptRoot "fx_bake_pack.py") $Name $tmp $Fps $Texel
