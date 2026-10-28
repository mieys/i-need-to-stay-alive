extends RefCounted

## BALANS TELEMETRİSİ (kullanıcı isteği 2026-10-11: "neyin dengesiz olduğunu anlayabileceğimiz bir sistem"). Her koşu bitince
## user://balans/kosular.jsonl dosyasına TEK SATIR JSON eklenir (Windows: %APPDATA%\Godot\app_userdata\Temiz Sürüm\balans\).
## Çok oyunculuda istemciler kendi kaydını host'a da yollar (NetworkManager.submit_balance_record) - host kendi dosyasına
## "via":"host" ile ekler. Aynı koşu iki dosyada olabilir: raporda run_id ile tekilleştirilir (tools/balans_rapor.ps1).
## Rapor: tools/balans_rapor.ps1 -> docs/balans/rapor.md. Format ayrıntısı: docs/notlar/madde_71-80.md (madde 75).
##
## BALANCE_REV: denge sabitlerini (hasar, can, bekleme, yaratık gücü...) değiştirdiğinde BİR ARTIR - rapor yalnız en son
## revizyonu baz alır (eski denge verisi yeni dengeyi yanıltmasın). Artırmayı unutursan eski+yeni veri karışır.
##
## HASAR KAYNAĞI: enemy.take_damage() hasarın kaynağını bilmez. Çağıran taraf hemen önce tag()/tag_weapon() ile etiketler, take_damage
## etiketi okuyup SİLER (take_src). Etiketsiz hasar "diger" (yetenekler, evrimler, efsunlar...) olur - rapor bu payı gösterir.
## Etiketlenen yerler: weapon.gd, projectile.gd, boomerang_projectile.gd, firework_projectile.gd (silahlar -> "w:<shop_key>"),
## enemy.gd DOT tiki ("dot"). Yetenek (Q/E/R) kırılımı için player.gd'deki take_damage çağrılarına tag(&"s:q") eklenebilir.

const CharactersScript: GDScript = preload("res://scripts/characters.gd")
const BALANCE_REV := 104 ## 104: YARATIK ALTINI YİNE YERDE (madde 384): ölen yaratığın altını (miktar hesabı aynı, gelir değişmez) karaktere otomatik gitmez, rastgele yere düşer ve toplama mesafesiyle XP gibi toplanır (toplayana +N yazısı + ses); toplayan alır, asist/takım payı bölüşümü pasif (KillGold.GROUND_DROPS); 1. seviye slime (sıçrama) ve 1. seviye iskelet (kemik atışı) yeteneksiz (2026-10-24). 103: İKİ YENİ LEVEL KARTI (madde 380): Kalkan Yenilenmesi (kademe 1-4: +0,8/1,2/1,6/2,0 mana kalkanı/sn, bedel -%1,5 hız) + İyileştirme Gücü (+%2/3/4/5 sağlanan can/kalkan, bedel -%2 saldırı hızı); havuz 13 -> 15 düz kart (2026-10-24). 102: LEVEL KARTLARINDA ÖDÜL/CEZA (madde 379): 13 düz stat kartı kazancı aynı + başka statta bedel (Can -%1,5 hız, Saldırı Gücü -%2 saldırı hızı, Saldırı Hızı -6 can, Hız -%2 kalkan...), silah türü kartları da bedelli (Yakın Dövüş -%5 hız, Nişancılık -12 can); bedel statı zeminde olan oyuncuya o kart çıkmaz (2026-10-24). 101: ZİNDANLAR (madde 373): üç zindan (Kemik Mahzeni / Et Kuyusu / Boynuzlu Kapı) + kademe +1..+2 sakinler, avcı, tuzaklar (oyuncuya azami canın %14'ü), kişisel zindan kaynakları (toplama 1-2) + SUNAK alımları (Ruh Akışı / Kemik Zırhı / Kan İksiri / Kızıl Tentür / Kristal Parçacık / Işık Hızı kartları, her alımda +2 bedel) + zindan sandıkları (kalp odası elit) (2026-10-23). 100: TAKAS KARTLARI: Kan Anlaşması %2/2,5/3/4 -> %6/12/18/24, Demir Kabuk 40/52/64/76 -> 40/70/100/140 (kazanç düz kartın kademe tablosunun x3 / x2'si; madde 369, 2026-10-23). 99: LEVEL KARTLARI: her turda 1 ÖZEL kart (6 takas: Cam Top/Demir Kabuk/Rüzgâr Ayakları/Çılgın Tetik/Kan Anlaşması/Dev Kalkan + 2 silah türü: Yakın Dövüş Ustalığı/Nişancılık %15) + YARATIKLAR: iskelet kemik atar, zombi atılır, slime sıçrar, Kademe 1 rosterine iskelet eklendi (madde 367/368, 2026-10-23). 98: SHAMAN Q (Saldırı Totemi): bekleme 45 -> 20 sn (yük başına) + totemin etrafındaki alan hasarı (saniyede %20 SG) KALDIRILDI - bug, alan hasarı yalnız Kalkan Totemi'nde (2026-10-21) ## 97: MATTHEW R YILDIRIM KALKANI PATLAMASI (madde 356): sabit 60 hasar -> saldırı gücünün %400'ü + kalkanın emdiği hasarın %50'si (emilen en çok kapasite kadar), artık süre dolunca da patlar (eskiden yalnız hasarla kırılınca) (2026-10-21) ## 96: OAKLEY YETENEK EVRİMLERİ (madde 348; kartlar önceden yoktu): Q Arı Sürüsü (bekleme -%25, sokma aralığı 1 -> 0,7 sn, halka x1,3 + 3 sn, zehirle ölende %10 çiçek (en çok 3), final Salgın Zehir 150 px), E Sarmaşıklar (bekleme -%25, hasar %60 -> %90, 3 -> 5 sarmaşık, sabitleme 4 -> 6 sn + boss yavaşlatma %30 -> %50, final Kök Hapishanesi +%25 hasar), R Hayat Ağacı (12 -> 16 sn + alan x1,25, meyve x1,4 + 6 çiçek, final Kadim Diriliş: gölgede yere düşen dost %50 canla kalkar) (2026-10-21) ## 95: SİLAH ÜSTÜ GÜÇ SINIRLARI (madde 346; analiz: 49 dk koşuda Matthew 44.681 altın / 67 eşya, Elara %498 saldırı hızı): AYNI PARÇADAN en fazla 6 kopya (satıcı + sandık; fiyat tavanı x2 yetmedi); CANAVARLAŞTIRMA ÖZÜTÜ %2 mevcut can hasarının 40 tavanı bosslarla birlikte ELİTLERE de; ZAMANBÜKENİN ELDİVENİ ve Elara AKIŞTA KAL bekleme azaltması vuruş başına değil en çok 0,25 sn'de bir (saniyede 4); SALDIRI HIZI TAVANI %600 -> %450 (aşan kısım 0,5 saldırı gücü/% aynı); kalkan delme: isabet başına toplam tavan zaten %40 (weapon.gd SHIELD_PEN_CAP), stat panelleri artık ham %96 yerine etkin değeri gösterir (2026-10-20) ## 94: SİLAH DENGE TURU (madde 345; kayıtlar + model: Topuz/Pençe kalabalıkta ~7-8 saldırı gücü/sn, Tüftüf/Yin Yang/Yay ~0,6-0,8): TOPUZ alan payı %50 -> %35; PENÇE alandaki diğer yaratıkların kanaması %30 -> %20/sn (ana hedef %30); ARBALET sersemlik kilidi kırıcı (aynı yaratık sersemlik bitince sersemlik süresi kadar yeniden sersemletilemez, final en çok %50 sersem); TÜFTÜF oran %100 -> %160 + menzil 150 -> 180; YAY oran %64 -> %85; BIÇAK %123 -> %154; KALKAN ve YIN YANG %100 -> %125 (2026-10-20) ## 93: YİN YANG KİTABI yavaşlatması GERİ ALINDI (kullanıcı: "çok güçsüz oldu") - aralık 2,29 -> 1,71 sn (fire_rate 1,6 -> 1,2), saldırı hızı bonusları tam işler; hedef yokken de aynı aralıkla yalnız ak küre kalkan taşır (YinYangBook.idle_shot) (2026-10-20, madde 334); 92: KALKAN yavaşlatması GERİ ALINDI - aralık tekrar 1,59 sn (fire_rate 1,6 -> 1,1111), saldırı hızı bonusları kalkana yine TAM işler; hasar %100 KALDI (kullanıcı onayı; saniyede hasar ilk sürümün x1,25'i), Ağır Kenar %130, Yıkılmaz Duvar %150 (2026-10-20, madde 342); 91: KALKAN yavaşladı - aralık 1,59 -> 2,29 sn (fire_rate 1,1111 -> 1,6), saldırı hızı bonusları kalkana YARI oranda işler (demirci kademesi tam; weapon.gd KALKAN_HASTE_EFFECT 0,5), hasar %80 -> %100 (saniyede ~%13 az), Siper Ağır Kenar %100 -> %130, Yıkılmaz Duvar %150 (2026-10-20, madde 340); 90: YENİ SİLAH YİN YANG KİTABI (menzilli tek hedef %100 saldırı gücü, aralık 1,6 / 0,7 = 2,3 sn + saldırı hızı bonusları yarı oranda (Kalkan kuralı), menzil 170; isabet başına %10 saldırı gücü mana kalkanı MENZİLSİZ en boş oyuncuya) + özellik Denge (Yin/Yang, Kara Mühür, Tai Chi Mührü) (2026-10-20, madde 334); 89: YENİ SİLAH KALKAN (yakın dövüş, menzil 110, geniş darbe: önündeki herkese %80 saldırı gücü + 45 px itme, bosslar itilmez) + özellik Siper (darbe başına vurulan düşman başına 1 sabit mana kalkanı, en fazla 3; elit/boss 2 sayılır; yalnız sahibine; 4 geliştirme + Yıkılmaz Duvar finali) (2026-10-20, madde 338); 88: AEGİS'İN SONSUZ MUHAFIZI kalkan yenilenmesi saniyede azami kalkanın %0,5'i -> %1'i (`ITEM_AEGIS_PER_SEC` 0.005 -> 0.01, 2026-10-20); 87: CADI Q DUMANI her yönde DİKEY bulut (24x22; yan yürüyüşte eskiden yatay 32x17, alan aynı) + hızlanınca 26 birimde bir bulut (boşluk kalmaz; en sık 0,1 sn) (2026-10-20); 86: GÖKKUŞAĞI ASASI ışını ~2 kat geniş (yarı genişlik 3 -> 6, final 3,8 -> 8; final delen ışının isabet yarıçapı 14 -> 20 px, hattaki daha fazla yaratığı vurur; temelde tek hedef, sayı aynı) (2026-10-20); 85: CADI R yeni iksir KALKAN İKSİRİ (6. iksir, rastgele havuz 5 -> 6; üstündeki müttefiklere saniyede saldırı gücünün %25'i kadar mana kalkanı) (2026-10-20); 84: GÜVENLİ ALANDA PASİFLER + EVCİL HAYVANLAR da durur (Melek/Oakley/Matthew/Talon pasifi, öldürme pasifleri, Kirpi/Kelebek/Peri/Papağan/köpek, totem, Necro kafatası; demirci dahil) (2026-10-20); 83: KORUMA ÜCRETİ KALDIRILDI + GÜVENLİ ALANDA ZAMAN DONAR (satıcı koruma bölgesi / demirci: can-kalkan yenilenmez, Q/E/R/ruhani/eşya beklemesi ilerlemez) + ÖLÜYKEN yetenek beklemeleri dolar; 82: EV ONARIMI yarıya - kimse içeride değilken dışarıda savaşılırken sn'de 0,5 -> 0,25 (sıfırdan tam 20 dk, yıkıktan açılış 8 dk); BABAANNE ÇORBASI artık yalnız girişte değil, içerideki canı %90 altı + beklemesi dolmuş oyuncuya 2 sn'de bir bakılarak getirilir (vazgeçme 9 -> 16 sn, 15 sn sonra yeniden dener; miktar/bekleme aynı) (2026-10-19). 80: PENÇE + GÖKKUŞAĞI ASASI buff: Pençe doğrudan hasar %145 -> %189 SG, Kanlı Pençe kanaması %20 -> %30 SG/sn; Gökkuşağı Asası saniyede %150 -> %220 SG, menzil 168 -> 185 (2026-10-19). 79: Agaci Koru agaci daha seri atar - kristal mermisi 0,8 -> 0,45 sn, sihirli atis 3 -> 1,8 sn (sarj 0,45 -> 0,35), vurus basi hasar ayni (2026-10-19). 78: KORUMA ÜCRETİ (madde 314): seyyar satıcıda ve demircide 10 sn'den uzun kalan oyuncudan her 5 sn'de bir mevcut altının %2'si (en az 1) kesilir, ödeyemeyen (altın 0) dükkandan atılır ve altını olana dek giremez; yeni altın gideri (2026-10-19). 77: EV KUŞATMASI + AÇILIŞ (madde 313): oyun evde 9 sn huzur + 30 sn geri sayımla başlar (yaratık doğuşu ve oyun saati geri sayım bitince); ev canı 300, evde 10 sn'den uzun kalınınca sn'de 1 azalır (5 dk), kimse içeride değilken dışarıda savaşılırken sn'de 0,5 onarılır, 0'da yıkılır (herkes dışarı atılır, %40 onarılınca açılır); babaanne dışarıda savaşamaz, can 100, yaratıklar ona saldırır, ölürse kalıcı (çorba biter). 76: BABAANNE ÇORBASI (madde 310): cozy evdeki babaanne içeri giren oyuncuya, canı %90'ın altındaysa yanına gidip bir kâse çorba verir = azami canın %30'u (heal kaynağı "babaanne", güçlendirmesiz), oyuncu başına 4 dk'da bir; yeni can kaynağı (2026-10-19). 75: TAKIM PAYI (madde 308): her yaratık öldürmesinin altınının %20'si ölen yaratığın 700 px yakınındaki canlı (düşmemiş) oyunculara EŞİT bölünür (Assist.team_share, öldürenin eşit payı onda kalır, kalan %80 hasar/asist kuralıyla; 1 altına yetmeyen kesir birikir, başkalarına en çok toplamın yarısı); altın yazısı "TAKIM +N", balans kaydı gold_assist["team"]. 74: ALTIN ASİST + PARÇA FİYATI + SİSMİK DALGA (2026-10-19 maç analizi: takım hasarının %67'si / altının %71'i tek oyuncuda): asist altın eşiği 4 -> 2, öldüren alt sınırı %50 -> %40, 1 altına yetmeyen asist payı birikir (Assist.carry); aynı 1. kademe parçanın her sahip olunan kopyası fiyatı +%10 (en çok x2, Items.repeat_mult); Sismik Dalga yalnız merkeze en yakın 8 düşmana tam hasar, sonrakiler %35. 73: YENİ SİLAH MIZRAK (yakın dövüş, menzil 150, hattaki herkese %120 saldırı gücü - hedefin 80 px gerisine kadar) + özellik Cirit (her 4. saplamada 280 px fırlatma, yolundakilere %90; 4 geliştirme + Şişleyen Cirit finali) (2026-10-19, madde 305). ## 72: Kanlı Pençe can emmesi %3 -> %1 (Kan Emici %5 -> %2), final %1 -> %0,5 azami can, saniyelik sınırlar YOK (eski "saniyede bir kez" de kalktı; kurban başına tek ödül) + kanama tikleri genel can çalma zarı atmaz; Pençe hızlı vuruşta ana pozlar en az ~2 kare (görsel, denge dışı) (2026-10-19, madde 304). ## 71: yeni silah GÖKKUŞAĞI ASASI (saniyede %150 SG tek hedef ışın, 0,5 sn tik; özellik Göz Kamaştıran Işık: 3 sn tutunca 1,5 sn sersemletme, boss/elit 3 sn %20 az hasar; final delen ışın) (2026-10-19, madde 306). ## 70: demirci silah geliştirmesi final (kademe 5) sonrası SINIRSIZ güçlendirme: her biri +%10 taban hasar + kademe V saldırı hızının +%5'i, özel geliştirme yok; 150 + 50 x alınan altın + 3 parçacık (2026-10-19, madde 297). ## 69: Tabanca + Tüfek ŞARJÖRLÜ (6 / 5 mermi): şarjör içi atış aralığı x0,8, doldurma (N - (N-1)*0,8) x atış aralığı - dakikadaki atış sayısı aynı, ritim patlamalı; ek atışlar mermi yemez (2026-10-19, madde 296). ## 68: Kanlı Pençe can emme %6 -> %3 sadece ana hedef, Kan Emici +%2 aynı, final %3 -> %1 azami can (sn'de 1) + hız %30 -> %20; kanama ve taban hasar aynı (2026-10-19, madde 293). ## 67: Minotaur can/kalkan -%30 + savurmada 1 sn sersemlik, Banshee boy x0,7 hasar +%40 (atılış 336, çığlık 364), ek oyuncu başına yaratık +50, ulti dışı yetenek itmeleri bossu itmez (2026-10-19, madde 293). ## 66: Melek Q/E kendine giden pay: bir dosta gerçekten can/kalkan gidiyorsa %50, kimseye gitmiyorsa (yalnız kendine basıyorsa) %100 (eskiden hep %50) (2026-10-19). 65: Balkabağı Kafa minyonları (balkabak + yarasa) can ve kalkan x2 (kabak %70 -> %140, yarasa %30 -> %60) + HASAR x2 (balkabağı patlaması 40 -> 80, yarasa ısırığı çarpanı 2 -> 4; hız/ödül/kanama aynı) (2026-10-19). 63: Ruhların Maskesi orb pasifi: orb başına %1 geri döndü (0,5 -> 1) ama her orbun bonusu KENDİ 4 sn'sinde söner, yeni orb eskisini YENİLEMEZ (eskiden her orb tüm yığının süresini baştan başlatıyordu: ortalama bonus ~3,9 x orb/sn %, şimdi ~2 x orb/sn %) (2026-10-18). 62: Ruhların Maskesi (orb başına hız) EPİKTEN EFSANEVİYE: orb başına hız %1 -> %0,5, +%20 EXP (eskiden %10) ve +%5 hareket hızı, tarif = eski + Rüzgar Eldiveni + 2. Tecrübe Kitabı (1790); Ninja El Kitabı / Son Şans / Bilgenin Pusulası tarifleri açık parçalara çevrildi (fiyatlar aynı) (2026-10-18). 61: SONSUZ MOD baskısı + XP kaçağı (madde 269): sonsuzda kat başına bileşik yaratık can +%8 / hasar +%5, yaratık tavanı kat başına +3 (en çok +60), 3 katta bir yeni 6 bossluk dalga (dalga başına boss can/kalkan +%50, hasar +%25); seviye 60'tan sonra XP gereksinimi dikleşti (artış seviye başına +3 daha), toplam XP bonusu en çok +%100 (2026-10-18). 60: Oakley R Koruyucu Büyü -> HAYAT AĞACI (12 sn ağaç: gölgesindekilere sn'de %15 SG + %1 azami can, %8 SG mana kalkanı; 2 sn'de bir en yakın 3 yaratığa kök %40 SG + 4 sn sabitleme; açılışta itme; solunca 3 çiçek; bekleme 60) (2026-10-18). 59: Gece görüş yarıçapı artık daralmıyor (AtmosphereMath.NIGHT_VISION_MULT 0,75 -> 1,0; sis, mermi menzili, Korsan/Kirpi/Matthew menzilleri aynı yarıçapı okur) (2026-10-18). 58: Agaci Koru agaci can/kalkan geri eski (70/22, yedek 3000/800; rev 51 dususu iptal) + yeni SIHIRLI ATIS: 3 sn de bir kristalden sarjli kure, 56 px alan hasari (ort. yaratik cani x0,6) + agactan disa itis 90 px (boss 150 -> C++ x0,4 = 60 px), menzildeki boss oncelikli (2026-10-18). 57: Tüftüf Bulaşıcı Salgı patlaması (bulaşma yarıçapı + halka) %50 küçüldü (100 -> 50), zehir hasarı %6 -> %7. 56: Pençe güçlendirme - Kanlı Pençe kanaması saldırı gücünün %7'si -> %20'si/sn (tek yük, birikmez), can emme %4 -> %6 ve artık ilk vuruşta da (eskiden sadece zaten kanayan hedefte; alan payında %33), alan hasarı 60 -> 80 px; pençe hasarı artık atış anında değil temasta (0,145 / 0,235 sn, Kanca Çekiş) (2026-10-17). 55: Topuz silah özelliği Sismik Dalga'nın merkezi karakterden vuruş noktasına (ana hedef) taşındı; topuz hasarı artık atış anında değil başın yere indiği anda (0,27 sn) (2026-10-17). 54: demirci kademesi (efsun kademesi 1-5) silaha stat verir: kademe basina +%10 hasar, -%5 atis araligi (weapon.gd TIER_*). 53: 7 efsanevi esyaya (Sifa Feneri, Tanrinin Eli, Bilgenin Pusulasi, Ruzgar Yuruyen Cizmeleri, Kan Madalyonu, Ahenk Cevheri, Kiyamet Bicagi) alt parca tarifi verildi (artik sahip olunan parcalar tuketilip fiyattan dusulur); fiyat = bilesen toplami: Sifa 2300 -> 2320, Cizmeler 2400 -> 2410, Kiyamet 2600 -> 2520 (2026-10-17). 52: Yaratik tavani -%30 (150 -> 105, ek oyuncu basi +30 -> +21) ve TUM silahlarin saldiri hizi -%30 (GameManager.WEAPON_ATTACK_SPEED_MULT 0.7, weapon.gd _effective_fire_wait) (2026-10-17). 51: Agaci Koru gorevi suresi 50 -> 170 sn, agac can/kalkan ~%25 dusuk (HP_PER_ENEMY_HIT 70 -> 52, SHIELD_PER_ENEMY_HIT 22 -> 16, yedek 3000/800 -> 2250/600) (2026-10-17). 50: Sovalye R kalkan hasar azaltimi %95 -> %92 (PALADIN_ULTI_SHIELD_COST_MULT 0.05 -> 0.08). 49: Balkabagi boss ates topu 20 -> 30 (+%50). 48: Talon E (Silah Salvosu) -%40 hasar cezası kaldırıldı, Ayna Formu kopya başına saldırı gücü cezası %8 -> %4 (2026-10-17); 47: fareler (rat1-3) oyundan kalktı, yerlerine slime1 (Kademe 1-4, 6) + elit slime2; slime gecikmesi kapalı (2026-10-17); 46: Assasin R (Gölge Hücumu) bekleme 90 -> 10 sn, hedefler sadece KENDİ görüş alanında (eski 600 birim yarıçap), ulti başına en fazla 20 çarpış (eskiden 10 sn sınırsız, ~45) (2026-10-16); 45 (+ kayda gold_kill/gold_assist/sup_sent eklendi, rev aynı: sadece yeni alanlar): asist sadece öldürmeden önceki 8 sn içindeki hasar/destekle (eskiden %10+ hasar süresizdi), Şovalye E/R koruması da bitişten sonra 8 sn sayılır (2026-10-15); 44: ASİST sistemi - çok oyunculuda yaratık altını hasar/destek verenlerle paylaşılır (öldüren en az %50; toplam <4 altın bölünmez) (2026-10-15); 43: yaratık altını yere düşmez, öldürene anında verilir ve her ölümde garanti (en az 1; kademeye göre şans x ortalama, boss paylaşımlı, minyon şansa bağlı) (2026-10-15); 42: maden kazma altını 5 kat (bakır 1 -> 5, gri 2 -> 10 / vuruş) (2026-10-15); 41: Talon E Şovalye kubbesinde = kubbe girdabı: halkadaki HERKESİN silahı döner ve dışa ateş eder, +%200 (evrimle +%250) saldırı hızı, -%40 hasar; Koşan Salvo/Keskin Çember yarı (2026-10-15); 40: Şovalye R koruma alanı daire (yarıçap 126) -> 2:1 elips yatay 126, dikey 63 (alan yarıya indi; yaratıklar aşağıdan/yukarıdan çok daha yakına gelir) - izometrik kubbe (2026-10-14); 39: seviye başına can artışı 20/10 -> her seviye +15 (11+ dahil) (2026-10-14); 38: Melek pasifi can yerine mana kalkanı yeniliyor (oran aynı, saldırı gücünün %2'si/sn) (2026-10-14); 37: Kopyanı Öldür kopyası - can/kalkan x30, hız %80 ve kalkan yedeği SİLİNDİ (oyuncunun statları aynen); verdiği/aldığı hasar %50 azalmayla başlar, oyunda geçen her 20 sn'de %1 artar, en çok %95 (2026-10-14); 36: kalp yenilenmesi artık her kalp eksildiğinde işler (2+ kalp 8 dk, 1 kalp 6,5 dk, 0 kalp 5 dk; eskiden sadece 0 kalpte 5 dk) (2026-10-14); 35: kalkan orbu - yaratıklardan yemekle aynı oranda (%0,25, şansla artar) düşen yeni toplanabilir, azami kalkanın %15'i (%70) / %30'u (%30) (2026-10-14); 34: her epik eşyadan en fazla 1 (parçalar serbest), Matthew pasifi Yıldırım Hızı tavanı %30 -> %15 hareket hızı + toplam hareket hızının her %1'i = %0,5 saldırı hızı (eskiden birikimin kendisi = aynı oranda saldırı hızı) (2026-10-14); 33: level atlama Can kartı 15/24/30/38 -> 20/35/50/70 (2026-10-14); 32: kalkan türlerinin kendi yenilenme değeri x1,3 (eşya/yetenek kaynaklı yenilenme hariç) (2026-10-14); 31: sağ alt tehlikeli bölge - bekçi kampları 3 -> 7 (29 -> 106 bekçi), arkadaşlarını çağırmazlar (sadece görenler kovalar), %35-70 oranında 1-2 kademe ilerisinden yaratık (2026-10-14); 30: maden kazma - köşelerdeki madenlerde durunca otomatik kazma, vuruş başına altın (bakır 1, gri 2; yeni altın kaynağı), madenler 1,5 vuruş/karo dayanır (en az 8) ve 120 sn sonra yeniden doğar (2026-10-14); 29: her silahtan en fazla 1 (aynı silah ikinci kez alınamaz), silah hasarı x1,5 -> x1,0 (yakın dövüş ek x1,4 kaldı), Yay Üçlü Ok yan ok hasarı %80 -> %60 (+%20 -> +%15 geliştirme) (2026-10-14); 28: Cadı iksir alanı süresi 4 -> 6 sn, mermi menzili = görüş elipsi (oyuncu + yaratık mermileri), yaratık yakın dövüş menzili 26 -> 12 px + isabet toleransı 40 -> 20 px (2026-10-14); 27: Ruh Mağazası kalıcı geliştirmeleri (20 kalıcı stat; oyuncular artık her koşuya Ruh Kıymığıyla alınmış bonuslarla başlayabilir) (2026-10-13); 26: Elara pasifi saldırı hızı sınırı %50 -> %30 (30. seviyede dolar) (2026-10-13); 25: karakter başına başlangıç statları (Can/Hız/Saldırı Gücü/Saldırı Hızı, Characters.BASE_STATS; eskiden herkes 100/252/10/+0) (2026-10-13); 24: Cadı Q dumanı topuğun hemen arkasına iner (eskiden ~41 birim geride) + yukarı/aşağı yürürken dar-derin bulut 24x22 (yatay 32x17, alan aynı), 0,3 sn'de bir (2026-10-13); 21: eşya kaynaklı bekleme azaltma da %60 üst sınırında (eskiden sadece kartlar) (2026-10-13); 20: yaratık kalkan soğurması normal %30 -> %60 (Kademe 7'de tam), elit %80 (2026-10-13); 19: eşya/ruhani/evcil saldırı hızı havuzu hıza EKLENİR (aralık = 1/(1+toplam)); eskiden 1'den çıkarılıp yüzük yığınında katlanıyordu (2026-10-13); 18: evcil hayvan Kirpi (sana saldıran yaratık azami kalkanının %5'i kadar hasar alır; kalkan varken alınan hasar %5 az) (2026-10-13); 17: evcil hayvan Peri (can eksikken 6 sn'de bir saldırı gücünün %10'u kadar can) (2026-10-12); 16: evcil hayvan Kelebek Ruhu (+%10 saldırı hızı, ilk silah isabetine saldırı gücünün %20'si lazer) (2026-10-12); 15: Savaş Kalkanı savaşta (son 3 sn hasar) yenilenme x0,5 + geliştirme başına yenilenme +2 -> +1,5 (2026-10-12); 14: evcil hayvanlar (köpek: sahibin statlarıyla saldırır; papağan: altın toplar + 10 şans) (2026-10-12); 13: Korsan pasifi Altın Avcısı (öldürme başına 1 altın, 30 altın = +1 saldırı gücü; Papağan kalktı) (2026-10-12); 12: silah parçacığı düşme şansı %1 -> %0,5, eşya satış iadesi %70 -> %50 (2026-10-12); 11: Matthew rework - köpek yok, şimşek kiti (pasif Yıldırım Hızı, E Elektrik Topu, R köpeksiz) (2026-10-12); 10: Ejderha Nefesi menzil x1,5 / açı x1,25 (eskiden x2 / x1,5) (2026-10-12); 9: silah sınırı 3 + silah hasarı x1,5 (yakın dövüş x2,1) deneme (2026-10-12); 8: Şovalye pasifi Dirençli Duruş (%40 altı %20 az hasar; Dikenli Zırh kalktı) (2026-10-12); 7: Elara pasifi gerçek +%50 hız + taşma dışı, Tüfek delme hasarı %70 (2026-10-12); 6: yaratık hasarı x0,8 iptal + Balkabağı güçlendirme (2026-10-11)
const SCHEMA := 1
const DIR_PATH := "user://balans"
const FILE_NAME := "kosular.jsonl"
const ENV_PATH := "LILSLAYERS_BALANCE_PATH" ## testler/bot koşuları için dosya yolu (tam yol) - yoksa varsayılan
const MAX_FILE_BYTES := 4 * 1024 * 1024 ## aşılırsa eski dosya kosular_eski.jsonl'e taşınır (4 MB ~ binlerce koşu)
const MAX_RECORD_CHARS := 20000 ## host'a gelen kayıt sınırı (RPC güvenliği)
const MAX_KEYS := 80

static var _src: String = ""
static var _dealt: Dictionary = {} ## kaynak -> [hasar, isabet, kritik]
static var _taken: Dictionary = {} ## yaratık ailesi -> alınan hasar
static var _dealt_tier: Dictionary = {} ## kademe(int) -> verilen hasar
static var _taken_tier: Dictionary = {} ## kademe(int) -> alınan hasar
static var _tier_time: Dictionary = {} ## kademe(int) -> o kademeye ilk girilen koşu saniyesi
static var _killer: String = "" ## bize en son vuran kaynak ailesi (ölüm sebebi tahmini)
## 2026-10-12 (madde 105): ölüm zamanı, silah/eşya edinme zamanı. Edinme, her ~5 sn'de bir sahip olunanları bir önceki örnekle karşılaştırarak
## bulunur (silah/eşya ekleyen 6 yere kanca koymamak için); çözünürlük SAMPLE_INTERVAL.
const SAMPLE_INTERVAL := 5.0
const MAX_DOWNS := 12
static var _downs: Array = [] ## [[koşu sn, kademe], ...] yere düşüş + kalıcı ölüm sırasıyla
static var _death_t: float = -1.0 ## kalıcı ölümün koşu saniyesi (-1 = ölmedi)
static var _death_tier: int = 0
static var _got_weapons: Array = [] ## [[anahtar, koşu sn], ...] edinme sırasıyla
static var _got_items: Array = []
static var _seen_weapons: Dictionary = {} ## anahtar -> görülen adet
static var _seen_items: Dictionary = {}
static var _next_sample: float = 0.0
## 2026-10-15 (madde 168): altın ve ASİST kaydı. Alıcı makinede (KillGold.show_at) sayılır: öldürme altını [adet, altın], asist altını
## türüne göre (1 hasar / 2 destek / 3 ikisi) [adet, altın]; verdiğimiz destek bildirimi (NetworkManager.report_support) sayısı.
static var _gold_kill: Array = [0, 0]
static var _gold_assist: Dictionary = {} ## tür(int) -> [adet, altın]
static var _sup_sent: int = 0
static var _gain: Dictionary = {} ## kaynak -> [can, kalkan] (yetenek/pasifin KENDİNE ve arkadaşlara bastığı; oyun sonu + Shift ipucu için)
static var _prevented: Dictionary = {} ## kaynak -> engellenen hasar (evcil Kirpi'nin %5'i; evcil yuvası ipucu, damage_stats.gd pet_totals)
static var _util: Dictionary = {} ## kaynak -> {ölçü: miktar} (ör. "ally" = Şovalye E'nin dostlardan üstlendiği hasar; damage_stats.gd UTIL_LABELS)
static var _cc_until: Dictionary = {} ## "yaratık id|kaynak|tür" -> msec: aynı kontrolün tazelenmesi tekrar sayılmasın (on_cc)
static var _windows: Dictionary = {} ## açık etki penceresi: kaynak -> sadece silah isabetleri mi (set_window; on_hit "during"/"during_w" ekler)
static var _pet_drops: int = 0 ## Papağan'ın ağaçtan düşürdüğü eşya sayısı (korsan_parrot.gd _drop_loot)
## 2026-10-18 (madde 269): sonsuz kat kırılımı. kat -> [koşu sn, öldürme, takım seviyesi, verilen hasar, alınan hasar, saldırı gücü, azami can, saldırı hızı %, eşya sayısı]
## (katın BAŞLANGICINDAKİ toplamlar; kat başına oranı ardışık satırların farkı verir - bkz. layers alanı, main.gd _on_endless_layer_reached).
const MAX_LAYER_ROWS := 80
static var _layers: Dictionary = {}


static func reset() -> void:
	_src = ""
	_dealt.clear()
	_taken.clear()
	_dealt_tier.clear()
	_taken_tier.clear()
	_tier_time.clear()
	_killer = ""
	_downs.clear()
	_death_t = -1.0
	_death_tier = 0
	_got_weapons.clear()
	_got_items.clear()
	_seen_weapons.clear()
	_seen_items.clear()
	_next_sample = 0.0
	_gold_kill = [0, 0]
	_gold_assist.clear()
	_sup_sent = 0
	_gain.clear()
	_prevented.clear()
	_util.clear()
	_cc_until.clear()
	_windows.clear()
	_pet_drops = 0
	_layers.clear()


## ---- Etiketleme ----

static func tag(source: StringName) -> void:
	_src = String(source)


## Silahın shop_key'i (weapon.gd set_meta) -> "w:<key>". Geçersiz/anahtarsız silah etiketlemez ("diger" kalır).
static func tag_weapon(weapon: Variant) -> void: ## Variant: silahı satılmış/silinmiş merminin çağrısı tipli parametrede hata verirdi
	if weapon == null or (weapon is Object and not is_instance_valid(weapon)):
		_src = ""
		return
	if weapon != null and is_instance_valid(weapon) and weapon is Node and (weapon as Node).has_meta("shop_key"):
		_src = "w:" + str((weapon as Node).get_meta("shop_key"))
	else:
		_src = ""


## enemy.take_damage'ın EN BAŞINDA: etiketi okur ve siler (erken dönüşlerde sonraki isabete sızmasın).
static func take_src() -> String:
	var s: String = _src
	_src = ""
	return s


## ---- Toplama (dealer-side: enemy.take_damage / _take_dot_damage; player.take_damage) ----

static func on_hit(source: String, amount: float, is_crit: bool) -> void:
	if amount <= 0.0:
		return
	var key: String = source if source != "" else "diger"
	var row: Array = _dealt.get(key, [0.0, 0, 0])
	row[0] += amount
	row[1] += 1
	if is_crit:
		row[2] += 1
	_dealt[key] = row
	if not _windows.is_empty():
		for w in _windows:
			if bool(_windows[w]):
				if key.begins_with("w:"):
					on_util(w, "during_w", amount)
			else:
				on_util(w, "during", amount)
	var t: int = GameManager.run_max_tier
	_dealt_tier[t] = float(_dealt_tier.get(t, 0.0)) + amount
	_maybe_sample()


static func on_taken(amount: float, source: Node) -> void:
	if amount <= 0.0:
		return
	var fam: String = _family_of(source)
	_taken[fam] = float(_taken.get(fam, 0.0)) + amount
	_killer = fam
	var t: int = GameManager.run_max_tier
	_taken_tier[t] = float(_taken_tier.get(t, 0.0)) + amount
	_maybe_sample()


## player.gd heal()/heal_shield()/_apply_*_to_ally: kaynağı BELİRTİLEN (yetenek/pasif) iyileştirme ve kalkan basmayı toplar.
## Kaynaksız (yemek, yenilenme, eşya...) çağrılar kaydedilmez - ekran yalnız yeteneklerin payını gösterir.
static func on_gain(source: String, heal_amount: float, shield_amount: float) -> void:
	if source == "" or (heal_amount <= 0.0 and shield_amount <= 0.0):
		return
	var row: Array = _gain.get(source, [0.0, 0.0])
	row[0] += maxf(heal_amount, 0.0)
	row[1] += maxf(shield_amount, 0.0)
	_gain[source] = row


## Bir kaynağın oyuncuya gelmeden engellediği hasar (şimdilik evcil Kirpi: mana kalkanı varken %5 az hasar).
static func on_prevented(source: String, amount: float) -> void:
	if source == "" or amount <= 0.0:
		return
	_prevented[source] = float(_prevented.get(source, 0.0)) + amount


## Yeteneğin hasar/can/kalkan dışı faydası (Shift ipucu "BU OYUNDA"): ölçü adları damage_stats.gd UTIL_LABELS'ta.
static func on_util(source: String, metric: String, amount: float = 1.0) -> void:
	if source == "" or amount <= 0.0:
		return
	var row: Dictionary = _util.get(source, {})
	row[metric] = float(row.get(metric, 0.0)) + amount
	_util[source] = row


## Yeteneğin bir yaratığa uyguladığı kontrol (kind: root/slow/fear/freeze/stun/mad) - ÇAĞIRAN (yerel oyuncunun) tarafta, apply_*'dan hemen
## önce. Aynı yaratığa aynı kaynaktan süre bitmeden gelen tazeleme sayılmaz; bossa işlemeyen türler (yavaşlatma dışı) bossta sayılmaz.
static func on_cc(source: String, kind: String, enemy: Object, duration: float) -> void:
	if source == "" or enemy == null or not is_instance_valid(enemy) or enemy.get("is_dead") == true:
		return
	if kind != "slow" and enemy.get("is_boss") == true:
		return
	var now: int = Time.get_ticks_msec()
	var key: String = "%d|%s|%s" % [enemy.get_instance_id(), source, kind]
	if now < int(_cc_until.get(key, 0)):
		return
	if _cc_until.size() > 4096:
		_cc_until.clear()
	_cc_until[key] = now + int(maxf(duration, 0.5) * 1000.0)
	on_util(source, kind, 1.0)


## Güçlendirme yeteneği açıkken verilen hasar (Elara E/R, Talon E/R, Assasin pasifi): yerel player.gd her fizik karesinde bayrağı yazar.
## weapons_only: sadece silah isabetleri ("w:") sayılır.
static func set_window(source: String, on: bool, weapons_only: bool) -> void:
	if on:
		_windows[source] = weapons_only
	elif _windows.has(source):
		_windows.erase(source)


static func util_snapshot() -> Dictionary:
	return _util.duplicate(true)


static func on_pet_drop() -> void:
	_pet_drops += 1


## Salt okunur kopyalar (arayüz: damage_stats.gd).
static func dealt_snapshot() -> Dictionary:
	return _dealt.duplicate(true)


static func gain_snapshot() -> Dictionary:
	return _gain.duplicate(true)


static func prevented_snapshot() -> Dictionary:
	return _prevented.duplicate()


static func pet_drops() -> int:
	return _pet_drops


## KillGold.show_at çağırır (altını kazanan makinede). assist_kind 0 = kendi öldürmemiz, 1/2/3 = asist türü, 4 = takım payı (assist.gd KIND_TEAM).
static func on_kill_gold(amount: int, assist_kind: int) -> void:
	if amount <= 0:
		return
	if assist_kind <= 0:
		_gold_kill[0] += 1
		_gold_kill[1] += amount
	else:
		var row: Array = _gold_assist.get(assist_kind, [0, 0])
		row[0] += 1
		row[1] += amount
		_gold_assist[assist_kind] = row


## NetworkManager.report_support (throttle'dan sonra): arkadaşa destek verdiğimiz sayı.
static func note_support_sent() -> void:
	_sup_sent += 1


## player.gd _go_down (permanent=false) / _finalize_death (permanent=true) çağırır.
static func note_down(permanent: bool) -> void:
	var now: float = GameManager.run_elapsed()
	if _downs.size() < MAX_DOWNS:
		_downs.append([_r1(now), GameManager.run_max_tier])
	if permanent and _death_t < 0.0:
		_death_t = now
		_death_tier = GameManager.run_max_tier


static func _maybe_sample() -> void:
	var now: float = GameManager.run_elapsed()
	if now < _next_sample:
		return
	_next_sample = now + SAMPLE_INTERVAL
	sample_loadout()


## Sahip olunan silah/eşya adetlerini bir önceki örnekle karşılaştırır; artanlar şimdiki koşu saniyesiyle "edinildi" listesine eklenir.
static func sample_loadout() -> void:
	var now: float = _r1(GameManager.run_elapsed())
	_diff_owned(GameManager.owned_weapons, _seen_weapons, _got_weapons, now)
	_diff_owned(GameManager.owned_items, _seen_items, _got_items, now)


static func _diff_owned(owned: Array, seen: Dictionary, got: Array, now: float) -> void:
	var counts: Dictionary = {}
	for e in owned:
		if e is Dictionary:
			var k: String = str((e as Dictionary).get("key", ""))
			counts[k] = int(counts.get(k, 0)) + 1
	for k in counts:
		for _i in range(int(counts[k]) - int(seen.get(k, 0))):
			if got.size() < MAX_KEYS * 2:
				got.append([k, now])
	seen.clear()
	seen.merge(counts)


static func note_tier(tier: int) -> void:
	if not _tier_time.has(tier):
		_tier_time[tier] = GameManager.run_elapsed()


## Sonsuz modda yeni kata girildi (her peer, main.gd): katın başlangıç anlık görüntüsü. Aynı kat bir kez; sonsuz değilse (kat <= 0) yok sayılır.
static func note_layer(layer: int, player: Node) -> void:
	if layer <= 0 or _layers.has(layer) or _layers.size() >= MAX_LAYER_ROWS:
		return
	var dealt: float = 0.0
	var taken: float = 0.0
	var ap: float = 0.0
	var hp: float = 0.0
	var atk: float = 0.0
	if player != null and is_instance_valid(player):
		dealt = _pf(player, "match_damage_dealt")
		taken = _pf(player, "match_damage_taken")
		ap = _pf(player, "damage_bonus")
		hp = _pf(player, "max_health")
		if player.has_method("get_attack_speed_bonus_percent"):
			atk = float(player.call("get_attack_speed_bonus_percent"))
	_layers[layer] = [_r1(GameManager.run_elapsed()), GameManager.run_kills, GameManager.team_level, _r1(dealt), _r1(taken), _r1(ap), _r1(hp),
			_r1(atk), GameManager.owned_items.size()]


## Oyuncunun nesne alanını güvenle okur (yoksa 0): testlerde sahte/eksik oyuncu ve eski sürümlerle uyumlu.
static func _pf(obj: Object, prop: String) -> float:
	if obj == null or not (prop in obj):
		return 0.0
	var v: Variant = obj.get(prop)
	return float(v) if (v is float or v is int) else 0.0


static func _r3(x: float) -> float:
	return snappedf(x, 0.001)


## Koşu sonu istatistik özeti: güç eğrisini (saldırı gücü, hız, kritik, can, yenilenme...) kayda koyar. Eskiden bunlar yoktu ve eşya sayımından tahmin ediliyordu.
static func player_stats(player: Node) -> Dictionary:
	if player == null or not is_instance_valid(player):
		return {}
	var atk: float = 0.0
	var atk_over: float = 0.0
	if player.has_method("get_attack_speed_bonus_percent"):
		atk = float(player.call("get_attack_speed_bonus_percent"))
	if player.has_method("get_attack_speed_overflow_percent"):
		atk_over = float(player.call("get_attack_speed_overflow_percent"))
	var exp_raw: float = _pf(player, "exp_gain_percent")
	return {
		"ap": _r1(_pf(player, "damage_bonus")),
		"atk": _r1(atk), ## toplam saldırı hızı % (üst sınır 600)
		"atk_over": _r1(atk_over), ## sınırı aşan % (0,5 saldırı gücüne döner)
		"crit_c": _r3(_pf(player, "crit_chance_bonus")),
		"crit_d": _r3(_pf(player, "crit_damage_bonus")),
		"hp": _r1(_pf(player, "max_health")),
		"regen": _r1(_pf(player, "heal_regen_card_bonus") + _pf(player, "item_health_regen")),
		"shield": _r1(_pf(player, "item_shield_max")),
		"shield_pct": _r3(_pf(player, "shield_max_percent")),
		"dodge": _r3(_pf(player, "dodge_chance")),
		"pen": _r3(_pf(player, "shield_pen_percent")),
		"exp": _r3(exp_raw),
		"exp_eff": _r3(GameManager.effective_exp_gain(exp_raw)),
		"luck": _r1(_pf(player, "luck")),
		"cdr": _r3(_pf(player, "cooldown_reduction_percent")),
		"ls": _r3(_pf(player, "lifesteal_percent")),
		"heal_pow": _r3(_pf(player, "heal_shield_power")),
		"spd": _r3(_pf(player, "speed_card_percent")),
		"range": _r3(_pf(player, "weapon_range_bonus")),
	}


## Seviye kartı seçimleri: kart kimliği -> [1., 2., 3., 4. kademeden kaç tane]. (player.upgrade_log: [id, kademe])
static func cards_record(player: Node) -> Dictionary:
	var out: Dictionary = {}
	if player == null or not is_instance_valid(player) or not ("upgrade_log" in player):
		return out
	for e in (player.get("upgrade_log") as Array):
		if not (e is Array) or (e as Array).size() < 2:
			continue
		var id: String = str(e[0])
		if not out.has(id) and out.size() >= MAX_KEYS:
			continue
		var row: Array = out.get(id, [0, 0, 0, 0])
		var t: int = clampi(int(e[1]), 1, 4)
		row[t - 1] = int(row[t - 1]) + 1
		out[id] = row
	return out


static func _layers_record() -> Dictionary:
	var out: Dictionary = {}
	for l in _layers:
		out[str(l)] = (_layers[l] as Array).duplicate()
	return out


static func _family_of(source: Node) -> String:
	if source == null or not is_instance_valid(source):
		return "?"
	if source.has_method("creature_family"):
		var f: String = str(source.call("creature_family"))
		if f != "":
			return ("elit_" if source.get("is_elite") == true else "") + f
	var scr: Script = source.get_script()
	if scr != null:
		return str(scr.resource_path.get_file().get_basename())
	return source.name


## ---- Kayıt ----

static func _enabled() -> bool:
	return disabled_reason() == ""


## Kaydın KAPALI olma nedeni (boş = açık). main.gd / network_manager.gd bunu net_log'a yazar (2026-10-17, madde 223).
static func disabled_reason() -> String:
	if GameManager.debug_mode_unlocked:
		return "debug modu açık (GameManager.debug_mode_unlocked)"
	## Headless koşular (testler) gerçek dosyayı kirletmesin; yalnız yol AÇIKÇA verildiyse (bot/analiz koşusu) yazılır.
	if DisplayServer.get_name() == "headless" and OS.get_environment(ENV_PATH) == "":
		return "headless ve %s verilmedi" % ENV_PATH
	return ""


static func _file_path() -> String:
	var env: String = OS.get_environment(ENV_PATH)
	return env if env != "" else DIR_PATH.path_join(FILE_NAME)


static func _top(d: Dictionary, n: int) -> Dictionary:
	if d.size() <= n:
		return d
	var keys: Array = d.keys()
	keys.sort_custom(func(a, b): return _scalar(d[a]) > _scalar(d[b]))
	var out: Dictionary = {}
	for i in n:
		out[keys[i]] = d[keys[i]]
	return out


static func _scalar(v: Variant) -> float:
	return float((v as Array)[0]) if v is Array else float(v)


static func _r1(x: float) -> float:
	return snappedf(x, 0.1)


## Koşunun tam kaydı. summary = main.gd _run_summary(); kind = "end" | "victory".
static func build_record(player: Node, summary: Dictionary, kind: String) -> Dictionary:
	var by_src: Dictionary = {}
	for k in _top(_dealt, MAX_KEYS):
		var row: Array = _dealt[k]
		by_src[k] = [_r1(row[0]), row[1], row[2]]
	var taken: Dictionary = {}
	for k in _top(_taken, MAX_KEYS):
		taken[k] = _r1(_taken[k])
	var dealt_tier: Dictionary = {}
	for t in _dealt_tier:
		dealt_tier[str(t)] = _r1(_dealt_tier[t])
	var taken_tier: Dictionary = {}
	for t in _taken_tier:
		taken_tier[str(t)] = _r1(_taken_tier[t])
	var tier_time: Dictionary = {}
	for t in _tier_time:
		tier_time[str(t)] = _r1(_tier_time[t])
	var weapons: Array = []
	for e in GameManager.owned_weapons:
		if not (e is Dictionary):
			continue
		var w: Dictionary = {"k": str(e.get("key", "")), "l": int(e.get("level", 1))}
		var ench: Variant = e.get("enchant", {})
		if ench is Dictionary and not (ench as Dictionary).is_empty():
			w["tr"] = str((ench as Dictionary).get("id", ""))
			w["up"] = ((ench as Dictionary).get("ups", []) as Array).size()
			if EnchantDefs.plus_count(ench as Dictionary) > 0:
				w["pl"] = EnchantDefs.plus_count(ench as Dictionary) ## final sonrası güçlendirme (madde 297)
		weapons.append(w)
	var items: Array = []
	for e in GameManager.owned_items:
		if e is Dictionary:
			items.append(str((e as Dictionary).get("key", "")))
	sample_loadout() ## son örnek: koşu bitmeden alınanlar da kayda girsin
	var shield_key: String = ShieldEnchantDefs.owned_type()
	var shield_ups: Array = []
	for u in GameManager.shield_enchant_ups:
		shield_ups.append(int(u))
	var evo: Array = []
	var dealt_total: float = 0.0
	var taken_total: float = 0.0
	var max_hp: float = 0.0
	if player != null and is_instance_valid(player):
		if player.has_method("get_skill_evolution_ids"):
			for id in player.get_skill_evolution_ids():
				evo.append(str(id))
		dealt_total = float(player.get("match_damage_dealt"))
		taken_total = float(player.get("match_damage_taken"))
		max_hp = float(player.get("max_health"))
	var peers: int = 1
	if NetworkManager.is_multiplayer_active and multiplayer_peer_count() > 0:
		peers = multiplayer_peer_count()
	return {
		"schema": SCHEMA,
		"rev": BALANCE_REV,
		"run_id": "%d-%d" % [Time.get_unix_time_from_system(), randi() % 1000000],
		"when": Time.get_datetime_string_from_system(true),
		"player": NetworkManager.local_player_name if NetworkManager.local_player_name != "" else "solo",
		"kind": kind,
		"char": int(summary.get("char_id", 0)),
		"char_name": str(CharactersScript.get_def(int(summary.get("char_id", 0))).get("name", "?")),
		"solo": bool(summary.get("solo", true)),
		"team": peers,
		"time": _r1(float(summary.get("time", 0.0))),
		"tier": int(summary.get("tier", 1)),
		"layer": int(summary.get("layer", 0)),
		"kills": int(summary.get("kills", 0)),
		"level": int(summary.get("level", 1)),
		"victory": bool(summary.get("victory", false)),
		"dead": GameManager.is_game_over,
		"killer": _killer,
		"max_hp": _r1(max_hp),
		"dealt": _r1(dealt_total),
		"taken": _r1(taken_total),
		"weapons": weapons,
		"items": items,
		"evo": evo,
		"by_src": by_src,
		"taken_by": taken,
		"dealt_tier": dealt_tier,
		"taken_tier": taken_tier,
		"tier_time": tier_time,
		"shield": shield_key,
		"shield_ups": shield_ups,
		"pet": str(GameManager.selected_pet),
		"downs": _downs.duplicate(),
		"death_t": _r1(_death_t) if _death_t >= 0.0 else -1.0,
		"death_tier": _death_tier,
		"got_weapons": _got_weapons.duplicate(),
		"got_items": _got_items.duplicate(),
		"gold_kill": _gold_kill.duplicate(),
		"gold_assist": _assist_record(),
		"sup_sent": _sup_sent,
		"stats": player_stats(player), ## bitiş statları (madde 269)
		"cards": cards_record(player), ## seviye kartı seçimleri kart -> [k1,k2,k3,k4]
		"layers": _layers_record(), ## sonsuz kat başlangıç anlık görüntüleri (bkz. note_layer)
	}


## {"dmg": [adet, altın], "sup": [...], "both": [...], "team": [...]} - bkz. on_kill_gold.
static func _assist_record() -> Dictionary:
	var names: Dictionary = {1: "dmg", 2: "sup", 3: "both", 4: "team"}
	var out: Dictionary = {}
	for k in _gold_assist:
		out[names.get(int(k), "dmg")] = (_gold_assist[k] as Array).duplicate()
	return out


static func multiplayer_peer_count() -> int:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.get_multiplayer() == null or not tree.get_multiplayer().has_multiplayer_peer():
		return 1
	return tree.get_multiplayer().get_peers().size() + 1


## Koşuyu yerel dosyaya yazar ve kaydı döndürür (boş = yazılmadı). Çağıran istemciyse kaydı host'a da yollar (main.gd).
static func write_run(player: Node, summary: Dictionary, kind: String) -> Dictionary:
	if not _enabled():
		return {}
	var rec: Dictionary = build_record(player, summary, kind)
	append_line(JSON.stringify(rec))
	return rec


## Tek satırı dosyaya ekler (yerel kayıt ve host'un aldığı kayıtlar). Boyut aşılırsa eskisi taşınır.
static func append_line(line: String) -> void:
	var path: String = _file_path()
	var dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	if FileAccess.file_exists(path):
		var f0 := FileAccess.open(path, FileAccess.READ)
		var size: int = f0.get_length() if f0 else 0
		if f0:
			f0.close()
		if size > MAX_FILE_BYTES:
			DirAccess.rename_absolute(path, path.get_basename() + "_eski.jsonl")
	var f: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.close()


## Son ingest_remote çağrısının reddedilme nedeni ("" = kabul edildi). NetworkManager.submit_balance_record net_log'a yazar: host'un dosyası
## değişmediğinde kaydın gelmediğini mi, gelip reddedildiğini mi (debug / boyut / şema) ayırt etmek için.
static var last_ingest_reason: String = ""


## Host'un aldığı istemci kaydı: doğrula, "via":"host" ekle, ekle. Geçersiz/aşırı büyük kayıt atılır (neden last_ingest_reason'da).
static func ingest_remote(json_text: String, sender_peer: int) -> bool:
	last_ingest_reason = disabled_reason()
	if last_ingest_reason != "":
		last_ingest_reason = "host kaydı kapalı: " + last_ingest_reason
		return false
	if json_text.length() > MAX_RECORD_CHARS:
		last_ingest_reason = "kayıt çok büyük (%d > %d karakter)" % [json_text.length(), MAX_RECORD_CHARS]
		return false
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		last_ingest_reason = "JSON değil"
		return false
	var rec: Dictionary = parsed
	if int(rec.get("schema", 0)) != SCHEMA or str(rec.get("run_id", "")) == "":
		last_ingest_reason = "şema/run_id geçersiz (şema %d, beklenen %d)" % [int(rec.get("schema", 0)), SCHEMA]
		return false
	rec["via"] = "host"
	rec["peer"] = sender_peer
	append_line(JSON.stringify(rec))
	return true
