extends CanvasLayer

## YERE DÜŞEN OYUNCU DA ARKADAŞLARINI İZLER (2026-10-19, kullanıcı: "yere düşen dostlar diğer oyuncuları izleyemiyor sadece
## ölünce izleyebiliyorlar"). İzleyici kamerası (main.gd _begin_spectate_mode) sadece KALICI ölüm ekranında açılıyordu; yerde yatan
## oyuncunun (player.gd is_downed) kamerası cesedine kilitli kalıyordu. Burada yerdeyken, hayatta/yerde olan en az bir arkadaş
## varsa alt ortada küçük bir şerit çıkar: "<  Ad  >" (masaüstünde ok tuşları da çalışır; A/D çalışmaz - panikle basılan
## hareket tuşları kamerayı cesetten koparmasın). Sıra: Kendin -> arkadaş 1 -> arkadaş 2 -> ... -> Kendin.
##
## Kamera: oyuncunun kendi Camera2D'si (player.death_camera, Player'ın çocuğu) izleme sürerken top_level yapılıp arkadaşa kaydırılır;
## diriltilince önce cesedine kayarak döner, sonra eski yerine (yerel 0,0) takılır. Kalıcı ölümde dokunulmaz: player.gd
## _detach_death_camera devralır (top_level'ı orada sıfırlanır) ve main.gd'nin ölüm izleyicisi çalışır.
## Ek RPC YOK: arkadaşların konumu zaten "remote_players" kuklalarında, görüş sisi de tüm oyuncuları kaynak sayıyor
## (vision_fog.gd _collect_source_positions) - izlenen arkadaşın çevresi görünür.

const MobileUI := preload("res://scripts/mobile_ui.gd")
const PhysicsInterp := preload("res://scripts/physics_interp.gd")
const HudTheme := preload("res://scripts/hud_theme.gd")

const LAYER := 55 ## HUD'un (1) ve sohbetin (40) üstünde, modal ekranların (90) altında
const FS := 32 ## m5x7 2x/4x - keskin
const FS_HINT := 16
const FOLLOW_SPEED := 900.0 ## main.gd SPECTATE_CAMERA_FOLLOW_SPEED ile aynı
const RETURN_SPEED := 1800.0 ## diriltilince cesede dönüş
const RELEASE_DIST := 3.0
## Yetenek paneli (hud.gd DOCK_H 152 x DOCK_UI_SCALE 0,92 + DOCK_BOTTOM_MARGIN 30 = ~170) üstünde kalsın.
const BOTTOM_OFFSET := 186.0
const PHONE_TOP := 96.0 ## telefonda alt kenar joystick/yetenek sütunlarıyla dolu: şerit üstte

var _target: Node2D = null ## null = kendi cesedi
var _held: bool = false ## oyuncunun kamerası bizde (top_level)
var _bar: PanelContainer = null
var _prev_btn: Button = null
var _next_btn: Button = null
var _name_label: Label = null
var _hint_label: Label = null


func _ready() -> void:
	layer = LAYER
	_build()
	_bar.visible = false


## Döngü: indeks -1 = kendin, 0..ally_count-1 = arkadaşlar. direction +1 / -1.
static func next_index(current: int, ally_count: int, direction: int) -> int:
	if ally_count <= 0:
		return -1
	return wrapi(current + 1 + direction, 0, ally_count + 1) - 1


func _process(delta: float) -> void:
	step(delta)


## Bir kare: durumu oku, şeridi göster/gizle, girdiyi işle, kamerayı sür. Testler doğrudan çağırır.
func step(delta: float) -> void:
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var cam: Camera2D = null
	if p != null:
		var cam_v: Variant = p.get("death_camera")
		if is_instance_valid(cam_v) and cam_v is Camera2D:
			cam = cam_v
	var downed: bool = p != null and p.get("is_downed") == true and not GameManager.is_game_over
	if not downed:
		_target = null
		_bar.visible = false
		if _held:
			## Diriltildi (ölü değil): cesedine kayarak dön. Kalıcı ölüm / oyuncu yok: kamera player.gd'nin (detach) elinde.
			if cam != null and cam.get_parent() == p and p.get("is_dead") != true:
				_glide_back(cam, p, delta)
			else:
				_held = false
		return
	var allies: Array = _living_allies()
	if _target != null and not allies.has(_target):
		## İzlenen arkadaş kalıcı öldü / ayrıldı: sıradakine geç (ölüm ekranı izleyicisiyle aynı davranış), kimse yoksa kendine dön.
		_target = null
		cycle(1, allies)
	_bar.visible = not allies.is_empty()
	if allies.is_empty():
		_target = null
	elif not MobileUI.enabled and p.get("is_chat_typing") != true:
		if Input.is_action_just_pressed("ui_left"):
			cycle(-1, allies)
		elif Input.is_action_just_pressed("ui_right"):
			cycle(1, allies)
	_refresh_label()
	if cam == null or cam.get_parent() != p:
		return
	if _target != null:
		if not _held:
			_take(cam)
		cam.global_position = cam.global_position.move_toward(PhysicsInterp.visual_position(_target), FOLLOW_SPEED * delta)
	elif _held:
		_glide_back(cam, p, delta)


## Sıradaki / önceki hedefe geç (butonlar ve ok tuşları). allies verilmezse canlı liste okunur.
func cycle(direction: int, allies: Array = []) -> void:
	if allies.is_empty():
		allies = _living_allies()
	var current: int = allies.find(_target) if _target != null else -1
	var idx: int = next_index(current, allies.size(), direction)
	_target = allies[idx] as Node2D if idx >= 0 else null
	_refresh_label()


## Hayatta VEYA yerde yatan (kalıcı ölmemiş) arkadaşlar: kukla yere düşünce is_dead false gelir (main.gd state_snapshot "dead").
func _living_allies() -> Array:
	var result: Array = []
	for rp: Node in get_tree().get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and rp is Node2D and rp.get("is_dead") != true:
			result.append(rp)
	return result


func is_following() -> bool:
	return _target != null


func _take(cam: Camera2D) -> void:
	var gp: Vector2 = cam.global_position
	cam.top_level = true
	## Oyuncunun kamerası fizik interpolasyonunda (physics_interp.gd); _process'te sürülen top_level kamera titrerdi.
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cam.global_position = gp
	_held = true


func _glide_back(cam: Camera2D, p: Node2D, delta: float) -> void:
	cam.global_position = cam.global_position.move_toward(p.global_position, RETURN_SPEED * delta)
	if cam.global_position.distance_to(p.global_position) <= RELEASE_DIST:
		_release(cam)


func _release(cam: Camera2D) -> void:
	cam.top_level = false
	cam.position = Vector2.ZERO
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	cam.reset_physics_interpolation()
	cam.reset_smoothing()
	_held = false


func _refresh_label() -> void:
	if _name_label == null:
		return
	if _target == null:
		_name_label.text = "Kendin"
	else:
		var nm: String = str(_target.get("player_name")) if "player_name" in _target else ""
		_name_label.text = nm if nm != "" else "Arkadaş"


func _build() -> void:
	var phone: bool = MobileUI.enabled
	var root := Control.new()
	root.theme = UIKit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_bar = PanelContainer.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP ## şeride tıklamak oyuna gitmesin
	_bar.add_theme_stylebox_override("panel", UIKit.panel_style("hud_plaque"))
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	if phone:
		_bar.anchor_top = 0.0
		_bar.anchor_bottom = 0.0
		_bar.offset_top = PHONE_TOP
		_bar.grow_vertical = Control.GROW_DIRECTION_END
	else:
		_bar.anchor_top = 1.0
		_bar.anchor_bottom = 1.0
		_bar.offset_bottom = -BOTTOM_OFFSET
		_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar.add_child(row)

	var btn_size := Vector2(72, 72) if phone else Vector2(56, 56)
	_prev_btn = _button("<", btn_size)
	_prev_btn.pressed.connect(func() -> void: cycle(-1))
	row.add_child(_prev_btn)

	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(340, 0)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 0)
	row.add_child(mid)
	_hint_label = Label.new()
	_hint_label.text = "ARKADAŞINI İZLE" if phone else "OK TUŞLARIYLA ARKADAŞINI İZLE"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.style_label(_hint_label, FS_HINT, HudTheme.DIM, 0)
	mid.add_child(_hint_label)
	_name_label = Label.new()
	_name_label.text = "Kendin"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.clip_text = true
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.style_label(_name_label, FS, HudTheme.ACCENT, 0)
	mid.add_child(_name_label)

	_next_btn = _button(">", btn_size)
	_next_btn.pressed.connect(func() -> void: cycle(1))
	row.add_child(_next_btn)
	UISound.connect_all_buttons(self)


func _button(text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIKit.style_button(b, "hud", false, FS)
	return b
