extends RefCounted

## YARATIK YAKIN DÖVÜŞ VURUŞU = SALDIRI KLİBİNİN VURUŞ KARESİ (madde 571, 2026-11-11; kullanıcı: "yaratıkların vuruş animasyonuyla
## hasar verme tickleri senkronize değil, sanki dokununca hasar verip saldırı animasyonunda hiçbir hasar vermiyormuş gibi").
## Kök neden: hasar saldırı başlar başlamaz (klibin 0. karesinde) iniyordu; üstelik uzun klipler (vampir 1,4 sn, zombi 1,16 sn,
## hayalet 1,4 sn) varsayılan 0,75 sn'lik vuruş aralığında baştan başladığından vuruş karesi sürekli temasta HİÇ görünmüyordu.
## Kural (host da istemci kuklası da aynı sahne verisinden hesaplar - ağ alanı yok):
##   - hasar, klipteki vuruş karesi (HIT_FRAME: pençe/kılıç/ısırık izinin ilk göründüğü kare) EKRANA GELDİĞİ an iner;
##   - yakın dövüşçünün klibi gerekirse hızlanır: bütün klip vuruş aralığına sığar ve vuruş karesine en geç MAX_WINDUP sn'de
##     varılır (saniyedeki vuruş sayısı, yani DPS aynı; yalnız ilk vuruş kurulma süresi kadar gecikir ve kaçılabilir).
##   - menzilli yaratıkların klibi hızlanmaz (büyü klibi aynı kalır), temas vuruşları yine vuruş karesinde iner.
## Kareler saldırı sayfasının sağa bakan satırından seçildi (ölçüm: kare başına sağa uzanma + 0. kareden fark, ardından gözle
## düzeltme: iskelet 4 = ilk kılıç yayı, sıçan 4 = tırmık izi, vampir 7 = ilk kıvılcım, golem 5 = yere iniş tozu...).
## Anahtar: sahne dosyasının adı (enemy_zombie1) önce birebir, sonra sondaki rakamsız aile adı (enemy_zombie). Slime'ların
## her sahnesinin sanatı farklı -> ayrı ayrı. Tabloda olmayan yeni yaratık: klibin FALLBACK_FRACTION'ı.

const HIT_FRAME := {
	"enemy_agac": 4, "enemy_balkabagi": 3, "enemy_banshee": 3, "enemy_bitki": 4, "enemy_demon": 5,
	"enemy_golem": 5, "enemy_hayalet": 5, "enemy_iblis": 3, "enemy_iskelet": 4, "enemy_kabak": 3,
	"enemy_lich": 5, "enemy_mantar": 4, "enemy_minotaur": 3, "enemy_ork": 2, "enemy_rat": 4,
	"enemy_rontgen": 7, "enemy_sandworm": 3, "enemy_ucansetan": 3, "enemy_underground": 0,
	"enemy_vampire": 7, "enemy_wendigo": 3, "enemy_yarasa": 1, "enemy_zombie": 5,
	"enemy_slime1": 6, "enemy_slime2": 6, "enemy_slime3": 4, "enemy_slime4": 5, "enemy_slime5": 5,
	"enemy_slime6": 5, "enemy_slime7": 5,
	## madde 575 (yeni havuz): goblin mızrak izi 2, gnoll pençe yayı 4, kertenkele kılıç/tırpan yayı 4; pelteler her sahnede farklı sanat:
	## bomba 3 = patlama parlaması (yakın dövüşü yok, kendini patlatır), ateş 4 = alev kabarması, kristal 4 = dikenler çıkar.
	"enemy_goblin": 2, "enemy_gnoll": 4, "enemy_kertenkele": 4,
	"enemy_pelte1": 3, "enemy_pelte2": 4, "enemy_pelte3": 4,
}
const FALLBACK_FRACTION := 0.4
## Vuruş karesine en geç (sn): daha uzun kurulan klip hızlanır.
const MAX_WINDUP := 0.4
## Klip en fazla bu kadar hızlanır (vampir ~2,0x).
const MAX_SPEED := 2.5


## Sahne yolundan (res://scenes/creatures/enemy_zombie1.tscn) vuruş karesi; tabloda yoksa klibin FALLBACK_FRACTION'ı.
static func hit_frame(scene_path: String, cols: int) -> int:
	var key: String = scene_path.get_file().get_basename()
	if HIT_FRAME.has(key):
		return clampi(int(HIT_FRAME[key]), 0, maxi(cols - 1, 0))
	var fam: String = key
	while not fam.is_empty() and fam[fam.length() - 1] >= "0" and fam[fam.length() - 1] <= "9":
		fam = fam.substr(0, fam.length() - 1)
	if HIT_FRAME.has(fam):
		return clampi(int(HIT_FRAME[fam]), 0, maxi(cols - 1, 0))
	return clampi(int(round(float(cols) * FALLBACK_FRACTION)), 0, maxi(cols - 1, 0))


## Saldırı klibinin oynama hızı çarpanı (1 = sahnenin sprite_fps'i). start_frame: klibin başladığı kare (lich parlama karesinden başlar).
static func attack_speed(cols: int, fps: float, hit: int, start_frame: int, interval: float, ranged: bool) -> float:
	if ranged or cols <= 1 or fps <= 0.0:
		return 1.0
	var s: float = 1.0
	if interval > 0.0:
		s = maxf(s, float(cols) / fps / interval) ## bütün klip vuruş aralığına sığsın (sürekli temasta her vuruş tam oynasın)
	s = maxf(s, float(maxi(hit - start_frame, 0)) / fps / MAX_WINDUP)
	return minf(s, MAX_SPEED)


## Saldırı DURUMUNUN süresi (klip bittikten sonra son karede bekler): hızlanan klip vuruş aralığından önce bitse bile duruş bir
## sonraki vuruşa (geri sekme sonrası yeniden deneme payı HOLD_PAD) kadar saldırıda kalır - aralarda yürüme pozuna düşmesin.
## Klibin eski doğal süresinden uzun olmaz (hızlanmayan klip = doğal süre, eskisi gibi).
## 0,12: 0,75 + 0,12 = 0,87 sn fizik karesinin (1/60) tam katı DEĞİL - tam kat olunca (0,85 = 51 kare) C++ ve GDScript kare yolları
## durumu kayan nokta farkıyla bir kare kaydırarak bitiriyordu (test_enemy_attack_frames).
const HOLD_PAD := 0.12


static func state_duration(cols: int, fps: float, speed: float, interval: float) -> float:
	if fps <= 0.0:
		return 0.0
	var natural: float = float(cols) / fps
	var clip: float = natural / maxf(speed, 0.01)
	if interval <= 0.0:
		return clip
	return maxf(clip, minf(natural, interval + HOLD_PAD))


## Saldırı başladıktan kaç sn sonra hasar iner (vuruş karesinin ekrana geldiği an).
static func hit_delay(hit: int, start_frame: int, fps: float, speed: float) -> float:
	if fps <= 0.0:
		return 0.0
	return float(maxi(hit - start_frame, 0)) / (fps * maxf(speed, 0.01))
