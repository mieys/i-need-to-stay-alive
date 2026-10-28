extends Node2D

## DERİN ORMAN bölge ışıkları (madde 359/360/361; prototip madde 358): bölge maskesinin (assets/map/derin_orman_bolge.png - R Kuzey, G Batı,
## B Doğu, A Güney; harita shader'larının bölge renk ayarıyla aynı doku) İÇİNDE, kameranın gördüğü alanda:
##   Kuzey "Kadim Kara Orman"  -> havada yavaşça yukarı süzülen camgöbeği-yeşil ruh ışıkları
##   Batı "Kızıl Bataklık"     -> daha yavaş, sönük kızıl-pembe sporlar
##   Doğu "Işıyan Kayalıklar"  -> yerinde parlayıp sönen kısa ömürlü kristal pırıltıları
##   Güney "Sisli Sazlık"      -> gezinip yanıp sönen sarı-yeşil ateş böcekleri (madde 361)
## Madde 385: Batı ve Doğu bölgesi KALDIRILDI (maskenin G/B kanalı boş, ortam ışığı doğmaz); türleri yerinde kalan Et Kuyusu / Boynuzlu Kapı'nın
## halesi ve kapıdan yükselen ışıkları için duruyor (GATES "zone" = eski bölge numarası). Kuzey kuzeybatıya uzadı (aynı R kanalı).
## ZİNDAN GİRİŞLERİ (madde 361, scripts/deep_forest_places.gd GATES): kapının ağzında bölge renginde nefes alan hale + kapıdan yükselen
## ışıklar; yerel oyuncu yaklaşınca (deep_forest_lore.gd set_gate_boost) hale büyür, ışık sıklaşır.
## Sadece görsel: her peer'de yerel ve rastgele, oynanışa etkisi yok, ağ yok. Tek düğüm + tek _draw (ışık başına bir draw_texture),
## toplamalı karışım, konumlar dünya pikseline yuvarlanır (piksel sanatı). Kamera bölge görmüyorsa ve ışık kalmadıysa hiçbir şey çizmez.
## main.gd harita görselleriyle birlikte kurar (attach) - yanına bölge/kapı duyuruları için deep_forest_lore.gd de eklenir.

const MASK_PATH := "res://assets/map/derin_orman_bolge.png"
const PlacesScript := preload("res://scripts/deep_forest_places.gd")
const HARITA_KOKU := Vector2(-2.0, 21.0) ## harita_renk.gdshaderinc DO_HARITA_KOKU ile aynı (main.tscn Harita ofseti)
const CELL := 16.0
const MAX_MOTES := 36 ## görüş alanının tamamı bölgedeyken aynı anda en çok ışık
const MIN_ZONE := 0.6 ## ışık ancak maske bu değerin üstündeyken doğar (bölge kenarında değil)
const SPAWN_PER_SEC := 10.0
const DRAW_Z := 5
## Bölge türü (maske kanalı) -> doku, ömür (en az/en çok sn), hız (px/sn), yanlara salınım (px), en çok parlaklık, titreme hızı,
## "blink": ateş böceği gibi kesik yanıp sönme (0 = yok)
const KINDS: Array[Dictionary] = [
	{"tex": "res://assets/fx/derin_orman/ruh_isigi.png", "life": Vector2(4.0, 8.0), "speed": Vector2(3.0, 9.0), "wobble": 6.0, "alpha": 1.0, "flicker": 3.1, "blink": 0.0},
	{"tex": "res://assets/fx/derin_orman/spor.png", "life": Vector2(5.0, 10.0), "speed": Vector2(2.0, 5.0), "wobble": 3.0, "alpha": 0.75, "flicker": 1.7, "blink": 0.0},
	{"tex": "res://assets/fx/derin_orman/parilti.png", "life": Vector2(0.8, 1.6), "speed": Vector2(0.0, 0.0), "wobble": 0.0, "alpha": 1.0, "flicker": 0.0, "blink": 0.0},
	{"tex": "res://assets/fx/derin_orman/ates_bocegi.png", "life": Vector2(5.0, 9.0), "speed": Vector2(4.0, 10.0), "wobble": 9.0, "alpha": 0.95, "flicker": 2.3, "blink": 0.9},
]
## Güneyde ateş böcekleri seyrek (tehlikesi az, sakin): bölge başına en çok ışık çarpanı
const KIND_DENSITY: Array[float] = [1.0, 1.0, 1.0, 0.5]
## Zindan kapısı: bölge -> hale rengi; ad -> ağız merkezinin ayak hücresinin alt orta noktasına göre konumu (dünya px)
const GATE_COLOR: Array[Color] = [Color(0.45, 1.0, 0.72), Color(1.0, 0.32, 0.42), Color(0.42, 0.86, 1.0), Color(1.0, 1.0, 0.6)]
const GATE_MOUTH: Dictionary = {"Kemik Mahzeni": Vector2(0, -24), "Et Kuyusu": Vector2(0, -40), "Boynuzlu Kapı": Vector2(0, -22)}
const GATE_TEX := "res://assets/fx/derin_orman/kapi_isigi.png"
const GATE_VIEW_MARGIN := 120.0
const GATE_MOTE_PER_SEC := 2.2

var _mask: Image
var _tex: Array[Texture2D] = []
var _gate_tex: Texture2D = null
## Işıklar PARALEL dizilerde (madde 372: eskiden ışık başına Dictionary - kare başına ~0,6 ms; hesap ve rastgele sıra AYNI, sadece depolama). Dizi sırası = ışık sırası.
var _m_pos := PackedVector2Array()
var _m_vel := PackedVector2Array()
var _m_age := PackedFloat64Array()
var _m_life := PackedFloat64Array()
var _m_phase := PackedFloat64Array()
var _m_kind := PackedInt32Array()
## Tür başına sabitler (KINDS'ten bir kez): titreme, kesik yanıp sönme, salınım, en çok parlaklık, doku yarı boyutu
var _k_flicker := PackedFloat64Array()
var _k_blink := PackedFloat64Array()
var _k_wobble := PackedFloat64Array()
var _k_alpha := PackedFloat64Array()
var _k_half := PackedVector2Array()
var _rng := RandomNumberGenerator.new()
var _spawn_acc: float = 0.0
var _gate_acc: float = 0.0
var _zone_frac: float = 0.0
var _time: float = 0.0
## kapı başına yakınlık güçlendirmesi (0..1, deep_forest_lore.gd yazar) ve görünürlük
var _gate_boost: Array[float] = []
var _gate_visible: Array[bool] = []


static func attach(harita: Node) -> Node2D:
	var fx: Node2D = (load("res://scripts/deep_forest_fx.gd") as GDScript).new()
	fx.name = "DeepForestFx"
	harita.add_child(fx)
	var lore: Node = (load("res://scripts/deep_forest_lore.gd") as GDScript).new()
	lore.name = "DeepForestLore"
	lore.set("fx", fx)
	harita.add_child(lore)
	return fx


func _ready() -> void:
	top_level = true ## dünya koordinatında çalışır (Harita ofsetinden bağımsız)
	z_index = DRAW_Z
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	var mtex: Texture2D = load(MASK_PATH) as Texture2D
	if mtex != null:
		_mask = mtex.get_image()
		if _mask.is_compressed():
			_mask.decompress()
	for k: Dictionary in KINDS:
		_tex.append(load(k["tex"]) as Texture2D)
		_k_flicker.append(float(k["flicker"]))
		_k_blink.append(float(k["blink"]))
		_k_wobble.append(float(k["wobble"]))
		_k_alpha.append(float(k["alpha"]))
	for t: Texture2D in _tex:
		_k_half.append(t.get_size() * 0.5 if t != null else Vector2.ZERO)
	_gate_tex = load(GATE_TEX) as Texture2D
	for _g in PlacesScript.GATES:
		_gate_boost.append(0.0)
		_gate_visible.append(false)
	if _mask == null or _tex.has(null):
		set_process(false)
		return
	_rng.randomize()


## Dünya konumundaki bölge payları (r Kuzey, g Batı, b Doğu, a Güney; 0..1).
func zone_rgb(world: Vector2) -> Color:
	if _mask == null:
		return Color(0, 0, 0, 0)
	var c: Vector2 = ((world - HARITA_KOKU) / CELL).floor()
	## dış çerçeve maskenin kenar değerini alır (harita_renk.gdshaderinc DO_KENAR_PAYI ile aynı: 0,14 x 256 ~ 36 hücre); daha uzağı bölge değil
	var w: int = _mask.get_width()
	var h: int = _mask.get_height()
	var pad: float = 0.14 * float(w)
	if c.x < -pad or c.y < -pad or c.x >= w + pad or c.y >= h + pad:
		return Color(0, 0, 0, 0)
	return _mask.get_pixel(clampi(int(c.x), 0, w - 1), clampi(int(c.y), 0, h - 1))


## Dünya konumundaki en güçlü bölgenin payı (0..1).
func zone_at(world: Vector2) -> float:
	var z: Color = zone_rgb(world)
	return maxf(maxf(z.r, z.g), maxf(z.b, z.a))


## Konumdaki baskın bölge türü (0 Kuzey, 1 Batı, 2 Doğu, 3 Güney) ya da MIN_ZONE altındaysa -1.
func zone_kind(world: Vector2) -> int:
	var z: Color = zone_rgb(world)
	var best: int = -1
	var v: float = MIN_ZONE
	for i in range(4):
		if z[i] > v:
			v = z[i]
			best = i
	return best


## Zindan girişinin ağız noktası (dünya px).
static func gate_mouth(i: int) -> Vector2:
	var g: Dictionary = PlacesScript.GATES[i]
	var cell: Vector2i = g["cell"]
	return HARITA_KOKU + Vector2(float(cell.x) + 0.5, float(cell.y) + 1.0) * CELL + (GATE_MOUTH.get(g["name"], Vector2(0, -24)) as Vector2)


## deep_forest_lore.gd: yerel oyuncu kapıya yaklaştıkça 0 -> 1.
func set_gate_boost(i: int, v: float) -> void:
	if i >= 0 and i < _gate_boost.size():
		_gate_boost[i] = clampf(v, 0.0, 1.0)


func _view_rect() -> Rect2:
	var xf: Transform2D = get_canvas_transform().affine_inverse()
	return Rect2(xf.origin, get_viewport_rect().size * xf.get_scale())


func _spawn(p: Vector2, kind: int, vel_scale: float = 1.0, life_scale: float = 1.0) -> void:
	var d: Dictionary = KINDS[kind]
	var ang: float = _rng.randf_range(-PI, 0.0) ## hep biraz yukarı süzülür
	var sp: Vector2 = d["speed"]
	var life: Vector2 = d["life"]
	_m_pos.append(p)
	_m_vel.append(Vector2(cos(ang), sin(ang)) * _rng.randf_range(sp.x, sp.y) * vel_scale)
	_m_age.append(0.0)
	_m_life.append(_rng.randf_range(life.x, life.y) * life_scale)
	_m_phase.append(_rng.randf_range(0.0, TAU))
	_m_kind.append(kind)


func _remove_mote(i: int) -> void:
	_m_pos.remove_at(i)
	_m_vel.remove_at(i)
	_m_age.remove_at(i)
	_m_life.remove_at(i)
	_m_phase.remove_at(i)
	_m_kind.remove_at(i)


## Tüm ışıkları siler (testler / yakalama araçları; eskiden `_motes = []` atanıyordu).
func clear_motes() -> void:
	_m_pos.clear()
	_m_vel.clear()
	_m_age.clear()
	_m_life.clear()
	_m_phase.clear()
	_m_kind.clear()


func _process(delta: float) -> void:
	_time += delta
	var view: Rect2 = _view_rect()
	var gates_seen: bool = false
	var gview: Rect2 = view.grow(GATE_VIEW_MARGIN)
	for i in range(_gate_visible.size()):
		_gate_visible[i] = gview.has_point(gate_mouth(i))
		gates_seen = gates_seen or _gate_visible[i]
	## görüş alanının ne kadarı bölgede (4x4 örnek) + baskın türün yoğunluk çarpanı
	var hit: float = 0.0
	for i in range(4):
		for j in range(4):
			var k: int = zone_kind(view.position + view.size * Vector2((i + 0.5) / 4.0, (j + 0.5) / 4.0))
			if k >= 0:
				hit += KIND_DENSITY[k]
	_zone_frac = hit / 16.0
	if _zone_frac <= 0.0 and _m_pos.is_empty() and not gates_seen:
		return
	var grown: Rect2 = view.grow(48.0)
	for k in range(_m_pos.size() - 1, -1, -1):
		var age: float = _m_age[k] + delta
		_m_age[k] = age
		var pos: Vector2 = _m_pos[k] + _m_vel[k] * delta
		_m_pos[k] = pos
		if age >= _m_life[k] or not grown.has_point(pos):
			_remove_mote(k)
	var target: int = int(round(MAX_MOTES * _zone_frac))
	_spawn_acc += delta * SPAWN_PER_SEC
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		if _m_pos.size() >= target:
			break
		var p := Vector2(_rng.randf_range(view.position.x, view.end.x), _rng.randf_range(view.position.y, view.end.y))
		var kind: int = zone_kind(p)
		if kind < 0:
			continue
		_spawn(p, kind)
	## zindan kapısından yükselen ışıklar (bölgenin kendi türü; yaklaşınca sıklaşır)
	if gates_seen:
		_gate_acc += delta
		for i in range(_gate_visible.size()):
			if not _gate_visible[i]:
				continue
			var rate: float = GATE_MOTE_PER_SEC * (1.0 + 2.5 * _gate_boost[i])
			if _rng.randf() < rate * delta and _m_pos.size() < MAX_MOTES + 12:
				var zk: int = int(PlacesScript.GATES[i]["zone"])
				var mouth: Vector2 = gate_mouth(i)
				_spawn(mouth + Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-4.0, 6.0)), zk, 1.6, 0.6)
	queue_redraw()


func _draw() -> void:
	## zindan kapısı halesi: ~2,6 sn'lik nefes; yakınlıkta büyür ve parlar (iki katman: geniş sönük + dar parlak)
	if _gate_tex != null:
		for i in range(_gate_visible.size()):
			if not _gate_visible[i]:
				continue
			var g: Dictionary = PlacesScript.GATES[i]
			var col: Color = GATE_COLOR[int(g["zone"])]
			var breath: float = 0.5 + 0.5 * sin(_time * 2.4 + float(i) * 1.7)
			var boost: float = _gate_boost[i]
			var mouth: Vector2 = gate_mouth(i)
			for layer in range(2):
				var sz: float = (2.0 if layer == 0 else 1.0) * (1.0 + 0.12 * breath + 0.35 * boost)
				var a: float = (0.35 if layer == 0 else 0.6) * (0.55 + 0.45 * breath) * (1.0 + 0.8 * boost)
				var ts: Vector2 = _gate_tex.get_size() * round(sz * 2.0) * 0.5
				draw_texture_rect(_gate_tex, Rect2((mouth - ts * 0.5).round(), ts), false, Color(col.r, col.g, col.b, minf(a, 1.0)))
	for i in range(_m_pos.size()):
		var kind: int = _m_kind[i]
		var age: float = _m_age[i]
		var phase: float = _m_phase[i]
		var t: float = age / _m_life[i]
		var a: float
		if _k_flicker[kind] > 0.0:
			## yavaşça belirir / söner, arada hafif titrer
			a = smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.7, 1.0, t)) * (0.75 + 0.25 * sin(age * _k_flicker[kind] + phase))
		else:
			## pırıltı: ortada tepe yapan kısa parlama
			a = sin(t * PI)
			a *= a
		if _k_blink[kind] > 0.0:
			## ateş böceği: kesik yanıp sönme (yarı süre karanlık)
			a *= 1.0 if sin(age * _k_blink[kind] * TAU + phase) > -0.2 else 0.08
		var p: Vector2 = _m_pos[i] + Vector2(sin(age * 0.9 + phase) * _k_wobble[kind], 0.0)
		draw_texture(_tex[kind], (p - _k_half[kind]).round(), Color(1, 1, 1, a * _k_alpha[kind]))


## Test/hata ayıklama: şu anki ışık sayısı (türe göre), görüş alanının bölge payı, görünen kapılar.
func debug_state() -> Dictionary:
	var by_kind: Array[int] = [0, 0, 0, 0]
	for k in _m_kind:
		by_kind[k] += 1
	return {"motes": _m_pos.size(), "zone_frac": _zone_frac, "by_kind": by_kind, "gates_visible": _gate_visible.count(true)}
