extends NpcActor
class_name BabaanneNpc

## BABAANNE (kullanıcı isteği 2026-10-19, madde 310): cozy evde (house_interior.gd iç mekanı) yaşayan sıcakkanlı büyükanne.
##  - GÜNLÜK PROGRAM (atmosferin EŞİTLENEN gün saati + GameManager.game_time'dan gün numarası -> her istemcide aynı iş):
##    sabah/öğle/akşam KAZANI KARIŞTIRIR (ara sıra çorbanın tadına bakar), RAFLARI/DOLAPLARI/MASAYI SİLER, okuma koltuğunda
##    OTURUP KİTAP OKUR, ŞÖMİNE ÖNÜNDEKİ KOLTUKTA oturur (bazen okur), geceleri BAZEN (3 gecenin 2'si) sol yatak odasındaki
##    çift kişilik yatakta UYUR (yatağın kendi yorgan pikselleri üstüne çizilir).
##  - OYUNCU GİRİNCE: el sallar, selam verir; canı eksikse (ve o oyuncu için bekleme dolduysa) yanına gidip bir kâse çorba verir
##    (FEED_HEAL_PERCENT, yalnız o oyuncunun KENDİ istemcisinde heal - can zaten istemci yetkili, bkz. food_drop.gd).
##  - KONUŞMA: house_interior.gd yakındaki oyuncuya "Babaanneyle konuş" ipucunu gösterir, etkileşim tuşu talk() çağırır (bağlama göre
##    sıcak cümleler + el sallama/gülme/düşünme/omuz silkme). Çıkış kapısına dönen oyuncuyu uğurlar. Uyurken uykulu cevap verir.
##  - SAVAŞ (madde 313): dışarıda savaş olduğunu bilir (selam/sohbet/uğurlama replikleri savaşa göre); açılışta deprem olunca endişelenir,
##    pencereye gidip "adaya canavarlar saldırıyor" der (house_intro.gd evresini okur); ev saldırı altındayken (house_siege.gd) işi
##    bırakıp endişelenir (korku balonu, "duvarlara vuruyorlar"); kazanı DİBİNDE karıştırır, arada tezgahta sebze doğrar.
##  - EV YIKILINCA dışarı çıkar (go_outside): savaşamaz, can 100 (HouseSiege'te, host yetkili), yaratıklar ona da saldırır
##    (GameManager.babaanne_target); ölürse kalıcı (bir daha görünmez). Ev onarılınca (yaşıyorsa) eve döner (come_home).
## Tamamen YEREL/kozmetik (NpcActor kuralı, ağ yok): davranış eşitlenen saatten ve oyuncu konumlarından türetilir.
## Eşya noktaları SABİT DEĞİL: pişmiş iç mekanın karolarından bulunur (kazan, yatak, koltuklar, kitaplık, raflar, masa) - ev Tiled'da
## (harita/cozy_ev.tmx) düzenlenirse büyükanne yeni yerlerini bulur. Ofsetler eşya BLOĞUNUN sol üst köşesine göre (oyun ölçeğinde ölçüldü).

const FRAMES: SpriteFrames = preload("res://assets/npc/babaanne/babaanne_frames.tres")
const AtmosphereMath := preload("res://scripts/atmosphere_math.gd")
const FearEmoteScript := preload("res://scripts/fear_emote.gd")
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const AVCI_TEX: Texture2D = preload("res://harita/Ev içi/Avci_esyalari.png")
const BED_TEX: Texture2D = preload("res://harita/Ev içi/House_interior.png")
const BOWL_REGION := Rect2(19 * 16, 4 * 16, 16, 16) ## Avci_esyalari: dolu kâse
## Çift kişilik yatağın (House_interior 6,0 3x4) kıvrım + yorgan + ayakucu satırları: uyurken büyükannenin ÜSTÜNE çizilir.
const BLANKET_REGION := Rect2(6 * 16, 35, 48, 29)
const BLANKET_OFFSET := Vector2(0.0, 35.0)

## DENGE (BALANCE_REV): çorba = azami canın %30'u (yemek kademesi 3 ile 4 arası), oyuncu başına 4 dk'da bir.
const FEED_HEAL_PERCENT := 0.30
const FEED_COOLDOWN := 240.0
## Canı bu oranın altındaysa çorba getirir (tam canlıya getirmez - oyun evde başlar, herkes tam canla doğar).
const FEED_BELOW := 0.9

const INSIDE_RADIUS := 3000.0 ## iç mekan haritadan 20000 birim uzakta (house_interior.gd INTERIOR_OFFSET)
const TALK_RADIUS := 36.0 ## gövde merkezleri arası (dünya px)
const FEED_REACH := 22.0
## ÇORBA ARAMASI (2026-10-19, kullanıcı: "hiç yemek vermiyor"): eskiden yalnız GİRİŞ anındaki selamdan sonra bakıyordu (o an uyuyor /
## meşgul / canı dolu / bekleme dolmamışsa o ziyarette bir daha getirmiyordu) ve 9 sn'de vazgeçiyordu (yürüyüş 46 px/sn, mutfaktan kapıya
## ~400 px yol + yürüyen hedef). Artık içerideyken FEED_SCAN sn'de bir canı eksik + beklemesi dolmuş oyuncuyu arar (en düşük canlıyı),
## FEED_GIVE_UP'ta vazgeçerse o oyuncuyu FEED_RETRY sn sonra yeniden dener. Yürüyüş hızı aynı (yürüme klibi hızlanmıyor, ayak kayardı).
const FEED_GIVE_UP := 16.0
const FEED_SCAN := 2.0
const FEED_RETRY := 15.0
const DOOR_ARM_DISTANCE := 100.0
const DOOR_NEAR_DISTANCE := 60.0
const FAREWELL_COOLDOWN := 6.0
## KONUŞMA SIKLIĞI (2026-10-19, kullanıcı: "çok fazla konuşuyor"): kendiliğinden söylenenler (iş mırıltısı, kuşatma endişesi, uyku,
## veda, dışarıda sakin söz, soluklanma) arasında en az CHAT_GAP sn (_chat). Her zaman konuşur: oyuncunun konuşturması (talk), çorba,
## açılış senaryosu (deprem/pencere), ölüm, dışarıda kovalanırken imdat; selam yalnız oyuncu GREET_COOLDOWN'dan beri selamlanmadıysa.
const CHAT_GAP := 30.0
const GREET_COOLDOWN := 120.0 ## aynı oyuncu bu sürede yine girer/çıkarsa selam / veda yok (çorba araması sürer)
const HURT_GAP := 6.0 ## dışarıda vurulunca "ah!" en az bu aralıkla
const GREET_TIME := 1.6
## ORTAK SELAM / VEDA (madde 328, kullanıcı: "büyükanne her karakteri için 1 cümle kuruyor, cümleler ortak olmalıydı"): aynı anda içeri giren (ya da
## selamdan GREET_GROUP_WINDOW sn içinde giren) herkes TEK cümleyle karşılanır; birden çok kişiye hitap eden cümle *_GROUP havuzundan. Veda da aynı:
## kapıya yakın herkes için tek cümle, hepsi vedalaşılmış sayılır.
const GREET_GROUP_WINDOW := 8.0
const EMOTE_TIME := 1.8
const SLOW_SPEED := 24.0 ## koltuğa/yatağa son birkaç piksellik kayış

## Gün saati (AtmosphereMath döngü birimi 0..600; 600 birim = 900 gerçek sn) -> iş. Gece: 390..540.
## WORRY / WINDOW programda yok: açılış evresi ve ev kuşatması current_activity()'de öne geçer (madde 313).
enum Act { COOK, WIPE, READ, FIRE_SIT, FIRE_READ, SLEEP, WORRY, WINDOW }
## Açılış geri sayımında: ilk WINDOW_AT sn deprem endişesi, sonra pencereye gidip bakar, WINDOW_END'de normal işine döner.
const WINDOW_AT := 3.0
const WINDOW_END := 16.0
const WINDOW_SAY_1 := 2.0 ## pencereye varınca bu kadar bakıp "canavarlar" der
const WINDOW_SAY_2 := 6.0 ## sonra dönüp oyunculara seslenir
## Kuşatmada iş başında kalır (kullanıcı: "genelde meşgul olmalı ev işleriyle ama çoğu zaman konuşup düşünüyor"): saldırı altındayken
## WORRY_EVERY_MIN..MAX sn'de bir WORRY_FOR sn endişelenip tek söz söyler, sonra işine döner. İlk endişe saldırıdan WORRY_FIRST sn sonra.
const WORRY_FIRST := 3.0
const WORRY_EVERY_MIN := 18.0
const WORRY_EVERY_MAX := 30.0
const WORRY_FOR := 4.0
const OUT_SCARED_RADIUS := 150.0 ## dışarıdayken bu yakında yaratık varsa imdat ister
## KAÇIŞ (kullanıcı: "ev yıkılırsa büyükanne yaratıklardan yürüyerek kaçmaya çalışacak"): host'ta FLEE_RADIUS içindeki yaratıklardan
## uzaklaşan, en yakın canlı oyuncuya doğru çekilen (koruma) FLEE_STEP'lik adımlar; duvar/su/bina olan adım döndürülerek denenir.
## Yaratıklardan yavaş: kaçmaya ÇALIŞIR, yaratıklar yetişip vurabilir. Sakinleşince (CALM_RETURN sn) evinin önüne döner. Konum host'tan eşitlenir
## (HouseSiege granny_net_pos) - her istemcide yaratıklar biraz farklı yerde olduğundan yerel kaçış her ekranda başka yere giderdi.
const FLEE_RADIUS := 220.0
const FLEE_STEP := 40.0
const FLEE_SPEED := 40.0 ## yaşlı yürüyüşü: en yavaş yaratık (1. kademe slime, takipte ~40-45 px/sn) bile yavaşça yetişir (MP denetimiyle ölçüldü; 54 hep kaçıyordu)
const FLEE_REPLAN := 0.35
const CALM_RETURN := 4.0
const PLAYER_PULL := 0.55
const PLAYER_PULL_RANGE := 700.0
const NET_SNAP := 96.0
## Nefes: FLEE_BURST sn kaçınca FLEE_REST sn soluklanır (durur, el sallar) - yaratıklar yakına gelince hızını tutturup arkasında kalıyordu
## (MP denetimi: 38-41 px arkada, hiç vuruş yok); soluklanırken yetişip vurabilirler ("yaratıklar ona da saldırabilir").
const FLEE_BURST := 3.5
const FLEE_REST := 1.5
const HOME_TIMEOUT := 12.0
const DEATH_FADE_AFTER := 7.0
const OUT_EMOTE_RAISE := -18.0 ## dışarıda can çubuğu varken korku balonu onun üstünde
const DAY_SECONDS := 900.0

## Eşya bloğu bulma: doku dosyası + bloğun içinde KESİN dolu bir karo (atlas) + o karonun bloktaki yeri.
const ANCHORS: Dictionary = {
	"kazan": {"tex": "Kazan_ocak.png", "atlas": Vector2i(0, 1), "rel": Vector2i(0, 1)},
	"yatak": {"tex": "House_interior.png", "atlas": Vector2i(7, 1), "rel": Vector2i(1, 1)},
	"kitaplik": {"tex": "Interior.png", "atlas": Vector2i(11, 7), "rel": Vector2i(0, 1)},
	"tabak_rafi": {"tex": "Avci_esyalari.png", "atlas": Vector2i(16, 1), "rel": Vector2i(0, 1)},
	"yemek_masasi": {"tex": "Interior.png", "atlas": Vector2i(10, 10), "rel": Vector2i(2, 1)},
	"tezgah": {"tex": "House_interior.png", "atlas": Vector2i(3, 8), "rel": Vector2i(0, 1)}, ## tezgah (lahana/ekmek/bıçak, 3x2): solunda durup sağa dönük doğrar (madde 313)
}
## Koltuk (Interior 1,10 2x3, SOLA bakar): aynalı yerleşimde bloğun sol karosu atlas (2,10) + çevirme.
const SOFA_TEX := "Interior.png"
const SOFA_ATLAS := Vector2i(1, 11)
const SOFA_ATLAS_FLIP := Vector2i(2, 11)

## Blok sol üstüne göre ayak noktaları (dünya px; gerçek oyun ölçeğinde evin üstünde ölçüldü - tools/proto, madde 310).
## Kazan / tezgah (madde 313, kullanıcı: "uzaktan yapmaya çalışıyor" + "water animasyonu ... arkası bize dönük, tezgahın ve kazanın
## aşağısında durmalı, yanlarında değil"): ikisinin de ÖNÜNDE (aşağısında) yukarı dönük durur, water_up döngüsü (gerçek çizicide ölçüldü).
const STIR_FEET := Vector2(16.0, 42.0) ## kazanın önü, yukarı dönük - taş ocağın ön yarısında, başı tencerenin önünde ("hala çok uzak": 50 -> 46 -> 42; 38 kazanın içine giriyordu)
const CHOP_FEET := Vector2(22.0, 30.0) ## tezgahın (kesme tahtası) önü, yukarı dönük (34 -> 30)
## Poz -> klip: kazan başında ve tezgahta water döngüsü (boya kareleri "doğal değil" - kullanıcı).
const POSE_CLIP: Dictionary = {"stir": "water", "chop": "water"}
const SLEEP_FEET := Vector2(26.0, 60.0) ## baş sol yastıkta
const BED_FOOT := Vector2(24.0, 70.0) ## yatağın ayak ucu (yatmadan önce varılan yer)
const SEAT_LEFT := Vector2(13.0, 43.0) ## sola bakan koltuk
const SEAT_RIGHT := Vector2(19.0, 43.0) ## sağa bakan (aynalı) koltuk
## Silinecek eşyalar: [anahtar, sol taraf ayak, sağ taraf ayak] (sol tarafta durup SAĞA, sağda durup SOLA bakarak siler).
const WIPE_SIDES: Dictionary = {
	"kitaplik": [Vector2(-3.0, 44.0), Vector2(35.0, 44.0)],
	"tabak_rafi": [Vector2(-4.0, 50.0), Vector2(38.0, 50.0)],
	"yemek_masasi": [Vector2(-4.0, 40.0), Vector2(78.0, 40.0)],
}

## REPLİKLER (madde 313, kullanıcı: "daha fazla konuşma varyasyonu ... türk kültürüne çok yakın duruyor, aman allahım yerine aman tanrım,
## evrensel olmalı"): her bağlamda çok sayıda cümle, kültüre özgü ifade yok (hitap: tatlım / canım / çocuğum; yemek: sebze çorbası, ekmek,
## turta). Barış havuzları açılışta ve testlerde; *_WAR havuzları canavarlar adaya saldırdıktan sonra (at_war()).
const GREETINGS: Array[String] = [
	"Hoş geldin tatlım!", "Ah, sonunda geldin canım!", "Gel bakayım, üşüdün mü?", "Ellerin buz gibi, gel ateşin başına!",
	"Neredeydin? Merak ettim!", "Kapıyı ört de içerisi ısınsın.", "Çizmelerini sil, yeni temizledim!",
	"Tam zamanında geldin, çorba kaynıyor.", "Yüzünü görmek içimi ısıttı.", "Gel otur, yorgun görünüyorsun.",
]
## Birden çok kişiye tek cümle (çoğul hitap).
const GREETINGS_GROUP: Array[String] = [
	"Hoş geldiniz çocuklar!", "Ah, hepiniz geldiniz, ne güzel!", "Gelin bakalım, üşüdünüz mü?", "Ellerinizi ısıtın, ateşin başına gelin!",
	"Neredeydiniz? Hepiniz için merak ettim!", "Kapıyı örtün de içerisi ısınsın.", "Çizmelerinizi silin, yeni temizledim!",
	"Tam zamanında geldiniz, çorba kaynıyor.", "Hepinizi görmek içimi ısıttı.", "Gelin oturun, yorgun görünüyorsunuz.",
]
const FAREWELLS_GROUP: Array[String] = [
	"Kendinize iyi bakın çocuklar!", "Akşama gelin, çorba hazır olur!", "Hava kararmadan dönün!", "Yolunuz açık olsun!",
	"Atkılarınızı unutmayın!", "Erken dönün, merak ederim.",
]
const FEED_LINES: Array[String] = [
	"Al bakalım, sıcak sıcak çorba!", "Ye ki gücün yerine gelsin.", "Bir kâse çorba içmeden bırakmam seni!",
	"Sebze çorbası, tam sevdiğin gibi.", "Afiyet olsun canım, kuvvet olsun!", "Yanına taze ekmek de koydum.",
	"Üfle üfle, dilini yakma!", "Annemin tarifi, her derde iyi gelir.",
]
const TALK_LINES: Array[String] = [
	"Gençken ben de senin gibi maceracıydım.", "Deden de hiç yerinde durmazdı, sen ona çekmişsin.",
	"Kazan kaynıyor, birazdan çorba hazır.", "Dışarıda dolaşırken atkını unutma!", "Bu kemiklerim yağmuru hep önceden bilir.",
	"Sen sağlıklı ol yeter, gerisi kolay.", "Akşama erken gel, ateşi yakarım.", "Rafların tozunu aldım, bak nasıl parlıyor!",
	"Bahçedeki çiçekler bu yıl çok güzel açtı.", "Kitabımın sonunu merak ediyorum, sakın söyleme!",
	"Bir gün sana örgü örmeyi öğreteceğim.", "Şu sandalye de benim dizlerim gibi gıcırdıyor.",
	"Elmalı turta yapmayı düşünüyorum, ne dersin?", "Pencereden kuşları izlemek en sevdiğim şey.",
]
const TALK_LOW_HP: Array[String] = [
	"Aman tatlım, ne bu hâlin? Otur biraz dinlen.", "Yaralanmışsın! Gel, bir çorba içmeden çıkma.",
	"Dizlerin titriyor, bir dakika otur.", "Bu kesik kötü görünüyor, hemen sarayım.",
]
const TALK_NIGHT: Array[String] = [
	"Gece dışarısı tehlikeli, şöminenin yanında otur.", "Yaratıklar gece azar, dikkat et canım.",
	"Yıldızlar ne güzel bu gece, ama sen yine de içeride kal.",
]
## Duygulu cümleler: [cümle, klip]
const TALK_EMOTE: Array = [
	["Hı hı hı! Sen de amma şakacısın!", "laugh"], ["Hmm... bir şey unuttum ama neydi?", "think"],
	["Ben ne bileyim tatlım, ben yaşlı bir kadınım.", "shrug"], ["Seni görmek ne güzel!", "wave"],
	["Gençken dansta herkesi geçerdim, hı hı!", "laugh"], ["Gözlüğüm nerede... ah, burnumun ucunda!", "think"],
]
const SLEEP_TALK: Array[String] = [
	"Zzz...", "Hıımm... beş dakika daha...", "Uyandırdın beni... iyi geceler tatlım.", "Zzz... çorba... Zzz...",
	"Mmm... kurabiyeler fırında... Zzz...", "Zzz... kim o... ah, sensin...",
]
const FED_RECENTLY: Array[String] = [
	"Daha az önce yedin, birazdan yine pişiririm.", "Karnın tok mu? Peki, akşama yine yaparım.",
	"Bu kadar çabuk acıktın mı? Biraz bekle, kazan doluyor.",
]
const FAREWELLS: Array[String] = [
	"Kendine iyi bak tatlım!", "Akşama gel, çorba hazır olur!", "Hava kararmadan dön!", "Yolun açık olsun canım!",
	"Atkını unutma!", "Erken dön, merak ederim.",
]
const COOK_MUTTER: Array[String] = [
	"Biraz daha tuz mu koysam?", "Mmm, tam kıvamında!", "Kokusu her yeri sardı!", "Bir tutam kekik iyi gider...",
	"Kaynasın bakalım, acele yok.", "Şu havuçlar da ne iri olmuş!",
]
const WIPE_MUTTER: Array[String] = ["Şu tozlar da hiç bitmez!", "Her yer pırıl pırıl olsun.", "Örümcek, burası senin evin değil!",
	"Bir de raflara bakalım..."]
const READ_MUTTER: Array[String] = ["Ne güzel kitap bu...", "Hmm, bu kısmı okumuştum galiba.", "Ah, sonunda kavuştular!",
	"Gözlüğümü silmem lazım..."]

## SAVAŞ: canavarlar adaya saldırdıktan sonra (GameManager.invasion_pending false).
const GREETINGS_WAR: Array[String] = [
	"Şükürler olsun, sağsın!", "Geldin mi canım? Dışarısı savaş alanı...", "Çabuk içeri, kapıyı ört! Canavarlar çok yakın.",
	"Yüzün gözün toz içinde! Kaç canavar devirdin?", "Seni bekliyordum, yüreğim ağzımdaydı!", "Yaralandın mı? Göster bakayım!",
	"Sesleri duydum, çok korktum senin için.", "Gel, biraz soluklan. Ama çok oyalanma!", "Kahramanım geldi! Dışarısı nasıl?",
	"Kapıyı sıkıca kapat, kokumuzu almasınlar.",
]
const GREETINGS_GROUP_WAR: Array[String] = [
	"Şükürler olsun, hepiniz sağsınız!", "Geldiniz mi çocuklar? Dışarısı savaş alanı...", "Çabuk içeri, kapıyı örtün! Canavarlar çok yakın.",
	"Yüzünüz gözünüz toz içinde! Kaç canavar devirdiniz?", "Sizi bekliyordum, yüreğim ağzımdaydı!", "Yaralanan var mı? Gösterin bakayım!",
	"Sesleri duydum, hepiniz için çok korktum.", "Gelin, biraz soluklanın. Ama çok oyalanmayın!", "Kahramanlarım geldi! Dışarısı nasıl?",
	"Kapıyı sıkıca kapatın, kokumuzu almasınlar.",
]
const FAREWELLS_GROUP_WAR: Array[String] = [
	"Şansınız bol olsun çocuklar!", "Sağ salim dönün, söz verin bana!", "Gösterin onlara gününü!", "Dikkat edin, birbirinizin arkasını kollayın!",
	"Cesur olun ama dikkatsiz olmayın!", "Ateşi yanık tutacağım, dönün bana!",
]
const FEED_LINES_WAR: Array[String] = [
	"Al şu çorbayı, savaşta güç lazım!", "Ye ki o canavarlara gününü göster!", "Sıcak sıcak iç, yaraların çabuk kapansın.",
	"Aç karnına savaşılmaz, ye hadi!", "Bu çorba ölüyü diriltir, iç bakalım!",
]
const TALK_WAR: Array[String] = [
	"Bu canavarlar da nereden çıktı böyle, anlamadım gitti.", "Deden de bir zamanlar bu adayı savunmuştu.",
	"Evde fazla oyalanma, canavarlar kokumuzu alır.", "Sen savaş, ben çorbayı sıcak tutarım.",
	"Ben savaşamam ama kalbim hep seninle.", "Kıyıdan gelen o sesler... bu gece uyku yok bana.",
	"Gücün tükenirse buraya gel, ama uzun kalma!", "Bu ada bizim, kimseye bırakmayız!",
	"Duvarlar yaşlı ama sağlamdır, yine de güvenme.", "Yaralarını sarmak için temiz bez ayırdım.",
	"Gece boyu ateşi söndürmeyeceğim, yolunu bulasın diye.", "Korkmak ayıp değil, korkuya rağmen yürümek cesarettir.",
	"Biri kapıya vurursa önce sesine bakarım, merak etme.", "Canavarların gözleri karanlıkta parlıyormuş, dikkat et.",
]
const TALK_NIGHT_WAR: Array[String] = [
	"Gece canavarlar daha da azar, gözünü dört aç.", "Karanlıkta yalnız dolaşma, yanında biri olsun.",
	"Fenerini al, karanlık onların tarafında.",
]
const TALK_EMOTE_WAR: Array = [
	["Ben gençken bir ayıyı tavayla kovaladım, hı hı!", "laugh"], ["Hmm... canavarlar acaba çorba sever mi?", "think"],
	["Ne yapayım, ben yaşlı bir kadınım.", "shrug"], ["Sağ salim döndün ya, gerisi boş!", "wave"],
	["Bir canavar daha görürsem şemsiyemle döverim, hı hı!", "laugh"], ["Kaç taneydiler? Saymayı unuttum...", "think"],
]
const FAREWELLS_WAR: Array[String] = [
	"Şansın bol olsun canım!", "Sağ salim dön, söz ver bana!", "Göster onlara gününü!", "Dikkat et, arkanı kolla!",
	"Cesur ol ama dikkatsiz olma!", "Ateşi yanık tutacağım, dön bana!",
]
const COOK_MUTTER_WAR: Array[String] = [
	"Savaşanlara sıcak çorba lazım...", "Elim titriyor ama çorba yanmasın.", "Kepçeyi sıkı tut, korkma!",
	"Kazan dolu olsun, kim gelirse doysun.", "Aç kalan kahraman olmaz...",
]
## Ev saldırı altındayken + açılış depremi.
const WORRY_LINES: Array[String] = [
	"Duyuyor musun? Duvarlara vuruyorlar!", "Bu ev çok dayanmaz, çık savaş!", "Aman tavan! Tavan çöküyor!",
	"Canavarlar kapıya dayandı!", "Burada saklanarak kurtulamayız tatlım!", "Duvarlar çatlıyor, aman Tanrım!",
	"Kapı daha ne kadar dayanır bilmiyorum!", "Çık şunları kovala, yoksa içeri girecekler!",
	"Tozlar başıma yağıyor... çabuk ol!", "Bu evi dedenle birlikte yaptık, yıkılmasın!",
]
const QUAKE_LINES: Array[String] = ["Aman Tanrım! Deprem mi bu?!", "Yer sallanıyor! Bir yere tutunun!", "Bu ses de ne?! Herkes iyi mi?"]
const WINDOW_SPOT_LINES: Array[String] = [
	"Canavarlar! Adaya canavarlar saldırıyor!", "Kıyıda gölgeler var... canavarlar geliyor!", "Aman Tanrım, sahil canavar dolu!",
]
const WINDOW_URGE_LINES: Array[String] = [
	"Hadi çocuklar, çıkın savaşın! Ben evi beklerim.", "Silahlarınızı alın, adamızı koruyun!",
	"Gidin hadi! Ben burada ateşi yanık tutarım.",
]
const OUTSIDE_LINES: Array[String] = [
	"Evim... yıkıldı mı yoksa?", "Ben savaşamam, yanımdan ayrılmayın!", "Şu canavarlar evimi yerle bir etti!",
	"Duvarlar onarılana kadar burada beklerim.", "Bu yaşta kapı önünde kaldım, ne günlere kaldık!", "Elimde süpürge bile yok...",
]
const SCARED_LINES: Array[String] = ["İmdat! Çocuklar, yetişin!", "Uzak dur benden, yaratık!", "Yardım edin!", "Kurtarın beni!",
	"Hayır, hayır, gelme!"]
const HURT_LINES: Array[String] = ["Ahh!", "Aman!", "Of belim!", "Ay!", "Acıyor!"]
const BREATH_LINES: Array[String] = ["Of... nefesim kesildi!", "Bu yaşta koşulur mu...", "Dizlerim... az dur!", "Biraz... soluklanayım..."]
const DEATH_LINES: Array[String] = ["Ah... çocuklarım...", "Ateşi... yanık tutun..."]
const HOME_LINES: Array[String] = ["Evime dönüyorum, çorbayı ısıtayım!", "Ah evim, güzel evim!", "Duvarlar sağlam mı? Bir bakayım."]

enum Mode { ACTIVITY, GREET, FEED_WALK, FEED_GIVE, EMOTE, FAREWELL }

var mode: Mode = Mode.ACTIVITY
var activity: int = -1
var _interior: Node2D = null
var _walkable: Dictionary = {}
var _grid: AStarGrid2D = null
var _main_cells: Dictionary = {}
var _tile: Vector2 = Vector2(16.0, 16.0)
var _door_local: Vector2 = Vector2.ZERO
var _home_cell: Vector2i = Vector2i.ZERO

## Bulunan noktalar (iç mekan yereli)
var stir_spot: Dictionary = {}
var bed_origin: Vector2 = Vector2.INF
var seats: Array[Dictionary] = [] ## {"feet", "face", "approach", "kind": "fire"/"read"}
var wipe_spots: Array[Dictionary] = [] ## {"feet", "face"}

## Etkinlik içi durum
var _phase: String = "" ## "walk" / "slide" / "pose" / "stand"
var _target: Dictionary = {}
var _timer: float = 0.0
var _sub_timer: float = 0.0
var _wipe_i: int = -1
var _mutter_cd: float = 8.0
var _sleeping: bool = false
var _blanket: Sprite2D = null

## Sosyal
var _inside_ids: Dictionary = {} ## örnek kimliği -> true
var _fed_at: Dictionary = {} ## örnek kimliği -> GameManager.game_time (son çorba)
var _greet_queue: Array[Node2D] = []
var _social_target: Node2D = null
var _social_timer: float = 0.0
var _door_armed: Dictionary = {}
var _farewell_cd: float = 0.0
var _greeted_at: Dictionary = {} ## örnek kimliği -> GameManager.game_time (son selam / veda)
var _last_greet_at: float = -INF ## son ortak selamın zamanı (game_time), bkz. GREET_GROUP_WINDOW
var _feed_retry_at: Dictionary = {} ## örnek kimliği -> çorbayı götüremeyince yeniden deneme zamanı (game_time)
var _feed_scan_t: float = 0.0
var _since_said: float = INF
var said_count: int = 0 ## testler: söylenen söz sayısı
var last_said: String = "" ## testler: son söylenen cümle
var _talk_i: int = 0
var _clock_override: float = -1.0 ## testler: gün saati (döngü birimi)
var _day_override: int = -1

## Savaş / ev (madde 313)
var house: Node = null ## HouseInterior (get_siege / get_intro / window_spot / exterior_* için)
var chop_spot: Dictionary = {}
var window_feet: Vector2 = Vector2.INF ## pencerenin önü (iç mekan yereli), house_interior verir
var outside: bool = false
var is_dead: bool = false
var _out_home: Vector2 = Vector2.ZERO ## dışarıda durduğu yer (ebeveyn yereli)
var _going_home: bool = false
var _out_check: float = 0.0
var _scared: bool = false
var _emote_cd: float = 0.0
var _death_t: float = -1.0
var _hp_bar: Node2D = null
var _window_said: int = 0
var _calm_t: float = 0.0
var _siege_worry_t: float = 0.0 ## kuşatmada süren endişe anının kalanı
var _siege_next_worry: float = WORRY_FIRST
var _burst_t: float = 0.0
var _rest_t: float = 0.0
var _home_t: float = 0.0
var _window_t: float = 0.0


## house_interior.gd çağırır. interior: pişmiş iç mekan kökü (ebeveyn); walkable: zemin - çarpışma - çıkış kapısı hücreleri;
## home_feet: oyuncunun doğduğu nokta (açık zeminin tohumu); door_local: çıkış kapısının ortası.
func configure(interior: Node2D, walkable: Dictionary, tile: Vector2, home_feet: Vector2, door_local: Vector2) -> void:
	setup(FRAMES)
	name = "BabaanneNpc"
	_interior = interior
	_walkable = walkable
	_tile = tile
	_door_local = door_local
	_home_cell = cell_of(home_feet)
	_build_grid()
	_find_spots()
	_blanket = Sprite2D.new()
	_blanket.name = "BabaanneYorgan"
	_blanket.texture = BED_TEX
	_blanket.region_enabled = true
	_blanket.region_rect = BLANKET_REGION
	_blanket.centered = false
	_blanket.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_blanket.z_index = 1
	_blanket.visible = false
	if bed_origin.is_finite():
		_blanket.position = bed_origin + BLANKET_OFFSET
	interior.add_child(_blanket)
	if not arrived.is_connected(_on_arrived):
		arrived.connect(_on_arrived)
	set_feet(_center_of(_home_cell))
	_switch_activity(current_activity(), true)


# ------------------------------------------------------------------ program

## Gün saati -> iş (statik: testler ve her istemci aynı sonucu verir).
static func activity_at(t: float, day: int) -> int:
	t = fposmod(t, 600.0)
	if t >= 540.0 or t < 40.0:
		return Act.COOK ## kahvaltı
	if t < 100.0:
		return Act.WIPE
	if t < 170.0:
		return Act.READ
	if t < 230.0:
		return Act.COOK ## öğle
	if t < 290.0:
		return Act.FIRE_SIT if day % 2 == 0 else Act.WIPE
	if t < 330.0:
		return Act.READ
	if t < 390.0:
		return Act.COOK ## akşam yemeği
	if t < 450.0:
		return Act.FIRE_READ if day % 2 == 1 else Act.FIRE_SIT
	## gece yarısı: 3 gecenin 2'sinde uyur ("geceleri bazen uyuyacak"), birinde şöminenin başında okur
	return Act.FIRE_READ if day % 3 == 2 else Act.SLEEP


func clock() -> float:
	if _clock_override >= 0.0:
		return _clock_override
	var atmo: Node = get_tree().get_first_node_in_group("atmosphere") if is_inside_tree() else null
	if atmo != null and "cycle_time" in atmo:
		return float(atmo.get("cycle_time"))
	return 60.0


func day_index() -> int:
	if _day_override >= 0:
		return _day_override
	return int(floor(GameManager.game_time / DAY_SECONDS))


## Açılış evresi (deprem -> pencere) ve ev kuşatması programın önüne geçer (madde 313).
func current_activity() -> int:
	var intro: Node = _intro()
	if intro != null and bool(intro.call("is_active")):
		var e: float = float(intro.call("countdown_elapsed"))
		if e < 0.0:
			return Act.COOK ## huzur: mutfakta çorba
		if e < WINDOW_AT:
			return Act.WORRY
		if e < WINDOW_END and window_feet.is_finite():
			return Act.WINDOW
	var siege: HouseSiege = _siege()
	if siege != null and siege.under_attack and _siege_worry_t > 0.0:
		return Act.WORRY
	return activity_at(clock(), day_index())


## Kuşatma endişe anları (yerel saat): saldırı sürdükçe ara ara kısa endişe, gerisi iş.
func _tick_siege_worry(delta: float) -> void:
	var siege: HouseSiege = _siege()
	if siege == null or not siege.under_attack:
		_siege_worry_t = 0.0
		_siege_next_worry = WORRY_FIRST
		return
	if _siege_worry_t > 0.0:
		_siege_worry_t = maxf(0.0, _siege_worry_t - delta)
		return
	_siege_next_worry -= delta
	if _siege_next_worry <= 0.0:
		_siege_worry_t = WORRY_FOR
		_siege_next_worry = randf_range(WORRY_EVERY_MIN, WORRY_EVERY_MAX)


func _intro() -> Node:
	return house.call("get_intro") if house != null and is_instance_valid(house) and house.has_method("get_intro") else null


func _siege() -> HouseSiege:
	return house.call("get_siege") as HouseSiege if house != null and is_instance_valid(house) and house.has_method("get_siege") else null


## Canavarlar adaya saldırdı mı (replikler buna göre).
func at_war() -> bool:
	return not GameManager.invasion_pending


func _pick(peace: Array, war: Array) -> Variant:
	var pool: Array = war if at_war() else peace
	return pool[randi() % pool.size()]


func say(text: String) -> void:
	super.say(text)
	_since_said = 0.0
	said_count += 1
	last_said = text


## Kendiliğinden söz (bkz. CHAT_GAP): son sözden bu yana gap geçmediyse susar. Söylediyse true.
func _chat(text: String, gap: float = CHAT_GAP) -> bool:
	if _since_said < gap:
		return false
	say(text)
	return true


## Selam / veda: oyuncu GREET_COOLDOWN içinde selamlandıysa false; değilse zamanı yazar.
func _greet_due(p: Node2D) -> bool:
	var id: int = p.get_instance_id()
	var last: Variant = _greeted_at.get(id)
	if last != null and GameManager.game_time - float(last) < GREET_COOLDOWN:
		return false
	_greeted_at[id] = GameManager.game_time
	return true


# ------------------------------------------------------------------ eşya noktaları

func _find_spots() -> void:
	stir_spot = {}
	bed_origin = Vector2.INF
	seats.clear()
	wipe_spots.clear()
	if _interior == null:
		return
	var found: Dictionary = {} ## anahtar -> Array[Vector2] blok sol üstleri
	var sofas: Array = [] ## [origin, flipped]
	for child: Node in _interior.get_children():
		var layer := child as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		for c: Vector2i in layer.get_used_cells():
			var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
			if src == null or src.texture == null:
				continue
			var tex_name: String = src.texture.resource_path.get_file()
			var atlas: Vector2i = layer.get_cell_atlas_coords(c)
			var alt: int = layer.get_cell_alternative_tile(c)
			for key: String in ANCHORS:
				var a: Dictionary = ANCHORS[key]
				if tex_name == a["tex"] and atlas == a["atlas"] and alt == 0:
					if not found.has(key):
						found[key] = []
					found[key].append(layer.position + Vector2(c - Vector2i(a["rel"])) * _tile)
			if tex_name == SOFA_TEX and atlas == SOFA_ATLAS and alt == 0:
				sofas.append([layer.position + Vector2(c - Vector2i(0, 1)) * _tile, false])
			elif tex_name == SOFA_TEX and atlas == SOFA_ATLAS_FLIP and alt != 0:
				sofas.append([layer.position + Vector2(c - Vector2i(0, 1)) * _tile, true])
	if found.has("kazan"):
		var o: Vector2 = found["kazan"][0]
		stir_spot = {"feet": o + STIR_FEET, "face": "up"}
	chop_spot = {}
	if found.has("tezgah"):
		## kazana en yakın tezgah (mutfak tezgahı)
		var best: Vector2 = found["tezgah"][0]
		for o: Vector2 in found["tezgah"]:
			if not stir_spot.is_empty() and o.distance_to(stir_spot["feet"]) < best.distance_to(stir_spot["feet"]):
				best = o
		chop_spot = {"feet": best + CHOP_FEET, "face": "up"}
	if found.has("yatak"):
		bed_origin = found["yatak"][0]
	## Koltuklar: en aşağıdaki (y en büyük) okuma koltuğu, diğerleri şöminenin önü.
	sofas.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).y < (b[0] as Vector2).y)
	for i in sofas.size():
		var o: Vector2 = sofas[i][0]
		var flipped: bool = sofas[i][1]
		var feet: Vector2 = o + (SEAT_RIGHT if flipped else SEAT_LEFT)
		var face: String = "right" if flipped else "left"
		var side: Vector2 = o + (Vector2(30.0, 44.0) if flipped else Vector2(0.0, 44.0)) ## koltuğun bakış yönündeki açık hücre
		seats.append({"feet": feet, "face": face, "approach": _center_of(_nearest_in(_main_cells, cell_of(side))),
			"kind": "read" if i == sofas.size() - 1 and sofas.size() > 2 else "fire"})
	for key: String in WIPE_SIDES:
		if not found.has(key):
			continue
		for o: Vector2 in found[key]:
			var sides: Array = WIPE_SIDES[key]
			for si in sides.size():
				var p: Vector2 = o + (sides[si] as Vector2)
				if _main_cells.has(cell_of(p)):
					wipe_spots.append({"feet": p, "face": "right" if si == 0 else "left"})
					break


func seat_of_kind(kind: String, prefer_flipped: bool) -> Dictionary:
	var best: Dictionary = {}
	for s: Dictionary in seats:
		if s["kind"] != kind:
			continue
		if best.is_empty() or ((s["face"] == "right") == prefer_flipped):
			best = s
	return best


# ------------------------------------------------------------------ etkinlikler

func _switch_activity(act: int, snap: bool) -> void:
	_leave_pose()
	activity = act
	_target = _target_for(act)
	_timer = 0.0
	_sub_timer = 0.0
	if _target.is_empty():
		_phase = "pose"
		play_idle("down")
		return
	if snap or not _interior_visible():
		set_feet(_target["feet"])
		_start_pose()
		return
	_phase = "walk"
	var goal: Vector2 = _target.get("approach", _target["feet"])
	walk_path(path_to(goal))


func _target_for(act: int) -> Dictionary:
	match act:
		Act.COOK:
			if not stir_spot.is_empty():
				return {"feet": stir_spot["feet"], "face": "up", "pose": "stir"}
		Act.WIPE:
			if not wipe_spots.is_empty():
				_wipe_i = (_wipe_i + 1) % wipe_spots.size()
				var w: Dictionary = wipe_spots[_wipe_i]
				return {"feet": w["feet"], "face": w["face"], "pose": "wipe"}
		Act.READ:
			var s: Dictionary = seat_of_kind("read", false)
			if not s.is_empty():
				return {"feet": s["feet"], "face": s["face"], "approach": s["approach"], "pose": "sitread"}
		Act.FIRE_SIT, Act.FIRE_READ:
			var s: Dictionary = seat_of_kind("fire", day_index() % 2 == 0)
			if not s.is_empty():
				return {"feet": s["feet"], "face": s["face"], "approach": s["approach"],
					"pose": "sitread" if act == Act.FIRE_READ else "seated"}
		Act.SLEEP:
			if bed_origin.is_finite():
				return {"feet": bed_origin + SLEEP_FEET, "face": "down",
					"approach": _center_of(_nearest_in(_main_cells, cell_of(bed_origin + BED_FOOT))), "pose": "sleep"}
		Act.WORRY:
			## olduğu yerde (oturuyor/yatıyorsa kalkıp en yakın açık zeminde) işi bırakır
			var here: Vector2 = feet()
			if not _main_cells.has(cell_of(here)):
				here = _center_of(_nearest_in(_main_cells, cell_of(here)))
			return {"feet": here, "face": "down", "pose": "worry"}
		Act.WINDOW:
			if window_feet.is_finite():
				return {"feet": window_feet, "face": "up", "pose": "window"}
	return {}


func _on_arrived() -> void:
	match mode:
		Mode.ACTIVITY:
			if _phase == "walk":
				if _target.has("approach") and feet().distance_to(_target["feet"]) > 1.0:
					_phase = "slide"
					walk_path(PackedVector2Array([_target["feet"]]), SLOW_SPEED)
					if _target["pose"] == "sleep":
						sprite.modulate.a = 0.0 ## yorgana girerken ayakta görünmesin
					return
				_start_pose()
			elif _phase == "slide":
				_start_pose()
		Mode.FEED_WALK:
			pass


func _start_pose() -> void:
	_phase = "pose"
	sprite.modulate.a = 1.0
	if _target.is_empty():
		play_idle("down")
		return
	set_feet(_target["feet"])
	var pose: String = _target["pose"]
	var face: String = _target["face"]
	match pose:
		"seated", "sitread":
			lock_clip("sit", face) ## ayaktan oturmaya geçiş, sonra poz (_tick_pose)
			_sub_timer = 0.65
		"sleep":
			_sleeping = true
			lock_clip("sleep", "down")
			_blanket.visible = true
			## yatağın içinde yatıyor: derinlik ön kopyası (yatak = "ekstra") onu ve yorganı örtmesin (madde 313)
			remove_from_group(NpcActor.GROUP)
			_mutter_cd = randf_range(4.0, 8.0)
		"worry":
			lock_clip("think", face)
			_sub_timer = randf_range(2.0, 3.0)
			_mutter_cd = 0.0 ## hemen bir şey söyler
			_emote_cd = 0.0
		"window":
			lock_clip("", "up") ## pencereden dışarı bakar
			_window_t = 0.0
			_window_said = 0
		_:
			lock_clip(POSE_CLIP.get(pose, pose), face)
			_sub_timer = randf_range(5.0, 8.0)


func _leave_pose() -> void:
	if _sleeping:
		_sleeping = false
		_blanket.visible = false
		add_to_group(NpcActor.GROUP)
		if bed_origin.is_finite():
			set_feet(_center_of(_nearest_in(_main_cells, cell_of(bed_origin + BED_FOOT))))
	if sprite != null:
		sprite.modulate.a = 1.0
	unlock_clip()


## Aynı iş içinde kısa kayış (kazan <-> tezgah): yürüme klibiyle yavaşça, varınca poz.
func _go_to(t: Dictionary) -> void:
	_target = t
	unlock_clip()
	if not _interior_visible():
		set_feet(t["feet"])
		_start_pose()
		return
	_phase = "slide"
	walk_path(PackedVector2Array([t["feet"]]), SLOW_SPEED)


func is_sleeping() -> bool:
	return _sleeping


func is_seated() -> bool:
	var c: String = current_clip()
	return c.begins_with("seated_") or c.begins_with("sitread_") or c.begins_with("sit_")


func _tick_pose(delta: float, inside: bool) -> void:
	if _phase != "pose" or _target.is_empty():
		return
	var pose: String = _target["pose"]
	var face: String = _target["face"]
	_sub_timer -= delta
	_mutter_cd -= delta
	match pose:
		"seated", "sitread":
			if current_clip().begins_with("sit_") and _sub_timer <= 0.0:
				lock_clip(pose, face)
				_sub_timer = randf_range(12.0, 20.0)
			elif pose == "sitread" and _sub_timer <= 0.0:
				## sayfa arası kısa mola: kitabı indirip bakar
				lock_clip("seated" if current_clip().begins_with("sitread_") else "sitread", face)
				_sub_timer = randf_range(3.0, 5.0) if current_clip().begins_with("seated_") else randf_range(12.0, 20.0)
			if inside and _mutter_cd <= 0.0 and pose == "sitread":
				_chat(READ_MUTTER[randi() % READ_MUTTER.size()])
				_mutter_cd = randf_range(60.0, 120.0)
		"stir":
			if _sub_timer <= 0.0:
				if current_clip().begins_with("water_"):
					## karıştırdıktan sonra: ya tadına bakar ya da tezgaha geçip sebze doğrar (madde 313)
					if not chop_spot.is_empty() and randf() < 0.5:
						_go_to({"feet": chop_spot["feet"], "face": "up", "pose": "chop"})
						return
					lock_clip("eat", face) ## çorbanın tadına bakar
					_sub_timer = 2.2
				else:
					lock_clip(POSE_CLIP["stir"], face)
					_sub_timer = randf_range(6.0, 9.0)
			if inside and _mutter_cd <= 0.0:
				_chat(_pick(COOK_MUTTER, COOK_MUTTER_WAR))
				_mutter_cd = randf_range(60.0, 120.0)
		"chop":
			if _sub_timer <= 0.0 and activity == Act.COOK and not stir_spot.is_empty():
				_go_to({"feet": stir_spot["feet"], "face": "up", "pose": "stir"}) ## doğradığını kazana atar
				return
		"worry":
			if _sub_timer <= 0.0:
				## düşünür -> sağa sola bakınır -> omuz silker (kaygı döngüsü)
				var c: String = current_clip()
				if c.begins_with("think_"):
					lock_clip("", ["left", "right", "up"][randi() % 3])
					_sub_timer = randf_range(1.0, 1.8)
				elif c.begins_with("idle_"):
					lock_clip("shrug", "down")
					_sub_timer = 0.8
				else:
					lock_clip("think", "down")
					_sub_timer = randf_range(2.0, 3.0)
			_emote_cd -= delta
			if _emote_cd <= 0.0:
				FearEmoteScript.show_on(self, FearEmoteScript.KIND_FACE, 2.4)
				_emote_cd = randf_range(6.0, 9.0)
			if inside and _mutter_cd <= 0.0:
				var intro: Node = _intro()
				var quake: bool = intro != null and bool(intro.call("is_active"))
				if quake and _window_said == 0:
					say(QUAKE_LINES[randi() % QUAKE_LINES.size()]) ## açılış senaryosu: her zaman
					_window_said = 1
				else:
					_chat(WORRY_LINES[randi() % WORRY_LINES.size()])
				_mutter_cd = randf_range(5.0, 8.0)
		"window":
			_window_t += delta ## pencerede geçen süre
			if _window_said == 0 and _window_t >= WINDOW_SAY_1:
				_window_said = 1
				say(WINDOW_SPOT_LINES[randi() % WINDOW_SPOT_LINES.size()])
				FearEmoteScript.show_on(self, FearEmoteScript.KIND_ALERT, 2.2)
			elif _window_said == 1 and _window_t >= WINDOW_SAY_2:
				_window_said = 2
				lock_clip("wave", "down") ## oyunculara döner: "çıkın savaşın"
				say(WINDOW_URGE_LINES[randi() % WINDOW_URGE_LINES.size()])
			elif _window_said == 2 and _window_t >= WINDOW_SAY_2 + 1.6:
				_window_said = 3
				lock_clip("", "down")
		"wipe":
			if _sub_timer <= 0.0 and activity == Act.WIPE:
				_switch_activity(Act.WIPE, false) ## sıradaki rafa geç
				return
			if inside and _mutter_cd <= 0.0:
				_chat(WIPE_MUTTER[randi() % WIPE_MUTTER.size()])
				_mutter_cd = randf_range(60.0, 120.0)
		"sleep":
			if inside and _mutter_cd <= 0.0:
				_chat("Zzz...")
				_mutter_cd = randf_range(30.0, 45.0)


# ------------------------------------------------------------------ davranış

func _behave(delta: float) -> void:
	_since_said += delta
	if is_dead:
		_tick_dead(delta)
		return
	if outside:
		_behave_outside(delta)
		return
	_farewell_cd = maxf(0.0, _farewell_cd - delta)
	_tick_siege_worry(delta)
	var inside: Array[Node2D] = _players_inside()
	_track_entries(inside)
	match mode:
		Mode.ACTIVITY:
			var want: int = current_activity()
			if want != activity:
				_switch_activity(want, false)
			_tick_pose(delta, not inside.is_empty())
			if not _sleeping and not _greet_queue.is_empty():
				## sıradaki herkes TEK ortak cümleyle karşılanır (madde 328)
				var group: Array[Node2D] = []
				for g: Node2D in _greet_queue:
					if is_instance_valid(g) and _greet_due(g):
						group.append(g)
				_greet_queue.clear()
				if not group.is_empty():
					_start_greet(group)
			if mode == Mode.ACTIVITY and not _sleeping:
				_feed_scan_t -= delta
				if _feed_scan_t <= 0.0:
					_feed_scan_t = FEED_SCAN
					var hungry: Node2D = _hungry_player(inside)
					if hungry != null:
						_start_feed_walk(hungry)
			if mode == Mode.ACTIVITY:
				_check_farewell(inside)
		Mode.GREET:
			_social_timer -= delta
			if is_instance_valid(_social_target) and not is_seated():
				face_point(_to_local_feet(_social_target))
			if _social_timer <= 0.0:
				if _wants_food(_social_target):
					_start_feed_walk(_social_target)
				else:
					_resume()
		Mode.FEED_WALK:
			_social_timer -= delta
			if not is_instance_valid(_social_target) or _social_timer <= 0.0 or not _is_inside(_social_target):
				if is_instance_valid(_social_target):
					_feed_retry_at[_social_target.get_instance_id()] = GameManager.game_time + FEED_RETRY
				_resume()
				return
			var tp: Vector2 = _to_local_feet(_social_target)
			if feet().distance_to(tp) <= FEED_REACH:
				_give_food(_social_target)
			elif not is_walking() or _target.get("chase", Vector2.INF).distance_to(tp) > 14.0:
				_target["chase"] = tp
				walk_path(path_to(tp))
		Mode.FEED_GIVE, Mode.EMOTE, Mode.FAREWELL:
			_social_timer -= delta
			if is_instance_valid(_social_target) and not is_seated() and not _sleeping:
				face_point(_to_local_feet(_social_target))
			if _social_timer <= 0.0:
				_resume()


func _track_entries(inside: Array[Node2D]) -> void:
	var live: Dictionary = {}
	for p: Node2D in inside:
		var id: int = p.get_instance_id()
		live[id] = true
		if not _inside_ids.has(id):
			_inside_ids[id] = true
			_door_armed[id] = false
			if GameManager.game_time - _last_greet_at < GREET_GROUP_WINDOW:
				_greeted_at[id] = GameManager.game_time ## az önceki ortak selam onu da kapsar: ayrı cümle yok
			elif not _greet_queue.has(p):
				_greet_queue.append(p)
	for id in _inside_ids.keys():
		if not live.has(id):
			_inside_ids.erase(id)
			_door_armed.erase(id)
	var keep: Array[Node2D] = []
	for p: Node2D in _greet_queue:
		if is_instance_valid(p) and live.has(p.get_instance_id()):
			keep.append(p)
	_greet_queue = keep


## group: aynı cümleyle karşılanan herkes (ilki yüzüne dönülen); birden çoksa çoğul hitaplı havuzdan.
func _start_greet(group: Array[Node2D]) -> void:
	if group.is_empty() or not is_instance_valid(group[0]):
		return
	var p: Node2D = group[0]
	mode = Mode.GREET
	_social_target = p
	_social_timer = GREET_TIME
	_last_greet_at = GameManager.game_time
	if group.size() > 1:
		say(_pick(GREETINGS_GROUP, GREETINGS_GROUP_WAR))
	else:
		say(_pick(GREETINGS, GREETINGS_WAR))
	if not is_seated():
		stop_walking()
		face_point(_to_local_feet(p))
		lock_clip("wave", facing)


func _wants_food(p: Node2D) -> bool:
	if not is_instance_valid(p) or p.get("is_dead") == true or p.get("is_downed") == true:
		return false
	var hp: Variant = p.get("health")
	var mx: Variant = p.get("max_health")
	if hp == null or mx == null or float(mx) <= 0.0 or float(hp) >= float(mx) * FEED_BELOW:
		return false
	if GameManager.game_time < float(_feed_retry_at.get(p.get_instance_id(), -INF)):
		return false
	return feed_ready(p)


## İçerideki, çorba isteyen (bkz. _wants_food) en düşük canlı oyuncu; yoksa null.
func _hungry_player(inside: Array[Node2D]) -> Node2D:
	var best: Node2D = null
	var best_r: float = INF
	for p: Node2D in inside:
		if not _wants_food(p):
			continue
		var r: float = float(p.get("health")) / maxf(float(p.get("max_health")), 1.0)
		if r < best_r:
			best_r = r
			best = p
	return best


func feed_ready(p: Node2D) -> bool:
	var last: Variant = _fed_at.get(p.get_instance_id())
	return last == null or GameManager.game_time - float(last) >= FEED_COOLDOWN


func _start_feed_walk(p: Node2D) -> void:
	mode = Mode.FEED_WALK
	_social_target = p
	_social_timer = FEED_GIVE_UP
	_leave_pose()
	_phase = ""
	_target = {"chase": Vector2.INF}
	walk_path(path_to(_to_local_feet(p)))


func _give_food(p: Node2D) -> void:
	mode = Mode.FEED_GIVE
	_social_timer = 1.6
	stop_walking()
	face_point(_to_local_feet(p))
	unlock_clip()
	say(_pick(FEED_LINES, FEED_LINES + FEED_LINES_WAR))
	_fed_at[p.get_instance_id()] = GameManager.game_time
	_fly_bowl(p)


## Kâse büyükannenin elinden oyuncuya uçar; varınca YALNIZ yerel oyuncunun kendi istemcisinde can verilir (uzaktakiler kendi ekranında).
func _fly_bowl(p: Node2D) -> void:
	var bowl := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = AVCI_TEX
	at.region = BOWL_REGION
	bowl.texture = at
	bowl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bowl.z_index = 2
	var parent: Node2D = get_parent() as Node2D
	parent.add_child(bowl)
	bowl.position = feet() + Vector2(0.0, -18.0)
	var end: Vector2 = _to_local_feet(p) + Vector2(0.0, -26.0)
	var tw: Tween = bowl.create_tween()
	tw.tween_property(bowl, "position", (bowl.position + end) * 0.5 + Vector2(0.0, -10.0), 0.22)
	tw.tween_property(bowl, "position", end, 0.22)
	tw.tween_callback(func() -> void:
		bowl.queue_free()
		_feed_arrived(p))


func _feed_arrived(p: Node2D) -> void:
	if not is_instance_valid(p) or not p.is_in_group("player") or p.get("is_dead") == true:
		return
	if p.has_method("on_food_picked_up"):
		p.call("on_food_picked_up")
	if p.has_method("heal"):
		p.call("heal", float(p.get("max_health")) * FEED_HEAL_PERCENT, false, &"babaanne")


func _resume() -> void:
	mode = Mode.ACTIVITY
	_social_target = null
	unlock_clip()
	_switch_activity(current_activity(), false)


## house_interior.gd: etkileşim ipucu gösterilsin mi.
func can_talk(p: Node2D) -> bool:
	if not is_instance_valid(p) or outside or is_dead or not _interior_visible() or mode == Mode.FEED_WALK:
		return false
	return (p.global_position - global_position).length() <= TALK_RADIUS


## Etkileşim tuşu: bağlama göre bir cümle (+ ayaktaysa duygu klibi). Uyurken uykulu cevap.
func talk(p: Node2D) -> String:
	var line: String
	var clip: String = ""
	if _sleeping:
		line = SLEEP_TALK[_talk_i % SLEEP_TALK.size()]
	else:
		var hp: Variant = p.get("health")
		var mx: Variant = p.get("max_health")
		var low: bool = hp != null and mx != null and float(mx) > 0.0 and float(hp) < float(mx) * 0.4
		var night: bool = AtmosphereMath.darkness(clock()) > 0.6
		if low and feed_ready(p) and mode == Mode.ACTIVITY:
			say(TALK_LOW_HP[_talk_i % TALK_LOW_HP.size()])
			_talk_i += 1
			_start_feed_walk(p)
			return TALK_LOW_HP[(_talk_i - 1) % TALK_LOW_HP.size()]
		elif low:
			line = TALK_LOW_HP[_talk_i % TALK_LOW_HP.size()]
		elif night and _talk_i % 3 == 0:
			var nights: Array[String] = TALK_NIGHT_WAR if at_war() else TALK_NIGHT
			line = nights[floori(_talk_i / 3.0) % nights.size()]
		elif _talk_i % 3 == 1:
			var emotes: Array = TALK_EMOTE_WAR if at_war() else TALK_EMOTE
			var e: Array = emotes[floori(_talk_i / 3.0) % emotes.size()]
			line = e[0]
			clip = e[1]
		else:
			var lines: Array[String] = TALK_WAR if at_war() else TALK_LINES
			line = lines[_talk_i % lines.size()]
	_talk_i += 1
	say(line)
	if not _sleeping:
		mode = Mode.EMOTE
		_social_target = p
		_social_timer = EMOTE_TIME
		if not is_seated():
			stop_walking()
			face_point(_to_local_feet(p))
			if clip != "":
				lock_clip(clip, facing)
	return line


func _check_farewell(inside: Array[Node2D]) -> void:
	for p: Node2D in inside:
		var id: int = p.get_instance_id()
		var d: float = (p.global_position - get_parent().to_global(_door_local)).length()
		if d > DOOR_ARM_DISTANCE:
			_door_armed[id] = true
		elif d < DOOR_NEAR_DISTANCE and _door_armed.get(id, false) and _farewell_cd <= 0.0:
			_door_armed[id] = false
			_farewell_cd = FAREWELL_COOLDOWN
			## kapıya yakın herkes için TEK ortak veda (madde 328): hepsi vedalaşılmış sayılır
			var leaving: Array[Node2D] = []
			for q: Node2D in inside:
				if q == p or (q.global_position - get_parent().to_global(_door_local)).length() < DOOR_ARM_DISTANCE:
					leaving.append(q)
			if _sleeping or not _greet_due(p):
				return
			var farewell: String = _pick(FAREWELLS_GROUP, FAREWELLS_GROUP_WAR) if leaving.size() > 1 else _pick(FAREWELLS, FAREWELLS_WAR)
			if not _chat(farewell):
				return
			for q: Node2D in leaving:
				_greeted_at[q.get_instance_id()] = GameManager.game_time
			if not is_seated() and _phase == "pose":
				mode = Mode.FAREWELL
				_social_target = p
				_social_timer = 1.6
				lock_clip("wave", facing)
				face_point(_to_local_feet(p))
			return


# ------------------------------------------------------------------ yol bulma (BlacksmithNpc ile aynı yaklaşım)

func _build_grid() -> void:
	if _walkable.is_empty():
		_grid = null
		return
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for c: Vector2i in _walkable:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(lo, hi - lo + Vector2i.ONE)
	_grid.cell_size = _tile
	_grid.offset = _tile * 0.5
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			if not _walkable.has(Vector2i(x, y)):
				_grid.set_point_solid(Vector2i(x, y), true)
	_home_cell = _nearest_in(_walkable, _home_cell)
	_main_cells = _flood_from(_home_cell)


func _flood_from(start: Vector2i) -> Dictionary:
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var n := Vector2i(c.x + dx, c.y + dy)
				if seen.has(n) or not _walkable.has(n):
					continue
				if dx != 0 and dy != 0 and (not _walkable.has(Vector2i(c.x + dx, c.y)) or not _walkable.has(Vector2i(c.x, c.y + dy))):
					continue
				seen[n] = true
				queue.append(n)
	return seen


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / _tile.x), floori(p.y / _tile.y))


func _center_of(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * _tile


func _nearest_in(cells: Dictionary, c: Vector2i) -> Vector2i:
	if cells.has(c):
		return c
	var best: Vector2i = c
	var best_d: int = 1 << 30
	for w: Vector2i in cells:
		var d: int = (w - c).length_squared()
		if d < best_d:
			best_d = d
			best = w
	return best


func is_open(p: Vector2) -> bool:
	return _main_cells.has(cell_of(p))


## Ayak noktasından hedefe; açık zemin dışındaki başlangıç/hedef (koltuk, yatak) en yakın açık hücreden düz adımla.
func path_to(target: Vector2) -> PackedVector2Array:
	if _grid == null:
		return PackedVector2Array([target])
	var out := PackedVector2Array()
	var here: Vector2 = feet()
	var start: Vector2i = cell_of(here)
	if not _main_cells.has(start):
		start = _nearest_in(_main_cells, start)
		out.append(_center_of(start))
	var tc: Vector2i = _nearest_in(_main_cells, cell_of(target))
	var pts: PackedVector2Array = _grid.get_point_path(start, tc)
	for i in range(1, pts.size()):
		out.append(pts[i])
	if out.is_empty() or out[out.size() - 1].distance_to(target) > 0.5:
		out.append(target)
	return out


# ------------------------------------------------------------------ yardımcılar

func _interior_visible() -> bool:
	var p: Node = get_parent()
	return p is CanvasItem and (p as CanvasItem).is_visible_in_tree()


func _is_inside(p: Node2D) -> bool:
	var origin: Vector2 = (get_parent() as Node2D).global_position
	return is_instance_valid(p) and p.global_position.distance_to(origin) < INSIDE_RADIUS


func _players_inside() -> Array[Node2D]:
	var out: Array[Node2D] = []
	if not is_inside_tree():
		return out
	for p: Node2D in NpcActor.live_players(get_tree()):
		if _is_inside(p):
			out.append(p)
	return out


func _to_local_feet(p: Node2D) -> Vector2:
	return get_parent().to_local(p.global_position) + Vector2(0.0, FEET_OFFSET)


# ------------------------------------------------------------------ dışarıda (ev yıkıldı, madde 313)

## house_interior.gd: ev yıkıldı -> dünya düğümüne (oyuncularla aynı ebeveyn) taşınır, kapının yanında durur. Yaratıklar artık
## onu da hedefler (GameManager.babaanne_target; host'ta vurulur -> HouseSiege.granny_damage).
func go_outside(world_parent: Node2D, feet_world: Vector2) -> void:
	if is_dead or outside:
		return
	_leave_pose()
	stop_walking()
	mode = Mode.ACTIVITY
	_social_target = null
	_greet_queue.clear()
	outside = true
	_going_home = false
	_scared = false
	_calm_t = 0.0
	_out_check = 0.0
	_mutter_cd = 1.5
	_emote_cd = 0.0
	get_parent().remove_child(self)
	world_parent.add_child(self)
	_out_home = world_parent.to_local(feet_world)
	set_feet(_out_home)
	lock_clip("", "down")
	GameManager.babaanne_target = self
	_ensure_hp_bar()
	_hp_bar.visible = true
	FearEmoteScript.show_on(self, FearEmoteScript.KIND_FACE, 3.0, 0.0, OUT_EMOTE_RAISE)


## Ev onarıldı: kapıya yürür, içeri girer (iç mekanda kapının önünden işine döner).
func come_home(entrance_world: Vector2) -> void:
	if is_dead or not outside:
		return
	_going_home = true
	_home_t = 0.0
	GameManager.babaanne_target = null ## eve yönelen babaanneyi yaratıklar bırakır
	if _hp_bar != null:
		_hp_bar.visible = false
	_chat(HOME_LINES[randi() % HOME_LINES.size()], HURT_GAP)
	var pts := PackedVector2Array()
	if feet().distance_to(_out_home) > 60.0:
		pts.append(_out_home) ## kaçıp uzaklaştıysa önce evin önüne
	pts.append(get_parent().to_local(entrance_world))
	walk_path(pts)


func _enter_home() -> void:
	_going_home = false
	outside = false
	get_parent().remove_child(self)
	_interior.add_child(self)
	set_feet(_center_of(_nearest_in(_main_cells, cell_of(_door_local + Vector2(0.0, -20.0)))))
	_resume()


func _behave_outside(delta: float) -> void:
	if _going_home:
		_home_t += delta
		if not is_walking() or _home_t >= HOME_TIMEOUT:
			_enter_home()
		return
	_mutter_cd -= delta
	_emote_cd -= delta
	var siege: HouseSiege = _siege()
	if siege == null or siege.is_authority():
		_flee_think(delta)
	else:
		_follow_net(delta, siege)
	if not is_walking():
		if _scared and not current_clip().begins_with("wave_"):
			lock_clip("wave", facing) ## köşeye sıkıştı / duruyor: imdat diye el sallar
		elif not _scared and current_clip().begins_with("wave_"):
			lock_clip("", "down")
	if _mutter_cd <= 0.0:
		if _scared:
			_chat(SCARED_LINES[randi() % SCARED_LINES.size()], HURT_GAP) ## kovalanırken imdat: kısa aralıkla
		else:
			_chat(OUTSIDE_LINES[randi() % OUTSIDE_LINES.size()])
		_mutter_cd = randf_range(8.0, 12.0) if _scared else randf_range(30.0, 45.0)
	if _scared and _emote_cd <= 0.0:
		FearEmoteScript.show_on(self, FearEmoteScript.KIND_ALERT, 2.0, 0.0, OUT_EMOTE_RAISE)
		_emote_cd = randf_range(5.0, 7.0)


## Ayak noktası dünya koordinatında (dışarıdayken ebeveyn Main).
func feet_world() -> Vector2:
	return get_parent().to_global(feet()) if get_parent() is Node2D else feet()


## Host: yaratıklardan uzaklaş + en yakın oyuncuya çekil; sakinleşince evin önüne dön.
func _flee_think(delta: float) -> void:
	if _rest_t > 0.0:
		_rest_t -= delta ## soluklanıyor: yerinde durur (yaratıklar yetişebilir)
		return
	if is_walking() and _scared:
		_burst_t += delta
		if _burst_t >= FLEE_BURST:
			_burst_t = 0.0
			_rest_t = FLEE_REST
			stop_walking()
			if randf() < 0.3 and _chat(BREATH_LINES[randi() % BREATH_LINES.size()], HURT_GAP):
				_mutter_cd = maxf(_mutter_cd, 3.0)
			return
	_out_check -= delta
	if _out_check > 0.0:
		return
	_out_check = FLEE_REPLAN
	var here: Vector2 = feet_world()
	var away := Vector2.ZERO
	var n: int = 0
	if is_inside_tree():
		for e: Node in EnemyQueryScript.candidates(get_tree(), here, FLEE_RADIUS):
			if not is_instance_valid(e) or e.get("is_dead") == true or not (e is Node2D):
				continue
			var d: Vector2 = here - (e as Node2D).global_position
			var dist: float = d.length()
			if dist >= FLEE_RADIUS:
				continue
			away += (d / maxf(dist, 1.0)) * (1.2 - dist / FLEE_RADIUS) ## yakındaki daha çok iter
			n += 1
	_scared = n > 0
	if not _scared:
		_calm_t += FLEE_REPLAN
		var home: Vector2 = get_parent().to_global(_out_home)
		if _calm_t >= CALM_RETURN and here.distance_to(home) > 12.0:
			var step: Vector2 = free_step(here, (home - here).normalized(), minf(FLEE_STEP, here.distance_to(home)))
			if step.is_finite():
				walk_path(PackedVector2Array([get_parent().to_local(step)]))
		return
	_calm_t = 0.0
	var dir: Vector2 = away.normalized() if away.length() > 0.001 else Vector2.DOWN
	var mate: Node2D = _nearest_outdoor_player(here)
	if mate != null:
		dir = (dir + (mate.global_position - here).normalized() * PLAYER_PULL).normalized()
	var target: Vector2 = free_step(here, dir, FLEE_STEP)
	if target.is_finite():
		walk_path(PackedVector2Array([get_parent().to_local(target)]), FLEE_SPEED)
	else:
		stop_walking() ## köşeye sıkıştı


## İstemci: host'un gönderdiği konuma yürür (uzaksa ışınlanır); korku/replikler yerel (kozmetik).
func _follow_net(delta: float, siege: HouseSiege) -> void:
	_out_check -= delta
	if _out_check <= 0.0:
		_out_check = 0.4
		_scared = _nearest_foe() != null
	var p: Vector2 = siege.granny_net_pos
	if not p.is_finite():
		return
	var target: Vector2 = get_parent().to_local(p)
	var d: float = feet().distance_to(target)
	if d > NET_SNAP:
		set_feet(target)
		stop_walking()
	elif d > 1.5:
		walk_path(PackedVector2Array([target]), maxf(FLEE_SPEED, d * 3.0))


## here'dan dir yönünde len kadar ötede duvar/su/bina olmayan nokta (yön ±30/60/90/135° döndürülerek); yoksa INF.
static func free_step(here: Vector2, dir: Vector2, length: float) -> Vector2:
	for deg in [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 135.0, -135.0]:
		var v: Vector2 = dir.rotated(deg_to_rad(deg)) * length
		var p: Vector2 = here + v
		if not GameManager.is_position_blocked_by_walls(p) and not GameManager.is_position_blocked_by_walls(here + v * 0.5):
			return p
	return Vector2.INF


func _nearest_outdoor_player(here: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d: float = PLAYER_PULL_RANGE
	if not is_inside_tree():
		return null
	for p: Node2D in NpcActor.live_players(get_tree()):
		if p.get("is_downed") == true or p.get("is_indoors") == true:
			continue
		var d: float = p.global_position.distance_to(here)
		if d < best_d:
			best_d = d
			best = p
	return best


func _nearest_foe() -> Node2D:
	if not is_inside_tree():
		return null
	var best: Node2D = null
	var best_d: float = OUT_SCARED_RADIUS
	for e: Node in EnemyQueryScript.candidates(get_tree(), global_position, OUT_SCARED_RADIUS):
		if not is_instance_valid(e) or e.get("is_dead") == true or not (e is Node2D):
			continue
		var d: float = (e as Node2D).global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e as Node2D
	return best


## Yaratık vuruşu (enemy.gd _schedule_melee_hit / enemy_projectile.gd / yetenekler - yalnız host'ta gerçek). Can HouseSiege'te.
func take_damage(amount: float, _source: Node = null) -> void:
	if is_dead or not outside:
		return
	var siege: HouseSiege = _siege()
	if siege != null:
		siege.granny_damage(amount)


## Her peer: can değişti (HouseSiege.granny_hp_changed -> house_interior.gd). Düşüşte kırmızı parlama + "Ahh!", ölümde kalıcı ölüm.
func on_hp_changed(hp: float, dead: bool) -> void:
	_ensure_hp_bar()
	var prev: float = float(_hp_bar.get_meta("hp", HouseSiege.GRANNY_MAX_HP))
	_hp_bar.set_meta("hp", hp)
	_hp_bar.queue_redraw()
	if hp < prev and sprite != null:
		sprite.modulate = Color(1.0, 0.45, 0.4)
		var tw: Tween = sprite.create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.18)
		if randf() < 0.35 and not dead:
			_chat(HURT_LINES[randi() % HURT_LINES.size()], HURT_GAP)
	if dead:
		die()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	GameManager.babaanne_target = null
	stop_walking()
	if _hp_bar != null:
		_hp_bar.visible = false
	say(DEATH_LINES[randi() % DEATH_LINES.size()])
	lock_clip("death", "down" if facing == "up" else facing)
	_death_t = 0.0


func _tick_dead(delta: float) -> void:
	if _death_t < 0.0:
		return
	_death_t += delta
	if _death_t >= DEATH_FADE_AFTER:
		modulate.a = maxf(0.0, 1.0 - (_death_t - DEATH_FADE_AFTER) / 2.0)
		if modulate.a <= 0.0:
			visible = false
			set_process(false)


## Dışarıdayken başının üstünde küçük can çubuğu (piksel kenarlı, yalnız can değişince yeniden çizilir).
func _ensure_hp_bar() -> void:
	if _hp_bar != null:
		return
	_hp_bar = Node2D.new()
	_hp_bar.name = "BabaanneCan"
	_hp_bar.set_script(HpBarScript)
	_hp_bar.position = Vector2(0.0, -66.0) ## saç topuzunun üstünde
	_hp_bar.z_index = 30
	_hp_bar.z_as_relative = false
	_hp_bar.visible = false
	_hp_bar.set_meta("hp", HouseSiege.GRANNY_MAX_HP)
	add_child(_hp_bar)


const HpBarScript := preload("res://scripts/babaanne_hp_bar.gd")
