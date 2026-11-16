extends Node2D

## Ruhani Yetenek "Can" (F): takım arkadaşlarının HEPSİNİN üzerinde çıkar (player.gd apply_spirit_can_buff + network_manager.gd
## _rpc_spirit_team_buff, uzak kuklalara aynı sahne). Görünüm = prototip "A Ruh Işığı" (madde 730, kullanıcı seçimi 2026-11-16,
## madde 734) - eski altın kubbe + dönen kesikli halkalar + "+" serpintisi silindi.
##  - 0-0,75 sn: gökten inen ışık sütunu (3 düz bant: dış yeşil-altın, altın, krem çekirdek; üstü 3 basamakta söner),
##    karakterin ARKASINDA; önünde yalnız soluk bir parıltı (gövde ışıkta yıkanır)
##  - 0,18 sn'de yere iner: altın ışık havuzu + iki genişleyen yer halkası
##  - 3 sn (dokunulmazlık): gövdeyi saran altın kabuk (kenara doğru koyulaşan bantlar, üst kenar krem), nefes alır
##  - yükselen birkaç 4 uçlu pırıltı (krem çekirdek, yeşil/altın kol)
## Kök ayak noktasında, 1 yerel birim = 1 dünya birimi (bkz. spirit_fx_util.gd). Ömür sabit (CAN_INVULN_TIME + sönüş).

const U := preload("res://scripts/spirit_fx_util.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")
const SHELL_TEX := preload("res://assets/fx/ruhani/can_shell.png") ## 6 kare: açılış 0,25/0,5/0,75/1 + nefes -/+
const GLOW_TEX := preload("res://assets/fx/ruhani/can_glow.png") ## en parlak bant 0,6 alfa pişti
const RING_TEX := preload("res://assets/fx/ruhani/ring_ground.png") ## 23 kare rx 4..26

const SHAFT_TOP := -110.0
const SHELL_Y := -16.0
const FADE := 0.4

var _t: float = 0.0
var _inv: float = SpiritualSkillsScript.CAN_INVULN_TIME
var _seed: int = 0
var _shell: Sprite2D = null
var _front: Node2D = null


func _ready() -> void:
	U.setup_root(self)
	show_behind_parent = true ## ışık sütunu + yer ışığı karakterin arkasında
	_seed = randi() % 10000
	_shell = Sprite2D.new()
	_shell.texture = SHELL_TEX
	_shell.hframes = 6
	_shell.position = Vector2(0.0, SHELL_Y)
	_shell.z_index = 2
	_shell.visible = false
	add_child(_shell)
	_front = U.front_layer(self, _draw_front)


func _process(delta: float) -> void:
	_t += delta
	if _t >= _inv + FADE:
		queue_free()
		return
	var tt: float = _t
	if tt >= 0.25:
		var s: float = U.ease_out((tt - 0.25) / 0.2)
		var fade: float = clampf((_inv + FADE - tt) / FADE, 0.0, 1.0)
		_shell.visible = true
		if s < 0.999:
			_shell.frame = clampi(int(roundf(s * 4.0)) - 1, 0, 3)
		else:
			var br: float = 0.6 * sin(TAU * 0.8 * tt)
			_shell.frame = 4 if br < -0.3 else (5 if br > 0.3 else 3)
		_shell.modulate.a = U.band(fade, 4)
	queue_redraw()
	_front.queue_redraw()


func _shaft_geom() -> Vector2:
	## (alt kenar y, genişlik çarpanı); sütun yoksa genişlik 0
	var tt: float = _t
	if tt >= 0.75:
		return Vector2(-1.0, 0.0)
	if tt < 0.18:
		return Vector2(lerpf(SHAFT_TOP, -1.0, U.ease_in(tt / 0.18)), 1.0)
	return Vector2(-1.0, 1.0 if tt < 0.42 else 1.0 - U.ease_io((tt - 0.42) / 0.33))


func _shaft(ci: CanvasItem, hw: float, col: Color, al: float, bot: float) -> void:
	var w: float = roundf(hw)
	if w < 1.0 or al <= 0.0:
		return
	var segs: Array = [[SHAFT_TOP, SHAFT_TOP + 22.0, 0.34], [SHAFT_TOP + 22.0, SHAFT_TOP + 44.0, 0.67], [SHAFT_TOP + 44.0, bot, 1.0]]
	for sg in segs:
		var ya: float = float(sg[0])
		var yb: float = minf(float(sg[1]), bot)
		if yb - ya >= 1.0:
			ci.draw_rect(Rect2(-w, roundf(ya), 2.0 * w, roundf(yb) - roundf(ya)), U.with_a(col, al * float(sg[2])))
	U.ellipse(ci, 0.0, bot, hw, maxf(1.0, hw * 0.45), U.with_a(col, al))


func _draw() -> void:
	var tt: float = _t
	var g: Vector2 = _shaft_geom()
	if g.y > 0.0:
		_shaft(self, 9.0 * g.y, U.HEAL3, 0.20, g.x)
		_shaft(self, 5.5 * g.y, U.GOLD3, 0.40, g.x)
		_shaft(self, 2.5 * g.y, U.CREAM, 0.80, g.x)
	if tt >= 0.18 and tt < 0.9:
		var k: float = (tt - 0.18) / 0.72
		U.frame(self, GLOW_TEX, 1, 0, 0.0, 0.0, U.with_a(Color.WHITE, U.band(0.6 * (1.0 - k), 4) / 0.6))
		for j in range(2):
			var kk: float = (tt - 0.18 - 0.12 * j) / 0.5
			if kk >= 0.0 and kk < 1.0:
				var rx: float = 5.0 + 21.0 * U.ease_out(kk)
				U.frame(self, RING_TEX, 23, int(roundf(rx)) - 4, 0.0, 0.0, U.with_a(U.HEAL3 if j == 1 else U.GOLD3, U.band(0.9 * (1.0 - kk), 4)))


func _draw_front() -> void:
	var tt: float = _t
	var g: Vector2 = _shaft_geom()
	if g.y > 0.0:
		_shaft(_front, 9.0 * g.y, U.GOLD4, 0.12, g.x)
		if tt > 0.16 and tt < 0.40:
			_shaft(_front, 2.5 * g.y, U.CREAM, 0.30, g.x)
	if tt > _inv + 0.1:
		return
	for j in range(3):
		var ph: float = (tt - 0.35 + float(j) * 0.42) / 1.25
		if ph < 0.0:
			continue
		var cyc: int = int(ph)
		var q: float = ph - float(cyc)
		var mx: float = (U.hash01(_seed + j * 5 + cyc * 17) - 0.5) * 20.0
		var my: float = -8.0 - q * 28.0
		var k: int = int(roundf(2.0 * sin(PI * q)))
		U.sparkle(_front, mx, my, k, U.CREAM, U.HEAL3 if (j + cyc) % 2 == 1 else U.GOLD3, 0.9)
