extends Node2D

## YENİ HAVUZUN MERMİLERİ (madde 575, 2026-11-11; bkz. enemy_abilities.gd _process_shot / _process_crystal): enemy_bone.gd ile AYNI yapı -
## yetkili (host/tek oyunculu) örnek hasar verir, istemcideki görsel kopya (broadcast_enemy_ability_fx "creature_shot") sadece uçar.
## data.style:
##   "spear"   - Goblin 3 "Mızrak Fırlatma": dönmeden uçan kısa mızrak (ahşap sap + demir uç), ilk değdiği oyuncuya hasar.
##   "spit"    - Kertenkele Adam 2 "Zehir Tükürüğü": sallanan yeşil damla; hedefin o anki NOKTASINA (data.dist) uçar, değdiği oyuncuya hasar,
##               vardığı yerde (ya da değdiği yerde) host küçük bir zehir gölü (enemy_acid_pool.gd) bırakır - yana adımla kaçılır.
##   "crystal" - Kristal Pelte "Kristal Saçması": mor kristal kıymığı (6'sı birden dairesel saçılır).
## Sanat: doku kodla çizilir (build_image, sanat pikseli = TEXEL dünya px, koyu kontür) - dosya yok, ısınma listesi gerekmez.

const TEXEL := 1.212 ## yaratık yetenek efektleriyle aynı piksel yoğunluğu (enemy_bone.gd)
const PaladinDome := preload("res://scripts/paladin_dome.gd")
const KalkanGuard := preload("res://scripts/kalkan_guard.gd") ## Kalkan silahı siper duruşu (madde 685)
const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const ShieldBubbleHit := preload("res://scripts/shield_bubble_hit.gd")
const ProjectileRangeScript := preload("res://scripts/projectile_range.gd")
const LIFETIME := 2.2
const HIT_RADIUS := 6.0
const WALL_IGNORE_TIME := 0.08
const POOF_TIME := 0.2
const SPIT_ACID_DURATION := 2.5

## Palet: 0 boş, 1 koyu kontür (otomatik), 2.. renkler
const PALETTES := {
	"spear": [Color8(46, 30, 22), Color8(126, 84, 48), Color8(168, 118, 70), Color8(150, 158, 170), Color8(226, 232, 240)],
	"spit": [Color8(20, 46, 24), Color8(70, 150, 52), Color8(126, 206, 76), Color8(196, 246, 140), Color8(196, 246, 140)],
	"crystal": [Color8(42, 20, 66), Color8(122, 70, 196), Color8(176, 120, 236), Color8(232, 200, 255), Color8(255, 246, 255)],
}
## Desenler (sağa bakan). Rakam = PALETTES indeksi (1 = sap/gövde koyu ton ... 4 = en parlak); "." boş. Kontür build_image'da eklenir.
const SHAPES := {
	"spear": [
		"..............33..",
		"11111111111113444.",
		"22222222222223444.",
		"..............33..",
	],
	"spit": [
		"....122..",
		"..112342.",
		"1.123442.",
		"..112222.",
		"....111..",
	],
	"crystal": [
		"...1222...",
		".11223442.",
		"1122334444",
		".11223332.",
		"...1222...",
	],
}

static var _tex: Dictionary = {}

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _style: String = "spear"
var _dir: Vector2 = Vector2.RIGHT
var _speed: float = 240.0
var _max_dist: float = -1.0 ## > 0: bu kadar yol alınca durur (tükürük hedef noktasına iner)
var _travelled: float = 0.0
var _life: float = 0.0
var _poof: float = -1.0
var _sprite: Sprite2D = null


static func build_image(style: String) -> Image:
	var rows: Array = SHAPES.get(style, SHAPES["spear"])
	var pal: Array = PALETTES.get(style, PALETTES["spear"])
	var h: int = rows.size()
	var w: int = String(rows[0]).length()
	var img := Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var filled := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and String(rows[y])[x] != "."
	for y in range(h):
		for x in range(w):
			if not filled.call(x, y):
				continue
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				if not filled.call(x + d.x, y + d.y):
					img.set_pixel(x + 1 + d.x, y + 1 + d.y, pal[0])
	for y in range(h):
		for x in range(w):
			var ch: String = String(rows[y])[x]
			if ch != ".":
				img.set_pixel(x + 1, y + 1, pal[clampi(int(ch), 1, pal.size() - 1)])
	return img


static func texture(style: String) -> Texture2D:
	if not _tex.has(style):
		_tex[style] = ImageTexture.create_from_image(build_image(style))
	return _tex[style]


func _ready() -> void:
	add_to_group(KalkanGuard.GROUP)
	z_index = 11
	_style = str(data.get("style", "spear"))
	_dir = Vector2(data.get("dir", Vector2.RIGHT))
	if _dir.length() < 0.01:
		_dir = Vector2.RIGHT
	_dir = _dir.normalized()
	_speed = float(data.get("speed", 240.0))
	_max_dist = float(data.get("dist", -1.0))
	_sprite = Sprite2D.new()
	_sprite.texture = texture(_style)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * TEXEL * _art_scale()
	add_child(_sprite)
	rotation = _dir.angle()


func _physics_process(delta: float) -> void:
	if _poof >= 0.0:
		_poof += delta
		if _poof >= POOF_TIME:
			queue_free()
		else:
			queue_redraw()
		return
	_life += delta
	if _life >= LIFETIME or not ProjectileRangeScript.within(self):
		_land()
		return
	var step: float = _speed * delta
	global_position += _dir * step
	_travelled += step
	if _style == "spit" and _sprite: ## damla uçarken hafifçe kabarıp söner
		var k: float = 1.0 + 0.12 * sin(_life * 22.0)
		_sprite.scale = Vector2(TEXEL * k, TEXEL / k) * _art_scale()
	if _max_dist > 0.0 and _travelled >= _max_dist:
		_land()
		return
	if _life >= WALL_IGNORE_TIME and GameManager.is_position_blocked_by_forest(global_position):
		_break()
		return
	if GameManager.merchant_zone_active and global_position.distance_to(GameManager.merchant_zone_pos) <= GameManager.MERCHANT_ZONE_RADIUS:
		_break()
		return
	for p in AbilitiesScript.damageable_players(get_tree()):
		var pn := p as Node2D
		if PaladinDome.node_contains(pn, global_position):
			if authoritative:
				PaladinDome.absorb_ranged_hit(pn, damage, source) ## kubbe atışı emer (madde 542)
			_break()
			return
		KalkanGuard.guard_shot(pn, self) ## Kalkan silahı siper duruşu: önden gelen atışın hasarı %30 azalır, atış durmaz (madde 705)
		if pn.has_method("get_talon_ward_radius"):
			var ward_r: float = float(pn.call("get_talon_ward_radius"))
			if ward_r > 0.0 and global_position.distance_to(pn.global_position) <= ward_r:
				_break()
				return
		if ShieldBubbleHit.touches(pn, global_position, HIT_RADIUS):
			ShieldBubbleHit.impact(pn, global_position)
			if authoritative:
				AbilitiesScript.deal_special_damage(p, damage, source, _style)
			_land()
			return
		if global_position.distance_to(pn.global_position) <= HIT_RADIUS + AbilitiesScript.TARGET_BODY_RADIUS:
			if authoritative:
				AbilitiesScript.deal_special_damage(p, damage, source, _style)
			_land()
			return


## Tükürük damlası küçük çizimdir: oyunda okunsun diye tam 2 kat (piksel ızgarası bozulmaz).
func _art_scale() -> float:
	return 2.0 if _style == "spit" else 1.0


## Bitiş: tükürük yere iner ve (yalnız host) zehir gölü bırakır; diğerleri kırılır.
func _land() -> void:
	if _style == "spit" and authoritative and _poof < 0.0:
		var acid_dmg: float = float(data.get("acid", 0.0))
		if acid_dmg > 0.0 and not GameManager.is_position_blocked_by_forest(global_position):
			var pos: Vector2 = global_position
			var adata: Dictionary = {"duration": SPIT_ACID_DURATION}
			AbilitiesScript.spawn_world_fx(get_tree(), "acid", pos, adata, true, source, acid_dmg)
			AbilitiesScript._broadcast_world_fx("acid", pos, adata)
	_break()


## Kırılma: mermi kaybolur, 5 kırıntı (stilin parlak rengi) dışa saçılıp söner.
func _break() -> void:
	if _poof >= 0.0:
		return
	_poof = 0.0
	if _sprite:
		_sprite.visible = false
	rotation = 0.0
	queue_redraw()


func _draw() -> void:
	if _poof < 0.0:
		return
	var t: float = clampf(_poof / POOF_TIME, 0.0, 1.0)
	var pal: Array = PALETTES.get(_style, PALETTES["spear"])
	var col := Color(pal[3], 1.0 - t)
	var px: float = TEXEL * 2.0
	for i in range(5):
		var a: float = float(i) / 5.0 * TAU + 0.4
		var r: float = 3.0 + 10.0 * t
		var p: Vector2 = (Vector2.from_angle(a) * r / TEXEL).round() * TEXEL ## sanat pikseli ızgarasına
		draw_rect(Rect2(p - Vector2(px, px) * 0.5, Vector2(px, px)), col)
