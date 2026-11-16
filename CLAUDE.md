# Proje notu (Godot 4.7 co-op top-down 2D; Türkçe)

Bu dosya HER mesajda okunur - KISA tutulur (2026-10-10, kullanıcı: "aşırı kota harcıyorsun"). Ayrıntılı geçmiş/tuzaklar `docs/notlar/madde_XX-YY.md`'de (eski CLAUDE.md maddeleri, numaralar AYNI;
kodda/yorumlarda geçen "madde N" atıfları oraya bakar). Tam eski metin: `docs/notlar/CLAUDE_tam_2026-10-10.md`. Bir alana dokunmadan önce SADECE ilgili madde dosyasını oku.
Yeni bir iş bitince ayrıntılı notu ilgili/son `docs/notlar/madde_*.md` dosyasına YENİ MADDE olarak ekle, `docs/notlar/INDEX.md`'ye (en alta) TEK satır ekle; buraya DİZİN YAZMA (CLAUDE.md her mesajda okunur).

## Kota kuralları (kullanıcı isteği 2026-10-10)
- Testler: işin İLGİLİ test dosyalarını koş (`-Filter`); TAM paketi (`run_tests.ps1` filtresiz, ~15 dk) sadece kullanıcı isterse ya da büyük bir partinin sonunda BİR kez. İki test koşusunu aynı anda başlatma (aynı geçici dosyaları paylaşırlar, sahte hata verir).
- Ekran görüntüsü / gerçek pencere doğrulaması sadece görsel işlerde; prototip görselleri az ve küçük.
- Büyük dosyaları baştan sona okuma; grep + ilgili aralık.

## Her işte geçerli kurallar
- **MP iki-yer hatası**: efektler/animasyonlar kasterde üretilir, diğer istemcilere AYRICA (`NetworkManager.broadcast_player_vfx`/`send_player_vfx`, durum/anim adı) gider; biri unutulursa diğer oyuncuda eski/hiç görünmez.
  Tek seferlik karakter FX -> `player.gd _play_and_broadcast_skill_fx(scene)`; dünya konumlu -> mevcut konum yardımcıları + `broadcast_player_vfx` match dalı; karede simüle edilen görsel -> paylaşılan `static func` (ör. `sword_swing_math.gd`);
  yeni animasyon adı -> karakterin `SpriteFrames`'ine de ekle (yoksa uzakta sessizce donar); aksiyon klip önekleri `scripts/char_anim.gd`. Ayrıntı: madde 1-7.
- **Host'tan gelmesi gereken RPC'ye** `if not _from_host(): return` (madde 29/42). Sık Main RPC'si -> `NetworkManager.main_rpc_targets()`.
- **Yaratık sistemi C++'ta** (`gdextension/enemy_world/`; madde 9, `docs/yaratik_yeniden_yazim/PLAN.md` + `ILERLEME.md`): yaratık hareket/AI kuralı = `enemy_world.cpp` + 4 kütüphane derle; her karede "enemies" taraması yazma -> `EnemyQuery.candidates`.
- **Yaratık tiki / uyku** (madde 267, 278): `enemy.gd` uyanıklık koşulları ÜÇ yerde aynı olmalı (`_ew_tick` hızlı yol zinciri, `_ew_hard_active`, `_ew_still_active`); yaratığa her karede işleyen yeni bir zamanlayıcı / durum eklersen `_ew_hard_active`'e koy (yoksa uyku onu atlar); yetenek sayaçlarını (`_cd`...) ya da kalkanı (`item_shield_*`) dışarıdan değiştiren kod önce `_ew_wake()` çağırmalı. Saldırı durumundaki yaratığın karesi C++'ta (`_ew_hold`, madde 286): `_state_duration` yalnız `_ew_hold` değilken "iş" sayılır, uyurken `_ew_dorm_sync` onu da düşer (yeni durum yazan `_enter_state` önce uyuyanı sync eder). Hakem: `tools/fps_micro/proc_ab.ps1 -EnvA EW_DORMANT=0 -EnvB EW_DORMANT=1` (`EW_HOLD=0`, `ENEMY_CPP_DEPTH=0` ilgili eski yolu açar).
- **Harita**: `harita/Harita.tmx`'i kullanıcı Tiled'da düzenler - üzerine yazmadan önce md5 kapısı (aynı betikte). Bake: `tools/bake_harita.gd` + gölge + minimap (hafıza: map-rebake-procedure). Haritaya süs = mevcut tileset sanatı.
- **Hareket eden kod** engel için `GameManager.is_position_blocked_by_walls`; mermi/görüş için `..._by_forest` (madde 27). Görev nesneleri çarpışması "move_blockers" grubu (madde 68).
- **Yeni dükkan/panel** `GameManager.register_blocking_panel(self)` (yoksa yetenek tuşları sızar, madde 31); yeni yetenek girişi `not _skill_keys_blocked()`.
- **Yeni yetenek / silah / FX** çalışma zamanında `load()` ile kaynak okuyorsa ısınma listesini yenile: `tools/gen_fx_warmup_list.ps1` (madde 267; yoksa ilk basışta 10-40 ms takılma). Performans işinde `tools/fps_micro/` (gürültüsüz mikro ölçüm, kullanıcı verisini yalıtır). Bu betikler oyunu kullanıcının GÖRMEDİĞİ ayrı masaüstünde koşar (pencere çıkmaz; görünür pencere `-Visible -AllowWindow` + önce izin). Render değişikliğinin hakemi `tools/fps_micro/proc_ab.ps1` (süreç düzeyi A/B; kopya-katman A/B'si yanıltıyor, madde 272).
- **Denge sabitlerini** değiştirince tüm depoda kopyasını ara (grep) - aynı sayı birden çok dosyada olabilir; ilgili açıklama metinlerini (`characters.gd` + kısa `*_short_desc`, `spiritual_skills.gd`, `weapon_catalog.gd`, `enchant_defs.gd`) ve testleri güncelle. Ayrıca `scripts/balance_log.gd BALANCE_REV`'i artır (madde 75; balans raporu eski dengeyi yeni dengeyle karıştırmasın).
- **CİLA DÖNEMİ (2026-11-06'dan birkaç hafta, kullanıcı kararı)**: yeni özellik / sistem / karakter / silah / bölge önerme ve kendiliğinden ekleme. Kullanıcı yeni özellik isterse kısaca "cila dönemindeyiz" diye hatırlat, yine isterse yap. Öncelik: hata, MP senkronu, FPS, stil rehberine uyum, yarım kalmış sistemleri bitirme ya da silme.
- **Arayüz rengi / yazı / piksel ızgarası**: `docs/stil_rehberi.md` (madde 403). Tek palet `scripts/hud_theme.gd` - kit/ekran dosyasına yeni hex yazma, rol ekle; yazı m5x7 16/32/48 + sayı PixeloidSans Bold 9/18/27; doku 1 sanat px = 3 ekran px.
- Kullanıcı Godot editörünü açık tutabilir: editörde açık bir .tscn'i dışarıdan düzenlersen editör kaydı üzerine yazabilir.
- **DASH YETENEKLERİ E'DE (madde 622, kullanıcı kararı 2026-11-12, KALICI)**: Talon / Elara / Assasin'de dash yeteneği E'dedir (Talon Hamle Vuruşu, Elara Sıvışma, Assasin Şahin Hamlesi); Q = Silah Salvosu / Gerçek Hasar / Gölge Adımı. Kullanıcı bu üçünde "E yeteneğini güçlendir / değiştir" derse DASH'i kastediyor - Q'ya geri taşıma, karıştırma. Evrim kimlikleri yuvaya göre (`talon_e*` = dash, `talon_q*` = salvo...). Kilitleyen test `tests/test_dash_on_e.gd`; ayrıntı + tuzaklar `docs/notlar/madde_161-170.md` madde 622.

## Test
`powershell -ExecutionPolicy Bypass -File tools/enemy_rewrite/run_tests.ps1 -Filter "<dosya>.gd"` (Godot `C:/Users/perva/Desktop/Arşiv/Godot_v4.7.2-stable_win64.exe`). Başarısız bir assert testi yarıda keser ve
temizliği atlar - sonraki testler zincirleme bozulur: İLK hataya bak. Çok oyunculu denetim: `tools/mp_audit/run_audit.ps1 -Mode <...>` (madde 28). Yeni yetenek/efekti iki pencerede HOST OLMAYAN oyuncuyla izle.

## Export / commit
- Kod değişikliği exe'ye yansımaz; Claude KENDİLİĞİNDEN export ALMAZ (kullanıcı Godot'tan kendisi alır) - iş bitince "export almayı unutma" hatırlat.
- Otomatik commit/push YOK; iş bitince commit edilmemiş değişiklik varsa söyle ve push isteyip istemediğini SOR.
- Repo arkadaşla paylaşılıyor (mieys/i-need-to-stay-alive, ikisi de doğrudan master'a push): göreve başlamadan `git fetch` + `git status` (yerel değişiklik yoksa `git pull`); push reddedilirse ASLA `--force`, `git pull` (merge) + gerçek çakışmayı kullanıcıya göster; binary asset (`.png`/ses/`.import`) çakışmasında sor.


## Madde dizini -> `docs/notlar/INDEX.md` (~670 satır, ~63k token: ASLA baştan sona okuma)
- Konu ararken `Grep` ile INDEX.md'de anahtar kelime / `^- 622\.` ara; her satır "özet -> madde dosyası" verir.
- Madde N -> dosya: 1-160 onluk dosyalar (`madde_01-10.md` ... `madde_151-160.md`); 161 ve sonrasının HEPSİ `madde_161-170.md`. Maddeyi `Grep "^## Madde 622\."` ile bulup yalnız o bölümü aralıkla oku.
- Kodda/yorumda `madde N` atfı görürsen önce INDEX.md'de o satırı ara, sonra yalnız o maddeyi oku.
