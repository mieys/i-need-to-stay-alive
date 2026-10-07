# Yaratık sistemi yeniden yazımı - İLERLEME

> Plan: `PLAN.md`. Her oturumun SONUNDA en üste yeni bir kayıt ekle (en yeni üstte). "Şu an" bölümünü her zaman güncel
> tut - bir sonraki oturum (başka hesap olabilir) SADECE bunu okuyarak devam edebilmeli. Yarım kalan iş varsa tam olarak
> hangi dosyada, hangi fonksiyonda kaldığını yaz; doğrulanmamış şeyi "doğrulandı" diye yazma.

## Şu an

- **EN GÜNCEL (2026-10-03, 07:04 sonrası - kota kesintisi sonrası doğrulandı):** Eski GDScript host simülasyonu SİLİNDİ,
  istemci kuklaları da C++'ta (ayrıntı: "Oturum kayıtları"nın en üstündeki iki kayıt). Aşağıdaki "7. bölüm sonu"
  maddesindeki "SIRADAKİ (2) eski yolu silmek" ARTIK YAPILDI - o madde tarihçedir. Son durum:
  tam paket 523 testten 522'si geçiyor + kalan tek hata (gerçek harita yol bulma) düzeltildi (köprü damgası, aşağıda);
  köprüyü elle adımlayan testler 49/49, compile 307/307, LAN MP + **Epic MP** geçti.
  **SIRADAKİ (kullanıcı kararı/izni):** (1) ~~commit + push~~ YAPILDI: `cf6c560` master'a push edildi (2026-10-03).
  `git stash list`'teki "eski host yolu silinmeden ONCE" yedeği artık gereksiz (kullanıcı isterse silinir). (2) Telefonda FPS (kullanıcı release APK alır).
  (3) Şovalye Q adı ("Kışkırtma" ama artık sadece kalkan yeniliyor) - kullanıcıya soruldu, cevap bekleniyor.
- **7. bölüm sonu (2026-10-03 sabah) - YENİDEN YAZIM FİİLEN TAMAM, YENİ YOL VARSAYILAN:**
  - `USE_ENEMY_WORLD = true` (kullanıcı oynadı: "FPS mükemmeldi"). Aşama 0-4 + Aşama 5'in MP ve test maddeleri TAMAM.
    Bu bölümde: grup taramaları (`EnemyQuery.candidates`), y-sıralaması + minimap C++'ta, görev kopyası itilmesi,
    4 kütüphane son kaynakla (05:18-05:26), tam paket + MP + gerçek oyun testleri yeni varsayılanla (ayrıntı aşağıda
    "7. bölüm"), davranış testleri `tests/test_enemy_world.gd`'de, Android export düzeltildi (JDK/SDK `C:\Users\perva\Android`).
  - **SIRADAKİ (kullanıcı kararı/izni):** (1) commit + push (hiçbiri yapılmadı; değişiklikler diskte). (2) Eski HOST
    simülasyon dalını silmek: denendi, Claude Code otomatik izin denetleyicisi "geri döndürülemez yerel silme" diye ENGELLEDİ
    - kullanıcı onaylarsa / commit sonrası yapılacak. Hazırlık: güvenlik anlık görüntüsü `git stash list` -> "Yaratik
    yeniden yazimi - eski host yolu silinmeden ONCE (2026-10-03)" (izlenen dosyalar; çalışma ağacı değişmedi - commit
    edilince bu stash silinebilir). Plan: enemy.gd `_physics_process` içindeki `if not is_dead:` bloğunu (o anki satır
    ~4409-4817: canlı yaratık host AI/hareket/itilme/saldırı) "kaydı yoksa `_ew_try_register()` dene, olmazsa uyar" ile
    değiştir; sonra sadece o bloğun kullandığı yardımcıları (referans taraması ile) sil; `enemy_world_config` anahtarını
    "eklenti var mı"ya indir; eski dalı adım adım koşan birim testlerini (tests/test_enemy_pathing vb.) kaldır/çevir.
    DİKKAT (PLAN Aşama 5 notu): silinince Web ön ayarı / Android armv7 / eklenti yüklenemezse yaratıklar hareket etmez.
    İstemci kukla dalı, ölüm dalı, `get_enemies_near` eski ızgarası, sis/silah GDScript taramaları SİLİNMEZ (istemci).
    (3) Telefonda FPS (kullanıcı release APK alır).- **GÜNCEL ÖZET (2026-10-03, aynı oturumun sonu):** Aşama 0-4 TAMAM, Aşama 5'ten çok oyunculu iki süreçli test + proje
  test paketi (iki yolda da regresyon yok) TAMAM. Pencereli gerçek oyunda yeni yol: 1000 yaratık + 3 silah 132 FPS
  (eski yol aynı sahnede ~7 FPS), 300 yaratıkta eski 24 / yeni 141 FPS (kullanıcı izledi). Varsayılan HÂLÂ KAPALI.
  Kalan: kullanıcı onayıyla varsayılanı açmak -> eski yolu silmek, Android telefonda deneme, küçük teknik işler (en alttaki
  "KALAN" maddesi). Aşağıdaki "ÖZET (2. oturum sonu)" ve sonrası tarihçe.
  Kota kesintisinden sonra (aynı gün, yeni oturum) son kontrol tamamlandı: `compile_check` 306/306 OK,
  `test_world_behaviors.gd` 26/26 PASS (son derlenen kütüphaneyle).
- **2026-10-03 7. bölüm (kullanıcı: "her şey tamamlanana kadar devam et") - Aşama 2 grup taramaları:**
  - Yeni `scripts/enemy_world/enemy_query.gd` `candidates(tree, merkez, yarıçap)`: yeni yolda C++ `query_points` + görev
    kopyaları (köprünün `enemies_near`'ı), eski yolda / istemcide / sınırsız yarıçapta tüm "enemies" grubu. Dönen dizi ÜST
    KÜME - çağıranların kendi süzgeçleri (ölü, mesafe, sis) AYNEN kaldı, yani sonuç değişmez. `BODY_PAD` 140 = gövde payı.
  - Dönüştürülen her-kare / sık taramalar: weapon.gd (yakın dövüş ışını, Buz Asası + rastgele havuz, Tüftüf, zincir
    sıçraması), remote_player.gd (kozmetik nişan x3), player.gd `_block_movement_into_enemies` (her fizik karesi), minimap
    (görünen daire + 320 px + bosslar ayrıca), golem/iskelet/hortlak/Matthew evcil hayvanları, totemler, kasırga, tüy
    fırtınası, kara delik (çekim: merkez `c - drag`), sarmaşık, arı muhafızı, yarasa sürüsü, görev ağacı. Dokunulmayanlar:
    yetenek BAŞLATMA anındaki tek seferlik taramalar (player.gd ~20, olay başına bir kez), `creature_blood` (ölmekte
    olanları da arıyor), totem_base ağ kopyası görseli, enemy_spawner (senkron/sayım - tüm grup gerekiyor).
  - Doğrulama `tools/enemy_rewrite/test_enemy_query.gd` (gerçek oyun, 768 canlı + 40 ölmekte, boss + elit): 500 rastgele
    (merkez, yarıçap) için eski taramanın bulduğu 59.929 canlı yaratığın EKSİĞİ 0; en büyük gövde 71,4 < 140; görev
    kopyası sorguda; "R içinde en yakın" 1000 çağrı tam tarama 693 ms -> aday 100 ms, sonuç 1000/1000 aynı. ENEMY_WORLD=0:
    aynı testler PASS (aday = tüm grup, eski yol değişmedi). compile_check 307/307.
  - Bulunan test tuzağı: `-s` ile çalışan betikte köprüye bağlı betiği `preload` ETME - autoload'lardan önce derlenir,
    köprü `GameManager`'ı bulamaz ve O SÜREÇ boyunca bozuk kalır. Çalışma anında `load()`.
  - BULGU (pencereli, 2000 yaratık oyuncunun çevresinde TOPLANINCA - gerçek oyun durumu): kare 36 ms. main.gd
    y-sıralaması 10 ms/çağrı (2 karede bir; toplanınca hepsi görünür), minimap yenilemesi 8 ms + her karede 2000 nokta
    çizimi. Önceki "2000 = 52 FPS" ölçümü yaratıklar henüz dağınıkken alınmıştı.
  - Y-sıralaması C++'ta: `EnemyWorld.draw_order(parent, extras, extras_foot)` + `set_foot` / `foot_missing`. Düğümler
    ağaçta TAŞINMAZ: görünür yaratıkların işgal ettiği ağaç indeksleri ayak y'sine göre dağıtılıp
    `RenderingServer.canvas_item_set_draw_index` ile verilir (oyuncu/efekt kardeşlerine göre konum aynı). Ayak = görsel
    düğümün global y'si + yerel ayak satırı x |ölçek| (main.gd `_creature_foot_y` formülü; görsel + yerel satır bir kez
    GDScript'ten). Kayıtsızlar (ölmekte, görev kopyası, müttefik) GDScript'te hesaplanıp ekstra verilir. main.gd
    `_update_creature_draw_order_ew`; eski yol aynen. Bilinen küçük fark: bir kardeş silinince motor arkadakilerin draw
    index'ini ağaç indeksine sıfırlar -> en fazla 2 kare eski sıra (sonraki sıralamada düzelir).
  - Minimap: kayıtlı sıradan yaratık noktaları HER KAREDE C++ `minimap_points` (aynı süzgeç: ölü/boss/untargetable değil,
    sis metası >= 0,5 yoksa 1, |ofset| <= 76; aynı piksele düşenler tekilleştirilir - aynı kare çizim üst üste binerdi);
    GDScript listesinde sadece bosslar + görev kopyaları.
  - Doğrulama `tools/enemy_rewrite/test_draw_minimap.gd` (yeni yol, 569 yaratık + boss/elit/ölmekte, 5 an): C++ sıralı küme =
    eski kural kümesi, ayak sırası (GDScript `_creature_foot_y` ile ölçüldü) bozuk 0, verilen indeksler = düğümlerin ağaç
    indeks kümesi; minimap piksel kümesi eski kuralla 5/5 aynı. Pencereli ekran görüntüsünde kalabalık ayak sırası doğru.
  - Sonuç (pencereli, yeni yol, silahlar kapalı): 1000 **204 FPS** (4,9 ms; önce 180), 2000 **107 FPS** (9,3 ms; önce 57),
    2000 toplanmış 13,9 ms (önce 36,3). y-sıralaması 2000'de 10 -> 2,0 ms/çağrı, minimap 8 -> 0,04 ms.
    Sonra draw index önbelleği (ağaç indeksi + verilen indeks aynıysa RenderingServer çağrısı yok; 30 çağrıda bir tam
    yenileme): 2000'de 1,6 ms/çağrı. Daha fazlası gereksiz: oyunun yaratık tavanı 100 + 20/oyuncu.
  - Görev kopyası itilmesi: C++ `set_extra_bodies` (köprü her kare "mission_copies"; yarıçap `_body_radius` yoksa 20 -
    enemy.gd ızgarasıyla aynı), `compute_separation` onlara karşı da iter, kova boyutuna yarıçapları katılır.
    test_world_content'e `kopya_itilme` senaryosu (kopyanın üstüne 10 zombi, 0,6 sn sonra en yakın/ortalama px): eski
    4,1/51,4 · 22,1/71,1 · 32,9/70,2; yeni 25,0/64,3 · 14,9/64,2 · 33,7/67,2 - senaryo oynak, dağılımlar örtüşüyor.
    test_world_content'in diğer satırları iki yolda yine aynı.
  - **Varsayılan açık doğrulaması:** tam paket (`run_tests.ps1`, yapılandırma = yeni yol) 523 test / 59 başarısız; aynı kodla
    eski yol (`-EnemyWorld 0`, 76 dosya - yeni `test_enemy_world.gd` dahil, geçti) 59 başarısız. Liste farkı sadece
    `test_weapon_frozen_targeting` (rastgele seçim + birim testinde iki yol da aynı GDScript koduna düşüyor: iki yolda
    ikişer tekrar, her seferinde farklı alt testler düşüyor) ve eski koşuda `test_new_enchants` zaman aşımı (aynı anda APK
    derleniyordu; tek başına 4/4). **Yeni başarısız test yok.** MP iki süreç, yeni varsayılan: konum farkı ort. 2,9/2,1/2,4
    px (eski yol 2,6), istemci öldürmesi 0/4/3 (eski 3), istemci saldırı animasyonu 923/947/908 (eski 894).
  - Kullanıcı yeni yolu editörde oynadı: "FPS mükemmeldi" (2026-10-03 sabaha karşı) + "her şeyi bitir".
  - Android export: kullanıcının editörü JDK/SDK'yı göremiyordu - Claude masaüstü uygulaması MSIX paketli, önceki
    oturumların `%LOCALAPPDATA%\Android`'e kurduğu araçlar aslında `...\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Local\Android`
    altında (kullanıcının programlarına görünmez). JDK + SDK (NDK hariç) `C:\Users\perva\Android\`e kopyalandı,
    `%APPDATA%\Godot\editor_settings-4.7.tres` oraya çevrildi (yedek `.bak_before_real_android_paths`). Ayrıca Gradle
    `:clean` önceki export'tan kalan `android/build/build`'i silemiyordu (elle silindi). Deneme debug APK (geçici klasöre)
    başarılı, içinde `lib/arm64-v8a/libenemyworld.android.template_debug.arm64.so` var.
- **ÖZET (2026-10-03 2. oturum sonu):** Aşama 0 + 1 TAMAM, Aşama 2 büyük ölçüde TAMAM (kalan: silah hedeflemesi grup
  taramaları - 1000 yaratıkta ~0,7 ms, acil değil). Yeni yol `ENEMY_WORLD=1` (ya da
  `scripts/enemy_world/enemy_world_config.gd` `USE_ENEMY_WORLD = true`) ile tek oyunculu / host'ta ÇALIŞIYOR ve headless A/B
  ile eski yolla eşleşiyor; varsayılan HÂLÂ KAPALI. **Kullanıcıdan beklenen:** editörde anahtarı açıp ELLE oynayıp "aynı
  hissettiriyor mu" demesi -> sonra varsayılanı açma kararı (oyun davranışı = kullanıcı kararı). Sıradaki iş (kullanıcı
  beklenirken yapılabilir): Aşama 5'ten çok oyunculu iki süreçli test (host yeni yol + istemci kukla) - en riskli
  doğrulanmamış kalem; sonra Aşama 3 sürü çizim ölçümü (pencereli, GPU), silah hedeflemesi sorguları.
  Aşağıdaki maddeler ayrıntı/tarihçedir.
- **2026-10-03 3. bölüm (aynı oturum, kullanıcı "devam et"):**
  - Çok oyunculu İKİ SÜREÇLİ test yazıldı ve geçti: `tools/enemy_rewrite/mp_runner.gd` + `run_mp.ps1` (LAN ENet,
    127.0.0.1:7791, host + istemci headless, istemci oyuncusu 400 px sağda, 60 yaratık K3, 15 sn). A/B:
    istemci kuklası ile host'taki yaratık ortalama konum farkı 2,7 / 2,2 px (p95 5,9 / 4,8), istemcinin aldığı hasar
    895 / 900 (yaratıklar uzak oyuncuyu da hedefliyor), istemcide saldırı animasyonu örneği 629 / 639, istemci silahının
    öldürmesi host'a ulaşıyor (kills_by_client 1 / 2). Bilinen artık: host kapanınca istemci ana menüye atılırken
    "current_scene null" betik hatası (düzenek kapanışı, oyun hatası değil).
  - Kullanıcı editörde denedi, "her şey eskisi gibi, FPS de aynı" dedi -> diskte anahtar `false`'tu, büyük ihtimalle
    ESKİ yol çalıştı. Artık hangi yolun çalıştığı görünür: başlangıçta Output'a `[Yaratık sistemi] YENİ/ESKİ`, masaüstü
    FPS etiketine yeni yol açıkken ` | C++ yaratık` (hud.gd; anahtar kapalıyken metin aynı).
  - Pencereli gösterim `tools/enemy_rewrite/demo_world.gd` (kullanıcı izledi): 300 yaratık K6, oyuncu dolaşıyor, silahlar
    açık: ESKİ ort. 24 FPS / fizik adımı 11,9 ms, YENİ ort. 141 FPS / 1,19 ms.
  - Varsayılan hâlâ KAPALI; kullanıcıya açma önerildi (cevap vermedi, "kalan aşamalara devam" dedi - kapalı bırakıldı).
- **2026-10-03 4. bölüm - Aşama 4 doğrulaması** (`tools/enemy_rewrite/test_world_content.gd`, gerçek oyun, iki yolda
  ayrı koşu, CONTENT satırları karşılaştırıldı - SONUNDA BİREBİR AYNI, betik hatası 0):
  - Durum etkileri (aynı tür 7 yaratık, 1 sn yer değiştirme px): kontrol 30,3 / donma 0 / kök 0 / korku +30,3 (uzaklaşır)
    / yavaş 15,2 / sersem 0 / geri itme 12,5; etkiler bitince hepsi 15,2 (yürümeye döndü).
    BULUNAN+DÜZELTİLEN: yeni yolda kareler ARASINDA uygulanan etki bir kare geç işliyordu (0,5 px kayma, korku/yavaş 1 kare
    geç) -> köprü artık C++ adımından ÖNCE uyanık yaratıkların durumunu yazıyor (`_physics_process` başı). Maliyet ~0,1 ms.
  - Boss (golem1 K6): yarıçap 71,4 -> C++'a 71,38 ulaştı, 3 sn yaklaşma 62 px, boss barı görünür. Elit: 63,0 -> C++ 62,99,
    elit 58 / normal 68 px yaklaşma (elit yavaş). İki yolda aynı.
  - Ağacı Koru (debug_force_start_mission): 12 yaratığın ağaca ort. mesafesi 563 -> 335, ağaca hasar 100. Aynı.
  - Alanı Güvenceye Al dalgası: 10 doğdu, 10'u C++'a kayıtlı, yaklaşma 163 px. Aynı.
  - Kopyanı Öldür: kopya doğdu, `get_enemies_near` kopyayı da döndürüyor; 6 sn'de silahlar kopyaya HİÇ vurmadı - İKİ YOLDA
    DA 0 (bu test kopyaya mermi isabetini kanıtlamıyor; eski yolda da 0 olduğu için regresyon değil).
  - Testte ağacı doğrudan silmek `world_event_manager.gd:429`'da (tipli değişkene silinmiş nesne) kare başına hata
    yağdırıyordu - iki yolda da; oyun akışında ağaç önce `is_dead` olduğu için görülmez, test düzeltildi.
  - Ölçüm: bench_current 1000 (yürüyen oyuncu) 2,80 ms (önce 2,67).
- **2026-10-03 5. bölüm - Aşama 3 (görsel + sürü çizimi)** (`tools/enemy_rewrite/render_world.gd`, PENCERELİ gerçek GPU,
  ekran görüntüleri scratchpad'de incelendi):
  - Görsel kontrol (300 yaratık + boss + elit + yanan/donmuş/zehirli/hasarlı): ateş/buz efektleri, hasar sayıları, boss
    barı, ayak y-sıralaması, sis elipsi, "FPS: 171 | C++ yaratık" etiketi doğru.
  - Ölçüm ilk hali (yeni yol): 500 164 FPS / 1000 82 FPS / 2000 35 FPS - GPU HER sayıda ~3,4 ms (darboğaz değil), fizik
    adımı 1,5/2,7/5,1 ms -> kalan kare süresi `_process` tarafında. Doğrudan çağrı profili (1000 yaratık): görüş sisi
    `_apply_enemy_visibility` 7,18 ms/kare (her yaratık için GDScript duvar ışını), main.gd `_update_creature_draw_order`
    ~3,4 ms/çağrı (2 karede bir), minimap taraması ~1,4 ms (0,2 sn'de bir).
  - Yapılan: (1) Sis: kayıtlı yaratıkların görünürlüğü C++ `fog_update` (vision_fog.gd `_target_visibility` +
    vision_occluders.gd `is_ray_blocked` + `_manage_item` BİREBİR; aynı 3 kare kaydırması, aynı metalar); vision_fog.gd yeni
    yolda "enemies" yerine köprünün `fog_extra_enemies()` (ölüm animasyonundakiler + görev kopyaları) listesini yönetiyor.
    7,18 -> 0,054 ms. Doğrulama: test_world_ingame'de her yaratık için C++ metası ile GDScript kuralı karşılaştırıldı:
    291/291 eşit (fark>0,15: 0, görünürlük tutarsız: 0). (2) main.gd y-sıralaması görünmeyen (sisin gizlediği)
    yaratıkları atlıyor (İKİ YOLDA DA - çizilmeyenin sırası önemsiz; sis yokken herkes görünür): 3,4 -> 0,76 ms.
  - Sonuç (pencereli, yeni yol): 500 **231 FPS** (4,3 ms) / 1000 **144 FPS** (6,9 ms) / 2000 **52 FPS** (19,1 ms).
    2000'de kalan ~10 ms: diğer grup taramaları (minimap, y-sıralama döngüsü, silahlar) + 2000 canvas item'ın CPU tarafı.
  - Test hatası bulundu+düzeltildi: test/bench'te oyuncu çizim karesi başına sabit px yürüyordu -> FPS yüksek yolda oyuncu
    daha hızlı kaçıyordu (300 yaratıkta "hasar 1494/676" sahte farkı). Artık gerçek zamanlı 150 px/sn; sonra A/B 300
    yaratık: yol 1507/1501, öldürme 8/8, hasar 1039/959, son mesafe 230/228.
  - Silah hedeflemesi (Aşama 2'nin kalanı): `weapon.gd _get_nearest_enemy` `_update_aim` üzerinden HER SİLAHTA HER KAREDE
    çağrılıyordu (tüm grup + meta okumaları). Yeni yolda C++ `query_nearest(origin, 0.5)` (ölü/untargetable değil,
    VisionFog.can_target: sis metası, yoksa sis açıkken geometrik görünürlük, sis yoksa hedeflenebilir) + görev kopyaları
    GDScript'te. Yeni bayrak `F_UNTARGETABLE` (= is_ability_invisible). C++ sis artık son kaynakları ve yazdığı değeri
    saklıyor (`fog_visibility_at`, `fog_vis`). Doğrulama: 60 rastgele noktada C++ sonucu eski algoritmayla 60/60 aynı.
    Buz Asası (`_get_nearest_unfrozen_enemy`), Tüftüf (`_get_highest_health_enemy`), yakın dövüş ışını hâlâ GDScript
    (nadir silahlar). Pencereli, 3 silah AÇIK: 1000 yaratık **132 FPS** (7,6 ms), 2000 **51 FPS**.
- **2026-10-03 6. bölüm - Aşama 5: projenin test paketi** (yeni kalıcı çalıştırıcı `tools/enemy_rewrite/run_tests.ps1` +
  `run_tests.gd`: her tests/test_*.gd ayrı süreçte, test başına FAIL satırı, `-EnemyWorld 0|1`, `-Filter`):
  - Eski yol (varsayılan), şimdiki ağaç: 75 dosya, 523 test, 60 başarısız. Karşılaştırma için son commit `c6e602a`'nın temiz
    kopyası `git worktree` ile `%TEMP%\ew_base`'e çıkarıldı (içe aktarıldı): 57 başarısız. Fark 3 test, hepsi
    açıklandı: `test_no_missing_resources` = git'te olmayan `android/build/` şablon klasörü (çevresel);
    `test_enemy_pathing` takılı-yaratık + `test_weapon_frozen_targeting` = gerçek zamanlı/kararsız testler, makine boşken
    iki tarafta ikişer kez koşuldu -> İKİ TARAFTA AYNI sonuç. **Eski yolda regresyon yok.** Kalan 57 başarısız
    (eskimiş denge/arayüz testleri: boss kalkan oranı, kalkan %40, dükkan paneli `closed`, ikon boyutları, ...)
    yeniden yazımdan ÖNCE de başarısızdı - bu işin konusu değil.
  - Yeni yol (`-EnemyWorld 1`): 59 başarısız; eski yola göre YENİ başarısız test YOK (tek fark: kararsız takılı-yaratık
    testi bu sefer geçti). DİKKAT: testlerin çoğu yaratığı `current_scene` olmadan kurduğu için o yaratıklar C++'a
    kaydolmaz (köprü current_scene ister) - yani bu paket yeni yolu ZAYIF sınar; asıl kanıt `tools/enemy_rewrite/`
    altındaki gerçek oyun testleri (test_world_ingame / test_world_content / mp_runner / test_world_behaviors).
    Aşama 5'in "testleri yeni sisteme taşı" maddesi = varsayılan açılınca bu kalıcı testleri resmi pakete almak.
  - Temel worktree kaldırıldı (`.git/worktrees/ew_base` salt-okunur klasörleri vardı, öznitelik kaldırılıp prune edildi).
  - Aşama 0 prototip eklentisinin kaydı KAPATILDI (`bench_soa_cpp/enemy_sim_bench.gdextension` -> `.gdextension.off`, her
    açılışta + dışa aktarımda ~1,8 MB gereksiz kütüphane yükleniyordu); `.godot/extension_list.cfg` artık sadece EOSG,
    ziva_agent, enemy_world. Yeniden koşmak için bench_soa_cpp.gd başındaki nota bak.
  - 4 kütüphane son C++ kaynağıyla derlendi (sorgular, sis, hedefleme dahil).
- **KALAN (kullanıcı kararı / cihazı gerekenler):** (1) varsayılanı açmak (`USE_ENEMY_WORLD = true`) - kullanıcı elle
  oynayıp onaylamalı; (2) sonra eski yolu silmek + CLAUDE.md/PLAN güncellemesi (geri dönüşü zor, varsayılan bir süre açık
  kaldıktan sonra); (3) Android'de telefonda deneme (APK kullanıcı alır). **Kalan küçük teknik işler:** Buz Asası /
  Tüftüf / yakın dövüş ışını hedeflemesi hâlâ GDScript taraması; 2000 yaratıkta ~10 ms diğer `_process` (minimap, y-sıralama
  döngüsü, canvas item CPU); görev kopyalarıyla yaratıklar arasında itilme yok (eski yolda ızgara kopyaları da itiyordu -
  küçük fark, kopya nadir).
- **Aşama:** 1 TAMAM, 2 neredeyse tamam (ayrıntı aşağıda "Sıradaki adım" 5-6). Aşama 0 TAMAM (dil = C++, PLAN §7; araç zinciri PLAN §6.1).
- **Yapılan (Aşama 1, dilim 1):** `gdextension/enemy_world/` yazıldı ve Windows template_debug DLL'i DERLENDİ
  (`bin/libenemyworld.windows.template_debug.x86_64.dll`). İçerik (`src/enemy_world.h/.cpp`): slot dizileri + boş slot
  listesi, orman ızgarası, aday (hedef) listesi, hedef başına BFS akış alanı (8 komşu, köşe sızması yok), hedef seçimi
  (ağaç > Şovalye baloncuğu odağı > en yakın; müttefik 160 px içinde x0,35), düşünme/hedef kaydırmalı aralıkları,
  itilme (enemy.gd formülleri birebir), geri itme sönümü, orman probu, gövde/baloncuk/satıcı sert yapıştırma, yakın
  dövüş + baloncuk + hayalet olay kuyruğu (`pop_events`: [tür, slot, hedef]...), yön satırı + yürüme karesi ve konumu
  düğüme C++'tan yazma (`write_views`).
- **Dilim 1 doğrulandı (2026-10-03, 2. oturum):** eklenti `--import` ile kayıtlı, 303 betik derleniyor.
  `tools/enemy_rewrite/bench_world.gd` (BENCH_MODE=check/perf) ile: C++ düz çizgi DDA'sı `enemy_pathing.gd line_blocked`
  ile 2000/2000 aynı; düz çizgisi duvarla kapalı başlayan 183/183 yaratık duvarı dolanıp oyuncuya ulaştı; 200/200 yaklaştı.
  Bu oturumda değişen: akış alanı yönü artık enemy.gd kuralıyla (düz çizgi açıksa düz yürü, kapalıysa akışta 16 hücre ileri
  inip görülebilen en uzak hücreye yönel = A* + `_smooth` eşdeğeri; eski "akış yönü 23°'den fazla saparsa" sezgiseli açık
  alanda zikzak yapardı). Ağaç hedefinde akış yarıçapı sınırsız. Görünüm yazımı değişmeyen konum/kareyi atlıyor.
  Gözlem (eski davranışla aynı, bilinçli bırakıldı): oyuncu duvar dibindeyse gövde "sert yapıştırması" yaratığı duvar
  hücresine itebiliyor (enemy.gd de duvara bakmıyor; içerideyse prob atlanıp kendi çıkıyor); <4 px çiftler olabiliyor
  (eski sistemde de yaratık-yaratık fizik çarpışması yok, `collision_mask=0`, sadece yumuşak itilme).
- **Dilim 2 YAPILDI + doğrulandı (2026-10-03, 2. oturum):** `step` enemy.gd `_physics_process` karar ağacına birebir
  yeniden yazıldı: düşünme/düşünmeme kareleri (`_ai_velocity`/`_ai_min_sep` önbelleği, düşünmeyen karede yön her kare),
  "en yakın" önbelleği 4 karede bir + geçersiz kılmalar her düşünmede (ağaç > tahrik > baloncuk odağı), tahrik TAMAMEN
  C++'ta (`set_taunt(slot, kışkırtan_instance_id, süre)`, süre sadece kovalama dalında azalır, kışkırtan hedeflenemezse
  `E_TAUNT_LOST`), korku kaçış (`F_FEAR_FLEE` + `set_fear_source`) / rastgele (`F_FEAR_WANDER`, hız x0,7 rage'siz),
  menzilli (menzilde + tahrik yok + görüş varsa dur; tek paylaşılan zamanlayıcı -> `E_RANGED_FIRE` (x1,6 içi) /
  `E_HOMING_FIRE` (x2,5 içi); görüş = enemy.gd `line_of_sight_clear` örneklemesi birebir, 150 ms önbellek), takılma
  çözücü + yana bükme (rota izlenirken atlanır), hedefsiz dolaşma, `apply_knockback_force/_distance` + `apply_skill_push`
  formülleri, flip_h için `get_face_left`. Aday listesine kalıcı kimlik eklendi (`set_targets(..., ids)`: tahrik, görüş
  önbelleği ve akış alanı sahibi bununla eşleşir; aday sırası kayarsa akış yeniden kurulur). `speed_mult` = chill x slow,
  `rage_mult` ayrı (`set_rage_mult`).
  Doğrulama: `tools/enemy_rewrite/test_world_behaviors.gd` 21/21 (yapay ızgara, haritasız, ~1 sn): açık alanda zikzaksız
  kovalama, duvar dolanma (duvara hiç girmeden), menzilli dur + atış zaman çizelgesi (12 sn'de 7 büyü + 2 garanti,
  enemy.gd tek zamanlayıcı kuralıyla hesaplanmış), duvar arkasında ateş yok + yürümeye devam, korku kaçış/dolaşma,
  donma (hiçbir şey) / kök (yürümez, saldırır), tahrik + kışkırtan kaybolunca dönüş, baloncuk odağı + kalkana saldırı (yakın
  saldırı yok), müttefik önyargısı, ağaç önceliği, dolaşma hızı <= x0,45, itme mesafeleri (20/100/boss 40/kuvvet 32 px) +
  0,7 sn tekrar penceresi, satıcı bölgesi, temas aralığı (5 sn'de 5-6), hayalet, saldırı kilidi. bench_world check yine
  183/183 dolanma.
  **Bilinçli farklar (PLAN §4.1'e yazıldı):** LOD yok (hepsi tam hassasiyet - C++'ta gereksiz); önbellekteki hedef
  hedeflenemez olunca 4 kare dolaşmak yerine hemen yeniden seçer; takılma probu sadece orman (su/ev zaten geçilebilir).
- **Adım 4 YAPILDI - oyuna bağlandı (2026-10-03, 2. oturum), anahtar varsayılan KAPALI:**
  - `scripts/enemy_world/enemy_world_config.gd`: `USE_ENEMY_WORLD := false`; ortam değişkeni `ENEMY_WORLD=1/0` sabiti ezer
    (kod değiştirmeden A/B). Eklenti yüklü değilse kendiliğinden eski yol.
  - `scripts/enemy_world/enemy_world_bridge.gd`: current_scene çocuğu "EnemyWorldBridge" (yaratığın _ready'sinden
    ERTELENEREK eklenir - o an sahne "çocuk ekliyor" kilidinde). Her kare: orman ızgarası (enemy_pathing.gd `_build`
    çıktısı, EnemyPathing kapalı olsa da), aday listesi (enemy.gd eleme kurallarıyla birebir), `step`, olaylar
    (`_ew_on_event` / `E_LOCO` -> `_ew_on_loco`), seyrek tarama (8 karede bir her kayıt: durum yaz + iş varsa uyandır),
    SADECE uyanık yaratıklara `_ew_tick`. Ölçüm alanları `last_step_ms/last_view_ms/last_tick_ms`, `event_counts`.
  - enemy.gd (hepsi `_ew_slot >= 0` korumalı, anahtar kapalıyken davranış AYNI): `_ready` sonunda `_ew_try_register`
    (kendi `_physics_process`'i kapanır), `die()` başında `_ew_unregister` (eski `_physics_process` geri açılır -> ölüm
    animasyonu eski yoldan), `_exit_tree` kaydı siler, `_ew_tick` (durum etkileri/yetenekler/saldırı animasyonu/
    durum zamanlayıcısı, en sonda `_ew_push_state` + `_ew_still_active`), `_ew_on_event` (temas/kalkan/hayalet/menzilli/
    tahrik bitişi gövdeleri `_physics_process`'teki dalların kopyası), `_enter_state` -> `_ew_anim_state_changed`,
    `apply_knockback_force/_distance` + `apply_skill_push` + `apply_taunt` + `apply_fear` host dalları C++'a yönlenir,
    39 giriş noktasının (apply_*, take_damage*, _flash, elit/boss/kademe ölçekleme, öfke...) ilk satırı `_ew_wake()`.
    `_interp_prev_pos/_interp_prev_frame` artık getter (C++'ın adım öncesi konumu).
  - C++ ekleri: adım başında dış konum algılama (`sync_external_moves`: doğumdaki add_child-sonrası konumlama, vampir
    ışınlanması vb. benimsenir), `get_prev_position`, `set_radius`, `get_target` = BU karenin hedefi, yürüme/bekleme
    tespiti (enemy.gd `_update_locomotion_state` birebir) + `E_LOCO`, WALK/IDLE karesini Sprite2D'ye C++ yazar
    (`set_anim_state`), AnimatedSprite2D `flip_h`'yi C++ yazar.
  - **Doğrulandı (gerçek menü akışı, headless, `tools/enemy_rewrite/test_world_ingame.gd`, aynı tohum A/B):**
    150 yaratık, 20 sn (yarısı oyuncu durur, yarısı yürür), oyuncuya tüfek+yay+tabanca:

    | ölçü | eski | EnemyWorld |
    |---|---|---|
    | K3 ortalama mesafe 0/5/20 sn | 500/285/73 | 499/282/69 |
    | K8 alınan hasar / düşman mermisi | 5887 / 301 | 5721 / 300 |
    | K8 mesafe | 500/256/83 | 499/251/80 |
    | K1 öldürme / alınan hasar | 100 / 490 | 99 / 473 |
    | duvar içinde kalan, kare ilerleyen | 0, 20/20 | 0, 20/20 |

    Betik hatası yok. `test_world_behaviors.gd` 21/21, `compile_check` 305/305.
  - **Ölçüm (bench_current, gerçek oyun, kademe 8, yürüyüş):** 200 yaratık 8,05 -> 0,99 ms; 500 -> 2,10 ms; 1000
    -> 3,83 ms (eski ~36,8). Yaratık başına ~3,6-4,2 µs. Kalan maliyetin çoğu C++'ın konum yazması (1000'de 1,69 ms):
    gerçek düğümün CollisionShape2D + HitArea çocukları her konum değişiminde fizik sunucusunu güncelliyor -> Aşama 2'de
    fizik cisimleri kalkınca düşecek. GDScript tiki 9 -> 0,8 µs (uyku modeli).
- **Doğrulanmadı / yapılmadı:** gerçek oyunda ELLE oynanış ("aynı hissettiriyor mu" - kullanıcı denemeli: editörde
  `scripts/enemy_world/enemy_world_config.gd` `USE_ENEMY_WORLD = true`), çok oyunculu (host'ta yeni yol, istemci kukla;
  denenmedi), Ağacı Koru / Şovalye baloncuğu / satıcı bölgesi / tahrik / korku GERÇEK oyunda (C++ testlerinde var),
  yaratık yetenekleri (vampir ışınlanması, lazer kilidi) gerçek oyunda, Android .so ve template_release derlemesi.
  Projenin kendi test paketi (`tests/`) koşulmadı (hafıza: kullanıcı ağır test koşularını sorulmadan istemiyor).
- **Sıradaki adım (sırayla):**
  1. ~~import + compile_check~~ (yapıldı)  2. ~~bench_world.gd~~ (yapıldı)  3. ~~Dilim 2 C++~~ (yapıldı)
  4. ~~köprü + enemy.gd bağlantısı~~ (yapıldı, yukarıda)
  5. Aşama 2 dilim A YAPILDI + doğrulandı (isabet sorguları, fizik gövdesi kapalı, get_enemies_near, yetenek alanları):
     - C++ `query_circle` / `query_segment` (kova ızgarası + 16 px pay; segment ilk temas sırasıyla, çember uzaklık
       sırasıyla) / `query_points` (merkez mesafesi, kova sırası = eski `get_enemies_near` anlamı), `hit_radius` +
       `set_hit_probe` (yaratığın HitArea'sı CANLIYDI: yerel oyuncunun fizik çemberi girince `_contact_timer = 0`;
       doğumda içerideyse ilk karede de - eski yolda da öyle), `set/get_contact_timer`, `set/get_ranged_timer`,
       `force_think`, `set_face`.
     - `scripts/enemy_world/enemy_world_hits.gd`: Area2D giriş/çıkış anlamlı süpürme sorgusu; `projectile.gd` ve
       `boomerang_projectile.gd` her fizik adımı SONUNDA `_ew_poll_hits()` -> aynı `_on_body_entered` (isabet kodu
       değişmedi; bumerangın `_physics_process`'i `_move_physics` + poll oldu). Görev kopyası fizik gövdesini korur.
     - enemy.gd kayıtta: gövde + HitArea çarpışması kapalı, `set_notify_transform(false)` (şekiller kapalıyken de fizik
       sunucusuna dönüşüm yazılıyordu, ~0,4 µs/yaratık); kayıt silinince geri açılır. `_ranged_timer`, `_contact_timer`,
       `_ai_has_decision` artık getter/setter'lı özellik (yeni yolda C++'a yönlenir - enemy_abilities.gd lazer/hayalet/
       vampir bunları dışarıdan yazıyordu), `_update_facing` yeni yolda `set_face`. `get_enemies_near` yeni yolda
       `enemy_world_bridge.gd enemies_near` (C++ + "mission_copies") - eski ızgara her karede tüm grubu tarıyordu.
     - Köprü: seyrek tarama 8 -> 30 karede bir (8'de 1000 yaratıkta ~0,5 ms/kare yiyordu).
     - Doğrulama: `test_world_behaviors.gd` 26/26 (yeni: segment sırası/ters sıra/ıska/ölü hariç, çember, kova eskiyken
       bulma, temas alanı sıfırlama), `test_world_ingame.gd` A/B: K1 öldürme 101/101 ve 99/96 (eski yolun kendi
       tekrarları 99-101), K8 mermi 301/300, alınan hasar ±%5 (eski yol da koşudan koşuya bu kadar oynuyor); silahlar AÇIKKEN
       150 yaratıkta fizik adımı K1 4,5-5,3 -> 1,1 ms, K8 6,2 -> 1,2-1,3 ms. bench_current 1000: 3,12 ms = 2,93 µs/yaratık
       -> **Aşama 1 ölçütü (<=3 µs) karşılandı.** 4 kütüphane (win debug/release, android arm64 debug/release) son
       kaynakla derlendi (2026-10-03 02:27-02:34).
     - Özel fonksiyon çağıranları (§3.1) tarandı: hepsi aynı enemy.gd düğümünde çalıştığı için yeni yolda da çalışıyor;
       hareket/AI alanı yazanlar sadece enemy_abilities.gd'deki 3 alan + `_update_facing` (yukarıda çözüldü).
     - **Ek doğrulama (aynı gün, sonra):** (1) Yaratık HitArea modeli AYNI koşuda karşılaştırıldı (geçici olarak HitArea
       açık bırakılıp hem fizik sinyali hem C++ sayıldı): 211 / 212 giriş - birebir. (2) Yetenekli aileler (hayalet,
       vampir, röntgen, iblis, ağaç, zombi; `BENCH_IDS`) A/B: betik hatası yok, mermi/lazer/büyü sayıları aynı (±3 %),
       hayalet ortaya çıkma olayları geliyor. Hasar yeni yolda ort. +3..+9 % (eski yolun kendi koşu oynaması ±10 %);
       sebebi bulundu: yaratıklar hedefe biraz DAHA ÇABUK varıyor (5. sn ortalama mesafe sürekli 3-7 px daha az) - eski
       A* kare başına 4 yol bütçesi + 0,2 sn rastgele düz çizgi kontrolü vardı, akış alanında herkes hemen doğru yönde.
       Bilinçli fark (PLAN §4.1 (5)), hata değil. (3) **headless'ta `Input.action_press` oyuncuyu YÜRÜTMÜYOR** - bu
       tarihe kadarki tüm "yürüyüş" ölçümleri (Aşama 0 dahil) aslında oyuncu DURURKEN alındı. `bench_current.gd` ve
       `test_world_ingame.gd` artık oyuncuyu doğrudan taşıyor; yürüyen oyuncuyla A/B (K3, 150 yaratık, silahlı): yol
       3558/3625 px, öldürme 7/7, hasar 595/570, son mesafe 580/573 - eşleşiyor; fizik adımı 6,33 -> 0,82 ms.
  6. Sıradaki: Aşama 2'nin kalanı - silah hedeflemesi grup taramaları (`weapon.gd _get_nearest_enemy`,
     `_find_enemy_on_facing_ray`, WeaponTargetPriority ...) 1000 yaratıkta her silahta O(n) GDScript; önce silahlı
     1000 yaratık ölçümü (test_world_ingame BENCH_N=1000) ile gerçekten ne kadar tuttuğunu ölç, sonra C++ sorgusuna
     (görüş sisi `VisionFogScript.can_target` kuralı dahil) taşı. Durum etkileri/hasar/ölüm zaten enemy.gd'de aynen
     çalışıyor (A/B ile doğrulandı) - Aşama 2'nin "hasar/ölüm/durum etkileri" maddeleri için ayrı yeniden yazım GEREKMİYOR
     (facade = mevcut düğüm); PLAN'daki "ince Node2D düğüm" hedefi fizik gövdesini kapatmakla fiilen karşılandı.
- **Bekleyen kullanıcı kararları:** yok. Alınanlar (PLAN §7): master + geçiş anahtarı; commit/push SADECE kullanıcı
  söyleyince (sorma); aşamalar arasında durmadan devam; dil C++.
- **Başlangıç noktası:** yeniden yazım öncesi tüm iş commit `c6e602a` ("Yeniden yazım öncesi: ..."), push edildi.
  O commit'ten sonra commit edilmemiş: `tools/enemy_rewrite/` (ölçüm betikleri + C++ prototip + derlenmiş dll/so),
  docs güncellemeleri, `.gitignore` (C++ ara dosyaları, .claude yerel dosyaları), elit aura/alev PNG'lerinin `.import`
  dosyaları (commit içe aktarmadan önce atılmıştı).
- **Not:** `tools/enemy_rewrite/bench_soa_cpp/enemy_sim_bench.gdextension` projeye kayıtlı (editör/oyun açılışında
  yüklenir, zararsız ~1 MB). Aşama 5'te ya silinecek ya da export dışı bırakılacak.

## Aşama kontrol listesi

Aşama 0: [x] bench_current  [x] bench_soa_gd  [x] bench_soa_cpp  [x] sonuç tablosu  [x] dil kararı (C++)
Aşama 1: [x] diziler+ızgara  [x] akış alanı  [x] hareket/itilme/duvar/knockback (C++, oyuna bağlı değil)  [x] hedef+yakın saldırı (C++ olayları; GDScript tarafı köprüde)  [x] ince düğüm+animasyon+y-sort (yürüme/bekleme C++, saldırı/ölüm GDScript; y-sort main.gd değişmeden çalışıyor)  [x] 1000 yaratık ölçümü (3,83 ms; ölçüt <=3 µs: 3,6 µs - kalan fizik cismi maliyeti Aşama 2'de)
Aşama 2: [x] arayüz §3.1 (facade = mevcut enemy.gd düğümü; dışarıdan yazılan AI alanları C++'a yönlendi)  [x] hasar/ölüm/düşmeler/elit/boss (kod aynen enemy.gd'de; K1 A/B öldürme eşleşiyor - düşmeler ayrıca sayılmadı)  [x] durum etkileri (enemy.gd'de, uyku modeliyle)  [x] isabet yakalayıcıları (gerçekte 2 dosya: projectile + boomerang -> sorgu)  [x] grup taramaları (get_enemies_near, silah hedeflemesi, EnemyQuery.candidates ile her-kare taramalar; 7. bölüm)
Aşama 3: [x] görsel ayrıntılar (ekran görüntüsüyle)  [x] sürü çizim ölçümü (sis C++'a, y-sıralaması görünenlerle; 1000 = 144 FPS)
Aşama 4: [x] aile yetenekleri (A/B: hayalet/vampir/röntgen/iblis/ağaç/zombi)  [x] boss/kademe/elit/görev/debug (test_world_content.gd; kademe kapısı kod değişmeden)
Aşama 5: [x] multiplayer (iki süreç LAN, yeni varsayılan)  [x] testler (tam paket, yeni başarısız yok; tests/test_enemy_world.gd)  [~] Android (export + .so paketleniyor; telefonda FPS kullanıcıda)  [x] varsayılan true  [ ] eski host dalını sil (izin engeli, kullanıcı kararı)

## Ölçümler

| Tarih | Senaryo | Yaratık | Sistem | Ortalama kare (ms) | p95 (ms) | Yaratık başına (µs) | Not |
|---|---|---|---|---|---|---|---|
| 2026-09-27 | eski ölçüm, Korsan, yürüyüş | 160 | eski | 9,7 | 15,6 | ~30 | taban (bkz. PLAN §2) |
| 2026-10-03 | bench_current (fizik adımı), Kademe 8, yürüyüş, headless | 200 | eski | 7,47 (adım) | 10,70 | 36,4 | tools/enemy_rewrite/bench_current.gd |
| 2026-10-03 | aynı | 500 | eski | 18,16 (adım) | 26,60 | 35,9 | 60 FPS bütçesi aşılıyor (kare 68,8 ms) |
| 2026-10-03 | aynı | 1000 | eski | 36,79 (adım) | 54,02 | 36,6 | ~7 FPS (kare 147,7 ms); doğrusal ölçekleniyor |
| 2026-10-03 | bench_soa_gd (GDScript düz dizi, akış alanı nesil damgalı, bütçe 2000 hücre/kare) | 200 | GDScript SoA | 3,80 (sim 1,38 + görünüm 0,24 + akış 2,19) | sim 1,62 | 8,1 | akış en kötü 6,1 ms |
| 2026-10-03 | aynı | 500 | GDScript SoA | 6,62 | sim 4,22 | 8,7 | akış en kötü 11,0 ms |
| 2026-10-03 | aynı | 1000 | GDScript SoA | 12,09 | sim 10,09 | 9,9 | eski 36,8 ms'ye karşı ~3x |
| 2026-10-03 | aynı | 2000 | GDScript SoA | 24,58 | sim 22,19 | 11,1 | |
| 2026-10-03 | bench_soa_cpp (C++ sim + GDScript görünüm), aynı senaryo | 200 | C++ | 0,29 (sim 0,045 + görünüm 0,23 + akış 0,014) | sim 0,068 | 1,36 (sim 0,22) | akış en kötü 0,14 ms |
| 2026-10-03 | aynı | 500 | C++ | 0,63 | sim 0,13 | 1,23 (sim 0,21) | |
| 2026-10-03 | aynı | 1000 | C++ | 1,30 | sim 0,30 | 1,29 (sim 0,24) | eski 36,8 ms'ye karşı ~28x (görünüm GDScript'te) |
| 2026-10-03 | aynı | 2000 | C++ | 2,68 | sim 0,78 | 1,33 (sim 0,31) | |
| 2026-10-03 | aynı | 5000 | C++ | 7,67 (görünüm 5,09) | sim 3,29 | 1,53 (sim 0,51) | görünüm baskın -> C++'a alınmalı |
| 2026-10-03 | bench_world perf (GERÇEK EnemyWorld dilim 1, görünüm C++'tan), yürüyüş | 200 | EnemyWorld | 0,317 | 0,507 | 1,59 | olay melee 90 |
| 2026-10-03 | aynı | 500 | EnemyWorld | 0,731 | 1,215 | 1,46 | |
| 2026-10-03 | aynı | 1000 | EnemyWorld | 1,395 (görünüm 1,09) | 2,04 | 1,40 (sim 0,30) | eski 36,8 ms'ye karşı ~26x; Aşama 1 ölçütü (<=3 µs) karşılandı |
| 2026-10-03 | aynı | 2000 | EnemyWorld | 2,710 | 3,540 | 1,36 | |
| 2026-10-03 | aynı | 5000 | EnemyWorld | 6,99 (görünüm 5,42) | 9,62 | 1,40 (sim 0,31) | görünüm = motorun set_position maliyeti (~1,1 µs); düşürmek için RenderingServer -> Aşama 3 |
| 2026-10-03 | bench_world check (oyuncu durur, 30 sn) | 200 | EnemyWorld | 0,289 | 0,393 | 1,45 | duvarı dolanan 183/183, DDA 2000/2000 aynı |
| 2026-10-03 | bench_world perf, DİLİM 2 (tam karar ağacı) | 1000 | EnemyWorld | 1,144 (görünüm 0,86) | 1,614 | 1,14 (sim 0,28) | dilim 2 maliyet eklemedi |
| 2026-10-03 | aynı | 5000 | EnemyWorld | 6,12 (görünüm 4,58) | 8,40 | 1,22 (sim 0,31) | |
| 2026-10-03 | bench_current GERÇEK OYUN, ENEMY_WORLD=0 (eski), K8 yürüyüş | 200 | eski | 8,05 (adım) | 12,96 | 39,2 | aynı oturumda tekrar ölçüldü |
| 2026-10-03 | bench_current ENEMY_WORLD=1, ilk bağlantı (her yaratık her kare GDScript tiki) | 200 | EnemyWorld | 2,53 | 2,84 | 11,8 (C++ 0,41 ms + GDScript 1,78 ms) | tik kırılımı: animasyon 3,5 µs, durum yazma 2,3, durum etkileri 1,2 |
| 2026-10-03 | bench_current ENEMY_WORLD=1, uyku modeli + C++ yürüme/bekleme animasyonu | 200 | EnemyWorld | 0,99 | 1,26 | ~4,2 (GDScript 1,22) | sabit ~0,3 ms aday listesi vb. dahil |
| 2026-10-03 | aynı | 500 | EnemyWorld | 2,10 | 2,75 | ~3,8 | |
| 2026-10-03 | aynı | 1000 | EnemyWorld | 3,83 | 4,79 | ~3,6 (C++ 2,25 ms, bunun 1,69'u konum yazma; GDScript 0,77) | eski ~36,8 ms; konum yazmanın çoğu fizik cismi (Aşama 2) |
| 2026-10-03 | bench_current ENEMY_WORLD=1, Aşama 2 dilim A (gövde kapalı + notify_transform kapalı + tarama 30 kare) | 1000 | EnemyWorld | 3,12 | 4,12 | **2,93** (C++ 1,83 ms, konum yazma 1,28; GDScript 0,72) | Aşama 1 ölçütü karşılandı |
| 2026-10-03 | aynı | 200 | EnemyWorld | 1,15 (dilim A, tarama 8 karedeyken) | 1,46 | ~4,9 | sabit maliyet (aday listesi vb.) 200'de baskın |
| 2026-10-03 | test_world_ingame, SİLAHLAR AÇIK (tüfek+yay+tabanca), K1 | 150 | eski / EnemyWorld | 4,49-5,26 / 1,06-1,13 | - | - | tüm fizik adımı (silah+oyuncu dahil) |
| 2026-10-03 | aynı, K8 (32 menzilli) | 150 | eski / EnemyWorld | 6,17 / 1,19-1,31 | - | - | |
| 2026-10-03 | test_world_ingame silahlı, K8, OYUNCU DURUYOR | 1000 | eski / EnemyWorld | 38,17 / 3,82 | - | - | eski yol yetişemiyor (12 sn'de 231 tik) |
| 2026-10-03 | bench_current, OYUNCU GERÇEKTEN YÜRÜYOR (doğrudan taşıma), K8 | 200 | eski | 7,95 | 12,99 | ~38,9 | önceki "yürüyüş" satırları aslında duran oyuncuydu |
| 2026-10-03 | aynı | 200 | EnemyWorld | 0,84 | 1,10 | ~3,2 (C++ 0,45 + GDScript 0,10) | |
| 2026-10-03 | aynı | 1000 | EnemyWorld | 2,67 | 3,46 | **2,5** (C++ 2,03, konum yazma 1,40; GDScript 0,29) | |

## Oturum kayıtları (en yeni üstte)

### 2026-10-08 (2) (yeniden yazım DIŞI iş - çok oyunculu sağlamlaştırma + host devri; spawner/enemy.gd'ye dokundu)
- `enemy_spawner.gd`: yaratık durum paketi artık ikili (`scripts/enemy_sync_codec.gd`: 22 bayt/yaratık, tur numarası, paket başına 40; RPC `_sync_enemy_positions(tick, data)`),
  yalnızca Main'i hazır istemcilere (`NetworkManager.game_ready_peers()`); doğuş RPC'si `_rpc_client_spawn_creature` yeni son parametre `player_count` (host'un sayısı) ve
  `_announce_spawn` ile hazır peer'lere; `_player_count()` = `NetworkManager.game_player_count()` (hayalet lobi oyuncusu sayılmaz); `export_handover/import_handover`
  (host devri: hangi boss/elit doğdu, Final, sonsuz mod, tutulan süre; ~2 sn'de bir `publish_host_handover`).
- `enemy.gd`: XP bölüşümü `game_player_count()`. C++ DEĞİŞMEDİ. Ayrıntı CLAUDE.md madde 29-30.
- `test_paladin_aggro_talon_pose_and_stat_tweaks`: kışkırtma testi 2 kare yerine 3 kare bekler (C++ yapay zekâ 3 karede bir düşünür; faz kayınca 2 kare yetmiyordu).

### 2026-10-08 (yeniden yazım DIŞI iş ama C++ + enemy_pathing değişti - collision herşey için)
- Kullanıcı: "collision shapeleri herşey için yeniden hesapla" (oyuncu + yaratıklar; su, bina tabanı, ağaç gövdesi, maden, düşman üssü). `scripts/terrain_collision.gd` nesne ayak izlerini
  karolardan hesaplar; `enemy_pathing.gd _build` orman ∪ nesneleri `_blocked`'a (C++ hareket + akış alanı + A*) yazar, SADECE ormanı yeni `_fog_blocked`'a.
- C++: `EnemyWorld.set_grid(..., fog_blocked = boş)` + `fog_solid_cell` (sadece `fog_ray_blocked` kullanır) - su/ağaç/bina görüşü KESMEZ. 4 kütüphane derlendi (Windows debug/release,
  Android arm64 debug/release). Köprü `_refresh_grid` fog ızgarasını geçirir. Ayrıntı CLAUDE.md madde 27.
- Testler: `test_terrain_collision_objects` (8), `test_map_terrain_collision` (10); gerçek pencerede tuş basışıyla doğrulandı.

### 2026-10-06 (yeniden yazım DIŞI iş - kademe kapısı hızlandırması + ork öfkesi, bilgi için)
- C++'a / hareket kurallarına dokunulmadı. `enemy.gd`: `gate_rush_mult` + `set_gate_rush()`; `_ew_push_state` içinde C++ "rage" çarpanı
  `(öfke çarpanı) x gate_rush_mult` oldu (C++ bunu sadece kovalama hızına uyguluyor, enemy_world.cpp 1587/1692/1785). `enemy_spawner.gd`:
  `_gate_rush_tick()` (`_check_tier_announcement` çağırır, kapı beklemiyorsa hemen çıkar): kapı >1 sn beklediyse kapıyı tutan, hiçbir
  oyuncunun görüş elipsinde olmayan eski yaratıklar 3x hızlanır, görüşe girince/kapı açılınca 1x. Neden: kapı kapalıyken hiç doğuş yok ve
  tutanlar hep görüş dışında ~40 px/sn yürüyen yaratıklar (ölçüm: kusursuz öldürücüyle bile ~8 sn boş, hızlanmayla ~2-3 sn).
  Ayrıca `enemy.gd ORK_RAGE_NERF_2026_10_06 = 0.85` (ork öfkesinin hız ARTIŞI x0.85). Testler: test_enemy_spawner_gate_and_ambush (16,
  mutasyonla doğrulandı), test_enemy_abilities (5). Gerçek oyunda elle denenmedi; 2 süreçli LAN koşusu yapılmadı (hız host'ta, istemci
  kuklası konumu ağdan alıyor).

### 2026-10-05 (yeniden yazım DIŞI iş, spawner'a ek - bilgi için)
- Yaratık hareketi/AI'sına/C++'a dokunulmadı. `enemy_spawner.gd`'ye host tarafı "ZAFER + SONSUZ MOD" bloğu eklendi (Final bossları
  `_final_bosses`'ta tutulur, hepsi ölünce zafer; sonra sonsuz katlar: yeni doğanın istatistik kademesi 15 + kat, roster 15'te
  kalır) ve `enemy.gd`'ye `dismiss_without_reward()` (die()'ın görsel/kayıt kısmı, ödül/öldürme yok) eklendi. `_spawn_boss_group` artık
  doğan listeyi döndürür; `_check_final_tier` hiç boss doğmadıysa `_final_spawned`'ı geri alıp yeniden dener. Ayrıntı: CLAUDE.md madde 10.

### 2026-10-03 (sonraki oturum, kısa kontrol)
- Kod değişikliği yok. Diskteki durum yeniden doğrulandı: compile_check 307/307, köprüyü elle adımlayan testler + test_enemy_world
  + test_client_puppet_facing 49/49. Sıradaki hâlâ "Şu an"daki kullanıcı kararları (commit/push, telefonda FPS, Şovalye Q adı).

### 2026-10-03 (07:04 sonrası, kota kesintisinden sonra devam) - son test hatası + Epic
- Önceki oturumun kayda geçmeyen son işi (dosyalardan doğrulandı): 06:53'te başlayan tam paket 523/522 geçti; kalan
  `test_enemy_pathing` gerçek harita testinde 20 çiftin hiçbiri ulaşmıyordu. Kök neden: köprünün çift-tik koruması
  `Engine.get_physics_frames()` damgası kullanıyordu - test köprüyü aynı motor karesinde art arda elle adımlayınca sayaç
  ilerlemiyor, yaratıklar ilk adımdan sonra hiç tiklenmiyor (saldırı durumu bitmiyor, donuyordu). Düzeltme:
  `enemy_world_bridge.gd` kendi `_step_counter`'ı (oyunda fizik karesi başına bir adım = aynı anlam). Sonra 19/20 (eşik %90).
- Bu oturumda tekrar doğrulandı: köprüyü elle adımlayan testler (test_enemy_pathing 7, test_paladin_aggro 12,
  test_map_terrain_collision 10, test_enemy_idle_animation 10, test_necro_skull 7) + test_enemy_world 2 +
  test_client_puppet_facing 1 = 49/49; compile_check 307/307.
- **Epic MP (gerçek Epic odası, iki süreç, `run_mp.ps1 -Net epic`):** konum farkı ort. 2,6 px (p95 5,4; LAN ile aynı),
  istemci hasarı 992, istemci öldürmesi 3/3, istemci saldırı animasyonu 626, istemci köprüsü (C++ kukla) açık, istemci
  fizik 0,91 ms / `_process` 1,05 ms, host fizik 1,06 ms.
- Görülen ama dokunulmayan: Epic odasındayken oyun KAPANIRKEN `main.gd:1727 _on_level_up_busy_state_changed`
  "paused on null instance" (EOS çıkışta bağlantıyı kapatıyor, ağaç artık yok). Sadece kapanışta tek satır; yeniden
  yazımla ilgisiz.

### 2026-10-03 (3. oturum devamı, kullanıcı: "eksikliklere devam" - 4 madde seçti: istemci perf, eski kodu sil, 59 test, Epic)
- **Eski host simülasyonu SİLİNDİ (kullanıcı onayıyla):** enemy.gd `_physics_process` `if not is_dead:` bloğu (~410 satır)
  yerine "kaydı yoksa `_ew_try_register()` dene, olmazsa `_ew_warn_unregistered()` bir kez uyar". Referans taramasıyla
  (yorumlar hariç, dosya-içi + dış `.ad`/`"ad"` erişimi) SADECE bu silmeyle ölü kalan 60+ fonksiyon/değişken/sabit ve
  sahipsiz yorumları kaldırıldı (yol bulma rotası, eski itilme + toplu geçiş + LOD, dolaşma, takılma, korku-dolaşma,
  hedef önbelleği, Şovalye odağı, duvar probu...). Önceden de ölü olanlara (`_apply_melee_recoil`, `_has_enchant_status`,
  `CHILL_MAX_STACKS`, `MELEE_HIT_RECOIL`, `SlowStatusFxScene`, `OVERHEAD_BAR_HIDE_DELAY`, `EW_E_LOCO`,
  `get_poison_stack_count`, `reset_zone_owners_cache`) dokunulmadı. enemy.gd 6068 -> ~4990 satır. KALDI (istemci/ölüm):
  istemci kukla dalı, ölüm dalı, `get_enemies_near` eski ızgarası (`_rebuild_separation_grid_if_needed`). Geri dönüş:
  `git stash list` "eski host yolu silinmeden ONCE". `enemy_world_config.gd`: anahtar kalktı, `enabled()` = eklenti var mı.
  Doğrulama (silmeden sonra): compile 307/307, davranış 26/26, test_world_ingame (hedefleme 60/60, sis tutarlı, betik
  hatası yok), test_world_content (öncekiyle aynı), MP konum 2,1 px.
- **İstemci (katılımcı) kuklaları C++'ta:** `F_PUPPET` + `set_net_target`/`get_net_time`, `step_puppet` (enemy.gd istemci
  dalı birebir: 0,7 sn ölü hesaplama, delta*18 yumuşatma, hız>15 ise hareket yönü yoksa 3 karede bir ağaç/en yakın
  oyuncu), yürüme/bekleme + kare ortak `step_loco_anim`. enemy.gd: istemcide de kayıt (`_ew_puppet`), `update_network_state`
  + vampir ışınlanması hedefi C++'a iletir, `_ew_tick_puppet` (parlama, işaret, durum süresi, saldırı karesi), köprü istemcide
  kozmetik ağacı aday yapar. Böylece istemci de C++ sis/sorgu/y-sıralaması/minimap/isabet kullanıyor. Yedek/A-B:
  `ENEMY_WORLD_PUPPET=0`. mp_runner'a istemci süre sondaları. A/B (150 yaratık, 2'şer koşu): istemci fizik 1,9 -> 1,45 ms,
  `_process` 2,57 -> 1,08 ms (toplam ~4,5 -> ~2,5 ms), konum farkı ve saldırı animasyonu sayıları aynı.
  4 kütüphane son kaynakla derlendi (06:50-06:53).
- **C++ düzeltmesi (testten bulundu):** kova ızgarası sadece adım başında kuruluyordu - adımdan SONRA kaydolan (yeni doğan,
  add_child sonrası taşınan) yaratık ilk adıma kadar hiçbir sorguda (silah hedeflemesi, EnemyQuery, isabet) yoktu (oyunda en
  fazla 1 kare). Artık add/remove `buckets_dirty` + `fresh_slots`; ilk sorgu (`ensure_query_ready`) yeni kayıtların konumunu
  düğümden tazeleyip ızgarayı yeniden kurar (query_nearest dahil). world_behavior_cases'e `sorgu_ilk_adimdan_once` (27/27).
- **Testler ("bozuk 59" + silmeyle kırılanlar):** çalıştırıcı `run_tests.gd` test düğümünü current_scene yapıyor (oyunda hep
  var; 14 test `add_child on null` ile düşüyordu). Eski host dalını adımlayan testler köprüyü elle adımlayacak şekilde
  çevrildi (test_enemy_pathing, test_paladin_aggro..., test_enemy_idle_animation, test_necro_skull korku, test_map_terrain_
  collision yaratık kısmı, test_client_puppet_facing yönü C++'tan okur). Eskimiş testler GÜNCEL kullanıcı kararlarına göre
  güncellendi (her birinde not var): boss can/kalkan 5. tur + %90, normal kalkan %30, can barı sadece bossta, dükkan KAPALI
  (SHOP_ENABLED=false) kuralı, kalkan satırları dükkandan kalktı, ikonlar 144 (48x3), yanma ateşi 9 kare, Korsan 3 şarj +
  eşleme araması, Oakley 48x48 ölçeği, şimşek karoları, Korsan mermisi/tilki kalkanı sprite sayfası, ruhani 8 yetenek,
  Vampir koşma %15 + toggle koruması, sandık tek kart + kart/buton sütunu, Şovalye Q = kalkan yenileme (kışkırtma evrimde),
  dock'ta pasif ikon aynı boyut, tooltip UIKit.INK renkleri, silah seçiminde `mode` yok, Destiny `flame_*` sayfaları (yeni
  alevin asa takibi ilk kez doğrulandı), android/ şablonu kaynak testinden hariç. Test hataları: HUD testleri `_ready()`'yi
  elle 2. kez çağırıyordu (Godot 4.7 @onready'yi yeniden çözüyor, taşınan panel null), donmuş hedefleme testinde testler arası
  sızıntı + 80 px rastgele havuz sınırı, Necro testleri oyuncuyu sahnesiz kuruyordu.
- **Oyunda fark edilen ama DOKUNULMAYAN:** Şovalye Q'nun adı hâlâ "Kışkırtma" ama temel Q artık sadece kalkan yeniliyor
  (kışkırtma "Meydan Okuma" evriminde) - isim kullanıcıya soruldu (oyun metni).

### 2026-10-03 (3. oturum, kota kesintisi sonrası) - grup taramaları, y-sıralaması/minimap C++, varsayılan AÇIK
- Önceki oturumun yarım kalan derleme kontrolü tamamlandı (306/306).
- Yeni: `enemy_query.gd` + ~25 her-kare tarama dönüşümü, C++ `draw_order`/`set_foot`/`foot_missing`/`minimap_points`/
  `set_extra_bodies`/`get_last_draw_order`, testler `test_enemy_query.gd`, `test_draw_minimap.gd`, `kopya_itilme`
  senaryosu, `world_behavior_cases.gd` + `tests/test_enemy_world.gd`; `render_world.gd`'ye canvas deneyleri.
- Ölçüm (pencereli): 1000 yaratık 180 -> 204 FPS, 2000 57 -> 107 FPS, 2000 toplanmış 36 -> ~14 ms.
- Doğrulandı: üst küme 0 eksik, çizim sırası/minimap eski kuralla birebir, tam paket yeni başarısız yok, MP eşleşiyor,
  gerçek oyun silah senaryosu temiz, Android APK'da .so var. Doğrulanmadı: telefonda çalışma/FPS.
- Öğrenilen: Claude masaüstü uygulaması MSIX - kabuktan `%LOCALAPPDATA%`'ya yazılan YENİ dosyalar kullanıcının
  programlarına görünmez (paket LocalCache); `-s` betiğinde köprüye bağlı betiği preload etme; 2000 yaratık ölçümünü
  yaratıklar TOPLANMIŞKEN de al (dağınıkken ölçülen 52 FPS, toplanınca 28 FPS idi).
### 2026-10-03 (2. oturum, ikinci hesap) - Aşama 1 dilim 1 doğrulandı, dilim 2 + oyuna bağlantı
- Dilim 1 ilk kez çalıştırıldı ve doğrulandı; akış alanı yönü enemy.gd kuralına (düz çizgi açıksa düz) çevrildi - eski
  sezgisel açık alanda zikzak yapardı.
- Dilim 2 (menzilli, korku, tahrik, dolaşma, takılma, itme formülleri) C++'ta; `test_world_behaviors.gd` 21/21.
- Köprü + enemy.gd anahtarlı bağlantı + uyku modeli + C++ yürüme/bekleme animasyonu; gerçek oyunda A/B eşleşiyor
  (bkz. "Şu an"), 200 yaratıkta fizik adımı 8,05 -> 0,99 ms.
- Yeni araçlar: `tools/enemy_rewrite/run_godot.ps1` (headless çalıştırıcı, `-Env "K=V;K=V"`), `bench_world.gd`,
  `test_world_behaviors.gd`, `test_world_ingame.gd`; `bench_current.gd` artık ENEMY_WORLD=1'de köprü kırılımını da yazar.
- Öğrenilen: preload edilmiş betiğin statik değişkenine `.get()` ile değil doğrudan erişilir; köprü düğümü ertelenerek
  eklendiği için aynı karede `get_node` bulamaz (bench bir kare bekliyor); PowerShell `-File` hashtable parametresi almaz.
- PLAN §4.1'deki "ENEMY_SEPARATION_SMOOTH 0,35" yanlıştı (enemy.gd'de 0,025), düzeltildi.
- Aynı oturumun devamı: Aşama 2 dilim A (mermi isabeti C++ sorgusuyla, fizik gövdesi + HitArea + dönüşüm bildirimi
  kapalı, get_enemies_near C++'ta, yeteneklerin dışarıdan yazdığı AI alanları özellikle C++'a yönlendi), 4 kütüphane
  derlendi (Android dahil). Bulunan/çözülen: HitArea canlıydı (eski yorum yanlış) -> C++ modeli 211/212 birebir;
  headless'ta oyuncu hiç yürümüyormuş -> testler oyuncuyu doğrudan taşıyor. Son ölçüm: yürüyen oyuncu, 1000 yaratık 2,67
  ms (2,5 µs/yaratık; eski ~38 µs).
- Öğrenilen: A/B'de tek koşunun hasarı ±10 % oynuyor - sonuç için her yoldan 3+ koşu ve sayımlar (atış/lazer/yakın
  saldırı) gerekli; HitArea gibi şüpheli modelleri AYNI koşuda iki yöntemle sayarak doğrula.

### 2026-10-03 (geç) - Aşama 1 dilim 1 C++ çekirdeği (hesap: ilk hesap, kota bitti)
- PLAN §4.1'e C++/GDScript bölüşüm tasarımı yazıldı (enemy.gd `_physics_process` satır satır okunarak).
- `gdextension/enemy_world/` yazıldı, Windows DLL derlendi; çalıştırılmadı (bkz. "Şu an").

### 2026-10-03 - Aşama 0 tamamlandı (hesap: ilk hesap)
- Ölçüm betikleri depoda: `tools/enemy_rewrite/compile_check.gd` (tüm betikler derleniyor mu), `bench_current.gd`
  (gerçek menü akışı, mevcut sistem), `bench_soa_gd.gd` (GDScript düz dizi prototipi), `bench_soa_cpp.gd` +
  `bench_soa_cpp/` (C++ prototipi). Hepsi headless; komutlar dosya başlarında.
- Sonuç (yukarıdaki tablo): eski 36 µs/yaratık, GDScript 8-11 µs, C++ 0,22-0,5 µs simülasyon. Karar C++.
- Araç zinciri kuruldu ve hem Windows (.dll) hem Android arm64 (.so) derlemesi doğrulandı. Tuzaklar PLAN §6.1'de
  (python takma adı AppData'yı sanallaştırıyor; godot-cpp 4.5 + clang 23 için cstdlib yaması).
- Ayrıca doğrulandı: elit aurası (arka katman sprite altında, ön katman üstünde, golemde ölçek 1,5, görünmezken gizli,
  ölünce siliniyor) ve tüm 303 betik derleniyor (`compile_check.gd`).
- Doğrulanmadı: C++ prototipinin Android'de gerçek telefonda çalışması (sadece derlendi).

### 2026-10-03 - plan kuruldu (hesap: ilk hesap)
- Kullanıcı tam yeniden yazıma karar verdi; kotası bitince başka hesaptan devam edeceğini söyledi -> devir düzeni kuruldu:
  `docs/yaratik_yeniden_yazim/PLAN.md` + bu dosya + `.claude/skills/yaratik-yeniden-yazim/SKILL.md` + CLAUDE.md §9.
- Kapsam ölçüldü (PLAN §3). Kod değişikliği yok.
