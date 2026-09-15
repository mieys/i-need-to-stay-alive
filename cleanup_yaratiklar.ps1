# Bu betiği proje kök dizininde (bu dosyanın bulunduğu yerde) PowerShell ile çalıştır:
#   powershell -ExecutionPolicy Bypass -File cleanup_yaratiklar.ps1
# Sadece OYUNDA HIÇ KULLANILMAYAN, doğrulanmış yedek/kaynak dosyaları siler.

$root = $PSScriptRoot
$y = Join-Path $root "visuals\Yaratıklar"

# 1) Tamamen gereksiz üst klasörler (hiçbir sahne bunlara referans vermiyor)
$topLevel = @(
    "Kademe 1","Kademe 2","Kademe 3","Kademe 4","Kademe 5","Kademe 6","Kademe 7",
    "Kademe 8","Kademe 9","Kademe 10","Kademe 11","Kademe 12","Kademe 13","Kademe 14","Kademe 15",
    "Boss Kademe 3","Boss Kademe 6","Boss Kademe 8","Boss Kademe 12","Boss Kademe 15",
    "Final Kademe","Slime +3"
)
foreach ($name in $topLevel) {
    $p = Join-Path $y $name
    if (Test-Path $p) {
        Remove-Item -LiteralPath $p -Recurse -Force
        Write-Host "Silindi: $p"
    }
}

# 2) Benim deneme sırasında oluşan artıklar (proje kökünde)
foreach ($name in @("_delete_boss3","_delete_png_test","_delete_iskelet3")) {
    $p = Join-Path $root $name
    if (Test-Path $p) {
        Remove-Item -LiteralPath $p -Recurse -Force
        Write-Host "Silindi: $p"
    }
}

# 3) "Tüm Yaratıklar" içinde kullanılmayan format klasörleri (PSD, ASEPRITE, Tiled_files/Tiled, Parts, Without_shadow)
$tumYaratiklar = Join-Path $y "Tüm Yaratıklar"
if (Test-Path $tumYaratiklar) {
    $unusedNames = @("PSD","ASEPRITE","Tiled_files","Tiled","Parts","Without_shadow")
    Get-ChildItem -LiteralPath $tumYaratiklar -Recurse -Directory -Force |
        Where-Object { $unusedNames -contains $_.Name } |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object {
            if (Test-Path $_.FullName) {
                Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "Silindi: $($_.FullName)"
            }
        }
}

Write-Host "`nTemizlik tamamlandi. Godot editorunu bir kez kapatip acarsan (ya da Dosya Sistemi panelinde 'Yeniden Tara' yaparsan) degisiklikler yansir."
