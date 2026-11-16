# HARİTA CİLA DENETİMİ (2026-11-15): her haritayı başsız Godot'ta açıp döker (denetim.gd -> out/grid_<id>.bin + meta_<id>.json), sonra
# python -I tools/harita_cila/analiz.py raporu yazar. Kullanıcı verisi yalıtılır (APPDATA geçici klasöre).
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/harita_cila/denetim.ps1 [-Haritalar "ana,bataklik,col,kis,batik_nekropol"]
param([string]$Haritalar = "ana,bataklik,col,kis,batik_nekropol", [int]$TimeoutSec = 300)
$ErrorActionPreference = 'Continue'
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
$proj = (Resolve-Path "$PSScriptRoot\..\..").Path
$out = Join-Path $PSScriptRoot "out"
New-Item -ItemType Directory -Force $out | Out-Null
if (-not (Test-Path (Join-Path $out ".gdignore"))) { New-Item -ItemType File (Join-Path $out ".gdignore") | Out-Null }
$tmp = Join-Path $env:TEMP "harita_cila_denetim"
$fakeRoot = Join-Path $tmp "appdata"
$appName = "Temiz S$([char]0x00FC)r$([char]0x00FC)m"
$realUser = Join-Path $env:APPDATA "Godot\app_userdata\$appName"
$fakeUser = Join-Path $fakeRoot "Godot\app_userdata\$appName"
New-Item -ItemType Directory -Force $fakeUser | Out-Null
if (Test-Path $realUser) {
	Get-ChildItem $realUser -Filter "*.cfg" -File | ForEach-Object { Copy-Item $_.FullName (Join-Path $fakeUser $_.Name) -Force }
}
$savedAppData = $env:APPDATA
$env:APPDATA = $fakeRoot
try {
	foreach ($id in $Haritalar.Split(",")) {
		$env:HARITA = $id.Trim()
		$log = Join-Path $tmp "log_$($env:HARITA).txt"
		$p = Start-Process -FilePath $godot -ArgumentList "--headless --path `"$proj`" --audio-driver Dummy --log-file `"$log`" -s res://tools/harita_cila/denetim.gd" -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $tmp "so_$($env:HARITA).txt") -RedirectStandardError (Join-Path $tmp "se_$($env:HARITA).txt")
		if (-not $p.WaitForExit($TimeoutSec * 1000)) { $p.Kill(); Write-Host "$($env:HARITA): ZAMAN AŞIMI" }
		Get-Content $log | Select-String "DENETIM|SCRIPT ERROR|Parse Error" | Select-Object -First 8 | ForEach-Object { Write-Host $_ }
	}
} finally {
	$env:APPDATA = $savedAppData
	Remove-Item Env:HARITA -ErrorAction SilentlyContinue
}
