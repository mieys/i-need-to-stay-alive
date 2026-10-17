extends Node2D

## Cadı Q (Zehirli Duman) - şişeden yere dökülen dumanın bıraktığı bulut. Dünya konumunda sabit; yaratıkların ÜSTÜNDE,
## oyuncuların ALTINDA, bulut başına %50 saydam çizilir (kullanıcı 2026-10-13; R alanları hâlâ zeminde - cadi_zone.gd).
## Bu düğüm sadece görsel + geometri: hasar/yavaşlatma kasterde tek yerde hesaplanır (player.gd _process_cadi_smoke -
## aynı yaratık kaç bulutun içinde olursa olsun saniyede BİR hasar alır), o tarama "authoritative" kopyaları `contains` ile sorar.
## Diğer istemcilerdeki kopyalar network_manager.gd "cadi_fx"/"smoke" ile AYNI seçeneklerle kurulur.

const CadiMath := preload("res://scripts/cadi_math.gd")
const GROUP := "cadi_smokes"
const SAFETY_EXTRA := 2.0

var life: float = CadiMath.SMOKE_LIFE
var size_mult: float = 1.0
var owner_peer: int = 0
var authoritative: bool = false
## Cadı yukarı/aşağı yürürken bırakılan dar + derin bulut: ayrı klipler (_v), ayrı iz (CadiMath.SMOKE_V_RX/RY).
var vert: bool = false

var _sprite: AnimatedSprite2D = null
var _t: float = 0.0
var _ending: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = CadiMath.SMOKE_Z
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = CadiMath.frames("smoke")
	## Evrim "Yoğun Duman" (+%30): sayfa büyütülür - 0,903 x 1,3 = 1,17 dünya birimi/piksel, oyunun genel efekt dokusuyla (1,212) aynı.
	_sprite.scale = Vector2.ONE * CadiMath.WORLD_TEXEL * size_mult
	_sprite.offset = -(CadiMath.SMOKE_V_CENTER_ART if vert else CadiMath.SMOKE_CENTER_ART)
	if vert:
		_sprite.position.x = roundf(randf_range(-CadiMath.SMOKE_V_JITTER_ART, CadiMath.SMOKE_V_JITTER_ART)) * CadiMath.WORLD_TEXEL * size_mult
	_sprite.modulate.a = CadiMath.SMOKE_ALPHA
	## Yan yana aynı bulut dizilmesin: rastgele aynalama (sadece görsel; orijin karenin yatay ortasında, iz değişmez).
	_sprite.flip_h = randf() < 0.5
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play(_clip("intro"))
	add_to_group(GROUP)
	_place_under_players.call_deferred()


## Sahnede y-sort yok: aynı z'deki kardeşler AĞAÇ SIRASIYLA çizilir. Oyuncular da z 1'de (yerel Player sahnenin ilk çocuğu,
## kuklalar sonradan eklenir) - sahnenin başına taşınan bulut onların altında, z 0'daki her şeyin (harita, yaratıklar, zemin
## efektleri) üstünde kalır. Oyuncunun önüne geçip z 2'ye alınan yaratık (creature_depth.gd) dumanın da üstünde çizilir.
## Bulutlar kendi aralarında Y SIRASINDA durur (ekranda aşağıdaki = öndeki, sonra çizilir): cadı yukarı yürürken yeni
## bulut eskilerin ARKASINDA, aşağı yürürken ÖNÜNDE kalır; aynı Y'de (yatay iz) yeni bulut üstte.
func _place_under_players() -> void:
	var parent: Node = get_parent()
	if not is_inside_tree() or parent == null:
		return
	var idx: int = 0
	while idx < parent.get_child_count():
		var c: Node = parent.get_child(idx)
		if c == self or not c.is_in_group(GROUP) or (c as Node2D).global_position.y > global_position.y:
			break
		idx += 1
	parent.move_child(self, idx)


func _clip(base: String) -> StringName:
	return StringName(base + "_v") if vert else StringName(base)


## Aynı cadı aynı noktaya yeniden duman döktüğünde (CadiMath.spawn_smoke) ömür baştan başlar. Sönmeye başladıysa ya da
## boyut/tür farklıysa false: yeni bulut açılır.
func refresh(new_life: float, new_size: float, new_vert: bool = false) -> bool:
	if _ending or new_vert != vert or not is_equal_approx(new_size, size_mult):
		return false
	life = new_life
	_t = 0.0
	return true


func _on_animation_finished() -> void:
	if _sprite.animation == _clip("intro") and not _ending:
		_sprite.play(_clip("loop"))
	elif _sprite.animation == _clip("outro"):
		queue_free()


## Hasar verir mi: ömrü boyunca (sönerken de) - "3 saniye boyunca kalır ve yavaşça kaybolur".
func is_active() -> bool:
	return _t < life


func contains(p: Vector2, margin: float = 0.0) -> bool:
	var rx: float = CadiMath.SMOKE_V_RX if vert else CadiMath.SMOKE_RX
	var ry: float = CadiMath.SMOKE_V_RY if vert else CadiMath.SMOKE_RY
	return CadiMath.in_ellipse(p, global_position, rx * size_mult + margin, ry * size_mult + margin)


func _process(delta: float) -> void:
	_t += delta
	if not _ending and _t >= life - CadiMath.SMOKE_OUTRO_TIME:
		_ending = true
		_sprite.play(_clip("outro"))
	elif _t > life + SAFETY_EXTRA:
		queue_free()
