extends Node2D

## Şimşek Asası'nın kesintisiz ışını (namludan hedefe).
##
## YENİDEN TASARIM (kullanıcı isteği 2026-09-25: "yıldırım asasının yıldırım efektini v.s yeniden tasarlamanı istiyorum
## pixel tarzda sonrasında spritesheete dönüştür ki performans düşmesin"): eskiden her karede antialias'lı çizgi
## zikzakları + script'te tek tek hesaplanan kıvılcım parçacıkları çiziliyordu. Artık:
##  - ışın gövdesi: lightning_strip.gd (piksel şimşek karoları, FLICKER_INTERVAL'da bir yeniden karıştırılır),
##  - hedefte: "impact" sprite döngüsü (cızırdayan kıvılcım çekirdeği),
##  - namluda: "orb" sprite döngüsü (asanın ucunda titreyen elektrik topu).
## Hepsi tools/gen_lightning_staff_fx.py sayfaları, 1 sanat pikseli = 1 dünya birimi.
##
## top_level: hem yerelde (current_scene çocuğu) hem uzak oyuncuda (RemotePlayer çocuğu - ölçekli kök) AYNI dünya
## koordinatında, aynı boyda çizilir (eskiden uzak kopyanın boyu ebeveyn ölçeğine bağlıydı).

const LightningStrip := preload("res://scripts/lightning_strip.gd")
const ImpactFrames := preload("res://assets/fx/lightning_staff/impact_frames.tres")
const OrbFrames := preload("res://assets/fx/lightning_staff/orb_frames.tres")
const FLICKER_INTERVAL := 0.05

@onready var sfx: AudioStreamPlayer2D = get_node_or_null("Sfx")

var _origin: Node2D = null
var _target: Node2D = null

## Ağ (remote) modu: uzak oyuncularda gerçek bir Enemy node referansı yok, broadcast_player_vfx ile sadece hedefin ve
## namlunun konumu gelir (bkz. remote_player.gd _start_beam_vfx/_update_beam_vfx, network_manager.gd "beam_start"/
## "beam_update").
var _use_network_target: bool = false
var _network_target_pos: Vector2 = Vector2.ZERO
var _network_origin_pos: Vector2 = Vector2.ZERO

var _from_local: Vector2 = Vector2.ZERO
var _tiles := PackedInt32Array()
var _flicker_timer: float = 0.0
var _impact: AnimatedSprite2D = null
var _orb: AnimatedSprite2D = null


func _ready() -> void:
	top_level = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	## Eski sahnedeki kullanılmayan sprite düğümleri (varsa) gizli kalsın.
	for old_name in ["Bolt", "Spark"]:
		var old: CanvasItem = get_node_or_null(old_name) as CanvasItem
		if old:
			old.visible = false
	_impact = _make_sprite(ImpactFrames)
	_orb = _make_sprite(OrbFrames)
	if sfx:
		sfx.finished.connect(sfx.play)
		sfx.play()


func _make_sprite(frames: SpriteFrames) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)
	s.play("loop")
	s.frame = randi() % frames.get_frame_count("loop")
	return s


func setup(origin: Node2D, target: Node2D) -> void:
	_origin = origin
	_target = target
	_use_network_target = false


## Uzak oyuncularda çağrılır. Orijin olarak silahın gerçek namlu konumu, hedef olarak da ağdan gelen hedef konumu
## kullanılır; eksik eski paketlerde RemotePlayer konumu güvenli geri dönüş olarak korunur.
func setup_network(target_pos: Vector2, extra_data: Dictionary) -> void:
	_origin = null
	_target = null
	_use_network_target = true
	_network_target_pos = target_pos
	var fallback_origin: Vector2 = get_parent().global_position if get_parent() is Node2D else target_pos
	_network_origin_pos = Vector2(extra_data.get("from_pos", fallback_origin))


## Uzak oyuncularda hedef ve silah namlusu pozisyonunu tazeler.
func update_target(target_pos: Vector2, origin_pos: Vector2 = Vector2.ZERO) -> void:
	_network_target_pos = target_pos
	if origin_pos != Vector2.ZERO:
		_network_origin_pos = origin_pos


func _process(delta: float) -> void:
	var from: Vector2 = global_position
	if _use_network_target:
		from = _network_origin_pos
	elif _origin and is_instance_valid(_origin):
		from = _origin.global_position
	var to: Vector2 = global_position
	if _use_network_target:
		to = _network_target_pos
	elif _target and is_instance_valid(_target):
		to = _target.global_position
	## Kök hedefte (isabet ucu) durur; ışın yerel olarak namludan köke çizilir.
	global_position = to
	_from_local = from - to
	_orb.position = _from_local
	_flicker_timer -= delta
	if _flicker_timer <= 0.0 or _tiles.size() < LightningStrip.tile_count(from, to):
		_flicker_timer = FLICKER_INTERVAL
		_tiles = LightningStrip.reroll(LightningStrip.tile_count(from, to))
	## Dinamik elektrik cızırtısı (sesin kendisi aynı) - hafif perde/ses dalgalanması.
	if sfx and sfx.playing:
		sfx.pitch_scale = lerp(sfx.pitch_scale, randf_range(0.94, 1.08), 0.4)
		sfx.volume_db = lerp(sfx.volume_db, -7.5 + randf_range(-1.5, 1.5), 0.4)
	queue_redraw()


func _draw() -> void:
	LightningStrip.draw(self, _from_local, Vector2.ZERO, _tiles)


## Gece ışığı (bkz. night_glow.gd / night_glow_catalog.gd): ışık tek noktada değil, namludan hedefe ışın boyunca.
func get_glow_segment() -> Array:
	return [to_global(_from_local), global_position]
