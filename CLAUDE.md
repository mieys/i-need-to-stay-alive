# Proje notu (Godot 4.7 co-op top-down 2D; Türkçe)

Bu dosya HER mesajda okunur - KISA tutulur (2026-10-10, kullanıcı: "aşırı kota harcıyorsun"). Ayrıntılı geçmiş/tuzaklar `docs/notlar/madde_XX-YY.md`'de (eski CLAUDE.md maddeleri, numaralar AYNI;
kodda/yorumlarda geçen "madde N" atıfları oraya bakar). Tam eski metin: `docs/notlar/CLAUDE_tam_2026-10-10.md`. Bir alana dokunmadan önce SADECE ilgili madde dosyasını oku.
Yeni bir iş bitince ayrıntılı notu ilgili/son `docs/notlar/madde_*.md` dosyasına YENİ MADDE olarak ekle, buraya sadece dizine TEK satır ekle.

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
- **Harita**: `harita/Harita.tmx`'i kullanıcı Tiled'da düzenler - üzerine yazmadan önce md5 kapısı (aynı betikte). Bake: `tools/bake_harita.gd` + gölge + minimap (hafıza: map-rebake-procedure). Haritaya süs = mevcut tileset sanatı.
- **Hareket eden kod** engel için `GameManager.is_position_blocked_by_walls`; mermi/görüş için `..._by_forest` (madde 27). Görev nesneleri çarpışması "move_blockers" grubu (madde 68).
- **Yeni dükkan/panel** `GameManager.register_blocking_panel(self)` (yoksa yetenek tuşları sızar, madde 31); yeni yetenek girişi `not _skill_keys_blocked()`.
- **Denge sabitlerini** değiştirince tüm depoda kopyasını ara (grep) - aynı sayı birden çok dosyada olabilir; ilgili açıklama metinlerini (`characters.gd`, `weapon_catalog.gd`, `enchant_defs.gd`) ve testleri güncelle. Ayrıca `scripts/balance_log.gd BALANCE_REV`'i artır (madde 75; balans raporu eski dengeyi yeni dengeyle karıştırmasın).
- Kullanıcı Godot editörünü açık tutabilir: editörde açık bir .tscn'i dışarıdan düzenlersen editör kaydı üzerine yazabilir.

## Test
`powershell -ExecutionPolicy Bypass -File tools/enemy_rewrite/run_tests.ps1 -Filter "<dosya>.gd"` (Godot `C:/Users/perva/Desktop/Arşiv/Godot_v4.7.2-stable_win64.exe`). Başarısız bir assert testi yarıda keser ve
temizliği atlar - sonraki testler zincirleme bozulur: İLK hataya bak. Çok oyunculu denetim: `tools/mp_audit/run_audit.ps1 -Mode <...>` (madde 28). Yeni yetenek/efekti iki pencerede HOST OLMAYAN oyuncuyla izle.

## Export / commit
- Kod değişikliği exe'ye yansımaz; Claude KENDİLİĞİNDEN export ALMAZ (kullanıcı Godot'tan kendisi alır) - iş bitince "export almayı unutma" hatırlat.
- Otomatik commit/push YOK; iş bitince commit edilmemiş değişiklik varsa söyle ve push isteyip istemediğini SOR.
- Repo arkadaşla paylaşılıyor (mieys/i-need-to-stay-alive, ikisi de doğrudan master'a push): göreve başlamadan `git fetch` + `git status` (yerel değişiklik yoksa `git pull`); push reddedilirse ASLA `--force`, `git pull` (merge) + gerçek çakışmayı kullanıcıya göster; binary asset (`.png`/ses/`.import`) çakışmasında sor.

## Madde dizini (ayrıntı: belirtilen dosya)
- 1. Tek seferlik, karaktere bağlı bir FX sahnesi mi? -> `docs/notlar/madde_01-10.md`
- 2. Dünya konumunda sabit duran bir efekt mi? -> `docs/notlar/madde_01-10.md`
- 3. Sürekli/karede-karede simüle edilen bir görsel mi? -> `docs/notlar/madde_01-10.md`
- 4. Yeni bir animasyon adı mı ekliyorsun? -> `docs/notlar/madde_01-10.md`
- 5. Sürekli döngüde oynaması gereken bir animasyon mu? -> `docs/notlar/madde_01-10.md`
- 6. Klip ADI kuralları artık TEK yerde: scripts/char_anim.gd. -> `docs/notlar/madde_01-10.md`
- 7. Gece ışığı (gün-gece sistemi, 2026-09-25). -> `docs/notlar/madde_01-10.md`
- 8. İnternet odası (Epic Online Services, 2026-10-02). -> `docs/notlar/madde_01-10.md`
- 9. DEVAM EDEN BÜYÜK İŞ: yaratık sistemi yeniden yazımı (2026-10-03'ten beri). -> `docs/notlar/madde_01-10.md`
- 10. Zafer + Sonsuz Mod + koşu rekorları/başarımlar (2026-10-05). -> `docs/notlar/madde_01-10.md`
- 11. Boss barı (2026-10-05). -> `docs/notlar/madde_11-20.md`
- 12. Kamera sarsıntısı (2026-10-05). -> `docs/notlar/madde_11-20.md`
- 13. Kademe başlangıcı, Romen rakamı, kuru kafa göstergesi, kopya silahları (2026-10-05). -> `docs/notlar/madde_11-20.md`
- 14. Telefon sohbet/grup dokunma kuralları (2026-10-05). -> `docs/notlar/madde_11-20.md`
- 15. Geri katılım anlık görüntüsü, koşu kaydı, telefon pencere ölçeği, kapı taraması (2026-10-05 analiz düzeltmeleri). -> `docs/notlar/madde_11-20.md`
- 16. Yükleme ekranı takılması (2026-10-05). -> `docs/notlar/madde_11-20.md`
- 17. Telefon kaydırma "başa dönüyor" (2026-10-05). -> `docs/notlar/madde_11-20.md`
- 18. Takılma kaydedici + günlük koruması (2026-10-06). -> `docs/notlar/madde_11-20.md`
- 19. Kademe 3 denge yumuşatması (2026-10-06). -> `docs/notlar/madde_11-20.md`
- 20. Market donması + çökmesi + telefon market kaydırması (2026-10-06). -> `docs/notlar/madde_11-20.md`
- 21. Efsunlar kapalı, kalıcı ölüden kalkış, minimapte ölüler, Vampir/ork/kademe kapısı ayarları (2026-10-06/07). -> `docs/notlar/madde_21-30.md`
- 22. Sandık kuralları: normal = sırayla, elit = herkese epik eşya (2026-10-07). -> `docs/notlar/madde_21-30.md`
- 23. Demirci dükkanı (silah + kalkan satıcısı) ve harita yeniden bake (2026-10-07). -> `docs/notlar/madde_21-30.md`
- 24. Silah parçacığı (demirci dükkanında silah almak için para birimi, 2026-10-08). -> `docs/notlar/madde_21-30.md`
- 25. Derinlik / y-sıralama: karakter nesnenin arkasındayken altında, önündeyken üstünde (2026-10-08). -> `docs/notlar/madde_21-30.md`
- 26. Assasin pasifi + Q bekleme, Vampir Q kalkan bedeli (2026-10-08). -> `docs/notlar/madde_21-30.md`
- 27. Collision "herşey için yeniden hesaplandı": su + bina tabanı + ağaç gövdesi + maden + düşman üssü, oyuncu VE yaratıklar (2026-10-0… -> `docs/notlar/madde_21-30.md`
- 28. Çok oyunculu senkron denetimi aracı + bulgular (2026-10-08). -> `docs/notlar/madde_21-30.md`
- 29. Çok oyunculu sağlamlaştırma (2026-10-08, madde 28 bulgularının düzeltmesi). -> `docs/notlar/madde_21-30.md`
- 30. HOST DEVRİ (2026-10-08, kullanıcı isteği: "host çıkınca host devri de olsun"). -> `docs/notlar/madde_21-30.md`
- 31. Dükkan/envanter açıkken yetenek tuşları oyuna gitmez (2026-10-08). -> `docs/notlar/madde_31-40.md`
- 32. Cesedin yanında bekleyen arkadaş, diriltme hakkı sayacını hızlandırır (2026-10-08). -> `docs/notlar/madde_31-40.md`
- 33. Sandık: önce altın sonra kart + kart inince ödül sesi; satış: ikon parçalanıp altına döner (2026-10-08). -> `docs/notlar/madde_31-40.md`
- 34. Kalıcı silah özellikleri (efsun) + demirci geliştirmeleri (2026-10-08). -> `docs/notlar/madde_31-40.md`
- 35. Silah kademe göstergesi artık KONTÜR (2026-10-08). -> `docs/notlar/madde_31-40.md`
- 36. Dükkan pencereleri grup panelinin soluna sığar (2026-10-08). -> `docs/notlar/madde_31-40.md`
- 37. Ateş/Buz Asası alevi asanın BAKIŞINA bağlı (2026-10-08). -> `docs/notlar/madde_31-40.md`
- 38. Matthew'in evcil hayvanı artık KÖPEK + yeni takip/savaş yapay zekâsı (2026-10-08). -> `docs/notlar/madde_31-40.md`
- 39. Bosslar elit oldu, boss/Final/zafer geçici KAPALI (2026-10-08). -> `docs/notlar/madde_31-40.md`
- 40. Kademe 3 bossu: MINOTAUR (2026-10-08). -> `docs/notlar/madde_31-40.md`
- 41. Kademe 5 bossu: YERALTI CANAVARI (2026-10-09). -> `docs/notlar/madde_41-50.md`
- 42. Boss çok oyunculu senkron denetimi + RPC güvenliği (2026-10-09, Minotaur + Yeraltı Canavarı sonrası "senkronda eksik var mı" sorus… -> `docs/notlar/madde_41-50.md`
- 43. Boss ve müttefik can/kalkan SAYILARI (2026-10-09). -> `docs/notlar/madde_41-50.md`
- 44. Silah satışında parçacık iadesi (2026-10-09). -> `docs/notlar/madde_41-50.md`
- 45. Yaratık derinliği: ağaç/ev arkasında örtülme, kendi aralarında sıra kapanışı, kare başı çizim sırası koruması (2026-10-09). -> `docs/notlar/madde_41-50.md`
- 46. Yaratıklar/oyuncular %15, bosslar %20 küçüldü (2026-10-09). -> `docs/notlar/madde_41-50.md`
- 47. Orman dokusu: duvar kenarı/harita kenarı ağaç + çalı + çiçek + mantar (2026-10-09, SADECE Harita.tmx değişti - oyun sahnesi HENÜZ … -> `docs/notlar/madde_41-50.md`
- 48. Vadi köprüsü: altından geçen örtülür, üstünden geçen üstte kalır + sağ uç açıldı (2026-10-09). -> `docs/notlar/madde_41-50.md`
- 49. Saklanma çalısı PROTOTİPLERİ (2026-10-09, sadece görsel; mekanik YOK). -> `docs/notlar/madde_41-50.md`
- 50. Saklanma çalılığı Harita.tmx'te (2026-10-09; oyun sahnesi HENÜZ bake EDİLMEDİ, görünmezlik mekaniği YOK). -> `docs/notlar/madde_41-50.md`
- 51. Ağaçlar görüşü (sis) keser, taç dahil (2026-10-09). -> `docs/notlar/madde_51-60.md`
- 52. Saklanma çalılığı MEKANİĞİ + köşe dışı çalılıklar (2026-10-09). -> `docs/notlar/madde_51-60.md`
- 53. Geniş çalılar rüzgarda bölünmesin (2026-10-09). -> `docs/notlar/madde_51-60.md`
- 54. Köprü: güvertede korkuluk + altında tam örtü (2026-10-09, madde 48'in devamı). -> `docs/notlar/madde_51-60.md`
- 55. Kenar bekçileri / yaratık kampları (2026-10-09). -> `docs/notlar/madde_51-60.md`
- 56. Çiçekler çalılar gibi sallanır (2026-10-09). -> `docs/notlar/madde_51-60.md`
- 57. Orta bölge ağaç seyreltme (2026-10-09). -> `docs/notlar/madde_51-60.md`
- 58. Kademe 8 bossu: BALKABAĞI KAFA (2026-10-09). -> `docs/notlar/madde_51-60.md`
- 59. Kademe 12 bossu: WENDİGO (2026-10-09). -> `docs/notlar/madde_51-60.md`
- 60. Kademe 15 bossu: BANSHEE (2026-10-09). -> `docs/notlar/madde_51-60.md`
- 61. FİNAL bossu: UÇAN ŞEYTAN + Final akışı (2026-10-09). -> `docs/notlar/madde_61-70.md`
- 62. Toplu istek: 13 madde (2026-10-10). -> `docs/notlar/madde_61-70.md`
- 63. Saklanma çalılığı: LoL tarzı, kare kare boyanmış bütün çalılık (2026-10-10). -> `docs/notlar/madde_61-70.md`
- 64. Denge turu: kalkan delme, can yenilenmesi kartı, Tabanca/Yay, Minotaur boynuzu, Havai Fişek, Buz Asası (2026-10-10). -> `docs/notlar/madde_61-70.md`
- 65. Yeraltı Canavarı çatlakları SPRITE oldu (FPS) + Ateş Asası buff (2026-10-10). -> `docs/notlar/madde_61-70.md`
- 66. Toplu istek: Kalkan Bağı, Şovalye E, parçacık, şans/kart kademesi, Tank, Yansıtan Kubbe, Elara, Minotaur (2026-10-10). -> `docs/notlar/madde_61-70.md`
- 67. Toplu istek 2 (2026-10-10): Yeraltı Canavarı, çalılık görünümü, kamera iptali, derinlik, görev ödülü, diriltme. -> `docs/notlar/madde_61-70.md`
- 68. Toplu istek 3 (2026-10-10): yeni görev ağacı, ağaç/konvoy çarpışma + derinlik, konvoy hızı, grup barları, minimap, çalıdan saldırı… -> `docs/notlar/madde_61-70.md`
- 69. Toplu istek 4 (2026-10-10): yeni eşyalar, 3 satırlı satıcı, sıvışma sınırı, Melek işareti, Talon zinciri, Elara titremesi, silah s… -> `docs/notlar/madde_61-70.md`
- 70. BÜYÜCÜ BUFF (2026-10-10, kullanıcı: "büyücü çok güçsüz diye kimse oynamıyor, neden?" -> analizdeki önerilerin HEPSİ onaylandı). -> `docs/notlar/madde_61-70.md`
- 71. Yeraltı Canavarı asidi küçüldü + seyreldi (2026-10-11). -> `docs/notlar/madde_61-70.md`
- 72. LOBİ SİSTEMİ: oda listesi, şifre, oyuncu sınırı, oda lobisi, karakter seçimi aşaması (2026-10-11). -> `docs/notlar/madde_61-70.md`
- 73. Silah özellikleri silah koduna taşındı (scripts/weapon_traits/) + kopyaya işlemiyordu, Ateş Nefesi, parçacık %1, can çalma 2/4/6/8 + 2 can, yaratık hasarı x0,8 (2026-10-11). -> `docs/notlar/madde_61-70.md`
- 74. Can yenilenmesi eşyaları x3, kopya görevi (x30 can/kalkan, %80 az hasar, ekip), eksik statlar + can çalma ikonu, Ateş Asası sesi, grup paneli sayıları (2026-10-11). -> `docs/notlar/madde_61-70.md`
- 75. BALANS TELEMETRİSİ: koşu kaydı (jsonl) + host'ta toplama + `tools/balans_rapor.ps1` raporu (2026-10-11). -> `docs/notlar/madde_71-80.md`
- 76. Yağmur + akarsu sesi: dikişsiz OGG döngüler, akarsu suya uzaklığa göre (2026-10-11). -> `docs/notlar/madde_71-80.md`
- 77. Saldırı hızı üst sınırı %600; aşan kısım canlı 0.5 saldırı gücü/% (kalıcı değil) (2026-10-11). -> `docs/notlar/madde_71-80.md`
- 78. Necromancer evrimleri (Q/E/R) + ulti rework: kalıcı pasif kafatası, R'de büyür; temel değerler kötüleşti (2026-10-11). -> `docs/notlar/madde_71-80.md`
- 79. Melek ulti rework: 2 sn kanatlı havalanma, itme+5 sn korku, boss %80 yavaşlatma, %100 AP can+kalkan, yeni R evrimleri (2026-10-11). -> `docs/notlar/madde_71-80.md`
- 80. Yaratık hasarı x0,8 iptal + can çalma 1 can + Balkabağı güçlendirme: atılış, hızlı toplar, faz 2 (2026-10-11). -> `docs/notlar/madde_71-80.md`
- 81. Level atlama satırı "Yüzen Kapsül" (oval, ince tier kenarı, gölge, yuvasız ikon) + seçme sesi prototipleri (2026-10-11). -> `docs/notlar/madde_81-90.md`
- 82. Level ekranı + kart seçme sesleri masaüstü dosyalarıyla değiştirildi (2026-10-11). -> `docs/notlar/madde_81-90.md`
- 83. Çiçek bölünmesi düzeltmesi (komşu verisi + grup temas eğilmesi) + ağaçlar görüşü kesmez (TREES_BLOCK_VISION=false) (2026-10-11). -> `docs/notlar/madde_81-90.md`
- 84. Seçim sesi masaüstü secim_smooth_uzatilmis.wav ile değiştirildi, sönümlü (2026-10-11). -> `docs/notlar/madde_81-90.md`
- 85. Collision analizi: su hayalet hücreler (145 çimen karosu + 362 örtülü), 10 px yoklama, orman düşük dolu karolar; düzeltme önerisi (2026-10-11). -> `docs/notlar/madde_81-90.md`
- 86. Su collision düzeltmesi (görünür su), engele takılınca kayma (wall_slide.gd), elit can barı + yıldız (elite_bar.gd) (2026-10-11). -> `docs/notlar/madde_81-90.md`
- 87. Kopya yaratık API'si, bağlantı olay günlüğü (net_log.txt), hayalet kukla düzeltmesi (2026-10-12). -> `docs/notlar/madde_81-90.md`
- 88. Şovalye pasif rework Dirençli Duruş (%40 altı %20 az hasar) + 4 efekt prototipi (2026-10-12). -> `docs/notlar/madde_81-90.md`
- 89. DENEME: silah sınırı 3 + silah hasarı x1,5 (yakın dövüş x2,1) (2026-10-12). -> `docs/notlar/madde_81-90.md`
- 90. Ateş Asası ekran kaplaması (A+B+C) + Tüftüf efekt bütçesi (2026-10-12). -> `docs/notlar/madde_81-90.md`
