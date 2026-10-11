extends Node2D

## ELİT yaratığın başının üstündeki can + kalkan barı (kullanıcı isteği 2026-10-11: "elit düşmanların üstünde can ve kalkan barı görünsün, tıpkı
## oyuncuların üstündeki gibi ama biraz daha boss can barına benzer olsun ve canı yeşil yerine kırmızı"). Oyuncunun barıyla aynı boy/konum sınıfı
## (overhead_bar.gd; üstte kalkan şeridi, altta can), ama boss barının (boss_bar_top.gd / boss_bar_art.gd) demir plaka + bantlı kırmızı can +
## mavi kalkan + %10 dilimleri + "son hasar izi" + solda elit yıldızıyla çizilir. Her zaman görünür (elit hasar almasa da). Çubuk sayıları yok.
## enemy.gd make_elite() ekler (host ve istemci aynı fonksiyondan geçer); değerleri her karede yaratıktan okur (health / item_shield_hp - istemcide de güncel).
## 1 sanat pikseli = 1 yerel birim (kamera zoom 2 -> 2 ekran px), boss üstü kafatası plakasıyla aynı ölçek.

const ArtScript: GDScript = preload("res://scripts/boss_bar_art.gd")

const BAR_W := 40
const HP_H := 5
const SH_H := 3
const PAD := 2        ## plaka kenarı (1 koyu anahat + 1 demir)
const PixelDraw := preload("res://scripts/pixel_draw.gd")
const StarScript := preload("res://scripts/elite_star.gd")
const STAR_PX := 11   ## elit yıldızı (9 texel x PixelDraw.TEXEL) - barın solunda
const PLATE_X := 9    ## plakanın sol kenarı (yıldızın sağında, yıldız plakaya biner)
const TRAIL_DELAY := 0.35
const TRAIL_SPEED := 0.9 ## oran/sn

var _enemy: Node = null
var bottom_y: float = -60.0 ## plakanın ALT kenarı (yaratık köküne göre yerel y)
var _hp: float = 1.0
var _sh: float = 0.0
var _has_shield: bool = false
var _trail: float = 1.0
var _trail_hold: float = 0.0


func setup(enemy: Node, bottom: float) -> void:
	_enemy = enemy
	bottom_y = bottom
	_read()
	_trail = _hp
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _read() -> void:
	var mx: float = maxf(float(_enemy.get("max_health")), 0.001)
	_hp = clampf(float(_enemy.get("health")) / mx, 0.0, 1.0)
	var smx: float = float(_enemy.get("item_shield_max"))
	_has_shield = smx > 0.0
	_sh = clampf(float(_enemy.get("item_shield_hp")) / smx, 0.0, 1.0) if _has_shield else 0.0


func _process(delta: float) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	if _enemy.get("is_dead") == true:
		queue_free()
		return
	visible = _enemy.get("is_ability_invisible") != true
	var old_hp: float = _hp
	var old_sh: float = _sh
	var old_has: bool = _has_shield
	_read()
	if _hp < old_hp - 0.0005:
		_trail_hold = TRAIL_DELAY
	if _hp >= _trail:
		_trail = _hp
	elif _trail_hold > 0.0:
		_trail_hold -= delta
	else:
		_trail = maxf(_hp, _trail - TRAIL_SPEED * delta)
	if absf(_hp - old_hp) > 0.0005 or absf(_sh - old_sh) > 0.0005 or _has_shield != old_has or _trail > _hp + 0.0005:
		queue_redraw()


func _draw() -> void:
	var plate_h: int = PAD * 2 + HP_H + ((SH_H + 1) if _has_shield else 0)
	var plate_w: int = PAD * 2 + BAR_W
	var total_w: int = PLATE_X + plate_w
	var o := Vector2(-roundf(float(total_w) * 0.5), roundf(bottom_y) - float(plate_h))
	var s := 1.0
	# plaka: koyu anahat + demir gövde + üst parlak çizgi + köşelerde altın çivi
	ArtScript.rrect(self, o, s, PLATE_X, 0, plate_w, plate_h, ArtScript.OUT2)
	ArtScript.rrect(self, o, s, PLATE_X + 1, 1, plate_w - 2, plate_h - 2, ArtScript.IRON_D)
	ArtScript.r(self, o, s, PLATE_X + 2, 1, plate_w - 4, 1, ArtScript.IRON_L)
	var bx: float = PLATE_X + PAD
	var y: float = PAD
	if _has_shield:
		ArtScript.fill_bar(self, o, s, bx, y, BAR_W, SH_H, _sh, ArtScript.SH_BANDS, ArtScript.EMPTY_BLUE)
		y += SH_H + 1
	ArtScript.hp_bar_trail(self, o, s, bx, y, BAR_W, HP_H, _hp, _trail)
	ArtScript.r(self, o, s, PLATE_X + 1, plate_h - 2, 1, 1, ArtScript.GOLD)
	ArtScript.r(self, o, s, PLATE_X + plate_w - 2, plate_h - 2, 1, 1, ArtScript.GOLD)
	# elit yıldızı (plakanın solunda, dikeyde ortalı) - eski kafatasının yeri
	PixelDraw.art(self, o + Vector2(float(STAR_PX) * 0.5 - 1.0, float(plate_h) * 0.5), StarScript.STAR, StarScript.PALETTE)
