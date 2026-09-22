extends Node2D

## Matthew'in yeni Q'su (Tilki Hücumu, skill id 43, kullanıcı isteği 2026-09-22: "tilkisini anında dashlı bir
## şekilde yakınına ışınlayıp ... en fazla 6 düşmana dash saldırısı atarak ... onları Matthewdan uzağa iter")
## için PIXEL tarzı vuruş efekti - Matthew'in üzerinde doğar (bkz. player.gd _skill_matthew_fox_strike,
## _play_and_broadcast_skill_fx). Üç turuncu pençe izi + dışa savrulan toz/kıvılcım + kısa parlama; gerçek
## hasar/itme buradan TAMAMEN bağımsız (bkz. CLAUDE.md - kozmetik/mantık ayrımı).

const PixelDraw := preload("res://scripts/pixel_draw.gd")

const LIFE := 0.4
const CLAW := [
	"o.o.o",
	".o.o.",
	"o.o.o",
]

var _t: float = 0.0
var _dust: Array = [] ## [angle, speed, size]

@onready var sound: AudioStreamPlayer2D = get_node_or_null("Sound")


func _ready() -> void:
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sound:
		sound.pitch_scale = randf_range(0.95, 1.1)
		sound.play()
	for i in range(10):
		_dust.append([randf() * TAU, randf_range(60.0, 150.0), randi_range(1, 2)])


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = PixelDraw.TEXEL
	var k: float = clampf(_t / LIFE, 0.0, 1.0)
	var fade: float = 1.0 - k
	## Kısa çarpma parlaması
	if k < 0.2:
		PixelDraw.disc(self, Vector2.ZERO, (1.0 - k / 0.2) * 6.0 * t, Color(1.0, 0.92, 0.7, 1.0 - k / 0.2))
	## Üç turuncu pençe izi (sabit açılarda, hafif fan şeklinde) - sırayla belirip solar
	var claw_col := Color(1.0, 0.6, 0.15)
	for i in range(3):
		var reveal: float = clampf(k * 3.0 - float(i) * 0.5, 0.0, 1.0)
		if reveal <= 0.0:
			continue
		var ang: float = deg_to_rad(-40.0 + float(i) * 40.0)
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var len_px: float = 22.0 * t * reveal
		var steps: int = maxi(2, int(len_px / t))
		for s in range(steps):
			var f: float = float(s) / float(steps)
			var pos: Vector2 = dir * (6.0 * t + f * len_px) + side * sin(f * PI) * 3.0 * t
			PixelDraw.px(self, pos, 2 if f < 0.5 else 1, Color(claw_col, fade * (1.0 - f * 0.3)))
	## Dışa savrulan toz/kıvılcım
	for d in _dust:
		var dist: float = float(d[1]) * _t
		var pos2: Vector2 = Vector2(cos(float(d[0])), sin(float(d[0]))) * dist
		PixelDraw.px(self, pos2, int(d[2]), Color(0.85, 0.7, 0.5, fade))
