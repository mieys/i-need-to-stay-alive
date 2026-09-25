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

## TÜM karakterlerin PAYLAŞILAN taban hareket hızı (bkz. player.gd "speed"
## export'unun varsayılanı, oradan buraya taşındı). remote_player.gd, hızlı
## hareket ederken yürüme animasyonunu (speed_scale) player.gd ile AYNI
## oranda hızlandırabilmek için gözlemlediği ağ hızını bu değere bölüyor -
## iki tarafın da AYNI sayıyı ayrı ayrı yazmaması için (bkz. CLAUDE.md
## paylaşılan formül kuralı) tek kaynak burası.
const BASE_MOVE_SPEED := 252.0

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
		## DÜZELTME (kullanıcı isteği: gerçek sanat eseri ikonlar) - eskiden
		## Q ile AYNI geçici "talon_devlesme_icon.png" dosyasını paylaşıyordu,
		## artık kendi özel ikonu var.
		"skill3_icon": "res://assets/skills/talon_ayna_formu_icon.png",
		"passive": "Yetenek kullandıkça yığılan güç: her kullanımda 6sn süren bir yük kazanır (en fazla 5, +%6 saldırı gücü / +%4 hasar azaltma her yük) - yetenek kullanılmazsa yükler 2sn'de bir azalır.",
		"passive_icon": "res://assets/skills/talon_passive_icon.png",
		"frames": "res://assets/characters/talha_frames.tres",
		"portrait": "res://assets/characters/talha_portrait.png",
		## Kullanıcı isteği (2026-09-22, new characters.zip): yeni 48x48 sprite sayfaları (idle/walk/run/eat/hurt/read/shrug/downed/death + kullanılmayan
		## strike/chop/pickup - tools/import_character_sheets.py). Gömülü gölge YOK: piksel elips ayak gölgesi (ground_shadow.gd).
		## Kullanıcı isteği (boyut): "Elara, büyücü kız, vampir çocuk, talon, melek ve korsan ... boyutunu %25 arttır" -
		## ölçek 1.78947 x 1.25 = 2.2368375 (EntityScale 0.95 ile oyun içi 2.125 px/sanat pikseli).
		## Karakter büyüyünce ayaklar aşağı kayacağı için offset.y telafi edildi: (41 - 24 - 1.8) x 2.125 = 32.3 px,
		## yani ayaklar eskisi gibi zemin çizgisinde kalır ve gölge (ground_shadow_y = 32.5) aynı yerde durur.
		## Gölge yarıçapı da karakterle orantılı büyütüldü (x1.25).
		## "run" klibi hareket hızı bonusu %15'i aşınca oynar (talimat) - eski "always_walk" kaldırıldı.
		"scale": Vector2(2.2368375, 2.2368375),
		"offset": Vector2(0, -1.8),
		"ground_shadow": Vector2(17.5, 6.25),
		"ground_shadow_y": 32.5,
		"run_speed_ratio": 1.15,
	},
	## DÜZELTME (kullanıcı isteği: "Oakley yeni yetenekleri", sonra "Oakley ve
	## Melek aynı karakter değil, sadece aynı yetenekleri kullanıyorlardı -
	## Melek'e sakın dokunma") - eski kit (Can Basma ULTİ + Kalkan Yenileme
	## TEMEL) SADECE Oakley'de TAMAMEN yeni bir kitle değiştirilmişti: Çiçek
	## (Q, yük tabanlı), Sarmaşıklar (E), Arı Sürüsü (R). Melek (char 10)
	## KENDİ eski kitini AYNEN koruyor - iki karakter geçmişte skill/skill2
	## numaralarını (1/10) PAYLAŞIYORDU ama bu SADECE sayısal id paylaşımıydı.
	## SONRAKİ TAM KİT DEĞİŞİKLİĞİ (kullanıcı isteği: "Oakleyin pasifi
	## silinecek ve Q su bundan sonra pasifi olacak... Oakleyin R yeteneği
	## artık boşta kalan Q yeteneği olacak... Yeni R yeteneği ise canı en az
	## olan arkadaşına koruyucu bir büyü yapar") - üç yönlü rotasyon: Çiçek
	## (eski Q, id 1) artık bir tuş yeteneği DEĞİL, tamamen otomatik bir
	## PASİF (bkz. player.gd _process_oakley_passive/_spawn_oakley_flower_
	## auto - 2 yük sistemi kaldırıldı, artık tek sabit aralıkla kendiliğinden
	## düşüyor); Arı Sürüsü (eski R, id 33) Q'ya taşındı; yepyeni bir yetenek
	## (Koruyucu Büyü, id 39) R'nin yeni sahibi. Eski düşük-can tetiklemeli
	## kalkan/can pasifi TAMAMEN silindi. player.gd tarafında Oakley'e özel
	## dallar SADECE "GameManager.selected_char_id == 2" kontrolüyle
	## ayrılıyor, Melek'in roster id'si (10) bunların hiçbirine dahil değil.
	2: {
		"name": "Oakley",
		## DÜZELTME (kullanıcı isteği: "Oakleyin R yeteneği artık boşta kalan Q
		## yeteneği olacak") - Arı Sürüsü buraya taşındı, id/metin/ikon
		## DEĞİŞMEDİ (bkz. eski skill3 alanları, artık burada).
		"skill": 33,
		"skill_name": "Arı Sürüsü",
		## 2026-09-25 ikinci tasarım (sabit alan yerine takip eden koruyucu sürü) - bkz. fx_oakley_bee_guard.gd sabitleri.
		"skill_desc": "YETENEK: 10sn boyunca etrafını geniş bir halka halinde saran minik arılar çağırır. Halkaya giren yaratıklar geri itilir ve zehirlenir: her etki 1 zehir yükü ekler (en fazla 10), her yük 4sn boyunca toplam saldırı gücünün %20'si kadar hasar verir. Aynı yaratık saniyede en fazla bir kez etkilenir. (20sn bekleme)",
		"skill_icon": "res://assets/skills/oakley_ari_suru_icon.png",
		"skill2": 10,
		"skill2_name": "Sarmaşıklar",
		"skill2_desc": "TEMEL: Yakındaki yaratıklara doğru ilerleyen 3 sarmaşık yaratır (6sn). İsabet eden yaratığı 4sn yere sabitler (hareket edemez, saldırabilir) ve saldırı gücünün %60'ı kadar hasar verir. Bosslar sabitlenmez, bunun yerine %30 yavaşlar. (16sn bekleme)",
		"skill2_icon": "res://assets/skills/oakley_sarmasik_icon.png",
		## DÜZELTME (kullanıcı isteği: "Yeni R yeteneği ise canı en az olan
		## arkadaşına koruyucu bir büyü yapar...") - bkz. player.gd
		## _skill_oakley_bond/OAKLEY_BOND_* sabitleri.
		## Kullanıcı isteği: "oakleyin ultisinin ikonunu 1-2 gün önce yüklediğimiz ve sonra
		## kaldırdığımız pasif ikonu olarak göster" - oakley_passive_icon.png 17 Eylül'de
		## eklenmişti, pasif Çiçek'e dönüşünce (bkz. "passive_icon" aşağıda, artık
		## oakley_cicek_icon.png) kullanımdan çıkmıştı; ULTİ (Koruyucu Büyü) ikonu olarak geri geldi.
		"skill3": 39,
		"skill3_name": "Koruyucu Büyü",
		"skill3_icon": "res://assets/skills/oakley_passive_icon.png",
		"skill3_desc": "ULTİ: Yakınındaki dostlar arasında canı (oran olarak) en az olana (kendisi dahil, önceliklidir) koruyucu bir büyü yapar. 10sn boyunca hedef her hasar aldığında Oakley'nin saldırı gücünün %20'si kadar can, %10'u kadar kalkan yeniler ve %20 hasar azaltma kazanır. (60sn bekleme)",
		## DÜZELTME (kullanıcı isteği: "Oakleyin pasifi silinecek ve Q su
		## bundan sonra pasifi olacak, ve otomatik olarak yakınlarına çiçek
		## bırakacak... 2 yük olayı falan yok bunda dolduğu anda oakleyin
		## yakınında rasgele yerlere bıraksın") - eski düşük-can tetiklemeli
		## kalkan/can pasifi TAMAMEN kaldırıldı, yerine Çiçek geldi (bkz.
		## player.gd _process_oakley_passive/OAKLEY_FLOWER_AUTO_INTERVAL).
		## Çiçeğin ALINDIĞINDA verdiği etkiler (can/kalkan/hız, büyüme) hiç
		## değişmedi - bkz. oakley_flower.gd, SADECE tetikleme yöntemi
		## (yük yerine otomatik zamanlayıcı + rastgele yakın konum) değişti.
		"passive": "Her 18 saniyede bir yakınına rastgele bir noktaya kendiliğinden bir çiçek bırakır (kendisi veya bir dost alabilir, 180sn yerde kalır, sihirli yeşil bir aurayla haritadaki dekorlardan ayırt edilir). Alınırsa saldırı gücünün %50'si kadar can + alanın %2 max kalkanı ve saldırı gücünün %15'i kadar kalkan yeniler, ayrıca alanı 2sn boyunca azalarak kaybolan %25 hıza kavuşturur; alınmazsa 5sn'de bir büyüyüp verdiği can/kalkanı kümülatif %40 arttırır (en fazla 2 büyüme).",
		## DÜZELTME (kullanıcı isteği: gerçek sanat eseri ikonlar) - eskiden
		## Melek ile AYNI geçici "oyku_ulti_can_basma_icon.png" dosyasını
		## paylaşıyordu, artık pasif haline gelen Çiçek'in KENDİ ikonu.
		"passive_icon": "res://assets/skills/oakley_cicek_icon.png",
		"frames": "res://assets/characters/oyku_frames.tres",
		"portrait": "res://assets/characters/oyku_portrait.png",
		## Kullanıcı isteği (2026-09-25, new characters.zip #3): eski LPC atlası (oyku_atlas.png, silindi) yerine yeni 48x48 sayfalar
		## (tools/import_character_sheets.py, anahtar "oakley" -> assets/characters/oakley/sheets; dosya adları oyku_*
		## korundu). Aynı üretici kanvası (OLCU: gövde 14x37, ayak satırı 40) - Talon/Elara'yla AYNI ölçek/offset/gölge
		## yüksekliği; gölge genişliği aynı gövde genişliğindeki (14) Matthew'in küçültme öncesi değeri.
		"scale": Vector2(2.2368375, 2.2368375),
		"offset": Vector2(0, -1.8),
		"ground_shadow": Vector2(15.25, 6.25),
		"ground_shadow_y": 32.5,
		"run_speed_ratio": 1.15,
	},
	3: {
		"name": "Matthew",
		## Kullanıcı isteği (2026-09-22): "Matthew'in yeni skili (diğer yeteneklerini bozmadan bunu Q'ya
		## yerleştir hız yeteneğini E'ye kalkan yeteneğini de R'ye yerleştir)" - Tilki Hücumu (yeni, id 43)
		## Q'ya geldi, Vahşi Hız (id 21) E'de DEĞİŞMEDEN kaldı, Feda Kalkanı (id 9) R/skill3'e taşındı
		## (bkz. player.gd _activate_skill/_activate_skill3 - eşleşen "Matthew Q/R yer değişimi" notları).
		"skill": 43,
		"skill_name": "Tilki Hücumu",
		"skill_desc": "YETENEK: Tilkisini anında yanına ışınlayıp görüş alanındaki en fazla 6 düşmana dash saldırısı attırır, saldırı gücünün %110'u kadar hasar verir ve onları kendinden uzağa iter. (8sn bekleme)",
		## Kullanıcı isteği (2026-09-25): Matthew'in 4 ikonu 48x48 piksel olarak sıfırdan çizildi (tools/gen_matthew_icons.py) -
		## Q artık Feda Kalkanı'nın ikonunu paylaşmıyor, kendi ikonu var.
		"skill_icon": "res://assets/skills/matthew_tilki_hucumu_icon.png",
		"skill2": 21,
		"skill2_name": "Vahşi Hız",
		"skill2_desc": "TEMEL: Kendine ve tilkisine 10 saniye boyunca %40 saldırı hızı ve %15 hareket hızı kazandırır. (35sn bekleme)",
		"skill2_icon": "res://assets/skills/matthew_vahsi_hiz_icon.png",
		"skill3": 9,
		"skill3_name": "Feda Kalkanı",
		"skill3_desc": "ULTİ: Yaratığı feda edip 15sn süren koruyucu bir kalkan çemberi kurar. (120sn bekleme)",
		"skill3_icon": "res://assets/skills/matthew_feda_kalkani_icon.png",
		"passive": "Statlarının %50'siyle saldıran bir yaratığa sahipsin. Ölürse 30sn sonra yeniden doğar.",
		"passive_icon": "res://assets/skills/matthew_passive_icon.png",
		"frames": "res://assets/characters/matthew_frames.tres",
		"portrait": "res://assets/characters/matthew_portrait.png",
		## Kullanıcı isteği (2026-09-23, new characters.zip #2): yeni 48x48 sprite sayfaları
		## (idle/walk/run/eat/hurt/read/shrug/down/death + kullanılmayan strike/chop/pickup -
		## tools/import_character_sheets.py). Diğer 48x48 kitin (Talon/Büyücü/Elara/Korsan/
		## Melek) AYNI ölçek/offset/ground_shadow_y sabitleri kullanıldı - aynı üretici/kanvas
		## düzeninden geldiği için (ayak satırı hepsinde 40/48) bu değerler karakterler arası
		## SABİT, sadece gölge genişliği (ground_shadow.x) ölçülen gövde genişliğine göre değişir.
		## DÜZELTME (kullanıcı isteği: "Matthew'in boyutunu %20 küçült") - "scale" x0.8
		## (2.2368375 -> 1.78947, tam olarak diğer 48x48 karakterlerin %25 büyütülmeden ÖNCEki
		## taban ölçeği). "offset" DEĞİŞMEDİ (art-piksel biriminde, sahne ölçeğiyle otomatik
		## küçülür) ama "ground_shadow"/"ground_shadow_y" EKRAN piksели cinsinden SABİT
		## değerlerdi - ölçekle orantılı küçültülmezse gölge artık ayakların altında değil
		## daha AŞAĞIDA kalırdı, bu yüzden ikisi de AYNI x0.8 ile çarpıldı.
		## Kullanıcı isteği (2026-09-23): "matthewi %10 büyüt" - scale x1.1 (1.78947 -> 1.968417); yukarıdaki
		## gerekçeyle gölge (ground_shadow/ground_shadow_y, ekran pikseli) de AYNI x1.1 ile büyütüldü.
		"scale": Vector2(1.968417, 1.968417),
		"offset": Vector2(0, -1.8),
		"ground_shadow": Vector2(13.42, 5.5),
		"ground_shadow_y": 28.6,
		"run_speed_ratio": 1.15,
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
		## Kullanıcı isteği (2026-09-24): Büyücü Kız'ın E'si de 1. seviyede açık (diğerlerinde 5) - bkz. skill_unlock_level.
		"skill2_unlock_level": 1,
		"skill_desc": "YETENEK: TEMEL (E) ve ULTİ (R) setini birlikte değiştirir (Set 1: Arcane Lanet + Hortum <-> Set 2: Don Nova + Meteor Patlaması). (1sn bekleme)",
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
		"skill2_desc": "TEMEL (2 setli - Q ile değiştirilir):\n1) Arcane Lanet: yaratıklar arasında 4 kez sekip her sekişte saldırı gücünün %80'i kadar hasar verir. (4sn bekleme)\n2) Don Nova: etraftaki tüm yaratıkları 6sn dondurur (donan yaratık hiçbir şey yapamaz) ve saldırı gücünün %100'ü kadar hasar verir. (30sn bekleme)",
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
		"skill3_desc": "ULTİ (2 setli - Q ile değiştirilir):\n1) Hortum: 15sn boyunca dolaşan 3 hortum çıkarır, her biri değdiği yaratığa saniyede en fazla 1 kez saldırı gücünün %90'ı kadar hasar verir. (45sn bekleme)\n2) Meteor Patlaması: 5sn hareketsiz odaklanıp etrafa saldırı gücünün %120'si kadar hasar veren meteorlar yağdırır. (120sn bekleme)",
		"skill3_variation_icons": [
			"res://assets/skills/buyucu_skill_hortum_icon.png",
			"res://assets/skills/buyucu_skill_meteor_icon.png",
		],
		## Pasif YOK: eski "Kadim Patlama" kullanıcı isteğiyle silindi (2026-09-23) - "passive" alanı olmadığı için
		## HUD/karakter seçimi/lobi pasif ikonunu ve açıklamasını otomatik gizler (bkz. hud.gd has_passive).
		"frames": "res://assets/characters/buyucu_frames.tres",
		"portrait": "res://assets/characters/buyucu_portrait.png",
		## Kullanıcı isteği (2026-09-22, new characters.zip): yeni 48x48 sprite sayfaları (idle/walk/run/eat/hurt/read/shrug/downed/death + kullanılmayan
		## strike/chop/pickup - tools/import_character_sheets.py). Gömülü gölge YOK: piksel elips ayak gölgesi (ground_shadow.gd).
		## Kullanıcı isteği (boyut): "%25 büyüt" - ölçek 1.78947 x 1.25 = 2.2368375 (EntityScale 0.95 ile oyun içi 2.125 px/sanat pikseli).
		## Ayaklar zemin çizgisinde (~32 px) kalsın diye offset.y = -1.8: (41 - 24 - 1.8) x 2.125 = 32.3 px.
		## Gölge yarıçapı da orantılı büyütüldü (x1.25); ground_shadow_y aynı kaldı (ayak çizgisi değişmedi).
		## "run" klibi hareket hızı bonusu %15'i aşınca oynar (talimat) - eski "always_walk" kaldırıldı.
		"scale": Vector2(2.2368375, 2.2368375),
		"offset": Vector2(0, -1.8),
		"ground_shadow": Vector2(18.75, 6.875),
		"ground_shadow_y": 32.5,
		"run_speed_ratio": 1.15,
		## (eski "always_walk" kaldırıldı: yeni sayfalarda gerçek "run" klibi var)
		"projectile_scene": "res://scenes/buyucu_projectile.tscn",
		"projectile_rotation_offset": -2.3999243,
	},
	5: {
		"name": "Assasin Çocuk",
		## DÜZELTME (kullanıcı isteği: "Assasin çocuğun R si ile Q skillinin
		## yerini değiştir") - Talon'un "R ile Q'nun yerini değiştir" isteğiyle
		## AYNI desen (bkz. o karakterin DEFS'indeki üstteki not): id NUMARALARI
		## (16=Q/ULTİ, 30=skill3/R) AYNI kaldı, sadece HANGİ fonksiyonun hangi
		## id'ye bağlı olduğu player.gd'de swap edildi (bkz. _activate_skill/
		## _activate_skill3 match blokları, SKILL_TIMING[16]/SKILL3_TIMING[30],
		## use_ulti_tier/hafif tarife istisnası) - Gölge Adımı artık Q'da,
		## Gölge Hücumu artık R'de. Eski yorum (aşağıda referans için
		## bırakıldı): eski ULTİ (Görünmezlik, id 5) TEMEL/E slotuna taşınmıştı
		## (bkz. skill2 aşağıda, SKILL2_TIMING[5], _activate_skill2()), yeni
		## bir ULTİ (Gölge Hücumu, id 16) onun yerini almıştı (bkz. player.gd
		## _skill_assasin_dash/SKILL_TIMING[16]) - o değişiklik E'yi
		## ETKİLEMEDİ, hâlâ geçerli.
		"skill": 30,
		"skill_name": "Gölge Adımı",
		"skill_desc": "YETENEK: 6 saniye boyunca görünmez olur ve yaratıkların içinden geçebilir. Görünmezken saldırı gücü %30 artar. (60sn bekleme)",
		## DÜZELTME (kullanıcı isteği: gerçek sanat eseri ikonlar) - eskiden
		## E ile AYNI geçici "assasin_gorunmezlik_icon.png" dosyasını
		## paylaşıyordu, artık kendi özel ikonu var.
		"skill_icon": "res://assets/skills/assasin_golge_adimi_icon.png",
		## DÜZELTME (kullanıcı isteği: yeni temel yetenek) - Görünmezlik'in
		## yerine 8 yönlü, 3 yüklü bir hamle geldi (bkz. player.gd
		## ASSASIN_DASH2_*/_try_assasin_dash2/SKILL2_TIMING[5] üstündeki not).
		"skill2": 5,
		"skill2_name": "Şahin Hamlesi",
		"skill2_desc": "TEMEL: Yürüdüğü yöne (8 yön) hızla hamle yapıp içinden geçtiği düşmanlara saldırı gücünün %150'si kadar hasar verir. 3 yükü vardır, her yük ayrı ayrı 12sn'de yenilenir.",
		"skill2_icon": "res://assets/skills/assasin_sahin_hamlesi_icon.png",
		## Kullanıcı isteği: Assasin Çocuk'un eski ULTİ'si (Gölge Hücumu) -
		## yakındaki yaratıklara sırayla hızla çarpar (bkz. player.gd
		## _skill_assasin_dash, skill id 16) - artık 3. yetenek/R'de.
		"skill3": 16,
		"skill3_name": "Gölge Hücumu",
		"skill3_desc": "ULTİ: 10 saniye boyunca yakındaki yaratıklara sırayla hızla çarpar; her çarpış saldırı gücünün %150'si kadar hasar verir ve saldırı hızının 4,5 katı hızda tekrarlanır. Vurulmamış yaratık kalmazsa (tek yaratık olsa bile) aynı yaratıklara tekrar saldırır. Bitince kullandığı konuma geri döner. (90sn bekleme)",
		"passive": "Bıçak Uzmanlığı: yetenek kullanımından sonraki 3 saniye boyunca garantili kritik vurur.",
		"passive_icon": "res://assets/skills/assasin_passive_icon.png",
		"frames": "res://assets/characters/assasin_frames.tres",
		"portrait": "res://assets/characters/assasin_portrait.png",
		## Kullanıcı isteği (2026-09-23, new characters.zip #2) - bkz. Matthew DEFS'indeki
		## AYNI notun üstündeki gerekçe (ölçüm: OLCU idle_down govde 16x38, ayak satiri 40).
		"scale": Vector2(2.2368375, 2.2368375),
		"offset": Vector2(0, -1.8),
		"ground_shadow": Vector2(17.5, 6.25),
		"ground_shadow_y": 32.5,
		"run_speed_ratio": 1.15,
	},
	7: {
		"name": "Şovalye Adam",
		## Kullanıcı isteği (2026-09-25): "şovalye adamın Q su R olacak. E si yeni Q olacak R si de E olacak" - Matthew'in
		## Q/R değişimiyle AYNI desen: id'ler yuvalar arasında taşındı (player.gd _activate_skill/_activate_skill2/
		## _activate_skill3 + SKILL*_TIMING eşleşen "2026-09-25 slot değişimi" notları). Eski E (Kalkan Yenileme, skill2
		## id 10 - Melek/Oakley ile paylaşılan id) Q'ya Şovalye'ye özel yeni id 45 ile geldi; Koruma Bariyeri (29) E'ye,
		## Koruma Baloncuğu (11) R'ye geçti. Açılış seviyeleri yuvaya bağlı (Q 1, E 5, R 10).
		"skill": 45,
		"skill_name": "Kışkırtma",
		"skill_desc": "YETENEK: 6 saniye boyunca her saniye EKSİK kalkanının %5'i + MAKSİMUM kalkanının %5'i kadar kalkan yeniler ve çevrendeki yaratıkların dikkatini 5 saniye boyunca üzerine çeker. (25sn bekleme)",
		"skill_icon": "res://assets/skills/sovalye_kiskirtma_icon.png",
		"skill2": 29,
		"skill2_name": "Koruma Bariyeri",
		"skill2_desc": "TEMEL: Yakındaki dostların etrafında 15sn boyunca dönen bir bariyer oluşturur, aldıkları hasarın %30'unu kendine yansıtır (kendi kalkanından geçer). Dost çok uzaklaşırsa bariyeri kaybolur. (60sn bekleme)",
		## Kullanıcı isteği (2026-09-25): ikonu yoktu - tools/gen_sovalye_icons.py.
		"skill2_icon": "res://assets/skills/sovalye_koruma_bariyeri_icon.png",
		## Kullanıcı bildirimi: "bazı karakterlerin pasifi oyun içindeyken
		## görünmüyor" - kök neden Şovalye Adam'ın hiç pasifi olmamasıydı
		## (tek istisna, diğer 10 karakterin hepsinde var). Kullanıcı isteğiyle
		## eklendi: aldığı hasarın bir kısmını saldırgana geri yansıtır (bkz.
		## player.gd thorns_reflect_percent/take_damage). "passive_vector_id" (skill_icon.gd _icon_thorns) artık
		## sadece yedek - 2026-09-25'ten beri gerçek piksel ikonu var (tools/gen_sovalye_icons.py).
		"passive": "Dikenli Zırh: Aldığı hasarın %10'unu saldırgana geri yansıtır.",
		"passive_icon": "res://assets/skills/sovalye_passive_icon.png",
		"passive_vector_id": 16,
		"thorns_reflect_percent": 0.10,
		"skill3": 11,
		"skill3_name": "Koruma Baloncuğu",
		"skill3_desc": "ULTİ: Kalkanı bitene kadar içine düşman/mermi girmeyen koruma alanı açar (%30 menzil, kalkan hasarı %95 azalır). Hareket edemez. (120sn bekleme)",
		"skill3_icon": "res://assets/skills/sovalye_ulti_koruma_baloncugu_icon.png",
		"frames": "res://assets/characters/sovalye_frames.tres",
		"portrait": "res://assets/characters/sovalye_portrait.png",
		## Kullanıcı isteği (2026-09-23, new characters.zip #2) - bkz. Matthew DEFS'indeki
		## AYNI notun üstündeki gerekçe (ölçüm: OLCU idle_down govde 16x33, ayak satiri 40).
		"scale": Vector2(2.2368375, 2.2368375),
		"offset": Vector2(0, -1.8),
		"ground_shadow": Vector2(17.5, 6.25),
		"ground_shadow_y": 32.5,
		"run_speed_ratio": 1.15,
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
		## SONRAKİ DÜZELTME (kullanıcı isteği 2026-09-22): "Elaranın Q yeteneği artık dash atmak yerine
		## azalarak kaybolacak şekilde 3sn boyunca %60 hareket hızı, %50 sıvışma ve birimlerin içinden
		## geçebilme kazandırır (sıvışma sınırını aşabilir), 10sn bekleme" - Kalkan Sıçraması (dash) TAMAMEN
		## kaldırıldı, id 12 AYNI kaldı (bkz. player.gd _skill_elara_evasion).
		"skill": 12,
		"skill_name": "Sıvışma",
		## 2026-09-25: hız %100 (azalan) -> %50 SABİT; sıvışma hâlâ azalarak (bkz. player.gd ELARA_EVASION_SPEED_PERCENT).
		"skill_desc": "YETENEK: 3 saniye boyunca %50 hareket hızı ve azalarak kaybolan %50 sıvışma kazandırır, yaratıkların içinden geçebilmeni sağlar (sıvışma sınırını aşabilir). Kalkan harcamaz. (10sn bekleme)",
		## Kullanıcı isteği (2026-09-24): Elara + Korsan'ın TÜM yetenek ikonları 48x48 piksel sanat olarak yeniden
		## çizildi (tools/gen_elara_korsan_icons.py) - Q'nun (Sıvışma) daha önce hiç ikonu yoktu (vektör yedeğine
		## düşüyordu), artık kanatlı çizme ikonu var.
		"skill_icon": "res://assets/skills/elara_sivisma_icon.png",
		"skill2": 11,
		"skill2_name": "Gerçek Hasar",
		## 2026-09-25: 6 saldırı -> 6 saniye, +%50 hasar kaldırıldı, saldırı hızı TOPLAMIN %30'u, bekleme 35 -> 25 sn.
		"skill2_desc": "TEMEL: 6 saniye boyunca saldırıların kalkanı yok sayar ve toplam saldırı hızın %30 artar. (25sn bekleme)",
		"skill2_icon": "res://assets/skills/elara_gercek_hasar_icon.png",
		"skill3": 31,
		"skill3_name": "Çift Tetik",
		"skill3_desc": "ULTİ: 15 saniye boyunca saldırılar 2 kez tetiklenir ama %60 hasar verir. (120sn bekleme)",
		"skill3_icon": "res://assets/skills/elara_cift_tetik_icon.png",
		"passive": "Seviye başına %1 saldırı hızı kazanır. (En fazla %50)",
		"passive_icon": "res://assets/skills/elara_passive_icon.png",
		"frames": "res://assets/characters/elara_frames.tres",
		"portrait": "res://assets/characters/elara_portrait.png",
		## Kullanıcı isteği (2026-09-22, new characters.zip): yeni 48x48 sprite sayfaları (idle/walk/run/eat/hurt/read/shrug/downed/death + kullanılmayan
		## strike/chop/pickup - tools/import_character_sheets.py). Gömülü gölge YOK: piksel elips ayak gölgesi (ground_shadow.gd).
		## Kullanıcı isteği (boyut): "%25 büyüt" - ölçek 1.78947 x 1.25 = 2.2368375 (EntityScale 0.95 ile oyun içi 2.125 px/sanat pikseli).
		## Ayaklar zemin çizgisinde (~32 px) kalsın diye offset.y = -1.8: (41 - 24 - 1.8) x 2.125 = 32.3 px.
		## Gölge yarıçapı da orantılı büyütüldü (x1.25); ground_shadow_y aynı kaldı (ayak çizgisi değişmedi).
		## "run" klibi hareket hızı bonusu %15'i aşınca oynar (talimat) - eski "always_walk" kaldırıldı.
		"scale": Vector2(2.2368375, 2.2368375),
		"offset": Vector2(0, -1.8),
		"ground_shadow": Vector2(17.5, 6.25),
		"ground_shadow_y": 32.5,
		"run_speed_ratio": 1.15,
	},
	9: {
		"name": "Korsan",
		## Kullanıcı isteği (beni oku.txt): Temel yetenek saatli bomba bırakır
		## (2 yük, yükü başına 20sn yenilenme - bkz. player.gd
		## _korsan_bomb_charges/KORSAN_BOMB_RECHARGE_TIME), ULTİ bırakılmış TÜM
		## bombaları patlatır (bkz. _skill_korsan_detonate_all/SKILL_TIMING[18]).
		"skill": 18,
		"skill_name": "Patlat",
		## Kullanıcı isteği (2026-09-22): "Korsanın Q'sunun bekleme süresini kaldır ve mana bedelini de
		## kaldır" - bkz. player.gd SKILL_TIMING[18] (cooldown 0.0) ve _activate_skill()'teki kalkan
		## bedeli muafiyet listesi (char_id != 18 eklendi).
		"skill_desc": "YETENEK: Bırakılmış tüm saatli bombaları patlatır. (Bekleme yok, kalkan harcamaz)",
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
		"skill3_desc": "ULTİ: Etrafındaki büyük bir alanı 8 saniye boyunca bombardımana tutar, her saniye saldırı gücünün %110'u kadar hasar verir. (40sn bekleme)",
		## DÜZELTME (kullanıcı bildirimi 2026-09-22: "Korsanın ultisinin skill ikonu yok") - skill3_icon hiç
		## eklenmemişti, HUD'da R slotu boş/placeholder kalıyordu (bkz. hud.gd "def.has(\"skill3_icon\")" kontrolü).
		## Kullanıcı isteği (2026-09-24): Korsan'ın 4 ikonu (Q/E/R/pasif) 48x48 piksel sanat kare ikon olarak yeniden
		## çizildi - bkz. tools/gen_elara_korsan_icons.py (eski halka-rozet üreticisi gen_korsan_bombardment_icon.py silindi).
		"skill3_icon": "res://assets/skills/korsan_bombardiman_icon.png",
		"passive": "Her öldürmede %10 ihtimalle 1 altın kazanırsın. Bu şans her level için +%1 artar (en fazla %100).",
		"passive_icon": "res://assets/skills/korsan_passive_icon.png",
		"frames": "res://assets/characters/korsan_frames.tres",
		"portrait": "res://assets/characters/korsan_portrait.png",
		## Kullanıcı isteği (2026-09-22, new characters.zip): yeni 48x48 sprite sayfaları (idle/walk/run/eat/hurt/read/shrug/downed/death + kullanılmayan
		## strike/chop/pickup - tools/import_character_sheets.py). Gömülü gölge YOK: piksel elips ayak gölgesi (ground_shadow.gd).
		## Kullanıcı isteği (boyut): "%25 büyüt" - ölçek 1.78947 x 1.25 = 2.2368375 (EntityScale 0.95 ile oyun içi 2.125 px/sanat pikseli).
		## Ayaklar zemin çizgisinde (~32 px) kalsın diye offset.y = -1.8: (41 - 24 - 1.8) x 2.125 = 32.3 px.
		## Gölge yarıçapı da orantılı büyütüldü (x1.25); ground_shadow_y aynı kaldı (ayak çizgisi değişmedi).
		## "run" klibi hareket hızı bonusu %15'i aşınca oynar (talimat) - eski "always_walk" kaldırıldı.
		"scale": Vector2(2.2368375, 2.2368375),
		"offset": Vector2(0, -1.8),
		"ground_shadow": Vector2(21.25, 6.875),
		"ground_shadow_y": 32.5,
		"run_speed_ratio": 1.15,
		## Yeni karakterlerin atlas'ında (beni oku.txt - sadece Idle/Hurt/
		## Spellcast/Walk) "run" animasyonu YOK - Büyücü Kız'da
		## olduğu gibi always_walk=true olmazsa, hız bir eşiği (bkz. player.gd
		## RUN_ANIM_SPEED_RATIO) aşınca _update_animation() var olmayan
		## "run_*" animasyonunu oynatmaya çalışır, AnimatedSprite2D'nin
		## gösterecek texture'ı kalmaz ve karakter TAMAMEN GÖRÜNMEZ olur
		## (hareket/saldırı/can vs. hepsi normal çalışmaya devam eder, sadece
		## sprite kaybolur) - kullanıcı bildirimi "son 3 karakter oyunun
		## içinde görünmüyor" bunun sonucuydu.
		## (eski "always_walk" kaldırıldı: yeni sayfalarda gerçek "run" klibi var)
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
		## DÜZELTME (kullanıcı isteği: "Melek'in can verme yeteneğinin (Q)
		## saldırı gücü oranını %30'a düşür") - bkz. player.gd
		## MELEK_Q_TICK_ATTACK_RATIO (Oakley'nin kendi %60'ı DEĞİŞMEDİ).
		"skill_desc": "YETENEK: Anında %15 can yeniler, sonraki 6sn boyunca saniyede %1 can + saldırı gücünün %30'u kadar can yeniler (kendine+müttefiğe). (20sn bekleme)",
		## DÜZELTME (kullanıcı isteği: gerçek sanat eseri ikonlar) - eskiden
		## Oakley ile AYNI geçici "oyku_ulti_can_basma_icon.png" dosyasını
		## paylaşıyordu, artık kendi özel ikonu var.
		"skill_icon": "res://assets/skills/melek_can_basma_icon.png",
		"skill2": 10,
		"skill2_name": "Kalkan Yenileme",
		## DÜZELTME (kullanıcı isteği: "Melekin kalkan yeteneğinin saldırı gücü
		## oranını %40'a düşür") - bkz. player.gd MELEK_E_TICK_ATTACK_RATIO
		## (Oakley'nin kendi %60'ı DEĞİŞMEDİ).
		"skill2_desc": "TEMEL: 6 saniye boyunca saniyede %1 kalkan + saldırı gücünün %40'ı kadar kalkan yeniler (kendine+müttefiğe). (15sn bekleme)",
		## DÜZELTME (kullanıcı isteği: gerçek sanat eseri ikonlar) - eskiden
		## Oakley'nin E/R'siyle AYNI geçici "oyku_kalkan_yenileme_icon.png"
		## dosyasını paylaşıyordu, artık kendi özel ikonu var.
		"skill2_icon": "res://assets/skills/melek_kalkan_yenileme_icon.png",
		## Kullanıcı isteği: Melek'in yeni 3. yeteneği (skill3, R tuşu) -
		## kendi etrafında VE can basma/kalkan yenileme ile bağ kurduğu
		## dostun etrafında yakındaki tüm yaratıkları korkutup kaçırır
		## (bkz. player.gd _skill_melek_fear, skill id 32).
		"skill3": 32,
		"skill3_name": "Kutsal Korku",
		"skill3_desc": "ULTİ: Kendi etrafındaki (ve bağ kurduğu dostun etrafındaki) tüm yaratıkları 4 saniye boyunca korkutup kaçırır. (45sn bekleme)",
		"skill3_icon": "res://assets/skills/melek_kutsal_korku_icon.png",
		## DÜZELTME (kullanıcı isteği: "Melek'in pasifi %0.5 can yerine saldırı
		## gücünün %5'si olarak güncelle. Yani 100 saldırı gücü varsa 5 can
		## yenileyecek yakınındaki herkes.") - bkz. player.gd _passive_melek/
		## MELEK_PASSIVE_ATTACK_POWER_PERCENT.
		## DÜZELTME (kullanıcı isteği: "Melek'in pasifinin can yenilenmesi
		## saldırı gücü oranını %5'ten %2'ye düşür").
		"passive": "Kendisinin ve yakındaki takım arkadaşlarının canını saniyede saldırı gücünün %2'si kadar yeniler.",
		## DÜZELTME (kullanıcı isteği: gerçek sanat eseri ikonlar) - eskiden
		## Oakley ile AYNI geçici "oyku_passive_icon.png" dosyasını
		## paylaşıyordu, artık kendi özel ikonu var.
		"passive_icon": "res://assets/skills/melek_passive_icon.png",
		"frames": "res://assets/characters/melek_frames.tres",
		"portrait": "res://assets/characters/melek_portrait.png",
		## Kullanıcı isteği (2026-09-22, new characters.zip): yeni 48x48 sprite sayfaları (idle/walk/run/eat/hurt/read/shrug/downed/death + kullanılmayan
		## strike/chop/pickup - tools/import_character_sheets.py). Gömülü gölge YOK: piksel elips ayak gölgesi (ground_shadow.gd).
		## Kullanıcı isteği (boyut): "%25 büyüt" - ölçek 1.78947 x 1.25 = 2.2368375 (EntityScale 0.95 ile oyun içi 2.125 px/sanat pikseli).
		## Ayaklar zemin çizgisinde (~32 px) kalsın diye offset.y = -1.8: (41 - 24 - 1.8) x 2.125 = 32.3 px.
		## Gölge yarıçapı da orantılı büyütüldü (x1.25); ground_shadow_y aynı kaldı (ayak çizgisi değişmedi).
		## "run" klibi hareket hızı bonusu %15'i aşınca oynar (talimat) - eski "always_walk" kaldırıldı.
		"scale": Vector2(2.2368375, 2.2368375),
		"offset": Vector2(0, -1.8),
		"ground_shadow": Vector2(20.0, 6.875),
		"ground_shadow_y": 32.5,
		"run_speed_ratio": 1.15,
		## Bkz. Korsan'daki "always_walk" notu - Melek'in atlas'ında da "run"
		## animasyonu yok, aynı görünmezlik hatasını önlemek için gerekli.
		## (eski "always_walk" kaldırıldı: yeni sayfalarda gerçek "run" klibi var)
	},
	11: {
		"name": "Necromancer",
		## Kullanıcı isteği (beni oku.txt): Pasif yakında ölen her düşmandan
		## ruh biriktirir (bkz. player.gd on_enemy_killed/_necro_gain_soul).
		## DÜZELTME (kullanıcı isteği: "Necromancer in Q skillini iskelet
		## çıkarma skilli ile değiştir E sini yarasa sürüsü çağırma ile
		## değiştir ve R sini golem çıkarma ile değiştir") - Talon/Assasin'in
		## Q/R takaslarıyla AYNI desen: id NUMARALARI (19=İskelet, 35=Yarasa,
		## 20=Golem) her zaman AYNI yeteneği temsil eder, sadece HANGİ tuşa
		## (skill/skill2/skill3) bağlı oldukları characters.gd'de VE
		## player.gd'de (bkz. _physics_process bypass dalları,
		## _activate_skill/_activate_skill3 match blokları/ön kontrolleri,
		## SKILL_TIMING/SKILL2_TIMING/SKILL3_TIMING, _necro_toggle_bats'teki
		## skill2_state, get_skill2_progress/get_skill3_progress'teki
		## char_id==11 özel dalı) üç yönlü rotasyonla değiştirildi: İskelet
		## Çağır artık Q'da (eskiden E, bekleme süresi yok, sadece ruh +
		## NECRO_SKELETON_COOLDOWN 1sn iç bekleme), Yarasa Sürüsü artık E'de
		## (eskiden R, basılıp kapatılabilen TOGGLE, bkz. player.gd
		## _necro_toggle_bats/_process_necro_bats), Golem Çağır artık R'de
		## (eskiden Q, 100 ruh + 10sn bekleme, standart skill3_state
		## makinesini kullanır). Ruh yoksa hiçbiri tetiklenmez. Ruh bedelleri
		## sonradan kullanıcı isteğiyle (İskelet 3->10, Golem 10->100) tekrar
		## güncellendi - bkz. player.gd NECRO_SKELETON_SOUL_COST/NECRO_GOLEM_
		## SOUL_COST. DÜZELTME (kullanıcı isteği: "necromancerın ultisi
		## hayalet yerine golem çağırsın") - Golem eskiden Hortlak (menzilli,
		## kaçan) çağırıyordu, artık necro'nun statlarının/canının %200'üne
		## sahip, kalkanlı, 6sn'de bir çevresini sersemleten bir Golem
		## çağırıyor (bkz. golem_pet.gd). DÜZELTME (kullanıcı bildirimi:
		## "golemi aşırı hızlı hareket ediyor... saldırı hızı azaltmasını %50
		## den %20 ye düşür") - buradaki yüzde golem_pet.gd'deki GOLEM_ATTACK_
		## SLOWDOWN_PERCENT ile AYNI kalmalı, %50 -> %20 olarak güncellendi.
		## GÜNCEL DİZİLİM (2026-09-24): Q = İskelet Çağır (19), E = Golem Çağır (20), R = Lanetli Kafatası (44);
		## Yarasa Sürüsü (35) ve necro_bat.gd/tscn tamamen silindi - yukarıdaki geçmiş notlar eski dizilimleri anlatır.
		"skill": 19,
		"skill_name": "İskelet Çağır",
		"skill_desc": "YETENEK: 5 Ruh tüketerek kendisi için savaşan bir iskelet yaratır (saldırı gücünün %50'si kadar vurur, saniyede ~1.3 kez saldırır, hareket hızının %90'ı, canının %100'ü, kalkansız, 60sn yaşar). Ruh yetmezse çağrılamaz. Toplamda (iskelet+golem) en fazla 20 yaratığa sahip olabilirsin. (1sn bekleme)",
		"skill_icon": "res://assets/skills/necromancer_iskelet_cagir_icon.png",
		## Kullanıcı isteği (2026-09-24): "iskelet Q golem E kafatası da R olmalı yarasayı ... yok et" - Golem Çağır
		## (id 20) R'den E'ye taşındı (standart skill2 makinesi, E kalkan tarifesi), Yarasa Sürüsü (id 35) tamamen silindi.
		"skill2": 20,
		"skill2_name": "Golem Çağır",
		"skill2_desc": "TEMEL: 25 Ruh tüketerek canının %200'üne sahip (hareket hızı %70, saldırı gücü %50 oranında), kalkanlı bir Golem çağırır (en fazla 2 tane, %20 daha yavaş saldırır, 6sn'de bir çevresindeki yaratıkları 1sn sersemletir, 120sn yaşar). Ruh yetmezse çağrılamaz. (10sn bekleme)",
		"skill2_icon": "res://assets/skills/necromancer_hortlak_cagir_icon.png",
		## Kullanıcı isteği (2026-09-24): Necromancer'ın ULTİ'si artık Lanetli Kafatası (skill3 id 44, R tuşu) - Golem Çağır'ın
		## (id 20) yerine. Standart skill3_state makinesi (10sn aktif + 60sn bekleme, bkz. player.gd SKILL3_TIMING[44] /
		## _skill_necro_skull, mantık scripts/necro_skull.gd). Ruh tüketmez (istekte ruh bedeli yok, bekleme süresi var).
		"skill3": 44,
		"skill3_name": "Lanetli Kafatası",
		"skill3_desc": "ULTİ: Düşmanlara dev bir lanetli kafatası gönderir. Kafatası 10sn boyunca kalabalıklara ve bosslara öncelik vererek düşmanlara çarpar; her çarpmada isabet alanındaki düşmanlara saldırı gücünün %110'u kadar hasar verir ve onları 3sn korkutur (korkan düşmanlar rastgele yönlerde yürür ve hasar veremez, bosslar korkmaz). (60sn bekleme)",
		"skill3_icon": "res://assets/skills/necromancer_lanetli_kafatasi_icon.png",
		"passive": "Etrafta ölen her düşman 1 ruh biriktirir (bosslar 5 ruh). Biriken ruh sayısı pasif ikonunun üstünde görünür.",
		"passive_icon": "res://assets/skills/necromancer_passive_icon.png",
		"frames": "res://assets/characters/necromancer_frames.tres",
		"portrait": "res://assets/characters/necromancer_portrait.png",
		## Kullanıcı isteği (2026-09-23, new characters.zip #2): yeni 48x48 sprite sayfaları -
		## bkz. Matthew DEFS'indeki AYNI notun üstündeki gerekçe (ölçüm: OLCU idle_down
		## govde 30x36, ayak satiri 40). Eski "always_walk" KALDIRILDI: yeni sayfalarda
		## gerçek "run" klibi var, artık %15 hız bonusunda run'a geçebilir.
		"scale": Vector2(2.2368375, 2.2368375),
		"offset": Vector2(0, -1.8),
		"ground_shadow": Vector2(20.0, 6.875),
		"ground_shadow_y": 32.5,
		"run_speed_ratio": 1.15,
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
		"skill_desc": "YETENEK (kalkan harcamaz): Bulunduğun konuma bir totem diker. Totem 30sn boyunca her saniye etrafındaki müttefiklere (ve sana) kendi kalkanının %0.5'i + saldırı gücünün %12'si kadar kalkan yeniler. (60sn bekleme)",
		"skill_icon": "res://assets/skills/shaman_kalkan_totemi_icon.png",
		"skill2": 27,
		"skill2_name": "Saldırı Totemi",
		"skill2_desc": "TEMEL: Bulunduğun konuma bir totem diker. Totem 30sn boyunca düzenli olarak en yakın düşmana ateş eder, saldırı gücü ve saldırı hızı senin statlarının %150'si kadardır. (60sn bekleme)",
		"skill2_icon": "res://assets/skills/shaman_saldiri_totemi_icon.png",
		"skill3": 28,
		"skill3_name": "Alan Saldırı Totemi",
		"skill3_desc": "ULTİ: Bulunduğun konuma bir totem diker. Totem 30sn boyunca etrafına bir alan açar - alana giren düşmanlar %20 + saldırı gücünün %20'si kadar (en fazla %80) yavaşlar, alanda duran düşmanlar her saniye saldırı gücünün %20'si kadar hasar alır. (60sn bekleme)",
		"skill3_icon": "res://assets/skills/shaman_alan_totemi_icon.png",
		"passive": "Totem Auraları: totemlerine yakın müttefiklerin düşmanlara verdiği hasar, düşmana 3sn boyunca her saniye o müttefiğin saldırı gücünün %10'u kadar yakma hasarı bırakır.",
		"passive_icon": "res://assets/skills/shaman_passive_icon.png",
		"frames": "res://assets/characters/shaman_frames.tres",
		"portrait": "res://assets/characters/shaman_portrait.png",
		## Kullanıcı isteği (2026-09-23, new characters.zip #2): eski LPC generator sayfaları
		## (walk/idle/hurt/spellcast, tools/gen_shaman_assets.py) yerini yeni 48x48 sprite
		## sayfalarına bıraktı - bkz. Matthew DEFS'indeki AYNI notun üstündeki gerekçe
		## (ölçüm: OLCU idle_down govde 24x37, ayak satiri 40). Eski "always_walk" KALDIRILDI:
		## yeni sayfalarda gerçek "run" klibi var, artık %15 hız bonusunda run'a geçebilir.
		"scale": Vector2(2.2368375, 2.2368375),
		"offset": Vector2(0, -1.8),
		"ground_shadow": Vector2(18.0, 6.875),
		"ground_shadow_y": 32.5,
		"run_speed_ratio": 1.15,
	},
	13: {
		"name": "Vampir Çocuk",
		## Kullanıcı isteği: yeni karakter Vampir Çocuk - yetenekleri kalkan YERİNE CAN harcar
		## (Q ve E maksimum canın %4'ü, R aktifken her saniye maksimum canın %3'ü, bkz.
		## player.gd VAMPIR_*). Skill id'leri: Q=40 (Kan Emme, SKILL_TIMING[40]), E=41 (Yarasa
		## Formu, SKILL2_TIMING[41]), R=42 (Kan Yarasaları, SKILL3_TIMING[42], basılıp
		## kapatılan toggle).
		## Görsel: assets/characters/vampir/ (tools/gen_vampir_assets.py + gen_vampir_frames.py).
		"skill": 40,
		"skill_name": "Kan Emme",
		"skill_desc": "YETENEK (maksimum canının %4'ünü harcar): Yakınındaki en yakın 3 düşmanın kanını emip kendine çeker, her birine saldırı gücünün %130'u kadar hasar verir ve maksimum canını oyun boyunca kalıcı olarak 1 arttırır (karakterin üstünde +1 Maks. Can yazar). (6sn bekleme)",
		"skill_icon": "res://assets/skills/vampir_kan_emme_icon.png",
		"skill2": 41,
		"skill2_name": "Yarasa Formu",
		"skill2_desc": "TEMEL (maksimum canının %4'ünü harcar): 5sn boyunca büyük bir yarasaya dönüşür - %60 hareket hızı kazanır, aldığı hasar %80 azalır, yaratıkların ve duvarların içinden geçebilir ve temas ettiği her yaratığa saldırı gücünün %80'i kadar hasar verir. Bu esnada silahlarını kullanamaz: silahlar karakterin içine çekilip kaybolur, form bitince geri çıkar. E'ye tekrar basarak süre dolmadan normal forma dönebilirsin (bekleme o an başlar). (22sn bekleme)",
		"skill2_icon": "res://assets/skills/vampir_yarasa_formu_icon.png",
		"skill3": 42,
		"skill3_name": "Kan Yarasaları",
		"skill3_desc": "ULTİ (BASILIP KAPATILABİLİR): Açıkken her saniye maksimum canının %5'ini harcar. Yakınındaki yaratıklara 6 küçük yarasa gönderir; yarasalar vurup saldırı gücünün %60'ı kadar hasar verir ve sana geri döner (hızları saldırı hızınla artar). Yarasalar her döndüğünde saldırı gücünün %5'i kadar can yenilenir.",
		"skill3_icon": "res://assets/skills/vampir_kan_yarasalari_icon.png",
		"passive": "Kan Emme: %1 can emme kazanır (verdiği hasarın %1'i kadar can yenilenir) ve her 1 saldırı gücü için 1 maksimum can kazanır.",
		"passive_icon": "res://assets/skills/vampir_passive_icon.png",
		"frames": "res://assets/characters/vampir_frames.tres",
		"portrait": "res://assets/characters/vampir_portrait.png",
		## Yeni karakter tasarımı (kullanıcı sprite sayfaları): 48x48 kareler (eski LPC seti 64x64'tü) ve
		## "run" DAHİL tüm klipler var - bu yüzden artık "always_walk" YOK, hız bonusu eşiği aşınca gerçek
		## koşma klibi oynar (bkz. run_speed_ratio). DEFAULT_ANIM_OFFSET (0,-5) 64 px'lik karelere göre
		## ayarlıydı; 48 px'lik karede ayaklar 41. satırda olduğu için karakter aynı zemin çizgisine
		## (ayaklar orijinin ~33 px altında) otursun diye offset.y = 10 (41 - 24 + 10 = 27 texel x 1.212 ~ 33 px).
		## Kullanıcı isteği (2026-09-22): "Vampirin boyutunu %30 büyüt ve altına gölge ekle", sonra "%10 daha", sonra "%15 daha" - ölçek varsayılanın
		## (1.27575) x 1.3 x 1.1 x 1.15 = x1.6445 = 2.09797 (oyun içi 0.95 küçültmesiyle 1.993 px/sanat pikseli). Ayaklar aynı zemin çizgisinde (~33 px)
		## kalsın diye offset.y = 0: (41 - 24 + 0) x 1.993 = 33.9 px (eskiden (41-24+10) x 1.212 = 32.7). Yarasa Formu kareleri de aynı klip
		## setinde olduğu için onlar da büyür. (vampir_fx.gd FX'leri kendi TEXEL'ini korur.)
		## Yarasa Formu kareleri (96x112) eski offset'e göre çizilmişti, bkz. tools/gen_vampir_assets.py BAT_CANVAS.
		"scale": Vector2(2.09797, 2.09797),
		"offset": Vector2(0, 0),
		## Kullanıcı isteği (boyut): "Elara, büyücü kız, vampir çocuk, talon, melek ve korsan ... boyutunu %25 arttır" isteği
		## Vampir için GERİ ALINDI (kullanıcı: "Vampir çocuğa yaptığın büyüklük değişimini geri al, diğerlerine dokunma") -
		## Vampir eski ölçeğinde (2.09797; ayaklar ~33.9 px) ve eski gölge yarıçapında kalıyor.
		## Yeni sprite sayfalarında gömülü gölge YOK (diğer karakterlerin karelerinde var) - kullanıcı isteğiyle ayrı piksel elips gölge
		## (bkz. scripts/ground_shadow.gd): yarıçap (px) ve ayak çizgisine göre y konumu. Hem yerel (player.gd) hem uzak (remote_player.gd)
		## oyuncu bunu ground_shadow.gd apply_to() ile aynı şekilde uygular.
		"ground_shadow": Vector2(19.0, 7.0),
		"ground_shadow_y": 33.4,
		## Kullanıcı isteği (animasyon talimatı): "run animasyonları hareket hızı bonusu %20'yi geçince
		## oynatılmalı (skiller, statlar vb.)" - genel eşik (player.gd RUN_ANIM_SPEED_RATIO) 1.25, bu karakter için 1.2.
		"run_speed_ratio": 1.15,
	},
	## Kullanıcı isteği (2026-09-25): yeni karakter "Suriyeli Hadime" (hadime.zip - 48x48 sayfalar + ayrı gelen read.png).
	## Yetenek id'leri: Q=46 (Lanet Kitabı, aç/kapa kanal - standart skill_state makinesini bypass eder, bkz. player.gd
	## _process_hadime_q), E=47 (Kara Delik, standart skill2), R=48 (Karabasan, standart skill3). Sabitler/formüller TEK yerde:
	## scripts/hadime_math.gd (uzak kopyalar da oradan okur). Pasif (hayalet formu) player.gd _hadime_rise_ghost/_process_downed.
	## Adlar kullanıcı vermediği için seçildi (Lanet Kitabı / Karabasan / Ruh Göçü; E'yi kullanıcı "Kara Delik" olarak
	## değiştirdi) - değiştirmek sadece metin.
	14: {
		"name": "Suriyeli Hadime",
		"skill": 46,
		"skill_name": "Lanet Kitabı",
		"skill_desc": "YETENEK (AÇ/KAPA): Kitabını okuyarak odaklanır; hafifçe havaya süzülür, birimlerin içinden geçebilir ve %30 yavaş hareket eder. Saniyede bir kitaptan yukarı fırlayan bir lanet etraftaki yaratıklara sırayla düşer ve saldırı gücünün %110'u kadar hasar verir. Açık kaldığı sürece her saniye temel yetenek kalkan bedelinin yarısı kadar kalkan harcar. Tekrar basınca (ya da kalkan yetmeyince) kapanır ve 8sn bekleme süresine girer.",
		"skill_icon": "res://assets/skills/hadime_lanet_kitabi_icon.png",
		"skill2": 47,
		## Kullanıcı isteği (2026-09-25, ikinci tur): "hadimenin E sini kara delik yeteneğiyle değiştiriyoruz" - eski Kara Büyü
		## tamamen kaldırıldı, id 47 aynı kaldı (bkz. player.gd _skill_hadime_black_hole, scripts/hadime_black_hole.gd).
		"skill2_name": "Kara Delik",
		"skill2_desc": "TEMEL: Bulunduğu konuma 5 saniye süren bir kara delik bırakır. Kara delik yakınındaki yaratıkları hafifçe içine doğru çeker, her saniye saldırı gücünün %80'i kadar hasar verir ve verdiği hasarın %20'si kadar kalkanlarını emerek Hadime'nin kalkanını yeniler (bosslar çekilmez). Lanet Kitabı basılıyken de kullanılabilir. (18sn bekleme)",
		"skill2_icon": "res://assets/skills/hadime_kara_delik_icon.png",
		"skill3": 48,
		"skill3_name": "Karabasan",
		"skill3_desc": "ULTİ: 15 saniye boyunca korkutucu karanlık Karabasan formuna bürünür. Yakınına yaklaşan tüm yaratıklar 1 saniyeliğine korkar, yakınındaki yaratıklar her saniye saldırı gücünün %80'i kadar hasar alır (bosslar korkmaz). (100sn bekleme)",
		"skill3_icon": "res://assets/skills/hadime_karabasan_icon.png",
		"passive": "Ruh Göçü: Yere düştüğünde 2 saniye sonra ruhu bedeninden ayrılır ve yarı saydam bir hayalet olarak ayağa kalkar; bedeni yerde kalır. Hayaletken yaratıklar onu görmezden gelir, sadece yetenekleriyle %80 daha az hasar vererek savaşabilir; hiçbir şey toplayamaz, kimseyi diriltemez, silah kullanamaz, dükkan ve görevlerle etkileşemez. Arkadaşları bedenini diriltince hayalet bedenine döner (tek oyunculuda 20 saniye sonra kendiliğinden).",
		"passive_icon": "res://assets/skills/hadime_passive_icon.png",
		"frames": "res://assets/characters/hadime_frames.tres",
		"portrait": "res://assets/characters/hadime_portrait.png",
		## tools/import_character_sheets.py (anahtar "hadime") - aynı üretici kanvası (OLCU: gövde 16x33, ayak satırı 40),
		## Şovalye Adam'la birebir aynı gövde ölçüsü: aynı ölçek/offset/gölge. SpriteFrames'te ayrıca ölümün tersi
		## "ghostrise_<yön>" klibi var (hayalet kalkışı - bkz. importer REVERSED_CLIPS).
		"scale": Vector2(2.2368375, 2.2368375),
		"offset": Vector2(0, -1.8),
		"ground_shadow": Vector2(17.5, 6.25),
		"ground_shadow_y": 32.5,
		"run_speed_ratio": 1.15,
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


## Kullanıcı isteği (2026-09-24): "karakterlerin q yeteneği 1. levelde e yeteneği 5. levelde R yetenekleri ise 10.
## levelde açılacak ... (büyücü kızın Q ve E yeteneği 1 levelde açık olmalı R ise 10 levelde açılacak)". Yetenek
## yuvası -> açıldığı TAKIM seviyesi (player.gd `level`, GameManager.team_level ile senkron). Anahtarlar input
## action adlarıyla aynı: "skill" = Q, "skill2" = E, "skill3" = R. Karaktere özel istisna DEFS'te
## "<yuva>_unlock_level" alanıyla (bkz. Büyücü Kız "skill2_unlock_level"). Tek kaynak: player.gd kilidi (girişi
## engeller) ve hud.gd kilit görseli (ikon üstünde seviye numarası) ikisi de buradan okur.
const SKILL_UNLOCK_LEVELS := {"skill": 1, "skill2": 5, "skill3": 10}


static func skill_unlock_level(char_id: int, slot: String) -> int:
	return int(get_def(char_id).get(slot + "_unlock_level", SKILL_UNLOCK_LEVELS.get(slot, 1)))
