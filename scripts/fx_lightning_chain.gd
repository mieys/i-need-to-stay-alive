extends Node2D

## Şimşek Asası'nın düşmandan düşmana sıçrayan (chain) elektrik arkı.
##
## YENİDEN TASARIM (kullanıcı isteği 2026-09-25, bkz. fx_lightning_beam.gd): ark artık ışınla AYNI piksel şimşek
## karolarıyla (lightning_strip.gd) çizilir ve ARC_TIME içinde söner; çarptığı yaratıkta "chain_hit" sprite'ı (kısa
## patlama + halka, tek sefer) oynar. Eskiden antialias'lı çizgi + script'te hesaplanan kıvılcım parçacıklarıydı.
## Yerelde yaratıkları takip eder (setup), uzak oyuncularda iki sabit konumla kurulur (setup_positions).

const LightningStrip := preload("res://scripts/lightning_strip.gd")
const HitFrames := preload("res://assets/fx/lightning_staff/chain_hit_frames.tres")
const ARC_TIME := 0.18
const FLICKER_INTERVAL := 0.04
## Düğüm, isabet sprite'ı (6 kare / 20 fps = 0.3 sn) bitene kadar yaşar.
const LIFETIME := 0.32

var _from_node: Node2D = null
var _to_node: Node2D = null
var _from_pos: Vector2 = Vector2.ZERO
var _to_pos: Vector2 = Vector2.ZERO
var _tiles := PackedInt32Array()
var _flicker_timer: float = 0.0
var _elapsed: float = 0.0


func setup(from_node: Node2D, to_node: Node2D) -> void:
	_from_node = from_node
	_to_node = to_node
	_from_pos = from_node.global_position if is_instance_valid(from_node) else global_position
	_to_pos = to_node.global_position if is_instance_valid(to_node) else global_position
	_finish_setup()


## Uzak (remote) oyuncularda çağrılır - bkz. network_manager.gd broadcast_player_vfx "chain_lightning".
func setup_positions(from_pos: Vector2, to_pos: Vector2) -> void:
	_from_node = null
	_to_node = null
	_from_pos = from_pos
	_to_pos = to_pos
	_finish_setup()


func _finish_setup() -> void:
	top_level = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	global_position = _to_pos
	_tiles = LightningStrip.reroll(LightningStrip.tile_count(_from_pos, _to_pos))
	var hit := AnimatedSprite2D.new()
	hit.sprite_frames = HitFrames
	hit.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(hit)
	hit.play("burst")
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()
		return
	## Konumları güncelle (yaratıklar hareket ediyorsa ark da takip etsin).
	if is_instance_valid(_from_node):
		_from_pos = _from_node.global_position
	if is_instance_valid(_to_node):
		_to_pos = _to_node.global_position
		global_position = _to_pos
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		_flicker_timer = FLICKER_INTERVAL
		_tiles = LightningStrip.reroll(LightningStrip.tile_count(_from_pos, _to_pos))
	queue_redraw()


func _draw() -> void:
	if _elapsed >= ARC_TIME:
		return
	var fade: float = 1.0 - _elapsed / ARC_TIME
	LightningStrip.draw(self, _from_pos - _to_pos, Vector2.ZERO, _tiles, Color(1.0, 1.0, 1.0, fade))


## Gece ışığı (bkz. night_glow.gd): sıçrama arkı boyunca, ark sönerken ışık da söner.
func get_glow_segment() -> Array:
	if _elapsed >= ARC_TIME:
		return []
	return [_from_pos, _to_pos]


func get_night_glow_energy() -> float:
	return 1.0 - clampf(_elapsed / ARC_TIME, 0.0, 1.0)
