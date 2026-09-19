extends CharacterBody2D

## Characters 1-6's active skill always lasted 10s with a 20s total cooldown.
## Öykü/Talha/Matthew (7-9) each need their own numbers instead, so the fixed
## duration/cooldown became per-character - see _skill_duration/_skill_cooldown
## and _skill_timing_for(). DEFAULT_* keeps 1-6 behaving exactly as before.
const DEFAULT_SKILL_DURATION := 10.0
const DEFAULT_SKILL_COOLDOWN := 20.0
const SKILL_TIMING := {
	## Oakley ULTİ (Can Basma): anında %15 can + sonraki 6sn boyunca saniyede
	## bir kendine/müttefikine can yenileyen tik (bkz. _skill_heal/
	## _process_healer_heal_tick).
	1: {"duration": 6.0, "cooldown": 20.0},
	7: {"duration": 6.0, "cooldown": 60.0}, ## artık kullanılmıyor (eski _skill_heal_aura eşlemesi) ama zararsız
	## #56 DÜZELTME: id 8 (100sn bekleme) eski bir ULTİ zamanlaması kalıntısıydı
	## - Yer Sarsıntısı artık Talon'un TEMEL'i (bkz. SKILL2_TIMING[8], 20sn
	## bekleme), hiçbir karakterin ULTİ'si id 8 değil, bu kayıt kaldırıldı.
	## eski Talon ULTİ (Devleşme, skill id 15) - kullanıcı isteğiyle ("Talon
	## yeni skilleri") TAMAMEN yeni bir kitle değiştirildi, bkz. id 38 (Ayna
	## Formu) aşağıda. Kayıt zararsız olduğu için siliniyor, sadece not
	## bırakılıyor (bkz. bu dosyadaki AYNI desen, ör. id 7).
	15: {"duration": 15.0, "cooldown": 120.0}, ## artık kullanılmıyor (eski Devleşme) ama zararsız
	## Talon ULTİ (Hamle Vuruşu, skill id 38) - kullanıcı isteği: "R ile Q'nun
	## yerini değiştir" (eskiden Ayna Formu buradaydı, bkz. SKILL3_TIMING[37]
	## şimdi orada). "duration" Elara'nın Kalkan Sıçraması'yla (id 31) AYNI
	## desen - sadece kısa hamle penceresi, gerçek kısıt 4sn bekleme.
	38: {"duration": 0.16, "cooldown": 4.0},
	9: {"duration": 15.0, "cooldown": 120.0}, ## Matthew: up to 15s shield dome
	## Şovalye (Paladin): Koruma Baloncuğu - sabit bir süresi YOK, kalkanı
	## (item_shield_hp) tükenene kadar sürer (bkz. _process_paladin_ulti).
	## "duration" burada sadece bir güvenlik tavanı - normal şartlarda hiç
	## dolmaz çünkü _process_paladin_ulti kalkan biter bitmez becerinin
	## kendisini erken bitirip cooldown'a sokuyor.
	## Kullanıcı isteği: bekleme süresi 120sn'ye düşürüldü (eskiden 180sn).
	11: {"duration": 60.0, "cooldown": 120.0},
	## DÜZELTME (kullanıcı isteği: "Elaranın R ile Q yeteneğinin yerini
	## değiştir") - eskiden Çift Tetik buradaydı (bkz. SKILL3_TIMING[31]
	## şimdi orada), id 12 artık Kalkan Sıçraması'nın (bkz. player.gd
	## _skill_elara_dash_refill) yeni evi - "duration" Talon'un Hamle
	## Vuruşu'yla (id 38) AYNI desen, sadece kısa hamle penceresi.
	12: {"duration": 0.12, "cooldown": 6.0},
	## Kurt Adam ULTİ: Kudurmuş Saldırı - kontrolsüz otomatik saldırı (bkz.
	## _skill_kurtadam_berserk/_kurtadam_berserk_direction). DÜZELTME
	## (kullanıcı isteği #45: "kurt adam ultisi sonsuza kadar sürüyor 20
	## saniye sürmesi gerekirdi") - 30 -> 20. Not: bu değer zaten SABİT/SONLU
	## idi (Şovalye'nin aksine erken-bitiş koşulu yok) - "sonsuza kadar
	## sürüyor" hissi muhtemelen _kurtadam_berserk_direction()'daki menzil
	## hesabı bug'ından (aşağıda düzeltildi) kaynaklanıyordu; karakter hedefe
	## hiç yaklaşamadığı için beceri "hiç işe yaramıyor/bitmiyor" gibi
	## görünüyor olabilirdi.
	14: {"duration": 20.0, "cooldown": 90.0},
	## DÜZELTME (kullanıcı bildirimi: "assasin çocuğun Q'su oakleyin Q su gibi
	## çalışıyor"): Assasin Çocuk'un ULTİ'si (Gölge Hücumu) eskiden id 5'ti,
	## characters.gd'de "skill": 16 olarak güncellendi (bkz. o dosyadaki
	## yorum) ama bu zamanlama kaydı 5'te unutulmuştu - _skill_timing_for(16)
	## bunu bulamayıp varsayılana (10sn/20sn) düşüyordu. Artık doğru id'de.
	## SONRAKİ DÜZELTME (kullanıcı isteği: "Assasin çocuğun R si ile Q
	## skillinin yerini değiştir") - Gölge Hücumu artık R/skill3'te, bu
	## kayıt SKILL3_TIMING[16]'ya taşındı (bkz. aşağısı), Gölge Adımı'nın
	## (id 30) eski SKILL3_TIMING kaydı da buraya taşındı.
	30: {"duration": 6.0, "cooldown": 60.0},
	## Korsan ULTİ (Patlat, skill id 18): bırakılmış tüm bombaları anında
	## patlatır - "duration" sadece kısa bir görsel/güvenlik penceresi,
	## gerçek kısıt bekleme süresi (bkz. _skill_korsan_detonate_all).
	## #39 DÜZELTME: 30sn -> 20sn (bomba şarj yenilenmesi de hızlandırıldığı
	## için ulti artık daha sık, daha tatmin edici kullanılabiliyor - bkz.
	## KORSAN_BOMB_RECHARGE_TIME).
	18: {"duration": 0.4, "cooldown": 20.0},
	## DÜZELTME (kullanıcı isteği: "Necromancer in R sini golem çıkarma ile
	## değiştir") - Golem Çağır (id 20) artık R/skill3'te, bu kayıt
	## SKILL3_TIMING[20]'ye taşındı (bkz. aşağısı).
	## Büyücü Kız ULTİ (Büyü Değişimi, skill id 3): kullanıcı isteğiyle eski
	## "Hızlı Ateş" (10sn saldırı hızı buff'ı) TAMAMEN kaldırıldı - artık
	## sadece TEMEL yeteneğin 4 varyasyonu arasında sırayla geçiş yapıyor
	## (bkz. _skill_buyucu_switch_variation, BUYUCU_VARIATION_NAMES). Anlık
	## bir aksiyon olduğu için "duration" sadece kısa bir görsel pencere,
	## kısa "cooldown" ise ULTİ'ye basılı tutup varyasyonları spam'lemeyi
	## önlüyor.
	3: {"duration": 0.25, "cooldown": 1.0},
	## DÜZELTME: Shaman ULTİ (Kalkan Totemi, skill id 26) - bu kayıt eksikti,
	## _skill_timing_for(26) varsayılana (10sn/20sn) düşüyordu, yani totem
	## 60sn değil 20sn'de bir tekrar dikilebiliyordu.
	## DÜZELTME (kullanıcı isteği: "totem bıraktığında yetenek aktifmiş gibi
	## görünmesin, karakterden bağımsız oldukları için gerek yok, skiller
	## direk bekleme süresine girsin") - "duration" artık totemin ömrünü
	## TAKLİT ETMİYOR (eski tasarım: HUD ilerleme halkasını totemle senkron
	## tutmak içindi); atıldığı an zaten cooldown'a geçtiği için (bkz.
	## _enter_shaman_totem_cooldown) bu değer artık hiç kullanılmıyor, 0
	## bırakıldı. Bekleme süresi de 60 -> 45sn (kullanıcı isteği).
	26: {"duration": 0.0, "cooldown": 45.0},
	## DÜZELTME (kullanıcı isteği: "Oakleyin R yeteneği artık boşta kalan Q
	## yeteneği olacak") - Arı Sürüsü (skill id 33): eskiden SKILL3_TIMING[33]
	## idi (R iken), "Bulunduğu konuma 10sn süren bir arı sürüsü salar", 20sn
	## bekleme - sayılar DEĞİŞMEDİ, sadece taşındı.
	33: {"duration": 10.0, "cooldown": 20.0},
}
var _skill_duration: float = DEFAULT_SKILL_DURATION
var _skill_cooldown: float = DEFAULT_SKILL_COOLDOWN

## İkinci (temel) yetenek slotu - şimdilik sadece Oakley kullanıyor ("skill2"
## alanı, bkz. characters.gd). Ana "skill" (R tuşu, ulti) sisteminden
## TAMAMEN ayrı kendi durum makinesine sahip (skill2_state/skill2_timer/
## skill2_total_elapsed), böylece ikisi birbirinden bağımsız süre/bekleme
## süresiyle aynı anda farklı aşamalarda olabilir. "skill2" alanı olmayan
## karakterlerde bu makine hiç tetiklenmez (get_skill2_id() 0 döner).
const DEFAULT_SKILL2_DURATION := 5.0
const DEFAULT_SKILL2_COOLDOWN := 15.0
const SKILL2_TIMING := {
	## Oakley + Şovalye (Paladin) TEMEL: Kalkan Yenileme - artık 5sn değil 6sn
	## sürüyor (kullanıcı isteği: "6 saniye boyunca her saniye ... kalkan
	## yenilesin", bkz. _skill_kalkan_yenileme/_process_healer_shield_tick).
	10: {"duration": 6.0, "cooldown": 15.0},
	## Elara TEMEL: sabit süresi YOK, "sonraki 6 saldırı" (silah başına)
	## tüketilene kadar sürer (bkz. _process_elara_true_damage) - "duration"
	## burada sadece güvenlik tavanı, tıpkı Paladin ultisindeki 9999 gibi.
	11: {"duration": 9999.0, "cooldown": 35.0},
	## Matthew TEMEL (Vahşi Hız, id 21): kendine+tilkisine 10sn boyunca %40
	## saldırı hızı + %15 hareket hızı (bkz. _skill_matthew_haste,
	## player_pet.gd _get_speed_mult/_get_attack_speed_mult - tilki tarafı
	## zaten kendi kendine bu id'yi dinliyordu, DÜZELTME (kullanıcı bildirimi:
	## "matthewin E yeteneği kendinde işlemiyor ve onda efektler çalışmıyor"):
	## eksik olan SADECE Matthew'in KENDİSİNE uygulanan kısmıydı).
	21: {"duration": 10.0, "cooldown": 35.0},
	## Kurt Adam TEMEL: Vahşi Kesik - anlık AOE darbe, duration sadece
	## savuruş animasyonu için kısa bir pencere.
	13: {"duration": 1.0, "cooldown": 15.0},
	## Assasin Çocuk TEMEL (id 5) eski Görünmezlik'in yerine gelen yeni yük-
	## tabanlı (3 yük, 12sn/yük) 8 yönlü hamle - Korsan/Necromancer'ın şarj
	## tabanlı TEMEL'leriyle AYNI mimari desen, bu yüzden standart skill2_state
	## bekleme makinesini KULLANMIYOR (bkz. _physics_process skill2_id_pressed
	## == 5 dalı, ASSASIN_DASH2_* sabitleri) - burada bilerek girdisi YOK.
	## eski Talon TEMEL (Yer Sarsıntısı, skill2 id 8) - "Talon yeni skilleri"
	## isteğiyle TAMAMEN yeni bir kitle değiştirildi, bkz. id 36 (Silah
	## Salvosu) aşağıda. Kayıt zararsız olduğu için siliniyor, not bırakılıyor.
	8: {"duration": 1.0, "cooldown": 20.0}, ## artık kullanılmıyor (eski Yer Sarsıntısı) ama zararsız
	## Talon TEMEL (Silah Salvosu, skill2 id 36): "3sn boyunca tüm silahlar
	## dışa dönük dönüp saldırır, %200 saldırı hızı kazanır" (bkz. _skill_
	## talon_weapon_salvo). "duration" gerçek 3sn'lik dönüş süresiyle birebir
	## eşleşiyor.
	36: {"duration": 3.0, "cooldown": 15.0},
	## Büyücü Kız TEMEL'inin 4 varyasyonu (bkz. BUYUCU_VARIATION_SKILL2_IDS/
	## _buyucu_try_activate_variation) - standart skill2_state makinesini
	## KULLANMIYORLAR (her varyasyon kendi bekleme sayacını, get_skill2_id()'nin
	## dinamik döndüğü id'ye göre BURADAN okuyor), Korsan/Necromancer'ın
	## şarj-tabanlı TEMEL'leriyle AYNI mimari desen.
	22: {"duration": 0.35, "cooldown": 4.0}, ## Varyasyon 1: Arcane Lanet
	23: {"duration": 0.5, "cooldown": 30.0}, ## Varyasyon 2: Don Nova
	24: {"duration": 15.0, "cooldown": 45.0}, ## Varyasyon 3: Hortum
	25: {"duration": 5.0, "cooldown": 120.0}, ## Varyasyon 4: Meteor Patlaması
	## DÜZELTME: Shaman TEMEL (Saldırı Totemi, skill2 id 27) - bkz.
	## SKILL_TIMING[26] üstündeki AYNI not (eksik kayıt + artık "duration"
	## kullanılmıyor + 45sn bekleme).
	27: {"duration": 0.0, "cooldown": 45.0},
	## DÜZELTME (kullanıcı isteği: "Necromancer in E sini yarasa sürüsü
	## çağırma ile değiştir") - Yarasa Sürüsü (skill2 id 35): eskiden
	## SKILL3_TIMING[35]'teydi (R iken), "basılıp kapatılabilir" bir TOGGLE,
	## standart skill2_state makinesini KULLANMIYOR (bkz. player.gd
	## _necro_toggle_bats/_process_necro_bats - girdi bloğunda id
	## kontrolüyle bypass edilir, Korsan bombasıyla AYNI mimari desen).
	## Burada SADECE _skill2_timing_for()'un varsayılana düşmemesi için var -
	## gerçek "süre" yok (kalkan bitene ya da tekrar basılana kadar sürer),
	## "cooldown" da 0 (bekleme süresi yok, sadece kalkan yeterliliği
	## kısıtlar).
	35: {"duration": 9999.0, "cooldown": 0.0},
}
var _skill2_duration: float = DEFAULT_SKILL2_DURATION
var _skill2_cooldown: float = DEFAULT_SKILL2_COOLDOWN

## ---------- Üçüncü aktif yetenek slotu (skill3, R tuşu) ----------
## Motor değişikliği (kullanıcı isteği: Shaman'ın 3 BAĞIMSIZ totem yeteneği
## var, her biri kendi 60sn'sinde) - eskiden bir karakterin en fazla 2
## bağımsız soğuma süreli aktif yeteneği olabiliyordu (skill=ulti/Q,
## skill2=temel/E - bkz. game_manager.gd _setup_input_actions). Büyücü Kız'ın 4
## varyasyonu TEK slotu (skill2) paylaşıyor, o yüzden Shaman'a uymuyor (3
## totemin HEPSİ aynı anda aktif/kendi bekleme süresinde olmalı). Bu üçüncü
## slot skill/skill2 ile BİREBİR simetrik, genel bir motor özelliği olarak
## eklendi - "skill3" alanı olmayan karakterlerde get_skill3_id() 0 döner,
## hiçbir ek UI/tuş görünmez (bkz. hud.gd/game_manager.gd).
const SKILL3_TIMING := {
	## Shaman'ın 3 totemi de burada - id'ler characters.gd DEFS[12]'deki
	## "skill"/"skill2"/"skill3" alanlarıyla eşleşiyor (bkz. orada).
	28: {"duration": 0.0, "cooldown": 45.0}, ## Alan Totemi - bkz. SKILL_TIMING[26] üstündeki DÜZELTME notu (artık "duration" kullanılmıyor + 45sn bekleme)
	## DÜZELTME (kullanıcı isteği: "Elaranın R ile Q yeteneğinin yerini
	## değiştir") - eskiden Kalkan Sıçraması buradaydı (bkz. SKILL_TIMING[12]
	## şimdi orada), id 31 artık Çift Tetik'in (bkz. player.gd
	## _skill_elara_double_fire) yeni evi - "duration" 25sn'lik gerçek buff
	## süresiyle birebir eşleşiyor, 120sn bekleme.
	31: {"duration": 25.0, "cooldown": 120.0},
	## DÜZELTME (kullanıcı isteği: "Assasin çocuğun R si ile Q skillinin
	## yerini değiştir") - eskiden Gölge Adımı (id 30) buradaydı (bkz.
	## SKILL_TIMING[30] şimdi orada), id 16 artık Gölge Hücumu'nun
	## (bkz. player.gd _skill_assasin_dash) yeni evi.
	16: {"duration": 15.0, "cooldown": 90.0},
	## Kullanıcı isteği: Melek'in yeni 3. yeteneği (Korku, id 32) - "duration"
	## sadece büyü animasyonu penceresi, gerçek etki (4sn korku) enemy.gd'nin
	## kendi _fear_timer'ında ayrıca tutulur.
	32: {"duration": 0.3, "cooldown": 45.0},
	## Kullanıcı isteği: Şovalye Adam'ın yeni 3. yeteneği (Koruma Bariyeri,
	## id 29) - 15sn boyunca aktif, 60sn bekleme.
	29: {"duration": 15.0, "cooldown": 60.0},
	## DÜZELTME (kullanıcı isteği: "Oakleyin R yeteneği artık boşta kalan Q
	## yeteneği olacak") - Arı Sürüsü (eskiden burada, id 33) Q'ya taşındı
	## (bkz. SKILL_TIMING[33] şimdi orada). Yeni R (Koruyucu Büyü, id 39):
	## "8 saniye boyunca aktif kalır... (60 saniye bekleme süresi)" - kullanıcı
	## isteği. "duration" gerçek 8sn'lik buff süresiyle birebir eşleşiyor ki
	## ikon "aktif" çerçevesi buf aktifken doğru görünsün.
	39: {"duration": 8.0, "cooldown": 60.0},
	## Kullanıcı isteği: Korsan'ın yeni 3. yeteneği (Bombardıman, id 34) -
	## "etrafındaki büyük bir alana 8 saniye boyunca bombardımana alır, her
	## saniye %150 saldırı gücü kadar hasar verir." Standart skill3_state
	## makinesi KULLANILIYOR (Büyücü/Necromancer'ın aksine basit, sabit süreli
	## bir kanal) - "duration" gerçek 8sn'lik bombardıman süresiyle birebir
	## eşleşiyor (bkz. KORSAN_BOMBARDMENT_DURATION, _skill_korsan_bombardment).
	34: {"duration": 8.0, "cooldown": 40.0},
	## DÜZELTME (kullanıcı isteği: "Necromancer in E sini yarasa sürüsü
	## çağırma ile değiştir") - Yarasa Sürüsü (id 35) artık E/skill2'de, bu
	## kayıt SKILL2_TIMING[35]'e taşındı (bkz. yukarısı).
	## Talon'un yeni 3. yeteneği (Ayna Formu, skill3 id 37) - kullanıcı isteği:
	## "R ile Q'nun yerini değiştir" (eskiden Hamle Vuruşu buradaydı, bkz.
	## SKILL_TIMING[38] şimdi orada). "15sn boyunca her silahının bir aynalı
	## kopyası belirir" (bkz. _skill_talon_mirror_form), 120sn bekleme.
	37: {"duration": 15.0, "cooldown": 120.0},
	## DÜZELTME (kullanıcı isteği: "Necromancer in R sini golem çıkarma ile
	## değiştir") - Golem Çağır (skill3 id 20): eskiden SKILL_TIMING[20]'deydi
	## (Q iken), 100 Ruh karşılığında golem çağırır - ruh kontrolü
	## _activate_skill3() başında yapılır, burada sadece bekleme süresi
	## (10sn, bkz. _skill_necro_summon_golem).
	20: {"duration": 0.4, "cooldown": 10.0},
}
var _skill3_duration: float = DEFAULT_SKILL2_DURATION
var _skill3_cooldown: float = DEFAULT_SKILL2_COOLDOWN

## ---------- Şovalye (Paladin): Koruma Baloncuğu + Kışkırtma ----------
## paladin_zone_active/paladin_zone_radius dışarıdan (enemy.gd, enemy_
## projectile.gd) okunuyor - "player" node'unda bu iki alan varsa ve
## paladin_zone_active true ise, o yarıçapın içine hiçbir yaratık/menzilli
## saldırı giremiyor (bkz. enemy.gd _physics_process min_separation,
## enemy_projectile.gd _physics_process).
var paladin_zone_active: bool = false
var paladin_zone_radius: float = 0.0

## ---------- Kurt Adam: Kudurmuş Saldırı (Q) ----------
## true iken oyuncu hareketini kontrol edemez - _physics_process karakteri
## en kısa menzilli silahına göre en yakın yaratığa doğru otomatik yürütür
## (bkz. _kurtadam_berserk_direction). Yetenek/kalkan modu/eşya kullanımı
## bundan ETKİLENMEZ, sadece hareket.
var _kurtadam_berserk_active: bool = false
var _paladin_movement_locked: bool = false
## #28 DÜZELTME: multiplayer'da ESC menüsü artık get_tree().paused KULLANMIYOR
## (bkz. main.gd _toggle_pause notu - tüm sahne ağacını durdurmak host'ta
## simülasyonu HERKES için dondurüyordu). Bunun yerine SADECE menüyü açan
## oyuncunun kendi karakteri bu bayrakla hareketsiz bırakılıyor.
var _menu_input_locked: bool = false

## ---------- Chat ----------
## Kullanıcı isteği: "enter tuşuna basarak mesaj yazabiliriz" - chat kutusu
## odaktayken true, hud.gd tarafından set edilir. _menu_input_locked'ın
## AKSİNE (o SADECE hareketi kilitler, yetenek/kalkan modu tuşları hâlâ
## çalışır - Şovalye'nin Koruma Baloncuğu gibi "hareketsiz ama yetenek
## kullanabilir" durumlar için bilerek öyle) bu bayrak hareketi VE yetenek
## tuşlarını (Q/E/R) birlikte kilitler - yoksa mesaj içindeki harfler (ör.
## "q", "e", "r") yanlışlıkla yetenek tetikleyebilirdi.
var is_chat_typing: bool = false
var _chat_bubble: Node2D = null

## hud.gd (yerel mesaj gönderildiğinde) VE network_manager.gd
## (broadcast_chat_message RPC alıcı tarafta - başka bir oyuncu bu KARAKTER
## host/tek-oyunculu bağlamında "yerel" oyuncuysa, bkz. main.gd) tarafından
## çağrılır.
func show_chat_bubble(text: String) -> void:
	if _chat_bubble and _chat_bubble.has_method("show_message"):
		_chat_bubble.show_message(text)

## ---------- Ev içi (house interior) ----------
## Kullanıcı isteği: "eve çok yaklaşınca F'ye basarak içeri girilsin,
## içerideyken yaratıklar saldıramamalı" - true iken oyuncu "ev içinde"
## sayılır: enemy.gd _find_closest_target_player() bu bayrağı is_invisible_now
## ile AYNI şekilde kontrol edip oyuncuyu hedef listesinden tamamen çıkarıyor
## (yaratıklar ona doğru yürümüyor/saldırmıyor/mermi atmıyor), enemy_spawner.gd
## da bu bayrak açıkken yeni yaratık üretmeyi durduruyor - bkz.
## house_interior.gd (giriş/çıkış tetikleyicisi).
var is_indoors: bool = false


## ---------- Seyyar Satıcı güvenli bölgesi ----------
## Kullanıcı isteği: "Dükkanın olduğu alanda ... bir alan olur ... oyuncular
## o bölgeye girince yaratıklar tarafından görünmez olurlar ... Bariyerin
## içindeyken silahlar çalışmaz. Yaratıklar bariyerin içine giremezler." -
## is_indoors ile BİREBİR AYNI desen (enemy.gd _find_closest_target_player()
## bu bayrağı da kontrol edip oyuncuyu hedef dışı bırakır, bkz. o dosyadaki
## yorum) ama AYRI bir bayrak: is_indoors'un kendi (ev'e özel) anlamına/
## davranışına DOKUNULMUYOR, ikisi bağımsız çalışıyor. bkz.
## traveling_merchant.gd (giriş/çıkış tetikleyicisi - oyuncunun kendi
## _physics_process'i GameManager.merchant_zone_active/pos/radius'a göre
## mesafe kontrolü yapıp bunu ayarlıyor).
var is_in_merchant_zone: bool = false

func is_in_merchant_zone_now() -> bool:
	return is_in_merchant_zone


## Şovalye'nin kalkan baloncuğu gibi tamamen YAKINLIK bazlı - F'ye basmaya
## gerek yok, sınırı geçince otomatik açılır/kapanır. SADECE durum
## DEĞİŞİMİNDE (girerken/çıkarken) set_combat_active() çağrılır, her karede
## değil - gereksiz process_mode toggling'inden kaçınmak için.
func _process_merchant_zone_state() -> void:
	var should_be_in_zone: bool = GameManager.merchant_zone_active \
			and global_position.distance_to(GameManager.merchant_zone_pos) <= GameManager.MERCHANT_ZONE_RADIUS
	if should_be_in_zone == is_in_merchant_zone:
		return
	is_in_merchant_zone = should_be_in_zone
	set_combat_active(not is_in_merchant_zone)


## bkz. main.gd _toggle_pause() / pause_menu.gd - ESC menüsü açılıp
## kapanırken LOKAL oyuncunun hareketini kilitler/serbest bırakır.
func set_menu_input_locked(locked: bool) -> void:
	_menu_input_locked = locked
var _paladin_barrier_instance: Node2D = null
## %55 küçültüldü (280 -> 126, bkz. kullanıcı isteği). Bilerek TEK bir sabit
## üzerinden yönetiliyor: bu değer HEM baloncuğun çizim yarıçapını (fx_
## paladin_barrier.gd'ye aktarılır) HEM DE gerçek engelleme/kalkan-saldırısı
## mesafesini (enemy.gd min_separation) belirliyor - ikisi aynı sayıdan
## geldiği için görünen boyut ile gerçek sınır HER ZAMAN birebir eşleşmeye
## devam eder (bkz. az önce düzeltilen "2 kat büyük görünüyor" bugu; sadece
## görsel bir ölçek çarpanı eklemek o bugu geri getirirdi).
const PALADIN_ULTI_ZONE_RADIUS := 126.0
const PALADIN_ULTI_RANGE_MULT := 1.3
## Kullanıcı isteği: "şovalye adamın kalkan baloncuğunun hasar azaltmasını
## %90'dan %95'e yükselt" - eskiden 0.2 (metinlerde yanlışlıkla "%90" yazsa
## da GERÇEKTE %80 azaltıyordu) idi, artık gerçekten %95 azaltıyor.
## SONRAKİ TUR (kullanıcı isteği: "şovalye adamın ultisi açıkkenki hasar
## azaltmasını %95'ten %90'a düşür"): 0.05 (%95 azaltım) -> 0.10 (%90 azaltım).
const PALADIN_ULTI_SHIELD_COST_MULT := 0.10 ## kalkanın aldığı hasar %90 azalır
const PALADIN_TAUNT_RADIUS := 500.0

@export var speed: float = Characters.BASE_MOVE_SPEED ## genel hız ayarı: 300'den %20 düşürülüp, kullanıcı isteğiyle %5 artırıldı (240 -> 252) - artık Characters.BASE_MOVE_SPEED'ten okunuyor (remote_player.gd ile PAYLAŞILAN tek kaynak, bkz. oradaki not)
@export var max_health: float = 100.0
@export var pickup_range: float = 60.0

## Newer build-crafting stats picked up from level-up cards.
var exp_gain_percent: float = 0.0  ## 0.15 = +15% XP from every orb
## Her 1 şans puanı yaratıkların "birşey düşürme" ihtimalini +%1 arttırır
## (bkz. enemy.gd _drop_gold/_drop_food - artık ÇARPAN değil DÜZ toplama).
## Kullanıcı isteğiyle "Şans" kartı artık +1 (eskiden +0.075) veriyor.
var luck: float = 0.0
var weapon_range_bonus: float = 0.0 ## added to every owned weapon's attack_range
## Kart kaynaklı ham sıyrılma şansı en fazla %60 olabilir (bkz.
## DODGE_CHANCE_CAP) - bunu AŞAN kart puanları DÜZELTME (zırh kaldırıldı):
## eskiden zırha dönüşen taşma artık basitçe boşa gidiyor (bkz. apply_upgrade
## "dodge" dalı). Kalkan Şimşek Hız modu bunun DIŞINDA, ayrı bir shield_mode_
## dodge_bonus olarak toplam etkin sıyrılmaya (bkz. take_damage effective_
## dodge) cap'in üstünde eklenmeye devam ediyor.
const DODGE_CHANCE_CAP := 0.6
var dodge_chance: float = 0.0      ## 0-1 chance to fully evade incoming damage

## Yeni stat: "Bekleme Süresi Azaltma" (level kartı, bkz. apply_upgrade
## "cooldown_reduction" dalı, level_up_screen.gd) - yeteneklerin (skill VE
## skill2) bekleme süresini bu oranda azaltır, bkz. _activate_skill/
## _activate_skill2. Kart başına +%4, üst sınır %60.
const COOLDOWN_REDUCTION_CAP := 0.60
var cooldown_reduction_percent: float = 0.0

## Read live by weapon.gd/projectile.gd - 0 means "no effect", same convention
## as aggressive_damage_bonus below. Currently only Talon's rage sets these.
var knockback_force: float = 0.0 ## pixels a hit target is shoved back on a successful hit
## Kalıcı geri tepme statı (seviye kartlarından). knockback_force bunun
## üzerine geçici bonusları (Talon öfkesi) ekleyerek hesaplanan efektif değer.
var knockback_stat: float = 0.0
## Kalkan Miktarı statı: maksimum kalkanı yüzde olarak arttırır
## (refresh_shield_stats formülüne çarpan olarak girer).
var shield_max_percent: float = 0.0
var damage_taken_mult: float = 1.0 ## multiplies incoming health damage (Talon's rage: 0.65)

## ---------- Eşyalar (Items - bkz. scripts/items.gd) ----------
## Silahların aksine seviyelenmiyorlar, dükkandan sabit fiyata satın alınıp
## envanterde biriktiriliyorlar (bkz. GameManager.owned_items, buy_item/
## remove_owned_item). Statları _apply_item_stats() ile GENEL bir dinamik
## set/get döngüsünde uygulanıyor - bu yüzden Items.DEFS'teki her "stats"
## anahtarı ya doğrudan var olan bir player.gd stat'ına (max_health,
## damage_bonus, shield_pen_percent, luck, exp_gain_percent, shield_max_percent,
## heal_regen_bonus, dodge_chance, knockback_stat) ya da aşağıdaki YENİ,
## sadece eşyalara özel stat'lardan birine karşılık gelmeli.
var max_item_slots: int = 1 ## 1. seviyede 1 slot (oyun başlangıcı), sonraki seviyelerde +1 (bkz. level_up())

## Eldiven/Sigara/Keskin Uçlar - weapon.gd _fire_at/_deal_beam_tick tarafından
## _player_stat() ile canlı okunuyor, doğrudan final_damage/shield_pen'e
## ekleniyor (silaha özel bonuslarla AYNI yerde, TÜM silahlara eşit uygulanır).
var item_flat_hit_damage: float = 0.0 ## Eldiven: +5 düz hasar/isabet
var item_damage_mult_bonus: float = 0.0 ## Sigara: verilen hasara %arttırım
var shield_pen_percent: float = 0.0 ## Keskin Uçlar: genel kalkan delme

## Eldiven/Kaos Kitabı - _apply_weapon_bonuses_to() içinde fire_rate_mult'a
## EK bir çarpan olarak uygulanıyor (Elara pasifiyle aynı desende, "1.0 -
## toplam yüzde" şeklinde birleştiriliyor, çarpımsal DEĞİL toplamsal).
var item_fire_rate_percent: float = 0.0
## Deri Çizme/Kitelama Seti - _physics_process() velocity hesabında ekstra
## bir çarpan (1.0 + bu) olarak uygulanıyor.
var item_speed_percent: float = 0.0
## "Hız" level-up kartı - kullanıcı isteği: "flat sayı yerine yüzdesel olsun,
## kart başına +%4". item_speed_percent (eşyalar) ile AYNI mantıkla
## (additive, (1.0 + toplam) çarpanı) ama ayrı bir biriktiricide tutuluyor ki
## eşya statlarıyla karışmasın.
var speed_card_percent: float = 0.0
## Hasat Çantası - get_pickup_range()'te çarpan olarak uygulanıyor.
var item_pickup_range_percent: float = 0.0

## Kaos Kitabı: her atışta (silah başına, bağımsız) bu ihtimalle ikinci bir
## atış daha yapılır - bkz. weapon.gd _on_fire_timer_timeout / bow draw dalı.
var item_double_fire_chance: float = 0.0
## Kitelama Seti: bir düşmana hasar verildiğinde o düşmana uygulanan hız
## azaltma yüzdesi (bkz. weapon.gd -> enemy.gd apply_slow, 5sn, yeniden
## vurulunca süre baştan başlar).
var item_enemy_slow_percent: float = 0.0
## Şanslı Zar: düşman altın düşürürken EK bir %ihtimalle 1 altın daha
## düşürmesi (bkz. enemy.gd _drop_gold).
var item_extra_gold_chance: float = 0.0
## Hasat Çantası: XP toplarken bu ihtimalle 1 can yenilenir (bkz. add_xp()).
var item_xp_heal_chance: float = 0.0
## Vampir Dişi pasifi: bir düşmanı öldürünce bu kadar can yenilenir (bkz.
## on_enemy_killed/on_enemy_killed_remote). Eşya stack'lendiği için kopya
## sayısıyla additive büyür (2 kopya = öldürmede 2 can).
var item_kill_heal_amount: float = 0.0
## Yetenek Kitabı pasifi: yeteneklerin kalkan bedelini (bkz.
## SKILL_SHIELD_COST_*/_activate_skill, _activate_skill2,
## _skill_buyucu_switch_variation'daki skill2_shield_cost) bu oranda azaltır.
var item_skill_shield_cost_reduction: float = 0.0

## Kalkan Yüzüğü - kalkan formüllerine (refresh_shield_stats/_shield_hit_
## regen_delay/_process_item_shield) doğrudan giren üç ayrı terim.
var item_shield_power_flat: float = 0.0 ## +ham kalkan gücü (max hesaba girer)
var item_shield_delay_reduction: float = 0.0 ## -yenilenme bekleme süresi (sn)
var item_shield_regen_percent: float = 0.0 ## +yenilenme hızı çarpanı

## Deri Çizme pasifi: SADECE hareket halindeyken aktif olan sıyrılma bonusu.
## item_move_dodge_base = eşya sayısınca biriken POTANSİYEL güç (satın
## alınca/satılınca _apply_item_stats ile güncellenir), item_move_dodge_
## active = HER FİZİK KARESİNDE oyuncu hareket ediyorsa base'e eşitlenir,
## değilse 0 - bkz. _physics_process/take_damage effective_dodge.
var item_move_dodge_base: float = 0.0
var item_move_dodge_active: float = 0.0

## Vitamin pasifi: hasar alındıktan sonraki 5sn boyunca aktif olan geçici
## can yenilenmesi. _bonus = eşya sayısınca biriken POTANSİYEL güç (saniye
## başına), _timer = geri sayım - bkz. take_damage()/_process_item_passives.
var item_vitamin_regen_bonus: float = 0.0
var item_vitamin_regen_timer: float = 0.0

## Fraction of incoming damage the item shield's HP pool eats while it has
## charge left; the rest always reaches health. Taban değer AKTİF KALKAN
## TÜRÜNE göre değişiyor (bkz. SHIELD_TYPES "absorption") - kartlar
## (level_up_screen "shield_protection" perk'i, artık "Kalkan Soğurma" adıyla,
## bkz. o dosyadaki UPGRADES) +%4 puan ekliyor, ayrı bir shield_protection_bonus
## biriktiricisinde (bkz. aşağıda) tutuluyor, gerçek kullanılan shield_protection
## her zaman _recompute_shield_protection() ile taban+bonus toplanıp bu
## sabitle sınırlanarak yeniden hesaplanıyor. Kullanıcı isteğiyle ("kalkan
## soğurma en fazla %92 olsun") kart/tür kaynaklı ham emilim en fazla %92
## olabilir (kalkan MODLARININ - bkz. SHIELD_MODE_PROTECTION_CAP - sağladığı
## ek emilim hariç, o %100'e kadar çıkabilir) - cap'i AŞAN kısım
## (apply_upgrade'teki "shield_protection" dalına bkz.) doğrudan
## shield_max_percent'e (maksimum kalkana) 1:1 dönüşür, hiç kaybolmaz.
const SHIELD_PROTECTION_CAP := 0.92
var shield_protection: float = 0.0 ## computed - see _recompute_shield_protection()
var shield_protection_bonus: float = 0.0 ## accumulated from level-up perk picks ("Kalkan Soğurma"), +0.04 each

## ---------- Kalkan Türleri (Standart/Enerji/Kale/Savaş) ----------
## 4 bağımsız kalkan türü var ama kullanıcı isteğiyle ("sadece 1 kalkan
## alınabilmeli") aynı anda seviyesi >0 olan EN FAZLA biri olabilir -
## shop_panel.gd satın almadan önce bunu zorluyor (bkz. _on_buy_upgrade/
## _on_sell_shield). Ayrı bir "aktif tür" seçimi YOK, hangisi sahipse otomatik
## kullanılır (bkz. _owned_shield_type_key). Kalkan MODLARI (shield_mode_*, bkz.
## _apply_shield_mode) bundan TAMAMEN bağımsız bir çarpan/bonus katmanı -
## hangi tür aktifse onun ham gücü/yenilenmesi/emilimi üstüne binmeye devam
## ediyor, hiçbir şey değişmedi. "delay"/"delay_per_level" kalkan hasar
## aldıktan sonra yenilenmenin başlaması için beklenen süre (kullanıcı
## isteğiyle her seviye -0.1sn, taban SHIELD_REGEN_DELAY_FLOOR'un altına
## inemez). Savaş Kalkanı savaş sırasında da yenilendiği için "delay" hiç
## kullanılmıyor (always_regen=true -> hasarda bekleme süresi hiç
## uygulanmıyor, bkz. _shield_hit_regen_delay).
## DÜZELTME (100-level rebalance, sonra 100->20 rebalance): gerçek cap
## shop_panel.gd MAX_LEVELS'te uygulanıyor (bu sabit hiçbir yerden okunmuyor,
## salt referans) - yanıltıcı kalmasın diye güncel tavanla (20) senkron tutuluyor.
const SHIELD_LEVEL_CAP := 20
const SHIELD_REGEN_DELAY_FLOOR := 1.5
## DÜZELTME (100-level rebalance): eski cap 30'du, "_per_level" değerleri
## artık seviye 100'de eski seviye 30 ile TAM AYNI toplam güce ulaşacak
## şekilde 29/99 (~0.2929) ile ölçeklendi - "power"/"delay"/"regen" taban
## değerleri (level 1'deki güç) DEĞİŞMEDİ, sadece per-level artışlar 100
## küçük adıma yayıldı (kullanıcı isteği: "ufak ufak gelecek").
## DÜZELTME (kullanıcı isteği: "Oyundaki geliştirilebilen tüm itemlerin
## levele göre gelişme hızını %100 arttır") - tüm "_per_level" değerleri
## (power/delay/regen) İKİ KATINA çıkarıldı, taban (level 1) değerler
## DEĞİŞMEDİ - level 100'deki toplam bonus da böylece eskisinin iki katı.
## DÜZELTME (100->20 level rebalance, kullanıcı isteği: "Silah ve kalkan
## tierlarını 100 yapmanı istemiştim onu 20'ye düşürerek ... 100 leveldeki
## güç nasılsa 20 leveldeki güç de öyle olacak şekilde güncelle") - buradaki
## *_per_level alanları (weapon.gd/_tier_from_level10'un aksine) DOĞRUDAN ham
## `level`e karşı çarpılıyor (bkz. aşağıdaki set_active_shield_type/
## get_item_shield_delay/_recalc_item_shield_max - "base + (level-1)*per_level"
## şekli), yani tavan seviye 100'den 20'ye inince UÇ NOKTA (level 20'deki güç)
## AYNI kalsın diye her *_per_level 99/19 (eski payda/yeni payda) ORANIYLA
## büyütüldü - "power"/"delay"/"regen" taban (level 1) değerleri DEĞİŞMEDİ.
const SHIELD_TYPES := {
## DÜZELTME (kullanıcı isteği: "tüm kalkanların seviye başına verilen
## statlarını %100 arttır, yenilenme oranlarını sadece %50 arttır") -
## *_per_level alanlarının HEPSİ 2 katına çıkarıldı (power_per_level/
## delay_per_level), SADECE regen_per_level 1.5 katına çıkarıldı (%50).
## Taban (seviye 1) değerleri (power/delay/regen/absorption) DEĞİŞMEDİ -
## bunlar "seviye başına" değil, başlangıç değeri.
	"shield_standart": {
		"name": "Standart Kalkan",
		"power": 150.0, "power_per_level": 61.0528,
		"delay": 8.0, "delay_per_level": -0.6106,
		"regen": 10.0, "regen_per_level": 4.57845,
		"absorption": 0.60,
		"always_regen": false,
	},
	"shield_enerji": {
		"name": "Enerji Kalkanı",
		"power": 90.0, "power_per_level": 48.8414,
		"delay": 4.5, "delay_per_level": -0.6106,
		"regen": 12.0, "regen_per_level": 9.15855,
		"absorption": 0.50,
		"always_regen": false,
	},
	"shield_kale": {
		"name": "Kale Kalkanı",
		"power": 180.0, "power_per_level": 97.6848,
		"delay": 9.0, "delay_per_level": -0.6106,
		"regen": 8.0, "regen_per_level": 9.15855,
		"absorption": 0.70,
		"always_regen": false,
	},
	"shield_savas": {
		"name": "Savaş Kalkanı",
		"power": 100.0, "power_per_level": 61.0528,
		"delay": 0.0, "delay_per_level": 0.0,
		## DÜZELTME (kullanıcı isteği #40: "savaş kalkanı çok güçlü, kalkan
		## yenilenmesini ve seviye başına kalkan yenilenmesi artışını %40
		## azalt") - hasar sonrası bekleme olmadan (always_regen) SÜREKLİ
		## yenilendiği için diğer türlere göre zaten avantajlıydı, bu yüzden
		## bu iki değer özellikle güçlüydü: regen 6.0 -> 3.6, regen_per_level
		## 2.0 -> 1.2 (ikisi de %40 azaltıldı) - 100-level rebalance ile
		## regen_per_level ayrıca 29/99 ile ölçeklendi (1.2 -> 0.3515), sonra
		## "tüm gelişme hızlarını %100 arttır" isteğiyle tekrar ikiye
		## katlandı (0.3515 -> 0.7030), 20-level rebalance ile 99/19 oranıyla
		## tekrar büyütüldü (0.7030 -> 3.6630), ve şimdi "yenilenme oranlarını
		## %50 arttır" isteğiyle bir kez daha büyütüldü (3.6630 -> 5.4945).
		"regen": 3.6, "regen_per_level": 5.4945,
		"absorption": 0.55,
		"always_regen": true, ## savaştayken de (hasar sonrası bekleme olmadan) yenilenir
	},
}

## Shield modes (see GameManager.active_shield_mode) - only one active at a
## time, recomputed into these plain modifiers by _apply_shield_mode() so the
## rest of the code doesn't need to know which mode is on.
## Kullanıcı isteği: kalkan modlarının sağladığı emilim (shield_mode_
## protection_bonus/thorny_intake_bonus) dahil edildiğinde toplam emilim
## %100'e kadar çıkabilir - SADECE kart/tür kaynaklı ham shield_protection
## %90'da sınırlı (bkz. SHIELD_PROTECTION_CAP).
const SHIELD_MODE_PROTECTION_CAP := 1.0
var shield_mode_max_mult: float = 1.0
## Meditasyon (resilience) modu: kalkan azaltma cezası yerine maksimum CANI
## %30 azaltır (bkz. _apply_shield_mode). Bir önceki uygulanan çarpanı
## saklar ki mod değişiminde ceza düzgün geri alınıp yeniden uygulansın.
var _last_applied_health_tax: float = 1.0
var shield_mode_regen_mult: float = 1.0
## Metanet Modu: savaştayken (hit-cooldown sırasında) kalkanın saniyede
## maksimumunun bu yüzdesi kadar sızıntı şeklinde yenilenmesi - 0 = hiç
## yenilenmez. Artık base_regen_rate'in bir çarpanı DEĞİL, doğrudan
## item_shield_max'in yüzdesi (MODE_DRAIN_RATE'teki gibi tutarlı birim).
var shield_mode_combat_regen_factor: float = 0.0 ## 0 = no regen while on hit-cooldown
var shield_mode_thorny_intake_bonus: float = 0.0
var shield_mode_thorny_reflect_percent: float = 0.0
var shield_mode_protection_bonus: float = 0.0
var shield_mode_speed_mult: float = 1.0
var aggressive_damage_bonus: float = 0.0 ## read live by weapon.gd, scales with current shield
## Talon pasifi (bkz. _talon_add_passive_stack/_passive_talon) - weapon.gd
## zaten bunu `_player_stat("talon_damage_bonus")` ile aggressive_damage_
## bonus'un YANINA (final_damage *= 1.0 + aggressive_damage_bonus +
## talon_damage_bonus) topluyordu, sadece Player'da karşılığı YOKTU (hep 0
## dönüyordu) - artık gerçek bir alan.
var talon_damage_bonus: float = 0.0

## Şimşek Hız Modu / Delicilik Modu / Tank Modu - see _apply_shield_mode().
var shield_mode_shield_pen_bonus: float = 0.0 ## ignores this fraction of an enemy's shield_protection (Delicilik)
var shield_mode_dodge_bonus: float = 0.0 ## added to dodge_chance (Şimşek Hız)
var shield_mode_damage_mult: float = 1.0 ## multiplies all outgoing damage (Tank)

## Modes that never regenerate on their own and instead burn down at a fixed
## %/sec of max shield while active (see _process_item_shield) - "aggressive"
## has its own special-cased branch below since its drain also drives
## aggressive_damage_bonus, so it isn't listed here.
const MODE_DRAIN_RATE := {
	"lightning": 0.05, ## Şimşek Hız Modu: %5/sn - a fast mover's shield doesn't last
	"piercing": 0.01, ## Delicilik Modu: %1/sn - a small cost for the pen bonus
}

## Level-up weapon stat bonuses, applied to every weapon the player owns
## (base weapon + any bought staves) - see _apply_weapon_bonuses().
## Kullanıcı isteği: "bundan böyle her karakter oyuna 10 saldırı gücüyle
## başlayacak" - eskiden 0'dan başlıyordu, artık taban 10 (bkz.
## on_team_leveled_up'taki +1/level artışı için de aynı istek).
var damage_bonus: float = 10.0
var fire_rate_mult: float = 1.0
var crit_chance_bonus: float = 0.0
var crit_damage_bonus: float = 0.0

## Kullanıcı isteği: "bundan sonra bütün yetenekler kritik vuruş yapabilir ve
## kritik vuruş hasar artışından etkilenebilir (can ve kalkan verme de dahil
## bunlar pozitif olarak artacak)" - eskiden SADECE silah oto-saldırıları
## (bkz. weapon.gd _base_crit_chance/_base_crit_damage + crit_chance_bonus/
## crit_damage_bonus) kritik vurabiliyordu, karakter yetenekleri (skill/skill2
## fonksiyonları) hiç kritik hesaba katmıyordu. Taban değerler weapon.gd'nin
## varsayılan @export değerleriyle (0.05/1.5) BİREBİR TUTARLI tutuldu - aynı
## crit_chance_bonus/crit_damage_bonus kart statları burada da kullanılıyor,
## böylece "Kritik Oran"/"Kritik Hasar" kartları artık yetenekleri de
## güçlendiriyor. Hasar veren yeteneklerde normal hasarı artırıyor, can/kalkan
## veren yeteneklerde ise verilen can/kalkan miktarını artırıyor - ikisi de
## "pozitif olarak artış" (kullanıcının deyimiyle).
const ABILITY_BASE_CRIT_CHANCE := 0.05
const ABILITY_BASE_CRIT_DAMAGE := 1.5

func _roll_ability_crit() -> bool:
	return randf() < clamp(ABILITY_BASE_CRIT_CHANCE + crit_chance_bonus, 0.0, 1.0)


## amount: yeteneğin normal (kritiksiz) miktarı - hasar, iyileştirme ya da
## kalkan miktarı farketmez, üçü için de AYNI kritik çarpanı uygulanıyor.
func _apply_ability_crit(amount: float, is_crit: bool) -> float:
	if not is_crit:
		return amount
	return amount * (ABILITY_BASE_CRIT_DAMAGE + crit_damage_bonus)

var health: float
## Oyun sonu istatistik ekranı (kullanıcı isteği: "oyun sonuna istatistik
## penceresi ekleyip kimin ne kadar vurduğunu ne kadar hasar tankladığını
## göster") - bu maç boyunca biriken toplamlar. Verdiği hasar: enemy.gd
## take_damage()'ın en başında (bkz. orada, host/client ayrımından ÖNCE,
## çünkü bu fonksiyon HER ZAMAN vuran client'ın kendi makinesinde en az bir
## kez çalışır) yerel oyuncuya eklenir - böylece host olmayan bir client'ın
## vuruşu da doğru şekilde KENDİSİNE atfedilir. Aldığı hasar: kendi
## take_damage()'ında (yukarıda) toplanır. Oyun bitince (bkz. main.gd
## _on_player_died/NetworkManager.sync_match_stats) herkese yayınlanır.
var match_damage_dealt: float = 0.0
var match_damage_taken: float = 0.0
var level: int = 1
var xp: float = 0.0
## Kullanıcı isteği: "seviye atlamak %30 zorlaşsın" - eski taban 10.0'dı,
## seviye başına büyüme oranı (level_up()'taki *1.12) AYNEN korunuyor, sadece
## eğri baştan %30 yukarı kaydırılıyor (10 * 1.3 = 13) - bu sayede HER
## seviye, eskisine göre tam olarak %30 daha fazla XP istiyor (oran sabit
## kaldığı için eğrinin şekli değişmiyor, sadece tamamı %30 daha zor).
var xp_to_next_level: float = 13.0
var is_dead: bool = false
## Klasik canlanma sistemi (kullanıcı isteği: "multiplayerda dirilme olayı
## ölür ölmez olmamalı. öldükten sonra arkadaşının 3 saniye boyunca
## yakınında durması gereksin seni diriltebilmek için") - main.gd/
## remote_player.gd bu bayrağı zaten senkronize edip bekliyordu (bkz.
## main.gd state_snapshot "is_downed" alanı, remote_player.gd "yerde yatan
## müttefik griye boyanır" görseli), ama BURASI (asıl durumun sahibi) hiç
## yazılmamıştı - eskiden GameManager.revives_remaining > 0 olduğu sürece
## ölüm ANINDA otomatik/koşulsuz canlandırılıyordu (bkz. die()), hiçbir
## müttefik yakınlığı gerekmiyordu. Artık (SADECE çok oyunculuda - tek
## oyunculuda kimse canlandıramayacağı için eski anlık davranış korunuyor,
## bkz. die()) ölüm anında bu bayrak açılıp is_dead da (hareket/saldırı/
## tekrar hasarı bloklamak için, bkz. _physics_process/take_damage) true
## yapılır; _process_downed() bir müttefik REVIVE_RANGE içinde kaldığı
## sürece REVIVE_CHANNEL_TIME kadar ilerleyen bir kanal başlatır - tamamlanırsa
## gerçek canlanma (_complete_revive), DOWNED_BLEEDOUT_TIME içinde kimse
## gelmezse kalıcı ölüm (_finalize_death) gerçekleşir.
var is_downed: bool = false
var _downed_time: float = 0.0
var _revive_progress: float = 0.0
const REVIVE_CHANNEL_TIME := 3.0
const REVIVE_RANGE := 90.0
const DOWNED_BLEEDOUT_TIME := 30.0
## Kullanıcı isteği: "birini diriltince 3 saniye boyunca ölümsüzlük veren bir
## buff olmalı dirilten ve diriltilen kişide" - bkz. _complete_revive()
## (diriltilen, yerel olarak) ve network_manager.gd grant_revive_
## invulnerability RPC'si (dirilten, uzak bir peer olabileceği için ağ
## üzerinden).
const REVIVE_INVULNERABILITY_TIME := 3.0
var is_revive_invulnerable: bool = false
var facing: String = "down"

var is_shielded: bool = false
## shield_visual baloncuğu artık HEM Şovalye Adam'ın R-tuşu becerisi
## (is_shielded, beceri süresince kalıcı görünür) HEM DE dükkandan alınan
## Sihirli Kalkan (item_shield_hp) tarafından sürülüyor - bkz.
## _update_shield_bubble(). Sihirli Kalkan tarafı KALICI değil: baloncuk
## sadece hasar alırken (kısa bir flaş süresi, _damage_flash_timer) ve
## kalkan gerçekten yenilenirken (_shield_regenerating) görünür, boşta
## dolu dururken görünmez.
var _bubble_active: bool = false
var _shield_regenerating: bool = false
var _damage_flash_timer: float = 0.0
const SHIELD_DAMAGE_FLASH_DURATION := 0.6
## is_shielded'ın bir önceki karedeki değeri - _update_shield_bubble()'ın
## "Şovalye Adam'ın becerisi TAM BU KARE bitti mi" (gerçek bir "kalkan
## kırıldı" anı, pop hak eder) diye ayırt edebilmesi için (bkz. o fonksiyon).
var _shield_active_prev_frame: bool = false
var is_invisible: bool = false
var is_assasin_dashing: bool = false
var assasin_dash_hits: int = 0
var _assasin_dash_fx: Node2D = null
var skill_speed_multiplier: float = 1.0
## Matthew'in TEMEL yeteneği (Vahşi Hız, skill2 id 21) için AYRI bir hareket
## hızı çarpanı - skill_speed_multiplier'dan bağımsız çünkü o SADECE ULTİ (R,
## skill_state) sistemine ait ve _end_skill_effects()'te sıfırlanıyor; bu ise
## TEMEL (E, skill2_state) sisteminde yaşayıp _end_skill2_effects()'te
## sıfırlanıyor (bkz. _skill_matthew_haste).
var skill2_speed_multiplier: float = 1.0
var heal_regen_bonus: float = 0.0
## heal_regen_bonus GEÇİCİ - Öykü'nün heal becerileri onu aktivasyonda
## MUTLAK olarak set eder (bkz. _skill_heal/_skill_heal_aura_falan) ve HER
## beceri bitişinde _end_skill_effects() onu 0.0'a sıfırlar (karaktere özel
## değil, TÜM karakterlerin ortak beceri-bitiş temizliği). "Can Yenilenmesi"
## level kartının bonusu bu yüzden AYRI, hep kalıcı bir biriktiricide
## tutuluyor - _process_regen() ikisini toplar, ama kart bonusuna hiçbir
## beceri (ne aktivasyon ne bitiş) asla dokunmaz.
## DÜZELTME (kullanıcı isteği #50: "her karakter 0.5 can yenilenmesiyle
## başlasın") - başlangıç değeri 0.0 -> 0.5. Bu, her karakterin maça "Can
## Yenilenmesi" kartını bir kez almış gibi başlamasını sağlar; level
## kartıyla alınan her ek +0.5 üstüne eklenmeye devam eder.
var heal_regen_card_bonus: float = 0.5

## Matthew's "Feda Kalkanı": a separate HP pool (sized from his pet's health
## at the moment it's sacrificed) that fully blocks incoming damage while up,
## instead of a flat duration-only invuln like Kalkancı's is_shielded - see
## take_damage() and _skill_shield_dome()/_pop_matthew_dome().
var matthew_dome_hp: float = 0.0
var matthew_dome_active: bool = false
var _matthew_fox_shield_fx: Node2D = null

## Resting sprite scale - Talha's rage grows past this, and every place that
## resets the sprite after a bounce/skill effect settles back to it. Used to
## be a flat constant tuned for the 32x32-sourced characters (1-6), but
## Baykuş (5) uses a much higher-resolution source atlas (see
## _load_character_frames()'s CHAR_ANIM_SCALE) so it needs its own value -
## set per-character in _load_character_frames(), this is just the fallback.
var char_base_anim_scale: Vector2 = Vector2(4.2, 4.2)

var skill_state: String = "ready"
var skill_timer: float = 0.0
var skill_total_elapsed: float = 0.0

var skill2_state: String = "ready"
var skill2_timer: float = 0.0
var skill2_total_elapsed: float = 0.0
var skill3_state: String = "ready"
var skill3_timer: float = 0.0
var skill3_total_elapsed: float = 0.0
## Kalkan Yenileme (skill2 id 10) aktif olduğu sürece true - _process_
## kalkan_yenileme() bu bayrağa bakarak her frame kalkan ekler.
var is_kalkan_yenileme_active: bool = false

signal health_changed(current, max_value)
signal xp_changed(current, needed)
signal leveled_up(new_level)
signal stats_changed
signal item_shield_changed(current, max_value)
signal died

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var shield_visual: Node2D = $ShieldVisual
@onready var shadow: Node2D = $Shadow
@onready var overhead_bar = $OverheadBar
## Kullanıcı isteği: "birisi düştüğünde diğerleri onu canlandırmak için bir
## süre var ama o süre görünmüyor" - bkz. downed_timer_label.gd/
## get_downed_remaining_seconds()/_process_downed.
@onready var downed_timer_label = $DownedTimerLabel
@onready var name_label: Label = $NameLabel
@onready var fire_sound: AudioStreamPlayer2D = $FireSound
## Kullanıcı bildirimi: "öldüğümüz zaman mapin sol üst kısmına geliyor
## kamera ve orda sabit kalıyor" - bkz. die() fonksiyonundaki düzeltme.
@onready var death_camera: Camera2D = get_node_or_null("Camera2D")

const FloatingText := preload("res://scenes/floating_text.tscn")
## Hiçbir karakterin ayrı, ücretsiz, "sabit" bir ana silahı YOK ve artık hiç
## otomatik başlangıç silahı da yok (kullanıcı isteği) - oyuncunun main.gd
## silah seçim ekranından seçtiği silah, dükkandan alınmış GİBİ diğerleriyle
## birebir aynı muamele gören normal bir owned_weapons kopyası olarak
## owned_weapon_nodes'a girer (bkz. weapon_select_screen.gd/main.gd
## _grant_selected_item).
const DaggerWeaponScene := preload("res://scenes/weapon_dagger.tscn")
const FireWeaponScene := preload("res://scenes/weapon_fire.tscn")
const LightningWeaponScene := preload("res://scenes/weapon_lightning.tscn")
const TabancaWeaponScene := preload("res://scenes/weapon_tabanca.tscn")
const TuftufWeaponScene := preload("res://scenes/weapon_tuftuf.tscn")
const TufekWeaponScene := preload("res://scenes/weapon_tufek.tscn")
const ArcaneWeaponScene := preload("res://scenes/weapon_arcane.tscn")
const YayWeaponScene := preload("res://scenes/weapon_yay.tscn")
const CrossbowWeaponScene := preload("res://scenes/weapon_crossbow.tscn")
const BoomerangWeaponScene := preload("res://scenes/weapon_boomerang.tscn")
const BuzAsasiWeaponScene := preload("res://scenes/weapon_buz_asasi.tscn")
const FisekWeaponScene := preload("res://scenes/weapon_fisek.tscn")
const PenceWeaponScene := preload("res://scenes/weapon_pence.tscn")
const TopuzWeaponScene := preload("res://scenes/weapon_topuz.tscn")
const UzunkilicWeaponScene := preload("res://scenes/weapon_uzunkilic.tscn")

## Skill VFX sahneleri - runtime load() yerine preload() (frame drop önler)
const FxOykuHealScene := preload("res://scenes/fx_oyku_heal.tscn")
const FxWaveBeamScene := preload("res://scenes/fx_wave_beam.tscn")
const FxKurtadamRageScene := preload("res://scenes/fx_kurtadam_rage.tscn")
const FxBuyucuFastfireScene := preload("res://scenes/fx_buyucu_fastfire.tscn")
const FxShieldActiveScene := preload("res://scenes/fx_shield_active.tscn")
const FxPaladinCastScene := preload("res://scenes/fx_paladin_cast.tscn")
const FxPaladinShatterScene := preload("res://scenes/fx_paladin_shatter.tscn")
const FxElaraDoubleScene := preload("res://scenes/fx_elara_double.tscn")
const FxElaraTrueScene := preload("res://scenes/fx_elara_true.tscn")
const FxAssasinStealthScene := preload("res://scenes/fx_assasin_stealth.tscn")
const FxKalkanYenilemeScene := preload("res://scenes/fx_kalkan_yenileme.tscn")
const FxTalhaRageScene := preload("res://scenes/fx_talha_rage.tscn")
const FxMatthewSacrificeScene := preload("res://scenes/fx_matthew_sacrifice.tscn")
const FxMatthewExplosionScene := preload("res://scenes/fx_matthew_explosion.tscn")
const FxMatthewFoxShieldScene := preload("res://scenes/fx_matthew_fox_shield.tscn")
const FxBuyucuTornadoScene := preload("res://scenes/fx_buyucu_tornado.tscn")
const FxMagePassiveBurstScene := preload("res://scenes/fx_mage_passive_burst.tscn")
## DÜZELTME (kullanıcı bildirimi: "matthewin temel yeteneği arkasında hız
## izleri çıkarmıyor tilkisinde çıkıyor ama kendisine çıkmıyor") - player_pet.
## gd'nin AYNI efekti (FxSpeedLineScene, bkz. o script'in _spawn_speed_line'ı)
## sadece tilki için _physics_process'te owner_player.is_skill2_active() +
## get_skill2_id()==21 kontrolüyle tetikleniyordu; Matthew'in KENDİ karakteri
## için hiç eşdeğer bir çağrı yoktu. Aşağıda AYNI sahne/desen Matthew'in
## kendisine de uygulanıyor (bkz. _process_matthew_speed_lines).
const FxSpeedLineScene := preload("res://scenes/fx_speed_line.tscn")
var _matthew_speed_line_timer: float = 0.0

var regen_display_accum: float = 0.0

## Can yenilenmesi de tıpkı kalkan yenilenmesi gibi artık "smooth" değil,
## saniyede TAM 1 tik ile toplu artıyor (kullanıcı isteği: "can
## yenilenmesinde de aynı olmalı" - bkz. SHIELD_REGEN_TICK_INTERVAL/
## _process_shield_regen_tick ile birebir aynı desen).
const HEALTH_REGEN_TICK_INTERVAL := 1.0
var _health_regen_tick_timer: float = 0.0
var _health_regen_tick_pending: float = 0.0

var item_shield_hp: float = 0.0
var item_shield_max: float = 0.0
var item_shield_regen_delay: float = 0.0
## Bir yetenek kullanıldıktan sonra kalkan yenilenmesini TAMAMEN durdurmaz
## (bkz. item_shield_regen_delay - o SADECE hasar alınca dolar), sadece
## _shield_hit_regen_delay() kadar bir süre boyunca yenilenme hızını %50
## düşürür (bkz. _process_item_shield/_process_kalkan_yenileme). "Bir
## yetenek kullandıktan sonra kalkan yenilenmesi durmayacak (hasar
## alınmadığı sürece) ama kalkan %50 daha yavaş yenilenecek" (kullanıcı isteği).
var item_shield_ability_slow_timer: float = 0.0
var spray_timer: float = 0.0
var base_modulate: Color = Color(1, 1, 1, 1)

## Kalkan yenilenmesi artık her karede yumuşakça (smooth) artmıyor - kullanıcı
## isteği: "kalkan yenilenmelerinin saniye/tick olmasını istiyorum anlık
## olarak smooth bir şekilde artmasını istemiyorum." Tüm pasif kalkan regen
## kaynakları (_process_item_shield taban yenilenmesi + Metanet trickle +
## _process_kalkan_yenileme) artık gerçek item_shield_hp'yi HEMEN değiştirmek
## yerine bu ortak biriktiriciye (_shield_regen_tick_pending) yazıyor;
## gerçek artış SADECE _process_shield_regen_tick() içinde, sabit aralıklarla
## (SHIELD_REGEN_TICK_INTERVAL) toplu halde uygulanıyor - toplam yenilenme
## miktarı/hızı DEĞİŞMEDİ, sadece HUD/bar'daki artış artık düzenli "tik"lerle
## oluyor, sürekli akıcı bir kayma değil.
const SHIELD_REGEN_TICK_INTERVAL := 1.0 ## saniyede TAM 1 tik (kullanıcı isteği: "saniyede 2 tick artıyor" - 0.5 idi, 1.0'a düzeltildi)
var _shield_regen_tick_timer: float = 0.0
var _shield_regen_tick_pending: float = 0.0

## Şovalye ultisi (Koruma Baloncuğu) aktifken kalkana gelen darbelerin
## gösterge metnini biriktirir - PALADIN_ULTI_SHIELD_COST_MULT çok küçük
## olduğu için (0.1) tek bir darbenin kalkana verdiği hasar çoğu zaman 1'in
## altında kalıp yuvarlanınca "0" olarak görünüyordu (bkz. kullanıcı bildirimi
## "gereksiz yere 0 yazıları çıkıyor"). Artık _spawn_floating_text SADECE
## birikmiş miktar en az 1'e ulaştığında çağrılıyor - toplam gösterilen sayı
## yine doğru, sadece anlamsız "0" spam'i kayboluyor.
var _paladin_barrier_dmg_display_accum: float = 0.0

## XP pickup combo: pitch climbs a bit with every orb collected back-to-back
## and resets once there's a short gap with no pickups.
## Kullanıcı isteği (bildirim: "orbları üst üste toplayınca pitch artış efekti
## hemen kayboluyor, üst üste toplamalarda pitch artışı için daha fazla zaman
## gerekiyor") - eski 0.35sn'lik pencere çok kısaydı: mıknatısla gelen orb
## akışı 0.35sn'den uzun bir boşlukla bölündüğü anda seri sıfırlanıyor ve
## pitch hemen 1.0'a düşüyordu. Artık 1.0sn - üst üste toplamalar gerçekten
## üst üste sayılıyor ve pitch kademesi (bkz. XP_STREAK_PITCH_STEP) kesintisiz
## yükselebiliyor. Not: bu yalnızca "ne kadar süre ara verilirse seri sıfırlanır"
## eşiği; pitch'in kendisi hâlâ her toplamada XP_STREAK_PITCH_STEP kadar artar.
const XP_STREAK_RESET_TIME := 1.0
## Kullanıcı isteği (bildirim: "pitch daha yavaş artsın çünkü onlarca orb
## topluyoruz") - eski ayar (adım 0.06 / tavan 14) tek bir orb akışında çok
## hızlı tırmanıyordu: 14 orb'da pitch 1.84'e (neredeyse bir oktav tiz) dayanıp
## TAVANA takılıyor, sonraki onlarca orb'da hiçbir değişim duyulmuyordu - yani
## "onlarca orb" toplandığında etki yarısından sonra ölü kalıyordu. Adım bu
## yüzden 3 kat küçültüldü (0.02): pitch her orb'da çok yumuşak yükseliyor.
##
## Kullanıcı isteği (bildirim: "tavan pitch 50 orbda olsun" + "50 orba dengeli
## bir şekilde yay") - tırmanış artık 50 orb'ın TAMAMINA eşit yayılıyor:
## tavan tam olarak 50. orb'da doluyor, ne önce takılıyor ne de sonrası boş
## kalıyor. Adım, tavan pitch'i 2.0 (bir oktav - çok tiz) yapmasın diye
## 0.02 -> 0.01'e indirildi: tavan pitch = 1.0 + 50*0.01 = 1.50, yani tam bir
## BEŞLİ (perfect fifth, ~7 yarım perde) - müzik olarak dengeli/doğal
## duran, tırmalamayan bir tepe. Her orb +0.01 pitch (≈0.17 yarım perde):
## tek tek neredeyse fark edilmez ama 50 orb boyunca birikimi net duyulur.
## NOT: pitch_scale bir FREKANS ÇARPANI olduğu için (2.0 = bir oktav) eşit
## pitch_scale adımları eşit MÜZİKAL aralıklara denk gelir - yani yükseliş
## zaten "dengeli"dir, duyusal olarak hızlanıp yavaşlamaz.
const XP_STREAK_PITCH_STEP := 0.01
const XP_STREAK_MAX := 50
var xp_pickup_streak: int = 0
var xp_streak_timer: float = 0.0
@onready var xp_pickup_sound: AudioStreamPlayer2D = $XPPickupSound

## Aynı anda (ör. bir seferde 4 orb) toplanınca hepsi TEK bir
## AudioStreamPlayer2D'yi çağırıyordu - her .play() bir öncekini kesiyordu,
## o yüzden 4 toplasan da tek ses duyuluyordu. Artık her toplama kendi geçici
## (tek seferlik) çalıcısını alıyor ve aralarına minicik bir gecikme
## (XP_SOUND_STAGGER_DELAY) ekleniyor ki hepsi duyulsun ama üst üste binip
## "tek ses" gibi olmasın - bkz. _play_xp_pickup_sound()/_fire_xp_sound().
const XP_SOUND_STAGGER_DELAY := 0.045
var _xp_sound_queue_count: int = 0

## Kullanıcı isteği (bildirim: "4 yürüme sesi ekledim bu sesler rastgele bir
## şekilde çalacak karakter hareket ederken. Ayrıca her seferinde fark
## edilmeyecek derecede çok az pitch farkı eklemeni istiyorum. seslerini %75
## azaltmayı unutma").
##
## ÖNCEKİ PLAN (tek ses, yürürken döngüde) BIRAKILDI: player.tscn'de artık 4
## ayrı (~0.3sn'lik TEK adım) ses var (WalkSound1..4) ve yürürken bunlar belli
## bir adım aralığıyla (WALK_STEP_INTERVAL) RASTGELE çalınır - böylece adımlar
## hep aynı sesi tekrarlıyormuş gibi durmaz (bkz. _play_walk_step).
##
## Ses seviyeleri player.tscn'de -12.04 dB (lineer 0.25 = %75 azaltılmış) -
## projedeki diğer seslerle aynı desen (volume_db sahnede, mantık script'te).
##
## Adım aralığı VE seslerin tizliği karakterin anlık GERÇEK hareket hızına
## bağlıdır: normal hızda aralık WALK_STEP_INTERVAL, pitch 1.0; hız arttıkça
## adımlar sıklaşır ve tizleşir (bkz. _update_walk_sound).
##
## Taban adım aralığı (sn): normal hızda iki adım sesi arasındaki süre.
## Kullanıcı isteği (bildirim: "adım sesleri çok hızlı geliyor %30 azaltır
## mısın gelme hızını"): eski 0.375sn'lik aralık %30 UZATILDI (0.375 / 0.7 =
## 0.536) - böylece saniyedeki adım sayısı %30 azalır (2.67 -> 1.87 adım/sn).
## SONRAKİ GERİ BİLDİRİM (bildirim: "biraz arttır çok yavaş oldu bu kez de"):
## 0.536 fazla yavaş kaldığı için aralık ikisinin ARASINA çekildi - 0.45sn
## (2.22 adım/sn): hem "çok hızlı" bulunan eski 0.375'ten yavaş, hem de "çok
## yavaş" bulunan 0.536'dan hızlı.
##
## Kullanıcı isteği (bildirim: "karakterin hareket hızıyla eşitlememiz gerek"):
## aralık, karakterin O ANKİ GERÇEK hareket hızı oranına bölünüyor (bkz.
## _update_walk_sound). Hız oranı hem adım aralığını böler hem seslerin
## pitch'ini çarpar, yani:
##     adım başına alınan yol = hız x aralık = (taban hız x oran) x
##     (WALK_STEP_INTERVAL / oran) = SABİT
## - adımlar karakterin hızıyla birebir eşleşir: hızlanınca adımlar hem
## sıklaşır hem tizleşir, ama iki adım arasında alınan mesafe hep aynı kalır.
const WALK_STEP_INTERVAL := 0.45
## Hız çarpanının sınırları - bu TEK sınır hem adım aralığını hem seslerin
## tizliğini belirler: 0.85 = belirgin yavaşlatılmış (seyrek/kalın adımlar),
## 1.8 = çok hızlı (sık/tiz adımlar).
const WALK_SPEED_RATIO_MIN := 0.85
const WALK_SPEED_RATIO_MAX := 1.8
## Kullanıcı bildirimi: "hareket hızı artınca adım sesleri çok gereksiz hızlı
## spamlanıyor, daha yavaş etkilenmesi gerek hareket hızından" - adımların
## ARALIĞI artık speed_ratio'yu DOĞRUDAN değil, 1.0'a bu oranda yaklaştırılmış
## (dampened) haliyle bölüyor (bkz. _update_walk_sound). Sesin TİZLİĞİ hâlâ
## tam speed_ratio'yu kullanıyor (bununla ilgili bir şikayet yoktu) - sadece
## adımların SIKLIĞI hıza daha az duyarlı.
const WALK_STEP_INTERVAL_SPEED_INFLUENCE := 0.5
## Her adımda pitch'e eklenen ÇOK KÜÇÜK rastgele sapma (±%4 ≈ 0.7 yarım perde):
## aynı sesin tekrar tekrar çalındığı belli olmasın, ama kulağa "farklı ses"
## gibi de gelmesin (kullanıcı isteği: "fark edilmeyecek derecede çok az").
const WALK_SOUND_PITCH_JITTER := 0.04
## Sahnede bulunan TÜM adım sesi çalıcıları - bkz. _collect_walk_sounds().
@onready var _walk_sounds: Array[AudioStreamPlayer2D] = _collect_walk_sounds()
## Sıradaki adıma kalan süre (sn) - dolduğunda rastgele bir adım sesi çalınır.
var _walk_step_timer: float = 0.0
@onready var shield_hit_sound: AudioStreamPlayer2D = $ShieldHitSound
## Kullanıcı isteği: "kalkansız hasar alma adında bir ses ekledim bu ses kalkan
## yokken karakter hasar alırsa çıkacak." - kalkanın EMTİĞİ isabetlerde
## shield_hit_sound, kalkan YOKKEN cana işleyen isabetlerde bu çalar
## (bkz. take_damage -> shield_absorbed_hit).
@onready var no_shield_damage_sound: AudioStreamPlayer2D = $NoShieldDamageSound
## Sadece Büyücü Kız (selected_char_id == 4) için - bkz. _activate_skill().
@onready var buyucu_ulti_sound: AudioStreamPlayer2D = $BuyucuUltiSound

## How many times each level-up card id has been picked this run, so the
## level-up screen can show "daha önce N kez alındı".
var upgrade_counts: Dictionary = {}


func get_upgrade_count(id: String) -> int:
	return upgrade_counts.get(id, 0)


func _ready() -> void:
	add_to_group("player")
	## Kullanıcı isteği: "oyundaki tüm oynanabilir karakterleri ve yaratıkları
	## v.s %5 küçültüp hareket hızlarını %10 azaltmanı istiyorum" - bkz.
	## EntityScale. Sahnedeki speed değeri elle değiştirilmedi, çarpan burada
	## uygulanıyor (enemy.gd'deki GLOBAL_SPEED_SCALE ile aynı desen).
	## ÖNEMLİ: _anim_base_speed biraz aşağıda bu değerden okunduğu için koşma
	## animasyonu eşiği de kendiliğinden aynı oranda kayar; ayrıca yaratıkları
	## takip eden evcil hayvanlar da hızlarını `player.speed`ten türettiği için
	## (bkz. golem_pet.gd/skeleton_pet.gd/wraith_pet.gd setup_from_player,
	## player_pet.gd FOLLOW_SPEED_MULT) onlar da kendiliğinden %10 yavaşlar.
	speed *= EntityScale.SPEED
	health_changed.connect(overhead_bar.set_health)
	item_shield_changed.connect(overhead_bar.set_shield)
	health = max_health
	health_changed.emit(health, max_health)
	xp_changed.emit(xp, xp_to_next_level)
	_anim_base_speed = speed
	if name_label:
		name_label.text = NetworkManager.local_player_name if NetworkManager.is_multiplayer_active else ""
	_load_character_frames()
	## Kullanıcı isteği (bkz. EntityScale): görselin ölçeği
	## _load_character_frames() içinde (char_base_anim_scale) küçültülüyor,
	## burada da gövde çemberi + kalkan baloncuğu küçültülüyor. Kök düğüm
	## BİLEREK ölçeklenmiyor: Camera2D kökün çocuğu olduğu için onu
	## ölçeklemek görüş alanını/zoom'u da değiştirirdi (istenen sadece
	## karakterin küçülmesi).
	_apply_entity_size_scale()
	if anim:
		anim.play("idle_down")
	if shield_visual:
		shield_visual.visible = false
		if shield_visual.has_method("set_shield_type"):
			shield_visual.set_shield_type(_owned_shield_type_key())
	_recompute_shield_protection()
	_apply_shield_mode()

	## NOT: Adım sesleri artık TEK SEFERLİK (bkz. yukarıdaki yürüme sesi notu),
	## bu yüzden burada stream döngü ayarı YAPILMIYOR. Önceki "tek ses döngüde
	## çalar" planında (yürüme sesi.mp3) stream'i çalışma zamanında döngüye
	## almak gerekiyordu; şimdi her adım kendi sesini bir kez çalıp bitiyor.

	## Chat balonu (bkz. scripts/chat_bubble.gd) - remote_player.gd'deki
	## AYNI script, ikisi de dinamik olarak oluşturuluyor.
	_chat_bubble = Node2D.new()
	_chat_bubble.set_script(preload("res://scripts/chat_bubble.gd"))
	add_child(_chat_bubble)

	## Kullanıcı isteği: "kimsenin başlangıç silahı yok" - artık hiçbir
	## otomatik silah verilmiyor (eski _grant_starting_weapon()/STARTING_
	## WEAPON_BY_CHAR kaldırıldı). Oyuncu main.gd'nin gösterdiği silah seçim
	## ekranından (bkz. weapon_select_screen.gd) seçtiği silahla
	## GameManager.owned_weapons'a eklenir - o an owned_weapons boş olduğu
	## için aşağıdaki döngü bu noktada henüz hiçbir şey kurmaz, sorun değil.

	## Dükkandan satın alınan TÜM silahlar (başlangıç silahı dahil) burada
	## sırayla geri yükleniyor - en fazla get_max_owned_weapons() tane, türü
	## karışık olabilir, HER kopyanın kendine özel bir seviyesi var (bkz.
	## GameManager.owned_weapons, buy_weapon_copy).
	for entry in GameManager.owned_weapons:
		buy_weapon_copy(entry.get("key", ""), entry.get("level", 1))

	## buy_weapon_copy() zaten her çağrıldığında yeniden konumlandırıyor, ama
	## hiç silah alınmamışsa (yukarıdaki döngü hiç çalışmazsa - normalde
	## olmaz, herkesin en az 1 başlangıç silahı var) bu hiç tetiklenmez - o
	## yüzden burada bir kere daha, koşulsuz çağrılıyor.
	_reposition_weapon_icons()


## Dükkandan satın alınabilecek/başlangıçta sahip olunabilecek silahların
## sahneleri - buy_weapon_copy() bununla instantiate eder.
const WEAPON_SCENES_BY_KEY := {
	"dagger": DaggerWeaponScene,
	"fire_staff": FireWeaponScene, "lightning_staff": LightningWeaponScene,
	"tabanca": TabancaWeaponScene, "tuftuf": TuftufWeaponScene, "tufek": TufekWeaponScene,
	"arcane": ArcaneWeaponScene, "yay": YayWeaponScene,
	"crossbow": CrossbowWeaponScene, "boomerang": BoomerangWeaponScene,
	"buz_asasi": BuzAsasiWeaponScene, "fisek": FisekWeaponScene,
	"pence": PenceWeaponScene, "topuz": TopuzWeaponScene,
	"uzunkilic": UzunkilicWeaponScene,
}

## Dükkandan satın alınan/başlangıçta sahip olunan silahlar - türü karışık
## olabilir ama en fazla bu kadar (başlangıç silahı dahil toplam). Herkes
## için aynı: WEAPON_ICON_SLOTS.size() ile birebir (kullanıcının çizdiği
## yıldız diyagramındaki 5 nokta) - artık "ana silah ayrı sayılır mı"
## sorusu yok, çünkü ayrı bir ana silah kavramı hiç yok.
const MAX_OWNED_WEAPONS := 5

func get_max_owned_weapons() -> int:
	## Talon'un Ayna Formu (skill id 38, bkz. _skill_talon_mirror_form) 15sn
	## boyunca silah sayısını 2 katına çıkarır - buy_weapon_copy()'nin normal
	## 5 sınırını geçici olarak gevşetir ki gerçek kopyalar (kendi setup/
	## bonus/tier mantığıyla, bkz. o fonksiyon) oluşturulabilsin.
	if _talon_mirror_form_active:
		return MAX_OWNED_WEAPONS * 2
	return MAX_OWNED_WEAPONS

## owned_weapons ile SIRA/INDEX olarak birebir eşleşen gerçek node dizisi -
## GameManager.owned_weapons sadece veriyi (key/level/spent) tutar, bu dizi
## sahnedeki gerçek Weapon instance'larını tutar. Her node'a hangi silah
## türü olduğu "shop_key" meta'sıyla etiketlenir (bkz. set_owned_weapon_level).
var owned_weapon_nodes: Array = []


## HUD/stats panel gibi "tek bir silahın statlarını göster" ihtiyacı olan
## yerler için - başlangıç silahı (owned_weapon_nodes[0]) döner, hiç silah
## yoksa (normalde asla olmaz, herkes en az 1 tane ile başlar) null döner.
func get_primary_weapon():
	if owned_weapon_nodes.size() > 0 and is_instance_valid(owned_weapon_nodes[0]):
		return owned_weapon_nodes[0]
	return null


## Yeni bir kopya ekler (satın alma VEYA kayıtlı oyunu geri yükleme için) -
## get_max_owned_weapons() doluysa hiçbir şey yapmadan false döner. Her kopya
## kendi icon_sprite/fire_timer'ıyla tamamen bağımsız ateş eder ve diğer
## silahler gibi kafanın üstünde KENDİ ayrı ikonuyla durur (grup/rozet yok -
## bkz. _reposition_weapon_icons).
func buy_weapon_copy(key: String, level: int) -> bool:
	if owned_weapon_nodes.size() >= get_max_owned_weapons():
		return false
	var scene: PackedScene = WEAPON_SCENES_BY_KEY.get(key)
	if not scene:
		return false
	var w = scene.instantiate()
	add_child(w)
	owned_weapon_nodes.append(w)
	w.set_meta("shop_key", key)
	if key == "dagger":
		_configure_dagger_melee(w)
	elif key == "pence":
		_configure_pence_melee(w)
	elif key == "topuz":
		_configure_topuz_melee(w)
	elif key == "uzunkilic":
		_configure_uzunkilic_melee(w)
	if w.has_signal("fired"):
		w.fired.connect(_on_weapon_fired)
	_apply_weapon_bonuses_to(w)
	apply_owned_weapon_tier(w, key, level)
	_reposition_weapon_icons()
	## Kullanıcı bildirimi: "karakterin silahları içeride gözükmemeli" -
	## oyun artık ev içindeyken başlayıp (bkz. house_interior.gd _ready())
	## birkaç saniye sonra silah seçim kartı açtığı için, seçilen İLK silah
	## tam olarak is_indoors=true iken buradan yaratılıyor. house_interior.gd
	## _enter_house()'daki gizleme SADECE o an zaten var olan silahları
	## kapsıyor - buraya sonradan eklenen bir kopyayı da aynı görünmez/donuk
	## duruma sokmak için burada ayrıca kontrol ediliyor.
	## DÜZELTME (kullanıcı bildirimi: "Fişek tüfek ve bıçak market alanın
	## içinde saldırı yapmaya devam ediyor") - dükkan SADECE seyyar satıcının
	## güvenli bölgesinin içinden açılabildiği için (etkileşim yarıçapı 80 <
	## bölge yarıçapı 264.6, bkz. traveling_merchant.gd/game_manager.gd) yeni
	## satın alınan HER silah is_in_merchant_zone=true İKEN doğuyordu - ama
	## set_combat_active() sadece bölgeye GİRİŞ/ÇIKIŞ GEÇİŞİNDE çalıştığı
	## için (bkz. _process_merchant_zone_state), zaten bölgedeyken doğan bu
	## yeni node hiç devre dışı bırakılmıyordu. is_indoors ile AYNI kontrol.
	if is_indoors or is_in_merchant_zone:
		w.visible = false
		w.process_mode = Node.PROCESS_MODE_DISABLED
	return true


## Geliştirmeler sekmesindeki "sat" - owned_weapon_nodes[index]'i tamamen
## kaldırır. shop_panel.gd _on_sell_weapon zaten "son silahını satamazsın"
## kontrolünü yapıyor, burası saf bir kaldırma fonksiyonu.
func remove_owned_weapon(index: int) -> bool:
	if index < 0 or index >= owned_weapon_nodes.size():
		return false
	var w = owned_weapon_nodes[index]
	owned_weapon_nodes.remove_at(index)
	if is_instance_valid(w):
		w.queue_free()
	_reposition_weapon_icons()
	return true


## ---------- Eşyalar (Items) ----------
func get_max_item_slots() -> int:
	return max_item_slots


## Items.DEFS[key]["stats"] içindeki her girdiyi player.gd'nin ilgili stat'ına
## uygular - sign=+1 satın alırken, sign=-1 satarken (birebir simetrik geri
## alma). Birkaç stat (dodge_chance/knockback_stat/max_health) özel işlem
## gerektiriyor (cap/eşleşen ikinci alan), geri kalan HER ŞEY dinamik set/get
## ile genel olarak uygulanıyor - bkz. items.gd üstündeki yorum.
## power_mult: kullanıcı isteği "sandık eşyalarının tier'ı olacak, tier
## başına güç %50 fazla" (bkz. Items.ITEM_TIER_POWER) - sandıktan gelen bir
## eşya Tier 2/3/4 ise buraya 1.5/2.0/2.5 geçilir, dükkandan düz satın alınan
## eşyalerde varsayılan 1.0 (Tier 1) ile eskisiyle birebir aynı davranır.
func _apply_item_stats(key: String, stat_sign: float, power_mult: float = 1.0) -> void:
	var def: Dictionary = Items.get_def(key)
	var stats: Dictionary = def.get("stats", {})
	for stat_name in stats:
		var delta: float = float(stats[stat_name]) * stat_sign * power_mult
		match stat_name:
			"dodge_chance":
				## Eşyalar için taşma başka bir stat'a DÖNÜŞMEZ (kullanıcı
				## isteği: "Maksimum stat sınırlarını geçemezler") - basitçe
				## cap'te kırpılır, satarken de aynı şekilde kırpılı kalır.
				dodge_chance = clamp(dodge_chance + delta, 0.0, DODGE_CHANCE_CAP)
			"knockback_stat":
				knockback_stat += delta
				knockback_force += delta
			"max_health":
				max_health = max(1.0, max_health + delta)
				if delta > 0.0:
					health += delta ## satın alırken de kart gibi anında iyileştirir
				health = clamp(health, 0.0, max_health)
				health_changed.emit(health, max_health)
			"shield_pen_percent":
				shield_pen_percent = clamp(shield_pen_percent + delta, 0.0, 1.0)
			_:
				if stat_name in self:
					set(stat_name, get(stat_name) + delta)
	_recompute_shield_protection()
	refresh_shield_stats()
	_apply_weapon_bonuses()


## Dükkandan (ya da bir sandıktan, bkz. chest_menu.gd) bir eşya satın alır
## (kind="copy" gibi ama HİÇ seviyelenmez) - get_max_item_slots() doluysa
## false döner. Aynı eşyadan istenildiği kadar kopya alınabilir (kullanıcı
## isteği), her biri kendi statlarını AYRI AYRI ekler (additive stacking).
## power_mult: bkz. _apply_item_stats üstündeki not - varsayılan 1.0 (dükkan/
## Tier 1), sandık eşyaları kendi tier'lerine göre daha yüksek geçer.
func buy_item(key: String, power_mult: float = 1.0) -> bool:
	if not Items.DEFS.has(key):
		return false
	if GameManager.owned_items.size() >= get_max_item_slots():
		return false
	_apply_item_stats(key, 1.0, power_mult)
	return true


## Envanterden bir eşya kopyasını satar - GameManager.owned_items[index]'in
## KENDİSİ shop_panel.gd/inventory_panel.gd tarafından kaldırılır, burası
## sadece o kopyanın statlarını geri alır (sign=-1).
## BUG'DAN KORUMA: kopyanın satın alındığı GÜÇ (tier) ile AYNI çarpanla geri
## alınmalı - entry'nin kendi "power" alanı okunuyor (bkz. GameManager.
## owned_items'a eklerken bu alanın nasıl yazıldığına dair chest_menu.gd/
## shop_panel.gd notları). Yoksa Tier 2+ bir sandık eşyası satıldığında
## sadece Tier 1 kadarı geri alınır, fazlası KALICI olarak oyuncuda kalırdı.
func remove_owned_item(index: int) -> bool:
	if index < 0 or index >= GameManager.owned_items.size():
		return false
	var entry: Dictionary = GameManager.owned_items[index]
	var key: String = entry.get("key", "")
	var power_mult: float = float(entry.get("power", 1.0))
	_apply_item_stats(key, -1.0, power_mult)
	return true


## Geliştirmeler sekmesindeki "Seviye Atlat" - SADECE owned_weapon_nodes[index]
## kopyasının seviyesini günceller, aynı türden başka kopyalar (varsa) hiç
## etkilenmez - her kopya kendi bağımsız geliştirmesine sahip.
func set_owned_weapon_level(index: int, level: int) -> void:
	if index < 0 or index >= owned_weapon_nodes.size():
		return
	var w = owned_weapon_nodes[index]
	if not is_instance_valid(w):
		return
	var key: String = w.get_meta("shop_key", "")
	apply_owned_weapon_tier(w, key, level)


## Tek bir silah instance'ına, tek bir seviyeye göre tier uygular - hem
## dükkandan alınan bağımsız kopyalar (buy_weapon_copy/set_owned_weapon_level)
## HEM Matthew'in ana Tüftüf'ü (_ready()'de doğrudan) bunu kullanır.
## 100 seviyeye rebalance (kullanıcı isteği: "Tüm silah/kalkan
## geliştirmelerini 100 levele yükseltip gelişim başına artan statları da
## buna göre güncelle - 100 levele arttırmamız daha güçlü olacakları anlamına
## gelmiyor sadece geliştirmelerin güçlendirmesi ufak ufak gelecek... kademe
## 3-5-7-10'da verilen güçlendirmeler 100 levele göre sıralanmalı: kademe
## 3=30 level, kademe 5=50 level, kademe 7=70 level, kademe 10=100 level.")
##
## Eskiden bu 13+1 silah (fire_staff hariç, o kademesizdi - bkz. aşağıda)
## 10 (bazıları 30, bkz. shop_panel.gd MAX_LEVELS eski değerleri) seviyeye
## kapalıydı ve "tier" (int, clamp(level,1,10)) DOĞRUDAN "level"e eşitti - bu
## yüzden tek bir "tier" değişkeni HEM sürekli büyüyen statları (hasar/ateş
## hızı/zırh delme gibi her seviyede küçük küçük artan şeyler) HEM de dönüm
## noktası (3/5/7/10) bonuslarını AYNI ANDA temsil edebiliyordu. Artık 100
## seviye olduğu için bu ikisi ayrıştı:
##   _tier_from_level10(level): sürekli büyüyen statlar İÇİN - level 1'de
##   eski tier 1, level 100'de eski tier 10 ile TAM AYNI değeri verecek
##   şekilde DÜZGÜN (lineer) ara değer üretir. Aşağıdaki "(tier-1)*X"/
##   "tier*X" formülleri HİÇ DEĞİŞMEDİ, sadece eski int tier'in yerine bu
##   float geldi - uç noktalar (level 1 ve level 100) eski (level 1 ve level
##   10) ile birebir eşit kalıyor, aradaki her seviye ESKİSİNDEN ÇOK daha
##   ufak bir artış veriyor (istenen "ufak ufak güçlenme").
##   Dönüm noktası bonusları (poison ramp çarpanı/pierce sayısı/crit hasarı
##   gibi İKİNCİL, "aşağı yukarı sabit basamak" bonuslar) ise artık ham
##   `level`e bakıp 30/50/70/100 eşiklerini kontrol ediyor (kullanıcının
##   verdiği TAM eşleme) - bonus DEĞERLERİ hiç değişmedi, sadece eşik seviyesi.
##   _visual_tier_from_level(level): weapon.gd'nin set_weapon_tier()/
##   tier_icon_textures'ı SADECE eski 1/3/5/7/10 karşılığı kadar ikon
##   içeriyor - ham level (1..100) verilirse ikon hep aynı (son) tier'de
##   kilitli kalırdı, bu yüzden görsel güncelleme için bu ayrı staircase
##   fonksiyonu kullanılıyor.
## Kullanıcı isteği: "Oyundaki geliştirilebilen tüm itemlerin levele göre
## gelişme hızını %100 arttır. Yani level başına verilecek statlar %100
## artacak her levelde." - bu, çoğu silahın (bkz. yukarıdaki not - ~12
## _apply_*_tier fonksiyonu bu TEK paylaşılan fonksiyonu kullanıyor) sürekli
## per-level büyümesinin kaynağı. Level 1'deki taban (tier=1.0, "hiç
## geliştirilmemiş" durumu) DEĞİŞMEDİ - sadece seviye başına artış (eski
## 9.0/99.0) iki katına çıkarıldı (18.0/99.0), yani level 100'deki tavan da
## eskisinin İKİ KATI kadar (tier 10 -> 19) bonus üretiyor - "(tier-1)*X"
## formüllerinin hepsi bunu otomatik yansıtır.
##
## DÜZELTME (kullanıcı isteği: "Silah ve kalkan tierlarını 100 yapmanı
## istemiştim onu 20'ye düşürerek geliştirme bedellerinin fiyatını ve
## geliştirme başına artan gücünü buna göre eşitle. 100 leveldeki güç nasılsa
## 20 leveldeki güç de öyle olacak şekilde güncelle.") - max seviye 100'den
## 20'ye indi (bkz. shop_panel.gd MAX_LEVELS). UÇ NOKTALAR (level 1 -> tier
## 1.0, level 20 -> tier 19.0) BİREBİR AYNI KALDI - sadece payda 99'dan 19'a
## indi, yani artık 20 (eskiden 100) adımda AYNI 1.0->19.0 aralığı taranıyor.
## Sonuç: eski level 100'ün ürettiği HER stat, yeni level 20'de DE aynen
## üretiliyor - "100 leveldeki güç ne ise 20 leveldeki güç de o" isteği
## otomatik sağlanıyor, "(tier-1)*X" formüllerinin hiçbirine dokunmaya gerek
## kalmadı.
static func _tier_from_level10(level: int) -> float:
	var lvl: int = clampi(level, 1, 20)
	return 1.0 + (float(lvl) - 1.0) * 18.0 / 19.0


static func _visual_tier_from_level(level: int) -> int:
	if level >= 20:
		return 10
	elif level >= 14:
		return 7
	elif level >= 10:
		return 5
	elif level >= 6:
		return 3
	return 1


func apply_owned_weapon_tier(w, key: String, level: int) -> void:
	if key == "tuftuf":
		_apply_tuftuf_tier(w, level)
	elif key == "tufek":
		_apply_tufek_tier(w, level)
	elif key == "tabanca":
		_apply_tabanca_tier(w, level)
	elif key == "arcane":
		_apply_arcane_tier(w, level)
	elif key == "dagger":
		_apply_hancer_tier(w, level)
	elif key == "yay":
		_apply_yay_tier(w, level)
	elif key == "crossbow":
		_apply_crossbow_tier(w, level)
	elif key == "boomerang":
		_apply_boomerang_tier(w, level)
	elif key == "buz_asasi":
		_apply_buz_asasi_tier(w, level)
	elif key == "fisek":
		_apply_fisek_tier(w, level)
	elif key == "pence":
		_apply_pence_tier(w, level)
	elif key == "topuz":
		_apply_topuz_tier(w, level)
	elif key == "uzunkilic":
		_apply_uzunkilic_tier(w, level)
	elif key == "lightning_staff":
		_apply_lightning_tier(w, level)
	## DÜZELTME (100-level rebalance): fire_staff eskiden kademesizdi (bu
	## generic "else" dalına düşüyordu, diğer 14 silahın hiçbirinde olmayan
	## bir eksiklikti). Şimdi tutarlılık için diğerleriyle aynı 1/3/5/7/10
	## dönüm noktası desenine kavuştu (bkz. _apply_fire_staff_tier) -
	## kullanıcının literal isteğinin ötesinde bir ek, mevcut 14 silahla
	## tutarlılık için eklendi.
	elif key == "fire_staff":
		_apply_fire_staff_tier(w, level)
	else:
		var dmg_bonus: float = (level - 1) * 3.0
		var fr_mult: float = max(0.5, 1.0 - (level - 1) * 0.015)
		if w.has_method("set_shop_damage_bonus"):
			w.set_shop_damage_bonus(dmg_bonus)
		if w.has_method("set_shop_fire_rate_mult"):
			w.set_shop_fire_rate_mult(fr_mult)


## Tüftüf: diğer dükkan silahları gibi 30 değil, 10 tier'e kapalı - bkz.
## tüftüf özellikleri.txt (2026 güncellemesi).
##   hasar: tier başına 5 hasar + saldırı gücünün (damage_bonus) %50'si
##   (saldırı gücü oranı tier'e göre değişmez - bkz. weapon.gd
##   card_damage_bonus_ratio, weapon_tuftuf.tscn'de 0.5 olarak ayarlı, bu
##   yüzden burada SADECE tier'e bağlı düz kısım (tier1 taban HARİÇ, tier
##   başına +5) set_shop_damage_bonus ile ekleniyor).
##   ateş hızı: tier başına %8 daha hızlı (tier 10'da ~%72 daha hızlı,
##   min. çarpan 0.3 ile sınırlı) - değişmedi.
## Zehirin "saniye başına artan hasarı" (ramp) da aynı şablonu izler: tier
## başına 1 + saldırı gücünün %1'i, 3/5/7/10. seviyelerde KÜMÜLATİF +%50
## (bkz. _refresh_tuftuf_poison - "Dönüm noktalarındaki her tierın sağladığı
## stata önceki tier dönüm noktasının sağladığı statlar dahildir" -> tier
## 3-4: x1.5, 5-6: x2.0, 7-9: x2.5, 10: x3.0). Zehrin İLK tıkı da bu ramp
## değeriyle başlar (1x, 2x, 3x... diye büyüyen düz bir merdiven).
const TUFTUF_POISON_RAMP_PER_TIER := 1.0
const TUFTUF_POISON_RAMP_ATTACK_POWER_RATIO := 0.01
const TUFTUF_BASE_POISON_DURATION := 30.0

func _apply_tuftuf_tier(w, level: int) -> void:
	## Matthew'in başlangıç Tüftüf'ü DAHİL, her Tüftüf kopyası aynı kuralı
	## izler - taze, level 1'den başlar, hiçbir özel kaydırma/bonus yok
	## (hiçbir karakterin ayrı bir "ana silahı" olmadığı için).
	var tier: float = _tier_from_level10(level)
	var dmg_bonus: float = (tier - 1.0) * 5.0
	var fr_mult: float = max(0.3, 1.0 - (tier - 1.0) * 0.08)
	if w.has_method("set_shop_damage_bonus"):
		w.set_shop_damage_bonus(dmg_bonus)
	if w.has_method("set_shop_fire_rate_mult"):
		w.set_shop_fire_rate_mult(fr_mult)
	if w.has_method("set_weapon_tier"):
		w.set_weapon_tier(_visual_tier_from_level(level))
	_refresh_tuftuf_poison(w)


## Zehrin "saniye başına artan hasarı" da (tıpkı silahın kendi hasarı gibi)
## saldırı gücünden (damage_bonus) pay alıyor - bu yüzden SADECE tier
## değiştiğinde (_apply_tuftuf_tier) değil, HER Hasar kartı alındığında da
## (damage_bonus güncellendiğinde, bkz. _apply_weapon_bonuses_to) yeniden
## hesaplanmalı, yoksa run ilerledikçe zehir "eski" kalır. Tier, silahın
## kendi set_weapon_tier() ile sakladığı _current_tier'dan okunur.
func _refresh_tuftuf_poison(w) -> void:
	if not is_instance_valid(w):
		return
	var tier: int = int(w.get("_current_tier") if "_current_tier" in w else 1)
	var milestone_mult: float = 1.0
	if tier >= 10:
		milestone_mult = 3.0
	elif tier >= 7:
		milestone_mult = 2.5
	elif tier >= 5:
		milestone_mult = 2.0
	elif tier >= 3:
		milestone_mult = 1.5
	var ramp: float = (tier * TUFTUF_POISON_RAMP_PER_TIER + damage_bonus * TUFTUF_POISON_RAMP_ATTACK_POWER_RATIO) * milestone_mult
	if "poison_tick_damage" in w:
		w.poison_tick_damage = ramp
	if "poison_ramp_per_tick" in w:
		w.poison_ramp_per_tick = ramp
	if "poison_duration" in w:
		w.poison_duration = TUFTUF_BASE_POISON_DURATION


## Arcane Asası: Tüftüf/Tüfek gibi 10 tier'e kapalı - bkz. Arcane asasının
## özellikleri.txt.
##   hasar: tier başına +16 (tier1 taban zaten weapon_arcane.tscn'de damage
##   olarak ayarlı, burada SADECE tier'e bağlı düz kısım ekleniyor -
##   card_damage_bonus_ratio hiç override edilmedi, yani Hasar kartlarının
##   saldırı gücü diğer silahlardaki gibi %100 ağırlıkla ekleniyor)
##   dönüm noktası bonusu: 3/5/7/10. seviyelerde KÜMÜLATİF +%8 (tier 3-4:
##   x1.08, 5-6: x1.16, 7-9: x1.24, 10: x1.32) - weapon.gd'deki YENİ
##   çarpımsal set_tier_damage_mult() katmanı ile uygulanıyor (düz tier
##   bonusu dahil TÜM hasara çarpımsal olarak etki etsin diye).
func _apply_arcane_tier(w, level: int) -> void:
	var tier: float = _tier_from_level10(level)
	var dmg_bonus: float = (tier - 1.0) * 16.0
	if w.has_method("set_shop_damage_bonus"):
		w.set_shop_damage_bonus(dmg_bonus)
	var milestone_mult: float = 1.0
	if level >= 20:
		milestone_mult = 1.32
	elif level >= 14:
		milestone_mult = 1.24
	elif level >= 10:
		milestone_mult = 1.16
	elif level >= 6:
		milestone_mult = 1.08
	if w.has_method("set_tier_damage_mult"):
		w.set_tier_damage_mult(milestone_mult)
	if w.has_method("set_weapon_tier"):
		w.set_weapon_tier(_visual_tier_from_level(level))


## Tüfek: Tüftüf gibi 10 tier'e kapalı - bkz. tüfeğin
## özellikleri.txt. Reload/mermi sistemi tamamen kaldırıldı - artık diğer
## reload'suz silahlar gibi sınırsız/anında ateş ediyor (bkz.
## weapon_tufek.tscn - max_ammo hiç set edilmiyor, weapon.gd'de varsayılan
## 0 kalıyor ki bu reload mantığını tamamen devre dışı bırakıyor).
##   hasar: tier başına +20
##   kalkan delme: tier başına +%3 (bu silahın kendi mermilerine özel, bkz.
##   weapon.gd weapon_shield_pen_bonus - oyuncunun genel kalkan delme
##   statından bağımsız, ona EK olarak uygulanır) - DÜZELTME (zırh kaldırıldı,
##   yerini kalkan delme aldı): eskiden weapon_armor_pen_bonus idi.
## Delme sayısı (pierce_count, birincil hedeften SONRA kaç ek düşmana daha
## çarpacağı) ve delici hasar (pierce_damage_percent) taban 1 ek düşman/%30 -
## dönüm noktalarında ikisi de birlikte sıçrar:
##   tier 3: 2 ek düşman delinir, delici hasar %40
##   tier 5: 3 ek düşman delinir, delici hasar %50
##   tier 7: 4 ek düşman delinir, delici hasar %60
##   tier 10: 5 ek düşman delinir, delici hasar %70

func _apply_tufek_tier(w, level: int) -> void:
	var tier: float = _tier_from_level10(level)
	var dmg_bonus: float = (tier - 1.0) * 20.0
	if w.has_method("set_shop_damage_bonus"):
		w.set_shop_damage_bonus(dmg_bonus)
	## Kullanıcı isteği (1. tur): "tüfeğin saldırı gücü oranını %30 arttır" -
	## weapon.gd card_damage_bonus_ratio varsayılanı (1.0 = oyuncunun saldırı
	## gücünün %100'ü) tüfek için hiç override edilmiyordu, %130'a çıkarıldı.
	## DÜZELTME (2. tur, kullanıcı isteği #27: "tüfeğin saldırı gücü oranını
	## %50 arttır") - mevcut 1.3 üstüne BİR KEZ DAHA %50: 1.3 * 1.5 = 1.95.
	w.card_damage_bonus_ratio = 1.95
	w.weapon_shield_pen_bonus = (tier - 1.0) * 0.03
	## Silahın görseli de aynı dönüm noktalarında (3/5/7/10, artık 30/50/70/100
	## level'de) yenilenir - bkz. weapon_tufek.tscn tier_icon_textures ve
	## weapon.gd set_weapon_tier().
	if w.has_method("set_weapon_tier"):
		w.set_weapon_tier(_visual_tier_from_level(level))
	var pierce_count: int = 1
	var pierce_percent: float = 0.3
	if level >= 20:
		pierce_count = 5
		pierce_percent = 0.7
	elif level >= 14:
		pierce_count = 4
		pierce_percent = 0.6
	elif level >= 10:
		pierce_count = 3
		pierce_percent = 0.5
	elif level >= 6:
		pierce_count = 2
		pierce_percent = 0.4
	w.pierce_count = pierce_count
	w.pierce_damage_percent = pierce_percent


## Tabanca: 2026 güncellemesi (bkz. Tabancanın özellikleri.txt) - eski mermi/
## reload sistemi tamamen kaldırıldı (Tüfek gibi artık sınırsız/anında ateş
## ediyor), yerine hedefte biriken "yük" (mark) mekaniği geldi. Taban hasar
## (17 + %90 saldırı gücü) VE ateş hızı tier'e göre DÜZ ARTMAZ - metinde
## "tier başına X" ifadesi hiç yok, sadece dönüm noktaları (3/5/7/10) ateş
## hızını VE yük kapasitesini artırıyor:
##   3/5/7 seviye: +%10 ateş hızı + %5 yük kapasitesi
##   10. seviye: +%12 ateş hızı + %5 yük kapasitesi
## Yük kapasitesi taban %70 (=70 yük, 1 yük=%1 hasar) - dönüm noktalarıyla
## kümülatif %90'a kadar çıkar (70/75/80/85/90).
func _apply_tabanca_tier(w, level: int) -> void:
	var milestone_fr_bonus: float = 0.0
	var milestone_mark_bonus: int = 0
	if level >= 20:
		milestone_fr_bonus = 0.10 + 0.10 + 0.10 + 0.12
		milestone_mark_bonus = 20
	elif level >= 14:
		milestone_fr_bonus = 0.10 + 0.10 + 0.10
		milestone_mark_bonus = 15
	elif level >= 10:
		milestone_fr_bonus = 0.10 + 0.10
		milestone_mark_bonus = 10
	elif level >= 6:
		milestone_fr_bonus = 0.10
		milestone_mark_bonus = 5
	var fr_mult: float = max(0.15, 1.0 - milestone_fr_bonus)
	if w.has_method("set_shop_fire_rate_mult"):
		w.set_shop_fire_rate_mult(fr_mult)
	w.mark_max_stacks = 70 + milestone_mark_bonus


## Hançer (Dagger): bkz. Hançerin özellikleri.txt. Diğer bazı 2026 güncellemesi
## silahler (Tabanca) gibi taban hasar/ateş hızı tier'e göre DÜZ ARTMAZ - tüm
## güç artışı kanama mekaniğinden gelir:
##   kapasite (bir hedefte AZAMİ birikebilecek yük sayısı): tier'e eşit (1..10)
##   yük/isabet (bir vuruşta eklenen yük sayısı): taban 1, dönüm noktalarında
##   (3/5/7/10) kümülatif +1 (tier 10'da isabet başına 5 yük)
##   yük başına saniye hasarı: tier + saldırı gücünün %5'i (tıpkı Tüftüf'ün
##   zehir ramp'i gibi - _refresh_hancer_bleed ile HER Hasar kartında da
##   tazelenir, sadece tier değişince değil).
const HANCER_BLEED_ATTACK_POWER_RATIO := 0.05

func _apply_hancer_tier(w, level: int) -> void:
	## bleed_max_stacks eskiden doğrudan "tier" (=level, 1..10) idi - artık
	## _tier_from_level10 ile 1..10 arasına yuvarlanarak dönüştürülüyor
	## (level 1 -> 1, level 100 -> 10, arada ~10 basamaklı düzgün bir artış).
	w.bleed_max_stacks = int(round(_tier_from_level10(level)))
	if level >= 20:
		w.bleed_stacks_per_hit = 5
	elif level >= 14:
		w.bleed_stacks_per_hit = 4
	elif level >= 10:
		w.bleed_stacks_per_hit = 3
	elif level >= 6:
		w.bleed_stacks_per_hit = 2
	else:
		w.bleed_stacks_per_hit = 1
	_refresh_hancer_bleed(w)


## Kanama tik hasarı saldırı gücünden (damage_bonus) pay aldığı için tier
## değişmese bile HER Hasar kartı alındığında yeniden hesaplanmalı - tier,
## silahın kendi tuttuğu bleed_max_stacks'ten (=tier) geri okunur.
func _refresh_hancer_bleed(w) -> void:
	if not is_instance_valid(w):
		return
	var tier: int = int(w.get("bleed_max_stacks") if "bleed_max_stacks" in w else 1)
	if "bleed_tick_damage_per_stack" in w:
		w.bleed_tick_damage_per_stack = float(tier) + damage_bonus * HANCER_BLEED_ATTACK_POWER_RATIO


## Crossbow: Yay ile aynı okları (arrow_projectile.tscn) kullanır ama tamamen
## ayrı bir silah - bkz. Crossbow+ Tamam/crossbow özellikleri.txt.
##   hasar: tier başına +16, %100 saldırı gücü (oran tier'e göre değişmez -
##   weapon_crossbow.tscn'de card_damage_bonus_ratio = 1.0 sabit).
##   Crossbow'a özgü ekstra kritik şansı/hasarı: her RAW tier +%4 kritik şansı
##   (weapon_crit_chance_bonus), dönüm noktalarında (3/5/7/10) KÜMÜLATİF +%10
##   ekstra kritik hasar (weapon_crit_damage_bonus) - ikisi de weapon.gd'nin
##   set_crit_chance_bonus/set_crit_damage_bonus setter'larına eklenen genel
##   "silaha özel ek bonus" katmanı. Bu iki alan sadece SAKLANMAKLA kalmaz,
##   oyuncunun güncel kart bonuslarıyla (crit_chance_bonus/crit_damage_bonus)
##   birlikte setter'lar TEKRAR çağrılarak hemen uygulanır - yoksa ilk satın
##   almada (bkz. buy_weapon_copy: _apply_weapon_bonuses_to ÖNCE, tier apply
##   SONRA çağrılıyor) crossbow'un tier bonusu bir sonraki kart alınana kadar
##   yansımazdı.
func _apply_crossbow_tier(w, level: int) -> void:
	var tier: float = _tier_from_level10(level)
	var dmg_bonus: float = (tier - 1.0) * 16.0
	if w.has_method("set_shop_damage_bonus"):
		w.set_shop_damage_bonus(dmg_bonus)
	w.weapon_crit_chance_bonus = tier * 0.04
	var milestone_crit_damage_bonus: float = 0.0
	if level >= 20:
		milestone_crit_damage_bonus = 0.40
	elif level >= 14:
		milestone_crit_damage_bonus = 0.30
	elif level >= 10:
		milestone_crit_damage_bonus = 0.20
	elif level >= 6:
		milestone_crit_damage_bonus = 0.10
	w.weapon_crit_damage_bonus = milestone_crit_damage_bonus
	if w.has_method("set_crit_chance_bonus"):
		w.set_crit_chance_bonus(crit_chance_bonus)
	if w.has_method("set_crit_damage_bonus"):
		w.set_crit_damage_bonus(crit_damage_bonus)
	if w.has_method("set_weapon_tier"):
		w.set_weapon_tier(_visual_tier_from_level(level))


## Boomerang: fırlatılınca throw_distance kadar gidip oyuncuya geri döner,
## dönene kadar tekrar atılamaz (bkz. weapon.gd single_active_projectile,
## boomerang_projectile.gd) - bkz. Boomerang+ tamam/boomerangın özellikleri.txt.
##   hasar: tier başına +16, %90 saldırı gücü (oran tier'e göre değişmez -
##   weapon_boomerang.tscn'de card_damage_bonus_ratio = 0.9 sabit).
##   dönüm noktaları (3/5/7/10): KÜMÜLATİF +%10 "daha hızlı fırlatılır ve daha
##   hızlı geri döner" - projectile_speed_mult üzerinden doğrudan merminin
##   speed'ini çarpar (fire_rate'i etkilemez).
func _apply_boomerang_tier(w, level: int) -> void:
	var tier: float = _tier_from_level10(level)
	var dmg_bonus: float = (tier - 1.0) * 16.0
	if w.has_method("set_shop_damage_bonus"):
		w.set_shop_damage_bonus(dmg_bonus)
	var milestone_speed_bonus: float = 0.0
	if level >= 20:
		milestone_speed_bonus = 0.40
	elif level >= 14:
		milestone_speed_bonus = 0.30
	elif level >= 10:
		milestone_speed_bonus = 0.20
	elif level >= 6:
		milestone_speed_bonus = 0.10
	w.projectile_speed_mult = 1.0 + milestone_speed_bonus
	if w.has_method("set_weapon_tier"):
		w.set_weapon_tier(_visual_tier_from_level(level))


## Buz Asası: her isabette boss olmayan hedefi 3 saniyeliğine dondurur.
## Hedefleme, donmamış düşmanları önceliklendirir; hepsi donmuşsa en yakın
## hedefe dönerek saldırmayı sürdürür (bkz. weapon.gd).
func _apply_buz_asasi_tier(w, level: int) -> void:
	var tier: float = _tier_from_level10(level)
	var dmg_bonus: float = (tier - 1.0) * 12.0
	if w.has_method("set_shop_damage_bonus"):
		w.set_shop_damage_bonus(dmg_bonus)
	var fr_reduction: float = (tier - 1.0) * 0.06
	var fr_mult: float = max(0.15, 1.0 - fr_reduction)
	if w.has_method("set_shop_fire_rate_mult"):
		w.set_shop_fire_rate_mult(fr_mult)
	w.chill_stacks_per_hit = 1
	if w.has_method("set_weapon_tier"):
		w.set_weapon_tier(_visual_tier_from_level(level))


## Fişek: hasarı FLAT (Tabanca/Hançer gibi "tier başına" hiç büyümüyor, bkz.
## Fişek özellikleri.txt "saldırı gücü oranı tier başına artmaz" VE ayrıca
## hiç "tier başına X hasar" cümlesi de yok) - tüm güç dönüm noktalarındaki
## KÜMÜLATİF +%15 patlama genişliği bonusundan gelir (splash_radius_mult).
func _apply_fisek_tier(w, level: int) -> void:
	var milestone_bonus: float = 0.0
	if level >= 20:
		milestone_bonus = 0.60
	elif level >= 14:
		milestone_bonus = 0.45
	elif level >= 10:
		milestone_bonus = 0.30
	elif level >= 6:
		milestone_bonus = 0.15
	w.splash_radius_mult = 1.0 + milestone_bonus
	if w.has_method("set_weapon_tier"):
		w.set_weapon_tier(_visual_tier_from_level(level))


## Pençe: kısa menzilli, alan hasarsız (aslında hafif AOE var, bkz.
## _configure_pence_melee) yakın dövüş - SADECE bu silahın kendi hasarından
## can çalar (bkz. weapon.gd lifesteal_percent/_apply_weapon_lifesteal,
## Pençeler Özellikleri.txt).
##   hasar: tier başına +20, %100 saldırı gücü (oran tier'e göre değişmez -
##   weapon_pence.tscn'de card_damage_bonus_ratio = 1.0 sabit).
##   can çalma: taban %0.3, dönüm noktalarında (3/5/7/10) KÜMÜLATİF +%0.2.
func _apply_pence_tier(w, level: int) -> void:
	var tier: float = _tier_from_level10(level)
	var dmg_bonus: float = (tier - 1.0) * 20.0
	if w.has_method("set_shop_damage_bonus"):
		w.set_shop_damage_bonus(dmg_bonus)
	var milestone_lifesteal_bonus: float = 0.0
	if level >= 20:
		milestone_lifesteal_bonus = 0.008
	elif level >= 14:
		milestone_lifesteal_bonus = 0.006
	elif level >= 10:
		milestone_lifesteal_bonus = 0.004
	elif level >= 6:
		milestone_lifesteal_bonus = 0.002
	w.lifesteal_percent = 0.003 + milestone_lifesteal_bonus
	if w.has_method("set_weapon_tier"):
		w.set_weapon_tier(_visual_tier_from_level(level))


## Topuz: kalkan delme YÜZDESİ (dönüm noktaları) kazanır - bkz. weapon.gd
## weapon_shield_pen_bonus, topuzun özellikleri.txt.
##   hasar: tier başına +20, %105 saldırı gücü (oran tier'e göre değişmez -
##   weapon_topuz.tscn'de card_damage_bonus_ratio = 1.05 sabit).
##   kalkan delme: dönüm noktalarında (3/5/7/10) KÜMÜLATİF +%10 yüzdesel.
## DÜZELTME (kullanıcı isteği: "zırh kaldırıldı, yerini kalkan delme
## alacak") - eskiden AYRICA tier başına (RAW) +2 DÜZ zırh delme de
## kazanıyordu (weapon_armor_pen_flat_bonus); düz zırh azaltma kavramının
## kalkan tarafında (yüzdesel emilim) doğrudan bir karşılığı olmadığı için
## bu düz bonus kaldırıldı, sadece yüzdesel (aşağıdaki milestone_bonus)
## kaldı - Topuz'un delme gücü artık SADECE dönüm noktalarında artıyor.
func _apply_topuz_tier(w, level: int) -> void:
	var tier: float = _tier_from_level10(level)
	var dmg_bonus: float = (tier - 1.0) * 20.0
	if w.has_method("set_shop_damage_bonus"):
		w.set_shop_damage_bonus(dmg_bonus)
	var milestone_bonus: float = 0.0
	if level >= 20:
		milestone_bonus = 0.40
	elif level >= 14:
		milestone_bonus = 0.30
	elif level >= 10:
		milestone_bonus = 0.20
	elif level >= 6:
		milestone_bonus = 0.10
	w.weapon_shield_pen_bonus = milestone_bonus
	if w.has_method("set_weapon_tier"):
		w.set_weapon_tier(_visual_tier_from_level(level))


## Uzunkılıç: hasarı FLAT (Hançer/Tabanca gibi "tier başına" hiç büyümüyor,
## bkz. Kılıç özellikleri.txt "saldırı gücü oranı tiera göre artmaz" VE hiç
## "tier başına X hasar" cümlesi de yok) - kalkan delme tier başına (RAW)
## büyür (weapon_shield_pen_bonus), dönüm noktalarındaki (3/5/7/10) KÜMÜLATİF
## +%10 "ekstra silah hasarı" ÇARPIMSAL bir katman (set_tier_damage_mult,
## Arcane'in dönüm noktası hasar çarpanıyla birebir aynı mekanik).
func _apply_uzunkilic_tier(w, level: int) -> void:
	var tier: float = _tier_from_level10(level)
	w.weapon_shield_pen_bonus = (tier - 1.0) * 0.05
	var milestone_mult: float = 1.0
	if level >= 20:
		milestone_mult = 1.40
	elif level >= 14:
		milestone_mult = 1.30
	elif level >= 10:
		milestone_mult = 1.20
	elif level >= 6:
		milestone_mult = 1.10
	if w.has_method("set_tier_damage_mult"):
		w.set_tier_damage_mult(milestone_mult)
	if w.has_method("set_weapon_tier"):
		w.set_weapon_tier(_visual_tier_from_level(level))


## Şimşek Asası (2026 güncellemesi): kesintisiz ışın - bkz. weapon.gd
## continuous_beam/_process_continuous_beam, Şimşek asası özellikleri.txt.
##   hasar: HER SANİYE tier başına +12, %65 saldırı gücü (oran tier'e göre
##   değişmez - weapon_lightning.tscn'de card_damage_bonus_ratio = 0.65 sabit).
##   Bu toplam saniyelik hasar artık TEK bir tik yerine saniyede 3 küçük tike
##   bölünerek geliyor (her tik tam hasarın %33'ü, bkz. weapon.gd
##   BEAM_TICK_DAMAGE_RATIO/beam_tick_interval) - toplamı DEĞİŞMEZ, sadece
##   dağılımı daha sık/yumuşak.
##   dönüm noktaları (3/5/7/10): KÜMÜLATİF fazladan +1 sıçrama - taban 1
##   sıçrama ile birlikte tier 10'da toplam 5 sıçrama hedefine kadar çıkar.
func _apply_lightning_tier(w, level: int) -> void:
	## DÜZELTME (100-level rebalance sırasında bulunan eski bug): bu fonksiyon
	## eskiden "tier = clamp(level, 1, 10)" kullanıyordu ama shop_panel.gd'deki
	## eski cap 30'du - yani seviye 11-30 arası HİÇBİR ek güç vermiyordu
	## (tier hep 10'da kilitli kalıyordu). Artık _tier_from_level10 eski
	## "etkin" 1..10 aralığını (eski gerçek max güç = eski level 10) level
	## 1..100'e düzgün yayıyor, bu eksik büyüme de kendiliğinden düzeliyor.
	var tier: float = _tier_from_level10(level)
	var dmg_bonus: float = (tier - 1.0) * 12.0
	if w.has_method("set_shop_damage_bonus"):
		w.set_shop_damage_bonus(dmg_bonus)
	var milestone_bonus: int = 0
	if level >= 20:
		milestone_bonus = 4
	elif level >= 14:
		milestone_bonus = 3
	elif level >= 10:
		milestone_bonus = 2
	elif level >= 6:
		milestone_bonus = 1
	w.chain_jump_count = 1 + milestone_bonus
	if w.has_method("set_weapon_tier"):
		w.set_weapon_tier(_visual_tier_from_level(level))


## Yay (Bow): diğer 10 tier'lik ekstra silahlar gibi - bkz. Yayın özellikleri.txt.
##   hasar: tier başına +10, %90 saldırı gücü (card_damage_bonus_ratio,
##   weapon_yay.tscn'de 0.9 olarak sabit - "oranı tier başına artmaz" demek bu,
##   burada SADECE tier'e bağlı düz kısım ekleniyor, tıpkı Arcane'in düz tier
##   bonusu gibi).
##   ateş hızı: tier başına %10 daha hızlı, AYRICA 3/5/7/10. seviyelerde
##   KÜMÜLATİF +%15 ek (dönüm noktası) - Tabanca'daki "üst üste binen dönüm
##   noktası" şablonuyla birebir aynı: taban + milestone tek bir fr_mult'ta
##   toplanıp set_shop_fire_rate_mult'a verilir (ayrı bir weapon.gd alanına
##   gerek yok, Arcane'in çarpımsal hasar katmanının aksine bu tamamen
##   toplamsal bir azalma). 0.15 taban çarpanı altına inmez (aşırı hızlı ateş
##   aralığını önler).
func _apply_yay_tier(w, level: int) -> void:
	var tier: float = _tier_from_level10(level)
	var dmg_bonus: float = (tier - 1.0) * 10.0
	if w.has_method("set_shop_damage_bonus"):
		w.set_shop_damage_bonus(dmg_bonus)
	# Level başına artan saldırı hızı oranı ve milestone bonusları %15 azaltıldı (0.85 ile çarpıldı)
	var milestone_fr_bonus: float = 0.0
	if level >= 20:
		milestone_fr_bonus = 0.51
	elif level >= 14:
		milestone_fr_bonus = 0.3825
	elif level >= 10:
		milestone_fr_bonus = 0.255
	elif level >= 6:
		milestone_fr_bonus = 0.1275
	var fr_reduction: float = (tier - 1.0) * 0.085 + milestone_fr_bonus
	var fr_mult: float = max(0.15, 1.0 - fr_reduction)
	if w.has_method("set_shop_fire_rate_mult"):
		w.set_shop_fire_rate_mult(fr_mult)
	if w.has_method("set_weapon_tier"):
		w.set_weapon_tier(_visual_tier_from_level(level))
	## Yay pasifi (kullanıcı isteği): her 3. saldırıdan sonra fazladan 1 ok
	## atar - dönüm noktası (artık 30/50/70/100 level) başına bu fazladan ok
	## sayısı +1 artar. tier1-2: +1, tier3-4: +2, tier5-6: +3, tier7-9: +4,
	## tier10: +5.
	var yay_multishot_bonus: int = 1
	if level >= 20:
		yay_multishot_bonus = 5
	elif level >= 14:
		yay_multishot_bonus = 4
	elif level >= 10:
		yay_multishot_bonus = 3
	elif level >= 6:
		yay_multishot_bonus = 2
	if w.has_method("set_yay_multishot_bonus"):
		w.set_yay_multishot_bonus(yay_multishot_bonus)


## Ateş Asası (fire_staff): DÜZELTME (100-level rebalance sırasında bulunan
## tutarsızlık) - eskiden bu silahın HİÇ kademe/dönüm noktası bonusu yoktu
## (apply_owned_weapon_tier'ın generic "else" dalına düşüyordu, diğer 14
## silahın hepsinde bir tane vardı). Diğerleriyle tutarlı olsun diye artık
## Arcane/Uzunkılıç'ın kullandığı AYNI çarpımsal set_tier_damage_mult()
## katmanıyla 30/50/70/100 dönüm noktalarında bir bonus alıyor (patlayıcı
## mermisine "explosion_radius" gibi ayrı bir alan olmadığı için düz hasar
## çarpanı seçildi - bu kullanıcının literal isteğinin ÖTESİNDE bir ek).
## Eski cap 30 idi (10 değil) ve raw `level` (clamp yok) kullanıyordu - bu
## yüzden temel büyüme _tier_from_level10 (eski 1..10 aralığı) DEĞİL, eski
## 1..30 aralığını 1..100'e yayan kendi oranıyla (29/99) ölçekleniyor.
## Ateş Asası pasifi (kullanıcı isteği: "ateş asasına yeni pasif ekliyoruz,
## isabet ettiğinde düşmanları 3 saniye boyunca yakarak her saniye saldırı
## gücünün %10'u kadar hasar versin") - Hançer'in bleed_tick_damage_per_
## stack'i / Tüftüf'ün zehir ramp'iyle AYNI desen: saldırı gücünden
## (damage_bonus) pay alan bir tik hasarı, tier değişince VE her Hasar
## kartında (bkz. _apply_weapon_bonuses_to) yeniden hesaplanır. Süre sabit
## 3sn (tier'e göre büyümez, bkz. weapon.gd/projectile.gd BURN_ON_HIT_
## DURATION).
const FIRE_STAFF_BURN_ATTACK_POWER_RATIO := 0.10

func _refresh_fire_staff_burn(w) -> void:
	if not is_instance_valid(w):
		return
	if "burn_on_hit_tick_damage" in w:
		w.burn_on_hit_tick_damage = damage_bonus * FIRE_STAFF_BURN_ATTACK_POWER_RATIO


func _apply_fire_staff_tier(w, level: int) -> void:
	## DÜZELTME (100->20 level rebalance): uç noktalar (level 1 ve level 20)
	## AYNI kalsın diye clamp/payda 99'dan 19'a çekildi - bkz.
	## _tier_from_level10 üstündeki AYNI düzeltme notu.
	var lvl: int = clampi(level, 1, 20)
	var dmg_bonus: float = (float(lvl) - 1.0) * 3.0 * 29.0 / 19.0
	if w.has_method("set_shop_damage_bonus"):
		w.set_shop_damage_bonus(dmg_bonus)
	var fr_reduction: float = (float(lvl) - 1.0) * 0.015 * 29.0 / 19.0
	var fr_mult: float = max(0.5, 1.0 - fr_reduction)
	if w.has_method("set_shop_fire_rate_mult"):
		w.set_shop_fire_rate_mult(fr_mult)
	var milestone_mult: float = 1.0
	if lvl >= 20:
		milestone_mult = 1.32
	elif lvl >= 14:
		milestone_mult = 1.24
	elif lvl >= 10:
		milestone_mult = 1.16
	elif lvl >= 6:
		milestone_mult = 1.08
	if w.has_method("set_tier_damage_mult"):
		w.set_tier_damage_mult(milestone_mult)
	if w.has_method("set_weapon_tier"):
		w.set_weapon_tier(_visual_tier_from_level(lvl))
	_refresh_fire_staff_burn(w)


## All weapons currently equipped (başlangıç silahı DAHİL, hepsi
## owned_weapon_nodes'ta - ayrı bir "ana silah" yok), used so a single
## upgrade (e.g. "menzil") can apply to everything the player owns.
func _all_weapons() -> Array:
	return owned_weapon_nodes


## Kafanın üstünde silah ikonlarının duracağı sabit noktalar - kullanıcının
## çizdiği yıldız diyagramına göre birebir 5 nokta: owned_weapon_nodes[0]
## (başlangıç silahı) tam üstte en yüksekte, sonraki ikonlar sırayla sağ
## üst / sol üst / sağ / sol konumlara yerleşiyor. Toplam her zaman en fazla
## 5 = bu dizinin boyutu = get_max_owned_weapons() - taşma olmaz. Her kopya
## HER ZAMAN kendi ayrı ikonunda durur - grup/rozet/gizleme YOK, hepsi aynı
## muameleyi görür (hiçbiri "özel/ana" değil).
const WEAPON_ICON_SLOTS: Array[Vector2] = [
	Vector2(0, -125),   ## başlangıç silahı - tam üstte (can/kalkan barının biraz üzerinde dursun diye -95'ten -125'e çekildi)
	Vector2(62, -70),   ## sağ üst
	Vector2(-62, -70),  ## sol üst
	Vector2(92, -28),   ## sağ
	Vector2(-92, -28),  ## sol
]


## owned_weapon_nodes'taki HER kopya (sıra/index'e göre) kendi ayrı ikon
## slotunu alır (en fazla WEAPON_ICON_SLOTS.size() kadar, bire bir eşleşir -
## taşma olmaz, bkz. get_max_owned_weapons).
## Helper: find the index of a weapon in owned_weapon_nodes.
func _get_weapon_index(weapon: Node) -> int:
	return owned_weapon_nodes.find(weapon)


func _reposition_weapon_icons() -> void:
	var iconed: Array = []
	for w in owned_weapon_nodes:
		if not is_instance_valid(w):
			continue
		if w.has_method("set_icon_offset") and "icon_sprite" in w and w.icon_sprite != null:
			iconed.append(w)
	for i in range(iconed.size()):
		var slot: Vector2 = WEAPON_ICON_SLOTS[min(i, WEAPON_ICON_SLOTS.size() - 1)]
		var w = iconed[i]
		w.set_icon_offset(slot)
		if w.icon_sprite and not w.is_reloading:
			w.icon_sprite.visible = true


## Pushes every accumulated level-up bonus onto one weapon. Called for every
## weapon whenever a relevant card is picked, and once for a newly bought
## staff so it starts with whatever the player has already picked up.
func _apply_weapon_bonuses_to(w) -> void:
	if not is_instance_valid(w):
		return
	if w.has_method("set_range_bonus"):
		w.set_range_bonus(weapon_range_bonus)
	if w.has_method("set_damage_bonus"):
		w.set_damage_bonus(damage_bonus)
	if w.has_method("set_fire_rate_mult"):
		## Eldiven/Kaos Kitabı: item_fire_rate_percent (additive %saldırı hızı
		## havuzu) - Elara pasifi gibi mult'u düşürerek uygulanıyor (düşük
		## mult = daha hızlı saldırı).
		## item_fire_rate_percent üst sınırı %90 - aşırı yığılma negatif çarpana yol açmasın.
		var safe_item_mult: float = max(0.1, 1.0 - item_fire_rate_percent)
		## Talon'un eski "canı azalınca saldırı hızı artışı" pasifi (bkz.
		## _talon_passive_fire_rate_mult, artık silindi) burada çarpılıyordu -
		## yeni pasif (bkz. _passive_talon) saldırı hızını DEĞİL, saldırı
		## gücünü/hasar azaltmayı etkiliyor, bu yüzden bu formülden çıkarıldı.
		w.set_fire_rate_mult(fire_rate_mult * _elara_passive_fire_rate_mult() * _kurtadam_berserk_fire_rate_mult() * safe_item_mult)
	if w.has_method("set_crit_chance_bonus"):
		w.set_crit_chance_bonus(crit_chance_bonus)
	if w.has_method("set_crit_damage_bonus"):
		w.set_crit_damage_bonus(crit_damage_bonus)
	## Tüftüf'ün zehir ramp'i de saldırı gücünden (damage_bonus) pay alıyor -
	## sadece tier değiştiğinde değil, HER kart alındığında (bu fonksiyon her
	## silah için burada zaten çağrılıyor) da tazelenmeli (bkz.
	## _refresh_tuftuf_poison).
	if w.get_meta("shop_key", "") == "tuftuf":
		_refresh_tuftuf_poison(w)
	elif w.get_meta("shop_key", "") == "dagger":
		_refresh_hancer_bleed(w)
	elif w.get_meta("shop_key", "") == "fire_staff":
		_refresh_fire_staff_burn(w)


func _apply_weapon_bonuses() -> void:
	for w in _all_weapons():
		_apply_weapon_bonuses_to(w)


## Karakterler LPC generator'da tasarlanıp Characters.DEFS'e kaydediliyor
## (bkz. scripts/characters.gd). Kareler 64x64; standart boy iki kez %10
## küçültüldü (2.1 → 1.89 → 1.701) - DEFS'te ayrıca "scale" verilmeyen her
## karakter otomatik bu standartta yüklenir.
const DEFAULT_ANIM_SCALE := Vector2(1.27575, 1.27575)
const DEFAULT_ANIM_OFFSET := Vector2(0, -5)


## Artık herkes ortak "ana silah"la (bkz. Characters.MAIN_WEAPON) başlıyor -
## karakterin kendi eski oto-saldırısı (mermi/pençe/vs.) tamamen kapatıldı,
## sadece bu tek yakın dövüş silahı kullanılıyor. R tuşuyla çalışan karakter
## yeteneği (skill/ulti) bundan ayrı, hiç değişmedi. CombatTuning artık karaktere
## göre değil, bu tek paylaşılan silaha göre sabit bir id ile anahtarlanıyor.
const MAIN_WEAPON_TUNING_ID := 0


## Kullanıcı isteği (bkz. EntityScale): oynanabilir karakterin GÖVDE çemberini
## ve kalkan baloncuğunu %5 küçültür.
## Görselin (anim) ölçeği BURADA değil _load_character_frames()'te
## küçültülüyor, çünkü oradaki char_base_anim_scale "gerçek taban" olarak her
## yerde kullanılıyor (ateş sarsıntısı sonrası geri dönüş, canlanma, Talon'un
## Devleşme ultisi) - tabanı orada ölçeklemek hepsini tutarlı tutar.
func _apply_entity_size_scale() -> void:
	EntityScale.shrink_collision(get_node_or_null("CollisionShape2D"))
	## Kalkan baloncuğu karakterin etrafını saran bir görsel - karakter %5
	## küçülünce baloncuk da küçülmezse orantısız geniş kalırdı.
	var bubble: Node2D = get_node_or_null("ShieldVisual/BubbleSprite")
	if bubble:
		bubble.scale *= EntityScale.SIZE


func _load_character_frames() -> void:
	var def: Dictionary = Characters.get_def(GameManager.selected_char_id)
	var path: String = def["frames"]
	if ResourceLoader.exists(path):
		var loaded_frames = load(path)
		if loaded_frames and anim:
			anim.sprite_frames = loaded_frames
	if anim:
		anim.modulate = Color(1, 1, 1, 1)
		base_modulate = anim.modulate
		## Kullanıcı isteği ("tüm oynanabilir karakterleri %5 küçült"): global
		## küçültme çarpanı anim.scale'e değil TABANA uygulanıyor - aşağıdaki
		## karakter tanımı ölçeği (Characters.DEFS "scale") her yerde bu
		## değişken üzerinden kullanılıyor.
		char_base_anim_scale = def.get("scale", DEFAULT_ANIM_SCALE) * EntityScale.SIZE
		anim.scale = char_base_anim_scale
		anim.offset = def.get("offset", DEFAULT_ANIM_OFFSET)
	else:
		base_modulate = Color(1, 1, 1, 1)
		char_base_anim_scale = DEFAULT_ANIM_SCALE * EntityScale.SIZE
	_always_walk = def.get("always_walk", false)
	## Silah kurulumu artık burada YOK - hiçbir karakterin ayrı bir "ana
	## silahı" olmadığı için herkesin başlangıç silahı (bkz.
	## STARTING_WEAPON_BY_CHAR) tamamen standart yoldan, _ready()'deki
	## _grant_starting_weapon()/buy_weapon_copy() akışıyla kurulur - burada
	## karaktere özel hiçbir dallanma gerekmez. _melee her zaman true (bkz.
	## _on_weapon_fired - şu anki tüm karakterler için zaten hep öyleydi).
	_melee = true
	lifesteal_percent = def.get("lifesteal", 0.0)
	thorns_reflect_percent = def.get("thorns_reflect_percent", 0.0)
	## Generator'dan çıkan karakterlerin gölgesi karelerin içinde gömülü
	## geldiği için ayrı gölge blob'u kullanılmıyor.
	if shadow:
		shadow.visible = false


## Matthew artık kendi ana silahını elle kurmuyor - herkes gibi
## weapon_tuftuf.tscn'i STARTING_WEAPON_BY_CHAR üzerinden normal bir
## owned_weapons kopyası olarak alıyor (bkz. _ready()/_grant_starting_
## weapon/buy_weapon_copy), o sahnenin içindeki her şey (ikon/dart tier
## dizileri, zehir statları, ateş sesi) zaten hazır - elle kopyalamaya
## gerek yok.

## "dagger" (ortak bıçak): tek bir generic weapon.gd sahnesi
## (weapon_dagger.tscn) tüm karakterler için aynı, sadece Characters.
## MAIN_WEAPON konfigürasyonu runtime'da configure_melee() ile üstüne
## uygulanıyor - eskiden bu, sabit "$Weapon" node'unun karakter yüklenirken
## bir kere yapılandırılmasıydı, şimdi her "dagger" kopyası
## instantiate edildiğinde (buy_weapon_copy) aynı şekilde çalışıyor.
func _configure_dagger_melee(w) -> void:
	if not w.has_method("configure_melee"):
		return
	var mw: Dictionary = Characters.MAIN_WEAPON
	## CombatTuning (F9 debug paneli): kaydedilmiş ince ayarlar varsa
	## bıçağın varsayılanlarının üzerine geçer - karaktere göre değil, tek
	## paylaşılan silaha göre (MAIN_WEAPON_TUNING_ID) tutuluyor.
	var rot_deg: float = rad_to_deg(mw.get("slash_fx_rotation_offset", 0.0))
	rot_deg = CombatTuning.get_value(MAIN_WEAPON_TUNING_ID, "rotation_offset_deg", rot_deg)
	var scale_mult: float = CombatTuning.get_value(MAIN_WEAPON_TUNING_ID, "scale_mult", 1.0)
	w.configure_melee(
		mw.get("melee_range", 110.0),
		mw.get("melee_aoe_radius", 60.0),
		mw.get("melee_aoe_damage", 0.5),
		mw.get("attack_sounds", []),
		mw.get("slash_fx", ""),
		mw.get("slash_fx_offset", 95.0),
		deg_to_rad(rot_deg),
		mw.get("melee_hit_segments", 1),
		scale_mult,
		mw.get("attack_sound_volume_db", -12.0),
		mw.get("slash_fx_fixed_rotation", false),
		mw.get("slash_fx_mirror", false))
	## Bıçak edinilir edinilmez tier 1 kanama mekanizmasını başlat.
	## _apply_hancer_tier yalnızca tier yükseltildiğinde çağrıldığı için
	## başlangıçta bleed_max_stacks = 0 kalıyor ve kanama hiç uygulanmıyordu.
	_apply_hancer_tier(w, 1)


## Pençe: dagger'ın aksine karakter tanımına (Characters.MAIN_WEAPON) değil,
## sabit kendi değerlerine göre yakın dövüşe alınır - kısa menzil, hafif alan
## hasarı ve kendi savuruş efekti (bkz. Pençeler Özellikleri.txt, fx_pence_slash.tscn).
## Ses efekti sağlanmadığı için attack_sounds boş bırakıldı (sessiz savuruş).
func _configure_pence_melee(w) -> void:
	if not w.has_method("configure_melee"):
		return
	## slash_fx_offset = 18.0 (Dagger/MAIN_WEAPON ile birebir aynı, bkz.
	## Characters.MAIN_WEAPON yorumu). lunge_range_ratio ARTIK VERİLMİYOR
	## (varsayılan 0.0'a düştü, bkz. weapon.gd melee_lunge_range_ratio) -
	## eskiden 0.85 idi (attack_range'in sabit bir oranı kadar, hedefin gerçek
	## mesafesinden BAĞIMSIZ bir noktaya giderdi). Kullanıcı bunun net şekilde
	## YANLIŞ olduğunu bildirdi: "yaratıkların üstüne saldırmıyor... hedefin
	## üzerine gidip vurması gerekiyor" - yani ikon artık HER ZAMAN hedefin O
	## ANKİ gerçek konumuna gidiyor (Dagger'ın hep yaptığı gibi), sabit bir
	## atılım mesafesine değil.
	## hit_segments = 2 (eskiden 1) - Dagger'ın 3 parçalı savuruşuna benzer,
	## tek bir donuk lunge yerine iki hızlı pençe darbesi ("yeterli
	## animasyona/savurma hareketine sahip değil" şikayeti - bkz. Dagger'ın
	## Characters.MAIN_WEAPON'daki melee_hit_segments=3 referansı).
	w.configure_melee(110.0, 60.0, 0.5, ["res://assets/audio/claw_slash.mp3"], "res://scenes/fx_pence_slash.tscn", 8.0, 0.0, 2, 1.0, -12.0, false, false)


## Topuz: "yere daire şeklinde alan hasarı" (bkz. topuzun özellikleri.txt) -
## Şovalye Adam'ın gürz darbesiyle AYNI görsel yaklaşım: efekt saldırı yönüne
## göre DÖNMEZ (slash_fx_fixed_rotation=true), sadece hangi tarafta belireceği
## yöne göre aynalanır (slash_fx_mirror=true) - "yere çakılmış" gibi hep aynı
## açıda durur. Dagger'a göre daha geniş bir alan hasarı yarıçapı (95 vs 60)
## ile "daire şeklinde" vurgusu karşılanıyor. Savuruş sesi AttackSound'dan
## (weapon_topuz.tscn), darbe sesi fx_topuz_slash.tscn'in kendi "Sound"
## node'undan (fx_animation.gd otomatik çalar) geliyor - iki ayrı ses.
## slash_fx_offset = 18.0 (Dagger/MAIN_WEAPON ile aynı, bkz. _configure_pence_melee
## yorumu). lunge_range_ratio ARTIK VERİLMİYOR (bkz. aynı yorumdaki geri
## alma gerekçesi - sabit değil, hep gerçek hedefe gider). hit_segments YİNE
## 1 kalıyor (Pençe/Uzunkılıç'ın aksine) çünkü Topuz tek, ağır bir gürz
## darbesi - flurry değil, tek bir vuruş.
func _configure_topuz_melee(w) -> void:
	if not w.has_method("configure_melee"):
		return
	w.configure_melee(120.0, 95.0, 0.5, [], "res://scenes/fx_topuz_slash.tscn", 8.0, 0.0, 1, 1.0, -12.0, true, true)


## Uzunkılıç: normal yönlü bir savuruş hilali (Topuz'un aksine sabit rotasyon
## DEĞİL - saldırı yönüne göre döner, dagger/pence ile aynı mod). Ses
## efektleri configure_melee'ye verilmiyor (sound_paths=[]) çünkü
## weapon_uzunkilic.tscn zaten kendi random_sfx_player.gd tabanlı AttackSound'unu
## taşıyor (3 farklı kılıç sesi arasından rastgele).
## slash_fx_offset = 18.0 (Dagger/MAIN_WEAPON ile aynı, bkz. _configure_pence_melee
## yorumu). lunge_range_ratio ARTIK VERİLMİYOR + hit_segments = 2 (aynı
## yorumdaki gerekçe - Pençe ile birebir aynı, tek fark savuruş efekti/sesleri).
func _configure_uzunkilic_melee(w) -> void:
	if not w.has_method("configure_melee"):
		return
	w.configure_melee(115.0, 60.0, 0.5, [], "res://scenes/fx_uzunkilic_slash.tscn", 8.0, 0.0, 2, 1.0, -12.0, false, false)


func _physics_process(delta: float) -> void:
	## "efekt sistemi" (ölüm.png/diriltme.png/kalp.png): durum ne olursa
	## olsun HER karede reaktif olarak güncelleniyor - bkz. fonksiyonların
	## kendi üstündeki DÜZELTME notları.
	_update_death_status_fx()
	_update_revive_rewind_fx()
	## Adım sesleri burada da güncelleniyor: aşağıdaki erken dönüşler
	## _update_walk_sound'a hiç ulaşmadığı için, yürürken ölürsen/düşersen
	## adım planlaması durdurulmazdı (bkz. fonksiyonun "is_moving=false" dalı).
	if is_downed:
		_update_walk_sound(false, delta)
		_process_downed(delta)
		return
	if is_dead:
		_update_walk_sound(false, delta)
		return

	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	## Şovalye'nin Koruma Baloncuğu ultisi aktifken tamamen hareketsiz kalır
	## (bkz. _skill_paladin_ulti) - input okunmaya devam eder ki animasyon/
	## yön sistemi bozulmasın, sadece gerçek hareket engellenir.
	## Kurt Adam'ın Kudurmuş Saldırı ultisi aktifken de hareket kontrolü
	## oyuncudan alınır - input yerine _kurtadam_berserk_direction()
	## (en kısa menzilli silahına göre en yakın yaratığa otomatik yürüme)
	## kullanılır (bkz. kullanıcı isteği: "hareketlerini oyuncu kontrol
	## edemez ancak yetenek ve kalkan modu kullanabilir").
	var effective_direction: Vector2 = input_direction
	## DÜZELTME (Assasin Çocuk'un Gölge Hücumu ultisi - bkz. _skill_assasin_
	## dash): dash sırasında global_position her 0.07sn'de bir doğrudan
	## hedef yaratığa ışınlanıyor - hareket girdisi/move_and_slide() bunu
	## engellemesin/üstüne binmesin diye Şovalye'nin Koruma Baloncuğu ve Kurt
	## Adam'ın Kudurmuş Saldırı'sıyla AYNI desende oyuncudan hareket kontrolü
	## alınıyor (input yine okunuyor ki yön/animasyon bozulmasın, sadece
	## gerçek hareket engelleniyor).
	## Büyücü Kız'ın "Meteor Patlaması" varyasyonu (bkz. _skill_buyucu_meteor):
	## 5sn boyunca yerinde kalıp odaklanması gerekiyor - Assasin Çocuk'un
	## dash'iyle AYNI desende hareket kontrolü alınıyor.
	if _paladin_movement_locked or _menu_input_locked or is_assasin_dashing or is_buyucu_channeling or is_chat_typing:
		velocity = Vector2.ZERO
		effective_direction = Vector2.ZERO
	elif _kurtadam_berserk_active:
		effective_direction = _kurtadam_berserk_direction()
		velocity = effective_direction * speed * skill_speed_multiplier * skill2_speed_multiplier * shield_mode_speed_mult * (1.0 + item_speed_percent + speed_card_percent + _current_temp_speed_boost())
	else:
		## Deri Çizme/Kitelama Seti: item_speed_percent (additive %hareket
		## hızı havuzu). speed_card_percent: "Hız" level-up kartı, aynı
		## additive mantık. _current_temp_speed_boost(): Oakley'nin Çiçek
		## yeteneği alındığında verdiği azalarak kaybolan geçici hız bonusu.
		velocity = input_direction * speed * skill_speed_multiplier * skill2_speed_multiplier * shield_mode_speed_mult * (1.0 + item_speed_percent + speed_card_percent + _current_temp_speed_boost())
	
	velocity += _knockback_velocity
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	
	_block_movement_into_enemies()
	_block_movement_into_players()
	_block_movement_into_terrain()
	move_and_slide()

	## Adım sesleri: animasyonun kullandığı AYNI "hareket ediyor mu" ölçütü
	## (bkz. hemen alttaki _update_animation çağrısı) - yani adımlar tam olarak
	## yürüme animasyonu oynarken duyulur. Kilitli/dash/kanal/sohbet
	## durumlarında yukarıda effective_direction sıfırlandığı için yeni adım
	## planlanmaz.
	_update_walk_sound(effective_direction.length() > 0.1, delta)

	_update_facing(effective_direction)
	_update_animation(effective_direction.length() > 0.1 and not _paladin_movement_locked)
	_process_regen(delta)
	_process_skill(delta)
	_process_skill2(delta)
	_process_item_shield(delta)
	_process_item_passives(delta)
	_process_kalkan_yenileme(delta)
	_process_healer_heal_tick(delta)
	_process_temp_speed_boost(delta)
	_process_shield_regen_tick(delta)
	_process_paladin_ulti(delta)
	_process_elara_true_damage(delta)
	_update_shield_bubble(delta)
	_process_spray(delta)
	_process_xp_streak(delta)
	_process_character_passive(delta)
	_process_korsan_bombs(delta)
	_process_korsan_bombardment(delta)
	_process_talon_weapon_salvo(delta)
	_process_talon_mirror_form(delta)
	_process_assasin_dash2_charges(delta)
	_process_necro_skeleton_cooldown(delta)
	_process_necro_bats(delta)
	_process_matthew_speed_lines(delta)
	_process_buyucu(delta)
	_process_skill3(delta)
	_process_oakley_bond(delta)
	_process_damage_redirect_range_check(delta)
	_refresh_local_barrier_link_visual()
	_process_merchant_zone_state()

	## DÜZELTME (kullanıcı bildirimi: "kalkanın içindeyken yetenek de
	## kullanılamamalı") - seyyar satıcının güvenli bölgesi (bkz.
	## is_in_merchant_zone/GameManager.merchant_zone_*) hem yaratıkların hem
	## artık oyuncunun kendi saldırganlığının devre dışı kaldığı KARŞILIKLI
	## bir ateşkes bölgesi olmalı - üç yetenek girişi de (ve aşağıdaki tüm
	## bypass dalları: Oakley Çiçek, Korsan bomba, Assasin hamle, Büyücü
	## varyasyonları, Necro yarasa sürüsü DAHİL) bölgedeyken tamamen engellenir.
	if Input.is_action_just_pressed("skill") and not is_chat_typing and not is_in_merchant_zone:
		## DÜZELTME (kullanıcı isteği: "Oakleyin pasifi silinecek ve Q su
		## bundan sonra pasifi olacak") - Çiçek artık burada DEĞİL, tamamen
		## otomatik bir pasif (bkz. _process_oakley_passive). Oakley'nin Q'su
		## artık Arı Sürüsü (eskiden R) - standart skill_state makinesini
		## kullanır, burada özel bir bypass dalına ihtiyacı yok.
		## DÜZELTME (kullanıcı isteği: "Necromancer in Q skillini iskelet
		## çıkarma skilli ile değiştir") - İskelet Çağır (id 19) Korsan'ın
		## bomba şarjıyla AYNI desen, bekleme süresi YERİNE ruh + kendi 1sn'lik
		## iç bekleme sayacıyla çalışır (bkz. _skill_necro_summon_skeleton
		## üstündeki not) - eskiden E/skill2'deydi (bkz. aşağıdaki skill2
		## dalı), standart skill_state == "ready" makinesini BAŞTAN bypass
		## ediyor.
		if get_skill_character_id() == 19:
			_skill_necro_summon_skeleton()
		elif skill_state == "ready":
			_activate_skill()
		## DÜZELTME (kullanıcı isteği #42: "şovalyenin ve kurt adamın
		## kendilerini hareketsiz bırakan yetenekleri yeteneğe tekrar
		## tıklanarak iptal edilebilsin") - Şovalye'nin Koruma Baloncuğu
		## (id 11, tam hareketsiz kalır) ve Kurt Adam'ın Kudurmuş Saldırısı
		## (id 14, kontrolü kaybedip otomatik saldırır) süresi dolmadan
		## erken iptal edilebilir; diğer karakterlerin yeteneklerine
		## dokunulmuyor.
		elif skill_state == "active" and get_skill_character_id() in [11, 14]:
			_cancel_active_skill_early()
	if Input.is_action_just_pressed("skill2") and not is_chat_typing and not is_in_merchant_zone:
		var skill2_id_pressed: int = get_skill2_id()
		## Korsan (Saatli Bomba, id 17) bekleme süresi YERİNE şarj ile çalışır -
		## standart skill2_state == "ready" makinesini BAŞTAN devre dışı
		## bırakıp doğrudan kendi fonksiyonuna yönlendiriyoruz (bkz. o
		## fonksiyonun üstündeki yorum).
		if skill2_id_pressed == 17:
			_korsan_try_place_bomb()
		## DÜZELTME (kullanıcı isteği: "Necromancer in E sini yarasa sürüsü
		## çağırma ile değiştir") - Yarasa Sürüsü (id 35) "basılıp
		## kapatılabilir" bir TOGGLE - eskiden R/skill3'teydi (bkz. aşağıdaki
		## skill3 dalındaki taşınma notu), standart skill2_state == "ready"
		## bekleme makinesini BAŞTAN bypass ediyor, her basış açar/kapatır
		## (bkz. _necro_toggle_bats - artık skill3_state yerine skill2_state
		## kullanıyor).
		elif skill2_id_pressed == 35:
			_necro_toggle_bats()
		## Assasin Çocuk TEMEL (id 5, yeni 8 yönlü hamle) - Korsan'ın bomba
		## şarjıyla AYNI desen, standart bekleme makinesi yerine kendi
		## yük sayacını kullanır (bkz. ASSASIN_DASH2_*/_try_assasin_dash2).
		elif skill2_id_pressed == 5:
			_try_assasin_dash2()
		## Büyücü Kız'ın 4 varyasyonlu TEMEL'i - Korsan/Necromancer'la AYNI
		## desen, standart skill2_state == "ready" bekleme makinesi yerine
		## kendi bağımsız bekleme dizisini (bkz. _buyucu_variation_cooldowns)
		## kullanıyor.
		elif skill2_id_pressed in BUYUCU_VARIATION_SKILL2_IDS:
			_buyucu_try_activate_variation()
		elif skill2_state == "ready" and skill2_id_pressed != 0:
			_activate_skill2()
	## Üçüncü aktif yetenek (R) - bkz. dosya başındaki SKILL3_TIMING notu.
	## skill3 alanı olmayan karakterlerde get_skill3_id() 0 döner, tuş
	## hiçbir şey yapmaz.
	if Input.is_action_just_pressed("skill3") and not is_chat_typing and not is_in_merchant_zone:
		var skill3_id_pressed: int = get_skill3_id()
		## Büyücü Kız'ın R'si (bkz. BUYUCU_SET_R_VARIATIONS) - E'nin skill2
		## dalıyla (yukarıda, "elif skill2_id_pressed in BUYUCU_VARIATION_
		## SKILL2_IDS:") BİREBİR simetrik: standart skill3_state == "ready"
		## bekleme makinesini BAŞTAN devre dışı bırakıp kendi bağımsız
		## bekleme dizisine yönlendiriyoruz - _activate_skill3() Büyücü Kız
		## için HİÇ ÇAĞRILMAZ.
		if skill3_id_pressed in BUYUCU_VARIATION_SKILL2_IDS:
			_buyucu_try_activate_variation_r()
		## DÜZELTME (kullanıcı isteği: "Necromancer in R sini golem çıkarma ile
		## değiştir") - Yarasa Sürüsü (eskiden burada, id 35) artık E/skill2'de
		## (bkz. yukarısı) - Golem Çağır (id 20) standart skill3_state
		## bekleme makinesini KULLANIYOR (bkz. _activate_skill()'teki eski
		## ön kontroller artık _activate_skill3()'te), bu yüzden burada özel
		## bir bypass dalına ihtiyacı yok, aşağıdaki genel "ready" dalından
		## geçiyor.
		elif skill3_state == "ready" and skill3_id_pressed != 0:
			_activate_skill3()


## Kullanıcı bildirimi: "yaratıklarla çarpıştığımda yaratıkların geriye
## itememem gerekiyor, yürüdüğüm yönde yaratık varsa onu geçememeliyim."
## Eskiden bu sınırı SADECE enemy.gd tutuyordu (min_separation) ve oyuncu
## onu ihlal ettiğinde yaratık geri İTİLİYORDU (bkz. enemy.gd
## _physics_process sonundaki "hard snap" - itme/knockback için bırakılan
## güvenlik ağı). Artık asıl engelleme burada: oyuncu bir yaratığın gövde
## yarıçapına (bkz. enemy.gd _body_radius) daha fazla yaklaştıracak hız
## bileşenini bu yönde iptal ediyor - yaratık yerinde kalıyor, oyuncu bir
## duvara çarpmış gibi duruyor. GameManager.BODY_BLOCK_SCALE ile aynı
## küçültme çarpanı kullanılıyor ki iki taraf hep aynı sınırda anlaşsın.
## DÜZELTME (kullanıcı isteği: "body blockları ufalt yoksa karakterler
## yaratıkların arasında sıkışıp ölüyor... bu kadar büyük olmasın") - 16'dan
## 12'ye küçültüldü (bkz. GameManager.BODY_BLOCK_SCALE'deki eş zamanlı
## düşüş). enemy.gd'deki KOPYASIYLA birebir aynı kalmalı.
## Kullanıcı isteği ("tüm oynanabilir karakterleri %5 küçült"): gövde çemberi
## de (bkz. EntityScale/_apply_entity_size_scale) %5 küçüldüğü için bu
## yarıçap da 12 -> 11.4 (12 x 0.95) oldu - enemy.gd'deki kopyası da AYNI
## değere çekildi, ikisi eşit kalmazsa iki taraf farklı sınırda anlaşır.
const PLAYER_BODY_RADIUS := 11.4 ## bkz. player.tscn CollisionShape2D radius, enemy.gd'nin PLAYER_BODY_RADIUS'uyla birebir aynı olmalı

var _knockback_velocity: Vector2 = Vector2.ZERO
const KNOCKBACK_DECAY := 800.0


func apply_knockback_force(dir: Vector2, force: float) -> void:
	if force <= 0.0:
		return
	var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	_knockback_velocity += d * force
	if _knockback_velocity.length() > 400.0:
		_knockback_velocity = _knockback_velocity.normalized() * 400.0


## DÜZELTME (kullanıcı isteği: "sadece karakterler yaratıklara doğru hareket
## edince onları gidiş hızına bağlı olarak azıcık itebilsin yoksa içlerinde
## sıkışır yine. (onlar bizi asla itemez unutma)") - eskiden oyuncu bir
## yaratığın gövdesine yaklaşan hız bileşenini SADECE iptal ediyordu
## (yaratık hiç kıpırdamıyordu, oyuncu duvara çarpmış gibi kalıyordu) - bu,
## birden fazla yaratık tarafından çevrelenince oyuncunun HİÇBİR yöne
## gidememesine (her biri kendi yönünü ayrı ayrı kilitlemesine) yol
## açıyordu. Artık oyuncu hâlâ o yönde ilerleyemiyor (velocity iptali
## AYNEN duruyor) ama üstüne, o an içine girmeye çalıştığı yaratığı
## YAKLAŞMA HIZIYLA orantılı, küçük bir kuvvetle iteliyor - yaratık biraz
## açılınca sıkışma kendiliğinden çözülüyor. Bu TEK YÖNLÜ: yaratıklar
## oyuncuyu asla bu şekilde itemez (bkz. enemy.gd _apply_mutual_bounce
## düzeltmesi - hasar teması artık sadece yaratığı sekiyor, oyuncuyu değil).
const PLAYER_PUSH_ENEMY_RATIO := 0.35
## DÜZELTME (kullanıcı bildirimi: "yaratıklar bizi itince collision
## shapelerin içine sıkışıyoruz ve bir daha asla hareket edemiyoruz") -
## birden fazla yaratık oyuncuyu farklı açılardan çevreleyince aşağıdaki
## döngü HER birinin kendi yaklaşma bileşenini ayrı ayrı silmesi yüzünden
## TOPLAMDA velocity'yi tamamen sıfırlayabiliyordu (her yön bir yaratık
## tarafından bloklanıyordu) - oyuncu hiçbir yöne gidemez hale geliyordu.
## Hâlâ FİZİKSEL OLARAK içlerinde olduğumuz yaratıklara (still_overlapping)
## artık yaklaşma hızından bağımsız, sabit bir "acil açılma" kuvveti de
## uygulanıyor ki sıkışma kalıcı olmasın - "onlar bizi asla itemez" kuralı
## aynen duruyor, sadece BİZİM onları itme gücümüz sıkışma anında garantili
## hale getirildi.
const STUCK_ESCAPE_PUSH_FORCE := 220.0

## DÜZELTME (kullanıcı bildirimi: "düşmanlar bizi hala itip duvara
## sıkıştırıyor ve bir daha çıkamıyoruz duvarın içinden") - kök neden bu
## fonksiyonun İÇİNDE değil, player.tscn'in kendisindeydi: kök CharacterBody2D
## hâlâ collision_mask=4 taşıyordu (enemy.gd'nin collision_layer=4'üyle
## eşleşen FİZİKSEL bir çarpışma) - yani move_and_slide() motor seviyesinde
## oyuncuyu yaratık gövdelerinden fiziksel olarak İTİYORDU, bu fonksiyonun
## (ve enemy.gd _apply_mutual_bounce'ın) "onlar bizi asla itemez" için
## yaptığı TÜM elle yapılan iş bunun ÜSTÜNE binip çakışıyordu - oyuncu bir
## duvara yaslanmış birden fazla yaratık tarafından sıkıştırılınca motorun
## kendi çarpışma çözümü (depenetration) oyuncuyu duvarın İÇİNE itebiliyordu.
## collision_mask artık 0 (bkz. player.tscn) - yaratıklarla tüm etkileşim
## SADECE bu fonksiyondaki (ve enemy.gd'deki karşılığı) elle yazılan mesafe/
## hız mantığından geçiyor, motor seviyesinde hiçbir fiziksel itiş kalmadı.
func _block_movement_into_enemies() -> void:
	## Kullanıcı isteği: Assasin Çocuk'un yeni 3. yeteneği (Gölge Adımı,
	## skill3 id 30) görünmezken yaratıkların içinden geçebilmeli - bkz.
	## _skill_assasin_invisibility_r/_end_assasin_invisibility_r (collision_
	## mask'tan düşman katmanının da AYRICA çıkarılması gerekiyor, bu
	## fonksiyon SADECE manuel "yaklaşmayı engelle" itmesini iptal eder).
	if is_invisible:
		return
	if velocity.length() < 0.1:
		return
	var still_overlapping: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var enemy_radius: float = e._body_radius if "_body_radius" in e else 20.0
		var required_sep: float = (enemy_radius + PLAYER_BODY_RADIUS) * GameManager.BODY_BLOCK_SCALE
		var to_enemy: Vector2 = e.global_position - global_position
		var dist: float = to_enemy.length()
		if dist <= 0.001 or dist >= required_sep:
			continue
		var into_dir: Vector2 = to_enemy / dist
		var approach_speed: float = velocity.dot(into_dir)
		if approach_speed > 0.0:
			velocity -= into_dir * approach_speed
			if e.has_method("apply_knockback_force"):
				e.apply_knockback_force(into_dir, approach_speed * PLAYER_PUSH_ENEMY_RATIO)
		still_overlapping.append([e, into_dir])
	for entry in still_overlapping:
		var stuck_enemy: Node = entry[0]
		if stuck_enemy.has_method("apply_knockback_force"):
			stuck_enemy.apply_knockback_force(entry[1], STUCK_ESCAPE_PUSH_FORCE)


## DÜZELTME (kullanıcı isteği: "oyundaki karakterler de birbirinin içinden
## geçemesin bundan sonra") - _block_movement_into_enemies() ile AYNI
## teknik (o an içine girmeye çalıştığı yöndeki hız bileşenini iptal etmek),
## ama "remote_players" (gerçek katılımcı kuklaları) grubuna karşı. Sadece
## KENDİ oyuncumuzu diğerlerinin içine girmekten alıkoyar - RemotePlayer
## kuklasını itmeye ÇALIŞMIYORUZ, çünkü o SADECE görsel bir kopya, gerçek
## konumu kendi (uzak) istemcisinde yetkili - burada bir itiş uygulasak bile
## bir sonraki konum paketiyle hemen ezilirdi. Her istemci bunu KENDİ
## oyuncusu için bağımsız uyguladığından iki taraf da diğerinin içine
## giremiyor gibi hissettiriyor, ekstra senkronizasyon gerekmiyor.
func _block_movement_into_players() -> void:
	if not NetworkManager.is_multiplayer_active or velocity.length() < 0.1:
		return
	var required_sep: float = (PLAYER_BODY_RADIUS * 2.0) * GameManager.BODY_BLOCK_SCALE
	for rp in get_tree().get_nodes_in_group("remote_players"):
		if not is_instance_valid(rp) or rp.get("is_dead") == true:
			continue
		var to_other: Vector2 = rp.global_position - global_position
		var dist: float = to_other.length()
		if dist <= 0.001 or dist >= required_sep:
			continue
		var into_dir: Vector2 = to_other / dist
		var approach_speed: float = velocity.dot(into_dir)
		if approach_speed > 0.0:
			velocity -= into_dir * approach_speed


## Kullanıcı isteği: "haritamdaki 'su' ve 'ev' layerlarını collisionshape
## olarak atar mısın... hiç kimse giremez... içinden geçemez" - bkz.
## GameManager.is_position_blocked_by_terrain yorumundaki gerekçe (TileSet
## fiziği yerine karo sorgusu). Eksen eksen (X ve Y ayrı ayrı) gövde
## yarıçapı kadar ileriye "yoklama" yapılıyor; hedef karo su/ev ise SADECE
## o eksendeki hız bileşeni iptal ediliyor - bu da duvara çarpınca akıcı bir
## şekilde "kayma" hissi verir (dik açıyla yaklaşınca tam durur, çapraz
## yaklaşınca duvar boyunca kaymaya devam eder).
## DÜZELTME (kullanıcı bildirimi: "collision shapeler tam su layerının
## olduğu yerlerde değil, bazı yerlerde o layer yok ama yine de varmış gibi
## geçilmiyor, aşırı geniş olmuş") - yoklama mesafesi eskiden PLAYER_BODY_
## RADIUS'a bağlıydı; bu, oyuncunun/yaratığın gövdesi büyüdükçe suyun GERÇEK
## sınırından çok daha önce durmasına yol açıyordu (özellikle büyük gövdeli
## yaratıklarda, bkz. enemy.gd - orada 44px'e kadar çıkıyordu). Artık gövde
## boyutundan bağımsız, sabit ve küçük bir tampon kullanılıyor - blok alanı
## artık su/ev karolarının GERÇEK sınırına çok daha yakın (sadece bir
## karenin geçişini önlemeye yetecek kadar pay bırakılıyor).
## SU/EV İÇİN HÂLÂ KAPALI (kullanıcı isteği: "oyundaki collision
## shapeleri kaldır haritada istediğimiz yere hareket edebilelim sonra
## sıfırdan collision shape dizicem çünkü") - haritada gerçek CollisionShape2D
## hiç yok (bkz. yukarıdaki dosya başı notu), "collision shape" burada bu
## fonksiyonun karo-sorgusu anlamına geliyor. Yeniden dizme İLK ADIM: orman
## katmanı ("Orman parçaları/Orman parçaları", plato/uçurum duvarları) -
## kullanıcı isteği: "orman parçaları layerını collision shape ile kaplamanı
## istiyorum". Bu yüzden aşağıda is_position_blocked_by_TERRAIN (su+ev+orman)
## DEĞİL is_position_blocked_by_FOREST kullanılıyor: oyuncu su/ev karolarında
## hâlâ serbest, orman duvarından geçemiyor. Su/ev de yeniden açılacaksa
## aşağıdaki üç çağrıyı is_position_blocked_by_terrain'e çevirmek yeterli.
func _block_movement_into_terrain() -> void:
	if velocity.length() < 0.1:
		return
	## DÜZELTME (kullanıcı bildirimi: "düşmanlar bizi hala itip duvara
	## sıkıştırıyor ve bir daha çıkamıyoruz duvarın içinden oyun bitene
	## kadar") - bu güvenlik ağı, yukarıdaki collision_mask düzeltmesinden
	## (bkz. player.tscn) SONRA da işe yarasın diye eklendi: oyuncu HERHANGİ
	## bir sebeple (ör. boss knockback'i, gelecekte başka bir regresyon)
	## zaten bir duvar karosunun İÇİNDEYSE, aşağıdaki normal "ileri yönde
	## prob" mantığı deneyeceği HER yönü de "engelli" bulup onu SONSUZA DEK
	## içeride hapsedebiliyordu (prob her zaman mevcut konumdan 10px İLERİYE
	## bakıyor, zaten içerideyken bu her yönde yine karonun içine denk
	## gelebiliyor). Zaten içerideyse blok mantığı TAMAMEN atlanır, oyuncu
	## kısıtlanmadan hareket edip dışarı çıkabilir.
	if GameManager.is_position_blocked_by_forest(global_position):
		return
	var probe_dist: float = 10.0
	if velocity.x != 0.0:
		var probe_x: Vector2 = global_position + Vector2(sign(velocity.x) * probe_dist, 0.0)
		if GameManager.is_position_blocked_by_forest(probe_x):
			velocity.x = 0.0
	if velocity.y != 0.0:
		var probe_y: Vector2 = global_position + Vector2(0.0, sign(velocity.y) * probe_dist)
		if GameManager.is_position_blocked_by_forest(probe_y):
			velocity.y = 0.0



const AGGRESSIVE_DRAIN_PERCENT := 0.01 ## of max shield, per second, while active
## +damage at full shield, scaling down to 0 as shield empties - grows with
## the mod's own level (0.6 at level 1 up to 1.4 at level 10), see
## _apply_shield_mode().
var aggressive_max_damage_bonus: float = 0.6


func _process_item_shield(delta: float) -> void:
	_process_aggressive_damage_bonus()
	## Baloncuğun "yenileniyor" sayılıp sayılmayacağı - bkz. _update_shield_bubble().
	## Sadece kalkan GERÇEKTEN yukarı tırmandığı karelerde true olur; drain/
	## liability modlarında (Agresif, Şimşek Hız, Delicilik) kalkan azaldığı
	## için bu asla true olmaz.
	_shield_regenerating = false

	if item_shield_ability_slow_timer > 0.0:
		item_shield_ability_slow_timer = max(0.0, item_shield_ability_slow_timer - delta)

	if item_shield_max <= 0:
		return

	if GameManager.active_shield_mode == "aggressive":
		# Agresif Modu: never regens on its own, just burns down steadily.
		if item_shield_hp > 0:
			item_shield_hp = max(0.0, item_shield_hp - item_shield_max * AGGRESSIVE_DRAIN_PERCENT * delta)
			item_shield_changed.emit(item_shield_hp, item_shield_max)
		return

	if MODE_DRAIN_RATE.has(GameManager.active_shield_mode):
		# Şimşek Hız / Delicilik: pure liability modes - never regen, just
		# burn down at a fixed %/sec of max shield while active.
		if item_shield_hp > 0:
			var rate: float = MODE_DRAIN_RATE[GameManager.active_shield_mode]
			item_shield_hp = max(0.0, item_shield_hp - item_shield_max * rate * delta)
			item_shield_changed.emit(item_shield_hp, item_shield_max)
		return

	## Yenilenme hızı artık aktif kalkan TÜRÜNE göre değişiyor (bkz.
	## SHIELD_TYPES/_active_shield_regen_rate) - eskiden tek bir GameManager.
	## shield_level'a bağlıydı, şimdi 4 türden hangisi aktifse onun kendi
	## taban+seviye formülü kullanılıyor, modlar (shield_mode_regen_mult) yine
	## aynı şekilde üstüne çarpan olarak biniyor.
	## Kalkan Yüzüğü: %4 daha hızlı yenilenme (bkz. item_shield_regen_percent).
	var base_regen_rate: float = _active_shield_regen_rate() * shield_mode_regen_mult * (1.0 + item_shield_regen_percent)
	## Yetenek kullanımı sonrası %50 yavaşlama cezası (bkz. item_shield_
	## ability_slow_timer sınıf üstü yorumu) - hasar sonrası TAM durdurma
	## (item_shield_regen_delay) ile KARIŞTIRILMASIN, bu SADECE hızı düşürür.
	var ability_slow_mult: float = 0.5 if item_shield_ability_slow_timer > 0.0 else 1.0

	if item_shield_regen_delay > 0:
		item_shield_regen_delay -= delta
		# Metanet Modu lets a small trickle through even on hit-cooldown -
		# artık base_regen_rate'ten bağımsız, doğrudan maksimum kalkanın
		# %'si/sn (MODE_DRAIN_RATE ile aynı tutarlı birim). Gerçek artış
		# artık anlık değil, _process_shield_regen_tick() ile "tik"leniyor
		# (bkz. _shield_regen_tick_pending sınıf üstü yorumu).
		if shield_mode_combat_regen_factor > 0.0 and item_shield_hp < item_shield_max:
			var trickle: float = item_shield_max * shield_mode_combat_regen_factor * ability_slow_mult
			_shield_regen_tick_pending += trickle * delta
			_shield_regenerating = true
		return

	if item_shield_hp < item_shield_max:
		_shield_regen_tick_pending += base_regen_rate * ability_slow_mult * delta
		_shield_regenerating = true


## Kalkanın gerçek artışını "smooth" (her karede minik minik) değil, sabit
## aralıklarla (SHIELD_REGEN_TICK_INTERVAL) toplu halde uygular - kullanıcı
## isteği: "kalkan yenilenmelerinin saniye/tick olmasını istiyorum, anlık
## olarak smooth bir şekilde artmasını istemiyorum." _process_item_shield ve
## _process_kalkan_yenileme her kare hesapladıkları miktarı doğrudan
## item_shield_hp'ye değil, _shield_regen_tick_pending biriktiricisine
## yazıyor; toplam yenilenme hızı/miktarı birebir aynı kalıyor, sadece
## HUD'daki/kalkan barındaki artış görünümü düzenli sıçramalar (tik) halinde
## oluyor.
func _process_shield_regen_tick(delta: float) -> void:
	_shield_regen_tick_timer += delta
	if _shield_regen_tick_timer < SHIELD_REGEN_TICK_INTERVAL:
		return
	_shield_regen_tick_timer = 0.0
	if _shield_regen_tick_pending <= 0.0:
		return
	var applied: float = min(_shield_regen_tick_pending, item_shield_max - item_shield_hp)
	_shield_regen_tick_pending = 0.0
	if applied > 0.0:
		item_shield_hp = min(item_shield_max, item_shield_hp + applied)
		item_shield_changed.emit(item_shield_hp, item_shield_max)


## Eşyaların (bkz. scripts/items.gd) zamanla/koşula bağlı pasiflerini işler -
## sürekli statlar zaten _apply_item_stats() ile satın alma anında uygulanıyor,
## burada sadece "belirli bir koşulda aktif/pasif olan" ya da "sayaç isteyen"
## pasifler var: Deri Çizme (hareket halinde sıvışma), Vitamin (hasar sonrası
## regen penceresi geri sayımı). DÜZELTME (zırh kaldırıldı): Steroid'in
## "düşük canda fazladan zırh" pasifi burada dururdu, zırhla birlikte
## kaldırıldı (bkz. items.gd steroid tanımı).
func _process_item_passives(delta: float) -> void:
	## Deri Çizme: sadece hareket halindeyken aktif sıvışma bonusu (bkz.
	## take_damage() effective_dodge).
	if item_move_dodge_base > 0.0:
		var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		item_move_dodge_active = item_move_dodge_base if input_direction.length() > 0.1 else 0.0

	## Vitamin: hasar sonrası 5sn'lik regen penceresi geri sayımı (bkz.
	## take_damage() - pencere orada 5.0'a set edilir; gerçek regen
	## uygulaması _process_regen() içinde, timer > 0 olduğu sürece).
	if item_vitamin_regen_timer > 0.0:
		item_vitamin_regen_timer = max(0.0, item_vitamin_regen_timer - delta)


## Şovalye (Paladin)'in TEMEL yeteneği (skill2 id 10): saniye başına %5 +
## zırhının %500'ü kadar kalkan, HER KAREDE sürekli (Oakley aynı id'yi
## kullanır ama kendi ayrı tik tabanlı formülüne sahiptir - bkz. aşağıdaki
## karakter ayrımı ve _process_healer_shield_tick).
## DÜZELTME (kullanıcı isteği: "şovalye adamın kalkan yenilenme skilinin
## saldırı gücü oranını silip zırh oranının %500ü olarak değiştir yani 1
## zırhı varsa skill açıkken her saniye 5 kalkan yenilenecek") - eskiden
## ikinci terim saldırı gücüne (damage_bonus * 2.0), sonra ZIRHA (armor * 5.0)
## bağlıydı. DÜZELTME (kullanıcı isteği: "şovalye adamın E yeteneği artık
## Zırhının %500'üne göre yenilenmesi artmayacak, bundan sonra sadece
## Aktifken saniyede EKSİK kalkan miktarının %5'ini yenileyecek") - zırh
## terimi tamamen kaldırıldı, "max kalkanın %5'i" yerine "EKSİK kalkanın
## (item_shield_max - item_shield_hp) %5'i" formülüne geçildi (bkz. aşağıdaki
## regen_amount hesabı) - dolu kalkana yaklaştıkça yenilenme doğal olarak
## yavaşlıyor.
const KALKAN_YENILEME_PERCENT_PER_SEC := 0.05

## Oakley'nin TEMEL yeteneği (skill2 id 10) - kullanıcı isteğiyle yeniden
## tasarlandı: "6 saniye boyunca her saniye kendinin veya müttefiğinin %1
## maksimum kalkanı + Oakley'nin saldırı gücü oranının %200'ü kadar kalkan
## yenilesin. %'lik kalkan yenileme HEDEFİN KENDİSİNE özgüdür, saldırı gücü
## oranı ise Oakley'nin saldırı gücünden hesaplanır." Sonradan kullanıcı
## isteğiyle saldırı gücü oranı %200'den %60'a düşürüldü (kalkan yenileme
## çok güçlüydü).
const OAKLEY_E_TICK_PERCENT := 0.01 ## saniyede: hedefin kendi max kalkanının %1'i
const OAKLEY_E_TICK_ATTACK_RATIO := 0.6 ## saniyede: + Oakley'nin saldırı gücünün %60'ı
## DÜZELTME (kullanıcı isteği: "Melekin kalkan yeteneğinin saldırı gücü
## oranını %40'a düşür" + "oakley ve melek farklı karakterler, isim hatasına
## yol açan her neyi düzelt") - bu tik SADECE Oakley (roster 2) DEĞİL, Melek
## (roster 10) tarafından da kullanılıyor (bkz. _process_kalkan_yenileme),
## ama oranın TEK bir OAKLEY_* sabitinden okunması Melek'e özel bir ayar
## yapmayı Oakley'i de değiştirmeden imkansız kılıyordu. Artık Melek KENDİ
## oranını kullanıyor (bkz. _process_healer_shield_tick'teki seçim) - Oakley
## OAKLEY_E_TICK_ATTACK_RATIO'da (%60) AYNEN kalıyor.
const MELEK_E_TICK_ATTACK_RATIO := 0.4 ## saniyede: Melek'in saldırı gücünün %40'ı (Oakley'den AYRI, bkz. yukarıdaki not)
const OAKLEY_E_RANGE := 300.0
const OAKLEY_E_TICK_INTERVAL := 1.0
var _oakley_e_tick_timer: float = 0.0
var _oakley_e_ally_target: Node2D = null

func _process_kalkan_yenileme(delta: float) -> void:
	if not is_kalkan_yenileme_active:
		return
	## Oakley (roster id 2) VE Melek (roster id 10, Oakley'nin birebir klonu -
	## bkz. characters.gd DEFS[10] yorumu "Oakley'nin bütün yetenekleri Melek'e
	## olduğu gibi geçecek"): tik tabanlı, kendine+müttefiğe uygulanan versiyon.
	## DÜZELTME (kullanıcı bildirimi: "şovalye adamın kalkan yeteneği oakley
	## ve meleğin kalkan yeteneği gibi çalışıyor") - kök neden: bu kontrol
	## sadece "== 2" idi, Melek'in roster id'si (10) hiç eklenmemişti (yorum
	## bunun yapıldığını iddia ediyordu ama kod hiç güncellenmemişti). Sonuç:
	## Melek yanlışlıkla Şovalye'nin GENERİK (müttefiksiz, %5/sn) formülüne
	## düşüyordu - Şovalye/diğer skill2=10 sahipleri (sadece Şovalye) bundan
	## tamamen ayrı kalmaya devam ediyor.
	if GameManager.selected_char_id == 2 or GameManager.selected_char_id == 10:
		_process_healer_shield_tick(delta)
		return
	if item_shield_max <= 0:
		return
	var ability_slow_mult: float = 0.5 if item_shield_ability_slow_timer > 0.0 else 1.0
	var missing_shield: float = item_shield_max - item_shield_hp
	var regen_amount: float = missing_shield * KALKAN_YENILEME_PERCENT_PER_SEC * delta * ability_slow_mult
	if item_shield_hp < item_shield_max:
		## Gerçek artış anlık değil, _process_shield_regen_tick() ile
		## "tik"leniyor (bkz. _shield_regen_tick_pending sınıf üstü yorumu).
		_shield_regen_tick_pending += regen_amount
		_shield_regenerating = true


## Oakley'nin TEMEL yeteneği için saniyede bir tetiklenen tik - hem Oakley'yi
## hem de (hâlâ menzilde/geçerliyse) _skill_kalkan_yenileme()'de kilitlenen
## müttefiği aynı anda kalkan yönünden iyileştirir.
func _process_healer_shield_tick(delta: float) -> void:
	var ability_slow_mult: float = 0.5 if item_shield_ability_slow_timer > 0.0 else 1.0
	_oakley_e_tick_timer -= delta
	if _oakley_e_tick_timer > 0.0:
		return
	_oakley_e_tick_timer += OAKLEY_E_TICK_INTERVAL

	## bkz. MELEK_E_TICK_ATTACK_RATIO üstündeki DÜZELTME notu - Melek (roster
	## 10) KENDİ oranını kullanır, Oakley (roster 2, aynı fonksiyonu paylaşan
	## tek diğer karakter) OAKLEY_E_TICK_ATTACK_RATIO'da değişmeden kalır.
	var attack_ratio: float = MELEK_E_TICK_ATTACK_RATIO if GameManager.selected_char_id == 10 else OAKLEY_E_TICK_ATTACK_RATIO
	var attack_power_bonus: float = damage_bonus * attack_ratio * ability_slow_mult
	## bkz. _skill_heal()'deki AYNI Melek düzeltmesi ("Q ve E ... kendisine
	## %50 daha az") - SADECE self_tick'e uygulanıyor, ally_tick (aşağısı)
	## attack_power_bonus'u TAM olarak kullanır.
	var self_amount_mult: float = 0.5 if GameManager.selected_char_id == 10 else 1.0

	## Kendisi: %1 kendi max kalkanı + saldırı gücünün %200'ü. Kullanıcı
	## isteği: "bütün yetenekler kritik vuruş yapabilir ... kalkan verme de
	## dahil" - her tik kendi kritik zarını atıyor.
	if item_shield_max > 0.0 and item_shield_hp < item_shield_max:
		var self_tick: float = _apply_ability_crit(((item_shield_max * OAKLEY_E_TICK_PERCENT * ability_slow_mult) + attack_power_bonus) * self_amount_mult, _roll_ability_crit())
		if self_tick > 0.0:
			_shield_regen_tick_pending += self_tick
			_shield_regenerating = true

	## Müttefik: %1 KENDİ max kalkanı + Oakley'nin saldırı gücünün %200'ü -
	## hedef hâlâ geçerli/canlı VE menzildeyse (multiplayer'da hareket
	## edebilir), kalkan alanları varsa (herkeste yok, ör. Matthew'in
	## yaratığı) uygulanır, yoksa sessizce atlanır.
	var ally_in_range: bool = _oakley_e_ally_target and is_instance_valid(_oakley_e_ally_target) \
			and "item_shield_max" in _oakley_e_ally_target and "item_shield_hp" in _oakley_e_ally_target \
			and global_position.distance_to(_oakley_e_ally_target.global_position) <= OAKLEY_E_RANGE
	if ally_in_range:
		var ally_shield_max: float = _oakley_e_ally_target.item_shield_max
		var ally_shield_hp: float = _oakley_e_ally_target.item_shield_hp
		if ally_shield_max > 0.0 and ally_shield_hp < ally_shield_max:
			var ally_tick: float = _apply_ability_crit((ally_shield_max * OAKLEY_E_TICK_PERCENT * ability_slow_mult) + attack_power_bonus, _roll_ability_crit())
			if ally_tick > 0.0:
				## bkz. _apply_shield_heal_to_ally üstündeki BUG DÜZELTMESİ notu -
				## hedef gerçek bir uzak oyuncuysa RPC ile kendi istemcisine
				## ulaştırılıyor, doğrudan kozmetik kuklaya yazılmıyor.
				_apply_shield_heal_to_ally(_oakley_e_ally_target, ally_tick)
				_spawn_wave_beam_to_ally(_oakley_e_ally_target, "shield")
	## Kullanıcı isteği ("efekt sistemi" - kalkan.png): "kalkan bağı kesilirse
	## efekt de kapanmalı" - bkz. heal tarafındaki AYNI geçiş-yakalama deseni.
	if ally_in_range and not _melek_shield_ally_aura_on:
		_set_ally_aura(_oakley_e_ally_target, "shield", true)
		_melek_shield_ally_aura_on = true
	elif not ally_in_range and _melek_shield_ally_aura_on:
		_set_ally_aura(_oakley_e_ally_target, "shield", false)
		_melek_shield_ally_aura_on = false


## Kullanıcı isteği: Melek'in 3. yeteneği - kendi etrafında VE Can Basma/
## Kalkan Yenileme ile bağ kurduğu bir dostun (_oakley_q_ally_target/
## _oakley_e_ally_target) etrafında yakındaki tüm yaratıkları 4sn korkutup
## kaçırır. _do_repel()/_skill_berserk() (AOE tarama + mesafe kontrolü)
## deseninin çok-merkezli versiyonu.
const MELEK_FEAR_RADIUS := 260.0
const MELEK_FEAR_DURATION := 4.0

func _skill_melek_fear() -> void:
	var centers: Array = [global_position]
	if is_instance_valid(_oakley_q_ally_target):
		centers.append(_oakley_q_ally_target.global_position)
	if is_instance_valid(_oakley_e_ally_target):
		centers.append(_oakley_e_ally_target.global_position)
	var feared: Array = []
	for center in centers:
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.get("is_dead") == true or feared.has(e):
				continue
			if center.distance_to(e.global_position) <= MELEK_FEAR_RADIUS:
				if e.has_method("apply_fear"):
					e.apply_fear(center, MELEK_FEAR_DURATION)
					feared.append(e)
	_spawn_burst(Color(1.0, 0.95, 0.6))
	_spawn_ring(Color(1.0, 0.95, 0.6))


## Baloncuk iki ayrı kaynaktan görünür olabilir: Şovalye Adam'ın R-tuşu
## becerisi (is_shielded) VEYA dükkandan alınan kalıcı Sihirli Kalkan
## (item_shield_hp > 0). İkisinden biri true olduğu sürece baloncuk görünür;
## ikisi de kapanınca kaybolur. Edge-triggered: sadece durum gerçekten
## değiştiğinde tetiklenir.
##
## GÖRÜNME/KAYBOLMA ANİMASYONU seçimi artık NEDENE göre ayrılıyor (bkz.
## shield_visual.gd'nin appear/dismiss/show_instant/hide_instant ayrımı):
## grow SADECE gerçek bir yenilenme/aktifleşme başlangıcında, pop SADECE
## gerçek bir "kalkan kırıldı/skill bitti" anında oynar - salt hasar flaşı
## (kalkan dolu/sabit/azalıyor ama yenilenmiyor) grow/pop'u TETİKLEMEZ,
## doğrudan "loop" gösterip sessizce kaybolur. Eskiden HER hasar flaşında
## appear()/dismiss() çağrılıyordu; flaş süresi (0.6sn) grow animasyonunun
## kendi süresinden (0.83sn) bile kısa olduğu için baloncuk loop'a hiç
## ulaşamıyor, sürekli büyüme/patlama arasında kesiliyordu (bkz. kullanıcı
## bildirimi: "hasar alırken hep başlangıç ve son kısmını gösteriyor").
func _update_shield_bubble(delta: float) -> void:
	if _damage_flash_timer > 0.0:
		_damage_flash_timer = max(0.0, _damage_flash_timer - delta)

	var owned_type: String = _owned_shield_type_key()
	if shield_visual and shield_visual.has_method("set_shield_type"):
		shield_visual.set_shield_type(owned_type)

	## Savaş Kalkanı (always_regen=true) neredeyse HER zaman "yenileniyor"
	## sayılır (delay yok, dolana kadar sürekli tırmanıyor) - bu yüzden
	## diğer 3 türden farklı olarak _shield_regenerating'i should_show'a HİÇ
	## katmıyoruz: kullanıcı isteği "savaş kalkanı daima yenilenen bir kalkan
	## olduğu için baloncuk efekti SADECE hasar alınca görünsün". is_shielded
	## (Şovalye Adam'ın R-tuşu becerisi) bundan bağımsız, her türde aynı
	## şekilde kalıcı gösterime devam eder.
	var is_combat_shield: bool = owned_type == "shield_savas"
	## is_shielded (Şovalye Adam'ın R-tuşu becerisi) hâlâ beceri süresince
	## kalıcı gösterir. Sihirli Kalkan (item shield) tarafı ise SADECE hasar
	## alırken (_damage_flash_timer) ve (Savaş Kalkanı DIŞINDA) gerçekten
	## yenilenirken (_shield_regenerating) görünür - dolu dururken baloncuk
	## göstermez.
	var should_show: bool = is_shielded or _damage_flash_timer > 0.0 or (_shield_regenerating and not is_combat_shield)
	var shield_skill_just_ended: bool = _shield_active_prev_frame and not is_shielded

	if should_show and not _bubble_active:
		_bubble_active = true
		if shield_visual:
			if is_shielded or (_shield_regenerating and not is_combat_shield):
				shield_visual.appear() ## gerçek yenilenme/aktifleşme anı - grow
			else:
				shield_visual.show_instant() ## salt hasar flaşı - doğrudan loop
	elif not should_show and _bubble_active:
		_bubble_active = false
		if shield_visual:
			var truly_broke: bool = shield_skill_just_ended or (item_shield_max > 0 and item_shield_hp <= 0.0)
			if truly_broke:
				shield_visual.dismiss() ## gerçek "kalkan bitti" anı - pop
			else:
				shield_visual.hide_instant() ## salt flaş süresi doldu - sessiz solma

	_shield_active_prev_frame = is_shielded


## Agresif Modu: the more shield charge you're sitting on, the harder every
## hit lands - read live by weapon.gd via _player_stat("aggressive_damage_bonus").
func _process_aggressive_damage_bonus() -> void:
	if GameManager.active_shield_mode == "aggressive" and item_shield_max > 0:
		aggressive_damage_bonus = (item_shield_hp / item_shield_max) * aggressive_max_damage_bonus
	else:
		aggressive_damage_bonus = 0.0


func _process_spray(delta: float) -> void:
	if GameManager.spray_level <= 0:
		return
	spray_timer += delta
	if spray_timer >= 10.0:
		spray_timer = 0.0
		_do_repel()


func _do_repel() -> void:
	var radius: float = 150.0 + GameManager.spray_level * 10.0
	var push: float = 70.0 + GameManager.spray_level * 6.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < radius and d > 0.1:
			var dir: Vector2 = (e.global_position - global_position).normalized()
			if e.has_method("apply_knockback_force"):
				e.apply_knockback_force(dir, push)
			else:
				e.global_position += dir * push
	_spawn_ring(Color(0.55, 0.85, 1.0))


# ---------- Character passives (always-on, unlike the R-key ulti / E-key temel) ----------

const PetScene := preload("res://scenes/player_pet.tscn")
var _matthew_pet: Node2D = null
## bkz. _spawn_matthew_pet/_on_matthew_pet_died - broadcast_pet_spawn/despawn
## ve konum senkronu (broadcast_pet_state) için aynı benzersiz kimlik.
var _matthew_pet_instance_id: String = ""

## Tracked explicitly instead of only polling is_instance_valid(_matthew_pet) -
## that polling approach was fragile around queue_free()'s one-frame delay and
## ended up only ever respawning the pet once. _matthew_pet_alive is flipped
## precisely by the pet's own "died" signal (see _on_matthew_pet_died), so the
## respawn countdown always starts at the right moment no matter how the pet
## died (combat or Matthew's own sacrifice).
var _matthew_pet_alive: bool = false
var _matthew_respawn_timer: float = 0.0 ## starts at 0 so the pet spawns on the very first tick
const MATTHEW_RESPAWN_DELAY := 30.0

## DÜZELTME (kullanıcı isteği: "oakley ve melek farklı karakterler, bunları
## bağlayan veya isim hatasına yol açan her neyi düzelt - eskiden Oakley'nin
## yetenekleri Melek'e geçti diye kodlar hala Oakley'e ait sanıyor, Melek'in
## yeteneklerinin adı Melek'le alakalı olmalı") - bu pasif fonksiyon/sabitler
## PRATİKTE SADECE Melek'e ait (Oakley roster id 2 yukarıdaki dispatch'te
## AYRI _process_oakley_passive'e gidiyor, buraya hiç düşmüyor) ama hala
## "OAKLEY_" önekini taşıyorlardı - MELEK_ olarak yeniden adlandırıldı.
const MELEK_PASSIVE_RANGE := 300.0
## DÜZELTME (kullanıcı isteği: "Melek'in pasifi %0.5 can yerine saldırı
## gücünün %5'si olarak güncelle. Yani 100 saldırı gücü varsa 5 can
## yenileyecek yakınındaki herkes.") - eskiden HER hedefin KENDİ max canının
## %0.5'iydi (bkz. _passive_melek - herkese FARKLI, kendi canına göre bir
## miktar); artık Melek'in KENDİ saldırı gücünün (damage_bonus) sabit bir
## yüzdesi - TEK bir ortak miktar, hem Melek'in kendisine hem her müttefike
## AYNI şekilde uygulanıyor.
## DÜZELTME (kullanıcı isteği: "Melek'in pasifinin can yenilenmesi saldırı
## gücü oranını %5'ten %2'ye düşür") - %5 çok güçlü bulundu.
const MELEK_PASSIVE_ATTACK_POWER_PERCENT := 0.02 ## saldırı gücünün %2'si/sn
const MELEK_PASSIVE_TICK_INTERVAL := 1.0
var _melek_passive_tick_timer: float = 0.0

## Talon: "her yetenek kullandığında yığılan güç" - kullanıcı isteği (YENİ
## KİT, eski "canı azalınca saldırı hızı artışı" pasifi TAMAMEN kaldırıldı):
## her yetenek (skill/skill2/skill3) kullanımında +1 yük (en fazla 5, bkz.
## _talon_add_passive_stack - _activate_skill/_activate_skill2/_activate_
## skill3'ün ÜÇÜNDE de çağrılıyor), her yük +%6 saldırı gücü (talon_damage_
## bonus üzerinden, weapon.gd zaten bunu okuyordu) ve +%4 hasar azaltma
## (take_damage()'taki _talon_passive_damage_taken_mult() üzerinden) verir.
## TALON_PASSIVE_GRACE_DURATION boyunca yeni bir yetenek kullanılmazsa
## yükler TALON_PASSIVE_DECAY_INTERVAL'de bir azalmaya başlar.
const TALON_PASSIVE_MAX_STACKS := 5
const TALON_PASSIVE_ATK_PER_STACK := 0.06 ## +%6 saldırı gücü / yük
const TALON_PASSIVE_DMG_REDUCTION_PER_STACK := 0.04 ## +%4 hasar azaltma / yük
const TALON_PASSIVE_GRACE_DURATION := 6.0 ## yeni kullanım olmadan yük azalmaya BAŞLAMADAN önceki süre
const TALON_PASSIVE_DECAY_INTERVAL := 2.0 ## bu süreden sonra HER 2sn'de bir yük azalır
var _talon_passive_stacks: int = 0
var _talon_passive_grace_timer: float = 0.0
var _talon_passive_decay_timer: float = 0.0


func _process_character_passive(delta: float) -> void:
	## DÜZELTME (kullanıcı isteği: "Oakleyin pasifi silinecek ve Q su bundan
	## sonra pasifi olacak") - eskiden Oakley'nin pasifi skill id 1'e (Q/ULTİ
	## yuvası) göre dallanıyordu, Melek'le PAYLAŞILAN bu id'ye bağlı olduğu
	## için _process_character_passive'in _process_oakley_passive'e giden
	## kısmı Oakley'nin "skill" alanı Arı Sürüsü'ne (id 33) taşınınca hiç
	## tetiklenmeyecekti - Necromancer'ın ruh toplama bug'ıyla (bkz. o
	## düzeltmenin notu) AYNI hata sınıfı. Artık Oakley roster id'sine (2)
	## göre DOĞRUDAN, en başta ayrılıyor - hangi yetenek Q/E/R'de olursa
	## olsun bozulmaz.
	if GameManager.selected_char_id == 2:
		_process_oakley_passive(delta)
		return
	match get_skill_character_id():
		## Melek eski pasifini ("kendini+müttefikleri %0.5/sn yeniler",
		## _passive_melek) AYNEN koruyor - skill id 1 artık SADECE Melek'in.
		1: _passive_melek(delta)
		7: _passive_melek(delta) ## artık kullanılmıyor ama zararsız - eski/olası gelecek eşleme
		## DÜZELTME: bu dispatch ESKİDEN "8" idi (Talon'un ESKİ ulti id'si,
		## Devleşme/Yer Sarsıntısı takası öncesinden kalma) - Talon'un GERÇEK
		## ulti id'si uzun süredir 15'ti (şimdi 38, bkz. characters.gd), yani
		## bu pasif dispatch ZATEN hiç tetiklenmiyordu (get_skill_character_id()
		## asla 8 dönmüyordu). "Talon yeni skilleri" isteğiyle pasif de
		## TAMAMEN yenilendi (bkz. _passive_talon), dispatch artık DOĞRU id'de.
		38: _passive_talon(delta)
		9: _passive_matthew(delta)


## Melek (bkz. dosya başı "1:" dispatch notu - Oakley'nin roster id 2 için
## AYRI bir pasifi var, bu fonksiyon artık pratikte SADECE Melek'e ait):
## "her saniye kendinin ve müttefiklerinin canını yeniler" - BUG DÜZELTMESİ:
## eskiden SADECE müttefikleri iyileştiriyordu, kendisi hiç yenilenmiyordu
## (bkz. kullanıcı bildirimi: "pasifi çalışmıyor ... kendinin ve
## müttefiklerinin canını yenilemesi gerekiyor ama yenilemiyor") - artık
## kendi canı da her karede yenileniyor, menzil sınırlaması yok (kendisi
## zaten her zaman "menzilde"). DÜZELTME (kullanıcı isteği: "Melek'in pasifi
## %0.5 can yerine saldırı gücünün %5'si olarak güncelle") - miktar artık
## hedefin KENDİ max canının %0.5'i DEĞİL, Melek'in KENDİ saldırı gücünün
## (damage_bonus) %5'i - bkz. MELEK_PASSIVE_ATTACK_POWER_PERCENT.
## DÜZELTME (kullanıcı isteği: "oakley ve melek farklı karakterler, isim
## hatasına yol açan her neyi düzelt") - fonksiyon _passive_oakley'den
## _passive_melek'e yeniden adlandırıldı (zaten SADECE Melek çağırıyordu).
func _passive_melek(delta: float) -> void:
	_melek_passive_tick_timer += delta
	if _melek_passive_tick_timer < MELEK_PASSIVE_TICK_INTERVAL:
		return
	_melek_passive_tick_timer -= MELEK_PASSIVE_TICK_INTERVAL

	## bkz. MELEK_PASSIVE_ATTACK_POWER_PERCENT üstündeki DÜZELTME notu - TEK
	## bir miktar, Melek'in KENDİ damage_bonus'undan hesaplanır, hem kendisine
	## hem her müttefike (aşağısı) AYNI şekilde uygulanır.
	var passive_heal: float = damage_bonus * MELEK_PASSIVE_ATTACK_POWER_PERCENT
	if max_health > 0.0 and health < max_health:
		health = min(max_health, health + passive_heal)
		health_changed.emit(health, max_health)

	for ally: Node in get_tree().get_nodes_in_group("player_ally"):
		if not is_instance_valid(ally):
			continue
		if global_position.distance_to(ally.global_position) > MELEK_PASSIVE_RANGE:
			continue
		if not ally.has_method("heal") or not ("max_health" in ally):
			continue
		var ally_heal: float = passive_heal
		ally.heal(ally_heal)
		if "peer_id" in ally:
			var target_peer_id: int = int(ally.peer_id)
			## Kendi sunucumuzda host da geçerli bir peer id'ye (1) sahip
			## olabilir - eskiden "> 1" idi ve host'u hedefleyen senkronizasyonu
			## yanlışlıkla atlıyordu.
			if target_peer_id > 0 and NetworkManager.is_multiplayer_active:
				NetworkManager.sync_ally_heal.rpc(target_peer_id, ally_heal)


## DÜZELTME (kullanıcı isteği: "Oakleyin pasifi silinecek ve Q su bundan sonra
## pasifi olacak, ve otomatik olarak yakınlarına çiçek bırakacak... 2 yük
## olayı falan yok bunda dolduğu anda oakleyin yakınında rasgele yerlere
## bıraksın") - eski düşük-can tetiklemeli kalkan/can pasifi TAMAMEN
## kaldırıldı. Çiçek artık oyuncunun BASTIĞI bir yetenek değil (bkz. eski
## _try_oakley_flower/OAKLEY_FLOWER_MAX_CHARGES - 2 yük sistemi silindi),
## SADECE bu zamanlayıcı üzerinden kendiliğinden düşüyor - eski yük
## yenilenme süresi (18sn) yeni tek/sabit aralık olarak korundu (dengeyi
## büyük ölçüde değiştirmesin diye).
const OAKLEY_FLOWER_AUTO_INTERVAL := 18.0
## "yakınında rasgele yerlere" - Oakley'nin TAM konumu yerine bu yarıçap
## içinde rastgele bir noktaya düşer (bkz. _spawn_buyucu_meteor_strike/
## _apply_korsan_bombardment_tick ile AYNI "rastgele açı + rastgele mesafe"
## deseni).
const OAKLEY_FLOWER_DROP_RADIUS := 70.0
var _oakley_flower_auto_timer: float = OAKLEY_FLOWER_AUTO_INTERVAL
var _oakley_flower_id_counter: int = 0

func _process_oakley_passive(delta: float) -> void:
	_oakley_flower_auto_timer -= delta
	if _oakley_flower_auto_timer > 0.0:
		return
	_oakley_flower_auto_timer = OAKLEY_FLOWER_AUTO_INTERVAL
	_spawn_oakley_flower_auto()


## bkz. _process_oakley_passive üstündeki DÜZELTME notu. Eski _try_oakley_
## flower() ile BİREBİR AYNI kurulum (çiçeğin kendisi/ağ yayını), sadece
## konum artık Oakley'nin TAM üstü değil rastgele yakın bir nokta, ve
## bırakma anında kısa bir "sihirli bağ" efekti eşlik ediyor (kullanıcı
## isteği: "çiçek bırakırken bıraktığı yere doğru... ince bir sihirli bağ
## efekti oluşacak anlık").
func _spawn_oakley_flower_auto() -> void:
	var angle: float = randf() * TAU
	var dist: float = randf_range(0.0, OAKLEY_FLOWER_DROP_RADIUS)
	var drop_pos: Vector2 = global_position + Vector2(cos(angle), sin(angle)) * dist
	_oakley_flower_id_counter += 1
	var flower_id: String = "%d_%d" % [multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0, _oakley_flower_id_counter]
	var flower := Node2D.new()
	flower.set_script(preload("res://scripts/oakley_flower.gd"))
	get_tree().current_scene.add_child(flower)
	flower.global_position = drop_pos
	flower.call("setup", damage_bonus, flower_id)
	var bond := Node2D.new()
	bond.set_script(preload("res://scripts/fx_oakley_flower_bond.gd"))
	get_tree().current_scene.add_child(bond)
	bond.call("setup", global_position, drop_pos)
	## bkz. eski _try_oakley_flower() üstündeki AYNI yorum - uzak istemcide
	## gerçek Oakley referansı olmadığı için gereken tüm veri extra_data ile
	## taşınıyor. "oakley_flower_spawn" işleneni değişmedi (remote_player.gd),
	## sadece konum artık drop_pos (global_position değil).
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "oakley_flower_spawn", drop_pos, {
			"caster_damage_bonus": damage_bonus,
			"flower_id": flower_id
		})
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "oakley_flower_bond", global_position, {
			"end_pos": drop_pos
		})
	_spawn_burst(Color(1.0, 0.7, 0.85))


## Herhangi bir yetenek (skill/skill2/skill3) BAŞARIYLA aktifleştiğinde
## _activate_skill()/_activate_skill2()/_activate_skill3()'ün ÜÇÜNDEN de
## çağrılır - SADECE Talon için (bkz. GameManager.selected_char_id == 1,
## roster id - get_skill_character_id()'nin AKSİNE ULTİ'ye göre DEĞİŞMEZ)
## bir yük ekler ve "çürüme" saatini sıfırlar. Diğer karakterlerde no-op.
func _talon_add_passive_stack() -> void:
	if GameManager.selected_char_id != 1:
		return
	_talon_passive_stacks = min(TALON_PASSIVE_MAX_STACKS, _talon_passive_stacks + 1)
	_talon_passive_grace_timer = TALON_PASSIVE_GRACE_DURATION
	_talon_passive_decay_timer = 0.0
	_talon_recompute_damage_bonus()


## _process_character_passive() (skill id 38, bkz. o fonksiyon) tarafından
## her karede çağrılır - sadece yük AZALMASINI işler (yük EKLENMESİ/saldırı
## gücü güncellemesi zaten anında _talon_add_passive_stack()'te olur).
func _passive_talon(delta: float) -> void:
	if _talon_passive_stacks <= 0:
		return
	if _talon_passive_grace_timer > 0.0:
		_talon_passive_grace_timer -= delta
		return
	_talon_passive_decay_timer += delta
	if _talon_passive_decay_timer >= TALON_PASSIVE_DECAY_INTERVAL:
		_talon_passive_decay_timer = 0.0
		_talon_passive_stacks -= 1
		_talon_recompute_damage_bonus()


## talon_damage_bonus'un TEK yazma noktası - İKİ AYRI kaynaktan besleniyor
## (pasif yükleri: +, Ayna Formu'nun kopya-başı cezası: -). Biri diğerini
## DOĞRUDAN atama (=) ile EZMESİN diye (ör. bir yük dolarken Ayna Formu da
## aktifse) ikisi HER ZAMAN birlikte, sıfırdan yeniden hesaplanıyor - bkz.
## _talon_add_passive_stack/_passive_talon/_skill_talon_mirror_form/_end_
## talon_mirror_form, hepsi doğrudan atama yerine BUNU çağırıyor.
func _talon_recompute_damage_bonus() -> void:
	var mirror_penalty: float = _talon_mirror_copies.size() * TALON_MIRROR_DMG_PENALTY_PER_COPY
	talon_damage_bonus = (_talon_passive_stacks * TALON_PASSIVE_ATK_PER_STACK) - mirror_penalty


## take_damage()'taki effective_damage hesabına çarpımsal olarak eklenir.
## damage_taken_mult'un AKSİNE (Kurt Adam berserk'i de kullanıyor,
## _end_skill_effects()'te KOŞULSUZ 1.0'a sıfırlanıyor) bu değer HER ZAMAN
## canlı yük sayısından taze hesaplanır - Talon'un KENDİ yeteneklerinden
## biri bitince (_end_skill_effects/_end_skill2_effects/_end_skill3_effects)
## YANLIŞLIKLA sıfırlanma riski yok.
func _talon_passive_damage_taken_mult() -> float:
	return 1.0 - (_talon_passive_stacks * TALON_PASSIVE_DMG_REDUCTION_PER_STACK)


## ---------- Korsan (roster 9, "skill": 18/"skill2": 17) ----------
## TEMEL (Saatli Bomba, E): şarj/yük tabanlı bir yetenek - standart
## skill2_state/bekleme makinesini KULLANMAZ (bkz. _physics_process'teki
## özel input dalı, get_skill2_id() == 17 kontrolü). ULTİ (Patlat, R) ise
## bırakılmış TÜM bombaları anında patlatır ve standart skill_state/bekleme
## makinesini (20sn, bkz. SKILL_TIMING[18]) kullanır. Pasif (öldürmede altın
## şansı) on_enemy_killed() üzerinden tetiklenir (bkz. enemy.gd die()).
## #39 DÜZELTME (kullanıcı bildirimi: "Korsan bomba/ulti düzenlemeleri"):
## bomba şarjı/hasarı genel olarak zayıf kalıyordu - şarj sayısı, yenilenme
## hızı ve hasar belirgin şekilde artırıldı (eski değerler: 2 şarj, 20sn
## yenilenme, 20 sabit + güç*1.5 hasar).
const KorsanBombScene := preload("res://scenes/korsan_bomb.tscn")
const KORSAN_MAX_BOMB_CHARGES := 3
## Kullanıcı isteği: "Korsanın bombasının... bekleme süresini 4 saniye
## kısalt" - eskiden 14.0.
const KORSAN_BOMB_RECHARGE_TIME := 10.0
const KORSAN_BOMB_DAMAGE_FLAT := 32.0
## Kullanıcı isteği: "Korsanın bombasının saldırı gücü oranını %100'e
## sabitle" - eskiden 2.2 (saldırı gücünün %220'si) idi, artık saldırı
## gücünün TAM %100'ü (damage_bonus ile birebir aynı miktar) bombanın
## hasarına ekleniyor.
const KORSAN_BOMB_DAMAGE_POWER_RATIO := 1.0
const KORSAN_PASSIVE_BASE_CHANCE := 0.10
const KORSAN_PASSIVE_CHANCE_PER_LEVEL := 0.01
var korsan_bomb_charges: int = KORSAN_MAX_BOMB_CHARGES
var _korsan_bomb_recharge_timer: float = 0.0
## Bırakılmış, henüz patlatılmamış GERÇEK bomba referansları (bkz.
## korsan_bomb.gd dosya başı notu - kozmetik uzak-oyuncu kopyaları bu
## diziye asla girmez).
var _korsan_bombs: Array = []

## ---------- Necromancer (roster 11, "skill": 20/"skill2": 19) ----------
## Pasif: yakında ölen her düşman ruh kazandırır (bosslar 5, diğerleri 1,
## bkz. on_enemy_killed()). TEMEL (İskelet Çağır, E) 3 ruh karşılığında bir
## iskelet çağırır - bekleme süresi YOK, standart skill2_state makinesini
## KULLANMAZ (bkz. _physics_process, get_skill2_id() == 19 kontrolü), tek
## kısıt ruh sayısı. ULTİ (Golem Çağır, R) 10 ruh karşılığında bir Golem
## çağırır, standart skill_state/bekleme makinesini (10sn, bkz.
## SKILL_TIMING[20]) kullanır.
## DÜZELTME (kullanıcı isteği: "necromancerın ultisi hayalet yerine golem
## çağırsın") - ULTİ artık wraith_pet.gd (Hortlak) yerine golem_pet.gd
## (Golem) çağırıyor (bkz. _skill_necro_summon_golem, NECRO_GOLEM_*
## sabitleri). wraith_pet.gd/wraith_pet.tscn dosyaları hâlâ projede duruyor
## (zararsız, artık hiçbir yerden çağrılmıyor) - silinmedi, ileride referans
## olarak kalabilir.
const SkeletonPetScene := preload("res://scenes/skeleton_pet.tscn")
const GolemPetScene := preload("res://scenes/golem_pet.tscn")
const NECRO_SOUL_PER_KILL := 1
const NECRO_SOUL_PER_BOSS_KILL := 5
## Kullanıcı isteği: "necromancerın iskelet çağırma bedelini 10 yap" /
## "necromancerın goleminin ruh bedelini 100 yap" - eskiden 3/10'du.
const NECRO_SKELETON_SOUL_COST := 10
const NECRO_GOLEM_SOUL_COST := 100
## Kullanıcı isteği: "necromancerın iskelet çağırma skiline 1 saniye bekleme
## süresi ekle" - eskiden TEMEL'in (İskelet Çağır) hiç bekleme süresi yoktu,
## sadece ruh sayısı/yaratık sınırı kısıtlıyordu (bkz. yukarıdaki "Necromancer"
## bloğu yorumu). Standart skill_state makinesi bu yetenek için hâlâ
## KULLANILMIYOR (bkz. _physics_process, get_skill_character_id() == 19 dalı -
## kullanıcı isteğiyle "R si ile Q skillinin yerini değiştir"deki AYNI desenle
## artık E yerine Q'da) - bu yüzden bekleme süresi ayrı bir zamanlayıcı ile
## (bkz. _necro_skeleton_cooldown_timer/
## _process_necro_skeleton_cooldown) Korsan'ın bomba şarj sistemiyle AYNI
## desende uygulanıyor.
const NECRO_SKELETON_COOLDOWN := 1.0
const NECRO_SKELETON_STAT_PERCENT := 0.30
const NECRO_SKELETON_HP_PERCENT := 1.0
const NECRO_SKELETON_LIFESPAN := 60.0
## Kullanıcı isteği: "golem necromancerin statlarının %200üne sahiptir" -
## zırh/saldırı gücü/can hâlâ %200 (kalkan ayrıca golem_pet.gd içinde kendi
## canının bir oranı olarak hesaplanıyor, bkz. GOLEM_SHIELD_HP_RATIO). Yaşam
## süresi eski Hortlak'la AYNI (120sn) - kullanıcı bunun değişmesini istemedi.
const NECRO_GOLEM_STAT_PERCENT := 2.0
const NECRO_GOLEM_HP_PERCENT := 2.0
const NECRO_GOLEM_LIFESPAN := 120.0
## DÜZELTME (kullanıcı bildirimi: "necromancerin golemi aşırı hızlı hareket
## ediyor statlardan aldığı hareket hızı oranını %200 den %70e düşür") -
## hareket hızı artık NECRO_GOLEM_STAT_PERCENT'ten (armor/attack_power hâlâ
## onu kullanıyor) BAĞIMSIZ, kendi ayrı oranıyla ölçekleniyor (bkz.
## golem_pet.gd setup_from_player'ın yeni speed_percent parametresi).
const NECRO_GOLEM_SPEED_PERCENT := 0.70
## Kullanıcı isteği: "Necromancerın goleminin saldırı gücü oranını %50 ile
## sabitle" - saldırı gücü artık NECRO_GOLEM_STAT_PERCENT'ten (armor/can hâlâ
## %200) BAĞIMSIZ, sabit bu orana göre hesaplanıyor (bkz. speed_percent'in
## AYNI şekilde ayrıştırılmasıyla aynı desen - golem_pet.gd setup_from_player
## attack_power_percent parametresi).
const NECRO_GOLEM_ATTACK_POWER_PERCENT := 0.50
## Necromancer'ın pasif-biriktirdiği ruh sayısı - HUD'da pasif ikonunun
## üstünde gösterilir (bkz. characters.gd DEFS[11] passive metni).
var necro_souls: int = 0
## Kullanıcı isteği (1. tur): "necromancerın yaratık spawnlama sınırını 10 ile
## sınırla" - o an hayatta olan iskelet+hortlak sayısını takip eder (bkz.
## _broadcast_necro_pet_spawn/_necro_active_pet_count).
## DÜZELTME (2. tur, kullanıcı isteği #33: "necromancerın yaratıkları
## saldırmadığı için ölmüyor, 10 sınırına takılıyor, işe yaramıyor - sınırı
## 20 yap") - 10 -> 20. Saldırmama sorunu için bkz. skeleton_pet.gd/
## wraith_pet.gd (bu dosyada değil, ayrı script'ler).
var _necro_active_pets: Array = []
const NECRO_MAX_ACTIVE_PETS := 20
## Kullanıcı isteği: "necromancer en fazla 2 golem çağırabilsin" - genel
## NECRO_MAX_ACTIVE_PETS (iskelet+golem toplamı) sınırından AYRI, sadece
## Golem'e özgü ikinci bir sınır (bkz. _necro_active_golem_count/
## _skill_necro_summon_golem/_activate_skill).
var _necro_active_golems: Array = []
const NECRO_MAX_GOLEMS := 2
## Bkz. NECRO_SKELETON_COOLDOWN yorumu - İskelet Çağır'ın 1sn bekleme süresi
## için ayrı zamanlayıcı (Korsan bomba şarjı ile aynı desen).
var _necro_skeleton_cooldown_timer: float = 0.0


## Matthew: owns a following/attacking pet at all times, auto-respawning
## MATTHEW_RESPAWN_DELAY seconds after it dies (whether killed in combat or
## sacrificed for his active - see _skill_shield_dome()).
func _passive_matthew(delta: float) -> void:
	if _matthew_pet_alive:
		return
	_matthew_respawn_timer -= delta
	if _matthew_respawn_timer <= 0.0:
		_spawn_matthew_pet()


func _spawn_matthew_pet() -> void:
	var pet = PetScene.instantiate()
	get_tree().current_scene.add_child(pet)
	pet.global_position = global_position
	pet.add_to_group("player_ally")
	if pet.has_method("setup_from_player"):
		pet.setup_from_player(self)
	pet.connect("died", Callable(self, "_on_matthew_pet_died"))
	_matthew_pet = pet
	_matthew_pet_alive = true
	_spawn_burst(Color(0.4, 0.7, 1.0))
	## DÜZELTME (Matthew'in tilkisi multiplayer'da diğer oyunculara HİÇ
	## görünmüyordu): burası eskiden broadcast_player_vfx.rpc(...,
	## "pet_spawn", ...) çağırıyordu, ama o RPC'nin match bloğunda ARTIK
	## (Necromancer için eklenen ayrı instance_id'li broadcast_pet_spawn/
	## broadcast_pet_despawn sistemine geçilirken) "pet_spawn" diye bir dal
	## kalmamış - yani bu çağrı sessizce hiçbir şey yapmıyordu, tilki diğer
	## istemcilerde asla doğmuyordu. Artık Necromancer'ın yaratıklarıyla AYNI,
	## GERÇEKTEN dinlenen mekanizmayı kullanıyor.
	if NetworkManager.is_multiplayer_active:
		_matthew_pet_instance_id = str(pet.get_instance_id())
		if "network_instance_id" in pet:
			pet.network_instance_id = _matthew_pet_instance_id
		NetworkManager.broadcast_pet_spawn.rpc(multiplayer.get_unique_id(), "res://scenes/player_pet.tscn", _matthew_pet_instance_id)


func _on_matthew_pet_died() -> void:
	_matthew_pet_alive = false
	_matthew_respawn_timer = MATTHEW_RESPAWN_DELAY
	if NetworkManager.is_multiplayer_active and not _matthew_pet_instance_id.is_empty():
		NetworkManager.broadcast_pet_despawn.rpc(multiplayer.get_unique_id(), _matthew_pet_instance_id)
	_matthew_pet_instance_id = ""


## enemy.gd die() içinden ÇAĞRILIR - bir düşman öldüğünde, öldüren oyuncuya
## bildirim (bkz. on_damage_dealt ile AYNI desen, sadece "hasar" yerine
## "öldürme" olayı için). Pasifi olmayan karakterlerde no-op.
func on_enemy_killed(enemy: Node) -> void:
	var is_boss_kill: bool = is_instance_valid(enemy) and enemy.get("is_boss") == true
	_apply_kill_heal_item()
	_distribute_arcane_stack(enemy.global_position if is_instance_valid(enemy) else global_position)
	## DÜZELTME (kullanıcı bildirimi: "Necromancer ölen düşmanlardan ruh
	## toplayamıyor") - kök neden: burada Necromancer id 20'ye (Golem Çağır'ın
	## SKILL id'si) göre dallanıyordu - bu SADECE Golem Q/skill slotundayken
	## doğruydu. "Necromancer in R sini golem çıkarma ile değiştir"
	## isteğiyle Golem R'ye taşınınca (artık Q'da İskelet, id 19) bu case bir
	## daha HİÇ eşleşmedi, ruh kazanımı tamamen durdu. get_skill_character_id()
	## (GameManager.selected_character, Q slotunun id'si) yerine roster
	## id'sine (GameManager.selected_char_id == 11) bakılıyor artık - hangi
	## yetenek hangi tuşta olursa olsun Necromancer'ın ruh kazanımı bundan
	## hiç etkilenmesin diye (bkz. Talon pasifinde daha önce yaşanmış AYNI
	## hata sınıfı).
	if GameManager.selected_char_id == 11:
		_necro_on_kill(is_boss_kill)
	match get_skill_character_id():
		18: _korsan_on_kill()
		## Büyücü Kız pasifi (Kadim Patlama) - bkz. _buyucu_on_kill. Burada
		## (host bizzat öldürdüğünde) gerçek Enemy node'u hâlâ geçerli
		## olduğu için konumu doğrudan ondan okunuyor.
		3: _buyucu_on_kill(enemy.global_position if is_instance_valid(enemy) else global_position)


## DÜZELTME (KRİTİK - multiplayer öldürme pasifleri): enemy.gd die() SADECE
## host'ta çalışır, bu yüzden asıl öldüren bir İSTEMCİYSE (host değilse) bu
## fonksiyon o istemcinin KENDİ Player node'unda, host'tan gelen
## notify_kill_passive RPC'si (bkz. network_manager.gd) üzerinden çağrılır.
## Gerçek Enemy node'una network_manager.gd üzerinden erişilemediği için
## (farklı peer, farklı sahne ağacı bağlamı) sadece is_boss_kill bilgisi
## taşınır - _korsan_on_kill/_necro_on_kill zaten enemy referansından başka
## bir şey kullanmıyordu. Büyücü Kız'ın pasifi ise ölüm KONUMUNA ihtiyaç
## duyduğu için (bkz. _buyucu_on_kill) bu RPC'ye ayrıca death_pos eklendi
## (bkz. network_manager.gd notify_kill_passive/enemy.gd die()).
func on_enemy_killed_remote(is_boss_kill: bool, death_pos: Vector2 = Vector2.ZERO) -> void:
	_apply_kill_heal_item()
	_distribute_arcane_stack(death_pos)
	## bkz. on_enemy_killed() üstündeki AYNI düzeltme notu - roster id'sine
	## göre, artık hangi yetenek Q/E/R'de olursa olsun doğru çalışır.
	if GameManager.selected_char_id == 11:
		_necro_on_kill(is_boss_kill)
	match get_skill_character_id():
		18: _korsan_on_kill()
		3: _buyucu_on_kill(death_pos)


## Vampir Dişi pasifi: karakterden bağımsız, item_kill_heal_amount > 0 ise
## (eşya sahipse) her öldürmede can yeniler. on_enemy_killed/_remote'un HER
## İKİ yolundan da (host'ta bizzat öldürme VE multiplayer'da RPC üzerinden
## bildirilen öldürme) çağrılır ki host olmayan bir oyuncu da pasifini alsın.
func _apply_kill_heal_item() -> void:
	if item_kill_heal_amount > 0.0:
		heal(item_kill_heal_amount)


## Arcane Asası pasifi (bkz. weapon.gd add_arcane_stack üstündeki DÜZELTME
## notu, kullanıcı isteği: "kendi öldürdüğü değil etrafta ölen düşmanlara
## göre stacklensin... 1 ölüm 5 asaya da stack vermemeli yani sadece
## rasgele 1 arcane asasına 1 stack olacak") - _apply_kill_heal_item() ile
## AYNI desen: on_enemy_killed/_remote'un HER İKİ yolundan da çağrılır ki
## host olmayan bir oyuncu da KENDİ silahları üzerinden pasifini alsın.
## Menzili (attack_range) ölüm konumunu kapsayan SAHİP OLUNAN Arcane
## kopyalarından SADECE rastgele BİRİNE 1 stack eklenir.
func _distribute_arcane_stack(death_pos: Vector2) -> void:
	var candidates: Array = []
	for w in owned_weapon_nodes:
		if not is_instance_valid(w) or not ("_is_arcane" in w) or not w._is_arcane:
			continue
		var w_range: float = float(w.attack_range) if "attack_range" in w else 0.0
		if w_range <= 0.0 or w.global_position.distance_to(death_pos) <= w_range:
			candidates.append(w)
	if candidates.is_empty():
		return
	var chosen: Node = candidates[randi() % candidates.size()]
	if chosen.has_method("add_arcane_stack"):
		chosen.add_arcane_stack()


## Korsan pasifi: "Her öldürmede %10 ihtimalle 1 altın kazanırsın. Bu şans
## her level için +%1 artar (en fazla %100)." (bkz. characters.gd DEFS[9]).
func _korsan_on_kill() -> void:
	var chance: float = clamp(KORSAN_PASSIVE_BASE_CHANCE + KORSAN_PASSIVE_CHANCE_PER_LEVEL * float(level - 1), 0.0, 1.0)
	if randf() < chance:
		GameManager.gold += 1
		_spawn_floating_text("+1 Altın", Color(1.0, 0.85, 0.2))


## Korsan'ın bomba şarjlarının zamanla yenilenmesi - _physics_process'ten
## her karede çağrılır, sadece Korsan seçiliyken bir işe yarar (no-op diğer
## karakterlerde). Ölü/geçersiz bomba referansları da burada temizlenir.
func _process_korsan_bombs(delta: float) -> void:
	if get_skill_character_id() != 18:
		return
	_korsan_bombs = _korsan_bombs.filter(func(b): return is_instance_valid(b))
	if korsan_bomb_charges < KORSAN_MAX_BOMB_CHARGES:
		_korsan_bomb_recharge_timer -= delta
		if _korsan_bomb_recharge_timer <= 0.0:
			korsan_bomb_charges += 1
			_korsan_bomb_recharge_timer = KORSAN_BOMB_RECHARGE_TIME if korsan_bomb_charges < KORSAN_MAX_BOMB_CHARGES else 0.0


## Kullanıcı isteği: "yük biriken yeteneği olan karakterlerde (assasin,
## korsan) yetenek birikirken kaç yük olduğunun yanında bir çember/sayaç
## olsun" - bkz. hud.gd/skill_icon.gd set_charge_progress. Şarjlar zaten
## maksimumdaysa 1.0 (● - hazır), aksi halde şu an dolmakta olan TEK şarjın
## oranı (◔/◑/◕ arası).
func get_korsan_bomb_charge_fraction() -> float:
	if korsan_bomb_charges >= KORSAN_MAX_BOMB_CHARGES:
		return 1.0
	if KORSAN_BOMB_RECHARGE_TIME <= 0.0:
		return 1.0
	return clamp(1.0 - (_korsan_bomb_recharge_timer / KORSAN_BOMB_RECHARGE_TIME), 0.0, 1.0)


## Korsan TEMEL (Saatli Bomba, skill2 id 17, E tuşu) - bkz. dosya başındaki
## "Korsan" bloğu üstündeki yorum. _physics_process'te skill2_id == 17 için
## standart _activate_skill2() yerine DOĞRUDAN bu fonksiyon çağrılır.
func _korsan_try_place_bomb() -> void:
	if korsan_bomb_charges <= 0:
		_spawn_floating_text("BOMBA YOK", Color(1.0, 0.4, 0.4))
		return
	korsan_bomb_charges -= 1
	if _korsan_bomb_recharge_timer <= 0.0:
		_korsan_bomb_recharge_timer = KORSAN_BOMB_RECHARGE_TIME
	var bomb: Node2D = KorsanBombScene.instantiate() as Node2D
	get_tree().current_scene.add_child(bomb)
	bomb.global_position = global_position
	if "damage" in bomb:
		bomb.damage = KORSAN_BOMB_DAMAGE_FLAT + damage_bonus * KORSAN_BOMB_DAMAGE_POWER_RATIO
	## Kullanıcı isteği: "Korsanın bombasının patlama alanı menzile göre
	## büyüyebilsin (sadece onun için geçerli)" - bomba SADECE hasar
	## alıyordu (yukarıdaki satır), yarıçapı hep korsan_bomb.gd'deki sabit
	## varsayılanda (150.0) kalıyordu. weapon_range_bonus zaten HER silahın
	## menzilini birebir aynı piksel miktarınca büyüten stat (bkz.
	## "range" kartı/_apply_weapon_bonuses) - bomba da AYNI stat'tan (silah
	## olmadığı için _apply_weapon_bonuses'a girmiyor, o yüzden burada elle)
	## birebir aynı miktarda büyüyor. Diğer hiçbir yetenek menzil statından
	## bu şekilde etkilenmiyor - bilerek SADECE bu bomba için.
	if "radius" in bomb:
		bomb.radius += weapon_range_bonus
	## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir" - bomba
	## kendi kritik zarını atabilsin diye sahibine referans veriliyor (bkz.
	## korsan_bomb.gd detonate/_roll_ability_crit).
	if "owner_player" in bomb:
		bomb.owner_player = self
	_korsan_bombs.append(bomb)
	_spawn_burst(Color(1.0, 0.6, 0.15))
	## DÜZELTME (görünmezlik): önceden _broadcast_skill_scene() kullanılıyordu
	## - o, kozmetik kopyayı atan oyuncunun RemotePlayer'ının ÇOCUĞU yapıp
	## (0,0) yerel konuma sabitliyordu, yani bomba dünyada bırakıldığı yerde
	## değil Korsan'ın üzerinde görünüyor, o hareket edince kayboluyordu
	## ("Korsan'ın bombaları görünmüyor" bildirimi). Artık genel dünya-
	## konumlu/kalıcı/id'li "drop" sistemini (bkz. network_manager.gd
	## broadcast_drop "korsan_bomb" dalı) kullanıyoruz - kozmetik kopya
	## GERÇEK bombanın bırakıldığı yerde sabit duruyor. id, patlatınca
	## (bkz. _skill_korsan_detonate_all) o kopyayı bulup kaldırmak için
	## gerçek bombanın meta'sında saklanıyor.
	if NetworkManager.is_multiplayer_active:
		var bomb_net_id: int = NetworkManager._gen_drop_id()
		bomb.set_meta("korsan_bomb_network_id", bomb_net_id)
		NetworkManager.broadcast_drop.rpc("korsan_bomb", global_position, 0, bomb_net_id)


## Korsan ULTİ (Patlat, skill id 18, R tuşu) - _activate_skill()'in match
## bloğundan çağrılır, standart skill_state/bekleme (20sn) makinesini
## kullanır. Bırakılmış TÜM gerçek bombaları patlatır. Bomba yokken hiç
## tetiklenmeyeceği için (bkz. _activate_skill() başındaki #39 kontrolü)
## aşağıdaki "any_detonated" kontrolü artık salt savunma amaçlı.
func _skill_korsan_detonate_all() -> void:
	var bombs_to_detonate: Array = _korsan_bombs.duplicate()
	_korsan_bombs.clear()
	var any_detonated: bool = false
	for b in bombs_to_detonate:
		if is_instance_valid(b) and b.has_method("detonate"):
			## DÜZELTME: gerçek bomba SADECE bırakan istemcide detonate()
			## ediliyor (patlama efekti de sadece onun ekranına ekleniyor).
			## Diğer katılımcılardaki kozmetik kopya (artık broadcast_drop
			## "korsan_bomb" ile dünya konumunda duruyor - bkz. yukarısı)
			## kendi başına asla patlamaz/kaybolmaz. Konumu detonate()
			## (queue_free çağırır) ÇAĞRILMADAN ÖNCE yakalayıp: (1) diğer
			## isabet efektlerinin kullandığı genel dünya-konumlu VFX
			## yayınıyla ("hitscan_impact") patlama animasyonunu herkesin
			## ekranında da oynatıyoruz, (2) remove_drop ile kozmetik bomba
			## kopyasını da kaldırıyoruz ki sonsuza dek yerde yanıp sönerek
			## kalmasın.
			var bomb_pos: Vector2 = b.global_position
			var bomb_net_id: int = int(b.get_meta("korsan_bomb_network_id", 0))
			b.detonate()
			any_detonated = true
			if NetworkManager.is_multiplayer_active:
				NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "hitscan_impact", bomb_pos, {
					"scene_path": "res://scenes/fx_korsan_explosion.tscn"
				})
				if bomb_net_id > 0:
					NetworkManager.remove_drop.rpc(bomb_net_id)
	if not any_detonated:
		_spawn_floating_text("BOMBA YOK", Color(1.0, 0.4, 0.4))
	_spawn_burst(Color(1.0, 0.5, 0.1))


## Korsan'ın yeni 3. yeteneği (Bombardıman, skill3 id 34, R tuşu) - "etrafındaki
## büyük bir alana 8 saniye boyunca bombardımana alır, her saniye %150
## saldırı gücü kadar hasar verir." Standart skill3_state makinesi (bkz.
## SKILL3_TIMING[34]) sadece süre/bekleme UI'ını (ikon halkası) yönetiyor -
## gerçek 1sn'lik hasar tikleri Büyücü Kız'ın Meteor kanalıyla (bkz.
## _skill_buyucu_meteor/_process_buyucu_meteor) AYNI desende, KENDİ ayrı
## zamanlayıcısıyla yürütülüyor (_process()'te _process_korsan_bombardment
## çağrısı, bkz. dosyanın _physics_process bloğu).
const KORSAN_BOMBARDMENT_RADIUS := 380.0
const KORSAN_BOMBARDMENT_DURATION := 8.0
const KORSAN_BOMBARDMENT_TICK_INTERVAL := 1.0
const KORSAN_BOMBARDMENT_DAMAGE_RATIO := 1.5 ## %150 saldırı gücü

var _korsan_bombardment_active: bool = false
var _korsan_bombardment_channel_timer: float = 0.0
var _korsan_bombardment_tick_timer: float = 0.0


func _skill_korsan_bombardment() -> void:
	_korsan_bombardment_active = true
	_korsan_bombardment_channel_timer = KORSAN_BOMBARDMENT_DURATION
	## İlk hasar tiki hemen değil 1sn sonra düşer (tıpkı meteor kanalı gibi) -
	## ama kanalın kendisi ANINDA görsel olarak belli olsun diye alan
	## yarıçapını gösteren bir halka hemen çiziliyor.
	_korsan_bombardment_tick_timer = KORSAN_BOMBARDMENT_TICK_INTERVAL
	_spawn_ring_sized(KORSAN_BOMBARDMENT_RADIUS, Color(1.0, 0.5, 0.15))
	_spawn_burst(Color(1.0, 0.5, 0.1))


## Kanal boyunca (bkz. yukarısı) her saniye Korsan'ın GÜNCEL konumu
## etrafındaki (hareket edebiliyor, sabit bir orijine kilitli DEĞİL) tüm
## yaratıklara hasar uygular ve bombardıman hissi için birkaç rastgele
## patlama efekti bırakır.
func _process_korsan_bombardment(delta: float) -> void:
	if not _korsan_bombardment_active:
		return
	_korsan_bombardment_channel_timer -= delta
	_korsan_bombardment_tick_timer -= delta
	if _korsan_bombardment_tick_timer <= 0.0:
		_korsan_bombardment_tick_timer += KORSAN_BOMBARDMENT_TICK_INTERVAL
		_apply_korsan_bombardment_tick()
	if _korsan_bombardment_channel_timer <= 0.0:
		_korsan_bombardment_active = false


func _apply_korsan_bombardment_tick() -> void:
	## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir" - tek bir
	## tik, tek bir kritik zarı (Korsan'ın bomba patlamasıyla AYNI desen).
	var is_crit: bool = _roll_ability_crit()
	var dmg: float = _apply_ability_crit(damage_bonus * KORSAN_BOMBARDMENT_DAMAGE_RATIO, is_crit)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if global_position.distance_to(e.global_position) > KORSAN_BOMBARDMENT_RADIUS:
			continue
		if e.has_method("take_damage"):
			e.take_damage(dmg, is_crit)
	## Görsel: bombardıman hissi için alan içinde rastgele 2 patlama - Korsan'ın
	## kendi bomba patlaması FX'iyle AYNI ("hitscan_impact" ile herkese
	## yayınlanır, bkz. _skill_korsan_detonate_all üstündeki AYNI desen).
	for i in range(2):
		var angle: float = randf() * TAU
		var dist: float = randf_range(0.0, KORSAN_BOMBARDMENT_RADIUS)
		var strike_pos: Vector2 = global_position + Vector2(cos(angle), sin(angle)) * dist
		_spawn_korsan_bombardment_strike_fx(strike_pos)


func _spawn_korsan_bombardment_strike_fx(pos: Vector2) -> void:
	if FxKorsanExplosionScene:
		var fx: Node2D = FxKorsanExplosionScene.instantiate() as Node2D
		get_tree().current_scene.add_child(fx)
		fx.global_position = pos
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "hitscan_impact", pos, {
			"scene_path": "res://scenes/fx_korsan_explosion.tscn",
		})


## Necromancer pasifi: "Etrafta ölen her düşman 1 ruh biriktirir (bosslar 5
## ruh)." (bkz. characters.gd DEFS[11]).
func _necro_on_kill(is_boss_kill: bool) -> void:
	var gained: int = NECRO_SOUL_PER_BOSS_KILL if is_boss_kill else NECRO_SOUL_PER_KILL
	necro_souls += gained
	_spawn_floating_text("+%d Ruh" % gained, Color(0.55, 0.95, 0.55))


## Necromancer TEMEL (İskelet Çağır, skill2 id 19, E tuşu) - kullanıcı isteği
## üzerine artık NECRO_SKELETON_COOLDOWN (1sn) bekleme süresi var (bkz.
## _necro_skeleton_cooldown_timer/_process_necro_skeleton_cooldown).
## _physics_process'te skill2_id == 19 için standart _activate_skill2()
## yerine DOĞRUDAN bu fonksiyon çağrılır - standart skill2_state makinesi
## HÂLÂ kullanılmıyor, bekleme süresi kendi ayrı zamanlayıcısıyla kontrol
## ediliyor. Diğer kısıtlar: ruh sayısı ve yaratık sınırı.
func _skill_necro_summon_skeleton() -> void:
	if _necro_skeleton_cooldown_timer > 0.0:
		return
	if necro_souls < NECRO_SKELETON_SOUL_COST:
		_spawn_floating_text("RUH YETERSİZ", Color(0.6, 0.9, 0.5))
		return
	## Kullanıcı isteği: "necromancerın yaratık spawnlama sınırını 10 ile
	## sınırla".
	if _necro_active_pet_count() >= NECRO_MAX_ACTIVE_PETS:
		_spawn_floating_text("YARATIK SINIRI (10)", Color(0.9, 0.6, 0.3))
		return
	necro_souls -= NECRO_SKELETON_SOUL_COST
	_necro_skeleton_cooldown_timer = NECRO_SKELETON_COOLDOWN
	var pet: Node2D = SkeletonPetScene.instantiate() as Node2D
	get_tree().current_scene.add_child(pet)
	pet.global_position = global_position
	if pet.has_method("setup_from_player"):
		pet.setup_from_player(self, NECRO_SKELETON_STAT_PERCENT, NECRO_SKELETON_HP_PERCENT, NECRO_SKELETON_LIFESPAN)
	_register_necro_pet(pet)
	_spawn_burst(Color(0.55, 0.95, 0.55))
	_broadcast_necro_pet_spawn(pet, "res://scenes/skeleton_pet.tscn")


## Bkz. NECRO_SKELETON_COOLDOWN yorumu - Korsan'ın _process_korsan_bombs'u ile
## aynı desen, sadece Necromancer seçiliyken bir işe yarar.
func _process_necro_skeleton_cooldown(delta: float) -> void:
	if _necro_skeleton_cooldown_timer > 0.0:
		_necro_skeleton_cooldown_timer = max(0.0, _necro_skeleton_cooldown_timer - delta)


## Necromancer ULTİ (Golem Çağır, skill id 20, R tuşu) - _activate_skill()
## match bloğundan çağrılır, standart skill_state/bekleme (10sn) makinesini
## kullanır. Ruh yeterliliği _activate_skill() başında zaten kontrol edildi.
## DÜZELTME (kullanıcı isteği: "necromancerın ultisi hayalet yerine golem
## çağırsın") - eskiden WraithPetScene (Hortlak) çağırıyordu, artık
## GolemPetScene (%200 stat/can, kalkanlı, bkz. golem_pet.gd) çağırıyor.
func _skill_necro_summon_golem() -> void:
	necro_souls -= NECRO_GOLEM_SOUL_COST
	var pet: Node2D = GolemPetScene.instantiate() as Node2D
	get_tree().current_scene.add_child(pet)
	pet.global_position = global_position
	if pet.has_method("setup_from_player"):
		pet.setup_from_player(self, NECRO_GOLEM_STAT_PERCENT, NECRO_GOLEM_HP_PERCENT, NECRO_GOLEM_LIFESPAN, NECRO_GOLEM_SPEED_PERCENT, NECRO_GOLEM_ATTACK_POWER_PERCENT)
	_register_necro_pet(pet)
	## bkz. NECRO_MAX_GOLEMS notu - genel pet listesine EK olarak, Golem'e özgü
	## sayaca da ekleniyor.
	_necro_active_golems.append(pet)
	if pet.has_signal("died"):
		pet.died.connect(func() -> void:
			_necro_active_golems.erase(pet)
		, CONNECT_ONE_SHOT)
	_spawn_burst(Color(0.75, 0.5, 1.0))
	_broadcast_necro_pet_spawn(pet, "res://scenes/golem_pet.tscn")


## Necromancer'ın TEMEL yeteneği (Yarasa Sürüsü, skill2 id 35, E tuşu) -
## "Basılıp kapatılabilir. Basıldığında her saniye %1 maks kalkan + 25 kalkan
## tüketerek etrafındaki yaratıklara yarasa gönderir, yarasalar yaratıklara
## vurup Necromancer'a geri döner (yarasaların hızı Necromancer'la eşdeğerdir).
## Yarasalar her yaratığa çarptığında %80 saldırı gücü kadar hasar verir."
## TOGGLE olduğu için standart skill2_state makinesini KULLANMIYOR - Korsan'ın
## bombasıyla AYNI mimari desen (bkz. _physics_process skill2_id_pressed == 35
## dalı). skill2_state SADECE HUD ikonunun "aktif" parlamasını (bkz.
## is_skill2_active) tetiklemek için ödünç kullanılıyor - skill2_timer'a HİÇ
## dokunulmuyor (0'da kalıyor), yani _process_skill2() içindeki standart
## süre/bekleme geçişleri bu karakter için asla çalışmıyor.
## DÜZELTME (kullanıcı isteği: "Necromancer in E sini yarasa sürüsü çağırma
## ile değiştir") - eskiden R/skill3 id 35'ti (bkz. get_skill3_progress()
## karşılığı artık get_skill2_progress()'teki char_id==11 özel dalı), aşağıda
## skill3_state/skill3_timer kullanan tüm satırlar skill2_state/skill2_timer
## olarak güncellendi.
const NECRO_BATS_SHIELD_DRAIN_PERCENT_OF_MAX := 0.01 ## %1 maks kalkan/sn
const NECRO_BATS_SHIELD_DRAIN_FLAT := 25.0 ## +25 kalkan/sn
const NECRO_BATS_DAMAGE_RATIO := 0.8 ## %80 saldırı gücü/isabet
const NECRO_BATS_RADIUS := 260.0 ## "etrafındaki" - yakındaki yaratıklar
const NECRO_BATS_TICK_INTERVAL := 1.0
## Aşırı kalabalık bir sürüde (max_concurrent_enemies=63) her tikte 63 yarasa
## fırlatmasın diye - bir tikte en fazla bu kadar yaratık hedeflenir.
const NECRO_BATS_MAX_TARGETS_PER_TICK := 6
const NecroBatScene := preload("res://scenes/necro_bat.tscn")

var _necro_bats_active: bool = false
var _necro_bats_tick_timer: float = 0.0


func _necro_toggle_bats() -> void:
	if _necro_bats_active:
		_necro_bats_active = false
		skill2_state = "ready"
		return
	if item_shield_hp <= 0.0:
		_spawn_floating_text("KALKAN YOK", Color(0.4, 0.7, 1.0))
		return
	_necro_bats_active = true
	_necro_bats_tick_timer = 0.0 ## ilk tik hemen bu karede düşsün
	skill2_state = "active" ## SADECE HUD ikonu için - bkz. yukarıdaki dosya başı notu
	_spawn_ring_sized(NECRO_BATS_RADIUS, Color(0.55, 0.15, 0.65))


## Her saniye: kalkanı tüket (biterse yetenek kendiliğinden kapanır),
## menzildeki yaratıklara birer yarasa gönder. Oyuncu ölür/düşerse (bkz.
## is_dead/is_downed) güvenlik amacıyla otomatik kapanır - aksi halde cansız
## bir bedenden sonsuza kadar kalkan tüketmeye devam ederdi.
func _process_necro_bats(delta: float) -> void:
	if not _necro_bats_active:
		return
	if is_dead or is_downed:
		_necro_bats_active = false
		skill2_state = "ready"
		return
	_necro_bats_tick_timer -= delta
	if _necro_bats_tick_timer > 0.0:
		return
	_necro_bats_tick_timer += NECRO_BATS_TICK_INTERVAL
	var drain: float = item_shield_max * NECRO_BATS_SHIELD_DRAIN_PERCENT_OF_MAX + NECRO_BATS_SHIELD_DRAIN_FLAT
	_spend_ability_shield_cost(drain)
	if item_shield_hp <= 0.0:
		_necro_bats_active = false
		skill2_state = "ready"
		_spawn_floating_text("KALKAN BİTTİ", Color(0.4, 0.7, 1.0))
		return
	_launch_necro_bats()


## Menzildeki yaratıklardan en fazla NECRO_BATS_MAX_TARGETS_PER_TICK tanesine
## (en yakınlardan başlayarak) birer yarasa gönderir - bkz. necro_bat.gd.
## Yarasalar SADECE bu (döken) istemcide var olur ve hasar verir, Korsan'ın
## bombalarıyla AYNI mimari (bkz. necro_bat.gd dosya başı notu).
func _launch_necro_bats() -> void:
	var candidates: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d <= NECRO_BATS_RADIUS:
			candidates.append([d, e])
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a, b): return a[0] < b[0])
	## Yarasaların hızı Necromancer'ın KENDİ o anki hareket hızıyla eşdeğer -
	## bkz. _physics_process'teki AYNI formül (velocity = ... * speed * ...).
	var bat_speed: float = speed * skill_speed_multiplier * skill2_speed_multiplier * shield_mode_speed_mult \
			* (1.0 + item_speed_percent + speed_card_percent + _current_temp_speed_boost())
	for i in range(min(candidates.size(), NECRO_BATS_MAX_TARGETS_PER_TICK)):
		var target: Node2D = candidates[i][1]
		var bat: Node2D = NecroBatScene.instantiate() as Node2D
		get_tree().current_scene.add_child(bat)
		bat.global_position = global_position
		bat.target = target
		bat.caster = self
		bat.speed = max(bat_speed, 40.0) ## oyuncu tamamen durursa bile yarasalar hareketsiz kalmasın
		var is_crit: bool = _roll_ability_crit()
		bat.damage = _apply_ability_crit(damage_bonus * NECRO_BATS_DAMAGE_RATIO, is_crit)
		bat.is_crit = is_crit


## Kullanıcı isteği: "necromancerın yaratık spawnlama sınırını 10 ile
## sınırla" - geçersiz (ölmüş/silinmiş) referansları temizleyip o an
## hayatta olan iskelet+hortlak sayısını döner.
func _necro_active_pet_count() -> int:
	_necro_active_pets = _necro_active_pets.filter(func(p): return is_instance_valid(p))
	return _necro_active_pets.size()


## bkz. NECRO_MAX_GOLEMS notu - sadece Golem'leri sayar, iskeletleri saymaz.
func _necro_active_golem_count() -> int:
	_necro_active_golems = _necro_active_golems.filter(func(p): return is_instance_valid(p))
	return _necro_active_golems.size()


func _register_necro_pet(pet: Node2D) -> void:
	_necro_active_pets.append(pet)
	## bkz. buy_weapon_copy'deki AYNI koruma - normalde ev içindeyken yetenek
	## kullanılamıyor ama bu güvenlik payı, bir şekilde çağrılırsa yaratığın
	## ev içinde görünüp dolaşmasını engelliyor (bkz. house_interior.gd
	## _set_combat_visuals_hidden).
	if is_indoors:
		pet.visible = false
		pet.process_mode = Node.PROCESS_MODE_DISABLED
	if pet.has_signal("died"):
		pet.died.connect(func() -> void:
			_necro_active_pets.erase(pet)
		, CONNECT_ONE_SHOT)


## Necromancer aynı anda BİRDEN FAZLA yaratık (iskelet/hortlak) çağırabildiği
## için Matthew'in tekli "pet_spawn" mekanizması yetersiz - bkz.
## network_manager.gd broadcast_pet_spawn/broadcast_pet_despawn (instance_id
## ile birden fazla kopyayı ayrı ayrı takip eder).
func _broadcast_necro_pet_spawn(pet: Node2D, scene_path: String) -> void:
	if not NetworkManager.is_multiplayer_active:
		return
	var instance_id: String = str(pet.get_instance_id())
	## DÜZELTME (kullanıcı bildirimi: "necromancerin yaratıklarını ufacık ve
	## çok hızlı hareket ederken görüyorlar"): GERÇEK yaratık artık bu id ile
	## kendi konumunu periyodik olarak yayınlıyor (bkz. skeleton_pet.gd/
	## wraith_pet.gd _broadcast_network_state) - diğer istemcilerdeki kozmetik
	## kopya (remote_player.gd _pet_visuals[instance_id]) artık kendi başına
	## dolaşmak yerine BUNU takip ediyor.
	if "network_instance_id" in pet:
		pet.network_instance_id = instance_id
	NetworkManager.broadcast_pet_spawn.rpc(multiplayer.get_unique_id(), scene_path, instance_id)
	if pet.has_signal("died"):
		pet.died.connect(func() -> void:
			if NetworkManager.is_multiplayer_active:
				NetworkManager.broadcast_pet_despawn.rpc(multiplayer.get_unique_id(), instance_id)
		)


## ---------- Shaman (roster 12, "skill": 26/"skill2": 27/"skill3": 28) ----------
## 3 totem yeteneği - bkz. characters.gd DEFS[12] ve scripts/totem_base.gd
## dosya başı notu. Her totem cast edildiği konumda sabit kalan, golem_pet.gd
## ile AYNI reliable spawn/despawn RPC'sini (_broadcast_necro_pet_spawn,
## adı "necro" ama TAMAMEN genel - Necromancer'a özgü hiçbir şey içermiyor,
## bu yüzden burada da doğrudan yeniden kullanılıyor) paylaşan bağımsız bir
## Node2D. Üç totem AYNI ANDA sahada olabilir (3 bağımsız 60sn bekleme).
const TotemShieldScene := preload("res://scenes/totem_shield.tscn")
const TotemAttackScene := preload("res://scenes/totem_attack.tscn")
const TotemAreaScene := preload("res://scenes/totem_area.tscn")

## Cast (yetenek atma) parlaması - piksel-art, yetenek başına renk SAHNEYE
## GÖMÜLÜ (modulate) tutuluyor: ağ yayını (broadcast_player_vfx "skill_scene")
## yalnızca sahne YOLUNU taşır, renk parametresi taşımaz - renk kodda
## verilseydi diğer oyuncularda renksiz/beyaz görünürdü.
const ShamanCastShieldScene := preload("res://scenes/fx_shaman_cast_shield.tscn")
const ShamanCastAttackScene := preload("res://scenes/fx_shaman_cast_attack.tscn")
const ShamanCastAreaScene := preload("res://scenes/fx_shaman_cast_area.tscn")


func _spawn_shaman_totem(scene: PackedScene, scene_path: String, skill_slot: int) -> void:
	if not scene:
		return
	var totem: Node2D = scene.instantiate() as Node2D
	get_tree().current_scene.add_child(totem)
	if totem.has_method("setup_from_player"):
		totem.setup_from_player(self)
	_broadcast_necro_pet_spawn(totem, scene_path)
	## BUG DÜZELTMESİ (kullanıcı bildirimi: "totemler yok olduktan sonra
	## hemen bekleme süresine girmiyor 3-4 saniye daha aktif görünüyor skill
	## barlarında") - kök neden: totemin GERÇEK ömrü (bkz. totem_base.gd
	## duration/SceneTreeTimer) ile HUD'daki skill_timer/skill2_timer/
	## skill3_timer BİRBİRİNDEN TAMAMEN BAĞIMSIZ iki ayrı saat; biri (ör.
	## oyuncu downed olduğunda - bkz. _physics_process'teki is_downed erken
	## dönüşü, _process_skill*'lar hiç çağrılmaz) donsa bile diğeri (totemin
	## kendi SceneTreeTimer'ı) akmaya devam ediyor, bu yüzden HUD totem
	## GERÇEKTEN yok olduktan SONRA bile bir süre "aktif" görünmeye devam
	## edebiliyordu. Artık totem GERÇEKTEN öldüğünde (bkz. totem_base.gd
	## _on_expire -> died sinyali), ilgili yetenek hâlâ "active" durumundaysa
	## hemen cooldown'a geçiriliyor - iki saat böylece senkron kalıyor.
	if totem.has_signal("died"):
		totem.died.connect(_enter_shaman_totem_cooldown.bind(skill_slot))


## bkz. _spawn_shaman_totem üstündeki BUG DÜZELTMESİ notu. skill_slot: 1 =
## Kalkan Totemi (ulti/"skill"), 2 = Saldırı Totemi ("skill2"), 3 = Alan
## Totemi ("skill3") - _process_skill/_process_skill2/_process_skill3'ün
## normal "active -> cooldown" geçişiyle BİREBİR AYNI adımlar.
## DÜZELTME (kullanıcı isteği: "totem bıraktığında yetenek aktifmiş gibi
## görünmesin, karakterden bağımsız oldukları için gerek yok, skiller direk
## bekleme süresine girsin attığında") - eskiden SADECE totem erken ölünce
## (died sinyali) çağrılıyordu. Artık ÜÇ totem yeteneğinin kendisinden
## (_skill_shaman_*_totem) de, totem atıldığı ANDA senkron olarak
## çağrılıyor - "active" durumu hiçbir karede HUD'a hiç yansımadan doğrudan
## cooldown'a geçiliyor. Totem GERÇEKTEN ölünce (died sinyali) bu fonksiyon
## TEKRAR çağrılır ama o noktada skill*_state zaten "cooldown" olduğu için
## "if skill_state == 'active'" korumaları sayesinde no-op olur - iki farklı
## TETİKLEYİCİden (atış anı + erken ölüm) çağrılsa da fonksiyonun kendisi
## hep aynı şeyi yapar: "bu totem slotu artık aktif değilse cooldown'a geçir".
func _enter_shaman_totem_cooldown(skill_slot: int) -> void:
	match skill_slot:
		1:
			if skill_state == "active":
				_end_skill_effects()
				skill_state = "cooldown"
				skill_timer = _skill_cooldown
		2:
			if skill2_state == "active":
				_end_skill2_effects()
				skill2_state = "cooldown"
				skill2_timer = _skill2_cooldown
		3:
			if skill3_state == "active":
				_end_skill3_effects()
				skill3_state = "cooldown"
				skill3_timer = _skill3_cooldown


func _skill_shaman_shield_totem() -> void:
	_spawn_shaman_totem(TotemShieldScene, "res://scenes/totem_shield.tscn", 1)
	## Pixel-art cast parlaması (eski jenerik renkli CPUParticles2D yerine) -
	## _play_and_broadcast_skill_fx hem kendi ekranında oynatır hem diğer
	## oyunculara aynı sahneyi yayınlar (bkz. o fonksiyonun üstündeki not).
	_play_and_broadcast_skill_fx(ShamanCastShieldScene)
	## kullanıcı isteği: totem yerleştirme yetenekleri "active" fazından hiç
	## geçmesin, atıldığı anda doğrudan cooldown'a girsin (bkz.
	## _enter_shaman_totem_cooldown üstündeki not).
	_enter_shaman_totem_cooldown(1)


func _skill_shaman_attack_totem() -> void:
	_spawn_shaman_totem(TotemAttackScene, "res://scenes/totem_attack.tscn", 2)
	_play_and_broadcast_skill_fx(ShamanCastAttackScene)
	_enter_shaman_totem_cooldown(2)


func _skill_shaman_area_totem() -> void:
	_spawn_shaman_totem(TotemAreaScene, "res://scenes/totem_area.tscn", 3)
	_play_and_broadcast_skill_fx(ShamanCastAreaScene)
	_enter_shaman_totem_cooldown(3)


## Kullanıcı isteği: pet ölümsüz olduğu için artık can/kalkan barına gerek
## yok - _attach_pet_bar() (eskiden overhead_bar.gd'yi pet'e takıyordu)
## tamamen kaldırıldı.


## Finds the nearest node in "player_ally" within max_range - used by Oakley's
## active to also hit whatever ally is closest (e.g. Matthew's pet, if that
## ever ends up being relevant across characters).
func _nearest_ally_in_range(max_range: float) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = max_range
	for ally in get_tree().get_nodes_in_group("player_ally"):
		if not is_instance_valid(ally):
			continue
		var d: float = global_position.distance_to(ally.global_position)
		if d <= nearest_dist:
			nearest_dist = d
			nearest = ally
	return nearest


## Oakley'nin Q/E yeteneklerinin hedef seçimi (kullanıcı isteği: "en düşük
## cana sahip müttefiği") - menzildeki müttefikler arasında can ORANI
## (health/max_health) EN DÜŞÜK olanı döner, hiçbiri menzilde değilse null.
func _lowest_health_ally_in_range(max_range: float) -> Node2D:
	var best: Node2D = null
	var best_ratio: float = 1.0
	for ally in get_tree().get_nodes_in_group("player_ally"):
		if not is_instance_valid(ally) or not ("max_health" in ally) or not ("health" in ally):
			continue
		if ally.get("max_health") <= 0.0:
			continue
		if global_position.distance_to(ally.global_position) > max_range:
			continue
		var ratio: float = float(ally.get("health")) / float(ally.get("max_health"))
		if best == null or ratio < best_ratio:
			best = ally
			best_ratio = ratio
	return best


## DÜZELTME (kullanıcı isteği #25: "Melek'in kalkan skili kalkanı en az olan
## dosta basmalı") - _skill_kalkan_yenileme() ESKİDEN yanlışlıkla
## _lowest_health_ally_in_range() kullanıyordu (can bazlı seçim), yani kalkan
## yenileme yeteneği aslında en düşük CANLI müttefiği hedefliyordu, kalkanı
## en az olanı değil. Bu, _lowest_health_ally_in_range() ile BİREBİR aynı
## mantık ama can yerine kalkan oranını (item_shield_hp/item_shield_max)
## kullanır. Maksimum kalkanı olmayan (henüz kalkan türü almamış) müttefikler
## hedef dışı bırakılır - onlara "kalkan yenilemek" anlamsız.
func _lowest_shield_ally_in_range(max_range: float) -> Node2D:
	var best: Node2D = null
	var best_ratio: float = 1.0
	for ally in get_tree().get_nodes_in_group("player_ally"):
		if not is_instance_valid(ally) or not ("item_shield_max" in ally) or not ("item_shield_hp" in ally):
			continue
		if ally.get("item_shield_max") <= 0.0:
			continue
		if global_position.distance_to(ally.global_position) > max_range:
			continue
		var ratio: float = float(ally.get("item_shield_hp")) / float(ally.get("item_shield_max"))
		if best == null or ratio < best_ratio:
			best = ally
			best_ratio = ratio
	return best


## Sahip olunan kalkan türünün anahtarını döner - kullanıcı isteğiyle
## ("sadece 1 kalkan alınabilmeli") aynı anda seviyesi >0 olan EN FAZLA
## bir tür olabilir (bkz. shop_panel.gd _on_buy_upgrade - başka bir tür
## satın alınmadan önce mevcut olan satılmak ZORUNDA). Bu yüzden artık ayrı
## bir "aktif tür" seçimi yok - hangi tür seviyeli/sahipse otomatik olarak o
## kullanılıyor, hiçbiri sahip değilse "" döner.
func _owned_shield_type_key() -> String:
	for key in SHIELD_TYPES:
		if int(GameManager.get(key + "_level")) > 0:
			return key
	return ""


## Sahip olunan kalkan türünün SHIELD_TYPES verisi - hiçbir tür sahip
## değilse boş dictionary döner.
func _active_shield_type_data() -> Dictionary:
	return SHIELD_TYPES.get(_owned_shield_type_key(), {})


## Sahip olunan türün GameManager'daki KENDİ seviyesi (ör. shield_kale_level)
## - hiçbir tür sahip değilse 0 döner, "kalkan yok" anlamına gelir (eskiden
## shield_level <= 0 ile aynı).
func _active_shield_level() -> int:
	var type_key: String = _owned_shield_type_key()
	if type_key == "":
		return 0
	return int(GameManager.get(type_key + "_level"))


func _active_shield_regen_rate() -> float:
	var t: Dictionary = _active_shield_type_data()
	var level: int = _active_shield_level()
	if t.is_empty() or level <= 0:
		return 0.0
	return float(t["regen"]) + (level - 1) * float(t["regen_per_level"])


## Kalkan hasar aldıktan sonra yenilenmenin duracağı süre - taban SHIELD_
## REGEN_DELAY_FLOOR'un (1.5sn) altına asla inmez. Savaş Kalkanı (always_
## regen=true) savaş sırasında da yenilendiği için hiç bekleme uygulamaz,
## her zaman 0.0 döner (bkz. _process_item_shield - 0, ">"0 kontrolünü hiç
## tetiklemez, yenilenme asla durmaz).
func _shield_hit_regen_delay() -> float:
	var t: Dictionary = _active_shield_type_data()
	var level: int = _active_shield_level()
	if t.is_empty() or level <= 0 or t.get("always_regen", false):
		return 0.0
	var base_delay: float = float(t["delay"])
	var per_level: float = float(t["delay_per_level"])
	## Kalkan Yüzüğü: -0.1sn bekleme süresi (bkz. item_shield_delay_reduction).
	return max(SHIELD_REGEN_DELAY_FLOOR, base_delay + (level - 1) * per_level - item_shield_delay_reduction)


## Kartlardan (level_up_screen "shield_protection" perk'i) gelen birikimi
## (shield_protection_bonus) sahip olunan türün taban emilimiyle toplayıp
## gerçekte kullanılan shield_protection'ı üretir - kalkan satın alınınca/
## satılınca (bkz. refresh_shield_stats) ya da yeni bir perk alınınca
## yeniden çağrılır.
func _recompute_shield_protection() -> void:
	var t: Dictionary = _active_shield_type_data()
	var base_absorption: float = float(t.get("absorption", 0.0))
	shield_protection = clamp(base_absorption + shield_protection_bonus, 0.0, SHIELD_PROTECTION_CAP)


## Dükkandan bir kalkan türü satın alındığında/geliştirildiğinde YA DA
## satıldığında (bkz. shop_panel.gd _on_buy_upgrade/_on_sell_shield) çağrılır
## - hangi türün sahip olunduğunu (_owned_shield_type_key) otomatik bulup
## gücünü/HP'sini yeniden hesaplar.
func refresh_shield_stats() -> void:
	var level: int = _active_shield_level()
	var t: Dictionary = _active_shield_type_data()
	_recompute_shield_protection()
	if level <= 0 or t.is_empty():
		item_shield_max = 0.0
		item_shield_hp = 0.0
		item_shield_changed.emit(0.0, 0.0)
		return
	var new_max: float = (float(t["power"]) + (level - 1) * float(t["power_per_level"]) + item_shield_power_flat) * shield_mode_max_mult * (1.0 + shield_max_percent)
	if item_shield_max <= 0:
		## Kalkan İLK KEZ satın alınıyor - kullanıcı isteğiyle anında dolu
		## başlamıyor, 0'dan başlayıp kendi kendine yenileniyor (bkz.
		## _process_item_shield).
		item_shield_hp = 0.0
	else:
		## Zaten sahip olunan türün SEVİYESİ arttırıldı (kalkan hâlâ aynı
		## tür) - mevcut HP, maksimumdaki artış kadar orantılı yükseliyor,
		## eskisi gibi.
		item_shield_hp += (new_max - item_shield_max)
	item_shield_hp = clamp(item_shield_hp, 0.0, new_max)
	item_shield_max = new_max
	item_shield_changed.emit(item_shield_hp, item_shield_max)


## Called once at startup and every time the player picks a new shield mode
## (see set_active_shield_mode) - recomputes the plain modifiers from
## whichever mode is active, then re-derives shield_max (Metanet Modu changes
## it) so everything stays in sync immediately.
func set_active_shield_mode(mode: String) -> void:
	if mode != "" and GameManager.get("shield_mod_" + mode + "_level") <= 0:
		return ## not bought yet, ignore
	GameManager.active_shield_mode = mode
	_apply_shield_mode()


## Called by ShopPanel after leveling up a mod, so an already-active mode
## immediately feels the stronger numbers without needing to be re-toggled.
func refresh_mod_level(key: String) -> void:
	var mode: String = key.replace("shield_mod_", "")
	if GameManager.active_shield_mode == mode:
		_apply_shield_mode()


## Straight-line interpolation from the mod's level-1 strength to its
## (artık) level-100 strength - shared by every mode below so leveling a mod
## always makes its own bonus (and only its own bonus) meaningfully stronger.
## DÜZELTME (100-level rebalance): eski cap 10'du (at_level_10 ismi kalıyor,
## artık gerçekte "level 100'deki güç" anlamına geliyor) - interpolasyon
## payı 9'dan 99'a çekildi, UÇ NOKTALAR (level 1 ve level 100'deki güç)
## birebir aynı, aradaki her seviye eskisinden çok daha ufak bir artış verir.
## DÜZELTME (kullanıcı isteği: "Oyundaki geliştirilebilen tüm itemlerin
## levele göre gelişme hızını %100 arttır") - taban (level 1) değer
## DEĞİŞMEDİ, ama tepe (level 100) değere olan mesafe iki katına çıkarıldı -
## kalkan modlarının 7'sinin de (resilience/thorny/turtle/aggressive/
## lightning/piercing/tank) TEK paylaşılan büyüme fonksiyonu bu olduğu için
## her birini ayrı ayrı değiştirmeye gerek yok.
func _mod_lerp(level: int, at_level_1: float, at_level_10: float) -> float:
	## DÜZELTME (100->20 level rebalance): bkz. _tier_from_level10 üstündeki
	## AYNI düzeltme notu - uç noktalar (level 1/level 20) aynı kalsın diye
	## payda 99'dan 19'a çekildi.
	var t: float = clamp(level - 1, 0, 19) / 19.0
	var doubled_at_level_10: float = at_level_1 + (at_level_10 - at_level_1) * 2.0
	return lerp(at_level_1, doubled_at_level_10, t)


func _apply_shield_mode() -> void:
	## Önceki modun uyguladığı maksimum can cezasını geri al (varsa)
	## - böylece mod değiştikçe ceza katlanmaz.
	if _last_applied_health_tax != 1.0:
		max_health = max_health / _last_applied_health_tax
		_last_applied_health_tax = 1.0
	shield_mode_max_mult = 1.0
	shield_mode_regen_mult = 1.0
	shield_mode_combat_regen_factor = 0.0
	shield_mode_thorny_intake_bonus = 0.0
	shield_mode_thorny_reflect_percent = 0.0
	shield_mode_protection_bonus = 0.0
	shield_mode_speed_mult = 1.0
	aggressive_max_damage_bonus = 0.6
	shield_mode_shield_pen_bonus = 0.0
	shield_mode_dodge_bonus = 0.0
	shield_mode_damage_mult = 1.0

	var mode: String = GameManager.active_shield_mode
	var level: int = 0
	if mode != "":
		level = GameManager.get("shield_mod_" + mode + "_level")
		if level <= 0:
			mode = ""
			GameManager.active_shield_mode = ""

	match mode:
		"resilience":
			shield_mode_regen_mult = _mod_lerp(level, 1.8, 3.0)
			## Savaştayken kalkan yenileme eşiği seviye 1'de %1, seviye başına
			## %0.25 artıyor (seviye 10'da %1 + 9*%0.25 = %3.25) - maksimum
			## kalkanın bu yüzdesi kadarı saniyede sızıntı şeklinde yenilenir.
			shield_mode_combat_regen_factor = _mod_lerp(level, 0.01, 0.0325)
			## Kullanıcı isteği: kalkan azaltma cezası yerine maksimum CAN'ı
			## %30 azalt (yani maksimumun %70'i kalır). Kalkana dokunulmaz.
			shield_mode_max_mult = 1.0
			_last_applied_health_tax = 0.7
			max_health = max_health * 0.7
		"thorny":
			shield_mode_thorny_intake_bonus = _mod_lerp(level, 0.2, 0.5)
			shield_mode_thorny_reflect_percent = _mod_lerp(level, 0.35, 0.7)
		"turtle":
			shield_mode_protection_bonus = _mod_lerp(level, 0.2, 0.45)
			shield_mode_speed_mult = 0.82
		"aggressive":
			aggressive_max_damage_bonus = _mod_lerp(level, 0.6, 1.4)
		"lightning":
			# Şimşek Hız Modu: faster + a flat dodge chance, at the cost of a
			# shield that burns down fast (see MODE_DRAIN_RATE).
			shield_mode_speed_mult = 1.0 + _mod_lerp(level, 0.15, 0.35)
			shield_mode_dodge_bonus = 0.10
		"piercing":
			# Delicilik Modu: chews through enemy shields - shield_mode_shield_
			# pen_bonus ignores a fraction of an enemy's own shield_protection
			# (see enemy.gd's take_damage) - a small steady shield cost in
			# exchange. DÜZELTME (zırh kaldırıldı): eskiden AYRICA enemy
			# armor'u da (shield_mode_armor_pen_bonus) deliyordu, o kısım
			# armorla birlikte kaldırıldı.
			shield_mode_shield_pen_bonus = _mod_lerp(level, 0.25, 0.6)
		"tank":
			# Tank Modu: a much bigger shield pool, at the cost of dealing less
			# damage and moving slower - the penalties stay fixed regardless of
			# level, only the shield bonus grows.
			shield_mode_max_mult = 1.0 + _mod_lerp(level, 0.35, 0.80)
			shield_mode_damage_mult = 0.75
			shield_mode_speed_mult = 0.95

	## Mod değiştiğinde maksimum can değişmiş olabilir (Meditasyon'un %30
	## cezası), bu yüzden mevcut canı yeni tavanla sınırlayıp HUD'a bildir.
	health = clamp(health, 0.0, max_health)
	health_changed.emit(health, max_health)
	refresh_shield_stats()


func _process_regen(delta: float) -> void:
	var total_regen: float = heal_regen_bonus + heal_regen_card_bonus
	## Vitamin pasifi: hasar aldıktan sonraki 5sn boyunca fazladan regen
	## (bkz. take_damage() - item_vitamin_regen_timer'ı 5.0'a set eder).
	if item_vitamin_regen_timer > 0.0:
		total_regen += item_vitamin_regen_bonus
	if total_regen > 0 and health < max_health:
		## Gerçek artış anlık değil, aşağıdaki tik döngüsüyle uygulanıyor -
		## bkz. _health_regen_tick_pending sınıf üstü yorumu.
		_health_regen_tick_pending += total_regen * delta

	_health_regen_tick_timer += delta
	if _health_regen_tick_timer < HEALTH_REGEN_TICK_INTERVAL:
		return
	_health_regen_tick_timer = 0.0
	if _health_regen_tick_pending <= 0.0:
		return
	var healed: float = min(_health_regen_tick_pending, max_health - health)
	_health_regen_tick_pending = 0.0
	if healed > 0.0:
		health += healed
		health_changed.emit(health, max_health)
		regen_display_accum += healed
		if regen_display_accum >= 1.0:
			var shown := int(regen_display_accum)
			_spawn_floating_text("%d" % shown, Color(0.4, 0.9, 0.45))
			regen_display_accum -= shown


func _process_skill(delta: float) -> void:
	if skill_state != "ready":
		skill_total_elapsed += delta
	if skill_timer <= 0:
		return
	skill_timer -= delta
	if skill_timer > 0:
		return
	if skill_state == "active":
		_end_skill_effects()
		skill_state = "cooldown"
		## Bekleme süresi artık yeteneğin AKTİF olma süresiyle ÇAKIŞMIYOR -
		## süre bitip yetenek etkisi sona erdiğinde bekleme süresi baştan
		## (tam _skill_cooldown kadar) başlıyor, eskiden olduğu gibi
		## (_skill_cooldown - _skill_duration) değil (bkz. kullanıcı isteği:
		## "yeteneklerin bekleme süresi yeteneğin aktif olma süresi bitince
		## aktifleşecek" - tüm karakterler için geçerli).
		skill_timer = _skill_cooldown
	elif skill_state == "cooldown":
		skill_state = "ready"
		skill_timer = 0.0
		skill_total_elapsed = _skill_duration + _skill_cooldown


func get_skill_progress() -> float:
	if skill_state == "ready":
		return 1.0
	## Payda artık sadece _skill_cooldown değil, tam döngü süresi (aktif +
	## bekleme) - yoksa ilerleme çubuğu bekleme süresi bitmeden "hazır"
	## gösterirdi (bkz. yukarıdaki bekleme süresi değişikliği).
	return clamp(skill_total_elapsed / (_skill_duration + _skill_cooldown), 0.0, 1.0)


func is_skill_active() -> bool:
	return skill_state == "active"


## HUD'daki yetenek ikonunun "aktiflik çerçevesi"nin kenarlarını kalan
## aktif süreye göre daraltmak için (bkz. skill_icon.gd) - 1.0 = yetenek
## yeni aktifleşti (tam süre kaldı), 0.0'a doğru azalır. Aktif değilken
## (bekleme/hazır) 0.0 döner - o durumda çerçeve zaten çizilmiyor.
func get_skill_active_fraction() -> float:
	if skill_state != "active" or _skill_duration <= 0.0:
		return 0.0
	return clamp(skill_timer / _skill_duration, 0.0, 1.0)


## HUD'daki pasif ikonunun üstünde biriken ruh sayısını göstermek için (bkz.
## skill_icon.gd set_stack_count, hud.gd _process). Diğer karakterlerde 0
## döner (zararsız - HUD zaten sadece Necromancer seçiliyken bu değeri okur).
func get_necro_souls() -> int:
	return necro_souls


func get_skill_character_id() -> int:
	if "selected_character" in GameManager:
		return GameManager.selected_character
	return 1


## İkinci (temel) yetenek - ana skill_state makinesinin birebir aynısı,
## sadece ayrı değişkenler/süreler üzerinde çalışıyor (bkz. SKILL2_TIMING).
func _process_skill2(delta: float) -> void:
	if skill2_state != "ready":
		skill2_total_elapsed += delta
	if skill2_timer <= 0:
		return
	skill2_timer -= delta
	if skill2_timer > 0:
		return
	if skill2_state == "active":
		_end_skill2_effects()
		skill2_state = "cooldown"
		## bkz. _process_skill()'deki aynı değişiklik notu - bekleme süresi
		## artık aktif süreyle çakışmıyor, aktif süre bitince baştan başlıyor.
		skill2_timer = _skill2_cooldown
	elif skill2_state == "cooldown":
		skill2_state = "ready"
		skill2_timer = 0.0
		skill2_total_elapsed = _skill2_duration + _skill2_cooldown


## DÜZELTME (Büyücü Kız'ın 4 varyasyonlu TEMEL'i): standart skill2_state
## makinesini KULLANMIYOR (bkz. _buyucu_try_activate_variation), bu yüzden
## HUD ilerleme halkası burada o anki varyasyonun KENDİ bekleme sayacından
## (_buyucu_variation_cooldowns) hesaplanıyor.
func get_skill2_progress() -> float:
	if GameManager.selected_char_id == 4:
		var cd: float = float(_skill2_timing_for(get_skill2_id()).get("cooldown", DEFAULT_SKILL2_COOLDOWN))
		if cd <= 0.0:
			return 1.0
		return clamp(1.0 - (_buyucu_variation_cooldowns[buyucu_variation] / cd), 0.0, 1.0)
	## DÜZELTME (kullanıcı isteği: "Necromancer in E sini yarasa sürüsü
	## çağırma ile değiştir") - Necromancer'ın Yarasa Sürüsü (bkz.
	## _necro_toggle_bats) bir TOGGLE - gerçek bekleme süresi yok (sadece
	## kalkan yeterliliği kısıtlar), her zaman "hazır" sayılır. Bunun ÖZEL
	## DALI olmasa skill2_total_elapsed (bkz. _process_skill2, skill2_state
	## != "ready" iken sınırsız birikiyor) yüzünden yanıltıcı bir "dolan
	## bekleme" göstergesi oluşurdu - eskiden bu dal get_skill3_progress()'te
	## R/skill3 için vardı (Yarasa Sürüsü orada iken), artık burada.
	if GameManager.selected_char_id == 11:
		return 1.0
	if get_skill2_id() == 0:
		return 1.0
	if skill2_state == "ready":
		return 1.0
	return clamp(skill2_total_elapsed / (_skill2_duration + _skill2_cooldown), 0.0, 1.0)


func is_skill2_active() -> bool:
	if GameManager.selected_char_id == 4:
		## DÜZELTME (Büyücü Kız rework): Hortum/Meteor artık E'nin DEĞİL, R'nin
		## (skill3) varyasyonları - "aktif/kanal" görseli artık is_skill3_
		## active()'e taşındı (bkz. aşağısı), E'nin elindeki Arcane Lanet/Don
		## Nova ikisi de neredeyse anlık olduğu için E hiçbir zaman "aktif"
		## görünmez.
		return false
	return skill2_state == "active"


## get_skill_active_fraction()'ın skill2 (TEMEL/E) karşılığı - bkz. o
## fonksiyonun üstündeki yorum.
func get_skill2_active_fraction() -> float:
	if GameManager.selected_char_id == 4:
		## bkz. is_skill2_active() üstündeki AYNI düzeltme notu - kanal görseli
		## artık get_skill3_active_fraction()'a taşındı.
		return 0.0
	if skill2_state != "active" or _skill2_duration <= 0.0:
		return 0.0
	return clamp(skill2_timer / _skill2_duration, 0.0, 1.0)


## Seçili karakterin ikinci yetenek kimliği ("skill2" alanı, bkz.
## characters.gd) - yoksa 0 döner, bu da skill2 sisteminin o karakter için
## tamamen devre dışı olduğu anlamına gelir (bkz. _physics_process, HUD).
## DÜZELTME (Büyücü Kız'ın 4 varyasyonlu TEMEL'i): characters.gd'deki
## statik "skill2" alanı SADECE HUD ikonunun görünür olması için var (bkz. o
## dosyadaki yorum) - gerçek/güncel varyasyon kimliği HER ZAMAN buradan,
## buyucu_variation'a göre dinamik olarak döner.
func get_skill2_id() -> int:
	if GameManager.selected_char_id == 4:
		return BUYUCU_VARIATION_SKILL2_IDS[BUYUCU_SET_E_VARIATIONS[buyucu_variation_set]]
	var def: Dictionary = Characters.get_def(GameManager.selected_char_id)
	return def.get("skill2", 0)


## Üçüncü yetenek (Q) - skill2'nin (temel/E) birebir aynısı, sadece
## karmaşık varyasyon durumu olmadan (bugün sadece Shaman kullanıyor,
## bkz. dosya başındaki SKILL3_TIMING notu).
func _process_skill3(delta: float) -> void:
	if skill3_state != "ready":
		skill3_total_elapsed += delta
	if skill3_timer <= 0:
		return
	skill3_timer -= delta
	if skill3_timer > 0:
		return
	if skill3_state == "active":
		_end_skill3_effects()
		skill3_state = "cooldown"
		skill3_timer = _skill3_cooldown
	elif skill3_state == "cooldown":
		skill3_state = "ready"
		skill3_timer = 0.0
		skill3_total_elapsed = _skill3_duration + _skill3_cooldown


## DÜZELTME (Büyücü Kız rework): E'nin get_skill2_progress()'iyle AYNI desen
## - Büyücü Kız'ın R'si standart skill3_state makinesini KULLANMADIĞI için
## (bkz. _buyucu_try_activate_variation_r) ilerleme, o anki R varyasyonunun
## KENDİ bağımsız bekleme sayacından (_buyucu_variation_cooldowns) hesaplanır.
func get_skill3_progress() -> float:
	if GameManager.selected_char_id == 4:
		var cd: float = float(_skill2_timing_for(get_skill3_id()).get("cooldown", DEFAULT_SKILL2_COOLDOWN))
		if cd <= 0.0:
			return 1.0
		return clamp(1.0 - (_buyucu_variation_cooldowns[BUYUCU_SET_R_VARIATIONS[buyucu_variation_set]] / cd), 0.0, 1.0)
	## DÜZELTME (kullanıcı isteği: "Necromancer in R sini golem çıkarma ile
	## değiştir") - eskiden burada Necromancer'ın Yarasa Sürüsü (bir TOGGLE,
	## bkz. _necro_toggle_bats) için "her zaman hazır sayılır" özel bir dal
	## vardı - Yarasa Sürüsü artık E/skill2'de (bkz. get_skill2_progress()'teki
	## karşılığı), R'de artık standart skill3_state makinesini kullanan Golem
	## Çağır var, bu yüzden özel dal kaldırıldı - normal ilerleme hesabı
	## geçerli.
	if get_skill3_id() == 0:
		return 1.0
	if skill3_state == "ready":
		return 1.0
	return clamp(skill3_total_elapsed / (_skill3_duration + _skill3_cooldown), 0.0, 1.0)


func is_skill3_active() -> bool:
	if GameManager.selected_char_id == 4:
		## Hortum'un 15sn'lik dolaşma penceresi/Meteor'un 5sn'lik odaklanma
		## kanalı artık R'nin (skill3) sorumluluğunda - bkz. is_skill2_active()
		## üstündeki taşıma notu.
		return _buyucu_meteor_channel_active or not _buyucu_active_tornadoes.is_empty()
	return skill3_state == "active"


func get_skill3_active_fraction() -> float:
	if GameManager.selected_char_id == 4:
		if _buyucu_meteor_channel_active and BUYUCU_METEOR_CHANNEL_TIME > 0.0:
			return clamp(_buyucu_meteor_channel_timer / BUYUCU_METEOR_CHANNEL_TIME, 0.0, 1.0)
		return 0.0
	## Necromancer'ın Yarasa Sürüsü - sabit bir süresi yok (kalkan bitene/
	## tekrar basılana kadar sürer), o yüzden skill3_timer/_skill3_duration
	## oranı (hiçbiri bu toggle tarafından hiç güncellenmiyor) anlamsız kalır.
	## Aktifken tam dolu (1.0) göster - "toggle açık" en doğru okunuşu bu.
	if GameManager.selected_char_id == 11:
		return 1.0 if _necro_bats_active else 0.0
	if skill3_state != "active" or _skill3_duration <= 0.0:
		return 0.0
	return clamp(skill3_timer / _skill3_duration, 0.0, 1.0)


## Seçili karakterin üçüncü yetenek kimliği ("skill3" alanı, bkz.
## characters.gd) - yoksa 0 döner (o karakter için R tuşu/HUD ikonu tamamen
## devre dışı kalır, bkz. hud.gd/game_manager.gd).
## DÜZELTME (Büyücü Kız rework): get_skill2_id()'nin AYNI deseni - Büyücü
## Kız'ın R'si de characters.gd'deki statik "skill3" alanını (sadece HUD
## ikonunun ilk karede görünmesi için bir yer tutucu, bkz. o dosyadaki
## yorum) DEĞİL, o anki setin R varyasyonunu (BUYUCU_SET_R_VARIATIONS)
## dinamik olarak döndürür.
func get_skill3_id() -> int:
	if GameManager.selected_char_id == 4:
		return BUYUCU_VARIATION_SKILL2_IDS[BUYUCU_SET_R_VARIATIONS[buyucu_variation_set]]
	var def: Dictionary = Characters.get_def(GameManager.selected_char_id)
	return def.get("skill3", 0)


func get_skill_display() -> String:
	match skill_state:
		"ready":
			return "Ulti: HAZIR (R)"
		"active":
			return "Ulti AKTİF (%.0fs)" % skill_timer
		_:
			return "Ulti bekleniyor (%.0fs)" % skill_timer


func get_skill2_display() -> String:
	match skill2_state:
		"ready":
			return "Temel: HAZIR (E)"
		"active":
			return "Temel AKTİF (%.0fs)" % skill2_timer
		_:
			return "Temel bekleniyor (%.0fs)" % skill2_timer


func _update_facing(input_direction: Vector2) -> void:
	if input_direction.length() < 0.1:
		return
	var ax: float = abs(input_direction.x)
	var ay: float = abs(input_direction.y)
	## Require one axis to clearly dominate before switching facing. Without
	## this, near-diagonal input (e.g. holding two movement keys at once)
	## flickers back and forth between two facings every frame - barely
	## noticeable on the old simple 32x32 sprites, but very visible on
	## detailed sprite packs where left/right and up/down look completely
	## different (reads as the character "spinning" or "suddenly turning").
	if ax > ay * 1.3:
		facing = "right" if input_direction.x > 0 else "left"
	elif ay > ax * 1.3:
		facing = "up" if input_direction.y < 0 else "down"


## Koşu animasyonuna geçiş eşiği: hareket hızı, oyun başındaki taban hızın
## bu katına çıkarsa (Rüzgar Hızı, Şimşek Hız Modu, hız kartları vb.)
## yürüme yerine koşma oynar.
const RUN_ANIM_SPEED_RATIO := 1.25
## Kullanıcı isteği: "hareket hızı azalınca/artınca yürüme animasyonunun
## sprite sheetleri de birazcık daha hızlı/yavaş gerçekleşsin, hızlı
## yürüdüğü görsel açıdan belli olsun" - koşma klibine GEÇMEDEN önce bile
## (RUN_ANIM_SPEED_RATIO eşiğinin altında), aynı "walk_" klibi hıza göre
## biraz daha hızlı/yavaş oynatılır. Üst sınır RUN_ANIM_SPEED_RATIO ile
## aynı: tam eşikte zaten run_ klibine geçildiği için ikisi arasında ani bir
## hız sıçraması olmaz. Alt sınır yavaşlatıcı etkilerde animasyonun aşırı
## ağırlaşmasını (neredeyse durmuş görünmesini) engeller.
const WALK_ANIM_SPEED_SCALE_MIN := 0.7
const WALK_ANIM_SPEED_SCALE_MAX := RUN_ANIM_SPEED_RATIO
var _anim_base_speed: float = 300.0
## Karakter tanımından gelir (Characters.DEFS "always_walk"): true ise hız ne
## olursa olsun koşma animasyonuna geçilmez (ör. Büyücü Kız hep yürür).
var _always_walk: bool = false
## Karakter tanımından gelir (Characters.DEFS "melee"): true ise temel silah
## pençe modundadır ve vuruşlarda slash animasyonu oynar (Kurt Adam).
var _melee: bool = false
## Karakter tanımından gelir (Characters.DEFS "lifesteal"): 0'dan büyükse
## yaratıklara verilen hasarın bu oranı kadar can yenilenir (Kurt Adam pasifi).
var lifesteal_percent: float = 0.0
## Karakter tanımından gelir (Characters.DEFS "thorns_reflect_percent"):
## 0'dan büyükse cana işleyen hasarın bu oranı saldırgana geri yansıtılır
## (Şovalye Adam pasifi - "Dikenli Zırh"). bkz. take_damage().
var thorns_reflect_percent: float = 0.0

## Şovalye Adam'ın Koruma Bariyeri (skill3, id 29) - bu oyuncu buflanmışsa
## aldığı hasarın bu oranı damage_redirect_peer_id'ye yansır (bkz. take_
## damage(), NetworkManager.sync_damage_redirect_buff/sync_redirected_
## damage). damage_redirect_timer, Şovalye'nin AÇIK "kaldır" RPC'si hiç
## ulaşmasa bile (bağlantı sorunu vs.) bu buff'ın kendi kendine sönmesini
## garanti eden yerel bir güvenlik sayacı.
var damage_redirect_percent: float = 0.0
var damage_redirect_peer_id: int = 0
var damage_redirect_timer: float = 0.0
## Bariyerin görsel olarak (bkz. fx_paladin_barrier_link.gd) HERKESİN
## ekranında (buflanan oyuncunun kendi ekranı DAHİL) doğru görünmesi için -
## main.gd "extra" senkron sözlüğüne eklenen bayrağın kaynağı.
func has_active_damage_redirect_barrier() -> bool:
	return damage_redirect_percent > 0.0 and damage_redirect_peer_id > 0


## Yerel oyuncu (bkz. remote_player.gd _refresh_barrier_link_visual - AYNI
## desen, uzak kopyalar için) - CLAUDE.md'nin "kaster görür, diğerleri
## görmez" hata sınıfına düşmemek için buflanan oyuncu KENDİ ekranında da
## bariyeri görmeli, sadece main.gd'nin extra dict'i ÜZERİNDEN DEĞİL.
var _local_barrier_link_fx: Node2D = null

func _refresh_local_barrier_link_visual() -> void:
	var active: bool = has_active_damage_redirect_barrier()
	if active:
		if not _local_barrier_link_fx or not is_instance_valid(_local_barrier_link_fx):
			_local_barrier_link_fx = Node2D.new()
			_local_barrier_link_fx.set_script(load("res://scripts/fx_paladin_barrier_link.gd"))
			add_child(_local_barrier_link_fx)
	elif _local_barrier_link_fx and is_instance_valid(_local_barrier_link_fx):
		_local_barrier_link_fx.queue_free()
		_local_barrier_link_fx = null


## Şovalye'den (bkz. damage_redirect_peer_id) çok uzaklaşılırsa bariyer
## kaybolur - kullanıcı isteği. Her fizik karede çağrılır (bkz.
## _physics_process), Şovalye'nin GÜNCEL konumunu kendi RemotePlayer
## kuklasından (zaten yüksek frekansta senkron, main.gd _rpc_update_player_
## transform) okur, yeni bir RPC gerekmez.
const PALADIN_BARRIER_BREAK_RANGE := 400.0

func _process_damage_redirect_range_check(delta: float) -> void:
	if damage_redirect_peer_id <= 0:
		return
	damage_redirect_timer -= delta
	if damage_redirect_timer <= 0.0:
		damage_redirect_percent = 0.0
		damage_redirect_peer_id = 0
		return
	var source: Node2D = null
	for rp in get_tree().get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and "peer_id" in rp and int(rp.peer_id) == damage_redirect_peer_id:
			source = rp
			break
	if source == null or global_position.distance_to(source.global_position) > PALADIN_BARRIER_BREAK_RANGE:
		damage_redirect_percent = 0.0
		damage_redirect_peer_id = 0


func _update_animation(is_moving: bool) -> void:
	## Saldırı ve yetenek (spellcast) animasyonları bitene kadar ezilmez.
	var current := String(anim.animation)
	if (current.begins_with("attack") or current.begins_with("spellcast")) and anim.is_playing():
		## Aşağıdaki WALK_ANIM_SPEED_SCALE mantığı yürüme dışında hiç
		## çalışmayacağı için, hızlı yürürkenki speed_scale'in buraya SIZIP
		## bu animasyonları da hızlandırmasını engellemek için burada da
		## sıfırlanıyor (anim.speed_scale sprite node'unun PAYLAŞILAN bir
		## özelliği, sadece walk_ klibine özel değil).
		anim.speed_scale = 1.0
		return
	var prefix := "idle_"
	var effective_speed: float = speed
	if is_moving:
		effective_speed = speed * skill_speed_multiplier * skill2_speed_multiplier * shield_mode_speed_mult * (1.0 + item_speed_percent + speed_card_percent)
		## DÜZELTME (kullanıcı isteği: "matthewin koşma animasyonu varsa bu
		## yetenek aktifken aktif olsun") - Vahşi Hız hareket hızını sadece
		## %15 arttırıyor (MATTHEW_HASTE_MOVE_SPEED_MULT), bu tek başına
		## aşağıdaki genel RUN_ANIM_SPEED_RATIO (1.25x) eşiğini AŞMIYOR, yani
		## koşma animasyonu normal şartlarda hiç tetiklenmiyordu. Yetenek
		## aktifken (ve karakterin gerçekten bir koşma karesi varsa) eşiğe
		## bakılmaksızın doğrudan koşma animasyonuna geçiliyor.
		var matthew_haste_running: bool = is_skill2_active() and get_skill2_id() == 21 \
			and anim.sprite_frames and anim.sprite_frames.has_animation("run_" + facing)
		if matthew_haste_running or (not _always_walk and effective_speed > _anim_base_speed * RUN_ANIM_SPEED_RATIO):
			prefix = "run_"
		else:
			prefix = "walk_"
		## Yürüme animasyonu olmayan eski/harici sprite setleri için güvence.
		if prefix == "walk_" and not (anim.sprite_frames and anim.sprite_frames.has_animation("walk_" + facing)):
			prefix = "run_"
	var target_anim := prefix + facing
	if anim.animation != target_anim:
		anim.play(target_anim)
	## bkz. WALK_ANIM_SPEED_SCALE_MIN/MAX üstündeki not - sadece walk_
	## klibindeyken uygulanır, idle_/run_'da her zaman normal (1.0) hızda.
	anim.speed_scale = clampf(effective_speed / _anim_base_speed, WALK_ANIM_SPEED_SCALE_MIN, WALK_ANIM_SPEED_SCALE_MAX) if prefix == "walk_" else 1.0


func _on_weapon_fired(_direction: Vector2) -> void:
	if is_dead:
		return
	if _melee:
		## Yakın dövüş: karakter animasyonu oynatılmaz, ateş sesi de yok -
		## geri bildirim hedefteki savuruş efekti + pençe sesi (weapon.gd).
		return
	if fire_sound:
		fire_sound.pitch_scale = randf_range(0.92, 1.08)
		fire_sound.play()

	## Normal atışlarda animasyon oynatılmaz (büyü/savurma animasyonu yalnızca
	## F yeteneğinde) - sadece ufak bir ölçek zıplaması geri bildirimi.
	if anim:
		var tw := create_tween()
		tw.tween_property(anim, "scale", anim.scale * 1.12, 0.06)
		tw.tween_property(anim, "scale", char_base_anim_scale, 0.08)
	
	# Broadcast fire sound to remote players
	if NetworkManager.is_multiplayer_active and fire_sound and fire_sound.stream and fire_sound.stream.resource_path != "":
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "weapon_sound", global_position, {
			"sound_path": fire_sound.stream.resource_path,
			"pitch": fire_sound.pitch_scale,
			## DÜZELTME: gerçek volume_db taşınmıyordu, katılımcılar bu silah
			## sesini her zaman 0dB (tam ses) duyuyordu (bkz. network_manager.gd
			## "weapon_sound" case'indeki yorum).
			"volume_db": fire_sound.volume_db,
		})


func is_invisible_now() -> bool:
	return is_invisible


## bkz. is_indoors üstündeki yorum - enemy.gd bunu is_invisible_now() ile AYNI
## desende okuyor.
func is_indoors_now() -> bool:
	return is_indoors


## Silahları (owned_weapon_nodes) VE Necromancer'ın aktif yaratıklarını
## (varsa) tamamen durdurup gizler/geri açar - "combat tamamen devre dışı"
## gerektiren her yerde (ev içi, seyyar satıcının güvenli bölgesi) ORTAK
## kullanılan tek nokta. Eskiden house_interior.gd'nin KENDİ private
## _set_combat_visuals_hidden() fonksiyonu vardı, buraya taşındı (aynı
## davranış, sadece paylaşılabilir hale getirildi - bkz. traveling_merchant.gd
## de bunu çağırıyor) ki iki ayrı yerde aynı döngü elle kopyalanıp biri
## güncellenirken diğeri unutulmasın. process_mode = DISABLED, o node'un
## (ve varsa alt Timer'larının) HİÇBİR şey yapmamasını (ateş etmeme, hareket
## etmeme, yaşam süresi tükenmeme) garantiler.
func set_combat_active(active: bool) -> void:
	var mode: ProcessMode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	for w in owned_weapon_nodes:
		if is_instance_valid(w):
			w.visible = active
			w.process_mode = mode
			## Kullanıcı bildirimi: "Yıldırım asasına sahipken market alanının
			## içine girince effekt çıkmaya devam ediyor ama hasar vermiyor" -
			## process_mode = DISABLED, weapon.gd'nin _process() döngüsünü
			## (ve içindeki _end_beam() çağrısını) tamamen durdurduğu için
			## zaten açık olan ışın FX'i (get_tree().current_scene altında,
			## bu node'dan bağımsız) sahipsiz kalıp sonsuza dek çalışmaya
			## devam ediyordu. Devre dışı bırakılan TEK ortak nokta burası
			## olduğundan ışını kapatmak da burada olmalı.
			if not active and w.get("continuous_beam") == true and w.has_method("_end_beam"):
				w._end_beam()
	if "_necro_active_pets" in self:
		for p in _necro_active_pets:
			if is_instance_valid(p):
				p.visible = active
				p.process_mode = mode


func get_pickup_range() -> float:
	## Hasat Çantası: +%10 toplama menzili (bkz. item_pickup_range_percent).
	return pickup_range * (1.0 + item_pickup_range_percent)


## Genel can yenileme - player_pet.gd'nin heal()'i ile AYNI imza/desen
## (bkz. orada) - Öykü'nün Q/pasif yeteneklerinin "müttefik" hedefi ileride
## (multiplayer'da) BAŞKA BİR OYUNCU olursa (bugün sadece Matthew'in
## yaratığı "player_ally" grubunda) doğru çalışsın diye buraya da eklendi.
func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	health = min(max_health, health + amount)
	health_changed.emit(health, max_health)
	## DÜZELTME (kullanıcı bildirimi: "yerden yemek alınca verdiği can
	## görünmüyor üstümüzde") - remote_player.gd::heal() zaten can sayısını
	## floating text ile gösteriyordu, buradaki (yerel oyuncunun KENDİ) heal()
	## bunu hiç yapmıyordu. Multiplayer'da yemek alımı çoğunlukla bu fonksiyona
	## sync_food_heal RPC'siyle ulaşıyor (bkz. network_manager.gd), o RPC zaten
	## sadece iyileşen oyuncunun kendi client'ında çalıştığı için burada ek bir
	## ağ yayını gerekmiyor.
	_spawn_floating_text("%d" % int(round(amount)), Color(0.4, 0.9, 0.45), true)


## Genel kalkan yenileme - Öykü'nün TEMEL (E) yeteneğinin "müttefik" hedefi
## multiplayer'da başka bir oyuncu olursa diye (bkz. heal() üstündeki aynı
## gerekçe) - item_shield_max <= 0 ise (kalkan sahibi değilse) no-op.
func heal_shield(amount: float) -> void:
	if is_dead or amount <= 0.0 or item_shield_max <= 0.0:
		return
	item_shield_hp = min(item_shield_max, item_shield_hp + amount)
	item_shield_changed.emit(item_shield_hp, item_shield_max)


## Kullanıcı bildirimi: "Yaratıklara dokununca üst üste çok sayıda hasar
## alıyoruz bu hasar spamını düzelt" - kök neden: her yaratık KENDİ
## contact_interval'ını doğru uyguluyordu ama yaratıklar ARASINDA hiçbir
## ortak sınır yoktu, bu yüzden bir kalabalığın ortasında 3-4 farklı
## yaratıktan gelen hasar aynı 1-2 karede üst üste binip "spam" hissi
## veriyordu. Bu türdeki oyunlarda yaygın, standart bir "isabet sonrası
## kısa dokunulmazlık" penceresi - SADECE gerçekten işleyen (bloklanmamış)
## bir hasardan SONRA sayaç sıfırlanır, bloklanan denemeler pencereyi
## UZATMAZ (aksi halde sürekli dokunan bir kalabalık oyuncuyu kalıcı
## dokunulmaz yapardı - istenen bu değil, sadece aynı anlık patlamayı
## engellemek).
var _last_damage_taken_at_msec: int = -999999
const CONTACT_DAMAGE_IFRAME_MS := 150

const FxBloodSplatterScene := preload("res://scenes/fx_blood_splatter.tscn")

func take_damage(amount: float, source: Node2D = null) -> void:
	if is_dead:
		return
	var _now_damage_msec: int = Time.get_ticks_msec()
	if _now_damage_msec - _last_damage_taken_at_msec < CONTACT_DAMAGE_IFRAME_MS:
		return
	_last_damage_taken_at_msec = _now_damage_msec
	## Ev içindeyken ek güvenlik: normalde yaratıklar zaten indoors oyuncuyu
	## hiç hedeflemiyor (bkz. enemy.gd), ama başka bir hasar kaynağı
	## (ör. çoktan atılmış bir mermi) yine de buraya ulaşırsa tamamen yok say.
	if is_indoors:
		return
	## bkz. is_indoors üstündeki AYNI güvenlik notu - seyyar satıcının güvenli
	## bölgesindeyken de (bkz. is_in_merchant_zone üstündeki yorum) hiçbir
	## hasar işlenmemeli.
	if is_in_merchant_zone:
		return
	## DÜZELTME (kullanıcı bildirimi: "assasin çocuk görünmez olunca
	## yaratıklar onu görebiliyor ve hasar verebiliyor hala") - enemy.gd
	## normalde görünmez oyuncuyu hiç HEDEFLEMİYOR (bkz. _find_closest_
	## target_player/_physics_process player_is_invisible kontrolü), ama
	## zaten fırlatılmış bir mermi/homing saldırı (bkz. enemy_projectile.gd
	## "asla ıskalamaz" notu) ya da hedefleme kararı hasar isabet etmeden
	## HEMEN ÖNCE görünmezliğe geçiş gibi bir yarış durumu yine de buraya
	## ulaşabiliyordu. is_indoors/is_in_merchant_zone ile AYNI güvenlik
	## deseni: hasar kaynağı ne olursa olsun (temas/mermi/yetenek fark
	## etmeksizin) görünmezken hiçbir hasar işlenmemeli.
	if is_invisible:
		return
	if is_assasin_dashing:
		return
	if is_revive_invulnerable:
		return
	## Maç istatistik ekranı (bkz. E7/oyun sonu istatistik ekranı): burası
	## gerçekten "tanklanan" (kaçınılmayan/geçersiz sayılmayan) her isabetin
	## tek toplandığı yer - kalkan tamamen yutsa da (aşağıdaki is_shielded
	## dalı) bu bir gelen hasarı savuşturmaktır, takım adına "tanklamak"
	## sayılır.
	match_damage_taken += amount
	## Oakley'nin Koruyucu Büyü'sü (skill3 id 39, bkz. _skill_oakley_bond/
	## _apply_oakley_bond_to_target) - kullanıcı isteği: "kişi her hasar
	## aldığında oakley'in saldırı gücünün %10'u kadar can yeniler ve aynı
	## şekilde her hasar aldığında oakley'in saldırı gücünün %5'i kadar
	## kalkan yeniler ayrıca dost birey bu esnada %20 hasar azaltma
	## kazanır". "Her hasar aldığında" - is_shielded/kalkan havuzu bu isabeti
	## SONRADAN tamamen emse BİLE (yani cana hiç işlemese bile) yine de bir
	## "hasar alma" anı sayılır, bu yüzden burada, TÜM aşağıdaki emilim/
	## azaltma mantığından ÖNCE işleniyor - hem heal/kalkan proc'u hem de
	## %20 azaltma (ham "amount" üzerinden, aşağıdaki HER mitigasyon
	## katmanından önce) buradan geçer.
	if oakley_bond_active:
		amount *= (1.0 - oakley_bond_damage_reduction)
		if oakley_bond_heal_per_hit > 0.0 and health < max_health:
			health = min(max_health, health + oakley_bond_heal_per_hit)
			health_changed.emit(health, max_health)
		if oakley_bond_shield_per_hit > 0.0 and item_shield_max > 0.0:
			heal_shield(oakley_bond_shield_per_hit)
	if is_shielded:
		## Kalkan hasarı tamamen yuttu: baloncukta hasarın geldiği yönde
		## ekstra parlak bir parıltı çaktır (bkz. shield_visual.gd flash()).
		if shield_visual:
			var impact_angle: float = randf_range(0.0, TAU)
			if source and is_instance_valid(source):
				impact_angle = (source.global_position - global_position).angle()
			shield_visual.flash(impact_angle)
			## #57 DÜZELTME: network_manager.gd broadcast_player_vfx()'in
			## "shield_hit_flash" dalı ZATEN vardı (bkz. orada) ama bunu
			## tetikleyen bir GÖNDEREN hiç yoktu - bu parıltı da (paladin
			## baloncuğu gibi) sadece kalkan sahibinin kendi ekranında
			## görünüyordu.
			if NetworkManager.is_multiplayer_active:
				NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "shield_hit_flash", global_position, {
					"angle": impact_angle
				})
		return

	if matthew_dome_active:
		# Feda Kalkanı: fully blocks the hit either way - it just eats the
		# dome's own HP pool instead of health, and pops (with an explosion)
		# if that pool runs out before the 15s window does.
		matthew_dome_hp -= amount
		_spawn_floating_text("%d" % int(round(amount)), Color(1.0, 1.0, 1.0))
		if matthew_dome_hp <= 0.0:
			_pop_matthew_dome(true)
		return

	## Deri Çizme pasifi: hareket halindeyken fazladan sıvışma (bkz.
	## item_move_dodge_active, _process_item_passives).
	var effective_dodge: float = clamp(dodge_chance + shield_mode_dodge_bonus + item_move_dodge_active, 0.0, 0.95)
	if effective_dodge > 0.0 and randf() < effective_dodge:
		_spawn_floating_text("SIYRILDI", Color(0.7, 0.95, 1.0))
		return

	var remaining: float = amount
	## Kullanıcı isteği: "kalkansız hasar alma ... ses kalkan yokken karakter
	## hasar alırsa çıkacak." - aşağıdaki eşya-kalkanı dalı bu bayrağı
	## işaretler; cana hasar işlerken (bu fonksiyonun sonu) hiçbir kalkan bu
	## isabeti EMMEMİŞSE "kalkansız hasar" sesi çalınır. (is_shielded ve Feda
	## Kalkanı kubbesi yukarıda erken return ettiği için buraya yalnızca
	## emilmeyen/kalkansız hasar ulaşır.)
	var shield_absorbed_hit: bool = false
	## Şovalye ultisi aktifken kalkanın hasar emilim oranı (cana giden hasarı
	## azaltma oranı) 10 puan düşer - kalkan HAVUZU çok daha dayanıklı olduğu
	## için (bkz. aşağıdaki shield_cost_mult) bu bir denge bedeli.
	var paladin_absorption_penalty: float = 0.10 if paladin_zone_active else 0.0
	var effective_protection: float = clamp(
		shield_protection + shield_mode_protection_bonus + shield_mode_thorny_intake_bonus - paladin_absorption_penalty,
		0.0, SHIELD_MODE_PROTECTION_CAP
	)
	if item_shield_hp > 0 and effective_protection > 0.0:
		# Shield only ever eats its protection share of the hit - the rest
		# always reaches health, even with a full shield.
		var absorbed: float = min(item_shield_hp, amount * effective_protection)
		## Şovalye ultisi aktifken kalkan HAVUZU çok daha az yıpranır ama
		## sağladığı koruma (remaining'den düşülen miktar) AYNI kalır - yani
		## oyuncu normalde ne kadar hasardan korunuyorsa yine o kadar korunur,
		## sadece kalkanın kendisi bunun için %95 daha az "harcanır" (bkz.
		## PALADIN_ULTI_SHIELD_COST_MULT).
		var shield_cost_mult: float = PALADIN_ULTI_SHIELD_COST_MULT if paladin_zone_active else 1.0
		item_shield_hp -= absorbed * shield_cost_mult
		remaining -= absorbed
		shield_absorbed_hit = true ## bkz. yukarıdaki "kalkansız hasar" sesi notu
		item_shield_regen_delay = _shield_hit_regen_delay()
		item_shield_changed.emit(item_shield_hp, item_shield_max)
		_spawn_floating_text("%d" % int(round(absorbed)), Color(1.0, 1.0, 1.0))
		var impact_angle: float = randf_range(0.0, TAU)
		if source and is_instance_valid(source):
			impact_angle = (source.global_position - global_position).angle()
		_spawn_shield_hit_fx(impact_angle)
		## Dükkandan alınan Sihirli Kalkan hasar aldığında baloncuk kısa bir
		## süreliğine belirir (bkz. _update_shield_bubble()) ve hasarın geldiği
		## yönde ekstra parıldar.
		_damage_flash_timer = SHIELD_DAMAGE_FLASH_DURATION
		if shield_visual:
			shield_visual.flash(impact_angle)
		## #57 DÜZELTME: bkz. yukarıdaki "is_shielded" dalındaki aynı not -
		## bu parıltı + halka efekti de artık uzak oyunculara broadcast
		## ediliyor (network_manager.gd "shield_hit_flash" dalı zaten hazırdı).
		if NetworkManager.is_multiplayer_active:
			NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "shield_hit_flash", global_position, {
				"angle": impact_angle,
				"with_ring": true
			})
		shield_hit_sound.pitch_scale = randf_range(0.95, 1.08)
		shield_hit_sound.play()

		# Dikenli Kalkan: reflect a cut of the absorbed damage back at whatever hit us.
		if shield_mode_thorny_reflect_percent > 0.0 and source and is_instance_valid(source) and source.has_method("take_damage"):
			var reflect_amount: float = absorbed * shield_mode_thorny_reflect_percent
			if reflect_amount > 0.0:
				source.take_damage(reflect_amount)

		if remaining <= 0:
			return

	## DÜZELTME (kullanıcı isteği: "zırh statını ve zırhla ilgili herşeyi
	## oyundan kaldır") - eskiden burada "remaining - armor" düz zırh
	## indirimi vardı, artık zırh yok, tam remaining hasarı işleniyor (yine de
	## en az 1 hasar garanti edilir).
	## Talon pasifi (bkz. _talon_passive_damage_taken_mult) - damage_taken_mult
	## ile ÇARPIMSAL olarak birleşir, ikisi ayrı kaynaklardan (Kurt Adam
	## berserk'i / Talon yükleri) geldiği için birbirini EZMEZ.
	var effective_damage: float = max(remaining, 1.0) * damage_taken_mult * _talon_passive_damage_taken_mult()
	## Şovalye Adam'ın Koruma Bariyeri (skill3 id 29, bkz. _skill_paladin_
	## barrier/_apply_damage_redirect_to_ally) - bu oyuncu buflanmışsa
	## hasarın bir kısmı Şovalye'ye yansır. AYRILAN pay Şovalye'nin KENDİ
	## take_damage()'ından geçecek (RPC alıcı tarafta local_player.take_
	## damage() çağırır, bkz. network_manager.gd sync_redirected_damage) -
	## kalkanı normal işler, bypass YOK.
	if damage_redirect_percent > 0.0 and damage_redirect_peer_id > 0:
		var redirected_amount: float = effective_damage * damage_redirect_percent
		effective_damage -= redirected_amount
		if NetworkManager.is_multiplayer_active and redirected_amount > 0.0:
			NetworkManager.sync_redirected_damage.rpc(damage_redirect_peer_id, redirected_amount)
	health -= effective_damage
	health_changed.emit(health, max_health)
	_spawn_floating_text("%d" % int(round(effective_damage)), Color(1.0, 1.0, 1.0))
	## Kullanıcı isteği: "kalkansız hasar alma adında bir ses ekledim bu ses
	## kalkan yokken karakter hasar alırsa çıkacak." (bkz. shield_absorbed_hit
	## üstündeki not) - kalkan YOKKEN gerçekten cana işleyen her isabette
	## çalınır; üst üste gelen isabetlerde tekdüze olmaması için küçük bir
	## pitch sapması eklenir.
	if not shield_absorbed_hit:
		no_shield_damage_sound.pitch_scale = randf_range(0.95, 1.05)
		no_shield_damage_sound.play()
		## Kullanıcı isteği ("efekt sistemi" - kan.png): "karakter kalkansızken
		## hasar aldığında bedeninin rasgele kısımlarından" kan efekti çıkar -
		## no_shield_damage_sound ile BİREBİR AYNI koşulu paylaşıyor.
		_play_and_broadcast_skill_fx(FxBloodSplatterScene)
	## Dikenli Zırh (Şovalye Adam pasifi - bkz. characters.gd
	## thorns_reflect_percent): cana işleyen hasarın bir kısmı saldırgana
	## geri yansır. shield_mode_thorny_reflect_percent'in (yukarıdaki dükkan
	## modu) yansıttığı KALKAN'IN emdiği pay ile AYNI desen, sadece burada
	## kaynak doğrudan cana işleyen effective_damage.
	if thorns_reflect_percent > 0.0 and source and is_instance_valid(source) and source.has_method("take_damage"):
		var thorns_reflect_amount: float = effective_damage * thorns_reflect_percent
		if thorns_reflect_amount > 0.0:
			source.take_damage(thorns_reflect_amount)
	## Vitamin pasifi: cana gerçek hasar değdiğinde 5sn'lik regen penceresini
	## baştan başlat (bkz. _process_regen).
	if item_vitamin_regen_bonus > 0.0:
		item_vitamin_regen_timer = 5.0
	if health <= 0:
		die()


func die() -> void:
	if is_downed or is_dead:
		return
	## Kullanıcı isteği: "multiplayerda dirilme olayı ölür ölmez olmamalı.
	## öldükten sonra arkadaşının 3 saniye boyunca yakınında durması gereksin
	## seni diriltebilmek için" - eskiden GameManager.revives_remaining > 0
	## olduğu sürece ölüm ANINDA otomatik/koşulsuz canlandırılıyordu, hiçbir
	## müttefik çabası gerekmiyordu.
	## DÜZELTME (kullanıcı bildirimi: "herkes anında diriliyor başkasının
	## diriltmesini beklemek gerekmiyor" + "diriltmek için üstlerinde
	## beklediğimizde diriltildiklerinde yok oluyorlar") - iki kök neden:
	## 1) Burada eskiden AYRICA _has_living_teammate() şartı vardı - o
	## fonksiyon "remote_players" grubunu tarıyor, bu grup (bağlantı/spawn
	## zamanlaması yüzünden) geçici olarak boş görünürse downed süreci
	## TAMAMEN atlanıp direkt aşağıdaki "anında canlan" dalına düşülüyordu,
	## GERÇEKTE hayatta müttefik varken bile. Artık multiplayer'da tek şart
	## hakkın (revives_remaining) olması - kimse gelip kurtarmazsa zaten
	## DOWNED_BLEEDOUT_TIME sonunda otomatik kalıcı ölüme düşülüyor (bkz.
	## _process_downed), _has_living_teammate() gereksizdi.
	## 2) Hak eskiden SADECE burada "var mı" diye KONTROL ediliyor, gerçek
	## tüketim 3 saniye SONRA _complete_revive()'da yapılıyordu. Bu pencerede
	## başka bir oyuncu da aynı hakkı "boş" görüp downed'a girebiliyordu;
	## kanal ikisinde de dolunca SADECE biri host'tan hakkı kazanıyor, diğeri
	## "diriltildi" gibi görünüp (kanal doldu, ilerleme çubuğu tam) aslında
	## _finalize_death() ile SİLİNİYORDU. Artık hak burada, downed'a girerken
	## HEMEN rezerve ediliyor - downed'a giren biri artık KESİN olarak
	## dirilme hakkına sahip, _complete_revive() bir daha host'a sormuyor.
	## DÜZELTME (kullanıcı isteği: "multiplayerda canların takım canı değil
	## kişisel olmasını istiyorum") - paylaşılan GameManager.revives_remaining
	## YERİNE bu oyuncunun KENDİ peer_revives hakkı kontrol ediliyor (bkz.
	## network_manager.gd _consume_revive_authoritative) - aksi halde bu
	## kontrol hiç azalmayan eski paylaşılan alanı okuyup HERKESİ sonsuza
	## kadar "hakkı var" sanardı.
	if NetworkManager.is_multiplayer_active and GameManager.get_peer_revives(multiplayer.get_unique_id()) > 0:
		if await NetworkManager.try_use_revive():
			_go_down()
			return
		_finalize_death()
		return
	## bkz. network_manager.gd try_use_revive() üstündeki DÜZELTME notu - artık
	## host'a sorup yanıt bekleyebildiği için `await` ile çağrılıyor (host/
	## tekli oyuncuda anında, aynı karede sonuçlanır, davranış değişmez).
	## Buraya artık SADECE tek oyunculu (multiplayer olmayan) akış düşer.
	## DÜZELTME (kullanıcı isteği: "efekt sistemi" - diriltme.png/ölüm.png/
	## kalp.png singleplayerda da çalışsın): "singleplayerda artık oyuncu
	## ölünce hemen dirilmeyecek, 3 saniye yerde ölü kalıp bu animasyon
	## çalışıp 3 saniye sonra dirilecek. diriltme süreleri genel olarak 3
	## saniye olacak (REVIVE_CHANNEL_TIME zaten 3.0)." - eskiden burada
	## ANINDA/koşulsuz tam canlanma vardı (downed süreci "anlamsız"
	## sayılıyordu, çünkü kurtaracak müttefik yok). Artık multiplayer'daki
	## AYNI downed/diriltme kanalı (_go_down/_process_downed) kullanılıyor -
	## _process_downed tek oyunculuda "rescuer" aramadan HER ZAMAN ilerler
	## (bkz. oradaki DÜZELTME notu), yani kanal koşulsuz tam 3 saniyede
	## dolup _complete_revive()'a düşer. Bu sayede ölüm/diriltme-tersten-
	## oynatma/diriltme-sonrası-kalp efektleri (hepsi is_dead/is_downed/
	## get_revive_progress_ratio'ya reaktif, bkz. _update_death_status_fx/
	## _update_revive_rewind_fx) EK bir değişiklik gerekmeden singleplayer'da
	## da otomatik çalışıyor.
	if await NetworkManager.try_use_revive():
		_go_down()
		return

	_finalize_death()


## En az bir RemotePlayer (gerçek uzak katılımcı) hayatta mı - "downed"
## durumuna girmenin anlamlı olması için en az birinin gelip kurtarabilecek
## durumda olması gerekir (bkz. die()).
func _has_living_teammate() -> bool:
	for rp: Node in get_tree().get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and rp.get("is_dead") != true:
			return true
	return false


## REVIVE_RANGE içindeki en yakın HAYATTA (ne ölü ne de kendisi downed)
## RemotePlayer'ı döner - _process_downed()'ın kanal ilerleme kontrolü için.
func _nearest_living_ally_for_revive(max_range: float) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = max_range
	for rp: Node in get_tree().get_nodes_in_group("remote_players"):
		if not is_instance_valid(rp):
			continue
		if rp.get("is_dead") == true or rp.get("is_downed") == true:
			continue
		var d: float = global_position.distance_to((rp as Node2D).global_position)
		if d <= nearest_dist:
			nearest_dist = d
			nearest = rp as Node2D
	return nearest


## Ölüm anında ANINDA canlanmak yerine yere düşer - is_dead de true olur
## (hareket/saldırı/tekrar hasar alma _physics_process/take_damage'daki
## mevcut "if is_dead: return" korumalarıyla otomatik bloklanır, ayrıca bir
## kontrol eklemeye gerek yok) ama died sinyali HENÜZ yayılmaz (main.gd
## "ölüm ekranı" sadece gerçek/kalıcı ölümde açılmalı). main.gd, "dead"
## alanını ağa YAYARKEN is_downed true olduğu sürece false gönderir (bkz.
## main.gd state_snapshot) - yoksa remote_player.gd _play_death_animation()
## bu oyuncunun kuklasını hemen queue_free() ederdi, canlanma imkansız
## olurdu. is_downed alanı ise ayrıca senkronize edilip (aynı yerde)
## remote_player.gd'de griye boyanma + enemy.gd'de hedef dışı bırakma için
## kullanılıyor.
## Kullanıcı isteği ("efekt sistemi" - ölüm.png/diriltme.png/kalp.png): bkz.
## _update_death_status_fx/_update_revive_rewind_fx üstündeki DÜZELTME
## notları. _physics_process'in en başında HER karede (durum ne olursa
## olsun) çağrılıyor - hangi fonksiyonun is_dead/is_downed'ı değiştirdiğini
## tek tek izlemek yerine mevcut durumu reaktif olarak yansıtıyor.
const FxDeathScene := preload("res://scenes/fx_death.tscn")
const FxReviveRewindScene := preload("res://scenes/fx_revive_rewind.tscn")
const FxReviveHeartScene := preload("res://scenes/fx_revive_heart.tscn")
var _death_status_fx: Node = null
var _revive_rewind_fx: Node = null
var _was_downed_for_heart_fx: bool = false

## "karakter öldüğünde üstünde yavaşça çıkacak... son 5 frame karakter ölü
## olduğu sürece looplu... Karakter dirilince bu efekt kalkar." is_dead HEM
## downed (bkz. _go_down) HEM kalıcı ölümde (bkz. _finalize_death) true
## olduğu için, ikisini de tek bir reaktif kontrolle kapsıyor.
func _update_death_status_fx() -> void:
	if is_dead:
		if not _death_status_fx or not is_instance_valid(_death_status_fx):
			_death_status_fx = FxDeathScene.instantiate()
			add_child(_death_status_fx)
	elif _death_status_fx and is_instance_valid(_death_status_fx):
		_death_status_fx.queue_free()
		_death_status_fx = null


## "diritme süresi boyunca ölen karakterin üstünde tersten başa doğru
## oynatılacak... müttefik diriltilince efektteki spritesheetler de bitmiş
## olmalı, yarıda kesilirse... bar ileri doğru sarılıp sona gelerek barla
## beraber kapanır." SADECE gerçek bir diriltme kanalı ilerliyorken (ratio>0)
## görünür - is_downed olup kimse gelmediği sürece (ratio hep 0) hiç
## belirmez, o zaten ölüm efektinin/gri tonun işi.
func _update_revive_rewind_fx() -> void:
	var ratio: float = get_revive_progress_ratio() if is_downed else 0.0
	if is_downed and ratio > 0.0:
		if not _revive_rewind_fx or not is_instance_valid(_revive_rewind_fx):
			_revive_rewind_fx = FxReviveRewindScene.instantiate()
			add_child(_revive_rewind_fx)
		if _revive_rewind_fx.has_method("set_progress"):
			_revive_rewind_fx.set_progress(ratio)
	elif _revive_rewind_fx and is_instance_valid(_revive_rewind_fx):
		_revive_rewind_fx.queue_free()
		_revive_rewind_fx = null

	## "bir karakter diğerini dirilttikten SONRA diriltilen kişinin nickinin
	## üzerinde 3 saniye boyunca aktif olacak" - is_downed'ın true'dan
	## false'a geçişini burada yakalıyoruz (_complete_revive tam olarak bunu
	## yapıyor), _finalize_death'te is_downed zaten false'a düşürülüp is_dead
	## true kaldığı için (kalıcı ölüm) yanlışlıkla tetiklenmez.
	if _was_downed_for_heart_fx and not is_downed and not is_dead:
		var heart := FxReviveHeartScene.instantiate()
		add_child(heart)
	_was_downed_for_heart_fx = is_downed


func _go_down() -> void:
	is_downed = true
	is_dead = true
	health = 0
	_downed_time = 0.0
	_revive_progress = 0.0
	_spawn_floating_text("DÜŞTÜN!", Color(1.0, 0.3, 0.3))
	if overhead_bar:
		overhead_bar.set_health(0.0, REVIVE_CHANNEL_TIME)
		overhead_bar.set_shield(0.0, 0.0)
	if anim:
		if anim.sprite_frames and anim.sprite_frames.has_animation("hurt"):
			anim.play("hurt")
		anim.modulate = Color(0.5, 0.5, 0.55, 1.0)
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "skill_ring", global_position, {
			"radius": 70.0,
			"color": Color(0.6, 0.15, 0.15)
		})


## "downed" iken _physics_process'in normal dalı yerine HER karede çağrılır
## (bkz. oradaki dallanma) - kanalı ilerletir/geriletir, süre dolarsa kalıcı
## ölüme düşer.
func _process_downed(delta: float) -> void:
	_downed_time += delta
	if _downed_time >= DOWNED_BLEEDOUT_TIME:
		_finalize_death()
		return
	## DÜZELTME (kullanıcı isteği: "efekt sistemi" - singleplayerda da 3
	## saniyelik diriltme süreci) - tek oyunculuda gerçek bir müttefik/
	## rescuer hiç yok ("remote_players" grubu hep boş), bu yüzden kanal
	## HER ZAMAN ilerliyormuş gibi davranılır - koşulsuz tam REVIVE_CHANNEL_
	## TIME (3sn) sonunda _complete_revive() tetiklenir. Multiplayer'daki
	## "gerçek bir müttefik yakında durmalı" davranışı AYNEN korunuyor.
	var rescuer: Node2D = _nearest_living_ally_for_revive(REVIVE_RANGE) if NetworkManager.is_multiplayer_active else null
	if rescuer or not NetworkManager.is_multiplayer_active:
		_revive_progress = min(REVIVE_CHANNEL_TIME, _revive_progress + delta)
	else:
		## Müttefik menzilden ayrılırsa kanal anlık sıfırlanmaz, iki katı
		## hızda geriler - "yakınında durması gereksin" isteğine göre kalıcı
		## bir varlık gerektiriyor ama kısa bir kopmayı da affediyor.
		_revive_progress = max(0.0, _revive_progress - delta * 2.0)
	if overhead_bar:
		overhead_bar.set_health(_revive_progress, REVIVE_CHANNEL_TIME)
	if downed_timer_label:
		downed_timer_label.set_remaining_seconds(get_downed_remaining_seconds())
	if _revive_progress >= REVIVE_CHANNEL_TIME:
		_complete_revive()


## bkz. main.gd state_snapshot - downed iken hp/max_hp alanları gerçek can
## yerine bu oranı taşır, böylece müttefikler kurtarma kanalının ilerlemesini
## downed oyuncunun ÜSTÜNDEKİ can çubuğunda (bkz. remote_player.gd
## overhead_bar.set_health) gerçek zamanlı görebilir.
func get_revive_progress_ratio() -> float:
	if not is_downed or REVIVE_CHANNEL_TIME <= 0.0:
		return 0.0
	return clamp(_revive_progress / REVIVE_CHANNEL_TIME, 0.0, 1.0)


## Kullanıcı isteği: "birisi düştüğünde diğerleri onu canlandırmak için bir
## süre var ama o süre görünmüyor" - kalıcı ölüme (bkz. DOWNED_BLEEDOUT_TIME)
## kadar kalan saniye. bkz. main.gd state_snapshot "extra" torbası ve
## downed_timer_label.gd - hem bu oyuncunun kendi ekranında (player.gd
## _process_downed) hem müttefiklerin ekranında (remote_player.gd, ağdan
## gelen extra.downed_remaining ile) AYNI değeri göstermek için kullanılıyor.
func get_downed_remaining_seconds() -> float:
	if not is_downed:
		return 0.0
	return max(0.0, DOWNED_BLEEDOUT_TIME - _downed_time)


func _complete_revive() -> void:
	## DÜZELTME (bkz. die() üstündeki DÜZELTME notu): revive hakkı artık
	## downed'a girerken ZATEN rezerve edildi - burada TEKRAR host'a
	## sorulmuyor. Eskiden burada ikinci bir try_use_revive() çağrısı vardı;
	## eğer bu arada hak başka bir oyuncu tarafından tüketilmişse (mümkündü,
	## çünkü hak henüz rezerve edilmemişti) kanal dolmuş/başarılı görünen bu
	## oyuncu aslında _finalize_death() ile SİLİNİYORDU ("diriltildi ama yok
	## oldu" şikayeti). Artık kanalı dolduran biri KESİN dirilir.
	is_downed = false
	is_dead = false
	_downed_time = 0.0
	_revive_progress = 0.0
	if downed_timer_label:
		downed_timer_label.set_remaining_seconds(0.0)
	health = max_health
	if item_shield_max > 0.0:
		item_shield_hp = item_shield_max
	health_changed.emit(health, max_health)
	item_shield_changed.emit(item_shield_hp, item_shield_max)
	_spawn_floating_text("CANLANDIN!", Color(1.0, 0.8, 0.2))
	_spawn_burst(Color(0.2, 1.0, 0.4))

	var tw_rev := create_tween()
	anim.modulate = Color(1.0, 1.0, 1.0, 0.4)
	tw_rev.tween_property(anim, "modulate:a", 1.0, 0.8)

	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "skill_burst", global_position, {
			"radius": 100.0,
			"color": Color(0.2, 1.0, 0.4)
		})

	## Kullanıcı isteği: "birini diriltince 3 saniye boyunca ölümsüzlük veren
	## bir buff olmalı dirilten ve diriltilen kişide" - diriltilen (kendisi,
	## yerel) burada doğrudan; dirilten (rescuer) muhtemelen BAŞKA bir peer
	## olduğu için ağ üzerinden (bkz. network_manager.gd
	## grant_revive_invulnerability).
	grant_revive_invulnerability()
	var rescuer: Node2D = _nearest_living_ally_for_revive(REVIVE_RANGE)
	if rescuer and is_instance_valid(rescuer) and "peer_id" in rescuer:
		var rescuer_pid: int = int(rescuer.get("peer_id"))
		if rescuer_pid > 0 and NetworkManager.is_multiplayer_active:
			NetworkManager.grant_revive_invulnerability.rpc_id(rescuer_pid, REVIVE_INVULNERABILITY_TIME)


## bkz. _complete_revive() üstündeki kullanıcı isteği notu. anim üstünde
## hafif bir yarı-şeffaflık/parıltı bırakır ki oyuncu dokunulmaz olduğunu
## görebilsin - is_assasin_dashing'in take_damage()'ta zaten kullandığı AYNI
## "geçici dokunulmazlık bayrağı" deseni.
func grant_revive_invulnerability(duration: float = REVIVE_INVULNERABILITY_TIME) -> void:
	is_revive_invulnerable = true
	if anim:
		anim.modulate = Color(1.0, 1.0, 1.0, 0.55)
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		is_revive_invulnerable = false
		if anim and is_instance_valid(anim):
			anim.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)


## Kalıcı ölüm - eskiden die()'ın alt kısmıydı (revive hakkı yoksa ya da
## downed kanalı/bleedout süresi başarısız olursa buraya düşülür).
func _finalize_death() -> void:
	is_downed = false
	is_dead = true
	health = 0
	if downed_timer_label:
		downed_timer_label.set_remaining_seconds(0.0)
	## Kullanıcı isteği: "öldüğü konum ve body si yerinde durmalı" - ceset
	## artık kalıcı olarak sahnede kaldığı için (bkz. aşağıdaki #47/#44
	## düzeltmesi) fiziksel çarpışması da kapatılıyor ki kimse cesede takılıp
	## kalmasın (remote_player.gd _play_death_animation'daki AYNI düzeltme).
	var col: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)
	died.emit()
	## DÜZELTME (kullanıcı bildirimi: "öldüğümüz zaman mapin sol üst kısmına
	## geliyor kamera ve orda sabit kalıyor"): bu fonksiyonun sonunda TÜM
	## Player node'u (Camera2D DAHİL - bkz. player.tscn, kamera onun ÇOCUĞU)
	## queue_free() ediliyordu. Kamera da yok olunca sahnede AKTİF hiçbir
	## Camera2D kalmıyor, viewport varsayılan (0,0) merkezli görünüme
	## düşüyor - haritanın sol üst köşesine "yapışmış" gibi görünen tam
	## olarak budur. Artık ölüm anında kamera Player'dan KOPARILIP sahnenin
	## köküne taşınıyor ve "current" yapılıyor - görünüm oyuncunun öldüğü
	## yerde SABİT kalıyor (rastgele bir köşeye atlamıyor). Bir süre sonra
	## (oyun bitene/sahneden çıkılana kadar asılı kalmasın diye) o da
	## temizleniyor.
	## #47/#44 DÜZELTME (kullanıcı bildirimi: "Biri ölünce bazen oyun donup
	## crashleniyor" / genel crash sorunu): kök neden bulundu - die() menzilli
	## bir düşman mermisinin (bkz. enemy_projectile.gd _on_body_entered, bir
	## Area2D "body_entered" SİNYALİ, yani fizik sorgu işleme SIRASINDA
	## çalışan bir callback) doğrudan take_damage() çağırmasıyla SENKRON
	## tetiklenebiliyordu. Aşağıdaki remove_child()/add_child() (kamera
	## koparma) da SENKRON çalışıyordu - tıpkı xp_orb.gd/gold_drop.gd/
	## food_drop.gd'de daha önce bulunan "Can't change this state while
	## flushing queries" çökme kalıbıyla (bkz. o dosyalardaki aynı düzeltme)
	## AYNI kök neden: bir fizik sorgu taşması SIRASINDA sahne ağacını
	## SENKRON değiştirmek arada bir (rastgele zamanlamaya bağlı - "bazen")
	## oyunu dondurup çökertiyordu. call_deferred ile güvenli bir ana
	## ertelenerek çözüldü.
	if death_camera and is_instance_valid(death_camera):
		call_deferred("_detach_death_camera")


## bkz. die() üstündeki #47/#44 düzeltmesi - kamera koparma/yeniden ebeveynleme
## işlemi buraya taşındı ki call_deferred ile güvenli bir ana ertelenebilsin.
func _detach_death_camera() -> void:
	if not death_camera or not is_instance_valid(death_camera):
		return
	var cam_global_pos: Vector2 = death_camera.global_position
	var cam_zoom: Vector2 = death_camera.zoom
	if death_camera.get_parent() == self:
		remove_child(death_camera)
	if not is_instance_valid(get_tree().current_scene):
		return
	get_tree().current_scene.add_child(death_camera)
	death_camera.global_position = cam_global_pos
	death_camera.zoom = cam_zoom
	death_camera.make_current()
	## #54 DÜZELTME (kullanıcı isteği: "Ölüm ekranında seçilebilir müttefik
	## takip kamerası"): eskiden bu kamera 20sn sonra OTOMATİK siliniyordu -
	## takım hâlâ hayattaysa (multiplayer'da "İzleyicisin" durumu çok daha
	## uzun sürebilir) 20sn dolunca görünüm yine sahnenin (0,0) köşesine
	## "yapışmış" gibi görünen o ESKİ hataya geri dönüyordu. Artık kamerayı
	## main.gd (bkz. _begin_spectate_mode/_process) devralıp seçilen bir
	## müttefiği takip ettiriyor ve ömrünü kendisi yönetiyor - burada süreli
	## bir otomatik silme YOK.
	## Ölme animasyonu (LPC hurt satırı: yere yığılma, 6 kare ~0.75sn).
	if anim.sprite_frames and anim.sprite_frames.has_animation("death"):
		anim.play("death")
	## DÜZELTME (kullanıcı bildirimi: "Ölen oyuncu multiplayerda bir süre
	## sonra tamamen yok oluyor öldüğü konum ve body si yerinde durmalı") -
	## burada eskiden anim.modulate:a 0.0'a soluklaştırılıyordu, yani Player
	## node'u (bkz. hemen altındaki düzeltme) sahnede kalsa BİLE tamamen
	## görünmez oluyordu - "ceset" hiçbir zaman görünür değildi. Artık hiç
	## soluklaştırılmıyor, ölüm animasyonunun son karesinde donuk kalıp
	## öldüğü konumda görünür bir ceset gibi duruyor. revive_from_permadeath()
	## zaten kendi modulate'ini koşulsuz sıfırlayıp yeniden fade-in yapıyor
	## (bkz. orası), bu yüzden burada hiç soluklaştırmamak canlanmayı bozmaz.
	## BUG DÜZELTMESİ (kullanıcı bildirimi: "1-2 dakika diriltmediğimizde
	## oyuncu yok oluyor ve bir daha diriltilemiyor") - kök neden: buradaki
	## `tween_callback(queue_free)` niyet olarak kamerayı (death_camera)
	## hedeflemesi gerekirken, bu fonksiyon Player script'inin İÇİNDE
	## olduğu için parametresiz "queue_free" bare referansı self'e (Player'ın
	## KENDİSİNE) bağlanıyordu - yani ölümden ~1-1.4sn sonra PLAYER NODE'UN
	## TAMAMI sahneden siliniyordu (üstteki yorumun "burada süreli bir
	## otomatik silme YOK" ifadesiyle doğrudan çelişerek). Bu, kullanıcının
	## tam olarak tarif ettiği "oyuncu yok oluyor" - artık hiçbir şey
	## silinmiyor, Player node'u kalıcı ölümden sonra da sahnede kalıyor
	## (dükkandan diriltme satın alınabilmesi de bkz. revive_from_permadeath
	## BUNA bağımlı).


## Kullanıcı isteği: "dükkandan diriltme satın alınabilmeli, ölü oyuncular
## diriltme satın alarak canlanabilmeli" - _complete_revive() (bkz. yukarısı)
## SADECE "downed" durumundan (kamera hiç Player'dan kopmamışken) çağrılmak
## üzere tasarlanmıştı. Kalıcı ölümden (is_dead, downed DEĞİL - bkz.
## _finalize_death/_detach_death_camera) sonra kamera zaten sahnenin köküne
## taşınmış ve main.gd'nin "izleyici modu" (_begin_spectate_mode) onu
## devralmış oluyor - bu yüzden burada AYRICA kamerayı geri Player'a takıyoruz.
## main.gd'nin kendi tarafındaki temizliği (izleyici modundan çıkma, ölüm
## ekranını kapatma) çağıran taraf (bkz. main.gd _revive_local_player)
## yapıyor - bu fonksiyon sadece Player'ın KENDİ durumundan sorumlu.
func revive_from_permadeath() -> void:
	if not is_dead or is_downed:
		return
	is_downed = false
	is_dead = false
	_downed_time = 0.0
	_revive_progress = 0.0
	## bkz. _finalize_death() üstündeki AYNI düzeltme - ceset olurken kapatılan
	## çarpışma canlanınca geri açılmalı.
	var col: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", false)
	health = max_health
	if item_shield_max > 0.0:
		item_shield_hp = item_shield_max
	health_changed.emit(health, max_health)
	item_shield_changed.emit(item_shield_hp, item_shield_max)
	_spawn_floating_text("CANLANDIN!", Color(1.0, 0.8, 0.2))
	_spawn_burst(Color(0.2, 1.0, 0.4))

	if death_camera and is_instance_valid(death_camera):
		if death_camera.get_parent() != self:
			var old_parent: Node = death_camera.get_parent()
			if old_parent:
				old_parent.remove_child(death_camera)
			add_child(death_camera)
			death_camera.position = Vector2.ZERO
		death_camera.make_current()

	if anim:
		anim.modulate = Color(1.0, 1.0, 1.0, 0.4)
		var tw_rev := create_tween()
		tw_rev.tween_property(anim, "modulate:a", 1.0, 0.8)

	grant_revive_invulnerability()

	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "skill_burst", global_position, {
			"radius": 100.0,
			"color": Color(0.2, 1.0, 0.4)
		})



## Can çalma pasifi: düşmanlar yedikleri gerçek hasarı buraya bildirir
## (enemy.take_damage). lifesteal_percent 0 olan karakterlerde hiçbir şey
## yapmaz.
## DÜZELTME (kullanıcı isteği: "can çalma sistemi komple değişiyor, artık
## verilen hasarın %'liğini yenilemiyor - %X can çalma = %X ihtimalle
## isabet halinde 1 can yeniler") - eskiden lifesteal_percent, hasarın
## GameManager.LIFESTEAL_EFFECTIVENESS ile ölçeklenmiş bir KATINI can olarak
## geri veren bir ÇARPANDI. Artık hasar MİKTARINDAN tamamen BAĞIMSIZ: her
## gerçek isabette (amount>0) sabit 1 can yenileme İHTİMALİ.
## LIFESTEAL_EFFECTIVENESS eski formüle özgüydü, burada artık kullanılmıyor
## (Kurt Adam'ın Vahşi Kesik'i KENDİ ayrı/sabit hasar-bazlı can çalmasında
## onu hâlâ kullanıyor - bkz. orası, bu değişiklik o AYRI mekanizmayı
## KAPSAMIYOR).
func on_damage_dealt(amount: float) -> void:
	if is_dead or lifesteal_percent <= 0.0 or amount <= 0.0 or health >= max_health:
		return
	if randf() < lifesteal_percent:
		health = min(max_health, health + 1.0)
		health_changed.emit(health, max_health)


## Kullanıcı isteği: "herkes kimin exp topladığından bağımsız olarak AYNI
## ANDA level atlamalı." EXP zaten paylaşılıyordu (share_xp RPC) ama SENKRON
## DEĞİLDİ: eskiden ham (bonussuz) miktar yayınlanıyor, HER oyuncu bunu
## KENDİ exp_gain_percent'iyle (Deneyim Defteri gibi kart yükseltmeleri -
## her oyuncu farklı kartlar seçebilir) tekrar çarpıyordu. Yani toplayanın
## bonusu bir kez, alıcının bonusu bir kez daha uygulanıyor, zamanla can
## sayıları birbirinden kayıyordu (bkz. kullanıcı bildirimi: "bir karakter
## level atlayınca diğeri atlamış sayılmıyor"). Artık NİHAİ (bonus dahil)
## miktar TOPLAYANIN bonusuyla BİR KEZ hesaplanıp olduğu gibi (bkz.
## _apply_xp_raw - başka çarpım YOK) herkese yayılıyor - böylece xp/level
## durumu her zaman bit bir eş kalır.
## Yerel oyuncu XP orbu topladığında ses ve Hasat Çantası tetiklemesi
func on_xp_collected() -> void:
	if is_dead:
		return
	_play_xp_pickup_sound()
	if item_xp_heal_chance > 0.0 and health < max_health and randf() < item_xp_heal_chance:
		health = min(max_health, health + 1.0)
		health_changed.emit(health, max_health)


## Ortak takım seviyesi atlandığında GameManager tarafından tetiklenir - her
## çağrı TAM OLARAK +1 seviye demektir (bkz. game_manager.gd _level_up_team/
## set_team_xp_state - toplu "yakalama" senkronunda bile seviye başına AYRI
## AYRI emit ediliyor), bu yüzden burada eklenen saldırı gücü/can hiç
## atlanmadan/katlanmadan her seviyede bir kez uygulanır (kullanıcı isteği:
## "level başına herkes fazladan 1 saldırı gücü ve 1 can kazanacak" - bu,
## level-up ekranındaki kart seçimine EK, kart neyse ondan bağımsız).
## DÜZELTME (kullanıcı isteği: "Level başına karakterlere verilen saldırı
## gücü miktarını 2 ye çıkarıp kazanılan can miktarını da 5'e çıkar.") - +1/+1
## yerine artık +2 saldırı gücü/+5 can her seviyede.
func on_team_leveled_up(new_level: int) -> void:
	level = new_level
	max_item_slots = level
	max_health += 5.0
	health += 5.0
	health_changed.emit(health, max_health)
	damage_bonus += 2.0
	_apply_weapon_bonuses()


func _process_xp_streak(delta: float) -> void:
	if xp_streak_timer <= 0.0:
		return
	xp_streak_timer -= delta
	if xp_streak_timer <= 0.0:
		xp_pickup_streak = 0


func _play_xp_pickup_sound() -> void:
	xp_pickup_streak = min(xp_pickup_streak + 1, XP_STREAK_MAX)
	xp_streak_timer = XP_STREAK_RESET_TIME
	var pitch: float = 1.0 + xp_pickup_streak * XP_STREAK_PITCH_STEP
	var delay: float = _xp_sound_queue_count * XP_SOUND_STAGGER_DELAY
	_xp_sound_queue_count += 1
	if delay <= 0.0:
		_fire_xp_sound(pitch)
	else:
		get_tree().create_timer(delay).timeout.connect(_fire_xp_sound.bind(pitch))


## _play_xp_pickup_sound() tarafından, aralarına minicik bir gecikme konularak
## sırayla çağrılır - $XPPickupSound'un kendisini DEĞİL, onun stream/volume/
## menzil ayarlarını kopyalayan geçici bir çalıcı kullanır, böylece birden
## fazlası gerçekten aynı anda/üst üste (hafif kaymalı) çalabilir.
func _fire_xp_sound(pitch: float) -> void:
	if not is_instance_valid(self):
		return
	_xp_sound_queue_count = max(0, _xp_sound_queue_count - 1)
	if not xp_pickup_sound or not xp_pickup_sound.stream:
		return
	var s := AudioStreamPlayer2D.new()
	s.stream = xp_pickup_sound.stream
	s.volume_db = xp_pickup_sound.volume_db
	s.max_distance = xp_pickup_sound.max_distance
	s.pitch_scale = pitch
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)


## Kullanıcı isteği (bkz. yukarıdaki "4 yürüme sesi" notu): karakter GERÇEKTEN
## hareket ederken, belli bir ARALIKLA (WALK_STEP_INTERVAL) rastgele bir adım
## sesi çalar - yani "yürüme sesi" artık kesintisiz bir döngü değil, adım adım
## gelen tek seferlik sesler.
##
## Hız eşlemesi karakterin O ANKİ GERÇEK hareket hızından yapılıyor: velocity
## (bkz. _physics_process'te üretildiği satır, knockback hariç) taban hıza
## bölünür ve çıkan oran hem adım aralığını böler hem pitch'i çarpar. Formülü
## elle tekrarlamak yerine velocity okunduğu için girdi miktarı, hız kartı,
## Deri Çizme/Kitelama Seti, Rüzgar Hızı, Şimşek Hız Modu, Oakley'nin geçici
## hız buff'ı ve yavaşlatıcı etkilerin HEPSİ kendiliğinden yansır (sınırlar:
## bkz. WALK_SPEED_RATIO_MIN/MAX - yavaşlatıcı etkilerde aşırı seyrek/kalın,
## aşırı hızda ise tiz cıvıltıya dönmesini engeller).
func _update_walk_sound(is_moving: bool, delta: float) -> void:
	if _walk_sounds.is_empty():
		return
	if not is_moving:
		## Adımlar tek seferlik sesler: durunca sadece YENİ adım planlamayı
		## bırakıyoruz (çalmakta olan adım kendi kendine biter - kesmek sesi
		## bozuk/tık diye duyururdu). Sayaç sıfırlandığı için tekrar hareket
		## etmeye başlanır başlanmaz ilk adım GECİKMESİZ duyulur.
		_walk_step_timer = 0.0
		return
	## Karakterin O ANKİ GERÇEK hareket hızı: velocity doğrudan kullanıldığı için
	## girdi miktarı, hız kartları/yetenekleri ve yavaşlatıcı etkilerin HEPSİ
	## kendiliğinden orana yansır (bkz. _physics_process'te velocity'nin
	## üretildiği satır). _knockback_velocity ÇIKARILIYOR çünkü o karakterin
	## kendi yürüyüşü değil, dışarıdan itilmedir - çıkarılmazsa geri itilirken
	## pitch/aralık oranı fırlayıp bir anda onlarca adım sesi çalardı.
	var own_velocity: Vector2 = velocity - _knockback_velocity
	var speed_ratio: float = clampf(own_velocity.length() / maxf(speed, 1.0), WALK_SPEED_RATIO_MIN, WALK_SPEED_RATIO_MAX)
	_walk_step_timer -= delta
	if _walk_step_timer > 0.0:
		return
	## Hız arttıkça aralık kısalır - karakter hızlandıkça adımlar sıklaşır -
	## ama bkz. WALK_STEP_INTERVAL_SPEED_INFLUENCE üstündeki not: aralık
	## speed_ratio'nun SÖNÜMLENMİŞ (1.0'a yaklaştırılmış) haline bölünüyor,
	## yoksa yüksek hızlarda adımlar "spamlanıyor" gibi geliyordu. Pitch
	## (_play_walk_step) hâlâ tam speed_ratio'yu kullanıyor.
	var interval_speed_ratio: float = 1.0 + (speed_ratio - 1.0) * WALK_STEP_INTERVAL_SPEED_INFLUENCE
	_walk_step_timer = WALK_STEP_INTERVAL / interval_speed_ratio
	_play_walk_step(speed_ratio)


## Adım seslerinden RASTGELE, o an ÇALMAYAN birini seçip çalar.
##
## "O an çalmayan" seçimi küçük bir çalıcı HAVUZU görevi görür: hızlı yürürken
## aralık 0.2sn'ye kadar inerken sesler ~0.3sn sürdüğü için adımlar üst üste
## biner - tek bir AudioStreamPlayer2D olsaydı her yeni adım .play() ile
## bir önceki adımın sesini KESERDİ (bkz. _fire_xp_sound'daki aynı sorun).
## Dördü de çalıyorsa bu adım atlanır (pratikte olmaz: en fazla 2 tanesi
## aynı anda çalar).
func _play_walk_step(speed_ratio: float) -> void:
	var available: Array[AudioStreamPlayer2D] = []
	for step_sound in _walk_sounds:
		if not step_sound.playing:
			available.append(step_sound)
	if available.is_empty():
		return
	var chosen: AudioStreamPlayer2D = available.pick_random()
	## Çok küçük rastgele sapma HER adımda yeniden hesaplanır (kullanıcı
	## isteği) - sesin hep aynı kayıt olduğu belli olmasın diye.
	chosen.pitch_scale = speed_ratio * randf_range(1.0 - WALK_SOUND_PITCH_JITTER, 1.0 + WALK_SOUND_PITCH_JITTER)
	chosen.play()


## Adım sesi olarak kullanılacak TÜM çalıcıları toplar. Sahnede elle liste
## tutmak yerine player.tscn'in çocukları taranıyor: yeni bir adım sesi eklemek
## için sahneye "WalkSound5" adında (ya da "walk_sounds" grubunda) yeni bir
## AudioStreamPlayer2D koymak yeterli - script değişikliği gerekmez.
func _collect_walk_sounds() -> Array[AudioStreamPlayer2D]:
	var out: Array[AudioStreamPlayer2D] = []
	for child in get_children():
		if child is AudioStreamPlayer2D and (String(child.name).begins_with("WalkSound") or child.is_in_group("walk_sounds")):
			out.append(child)
	return out


## Level atlama kartlarının verdiği bonuslar - level atlama kolaylaştırıldığı
## için (bkz. level_up()'taki 1.2->1.12 değişikliği) daha sık kart seçileceği
## için her kartın tek başına verdiği bonus yarı yarıya düşürüldü (eski
## değerlerin yorumlarda görülebilir) - toplamda dengeyi korumak için.
##
## Kullanıcı isteği: "seviye atlarken verilen statlar %30 artsın (stat
## miktarları 2.3 3.7 tarzı olmasın, yuvarlayarak tamamla - 2.3 yerine 2.5,
## 3.7 yerine 4 gibi)". Aşağıdaki tüm kart bonusları eski değerin ×1.3'ü
## alınıp _nice_up() ile YUKARI (asla aşağı değil, kart zayıf hissettirmesin
## diye) en yakın "güzel" adıma yuvarlanarak hesaplandı - mutlak puan
## statlar (hız, zırh, hasar, menzil vb.) 0.5'in katına, yüzdesel statlar
## (kritik şans, sıyrılma, kalkan emilimi vb.) %0.5'in (0.005) katına.
func _nice_up(value: float, step: float = 0.5) -> float:
	return ceil(value / step) * step


## Kullanıcı isteği: "level atlama kartlarının tier'ı olucak, 4 tier olucak...
## ilk tierın bir kat fazla hali olarak verecek her tierda" - tier level_up_
## screen.gd'de kart başına rastgele seçilir (üst tierlar daha nadir, bkz. o
## dosyadaki TIER_WEIGHTS/_roll_tier) ve buraya iletilir. Tier N, Tier 1'in
## verdiği bonusun TAM N KATINI verir (tier=1 -> ×1, eskisiyle birebir aynı
## davranış - varsayılan parametre de bu yüzden 1).
func apply_upgrade(id: String, tier: int = 1) -> void:
	upgrade_counts[id] = upgrade_counts.get(id, 0) + 1
	## DÜZELTME (kullanıcı isteği: "level atlama kartlarının her tier başına
	## artışını %30 yapalım") - bkz. level_up_screen.gd _scaled_desc_value()
	## içindeki BİREBİR AYNI formül - ikisi de tier1=×1.0, tier2=×1.3,
	## tier3=×1.6, tier4=×1.9 versin diye asla sapamaz (kart NE YAZIYORSA
	## GERÇEKTE de o kadar uygulanmalı).
	var tier_mult: float = 1.0 + float(tier - 1) * 0.3
	match id:
		"speed":
			## Kullanıcı isteği: flat sayı yerine yüzdesel, kart başına +%4.
			speed_card_percent += 0.04 * tier_mult
		"max_health":
			var health_bonus: float = _nice_up(10.0 * 1.3) * tier_mult ## eskiden 10, +%30 -> 13
			max_health += health_bonus
			health += health_bonus
			health_changed.emit(health, max_health)
		"damage":
			## Kullanıcı isteği: kart başına saldırı gücü bonusu 2.5 -> 6.
			damage_bonus += 6.0 * tier_mult
			_apply_weapon_bonuses()
		"fire_rate":
			## Kullanıcı isteği: kart başına ateş hızı bonusu %5 -> %6.
			var fire_rate_bonus: float = 0.06 * tier_mult
			fire_rate_mult *= (1.0 - fire_rate_bonus)
			_apply_weapon_bonuses()
		"health_regen":
			## Kullanıcı isteği: level up kartlarına "can yenilenmesi" eklendi.
			## heal_regen_bonus (Öykü'nün beceri-tabanlı, GEÇİCİ regen'i) YERİNE
			## bilerek ayrı bir kalıcı biriktiriciye (heal_regen_card_bonus)
			## yazıyor - bkz. o değişkenin üstündeki not, aksi halde beceri
			## bitince bu kartın bonusu da silinirdi. _process_regen() ikisini
			## toplayıp tik başına düz can olarak uyguluyor.
			## Kullanıcı isteği: "level atlama kartlarındaki can yenilenmesi
			## oranını 0.75'den 0.50'ye düşür" - eskiden _nice_up(1.3)*0.5=0.75,
			## şimdi doğrudan 0.5.
			heal_regen_card_bonus += 0.5 * tier_mult ## eskiden 0.75
		"shield_protection":
			## DÜZELTME (kullanıcı isteği: "kalkan emilimi statının adını
			## kalkan soğurma olarak değiştir ve level atlama kartlarına
			## kalkan soğurma statlarını ekle (level başına %4). Kalkan
			## soğurma en fazla %92 olsun, fazladan kalkan soğurma maksimum
			## kalkan olarak statlara eklenecek.") - bu kart daha önce
			## level_up_screen.gd'nin UPGRADES havuzundan çıkarılmıştı, artık
			## "Kalkan Soğurma" adıyla YENİDEN eklendi (bkz. o dosya). Kart
			## başına +%4, cooldown_reduction ile AYNI şekilde bilinçli
			## olarak +%30 kart-güçlendirme çarpanına TABİ DEĞİL. Ham emilim
			## (taban+kart) en fazla %92 (SHIELD_PROTECTION_CAP) - bu kart
			## bunu AŞARSA taşan kısım doğrudan maksimum kalkana
			## (shield_max_percent) 1:1 dönüşür (kullanıcı isteği: "%1 hasar
			## emilimi %1 ekstra kalkan"), hiç kaybolmaz.
			var protection_bonus: float = 0.04 * tier_mult
			var base_absorption: float = float(_active_shield_type_data().get("absorption", 0.0))
			var uncapped_total: float = base_absorption + shield_protection_bonus + protection_bonus
			if uncapped_total > SHIELD_PROTECTION_CAP:
				var overflow: float = uncapped_total - SHIELD_PROTECTION_CAP
				shield_protection_bonus = SHIELD_PROTECTION_CAP - base_absorption
				shield_max_percent += overflow
				refresh_shield_stats() ## shield_max_percent değişti, tavanı etkiler
			else:
				shield_protection_bonus += protection_bonus
			_recompute_shield_protection()
		"crit_chance":
			var crit_chance_gain: float = _nice_up(0.025 * 1.3, 0.005) * tier_mult ## eskiden 0.025 (ondan önce 0.05), +%30 -> 0.035
			crit_chance_bonus = min(1.0, crit_chance_bonus + crit_chance_gain)
			_apply_weapon_bonuses()
		"crit_damage":
			crit_damage_bonus += _nice_up(0.125 * 1.3, 0.005) * tier_mult ## eskiden 0.125 (ondan önce 0.25), +%30 -> 0.165
			_apply_weapon_bonuses()
		"pickup_range":
			pickup_range += _nice_up(15.0 * 1.3) * tier_mult ## eskiden 15 (ondan önce 30), +%30 -> 19.5
		## DÜZELTME (kullanıcı isteği: "zırh delme olmadığından yerini kalkan
		## delme alacak") - eskiden bu kart armor_pen_percent'i arttırıyordu,
		## artık AYNI id/miktar shield_pen_percent'e uygulanıyor (bkz.
		## level_up_screen.gd UPGRADES listesindeki AYNI id'nin "Kalkan Delme"
		## olarak yeniden adlandırılması).
		"shield_pen_percent":
			var shield_pen_gain: float = _nice_up(0.05 * 1.3, 0.005) * tier_mult ## eskiden 0.05 (ondan önce 0.1), +%30 -> 0.065
			shield_pen_percent = min(1.0, shield_pen_percent + shield_pen_gain)
		"exp_gain":
			exp_gain_percent += _nice_up(0.075 * 1.3, 0.005) * tier_mult ## eskiden 0.075 (ondan önce 0.15), +%30 -> 0.10
		"luck":
			## Her 1 şans puanı yaratıkların birşey düşürme ihtimalini +%1
			## arttırır (bkz. enemy.gd _drop_gold/_drop_food, düz toplama).
			## Kullanıcı isteğiyle kart artık düz puan veriyor (eskiden 0.075,
			## çarpımsal bir yüzde idi).
			luck += _nice_up(1.0 * 1.3) * tier_mult ## eskiden 1.0, +%30 -> 1.5
		"range":
			weapon_range_bonus += _nice_up(30.0 * 1.3) * tier_mult ## eskiden 30 (ondan önce 60), +%30 -> 39
			_apply_weapon_bonuses()
		"dodge":
			## DÜZELTME (zırh kaldırıldı) - ham sıyrılma en fazla %60
			## (DODGE_CHANCE_CAP); bunu AŞAN kart puanları eskiden zırha
			## dönüşürdü, artık zırh olmadığı için basitçe cap'te duruyor
			## (taşma kaybolur).
			var dodge_gain: float = _nice_up(0.025 * 1.3, 0.005) * tier_mult ## eskiden 0.025 (ondan önce 0.05), +%30 -> 0.035
			dodge_chance = min(DODGE_CHANCE_CAP, dodge_chance + dodge_gain)
		"knockback":
			## BUG DÜZELTMESİ (kullanıcı bildirimi: "geri tepme yaratıkları geri
			## itmiyor") - kod yolu (weapon.gd _apply_knockback/projectile.gd
			## _apply_knockback -> enemy.gd apply_knockback_force) aslında
			## ÇALIŞIYORDU, sorun büyüklüktü: enemy.gd'nin itiş sönümlemesi
			## (KNOCKBACK_DECAY=1400 px/sn²) öyle hızlı ki eski 19.5'lik bonus
			## saniyenin ~%1'inde sönüp göz ile fark edilmeyen (<1px) bir itiş
			## üretiyordu - oyundaki DİĞER tüm itiş kaynakları (ör. İtici Sprey
			## eşyası _do_repel(), taban itiş 70) zaten kat kat daha büyük
			## değerler kullanıyor. Artık kart başına bonus, o zaten çalışan
			## itiş kaynaklarıyla AYNI mertebede (70) - tek kartla bile
			## gerçekten hissedilir bir itiş oluyor, birkaç kartla üst sınıra
			## (400, bkz. weapon.gd/projectile.gd min(...,400.0)) yaklaşılabilir.
			var knockback_bonus: float = 70.0 * tier_mult
			knockback_stat += knockback_bonus
			## Efektif değere de aynı miktarı ekle: öfke penceresi içinde
			## alınsa bile geçici bonus korunur, pencere dışında birebir.
			knockback_force += knockback_bonus
		"lifesteal":
			## Kullanıcı isteği: "kart seçimlerine can çalma statını ekle" -
			## lifesteal_percent zaten tam çalışan bir mekanizma (bkz.
			## on_damage_dealt, Kurt Adam'ın pasifi/öfke bonusu bunu kullanıyor),
			## sadece kartla büyütülebilen bir yolu yoktu. Diğer küçük yüzdesel
			## kartlarla (crit_chance +%2.5, dodge +%2.5) kıyasla lifesteal daha
			## güçlü bir stat olduğu için +%1 seçildi.
			## DÜZELTME (kullanıcı isteği: "Can çalma veren tüm statları %70
			## azalt (Kurt Adam ve Pençe hariç)") - +%1 -> +%0.3 (Kurt Adam'ın
			## kendi pasifi/öfke bonusu ve Pençe'nin silah-içi can çalması bu
			## genel karttan bağımsız, DOKUNULMADI).
			## SONRAKİ DÜZELTME (kullanıcı isteği: "Can çalmanı statların 1.
			## kademede 0.3 kademe başına 0.3 arttırarak tekrar düzenle") -
			## diğer TÜM statların kullandığı paylaşılan tier_mult (1.0/1.3/
			## 1.6/1.9, bkz. fonksiyon başı) yerine BİLEREK ham kademe sayısıyla
			## (tier) çarpılıyor - 1.=0.3, 2.=0.6, 3.=0.9, 4.=1.2 düz artış.
			## level_up_screen.gd _scaled_desc_value()'daki "lifesteal" özel
			## dalı bu formülle BİREBİR AYNI kalmalı (bkz. orada).
			lifesteal_percent += 0.003 * float(tier)
		"shield_amount":
			shield_max_percent += _nice_up(0.05 * 1.3, 0.005) * tier_mult ## eskiden 0.05 (ondan önce 0.10), +%30 -> 0.065
			refresh_shield_stats()
		"cooldown_reduction":
			## Yeni stat: "Bekleme Süresi Azaltma" - kart başına +%4, üst
			## sınır %60 (bkz. COOLDOWN_REDUCTION_CAP, _activate_skill/
			## _activate_skill2). Bilinçli olarak +%30 kart-güçlendirme
			## çarpanına TABİ DEĞİL - kullanıcı bu statı şimdi tanımlarken
			## değerini doğrudan %4 olarak belirtti.
			cooldown_reduction_percent = min(COOLDOWN_REDUCTION_CAP, cooldown_reduction_percent + 0.04 * tier_mult)
			## DÜZELTME (kullanıcı bildirimi #46: "bekleme süresinde azalma
			## aldığında skillerin bekleme süresi kısalmıyor") - eskiden yeni
			## oran SADECE _activate_skill/_activate_skill2 bir SONRAKİ kez
			## çağrıldığında (yani yetenek bir dahaki kullanımında) devreye
			## giriyordu; o an ZATEN bekleme süresindeyse (skill_state/
			## skill2_state == "cooldown") kalan süre eski (indirimsiz) tam
			## bekleme süresine göre saymaya devam ediyordu - ultiler gibi uzun
			## bekleme süreli yeteneklerde bu, kartın etkisini neredeyse hiç
			## hissettirmiyordu. Artık halihazırda BEKLEMEDEYSE kalan süre de
			## anında yeni orana göre ORANTILI olarak kısaltılıyor.
			if skill_state == "cooldown":
				var raw_cd: float = _skill_timing_for(get_skill_character_id()).get("cooldown", DEFAULT_SKILL_COOLDOWN)
				var new_cd: float = raw_cd * (1.0 - cooldown_reduction_percent)
				if _skill_cooldown > 0.0:
					skill_timer *= new_cd / _skill_cooldown
				_skill_cooldown = new_cd
			if skill2_state == "cooldown":
				var raw_cd2: float = _skill2_timing_for(get_skill2_id()).get("cooldown", DEFAULT_SKILL2_COOLDOWN)
				var new_cd2: float = raw_cd2 * (1.0 - cooldown_reduction_percent)
				if _skill2_cooldown > 0.0:
					skill2_timer *= new_cd2 / _skill2_cooldown
				_skill2_cooldown = new_cd2
	stats_changed.emit()


# ---------- Skills ----------

## DÜZELTME (kullanıcı isteği: "Melek karakterinin Q yeteneğinin bekleme
## süresini %30 arttır") - skill id 1 (Can Basma) Oakley'yle PAYLAŞILIYOR
## (bkz. characters.gd DEFS[10]/DEFS[2] "skill":1 notu, _skill2_timing_for
## id 10'daki AYNI paylaşım deseni) - SKILL_TIMING[1]'i doğrudan değiştirmek
## Oakley'yi de etkilerdi, bu yüzden Melek için ayrı bir bekleme süresi
## döndürülüyor, Oakley (ve varsayılan) SKILL_TIMING[1]'deki 20sn'de kalıyor.
const MELEK_CAN_BASMA_COOLDOWN := 26.0 ## 20sn * 1.3

func _skill_timing_for(char_id: int) -> Dictionary:
	if char_id == 1 and GameManager.selected_char_id == 10:
		var base: Dictionary = SKILL_TIMING.get(1, {"duration": DEFAULT_SKILL_DURATION, "cooldown": DEFAULT_SKILL_COOLDOWN})
		return {"duration": base.get("duration", DEFAULT_SKILL_DURATION), "cooldown": MELEK_CAN_BASMA_COOLDOWN}
	return SKILL_TIMING.get(char_id, {"duration": DEFAULT_SKILL_DURATION, "cooldown": DEFAULT_SKILL_COOLDOWN})


## DÜZELTME: skill2 id 10 ÜÇ karakter arasında PAYLAŞILIYOR - Şovalye (roster
## id 7, Kalkan Yenileme - kullanıcı isteği: "bekleme süresi 50 saniye
## olacak"), Melek (roster id 10, kendi asıl Kalkan Yenileme'si, paylaşılan
## tablodaki varsayılan bekleme ile) VE Oakley (roster id 2, kullanıcı
## isteği "Oakley yeni yetenekleri" ile Kalkan Yenileme'nin YERİNİ ALAN
## Sarmaşıklar - "16sn bekleme", SADECE Oakley - bkz. "Oakley ve Melek aynı
## karakter değil, Melek'e dokunma" düzeltmesi). SKILL2_TIMING[10]'u
## doğrudan değiştirmek Şovalye/Melek'i de etkilerdi, bu yüzden Şovalye ve
## Oakley için ayrı bekleme süresi döndürülüyor - "duration" (6sn, hepsinde
## aynı) paylaşılan tablodan geliyor.
const SOVALYE_KALKAN_YENILEME_COOLDOWN := 50.0
const OAKLEY_VINES_COOLDOWN := 16.0
## DÜZELTME (kullanıcı isteği: "Melek karakterinin E yeteneğinin bekleme
## süresini %15 arttır") - üstteki Şovalye/Oakley ayrımıyla AYNI desen,
## Melek'in kendi Kalkan Yenileme'si (id 10, paylaşılan varsayılan 15sn).
const MELEK_KALKAN_YENILEME_COOLDOWN := 17.25 ## 15sn * 1.15

func _skill2_timing_for(skill2_id: int) -> Dictionary:
	if skill2_id == 10:
		var base: Dictionary = SKILL2_TIMING.get(10, {"duration": DEFAULT_SKILL2_DURATION})
		if GameManager.selected_char_id == 7:
			return {"duration": base.get("duration", DEFAULT_SKILL2_DURATION), "cooldown": SOVALYE_KALKAN_YENILEME_COOLDOWN}
		if GameManager.selected_char_id == 2:
			return {"duration": base.get("duration", DEFAULT_SKILL2_DURATION), "cooldown": OAKLEY_VINES_COOLDOWN}
		if GameManager.selected_char_id == 10:
			return {"duration": base.get("duration", DEFAULT_SKILL2_DURATION), "cooldown": MELEK_KALKAN_YENILEME_COOLDOWN}
	return SKILL2_TIMING.get(skill2_id, {"duration": DEFAULT_SKILL2_DURATION, "cooldown": DEFAULT_SKILL2_COOLDOWN})


func _skill3_timing_for(skill3_id: int) -> Dictionary:
	return SKILL3_TIMING.get(skill3_id, {"duration": DEFAULT_SKILL2_DURATION, "cooldown": DEFAULT_SKILL2_COOLDOWN})


## Kullanıcı isteği: "Tüm karakterlerin Temel yetenekleri artık mevcut
## kalkanı kullanmayacak. Temel yetenekler %4 maksimum kalkan ve 20 kalkan
## eksiltecek, ultiler ise %8 maksimum kalkan ve 40 kalkan eksiltecek." -
## eski "mevcut kalkanın X%'i" formülü tamamen kaldırıldı, artık HER ZAMAN
## maksimum kalkana göre sabit bir maliyet (yüzde + düz miktar) hesaplanıyor.
## DÜZELTME (kullanıcı isteği, 2. tur: "yetenekler kullanım bedeli için
## gereken kalkan olmazsa çalışmayacak") - eskiden kalkan yetersizse (ya da
## item_shield_max=0) yetenek YİNE DE tetikleniyordu (best-effort harcama).
## Artık öyle DEĞİL - bkz. hemen aşağıdaki _has_enough_ability_shield ve
## çağıran yerlerdeki ön kontrol.
const SKILL2_SHIELD_COST_PERCENT_OF_MAX := 0.04
const SKILL2_SHIELD_COST_FLAT := 20.0
const SKILL_SHIELD_COST_PERCENT_OF_MAX := 0.08
const SKILL_SHIELD_COST_FLAT := 40.0

## DÜZELTME (kullanıcı isteği: "bundan sonra yetenekler kullanım bedeli için
## gereken kalkan olmazsa çalışmayacak") - eskiden maliyet HER ZAMAN "elde
## ne kadar kalkan varsa o kadarı harcanıp 0'da dur" şeklinde best-effort
## uygulanıyordu (bkz. altındaki yorumun eski hali), yetenek kalkan yetersiz
## olsa BİLE tetikleniyordu. Artık her karakter oyuna standart kalkanla
## başladığı için (bkz. game_manager.gd shield_standart_level) bu maliyet
## GERÇEK bir kısıt haline getirildi - bkz. _has_enough_ability_shield,
## çağıran yerlerdeki (skill/skill2/büyücü varyasyonu) ön kontrol.
func _has_enough_ability_shield(cost: float) -> bool:
	return cost <= 0.0 or item_shield_hp >= cost


func _spend_ability_shield_cost(amount: float) -> void:
	if amount <= 0.0 or item_shield_hp <= 0.0:
		return
	item_shield_hp = max(0.0, item_shield_hp - amount)
	item_shield_changed.emit(item_shield_hp, item_shield_max)


func _activate_skill2() -> void:
	var skill2_id: int = get_skill2_id()
	if skill2_id == 0:
		return
	## Kalkanla İLGİLİ yetenekler bu maliyetten muaf - kullanıcı isteği:
	## "kalkan yenileyen veya kalkanla ilgili yetenekler harcamasın." Kalkan
	## Yenileme (id 10, Şovalye'nin TEMEL/E yeteneği) kalkanı zaten
	## YENİLEDİĞİ için önce onu harcamak anlamsız/kendiyle çelişkili olurdu.
	## DÜZELTME (kullanıcı isteği: "Oakley yeni yetenekleri") - id 10 artık
	## Oakley'de FARKLI bir yetenek (Sarmaşıklar, kalkanla İLGİSİZ bir
	## hasar/sabitleme yeteneği) - SADECE Oakley için muafiyetin ARTIK bir
	## anlamı yok (Melek ve Şovalye hâlâ gerçek Kalkan Yenileme kullanıyor,
	## dolayısıyla hâlâ muaf) - bu yüzden muafiyet id YERİNE karaktere göre
	## kontrol ediliyor.
	## Yetenek Kitabı: bkz. item_skill_shield_cost_reduction üstündeki yorum.
	var skill2_shield_cost: float = (item_shield_max * SKILL2_SHIELD_COST_PERCENT_OF_MAX + SKILL2_SHIELD_COST_FLAT) * (1.0 - item_skill_shield_cost_reduction)
	var is_shield_related_skill2: bool = (skill2_id == 10 and GameManager.selected_char_id != 2)
	## Kullanıcı isteği: "Kurt adamın yetenekleri kalkan harcamamalı" - Vahşi
	## Kesik (TEMEL, skill2 id 13) Şovalye'nin Kalkan Yenileme'siyle AYNI
	## şekilde bu bedelden muaf.
	if not is_shield_related_skill2 and skill2_id != 13:
		## Kullanıcı isteği: "yetenekler kullanım bedeli için gereken kalkan
		## olmazsa çalışmayacak" - yetersizse bekleme süresine HİÇ girmeden
		## (Necromancer'ın ruh/korsan'ın bomba kontrolleriyle AYNI desen)
		## tetiklenmeden çıkılıyor.
		if not _has_enough_ability_shield(skill2_shield_cost):
			_spawn_floating_text("KALKAN YETERSİZ", Color(0.4, 0.7, 1.0))
			return
		_spend_ability_shield_cost(skill2_shield_cost)
	## Kullanıcı isteği: "yetenek kullanıldıktan sonra kalkan yenilenme hızı,
	## kalkan yenilenme bekleme süresi kadar boyunca %50 daha yavaş
	## yenilenecek" - kalkan harcansın harcanmasın HER TEMEL yetenek
	## kullanımında tetiklenir (bkz. item_shield_ability_slow_timer/
	## _process_item_shield).
	item_shield_ability_slow_timer = _shield_hit_regen_delay()
	var timing: Dictionary = _skill2_timing_for(skill2_id)
	_skill2_duration = timing["duration"]
	## Bekleme Süresi Azaltma statı (level kartı, bkz. apply_upgrade
	## "cooldown_reduction") - üst sınır COOLDOWN_REDUCTION_CAP.
	_skill2_cooldown = timing["cooldown"] * (1.0 - cooldown_reduction_percent)
	skill2_state = "active"
	skill2_timer = _skill2_duration
	skill2_total_elapsed = 0.0
	_talon_add_passive_stack()
	## DÜZELTME (kullanıcı bildirimi: "neredeyse hiçbir karakter yetenek
	## kullanımında spellcast animasyonunu kullanmıyor kullanması gerekiyor")
	## - _activate_skill() (ULTİ) bunu zaten yapıyordu, TEMEL (E) için AYNI
	## tetikleme burada eksikti (Büyücü Kız'ın kendi bypass yolu -
	## _buyucu_try_activate_variation - hariç, o zaten kendi spellcast'ini
	## çalıyor, buraya hiç ulaşmıyor).
	if is_instance_valid(anim) and anim.sprite_frames and anim.sprite_frames.has_animation("spellcast_" + facing):
		anim.play("spellcast_" + facing)
	match skill2_id:
		## id 5 (Assasin Çocuk TEMEL) artık BURAYA hiç ulaşmıyor - bkz.
		## SKILL2_TIMING[5] üstündeki not, _physics_process'te Korsan/
		## Necromancer gibi bypass ediliyor. _skill_invisibility() hâlâ
		## dosyada duruyor (zararsız, artık çağrılmıyor).
		## eski Talon TEMEL'i (Yer Sarsıntısı, id 8) - "Talon yeni skilleri"
		## isteğiyle Silah Salvosu'nun (id 36) yerine geçti.
		36: _skill_talon_weapon_salvo()
		10: _skill_kalkan_yenileme()
		11: _skill_elara_true_damage()
		13: _skill_kurtadam_slash()
		21: _skill_matthew_haste()
		## Shaman TEMEL (Saldırı Totemi) - bkz. characters.gd DEFS[12].
		27: _skill_shaman_attack_totem()


func _end_skill2_effects() -> void:
	## Talon TEMEL (Silah Salvosu, id 36) biterken silah ikonlarını normal
	## konumuna döndürür (bkz. _skill_talon_weapon_salvo/_end_talon_weapon_salvo).
	if _talon_weapon_salvo_active:
		_end_talon_weapon_salvo()
	is_kalkan_yenileme_active = false
	## Oakley TEMEL'inin (Kalkan Yenileme) tik zamanlayıcısı/müttefik hedefi.
	_oakley_e_tick_timer = 0.0
	## Kullanıcı isteği ("efekt sistemi" - kalkan.png): bkz. _end_skill_
	## effects()'teki AYNI heal temizliği notu.
	if _melek_shield_ally_aura_on and is_instance_valid(_oakley_e_ally_target):
		_set_ally_aura(_oakley_e_ally_target, "shield", false)
	_melek_shield_ally_aura_on = false
	stop_self_aura_fx("shield")
	_oakley_e_ally_target = null
	## DÜZELTME (kullanıcı bildirimi: "assasin çocuğun görünmezlik yeteneği
	## kullanıldıktan sonra görünmezliğin süresi bitince görünmezliği
	## kaybolmuyor hala görünmez kalıyor") - kök neden: Görünmezlik artık
	## TEMEL (E, skill2 id 5) yeteneği ama sıfırlaması yanlışlıkla SADECE
	## ULTİ'nin (R, skill/skill_state) bitiş fonksiyonunda (_end_skill_
	## effects) vardı - o tamamen ayrı bir zamanlayıcı/durum makinesi olduğu
	## için görünmezlik hiç kapanmıyordu. Artık gerçekten biten yerde (skill2
	## süresi dolunca çağrılan burada) kapatılıyor, saydamlık da geri alınıyor.
	is_invisible = false
	modulate.a = 1.0
	## Elara TEMEL bitince (süre doldu YA DA tüm silahların 6'şar saldırısı
	## tüketildi) her silahtaki kalan gerçek hasar hakları temizleniyor -
	## normal koşulda zaten _process_elara_true_damage hepsini 0'a indirmişken
	## çağırıyor ama erken (manuel) bitişte de garanti altına alınıyor.
	if get_skill2_id() == 11:
		for w in owned_weapon_nodes:
			if not is_instance_valid(w):
				continue
			if w.has_method("clear_true_damage_charges"):
				w.clear_true_damage_charges()
	## Matthew TEMEL (Vahşi Hız, id 21) biterken kendi hareket/saldırı hızı
	## çarpanlarını geri alır (bkz. _skill_matthew_haste) - tilki tarafı
	## zaten kendi başına is_skill2_active()'e bakıp otomatik kapanıyor.
	if get_skill2_id() == 21:
		skill2_speed_multiplier = 1.0
		for w in owned_weapon_nodes:
			if not is_instance_valid(w):
				continue
			if "fire_rate_multiplier" in w:
				w.fire_rate_multiplier = 1.0


## Üçüncü yetenek (R) - _activate_skill2()'nin birebir aynısı, kalkan bedeli
## de AYNI "temel seviyesi" tarifeyi (SKILL2_SHIELD_COST_*) kullanıyor -
## Shaman'ın totemleri kalkanla ilgili olmadığı için hiçbir muafiyet YOK.
## Kullanıcı isteği: Elara'nın yeni 3. yeteneği (id 31, Kalkan Sıçraması)
## kalkan VEREN bir yetenek olduğu için (kullanıcı isteği: "bu yetenek
## kalkan harcamaz") - _activate_skill()'in Paladin/Matthew/Büyücü
## Kız/Kurt Adam muafiyet listesiyle AYNI desen.
func _activate_skill3() -> void:
	var skill3_id: int = get_skill3_id()
	if skill3_id == 0:
		return
	## DÜZELTME (kullanıcı isteği: "Necromancer in R sini golem çıkarma ile
	## değiştir") - Golem Çağır'ın (id 20) ön kontrolleri eskiden
	## _activate_skill()'deydi (Q iken), buraya taşındı - bkz.
	## _skill_necro_summon_golem.
	if skill3_id == 20 and necro_souls < NECRO_GOLEM_SOUL_COST:
		_spawn_floating_text("RUH YETERSİZ", Color(0.6, 0.9, 0.5))
		return
	if skill3_id == 20 and _necro_active_pet_count() >= NECRO_MAX_ACTIVE_PETS:
		_spawn_floating_text("YARATIK SINIRI (10)", Color(0.9, 0.6, 0.3))
		return
	if skill3_id == 20 and _necro_active_golem_count() >= NECRO_MAX_GOLEMS:
		_spawn_floating_text("GOLEM SINIRI (2)", Color(0.75, 0.5, 1.0))
		return
	## DÜZELTME (bkz. _activate_skill()'teki eşleşen not) - Talon'un Ayna
	## Formu (R, id 37) burada ARTIK TEMEL tarifesini DEĞİL, genel ULTİ
	## tarifesini (SKILL_SHIELD_COST_*) ödüyor: 120sn bekleme süreli,
	## gerçekten ulti hissi veren yetenek bu, ağır bedeli hak ediyor -
	## Hamle Vuruşu (Q, id 38) ise artık BURADAKİ hafif tarifeyi ödüyor.
	## DÜZELTME (kullanıcı isteği: "Elaranın R ile Q yeteneğinin yerini
	## değiştir") - eskiden burada "skill3_id != 31" muafiyetiyle Kalkan
	## Sıçraması bedelsizdi; o artık Q'da (bkz. _activate_skill()'teki yeni
	## "char_id != 12" muafiyeti), id 31 şimdi Çift Tetik'in yeni evi ve
	## Ayna Formu gibi genel ULTİ tarifesini ödüyor - muafiyet tamamen
	## kaldırıldı.
	## SONRAKİ DÜZELTME (kullanıcı isteği: "Assasin çocuğun R si ile Q
	## skillinin yerini değiştir") - Gölge Hücumu (id 16) Q'dan R'ye taşındı,
	## eskiden Q'nun varsayılan AĞIR tarifesini ödüyordu (herhangi bir
	## istisnaya girmiyordu) - burada (R'nin varsayılanı HAFİF) aynı ağır/
	## ULTİ tarifeyi korumak için Ayna Formu/Çift Tetik ile AYNI listeye
	## eklendi.
	## SONRAKİ DÜZELTME (kullanıcı isteği: "Necromancer in R sini golem
	## çıkarma ile değiştir") - Golem Çağır (id 20) da AYNI sebeple
	## (eskiden Q'nun varsayılan AĞIR tarifesini ödüyordu) eklendi.
	## Oakley'nin yeni R'si (Koruyucu Büyü, id 39) de AYNI listeye eklendi -
	## eski R (Arı Sürüsü) hafif tarifedeydi ama bu yeni yetenek gerçek bir
	## ULTİ hissi veriyor (60sn bekleme, güçlü koruma) - diğer karakterlerin
	## R'deki gerçek ultileriyle (Ayna Formu/Çift Tetik/Gölge Hücumu/Golem
	## Çağır) AYNI tarife.
	var use_ulti_tier: bool = (skill3_id == 37 or skill3_id == 31 or skill3_id == 16 or skill3_id == 20 or skill3_id == 39)
	var skill3_shield_cost: float = (item_shield_max * (SKILL_SHIELD_COST_PERCENT_OF_MAX if use_ulti_tier else SKILL2_SHIELD_COST_PERCENT_OF_MAX) + (SKILL_SHIELD_COST_FLAT if use_ulti_tier else SKILL2_SHIELD_COST_FLAT)) * (1.0 - item_skill_shield_cost_reduction)
	if not _has_enough_ability_shield(skill3_shield_cost):
		_spawn_floating_text("KALKAN YETERSİZ", Color(0.4, 0.7, 1.0))
		return
	_spend_ability_shield_cost(skill3_shield_cost)
	item_shield_ability_slow_timer = _shield_hit_regen_delay()
	var timing: Dictionary = _skill3_timing_for(skill3_id)
	_skill3_duration = timing["duration"]
	_skill3_cooldown = timing["cooldown"] * (1.0 - cooldown_reduction_percent)
	skill3_state = "active"
	skill3_timer = _skill3_duration
	skill3_total_elapsed = 0.0
	_talon_add_passive_stack()
	## bkz. _activate_skill2() üstündeki AYNI düzeltme notu.
	if is_instance_valid(anim) and anim.sprite_frames and anim.sprite_frames.has_animation("spellcast_" + facing):
		anim.play("spellcast_" + facing)
	match skill3_id:
		28: _skill_shaman_area_totem()
		## DÜZELTME (kullanıcı isteği: "Elaranın R ile Q yeteneğinin yerini
		## değiştir") - Çift Tetik (eskiden Q/skill id 12) artık R'de, bkz.
		## _activate_skill()'teki eşleşen düzeltme (Kalkan Sıçraması artık
		## orada).
		31: _skill_elara_double_fire()
		## DÜZELTME (kullanıcı isteği: "Assasin çocuğun R si ile Q skillinin
		## yerini değiştir") - Gölge Adımı (id 30) artık Q'da (bkz.
		## _activate_skill()), Gölge Hücumu (id 16) buraya taşındı.
		16: _skill_assasin_dash()
		32: _skill_melek_fear()
		29: _skill_paladin_barrier()
		## DÜZELTME (kullanıcı isteği: "Oakleyin R yeteneği artık boşta kalan Q
		## yeteneği olacak") - Arı Sürüsü (id 33) Q'ya taşındı (bkz.
		## _activate_skill()'teki eşleşen düzeltme), yeni R (Koruyucu Büyü,
		## id 39) buraya geldi.
		39: _skill_oakley_bond()
		34: _skill_korsan_bombardment()
		## Talon'un yeni 3. yeteneği (Ayna Formu, id 37) - kullanıcı isteği: "R
		## ile Q'nun yerini değiştir" - eskiden R'de Hamle Vuruşu vardı.
		37: _skill_talon_mirror_form()
		## DÜZELTME (kullanıcı isteği: "Necromancer in R sini golem çıkarma ile
		## değiştir") - Golem Çağır (id 20) artık burada, eskiden Q'da.
		20: _skill_necro_summon_golem()


func _end_skill3_effects() -> void:
	match get_skill3_id():
		## DÜZELTME (kullanıcı isteği: "Assasin çocuğun R si ile Q skillinin
		## yerini değiştir") - Gölge Adımı'nın (id 30) temizliği artık Q'da
		## (bkz. _end_skill_effects()). Gölge Hücumu'nun (id 16) BURADA hiç
		## temizliği YOKTU - yanlışlıkla "tek seferlik bir sıçrayış, temizliğe
		## gerek yok" sanılmıştı, oysa is_assasin_dashing/_assasin_dash_fx/
		## modulate sıfırlaması eskiden Q'nun genel _end_skill_effects()'i
		## İÇİNDE koşulsuz yaşıyordu (dash o zaman Q'daydı). Taşıma sonrası
		## KULLANICI BİLDİRİMİ ("Assasin çocuğun q ve r si görünmezlik
		## veriyor" - aslında R "görünmez" değil, dash'in başında set edilen
		## koyu/%60 saydam modulate hiç sıfırlanmadığı için KARAKTER KALICI
		## OLARAK yarı saydam/koyu kalıyordu, görünmezlikle karıştırılmıştı):
		## kök neden buydu, artık burada da AYNI temizlik yapılıyor.
		16:
			is_assasin_dashing = false
			if _assasin_dash_fx and is_instance_valid(_assasin_dash_fx):
				if _assasin_dash_fx.has_method("stop"):
					_assasin_dash_fx.stop()
				_assasin_dash_fx = null
			## bkz. _end_skill_effects()'teki AYNI çapraz-slot koruması - Q'nun
			## Gölge Adımı'sı (id 30) HÂLÂ aktifken (kendi modulate.a=0.35
			## saydamlığını kullanıyor) buraya girilirse onu ZAMANINDAN ÖNCE
			## sıfırlamayalım.
			if not (skill_state == "active" and get_skill_character_id() == 30):
				modulate = Color(1, 1, 1, 1)
		29:
			_end_paladin_barrier()
		## DÜZELTME (kullanıcı isteği: "Elaranın R ile Q yeteneğinin yerini
		## değiştir") - Çift Tetik'in temizliği eskiden _end_skill_effects()
		## (Q/skill_state) tarafında koşulsuzdu, artık R/skill3_state'te bitiyor.
		31:
			if elara_double_fire_active:
				_end_elara_double_fire()
		## Talon'un Ayna Formu (kullanıcı isteği: "R ile Q'nun yerini değiştir"
		## sonrası artık skill3/R'de) - bkz. _skill_talon_mirror_form.
		37:
			if _talon_mirror_form_active:
				_end_talon_mirror_form()


func _activate_skill() -> void:
	var char_id: int = get_skill_character_id()
	## DÜZELTME (kullanıcı isteği: "Necromancer in R sini golem çıkarma ile
	## değiştir") - Golem Çağır'ın (id 20) ruh/yaratık-sınırı/golem-sınırı ön
	## kontrolleri artık _activate_skill3()'te (bkz. orada), Q artık İskelet
	## Çağır'ın (id 19) evi ve o kendi ruh/sınır kontrollerini
	## _skill_necro_summon_skeleton() içinde ZATEN kendi yapıyor.
	## Kullanıcı isteği: "şovalye adamın koruma baloncuğunu aktifleştirebilmek
	## için en az %20 kalkan değeri olmalı (kalkan harcamıcak sadece en az
	## %20 kalkanının olması gerek)" - Koruma Baloncuğu (id 11) kalkanı
	## TÜKETMİYOR, burada sadece bir eşik/ön koşul olarak kontrol ediliyor.
	if char_id == 11:
		var paladin_shield_ratio: float = (item_shield_hp / item_shield_max) if item_shield_max > 0.0 else 0.0
		if paladin_shield_ratio < 0.20:
			_spawn_floating_text("KALKAN YETERSİZ (%20)", Color(0.4, 0.7, 1.0))
			return
	## #39 DÜZELTME (kullanıcı bildirimi: "Korsan bomba/ulti düzenlemeleri") -
	## Korsan'ın ULTİ'si (Patlat, id 18) bırakılmış hiç bombası yokken de
	## tetiklenebiliyordu ve standart 30sn'lik TAM bekleme süresini boşa
	## başlatıyordu (kalkan bile harcanıyordu). Necromancer'ın ruh/yaratık
	## sınırı kontrolleriyle AYNI desen: bomba yoksa yetenek hiç tetiklenmez,
	## bekleme süresine girmez, kalkan harcanmaz.
	if char_id == 18 and _korsan_bombs.is_empty():
		_spawn_floating_text("BOMBA YOK", Color(1.0, 0.4, 0.4))
		return
	## Paladin'in ULTİ'si (id 11, Koruma Baloncuğu / kalkan yenilenmesi) VE
	## Matthew'ün ULTİ'si (id 9, Feda Kalkanı - yaratığı feda edip kalkan
	## çemberi kurar) kalkanla İLGİLİ/kalkan VEREN yetenekler oldukları için
	## muaf - bkz. _activate_skill2() üstündeki aynı gerekçe (kullanıcı
	## isteği #31: "kalkan veren yetenekler kalkan harcamamalı"). DÜZELTME:
	## Matthew'ün Feda Kalkanı eskiden bu istisnaya dahil DEĞİLDİ - kendi
	## kalkanını harcayıp SONRA yaratığını feda ederek başka bir kalkan
	## kuruyordu, anlamsız bir çelişkiydi.
	## Büyücü Kız'ın ULTİ'si (id 3, _skill_buyucu_switch_variation) de bu
	## bedelden muaf - kullanıcı bildirimi: "büyücü kızın Q yeteneği kalkan
	## harcıyor ama E yeteneği harcamıyor, tam tersi olmalı." Q sadece hangi
	## TEMEL varyasyonunun aktif olduğunu değiştiren bedelsiz bir aksiyon;
	## gerçek bedel artık E'de/TEMEL'de uygulanıyor (bkz.
	## _buyucu_try_activate_variation() üstündeki güncellenen yorum).
	## DÜZELTME (kullanıcı bildirimi: "talonun q su ulti olarak algılandığı için
	## çok fazla kalkan harcıyor, ultisinin R tuşu olması gerek") - Talon'un
	## Hamle Vuruşu'nu (Q/"skill" alanı, id 38) BURADAKİ genel ULTİ tarifesi
	## (SKILL_SHIELD_COST_*, 4sn'lik bekleme süresine göre ÇOK ağır) yerine
	## Ayna Formu (R/skill3, id 37 - bkz. _activate_skill3()'teki eşleşen
	## düzeltme) ile birebir aynı, hafif TEMEL tarifesi (SKILL2_SHIELD_COST_*)
	## ödüyor artık - gerçek "ulti" (uzun bekleme süreli, ağır) davranışı
	## SADECE R'ye ait olsun diye ikisi kasıtlı olarak yer değiştirdi.
	## DÜZELTME (kullanıcı bildirimi: "Melek yeteneğinin Q yeteneğinin mana
	## bedeli ulti mana bedeli olarak algılanıyor, o temel yeteneklerden biri
	## sadece") - Can Basma (id 1) Oakley'yle PAYLAŞILAN bir id olduğu için
	## (bkz. _skill_timing_for üstündeki AYNI paylaşım notu) SADECE Melek
	## (selected_char_id 10) için hafif/TEMEL tarifeye düşürülüyor - Oakley'nin
	## KENDİ Can Basma kullanımı (id 1, roster id 2) ağır/ULTİ tarifesinde
	## değişmeden kalıyor.
	var is_melek_can_basma: bool = (char_id == 1 and GameManager.selected_char_id == 10)
	## DÜZELTME (kullanıcı isteği: "Assasin çocuğun R si ile Q skillinin
	## yerini değiştir") - Gölge Adımı (id 30) R'den Q'ya taşındı, eskiden
	## R'nin varsayılan hafif tarifesini (SKILL2_SHIELD_COST_*) ödüyordu
	## (bkz. _activate_skill3()'teki use_ulti_tier - 30 orada YOKTU), burada
	## (Q'nun varsayılanı AĞIR) aynı hafif tarifeyi korumak için id 38 ile
	## AYNI istisnaya eklendi.
	var is_assasin_shadow_step: bool = (char_id == 30)
	## DÜZELTME (kullanıcı isteği: "Oakleyin R yeteneği artık boşta kalan Q
	## yeteneği olacak") - Arı Sürüsü (id 33) R'den Q'ya taşındı, eskiden
	## R'nin varsayılan hafif tarifesini ödüyordu (33, _activate_skill3()'teki
	## use_ulti_tier listesinde hiç YOKTU), aynı hafif tarifeyi korumak için
	## buraya eklendi.
	var is_oakley_bee_swarm: bool = (char_id == 33)
	## Yetenek Kitabı: bkz. item_skill_shield_cost_reduction üstündeki yorum.
	var skill_shield_cost: float = (item_shield_max * (SKILL2_SHIELD_COST_PERCENT_OF_MAX if (char_id == 38 or is_melek_can_basma or is_assasin_shadow_step or is_oakley_bee_swarm) else SKILL_SHIELD_COST_PERCENT_OF_MAX) + (SKILL2_SHIELD_COST_FLAT if (char_id == 38 or is_melek_can_basma or is_assasin_shadow_step or is_oakley_bee_swarm) else SKILL_SHIELD_COST_FLAT)) * (1.0 - item_skill_shield_cost_reduction)
	## Kullanıcı isteği: "Kurt adamın yetenekleri kalkan harcamamalı" - Kudurmuş
	## Saldırı (ULTİ, id 14) artık Koruma Baloncuğu/Feda Kalkanı/Büyü Değişimi
	## (11/9/3) ile AYNI şekilde bu bedelden muaf.
	## DÜZELTME (kullanıcı isteği: "Shamanın kalkan yeteneği kalkan
	## harcamamalı") - Kalkan Totemi (ULTİ, id 26) da kalkan VEREN bir yetenek
	## (bkz. totem_shield.gd) - üstteki "Shaman'ın totemleri kalkanla ilgili
	## olmadığı için hiçbir muafiyet YOK" notu SADECE _activate_skill3()'teki
	## Alan Totemi (id 28) için geçerliydi, Kalkan Totemi bambaşka bir
	## dispatch (_activate_skill) üzerinden çalışıyor ve o zamana kadar
	## muafiyet listesine hiç eklenmemişti.
	## DÜZELTME (kullanıcı isteği: "talonun Q yeteneğinin mana bedelini
	## kaldır") - Hamle Vuruşu (id 38) artık Koruma Baloncuğu/Feda Kalkanı/
	## Büyü Değişimi/Kudurmuş Saldırı/Kalkan Totemi (11/9/3/14/26) ile AYNI
	## şekilde bu bedelden tamamen muaf - eskiden sadece HAFİF (ulti değil
	## temel) tarifeye düşürülmüştü (bkz. yukarıdaki skill_shield_cost
	## hesabı), artık hiç kalkan harcamıyor.
	## DÜZELTME (kullanıcı isteği: "Elaranın R ile Q yeteneğinin yerini
	## değiştir") - Kalkan Sıçraması (id 12) "Kalkan harcamaz" - eskiden R/
	## skill3'teyken _activate_skill3()'ün "skill3_id != 31" muafiyetiyle
	## bedelsizdi, şimdi Q'ya taşındığı için AYNI muafiyet burada.
	if char_id != 11 and char_id != 9 and char_id != 3 and char_id != 14 and char_id != 26 and char_id != 38 and char_id != 12:
		## Kullanıcı isteği: "yetenekler kullanım bedeli için gereken kalkan
		## olmazsa çalışmayacak" - yetersizse bekleme süresine hiç girmeden
		## tetiklenmeden çıkılıyor (yukarıdaki ruh/bomba kontrolleriyle AYNI
		## desen).
		if not _has_enough_ability_shield(skill_shield_cost):
			_spawn_floating_text("KALKAN YETERSİZ", Color(0.4, 0.7, 1.0))
			return
		_spend_ability_shield_cost(skill_shield_cost)
	## bkz. _activate_skill2() üstündeki aynı yorum - ulti kullanımı da
	## (kalkanla ilgili olsa bile) kalkan yenilenmesini kısa süreliğine
	## yavaşlatır.
	item_shield_ability_slow_timer = _shield_hit_regen_delay()
	var timing: Dictionary = _skill_timing_for(char_id)
	_skill_duration = timing["duration"]
	_skill_cooldown = timing["cooldown"] * (1.0 - cooldown_reduction_percent)
	skill_state = "active"
	skill_timer = _skill_duration
	skill_total_elapsed = 0.0
	_talon_add_passive_stack()
	## Yetenek kullanımında büyü animasyonu (varsa, baktığı yöne göre).
	if is_instance_valid(anim) and anim.sprite_frames and anim.sprite_frames.has_animation("spellcast_" + facing):
		anim.play("spellcast_" + facing)
	## DÜZELTME: Büyücü Kız'ın ultisi artık "Hızlı Ateş" (10sn'lik buff) değil,
	## anlık bir varyasyon değiştirme aksiyonu (bkz. _skill_buyucu_switch_
	## variation) - buyucu_ulti_sound (buyucu_ulti.wav) ~10 saniyelik uzun/
	## dramatik bir ses klibi, 1sn'lik kısa bekleme süresiyle spam'lenebilen
	## bu yeni aksiyonda üst üste binip kakofoniye yol açardı. Kısa bir
	## "değişim" sesi artık doğrudan _skill_buyucu_switch_variation()
	## içinde çalınıyor, bu genel ses artık HİÇ tetiklenmiyor (node/preload
	## kaldırılmadı - zararsız, ileride başka bir amaçla kullanılabilir).
	match char_id:
		1: _skill_heal()
		2: _skill_rage()
		3: _skill_buyucu_switch_variation()
		4: _skill_shield()
		## eski Talon ULTİ'si (Devleşme, id 15) - "Talon yeni skilleri" isteğiyle
		## Hamle Vuruşu'nun (id 38) yerine geçti (kullanıcı isteği: "R ile Q'nun
		## yerini değiştir" - Ayna Formu R'ye, Hamle Vuruşu Q'ya taşındı).
		38: _skill_talon_dash()
		## DÜZELTME (kullanıcı bildirimi: "assasin çocuğun Q'su oakleyin Q su
		## gibi çalışıyor") - kök neden: characters.gd'de Assasin Çocuk'un
		## ULTİ'si (Gölge Hücumu) id 5'ten 16'ya taşınmıştı ama bu eşleme
		## tablosu hâlâ eski id 5'i dinliyordu - id 16 hiçbir case'e denk
		## gelmediği için en alttaki "_: _skill_heal()" varsayılanına
		## düşüyordu, yani Assasin'in Q'su GERÇEKTEN Oakley'nin Can Basma'sını
		## (id 1) çalıştırıyordu. Artık doğru id (16) dinleniyor.
		## SONRAKİ DÜZELTME (kullanıcı isteği: "Assasin çocuğun R si ile Q
		## skillinin yerini değiştir") - Gölge Hücumu (id 16) artık R'de
		## (bkz. _activate_skill3()), Gölge Adımı (id 30) buraya taşındı.
		30: _skill_assasin_invisibility_r()
		## Shaman ULTİ (Kalkan Totemi) - bkz. characters.gd DEFS[12].
		26: _skill_shaman_shield_totem()
		6: _skill_haste()
		7: _skill_heal_aura()
		## #56 DÜZELTME: _skill_berserk() (Talon'un Yer Sarsıntısı'sı) BURADA
		## (ULTİ tablosu) YANLIŞ yerdeydi - hiçbir karakterin "skill" (ulti)
		## id'si 8 olmadığı için bu case zaten hiç tetiklenmiyordu. Yer
		## Sarsıntısı Talon'un TEMEL'i (skill2 id 8) - artık _activate_skill2()
		## tablosunda çağrılıyor (bkz. o fonksiyon).
		9: _skill_shield_dome()
		11: _skill_paladin_ulti()
		## DÜZELTME (kullanıcı bildirimi: "Elaranın skilleri bozuldu Q artık
		## çalışmıyor dash atması lazımdı Q ile çünkü yerlerini değiştirmiştik
		## R ile") - bu case YANLIŞLIKLA _activate_skill2()'ye eklenmişti
		## (id 12 hiçbir zaman bir skill2_id DEĞİL - Q burada, gerçek "skill"
		## dispatch'i), asıl BURAYA (Q/skill tablosu) hiç eklenmemişti, bu
		## yüzden Q hâlâ eski Çift Tetik'i çağırıyordu. Kalkan Sıçraması
		## (eskiden R/skill3 id 31) artık Q'da, bkz. _activate_skill3()'teki
		## eşleşen düzeltme (Çift Tetik artık orada).
		12: _skill_elara_dash_refill()
		14: _skill_kurtadam_berserk()
		18: _skill_korsan_detonate_all()
		## DÜZELTME (kullanıcı isteği: "Oakleyin R yeteneği artık boşta kalan Q
		## yeteneği olacak") - Arı Sürüsü (id 33) artık burada, eskiden R/
		## skill3'teydi (bkz. _activate_skill3()'teki eşleşen düzeltme).
		33: _skill_oakley_bee_swarm()
		## DÜZELTME (kullanıcı isteği: "Necromancer in R sini golem çıkarma ile
		## değiştir") - Golem Çağır (id 20) artık R/skill3'te (bkz.
		## _activate_skill3()), İskelet Çağır (id 19) Q'ya taşındı ama kendi
		## bypass dalından çağrıldığı için (bkz. _physics_process) burada bir
		## case'e hiç ihtiyacı yok.
		_: _skill_heal()


func _end_skill_effects() -> void:
	for w in owned_weapon_nodes:
		if not is_instance_valid(w):
			continue
		if "rage_multiplier" in w:
			w.rage_multiplier = 1.0
		if "fire_rate_multiplier" in w:
			w.fire_rate_multiplier = 1.0
		if "aoe_radius_multiplier" in w:
			w.aoe_radius_multiplier = 1.0
	## DÜZELTME (kullanıcı isteği: "Assasin çocuğun R si ile Q skillinin
	## yerini değiştir") - Gölge Adımı'nın (id 30) temizliği eskiden
	## _end_skill3_effects()'teydi (R/skill3_state), şimdi id buraya (Q/
	## skill_state) taşındığı için temizliği de burada.
	if get_skill_character_id() == 30:
		_end_assasin_invisibility_r()
	## eski Talon ULTİ (Devleşme) temizliği burada YAŞIYORDU - "Talon yeni
	## skilleri" isteğiyle yerini Hamle Vuruşu (id 38, bkz. _skill_talon_dash)
	## aldı, o da tek seferlik bir hamle olduğu için burada özel bir temizliğe
	## gerek yok. Ayna Formu'nun temizliği artık R'ye taşındığı için (kullanıcı
	## isteği: "R ile Q'nun yerini değiştir") _end_skill3_effects()'te.
	is_shielded = false
	## Baloncuğun kaybolup kaybolmayacağına artık _update_shield_bubble() karar
	## verir - Sihirli Kalkan zaten sadece hasar/yenilenme sırasında kısaca
	## görünüyor, o yüzden beceri bitince genelde hemen "pop" ile kaybolur.
	## DÜZELTME (kullanıcı isteği: Assasin Çocuk'un yeni 3. yeteneği Gölge
	## Adımı, skill3 id 30, is_invisible'ı 6sn boyunca AÇIK tutar) - bu satır
	## eskiden koşulsuzdu; oyuncu ULTİ'yi (bu fonksiyonun ait olduğu skill/
	## skill_state) skill3-görünmezlik HÂLÂ aktifken kullanıp bitirirse,
	## burası görünmezliği ZAMANINDAN ÖNCE (kendi 6sn'lik skill3 süresi
	## dolmadan) kapatıyordu - collision_mask ise skill3 kendi süresini
	## dolduruncaya kadar hâlâ düşman katmanını dışlıyor, yani oyuncu
	## görünür ama yaratıkların içinden geçebilir garip bir ara duruma
	## düşüyordu. Artık skill3'ün KENDİ görünmezliği aktifken bu satır
	## atlanır - gerçek kapatma _end_skill3_effects()'te (skill3 kendi
	## süresi dolunca) olur.
	if not (skill3_state == "active" and get_skill3_id() == 30):
		is_invisible = false
	is_assasin_dashing = false
	if _assasin_dash_fx and is_instance_valid(_assasin_dash_fx):
		if _assasin_dash_fx.has_method("stop"):
			_assasin_dash_fx.stop()
		_assasin_dash_fx = null
	skill_speed_multiplier = 1.0
	heal_regen_bonus = 0.0
	## Oakley ULTİ'sinin (Can Basma) tik zamanlayıcısı/müttefik hedefi - beceri
	## erken/geç biterse bile bir sonraki kullanıma temiz başlasın diye.
	_oakley_q_tick_timer = 0.0
	## Kullanıcı isteği ("efekt sistemi" - iyileşme.png): yetenek süresi
	## dolduğunda (bağ kopmasa BİLE) hem müttefikteki hem kendi üzerindeki
	## aura kapanmalı - _process_healer_heal_tick artık skill_state!="active"
	## olunca hiç çağrılmayacağı için o geçişi kendi başına yakalayamaz,
	## temizlik burada garanti ediliyor.
	if _melek_heal_ally_aura_on and is_instance_valid(_oakley_q_ally_target):
		_set_ally_aura(_oakley_q_ally_target, "heal", false)
	_melek_heal_ally_aura_on = false
	stop_self_aura_fx("heal")
	_oakley_q_ally_target = null
	## DÜZELTME (bkz. _skill_talon_mirror_form()'daki kırmızı ton notu): bu
	## fonksiyon Q/ULTİ slotu (skill_state) bitince çalışır - Talon'un Q'su
	## (Hamle Vuruşu) sadece 0.16sn sürdüğü için SIK SIK tetiklenir. Ayna
	## Formu (R, skill3 id 37) HÂLÂ aktifken buraya girilirse (çok olağan bir
	## durum, R 15sn sürüyor) bu satır kızıl tonu ZAMANINDAN ÖNCE
	## sıfırlardı - is_invisible'ın aşağıdaki AYNI korumasıyla (skill3 id 30
	## için) BİREBİR aynı desen. Gölge Hücumu (id 16, dash'in koyu/%60 saydam
	## tonu - bkz. _skill_assasin_dash/_end_skill3_effects) da AYNI sebeple
	## eklendi.
	if not (skill3_state == "active" and (get_skill3_id() == 37 or get_skill3_id() == 16)):
		modulate = Color(1, 1, 1, 1)
	knockback_force = knockback_stat ## öfke bonusu düşer, kalıcı stat kalır
	damage_taken_mult = 1.0
	anim.scale = char_base_anim_scale
	_talon_ulti_active = false
	if matthew_dome_active:
		_pop_matthew_dome(false) ## 15s ran out on its own, no explosion
	if paladin_zone_active:
		_end_paladin_ulti()
	## Çift Tetik'in temizliği artık R'ye taşındığı için (kullanıcı isteği:
	## "Elaranın R ile Q yeteneğinin yerini değiştir") _end_skill3_effects()'te.
	if _kurtadam_berserk_active:
		_end_kurtadam_berserk()


## DÜZELTME (kullanıcı isteği #42) - _process_paladin_ulti()'nin kalkan
## bitince yaptığı "erken bitiş"iyle AYNI akış (bkz. _end_skill_effects,
## skill_state/skill_timer sıfırlaması), sadece tetikleyici burada oyuncunun
## yetenek tuşuna TEKRAR basması. _end_skill_effects() zaten hem Şovalye'nin
## (paladin_zone_active) hem Kurt Adam'ın (_kurtadam_berserk_active) kendine
## özgü temizliğini kapsıyor.
func _cancel_active_skill_early() -> void:
	if paladin_zone_active:
		_paladin_barrier_break()
	_end_skill_effects()
	skill_state = "cooldown"
	skill_timer = _skill_cooldown


## Oakley ULTİ (Can Basma, id 1) - kullanıcı isteği ile yeniden tasarlandı:
## "kendini ve yakınındaki en düşük cana sahip müttefiği maks canın %15'ini
## anında yenilesin, sonraki 6 saniye boyunca her saniye kendinin veya
## müttefiğinin %1 canı + Oakley'nin %60 saldırı gücü olacak şekilde can
## yenilemesi versin. %'lik can yenileme HEDEFİN KENDİSİNE özgüdür, saldırı
## gücü oranı ise Oakley'nin saldırı gücünden hesaplanır." Multiplayer'da
## doğru çalışması için hedef (ally) referansı saklanıp her tikte canlılığı/
## menzili yeniden kontrol ediliyor (bkz. _process_healer_heal_tick).
const OAKLEY_Q_INSTANT_PERCENT := 0.15 ## anında: hedefin kendi max canının %15'i
const OAKLEY_Q_TICK_PERCENT := 0.01 ## saniyede: hedefin kendi max canının %1'i
const OAKLEY_Q_TICK_ATTACK_RATIO := 0.60 ## saniyede: + Oakley'nin saldırı gücünün %60'ı
## DÜZELTME (kullanıcı isteği: "Melek'in can verme yeteneğinin (Q) saldırı
## gücü oranını %30'a düşür" + "oakley ve melek farklı karakterler, isim
## hatasına yol açan her neyi düzelt") - bkz. MELEK_E_TICK_ATTACK_RATIO
## üstündeki AYNI not: bu tik de Oakley VE Melek arasında paylaşılıyor, Melek
## artık KENDİ oranını kullanıyor (bkz. _process_healer_heal_tick'teki
## seçim), Oakley OAKLEY_Q_TICK_ATTACK_RATIO'da (%60) AYNEN kalıyor.
const MELEK_Q_TICK_ATTACK_RATIO := 0.30 ## saniyede: Melek'in saldırı gücünün %30'u (Oakley'den AYRI)
const OAKLEY_Q_RANGE := 300.0
const OAKLEY_Q_TICK_INTERVAL := 1.0
var _oakley_q_tick_timer: float = 0.0
var _oakley_q_ally_target: Node2D = null

## --- Melek Can Basma/Kalkan Yenileme aura efektleri ("efekt sistemi") ---
## bkz. fx_melek_ally_aura.gd dosya başı notu. _ally_aura_fx bu OYUNCUNUN
## KENDİ üzerinde gösterilen aura'ları tutar (aura_type -> Node) - hem Melek
## kendi kendine çağırdığında (kendi client'ında) HEM DE ağ üzerinden başka
## bir oyuncunun bize kalkan/can gönderdiği bildirimi geldiğinde
## (broadcast_ally_aura_start/stop, bkz. network_manager.gd) aynı iki
## fonksiyon kullanılıyor - "ally" burada HER ZAMAN "self" demek (bu Node'un
## ÜZERİNDE gösterilen aura), kimin başlattığı önemli değil.
const FxMelekHealAuraScene := preload("res://scenes/fx_melek_heal_aura.tscn")
const FxMelekShieldAuraScene := preload("res://scenes/fx_melek_shield_aura.tscn")
var _ally_aura_fx: Dictionary = {}
## _process_healer_heal_tick/_process_healer_shield_tick'teki "bağ hâlâ
## menzilde mi" geçişlerini izlemek için - aura start/stop'u sadece GERÇEK
## bir değişiklikte tetikler, her saniyelik tik'te tekrar tetiklemez.
var _melek_heal_ally_aura_on: bool = false
var _melek_shield_ally_aura_on: bool = false

func start_ally_aura_fx(aura_type: String) -> void:
	if _ally_aura_fx.has(aura_type) and is_instance_valid(_ally_aura_fx[aura_type]):
		return
	var scene: PackedScene = FxMelekHealAuraScene if aura_type == "heal" else (FxMelekShieldAuraScene if aura_type == "shield" else null)
	if not scene:
		return
	var fx := scene.instantiate()
	add_child(fx)
	_ally_aura_fx[aura_type] = fx


func stop_ally_aura_fx(aura_type: String) -> void:
	if not _ally_aura_fx.has(aura_type):
		return
	var fx = _ally_aura_fx[aura_type]
	if is_instance_valid(fx) and fx.has_method("stop_aura"):
		fx.call("stop_aura")
	_ally_aura_fx.erase(aura_type)


## BUG DÜZELTMESİ (çok oyunculu genel kontrol sırasında bulundu): Melek'in
## KENDİ üzerindeki aura'sı (self-case) _play_and_broadcast_skill_fx ile
## başlatılıyor (yerel + RPC tek çağrıda), AMA erken bitişte (yetenek süresi
## dolmadan _cancel_active_skill_early() ile iptal edilirse) SADECE yerel
## stop_ally_aura_fx() çağrılıyordu - diğer istemcilerdeki kozmetik kopya
## bundan HİÇ haberdar olmuyor, varsayılan 6sn'lik kendi zaman aşımına kadar
## oynamaya devam ediyordu (CLAUDE.md'nin tam olarak uyardığı "kastın
## ekranında doğru/kapandı, diğerinde eski efekt kalıyor" hatası). Bu
## fonksiyon yerel durdurmayla AYNI anda kendi peer id'mize de bir "durdur"
## bildirimi yayınlıyor - _resolve_aura_target (bkz. network_manager.gd)
## alıcı tarafta "bu benim kendi id'm mi" kontrolüyle doğru RemotePlayer
## kuklasını buluyor.
func stop_self_aura_fx(aura_type: String) -> void:
	stop_ally_aura_fx(aura_type)
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_ally_aura_stop.rpc(multiplayer.get_unique_id(), aura_type)


## ally'nin (RemotePlayer/yerel Player) ÜZERİNDE aura başlatır/durdurur - hem
## bu client'ta DOĞRUDAN (ally o an ekrandaki hangi node ise) hem de ağdaki
## diğer istemcilere (ally'nin KENDİ ekranı + üçüncü izleyiciler) broadcast
## eder. Pet gibi peer_id'si olmayan hedefler (bkz. _apply_heal_to_ally'deki
## AYNI "peer_id" in kontrolü) sadece yerelde gösterilir, ağ gerekmez.
func _set_ally_aura(ally: Node2D, aura_type: String, on: bool) -> void:
	if not is_instance_valid(ally):
		return
	if ally.has_method("start_ally_aura_fx") and on:
		ally.start_ally_aura_fx(aura_type)
	elif ally.has_method("stop_ally_aura_fx") and not on:
		ally.stop_ally_aura_fx(aura_type)
	if NetworkManager.is_multiplayer_active and ("peer_id" in ally):
		var target_peer_id: int = int(ally.peer_id)
		if target_peer_id > 0:
			if on:
				NetworkManager.broadcast_ally_aura_start.rpc(multiplayer.get_unique_id(), target_peer_id, aura_type)
			else:
				NetworkManager.broadcast_ally_aura_stop.rpc(target_peer_id, aura_type)


func _skill_heal() -> void:
	## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir ... can ve
	## kalkan verme de dahil bunlar pozitif olarak artacak" - iyileştirme
	## yeteneklerinde kritik, verilen canı artırıyor.
	var is_crit: bool = _roll_ability_crit()
	## DÜZELTME (kullanıcı isteği: "Melek'in Q ve E can ve kalkan yetenekleri
	## kendisine %50 daha az basmalı, dostlarına bastığı kalkan ve can
	## değişmeyecek") - SADECE Melek'in (roster id 10) kendisine giden anlık
	## can miktarı yarıya iniyor, aşağıdaki müttefik miktarı (ally_heal)
	## bundan HİÇ etkilenmiyor. Bu fonksiyon Oakley için de teorik olarak
	## erişilebilir (bkz. dosya başı "1: _skill_heal()" varsayılan dispatch)
	## ama pratikte Oakley'nin Q'su _try_oakley_flower() ile bypass edildiği
	## için buraya hiç ulaşmıyor - yine de değişiklik bilerek SADECE Melek'e
	## (== 10) scope'landı, Oakley'nin davranışına dokunulmadı.
	var self_amount_mult: float = 0.5 if GameManager.selected_char_id == 10 else 1.0
	var heal_amount: float = _apply_ability_crit(max_health * OAKLEY_Q_INSTANT_PERCENT * self_amount_mult, is_crit)
	health = min(max_health, health + heal_amount)
	health_changed.emit(health, max_health)
	_spawn_floating_text("%d" % int(round(heal_amount)), Color(0.4, 0.9, 0.45), true)

	_oakley_q_ally_target = _lowest_health_ally_in_range(OAKLEY_Q_RANGE)
	_melek_heal_ally_aura_on = false
	if _oakley_q_ally_target and is_instance_valid(_oakley_q_ally_target) and "max_health" in _oakley_q_ally_target:
		var ally_heal: float = _apply_ability_crit(_oakley_q_ally_target.max_health * OAKLEY_Q_INSTANT_PERCENT, _roll_ability_crit())
		_apply_heal_to_ally(_oakley_q_ally_target, ally_heal)
		_spawn_wave_beam_to_ally(_oakley_q_ally_target, "heal")
		## Kullanıcı isteği ("efekt sistemi" - iyileşme.png): "dost bireyin
		## içinde belirecek" - anlık iyileştirmeyle AYNI anda, tik beklemeden.
		_set_ally_aura(_oakley_q_ally_target, "heal", true)
		_melek_heal_ally_aura_on = true

	## "...ayrıca meleğin üzerindede aynı şekilde gerçekleşecek" - SADECE
	## Melek'te (Oakley bu koda pratikte hiç ulaşmıyor, bkz. yukarıdaki
	## DÜZELTME notu, ama yine de tutarlı olsun diye scope'landı).
	## _play_and_broadcast_skill_fx: CLAUDE.md'nin önerdiği standart yardımcı
	## (hem yerel instantiate hem de RPC yayını tek çağrıda).
	if GameManager.selected_char_id == 10:
		stop_self_aura_fx("heal") ## önceki kullanımdan kalmış olabilir
		_ally_aura_fx["heal"] = _play_and_broadcast_skill_fx(FxMelekHealAuraScene)

	_oakley_q_tick_timer = OAKLEY_Q_TICK_INTERVAL
	_spawn_burst(Color(0.3, 1.0, 0.4))
	
	if FxOykuHealScene:
		var fx := FxOykuHealScene.instantiate() as Node2D
		add_child(fx)
	_broadcast_skill_scene("res://scenes/fx_oyku_heal.tscn")


## Oakley'nin müttefike can verdiği HER yerde (ULTİ anlık heal + tik) kullanılan
## ortak yardımcı. Hedef bir RemotePlayer ise (yani gerçek bir ağ oyuncusu),
## doğrudan RemotePlayer.heal() çağırmak SADECE Oakley'nin ekranındaki
## kozmetik kuklayı değiştirir - o oyuncunun GERÇEK (yetkili) canı kendi
## istemcisindeki Player node'unda tutulur ve main.gd _process_multiplayer_sync
## her ~50ms'de bir Oakley'nin ekranındaki kuklayı o gerçek değerle EZER, yani
## can hiç artmamış gibi görünür/titrer. Bu yüzden hedefin "peer_id"si varsa
## NetworkManager.sync_ally_heal ile doğrudan o oyuncunun kendi istemcisine
## RPC gönderilir (bkz. _passive_melek'teki aynı desen) - gerçek can orada
## değişir ve normal senkronizasyonla herkese yayılır. peer_id'si olmayan
## yerel müttefikler (ör. Matthew'in yaratığı) eskisi gibi doğrudan .heal()
## alır.
func _apply_heal_to_ally(ally: Node2D, amount: float) -> void:
	if amount <= 0.0 or not is_instance_valid(ally):
		return
	if "peer_id" in ally:
		var target_peer_id: int = int(ally.peer_id)
		## Kendi sunucumuzda host da geçerli bir peer id'ye (1) sahip olabilir.
		if target_peer_id > 0 and NetworkManager.is_multiplayer_active:
			NetworkManager.sync_ally_heal.rpc(target_peer_id, amount)
			return
	if ally.has_method("heal"):
		ally.heal(amount)


## BUG DÜZELTMESİ (kullanıcı bildirimi: "oakley ve meleğin kalkan yenileme
## yeteneği takım arkadaşlarına kalkan vermiyor") - _apply_heal_to_ally
## (can) ile BİREBİR AYNI desen, sadece kalkan için (bkz. network_manager.gd
## sync_ally_shield_heal). _process_healer_shield_tick() eskiden müttefik
## hedefine DOĞRUDAN .heal_shield() çağırıyordu - RemotePlayer hedeflerde bu
## sadece kozmetik kuklayı etkiliyordu.
func _apply_shield_heal_to_ally(ally: Node2D, amount: float) -> void:
	if amount <= 0.0 or not is_instance_valid(ally):
		return
	if "peer_id" in ally:
		var target_peer_id: int = int(ally.peer_id)
		if target_peer_id > 0 and NetworkManager.is_multiplayer_active:
			NetworkManager.sync_ally_shield_heal.rpc(target_peer_id, amount)
			return
	if ally.has_method("heal_shield"):
		ally.heal_shield(amount)


## Dalga/ışın FX'i artık Oakley'yi (caster) her karede TAKİP eder (bkz.
## fx_wave_beam.gd start_pos güncellemesi) - eskiden başlangıç noktası
## SADECE çağrıldığı anki konumda sabit kalıyordu, Oakley hareket ederse
## ışın havada asılı kalmış gibi görünüyordu (kullanıcı bildirimi: "efekt
## oakleyi takip etmiyor sadece takım arkadaşına doğru gidiyor").
func _spawn_wave_beam_to_ally(target: Node2D, wave_type: String) -> void:
	if not is_instance_valid(target):
		return
	if FxWaveBeamScene:
		var wave: Node2D = FxWaveBeamScene.instantiate() as Node2D
		get_tree().current_scene.add_child(wave)
		if wave.has_method("setup"):
			wave.setup(global_position, target, wave_type, self)
	if NetworkManager.is_multiplayer_active:
		var target_path: String = String(target.get_path())
		var target_peer_id: int = int(target.peer_id) if "peer_id" in target else 0
		NetworkManager.broadcast_wave_fx.rpc(global_position, target_path, wave_type, multiplayer.get_unique_id(), target_peer_id)




## 6 saniyelik aktif pencere boyunca saniyede bir tetiklenir (bkz.
## OAKLEY_Q_TICK_INTERVAL) - hem Oakley'yi hem de (hâlâ menzilde/canlıysa)
## _skill_heal()'de kilitlenen müttefiği aynı anda iyileştirir. Sadece
## Oakley'nin ULTİ'si aktifken çalışır (bkz. get_skill_character_id()==1).
func _process_healer_heal_tick(delta: float) -> void:
	if skill_state != "active" or get_skill_character_id() != 1:
		return
	_oakley_q_tick_timer -= delta
	if _oakley_q_tick_timer > 0.0:
		return
	_oakley_q_tick_timer += OAKLEY_Q_TICK_INTERVAL

	## bkz. MELEK_Q_TICK_ATTACK_RATIO üstündeki DÜZELTME notu - Melek (roster
	## 10) KENDİ oranını kullanır, Oakley OAKLEY_Q_TICK_ATTACK_RATIO'da
	## değişmeden kalır.
	var attack_ratio: float = MELEK_Q_TICK_ATTACK_RATIO if GameManager.selected_char_id == 10 else OAKLEY_Q_TICK_ATTACK_RATIO
	var attack_power_bonus: float = damage_bonus * attack_ratio
	## bkz. _skill_heal()'deki AYNI Melek düzeltmesi - SADECE self_tick'e
	## uygulanıyor, ally_tick (aşağısı) attack_power_bonus'u TAM olarak kullanır.
	var self_amount_mult: float = 0.5 if GameManager.selected_char_id == 10 else 1.0

	## Kendisi: %1 kendi max canı + saldırı gücünün %60'ı. Kullanıcı isteği:
	## "bütün yetenekler kritik vuruş yapabilir" - her tik kendi kritik zarını
	## atıyor.
	var self_tick: float = _apply_ability_crit((max_health * OAKLEY_Q_TICK_PERCENT + attack_power_bonus) * self_amount_mult, _roll_ability_crit())
	if self_tick > 0.0 and health < max_health:
		health = min(max_health, health + self_tick)
		health_changed.emit(health, max_health)

	## Müttefik: %1 KENDİ max canı + Oakley'nin saldırı gücünün %60'ı - hedef
	## hâlâ geçerli/canlı VE menzildeyse (multiplayer'da hareket edebilir).
	var ally_in_range: bool = _oakley_q_ally_target and is_instance_valid(_oakley_q_ally_target) \
			and "max_health" in _oakley_q_ally_target \
			and global_position.distance_to(_oakley_q_ally_target.global_position) <= OAKLEY_Q_RANGE
	if ally_in_range:
		var ally_tick: float = _apply_ability_crit(_oakley_q_ally_target.max_health * OAKLEY_Q_TICK_PERCENT + attack_power_bonus, _roll_ability_crit())
		if ally_tick > 0.0:
			_apply_heal_to_ally(_oakley_q_ally_target, ally_tick)
			_spawn_wave_beam_to_ally(_oakley_q_ally_target, "heal")
	## Kullanıcı isteği ("efekt sistemi" - iyileşme.png): "iyileşme bağı
	## kesilirse efekt de kapanmalı" - ally_in_range HER tik'te (saniyede
	## bir) tazelendiği için, geçiş anları (bağlandı/koptu) burada yakalanıp
	## sadece o anda start/stop tetiklenir, her tik'te tekrar tetiklenmez.
	if ally_in_range and not _melek_heal_ally_aura_on:
		_set_ally_aura(_oakley_q_ally_target, "heal", true)
		_melek_heal_ally_aura_on = true
	elif not ally_in_range and _melek_heal_ally_aura_on:
		_set_ally_aura(_oakley_q_ally_target, "heal", false)
		_melek_heal_ally_aura_on = false



func _skill_rage() -> void:
	for w in owned_weapon_nodes:
		if not is_instance_valid(w):
			continue
		if "rage_multiplier" in w:
			w.rage_multiplier = 1.3
	modulate = Color(1.0, 0.55, 0.55, 1.0)
	_spawn_burst(Color(1.0, 0.2, 0.2))
	
	if FxKurtadamRageScene:
		var fx := FxKurtadamRageScene.instantiate() as Node2D
		add_child(fx)
		_broadcast_skill_scene("res://scenes/fx_kurtadam_rage.tscn")


## ---------- Büyücü Kız (roster 4, "skill": 3, TEMEL: 4 varyasyon) ----------
## Kullanıcı isteği ile eklenen yeni kit:
##   Pasif (Kadim Patlama): öldürdüğü her yaratık patlayıp çevresindeki diğer
##     yaratıklara saldırı gücünün %20'si kadar alan hasarı verir (bkz.
##     _buyucu_on_kill, on_enemy_killed/on_enemy_killed_remote).
##   TEMEL (E): 4 farklı varyasyon, her birinin KENDİ bekleme süresi ayrı ayrı
##     işler (bkz. _buyucu_variation_cooldowns, _buyucu_try_activate_variation) -
##     standart skill2_state makinesini KULLANMAZ, Korsan/Necromancer'ın
##     şarj-tabanlı TEMEL'leriyle AYNI mimari desen.
##   ULTİ (R): SADECE hangi varyasyonun aktif olduğunu değiştirir (bkz.
##     _skill_buyucu_switch_variation) - eski "Hızlı Ateş" (10sn saldırı hızı
##     buff'ı) TAMAMEN kaldırıldı.
const BUYUCU_PASSIVE_EXPLOSION_RATIO := 0.20
const BUYUCU_PASSIVE_EXPLOSION_RADIUS := 160.0

const BUYUCU_VARIATION_COUNT := 4
## skill2 kimlik uzayında Büyücü'ye ayrılmış 4 sabit id (bkz. SKILL2_TIMING) -
## characters.gd'nin statik "skill2" alanı SADECE HUD ikonunun ilk karede
## görünür olması için var, gerçek/güncel id HER ZAMAN get_skill2_id()'nin
## buyucu_variation'a göre dinamik döndürdüğü değer.
const BUYUCU_VARIATION_SKILL2_IDS: Array[int] = [22, 23, 24, 25]
const BUYUCU_VARIATION_NAMES: Array[String] = [
	"Arcane Lanet", "Don Nova", "Hortum", "Meteor Patlaması",
]

## Varyasyon 1: Arcane Lanet - yaratıklar arasında sırayla sekip her sekişte
## hasar veren bir lanet (bkz. weapon.gd'nin Şimşek Asası zincir sıçraması
## _apply_chain_jumps ile AYNI aday seçim mantığı, tek fark burada TEK bir
## lanet SIRAYLA (kısa gecikmelerle) sekiyor - Assasin Çocuk'un Gölge
## Hücumu'ndaki "çok hızlı, hiçbir şey anlaşılmıyor" bildiriminden ders).
const BUYUCU_ARCANE_BOUNCE_COUNT := 4
## Kullanıcı isteği: "büyücü kızın arcane lanetinin ... saldırı gücü oranını
## %30 dan %80e yükselt" - açıklama metni (bkz. aşağıdaki dinamik açıklama
## bloğu) bu sabiti otomatik okuyup yüzdeyi gösterdiği için ayrıca elle
## güncellemeye gerek yok.
const BUYUCU_ARCANE_BOUNCE_RATIO := 0.80
const BUYUCU_ARCANE_BOUNCE_RANGE := 280.0
const BUYUCU_ARCANE_BOUNCE_DELAY := 0.14

## Varyasyon 2: Don Nova - etraftaki TÜM yaratıkları dondurur + anlık hasar.
## enemy.gd apply_freeze_full()'ın tam donma sistemini kullanır (bkz. o
## fonksiyonun üstündeki yorum) - "donan yaratıklar hiçbir şey yapamaz".
const BUYUCU_NOVA_RADIUS := 320.0
const BUYUCU_NOVA_FREEZE_DURATION := 6.0
const BUYUCU_NOVA_DAMAGE_RATIO := 1.0

## Varyasyon 3: Hortum - bkz. fx_buyucu_tornado.gd (bağımsız, dolaşan bir
## varlık olarak ayrı bir script dosyasında implemente edildi).
const BUYUCU_TORNADO_COUNT := 3
const BUYUCU_TORNADO_DURATION := 15.0
const BUYUCU_TORNADO_HIT_RATIO := 1.20
const BUYUCU_TORNADO_HIT_INTERVAL := 1.0
const BUYUCU_TORNADO_RADIUS := 380.0
const BUYUCU_TORNADO_TOUCH_RADIUS := 46.0

## Varyasyon 4: Meteor Patlaması - 5sn hareketsiz kalıp odaklanır (bkz.
## is_buyucu_channeling/_physics_process hareket kilidi), bu süre boyunca
## etrafa telegraph edilen (kısa bir uyarı halkasıyla önceden gösterilen)
## meteorlar düşer.
const BUYUCU_METEOR_CHANNEL_TIME := 5.0
const BUYUCU_METEOR_RADIUS := 420.0
const BUYUCU_METEOR_HIT_RATIO := 1.20
const BUYUCU_METEOR_IMPACT_RADIUS := 70.0
const BUYUCU_METEOR_INTERVAL := 0.4
const BUYUCU_METEOR_TELEGRAPH_TIME := 0.5

const FxKorsanExplosionScene := preload("res://scenes/fx_korsan_explosion.tscn")
const FxLightningChainScene := preload("res://scenes/fx_lightning_chain.tscn")
const FxSkillRingScene := preload("res://scenes/fx_skill_ring.tscn")
## DÜZELTME (kullanıcı bildirimi: "büyücü kızın bazı skill efektleri
## görünmüyor ve görünenlerin de eski efektleri görünüyor, yeni efektler
## yaptırılmıştı ziva agent tarafından"): bu üç sahne (ve fx_arcane_impact.gd,
## FxArcaneSkullBounce'ın kendi içinden doğrudan preload ettiği, ayrı bir
## sahneye ihtiyacı yok) zaten scripts/ klasöründe tam çalışır halde
## duruyordu ama HİÇBİR ability fonksiyonundan çağrılmıyordu - Meteor hâlâ
## Korsan'ın bomba patlamasını (FxKorsanExplosionScene), Arcane Lanet hâlâ
## genel şimşek zinciri efektini (FxLightningChainScene) kullanıyordu.
const FxArcaneSkullBounceScene := preload("res://scenes/fx_arcane_skull_bounce.tscn")
const FxFrostNovaBurstScene := preload("res://scenes/fx_frost_nova_burst.tscn")
const FxMeteorStrikeScene := preload("res://scenes/fx_meteor_strike.tscn")
const FxBuyucuTornadoScript := preload("res://scripts/fx_buyucu_tornado.gd")

## DÜZELTME (kullanıcı isteği: "3 skill sistemine geçtiğimiz için büyücü
## kızın ultisi diğer 2 skilin varyasyonunu değiştirecek, E ve R'nin kendi
## sabit 2'şerli setleri olacak") - eskiden ULTİ 4 varyasyon arasında TEK
## TEK döngüsel geçiş yapıyordu (buyucu_variation 0->1->2->3->0) ve HEM
## E HEM R (o zaman R yoktu) bu TEK değişkeni okuyordu. Artık E ve R SABİT
## birer ikili set: Set 1 = {E: Arcane Lanet(0), R: Hortum(2)}, Set 2 =
## {E: Don Nova(1), R: Meteor Patlaması(3)} - ULTİ sadece "hangi set aktif"
## (buyucu_variation_set, 0/1) bayrağını değiştirir, İKİ slot da AYNI ANDA
## öteki sete geçer. buyucu_variation ve _buyucu_variation_cooldowns (4
## elemanlı, varyasyon id'sine göre indeksli) ALTTA YATAN depolama olarak
## AYNEN kalıyor - buyucu_variation artık "ULTİ ile döngüsel değişen" değil,
## "E ve R'nin BUYUCU_SET_*_VARIATIONS üzerinden TÜRETTİĞİ" bir değer;
## bkz. get_skill2_id/get_skill3_id/_skill_buyucu_switch_variation.
var buyucu_variation: int = 0
var buyucu_variation_set: int = 0 ## 0 veya 1 - ULTİ (Q) ile değişir
const BUYUCU_SET_E_VARIATIONS: Array[int] = [0, 1] ## E: Arcane Lanet, Don Nova
const BUYUCU_SET_R_VARIATIONS: Array[int] = [2, 3] ## R: Hortum, Meteor Patlaması
var _buyucu_variation_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
var is_buyucu_channeling: bool = false ## Meteor odaklanma kanalı - hareket kilidi
var _buyucu_meteor_channel_active: bool = false
var _buyucu_meteor_channel_timer: float = 0.0
var _buyucu_meteor_origin: Vector2 = Vector2.ZERO
var _buyucu_meteor_spawn_timer: float = 0.0
var _buyucu_active_tornadoes: Array = []


## Ana _physics_process döngüsünden her karede çağrılır (bkz. o fonksiyondaki
## _process_korsan_bombs/_process_matthew_speed_lines ile AYNI desen) -
## Büyücü Kız SEÇİLİ DEĞİLKEN tamamen no-op, başka karakterlere hiçbir
## etkisi yok.
func _process_buyucu(delta: float) -> void:
	if GameManager.selected_char_id != 4:
		return
	for i in range(BUYUCU_VARIATION_COUNT):
		if _buyucu_variation_cooldowns[i] > 0.0:
			_buyucu_variation_cooldowns[i] = max(0.0, _buyucu_variation_cooldowns[i] - delta)
	_buyucu_active_tornadoes = _buyucu_active_tornadoes.filter(func(t): return is_instance_valid(t))
	_process_buyucu_meteor(delta)


func get_buyucu_variation_name() -> String:
	return BUYUCU_VARIATION_NAMES[buyucu_variation]


## R slotu (skill3) için AYNI isim - artık E ve R BAĞIMSIZ birer sabit
## varyasyon gösterdiği için (bkz. BUYUCU_SET_E_VARIATIONS/BUYUCU_SET_R_
## VARIATIONS üstündeki yorum) hud.gd'nin skill3_icon'u da kendi setini
## okuyabilsin diye eklendi.
func get_buyucu_variation_name_r() -> String:
	return BUYUCU_VARIATION_NAMES[BUYUCU_SET_R_VARIATIONS[buyucu_variation_set]]


## DÜZELTME (Büyücü Kız rework): açıklama metni artık HERHANGİ bir varyasyon
## index'i için üretilebilsin diye parametreli hale getirildi -
## get_buyucu_variation_desc() (E slotu, eski davranış AYNEN) ve
## get_buyucu_variation_desc_r() (R slotu) İKİSİ DE bu tek fonksiyonu
## çağırıyor, metin/oran/bekleme süresi formülleri TEK YERDE kalıyor.
func _buyucu_variation_desc_for(variation: int) -> String:
	match variation:
		0:
			return "TEMEL (Arcane Lanet): yaratıklar arasında %d kez sekip her sekişte saldırı gücünün %%%d'ü kadar hasar verir. (%.0fsn bekleme)" % [
				BUYUCU_ARCANE_BOUNCE_COUNT, int(BUYUCU_ARCANE_BOUNCE_RATIO * 100.0), float(SKILL2_TIMING[22]["cooldown"])]
		1:
			return "TEMEL (Don Nova): etraftaki tüm yaratıkları %.0fsn dondurur (hiçbir şey yapamazlar) ve saldırı gücünün %%%d'ü kadar hasar verir. (%.0fsn bekleme)" % [
				BUYUCU_NOVA_FREEZE_DURATION, int(BUYUCU_NOVA_DAMAGE_RATIO * 100.0), float(SKILL2_TIMING[23]["cooldown"])]
		2:
			return "R YETENEĞİ (Hortum): %.0fsn boyunca dolaşan %d hortum çıkarır, her biri değdiği yaratığa saniyede en fazla 1 kez saldırı gücünün %%%d'ü kadar hasar verir. (%.0fsn bekleme)" % [
				BUYUCU_TORNADO_DURATION, BUYUCU_TORNADO_COUNT, int(BUYUCU_TORNADO_HIT_RATIO * 100.0), float(SKILL2_TIMING[24]["cooldown"])]
		3:
			return "R YETENEĞİ (Meteor Patlaması): %.0fsn hareketsiz odaklanıp etrafa saldırı gücünün %%%d'ü kadar hasar veren meteorlar yağdırır. (%.0fsn bekleme)" % [
				BUYUCU_METEOR_CHANNEL_TIME, int(BUYUCU_METEOR_HIT_RATIO * 100.0), float(SKILL2_TIMING[25]["cooldown"])]
		_:
			return ""


func get_buyucu_variation_desc() -> String:
	return _buyucu_variation_desc_for(buyucu_variation)


func get_buyucu_variation_desc_r() -> String:
	return _buyucu_variation_desc_for(BUYUCU_SET_R_VARIATIONS[buyucu_variation_set])


func get_buyucu_variation_cooldown_remaining() -> float:
	return _buyucu_variation_cooldowns[buyucu_variation]


func get_buyucu_variation_cooldown_remaining_r() -> float:
	return _buyucu_variation_cooldowns[BUYUCU_SET_R_VARIATIONS[buyucu_variation_set]]


## ULTİ (Q) - artık aktif bir efekt DEĞİL, SADECE E ve R'nin hangi SABİT
## sette olduğunu (Set 1: E=Arcane Lanet/R=Hortum, Set 2: E=Don Nova/
## R=Meteor Patlaması) İKİSİNİ BİRDEN değiştirir (bkz. buyucu_variation_set/
## BUYUCU_SET_E_VARIATIONS/BUYUCU_SET_R_VARIATIONS üstündeki yorum).
## buyucu_variation, E slotunun o anki varyasyonunu YANSITAN bir "yansıma"
## değişkeni olarak burada senkron tutuluyor - get_buyucu_variation_name/
## desc/cooldown_remaining (E'nin HUD gösterimi) DEĞİŞMEDEN çalışmaya devam
## etsin diye.
const FxMageSwapScene := preload("res://scenes/fx_mage_swap.tscn")

func _skill_buyucu_switch_variation() -> void:
	buyucu_variation_set = 1 - buyucu_variation_set
	buyucu_variation = BUYUCU_SET_E_VARIATIONS[buyucu_variation_set]
	_spawn_floating_text(BUYUCU_VARIATION_NAMES[buyucu_variation], Color(0.75, 0.45, 1.0))
	_spawn_burst(Color(0.6, 0.3, 0.9))
	## Kullanıcı isteği ("efekt sistemi"): "bu efekt büyücü kız her Q ile
	## yeteneklerini değiştirdiğinde üstünde gösterilecek" - _play_and_
	## broadcast_skill_fx TEK çağrıda hem yerel instantiate'ı hem de diğer
	## istemcilere RPC yayınını yapıyor (bkz. CLAUDE.md - iki ayrı yer asla
	## sapamaz).
	_play_and_broadcast_skill_fx(FxMageSwapScene)
	## Kısa/tiz bir "büyü değişimi" sesi - eski buyucu_ulti_sound (10sn'lik
	## dramatik klip) artık burada KULLANILMIYOR (bkz. _activate_skill()
	## üstündeki yorum), bu aksiyon anlık ve sık tetiklenebilir olduğu için.
	## DÜZELTME (derin multiplayer denetimi): elle AudioStreamPlayer2D
	## kurmak yerine _play_networked_sound kullanılıyor artık - eski hali
	## sesi sadece yerelde çalıyordu, uzak oyuncular büyü değişimini hiç
	## duymuyordu.
	_play_networked_sound("res://assets/audio/arcane_attack.mp3", randf_range(1.35, 1.55), -4.0)


## TEMEL (E) - Korsan'ın Saatli Bomba'sı/Necromancer'ın İskelet Çağır'ıyla
## AYNI mimari desen: standart skill2_state == "ready" bekleme makinesini
## KULLANMAZ, her varyasyonun KENDİ bekleme süresini (_buyucu_variation_
## cooldowns) doğrudan kontrol eder - bir varyasyonu kullanıp ULTİ ile başka
## birine geçmek O VARYASYONUN bekleme süresini atlatmaz, her biri bağımsız
## ilerler.
func _buyucu_try_activate_variation() -> void:
	## DÜZELTME (Büyücü Kız rework): buyucu_variation, _skill_buyucu_switch_
	## variation()'da HER SET DEĞİŞİMİNDE zaten BUYUCU_SET_E_VARIATIONS[
	## buyucu_variation_set]'e senkronlanıyor - burada AYRICA senkronlayıp
	## olası bir gelecekteki sapmayı (iki yerin farklı şey söylemesi,
	## CLAUDE.md'nin tam da uyardığı hata sınıfı) baştan engelliyoruz.
	buyucu_variation = BUYUCU_SET_E_VARIATIONS[buyucu_variation_set]
	if _buyucu_variation_cooldowns[buyucu_variation] > 0.0:
		return
	## DÜZELTME (kullanıcı bildirimi: "büyücü kızın Q yeteneği kalkan harcıyor
	## ama E yeteneği harcamıyor, tam tersi olmalı") - eskiden burada (TEMEL/E)
	## hiç kalkan bedeli alınmıyordu, ULTİ (Q, _skill_buyucu_switch_variation)
	## ise _activate_skill()'in standart ULTİ bedelini ödüyordu - istenenin TAM
	## TERSİYDİ. Artık diğer karakterlerin TEMEL'leriyle (_activate_skill2())
	## AYNI standart kalkan bedeli burada uygulanıyor; Q ise _activate_skill()
	## içindeki ayrı muafiyetle (char_id != 3) bedelsiz kalıyor.
	## Yetenek Kitabı: bkz. item_skill_shield_cost_reduction üstündeki yorum.
	var skill2_shield_cost: float = (item_shield_max * SKILL2_SHIELD_COST_PERCENT_OF_MAX + SKILL2_SHIELD_COST_FLAT) * (1.0 - item_skill_shield_cost_reduction)
	if not _has_enough_ability_shield(skill2_shield_cost):
		_spawn_floating_text("KALKAN YETERSİZ", Color(0.4, 0.7, 1.0))
		return
	_spend_ability_shield_cost(skill2_shield_cost)
	item_shield_ability_slow_timer = _shield_hit_regen_delay()
	var timing: Dictionary = _skill2_timing_for(BUYUCU_VARIATION_SKILL2_IDS[buyucu_variation])
	_buyucu_variation_cooldowns[buyucu_variation] = float(timing["cooldown"]) * (1.0 - cooldown_reduction_percent)
	if is_instance_valid(anim) and anim.sprite_frames and anim.sprite_frames.has_animation("spellcast_" + facing):
		anim.play("spellcast_" + facing)
	match buyucu_variation:
		0: _skill_buyucu_arcane_curse()
		1: _skill_buyucu_frost_nova()
		2: _skill_buyucu_tornado()
		3: _skill_buyucu_meteor()


## R YETENEĞİ (skill3) - _buyucu_try_activate_variation()'ın (E/TEMEL)
## BİREBİR yapısal kopyası, tek fark BUYUCU_SET_E_VARIATIONS yerine
## BUYUCU_SET_R_VARIATIONS okuması. Standart skill3_state == "ready" bekleme
## makinesini KULLANMAZ (Şovalye'nin totemleri/Shaman'ın skill3'ü gibi
## DEĞİL) - E'yle AYNI şekilde _buyucu_variation_cooldowns'daki KENDİ
## bağımsız bekleme sayacını doğrudan kontrol eder. player.gd'nin
## _activate_skill3() dispatch'i BUYUCU_VARIATION_SKILL2_IDS için bu
## fonksiyona yönlendiriyor (bkz. _physics_process skill3 input dalı) -
## _activate_skill3() Büyücü Kız'ın R'si için HİÇ ÇAĞRILMAZ.
func _buyucu_try_activate_variation_r() -> void:
	var variation: int = BUYUCU_SET_R_VARIATIONS[buyucu_variation_set]
	if _buyucu_variation_cooldowns[variation] > 0.0:
		return
	## bkz. _buyucu_try_activate_variation() üstündeki AYNI kalkan bedeli notu.
	var skill3_shield_cost: float = (item_shield_max * SKILL2_SHIELD_COST_PERCENT_OF_MAX + SKILL2_SHIELD_COST_FLAT) * (1.0 - item_skill_shield_cost_reduction)
	if not _has_enough_ability_shield(skill3_shield_cost):
		_spawn_floating_text("KALKAN YETERSİZ", Color(0.4, 0.7, 1.0))
		return
	_spend_ability_shield_cost(skill3_shield_cost)
	item_shield_ability_slow_timer = _shield_hit_regen_delay()
	var timing: Dictionary = _skill2_timing_for(BUYUCU_VARIATION_SKILL2_IDS[variation])
	_buyucu_variation_cooldowns[variation] = float(timing["cooldown"]) * (1.0 - cooldown_reduction_percent)
	if is_instance_valid(anim) and anim.sprite_frames and anim.sprite_frames.has_animation("spellcast_" + facing):
		anim.play("spellcast_" + facing)
	match variation:
		2: _skill_buyucu_tornado()
		3: _skill_buyucu_meteor()


## Pasif (Kadim Patlama): "her bir yaratık öldürdüğünde yaratık patlayarak
## etrafındaki diğer yaratıklara saldırı gücünün %20'si kadar alan hasarı
## verir" - on_enemy_killed/on_enemy_killed_remote üzerinden hem host'ta
## bizzat öldürülen hem de multiplayer'da bir istemcinin öldürdüğü
## durumlarda tetiklenir (bkz. o fonksiyonlar).
func _buyucu_on_kill(pos: Vector2) -> void:
	## Kullanıcı isteği: alan hasarı global %33 etkinlik (bkz. GameManager.
	## AOE_DAMAGE_EFFECTIVENESS).
	var dmg: float = damage_bonus * BUYUCU_PASSIVE_EXPLOSION_RATIO * GameManager.AOE_DAMAGE_EFFECTIVENESS
	if dmg <= 0.0:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if pos.distance_to(e.global_position) > BUYUCU_PASSIVE_EXPLOSION_RADIUS:
			continue
		if e.has_method("take_damage"):
			e.take_damage(dmg, false)
	_spawn_world_explosion_fx(pos)


## Sabit bir DÜNYA konumunda (oyuncunun güncel konumu değil - öldürülen
## yaratık oyuncudan uzakta olabilir) patlama görseli+sesi oluşturur ve
## multiplayer'da senkronize eder. "melee_hit" broadcast'i (bkz.
## network_manager.gd) global_position = pos atadığı için tam olarak bunun
## için uygun - Assasin Çocuk'un Gölge Hücumu'ndaki _spawn_assasin_dash_
## hit_fx ile AYNI desen. fx_korsan_explosion.tscn kendi patlama sesini
## zaten içeriyor, ayrıca sound_path taşımaya gerek yok.

func _spawn_world_explosion_fx(pos: Vector2) -> void:
	if not FxMagePassiveBurstScene:
		return
	var fx: Node2D = FxMagePassiveBurstScene.instantiate() as Node2D
	get_tree().current_scene.add_child(fx)
	fx.global_position = pos
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "melee_hit", pos, {
			"scene_path": "res://scenes/fx_mage_passive_burst.tscn",
		})


## Verilen dünya konumundan başlayarak menzil içindeki en yakın yaratığı
## (exclude listesindekiler hariç) döner - weapon.gd'nin Şimşek Asası zincir
## sıçramasındaki aday seçimiyle AYNI mantık.
func _find_closest_enemy_in_range(origin: Vector2, max_range: float, exclude: Array = []) -> Node2D:
	var closest: Node2D = null
	var min_d: float = max_range
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if e in exclude:
			continue
		var d: float = origin.distance_to(e.global_position)
		if d <= min_d:
			min_d = d
			closest = e
	return closest


## Oyuncu merkezli, İSTENEN yarıçapta bir halka efekti - _spawn_ring()'in
## (her zaman 120px sabit) genelleştirilmiş hâli, AOE'nin gerçek boyutunu
## doğru yansıtması gereken yetenekler için (Don Nova/Hortum/Meteor kanalı).
## "skill_ring" broadcast'i uzak oyuncularda rp'nin KENDİ güncel konumuna
## göre çiziliyor (bkz. remote_player.gd _spawn_ring_vfx) - bu üç yetenek de
## zaten döken oyuncunun ÜZERİNDE/etrafında olduğu için doğru.
func _spawn_ring_sized(radius: float, color: Color) -> void:
	if not FxSkillRingScene:
		return
	var ring: Node2D = FxSkillRingScene.instantiate() as Node2D
	get_tree().current_scene.add_child(ring)
	ring.global_position = global_position
	if ring.has_method("setup"):
		ring.setup(radius, color)
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "skill_ring", global_position, {
			"radius": radius,
			"color": color,
		})


## Meteor telegraph halkaları İÇİN - oyuncudan uzak, rastgele bir dünya
## konumunda çizilir. Bilerek SADECE yerel (broadcast edilmiyor): "skill_ring"
## mekanizması uzak oyuncularda her zaman rp'nin kendi konumuna göre çizildiği
## için (bkz. yukarısı) merkez-dışı bir telegraph'ı doğru gösteremezdi -
## asıl önemli/paylaşılan kısım olan patlama görseli zaten _spawn_world_
## explosion_fx ile doğru dünya konumunda senkronize ediliyor.
## DÜZELTME (kullanıcı bildirimi: "büyücü kızın bazı skill efektleri
## görünmüyor"): bu uyarı halkası (Meteor'un "buraya düşecek" telegraph'ı)
## eskiden SADECE bu istemcide (adın "_local" olması bilerek/isteyerek
## değildi, unutulmuş bir eksiklikti) çiziliyordu, diğer oyunculara HİÇ
## yayınlanmıyordu - onlar telegraph'ı hiç görmeden aniden patlamayı
## görüyordu. Artık "hitscan_impact" ile (bkz. network_manager.gd, artık
## radius/color de taşıyor) diğer istemcilere de yayınlanıyor.
func _spawn_local_telegraph_ring(pos: Vector2, radius: float, color: Color) -> void:
	if not FxSkillRingScene:
		return
	var ring: Node2D = FxSkillRingScene.instantiate() as Node2D
	get_tree().current_scene.add_child(ring)
	ring.global_position = pos
	if ring.has_method("setup"):
		ring.setup(radius, color)
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "hitscan_impact", pos, {
			"scene_path": "res://scenes/fx_skill_ring.tscn",
			"radius": radius,
			"color": color,
		})


## Bir sesi hem yerel olarak hem de (varsa) multiplayer'da broadcast eder -
## "weapon_sound" mekanizması (bkz. network_manager.gd) zaten genel amaçlı,
## rp'ye eklenip çalınıyor.
func _play_networked_sound(path: String, pitch: float, volume_db: float = 0.0) -> void:
	var stream: AudioStream = load(path) as AudioStream
	if not stream:
		return
	var asp := AudioStreamPlayer2D.new()
	get_tree().current_scene.add_child(asp)
	asp.global_position = global_position
	asp.stream = stream
	asp.pitch_scale = pitch
	asp.volume_db = volume_db
	asp.max_distance = 1500.0
	asp.finished.connect(asp.queue_free)
	asp.play()
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "weapon_sound", global_position, {
			"sound_path": path,
			"pitch": pitch,
			"volume_db": volume_db,
		})


## Varyasyon 1: Arcane Lanet - en yakın yaratıktan başlayıp sırayla en fazla
## BUYUCU_ARCANE_BOUNCE_COUNT farklı yaratığa sekip her sekişte saldırı
## gücünün %30'u kadar hasar verir.
func _skill_buyucu_arcane_curse() -> void:
	var start: Node2D = _find_closest_enemy_in_range(global_position, BUYUCU_ARCANE_BOUNCE_RANGE)
	if not start:
		_spawn_floating_text("HEDEF YOK", Color(0.7, 0.5, 1.0))
		return
	_spawn_burst(Color(0.55, 0.25, 0.95))
	_run_buyucu_arcane_bounce(start)


## await ile SIRAYLA sekiyor (aynı anda değil) - kullanıcının Assasin
## Çocuk'un Gölge Hücumu için verdiği "çok hızlı, hiçbir şey anlaşılmıyor"
## geri bildiriminden ders: her sekme net görülebilsin diye aralarında kısa
## bir gecikme var (bkz. BUYUCU_ARCANE_BOUNCE_DELAY). _skill_assasin_dash()
## ile AYNI "fire and forget" await deseni - çağıran taraf beklemiyor.
func _run_buyucu_arcane_bounce(first_target: Node2D) -> void:
	var dmg: float = damage_bonus * BUYUCU_ARCANE_BOUNCE_RATIO
	var visited: Array = []
	var current_from: Node2D = self
	var current_target: Node2D = first_target
	for i in range(BUYUCU_ARCANE_BOUNCE_COUNT):
		if not is_instance_valid(current_target) or current_target.get("is_dead") == true:
			break
		visited.append(current_target)
		if current_target.has_method("take_damage"):
			## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir" -
			## her sekiş kendi başına ayrı bir kritik zarı atıyor.
			var is_crit: bool = _roll_ability_crit()
			current_target.take_damage(_apply_ability_crit(dmg, is_crit), is_crit)
		_spawn_arcane_bounce_fx(current_from, current_target)
		current_from = current_target
		if i < BUYUCU_ARCANE_BOUNCE_COUNT - 1:
			await get_tree().create_timer(BUYUCU_ARCANE_BOUNCE_DELAY).timeout
			var next_target: Node2D = _find_closest_enemy_in_range(current_target.global_position, BUYUCU_ARCANE_BOUNCE_RANGE, visited)
			if not next_target:
				break
			current_target = next_target


## DÜZELTME (kullanıcı bildirimi: "yeni efektler yaptırılmıştı ziva agent
## tarafından ama görünmüyor/eskisi görünüyor"): eskiden weapon.gd'nin genel
## şimşek zinciri efektini (fx_lightning_chain.tscn/"chain_lightning") ödünç
## alıyordu - "arcane temalı bir sıçrama" olarak makul ama Büyücü Kız'a özel
## üretilmiş mor piksel kafatası efekti (fx_arcane_skull_bounce.gd - hedeften
## hedefe uçan kafatası + iz + çarpma patlaması) zaten vardı, hiç
## kullanılmıyordu. Artık o kullanılıyor - "chain_lightning" broadcast'iyle
## AYNI iskelet üzerinden kendi vfx_type'ı ("arcane_skull_bounce", bkz.
## network_manager.gd) ile yayınlanıyor.
func _spawn_arcane_bounce_fx(from_node: Node2D, to_node: Node2D) -> void:
	if not is_instance_valid(to_node):
		return
	if FxArcaneSkullBounceScene:
		var fx: Node2D = FxArcaneSkullBounceScene.instantiate() as Node2D
		get_tree().current_scene.add_child(fx)
		if fx.has_method("setup"):
			fx.setup(from_node.global_position if is_instance_valid(from_node) else global_position, to_node)
	if NetworkManager.is_multiplayer_active and not NetworkManager.should_throttle("buyucu_chain_%d" % multiplayer.get_unique_id(), 0.05):
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "arcane_skull_bounce", to_node.global_position, {
			"from_pos": from_node.global_position if is_instance_valid(from_node) else global_position,
		})


## Varyasyon 2: Don Nova - "etrafındaki tüm yaratıkları 6 saniye boyunca
## dondurur ve saldırı gücünün %100'ü kadar hasar verir."
func _skill_buyucu_frost_nova() -> void:
	var dmg: float = damage_bonus * BUYUCU_NOVA_DAMAGE_RATIO
	var hit_any: bool = false
	## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir" - Don
	## Nova'nın tüm alan hasarı TEK bir kritik zarına bağlı (aynı anda vurduğu
	## herkese aynı sonuç uygulanır, Meteor'un tek patlamasıyla AYNI mantık).
	var is_crit: bool = _roll_ability_crit()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if global_position.distance_to(e.global_position) > BUYUCU_NOVA_RADIUS:
			continue
		hit_any = true
		if e.has_method("take_damage"):
			e.take_damage(_apply_ability_crit(dmg, is_crit), is_crit)
		if e.has_method("apply_freeze_full"):
			e.apply_freeze_full(BUYUCU_NOVA_FREEZE_DURATION)
	## DÜZELTME (kullanıcı bildirimi: "büyücü kızın don nova yeteneği sanırım
	## görünmüyor" + sonraki tur "yeni efektler yaptırılmıştı ziva agent
	## tarafından ama görünmüyor/eskisi görünüyor"): fx_frost_nova_burst.gd
	## (radial buz şoku halkası + 28 donuk rüzgar parçacığı + animasyonlu buz
	## patlaması) zaten tam çalışır halde vardı ama hiç çağrılmıyordu - bunun
	## yerine generic _spawn_ring_sized/_spawn_burst (herhangi bir yetenek
	## için kullanılan, temaya özgü olmayan çizimler) kullanılıyordu. max_radius
	## varsayılanı (320.0) zaten BUYUCU_NOVA_RADIUS ile birebir eşleştiği için
	## ekstra bir setup() çağrısına gerek yok.
	modulate = Color(0.55, 0.85, 1.0, 1.0)
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if is_instance_valid(self):
			modulate = Color(1.0, 1.0, 1.0, 1.0)
	)
	if FxFrostNovaBurstScene:
		var nova_fx: Node2D = FxFrostNovaBurstScene.instantiate() as Node2D
		get_tree().current_scene.add_child(nova_fx)
		nova_fx.global_position = global_position
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "hitscan_impact", global_position, {
			"scene_path": "res://scenes/fx_frost_nova_burst.tscn",
		})
	_play_networked_sound("res://assets/audio/buz_asasi_freeze.mp3", 1.0, -3.0)
	if not hit_any:
		_spawn_floating_text("HEDEF YOK", Color(0.6, 0.85, 1.0))


## Varyasyon 3: Hortum - "etrafına 3 adet hortum gönderir, 15 saniye
## boyunca rasgele konumlarda yaratıklara doğru hareket ederek her temas
## ettiğinde (saniyede en fazla 1 kez) hasar verir." Gerçek hareket/hasar
## mantığı fx_buyucu_tornado.gd'de (bkz. o dosyanın kapsam notu).
## DÜZELTME (kullanıcı bildirimi: "bazı karakterler ve yetenekleri
## multiplayerda çalışmıyor ve görünmüyor"): hortumların GÖRSEL kopyası
## eskiden hiç diğer istemcilere yayınlanmıyordu (hasar zaten host-yetkili
## take_damage() ile senkronize oluyordu, ama efektin kendisi sadece döken
## oyuncunun ekranında vardı). Artık Necromancer'ın iskelet/golem'leriyle
## AYNI broadcast_pet_spawn/despawn/state deseni kullanılıyor (bkz.
## fx_buyucu_tornado.gd'deki AYNI düzeltme notu).

func _skill_buyucu_tornado() -> void:
	var dmg: float = damage_bonus * BUYUCU_TORNADO_HIT_RATIO
	for i in range(BUYUCU_TORNADO_COUNT):
		if not FxBuyucuTornadoScene:
			continue
		var t := FxBuyucuTornadoScene.instantiate() as Node2D
		get_tree().current_scene.add_child(t)
		t.setup(self, global_position, BUYUCU_TORNADO_RADIUS, dmg, BUYUCU_TORNADO_HIT_INTERVAL, BUYUCU_TORNADO_DURATION, BUYUCU_TORNADO_TOUCH_RADIUS)
		_buyucu_active_tornadoes.append(t)
		if NetworkManager.is_multiplayer_active:
			var instance_id: String = str(t.get_instance_id())
			t.network_instance_id = instance_id
			NetworkManager.broadcast_pet_spawn.rpc(multiplayer.get_unique_id(), "res://scenes/fx_buyucu_tornado.tscn", instance_id)
			## Hortum kendi ömrü bitince (bkz. fx_buyucu_tornado.gd _process
			## lifetime kontrolü) kendi kendine queue_free() çağırıyor - bu
			## dinleyici o anı yakalayıp kozmetik kopyayı da diğer
			## istemcilerde kaldırıyor (Necromancer pet'lerinde despawn
			## AYRI bir "died" sinyaliyle tetiklenir, ama bu efektin öyle bir
			## sinyali yok - tree_exiting en güvenilir/genel yakalama noktası).
			t.tree_exiting.connect(func() -> void:
				if NetworkManager.is_multiplayer_active:
					NetworkManager.broadcast_pet_despawn.rpc(multiplayer.get_unique_id(), instance_id)
			)
	_spawn_ring_sized(BUYUCU_TORNADO_RADIUS, Color(0.7, 0.85, 0.95))
	_spawn_burst(Color(0.75, 0.88, 0.95))
	_play_networked_sound("res://assets/audio/boomerang_spin.mp3", 0.85, -6.0)


## Varyasyon 4: Meteor Patlaması - "5 saniye boyunca hareketsiz kalıp
## odaklanır ve etrafında geniş bir alana rasgele meteorlar düşürür."
## Kanal boyunca is_buyucu_channeling ile hareket kilitlenir (bkz.
## _physics_process), gerçek meteor yağmuru _process_buyucu_meteor() +
## _spawn_buyucu_meteor_strike() tarafından yürütülür.
func _skill_buyucu_meteor() -> void:
	_buyucu_meteor_channel_active = true
	is_buyucu_channeling = true
	_buyucu_meteor_channel_timer = BUYUCU_METEOR_CHANNEL_TIME
	_buyucu_meteor_origin = global_position
	_buyucu_meteor_spawn_timer = 0.0
	modulate = Color(1.0, 0.55, 0.3, 1.0)
	_spawn_ring_sized(BUYUCU_METEOR_RADIUS, Color(1.0, 0.5, 0.2))
	_play_networked_sound("res://assets/audio/buyucu_ulti.wav", 1.0, -4.0)


func _process_buyucu_meteor(delta: float) -> void:
	if not _buyucu_meteor_channel_active:
		return
	## Kanal boyunca odaklanma (spellcast) animasyonunu sürekli döngüde tutar
	## - _update_animation() zaten "spellcast" ile başlayan animasyonları
	## anim.is_playing() true iken EZMİYOR (bkz. o fonksiyonun en başı), bu
	## yüzden sadece bittiğinde yeniden başlatmak yeterli.
	if is_instance_valid(anim) and anim.sprite_frames and anim.sprite_frames.has_animation("spellcast_" + facing) and not anim.is_playing():
		anim.play("spellcast_" + facing)
	_buyucu_meteor_channel_timer -= delta
	_buyucu_meteor_spawn_timer -= delta
	if _buyucu_meteor_spawn_timer <= 0.0:
		_buyucu_meteor_spawn_timer = BUYUCU_METEOR_INTERVAL
		_spawn_buyucu_meteor_strike()
	if _buyucu_meteor_channel_timer <= 0.0:
		_buyucu_meteor_channel_active = false
		is_buyucu_channeling = false
		modulate = Color(1.0, 1.0, 1.0, 1.0)


## Tek bir meteor: rastgele bir konumda kısa bir uyarı halkası belirir,
## BUYUCU_METEOR_TELEGRAPH_TIME kadar sonra o noktaya hasar verip patlar -
## "gökten meteor düşme" hissi için okunabilir bir gecikme (Assasin Çocuk'un
## Gölge Hücumu düzeltmelerinden aynı ders: ani/anlaşılmaz yerine telegraph'lı).
func _spawn_buyucu_meteor_strike() -> void:
	var angle: float = randf() * TAU
	var dist: float = randf_range(0.0, BUYUCU_METEOR_RADIUS)
	var strike_pos: Vector2 = _buyucu_meteor_origin + Vector2(cos(angle), sin(angle)) * dist
	_spawn_local_telegraph_ring(strike_pos, BUYUCU_METEOR_IMPACT_RADIUS, Color(1.0, 0.35, 0.1))
	## DÜZELTME (kullanıcı bildirimi: "yeni efektler yaptırılmıştı ziva agent
	## tarafından" ama görünmüyorlardı): gökten düşen taş + toz izi + patlama
	## (fx_meteor_strike.gd) BUYUCU_METEOR_TELEGRAPH_TIME'a çok yakın (0.45sn)
	## kendi düşüş süresinde oynuyor - halka ile AYNI anda başlatılıp "işte
	## buraya düşüyor" hissi tamamlanıyor, gerçek hasar aşağıdaki bekleme
	## sonunda (düşüş bitişiyle eşzamanlı) uygulanıyor. Eskiden bu görsel hiç
	## yoktu, sadece hasar anında Korsan'ın bomba patlaması (FxKorsanExplosionScene)
	## kullanılıyordu - tamamen alakasız bir efekt "eski efekt" olarak kalmıştı.
	if FxMeteorStrikeScene:
		var meteor_fx: Node2D = FxMeteorStrikeScene.instantiate() as Node2D
		get_tree().current_scene.add_child(meteor_fx)
		if meteor_fx.has_method("setup"):
			meteor_fx.setup(strike_pos)
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "hitscan_impact", strike_pos, {
			"scene_path": "res://scenes/fx_meteor_strike.tscn",
			"setup_pos": true,
		})
	await get_tree().create_timer(BUYUCU_METEOR_TELEGRAPH_TIME).timeout
	var dmg: float = damage_bonus * BUYUCU_METEOR_HIT_RATIO
	## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir".
	var is_crit: bool = _roll_ability_crit()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if strike_pos.distance_to(e.global_position) > BUYUCU_METEOR_IMPACT_RADIUS:
			continue
		if e.has_method("take_damage"):
			e.take_damage(_apply_ability_crit(dmg, is_crit), is_crit)


func _skill_shield() -> void:
	is_shielded = true
	## Baloncuğun görünmesi artık _update_shield_bubble() tarafından tetiklenir
	## (bir sonraki fizik karesinde is_shielded true olduğunu görüp appear() çağırır).
	_spawn_burst(Color(0.3, 0.6, 1.0))
	
	if FxShieldActiveScene:
		var fx := FxShieldActiveScene.instantiate() as Node2D
		add_child(fx)
		_broadcast_skill_scene("res://scenes/fx_shield_active.tscn")


## Şovalye (Paladin) ULTİ - Koruma Baloncuğu: is_shielded'ın aksine tam
## bağışıklık VERMEZ - bunun yerine kalkanın (item_shield_hp) aldığı hasarı
## %95 azaltır (bkz. take_damage, PALADIN_ULTI_SHIELD_COST_MULT), etrafında
## yaratık/menzilli saldırı giremeyen 280px'lik bir alan açar (bkz. enemy.gd,
## enemy_projectile.gd - paladin_zone_active/paladin_zone_radius'u okuyorlar),
## menzili %30 arttırır ama kendisi tamamen hareketsiz kalır. Sabit bir süresi
## yok - kalkanı bitene kadar sürer (bkz. _process_paladin_ulti).
func _skill_paladin_ulti() -> void:
	paladin_zone_active = true
	paladin_zone_radius = PALADIN_ULTI_ZONE_RADIUS
	_paladin_movement_locked = true
	velocity = Vector2.ZERO
	for w in owned_weapon_nodes:
		if not is_instance_valid(w):
			continue
		if w.has_method("set_temp_range_mult"):
			w.set_temp_range_mult(PALADIN_ULTI_RANGE_MULT)
	if _paladin_barrier_instance == null or not is_instance_valid(_paladin_barrier_instance):
		_paladin_barrier_instance = Node2D.new()
		_paladin_barrier_instance.set_script(load("res://scripts/fx_paladin_barrier.gd"))
		## z_index kendi _ready()'sinde absolute olarak ayarlanıyor (bkz.
		## fx_paladin_barrier.gd) - zeminin üstünde kalıcı görünür olsun diye.
		add_child(_paladin_barrier_instance)
	_paladin_barrier_instance.radius = PALADIN_ULTI_ZONE_RADIUS
	_paladin_barrier_instance.active = true
	_spawn_burst(Color(0.35, 0.75, 1.0))
	
	if FxPaladinCastScene:
		var fx := FxPaladinCastScene.instantiate() as Node2D
		add_child(fx)
		_broadcast_skill_scene("res://scenes/fx_paladin_cast.tscn")


## _end_skill_effects() her beceri bitiminde (süre dolunca VEYA burada
## olduğu gibi kalkan tükenince erken) çağrılır - paladin'e özel temizlik
## buraya ayrıldı ki genel fonksiyon şişmesin (bkz. matthew_dome_active'in
## aynı deseni kullanması).
func _end_paladin_ulti() -> void:
	paladin_zone_active = false
	paladin_zone_radius = 0.0
	_paladin_movement_locked = false
	for w in owned_weapon_nodes:
		if not is_instance_valid(w):
			continue
		if w.has_method("set_temp_range_mult"):
			w.set_temp_range_mult(1.0)
	if _paladin_barrier_instance and is_instance_valid(_paladin_barrier_instance):
		_paladin_barrier_instance.active = false
	_paladin_barrier_instance = null


## Kullanıcı isteği: Şovalye Adam'ın yeni 3. yeteneği (Koruma Bariyeri, id
## 29) - yakındaki dostların (bkz. "player_ally" grubu - totem_shield.gd
## _tick() ile AYNI tarama, SADECE gerçek uzak müttefikler, kendisi hiçbir
## zaman bu grupta olmadığı için ayrıca hariç tutmaya gerek yok) etrafında
## 15sn boyunca dönen bir bariyer oluşturur, aldıkları hasarın %30'unu
## Şovalye'ye yansıtır. Menzil dışına çıkan dostun bariyeri kendi
## client'ında _process_damage_redirect_range_check ile ayrıca kapanır.
const PALADIN_BARRIER_CAST_RADIUS := 280.0
const PALADIN_BARRIER_REDIRECT_PERCENT := 0.30
const PALADIN_BARRIER_DURATION := 15.0

var _barrier_buffed_allies: Array = []

func _skill_paladin_barrier() -> void:
	_barrier_buffed_allies.clear()
	for ally in get_tree().get_nodes_in_group("player_ally"):
		if not is_instance_valid(ally) or ally.get("is_dead") == true:
			continue
		if global_position.distance_to(ally.global_position) > PALADIN_BARRIER_CAST_RADIUS:
			continue
		_apply_damage_redirect_to_ally(ally, PALADIN_BARRIER_REDIRECT_PERCENT, PALADIN_BARRIER_DURATION)
		_barrier_buffed_allies.append(ally)
	_spawn_burst(Color(0.9, 0.85, 0.4))
	_spawn_ring(Color(0.9, 0.85, 0.4))


func _end_paladin_barrier() -> void:
	for ally in _barrier_buffed_allies:
		if is_instance_valid(ally):
			_apply_damage_redirect_to_ally(ally, 0.0, 0.0)
	_barrier_buffed_allies.clear()


## bkz. sınıf üstü damage_redirect_* notu (player.gd üst kısmı) -
## _apply_shield_heal_to_ally ile AYNI "hedefin peer_id'sine RPC" deseni,
## sadece bir sayı yerine bir YÜZDE+SÜRE+kaynak peer id taşıyor. percent<=0
## göndermek buff'ı KALDIRIR (bkz. _end_paladin_barrier/_process_damage_
## redirect_range_check).
func _apply_damage_redirect_to_ally(ally: Node2D, percent: float, duration: float) -> void:
	if not is_instance_valid(ally) or not ("peer_id" in ally):
		return
	var target_peer_id: int = int(ally.peer_id)
	if target_peer_id <= 0 or not NetworkManager.is_multiplayer_active:
		return
	var my_peer_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	NetworkManager.sync_damage_redirect_buff.rpc(target_peer_id, my_peer_id, percent, duration)


## enemy.gd'nin "kalkana saldırma" bloğu her isabette bunu çağırır - kalkanın
## gerçekten hasar aldığını göstermek için baloncukta kısa bir parlama tetikler.
## #57 DÜZELTME (kullanıcı bildirimi: "şovalye adamın kalkan baloncuğunun
## çatlama parçalama efektleri v.s diğer oyunculara gösterilmiyor, şovalye
## adam nasıl görüyorsa öyle olmalı"): network_manager.gd broadcast_player_
## vfx()'in "paladin_barrier_flash" dalı ZATEN vardı (bkz. orada ve fx_
## paladin_barrier.gd flash_from_angle() üstündeki eski yorum, "artık
## düzeltildi" diyordu) - ama GÖNDEREN taraf (bu fonksiyon) hiçbir zaman
## broadcast_player_vfx.rpc() ÇAĞIRMIYORDU, alıcı taraf hazırdı fakat hiç
## tetiklenmiyordu. Artık açı TEK bir yerde hesaplanıp hem yerel flash_from_
## angle()'a hem uzak oyunculara AYNI şekilde gönderiliyor - "oyuncu ne
## görüyorsa diğerleri de görmeli" isteğinin karşılığı (fx_paladin_barrier.gd
## eski flash(attacker)'daki nearest-enemy fallback mantığı burada korundu).
func flash_paladin_barrier(attacker: Node2D = null) -> void:
	if not (_paladin_barrier_instance and is_instance_valid(_paladin_barrier_instance)):
		return
	var angle: float = 0.0
	if attacker and is_instance_valid(attacker):
		angle = (attacker.global_position - global_position).angle()
	else:
		var closest_enemy: Node2D = null
		var min_dist: float = 99999.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e.get("is_dead") != true:
				var d: float = global_position.distance_to(e.global_position)
				if d < min_dist:
					min_dist = d
					closest_enemy = e
		if closest_enemy:
			angle = (closest_enemy.global_position - global_position).angle()
		else:
			angle = randf_range(0.0, TAU)
	if _paladin_barrier_instance.has_method("flash_from_angle"):
		_paladin_barrier_instance.flash_from_angle(angle)
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "paladin_barrier_flash", global_position, {
			"angle": angle
		})


## Şovalye ultisi aktifken dış koruma alanına (baloncuk) isabet eden HER
## vuruş buraya gelir - bilerek normal take_damage()'dan AYRI: o akış
## shield_protection stat'ına bağlı çalışıyor (hiç kalkan item'ı/bonusu
## yoksa effective_protection sıfır oluyor ve hasar dümdüz cana gidiyordu -
## bkz. kullanıcı bildirimi "kalkana hasar veremiyorlar direk candan
## gidiyor"). Burada oran sabit ve stat'tan bağımsız: dış kalkana X hasar
## gelirse gerçek kalkana (item_shield_hp) SADECE %10'u işler
## (PALADIN_ULTI_SHIELD_COST_MULT), cana hiç dokunmaz - "biri dış kalkana
## 100 vurursa normal kalkana 10 yansıyacak" isteğinin karşılığı.
func take_paladin_barrier_damage(amount: float, attacker: Node2D = null) -> void:
	if is_dead or not paladin_zone_active:
		return
	var shield_damage: float = amount * PALADIN_ULTI_SHIELD_COST_MULT
	item_shield_hp = max(0.0, item_shield_hp - shield_damage)
	item_shield_regen_delay = _shield_hit_regen_delay()
	item_shield_changed.emit(item_shield_hp, item_shield_max)
	## Küçük darbeler tek başına 1'in altında kalıp "0" olarak görünmesin diye
	## biriktirilip SADECE 1'e ulaşınca gösteriliyor (bkz. sınıf üstü yorum).
	_paladin_barrier_dmg_display_accum += shield_damage
	if _paladin_barrier_dmg_display_accum >= 1.0:
		var shown: int = int(_paladin_barrier_dmg_display_accum)
		_spawn_floating_text("%d" % shown, Color(1.0, 1.0, 1.0))
		_paladin_barrier_dmg_display_accum -= shown
	if shield_hit_sound:
		shield_hit_sound.pitch_scale = randf_range(0.95, 1.08)
		shield_hit_sound.play()
	flash_paladin_barrier(attacker)


## Kalkan (item_shield_hp) sıfıra inince ulti'yi ERKEN bitirir - normal
## _process_skill() sadece skill_timer'ın sıfırlanmasını bekler ama bu
## becerinin süresi sabit değil (SKILL_TIMING[11].duration sadece 9999sn'lik
## bir güvenlik tavanı), o yüzden gerçek bitiş koşulu burada elle kontrol
## ediliyor. Bittiğinde tam bekleme süresi (180sn) baştan başlar - süre
## sabit olmadığı için "_skill_cooldown - _skill_duration" hesabı (normal
## akışta kullanılan) burada anlamsız.
func _process_paladin_ulti(_delta: float) -> void:
	if not paladin_zone_active:
		return
	## DÜZELTME (kullanıcı bildirimi: "uzun süre aktif kalan skillerde sürekli
	## kullanması gerekiyor animasyonu") - Koruma Baloncuğu boyunca karakter
	## tamamen hareketsiz kalıyor (bkz. _paladin_movement_locked), yani kendi
	## yürüme/saldırı animasyonu hiç devreye girmiyor - _process_buyucu_meteor
	##'daki AYNI desen: _update_animation() zaten "spellcast" ile başlayan
	## animasyonları anim.is_playing() true iken EZMİYOR, bu yüzden sadece
	## bittiğinde yeniden başlatmak yeterli.
	if is_instance_valid(anim) and anim.sprite_frames and anim.sprite_frames.has_animation("spellcast_" + facing) and not anim.is_playing():
		anim.play("spellcast_" + facing)
	if item_shield_hp <= 0.0:
		_paladin_barrier_break()
		_end_skill_effects()
		skill_state = "cooldown"
		skill_timer = _skill_cooldown


func _paladin_barrier_break() -> void:
	if FxPaladinShatterScene:
		var fx := FxPaladinShatterScene.instantiate() as Node2D
		fx.global_position = global_position
		get_tree().current_scene.add_child(fx)
		if NetworkManager.is_multiplayer_active:
			NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "hitscan_impact", global_position, {
				"scene_path": "res://scenes/fx_paladin_shatter.tscn"
			})
		
	## DÜZELTME (kullanıcı isteği #51: "şovalyenin kalkan baloncuğu patlayınca
	## yaratıkları daha uzağa itmeli") - REPEL_FORCE 140 -> 240 (dosyadaki
	## benzer bir alan-itme becerisinin (bkz. aşağıdaki KNOCKBACK := 260.0)
	## gücüne yakın, belirgin şekilde daha güçlü bir itiş).
	const REPEL_RADIUS := 180.0
	const REPEL_FORCE := 240.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.get("is_dead") != true:
			var d := global_position.distance_to(e.global_position)
			if d <= REPEL_RADIUS:
				var dir: Vector2 = (e.global_position - global_position).normalized()
				if d < 0.1:
					dir = Vector2.UP
				if e.has_method("apply_knockback_force"):
					e.apply_knockback_force(dir, REPEL_FORCE)
				else:
					e.global_position += dir * REPEL_FORCE


## Şovalye (Paladin) TEMEL - Kışkırtma: menzildeki tüm yaratıkları (bkz.
## PALADIN_TAUNT_RADIUS) _skill2_duration boyunca kışkırtır - is_ranged
## yaratıklar bile normalde koruduğu "uzak dur" mesafesini bırakıp doğrudan
## üstüne yürür (bkz. enemy.gd apply_taunt/_taunt_timer).
func _skill_paladin_taunt() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if global_position.distance_to(e.global_position) <= PALADIN_TAUNT_RADIUS:
			if e.has_method("apply_taunt"):
				e.apply_taunt(_skill2_duration)
	_spawn_burst(Color(1.0, 0.85, 0.3))


## ---------- Elara: Yay + Gerçek Hasar (E) + Çift Tetik (R) ----------
## Pasif: seviye başına %1 saldırı hızı, en fazla %50 (bkz. _elara_passive_
## fire_rate_mult - _apply_weapon_bonuses_to içinde fire_rate_mult'a çarpan
## olarak uygulanıyor, ayrıca her level_up()'ta tazeleniyor).
const ELARA_PASSIVE_ATK_SPEED_PER_LEVEL := 0.01
const ELARA_PASSIVE_ATK_SPEED_CAP := 0.5

## R - Çift Tetik: 25sn boyunca tüm silahlar saldırı başına 2 kez ateşleniyor
## ama her atış sadece %60 hasar veriyor (bkz. weapon.gd _player_flag ile
## okunan elara_double_fire_active - _on_fire_timer_timeout ve yayın draw-
## ready dalı bu bayrağa bakıp ikinci bir _fire_at() daha çağırıyor,
## ELARA_DOUBLE_FIRE_DAMAGE_MULT ise _fire_at/_deal_beam_tick içinde hasara
## çarpan olarak uygulanıyor).
var elara_double_fire_active: bool = false

## E - Gerçek Hasar: her silahın SONRAKİ 6 saldırısı (silah başına, bkz.
## kullanıcı onayı "Silah başına 6") %50 fazla ve zırh+kalkanı görmezden
## gelen gerçek hasar veriyor. Sabit bir süresi yok - SKILL2_TIMING[11]'deki
## "duration" sadece güvenlik tavanı (Paladin ultisindeki 9999 gibi),
## gerçek bitiş _process_elara_true_damage'ta tüm silahların hakları
## tükendiğinde tetikleniyor.
const ELARA_TRUE_DAMAGE_CHARGES := 6


func _elara_passive_fire_rate_mult() -> float:
	if get_skill_character_id() != 12 and get_skill2_id() != 11:
		return 1.0
	## fire_rate_mult zaten "çarpan küçüldükçe hızlanır" mantığında (bkz.
	## weapon.gd set_fire_rate_mult) - bu yüzden bonus burada 1.0'dan
	## ÇIKARILARAK uygulanıyor (örn. %50 bonus -> 0.5 çarpan -> 2 kat hız).
	return 1.0 - min(level * ELARA_PASSIVE_ATK_SPEED_PER_LEVEL, ELARA_PASSIVE_ATK_SPEED_CAP)


const KURTADAM_BERSERK_DAMAGE_TAKEN_MULT := 0.5 ## -%50 hasar
const KURTADAM_BERSERK_LIFESTEAL_BONUS := 0.10 ## +%10 can çalma
const KURTADAM_BERSERK_FIRE_RATE_BONUS := 0.30 ## +%30 saldırı hızı
const KURTADAM_BERSERK_SPEED_MULT := 1.3 ## +%30 hareket hızı (kullanıcı isteği)


## Kurt Adam ULTİ (skill id 14): "30 saniye boyunca kontrolünü kaybetmesini
## sağlar ve silahlarının menziline bağlı olarak yaratıklara yaklaşıp
## onlara kontrolsüzce saldırmasına neden olur" - hareketi _physics_
## process'te _kurtadam_berserk_direction() ile otomatik yönetilir (bkz.
## _kurtadam_berserk_active). Oyuncu bu süre boyunca yetenek/kalkan
## modu/eşya kullanmaya devam edebilir, sadece hareketi kontrol edemez.
func _skill_kurtadam_berserk() -> void:
	_kurtadam_berserk_active = true
	damage_taken_mult = KURTADAM_BERSERK_DAMAGE_TAKEN_MULT
	lifesteal_percent += KURTADAM_BERSERK_LIFESTEAL_BONUS
	skill_speed_multiplier = KURTADAM_BERSERK_SPEED_MULT
	_apply_weapon_bonuses()
	modulate = Color(1.0, 0.4, 0.35, 1.0)
	_spawn_burst(Color(1.0, 0.15, 0.1))
	
	if FxKurtadamRageScene:
		var fx := FxKurtadamRageScene.instantiate() as Node2D
		add_child(fx)
	_broadcast_skill_scene("res://scenes/fx_kurtadam_rage.tscn")


func _end_kurtadam_berserk() -> void:
	_kurtadam_berserk_active = false
	lifesteal_percent -= KURTADAM_BERSERK_LIFESTEAL_BONUS
	_apply_weapon_bonuses()


## bkz. _elara_passive_fire_rate_mult() ile aynı desen - Kudurmuş Saldırı
## aktifken +%30 saldırı hızı verir (mult <1.0 = daha hızlı saldırı).
func _kurtadam_berserk_fire_rate_mult() -> float:
	if not _kurtadam_berserk_active:
		return 1.0
	return max(0.1, 1.0 - KURTADAM_BERSERK_FIRE_RATE_BONUS)


## Kudurmuş Saldırı aktifken oyuncunun otomatik hareket yönünü hesaplar:
## "silahlarının menziline bağlı olarak yaratıklara yaklaşıp onlara
## kontrolsüzce saldırmasına neden olur (en kısa menzilli silah
## önceliklidir)" - en kısa attack_range'e sahip silahını baz alıp en
## yakın yaratığa doğru yürür; o yaratık zaten menzildeyse yerinde durur
## (silahlar kendi ateşleme mantığıyla otomatik vurur).
func _kurtadam_berserk_direction() -> Vector2:
	var shortest_range: float = INF
	for w in owned_weapon_nodes:
		if not is_instance_valid(w):
			continue
		## DÜZELTME (kullanıcı isteği #45: "kurt adam ultisini açıp kontrolünü
		## kaybettiğinde yaratıklara saldıracağı zaman saldırabileceği menzile
		## doğru gitmiyor") - attack_range == 0.0 "SINIRSIZ menzil" anlamına
		## gelir (bkz. weapon.gd dosya başı yorumu), SIFIR mesafe değil. Eskiden
		## bu istisna hesaba katılmadığı için, oyuncu sınırsız menzilli
		## herhangi bir silaha (tabanca/tüfek/yay vb.) sahipse shortest_range
		## anında 0.0'a düşüyordu - bu da "hedefe 0 birim kalana kadar
		## yaklaş" gibi imkansız bir koşula dönüşüp Kurt Adam'ın asla gerçek
		## bir saldırı menziline "varmış" sayılmamasına, sürekli yaratığın
		## üstüne yürümeye çalışmasına yol açıyordu. Artık sınırsız menzilli
		## silahlar bu hesaba hiç katılmıyor.
		if "attack_range" in w and w.attack_range > 0.0 and w.attack_range < shortest_range:
			shortest_range = w.attack_range
	if shortest_range == INF:
		shortest_range = 0.0
	
	var target: Node2D = null
	var target_dist: float = INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < target_dist:
			target_dist = d
			target = e
	
	if target == null:
		return Vector2.ZERO
	if target_dist <= shortest_range:
		return Vector2.ZERO
	return (target.global_position - global_position).normalized()


func _skill_elara_double_fire() -> void:
	elara_double_fire_active = true
	_spawn_burst(Color(0.95, 0.75, 0.25))
	
	if FxElaraDoubleScene:
		var fx := FxElaraDoubleScene.instantiate() as Node2D
		add_child(fx)
	_broadcast_skill_scene("res://scenes/fx_elara_double.tscn")


func _end_elara_double_fire() -> void:
	elara_double_fire_active = false


func _skill_elara_true_damage() -> void:
	for w in owned_weapon_nodes:
		if not is_instance_valid(w):
			continue
		if w.has_method("add_true_damage_charges"):
			w.add_true_damage_charges(ELARA_TRUE_DAMAGE_CHARGES)
	_spawn_burst(Color(1.0, 0.85, 0.3))
	
	if FxElaraTrueScene:
		var fx := FxElaraTrueScene.instantiate() as Node2D
		add_child(fx)
	_broadcast_skill_scene("res://scenes/fx_elara_true.tscn")


## Silah başına verilen 6'şar gerçek hasar hakkı hepsi tükenince yeteneği
## erken bitirip bekleme süresine sokuyor (bkz. sınıf yorumu - sabit süre
## yerine "tüketilene kadar" mantığı, Paladin ultisindeki kalkan-tükenme
## desenininin aynısı).
func _process_elara_true_damage(_delta: float) -> void:
	if skill2_state != "active" or get_skill2_id() != 11:
		return
	for w in owned_weapon_nodes:
		if not is_instance_valid(w):
			continue
		if w.has_method("true_damage_charges_remaining") and w.true_damage_charges_remaining() > 0:
			return
	_end_skill2_effects()
	skill2_state = "cooldown"
	skill2_timer = _skill2_cooldown


## Kullanıcı isteği: Elara'nın yeni 3. yeteneği - ileri kısa bir hamle atar
## ve anında kalkanının %12'sini yeniler, kalkan HARCAMAZ (bkz.
## _activate_skill3() üstündeki muafiyet notu). _assasin_dash2_execute()
## (Şahin Hamlesi) ile AYNI yön/tween deseni - ama düşman tarama/hasar YOK,
## bu saf bir konumlanma hamlesi.
## DÜZELTME (kullanıcı isteği: "Elaranın dashini %30 kısalt ve %50 yavaşlat")
## - mesafe 180 -> 126 (-%30), süre 0.12 -> 0.24 (iki katı = %50 yavaş).
const ELARA_DASH_DISTANCE := 126.0
const ELARA_DASH_TIME := 0.24
const ELARA_DASH_SHIELD_HEAL_PERCENT := 0.12

func _skill_elara_dash_refill() -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var raw_dir: Vector2 = input_dir if input_dir.length() > 0.1 else _facing_to_vector(facing)
	var snapped_angle: float = round(raw_dir.angle() / (PI / 4.0)) * (PI / 4.0)
	var dash_dir: Vector2 = Vector2(cos(snapped_angle), sin(snapped_angle))
	var start_pos: Vector2 = global_position
	var end_pos: Vector2 = start_pos + dash_dir * ELARA_DASH_DISTANCE
	_spawn_burst(Color(0.4, 0.85, 1.0))
	var dash_tween := create_tween()
	dash_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	dash_tween.tween_method(func(p: Vector2): global_position = p, start_pos, end_pos, ELARA_DASH_TIME)
	await dash_tween.finished
	heal_shield(item_shield_max * ELARA_DASH_SHIELD_HEAL_PERCENT)


func _skill_invisibility() -> void:
	is_invisible = true
	modulate.a = 0.35
	_spawn_burst(Color(0.7, 0.5, 1.0))

	if FxAssasinStealthScene:
		var fx := FxAssasinStealthScene.instantiate() as Node2D
		add_child(fx)
		# Broadcast stealth scene to remote players
		if NetworkManager.is_multiplayer_active:
			NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "skill_scene", global_position, {
				"scene_path": "res://scenes/fx_assasin_stealth.tscn",
				"position": Vector2.ZERO
			})


## Kullanıcı isteği: Assasin Çocuk'un yeni 3. yeteneği (Gölge Adımı, skill3
## id 30) - eskiden ölü kod olan _skill_invisibility()'i (is_invisible zaten
## TAM multiplayer-senkron bir bayrak, bkz. main.gd extra dict/remote_
## player.gd/enemy.gd hedef seçimi) yeniden kullanır, üstüne +%30 saldırı
## gücü (Talon'un Devleşme'sindeki AYNI "verilen miktarı sakla, bitince
## AYNI miktarı geri çıkar" deseni, bkz. _talon_devasa_armor_bonus) ve
## "yaratıkların içinden geçebilir" (collision_mask'tan düşman katmanını
## geçici olarak çıkarma) ekler.
var _assasin_invis_damage_bonus_add: float = 0.0

func _skill_assasin_invisibility_r() -> void:
	_skill_invisibility()
	_assasin_invis_damage_bonus_add = damage_bonus * 0.30
	damage_bonus += _assasin_invis_damage_bonus_add
	_apply_weapon_bonuses()
	collision_mask &= ~4 ## bkz. _block_movement_into_enemies() üstündeki AYNI not - düşman fizik katmanı (4)


func _end_assasin_invisibility_r() -> void:
	is_invisible = false
	modulate.a = 1.0
	if _assasin_invis_damage_bonus_add > 0.0:
		damage_bonus -= _assasin_invis_damage_bonus_add
		_assasin_invis_damage_bonus_add = 0.0
		_apply_weapon_bonuses()
	collision_mask |= 4


## Gölge Hücumu ultisinin ayar sabitleri - bkz. _skill_assasin_dash içindeki
## ilgili düzeltme notları (kullanıcı bildirimi: "çok hızlı ışınlanır gibi
## vuruyor hiçbirşey anlaşılmıyor" + "haritadaki her yaratığa vuruyor sadece
## çevresindekilere vurmasını istiyorum").
const ASSASIN_DASH_RADIUS := 600.0 ## SADECE cast konumunun bu yarıçapındaki yaratıklara sıçrar
const ASSASIN_DASH_LUNGE_TIME := 0.09 ## anlık ışınlanma yerine kısa, görünür bir sıçrayış
const ASSASIN_DASH_HIT_INTERVAL := 0.2 ## vuruşlar arası bekleme (eskiden 0.07 - göz seçemiyordu)
const ASSASIN_DASH_HIT_SOUNDS: Array[String] = [
	"res://assets/audio/assasin_swing1.mp3",
	"res://assets/audio/assasin_swing2.mp3",
	"res://assets/audio/assasin_swing3.mp3",
]


## ---------- Assasin Çocuk TEMEL (yeni, id 5): 8 Yönlü Hamle ----------
## Kullanıcı isteği: "yürüdüğü yöne doğru ileriye hızla dash atar (8 direction)
## ve içinden geçtiği düşmanlara saldırı gücünün %150'si kadar hasar verir.
## Bu yeteneğin 3 yükü bulunur. Her yük 12 saniye bekleme süresine sahiptir
## (yüklerin yenilenmesi bekleme süresindeyken yeteneği tekrar kullanmak
## bekleme süresini sıfırlamaz olduğu gibi yenilenmeye devam eder yükler)."
## Eski Görünmezlik'in (bkz. yukarıdaki SKILL2_TIMING[5] notu) yerine geldi -
## Korsan'ın bomba şarj sistemiyle (_process_korsan_bombs/_korsan_try_place_
## bomb) BİREBİR AYNI mimari: "bir yük dolarken tekrar kullanmak süreyi
## sıfırlamaz" davranışı buradaki `if _assasin_dash2_recharge_timer <= 0.0`
## koruması sayesinde otomatik sağlanıyor.
const ASSASIN_DASH2_MAX_CHARGES := 3
const ASSASIN_DASH2_RECHARGE_TIME := 12.0
## DÜZELTME (kullanıcı isteği: "Assasin çocuğun dash skilini %40 kısalt ve
## %50 yavaşlat") - mesafe 260 -> 156 (-%40), süre 0.12 -> 0.24 (iki katı =
## %50 yavaş).
const ASSASIN_DASH2_DISTANCE := 156.0 ## dash mesafesi (piksel)
const ASSASIN_DASH2_HIT_WIDTH := 48.0 ## dash çizgisine bu mesafedeki düşmanlar isabet alır
const ASSASIN_DASH2_DASH_TIME := 0.24 ## görünür ama hızlı bir sıçrayış (ultinin LUNGE_TIME'ıyla aynı ruh)
const ASSASIN_DASH2_DAMAGE_MULT := 1.5 ## saldırı gücünün %150'si
var assasin_dash2_charges: int = ASSASIN_DASH2_MAX_CHARGES
var _assasin_dash2_recharge_timer: float = 0.0
var _assasin_dash2_fx: Node2D = null


func _process_assasin_dash2_charges(delta: float) -> void:
	if get_skill2_id() != 5:
		return
	if assasin_dash2_charges < ASSASIN_DASH2_MAX_CHARGES:
		_assasin_dash2_recharge_timer -= delta
		if _assasin_dash2_recharge_timer <= 0.0:
			assasin_dash2_charges += 1
			_assasin_dash2_recharge_timer = ASSASIN_DASH2_RECHARGE_TIME if assasin_dash2_charges < ASSASIN_DASH2_MAX_CHARGES else 0.0


## bkz. get_korsan_bomb_charge_fraction üstündeki AYNI kullanıcı isteği notu
## - Assasin'in Şahin Hamlesi şarjları için birebir aynı hesap.
func get_assasin_dash2_charge_fraction() -> float:
	if assasin_dash2_charges >= ASSASIN_DASH2_MAX_CHARGES:
		return 1.0
	if ASSASIN_DASH2_RECHARGE_TIME <= 0.0:
		return 1.0
	return clamp(1.0 - (_assasin_dash2_recharge_timer / ASSASIN_DASH2_RECHARGE_TIME), 0.0, 1.0)


func _try_assasin_dash2() -> void:
	if is_dead or is_downed:
		return
	if assasin_dash2_charges <= 0:
		_spawn_floating_text("HAMLE YOK", Color(1.0, 0.4, 0.4))
		return
	assasin_dash2_charges -= 1
	## bkz. dosya başı yorumu - bir yük ZATEN yenilenmekteyken bu ikinci
	## kullanım o sayaçı SIFIRLAMAZ, sadece henüz başlamamışsa başlatır.
	if _assasin_dash2_recharge_timer <= 0.0:
		_assasin_dash2_recharge_timer = ASSASIN_DASH2_RECHARGE_TIME
	_assasin_dash2_execute()


## up/down/left/right facing string'ini birim vektöre çevirir - _update_facing()'in
## tersi, girdi yokken (oyuncu duruyorken) son baktığı yöne dash atması için.
func _facing_to_vector(f: String) -> Vector2:
	match f:
		"up": return Vector2.UP
		"down": return Vector2.DOWN
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
	return Vector2.DOWN


func _assasin_dash2_execute() -> void:
	## "Yürüdüğü yöne doğru" - o anki hareket girdisi varsa onu, yoksa (durgun
	## haldeyken) son bakılan yönü (facing) kullanır; ikisi de en yakın 8
	## yöne (45°'lik dilimlere) yuvarlanır.
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var raw_dir: Vector2 = input_dir if input_dir.length() > 0.1 else _facing_to_vector(facing)
	var snapped_angle: float = round(raw_dir.angle() / (PI / 4.0)) * (PI / 4.0)
	var dash_dir: Vector2 = Vector2(cos(snapped_angle), sin(snapped_angle))

	var start_pos: Vector2 = global_position
	var end_pos: Vector2 = start_pos + dash_dir * ASSASIN_DASH2_DISTANCE

	var total_damage: float = 0.0
	for w: Node in owned_weapon_nodes:
		if is_instance_valid(w) and "damage" in w:
			total_damage += float(w.get("damage"))
	if total_damage <= 0.0:
		total_damage = 10.0
	var hit_damage: float = total_damage * ASSASIN_DASH2_DAMAGE_MULT

	## İçinden geçtiği düşmanlar: dash çizgisine (start_pos -> end_pos)
	## ASSASIN_DASH2_HIT_WIDTH mesafesinden yakın olan TÜM canlı yaratıklar -
	## ultinin nokta-tabanlı "en yakın hedef" taramasından FARKLI, burada
	## çizgi/segment mesafesi kullanılıyor (bkz. Geometry2D.get_closest_
	## point_to_segment).
	var hit_enemies: Array = []
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if not (e is Node2D):
			continue
		var epos: Vector2 = (e as Node2D).global_position
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(epos, start_pos, end_pos)
		if epos.distance_to(closest) <= ASSASIN_DASH2_HIT_WIDTH:
			hit_enemies.append(e)

	_spawn_burst(Color(0.1, 0.05, 0.25))
	## BUG DÜZELTMESİ (kullanıcı bildirimi: "assasin çocuk temel yeteğiyle
	## dash attığında 3 saniye siyah gölgeli kalmaya devam ediyor") - kök
	## neden: _assasin_dash2_fx TEK bir paylaşılan referans; oyuncunun 3
	## yükü olduğu için bu fonksiyon üst üste (bir önceki çağrının "await
	## dash_tween.finished" askıda dururken) tekrar çağrılabiliyor. İkinci
	## çağrı bu referansı YENİ fx ile değiştirince, İLK çağrının coroutine'i
	## sonunda uyanıp _assasin_dash2_fx.stop() çağırdığında artık YANLIŞ
	## (ikinci) fx'i durduruyordu - İLK fx'in referansı hiç stop() almadan
	## kayboluyor, kendi SAFETY_DURATION (6sn, bkz. fx_assasin_dash.gd)
	## güvenlik tavanına kadar koyu mor "gölge" görüntüsü üretmeye devam
	## ediyordu. Artık yeni bir dash başlarken, hâlâ durdurulmamış eski bir
	## fx varsa ÖNCE o durduruluyor.
	if _assasin_dash2_fx and is_instance_valid(_assasin_dash2_fx) and _assasin_dash2_fx.has_method("stop"):
		_assasin_dash2_fx.stop()
	_assasin_dash2_fx = _play_and_broadcast_skill_fx(preload("res://scenes/fx_assasin_dash.tscn"))

	var dash_tween := create_tween()
	dash_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	dash_tween.tween_method(func(p: Vector2): global_position = p, start_pos, end_pos, ASSASIN_DASH2_DASH_TIME)
	await dash_tween.finished

	if _assasin_dash2_fx and is_instance_valid(_assasin_dash2_fx) and _assasin_dash2_fx.has_method("stop"):
		_assasin_dash2_fx.stop()
	_assasin_dash2_fx = null

	## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir" - her
	## isabet kendi kritik zarını atar (ultinin _skill_assasin_dash'iyle AYNI
	## desen).
	for e in hit_enemies:
		if not is_instance_valid(e) or e.get("is_dead") == true or not is_inside_tree():
			continue
		if e.has_method("take_damage"):
			var is_crit: bool = _roll_ability_crit()
			e.call("take_damage", _apply_ability_crit(hit_damage, is_crit), is_crit)
			_spawn_assasin_dash_hit_fx((e as Node2D).global_position, dash_dir)


## Her isabette gerçek bıçak kesme efektini (dagger'ın normal savuruşuyla
## AYNI sahne, fx_assasin_slash.tscn) ve rastgele bir kesme sesini hedefin
## konumunda oynatır - kullanıcı isteği: "her bir yaratığa vurduğunda vuruş
## ses efekti ve bıçak kesme efekti çıksın". Diğer tüm kozmetik efektler
## gibi (bkz. dosya geneli "melee_hit" broadcast deseni) katılımcılara da
## aynı şekilde yayınlanıyor - host'un gördüğü/duyduğu her isabet
## katılımcılarda da birebir görünür/duyulur olsun diye.
func _spawn_assasin_dash_hit_fx(pos: Vector2, dir: Vector2) -> void:
	var facing_dir: Vector2 = dir.normalized() if dir.length() > 0.1 else Vector2.DOWN
	var sound_path: String = ASSASIN_DASH_HIT_SOUNDS[randi() % ASSASIN_DASH_HIT_SOUNDS.size()]
	var slash_scene: PackedScene = preload("res://scenes/fx_assasin_shadow_hit.tscn")
	if slash_scene and get_tree().current_scene:
		var slash: Node2D = slash_scene.instantiate() as Node2D
		if slash:
			get_tree().current_scene.add_child(slash)
			slash.global_position = pos
			slash.rotation = facing_dir.angle() + PI / 4.0
	if ResourceLoader.exists(sound_path):
		var stream: AudioStream = load(sound_path) as AudioStream
		if stream:
			var asp := AudioStreamPlayer2D.new()
			get_tree().current_scene.add_child(asp)
			asp.global_position = pos
			asp.stream = stream
			asp.pitch_scale = randf_range(0.92, 1.1)
			asp.max_distance = 1200.0
			asp.finished.connect(asp.queue_free)
			asp.play()
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "melee_hit", pos, {
			"scene_path": "res://scenes/fx_assasin_shadow_hit.tscn",
			"rotation": facing_dir.angle(),
			"sound_path": sound_path,
		})


func _skill_assasin_dash() -> void:
	is_assasin_dashing = true
	assasin_dash_hits = 0
	modulate = Color(0.1, 0.05, 0.25, 0.6)
	## DÜZELTME (kullanıcı bildirimi: "assasin çocuğun ultisinin dash efekti
	## diğer oyunculara farklı kendine farklı görünüyor, diğer oyunculara
	## daha güzel görünüyor onlarınki gibi görünmeli") - fx'in kendisi
	## local/remote'ta birebir aynı (bkz. network_manager.gd "skill_scene"
	## yayını); asıl fark kamerada: aşağıdaki lunge_tween karakterin
	## konumunu SERT adımlarla değiştiriyor, kamera Player'ın çocuğu olduğu
	## için (bkz. death_camera) bunu birebir/sarsıntılı yansıtıyordu. Diğer
	## oyuncuların ekranında ise bu hareket remote_player.gd'nin lerp'iyle
	## (üstel yumuşama eğrisi) göründüğü için akıcıydı. Godot'un yerleşik
	## kamera yumuşatmasını SADECE dash süresince açarak local görünümü
	## remote ile eşleştiriyoruz - normal oynanışta kamera davranışı
	## değişmez.
	## DÜZELTME: normal oynanışta kamera artık HER ZAMAN yumuşatılıyor (bkz.
	## player.tscn Camera2D position_smoothing_enabled/speed - piksel-art +
	## pixel-snap ile titreşimsiz görünmesi için) - bu yüzden sadece "enabled"
	## kaydedip geri almak yetmiyor, dash'in kendi (daha yavaş, 10.0) hızı
	## kalıcı kalıp normal hızın (20.0) yerine geçerdi. Artık SPEED de
	## kaydedilip geri alınıyor.
	var _dash_cam_was_smoothing: bool = false
	var _dash_cam_prev_speed: float = 20.0
	if death_camera and is_instance_valid(death_camera):
		_dash_cam_was_smoothing = death_camera.position_smoothing_enabled
		_dash_cam_prev_speed = death_camera.position_smoothing_speed
		death_camera.position_smoothing_enabled = true
		death_camera.position_smoothing_speed = 10.0

	# Instantiate and add the FX trail
	var fx_scene: PackedScene = preload("res://scenes/fx_assasin_dash.tscn")
	if fx_scene:
		_assasin_dash_fx = fx_scene.instantiate() as Node2D
		add_child(_assasin_dash_fx)
		if NetworkManager.is_multiplayer_active:
			NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "skill_scene", global_position, {
				"scene_path": "res://scenes/fx_assasin_dash.tscn",
				"position": Vector2.ZERO
			})
	
	## DÜZELTME (kullanıcı isteği: "haritadaki her yaratığa vuruyor ben sadece
	## çevresindekilere vurmasını istiyorum") - eskiden her sıçrayıştan SONRA
	## bir sonraki hedef YENİ (ışınlanılan) konumdan aranıyordu, yani
	## yaratıklar birbirine ASSASIN_DASH_RADIUS'tan yakın olduğu sürece ulti
	## zincirleme şekilde haritanın bir ucundan öbürüne sıçrayabiliyordu.
	## Artık arama HER ZAMAN ultinin cast edildiği BAŞLANGIÇ konumundan
	## (origin_pos) ölçülüyor - sadece o anki gerçek çevresindeki yaratıklar
	## hedeflenir, karakter kendisi ışınlandıkça arama alanı KAYMAZ.
	var origin_pos: Vector2 = global_position

	# Run the sequence of dashes — hit each enemy at most once, up to 25 targets
	var max_hits: int = 25
	var hit_enemies: Array[Node] = []
	while assasin_dash_hits < max_hits:
		# Check if player is dead or game ended or skill is no longer active
		if not is_inside_tree() or skill_state != "active" or is_dead:
			break

		# Sum weapon damage once per dash tick
		var total_damage: float = 0.0
		for w: Node in owned_weapon_nodes:
			if is_instance_valid(w) and "damage" in w:
				total_damage += float(w.get("damage"))
		if total_damage <= 0.0:
			total_damage = 10.0

		# Find nearest un-hit, alive enemy within ASSASIN_DASH_RADIUS of origin_pos
		## DÜZELTME (kullanıcı bildirimi: "assasin çocuk hala düzgün çalışmıyor
		## ultisi"): enemy.gd yaratıkları "enemies" (ÇOĞUL) grubuna ekliyor
		## (bkz. enemy.gd _ready -> add_to_group("enemies")) - burada YANLIŞLIKLA
		## "enemy" (TEKİL, hiç var olmayan bir grup) taranıyordu. Sonuç: bu
		## dizi HER ZAMAN boş geliyordu, target_enemy hiç bulunamıyor, ULTİ
		## daha İLK adımda sessizce "break" edip hiçbir şey yapmadan bitiyordu
		## (sadece savuruş efekti/flaş görünüp tek bir düşmana bile
		## çarpmıyordu) - kullanıcının "hala çalışmıyor" bildirdiği tam olarak
		## buydu.
		var enemies: Array = get_tree().get_nodes_in_group("enemies")
		var target_enemy: Node2D = null
		var min_dist: float = ASSASIN_DASH_RADIUS
		for e: Node in enemies:
			if not is_instance_valid(e):
				continue
			if e in hit_enemies:
				continue
			if e.get("is_dead") == true:
				continue
			if e is Node2D:
				var dist: float = origin_pos.distance_to((e as Node2D).global_position)
				if dist < min_dist:
					min_dist = dist
					target_enemy = e as Node2D

		# No more reachable enemies — stop early
		if not target_enemy:
			break

		## DÜZELTME (kullanıcı bildirimi: "çok hızlı ışınlanır gibi vuruyor
		## hiçbirşey anlaşılmıyor") - anında ışınlanmak (tek karede pozisyon
		## atlaması) yerine hedefe kısa bir sıçrayış tween'iyle gidiliyor, göz
		## takip edebilsin ve her vuruş ayrı ayrı okunabilsin diye.
		var start_pos: Vector2 = global_position
		var target_pos: Vector2 = target_enemy.global_position
		var dash_dir: Vector2 = target_pos - start_pos
		var lunge_tween := create_tween()
		lunge_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		lunge_tween.tween_method(func(p: Vector2): global_position = p, start_pos, target_pos, ASSASIN_DASH_LUNGE_TIME)
		await lunge_tween.finished

		# Hedef bu kısa sıçrayış sırasında öldüyse/geçersiz olduysa hasar verme
		if not is_instance_valid(target_enemy) or target_enemy.get("is_dead") == true:
			hit_enemies.append(target_enemy)
			continue

		# Deal damage
		## DÜZELTME: enemy.gd'nin take_damage() imzası
		## (amount: float, is_crit: bool = false, ...) - ikinci parametre
		## KESİNLİKLE bool. Burada yanlışlıkla "self" (Player node'unun
		## kendisi) veriliyordu; tip uyuşmazlığı yüzünden çağrı hata verip
		## hasar HİÇ işlenmiyordu (bkz. yukarıdaki "enemies" grup adı
		## düzeltmesiyle AYNI ultinin "hiçbir şey yapmıyormuş gibi görünme"
		## bildirimine katkıda bulunan ikinci kök neden).
		## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir" - her
		## sıçrayış/vuruş kendi kritik zarını atıyor.
		if target_enemy.has_method("take_damage"):
			var is_crit: bool = _roll_ability_crit()
			target_enemy.call("take_damage", _apply_ability_crit(total_damage, is_crit), is_crit)

		hit_enemies.append(target_enemy)
		assasin_dash_hits += 1

		if _assasin_dash_fx and is_instance_valid(_assasin_dash_fx) and _assasin_dash_fx.has_method("hit_flash"):
			_assasin_dash_fx.call("hit_flash")

		## DÜZELTME (kullanıcı isteği: "her bir yaratığa vurduğunda vuruş ses
		## efekti ve bıçak kesme efekti çıksın") - eskiden sadece mor bir
		## piksel patlaması (hit_flash) vardı, gerçek bir bıçak kesme
		## sprite'ı ve ses hiç yoktu. Artık bıçağın normal savuruş efektiyle
		## (fx_assasin_slash.tscn) AYNI sahne + rastgele bir kesme sesi her
		## isabette çalınıyor, katılımcılara da broadcast ediliyor.
		_spawn_assasin_dash_hit_fx(target_pos, dash_dir)

		# Brief delay between dashes - eskiden 0.07 idi, göz seçemiyordu.
		await get_tree().create_timer(ASSASIN_DASH_HIT_INTERVAL).timeout

	## DÜZELTME (kullanıcı bildirimi: "1 kere bi yaratığa doğru saldırdı sonra
	## yerinde hareketsiz bir gölge şeklinde kaldı"): burada eskiden sadece
	## "skill_timer = 0.0" yapılıyordu - ama _process_skill()'in en başındaki
	## "if skill_timer <= 0: return" kontrolü YÜZÜNDEN bu değer tam sıfıra
	## eşitlenince bir daha ASLA işlenmiyordu (fonksiyon her karede hemen en
	## başta çıkıyordu, "active" -> "cooldown" geçişini yapan ve
	## _end_skill_effects()'i çağıran koda hiç ulaşamıyordu). Sonuç: skill_
	## state sonsuza dek "active" + skill_timer sonsuza dek 0 olarak KİLİTLİ
	## kalıyordu - is_assasin_dashing hiç false'a dönmediği için karakter
	## hareketsiz kalıyor (bkz. _physics_process hareket kilidi), modulate de
	## hiç sıfırlanmadığı için karanlık "gölge" tonunda takılı kalıyordu.
	## Artık _cancel_active_skill_early() (Şovalye/Kurt Adam'ın kendini
	## erken iptal etmesiyle AYNI, doğrulanmış yardımcı fonksiyon) çağrılıyor -
	## bu doğrudan _end_skill_effects()'i (modulate/is_assasin_dashing/dash FX
	## sıfırlaması dahil) çalıştırıp state'i "cooldown"a alıyor, yarış
	## koşuluna hiç düşmüyor.
	##
	## DÜZELTME (kullanıcı isteği: "ultisini kullanıp yaratıklara vurduktan
	## sonra kullandığı konuma geri dönsün") - vuruş zinciri karakteri
	## haritada rastgele bir yere sürüklüyordu, ulti bitince oyuncu orada
	## kalıyordu. Zincir bitince (düşman bulunamadı/max_hits/ölüm) cast
	## noktasına (origin_pos) aynı lunge-tween ile kısa bir dönüş yapılır -
	## ölmüşse veya sahneden ayrıldıysa bu adım atlanır.
	if is_inside_tree() and not is_dead and global_position != origin_pos:
		var return_tween := create_tween()
		return_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		return_tween.tween_method(func(p: Vector2): global_position = p, global_position, origin_pos, ASSASIN_DASH_LUNGE_TIME)
		await return_tween.finished
	if death_camera and is_instance_valid(death_camera):
		death_camera.position_smoothing_enabled = _dash_cam_was_smoothing
		death_camera.position_smoothing_speed = _dash_cam_prev_speed
	_cancel_active_skill_early()


func _skill_haste() -> void:
	skill_speed_multiplier = 1.7
	modulate = Color(0.6, 0.9, 1.0, 1.0)
	_spawn_burst(Color(0.4, 0.9, 1.0))
	
	if FxBuyucuFastfireScene:
		var fx := FxBuyucuFastfireScene.instantiate() as Node2D
		add_child(fx)
	_broadcast_skill_scene("res://scenes/fx_buyucu_fastfire.tscn")


const OAKLEY_HEAL_INSTANT_PERCENT := 0.15
const OAKLEY_HEAL_TAIL_PERCENT := 0.05 ## per second, for _skill_duration (6s) via heal_regen_bonus
const OAKLEY_HEAL_RANGE := 300.0


## Oakley: instant heal to self + nearest ally in range, then both keep healing
## %5/sec of their OWN max health for the rest of the 6s active window (see
## SKILL_TIMING) - heal_regen_bonus expiring is handled generically by
## _end_skill_effects(), same mechanism Şifacı's heal already uses.
func _skill_heal_aura() -> void:
	## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir ... can ve
	## kalkan verme de dahil bunlar pozitif olarak artacak".
	var heal_amount: float = _apply_ability_crit(max_health * OAKLEY_HEAL_INSTANT_PERCENT, _roll_ability_crit())
	health = min(max_health, health + heal_amount)
	health_changed.emit(health, max_health)
	_spawn_floating_text("%d" % int(round(heal_amount)), Color(0.4, 0.9, 0.45), true)
	heal_regen_bonus = max_health * OAKLEY_HEAL_TAIL_PERCENT

	var ally: Node2D = _nearest_ally_in_range(OAKLEY_HEAL_RANGE)
	if ally and is_instance_valid(ally) and "max_health" in ally:
		var ally_heal: float = _apply_ability_crit(ally.max_health * OAKLEY_HEAL_INSTANT_PERCENT, _roll_ability_crit())
		if ally.has_method("heal"):
			ally.heal(ally_heal)
		if ally.has_method("set_temp_heal_regen"):
			ally.set_temp_heal_regen(ally.max_health * OAKLEY_HEAL_TAIL_PERCENT, _skill_duration, self, OAKLEY_HEAL_RANGE)

	_spawn_burst(Color(0.3, 1.0, 0.5))
	
	if FxOykuHealScene:
		var fx := FxOykuHealScene.instantiate() as Node2D
		add_child(fx)
	_broadcast_skill_scene("res://scenes/fx_oyku_heal.tscn")


## DÜZELTME (kullanıcı isteği: "Oakleyin pasifi silinecek ve Q su bundan sonra
## pasifi olacak") - Çiçek artık bir Q/skill yeteneği DEĞİL, tamamen otomatik
## bir pasif (bkz. _process_oakley_passive/_spawn_oakley_flower_auto,
## yukarıda) - eski 2-yük/18sn şarj sistemi (OAKLEY_FLOWER_MAX_CHARGES/
## oakley_flower_charges/_try_oakley_flower) ve Q girdisi tamamen kaldırıldı.
## Oakley: Sarmaşıklar yeteneği (TEMEL/E, skill2 id 10 - _skill_kalkan_
## yenileme() tarafından yönlendiriliyor, bkz. o fonksiyonun üstündeki not).
## 3 sarmaşık oluşturur - HER biri kendi hedefini yakındaki yaratıklardan
## RASTGELE seçer (bkz. oakley_vine.gd _pick_new_target), 3'ü de en yakın
## AYNI yaratığa kilitlenip "sıraya girmez". DÜZELTME (kullanıcı isteği:
## "senkronize et, diğer oyuncular da öyle görmeli") - necro pet'lerle
## BİREBİR AYNI görev ayrımı (bkz. _broadcast_necro_pet_spawn): burada SADECE
## spawn/despawn yayınlanır, sarmaşığın KENDİSİ konum/hedef durumunu kendi
## _process'inde periyodik olarak yayınlar (bkz. oakley_vine.gd
## _broadcast_network_state).
const OAKLEY_VINES_COUNT := 3
var _oakley_vine_id_counter: int = 0

func _skill_oakley_vines() -> void:
	for i in range(OAKLEY_VINES_COUNT):
		var vine := Node2D.new()
		vine.set_script(preload("res://scripts/oakley_vine.gd"))
		get_tree().current_scene.add_child(vine)
		vine.global_position = global_position
		vine.call("setup", damage_bonus)
		if NetworkManager.is_multiplayer_active:
			_oakley_vine_id_counter += 1
			var vine_id: String = "%d_%d" % [multiplayer.get_unique_id(), _oakley_vine_id_counter]
			vine.network_instance_id = vine_id
			NetworkManager.broadcast_oakley_vine_spawn.rpc(multiplayer.get_unique_id(), vine_id)
			vine.tree_exiting.connect(func() -> void:
				if NetworkManager.is_multiplayer_active:
					NetworkManager.broadcast_oakley_vine_despawn.rpc(multiplayer.get_unique_id(), vine_id)
			)
	_spawn_burst(Color(0.35, 0.75, 0.3))


## Oakley: Arı Sürüsü yeteneği (3. Yetenek/R, skill3 id 33 - bkz.
## _activate_skill3()'teki match dalı). DÜZELTME (kullanıcı isteği:
## "senkronize et, diğer oyuncular da öyle görmeli") - bkz. oakley_bee_
## swarm.gd dosya başı notu: sabit konumda durduğu için TEK SEFERLİK bir
## "skill_ring"/"hitscan_impact" tarzı broadcast yeterli, sürekli senkron
## gerekmiyor (oakley_vine.gd'nin aksine).
func _skill_oakley_bee_swarm() -> void:
	var swarm := Node2D.new()
	swarm.set_script(preload("res://scripts/oakley_bee_swarm.gd"))
	get_tree().current_scene.add_child(swarm)
	swarm.global_position = global_position
	swarm.call("setup", damage_bonus)
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "oakley_bee_swarm_spawn", global_position, {})


## ---------- Oakley YENİ R: Koruyucu Büyü (skill3 id 39) ----------
## Kullanıcı isteği: "Yeni R yeteneği ise canı en az olan arkadaşına koruyucu
## bir büyü yapar bu büyü 8 saniye boyunca aktif kalır ve kişi her hasar
## aldığında oakley'in saldırı gücünün %10'u kadar can yeniler ve aynı
## şekilde her hasar aldığında oakley'in saldırı gücünün %5'i kadar kalkan
## yeniler ayrıca dost birey bu esnada %20 hasar azaltma kazanır. Eğer canı
## en az olan kişi oakleyse bu büyüyü kendisine yapar. Canı en az olan
## önceliklidir. (60 saniye bekleme süresi)"
##
## Heal/kalkan miktarları CAST ANINDA Oakley'nin o anki saldırı gücünden
## SABİTLENİR (flower/arı sürüsünün "caster_damage_bonus" anlık görüntüsüyle
## AYNI desen) - böylece hedef başka bir peer'sa bile her isabet için
## Oakley'nin GÜNCEL statlarına ağ üzerinden erişmeye gerek kalmaz, hedef
## kendi take_damage()'ında tamamen yerel olarak uygular (bkz. aşağıdaki
## oakley_bond_* alanları/take_damage() içindeki kullanım).
const OAKLEY_BOND_RANGE := 400.0 ## bkz. PALADIN_BARRIER_BREAK_RANGE ile aynı mertebe
const OAKLEY_BOND_DURATION := 8.0
const OAKLEY_BOND_HEAL_RATIO := 0.10
const OAKLEY_BOND_SHIELD_RATIO := 0.05
const OAKLEY_BOND_DAMAGE_REDUCTION := 0.20

## Bu oyuncu ŞU AN birinin Koruyucu Büyü hedefiyse (kendi büyüsü de dahil)
## dolu olan alanlar - take_damage() bunları okur, _process_oakley_bond
## süresini işler.
var oakley_bond_active: bool = false
var oakley_bond_heal_per_hit: float = 0.0
var oakley_bond_shield_per_hit: float = 0.0
var oakley_bond_damage_reduction: float = 0.0
var oakley_bond_timer: float = 0.0


func _skill_oakley_bond() -> void:
	var target: Node2D = _oakley_lowest_hp_bond_target(OAKLEY_BOND_RANGE)
	if not target:
		return
	var heal_per_hit: float = damage_bonus * OAKLEY_BOND_HEAL_RATIO
	var shield_per_hit: float = damage_bonus * OAKLEY_BOND_SHIELD_RATIO
	_apply_oakley_bond_to_target(target, heal_per_hit, shield_per_hit, OAKLEY_BOND_DAMAGE_REDUCTION, OAKLEY_BOND_DURATION)
	_spawn_wave_beam_to_ally(target, "shield")
	_spawn_burst(Color(0.4, 1.0, 0.55))


## "Canı en az olan önceliklidir" - kendisi DAHİL (bkz. kullanıcı isteği:
## "Eğer canı en az olan kişi oakleyse bu büyüyü kendisine yapar"), oran
## bazlı (health/max_health), downed/dead olanlar hariç (downed iken health/
## max_health GERÇEK can yerine diriltme oranını taşır - bkz. get_revive_
## progress_ratio üstündeki yorum, bu yüzden burada anlamsız/yanıltıcı
## olurdu). Sadece gerçek oyuncular (peer_id'si olanlar) hedeflenir, evcil
## hayvanlar/yaratıklar DEĞİL - _apply_oakley_bond_to_target zaten sadece
## self ya da peer_id'li bir hedefle çalışabiliyor.
func _oakley_lowest_hp_bond_target(max_range: float) -> Node2D:
	var best: Node2D = null
	var best_ratio: float = INF
	if not is_dead and not is_downed and max_health > 0.0:
		best = self
		best_ratio = health / max_health
	for ally in get_tree().get_nodes_in_group("player_ally"):
		if not is_instance_valid(ally) or not ("max_health" in ally) or not ("health" in ally):
			continue
		if not ("peer_id" in ally):
			continue
		if ally.get("is_dead") == true or ally.get("is_downed") == true:
			continue
		if float(ally.get("max_health")) <= 0.0:
			continue
		if global_position.distance_to(ally.global_position) > max_range:
			continue
		var ratio: float = float(ally.get("health")) / float(ally.get("max_health"))
		if ratio < best_ratio:
			best = ally
			best_ratio = ratio
	return best


## Hedef kendisiyse doğrudan yerel alanlara yazar; başka bir peer'sa (bkz.
## _apply_damage_redirect_to_ally ile AYNI desen, network_manager.gd
## sync_damage_redirect_buff) hedefin KENDİ istemcisine RPC ile iletir - o
## istemci kendi take_damage()'ında tamamen yerel olarak uygular.
func _apply_oakley_bond_to_target(target: Node2D, heal_per_hit: float, shield_per_hit: float, reduction: float, duration: float) -> void:
	if target == self:
		oakley_bond_active = true
		oakley_bond_heal_per_hit = heal_per_hit
		oakley_bond_shield_per_hit = shield_per_hit
		oakley_bond_damage_reduction = reduction
		oakley_bond_timer = duration
		return
	if not is_instance_valid(target) or not ("peer_id" in target):
		return
	var target_peer_id: int = int(target.get("peer_id"))
	if target_peer_id <= 0 or not NetworkManager.is_multiplayer_active:
		return
	NetworkManager.sync_oakley_bond_buff.rpc(target_peer_id, heal_per_hit, shield_per_hit, reduction, duration)


func _process_oakley_bond(delta: float) -> void:
	if not oakley_bond_active:
		return
	oakley_bond_timer -= delta
	if oakley_bond_timer <= 0.0:
		oakley_bond_active = false
		oakley_bond_heal_per_hit = 0.0
		oakley_bond_shield_per_hit = 0.0
		oakley_bond_damage_reduction = 0.0


## Çiçek alındığında 2sn boyunca azalarak kaybolan geçici hareket hızı
## bonusu (bkz. oakley_flower.gd _pick_up -> apply_temp_speed_boost). Genel/
## karaktersiz bir yardımcı - şu an SADECE Çiçek kullanıyor ama isim/kapsam
## başka bir gelecek yetenek için de kullanılabilir bırakıldı.
var _temp_speed_boost_percent: float = 0.0
var _temp_speed_boost_timer: float = 0.0
var _temp_speed_boost_initial_duration: float = 0.0

func apply_temp_speed_boost(percent: float, duration: float) -> void:
	_temp_speed_boost_percent = percent
	_temp_speed_boost_timer = duration
	_temp_speed_boost_initial_duration = duration


func _current_temp_speed_boost() -> float:
	if _temp_speed_boost_timer <= 0.0 or _temp_speed_boost_initial_duration <= 0.0:
		return 0.0
	## Kullanıcı isteği: "2 saniyeliğine alan kişiye azalarak kaybolacak
	## şekilde %25 hareket hızı kazandırır" - lineer olarak sıfıra iniyor.
	return _temp_speed_boost_percent * (_temp_speed_boost_timer / _temp_speed_boost_initial_duration)


func _process_temp_speed_boost(delta: float) -> void:
	if _temp_speed_boost_timer > 0.0:
		_temp_speed_boost_timer = max(0.0, _temp_speed_boost_timer - delta)


## Şovalye Adam VE Melek: TEMEL yetenek (skill2 id 10) - 6 saniye boyunca az
## miktarda kalkan yeniler, gerçek regen miktarı _process_kalkan_yenileme()'de
## tikle hesaplanır (bkz. skill2_duration = 6.0, SKILL2_TIMING). İkisi de
## GERÇEK Kalkan Yenileme kullanıyor, sadece bekleme süreleri farklı (bkz.
## _skill2_timing_for).
## DÜZELTME (kullanıcı isteği: "Oakley yeni yetenekleri", sonra "Oakley ve
## Melek aynı karakter değil, Melek'e dokunma") - Oakley AYNI id'yi (10)
## paylaşıyor ama onun TEMEL'i artık Sarmaşıklar (bkz. _skill_oakley_vines) -
## bu fonksiyona hâlâ Oakley için de girilir (match skill2_id: 10:
## _skill_kalkan_yenileme() hiç değişmedi), o yüzden en başta ayrılıp asıl
## Kalkan Yenileme mantığı (aşağısı) Şovalye VE Melek'te çalışıyor, SADECE
## Oakley'de Sarmaşıklar'a yönleniyor.
func _skill_kalkan_yenileme() -> void:
	if GameManager.selected_char_id == 2:
		_skill_oakley_vines()
		return
	is_kalkan_yenileme_active = true
	_oakley_e_tick_timer = 0.0
	## DÜZELTME (#25): eskiden yanlışlıkla _lowest_health_ally_in_range()
	## kullanıyordu (can bazlı) - bu bir KALKAN yenileme yeteneği, hedefi
	## kalkanı en az olan (bkz. _lowest_shield_ally_in_range) müttefik olmalı.
	_oakley_e_ally_target = _lowest_shield_ally_in_range(OAKLEY_E_RANGE)
	_melek_shield_ally_aura_on = false
	if _oakley_e_ally_target and is_instance_valid(_oakley_e_ally_target):
		_spawn_wave_beam_to_ally(_oakley_e_ally_target, "shield")
		## Kullanıcı isteği ("efekt sistemi" - kalkan.png): "dost bireyin
		## içinde belirecek".
		_set_ally_aura(_oakley_e_ally_target, "shield", true)
		_melek_shield_ally_aura_on = true
	## "...ayrıca meleğin üzerindede aynı şekilde gerçekleşecek" - SADECE
	## Melek'te (Paladin/Şovalye Adam bu GENERİK formüle inmiyor, bkz.
	## _process_kalkan_yenileme'deki char_id ayrımı).
	if GameManager.selected_char_id == 10:
		stop_self_aura_fx("shield") ## önceki kullanımdan kalmış olabilir
		_ally_aura_fx["shield"] = _play_and_broadcast_skill_fx(FxMelekShieldAuraScene)
	_spawn_burst(Color(0.3, 0.6, 1.0))
	
	if FxKalkanYenilemeScene:
		var fx := FxKalkanYenilemeScene.instantiate() as Node2D
		add_child(fx)
	_broadcast_skill_scene("res://scenes/fx_kalkan_yenileme.tscn")



const KURTADAM_SLASH_RADIUS := 140.0
const KURTADAM_SLASH_DAMAGE_MULT := 1.2 ## saldırı gücünün %120'si
const KURTADAM_SLASH_LIFESTEAL_PERCENT := 0.04 ## verilen hasarın %4'ü can çalar


## Kurt Adam'ın "saldırı gücü" olarak Pençe silahının (bkz. shop_key meta)
## o anki tam hesaplanmış hasarı (temel + kart + dükkan bonusları dahil)
## kullanılır - sahibi değilse (olmamalı, ama güvenlik için) ilk silahına,
## o da yoksa düz damage_bonus statına düşer.
func _kurtadam_attack_power() -> float:
	for w in owned_weapon_nodes:
		if not is_instance_valid(w):
			continue
		if w.get_meta("shop_key", "") == "pence" and "damage" in w:
			return w.damage
	if owned_weapon_nodes.size() > 0 and is_instance_valid(owned_weapon_nodes[0]) and "damage" in owned_weapon_nodes[0]:
		return owned_weapon_nodes[0].damage
	return damage_bonus


## Kurt Adam TEMEL (skill2 id 13): "etrafındakileri büyük bir slash ile
## kesip saldırı gücünün %120si kadar hasar verir ve bu yetenekle verdiği
## hasarın %4ü kadar can çalar."
func _skill_kurtadam_slash() -> void:
	var attack_power: float = _kurtadam_attack_power()
	## Kullanıcı isteği: alan hasarı global %33 etkinlik (bkz. GameManager.
	## AOE_DAMAGE_EFFECTIVENESS) - bu yetenek etraftaki TÜM düşmanlara vurduğu
	## için alan hasarı sayılıyor.
	var slash_damage: float = attack_power * KURTADAM_SLASH_DAMAGE_MULT * GameManager.AOE_DAMAGE_EFFECTIVENESS
	## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir" - can
	## çalma (lifesteal) hasara bağlı olduğu için (aşağıda total_dealt
	## üzerinden) kritik burada zaten otomatik olarak iyileştirmeye de yansır.
	var is_crit: bool = _roll_ability_crit()
	slash_damage = _apply_ability_crit(slash_damage, is_crit)
	var total_dealt: float = 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if global_position.distance_to(e.global_position) <= KURTADAM_SLASH_RADIUS:
			if e.has_method("take_damage"):
				e.take_damage(slash_damage, is_crit)
				total_dealt += slash_damage
	if total_dealt > 0.0:
		## Kullanıcı isteği: can çalma global %33 etkinlik (bkz. GameManager.
		## LIFESTEAL_EFFECTIVENESS). total_dealt zaten yukarıdaki AOE
		## çarpanını içeren slash_damage'dan geliyor, bu ayrı bir can çalma
		## çarpanı.
		var healed: float = total_dealt * KURTADAM_SLASH_LIFESTEAL_PERCENT * GameManager.LIFESTEAL_EFFECTIVENESS
		health = min(max_health, health + healed)
		health_changed.emit(health, max_health)
		_spawn_floating_text("%d" % int(round(healed)), Color(0.4, 0.9, 0.45), true)
	_spawn_burst(Color(1.0, 0.15, 0.1))
	
	if FxKurtadamRageScene:
		var fx := FxKurtadamRageScene.instantiate() as Node2D
		add_child(fx)
	_broadcast_skill_scene("res://scenes/fx_kurtadam_rage.tscn")


## Matthew TEMEL (Vahşi Hız, skill2 id 21) - "kendine ve tilkisine 10 saniye
## boyunca %40 saldırı hızı ve %15 hareket hızı kazandırır." DÜZELTME
## (kullanıcı bildirimi: "matthewin E yeteneği kendinde işlemiyor ve onda
## efektler çalışmıyor") - kök neden: characters.gd'de tanımlanan bu yetenek
## (id 21) _activate_skill2()'nin eşleme tablosunda HİÇ yoktu, yani E'ye
## basılınca sadece skill2_state/timer makinesi çalışıyor ama gerçekte HİÇBİR
## fonksiyon tetiklenmiyordu. Tilki (player_pet.gd _get_speed_mult/
## _get_attack_speed_mult) zaten is_skill2_active()+get_skill2_id()==21'i
## KENDİ BAŞINA dinlediği için hiç etkilenmemişti - eksik olan SADECE
## Matthew'in kendi silahlarına/hareketine uygulanan kısımdı.
const MATTHEW_HASTE_ATTACK_SPEED_MULT := 1.4 ## %40 daha hızlı saldırı
const MATTHEW_HASTE_MOVE_SPEED_MULT := 1.15 ## %15 daha hızlı hareket

func _skill_matthew_haste() -> void:
	skill2_speed_multiplier = MATTHEW_HASTE_MOVE_SPEED_MULT
	for w in owned_weapon_nodes:
		if not is_instance_valid(w):
			continue
		if "fire_rate_multiplier" in w:
			w.fire_rate_multiplier = 1.0 / MATTHEW_HASTE_ATTACK_SPEED_MULT
	_spawn_burst(Color(1.0, 0.75, 0.15))


## player_pet.gd _physics_process'teki tilki hız çizgisi kontrolüyle BİREBİR
## AYNI desen (bkz. FxSpeedLineScene notu) - sadece Matthew'in KENDİ hızına/
## konumuna uygulanıyor. Kullanıcı bildirimi: "tilkisinde çıkıyor ama
## kendisine çıkmıyor".
func _process_matthew_speed_lines(delta: float) -> void:
	if not (is_skill2_active() and get_skill2_id() == 21):
		return
	if velocity.length() <= 20.0:
		return
	_matthew_speed_line_timer -= delta
	if _matthew_speed_line_timer <= 0.0:
		_matthew_speed_line_timer = 0.05
		_spawn_matthew_speed_line(velocity)


## DÜZELTME (kullanıcı bildirimi: "bazı karakterler ve yetenekleri
## multiplayerda çalışmıyor ve görünmüyor"): bu efekt eskiden SADECE
## Matthew'i oynayan istemcinin kendi ekranında görünüyordu - diğer
## istemcilere hiç yayınlanmıyordu (network_manager.gd'ye yeni "speed_line"
## vfx_type'ı eklendi, bkz. orada).
func _spawn_matthew_speed_line(dir: Vector2) -> void:
	if not FxSpeedLineScene:
		return
	var fx := FxSpeedLineScene.instantiate() as Node2D
	get_tree().current_scene.add_child(fx)
	var offset := Vector2(randf_range(-4.0, 4.0), randf_range(-6.0, 6.0))
	var spawn_pos: Vector2 = global_position + offset
	var line_color := Color(1.0, 0.75, 0.15, 0.75)
	fx.global_position = spawn_pos
	fx.setup(dir, line_color)
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "speed_line", spawn_pos, {
			"scene_path": "res://scenes/fx_speed_line.tscn",
			"direction": dir,
			"color": line_color,
		})


const TALON_SLAM_STUN_DURATION := 3.0
const TALON_SLAM_RADIUS := 260.0

## #56 DÜZELTME (kullanıcı bildirimi: "talonun yetenekleri yanlış ziva
## yüzünden yetenekleri bozulmuş - asıl yetenekleri ultisi kendisini
## devleştiren birşeydi temel skili de yere vurup sersemletmeydi"):
## characters.gd Talon'u ULTİ (skill id 15, Devleşme) + TEMEL (skill2 id 8,
## Yer Sarsıntısı - tam olarak aşağıdaki _skill_berserk()) olarak
## TANIMLIYORDU, ama:
##   1) _activate_skill()'in eşleme tablosunda id 15 için HİÇ case yoktu -
##      Talon'un ultisi sessizce en alttaki varsayılana (_skill_heal(),
##      Oakley'nin Can Basma'sı) düşüyordu.
##   2) _skill_berserk() (Yer Sarsıntısı'nın GERÇEK kodu) yanlışlıkla
##      _activate_skill()'in (ULTİ) eşleme tablosunda "8:" olarak duruyordu -
##      ama Talon'un ULTİ id'si 15, TEMEL id'si 8 (characters.gd'ye bkz.) -
##      hiçbir karakterin "skill" (ulti) id'si 8 olmadığı için bu case zaten
##      hiç tetiklenmiyordu, ve gerçek TEMEL (_activate_skill2) tablosunda id
##      8 için hiçbir case YOKTU - yani E tuşuna basınca hiçbir şey olmuyordu.
## Artık _skill_berserk() _activate_skill2()'ye taşındı (bkz. o fonksiyon),
## SKILL_TIMING/SKILL2_TIMING de doğru id'lere göre düzeltildi.
## DÜZELTME (zırh kaldırıldı): eskiden zırh VE can %30 artardı, artık sadece
## can artıyor.
const TALON_DEVASA_STAT_BONUS_PERCENT := 0.30 ## can %30 artar
const TALON_DEVASA_SCALE_MULT := 2.0 ## boyut 2 katına çıkar
const TALON_DEVASA_AOE_MULT := 2.0 ## vuruş alanı (menzil DEĞİL) 2 katına çıkar
var _talon_devasa_health_bonus: float = 0.0
## main.gd extra["talon_giant"] bunu okuyup remote_player.gd'ye yayınlıyor ki
## Talon'un devleşme (2x boyut) görseli DİĞER oyunculara da yansısın (bkz.
## remote_player.gd update_extra_state_from_net -> _talon_giant_active).
var _talon_ulti_active: bool = false
var _talon_aura_sprite: Sprite2D = null
var _talon_aura_tween: Tween = null


## Talon ULTİ (Devleşme, skill id 15): "15sn boyunca boyutu ve saldırılarının
## vuruş alanı (menzil değil) 2 katına çıkar, canı da %30 artar." Geri alma
## _end_skill_effects()'te yapılır (anim.scale zaten oradaki genel
## sıfırlamayla, can ise _talon_devasa_health_bonus üzerinden).
func _skill_talon_devasa() -> void:
	_talon_ulti_active = true
	anim.scale = char_base_anim_scale * TALON_DEVASA_SCALE_MULT
	for w in owned_weapon_nodes:
		if not is_instance_valid(w):
			continue
		if "aoe_radius_multiplier" in w:
			w.aoe_radius_multiplier = TALON_DEVASA_AOE_MULT
	_talon_devasa_health_bonus = max_health * TALON_DEVASA_STAT_BONUS_PERCENT
	max_health += _talon_devasa_health_bonus
	health += _talon_devasa_health_bonus
	health_changed.emit(health, max_health)
	
	# Talon devasa iken tıpkı Goku'nun Kaio-ken'i gibi kırmızıya döner
	anim.modulate = Color(1.0, 0.4, 0.4, 1.0)
	
	if not _talon_aura_sprite:
		_talon_aura_sprite = Sprite2D.new()
		_talon_aura_sprite.texture = preload("res://assets/generated/talon_kaioken_aura_base_frame_0.png")
		_talon_aura_sprite.z_index = -1
		# Karakterin ayaklarına/merkezine doğru oturması için pozisyon ayarı
		_talon_aura_sprite.position = Vector2(0, 5)
		anim.add_child(_talon_aura_sprite)
		
	_talon_aura_sprite.show()
	_talon_aura_sprite.scale = Vector2(1.8, 1.8) # Aura, Talon devasa iken daha geniş görünür
	_talon_aura_sprite.modulate = Color(1, 1, 1, 0.6)
	
	if _talon_aura_tween:
		_talon_aura_tween.kill()
	_talon_aura_tween = create_tween().set_loops()
	_talon_aura_tween.tween_property(_talon_aura_sprite, "modulate:a", 0.4, 0.4)
	_talon_aura_tween.parallel().tween_property(_talon_aura_sprite, "scale", Vector2(1.9, 1.9), 0.4)
	_talon_aura_tween.tween_property(_talon_aura_sprite, "modulate:a", 0.8, 0.4)
	_talon_aura_tween.parallel().tween_property(_talon_aura_sprite, "scale", Vector2(1.7, 1.7), 0.4)
	
	_spawn_burst(Color(1.0, 0.2, 0.2)) # Burst rengini de kırmızı yaptık
	## DÜZELTME (derin multiplayer görsel denetimi): bu fonksiyon her zaman
	## fx_talha_rage.tscn'i YAYINLIYORDU ama kendi ekranında hiç
	## instantiate ETMİYORDU (bkz. _skill_talon_slam'daki eşleşen yerel
	## instantiate) - caster sadece aura+kırmızı ton+burst görüyordu, uzak
	## oyuncular ise ayrıca tam bir yer-sarsıntısı efekti görüyordu.
	if FxTalhaRageScene:
		var devasa_fx := FxTalhaRageScene.instantiate() as Node2D
		add_child(devasa_fx)
	_broadcast_skill_scene("res://scenes/fx_talha_rage.tscn")


## ================= Talon YENİ KİT (kullanıcı isteği: "Talon yeni
## skilleri") =================
## Üç yetenek de silah TEMALI: Silah Salvosu (TEMEL/E, id 36) ve Ayna Formu
## (3. yetenek/R, id 37 - kullanıcı isteği: "R ile Q'nun yerini değiştir"
## sonrası) ikisi de owned_weapon_nodes'u karakterin etrafında dairesel
## dizen TEK ortak yardımcıyı (_talon_set_weapons_circular) kullanıyor -
## CLAUDE.md'nin uyardığı "iki ayrı yer" hatasına düşmemek için
## formül TEK yerde.
##
## BİLİNÇLİ MİMARİ KARAR: weapon.gd'nin ateş mantığı TAMAMEN hedef-node
## tabanlı (_get_target_enemy() → _fire_at(target: Node2D)) - 15 farklı
## silah tipini (asa/tabanca/kılıç/yay vb.) "hedefsiz, belirli bir yöne ateş
## et" durumuna zorlamak TÜM silah sistemini riske atardı. Silah Salvosu bu
## yüzden silahların GERÇEK fire()'ını çağırmıyor - onun yerine (Şovalye'nin
## bariyeri/totemler gibi mevcut "özel hasar kaynağı" desenleriyle AYNI
## felsefeyle) silahları KOZMETİK olarak döndürüp ayrı, bağımsız bir alan-
## hasarı tick'i uyguluyor. Ayna Formu ise GERÇEK, bağımsız ateş eden
## kopyalar için mevcut buy_weapon_copy() silah-oluşturma yolunu yeniden
## kullanıyor (get_max_owned_weapons()'daki geçici sınır gevşetmesiyle).

## Silahları (owned_weapon_nodes) merkez (karakter) etrafında EŞİT açılarla
## dairesel konumlandırır - hem Silah Salvosu'nun dönen tek turu hem Ayna
## Formu'nun sabit dizilimi tarafından kullanılan TEK ortak yardımcı.
## _talon_set_weapons_circular VE _talon_salvo_damage_tick'in İKİSİNİN DE
## kullandığı TEK ortak liste - hangi silahın dizideki hangi index'te (yani
## hangi açıda) olduğu iki yerde de BİREBİR aynı sırayla eşleşsin diye (yoksa
## görsel konum ile hasar hattı birbirinden sapabilirdi).
func _talon_iconed_weapons() -> Array:
	var iconed: Array = []
	for w in owned_weapon_nodes:
		if is_instance_valid(w) and w.has_method("set_icon_offset"):
			iconed.append(w)
	return iconed


func _talon_set_weapons_circular(radius: float, angle_offset: float) -> void:
	var iconed: Array = _talon_iconed_weapons()
	if iconed.is_empty():
		return
	var count: int = iconed.size()
	for i in range(count):
		var w = iconed[i]
		## bkz. talon_formation_math.gd dosya başı notu - remote_player.gd
		## (kozmetik kopya) BİREBİR AYNI formülü _update_talon_formation'da
		## çağırıyor, TEK kaynak burada.
		var slot: Dictionary = TalonFormationMath.compute_slot(i, count, radius, angle_offset)
		w.set_icon_offset(slot["offset"])
		## Namlu/ucu dışa doğru baksın (kullanıcı isteği) - silahın kendi
		## hedefe-dönme mantığını (_update_aim) geçici olarak devre dışı
		## bırakıp rotasyonu burada elle veriyoruz (bkz. weapon.gd
		## icon_faces_target - _talon_restore_weapon_aim() sonunda geri açar).
		## DÜZELTME (kullanıcı bildirimi: "namlu uçları içe doğru bakıyor
		## dışarı doğru bakması gerekiyor") - "slot.angle - forward" _update_
		## aim()'deki (hedefe dönük bakma) formülüyle AYNIYDI ama namlunun
		## kendi ucu sprite'ta merkeze doğru çizilmiş olduğu için sonuç ters
		## (içe dönük) çıkıyordu - +PI ile 180° çevrilip dışa dönük hale
		## getirildi (bkz. remote_player.gd _update_talon_formation - AYNI
		## düzeltme orada da uygulandı, formül iki dosyada asla sapamaz).
		if "icon_faces_target" in w:
			w.icon_faces_target = false
		if w.icon_sprite:
			## DÜZELTME (kullanıcı bildirimi: "silahların dışa bakması
			## gerekirken içe bakıyorlar") - slot["angle"] compute_slot'ta
			## zaten merkezden dışa bakan açı (offset de aynı açıyla
			## hesaplanıyor, bkz. talon_formation_math.gd), _update_aim'deki
			## genel "rotation = hedef_açısı - forward" kuralıyla AYNI
			## formül kullanılmalı. Eski +PI fazladan 180° ekleyip namluları
			## içe (karaktere doğru) çeviriyordu - remote_player.gd
			## _update_talon_formation'daki AYNI düzeltme.
			w.icon_sprite.rotation = slot["angle"] - deg_to_rad(float(w.sprite_forward_angle_deg))


## Yukarıdaki fonksiyonun icon_faces_target=false yaptığı TÜM silahlarda
## normal hedefe-dönme davranışını geri açar - hem Silah Salvosu hem Ayna
## Formu bitişinde çağrılır.
func _talon_restore_weapon_aim() -> void:
	for w in owned_weapon_nodes:
		if is_instance_valid(w) and "icon_faces_target" in w:
			w.icon_faces_target = true


## ---------- Silah Salvosu (TEMEL/E, skill2 id 36) ----------
## "Tüm silahlarını paralel bir şekilde yan yana aynı yönde tutar ve onlarla
## saldırı salvosu başlatır ... namluları/uçları dışa doğru bakarak
## karakterin etrafında 2 tur atar ... silahlar %200 saldırı hızı kazanır,
## tüm bu olanlar 3 saniye sürer." - bkz. dosya başı "BİLİNÇLİ MİMARİ KARAR"
## notu: gerçek hasar weapon.gd'nin kendi fire()'ı yerine _talon_salvo_
## damage_tick()'teki bağımsız alan-hasarıyla veriliyor.
const TALON_SALVO_DURATION := TalonFormationMath.SALVO_DURATION
const TALON_SALVO_ROTATIONS := TalonFormationMath.SALVO_ROTATIONS
const TALON_SALVO_RADIUS := TalonFormationMath.SALVO_RADIUS ## WeaponOrbitMath.BASE_ORBIT_RADIUS ile AYNI görsel dil (bkz. weapon_orbit_math.gd)
const TALON_SALVO_HIT_MARGIN := 40.0 ## dönüş yarıçapının ötesinde de biraz isabet payı
const TALON_SALVO_FIRE_RATE_MULT := 1.0 / 3.0 ## +%200 saldırı hızı = 3 kat hızlı = 1/3 bekleme
const TALON_SALVO_TICK_INTERVAL := 0.25
const TALON_SALVO_TICK_DAMAGE_MULT := 0.4 ## her tick'te toplam silah hasarının bu kadarı
## DÜZELTME (kullanıcı bildirimi: "talonun E si aktifken silahlar sıkmadıkları
## yerlere de hasar veriyor, dönerken düz bir doğrultuda ateş etmesi lazım") -
## eskiden hasar TÜM yönlerde (karakter etrafında tam bir daire, hit_radius)
## uygulanıyordu; artık HER silah SADECE kendi o anki namlu doğrultusundaki
## dar bir HAT üzerinde (bkz. _talon_salvo_damage_tick, Geometry2D.
## get_closest_point_to_segment - _skill_talon_dash'teki AYNI çizgi-tabanlı
## isabet deseni) hasar veriyor.
const TALON_SALVO_HIT_WIDTH := 44.0 ## her silahın hasar hattının genişliği (Talon'un kendi dash'indeki TALON_DASH_HIT_WIDTH ile aynı mertebede)
var _talon_weapon_salvo_active: bool = false
var _talon_salvo_elapsed: float = 0.0
var _talon_salvo_tick_timer: float = 0.0
var _talon_salvo_angle_offset: float = 0.0 ## _talon_salvo_damage_tick'in o anki namlu açılarını yeniden hesaplayabilmesi için _process_talon_weapon_salvo'da yazılır


func _skill_talon_weapon_salvo() -> void:
	_talon_weapon_salvo_active = true
	_talon_salvo_elapsed = 0.0
	_talon_salvo_tick_timer = 0.0
	for w in owned_weapon_nodes:
		if not is_instance_valid(w):
			continue
		if "fire_rate_multiplier" in w:
			w.fire_rate_multiplier = TALON_SALVO_FIRE_RATE_MULT
		## kullanıcı isteği: "saldırı salvosu hedeflere doğru oluyor, baktıkları
		## yöne doğru olsun istemiştim, hedef yoksa bile atmalı" - bkz. weapon.gd
		## fire_in_facing_direction üstündeki not.
		if "fire_in_facing_direction" in w:
			w.fire_in_facing_direction = true
	_talon_set_weapons_circular(TALON_SALVO_RADIUS, 0.0)
	_spawn_burst(Color(1.0, 0.6, 0.2))


## _process_talon_weapon_salvo (bkz. _physics_process çağrısı) her karede
## dönüş açısını ilerletir (3sn'de 2 tam tur) ve periyodik hasar tick'i
## tetikler.
func _process_talon_weapon_salvo(delta: float) -> void:
	if not _talon_weapon_salvo_active:
		return
	_talon_salvo_elapsed += delta
	var progress: float = clamp(_talon_salvo_elapsed / TALON_SALVO_DURATION, 0.0, 1.0)
	_talon_salvo_angle_offset = progress * TAU * TALON_SALVO_ROTATIONS
	_talon_set_weapons_circular(TALON_SALVO_RADIUS, _talon_salvo_angle_offset)
	_talon_salvo_tick_timer += delta
	if _talon_salvo_tick_timer >= TALON_SALVO_TICK_INTERVAL:
		_talon_salvo_tick_timer = 0.0
		_talon_salvo_damage_tick()


## DÜZELTME (kullanıcı bildirimi: "silahlar sıkmadıkları yerlere de hasar
## veriyor, dönerken düz bir doğrultuda ateş etmesi lazım") - artık TEK bir
## toplu daire hasarı YOK; her silah _talon_iconed_weapons()'taki KENDİ
## index'ine göre _talon_set_weapons_circular'ın O AN çizdiği İLE BİREBİR AYNI
## açıyı (TalonFormationMath.compute_slot, _talon_salvo_angle_offset) yeniden
## hesaplayıp SADECE o doğrultudaki dar bir hat üzerindeki düşmanlara kendi
## payına düşen hasarı veriyor - bkz. _skill_talon_dash()'teki AYNI
## Geometry2D.get_closest_point_to_segment çizgi-isabet deseni, crit zarı da
## AYNI (_roll_ability_crit/_apply_ability_crit).
func _talon_salvo_damage_tick() -> void:
	var iconed: Array = _talon_iconed_weapons()
	if iconed.is_empty():
		return
	var count: int = iconed.size()
	var hit_range: float = TALON_SALVO_RADIUS + TALON_SALVO_HIT_MARGIN
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for i in range(count):
		var w = iconed[i]
		if not (is_instance_valid(w) and "damage" in w):
			continue
		var weapon_tick_damage: float = float(w.get("damage")) * TALON_SALVO_TICK_DAMAGE_MULT
		if weapon_tick_damage <= 0.0:
			continue
		var slot: Dictionary = TalonFormationMath.compute_slot(i, count, TALON_SALVO_RADIUS, _talon_salvo_angle_offset)
		var dir: Vector2 = Vector2(cos(slot["angle"]), sin(slot["angle"]))
		var seg_start: Vector2 = global_position
		var seg_end: Vector2 = global_position + dir * hit_range
		for e in enemies:
			if not is_instance_valid(e) or e.get("is_dead") == true or not (e is Node2D):
				continue
			var epos: Vector2 = (e as Node2D).global_position
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(epos, seg_start, seg_end)
			if epos.distance_to(closest) > TALON_SALVO_HIT_WIDTH:
				continue
			if e.has_method("take_damage"):
				var is_crit: bool = _roll_ability_crit()
				e.call("take_damage", _apply_ability_crit(weapon_tick_damage, is_crit), is_crit)


## _end_skill2_effects() (skill2 süresi dolunca) tarafından çağrılır - silah
## ikonlarını normal (WEAPON_ICON_SLOTS tabanlı) konumuna döndürür.
func _end_talon_weapon_salvo() -> void:
	_talon_weapon_salvo_active = false
	for w in owned_weapon_nodes:
		if not is_instance_valid(w):
			continue
		if "fire_rate_multiplier" in w:
			w.fire_rate_multiplier = 1.0
		if "fire_in_facing_direction" in w:
			w.fire_in_facing_direction = false
	_talon_restore_weapon_aim()
	_reposition_weapon_icons()


## ---------- Hamle Vuruşu (ULTİ/Q, skill id 38 - kullanıcı isteği: "R ile
## Q'nun yerini değiştir" sonrası) ----------
## "İleri doğru kısa mesafe atılır, isabet ettiği düşmanlara %60 saldırı
## gücü hasar verir ve isabet ettiği her düşman başına eksik kalkanın %4'ünü
## yeniler." - bkz. _assasin_dash2_execute() ile BİREBİR AYNI 8-yönlü dash +
## çizgi-tabanlı isabet tespiti şablonu, kalkan yenilemesi Elara'nın
## _skill_elara_dash_refill()'iyle AYNI heal_shield() çağrısı.
const TALON_DASH_DISTANCE := 160.0
const TALON_DASH_TIME := 0.16
const TALON_DASH_HIT_WIDTH := 48.0
const TALON_DASH_DAMAGE_MULT := 0.6 ## saldırı gücünün %60'ı
const TALON_DASH_SHIELD_REFILL_PERCENT := 0.04 ## isabet başına eksik kalkanın %4'ü


func _skill_talon_dash() -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var raw_dir: Vector2 = input_dir if input_dir.length() > 0.1 else _facing_to_vector(facing)
	var snapped_angle: float = round(raw_dir.angle() / (PI / 4.0)) * (PI / 4.0)
	var dash_dir: Vector2 = Vector2(cos(snapped_angle), sin(snapped_angle))
	var start_pos: Vector2 = global_position
	var end_pos: Vector2 = start_pos + dash_dir * TALON_DASH_DISTANCE

	var total_damage: float = 0.0
	for w: Node in owned_weapon_nodes:
		if is_instance_valid(w) and "damage" in w:
			total_damage += float(w.get("damage"))
	if total_damage <= 0.0:
		total_damage = 10.0
	var hit_damage: float = total_damage * TALON_DASH_DAMAGE_MULT

	var hit_enemies: Array = []
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true or not (e is Node2D):
			continue
		var epos: Vector2 = (e as Node2D).global_position
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(epos, start_pos, end_pos)
		if epos.distance_to(closest) <= TALON_DASH_HIT_WIDTH:
			hit_enemies.append(e)

	_spawn_burst(Color(1.0, 0.55, 0.2))
	var dash_tween := create_tween()
	dash_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	dash_tween.tween_method(func(p: Vector2): global_position = p, start_pos, end_pos, TALON_DASH_TIME)
	await dash_tween.finished
	if not is_instance_valid(self) or is_dead:
		return

	for e in hit_enemies:
		if not is_instance_valid(e) or e.get("is_dead") == true or not is_inside_tree():
			continue
		if e.has_method("take_damage"):
			var is_crit: bool = _roll_ability_crit()
			e.call("take_damage", _apply_ability_crit(hit_damage, is_crit), is_crit)
			if item_shield_max > 0.0:
				heal_shield((item_shield_max - item_shield_hp) * TALON_DASH_SHIELD_REFILL_PERCENT)


## ---------- Ayna Formu (3. yetenek/R, skill3 id 37 - kullanıcı isteği: "R
## ile Q'nun yerini değiştir" sonrası) ----------
## "15 saniye boyunca form değiştirir ve silahlarının sayısı 2 katına
## çıkar ... kopyalanan her silah başına saldırı gücü %8 azalmalı." - bkz.
## dosya başı "BİLİNÇLİ MİMARİ KARAR" notu: kopyalar buy_weapon_copy() ile
## GERÇEKTEN oluşturulup bağımsız ateş eder (kozmetik DEĞİL).
const TALON_MIRROR_RADIUS := TalonFormationMath.MIRROR_RADIUS
const TALON_MIRROR_DMG_PENALTY_PER_COPY := 0.08 ## kopya başına -%8 saldırı gücü
var _talon_mirror_form_active: bool = false
## SADECE bu ulti tarafından eklenen kopyalar - orijinal silahlarla
## KARIŞTIRILMAZ, biterken SADECE bunlar kaldırılır.
var _talon_mirror_copies: Array = []


func _skill_talon_mirror_form() -> void:
	_talon_mirror_form_active = true
	_talon_mirror_copies.clear()
	## owned_weapon_nodes'u DUPLICATE ediyoruz çünkü buy_weapon_copy() aynı
	## diziye ekleme yapıyor - orijinal listenin üzerinde SIRAYLA dönerken
	## dizi büyürse (yeni eklenen kopyalar da tekrar kopyalanır, sonsuz
	## döngü/istenmeyen ikinci nesil kopyalar) diye sabit bir anlık görüntü
	## alınıyor.
	var originals: Array = owned_weapon_nodes.duplicate()
	for w in originals:
		if not is_instance_valid(w):
			continue
		var key: String = w.get_meta("shop_key", "")
		if key == "":
			continue
		if buy_weapon_copy(key, 1):
			_talon_mirror_copies.append(owned_weapon_nodes[owned_weapon_nodes.size() - 1])
	_talon_recompute_damage_bonus()
	_talon_set_weapons_circular(TALON_MIRROR_RADIUS, 0.0)
	_spawn_burst(Color(0.65, 0.35, 1.0))
	## kullanıcı isteği: "Talonun ultisi açıkken kendisi ve silahları kırmızı
	## tonlarında parlamalı" (Ayna Formu/R, 15sn - bkz. AskUserQuestion cevabı).
	## Kök `modulate`e uygulanıyor: Godot'ta CanvasItem modulate alt öğelere
	## ÇARPIMSAL yayılır, anim VE owned_weapon_nodes ikisi de Player'ın
	## çocuğu olduğu için TEK bu satır hem karakteri hem silahları kırmızıya
	## boyuyor - Kurt Adam'ın Kudurmuş Saldırı'sıyla (bkz.
	## _skill_kurtadam_berserk) AYNI teknik. main.gd zaten bu kök modulate'i
	## (anim.modulate ile çarpıp) diğer oyunculara yayınlıyor (bkz.
	## _process_multiplayer_sync extra["modulate"]) - ekstra senkron kodu
	## GEREKMİYOR. Geri alma _end_talon_mirror_form()'da (gerçek 15sn
	## dolunca) - _end_skill_effects()'teki GENEL modulate sıfırlaması
	## BİLEREK bunu ES GEÇİYOR (bkz. o fonksiyondaki skill3 koruması), yoksa
	## Talon'un Q'sunu (0.16sn'lik ayrı bir zamanlayıcı) her kullanışında bu
	## kırmızı ton ZAMANINDAN ÖNCE (R hâlâ sürerken) sıfırlanırdı.
	modulate = Color(1.0, 0.4, 0.4, 1.0)


## Sabit dairesel dizilim (Silah Salvosu'nun aksine DÖNMÜYOR) - her karede
## yeniden uygulanıyor çünkü silah SAYISI süre içinde değişebilir (bir kopya
## ya da orijinal, oyuncu ölmeden/silah satmadan de facto kaybolabilir).
func _process_talon_mirror_form(_delta: float) -> void:
	if not _talon_mirror_form_active:
		return
	## DÜZELTME (kullanıcı bildirimi: "E skilinin animasyonu R skili açıkken
	## gerçekleşmiyor") - Silah Salvosu (E) aynı anda aktifse onun dönen
	## dizilimi ÖNCELİKLİ olmalı. İkisi de _talon_set_weapons_circular
	## çağırdığı için (bkz. _physics_process çağrı sırası:
	## _process_talon_weapon_salvo SONRA _process_talon_mirror_form), Ayna
	## Formu'nun sabit (angle=0) dizilimi HER KAREDE Silah Salvosu'nun o
	## karede ilerlemiş dönüş açısının ÜSTÜNE yazıp onu görsel olarak
	## donmuş/sabit gösteriyordu. Salvo bittiğinde (_talon_weapon_salvo_active
	## false olunca) Ayna Formu'nun sabit dizilimi buradan normal şekilde
	## devam eder.
	if _talon_weapon_salvo_active:
		return
	_talon_set_weapons_circular(TALON_MIRROR_RADIUS, 0.0)


## _end_skill_effects() (ULTİ süresi dolunca) tarafından çağrılır - SADECE bu
## ulti tarafından eklenen kopyaları kaldırır (gerçek/orijinal silahlara
## DOKUNMAZ), ceza (talon_damage_bonus) ve ikon konumlarını geri alır.
func _end_talon_mirror_form() -> void:
	_talon_mirror_form_active = false
	for w in _talon_mirror_copies:
		var idx: int = owned_weapon_nodes.find(w)
		if idx >= 0:
			owned_weapon_nodes.remove_at(idx)
		if is_instance_valid(w):
			w.queue_free()
	_talon_mirror_copies.clear()
	_talon_recompute_damage_bonus()
	_talon_restore_weapon_aim()
	_reposition_weapon_icons()
	## bkz. _skill_talon_mirror_form()'daki kırmızı ton notu - GERÇEK bitiş
	## burası, kızıl parlamayı burada söndürüyoruz.
	modulate = Color(1, 1, 1, 1)
## ================= /Talon YENİ KİT =================


## Talon: "yere geniş büyük bir darbe indirip isabet ettirdiği tüm
## yaratıkları 3 saniye boyunca sersemletir" - kullanıcı isteği, eski Öfke
## Patlaması kendi buff'ıyla (boyut/hasar/geri tepme artışı) birlikte
## TAMAMEN kaldırıldı. Sersemleyen yaratıklar enemy.gd'nin is_frozen
## sistemiyle (bkz. apply_stun) hareket edemez ve kimseye hasar veremez -
## Buz Asası'nın donmasıyla BİREBİR aynı mekanizma, sadece süresi sabit 3sn
## ve chill_stacks birikimine bağlı değil.
## #56 DÜZELTME: bu Talon'un TEMEL (E, skill2 id 8) yeteneği - eskiden
## yanlışlıkla ULTİ (R) eşleme tablosunda duruyordu (bkz. yukarıdaki not),
## şimdi _activate_skill2()'nin eşleme tablosunda çağrılıyor.
func _skill_berserk() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if global_position.distance_to(e.global_position) <= TALON_SLAM_RADIUS:
			if e.has_method("apply_stun"):
				e.apply_stun(TALON_SLAM_STUN_DURATION)
	_spawn_burst(Color(1.0, 0.55, 0.15))
	
	if FxTalhaRageScene:
		var fx := FxTalhaRageScene.instantiate() as Node2D
		add_child(fx)
	_broadcast_skill_scene("res://scenes/fx_talha_rage.tscn")


## Matthew: sacrifices his pet (if he has one) for a shield dome sized off
## the pet's current health - see take_damage()'s matthew_dome_active branch
## and _pop_matthew_dome(). If the pet isn't around (already mid-respawn),
## the button still goes on cooldown but does nothing - matches how a
## reasonable "activate my minion's sacrifice" ability should behave when
## there's no minion to sacrifice.
func _skill_shield_dome() -> void:
	if not _matthew_pet_alive or not _matthew_pet or not is_instance_valid(_matthew_pet) or not ("health" in _matthew_pet):
		_spawn_floating_text("YARATIK YOK", Color(1.0, 0.4, 0.4))
		return
	## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir ... kalkan
	## verme de dahil bunlar pozitif olarak artacak" - kritikte kalkana
	## dönüşen tilki canı normalden fazla sayılıyor.
	matthew_dome_hp = _apply_ability_crit(_matthew_pet.health, _roll_ability_crit())
	matthew_dome_active = true
	# The fox runs to Matthew instead of dying instantly, then becomes the shield.
	if _matthew_pet.has_method("begin_matthew_shield_form"):
		_matthew_pet.begin_matthew_shield_form(self)
	_spawn_burst(Color(0.95, 0.55, 0.2))
	
	if FxMatthewSacrificeScene:
		var sacrifice_fx: Node2D = FxMatthewSacrificeScene.instantiate() as Node2D
		add_child(sacrifice_fx)
	if FxMatthewFoxShieldScene:
		_matthew_fox_shield_fx = FxMatthewFoxShieldScene.instantiate() as Node2D
		add_child(_matthew_fox_shield_fx)
	_broadcast_skill_scene("res://scenes/fx_matthew_sacrifice.tscn")


func _pop_matthew_dome(exploded: bool) -> void:
	matthew_dome_active = false
	matthew_dome_hp = 0.0
	if _matthew_fox_shield_fx and is_instance_valid(_matthew_fox_shield_fx):
		if _matthew_fox_shield_fx.has_method("pop"):
			_matthew_fox_shield_fx.pop()
		_matthew_fox_shield_fx = null
	if _matthew_pet and is_instance_valid(_matthew_pet):
		if _matthew_pet.has_method("end_matthew_shield_form"):
			_matthew_pet.end_matthew_shield_form()
	if exploded:
		_matthew_dome_explosion()


## Same shape as _do_repel() - area damage + knockback around the player.
func _matthew_dome_explosion() -> void:
	const RADIUS := 220.0
	const DAMAGE := 60.0
	const KNOCKBACK := 260.0
	## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir".
	var is_crit: bool = _roll_ability_crit()
	var dmg: float = _apply_ability_crit(DAMAGE, is_crit)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d > RADIUS:
			continue
		if e.has_method("take_damage"):
			e.take_damage(dmg, is_crit)
		if d > 0.1:
			var dir: Vector2 = (e.global_position - global_position).normalized()
			if e.has_method("apply_knockback_force"):
				e.apply_knockback_force(dir, KNOCKBACK)
			else:
				e.global_position += dir * KNOCKBACK
	_spawn_burst(Color(0.95, 0.55, 0.2))
	
	if FxMatthewExplosionScene:
		var fx := FxMatthewExplosionScene.instantiate() as Node2D
		# Add directly to main scene so it stays at the explosion position
		# rather than following player if player moves away quickly.
		fx.global_position = global_position
		get_tree().current_scene.add_child(fx)
		if NetworkManager.is_multiplayer_active:
			NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "hitscan_impact", global_position, {
				"scene_path": "res://scenes/fx_matthew_explosion.tscn"
			})


## Helper: broadcast a skill overlay scene to remote players.
func _broadcast_skill_scene(scene_path: String) -> void:
	if not NetworkManager.is_multiplayer_active:
		return
	NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "skill_scene", global_position, {
		"scene_path": scene_path,
		"position": Vector2.ZERO
	})


## YENİ YETENEK/EFEKT EKLERKEN BUNU KULLAN: bir "kendine bağlı" (karakteri
## takip eden) FX sahnesini hem kendi ekranında oynatıp HEM diğer oyunculara
## yayınlamanın TEK, doğru yolu.
##
## KÖK NEDEN NOTU: eskiden her yetenek bunu elle iki AYRI yerde yapıyordu -
## instantiate() için preload edilmiş bir sahne DEĞİŞKENİ, broadcast için
## ayrıca elle yazılmış bir String yol (bkz. _spawn_buyucu_meteor_strike
## üstündeki "ziva agent" notu - tam bu yüzden yeni eklenen bir efekt hiç
## görünmüyordu). Biri güncellenip diğeri unutulunca diğer oyuncularda ESKİ
## efekt/animasyon kalıyordu. Burada TEK referans var: `scene` parametresi -
## broadcast edilen yol da doğrudan `scene.resource_path`'ten okunuyor, elle
## yazılmış ikinci bir String asla olmuyor, yani ikisi YAPISAL OLARAK
## birbirinden sapamaz.
##
## `scene`: FX'in PackedScene'i (bir @onready/const preload). Karaktere
## child olarak eklenir (self'e - yani seni takip eder), fx_shield_active.gd/
## fx_oyku_heal.gd gibi mevcut "kendine bağlı" efektlerle AYNI desen. Dünya
## konumunda SABİT duran (ör. meteor, telegraph ring, patlama) efektler için
## bunun yerine _spawn_world_explosion_fx / _spawn_local_telegraph_ring gibi
## konum-tabanlı yardımcıları kullan - bu fonksiyon onların yerini tutmaz.
##
## Kullanım: eskiden
##   if FxYeniEfekt: var fx := FxYeniEfekt.instantiate() as Node2D; add_child(fx)
##   _broadcast_skill_scene("res://scenes/fx_yeni_efekt.tscn")
## artık tek satır:
##   _play_and_broadcast_skill_fx(FxYeniEfekt)
func _play_and_broadcast_skill_fx(scene: PackedScene) -> Node:
	if not scene:
		return null
	var fx: Node = scene.instantiate()
	add_child(fx)
	if NetworkManager.is_multiplayer_active and not scene.resource_path.is_empty():
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "skill_scene", global_position, {
			"scene_path": scene.resource_path,
			"position": Vector2.ZERO
		})
	return fx


func _spawn_burst(color: Color) -> void:
	var p := CPUParticles2D.new()
	get_tree().current_scene.add_child(p)
	p.global_position = global_position
	p.amount = 28
	p.lifetime = 0.7
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 0.9
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 170.0
	p.gravity = Vector2(0, 40)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = color
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
	# Broadcast to remote players
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "skill_burst", global_position, {
			"radius": 100.0,
			"color": color
		})

	_spawn_ring(color)
	_spawn_ring(color.lightened(0.3))


func _spawn_shield_hit_fx(impact_angle: float) -> void:
	var fx := Node2D.new()
	fx.set_script(load("res://scripts/fx_shield_hit.gd"))
	add_child(fx)
	## LPC sprite'ının gövde merkezi yaklaşık node orijininde: halka karakteri
	## tam sarsın diye merkezde durur (eski -24 yukarı kayıklığı kaldırıldı).
	fx.position = Vector2.ZERO
	fx.setup(impact_angle)


func _spawn_ring(color: Color) -> void:
	var ring := Node2D.new()
	ring.set_script(load("res://scripts/fx_ring.gd"))
	get_tree().current_scene.add_child(ring)
	ring.global_position = global_position
	ring.color = color
	# Broadcast to remote players
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "skill_ring", global_position, {
			"radius": 120.0,
			"color": color
		})


func _spawn_floating_text(text: String, color: Color, big: bool = false) -> void:
	var ft = FloatingText.instantiate()
	get_tree().current_scene.add_child(ft)
	ft.follow_target = self
	ft.follow_offset = Vector2(0, -30)
	ft.global_position = global_position + Vector2(0, -30)
	ft.setup(text, color, big)
