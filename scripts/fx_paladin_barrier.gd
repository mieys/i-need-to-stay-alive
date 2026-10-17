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
## yerel oyuncu bu baloncuğun içindeyken baloncuğun DIŞINDA çalan her AudioStreamPlayer2D alçak geçiren + yankılı MUFFLE_BUS'a
## yönlenir, içindeki sesler (Şovalye'nin/dostların kendi sesleri) normal kalır - dome_sound_muffle.gd + dome_sound_router.gd
## (2026-10-17: eski Area2D audio_bus_override yöntemi Godot 4.7.2'de hiç çalışmıyormuş, madde 218). UI sesleri etkilenmez.

var radius: float = 126.0 ## player.gd _skill_paladin_ulti() PALADIN_ULTI_ZONE_RADIUS ile üzerine yazar - bu sadece varsayılan
var color: Color = Color(0.35, 0.78, 1.0, 0.95) ## gece ışığı rengi (bkz. night_glow_catalog.gd "cp": "color")
var active: bool = true
## Seyyar satıcının güvenli bölgesi de bu script'i kullanır (traveling_merchant.gd) - add_child'dan ÖNCE atanır:
## "gold" = altın ticaret kubbesi (tools/gen_paladin_dome_fx.py *_gold sayfaları), boğuk ses KAPALI.
var variant: String = ""
var muffle_outside_sound: bool = true

## Satıcının altın kubbesi (daire, eski düz görünüm). Şovalye'nin mavi düz daire sayfaları (loop/flash_sheet.png) 2026-10-14'ten beri
## kullanılmıyor - izometrik kubbeye geçildi (aşağıda), dosyalar geri dönüş için duruyor.
const LoopFramesGold := preload("res://assets/fx/paladin_dome/loop_gold_frames.tres")
const FlashFramesGold := preload("res://assets/fx/paladin_dome/flash_gold_frames.tres")
## İZOMETRİK KUBBE (kullanıcı seçimi 2026-10-14, prototip "C - Işık Perdesi", madde 160): tools/gen_paladin_iso_dome_fx.py.
## Koruma alanı artık elips (scripts/paladin_dome.gd); görsel o elipsin üstünde duran yarım küre, ÜÇ katman:
##  zemin ayak izi + ARKA kabuk -> mutlak z 0 (zeminin üstü, karakterlerin [z 1] ALTI), ÖN kabuk + isabet parlaması -> z 20 (karakterlerin üstü).
const IsoFloorTex := preload("res://assets/fx/paladin_dome/iso_floor.png")
const IsoBackFrames := preload("res://assets/fx/paladin_dome/iso_back_frames.tres")
const IsoFrontFrames := preload("res://assets/fx/paladin_dome/iso_front_frames.tres")
const IsoFlashFrames := preload("res://assets/fx/paladin_dome/iso_flash_frames.tres")
const PaladinDome := preload("res://scripts/paladin_dome.gd")
## İzometrik sayfalarda merkezin (Şovalye'nin ayak noktası) kare içindeki yeri (üretici OX/OY, zemin OX/FLOOR_HALF).
const ISO_ORIGIN := Vector2(128, 128)
const ISO_FLOOR_ORIGIN := Vector2(128, 68)
## Isabet çatlağı kubbenin kenarında yerden bu kadar yukarıda (dünya px) - kabuğun yüzeyine denk gelsin.
const ISO_CRACK_LIFT := 10.0
## Sayfalardaki kubbe yarıçapı (sanat pikseli = dünya birimi) - radius farklıysa sprite orantılı ölçeklenir. İzometrik sayfalar da
## yarıçap (elipsin yatay yarıçapı) 126 için üretildi.
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

## Boğuk ses artık ortak bileşende (dome_sound_muffle.gd - satıcı baloncuğu da kullanır).
const DomeSoundMuffleScript := preload("res://scripts/dome_sound_muffle.gd")

var _hit_fx_count: int = 0
var _hit_fx_cooldown: float = 0.0
var _loop: AnimatedSprite2D = null
var _flash: AnimatedSprite2D = null
## Açılışta büyüyen düğüm: altın kubbede _loop, izometrik kubbede tüm katmanları taşıyan _iso.
var _grow: Node2D = null
var _iso: Node2D = null
var _t: float = 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = PaladinDome.SHELL_Z ## zeminin (0) kesinlikle üstünde, kalıcı/güvenilir görünürlük; kubbenin önündekiler creature_depth.gd ile üstüne çıkar
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	## Karakterin kendi ölçeğinden bağımsız global boyut: 1 yerel birim = 1 dünya birimi = 1 sanat pikseli.
	var p := get_parent()
	if p is Node2D:
		var ps: Vector2 = (p as Node2D).scale
		if ps.x != 0.0 and ps.y != 0.0:
			scale = Vector2(1.0 / ps.x, 1.0 / ps.y)
	var art_scale: float = radius / ART_RADIUS
	if variant == "gold":
		_loop = _make_sprite(LoopFramesGold, art_scale)
		_loop.play("loop")
		_loop.frame = randi() % LoopFramesGold.get_frame_count("loop")
		_flash = _make_sprite(FlashFramesGold, art_scale)
		_grow = _loop
	else:
		_build_iso()
	_flash.visible = false
	_flash.animation_finished.connect(func() -> void: _flash.visible = false)
	if muffle_outside_sound:
		var muffle := Node2D.new()
		muffle.set_script(DomeSoundMuffleScript)
		muffle.set("radius", radius)
		muffle.set("elliptic", variant != "gold")
		add_child(muffle)
	## Açılış: küçükten büyüyerek belirir.
	modulate.a = 0.0
	_grow.scale = Vector2.ONE * art_scale * 0.7


func _build_iso() -> void:
	_iso = Node2D.new()
	_iso.name = "IsoDome"
	add_child(_iso)
	_grow = _iso
	var floor_spr := Sprite2D.new()
	floor_spr.texture = IsoFloorTex
	floor_spr.centered = false
	floor_spr.offset = -ISO_FLOOR_ORIGIN
	floor_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_spr.z_as_relative = false
	floor_spr.z_index = 0
	_iso.add_child(floor_spr)
	var back := _make_iso_layer(IsoBackFrames, true)
	_loop = _make_iso_layer(IsoFrontFrames, false)
	var start: int = randi() % IsoFrontFrames.get_frame_count("loop")
	for s: AnimatedSprite2D in [back, _loop]:
		s.play("loop")
		s.frame = start
	_flash = _make_iso_layer(IsoFlashFrames, false)


func _make_iso_layer(frames: SpriteFrames, behind_characters: bool) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.offset = -ISO_ORIGIN
	if behind_characters:
		s.z_as_relative = false
		s.z_index = 0
	_iso.add_child(s)
	return s


func _make_sprite(frames: SpriteFrames, art_scale: float) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = true
	s.scale = Vector2.ONE * art_scale
	add_child(s)
	return s


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
	if _iso != null:
		## İzometrik kubbe: çatlak, saldırı yönündeki ELİPS kenarında, kabuğun yüzeyi olsun diye biraz yukarıda.
		fx.call("setup", angle, PaladinDome.radius_along(radius, Vector2.from_angle(angle)), false, PALADIN_CRACK_SCALE)
		fx.position = Vector2(0.0, -ISO_CRACK_LIFT)
	else:
		fx.call("setup", angle, radius, false, PALADIN_CRACK_SCALE)


func _process(delta: float) -> void:
	if not active:
		queue_free()
		return
	if _t < APPEAR_TIME:
		_t += delta
		var k: float = clampf(_t / APPEAR_TIME, 0.0, 1.0)
		modulate.a = k
		_grow.scale = Vector2.ONE * (radius / ART_RADIUS) * lerpf(0.7, 1.0, 1.0 - (1.0 - k) * (1.0 - k))
	if _hit_fx_cooldown > 0.0:
		_hit_fx_cooldown = max(0.0, _hit_fx_cooldown - delta)
