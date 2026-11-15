# 2v2 PvPvE MODU - İLERLEME (plan: PLAN.md)

Her aşama bitince buraya: ne yapıldı, hangi dosyalar, hangi testler geçti, ölçülen / denenen, açık kalanlar, plandan sapmalar.

## Kararlar
- 2026-11-12: PLAN.md bölüm 2'deki bütün öneriler kabul edildi (K1 zafer = eleme ya da K10 son vuruş, K2 iki uçtan başlangıç + 60 sn hazırlık,
  K5 oto-nişan oyuncuyu da hedefler ama silah x0,4, K8 K5 bossu takım gücü...).
- 2026-11-12: kullanıcının TAKIM ÜSSÜ fikri (2.2) + kararları: yalnız üste doğuş (cesette diriltme yok), yaratıklar üsse giremez,
  iyileşme girer girmez şartsız ama yavaş (öneri sn'de %2 can + %2 kalkan), rakip oyuncu giremez, üste PvP yok. 2.1 buna göre yeniden yazıldı.
- 2026-11-12: "yaratıklar bu bölgeye yaklaşmasın hızlıca geri dönsün" -> 2.2 geri dönüş halkası (üs + ~80 birim; hedef bırakılır, x1,5 hızla ~1,2 sn üsten uzağa,
  bosslar dahil; korku kaçışının görselsiz sürümü, C++), sert sınır yalnız son güvence, yol ızgarasında üs + halka kapalı.
- AÇIK: üsteyken dışarıdaki yaratığa / oyuncuya hasar verilebilsin mi (öneri: hayır, sınırdan bedava kasılma olmasın).

## Aşama 0 - Ölçüm: ERTELENDİ
Kullanıcı (2026-11-12): "pvpve sistemini oyuna eklemeye başlayabilirsin ayrı bir mod olarak. daha sonra cila çekeriz dengeleriz." -> ölçüm, denge aşamasıyla (6) birlikte.

## Aşama 1a - Mod + takımlar + takım üsleri (kamp): UYGULANDI (2026-11-12, madde 607)
Kullanıcı: "@kamp.zip bu kamp assetleriyle her haritanın birbirinden uzak rasgele noktalarında kamp oluşmasını sağla ve bu kampları üs olarak ata."

### Yapılanlar
1. KAMP SANATI: kamp.zip (Craftpix "Camp") -> `tools/kamp/kaynak/` (örnek Camp.tmx + kullanılan PNG'ler + lisans). `python -I tools/kamp/gen_kamp.py [--onizleme x.png]`
   örnek haritayı parçalara böler -> `assets/map/kamp/` 29 parça (6 çadır grubu, kamp ateşi + kazanlı kertenkele, 8 animasyonlu kamp karakteri 12 kare 150 ms,
   kütükler PİKSEL öbeği (karo öbeği tek parça çıkıyordu), kaya, silah rafı) + `scripts/pvp/kamp_yerlesim.gd` (ÜRETİLİR; .json exe'ye girmiyor).
   Zemin / çimen / tepe / ağaç / çiçek alınmaz: kamp kurulduğu haritanın zeminine oturur. 1 sanat px = 1 dünya birimi (harita karolarıyla aynı).
2. MOD: `scripts/pvp/game_mode.gd` (coop / pvp; PvP yalnız çok oyunculuda, `MOD=pvp|coop` geliştirme ezmesi), `feature_override` -> PvP'de `ev_acilisi` kapalı;
   `map_profiles.gd feature()` önce moda bakar, `install()` ana haritada da kapalı bayrağın düğümünü (HouseInterior) kaldırır (co-op'ta hiçbir şey silinmez).
3. TAKIMLAR: `scripts/pvp/teams.gd` (`balanced_assign`: sırayla 0/1/0/1, kimse sonradan takım değiştirmez), `scripts/pvp/pvp_net.gd`
   (NetworkManager çocuğu "PvpNet": `_rpc_state` her lobby_updated'da, `_rpc_bases` + kamp yarıçapı, `_rpc_request_bases`), `LOBBY_PROTOCOL` lobi-34.
4. ODA KUR: masaüstü formda "Mod" satırı Ortak / 2v2 Takım (`room_browser.gd _set_game_mode`); telefon hep Ortak.
5. ÜSLER: `scripts/pvp/team_bases.gd` (yalnız PvP'de Main'e, main.gd): host seçer -> herkes kurar.
   - Yerleşim `base_placement.gd`: 32 birim ızgara, haritanın başlangıcından ULAŞILABİLİR, su/bina/orman olmayan, boş yarıçap (kamp 176 ... 64), kaçınma
     (bekçi kampı 520, maden 260); ÖNCE UZAKLIK: en uzak çift ulaşılabilir alan köşegeninin %42'sine ulaşmazsa boşluk eşiği düşer (dar zindanda küçük kamp,
     `team_camp.gd fits`). Rastgele: en uzak çiftin %85'i kadar uzak çiftlerden biri.
   - Kamp `team_camp.gd`: parçalar Main'in çocukları, "ysort_props" + totem DERİNLİK yöntemi (arkasında karakter varsa z 2), çadırlar "move_blockers".
   - Sınır perdesi: Shaman E "Işık Perdesi" shader'ı (madde 586), kendi üssün mavi / rakibinki kızıl, `GroundSlot.add_on_floor`.
   - Rakip oyuncu giremez: üs çemberi "move_blockers" grubuna YALNIZ rakip takımın makinesinde girer (player.gd'ye dokunulmadı).
   - Başlangıç: yerel oyuncu kendi kampının güneyi (±36, 140); (±34, 74) yeşil çadırın çarpışma çemberine düşüyordu.
   - İyileşme: kendi üssünde girer girmez sn'de azami can + mana kalkanının %2'si (`player.gd heal(..., quiet)` yeni parametre: her karede sayı çıkmasın).
   - Yaratık: host 0,2 sn'de bir üs + 80 halkasındaki adaylara `enemy.gd apply_base_repel` (korku kaçışının görselsiz / kontrol sayılmayan / bosslara da işleyen
     sürümü, 1,2 sn, x1,5 hız); üsteki oyuncu hedef değil (`base_zones.gd shelters`: enemy.gd temas + hedef arama, enemy_world_bridge.gd `_build_targets`);
     üsteki oyuncu doğuş çapası değil (`enemy_spawner.gd _underground`), doğuş noktası üs + 300 içine düşmez (`_random_spawn_position`).
   - `base_zones.gd` BAĞIMLILIKSIZ sorgu dosyası (yaratık kodu team_bases.gd'yi preload etmesin: döngü).

### Doğrulama
- `tests/test_pvp_mode.gd` 9 test geçti; ayrıca test_all_scripts_compile, test_map_profiles, test_lobby_rooms, test_necro_skull, test_enemy_dormancy,
  test_guard_camps, test_hide_brush geçti. test_mobile_screens.gd'de 2 hata (telefon karakter seçimi yüz kartı, telefon ayarlar satırları): dokunulmayan
  ekranlar (paralel oturumun alanı), bu işe bağlı değil.
- Duman `tools/pvp/pvp_duman.gd` (başsız, MOD=pvp, HARITA): 5 seçilebilir harita TAMAM - üs ayrımı ana 3500-3739, bataklık 2877, çöl 3152,
  Batık Nekropol 2278 (kamp yarıçapı 150, 54 parça), Lağım Ağı 2378-2462 (128, 46 parça); yerleşim 110-320 ms (host, yükleme altında);
  3 sn'de %6,7-6,9 can; 20 sn sonra üs içinde yaratık 0. İlk sürümde zindanlarda üsler 195 / 517 birim yakındı -> önce-uzaklık kuralı.
- MP denetimi `run_audit.ps1 -Mode pvp` (`tools/mp_audit/pvp_audit.gd`): istemci modu ve takımını (1) host'tan aldı, aynı üsler, ev yok, kendi kampında;
  rakip üsse 2,5 sn yürüdü, sınırda durdu (merkeze 291, sınır 280).
- Gerçek çizici `tools/pvp/kamp_goruntu.ps1 [-Harita x]` -> `tools/pvp/out/kamp_<harita>_{kendi,rakip}.png`.

### Açık kalanlar / plandan sapmalar
- SAPMA: yaratık için C++ sert sınırı + yol ızgarasında kapalı üs YAPILMADI; geri dönüş GDScript host tikiyle. Kovalanan oyuncu üsse girince yaratığın
  halkada yaklaş-dön salınımı / yolun üssün içinden geçmesi oyun testinde izlenecek.
- Lobide takım seçimi YAPILDI (madde 608: seçim ekranında iki takım başlığı + BU TAKIMA GEÇ, host doğrular, oyun başlayınca kilitli, boş takımla başlatılmaz); host başka oyuncuyu taşıyamaz, 2+2 şartı yok. Oda listesinde mod yazmıyor; telefon formunda mod satırı yok.
- Atılma / ışınlanma / uçuş yetenekleri (Assasin R, Talon Q, Cadı süpürgesi "Yüksek Uçuş" evrimi...) rakip üs sınırında kesilmiyor.
- Gece kamp ateşi ışığı, minimap üs işareti, takım bildirimi yok.
- Host devrinde üsler yeniden (başka yerde) seçilir.
- Sıradaki: Aşama 1b (takım XP, takım görüşü, müttefik süzgeci 60 yer), sonra 2 (PvP hasarı, üste PvP yasağı), 4 (ölünce üste doğuş).

### Aşama 1a düzeltmesi - KÜÇÜK, İNSANSIZ KAMP (2026-11-12, madde 607 ek)
Kullanıcı: "ben küçük bir kamp istemiştim ayrıca birsürü insan var burda. olmamalıydı".
- `tools/kamp/gen_kamp.py` artık yalnız `KUCUK_KAMP`: kazan ateşi + 4 kütük + 2 çadır (beyaz-mavi + mor, örnekteki yerlerinde) + silah rafı + 2 küçük taş
  = 10 parça (eskisi 29), kapsam 292 x 121 birim. Karakter sayfalarından gelen HİÇBİR karo çizilmez (çadırlarda uyuyanlar dahil). Örnekteki ateş
  kazanı karıştıran bir kertenkeleydi: aynı sayfanın kertenkelesiz kazan varyantı (tek sütunlar, `FIRE_FRAMES`) ateş çukuruna piksel hizalanır
  (`fire_alignment`, kayma (-5, 7)). Eski 19 parçanın PNG'si + .import'u silindi.
- Başlangıç yeri kütük karesinin güneyi (±36, 66); yerleşimin tam kamp eşiği 152, tam küçük kampın sığdığı eşik 128 (`FULL_CAMP_CLEAR`):
  uzaklık şartını tutturamayan eşiklerden önce tam kamp sığan en uzak çift seçilir; 128'de uzaklık şartı %30 gevşer.
- Yerleşim yeni kuralları: bekçi kampları SABİT `guard_camps.gd CAMPS`'tan (GuardCamps kamplarını ilk tikte kuruyordu, liste boştu -> üs güneydoğudaki
  düşman üssü kamplarının ortasına düştü), kaçınma 520 + kampın yarıçapı; harita süslerinin ÇİZİLEN dikdörtgeni (ağaç tacı dahil) kampa uygun değil
  (`team_bases.gd _decor_mask`, `DECOR_LAYER_PREFIXES`; küçük Çalılar sayılmaz: her yerde oldukları için kamp kırpılıyordu).
- Üste takılı kalan yaratık (geri dönüşe rağmen 1,6 sn üs içinde, dar zindanda duvara takılan) halkanın dışındaki ilk boş noktaya ışınlanır
  (`enemy.gd teleport_to`, host); doğurucunun 10 denemesi de üsse yakın düşerse nokta üs payının dışına itilir.
- Duman (5 harita, TAMAM): ana / bataklık / çöl / Batık Nekropol tam küçük kamp (10 parça), Lağım Ağı dar: kamp yarıçapı 80 (çadırsız: ateş + kütük
  + raf + taş); üste yaratık 0; en yakın bekçi kampı 682-813. Gerçek çizici `tools/pvp/out/kamp_ana_kendi.png`.
- NOT: bu sırada başka bir oturum `teams.gd` / `pvp_net.gd` / `test_pvp_mode.gd`'ye lobide takım seçimi ekliyordu (try_move, start_block_reason,
  request_team, 2 yeni test); o dosyalara bu düzeltmede dokunulmadı.

## Aşama 2 (çekirdek) - Rakibe hasar + takım ayrımı + üs alanı: UYGULANDI (2026-11-12, madde 615)
Kullanıcı: "2v2 modu düzgün çalışmıyor, düşmanlarla dost gibiyiz, herkes aynı takımda; üs koruma alanları çok büyük, yolları kapatıyor, küçülmeli."
Ayrıntı + dosyalar + tuzaklar `docs/notlar/madde_161-170.md` madde 615. Özet:
- ÜS ALANI 280 -> 160 (dar yerde kamp + 16, en az 72); `BaseZones.radius`.
- Rakip RemotePlayer = vekil düğüm (`pvp_target.gd`, mission_target sözleşmesi) -> bütün silah / yetenek yolları bilmeden vurur; hasar kurbanda doğrulanır (`PvpNet.send_hit` / `victim_check` / `PvpRules.incoming_cap` / `player.take_pvp_damage`).
- Kurallar `pvp_rules.gd`: silah x0,4, yetenek x1, alan x0,7, süreli x0,5, tek vuruş <= %25, kontrol x0,5, hazırlık 60 sn, üste PvP yok (başlangıç tahminleri).
- Takım ayrımı: takım görüşü (sis), rakip kukla görüş dışında gizli + minimapte yok, grup paneli yalnız takım, ad rengi mavi / kızıl.
- Doğrulama: `test_pvp_damage` 8 test + ilgili testler + `run_audit.ps1 -Mode pvp` (istemci host'a 80 hasar yazdı, bariyer 155).
### Açık kalanlar (sıradaki)
- Aşama 3: destek yetenekleri (Melek, Şovalye, Oakley, Cadı, Shaman E, Yin Yang, Kalkan Bağı...) hâlâ rakibi de etkiliyor - `remote_players` taramalarına `Teams.allies` süzgeci; yavaşlatma / kök / korku / itme oyuncuda yok; rakibe karşı görünmezlik / çalılık.
- Aşama 4: öldürme ödülü + bildirim, ölünce yalnız üste doğuş, eleme / K10 zaferi, kalp kuralları, takım XP / altın payı.
- Denge: hasar çarpanları ölçülmedi (Aşama 0 ertelendi), gerçek oyunda oynanıp ayarlanacak. Hazırlık süresi 60 sn (`PvpRules.PREP_SECONDS`): test için kısaltılabilir.

## Aşama 3 + 4 - Destek / kontrol / ölüm / skor / zafer: UYGULANDI (2026-11-12, madde 617)
Kullanıcı: "tüm aşamaları bitirip normal bir pvp haline getir". Ayrıntı + dosyalar + tuzaklar `docs/notlar/madde_161-170.md` madde 617. Özet:
- DESTEK: rakip kukla `player_ally` + `remote_allies` gruplarından çıkar (`pvp_rivals`); iyileştirme / kalkan / bağ / iksir / Şovalye / Oakley / Yin Yang / ruhani Can / Cadı süpürgesi rakibe işlemez. YENİ destek kodu `remote_allies` / `player_ally` taramalı.
- KONTROL: yavaşlatma / kök / korku / itiş rakibe gider; kurban tarafında yarı süre + AZALAN ETKİ (3 kontrolden sonra 3 sn bağışıklık), oyuncuda en çok %60 yavaş. Çalıda saklı rakip görünmez / vurulamaz.
- ÖLÜM: diriltme yok; ölüm süresi (10 + 2 x kademe sn) sonunda YALNIZ kendi üssünde tam canla doğuş, doğuş + üsten çıkış koruması (3 sn), kalbi yoksa kalıcı ölüm, kalp yenilenince / dükkandan diriltme üste kaldırır.
- SKOR: öldürme sayacı + altın (60 + 20 x kademe + seri eki), bildirim, üst orta skor şeridi (TAB: oyuncu tablosu), minimapte iki üs.
- ZAFER: eleme (takımın hepsi kalıcı ölü / ayrıldı), K10 bossunun son vuruşu, takım teslimi (oy yalnız kendi takımında); "KAZANDINIZ / KAYBETTİNİZ" ekranı. K13: sonsuz mod yok.
- TAKIM XP: iki takımın ayrı XP / seviyesi (host tutar, her takıma yalnız kendi durumunu yollar); zorluk ölçeği ikisinin yükseğine bakar. Ödüller (sandık sırası, elit sandık, boss altını, takım payı) kendi takımına.
- K5 bossunu öldüren takıma 3 dk +%20 saldırı hızı; savaşta kart ekranı ertelenir (K10).
- Doğrulama: `tests/test_pvp_stage4.gd` 13 test + ilgili eski testler + `run_audit.ps1 -Mode pvp -TimeoutSec 420` GEÇTİ (iki süreçli: ölüm -> skor + altın + bildirim -> tam canla üste doğuş -> doğuş koruması -> kalıcı ölüm -> eleme -> maç sonu).
### Hâlâ açık
- Takım / herkes sohbeti, balans kaydı `mode` alanları, görev ödüllerinin tamamlayan takıma ayrılması, Şovalye kubbesi / Talon ışınlanmasının rakip üs sınırında kesilmesi, host devrinde skor + takım XP.
- DENGE: hasar çarpanları (silah x0,4, yetenek x1, alan x0,7, süreli x0,5, tek vuruş %25), ölüm süresi, öldürme altını, hazırlık 60 sn ve K5 gücü hepsi ilk tahmin; gerçek 4 kişilik oyunda oynanıp ayarlanacak.
