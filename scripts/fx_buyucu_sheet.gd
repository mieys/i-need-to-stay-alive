extends Node2D
## Büyücü Kız tek sayfalık efekt sahneleri (madde 188, BuyucuFx): char = true ise karakterin çocuğu olarak karakter sprite'ına hizalı
## (fx_buyucu_tornado_cast / fx_buyucu_surge_wave - _play_and_broadcast_skill_fx, uzak kopyada aynı sahne), değilse dünyada duran sayfa
## (fx_buyucu_tornado_hit - "hitscan_impact" ile uzak kopyada aynı sahne). Sayfa bitince düğüm kendini siler.

const BuyucuFxScript := preload("res://scripts/buyucu_fx.gd")

@export var sheet: String = ""
@export var fps: float = 15.0
@export var layer_z: int = 0
@export var char_attached: bool = false


func _ready() -> void:
	var s: Node = null
	if char_attached:
		s = BuyucuFxScript.char_layer(self, get_parent(), sheet, layer_z, fps)
	else:
		var sp: Sprite2D = BuyucuFxScript.Sheet.new()
		sp.centered = true
		sp.z_index = layer_z
		sp.scale = Vector2.ONE * BuyucuFxScript.PX
		add_child(sp)
		s = sp.call("setup", [[sheet, false]], fps)
	if s != null:
		s.tree_exited.connect(queue_free)
