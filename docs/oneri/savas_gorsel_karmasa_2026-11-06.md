# Çok oyunculu savaşta görsel yorgunluk ve karmaşa - analiz ve öneri (2026-11-06)

Kullanıcı: "oyun savaş esnasında multiplayerda aşırı göz yorucu ve karmaşık". Bu belge ÖLÇÜLENİ, kareden GÖRÜLENİ ve YORUMU ayrı tutar.
Araç: `tools/buyuk_test/mp_clutter.ps1` (+ `mp_clutter.gd`, `mp_clutter_rapor.py`). Host + istemci BAŞSIZ, ekranı kaydeden istemci gerçek renderlı
(gizli masaüstü). İki parti, her biri 3 oyuncu + aynı izleyicinin TEK oyunculu tabanı, 70 yaratık, 70 sn, yetenekler sık basılı.
- Efekt yoğun parti: Büyücü Kız (host), Shaman, Melek (izleyici). Etiketler `ags_fx3` / `ags_fx_solo`.
- Dengeli parti: Talon, Şovalye, Elara (izleyici). Etiketler `ags_den3` / `ags_den_solo`.
Kareler: `tools/buyuk_test/out/<etiket>/viewer/` (m*_00_base.jpg gerçek kare, `kategori_haritasi_m*.jpg` hangi kategori nerede).

## 1. Ölçülen (güvenilir)

| ölçü (ekrandaki, ort. 60 sn) | efekt yoğun MP / tek | dengeli MP / tek |
|---|---|---|
| diğer oyuncuların silah ikonları | 5,9 / 0 | 6,5 / 0 |
| oyuncu yetenek + silah efekt birimi | 23,9 / 24,3 | 14,5 / 4,2 (x3,5) |
| can/kalkan çubuğu + durum ikonu | 3,1 / 1,0 | 3,5 / 1,0 |
| yerdeki eşya (XP/altın) | 0,6 / 0,9 | 3,0 / 0,2 |
| efekt/ikon toplamı (yaratık ve oyuncu hariç) | 51 / 44 | 49 / 33 (+%48) |
| çizim çağrısı | 705 / 524 (+%35) | 671 / 541 (+%24) |
| doygun renkli piksel payı | %4,1 / %2,1 (x1,95) | %2,4 / %2,2 |

- Yaratık sayısı iki tarafta da 55-70 (aynı). Yani artış yaratıktan değil, OYUNCULARDAN geliyor: başkalarının silahları, efektleri, çubukları.
- Kare hızı izleyicide 57 / 96 ve 72 / 116 çıktı AMA 3 süreç aynı makinede koştuğu için bunun bir kısmı işlemci paylaşımıdır; çizim çağrısı artışı gerçektir.

## 2. Ölçülemeyen / sonuçsuz (dürüst not)

- Yanıp sönme (strobo) ölçümü: örnekleme aralığı MP'de kare hızı düştüğü için uzadı; saniyeye normalize edince efekt yoğun partide MP/tek 0,9-1,05x
  (fark yok), dengelide 1,3-2,4x (taban çok sakin olduğundan). SONUÇ: ışık patlaması/strobo ana sorun görünmüyor; ham değerleri kullanma.
- Ablation "ekran alanı %": MP'de ağ güncellemeleri tree duraklıyken de sahneyi oynattığı için kategori alanları şişik (3 silah ikonu %2,4 çıkamaz).
  Yalnız renkli kategori haritası (nitel) ve birim sayıları güvenilir.
- 4 oyuncu ölçülmedi (RAM: 4 GB boş). 3 oyuncudan doğrusal tahmin: başkalarının payı oyuncu sayısıyla artar.
- Gerçek göz yorgunluğu (algı) ölçülemez; ölçülen "ne kadar şey var". Kullanıcının hangi anların yorucu olduğunu söylemesi değerli.
- Ölçülen savaşlarda tesadüfen BOSS vardı (Yeraltı Canavarı / Minotaur: doğal boss saati) - boss'suz savaşta tablo biraz daha sakindir.

## 3. Karelerden görülen (yorum)

1. **Kimin kim olduğu zor.** Kendi karakterim yaratık yığınının içinde küçük; müttefik isimleri düz beyaz yazı (hasar sayısıyla aynı görünüm), üç oyuncunun
   can çubuğu aynı yeşil, takım rengi yok. Her müttefikin canı iki yerde (kafa üstü çubuğu + sağ panel) tekrar ediyor.
2. **Müttefik efektleri kendi efektlerim kadar parlak ve büyük.** Host'un Ateş Asası alevi karedeki en doygun şey (blok pikselleri karakterinkinin ~3-4 katı);
   Shaman'ın ~400 px'lik noktalı halkaları + turuncu kök çizgileri + golem; Şovalye kubbesi (ince dither ağı); hepsi tam opak.
3. **Ateş aynı turuncu hem dostta hem düşmanda:** oyuncu alevi, yaratık yanma sprite'ı (~30 küçük alev bir arada) ve boss ateşi ayırt edilmiyor.
4. **Boss mekanik nesneleri ekranı noktalıyor:** Yeraltı Canavarı uzuv sütunları (`worm_limb`, ekranda 8-9 adet) yeşil zeminde yüksek kontrastlı kahverengi + beyaz diş;
   dikkati tehlikeli şeylerden çekebilir. Minotaur'un beyaz yay çizgileri de çok büyük.
5. HUD düzenli ve çakışmıyor (~%13 ekran). Boss barı geniş ama okunur. (Test sayılarında "1000000000" can yazısı ölümsüzlük hilesinden, gerçek değil.)

## 4. Kodda görülen (neden)

- Her oyuncunun TÜM efektleri herkese tam boy yayınlanıyor (`NetworkManager.broadcast_player_vfx` -> alıcıda kopya); mesafe/sahiplik/yoğunluk ayrımı yok.
- Mevcut görsel ayarlar yalnız ortam için: Güneş/Bulut, Zemin Ayrıntısı, Rüzgar, Kalite/Render ölçeği, Hasar sayıları. **Savaş efektlerini azaltan ayar YOK.**
- İyi olan (korunmalı): hasar sayıları yalnız vuran oyuncuda; Hasar Sayıları Hepsi/Yalnız Kritik/Kapalı ayarı.

## 5. Öneriler (etki sırasıyla; hepsi cila dönemine uygun: ekleme değil azaltma/tutarlılık)

1. **Müttefik efekt yoğunluğu (alıcı tarafta, ağ değişmez) - YALNIZ "KİŞİSEL" sınıfa uygulanır (bkz. 5b; kullanıcı düzeltmesi 2026-11-06).** Başkalarının KİŞİSEL
   yetenek/silah efektleri varsayılan %50-60 saydam, yer halkaları/aura çizgileri çok soluk, müttefik silah ucu partikülleri kapalı; KENDİ efektlerim tam; TAKIM ve
   ÇAĞRILAN sınıfı hiçbir ayarda saydamlaşmaz. Ayar: Tam / Azaltılmış (varsayılan) / Minimal. Kanıt: efekt birimi x3,5, başkalarının silahı +6,5, doygun renk x2.
   Yeri: uzak oyuncu efektinin üretildiği dallar (`network_manager.gd broadcast_player_vfx` `skill_scene` dalı 3511 + `skill_ring`/`skill_burst`/`hitscan_impact` + `remote_player.gd`).
   Çizim çağrısını da düşürür (+%24-35).
2. **Otomatik yoğunluk:** ekrandaki efekt + yaratık eşiği aşılınca (öneri: >35 efekt birimi) 1'deki "Azaltılmış" kendiliğinden devreye girer, yoğunluk düşünce çözülür.
   Yine yalnız KİŞİSEL sınıfı etkiler; TAKIM/ÇAĞRILAN yoğunlukta bile tam kalır (en fazla "Minimal"de TAKIM'ın yalnız ince süsü sadeleşir, ana gösterge değil).
3. **Müttefik kimliği:** kendi karaktere ince açık halka/kontür; her oyuncuya sabit renkli ayak halkası (4 renk); isim yalnız yakında düşman yokken; kafa üstü
   can çubuğu yalnız hasar alınca/kalkan varken (sağ panelde zaten var). Beyaz isim yazısı hasar sayısından görsel olarak ayrılsın.
4. **Ateş:** Ateş Asası alev pikselleri karakter ızgarasına (stil rehberi 1 sanat px = 3 ekran px); ekranda aynı anda en çok ~8 yaratık yanma alevi, fazlası sade ton.
   Oyuncu ateşi ile düşman/boss ateşi renk olarak ayrışsın (örn. düşman tehlikesi kırmızı-mor).
5. **Boss mekanik nesneleri (karar senin):** Yeraltı Canavarı uzuvları aktif değilken soluk/daha az doygun, saldırıya geçince belirgin; ekranda aynı anda 4-5 ile sınırlı gösterim.
6. **Test:** 1-3'ü aynı MP yakalamada A/B (mevcut / azaltılmış / azaltılmış+kimlik) yapıp çizim çağrısı + birim sayısı + aynı kareler GIF ile karşılaştırmak (altyapı hazır).

## 5b. Sınıflandırma kuralı (kullanıcı geri bildirimi 2026-11-06: "takım odaklı yetenekler diğer oyunculara belirgin olmalı - Melek, Şovalye; çağıranların spawnladıkları saydam olmamalı - Shaman, Necromancer")

Karar ölçütü: **bu efekt bir arkadaşa ya da düşmana "bilgi" mi veriyor (kim korunuyor, nerede tehlike/destek var, bu bir çağrılan)?** Evetse tam görünür; yalnız
karakterin kendi gösterişiyse (kendi saldırısının süsü, kendi formu) azalır.

| Sınıf | Davranış | Koddaki kanal / örnekler |
|---|---|---|
| **TAKIM** (arkadaşa destek/koruma) | Hep tam opak, hiçbir ayarda saydamlaşmaz | `broadcast_ally_aura_start/stop` (Melek can/kalkan bağı, `melek_halo_fx`); `melek_sparkle`; `fx_melek_holy`/`fx_melek_ascend` (Melek R: can+kalkan yenileme, korku); `sovalye_echo` (Yankı Darbesi), `paladin_barrier_flash`, `fx_sovalye_taunt`/`fx_sovalye_guard`/`fx_paladin_cast` (Koruma Bariyeri, kubbe + `paladin_dome.gd` kabuğu); `shield_hit_flash` (kalkan baloncuğu); `fx_oakley_ward_cast`, `oakley_tree`/`oakley_tree_root`/`oakley_revive`/`oakley_flower_*` (Hayat Ağacı, çiçek şifa halkası); `cadi_fx`/`cadi_throw` (iksir alanı, süpürge yolcusu); `fx_revive_heart`/`fx_revive_rewind` (diriltme); `yinyang_idle` (kalkan küresi); Elara/Talon E-R'de dosta işleyen halkalar |
| **ÇAĞRILAN** (oyuncunun yarattığı varlık/yapı) | Hep tam opak; efekt değil "nesne" sayılır, yoğunluk ayarına GİRMEZ | `broadcast_pet_spawn/despawn/state` (Necromancer iskelet/golem/hayalet, evcil hayvanlar, Oakley arı sürüsü `OakleyBeeGuard`); Shaman totemleri (`totem_base/attack/shield.gd`, `setup_from_player` ile kozmetik kopya) ve Kalkan Totemi alanı; Shaman/Necro R formları (golem gövdesi); Oakley ağacı/çiçek varlıkları; Hadime/Matthew/Büyücü'nün bıraktığı kalıcı alanlar (kara delik, hortum, Don Nova halkası zaten düşmana bilgi verir) |
| **FORM** (dönüşüm; kullanıcı düzeltmesi 2026-11-06 ikinci tur: "dönüşümler de sayılmamalı - golem formu, Matthew'in yıldırım topu gibi") | Hep tam opak VE otomatik yoğunluk sayacına GİRMEZ (golem/top ekranı kalabalık gösterip başkalarının efektini soldurmasın); form bitince eski kurala döner | Shaman Elemental Golem (`ShamanGolemMath`, `_shaman_golem_form`; golem darbe/sarsıntı/iniş = `hitscan_impact` + `fx_scale`); Matthew Elektrik Topu (`_matthew_ball`, `fx_matthew_ball`, kıvılcım halkası); Vampir yarasa formu (`_vampir_bat_form`); Talon R formu (`fx_talon_form`, `_talon_form_active`, kırmızı-siyah shader/silah partikülü); Cadı süpürgesi (`_cadi_broom`, `ride_` klibi); Melek R kanatlı havalanma (`fx_melek_ascend`, 2 sn); SINIRDA ama güvenli tarafta FORM sayıldı: Hadime Q süzülme (`_hadime_q`), Elara Sıvışma (`_elara_evasion`), Assasin görünmezlik/gölge, Ninja eşyası (`_item_ninja`) |
| **KİŞİSEL** (kendi gösterişi, bilgi değeri düşük) | Varsayılan %50-60 saydam, yer süsü solar; Minimal'de çıplak çekirdek | Silah ucu partikülleri (`staff_tip_fx`), namlu parıltısı/kovan (`muzzle_flash`, `shell_casing_fx`), saldırı ardıl/vuruş izi, `fx_matthew_fox_strike`/`form_burst`/`spark*`, Talon zinciri/atılış/form izi, Assasin gölge/atılış izi, `fx_buyucu_*` yetenek döküntüsü (kast kitabı/set zerreleri; meteor/hortum ÇEKİRDEĞİ düşmana bilgi verdiği için kalır), kendi hız çizgisi, kendi kan/yanma süsü |

Kurallar:
- Sınıf, sahne dosyasına göre tek bir tabloda tutulur (`skill_scene` dalının aldığı `scene_path` anahtarı; diğer kanallar kendi tür adıyla). Tabloda olmayan yeni efekt
  ÖNCE tam görünür sayılır (güvenli varsayılan: bir şeyi yanlışlıkla saydam yapmak, fazla göstermekten daha kötü).
- FORM güvencesi (iki katman): (1) form efektleri sahne tablosunda FORM; (2) tablo yanlış/eksik olsa bile KASTERİ o anda formda olan bir kuklanın (`remote_player.gd`
  zaten `_shaman_golem_form`, `_matthew_ball`, `_vampir_bat_form`, `_talon_form_active`, `_cadi_broom` bayraklarını taşıyor) efektleri azaltılmaz. Bedeli: Talon formundayken
  silah partikülü de tam kalır - formlar 15-20 sn sürdüğü için kabul edilebilir. Dönüşüm gövdesi zaten efekt değil karakterin kendi klibi, saydamlaşmaz.
- Otomatik yoğunluk sayacı (öneri 2): yalnız KİŞİSEL birimleri sayar; TAKIM/ÇAĞRILAN/FORM birimleri sayıya girmez (yoksa 20 sn'lik bir golem herkesin efektini soldurur).
- Saydamlaşma sahip kontrolüyle: yalnız `RemotePlayer`'a ait KİŞİSEL efekt; yerel oyuncunun kendi efekti ve her TAKIM/ÇAĞRILAN hep tam.
- Kimlik katmanı (öneri 3) bununla birlikte çalışır: kalabalıkta okunmayan şey TAKIM'ı soldurmak değil, KİŞİSEL gürültüyü azaltmak; destek efektleri arka plandan
  ayrışsın diye müttefiklerin TAKIM efektine sahip rengi hafifçe verilebilir (ayak halkasıyla aynı 4 renk) - AYRI karar, bu turda uygulanmadı.
- Açık nokta (kullanıcıya sorulacak): "Şovalye'nin bazı yetenekleri" hangileri? Koruma Bariyeri (E), Koruma Baloncuğu (R) ve Yankı Darbesi TAKIM sayıldı; Şovalye'nin
  kişisel yetenek efekti varsa (pasif Dirençli Duruş halesi) KİŞİSEL mi TAKIM mı olacağı onun cevabına bağlı.

## 6. Bu turda ölçüm sırasında bulunup düzeltilenler

- `melek_bond_ribbon.gd` (Melek bağı): kaster silinince her karede "previously freed" hatası (3 oyunculu partide eş başına 230-320). Düzeltildi, MP tekrarında 0.
- `enemy_abilities.caster_disabled` (diken/lazer sahibi ölünce hata, koşuda binlerce) düzeltildi. Assasin R ikonu bağlandı. Ev ipucu yazısı seviye ekranında gizleniyor.
- `enemy.gd` hasar sayısı RPC'si bağlı olmayan eşe gidiyordu ("unknown peer ID", host'ta dakikada 2-3): bağlı eş kontrolü eklendi.
- AÇIK: projenin kendi `run_audit.ps1 -Mode sync` denetiminde (Assasin host + Vampir istemci) host'ta 30 sn'de 25 kez "Lambda capture at index 0 was freed";
  benim 6 farklı karakterli MP koşularımda yok; kaynağı Assasin/Vampir yolunda, henüz izlenmedi.
