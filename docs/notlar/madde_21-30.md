# CLAUDE.md maddeleri 21-30 (taşındı 2026-10-10; numaralar AYNI, başka dosyalardaki "madde N" atıfları geçerli)

21. **Efsunlar kapalı, kalıcı ölüden kalkış, minimapte ölüler, Vampir/ork/kademe kapısı ayarları (2026-10-06/07).**
   (a) `EnchantDefs.enabled = false` (scripts/enchant_defs.gd): silah efsunları OYUNDAN çıkarıldı (kart havuzu `enchants_for()` boş) ama
   TÜM veri yerinde (21 tanım, scripts/enchants/*.gd, assets/fx/enchant, enchant_area/behavior altyapısı, testler) - geri açmak için
   anahtarı true yap; efsun kurallarını sınayan testler anahtarı geçici açıp kapatır. Kalkan seçimleri (shield_enchant_defs.gd) ve genel
   kartlar aynen çalışır (elit sandık ekranı onları sunardı; 2026-10-07'den beri elit sandık epik eşya verir, bkz. madde 22). (b) Kalıcı ölü (is_dead, is_downed değil) oyuncunun diriltme hakkı varsa
   (hak yenilenmesi 5 dk) VE hayatta bir müttefik varsa `player.gd _process_permadeath_rise` hakkı harcayıp onu "yerde yatan" (kurtarılabilir)
   duruma çevirir (`rose_from_permadeath` -> main.gd izleyici/ölüm ekranını kapatır, `NetworkManager.report_self_alive_again` host'un
   `_confirmed_dead_peers` kaydını siler; dükkandan diriltme de artık aynı kaydı siliyor - eskiden canlı oyuncu "ölü" sayılıp oyun erken
   bitebiliyordu). (c) Minimap ölü/yerde yatan oyuncuları artık atlamaz: kararmış portre + kırmızı çarpı + nabız halkası. (d) Kademe
   kapısı (eski kademe ölmeden yenisi doğmaz) beklerken kapıyı tutan, görüş dışındaki eski yaratıklar 3x hızlanır
   (`enemy_spawner.gd _gate_rush_tick`, `enemy.gd set_gate_rush`). (e) Ork öfkesi hız artışı x0.85, Vampir R can bedeli %2,5/sn, Vampir Q
   bedelsiz. Testler: test_permadeath_rise_and_dead_minimap_markers, test_enemy_spawner_gate_and_ambush, test_new_enchants,
   test_vampir_cocuk, test_enemy_abilities. Oyunda iki gerçek oyuncuyla elle denenmedi (rise yolu OfflineMultiplayerPeer'li birim testle).

22. **Sandık kuralları: normal = sırayla, elit = herkese epik eşya (2026-10-07).** Kullanıcı: "elit sandıklardan sadece epik item çıkacak çünkü efsunları
   kaldırmıştık; normal sandıklar sırayla oyunculara verilecek, alan kişi sıradaki değilse sandık grup penceresinden o kişinin barına gidecek; elit sandıklar
   herkese eşit dağıtılacak". (a) NORMAL: `NetworkManager.host_award_chest` alıcıyı `advance_chest_turn` / `next_chest_turn` ile seçer (yaşayan katılımcılar peer id'ye
   göre küçükten büyüğe döner, `_chest_turn_last_peer` host'ta tutulur, oda/oyun sıfırlanınca 0; ilk sandık en küçük peer id'ye = host). Sandığı yerden ALAN kişi
   alıcıyı belirlemez (eski "alan alır" ve "1/N rastgele" kuralları SİLİNDİ, `pick_chest_winner` kalktı). Alan ≠ alıcı ise `_rpc_announce_chest_winner(picker, winner)`
   HER peer'de `scripts/chest_pass_fx.gd`'yi oynatır: küçük sandık alanın çubuğundan (müttefik = `party_panel.gd get_row_center`, kendimiz = `hud.gd get_own_bar_center`)
   alıcınınkine uçar; konumlar her peer'de yerel okunur, ağdan koordinat gitmez; çubuk bulunamazsa (telefonda kapalı panel) efekt atlanır, yüzen yazı kalır. Sandığın
   altın payı alıcıyla gider (`_award_chest_gold([winner])` değişmedi). Sıra göstergesi (kimde sıra) kalıcı olarak ekranda YOK - sadece uçuş + yüzen yazı.
   (b) ELİT: `host_award_elite_chest` değişmedi (yaşayan HER oyuncuya birer tane, sıra ilerlemez); açılınca `main.gd _show_elite_chest` artık efsun ekranı değil
   `chest_menu.gd`'yi ELİT modda açar (`setup(player, 0, true)`: `item_pool(true)` = sadece EPİK eşyalar, destekçi-özel olanlar elenir; kart çerçevesi epik (TierSystem 3), elit
   sandık animasyonu/ışınları, başlık "ELİT SANDIK", altın `pop_pending_chest_gold(true)`). Epik de AL/SAT'lı (SAT = fiyatın %70'i); epik slotu (10) doluysa AL kapanır.
   Efsun ekranı (`enchant_screen.gd`) sadece debug menüsünden. Testler: `test_chest_turn_rotation` (10, mutasyonla sıra + epik havuz denendi), `test_chest_system`,
   `test_spiritual_skills_and_rewards`. 2026-10-07 başsız İKİ GERÇEK SÜREÇ (host + istemci, gerçek Main + gerçek kuyruk): 3 sandık -> [host, istemci, host], elit -> ikisi de
   epik aldı, uçuş iki tarafta ters yönlü doğru koordinatlarla oynadı, hata yok. Gerçek oyunda görsel olarak (uçuşun nasıl göründüğü, telefon yerleşimi) elle izlenmedi.

23. **Demirci dükkanı (silah + kalkan satıcısı) ve harita yeniden bake (2026-10-07).** Kullanıcı: "haritayı Harita.tmx üzerinden yeniden bakeler misin ama
   hiçbir şeyi kaybetmesin; yeni blacksmith yapısının kapısından içeri girince yeni bir dükkan, örse yaklaşınca etkileşimle silahlar burada satılsın, kalkanlar
   da, seyyar satıcıda silah satılmayacak". (a) HARİTA: `tools/bake_harita.gd` -> uid'leri eski dosyadan geri yaz -> eskiyle düğüm/materyal farkı (memory
   map-rebake-procedure) yapıldı; shader/materyal/y_sort aynı, 1 TileSet, hücre sayıları TMX ile birebir. Kullanıcının Tiled'da sildiği `tarla` grubu bake'te
   düştü (kodda kullanılmıyordu). Minimap + harita gölgeleri de yeniden pişirildi (`bake_map_shadows.gd` CATS "house" artık `ev/Blacksmith` + `ev/blacksmith kapı`
   içerir); `--headless --import` BİLEREK çalıştırılmadı (iki PNG editör açılınca yeniden import olur; yeni betiklerin .gd.uid dosyaları da o zaman oluşur).
   (b) GİRİŞ/İÇ MEKAN: `scripts/weapon_shop.gd` (main.tscn `WeaponShop`, house_interior.gd deseni, aynı `is_indoors` bayrağı -> yaratık saldırmaz/doğmaz, silahlar
   gizlenir, kamera sınırı kalkar): dış kapı = `ev/blacksmith kapı` katmanının alt kenarı + etkileşim tuşu + kararma geçişi; iç mekan `scenes/silah_saticisi_baked.tscn`
   (`tools/bake_silah_saticisi.gd`, kaynak `harita/silah satıcısı.tmx`) `INTERIOR_OFFSET` (24000,0)'da (ev içi 20000,0'dan 4000 birim yanda); ÇIKIŞ = iç haritadaki
   `blacksmith kapı iç` katmanı (güney duvarda 2 hücre; "içi" DEĞİL "iç"); ÖRS = `Eleman pozisyon` katmanındaki tek karo (görünmez yapılır, yarıçap 84 px
   içinde etkileşim ipucu). Tiled'da bu katman adları değişirse weapon_shop.gd sabitleri güncellenmeli. ÇARPIŞMA çalışma anında: duvarlar (`walls`, `walls_top`)
   TAM; eşya katmanlarında sadece her sütunun en alt karosu (paketin katmanları nesnelerin tüm yüksekliğini taşıyor, hepsini kaplamak kapı cebini odadan
   ayırıyordu: doğma noktasından 11 hücre erişilebiliyordu); kapı önünde yanlarda 2, kuzeyde 3 hücre eşya çarpışması kaldırılır (oyuncu 16 px, tek hücrelik geçide
   sığmaz - testle ölçüldü). Doğma noktası SOL kapı hücresinin ortasının 3 hücre üstü (iki hücrenin ortası komşu duvar karosuna değiyordu). Oda dışı evin içi gibi
   düz SİYAH (kullanıcı seçti, `OUTSIDE_STYLE = &"clean"`): duvar paketinin koyu arduvaz dolgusu (39,38,46) duvar katmanlarında bir renk anahtarı gölgelendiriciyle siyaha çevrilir
   (gri kenar kalmaz; karoyu silmek yerine renk çevrildiği için zemin sızmaz) + zemin dikdörtgeninin dışındaki dolgu karoları silinir; `&"black"`/`&"match"` (gri boşluk) karşılaştırma
   için kodda durur, `set_outside_style` çalışma anında değiştirir. Evin içine dokunulmadı (orada gri kenar zaten yoktu). Önde çizilen
   katmanlar `torches_pillar_n_front`/`walls_top` z=2 (oyuncu z=1). Harita üzerindeki bina çarpışmasızdır (oyuncu/yaratık engeli sadece orman katmanında, kullanıcının
   bilinçli tercihi, bkz. player.gd `_block_movement_into_terrain`) - dokunulmadı. (c) KURALLAR `scripts/weapon_shop_logic.gd` (TEK kaynak, testli): 15 silahın hepsi,
   eski fiyatlar (ShopPanel `_copy_cost_raw`: 2. silah 30, sonrakiler 80; indirim `apply_shop_discount`), en fazla 5 silah, aynı silahtan 2. kopya serbest, ziyaret
   başına 1 kez kuralı YOK; kalkan Savaş/Enerji/Kale 250 altın, Standart'ın yerine geçer ve KALICI (bir tür seçilince diğerleri kilitli - kullanıcı bunu söylemedi,
   eski efsun kuralı; değiştirilebilir istenirse `shield_block_reason` + geliştirme sıfırlama); geliştirmeler (ShieldEnchantDefs `upgrades`, limit 0 = sınırsız)
   tür alınınca satılır, fiyat 100 + 25 x (o satırdan zaten alınan sayı) - fiyatı kullanıcı vermedi, benim seçimim (`UPGRADE_*` sabitleri). Satın alma efsun
   kartlarıyla aynı yoldan (`player.apply_enchant_choice`). (d) EKRAN `scripts/weapon_shop_screen.gd`: solda ayrıntı, ortada SİLAHLAR (2 sütun x 8 yatay plaka) /
   KALKANLAR sekmeleri, sağda envanter (5 silah yuvası + kalkan statları); oyunu duraklatmaz (seyyar satıcı gibi), ESC/B kapatır, kumandada D-pad seçer A satın alır.
   (e) SEYYAR SATICI: artık sadece 8 eşya (`STOCK_SIZE` 8, silah kartları ve ekrandaki SİLAHLAR bölümü silindi; ENVANTER penceresi silahları göstermeye devam eder).
   Tuzaklar: `move_and_slide` coroutine içinde `physics_frame` sinyalinden çağrılınca "Body state is inaccessible" hatası verir (gövdeyi `_physics_process`'ten sür);
   testlerde yaratılan dünyaları `free()` ile sil (`queue_free` "player" grubunu bir sonraki teste sızdırır). Testler: `test_weapon_shop` (16; mutasyonla kapı
   cebi kapanınca fiziksel yürüme testinin kırıldığı görüldü), `test_merchant_*` (eşya kartlarıyla yeniden yazıldı). Gerçek oyunda elle denenmedi; telefon düzeni
   (PHONE_K, merchant'tan kopya) ve iç mekandaki meşale/ocak animasyonları doğrulanmadı.

24. **Silah parçacığı (demirci dükkanında silah almak için para birimi, 2026-10-08).** Kullanıcı: "blacksmithdeki silahların silah parçacığı ile alınmasını
   istiyorum; yaratıklardan %0.5, elitten kesin 1, bosstan 5; oyunculara eşit miktarda gitsin (biri 5 alırsa 5 tane herkese); yemek gibi yerde dursun, hafif yukarı
   aşağı olsun; pixel sanatı hazırla; silah 10 parçacık + bir miktar altın, geliştirme başına 5 parçacık + altın". Soruyla netleşti: altın kısmı AYNI (2. silah 30 /
   sonrakiler 80, kalkan türü 250, geliştirme 100+25n), ve SADECE SİLAH parçacık ister - kalkan türü + geliştirmeler parçacıksız (kullanıcının son cevabı "geliştirmeler
   de parçacıksız"). `weapon_shop_logic.gd` `SHARD_COST_WEAPON = 10`, `SHARD_COST_UPGRADE = 0`, `SHARD_COST_SHIELD = 0`: geliştirmeye 5 parçacık isterse TEK satır
   (`SHARD_COST_UPGRADE = 5`) - kurallar (`*_block_reason`, `buy_*` düşer/iade eder) ve ekran (plaka + ayrıntı) hazır. DÜŞME `enemy.gd` `_drop_weapon_shards` (die()'da,
   sadece host/tek oyunculu): sıradan %0.5 x killer şansı (`LUCK_DROP_MULT_PER_POINT`, diğer drop'larla aynı çarpım - şansın bunu da büyütmesi benim seçimim),
   elit 1, boss 5 AYRI drop (halka şeklinde saçılır, her biri 1); `weapon_shard_count` saf fonksiyon, testli. YERDEKİ DROP `scripts/weapon_shard_drop.gd` +
   `scenes/weapon_shard_drop.tscn` (food_drop deseni: kök ±3 px zıplar, gölge `drop_shadow.gd`, 300 sn sonra kaybolur, grup `weapon_shard_drops`); `WeaponShardDrop.spawn(
   tree, konum, miktar)` "drop yarat + `broadcast_drop` yayını" sözleşmesinin TEK yeri (enemy.gd + debug menüsü bunu çağırır; yeni bir kaynak eklersen onu kullan).
   PAYLAŞIM: toplayan kim olursa olsun yaşayan HER oyuncuya `amount` (BÖLÜNMEZ, altın/sandık payının aksine): `NetworkManager.host_award_weapon_shards` -> host kendine +
   uzak oyunculara `grant_weapon_shards` RPC (sadece host'tan kabul). İstemcide görsel kopya (`network_spawned`) toplanınca `request_drop_pickup(.., "weapon_shard")`.
   SAYAÇ `GameManager.weapon_shards` (+ `weapon_shards_changed` sinyali, `add_weapon_shards`; koşu durumuna/geri katılım anlık görüntüsüne ve reset'e dahil). HUD:
   altın göstergesinin altında `ShardIndicator` (hud.gd `_ensure_shard_indicator`, hud.tscn'e YAZILMADI - editör geri alıyor; grup paneli/debug düğmesi sol sütunun alt
   kenarını `_left_stack_bottom()`'dan alır, yeni bir sol sütun parçası eklersen onu da oraya kat). SANAT `tools/gen_weapon_shard.py` (deterministik, 22x22, 6 kare
   parıltı; çıktı `assets/pickups/weapon_shard/`: `shard_sheet.png`, `shard_icon.png`, `weapon_shard_frames.tres`). Debug menüsü Oyuncu sayfası: "+10/+50 parçacık",
   "Parçacık düşür". Tuzaklar: weapon_shard_drop.gd sahneyi `preload` ETMEZ (sahne betiği önyüklüyor - döngüsel başvuru), `load()` kullanır; `grant_weapon_shards`
   `is_multiplayer_active` değilken reddeder (`_host_peer_id()` bağlı değilken 0 ve yerel çağrının gönderen kimliği de 0). Testler: `test_weapon_shards` (10),
   `test_weapon_shop` (parçacık maliyeti/iade/ekran, 21 toplam); İKİ SÜREÇLİ gerçek LAN: istemcinin üstüne 3, host'un üstüne 2, istemcinin üstüne 5 ayrı drop, ve
   host'un fiziksel toplaması KAPALI iken sadece istemci RPC yolu (6) -> iki tarafta da tam +16, drop kalmadı, uzak drop'un görsel kopyası istemcide göründü.
   Gerçek oyunda elle izlenmedi: parçacığın görünüşü/HUD yerleşimi, telefon yerleşimi, dükkan ekranındaki parçacık satırı.

25. **Derinlik / y-sıralama: karakter nesnenin arkasındayken altında, önündeyken üstünde (2026-10-08).** Kullanıcı: "bir şeyin arkasındayken karakter üstünde olup
   önündeyken arkasında olma mantığı" (yani standart derinlik). Oyuncular z_index 1'de (haritanın tamamının üstünde) olduğundan eskiden hiçbir harita nesnesi
   onları örtmüyordu (sadece otlarda vardı, `grass_sway.gd`). `scripts/depth_occluders.gd` otlarla AYNI "ön kopya" yöntemini genelleştirir (Main'e Y-Sort AÇILMADI -
   FX/yaratık/küre sırası bozulurdu): ağaç ("Shader Eklenecek/Ağaç 0/1/2", sallanan ağaç shader'ına `on_katman` eklendi, kopya aynı köşe kaydırmasını yapar),
   binalar (`BUILDING_GROUPS`: Blacksmith/Ev/kapı/ayrıntı/çatı katmanları 8-komşu bağlı bileşen = TEK kök, çatı ile duvar aynı anda önde/arkada), maden/çalı/düşman üssü
   (`OBJECT_LAYERS`, atlas komşuluğu = nesne) ve demirci iç mekanı (`SMITHY_INTERIOR_LAYERS`, `setup_interior`) katmanlarının bir KOPYASI z_index 2'de çizilir;
   `scenes/derinlik_on_katman.gdshader` kopyada SADECE kökü karakterin ayağından aşağıda olan pikselleri VE sadece karakterin gövde dikdörtgeninde bırakır (yaratık/küre
   örtülmez). Kök hesapları saf işlevlerde (`object_bases`, `building_bases`) - collision de bunları kullanacak. Karakter = yerel + uzak oyuncu (ayak +15, yarım genişlik 11,
   boy 34, grass_sway ile aynı). Orman parçaları/zemin BİLEREK dışarıda. Yaratık-oyuncu: `scripts/creature_depth.gd` (main.gd `CreatureDepth`): oyuncunun ÖNÜNDE
   (ayağı aşağıda) ve örtüşen yaratık geçici z 2; histerezis 2 px; evcil/müttefik dahil değil. Tuzaklar: yassı (zemine serili) bir katmanı OBJECT_LAYERS'a ekleme -
   oyuncuyu ayağının üstünde örter; Tiled'da katman adı değişirse sabitler güncellenmeli (sessizce atlanır). Testler: `test_depth_occluders` (5), `test_creature_depth`
   (2). Gerçek pencereli ekran görüntüsüyle ağaç/ev/maden doğrulandı (oyuncu arkadayken örtülüyor, önde görünüyor); düşman üssü, iç mekan ve yaratık z'si gerçek ekranda izlenmedi.
   (Collision için bkz. madde 27. Yaratıkların ağaç/ev arkasında örtülmesi, kopyaların z 3'e alınması ve çizim sırası koruması için bkz. madde 45.)

26. **Assasin pasifi + Q bekleme, Vampir Q kalkan bedeli (2026-10-08).** (a) Assasin "Bıçak Uzmanlığı" ("yetenek kullanımından sonra 3 sn garantili kritik") HİÇ
   uygulanmamıştı (sadece açıklama metniydi) - şimdi `player.gd _assasin_passive_on_skill_used` (Q `_try_assasin_dash2`, E `_activate_skill2`, R `_activate_skill3`; her kullanım
   3 sn'ye yeniler, oyun süresiyle azalır) -> `_roll_ability_crit` kesin true + `weapon.gd _passive_guaranteed_crit` iki kritik zarında. Yeni yetenek eklerken Assasin için
   AYNI kancayı çağır. (b) Şahin Hamlesi (Q) yük başı bekleme 10 -> 8 sn (`ASSASIN_DASH2_RECHARGE_TIME`). (c) Vampir Q (Kan Emme) kalkan bedelini YENİDEN öder (2026-10-06
   muafiyeti kalktı, `_activate_skill` muaf listesinde id 40 yok); karşılığında Kan Kalkanı evrimi hasarın %3 -> %6'sı (`EVO_VAMPIR_Q_SHIELD_RATIO`) ve Q 3 -> 4 hedef
   (`VAMPIR_Q_TARGET_COUNT`; Kan Ziyafeti hâlâ 5, metni "4 yerine 5"). Testler: `test_assasin_passive` (5), `test_vampir_cocuk` (32), `test_assasin_evolutions`.

27. **Collision "herşey için yeniden hesaplandı": su + bina tabanı + ağaç gövdesi + maden + düşman üssü, oyuncu VE yaratıklar (2026-10-08).** Kullanıcı: "oyundaki collision
   shapeleri yeniden hesapla herşey için"; soruyla: OYUNCU + YARATIKLAR (yol bulma dahil), su + evler/demirci + ağaç gövdeleri + maden/düşman üssü hepsi. Haritada gerçek
   CollisionShape2D yok; hareket engeli bir hücre sorgusu (orman duvarı = `GameManager.is_position_blocked_by_forest`). `scripts/terrain_collision.gd` (TEK kaynak) oyun
   başında (~65 ms) haritadaki karolardan hesaplar: nesne tabanının alt BANDI (ağaç 9 px, ev 28 px, maden 14 px, düşman üssü 12 px; kök = depth_occluders.gd `object_bases`/
   `building_bases`) piksel piksel taranır, hareket engeli KÖK noktasıyla (ayak +15 px aşağıda) sorgulandığı için ayak izi 15 px YUKARI kaydırılır, bir hücre en az 20 piksel
   alırsa engel (orman katmanının 16 px ızgarası). Su = "Su/Su" hücreleri 1 hücre yukarı; "Köprü/Köprü alt" altındakiler açık. Kategori başına sabit `ENABLE_*` (hepsi true);
   `stats` / `by_category` hata ayıklama. API: `GameManager.is_position_blocked_by_walls(p)` = orman VEYA bu hücreler -> HAREKET: player.gd `_block_movement_into_terrain` + ışınlanma/atılış
   noktaları (blink, Elara atılışı, Golem zıplaması, ruhani yürüyüş), skeleton/golem pet, görev kopyası, Hadime kara deliği; `is_position_blocked_by_terrain` (spawn/yerleşim)
   de içerir. BİLEREK SADECE orman kalanlar: mermi, ışın kısaltma, görüş (sis), duvara çarptırma, yetenek menzili (`is_position_blocked_by_forest`) - ağaç/ev/su ateşi ve görüşü kesmez.
   YARATIKLAR + YOL BULMA: `enemy_pathing.gd _build` orman ∪ nesne hücrelerini `_blocked`'a (A* + C++ hareket/akış alanı), SADECE ormanı `_fog_blocked`'a yazar; C++ `EnemyWorld.set_grid` yeni
   6. parametre `fog_blocked` (boşsa eski davranış) ve `fog_ray_blocked` onu kullanır -> su/ağaç görüşü KESMEZ. **4 kütüphane yeniden derlendi** (Windows debug+release, Android arm64
   debug+release; araç zinciri PLAN §6.1) - yeni bir C++ değişikliğinde yine derle. Kapılar da engel (içeri etkileşimle girilir, yakınlık tabanlı). Boşluk: oyuncu duvar önünde ayağı tabandan ~10 px
   uzakta durur (yoklama 10 px, orman ile aynı); arkadan yaklaşınca ayak tabandan ~40 px kuzeyde (derinlik sırası gereği evin arkasında gizli). Zaten engel hücresinin İÇİNDEKİ oyuncu/yaratık
   serbest (hapsolmasın). Tuzaklar: Tiled'da katman adları değişirse terrain_collision.gd sabitleri (test_terrain_collision_objects hepsini sınar); yassı bir nesne katmanını ekleme; yeni bir
   "hareket eden" kod yazarsan `is_position_blocked_by_walls` kullan (mermi/görüş ise forest). Testler: `test_terrain_collision_objects` (8: kategoriler, bina önden/arkadan, ağaç, su + köprü,
   spawn, yol bulma ızgarası, C++ yaratık suya girmez, su görüşü kesmez ama orman keser; mutasyonla 5'i kırıldı), `test_map_terrain_collision` (10, eski "kapalı" iki test ters çevrildi). Gerçek
   pencerede gerçek tuş basışıyla (kırmızı bindirme) bina/ağaç/maden/göl doğrulandı. Gerçek oyunda uzun süre oynanarak izlenmedi: yaratıkların göl çevresinde takılması, kapıya yürüme akışı, telefon.


28. **Çok oyunculu senkron denetimi aracı + bulgular (2026-10-08).** `tools/mp_audit/run_audit.ps1 [-Mode sync|rejoin]`: iki GERÇEK süreç (başsız LAN, host = Assasin, istemci = Vampir),
   her 1 sn'de gerçek durum vs diğer tarafın kuklası, yaratık/drop sayıları, takım durumu, ENet trafiği (`sync_audit_compare.py` raporlar); `rejoin` modu: istemci düşer, aynı kimlikle
   geri katılır, yakalama karşılaştırılır. Yeni bir senkron özellik eklediğinde koştur. Ölçüm (2 oyuncu, ~27 yaratık): yaratık konum hatası ort. ~6 px (p95 ~11), sayılar ±1 (ölüm gecikmesi),
   kukla durumu (silah anahtarları/seviye/xp/zaman/parçacık) eşit, can/kalkan en çok ~1 sn geriden (durum kanalı), host->istemci ~22 KB/s (112 paket/s), istemci->host ~6 KB/s, günlük temiz.
   Bulgular (HEPSİ 2026-10-08'de düzeltildi, bkz. madde 29): (1) rejoin yakalamasında yerdeki drop'lar (XP/altın/yemek/sandık/parçacık) YOK, aktif görev/evcil de yok; (2) rejoin yüklemesinde host'un RPC'leri
   "Node not found: Main" (~5/sn) ve o sırada gönderilen güvenilir yayınlar kayboluyor; (3) 99 any_peer RPC'de gönderen kontrolü yok + reddedilen yabancı bağlantısı kesilmiyor ve
   `_player_count()` (lobby_players) düşman canını şişiriyor; (4) oyuncu konum RPC'si `unreliable` (sıra yok); (5) yaratık durum paketi yaratık başına ~85 B / 0,15 sn.

29. **Çok oyunculu sağlamlaştırma (2026-10-08, madde 28 bulgularının düzeltmesi).** (a) `NetworkManager._from_host()`: host'tan gelmesi gereken ~40 RPC'nin ilk satırı
   (`if not _from_host(): return`; `sync_game_over/sync_team_xp/broadcast_victory/grant_*/open_chest_for_peer/_rpc_client_spawn_creature/_rpc_victory_dissolve...`). Tekli
   oyunda (`is_multiplayer_active` false) HER ZAMAN true - OfflineMultiplayerPeer'de yerel çağrı gönderen "1" görünür ama `_host_peer` 0'dır (ilk sürüm tekli oyunu
   bozuyordu, `test_endless_mode` yakaladı). Yeni bir host->istemci RPC eklersen aynı satırı koy. (b) Başlamış odaya giren yabancı: "Bu oyun başlamış" mesajından 2 sn
   sonra host bağlantısını keser (`_kick_stranger_later`), istemci mesajı korur (`_denied_by_game`). (c) Oyuncu sayısı = `NetworkManager.game_player_count()` (`_game_peers`:
   oyun başında lobideki herkes + kabul edilen geri katılımcılar), `lobby_players.size()` DEĞİL; istemci doğuşunda sayıyı host RPC ile alır (`player_count` parametresi,
   `_apply_global_buff(enemy, player_count)`), yaratığa `mp_player_count` meta olarak yazılır. (d) Sıra numaraları uygulama düzeyinde (Epic'te unreliable_ordered/kanal
   garantisi yok): oyuncu konum paketi `seq` (main.gd `_is_stale_transform`), yaratık paketi `tick` (`EnemySyncCodec.is_stale`); kural tek yerde `enemy_sync_codec.gd seq_newer`.
   (e) Yaratık durum paketi ikili: `scripts/enemy_sync_codec.gd` (22 bayt/yaratık, eskiden ~85). Alan eklersen codec'e + `tests/test_mp_hardening.gd`'ye ekle; paket başı 40
   yaratık Epic ~1100 bayt sınırının altında kalmalı. (f) HAZIR PEER KAYDI: host'un sık yayınları (`game_ready_peers()`) ve istemcilerin Main RPC'leri
   (`main_rpc_targets()`: konum/durum paketleri) SADECE Main'i kurulmuş peer'lere gider (`notify_main_ready_for_catchup` -> `_rpc_main_ready` -> `_publish_ready_roster`);
   yükleme ekranındaki geri katılana ve lobideki yabancıya "Node not found: Main" yağmuru kesildi. Yeni bir Main-düğümü RPC'sini SIK gönderirsen `for p in NetworkManager.
   main_rpc_targets(): f.rpc_id(p, ...)` kullan. (g) Geri katılana yakalama: yerdeki drop'lar (`collect_drop_catchup` / `_rpc_drop_catchup`, aynı `_spawn_visual_drop` kurulumu,
   kimlik tekrarı yok sayılır) ve süren görev (`world_event_manager._on_peer_needs_game_catchup` -> `broadcast_world_event_catchup`, main.gd bildirimsiz kurar). Evcil
   hayvanlar yakalanmaz. (h) BİLİNÇLİ YAPILMAYANLAR: aktarım kanalı ayrımı (ENet'te güvenilmez paketler zaten sıra beklemez; ayrım sadece güvenilir-güvenilir bloklanmayı
   azaltır, Epic'te kanal desteği doğrulanmadı) ve drop yayınlarını toplu gönderme (kazanç küçük, kayıp-sıra riski var). Denetim: `tools/mp_audit/run_audit.ps1 -Mode security`
   (host + istemci + yabancı: sahte host-RPC reddi, yabancı atma, oyuncu sayısı, yaratık canı iki tarafta aynı). Testler: `test_mp_hardening` (10, mutasyonla denendi).

30. **HOST DEVRİ (2026-10-08, kullanıcı isteği: "host çıkınca host devri de olsun").** Oyun SÜRERKEN host düşerse (menüye çıktı = `close_room`, çöktü, ağı koptu ya da 12 sn
   kalp atışı sessizliği) kalan oyuncular otomatik devam eder; lobideyken eski davranış (oda kapanır). Kurallar `scripts/net/host_migration.gd` (saf, testli), ağ/sahne tarafı
   `network_manager.gd` "HOST DEVRİ" bloğu. AKIŞ: host oyun boyunca herkese SIRA LİSTESİ (`_publish_migration_roster`: kimlik, ad, ENet uzak adresi, Epic kimliği; katılım sırası, host
   ilk) + 1 sn'de bir kalp atışı + spawner'ın DEVİR PAKETİ (`publish_host_handover`, ~2 sn) yollar. Düşünce her istemci AYNI listeden aynı adayı seçer (`_try_begin_host_migration`):
   kendi durumunu yakalar (`player.get_rejoin_snapshot()` + takım ilerlemesi + koşu bayrakları), dünyayı DONDURUR (`get_tree().paused`; NetworkManager PROCESS_MODE_ALWAYS), aday kendisiyse
   AYNI portta sunucu kurar (`_migration_host_start`: LAN ENet, internet odasında yeni EOSG sunucusu + oda ilanı) ve yükleme ekranından yeniden açar; değilse adaya bağlanır
   (`_migration_try_connect`) ve BİLİNEN geri katılım akışından geçer (`_rpc_game_in_progress_state` -> otomatik HAZIR -> `request_join_in_progress_game`; yeni host'un o oyuncunun kaydı
   olmadığı için `_rpc_receive_rejoin_snapshot` istemcinin KENDİ görüntüsünü korur). Aday 10 sn (Epic 30 sn) içinde kurulamazsa sıradakine geçilir, 55 sn (Epic 100) sonra
   eski davranışa düşülür (`host_left_game`). SONUÇ (soft restart, bilinçli seçim - kesintisiz devir yerine): herkes birkaç sn yükleme ekranı görür (LAN ~5 sn, çökmede ek ~5 sn tespit;
   Epic ~15-20 sn), kartlar/silahlar/seviye/altın korunur; YARATIKLAR, YERDEKİ DROP'LAR, SÜREN GÖREVLER, evcil hayvanlar, ölü oyuncunun ölü durumu (%35 canla döner) SIFIRLANIR;
   gün/hava (`_last_atmosphere_state`), oyun saati, zafer/sonsuz mod bayrakları ve spawner'ın gizli sayaçları (`export_handover/import_handover`; yaşayan boss'un kademesi "doğdu"
   sayılmaz, hemen yeniden doğar; zaferden önce Final yeniden doğar) korunur. Peer id'ler DEĞİŞİR (yeni host = 1, diğerleri yeni rastgele id) - bu yüzden devir sahneyi yeniden kurar,
   peer id'ye bağlı hiçbir durum taşınmaz. Koşu rekoru çift yazılmasın diye `GameManager.run_record_suppressed`. Tuzaklar: (1) [2026-10-10 DÜZELTME: asıl neden bu DEĞİLDİ - bkz. madde 62f: Epic'in tik'i duraklı ağaçta durduğu için bağlantı hiç kurulamıyordu; `ONLINE_RETRY_SEC` yeniden denemesi
   zararsız ama gereksiz, kaldı] Epic'te istek aday sunucuyu kurmadan gönderilirse ENet gibi yeniden
   denenmez, ASILI kalır -> `ONLINE_RETRY_SEC` ile periyodik yeni istek (ilk deneme gerçekten böyle takıldı); (2) devir sürerken dünya donuk olmazsa silahlar bağlı olmayan eşe RPC atar
   (hata yağar) - `main_rpc_targets()` devirde boş döner; (3) host düşünce EOSG'de birkaç RPC hatası kaçınılmaz (durum "bağlı değil"e dönüp sinyal gelene kadar); (4) devir sırası
   host'tan gelen listeye bağlı: istemci oyunun ilk saniyelerinde liste gelmeden host düşerse devir başlamaz, eski davranış. Test: `test_host_migration` (8) + ÜÇ SÜREÇLİ gerçek denetim
   `tools/mp_audit/run_audit.ps1 -Mode migration [-Kill crash|close] [-Net epic] -Secs 75` (host öldürülür; yeni host ilk katılan; ikinci istemci ona bağlanır; silah/seviye/altın korunur;
   yeni host'un doğurduğu yaratıklar ikinci istemcide görünür; günlükler temiz): LAN çökme + kapanma ve gerçek Epic çökme geçti. Gerçek oyunda elle oynanarak, telefonda, 4+ oyuncuyla ve
   iki aday birden düşünce (üçüncü adaya geçiş) denenmedi.
