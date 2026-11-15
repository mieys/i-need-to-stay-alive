# Kaynak kod koruması (şifreli PCK) - madde 613 ek 3

**Sorun:** Stok export'ta betikler `.pck` içinde açık (sıkıştırılmış bytecode); GDRE gibi araçlar tek tıkla tam GDScript'e çevirir.
**Çözüm:** PCK'yı AES-256 ile şifrele. Godot bunun için anahtarı **şablonun (export template) içine gömmeni** ister, yani özel şablon gerekir.

## Parçalar

| Ne | Nerede |
|---|---|
| Özel Godot 4.7.2 kaynağı (3 dosyalık yama) | `%LOCALAPPDATA%\Toolchains\godot-4.7.2-src` (yalnız Claude'un kabuğunda görünür) |
| Derleme betiği | `tools/godot_sablon/derle.ps1` |
| Anahtar (64 hex) | `C:\Users\perva\Godot_sablon\anahtar.txt` - **GİT'E GİRMEZ, yedekle**; kaybolursa şablon + anahtar yeniden üretilir (eski exe'ler yine eski anahtarla açılır) |
| Şablonlar | `C:\Users\perva\Godot_sablon\windows_release_x86_64.exe` (+ `.console.exe`), `windows_debug_x86_64.exe` |
| Export ayarı | `export_presets.cfg` > **"Windows Desktop (Korumali)"** (şifreleme + özel şablon yolu) |
| Anahtarın editördeki yeri | `.godot/export_credentials.cfg` (git'e girmez; editör bunu kendi yazar) |

Yama: anahtar exe'de ham 32 bayt olarak durmaz; derleme başına rastgele tohumlu XOR akışıyla maskeli saklanır, çalışırken çözülür
(`script_encryption_key_resolve`). Hazır "anahtar bulucu" araçları ham 32 baytı taradığı için bunları atlatır.

## Export (kullanıcı alır, Claude almaz)

1. Godot'u KAPATIP yeniden aç (yeni ayar + anahtar yüklensin).
2. Proje > Dışa Aktar > **Windows Desktop (Korumali)** > "Dışa Aktar" (Release; "Debug ile dışa aktar" işaretliyse debug şablonu kullanılır).
3. Çıktı normal exe ile aynı yere (`../../pc versiyon/Potpourri.exe`) gider; yanındaki DLL'ler aynen kalır.
4. `tools/dagitim/paketle.ps1` artık şifresiz exe'yi **reddeder** (`res://scripts/game_manager.gd` düz yazı görünüyorsa durur; bilerek `-KorumasizIzin`).

Komut satırından: `powershell -File tools/godot_sablon/export_korumali.ps1`.

## Bilinen sınırlar (dürüst olalım)

- Mutlak koruma yok: exe oyuncunun makinesinde. Hedef "tek tıkla GDRE / hazır anahtar bulucu" seviyesini kapatıp çıtayı yükseltmek.
  Belleği izleyen (çalışırken anahtarı okuyan) biri yine çıkarabilir.
- **Android APK** henüz korumasız (APK'nın kendi şablonunu aynı anahtarla derlemek ayrı iş).
- Şablonda D3D12 sürücüsü YOK (Vulkan'ı olmayan eski GPU'larda D3D12'ye düşme yok), AccessKit + OpenXR yok. Oyun Vulkan kullanıyor.
- Godot sürümü değişirse (4.7.3...) şablon yeniden derlenmeli: `tools/godot_sablon/derle.ps1` (kaynağı yeni etikete alıp aynı 3 yamayı uygula).
- `override.cfg` / `--main-pack` hâlâ `security_guard.scan_install` ile yakalanır (ilerleme kaydı kapanır).
