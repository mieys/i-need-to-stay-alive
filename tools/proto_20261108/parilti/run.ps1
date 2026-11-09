$proj = "C:\Users\perva\Desktop\I need to stay alive\I need to stay alive"
$godot = (Get-ChildItem "C:\Users\perva\Desktop" -Directory | Where-Object { Test-Path (Join-Path $_.FullName "Godot_v4.7.2-stable_win64.exe") } | Select-Object -First 1).FullName + "\Godot_v4.7.2-stable_win64.exe"
$here = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "out"
$env:CAP_OUT = $here
. "$proj\tools\fps_micro\hidden_launch.ps1"
$log = Join-Path $here "log.txt"
$script = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "parilti_capture.gd"
$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --resolution 1280x720 --log-file `"$log`" -s `"$script`"" -WorkDir $proj -TimeoutSec 120
"exit=$code"
