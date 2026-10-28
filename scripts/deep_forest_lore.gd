extends Node

## DERİN ORMAN duyuruları (madde 361): yerel oyuncu bir tepe arkası bölgesine bu koşuda İLK kez girince üst ortada bölgenin adı + tek
## cümlelik sezdirme (altın kurdele); bir zindan girişine yaklaşınca kapının adı + "mühürlü" uyarısı (kırmızı kurdele) ve kapının halesi
## yaklaştıkça büyür (deep_forest_fx.gd set_gate_boost). Madde 371: kapılar artık AÇIK - ağzında etkileşim tuşu zindana indirir (dungeon_manager.gd).
## Sadece yerel: her peer kendi oyuncusuna bakar, ağ yok. deep_forest_fx.gd attach() kurar (fx = ışık düğümü).

const PlacesScript := preload("res://scripts/deep_forest_places.gd")
const CHECK_SEC := 0.25
## bölge duyurusu için oyuncunun bölgede kalması gereken süre (sınırda gidip gelince yanıp sönmesin)
const ZONE_SETTLE_SEC := 0.75
const GATE_NOTICE_DIST := 72.0
const GATE_BOOST_NEAR := 56.0
const GATE_BOOST_FAR := 190.0
## maske kanalı sırası; madde 385: Batı/Doğu kaldırıldı (kanalları boş -> duyuruları çıkmaz, kapı duyuruları aynı)
const ZONE_TEXT: Array[Array] = [
	["KADİM KARA ORMAN", "Burada ağaçlar ölü doğar; ruhlar yolunu kaybetmiş."],
	["KIZIL BATAKLIK", "Toprak nefes alıyor. Bir şey seni izliyor..."],
	["IŞIYAN KAYALIKLAR", "Kristaller unutulmuş bir şarkıyı mırıldanıyor."],
	["SİSLİ SAZLIK", "Yaşlı ağaç uyumuyor. Sadece bekliyor."],
]
const GATE_TEXT: Dictionary = {
	"Kemik Mahzeni": ["KEMİK MAHZENİ", "Mühür çatlamış. Aşağıdan kemik sesleri geliyor... inmeye cesaretin var mı?"],
	"Et Kuyusu": ["ET KUYUSU", "Kuyunun ağzı açık. Derinlerden bir kalp atışı duyuluyor."],
	"Boynuzlu Kapı": ["BOYNUZLU KAPI", "Kapı aralık. Mavi ışık içeriden birini çağırıyor."],
}

var fx: Node2D = null
var _acc: float = 0.0
var _zone_shown: Array[bool] = [false, false, false, false]
var _gate_shown: Array[bool] = []
var _settle_kind: int = -1
var _settle_t: float = 0.0


func _ready() -> void:
	for _g in PlacesScript.GATES:
		_gate_shown.append(false)


func _process(delta: float) -> void:
	_acc += delta
	if _acc < CHECK_SEC:
		return
	var step: float = _acc
	_acc = 0.0
	if fx == null or not is_instance_valid(fx):
		return
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var pos: Vector2 = player.global_position
	_check_zone(pos, step)
	_check_gates(pos)


func _check_zone(pos: Vector2, step: float) -> void:
	var kind: int = fx.call("zone_kind", pos)
	if kind != _settle_kind:
		_settle_kind = kind
		_settle_t = 0.0
		return
	if kind < 0 or _zone_shown[kind]:
		return
	_settle_t += step
	if _settle_t >= ZONE_SETTLE_SEC:
		_zone_shown[kind] = true
		_banner("info", ZONE_TEXT[kind][0], ZONE_TEXT[kind][1])


func _check_gates(pos: Vector2) -> void:
	for i in range(PlacesScript.GATES.size()):
		var mouth: Vector2 = fx.call("gate_mouth", i)
		var d: float = pos.distance_to(mouth)
		fx.call("set_gate_boost", i, 1.0 - smoothstep(GATE_BOOST_NEAR, GATE_BOOST_FAR, d))
		if d < GATE_NOTICE_DIST and not _gate_shown[i]:
			_gate_shown[i] = true
			var t: Array = GATE_TEXT.get(PlacesScript.GATES[i]["name"], [String(PlacesScript.GATES[i]["name"]).to_upper(), "Mühürlü."])
			_banner("tier", t[0], t[1])


func _banner(kind: String, ribbon: String, body: String) -> void:
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("_show_banner_notice"):
		main.call("_show_banner_notice", kind, ribbon, body, 4.5)


## Test: duyuru durumları.
func debug_state() -> Dictionary:
	return {"zones": _zone_shown.duplicate(), "gates": _gate_shown.duplicate()}
