extends Node

## YARATIK - OYUNCU çizim sırası (y-sıralama) - kullanıcı isteği (2026-10-08): "bir şeyin arkasındayken karakter onun altında, önündeyken üstünde görünsün".
## Oyuncular z_index 1'de, yaratıklar z 0'da: oyuncu bir yaratığın ÖNÜNDEYKEN (ayağı yaratığın ayağından aşağıda) üstte doğru görünüyordu ama
## ARKASINDAYKEN de üstte kalıyordu. Burada oyuncunun gövdesiyle örtüşen ve AYAĞI oyuncunun ayağından aşağıda olan (yani oyuncunun önünde duran)
## yaratıklar geçici olarak z_index 2'ye alınır (oyuncunun üstüne çizilir), önlerinden ayrılınca eski z'ye döner. Yaratıkların kendi aralarındaki
## sıra aynen kalır (main.gd _update_creature_draw_order, C++ draw_order); harita nesneleri için bkz. depth_occluders.gd.
## Karakterler = yerel oyuncu + uzak oyuncu kuklaları (depth_occluders.gd collect_characters). Tamamen yerel/kozmetik, ağ gerekmez.
## Sadece "enemies" (+ görev kopyaları, EnemyQuery.candidates'in döndürdüğü): evcil hayvan/müttefik (player_ally*) oyuncunun altında KALIR (eskisi gibi).
## Ölüm animasyonundaki (is_dead) yaratık yerde yatar - hep oyuncunun altında kalır.
## Titreme koruması: yükselme ayak farkı > +HYSTERESIS, inme < -HYSTERESIS (yan yana yürürken z her karede gidip gelmesin).

const DepthScript := preload("res://scripts/depth_occluders.gd")
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")

const FRONT_Z := 2
## Karaktere bu uzaklıktan (kök noktası, x ve y ayrı ayrı) yakın yaratıklar incelenir; çok büyük gövdeler (boss ~71 px) için geniş tutuldu.
const SCAN_RADIUS := 130.0
const HYSTERESIS := 2.0
const FALLBACK_HEIGHT := 48.0

var _raised: Dictionary = {} ## yaratık düğümü -> yükselmeden önceki z_index


## Saf kural (testler için): bu yaratık oyuncunun ÜSTÜNE çizilmeli mi?
##  foot_y/height: yaratığın ayağının dünya y'si ve görsel boyu; dx: yaratığın x'i - oyuncunun x'i; feet_y: oyuncunun ayağı; raised: şu an yükseltilmiş mi.
static func should_cover(foot_y: float, height: float, dx: float, feet_y: float, raised: bool) -> bool:
	var margin: float = -HYSTERESIS if raised else HYSTERESIS
	if foot_y <= feet_y + margin:
		return false ## ayağı oyuncununkinden yukarıda ya da aynı hizada: yaratık oyuncunun ARKASINDA, altında kalır
	if foot_y - height >= feet_y:
		return false ## görselin tamamı oyuncunun ayağından aşağıda: örtüşme yok, z'ye dokunma
	return absf(dx) <= DepthScript.BODY_HALF_WIDTH + maxf(height * 0.5, 20.0)


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 2 != 0:
		return
	update_now()


func update_now() -> void:
	var want: Dictionary = {}
	var chars: Array[Vector4] = DepthScript.collect_characters(get_tree())
	for c in chars:
		for e in EnemyQueryScript.candidates(get_tree(), Vector2(c.x, c.y), SCAN_RADIUS):
			var n := e as Node2D
			if n == null or not is_instance_valid(n) or not n.visible or n.get("is_dead") == true:
				continue
			if absf(n.global_position.x - c.x) > SCAN_RADIUS or absf(n.global_position.y - c.y) > SCAN_RADIUS:
				continue
			if want.has(n):
				continue
			if should_cover(_foot_y(n), _height(n), n.global_position.x - c.x, c.y, _raised.has(n)):
				want[n] = true
	for n: Node2D in want:
		if not _raised.has(n):
			_raised[n] = n.z_index
			n.z_index = FRONT_Z
	for n in _raised.keys():
		if want.has(n):
			continue
		if is_instance_valid(n):
			(n as Node2D).z_index = int(_raised[n])
		_raised.erase(n)


## Yaratığın ayağının dünya y'si: main.gd'nin ölçtüğü (sprite karesindeki en alt dolu satır) değer; main yoksa kök noktası.
func _foot_y(n: Node2D) -> float:
	var main: Node = get_parent()
	if main != null and main.has_method("_creature_foot_y"):
		return float(main.call("_creature_foot_y", n))
	return n.global_position.y


## Yaratık görselinin ekrandaki boyu (px): Sprite2D / AnimatedSprite2D karesi x ölçek. Bulunamazsa FALLBACK_HEIGHT.
func _height(n: Node2D) -> float:
	var vis: Node2D = null
	for child_name in ["Sprite2D", "AnimatedSprite2D"]:
		var c: Node = n.get_node_or_null(child_name)
		if c is Sprite2D or c is AnimatedSprite2D:
			vis = c as Node2D
			break
	if vis == null:
		return FALLBACK_HEIGHT
	var h: float = 0.0
	if vis is Sprite2D:
		var s := vis as Sprite2D
		if s.texture != null:
			h = s.texture.get_size().y / float(maxi(s.vframes, 1))
	else:
		var a := vis as AnimatedSprite2D
		if a.sprite_frames != null and a.sprite_frames.has_animation(a.animation) and a.sprite_frames.get_frame_count(a.animation) > 0:
			var t: Texture2D = a.sprite_frames.get_frame_texture(a.animation, 0)
			if t != null:
				h = t.get_size().y
	return h * absf(vis.global_scale.y) if h > 0.0 else FALLBACK_HEIGHT


func _exit_tree() -> void:
	for n in _raised.keys():
		if is_instance_valid(n):
			(n as Node2D).z_index = int(_raised[n])
	_raised.clear()
