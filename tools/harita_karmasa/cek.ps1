# HARİTA KARMAŞA ÖLÇÜMÜ (madde 529): yüzey + zindan haritalarından aynı ayarla dünya görüntüsü (HUD gizli) alır, ölçer, karşılaştırma sayfası yapar.
# Kullanım: powershell -ExecutionPolicy Bypass -File tools/harita_karmasa/cek.ps1 [-Label once] [-Maps "ana,bataklik"] [-Env "A=1;B=2"]
# Çıktı tools/harita_karmasa/out/<Label>/ : <harita>_p<n>_dunya.png (+ _dunya2: 0,45 sn sonra, hareket), olcum.txt, karsilastirma.png.
# Gizli masaüstünde koşar (pencere çıkmaz), APPDATA yalıtılı. Noktalar noktalar.py'den (sabit tohum: önce/sonra aynı yerler).
param([string]$Label = "son", [string]$Maps = "", [string]$Env = "")
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$proj = (Resolve-Path "$here\..\..").Path
$godot = "C:\Users\perva\Desktop\Ar$([char]0x015F)iv\Godot_v4.7.2-stable_win64.exe"
. "$proj\tools\fps_micro\hidden_launch.ps1"
$out = "$here\out\$Label"
New-Item -ItemType Directory -Force $out, "$here\out\appdata" | Out-Null
$env:APPDATA = "$here\out\appdata"
foreach ($kv in $Env.Split(";", [StringSplitOptions]::RemoveEmptyEntries)) { $p = $kv.Split("=", 2); Set-Item "env:$($p[0])" $p[1] }
$want = $Maps.Split(",", [StringSplitOptions]::RemoveEmptyEntries)
foreach ($l in (python -I "$here\noktalar.py" "$proj")) {
	$kv = $l.Split("=", 2)
	if ($want.Count -gt 0 -and $want -notcontains $kv[0]) { continue }
	$env:HARITA = $kv[0]
	$env:CAP_NOKTALAR = $kv[1]
	$env:CAP_OUT = $out
	$env:CAP_GIZLE = "dunya:HUD|dunya2:HUD"
	$code = Invoke-GodotHidden -Exe $godot -ArgLine "--path `"$proj`" --log-file `"$out\$($kv[0]).log`" -s res://tools/harita_secimi/harita_tur.gd" -WorkDir $proj -TimeoutSec 300
	Write-Host "$($kv[0]) -> $code"
}
python -I "$here\olc.py" "$out" | Tee-Object "$out\olcum.txt"
python -I "$here\sayfa.py" "$out" "$out\karsilastirma.png"
