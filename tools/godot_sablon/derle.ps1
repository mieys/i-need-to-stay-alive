# KORUMALI EXPORT SABLONU (madde 613 ek 3): PCK sifreleme icin anahtari ICINE GOMULU ozel Godot export sablonu derler.
# Kaynak: resmi godotengine/godot 4.7.2-stable (%LOCALAPPDATA%\Toolchains\godot-4.7.2-src, `git clone --depth 1 --branch 4.7.2-stable`)
# + 3 dosyalik yama (core/core_builders.py, core/object/script_language.h, core/io/file_access_pack.cpp): anahtar exe'de HAM durmaz,
# derleme basina rastgele tohumlu XOR akisiyla maskeli saklanir (hazir "anahtar bulucu" araclari ham 32 bayti tarar).
# Anahtar: C:\Users\<kullanici>\Godot_sablon\anahtar.txt (64 hex; GIT'E GIRMEZ, KAYBETME - kaybolursa sablon + anahtar yeniden uretilir).
# Cikti: C:\Users\<kullanici>\Godot_sablon\windows_{release,debug}_x86_64.exe  (+ .console.exe)
#   .\tools\godot_sablon\derle.ps1                 # yalniz release (oyunculara giden)
#   .\tools\godot_sablon\derle.ps1 -Hedef hepsi    # release + debug
# Stok sablondan farklar: d3d12=no (D3D12 SDK indirmesi gerekirdi; Vulkan yoksa D3D12'ye dusme YOK), accesskit=no, openxr=no.
param([ValidateSet("release", "debug", "hepsi")][string]$Hedef = "release", [int]$Jobs = 8)

$ErrorActionPreference = "Stop"
$tc = Join-Path $env:LOCALAPPDATA "Toolchains"
$src = Join-Path $tc "godot-4.7.2-src"
$py = Join-Path $env:LOCALAPPDATA "Python\pythoncore-3.14-64\python.exe"
$mingw = Get-ChildItem $tc -Directory -Filter "llvm-mingw-*" | Select-Object -First 1
# CIKTI + ANAHTAR AppData ALTINDA OLMAZ: Claude uygulamasi MSIX paketli, %LOCALAPPDATA% altina YENI yazdigi dosyalar kullanicinin kendi
# programlarina (Godot editoru) gorunmez (hafiza: reference-claude-appdata-virtualization). Bu yuzden C:\Users\<kullanici>\Godot_sablon\.
$outDir = Join-Path $env:USERPROFILE "Godot_sablon"
$keyFile = Join-Path $outDir "anahtar.txt"
$oldKey = Join-Path $tc "godot_sifre\anahtar.txt"   # ilk derleme anahtari oraya yazmisti (sanallastirilmis yer): ayni anahtari koru

if (-not (Test-Path $src)) { throw "Godot kaynagi yok: $src" }
if (-not (Test-Path $py)) { throw "SCons icin Python yok: $py" }
if ($null -eq $mingw) { throw "llvm-mingw yok: $tc" }
New-Item -ItemType Directory -Force $outDir | Out-Null
if (-not (Test-Path $keyFile) -and (Test-Path $oldKey)) { Copy-Item $oldKey $keyFile }

if (-not (Test-Path $keyFile)) {
	$bytes = New-Object byte[] 32
	$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
	$rng.GetBytes($bytes)
	$rng.Dispose()
	($bytes | ForEach-Object { $_.ToString("x2") }) -join "" | Set-Content -Path $keyFile -Encoding ascii -NoNewline
	"Yeni anahtar uretildi: $keyFile"
}
$key = (Get-Content $keyFile -Raw).Trim()
if ($key.Length -ne 64) { throw "Anahtar 64 hex olmali: $keyFile" }

$env:SCRIPT_AES256_ENCRYPTION_KEY = $key
$env:PATH = (Join-Path $mingw.FullName "bin") + ";" + $env:PATH

$targets = @()
if ($Hedef -in "release", "hepsi") { $targets += "template_release" }
if ($Hedef -in "debug", "hepsi") { $targets += "template_debug" }

foreach ($t in $targets) {
	$kind = $t -replace "template_", ""
	$log = Join-Path $outDir "derleme_$kind.log"
	"[$(Get-Date -Format HH:mm:ss)] $t derleniyor (gunluk: $log)"
	$args = @("-m", "SCons", "platform=windows", "use_mingw=yes", "use_llvm=yes", "arch=x86_64", "target=$t", "production=yes",
		"d3d12=no", "accesskit=no", "openxr=no", "-j$Jobs")
	$p = Start-Process -FilePath $py -ArgumentList $args -WorkingDirectory $src -NoNewWindow -Wait -PassThru `
		-RedirectStandardOutput $log -RedirectStandardError ($log + ".err")
	if ($p.ExitCode -ne 0) { throw "$t derlemesi basarisiz (cikis $($p.ExitCode)); bkz $log ve $log.err" }
	foreach ($variant in "", ".console") {
		$built = Join-Path $src "bin\godot.windows.$t.x86_64.llvm$variant.exe"   # use_llvm=yes dosya adina ".llvm" ekler
		if (Test-Path $built) {
			Copy-Item $built (Join-Path $outDir "windows_${kind}_x86_64$variant.exe") -Force
			"  -> windows_${kind}_x86_64$variant.exe ($([math]::Round((Get-Item $built).Length/1MB,1)) MB)"
		}
	}
}
"[$(Get-Date -Format HH:mm:ss)] bitti. Sablonlar: $outDir"
