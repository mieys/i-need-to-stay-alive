extends Node2D

## Şovalye (Paladin) R'si ("Koruma Baloncuğu") aktifken oyuncuya eklenen kalıcı, BÜYÜK koruma alanı baloncuğu - bkz.
## player.gd _skill_paladin_ulti/_end_paladin_ulti. Diğer oyuncularda remote_player.gd _ensure_barrier_visual AYNI
## script'i kurar (tek görsel yolu).
##
## z_index MUTLAKA absolute olmalı (z_as_relative = false) - Player'ın kendi z_index'i main.tscn'de 1 olarak ayarlı,
## göreceli negatif bir değer (ör. -5) zemin TileMapLayer'larının (z_index=0, absolute) ARKASINDA kalıp baloncuğu
## tamamen görünmez yapıyordu.
##
## YENİDEN TASARIM (kullanıcı isteği 2026-09-25: "şovalye adamın kalkan baloncuğunun efektini de pixel tarzda yeniden
## tasarlamanı istiyorum yine önceki hali gibi hasar alınca özel efektler ve bariyer hasar alıyormuş gibi hafif
## parıldamalı görünmeli ... spritesheete dönüştür ki performans kaybı yaşanmasın"): eskiden kubbe her karede bir
## shader'la (shaders/shield_dome.gdshader, ColorRect) + ayrı bir çizim overlay'iyle (fx_paladin_overlay.gd) çiziliyordu.
## Artık tools/gen_paladin_dome_fx.py sayfaları:
##  - loop: altıgen örgülü mavi enerji kubbesi, üzerinden çapraz akan parıltı bandı (16 kare döngü).
##  - flash: her isabette kubbenin kenar bandı ve örgüsü hafifçe parlayıp söner (loop'un ÜSTÜNDE ayrı sprite).
## İsabet noktasındaki yönlü piksel çatlak (fx_shield_hit.gd, zaten sprite) önceki gibi kalır.
##
## BOĞUK SES (aynı istek: "içinde bulunan oyuncular dışardaki sesleri boğuk duymalı sanki bir bariyerin içindeymiş gibi"):
## yerel oyuncu bu baloncuğun içindeyken baloncuğun DIŞINI kaplayan halka biçimli bir Area2D kurulur; audio_bus_override
## ile o halkanın içinde (yani baloncuğun dışında) çalan her AudioStreamPlayer2D, alçak geçiren filtreli MUFFLE_BUS'a
## yönlenir (Godot: 2D ses çalar, bulunduğu noktadaki bus-override'lı alanın bus'ını kullanır). Baloncuğun içindeki
## sesler (Şovalye'nin/dostların kendi silahları vb.) normal kalır. Alan, hiçbir Area2D sinyali/sorgusu olmayan oyunda
## çarpışma katmanı 1'de (AudioStreamPlayer2D.area_mask varsayılanı) ama monitorable/monitoring KAPALI durur - başka
## alanlarla çift oluşturmaz, fiziğe etkisi yoktur. UI sesleri (AudioStreamPlayer) etkilenmez.

var radius: float = 126.0 ## player.gd _skill_paladin_ulti() PALADIN_ULTI_ZONE_RADIUS ile üzerine yazar - bu sadece varsayılan
var color: Color = Color(0.35, 0.78, 1.0, 0.95) ## gece ışığı rengi (bkz. night_glow_catalog.gd "cp": "color")
var active: bool = true
## Seyyar satıcının güvenli bölgesi de bu script'i kullanır (traveling_merchant.gd) - add_child'dan ÖNCE atanır:
## "gold" = altın ticaret kubbesi (tools/gen_paladin_dome_fx.py *_gold sayfaları), boğuk ses KAPALI.
var variant: String = ""
var muffle_outside_sound: bool = true

const LoopFrames := preload("res://assets/fx/paladin_dome/loop_frames.tres")
const FlashFrames := preload("res://assets/fx/paladin_dome/flash_frames.tres")
const LoopFramesGold := preload("res://assets/fx/paladin_dome/loop_gold_frames.tres")
const FlashFramesGold := preload("res://assets/fx/paladin_dome/flash_gold_frames.tres")
## Sayfalardaki kubbe yarıçapı (sanat pikseli = dünya birimi) - radius farklıysa sprite orantılı ölçeklenir.
const ART_RADIUS := 126.0
const APPEAR_TIME := 0.25

## Kullanıcı bildirimi (2026-09-23): "şovalye adamın kalkan baloncuğunu açtığımda fps 10'a düşüyor çünkü çok sayıda
## kalkan hasar alma efekti oluyor" - kalabalık bir sürüde saniyede onlarca isabet olabiliyor. Yönlü çatlak fx'i
## (fx_shield_hit.gd) sprite olsa da aynı anda kaç tane canlı olabileceği ve doğma sıklığı sınırlı; kubbenin kendi
## flaşı (tek sprite, yeniden başlatılır) her isabette tetiklenir.
const MAX_CONCURRENT_HIT_FX := 4
const HIT_FX_MIN_INTERVAL := 0.05
## Bariyer isabet efektinin (çatlak) sabit ölçeği - 1.0 = oyuncunun kendi kalkan baloncuğundaki çatlakla aynı boy.
const PALADIN_CRACK_SCALE := 1.0

const AudioBuses := preload("res://scripts/audio_buses.gd")
## Halkanın dış yarıçapı (dünya birimi) - ekranın çok dışı; daha uzaktaki sesler zaten duyulmuyor (max_distance).
const MUFFLE_OUTER_RADIUS := 4000.0
const MUFFLE_SEGMENTS := 24

var _hit_fx_count: int = 0
var _hit_fx_cooldown: float = 0.0
var _loop: AnimatedSprite2D = null
var _flash: AnimatedSprite2D = null
var _t: float = 0.0
var _muffle_area: Area2D = null


func _ready() -> void:
	z_as_relative = false
	z_index = 20 ## zeminin (0) kesinlikle üstünde, kalıcı/güvenilir görünürlük
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	## Karakterin kendi ölçeğinden bağımsız global boyut: 1 yerel birim = 1 dünya birimi = 1 sanat pikseli.
	var p := get_parent()
	if p is Node2D:
		var ps: Vector2 = (p as Node2D).scale
		if ps.x != 0.0 and ps.y != 0.0:
			scale = Vector2(1.0 / ps.x, 1.0 / ps.y)
	var art_scale: float = radius / ART_RADIUS
	var gold: bool = variant == "gold"
	_loop = _make_sprite(LoopFramesGold if gold else LoopFrames, art_scale)
	_loop.play("loop")
	_loop.frame = randi() % LoopFrames.get_frame_count("loop")
	_flash = _make_sprite(FlashFramesGold if gold else FlashFrames, art_scale)
	_flash.visible = false
	_flash.animation_finished.connect(func() -> void: _flash.visible = false)
	## Açılış: küçükten büyüyerek belirir.
	modulate.a = 0.0
	_loop.scale = Vector2.ONE * art_scale * 0.7


func _make_sprite(frames: SpriteFrames, art_scale: float) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = true
	s.scale = Vector2.ONE * art_scale
	add_child(s)
	return s


func _exit_tree() -> void:
	_remove_muffle_area()


## Kullanıcı bildirimi: "Şovalye adamın kalkan baloncuğuna vurulduğu andaki çatlama ve kalkanın hasar alma efekti
## şovalye adam haricinde kimseye görünmüyor" - network_manager.gd broadcast_player_vfx() "paladin_barrier_flash"
## RPC'siyle bu fonksiyon uzak kopyalarda da çağrılıyor (saldıranın Node2D'si uzakta anlamsız, sadece açı gider).
func flash_from_angle(angle: float) -> void:
	_play_flash()
	_spawn_pixel_hit(angle)


func flash(attacker: Node2D = null) -> void:
	var parent := get_parent() as Node2D
	var angle: float = randf_range(0.0, TAU)
	if attacker and is_instance_valid(attacker) and parent:
		angle = (attacker.global_position - parent.global_position).angle()
	flash_from_angle(angle)


func _play_flash() -> void:
	if _flash == null:
		return
	_flash.visible = true
	_flash.frame = 0
	_flash.play("flash")


## Kullanıcı isteği (2026-09-21): "kalkanların hasar alma efektleri pixel tarzı, mavi ve yarı saydam bir bariyer hasarı
## efekti olsun" - oyuncu kalkanıyla AYNI pixel efekt (fx_shield_hit.gd, bu bariyerin kendi yarıçapıyla) doğar.
func _spawn_pixel_hit(angle: float) -> void:
	if _hit_fx_cooldown > 0.0 or _hit_fx_count >= MAX_CONCURRENT_HIT_FX:
		return
	_hit_fx_cooldown = HIT_FX_MIN_INTERVAL
	_hit_fx_count += 1
	var fx := Node2D.new()
	fx.set_script(load("res://scripts/fx_shield_hit.gd"))
	add_child(fx)
	fx.tree_exited.connect(func() -> void: _hit_fx_count -= 1)
	## Kullanıcı bildirimi (2026-09-24): çatlaklar çok büyüktü - sabit PALADIN_CRACK_SCALE boyutunda, bariyerin kenarında.
	fx.call("setup", angle, radius, false, PALADIN_CRACK_SCALE)


func _process(delta: float) -> void:
	if not active:
		queue_free()
		return
	if _t < APPEAR_TIME:
		_t += delta
		var k: float = clampf(_t / APPEAR_TIME, 0.0, 1.0)
		modulate.a = k
		_loop.scale = Vector2.ONE * (radius / ART_RADIUS) * lerpf(0.7, 1.0, 1.0 - (1.0 - k) * (1.0 - k))
	if _hit_fx_cooldown > 0.0:
		_hit_fx_cooldown = max(0.0, _hit_fx_cooldown - delta)
	_update_muffle()


## ---------------------------------------------------------------- boğuk ses (bkz. dosya başı notu)
func _update_muffle() -> void:
	if not muffle_outside_sound:
		return
	var local_player := get_tree().get_first_node_in_group("player") as Node2D
	var inside: bool = local_player != null and is_instance_valid(local_player) and local_player.get("is_dead") != true \
		and local_player.global_position.distance_to(global_position) <= radius
	if inside and _muffle_area == null:
		_create_muffle_area()
	elif not inside and _muffle_area != null:
		_remove_muffle_area()
	if _muffle_area != null:
		_muffle_area.global_position = global_position


## Yerel oyuncunun şu an içinde olduğu kubbeler - biri bile varsa konumsuz ortam sesleri (yağmur/rüzgar/fırtına/orman)
## de boğulur (bkz. audio_buses.gd AMBIENT - 2026-09-25 "kalkanın içindeyken sesler boğuklaşmıyor" düzeltmesi).
static var _domes_with_player_inside: Dictionary = {}


func _create_muffle_area() -> void:
	_domes_with_player_inside[get_instance_id()] = true
	AudioBuses.set_ambient_muffled(true)
	var area := Area2D.new()
	area.name = "BarrierMuffleArea"
	area.top_level = true
	area.monitoring = false
	area.monitorable = false
	area.collision_layer = 1 ## AudioStreamPlayer2D.area_mask varsayılanı
	area.collision_mask = 0
	area.audio_bus_override = true
	area.audio_bus_name = AudioBuses.muffle_bus()
	## Halka: baloncuk yarıçapından dışarı, MUFFLE_SEGMENTS dışbükey dörtgen (CollisionPolygon2D delikli şekil almaz).
	var inner: float = radius
	for i in range(MUFFLE_SEGMENTS):
		var a0: float = TAU * float(i) / MUFFLE_SEGMENTS
		var a1: float = TAU * float(i + 1) / MUFFLE_SEGMENTS
		var poly := CollisionPolygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2.from_angle(a0) * inner, Vector2.from_angle(a0) * MUFFLE_OUTER_RADIUS,
			Vector2.from_angle(a1) * MUFFLE_OUTER_RADIUS, Vector2.from_angle(a1) * inner,
		])
		area.add_child(poly)
	add_child(area)
	area.global_position = global_position
	_muffle_area = area


func _remove_muffle_area() -> void:
	if _muffle_area != null and is_instance_valid(_muffle_area):
		_muffle_area.queue_free()
	_muffle_area = null
	if _domes_with_player_inside.erase(get_instance_id()) and _domes_with_player_inside.is_empty():
		AudioBuses.set_ambient_muffled(false)
