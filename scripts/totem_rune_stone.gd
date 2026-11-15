extends Sprite2D
class_name TotemRuneStone

## Shaman Q/E RÜN TAŞI (madde 557 + 569; kullanıcının çizimleri, `tools/gen_shaman_rune_stones.py`). Totem sahnesindeki "TotemSprite".
## Madde 569 (kullanıcı: "rünler çok donuk, uçuyormuş gibi görünmüyor, hiç parıldamıyor ve efektsiz" -> prototip madde 568 "A - Parlayan
## Oyma" seçildi + "rün taşı uçuyormuş gibi görünmüyor, yukarı aşağı süzülmüyor"):
##  - TAŞ SÜZÜLÜR: yerden HOVER_LIFT yukarıda, BOB_PERIOD'da bir ±BOB_AMP; adımlar TAM TAŞ PİKSELİ (Sprite2D.offset, piksel kaymaz).
##    Dikilme animasyonu `position`'ı oynatır, süzülme `offset` + çocukların konumu -> ikisi çakışmaz. Gölge yerde kalır (TotemBase,
##    DropShadow süzülme başlamadan ölçülür) ve taş yükseldikçe daralır (`lift_frac`). Kapatmak: HOVER_LIFT = BOB_AMP = 0.
##  - RÜNLER TAŞTA AKKOR: evrimsiz rün + verilen HER evrimin rünü taşın içinde SIRAYLA yanar (belir T_IN / parla T_HOLD / sön T_OUT,
##    PERIOD'da bir, sönerken sıradaki belirir). Çekirdek beyaz-sıcak (Q sarı / E açık mavi gölge), çevresinde 3 halkalı kademeli hale
##    (dither yok), taşın DIŞINDA 2 halkalı parıltı en parlak rünle + nefesle güçlenir, rünün üstünden iri kıvılcımlar yükselir
##    (Q ateş / E buz renkleri). Evrim yoksa tek rün hep yanar. Atışta / kalkan tikinde `flare()`.
## Evrim listesi her yeni rün başında yeniden okunur (totem yaşarken alınan evrim döngüye girer).
## Tamamen kozmetik, ağ yok: gerçek totemde caster = Player, ağ kopyasında RemotePlayer (has_evo extra["evo"]) - TotemBase `has_evo_func`
## bağlar; zamanlama her istemcide kendi saatinde.

const COLS := 2 ## rün sayfası: 0 akkor çekirdek + oyma, 1 üç halkalı hale
const RUNE_ROWS := 6 ## 0 evrimsiz, 1-4 kullanıcının "N evrimli ekstra" çizimleri, 5 final
const T_IN := 0.5
const T_HOLD := 1.0
const T_OUT := 0.6
const PERIOD := T_IN + T_HOLD
const BREATHE_SPEED := 2.4
## Süzülme (dünya birimi).
const HOVER_LIFT := 4.0
const BOB_AMP := 1.6
const BOB_PERIOD := 2.6
## Taş dış parıltısı: (taban + nefes) x en parlak rün (en az GLOW_MIN) + atış parlaması.
const GLOW_BASE := 0.35
const GLOW_BREATHE := 0.35
const GLOW_MIN := 0.4
const GLOW_FLARE := 0.3
const FLARE_TIME := 0.35
## Atışta (madde 570): rün halesi kısa parlar, taş hedefin tersine KICK_PX taş pikseli geri teper.
const FLARE_HALO := 0.6
const KICK_TIME := 0.09
const KICK_PX := 1.0
## Kıvılcım: saniyede SPARK_RATE, ömür SPARK_LIFE, SPARK_RISE dünya/sn yükselir; kıvılcım pikseli SPARK_PX taş pikseli (~karakter pikseli).
const SPARK_RATE := 2.5
const SPARK_LIFE := 0.9
const SPARK_RISE := 14.0
const SPARK_PX := 1.4
const SPARK_SPREAD := 3.0
const SPARK_COLORS := {
	"q": [Color8(255, 244, 207), Color8(250, 148, 51), Color8(214, 76, 31), Color8(102, 26, 15)],
	"e": [Color8(255, 255, 255), Color8(166, 216, 255), Color8(74, 168, 255), Color8(30, 80, 180)],
}
## Taşın 32x32 karesinde rünlerin ortası (sayfa merkezine göre, taş pikseli).
const RUNE_CENTER := {"q": Vector2(-1.0, -2.5), "e": Vector2(-1.0, -0.5)}

## Hangi evrim hangi rün çizimini gösterir (kullanıcı: "her evrime uygun rün görünüşüne sen karar verebilirsin").
const EVO_ROW := {
	"shaman_q1": 4, ## Üçüncü Totem - üç yatay çizgi (üç yük)
	"shaman_q2": 1, ## Alev Dokunuşu - kıvrılan alev dili
	"shaman_q3": 3, ## Çabuk Totem - kadran (zaman)
	"shaman_q4": 2, ## Ruh Emici - aşağı kıvrılan diş
	"shaman_qf": 5, ## Patlayan Alev - final rünü
	"shaman_e1": 1, ## Geniş Alan - kemer / kubbe
	"shaman_e2": 3, ## Savaş Ritmi - atılan ok
	"shaman_e3": 2, ## Yapışkan Zemin - zincir halkası
	"shaman_e4": 4, ## Güçlü Kalkan - artı
	"shaman_ef": 5, ## İtici Dalga - final rünü
}
const EVO_ORDER := {
	"q": ["shaman_q1", "shaman_q2", "shaman_q3", "shaman_q4", "shaman_qf"],
	"e": ["shaman_e1", "shaman_e2", "shaman_e3", "shaman_e4", "shaman_ef"],
}


## Kıvılcımları çizen çocuk katman (rünlerin üstünde).
class SparkLayer extends Node2D:
	var stone: Node = null

	func _draw() -> void:
		if stone:
			stone.call("_draw_sparks", self)


@export var kind: String = "q"
@export var rune_sheet: Texture2D
@export var glow_texture: Texture2D

## func(evo_id: String) -> bool. TotemBase._ready bağlar; bağlı değilse yalnız evrimsiz rün.
var has_evo_func: Callable = Callable()

var _t: float = 0.0
var _next_start: float = 0.0
var _seq_pos: int = 0
var _active: int = -1
var _flare: float = 0.0
var _hover_local: float = 0.0
var _kick: float = 0.0
var _kick_off: Vector2 = Vector2.ZERO
var _glow: Sprite2D = null
var _sparks: SparkLayer = null
var _slots: Array[Sprite2D] = [] ## akkor çekirdek; halesi çocuğu ("Halo", show_behind_parent)
var _halos: Array[Sprite2D] = []
var _slot_start: Array[float] = [0.0, 0.0]
var _slot_row: Array[int] = [0, 0]
var _slot_steady: Array[bool] = [false, false]
var _slot_live: Array[bool] = [false, false]


func _ready() -> void:
	_glow = Sprite2D.new()
	_glow.name = "StoneGlow"
	_glow.texture = glow_texture
	_glow.show_behind_parent = true ## taşın ARKASINDA: halka taşın dışına taşar
	_glow.modulate.a = 0.0
	add_child(_glow)
	for i in range(2):
		var s := Sprite2D.new()
		s.name = "Rune%d" % i
		s.texture = rune_sheet
		s.hframes = COLS
		s.vframes = RUNE_ROWS
		s.visible = false
		add_child(s)
		var h := Sprite2D.new()
		h.name = "Halo"
		h.texture = rune_sheet
		h.hframes = COLS
		h.vframes = RUNE_ROWS
		h.show_behind_parent = true
		s.add_child(h)
		_slots.append(s)
		_halos.append(h)
	_sparks = SparkLayer.new()
	_sparks.name = "Sparks"
	_sparks.stone = self
	add_child(_sparks)


## Sahip olunan rün satırları, döngü sırasıyla (ilk eleman hep evrimsiz rün 0).
func rune_rows() -> Array[int]:
	var rows: Array[int] = [0]
	if not has_evo_func.is_valid():
		return rows
	for evo_id: String in EVO_ORDER.get(kind, []):
		if bool(has_evo_func.call(evo_id)):
			rows.append(int(EVO_ROW[evo_id]))
	return rows


## Atış / kalkan tikinde taş kısa parlar (TotemBase._flare_stone).
func flare() -> void:
	_flare = FLARE_TIME


## Ateş topu çıkarken taş hedefin tersine kısa geri teper (TotemAttack._on_fired).
func kick(toward: Vector2) -> void:
	if toward.length() < 0.01:
		return
	_kick = KICK_TIME
	_kick_off = (-toward.normalized() * KICK_PX).round()


## Süzülmenin o anki dünya kayması (negatif = yukarı); ateş topu / kalkan şeridi çıkışı buna eklenir.
func hover_world() -> float:
	return _hover_local * scale.y


## 0 = en alçak, 1 = en yüksek (gölge daralması için).
func lift_frac() -> float:
	if BOB_AMP <= 0.0:
		return 0.0
	return clampf((-hover_world() - (HOVER_LIFT - BOB_AMP)) / (2.0 * BOB_AMP), 0.0, 1.0)


func _process(delta: float) -> void:
	advance(delta)


## Testler doğrudan çağırır.
func advance(delta: float) -> void:
	_t += delta
	_flare = maxf(0.0, _flare - delta)
	## süzülme: tam taş pikseli adımları
	var lift: float = -HOVER_LIFT + sin(_t * TAU / BOB_PERIOD) * BOB_AMP
	_hover_local = roundf(lift / scale.y)
	_kick = maxf(0.0, _kick - delta)
	var hov := Vector2(0.0, _hover_local) + (_kick_off if _kick > 0.0 else Vector2.ZERO)
	offset = hov
	if _glow:
		_glow.position = hov
	for s in _slots:
		s.position = hov
	if _t >= _next_start:
		_begin_next()
	var breathe: float = 0.5 + 0.5 * sin(_t * BREATHE_SPEED)
	var peak: float = 0.0
	var fl: float = _flare / FLARE_TIME
	for i in range(2):
		peak = maxf(peak, _update_slot(i, breathe, fl * fl))
	if _glow:
		var f: float = _flare / FLARE_TIME
		_glow.modulate.a = clampf((GLOW_BASE + GLOW_BREATHE * breathe) * maxf(GLOW_MIN, peak) + GLOW_FLARE * f * f, 0.0, 1.0)
	if _sparks:
		_sparks.queue_redraw()


func _begin_next() -> void:
	var rows: Array[int] = rune_rows()
	_next_start = _t + PERIOD
	if rows.size() <= 1:
		if _active >= 0 and _slot_live[_active] and _slot_steady[_active] and _slot_row[_active] == rows[0]:
			return
		_start_slot(rows[0], true)
		return
	if _active >= 0 and _slot_live[_active] and _slot_steady[_active]:
		_slot_steady[_active] = false
		_slot_start[_active] = _t - PERIOD
	var row: int = rows[_seq_pos % rows.size()]
	_seq_pos += 1
	_start_slot(row, false)


func _start_slot(row: int, steady: bool) -> void:
	var i: int = 0 if _active != 0 else 1
	_active = i
	_slot_start[i] = _t
	_slot_row[i] = row
	_slot_steady[i] = steady
	_slot_live[i] = true


## Yuvanın parlaklığı 0..1 (yumuşak belirip sönme); görünmüyorsa -1.
static func slot_level(age: float, steady: bool) -> float:
	if age < 0.0:
		return -1.0
	if age < T_IN:
		return smoothstep(0.0, 1.0, age / T_IN)
	if steady or age < T_IN + T_HOLD:
		return 1.0
	if age < T_IN + T_HOLD + T_OUT:
		return smoothstep(0.0, 1.0, 1.0 - (age - T_IN - T_HOLD) / T_OUT)
	return -1.0


## Görünümü günceller; döndürdüğü = bu yuvanın parlaklığı (0..1).
func _update_slot(i: int, breathe: float, flash: float = 0.0) -> float:
	var s: Sprite2D = _slots[i] if i < _slots.size() else null
	var k: float = slot_level(_t - _slot_start[i], _slot_steady[i]) if _slot_live[i] else -1.0
	if k < 0.0:
		_slot_live[i] = false
		if s:
			s.visible = false
		return 0.0
	if s:
		s.visible = true
		s.frame = _slot_row[i] * COLS
		s.modulate.a = k
		var h: Sprite2D = _halos[i]
		h.frame = _slot_row[i] * COLS + 1
		h.modulate.a = minf(1.0, (0.75 + 0.25 * breathe) * k + FLARE_HALO * flash) ## çekirdeğin alfasıyla çarpılır (çocuk) -> hale k² ile belirir
	return k


## Yükselen kıvılcımlar (deterministik: doğuş zamanı sırasından), taş yerel koordinatında (taş pikseli).
func _draw_sparks(layer: Node2D) -> void:
	var cols: Array = SPARK_COLORS.get(kind, SPARK_COLORS["q"])
	var origin: Vector2 = RUNE_CENTER.get(kind, Vector2.ZERO) + offset
	var rise_local: float = SPARK_RISE / maxf(0.01, scale.y)
	var period: float = 1.0 / SPARK_RATE
	var j0: int = int(floor((_t - SPARK_LIFE) / period)) - 1
	for j in range(j0, int(floor(_t / period)) + 1):
		var age: float = _t - float(j) * period
		if age < 0.0 or age > SPARK_LIFE:
			continue
		var u: float = age / SPARK_LIFE
		var jx: float = float(posmod(j * 37, 11) - 5) / 5.0 * SPARK_SPREAD
		var x: float = origin.x + jx + sin(u * 5.0 + float(j)) * 0.6 * SPARK_PX
		var y: float = origin.y - rise_local * age
		var col: Color = cols[mini(3, int(u * 4.0))]
		var sz: float = (2.0 if u < 0.5 else 1.0) * SPARK_PX
		col.a = 1.0 - smoothstep(0.0, 1.0, (u - 0.6) / 0.4)
		layer.draw_rect(Rect2(Vector2(x - sz * 0.5, y - sz * 0.5), Vector2(sz, sz)), col)


## Test / ayıklama: o an görünen rün satırları.
func visible_rows() -> Array[int]:
	var out: Array[int] = []
	for i in range(2):
		if _slot_live[i] and i < _slots.size() and _slots[i].visible:
			out.append(_slot_row[i])
	return out
