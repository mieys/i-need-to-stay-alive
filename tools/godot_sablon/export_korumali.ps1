# Korumali (sifreli PCK) Windows export - komut satiri. KULLANICI calistirir (CLAUDE.md: Claude kendiliginden export almaz).
#   powershell -ExecutionPolicy Bypass -File tools/godot_sablon/export_korumali.ps1            # preset'in kendi export_path'ine
#   ... -Cikti "C:\yol\Potpourri.exe"   ... -Debug (debug sablonla)
# Anahtar C:\Users\<kullanici>\Godot_sablon\anahtar.txt'den yalniz bu surecin ortamina (GODOT_SCRIPT_ENCRYPTION_KEY) konur.
# Godot editoru acikken de calisir ama import onbellegi cakisabilir: en temizi editoru kapatmak. Madde 613 ek 3. Dosya ASCII (PS 5.1).
param(
  [string]$Preset = "Windows Desktop (Korumali)",
  [string]$Cikti = "",
  [string]$Godot = "",
  [switch]$Debug
)
$ErrorActionPreference = "Stop"
$kok = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$anahtar = Join-Path $env:USERPROFILE "Godot_sablon\anahtar.txt"
if (-not (Test-Path -LiteralPath $anahtar)) { throw "Anahtar yok: $anahtar (once tools/godot_sablon/derle.ps1)" }
$sablon = Join-Path $env:USERPROFILE ("Godot_sablon\windows_" + $(if ($Debug) { "debug" } else { "release" }) + "_x86_64.exe")
if (-not (Test-Path -LiteralPath $sablon)) { throw "Sablon yok: $sablon (once tools/godot_sablon/derle.ps1)" }

if (-not $Godot) {
  $arsiv = "$env:USERPROFILE\Desktop\Ar" + [char]0x015F + "iv\Godot_v4.7.2-stable_win64.exe"   # testlerin kullandigi (run_tests.ps1)
  $adaylar = @($arsiv, "$env:USERPROFILE\.ziva\engines\godot\4.7.2\Godot.exe")
  $Godot = $adaylar | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $Godot) { throw "Godot editoru bulunamadi; -Godot <yol> ver." }

$env:GODOT_SCRIPT_ENCRYPTION_KEY = (Get-Content -LiteralPath $anahtar -Raw).Trim()
$mod = if ($Debug) { "--export-debug" } else { "--export-release" }
$ek = @(); if ($Cikti) { $ek += $Cikti }
Write-Host ("Godot: " + $Godot)
Write-Host ("Preset: " + $Preset + "  (" + $(if ($Debug) { "debug" } else { "release" }) + " sablon)")
& $Godot --headless --path $kok $mod $Preset @ek
if ($LASTEXITCODE -ne 0) { throw ("export basarisiz (cikis " + $LASTEXITCODE + ")") }
Write-Host "Export tamam. Dagitim icin: tools/dagitim/paketle.ps1 (korumasiz exe'yi reddeder)." -ForegroundColor Green
