# 2v2 PvPvE MODU - PLAN (çok oturumlu iş)

Durum: Aşama 1a UYGULANDI (2026-11-12, madde 607: mod + takımlar + kamp üsleri; ayrıntı ILERLEME.md), Aşama 2 (rakibe hasar, madde 615) + Aşama 3 + 4 (destek / kontrol / ölüm / skor / zafer / takım XP, madde 617) UYGULANDI; kalan: arayüz cilası (TAB tablosu, sohbet) + denge. Aşama 0 (ölçüm) kullanıcı
kararıyla denge aşamasına ertelendi ("daha sonra cila çekeriz dengeleriz"). Cila dönemi sürüyor; kullanıcı açıkça istedi. Uygulama kullanıcı "başla" deyince,
BİR OTURUMDA TEK AŞAMA. Her aşamanın sonucu `ILERLEME.md`'ye yazılır. Bölüm 2'deki kuralların hepsi 2026-11-12'de kullanıcı tarafından kabul edildi
("önerilerini kabul ediyorum"); 2.1 (ölüm / dirilme) ve 2.2 (takım üssü) aynı gün kullanıcının sorusu / fikri / kararlarıyla eklendi; 2.2'nin "üsten dışarıya hasar" satırı soruldu.

Kullanıcı (2026-11-12): "normal oyun haritasında 2v2 tarzı pvp-pve karışık bir oyun modu ... oyun olduğu gibi çalışacak ama pvp de olacak takım halinde".
Önceki konuşmadaki sorun: "her oyuncunun hasarı dayanıklılığına göre çok yüksek" (hasar çarpılarak, can toplanarak büyüyor).

## 1. Hedef
- Ana harita + normal koşu AYNEN: kademeler, yaratıklar, level kartı + pazar, sandık, görevler, seyyar satıcı, K5/K10 bossu.
- 4 oyuncu, 2 takım. Takım içi co-op bugünkü gibi. Karşı takıma hasar ve kontrol etkisi gider.
- Yaratıklar herkese düşmandır (üçüncü taraf); en yakın oyuncuya saldırır, takım bakmaz.
- Co-op kipi BİREBİR aynı kalır. Bütün işin ana güvencesi bu (bkz. 7).

## 2. Kurallar (önerim)
| # | Konu | Öneri | Durum |
|---|------|-------|-------|
| K1 | Zafer | (a) rakip takımın iki oyuncusu da kalıcı öldü (kalpler bitti) YA DA (b) K10 bossu ölünce son vuruşu yapan takım kazanır | kabul |
| K2 | Başlangıç | ev açılışı + kuşatma + babaanne kapalı (`ev_acilisi` false); her takım haritanın bir ucundaki kendi ÜSSÜNDE başlar (2.2); ilk 60 sn PvP kapalı ("hazırlık") | kabul |
| K3 | Seviye | takım başına ayrı XP / seviye (bugün tek `GameManager.team_xp`); yaratık XP'si toplayan oyuncunun takımına | kabul |
| K4 | Altın | kişisel (bugünkü gibi); asist + %20 takım payı yalnız takım arkadaşına; rakip oyuncu öldürme ödülü (taban + kademe; seri bozma eki) | kabul |
| K5 | Silah oto-nişanı | rakip oyuncu normal hedef adayı, ama silah hasarı oyuncuya ayrı çarpanla (başlangıç x0,4). "Oyuncuya odaklan" tuşu sonraki aşama | kabul |
| K6 | Dost ateşi | yok; takım arkadaşına hasar / kontrol / itme hiç gitmez | kesin |
| K7 | Görüş | takım görüşü (kendi + takım arkadaşı); rakip, görüş dışında dünyada + minimapte görünmez; saklanma çalılığı rakibe karşı da çalışır | kabul |
| K8 | Bosslar | ortak, tek boss = yarış. K5 bossunu öldüren takıma 3 dk güç (hasar + iyileşme, LoL Baron'u gibi) | kabul |
| K9 | Güvenli alan | seyyar satıcının koruma bölgesinde PvP yok (orada zaman zaten donuyor, madde 325) | kabul |
| K10 | Ruh hâli | bugün menüdeki oyuncu dokunulmaz (madde 438) = PvP'den kaçış. PvP savaşındayken (son 6 sn'de oyuncudan hasar) level / pazar / sandık menüsü açılmaz, savaş bitince açılır; menüye süre sınırı (20 sn, sonra `auto_pick`); "herkes menüdeyse dünya durur" yalnız 4 kişi birden menüdeyken | kabul |
| K11 | Teslim | takım içi oylama (2 kişi oybirliği) -> o takım kaybeder (madde 540'ın takım sürümü) | kabul |
| K12 | Kalp / diriliş | cesette diriltme yok; ölüm süresi (10 sn + 2 sn x kademe) sonra YALNIZ kendi üssünde doğuş, her dönüş 1 kalp - ayrıntı 2.1 / 2.2 | kabul |
| K13 | Sonsuz mod | bu kipte kapalı (zaferle oyun biter) | kabul |

### 2.1 Ölüm ve dirilme (kamp önlemi; 2026-11-12, kullanıcı kararı: "yalnızca üste doğsun")
Kullanıcı (2026-11-12): "bir oyuncu yere düştüğünde diğer oyuncular etrafında kamp kurup onun diriltilmesini önlemez mi?" Evet, bugünkü kurallarla önler.
Ardından: "oyuncular ölünce bir süre yerde ölü kalıp sonrasında orada [üste] dirilecek" + "yalnızca üste doğsun".
Bugün (player.gd `die` / `_process_downed` / `_rise_from_permadeath_to_downed`):
- Kalbi olan oyuncu düşünce kalp HEMEN harcanır, ceset yerinde bekler.
- Haritada hayatta bir müttefik olduğu sürece bekleme SINIRSIZ.
- Diriltme = müttefik 90 birim içinde 3 sn durur (`REVIVE_RANGE`, `REVIVE_CHANNEL_TIME`). Uzaklaşınca kanal 2 kat hızla geriler, hasar kanalı kesmez.
- Diriltecek kimse kalmazsa 10 sn sonra kalıcı ölüm (`DOWNED_NO_RESCUER_GRACE`).
- Kalp yenilenince kalıcı ölü CESEDİN YERİNDE yeniden düşmüş olarak kalkar.

PvP'de üç yer kampa açık: sınırsız bekleme, sabit ceset yeri, cesette kalkış. PvP kipinde şu kurallar geçerli (co-op aynen kalır):
- Cesette diriltme YOK. Ölen oyuncu "ölüm süresi" boyunca cesette yatar: 10 sn + kademe başına 2 sn (K1 10 sn, K10 28 sn).
  Bu sürede arkadaşlarını izler (madde 288 şeridi), sayaç ekranda. Ceset başında kamp kurmanın hiçbir kazancı kalmaz.
- Süre bitince oyuncu kendi takımının ÜSSÜNDE (2.2) tam can + kalkanla doğar. Her dönüş 1 kalp harcar.
  İki takım arkadaşı aynı anda ölse de böyle olur (kalıcı ölüm yalnız kalp bitince).
- Kalbi 0 olan ölen oyuncu üste dönmez, kalıcı ölür. Kalp yenilenince cesette değil üste kalkar.
  Ölüm ekranındaki diriltme satın alma (500 altın, main.gd `MINI_SHOP_REVIVE_COST`) da üste doğurur.
- Eleme (K1): bir takımın iki oyuncusu aynı anda kalıcı ölüyse o takım hemen kaybeder; kalp yenilenmesi ya da satın alma beklenmez.
- Üsten çıkış kampına karşı: dirildikten sonra ilk kez üsten ÇIKINCA 3 sn oyuncu hasarına dokunulmazlık (saldırınca biter).
  Üsten her yönden çıkılır ve takım görüşü içeriden dışarıyı gösterir: iki kişi bütün çevreyi tutamaz.
- İnfaz yok (zaten diriltme yok). Öldürme ödülü öldürene (K4); asist son 8 sn'de hasar verenlere (madde 167). Ölü oyuncuya yaratıklar bugünkü gibi saldırmaz.

### 2.2 Takım üssü (kullanıcı fikri + kararları, 2026-11-12)
Kullanıcı: "oyuncuların doğduğu tarafa kendilerini güvende tutan seyyar satıcıya benzer koruma alanı olan bir üs ... burdayken oyuncular iyileşip toparlanabilmeli
yeteneklerini doldurabilmeli ... ancak bu bölgede pek yaratık spawnlanmamalı ... bu güvenli alanlara kendi takımı haricinde başka oyuncular giremeyecek."
Sonra: "yaratıklar da o alana giremesin, 4sn hasar almama kuralına da gerek yok girdiği anda yavaşça iyileşmeye başlasın. ama çok hızlı olmasın bu iyileşme ve kalkan yenileme".
Satıcı bölgesiyle farkı (satıcı: game_manager.gd `MERCHANT_ZONE_RADIUS` 185, `is_safe_zone_frozen`):

| | Seyyar satıcı bölgesi (bugün) | Takım üssü (PvP kipi) |
|---|---|---|
| Zaman / beklemeler | donar (can yenilenmez, Q/E/R dolmaz) | NORMAL akar: Q/E/R, ruhani, yük, eşya beklemeleri dolar |
| İyileşme | yok | girer girmez, şartsız, YAVAŞ: saniyede azami canın %2'si + azami mana kalkanının %2'si (boştan tama ~50 sn; tek sabit, oyun testinde ayarlanır). Karakterin kendi yenilenmesine eklenir, kalkan yenilenme gecikmesini beklemez. Girişte zehir / yanma / kanama söner |
| Yaratıklar | içerideki oyuncuyu hedef almaz, mermileri söner (enemy.gd ~993 / ~3140, `*_projectile.gd`) | YAKLAŞMAZ (bosslar dahil): üssün çevresindeki ince GERİ DÖNÜŞ HALKASINA (üs yarıçapı + ~80 birim) giren yaratık hedefini bırakır, üsten uzağa doğru hızlıca (x1,5 hız, ~1,2 sn) geri döner, sonra normal davranışa döner. Üsteki ya da halkadaki oyuncuyu hedef almaz (satıcı kuralı), mermileri / yetenekleri sınırda söner. Sert sınır (C++ `push_out_of_zones`) yalnız son güvence: itme / geri tepme ile içeri savrulan yaratık dışarı atılır |
| Doğuş | içerideki oyuncu doğuş çapası değil (enemy_spawner.gd ~1303-1364) | AYNI kural + doğuş noktası hiçbir üssün yarıçapı + 300 birim içine düşmez. Üste oturan takıma yaratık gelmez, kasılmak için çıkmak zorunda |
| Rakip oyuncu | girer (PvP yok, K9) | GİREMEZ: kendi makinesinde sınırda durur (duvar gibi kayar, `wall_slide.gd`); atılma / ışınlanma / uçuş / duvar geçen yetenekler (`passes_walls()`) sınırda kesilir; itme dışarı atar |
| Üsten dışarıya hasar | - | KARAR (soruldu). Öneri: YOK. Üsteyken silah / yetenek dışarıdaki yaratığa da oyuncuya da hasar vermez, silahlar hedef almaz. Nedeni: yaratıklar içeridekine dokunamaz; geri dönüş halkasıyla sınırda beklemezler ama kovalayan sürüyü üsse çekip dönen yaratıkları içeriden vurmak yine bedava kasılma olur |
| PvP hasarı | yok | saldıran YA DA kurban üsteyse oyuncu hasarı ve kontrol 0 |

- Yaratık engeli teknik (kullanıcı 2026-11-12: "yaratıklar bu bölgeye yaklaşmasın hızlıca geri dönsün bu bölgeye yaklaşıldığında"):
  - Bugün C++ bölgesi yalnız bir HEDEFE (oyuncuya) bağlı kubbe (`t_zone`, `zone_r_along`, enemy_world.cpp ~2389 `push_out_of_zones`). Üs için hedeften bağımsız, kalıcı bölge listesi gerekir
    (yaratık onu kovalamaz). Kural C++'ta (CLAUDE.md: yaratık hareket kuralı = enemy_world.cpp + 4 kütüphane derlenir; GDScript'te her karede yaratık taraması YAZILMAZ).
  - Geri dönüş, var olan korku kaçışının (`F_FEAR_FLEE` + `set_fear_source`, enemy.gd `apply_fear`) görsel / durum simgesi / kontrol sayacı (`BalanceLog.on_cc`) OLMAYAN sürümü:
    kaynak = üs merkezi, hız çarpanı, bosslara da işler (Melek korkusu bossa işlemez), hasar vermez. Yeni zamanlayıcı uyku kuralına girer (`_ew_hard_active`, madde 267/278).
  - Yol bulma: üs + halka yol ızgarasında kapalı. Yoksa üssün öbür yanındaki oyuncuyu kovalayan yaratık halkada ileri-geri salınır (yaklaş, dön, yaklaş).
  - Halkadaki oyuncu yaratığa karşı güvende ama rakip oyuncuya açık (PvP kuralı yalnız üssün kendisinde). Kaçan yaratığı arkadan vurmak serbest bir kaçış ödülü;
    halka ince tutulur ki sınırdan kasılma yeri olmasın (oyun testinde ölçülür).
  - Sınırın şekli görsel sınırla aynı hesap olmalı (kubbe gibi elips ya da daire, Aşama 1'de seçilir).
- Yer: K2'deki iki uç (sol / sağ maden köşesi yakını), ama maden üssün DIŞINDA kalır (yoksa güvenli altın olur). Aşama 1'de gerçek haritada seçilir:
  açık zemin, ulaşılabilir (`tools/harita_secimi/hareket_yoklama.gd` deseni), merkeze eşit uzaklık. Bekçi kampı / görev / satıcı durağı / boss doğuşu üsse düşmez.
  Yol kesmemeli: yaratıklar giremediği için üs bir geçidi tıkarsa yaratık akışı bozulur.
- Boyut: başlangıç yarıçapı ~280 birim (satıcının ~1,5 katı; 4 kişi sığsın), oyun testinde ayarlanır.
- Görünüş: Harita.tmx'e DOKUNULMAZ (üs yalnız PvP kipinde var). Çalışma anında `team_base.tscn`: haritanın kendi set sanatıyla küçük kamp (çadır, sancak, kamp ateşi;
  "harita süsü = mevcut tileset sanatı"), çarpışmasız ya da yalnız küçük ayak izi. Sınır: Shaman E "Işık Perdesi" dili (madde 586, `shaman_aura_perde.gdshader` + `GroundSlot.add_on_floor`),
  takım renginde: kendi üssün mavi, rakibinki kırmızı. Minimapte iki üs.
- Satıcı nötr kalır (K9): iki takım da girer, orada PvP yok.

## 3. PvP hasar dengesi
PvE'de can çarpanı kullanılamaz (yaratıklar da vurur). Bu yüzden kurallar YALNIZ oyuncudan gelen hasara ve PvP savaşındaki iyileşmeye işler.
- Tek kapı: kurbanın makinesinde `scripts/pvp/pvp_rules.gd` `incoming(amount, info) -> float`. Yalnız orada hesaplanır; vuran taraf ham değeri yollar.
- Kademe çarpanı k(kademe): TAHMİN DEĞİL, Aşama 0'da ölçülen tablo. Hedef: eşit iki oyuncu arasında yeteneksiz ~5 sn, tam kombo ~2 sn'de ölüm.
  `k = hedefin etkin canı / (saldıranın tek hedef DPS'i x hedef süre)`.
- Kategori çarpanları (başlangıç, ölçümle ayarlanır): silah x0,4 (otomatik nişan bedava isabet), yetenek x1, süreli hasar x0,5, çağrılan / evcil / totem x0,5, alan hasarı x0,7.
- Tek vuruş tavanı: en çok hedefin azami can + kalkanının %25'i (tek atma yok).
- Kritik bonusu oyuncuya yarım.
- Can çalma, oyuncuya vurulan hasardan x0,3.
- "Yara": oyuncudan hasar aldıktan sonraki 5 sn'de gelen iyileştirme / kalkan / yenilenme x0,5 (kısa ve kısmi ki yaratık savaşı bozulmasın). Melek / Şovalye / Shaman / Oakley / Cadı'lı takımla ölçülür.
- Kontrol (sersemletme / dondurma / kök / korku / yavaşlatma): oyuncuya süre x0,5; aynı oyuncuya 15 sn içinde 2. kontrol yarım, 3. çeyrek, ardından 3 sn bağışıklık. Geri itme x0,5. Boss / elit çarpanları (`Enemy.damage_mult_of`) oyuncu kaynağına işlemez.
- Mana kalkanı soğurması (%80) ve kalkan türleri aynı; kalkan delme oyuncuda da çalışır.

## 4. Teknik mimari
### 4.1 Mod bayrağı
- `GameManager.game_mode` ("coop" | "pvp2v2"), tek kaynak `scripts/game_modes.gd` (`map_profiles.gd` deseni). Mod, harita profilinin `ozellik` bayraklarını ezebilir (ör. `ev_acilisi` false). `MapProfiles.feature()` önce moda bakar.
- ODA KUR'a "Mod" satırı (harita satırının yanında, madde 444); yalnız 4 kişilik odada açık. `_rpc_start_game(map_id, mode)`, geç katılım, LAN alanı, EOS özniteliği, host devri anlık görüntüsü (`_migration_resume_gm`), `LOBBY_PROTOCOL` artar.

### 4.2 Takım
- `lobby_players[peer]["team"]` (0 / 1). Seçim ekranında iki takım sütunu (`lobby_select_desktop.gd`), oyuncu takım değiştirir, host düzenler, 2 + 2 olmadan başlamaz.
- Tek yardımcı `scripts/pvp/teams.gd`: `team_of(peer)`, `is_ally(a, b)`, `is_enemy(a, b)`, `allies(tree, include_self)`, `enemies(tree)`.
  Co-op'ta herkes aynı takımdadır, `allies()` bugünkü kümeyi döndürür: co-op davranışı değişmez.

### 4.3 "Uzak oyuncu = müttefik" varsayımının denetimi
- Bugün "remote_players" grubu müttefik sayılıyor: 28 dosyada 60 grup taraması (2026-11-12 sayımı; player.gd 12, enemy.gd 4, enemy_spawner 4, main 4, network_manager 3, game_manager 3,
  assist, cadi_math, dome_weapon_ring, drop_attraction, fx_kalkan_bagi_link, hide_brush_manager, oakley_tree, paladin_dome, party_panel, minimap, yinyang_book, downed_spectate,
  mobile_party_column, pause_menu, mine_world, guard_camps, weather_storm, world_event_manager...) + NetworkManager'ın eş sözlükleri / `lobby_players` döngüleri.
- Her yer sınıflanır: (a) müttefik etkisi (iyileştirme, kalkan, bağ, diriltme, asist, yolcu, kubbe koruması) -> `Teams.allies`;
  (b) "herhangi oyuncu" (yaratık hedefi, doğuş, gövde ayrımı, hava) -> aynen; (c) rakip etkisi -> `Teams.enemies`.
- Koruma testi: tarama testi, `Teams` dışında yeni bir "remote_players" müttefik taraması eklenince uyarır (tüm betik derleme testi deseni).

### 4.4 Hasar yolu (yetki kurbanda)
- Bugün oyuncu hasarının yetkilisi kurbanın kendi makinesi: host, yaratığın kuklaya vuruşunu `forward_damage_to_peer` ile yollar (`_from_host` kapılı, network_manager.gd ~4364).
- PvP: vuran makine rakip kuklaya (RemotePlayer) isabeti bulur -> yeni `NetworkManager.pvp_hit.rpc_id(victim_peer, amount, info)` (CH_COMBAT;
  `info` = kategori, kritik, kalkan delme, kontrol türü / süresi, yetenek etiketi `s:...`).
  Kurban doğrular: gönderen canlı + rakip takım + mesafe makul (görüş elipsi + gecikme payı) + hazırlık / dokunulmazlık yok.
  Sonra `PvpRules.incoming` -> `take_damage`'ın PvP kolu. Sonuç mevcut durum senkronuyla yayılır.
- Host yolda değil (gecikme eklemez, host avantajı yok). Öldürme / kalp, bugünkü `die()` akışıyla host'a gider; yeni alan "öldüren peer".
- İsabet vuranın ekranında hesaplanır ("vurana göre"): kurban kaçtığını sanıp vurulabilir. Mesafe payı bunu sınırlar.

### 4.5 Hedeflenebilir rakip kukla
- Rakip RemotePlayer'lar "pvp_targets" grubunda; madde 496'daki "mission_copies" sözleşmesi örnek (yaratık olmayan, vurulabilen hedef; `weapon.gd` + `weapon_target_priority.gd` bunu zaten tanıyor).
- Tek yönlendirici `scripts/pvp/hit_router.gd`: `HitRouter.damage(target, amount, info)`. Yaratıksa eski yol, rakip kuklaysa `pvp_hit`. `PvpTargets.near(center, r)` alan sorguları için.
  Her vuruş yolu buna bağlanır: silah hedef seçimi (`weapon.gd _get_target_enemy`), mermi çarpışması, yakın dövüş matematikleri (`*_math.gd`),
  `EnemyQuery.candidates` çağıran alan hasarları, süreli hasarlar, kontrol.
- C++'a (`EnemyWorld`) dokunulmaz: oyuncular C++ dünyasında değil.
- Oyuncu tarafı kontrol: grep'te yalnız `apply_stun` + `apply_knockback_force` çıktı. Yavaşlatma / dondurma / kök / korku / süreli hasar durumunun oyuncuda olup olmadığı
  Aşama 3'te doğrulanır, yoksa eklenir (iki ekranda görünür: MP iki-yer kuralı).

### 4.6 Görüş
- `vision_fog.gd SOURCE_GROUPS` (bugün "player" + "remote_players" = herkesin görüşü ortak) -> kendi + takım arkadaşı.
- Rakip kukla takım görüşü dışında: sprite, karakter üstü çubuk, ad, minimap işareti gizli. Saklanma çalılığındaki rakip görüş halkası kuralıyla (madde 283).
- Hasar sayıları zaten yalnız vurana gider (değişmez).

### 4.7 Takım XP / seviye
- `GameManager.team_xp / team_level / team_xp_needed` -> takım başına; host yetkili, `set_team_xp_state` takım kimliğiyle. Level kartı / pazar / evrim kuyruğu kendi takımının seviyesine bağlı.
- Aşama 1'de kontrol: XP gereksinimi oyuncu sayısına göre mi ölçekleniyor? İki takımın her biri 2 kişilik takım gibi davranmalı.

### 4.8 Destek ve alan yetenekleri
- Müttefik süzgeci: Melek bağı, Şovalye E / R koruması + hasar yönlendirmesi, Shaman E şeridi, Oakley ağacı, Cadı iksirleri (iyileştirme / kalkan yalnız takıma, hasar iksirleri rakibe),
  Cadı süpürgesi yolcusu, Yin Yang kalkan alıcısı, Kalkan Bağı ortağı, Peri, papağan düşürmesi, asist, takım payı.
- Ceseti dirilten yetenekler (Oakley R finali "Kadim Diriliş", `oakley_revive` yayını, madde 348) PvP kipinde cesedi kaldırmaz (2.1: diriltme yok); yerine ne yapacağı Aşama 3'te.
- Şovalye kubbesi rakip oyuncuyu da dışarıda tutar: yerel hareket kuralı (`PaladinDome`), kuklada değil sahibin makinesinde.

### 4.9 Değişmeyenler
- Yaratık yapay zekâsı, doğuş, tavan (oyuncu sayısına göre zaten), kenar bekçileri, maden, hava, gün-gece.
- Görevler açık; ödül tamamlayan takıma. Takım ayrımı anlamsızsa görev bu kipte kapatılır (Aşama 4'te tek tek bakılır).

## 5. Arayüz (masaüstü; telefon sonra)
- Takım rengi: müttefik mavi / rakip kırmızı. Ad + karakter üstü çubuk kenarı. Renkler `hud_theme.gd`'ye rol olarak (`TEAM_ALLY` / `TEAM_ENEMY`, stil rehberi).
- Üst orta skor şeridi: iki takımın seviyesi, kalan kalpler, öldürme sayısı; TAB'da ayrıntılı tablo.
- Öldürme bildirimi: `game_notice` sağ sütun (compact).
- Grup paneli yalnız takım arkadaşı; minimapte rakip yalnız görüşteyken.
- Sohbet: takım (varsayılan) / herkes.
- Oyun sonu: KAZANDINIZ / KAYBETTİNİZ + iki takım tablosu (`game_over_board.gd`).

## 6. Aşamalar (bir oturumda bir aşama)
- **Aşama 0 - Ölçüm (oyun kodu yok).** `tools/buyuk_test` yeni kip `pvp_ttk`: K2/4/6/8/10'da her karakterin tipik yapısıyla tek hedef DPS'i (silah / Q / E / R ayrı)
  + etkin can (can + kalkan, soğurma, yenilenme). Tipik yapı = balans kaydındaki `stats` / `cards` kademe ortalaması (madde 269). Çıktı: k(kademe) tablosu `docs/pvp/olcum.md`.
- **Aşama 1 - Mod + takım altyapısı (PvP hasarı YOK).** `game_modes.gd`, ODA KUR "Mod", lobi takım sütunları + `team`, `teams.gd`, 4.3 denetimi, takım XP, takım görüşü,
  asist / takım payı / sandık sırası / teslim takım içinde, ev açılışı kapalı,
  TAKIM ÜSLERİ (2.2: yer seçimi, `scripts/pvp/team_base.gd` bölge sorgusu `TeamBase.at(pos)` / `blocks(team, pos)`, yavaş iyileşme, doğuş çapası + doğuş noktası dışlaması,
  yaratık geri dönüş halkası + sert sınır (C++ kalıcı bölge + 4 kütüphane), rakip girişi engeli, sınır görseli, minimap).
  Bitiş ölçütü: co-op kipinde hiçbir şey değişmedi (ilgili testler + tek oyunculu duman + `run_audit` bir co-op kipi); pvp kipinde iki takım aynı haritada ayrı ayrı oynuyor.
- **Aşama 2 - Silahlar oyuncuya vurur.** `hit_router.gd`, `pvp_hit`, `pvp_rules.gd` (k tablosu, kategori, tavan, kritik, can çalma, yara, üste PvP yok), tüm silahların vuruş yolları
  (mermi / yakın dövüş / ışın / saçma / alan / özellikler), hazırlık süresi + güvenli alan, isabet efekti iki ekranda.
- **Aşama 3 - Yetenekler + kontrol + çağrılanlar.** 14 karakterin Q / E / R / pasifi için tablo (rakibe ne yapar), oyuncu tarafı kontrol + azalan etki, Necromancer iskelet / golem,
  totemler, evciller rakibe saldırır, kubbe / görünmezlik / çalılık rakibe karşı.
- **Aşama 4 - Ölüm, kalp, zafer.** Ölüm / dirilme kuralları (2.1: cesette diriltme kapalı, ölüm süresi, yalnız üste doğuş, üsten çıkış dokunulmazlığı, kalp),
  öldürme ödülü + seri, öldüren alanı, diriliş dokunulmazlığı, K5 bossu takım gücü, K10 / eleme zaferi, takım teslimi, ruh hâli kuralı (K10), görevlerin takım ödülü.
- **Aşama 5 - Arayüz.** Bölüm 5.
- **Aşama 6 - MP denetimi + denge.** 4 süreç (`tools/tanitim/coop.ps1` 4 süreç düzeni örnek) ile `run_audit.ps1 -Mode pvp`; gerçek oyunda öldürme süresi ölçümü;
  balans kaydına `mode` + PvP alanları (verilen / alınan oyuncu hasarı, öldürme, ölüm nedeni), `BALANCE_REV`.

## 7. Riskler / tuzaklar
- En büyük risk co-op'u bozmak. Her değişiklik "herkes aynı takım" durumunda birebir eski davranışı vermeli; `Teams` co-op'ta eski kümeyi döndürür.
- MP iki-yer kuralı: rakibe vuruş efekti, kontrol görseli, öldürme bildirimi iki ekranda (CLAUDE.md).
- Ruh hâli kaçışı (K10) ve dokunulmazlık pencereleri (diriliş, hazırlık) birlikte test edilmeli.
- "Vurana göre" isabet + gecikme: mesafe payı az olursa haklı vuruşlar düşer, çok olursa duvar arkasından vuruş olur.
- Desteklerin ölümsüzlüğü: yara kuralı olmadan Melek / Şovalye'li takım ölmez. Aşama 0 ölçümüne iyileştirme de girer.
- Hile: arkadaş oyunu; kurban tarafı doğrulama yeterli, sunucu yetkisi yok.
- Kapsam dışı: 1v1 / 3v3, arena, eşleştirme, telefon arayüzü, diğer haritalar (sonra harita profiliyle açılır).
