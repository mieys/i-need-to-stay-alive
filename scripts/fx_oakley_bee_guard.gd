extends Node2D
class_name OakleyBeeGuard

## Oakley Q - Arı Sürüsü (skill id 33).
##
## Kullanıcı istekleri (2026-09-25): "oakleyin arı yeteneğini siliyoruz artık oakley arı yeteneğini açtığında kendisini
## takip eden minik arılar olsun ve kendisine yaklaşan düşmanları zehirleyip onları geriye itsin" + ardından "arılar
## düşmanlara saldırmamalı geniş bir şekilde karakterin etrafını sarmalı yaklaşanlar alandan etkilenip öyle hasar almalı".
## Eski sabit bal peteği alanı silindi; ilk sürümdeki "arı yaratığa dalıp sokar" davranışı da kaldırıldı.
##
## NASIL: bu düğüm Oakley'nin (ya da diğer ekranlarda kuklasının) ÇOCUĞU - sürü onunla birlikte yürür. BEE_COUNT minik arı
## karakterin etrafında GENİŞ, katmanlı bir halka halinde döner (her arının kendi yarıçapı/hızı). Halkanın alanına
## (ayak hizasından GUARD_RADIUS) giren yaratık alandan etkilenir: bir arı zehri yükü (enemy.gd apply_bee_poison - eski alanla
## AYNI yük/hasar kuralı) + dışarı doğru geri itme (apply_knockback_distance) + üstünde küçük sokma efekti. Aynı yaratık en
## fazla STING_INTERVAL'de bir etkilenir.
##
## SENKRON (CLAUDE.md): player.gd _play_and_broadcast_skill_fx bu sahneyi kasterde VE diğer oyunculardaki kuklasında kurar
## (yörünge formülü aynı, zamanla belirlenir). Etki (zehir/itme) SADECE kasterin kendi kopyasında (yerel oyuncu = "player"
## grubu) hesaplanır; her etkide "oakley_bee_sting" yayını gider, uzak kopya remote_sting() ile aynı noktada sokma efektini
## oynatır (hasar vermez). Zehir/itme enemy.gd'de zaten host'a yönlenir.
##
## Görseller tools/gen_oakley_fx.py: bee_tiny (minik arı), bee_sting (etki anı), bee_swarm_burst (açılış).

const TEXEL := 1.212
const BEE_FRAMES := preload("res://assets/fx/oakley/bee_tiny_frames.tres")
const STING_FRAMES := preload("res://assets/fx/oakley/bee_sting_frames.tres")
const BURST_FRAMES := preload("res://assets/fx/oakley/bee_swarm_burst_frames.tres")
const BUZZ_PATH := "res://assets/audio/oakley/oakley_bees.wav"
const BUZZ_GAP := 0.8
const VisionFogScript: GDScript = preload("res://scripts/vision_fog.gd")

## SKILL_TIMING[33] "duration" ile aynı (player.gd) - açıklama metni characters.gd DEFS[2] "skill_desc".
const DURATION := 10.0
const BEE_COUNT := 14
## Ayak hizasından ölçülen etki yarıçapı (dünya birimi) - arı halkasının dış kenarı da buraya yakın döner.
const GUARD_RADIUS := 130.0
const STING_INTERVAL := 1.0
const KNOCKBACK_DISTANCE := 70.0
## Etki başına bir zehir yükü: saldırı gücünün %20'si, 4 sn'ye yayılı (enemy.gd apply_bee_poison / BEE_POISON_*).
const DAMAGE_RATIO_PER_STACK := 0.20
const LEAVE_TIME := 0.5
const FEET := Vector2(0.0, 30.0)
## Halka: ayak hizasının biraz üstünde (arılar havada), zemin düzleminde yassı elips; arılar iç/dış katmanlara dağılır.
const ORBIT_CENTER := Vector2(0.0, 12.0)
const ORBIT_RX_MIN := 58.0
const ORBIT_RX_MAX := 118.0
const ORBIT_FLATTEN := 0.5
## bee_swarm_burst karesi 64x56, gövde ortası (32,30) - kare merkezi (32,28); gövde ortası kökün ~8 birim üstü.
const BURST_OFFSET := Vector2(0.0, -8.0 - 2.0 * TEXEL)

var _host: Node2D = null
var _authority: bool = false
var _damage_bonus: float = 0.0
var _t: float = 0.0
var _leave_t: float = -1.0
var _bees: Array = [] ## Dictionary: node, phase, speed, radius, wob
var _recent: Dictionary = {} ## yaratık instance_id -> kalan bekleme
var _sfx: AudioStreamPlayer2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_host = get_parent() as Node2D
	_authority = _host != null and _host.is_in_group("player")
	if _authority and "damage_bonus" in _host:
		_damage_bonus = float(_host.get("damage_bonus"))
	var burst := AnimatedSprite2D.new()
	burst.sprite_frames = BURST_FRAMES
	burst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	burst.scale = Vector2.ONE * TEXEL
	burst.position = BURST_OFFSET
	burst.z_index = 3
	add_child(burst)
	burst.animation_finished.connect(burst.queue_free)
	burst.play(&"burst")
	for i in range(BEE_COUNT):
		var node := AnimatedSprite2D.new()
		node.sprite_frames = BEE_FRAMES
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		node.scale = Vector2.ONE * TEXEL
		node.z_index = 3 ## karakterin/yaratıkların üstünden uçar
		add_child(node)
		node.play(&"fly")
		node.frame = i % 4
		## Deterministik dağılım (kaster ve uzak kopya aynı): katmanlı yarıçaplar, yarısı ters yönde, farklı hızlar.
		var layer: float = float(i % 4) / 3.0
		_bees.append({
			"node": node,
			"phase": TAU * float(i) / float(BEE_COUNT),
			"speed": (0.9 + 0.35 * float((i * 7) % 5) / 4.0) * (1.0 if i % 2 == 0 else -1.0),
			"radius": lerpf(ORBIT_RX_MIN, ORBIT_RX_MAX, layer),
			"wob": 0.6 + 0.15 * float(i % 4),
		})
		node.position = ORBIT_CENTER
	var stream: AudioStream = load(BUZZ_PATH) as AudioStream
	if stream != null:
		_sfx = AudioStreamPlayer2D.new()
		_sfx.stream = stream
		_sfx.volume_db = -11.0
		_sfx.max_distance = 900.0
		add_child(_sfx)
		## Vızıltılar arasında kısa sessizlik - 10 sn boyunca kesintisiz uğultu yorar.
		_sfx.finished.connect(func() -> void:
			get_tree().create_timer(BUZZ_GAP).timeout.connect(func() -> void:
				if is_instance_valid(self) and _leave_t < 0.0 and is_instance_valid(_sfx):
					_sfx.play()))
		_sfx.play()


## Yörüngedeki (yerel) konum - kaster ve uzak kopya AYNI formülü, AYNI zamanla (_t) kullanır.
func _orbit_pos(b: Dictionary) -> Vector2:
	var a: float = float(b["phase"]) + float(b["speed"]) * _t
	var r: float = float(b["radius"]) * (1.0 + 0.08 * sin(_t * 2.3 + float(b["phase"]) * 2.0))
	var bob: float = sin(_t * 9.0 + float(b["phase"]) * 3.0) * float(b["wob"]) * 2.0
	## Açılışta gövdeden dışarı doğru açılır.
	var open: float = clampf(_t / 0.55, 0.0, 1.0)
	open = 1.0 - pow(1.0 - open, 3.0)
	return ORBIT_CENTER + Vector2(cos(a) * r, sin(a) * r * ORBIT_FLATTEN + bob) * open


func _process(delta: float) -> void:
	_t += delta
	var host_down: bool = _host == null or not is_instance_valid(_host) or _host.get("is_dead") == true
	if _leave_t < 0.0 and (_t >= DURATION or host_down):
		_leave_t = 0.0
		if _sfx != null:
			_sfx.stop()
	if _leave_t >= 0.0:
		_process_leave(delta)
		return
	if _authority:
		_authority_area(delta)
	for b in _bees:
		var node: AnimatedSprite2D = b["node"]
		var prev: Vector2 = node.position
		node.position = _orbit_pos(b)
		var dx: float = node.position.x - prev.x
		if absf(dx) > 0.05:
			node.flip_h = dx < 0.0


## Alana giren yaratıklar: zehir yükü + dışarı itme + sokma efekti (sadece kasterin kopyasında).
func _authority_area(delta: float) -> void:
	for id in _recent.keys():
		_recent[id] = float(_recent[id]) - delta
		if float(_recent[id]) <= 0.0:
			_recent.erase(id)
	var feet: Vector2 = global_position + FEET
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true or not (e is Node2D):
			continue
		var id: int = e.get_instance_id()
		if _recent.has(id):
			continue
		var epos: Vector2 = (e as Node2D).global_position
		if epos.distance_to(feet) > GUARD_RADIUS:
			continue
		if not VisionFogScript.can_target(e):
			continue
		_recent[id] = STING_INTERVAL
		if e.has_method("apply_bee_poison"):
			e.call("apply_bee_poison", (_damage_bonus * DAMAGE_RATIO_PER_STACK) / 4.0)
		if e.has_method("apply_knockback_distance"):
			var away: Vector2 = epos - feet
			e.call("apply_knockback_distance", away if away.length() > 0.01 else Vector2.RIGHT, KNOCKBACK_DISTANCE)
		_spawn_sting_fx(epos)
		if NetworkManager.is_multiplayer_active:
			NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "oakley_bee_sting", epos, {})


## Uzak kopya: kasterin sürüsü bu noktadaki yaratığı etkiledi - aynı noktada sokma efekti (sadece görsel).
func remote_sting(world_pos: Vector2) -> void:
	if _leave_t >= 0.0:
		return
	_spawn_sting_fx(world_pos)


func _spawn_sting_fx(world_pos: Vector2) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = STING_FRAMES
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.scale = Vector2.ONE * TEXEL
	fx.z_index = 4
	tree.current_scene.add_child(fx)
	fx.global_position = world_pos + Vector2(0.0, -8.0)
	fx.animation_finished.connect(fx.queue_free)
	fx.play(&"sting")


## Süre bitti / Oakley öldü: arılar dışa doğru dağılıp yukarı süzülerek söner, sonra düğüm silinir.
func _process_leave(delta: float) -> void:
	_leave_t += delta
	var k: float = clampf(_leave_t / LEAVE_TIME, 0.0, 1.0)
	for b in _bees:
		var node: Node2D = b["node"]
		var dir: Vector2 = (node.position - ORBIT_CENTER)
		dir = dir.normalized() if dir.length() > 0.5 else Vector2.RIGHT.rotated(float(b["phase"]))
		node.position += (dir * 90.0 + Vector2(0.0, -40.0)) * delta
	modulate.a = 1.0 - k
	if k >= 1.0:
		queue_free()
