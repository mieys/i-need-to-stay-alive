extends Node2D

## Oakley'in Koruyucu Büyü'sü (R, skill3 id 39) - büyüyü ALAN kişinin etrafındaki yaprak mührü.
##
## YENİDEN TASARIM (kullanıcı isteği 2026-09-25: "pasif harici yeteneklerin efektlerini pixel tarzda yeniden tasarla,
## spritesheete dönüştür" + "şuankiler çok kötü"): eski _draw() (dither küre + kesikli halkalar + her karede yüzlerce
## px() ile çizilen yapraklar/parçalar) tamamen kaldırıldı. Artık tools/gen_oakley_fx.py sayfaları:
##  - ward_back / ward_front: "open" (yapraklar sarmal çizerek gelir, ayak altındaki altın rünlü mühür kendini çizer,
##    parlar) -> "loop" (gövde etrafında dönen parlak yapraklar + dönen altın glifli mühür + yükselen zerreler + çok
##    soluk kubbe kenarı) -> "close" (yapraklar dağılıp düşer, mühür söner). Yörüngenin ARKA yarısı karakterin arkasında
##    (bu düğüm show_behind_parent), ÖN yarısı önünde (ebeveyne kardeş olarak eklenen ön katman) - fx_paladin_barrier_link.gd deseni.
##  - ward_hit: hasar anında yaprak kalkanı parlaması + savrulan yaprak kırıkları (ön katmanın üstünde).
##
## DEĞİŞMEYEN davranış (kullanıcı isteği 2026-09-21: "R'si aktifken etrafında yeşil koruyucu yapraklar ... bu kalkana
## sahip kişi her hasar aldığında üstünde yeşil parçalar çıkmalı"): Player'ın (büyüyü alan kişi) YA DA RemotePlayer
## kuklasının ÇOCUĞU; ömrü ebeveynin bayrağını izler - yerelde oakley_bond_active, uzakta _oakley_bond_on (bkz. main.gd
## extra["oakley_bond"], remote_player.gd). Uzak kuklada "hasar aldı" bilgisi sağlık+kalkan düşüşünden anlaşılır (yerelde
## player.gd take_damage hit()'i doğrudan çağırır) - iki taraf AYNI sahneyi kullanır.

const BACK_FRAMES := preload("res://assets/fx/oakley/ward_back_frames.tres")
const FRONT_FRAMES := preload("res://assets/fx/oakley/ward_front_frames.tres")
const HIT_FRAMES := preload("res://assets/fx/oakley/ward_hit_frames.tres")
const TEXEL := 1.212
## Kare 72x96, ayak (36,84) = karakter kökünün +33'ü (ayak hizası) -> kare merkezi (36,48) yerel y = 33 - 36*TEXEL.
const CENTER := Vector2(0.0, 33.0 - 36.0 * TEXEL)
const NO_FLAG_GRACE := 2.0 ## uzak kopyada durum paketi gecikirse bayrak henüz true olmayabilir
## Hasar parlaması en fazla bu sıklıkta baştan başlar (sürekli vurulan kişide titremesin).
const HIT_RESTART_FRAME := 3

var _host: Node2D = null
var _t: float = 0.0
var _seen_on: bool = false
var _off_time: float = 0.0
var _closing: bool = false
var _last_total: float = -1.0
var _is_puppet: bool = false

var _back: AnimatedSprite2D = null
var _front: AnimatedSprite2D = null
var _hit: AnimatedSprite2D = null


func _ready() -> void:
	z_index = 0
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_host = get_parent() as Node2D
	_is_puppet = _host != null and not _host.is_in_group("player")
	_back = _make_layer(BACK_FRAMES)
	add_child(_back)
	_front = _make_layer(FRONT_FRAMES)
	_hit = _make_layer(HIT_FRAMES)
	_hit.visible = false
	_hit.animation_finished.connect(func() -> void: _hit.visible = false)
	if _host != null:
		_host.add_child.call_deferred(_front)
		_host.add_child.call_deferred(_hit)
	_back.animation_finished.connect(_on_anim_finished)
	_play(&"open")


func _make_layer(frames: SpriteFrames) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * TEXEL
	s.position = CENTER
	return s


func _play(anim: StringName) -> void:
	_back.play(anim)
	if is_instance_valid(_front):
		_front.play(anim)


func _on_anim_finished() -> void:
	if _back.animation == &"open":
		_play(&"loop")
	elif _back.animation == &"close":
		queue_free()


func _exit_tree() -> void:
	if is_instance_valid(_front):
		_front.queue_free()
	if is_instance_valid(_hit):
		_hit.queue_free()


func _flag_on() -> bool:
	if _host == null or not is_instance_valid(_host):
		return false
	if "oakley_bond_active" in _host:
		return bool(_host.oakley_bond_active)
	if "_oakley_bond_on" in _host:
		return bool(_host._oakley_bond_on)
	return true


## Hasar alındı: yaprak kalkanı parlar, kırıklar saçılır (yerel: player.gd take_damage, uzak: sağlık/kalkan düşüşü).
func hit() -> void:
	if _closing or not is_instance_valid(_hit):
		return
	if _hit.visible and _hit.is_playing() and _hit.frame < HIT_RESTART_FRAME:
		return
	_hit.visible = true
	_hit.frame = 0
	_hit.play(&"hit")


func _process(delta: float) -> void:
	_t += delta
	var on: bool = _flag_on()
	if on:
		_seen_on = true
		_off_time = 0.0
	else:
		_off_time += delta
	var should_close: bool = (_seen_on and _off_time > 0.3) or ((not _seen_on) and _t > NO_FLAG_GRACE)
	if should_close and not _closing:
		_closing = true
		_play(&"close")
	## Uzak kuklada hasar tespiti: sağlık + kalkan toplamı düştüyse hit().
	if _is_puppet and _host != null and is_instance_valid(_host) and "health" in _host:
		var total: float = float(_host.health) + (float(_host.item_shield_hp) if "item_shield_hp" in _host else 0.0)
		if _last_total >= 0.0 and total < _last_total - 0.01:
			hit()
		_last_total = total
	## Ön katman sonradan (call_deferred) eklendiği için karesini arka katmanla eşitle.
	if is_instance_valid(_front) and _front.animation == _back.animation and _front.frame != _back.frame:
		_front.frame = _back.frame
