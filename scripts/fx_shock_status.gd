extends Node2D

## Efsun "Şok" durumu göstergesi (bkz. enemy.gd _spawn_shock_status_fx): yaratığın gövdesi etrafında titreyen küçük sarı
## pixel yıldırım çatlakları. Host'ta durum başlayınca kurulur, istemcilerde broadcast_enemy_vfx "shock_start" ile -
## istemcideki enemy.is_shocked() bu düğümün varlığından okunur (Şimşek Dikeni/Çekici'nin "şoklu hedefe +%" bonusu).

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const FLICKER := 0.09

var radius: float = 20.0
var _flicker: float = 0.0
var _seed: int = 0


func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_seed = randi()


func _process(delta: float) -> void:
	_flicker -= delta
	if _flicker <= 0.0:
		_flicker = FLICKER
		_seed = randi()
		queue_redraw()


func _draw() -> void:
	var r: float = clampf(radius, 12.0, 40.0)
	for i in range(3):
		var ang: float = TAU * PixelDraw.hash01(_seed + i * 17)
		var base := Vector2(cos(ang), sin(ang) * 0.8) * r * 0.9 + Vector2(0.0, -r * 0.4)
		var p: Vector2 = base
		for s in range(3):
			var jag := Vector2(PixelDraw.hash01(_seed + i * 31 + s) - 0.5, PixelDraw.hash01(_seed + i * 47 + s) - 0.5) * 9.0
			var q: Vector2 = p + jag
			PixelDraw.line(self, p, q, Color(1.0, 0.92, 0.35, 0.95), 1)
			p = q
		PixelDraw.px(self, p, 1, Color(1.0, 1.0, 0.85, 1.0))
