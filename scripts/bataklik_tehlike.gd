extends RefCounted

## KARA BATAKLIK TEHLİKELERİ (2026-11-15, kullanıcı: bataklık için zorlaştırıcı mekanik önerisinden "2 ve 3 ekle"). Yalnız profilinde üst düzey
## "bataklik_tehlike" anahtarı olan haritada (MapProfiles.swamp_hazards(); Kara Bataklık) - suyun yürünebilmesi (su_yurunur) TEK BAŞINA açmaz.
## Saf hesaplar static: player.gd, remote_player.gd, wade_fx.gd, enemy_spawner.gd ve testler aynı sayıları okur.
##
## 1) BATMA (her ekran kendi oyuncusunu sayar, player.gd _process_wade_sink): suda (WadeFx.is_wading -> wade_slow_active) SINK_DELAY sn hareket
##    girdisi vermeden duran oyuncunun ayakları çamura gömülür. Gömülüyken yürümeye kalkınca PULL_TIME sn yerinden kıpırdayamaz (hız x0; yürüme
##    animasyonu yerinde oynar = çırpınma), sonra serbest. Yürümek / itilmek / dash sayacı sıfırlar; sudan çıkmak (uçmak, ölmek) her şeyi sıfırlar.
##    Görsel: su çizgisi gömüldükçe SINK_EXTRA_PX'e kadar derinleşir (wade_fx.gd, oyuncu + kukla); ağ extra["wsk"] = o ek piksel (0'da anahtar yok).
##    HUD rozeti "sink" (gömülüyken / çekilirken, süresiz).
## 2) SUDAN PUSU (yalnız host, enemy_spawner.gd _process_water_ambush): PUSU_WADE_MIN sn kesintisiz suda yürüyen (yerel ya da uzak) oyuncunun
##    yakınındaki suda, her yoklamada PUSU_CHANCE olasılıkla, PUSU_WARN sn kabarcık uyarısından sonra 2-3 yaratık sudan çıkar (oyuncu başına
##    PUSU_COOLDOWN). Yaratıklar o anki doğuş kademesinin listesinden (uçanlar hariç), elit değil, yaratık tavanına ve kademe kapısına bağlı.
##    Uyarı + sıçrama görseli fx_su_pusu.gd: host kendinde çizer + `_rpc_water_ambush_fx` ile herkese; yaratıklar her zamanki doğuş RPC'siyle.

const SINK_DELAY := 1.5      ## sn: suda kıpırdamadan bu kadar durunca gömülür
const PULL_TIME := 0.6       ## sn: gömülüyken yürümeye kalkınca kıpırdayamama süresi
const SINK_SHOW_FROM := 0.5  ## sn: su çizgisi bundan sonra derinleşmeye başlar (durur durmaz titremesin)
const SINK_EXTRA_PX := 4     ## gömülünce su çizgisine eklenen en çok piksel (oyuncu en derin 5 px -> 9 px: diz)
const MOVE_INPUT_MIN := 0.2  ## hareket girdisi eşiği
const STILL_EPS_PX := 0.5    ## kare başına bundan az yer değiştirme = duruyor (gömülmemişken)
const JUMP_FREE_PX := 12.0   ## kare başına bundan çok yer değiştirme (dash / ışınlanma) gömülmeyi de bozar

const PUSU_WADE_MIN := 3.0   ## sn: kesintisiz suda geçen süre bu eşiği geçince pusu zarı atılır
const PUSU_CHECK := 0.25     ## sn: host yoklama aralığı
const PUSU_CHANCE := 0.12    ## yoklama başına olasılık (eşikten sonra ortalama ~2 sn)
const PUSU_COOLDOWN := 35.0  ## sn: aynı oyuncu için iki pusu arası
const PUSU_PACK_MIN := 2
const PUSU_PACK_MAX := 3
const PUSU_DIST_MIN := 56.0  ## oyuncudan uzaklık (dünya px; oyuncu ~82 px/sn yürür, suda ~62)
const PUSU_DIST_MAX := 110.0
const PUSU_ATTEMPTS := 10    ## üye başına suda nokta arama denemesi
const PUSU_WARN := 0.8       ## sn: kabarcık uyarısı -> sıçrama + yaratık
## Sudan çıkmayan aileler (wade_fx.gd FLYING_FAMILIES ile aynı + Balkabağı Kafa'nın minyonları): kimlik = aile + sayı.
const PUSU_EXCLUDED := {"hayalet": true, "yarasa": true, "ucansetan": true, "banshee": true, "rontgen": true, "underground": true,
	"sandworm": true, "kabak": true}

const MapProfilesScript := preload("res://scripts/map_profiles.gd")


static func enabled() -> bool:
	return MapProfilesScript.swamp_hazards()


## Bir kare ilerlet: (still, pull) -> yeni (still, pull). still = suda kıpırdamadan geçen sn (SINK_DELAY'de durur), pull = kalan çekilme sn.
## wants_move: oyuncunun hareket girdisi var mı; moved_px: bu karede gerçek yer değiştirme (itilme / dash).
static func sink_step(still: float, pull: float, delta: float, wants_move: bool, moved_px: float) -> Vector2:
	if moved_px > JUMP_FREE_PX:
		return Vector2.ZERO
	if pull > 0.0:
		pull -= delta
		if pull <= 0.0:
			return Vector2.ZERO
		return Vector2(still, pull)
	if is_sunk(still):
		if wants_move:
			return Vector2(still, PULL_TIME)
		return Vector2(still, 0.0)
	if wants_move or moved_px > STILL_EPS_PX:
		return Vector2.ZERO
	return Vector2(minf(still + delta, SINK_DELAY), 0.0)


static func is_sunk(still: float) -> bool:
	return still >= SINK_DELAY


## Hız çarpanı: çekilirken 0, değilse 1 (suyun %25 yavaşlatması ayrı, player.gd _wade_move_mult).
static func sink_mult(pull: float) -> float:
	return 0.0 if pull > 0.0 else 1.0


## Su çizgisine eklenecek tam piksel: durdukça 0 -> SINK_EXTRA_PX, çekilirken geri iner.
static func sink_px(still: float, pull: float) -> int:
	var k: float
	if pull > 0.0:
		k = pull / PULL_TIME
	else:
		k = clampf((still - SINK_SHOW_FROM) / (SINK_DELAY - SINK_SHOW_FROM), 0.0, 1.0)
	return int(round(k * SINK_EXTRA_PX))


## HUD durum satırı (player.gd get_status_effects): gömülüyken / çekilirken süresiz rozet.
static func status_entry(still: float, pull: float) -> Dictionary:
	if pull > 0.0 or is_sunk(still):
		return {"id": "wade_sink", "kind": "sink", "is_buff": false, "stacks": 0, "remaining": -1.0, "duration": -1.0}
	return {}


## Pusu zarı atılabilir mi (süre eşiği + bekleme).
static func pusu_ready(wade_time: float, cooldown_left: float) -> bool:
	return wade_time >= PUSU_WADE_MIN and cooldown_left <= 0.0


## Bu yaratık kimliği sudan çıkabilir mi (aile = sondaki rakamlar atılmış kimlik).
static func pusu_id_ok(id: String) -> bool:
	var fam: String = id
	while fam.length() > 0 and fam[fam.length() - 1] >= "0" and fam[fam.length() - 1] <= "9":
		fam = fam.left(fam.length() - 1)
	return not PUSU_EXCLUDED.has(fam)
