class_name Characters

## Oyunun karakter kayıt defteri: karakterler LPC generator'da tasarlanıp
## kare kare export ediliyor, atlas + SpriteFrames'e çevrilip buraya
## ekleniyor. Yetenekler player.gd'deki eski yetenek kimlikleriyle (1-9,
## artık 10+ de olabilir) eşleştirilir - "skill" alanı
## GameManager.selected_character'a yazılır ve yetenek kodu hiç değişmeden
## çalışır. Bir karakterin isteğe bağlı ikinci (temel) bir aktif yeteneği
## olabilir: "skill2" alanı (bkz. Öykü) - varsa ayrı bir tuşla (bkz.
## game_manager.gd "skill2" action) tetiklenir, kendi süre/bekleme
## süresine sahiptir (bkz. player.gd SKILL2_TIMING). "passive" alanı hem
## seçim ekranında metin olarak gösterilir hem de (varsa "passive_icon")
## HUD'da küçük bir ikonla gösterilir; oynanışa etkisi varsa
## player.gd _process_character_passive içinde "skill" id'sine göre
## işlenir.
##
## Yeni karakter eklemek için: atlas/frames/portre dosyalarını üret,
## DEFS'e yeni bir kayıt ekle - seçim ekranı kartı otomatik oluşturur.

const DEFS := {
	1: {
		"name": "Talon",
		## Kullanıcı isteği (YENİ KİT - eski Devleşme/Yer Sarsıntısı kitinin
		## TAMAMEN yerine geldi): "Talon yeni skilleri" - silah temalı 3 aktif
		## yetenek + yığılan bir pasif (bkz. player.gd _skill_talon_weapon_
		## salvo/_skill_talon_dash/_skill_talon_mirror_form). İkon dosyaları
		## HENÜZ YOK - geçici olarak eski Talon ikonları yeniden kullanılıyor,
		## gerçek sanat geldiğinde değiştirilmeli.
		## DÜZELTME (kullanıcı isteği: "R ile Q'nun yerini değiştir") - id
		## NUMARALARI (38=Q/ULTİ, 37=skill3/R) AYNI kaldı, sadece HANGİ
		## fonksiyonun hangi id'ye bağlı olduğu player.gd'de swap edildi (bkz.
		## _activate_skill/_activate_skill3 match blokları, SKILL_TIMING[38]/
		## SKILL3_TIMING[37]) - Ayna Formu artık R'de, Hamle Vuruşu Q'da.
		## SONRAKİ TUR DÜZELTME (kullanıcı bildirimi: "talonun q su ulti olarak
		## algılandığı için çok fazla kalkan harcıyor, ultisinin R tuşu olması
		## gerek") - Q/R TUŞLARI (yukarıdaki "skill"/"skill3" id'leri) bir daha
		## DEĞİŞMEDİ, SADECE hangisinin "gerçek ulti" (ağır kalkan bedeli +
		## metindeki "ULTİ:" etiketi) sayıldığı player.gd _activate_skill()/
		## _activate_skill3()'te swap edildi - Hamle Vuruşu (Q, 4sn bekleme,
		## çok sık kullanılıyor) artık HAFİF/TEMEL bedeli ödüyor, Ayna Formu
		## (R, 120sn bekleme, gerçekten ulti hissi veren yetenek) artık AĞIR/
		## ULTİ bedelini ödüyor - metin etiketleri de buna göre aşağıda swap
		## edildi.
		"skill": 38,
		"skill_name": "Hamle Vuruşu",
		"skill_desc": "YETENEK: İleri kısa bir hamle yapar, isabet ettiği düşmanlara saldırı gücünün %60'ı kadar hasar verir ve isabet başına eksik kalkanının %4'ünü yeniler. (4sn bekleme)",
		"skill_icon": "res://assets/skills/talon_devlesme_icon.png",
		"skill2": 36,
		"skill2_name": "Silah Salvosu",
		"skill2_desc": "TEMEL: 3sn boyunca tüm silahların dışa dönük olarak etrafında 2 tur atıp sürekli saldırır, bu esnada %200 saldırı hızı kazanırlar. (15sn bekleme)",
		"skill2_icon": "res://assets/skills/talon_yer_sarsintisi_icon.png",
		"skill3": 37,
		"skill3_name": "Ayna Formu",
		"skill3_desc": "ULTİ: 15sn boyunca her silahının bir aynalı kopyası belirir (silah sayısı 2 katına çıkar, hepsi eşit aralıklarla etrafını sarar) - her kopya bağımsız ateş eder. Kopya başına saldırı gücü %8 azalır. (120sn bekleme)",
		"skill3_icon": "res://assets/skills/talon_devlesme_icon.png",
		"passive": "Yetenek kullandıkça yığılan güç: her kullanımda 6sn süren bir yük kazanır (en fazla 5, +%6 saldırı gücü / +%4 hasar azaltma her yük) - yetenek kullanılmazsa yükler 2sn'de bir azalır.",
		"passive_icon": "res://assets/skills/talon_passive_icon.png",
		"frames": "res://assets/characters/talha_frames.tres",
		"portrait": "res://assets/characters/talha_portrait.png",
	},
	## DÜZELTME (kullanıcı isteği: "Oakley yeni yetenekleri", sonra "Oakley ve
	## Melek aynı karakter değil, sadece aynı yetenekleri kullanıyorlardı -
	## Melek'e sakın dokunma") - eski kit (Can Basma ULTİ + Kalkan Yenileme
	## TEMEL, ikisi de kendine+müttefiğe can/kalkan yenileyen destek
	## yetenekleriydi) SADECE Oakley'de TAMAMEN yeni bir kitle değiştirildi:
	## Çiçek (Q, yük tabanlı), Sarmaşıklar (E, sabitleme), Arı Sürüsü (R, YENİ
	## - Oakley'nin ilk kez sahip olduğu 3. yetenek). Melek (char 10) KENDİ
	## eski kitini (Can Basma/Kalkan Yenileme/pasif/Kutsal Korku) AYNEN
	## koruyor - iki karakter geçmişte skill/skill2 numaralarını (1/10)
	## PAYLAŞIYORDU (bkz. player.gd'deki dispatch tabloları) ama bu SADECE
	## sayısal id paylaşımıydı, ayrı karakterler olarak ayrı kitleri var;
	## player.gd tarafında Oakley'e özel dallar artık SADECE
	## "GameManager.selected_char_id == 2" kontrolüyle ayrılıyor, Melek'in
	## roster id'si (10) bu yeni yeteneklere hiç dahil değil.
	2: {
		"name": "Oakley",
		"skill": 1,
		"skill_name": "Çiçek",
		"skill_desc": "Yere bir çiçek bırakır (kendisi veya bir dost alabilir, 180sn yerde kalır). Alınırsa saldırı gücünün %50'si kadar can yeniler ve alanı 2sn boyunca azalarak kaybolan %25 hıza kavuşturur; alınmazsa 5sn'de bir büyüyüp verdiği canı kümülatif %40 arttırır (en fazla 2 büyüme). 2 yük, yük başına 18sn.",
		"skill_icon": "res://assets/skills/oyku_ulti_can_basma_icon.png",
		"skill2": 10,
		"skill2_name": "Sarmaşıklar",
		"skill2_desc": "TEMEL: Yakındaki yaratıklara doğru ilerleyen 3 sarmaşık yaratır (6sn). İsabet eden yaratığı 4sn yere sabitler (hareket edemez, saldırabilir) ve saldırı gücünün %60'ı kadar hasar verir. Bosslar sabitlenmez, bunun yerine %30 yavaşlar. (16sn bekleme)",
		"skill2_icon": "res://assets/skills/oyku_kalkan_yenileme_icon.png",
		"skill3": 33,
		"skill3_name": "Arı Sürüsü",
		"skill3_desc": "3. YETENEK: Bulunduğu konuma 10sn süren bir arı sürüsü salar. İçindeki yaratıklar saniyede 1 zehir yükü biriktirir (en fazla 10), her yük 4sn boyunca toplam saldırı gücünün %20'si kadar hasar verir. (20sn bekleme)",
		"skill3_icon": "res://assets/skills/oyku_kalkan_yenileme_icon.png",
		"passive": "Canı %20'nin altına düşünce anında %40 kalkan kazanır ve 6sn içinde maksimum canının %25'ini yeniler. (120sn bekleme, bekleme süresi azaltmadan etkilenmez)",
		"passive_icon": "res://assets/skills/oyku_passive_icon.png",
		"frames": "res://assets/characters/oyku_frames.tres",
		"portrait": "res://assets/characters/oyku_portrait.png",
	},
	3: {
		"name": "Matthew",
		"skill": 9,
		"skill_name": "Feda Kalkanı",
		"skill_desc": "ULTİ: Yaratığı feda edip 15sn süren koruyucu bir kalkan çemberi kurar. (120sn bekleme)",
		"skill_icon": "res://assets/skills/matthew_feda_kalkani_icon.png",
		"skill2": 21,
		"skill2_name": "Vahşi Hız",
		"skill2_desc": "TEMEL: Kendine ve tilkisine 10 saniye boyunca %40 saldırı hızı ve %15 hareket hızı kazandırır. (35sn bekleme)",
		"skill2_icon": "res://assets/skills/matthew_vahsi_hiz_icon.png",
		"passive": "Statlarının %50'siyle saldıran bir yaratığa sahipsin. Ölürse 30sn sonra yeniden doğar.",
		"passive_icon": "res://assets/skills/matthew_passive_icon.png",
		"frames": "res://assets/characters/matthew_frames.tres",
		"portrait": "res://assets/characters/matthew_portrait.png",
	},
	4: {
		"name": "Büyücü Kız",
		## Kullanıcı isteği (rework #2): "artık 3 skill sistemine geçtiğimiz
		## için büyücü kızın ultisi diğer 2 skilin varyasyonunu değiştirecek.
		## diğer 2 skill de varolan 4 varyasyonlu temel yeteneği ile 2 parçaya
		## ayrılacak" - eski TEK slot (E, 4 varyasyon arasında dönen) artık
		## İKİ SABİT SET'e bölündü: Set 0 = {E: Arcane Lanet, R: Hortum},
		## Set 1 = {E: Don Nova, R: Meteor Patlaması} (bkz. player.gd
		## BUYUCU_SET_E_VARIATIONS/BUYUCU_SET_R_VARIATIONS). ULTİ artık İKİ
		## slotu da AYNI ANDA diğer sete geçiriyor (bkz.
		## _skill_buyucu_switch_variation - buyucu_variation_set 0<->1).
		"skill": 3,
		"skill_name": "Büyü Değişimi",
		"skill_desc": "ULTİ: TEMEL (E) ve 3. yeteneğin (R) setini birlikte değiştirir (Set 1: Arcane Lanet + Hortum <-> Set 2: Don Nova + Meteor Patlaması). (1sn bekleme)",
		## DÜZELTME (kullanıcı bildirimi: "büyücü kızın skill ikonları
		## görünmüyor"): eskiden hem ULTİ hem pasif ikonu, ULTİ tamamen
		## kaldırılmış ESKİ "Hızlı Ateş" yeteneğinin ikonuna
		## (buyucu_hizli_ates_icon.png) işaret ediyordu - assets/skills
		## klasöründe bu kit için özel olarak üretilmiş gerçek ikonlar
		## (buyucu_ulti_buyu_degisimi_icon.png, buyucu_passive_kadim_patlama_
		## icon.png, buyucu_skill_*_icon.png) zaten vardı ama hiçbiri buraya
		## hiç bağlanmamıştı.
		"skill_icon": "res://assets/skills/buyucu_ulti_buyu_degisimi_icon.png",
		## "skill2"/"skill3" alanları SADECE HUD'un ikonlarını göstermesi
		## için (bkz. hud.gd _setup_ability_icons has_skill2/has_skill3
		## kontrolü) - gerçek varyasyon kimlikleri çalışma zamanında
		## player.gd'nin get_skill2_id()/get_skill3_id() override'ları
		## tarafından belirleniyor (bkz. BUYUCU_VARIATION_SKILL2_IDS/
		## BUYUCU_SET_E_VARIATIONS/BUYUCU_SET_R_VARIATIONS). Ad/açıklama de
		## HER KAREDE player.gd'nin get_buyucu_variation_name/desc()'iyle
		## ÜZERİNE YAZILIYOR (bkz. hud.gd _process, skill_icon.gd name_
		## override/desc_override) - buradaki metinler sadece ilk karede/geri
		## düşüş (fallback) değeri.
		"skill2": 22,
		"skill2_name": "Arcane Lanet (Set 1/2)",
		"skill2_desc": "TEMEL (E, 2 setli - ULTİ ile değiştirilir):\n1) Arcane Lanet: yaratıklar arasında 4 kez sekip her sekişte saldırı gücünün %80'i kadar hasar verir. (4sn bekleme)\n2) Don Nova: etraftaki tüm yaratıkları 6sn dondurur (donan yaratık hiçbir şey yapamaz) ve saldırı gücünün %100'ü kadar hasar verir. (30sn bekleme)",
		## bkz. hud.gd _process (GameManager.selected_char_id == 4 dalı) -
		## HER karede o anki set'e göre skill2_icon.custom_texture'ı burdan
		## (buyucu_variation_set index'iyle, 0 veya 1) seçiyor. Sıra: 0=Arcane
		## Lanet, 1=Don Nova.
		"skill2_icon": "res://assets/skills/buyucu_skill_arcane_lanet_icon.png",
		"skill2_variation_icons": [
			"res://assets/skills/buyucu_skill_arcane_lanet_icon.png",
			"res://assets/skills/buyucu_skill_don_nova_icon.png",
		],
		## Kullanıcı isteği (rework #2 devamı): eski Hortum/Meteor Patlaması
		## varyasyonları artık YENİ 3. yetenek (R) slotuna taşındı - bkz.
		## player.gd _buyucu_try_activate_variation_r/BUYUCU_SET_R_VARIATIONS.
		"skill3": 24,
		"skill3_name": "Hortum (Set 1/2)",
		"skill3_desc": "3. YETENEK (R, 2 setli - ULTİ ile değiştirilir):\n1) Hortum: 15sn boyunca dolaşan 3 hortum çıkarır, her biri değdiği yaratığa saniyede en fazla 1 kez saldırı gücünün %120'si kadar hasar verir. (45sn bekleme)\n2) Meteor Patlaması: 5sn hareketsiz odaklanıp etrafa saldırı gücünün %120'si kadar hasar veren meteorlar yağdırır. (120sn bekleme)",
		"skill3_variation_icons": [
			"res://assets/skills/buyucu_skill_hortum_icon.png",
			"res://assets/skills/buyucu_skill_meteor_icon.png",
		],
		"passive": "Kadim Patlama: öldürdüğün her yaratık patlayıp çevresindeki diğer yaratıklara saldırı gücünün %20'si kadar alan hasarı verir.",
		"passive_icon": "res://assets/skills/buyucu_passive_kadim_patlama_icon.png",
		"frames": "res://assets/characters/buyucu_frames.tres",
		"portrait": "res://assets/characters/buyucu_portrait.png",
		"always_walk": true,
		"projectile_scene": "res://scenes/buyucu_projectile.tscn",
		"projectile_rotation_offset": -2.3999243,
	},
	5: {
		"name": "Assasin Çocuk",
		## Kullanıcı isteği: "assasin çocuğun yeni bir yeteneği olucak,
		## görünmezlik yeteneği artık temel yeteneğiyken ultisi ise etraftaki
		## 25 yaratığa hızlı bir şekilde üzerlerine gidip onlara çarpıp sıra
		## sıra maksimum 25 yaratığa aynı hareketi yapmalı" - eski ULTİ
		## (Görünmezlik, id 5) TEMEL/E slotuna taşındı (bkz. skill2 aşağıda,
		## SKILL2_TIMING[5], _activate_skill2()), yeni bir ULTİ (Gölge
		## Hücumu, id 16) onun yerini aldı (bkz. player.gd
		## _skill_assasin_dash/SKILL_TIMING[16]).
		"skill": 16,
		"skill_name": "Gölge Hücumu",
		"skill_desc": "ULTİ: Yakındaki yaratıklara sırayla hızla çarpar (en fazla 25 yaratık), her çarpışta tüm silahlarının toplam hasarı kadar 1 kez hasar verir, bitince kullandığı konuma geri döner. (90sn bekleme)",
		"skill_icon": "res://assets/skills/assasin_golge_hucumu_icon.png",
		## DÜZELTME (kullanıcı isteği: yeni temel yetenek) - Görünmezlik'in
		## yerine 8 yönlü, 3 yüklü bir hamle geldi (bkz. player.gd
		## ASSASIN_DASH2_*/_try_assasin_dash2/SKILL2_TIMING[5] üstündeki not).
		"skill2": 5,
		"skill2_name": "Şahin Hamlesi",
		"skill2_desc": "TEMEL: Yürüdüğü yöne (8 yön) hızla hamle yapıp içinden geçtiği düşmanlara saldırı gücünün %150'si kadar hasar verir. 3 yükü vardır, her yük ayrı ayrı 12sn'de yenilenir.",
		"skill2_icon": "res://assets/skills/assasin_gorunmezlik_icon.png",
		## Kullanıcı isteği: Assasin Çocuk'un yeni 3. yeteneği (skill3, R
		## tuşu) - 6sn görünmez olur, yaratıkların içinden geçebilir,
		## saldırı gücü %30 artar (bkz. player.gd
		## _skill_assasin_invisibility_r, skill id 30).
		"skill3": 30,
		"skill3_name": "Gölge Adımı",
		"skill3_desc": "3. YETENEK: 6 saniye boyunca görünmez olur ve yaratıkların içinden geçebilir. Görünmezken saldırı gücü %30 artar. (60sn bekleme)",
		"passive": "Bıçak Uzmanlığı: yetenek kullanımından sonraki 3 saniye boyunca garantili kritik vurur.",
		"passive_icon": "res://assets/skills/assasin_passive_icon.png",
		"frames": "res://assets/characters/assasin_frames.tres",
		"portrait": "res://assets/characters/assasin_portrait.png",
	},
	6: {
		"name": "Kurt Adam",
		"skill": 14,
		"skill_name": "Kudurmuş Saldırı",
		"skill_desc": "ULTİ: 20sn kudurup en yakındakilere otomatik vurur. %50 az hasar alır, %30 hızlı vurur, %30 hızlı koşar, %10 can çalma şansı kazanır. (90sn bekleme)",
		"skill_icon": "res://assets/skills/kurtadam_kudurmus_saldiri_icon.png",
		"skill2": 13,
		"skill2_name": "Vahşi Kesik",
		"skill2_desc": "TEMEL: Etrafına %120 pençe hasarı vurur ve %4 can çalar. (15sn bekleme)",
		"skill2_icon": "res://assets/skills/kurtadam_vahsi_kesik_icon.png",
		## DÜZELTME (kullanıcı isteği: "can çalma sistemi komple değişiyor, artık
		## verilen hasarın %'liğini yenilemiyor - %X can çalma = %X ihtimalle
		## isabet halinde 1 can yeniler") - metin eski ("hasarın %X'i kadar can
		## yeniler") mekaniği anlatıyordu, yeni mekaniğe göre güncellendi (bkz.
		## player.gd on_damage_dealt).
		"passive": "Can Çalma: isabet başına %1 ihtimalle 1 can yeniler.",
		"passive_icon": "res://assets/skills/kurtadam_passive_icon.png",
		"lifesteal": 0.01,
		"frames": "res://assets/characters/kurtadam_frames.tres",
		"portrait": "res://assets/characters/kurtadam_portrait.png",
		"always_walk": true,
	},
	7: {
		"name": "Şovalye Adam",
		"skill": 11,
		"skill_name": "Koruma Baloncuğu",
		"skill_desc": "ULTİ: Kalkanı bitene kadar içine düşman/mermi girmeyen koruma alanı açar (%30 menzil, kalkan hasarı %90 azalır). Hareket edemez. (120sn bekleme)",
		"skill_icon": "res://assets/skills/sovalye_ulti_koruma_baloncugu_icon.png",
		"skill2": 10,
		"skill2_name": "Kalkan Yenileme",
		"skill2_desc": "TEMEL: 6 saniye boyunca saniyede EKSİK kalkanının %5'ini yeniler. (50sn bekleme)",
		"skill2_icon": "res://assets/skills/sovalye_kiskirtma_icon.png",
		## Kullanıcı bildirimi: "bazı karakterlerin pasifi oyun içindeyken
		## görünmüyor" - kök neden Şovalye Adam'ın hiç pasifi olmamasıydı
		## (tek istisna, diğer 10 karakterin hepsinde var). Kullanıcı isteğiyle
		## eklendi: aldığı hasarın bir kısmını saldırgana geri yansıtır (bkz.
		## player.gd thorns_reflect_percent/take_damage). Henüz gerçek sanat
		## eseri ikonu yok, bu yüzden "passive_vector_id" ile skill_icon.gd
		## _icon_thorns'a düşüyor (bkz. Talon Devleşme'nin gerçek ikonu
		## gelene kadar aynı şekilde vektörle gösterilmesiyle AYNI desen).
		"passive": "Dikenli Zırh: Aldığı hasarın %10'unu saldırgana geri yansıtır.",
		"passive_vector_id": 16,
		"thorns_reflect_percent": 0.10,
		## Kullanıcı isteği: Şovalye Adam'ın yeni 3. yeteneği (skill3, R
		## tuşu) - yakındaki dostların etrafında 15sn boyunca dönen bir
		## bariyer oluşturup aldıkları hasarın %30'unu kendine yansıtır
		## (bkz. player.gd _skill_paladin_barrier, skill id 29).
		"skill3": 29,
		"skill3_name": "Koruma Bariyeri",
		"skill3_desc": "3. YETENEK: Yakındaki dostların etrafında 15sn boyunca dönen bir bariyer oluşturur, aldıkları hasarın %30'unu kendine yansıtır (kendi kalkanından geçer). Dost çok uzaklaşırsa bariyeri kaybolur. (60sn bekleme)",
		"frames": "res://assets/characters/sovalye_frames.tres",
		"portrait": "res://assets/characters/sovalye_portrait.png",
	},
	8: {
		"name": "Elara",
		## DÜZELTME (kullanıcı isteği: "Elaranın R ile Q yeteneğinin yerini
		## değiştir") - Talon'un AYNI isteğiyle (bkz. characters.gd DEFS[1]
		## üstündeki "R ile Q'nun yerini değiştir" notu) BİREBİR aynı desen:
		## id NUMARALARI (12=Çift Tetik, 31=Kalkan Sıçraması) ve "skill"/
		## "skill3" alanlarının HANGİ id'yi taşıdığı DEĞİŞMEDİ - SADECE
		## player.gd'de hangi fonksiyonun/bekleme süresinin/bedelin hangi
		## id'ye bağlı olduğu swap edildi (bkz. _activate_skill/
		## _activate_skill3 match blokları, SKILL_TIMING[12]/SKILL3_TIMING[31]
		## üstündeki eşleşen notlar) - Kalkan Sıçraması artık Q'da (hafif/
		## sık), Çift Tetik artık R'de (ağır/gerçek ulti). Buradaki metin
		## alanları da buna göre yer değiştirdi.
		"skill": 12,
		"skill_name": "Kalkan Sıçraması",
		"skill_desc": "YETENEK: İleri kısa bir hamle atar ve anında kalkanının %12'sini yeniler. Kalkan harcamaz. (6sn bekleme)",
		## Kalkan Sıçraması'nın kendi ikon dosyası hiç olmadı (eskiden R'de
		## de yoktu, bkz. hud.gd _setup_ability_icons - def.has("skill_icon")
		## yoksa skill_icon.gd kendi vektör simgesine düşer, hatasız).
		"skill2": 11,
		"skill2_name": "Gerçek Hasar",
		"skill2_desc": "TEMEL: Sonraki 6 saldırı %50 fazla hasar vurur ve kalkanı yok sayar. (35sn bekleme)",
		"skill2_icon": "res://assets/skills/elara_gercek_hasar_icon.png",
		"skill3": 31,
		"skill3_name": "Çift Tetik",
		"skill3_desc": "ULTİ: 25 saniye boyunca saldırılar 2 kez tetiklenir ama %60 hasar verir. (120sn bekleme)",
		"skill3_icon": "res://assets/skills/elara_cift_tetik_icon.png",
		"passive": "Seviye başına %1 saldırı hızı kazanır. (En fazla %50)",
		"passive_icon": "res://assets/skills/elara_passive_icon.png",
		"frames": "res://assets/characters/elara_frames.tres",
		"portrait": "res://assets/characters/elara_portrait.png",
	},
	9: {
		"name": "Korsan",
		## Kullanıcı isteği (beni oku.txt): Temel yetenek saatli bomba bırakır
		## (2 yük, yükü başına 20sn yenilenme - bkz. player.gd
		## _korsan_bomb_charges/KORSAN_BOMB_RECHARGE_TIME), ULTİ bırakılmış TÜM
		## bombaları patlatır (bkz. _skill_korsan_detonate_all/SKILL_TIMING[18]).
		"skill": 18,
		"skill_name": "Patlat",
		"skill_desc": "ULTİ: Bırakılmış tüm saatli bombaları patlatır. (20sn bekleme)",
		"skill_icon": "res://assets/skills/korsan_patlat_icon.png",
		"skill2": 17,
		"skill2_name": "Saatli Bomba",
		"skill2_desc": "TEMEL: Bulunduğu konuma saatli bomba bırakır (3 yük, yük başına 14sn yenilenir). Patladığında 32 + saldırı gücünün %220'si kadar hasar verir.",
		"skill2_icon": "res://assets/skills/korsan_saatli_bomba_icon.png",
		## Kullanıcı isteği: Korsan'ın yeni 3. yeteneği (Bombardıman, skill3 id
		## 34, R tuşu) - "etrafındaki büyük bir alana 8 saniye boyunca
		## bombardımana alır, her saniye %150 saldırı gücü kadar hasar verir."
		## Standart skill3_state (SKILL3_TIMING[34]) makinesini kullanır, gerçek
		## tikler player.gd _process_korsan_bombardment'ta.
		"skill3": 34,
		"skill3_name": "Bombardıman",
		"skill3_desc": "3. YETENEK: Etrafındaki büyük bir alanı 8 saniye boyunca bombardımana tutar, her saniye saldırı gücünün %150'si kadar hasar verir. (40sn bekleme)",
		"passive": "Her öldürmede %10 ihtimalle 1 altın kazanırsın. Bu şans her level için +%1 artar (en fazla %100).",
		"passive_icon": "res://assets/skills/korsan_passive_icon.png",
		"frames": "res://assets/characters/korsan_frames.tres",
		"portrait": "res://assets/characters/korsan_portrait.png",
		## Yeni karakterlerin atlas'ında (beni oku.txt - sadece Idle/Hurt/
		## Spellcast/Walk) "run" animasyonu YOK - Büyücü Kız/Kurt Adam'da
		## olduğu gibi always_walk=true olmazsa, hız bir eşiği (bkz. player.gd
		## RUN_ANIM_SPEED_RATIO) aşınca _update_animation() var olmayan
		## "run_*" animasyonunu oynatmaya çalışır, AnimatedSprite2D'nin
		## gösterecek texture'ı kalmaz ve karakter TAMAMEN GÖRÜNMEZ olur
		## (hareket/saldırı/can vs. hepsi normal çalışmaya devam eder, sadece
		## sprite kaybolur) - kullanıcı bildirimi "son 3 karakter oyunun
		## içinde görünmüyor" bunun sonucuydu.
		"always_walk": true,
	},
	10: {
		"name": "Melek",
		## Kullanıcı isteği (beni oku.txt): "Oakley adlı karakterin bütün
		## yetenekleri ve pasifi Melek'e olduğu gibi geçecek" - bu yüzden
		## skill/skill2 id'leri BİREBİR Oakley'ninkiyle (char 2) aynı bırakıldı,
		## metinler de birebir kopyalandı. DÜZELTME (kullanıcı isteği: "Oakley
		## ve Melek aynı karakter değil, sadece aynı yetenekleri
		## kullanıyorlardı - Melek'e sakın dokunma, Oakley değişecek sadece") -
		## Oakley'nin YENİ kiti (Çiçek/Sarmaşıklar/yeni pasif) BİLEREK BURAYA
		## KOPYALANMADI, Melek eski Can Basma/Kalkan Yenileme kitini AYNEN
		## koruyor. player.gd tarafında Oakley'e özel "GameManager.
		## selected_char_id == 2" kontrolleri SADECE Oakley'i kapsıyor, 10
		## (Melek) artık dahil DEĞİL - bkz. _skill2_timing_for/_skill_kalkan_
		## yenileme/_process_oakley_passive.
		"skill": 1,
		"skill_name": "Can Basma",
		"skill_desc": "ULTİ: Anında %15 can yeniler, sonraki 6sn boyunca saniyede %1 can + saldırı gücünün %60'ı kadar can yeniler (kendine+müttefiğe). (20sn bekleme)",
		"skill_icon": "res://assets/skills/oyku_ulti_can_basma_icon.png",
		"skill2": 10,
		"skill2_name": "Kalkan Yenileme",
		"skill2_desc": "TEMEL: 6 saniye boyunca saniyede %1 kalkan + saldırı gücünün %60'ı kadar kalkan yeniler (kendine+müttefiğe). (15sn bekleme)",
		"skill2_icon": "res://assets/skills/oyku_kalkan_yenileme_icon.png",
		## Kullanıcı isteği: Melek'in yeni 3. yeteneği (skill3, R tuşu) -
		## kendi etrafında VE can basma/kalkan yenileme ile bağ kurduğu
		## dostun etrafında yakındaki tüm yaratıkları korkutup kaçırır
		## (bkz. player.gd _skill_melek_fear, skill id 32).
		"skill3": 32,
		"skill3_name": "Kutsal Korku",
		"skill3_desc": "3. YETENEK: Kendi etrafındaki (ve bağ kurduğu dostun etrafındaki) tüm yaratıkları 4 saniye boyunca korkutup kaçırır. (45sn bekleme)",
		## DÜZELTME (kullanıcı isteği: "Melek'in pasifi %0.5 can yerine saldırı
		## gücünün %5'si olarak güncelle. Yani 100 saldırı gücü varsa 5 can
		## yenileyecek yakınındaki herkes.") - bkz. player.gd _passive_oakley/
		## OAKLEY_PASSIVE_ATTACK_POWER_PERCENT.
		"passive": "Kendisinin ve yakındaki takım arkadaşlarının canını saniyede saldırı gücünün %5'i kadar yeniler.",
		"passive_icon": "res://assets/skills/oyku_passive_icon.png",
		"frames": "res://assets/characters/melek_frames.tres",
		"portrait": "res://assets/characters/melek_portrait.png",
		## Bkz. Korsan'daki "always_walk" notu - Melek'in atlas'ında da "run"
		## animasyonu yok, aynı görünmezlik hatasını önlemek için gerekli.
		"always_walk": true,
	},
	11: {
		"name": "Necromancer",
		## Kullanıcı isteği (beni oku.txt): Pasif yakında ölen her düşmandan
		## ruh biriktirir (bkz. player.gd on_enemy_killed/_necro_gain_soul),
		## TEMEL 10 ruh karşılığında iskelet çağırır (bekleme süresi yok, bkz.
		## SKILL2_TIMING[19]/_skill_necro_summon_skeleton - kullanıcı isteği
		## üzerine artık 1sn bekleme süresi eklendi, bkz. NECRO_SKELETON_
		## COOLDOWN), ULTİ 100 ruh karşılığında bir Golem çağırır (10sn bekleme,
		## bkz. SKILL_TIMING[20]/_skill_necro_summon_golem). Ruh yoksa hiçbiri
		## tetiklenmez, ikisi de kalkan tüketmez (bkz. _activate_skill/
		## _activate_skill2'deki id 20/19 muafiyeti). Ruh bedelleri sonradan
		## kullanıcı isteğiyle (İskelet 3->10, Golem 10->100) tekrar güncellendi
		## - bkz. player.gd NECRO_SKELETON_SOUL_COST/NECRO_GOLEM_SOUL_COST.
		## DÜZELTME (kullanıcı isteği: "necromancerın ultisi hayalet yerine
		## golem çağırsın") - ULTİ eskiden Hortlak (menzilli, kaçan) çağırıyordu,
		## artık necro'nun statlarının/canının %200'üne sahip, kalkanlı, 6sn'de
		## bir çevresini sersemleten bir Golem çağırıyor (bkz. golem_pet.gd).
		## DÜZELTME (kullanıcı bildirimi: "golemi aşırı hızlı hareket ediyor...
		## saldırı hızı azaltmasını %50 den %20 ye düşür") - buradaki yüzde
		## golem_pet.gd'deki GOLEM_ATTACK_SLOWDOWN_PERCENT ile AYNI kalmalı,
		## %50 -> %20 olarak güncellendi.
		"skill": 20,
		"skill_name": "Golem Çağır",
		"skill_desc": "ULTİ: 100 Ruh tüketerek canının %200'üne sahip (hareket hızı %70, saldırı gücü %50 oranında), kalkanlı bir Golem çağırır (en fazla 2 tane, %20 daha yavaş saldırır, 6sn'de bir çevresindeki yaratıkları 1sn sersemletir, 120sn yaşar). (10sn bekleme)",
		"skill_icon": "res://assets/skills/necromancer_hortlak_cagir_icon.png",
		"skill2": 19,
		"skill2_name": "İskelet Çağır",
		"skill2_desc": "TEMEL: 10 Ruh tüketerek kendisi için savaşan bir iskelet yaratır (statlarının %30'u, canının %100'ü, kalkansız, 60sn yaşar). Toplamda (iskelet+golem) en fazla 10 yaratığa sahip olabilirsin. (1sn bekleme)",
		"skill2_icon": "res://assets/skills/necromancer_iskelet_cagir_icon.png",
		## Kullanıcı isteği: Necromancer'ın yeni 3. yeteneği (Yarasa Sürüsü,
		## skill3 id 35, R tuşu) - basılıp kapatılabilen bir TOGGLE, standart
		## skill3_state makinesini KULLANMAZ (bkz. player.gd _necro_toggle_bats/
		## _process_necro_bats). Her saniye %1 maks kalkan + 25 kalkan tüketip
		## menzildeki yaratıklara yarasa gönderir, yarasalar hedefe vurup geri
		## döner.
		"skill3": 35,
		"skill3_name": "Yarasa Sürüsü",
		"skill3_desc": "3. YETENEK (BASILIP KAPATILABİLİR): Açıkken her saniye %1 maksimum kalkan + 25 kalkan tüketerek etrafındaki yaratıklara yarasa gönderir. Yarasalar hedefe saldırı gücünün %80'i kadar hasar verip sana geri döner (hızları hareket hızınla eşittir). Kalkanın biterse kendiliğinden kapanır.",
		"passive": "Etrafta ölen her düşman 1 ruh biriktirir (bosslar 5 ruh). Biriken ruh sayısı pasif ikonunun üstünde görünür.",
		"passive_icon": "res://assets/skills/necromancer_passive_icon.png",
		"frames": "res://assets/characters/necromancer_frames.tres",
		"portrait": "res://assets/characters/necromancer_portrait.png",
		## Bkz. Korsan'daki "always_walk" notu - Necromancer'ın atlas'ında da
		## "run" animasyonu yok, aynı görünmezlik hatasını önlemek için gerekli.
		"always_walk": true,
	},
	12: {
		"name": "Shaman",
		## Kullanıcı isteği: yeni karakter Shaman, 3 BAĞIMSIZ totem yeteneği
		## (hepsi 60sn bekleme, aynı anda aktif olabilir) - bu yüzden ilk kez
		## üçüncü bir aktif slot ("skill3", R tuşu, bkz. player.gd SKILL3_TIMING/
		## game_manager.gd _setup_input_actions) kullanılıyor. Totemler cast
		## edildiği DÜNYA konumunda sabit kalan, ağ üzerinden senkronize
		## objeler (bkz. scripts/totem_base.gd - golem_pet.gd'nin "sabit"
		## versiyonu).
		"skill": 26,
		"skill_name": "Kalkan Totemi",
		"skill_desc": "ULTİ (kalkan harcamaz): Bulunduğun konuma bir totem diker. Totem 30sn boyunca her saniye etrafındaki müttefiklere (ve sana) kendi kalkanının %0.5'i + saldırı gücünün %20'si kadar kalkan yeniler. (60sn bekleme)",
		"skill_icon": "res://assets/skills/shaman_kalkan_totemi_icon.png",
		"skill2": 27,
		"skill2_name": "Saldırı Totemi",
		"skill2_desc": "TEMEL: Bulunduğun konuma bir totem diker. Totem 30sn boyunca düzenli olarak en yakın düşmana ateş eder, saldırı gücü ve saldırı hızı senin statlarının %150'si kadardır. (60sn bekleme)",
		"skill2_icon": "res://assets/skills/shaman_saldiri_totemi_icon.png",
		"skill3": 28,
		"skill3_name": "Alan Saldırı Totemi",
		"skill3_desc": "R: Bulunduğun konuma bir totem diker. Totem 30sn boyunca etrafına bir alan açar - alana giren düşmanlar %20 + saldırı gücünün %20'si kadar (en fazla %80) yavaşlar, alanda duran düşmanlar her saniye saldırı gücünün %20'si kadar hasar alır. (60sn bekleme)",
		"skill3_icon": "res://assets/skills/shaman_alan_totemi_icon.png",
		"passive": "Totem Auraları: totemlerine yakın müttefiklerin düşmanlara verdiği hasar, düşmana 3sn boyunca her saniye o müttefiğin saldırı gücünün %10'u kadar yakma hasarı bırakır.",
		"passive_icon": "res://assets/skills/shaman_passive_icon.png",
		"frames": "res://assets/characters/shaman_frames.tres",
		"portrait": "res://assets/characters/shaman_portrait.png",
		## shaman.zip'in atlas'ında (standart LPC walk/idle/hurt/spellcast)
		## "run" animasyonu yok - bkz. Korsan/Melek/Necromancer'daki AYNI
		## "always_walk" notu, yoksa hız eşiği aşılınca karakter TAMAMEN
		## GÖRÜNMEZ olur.
		"always_walk": true,
	},
}


## Ortak "ana silah": artık her karakter oto saldırısı için kendi silahı
## yerine bunu kullanıyor (Assasin Çocuk'un hançer/yakın dövüş mantığıyla
## birebir aynı) - dükkandaki silah yükseltmeleri (fire_staff/lightning_staff/
## tabanca) tamamen kaldırıldı, silah geliştirme için ileride ayrı bir sistem
## yapılacak. R tuşuyla çalışan karakter yeteneği (skill/ulti) bundan ayrı, aynen
## kalıyor.
const MAIN_WEAPON := {
	"melee": true,
	"melee_range": 110.0,
	"melee_aoe_radius": 60.0,
	"melee_aoe_damage": 0.5,
	"attack_sounds": [
		"res://assets/audio/assasin_swing1.mp3",
		"res://assets/audio/assasin_swing2.mp3",
		"res://assets/audio/assasin_swing3.mp3",
	],
	"slash_fx": "res://scenes/fx_assasin_slash.tscn",
	"melee_hit_segments": 3,
	## weapon.gd artık efekti/ikonu hedefin (yaratığın) gerçek konumuna
	## yakın bir noktaya koyuyor - bu değer, tam üstüne binip görüşü
	## kapatmasın diye saldırı yönünün TERSİNE (oyuncuya doğru) ne kadar
	## geri çekileceğini belirler. Eski "karakterden dışa kayma" mesafesi
	## (95px) burada anlamsız - küçük bir değer (yaratığın kenarı kadar).
	## DÜZELTME (kullanıcı bildirimi: "yakın dövüş silahlarının animasyonları
	## saldırdığı hedeften çok uzakta görünüyor hedefe daha yakın olmaları
	## gerekiyor") - 18px hâlâ fark edilir bir boşluk bırakıyordu, 8px'e
	## düşürüldü (pençe/topuz/uzunkılıç ile TUTARLI kalması için oradaki
	## configure_melee() çağrılarındaki sabitler de aynı oranda küçültüldü).
	"slash_fx_offset": 8.0,
}


static func get_def(char_id: int) -> Dictionary:
	return DEFS.get(char_id, DEFS[1])
