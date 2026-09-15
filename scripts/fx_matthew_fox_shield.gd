extends Node2D
class_name MatthewFoxShieldFx

## Tamamen kod ile çizilen tilki kalkanı efekti.
## İçi yarı saydam turuncu dolu daire + parlak turuncu kenarlık + üstte tilki kulakları.

const RADIUS: float = 44.0
const BORDER_WIDTH: float = 3.0
const EAR_SIZE: float = 10.0

# Renkler
const COLOR_FILL: Color     = Color(1.0, 0.55, 0.05, 0.30)   # yarı saydam turuncu iç
const COLOR_FILL2: Color    = Color(1.0, 0.75, 0.15, 0.12)   # merkeze doğru açılan parlaklık
const COLOR_RIM: Color      = Color(1.0, 0.65, 0.10, 0.95)   # parlak turuncu kenarlık
const COLOR_EAR: Color      = Color(1.0, 0.65, 0.10, 0.95)   # kulak dolgusu
const COLOR_EAR_IN: Color   = Color(1.0, 0.90, 0.50, 0.85)   # kulak iç açık ton

var elapsed: float = 0.0
var popping: bool = false
var pop_elapsed: float = 0.0
const POP_DURATION: float = 0.25

func _process(delta: float) -> void:
	if popping:
		pop_elapsed += delta
		if pop_elapsed >= POP_DURATION:
			queue_free()
			return
	else:
		elapsed += delta
	queue_redraw()

func pop() -> void:
	if popping:
		return
	popping = true
	pop_elapsed = 0.0

func _draw() -> void:
	var t: float = elapsed
	var p: float = 0.0
	if popping:
		p = pop_elapsed / POP_DURATION

	var scale_factor: float = 1.0 + p * 0.25
	var alpha_mult: float = 1.0 - p

	# Hafif nefes alma
	var breath: float = sin(t * 2.8) * 0.025
	var r: float = RADIUS * (1.0 + breath) * scale_factor

	# --- Daire iç dolgu (2 katman) ---
	var fill_col: Color = COLOR_FILL
	fill_col.a *= alpha_mult
	draw_circle(Vector2.ZERO, r, fill_col)

	var fill2_col: Color = COLOR_FILL2
	fill2_col.a *= alpha_mult * (0.8 + sin(t * 3.0) * 0.2)
	draw_circle(Vector2.ZERO, r * 0.55, fill2_col)

	# --- Parlak turuncu kenarlık ---
	var rim_col: Color = COLOR_RIM
	rim_col.a *= alpha_mult * (0.85 + sin(t * 3.5) * 0.15)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, rim_col, BORDER_WIDTH + 1.5)
	draw_arc(Vector2.ZERO, r - 1.5, 0.0, TAU, 64, rim_col, BORDER_WIDTH - 0.5)
	var rim_glow: Color = Color(1.0, 0.90, 0.55, 0.45 * alpha_mult)
	draw_arc(Vector2.ZERO, r - 3.0, 0.0, TAU, 64, rim_glow, 2.0)

	# --- Tilki Kulakları ---
	# Kulak taban noktaları daireyle birleşik görünsün diye
	# polar koordinatla dairenin çevresi üzerindeki noktalara oturtuldu.
	# Sol kulak merkezi ~120° (daireyi 0°=sağ, 270°=üst kabul edersek),
	# Sağ kulak simetrik olarak ~60°.
	var ear_col: Color = COLOR_EAR
	ear_col.a *= alpha_mult
	var ear_in_col: Color = COLOR_EAR_IN
	ear_in_col.a *= alpha_mult * 0.85

	var ear_h: float = r * 0.45   # kulak yüksekliği (dairenin dışına çıkış)

	# Sol kulak: daire çevresi üzerinde ~100° ile ~145° arası taban (üst-sol bölge)
	# Godot'ta 0°=sağ, açı saat yönünde artar; üst = -PI/2 = 270° = -90°
	# Sol kulak merkez açısı: -90° - 30° = -120° → sol üst
	var la1: float = deg_to_rad(-145.0)  # sol taban sol nokta
	var la2: float = deg_to_rad(-100.0)  # sol taban sağ nokta
	var l_mid_angle: float = (la1 + la2) * 0.5
	var lp1: Vector2 = Vector2(cos(la1), sin(la1)) * r
	var lp2: Vector2 = Vector2(cos(la2), sin(la2)) * r
	# Kulak ucu: orta açıdan dışa doğru ear_h kadar
	var l_tip: Vector2 = Vector2(cos(l_mid_angle), sin(l_mid_angle)) * (r + ear_h)
	draw_polygon(PackedVector2Array([lp1, l_tip, lp2]),
		PackedColorArray([ear_col, ear_col, ear_col]))
	# İç parlaklık
	var l_tip_in: Vector2 = Vector2(cos(l_mid_angle), sin(l_mid_angle)) * (r + ear_h * 0.75)
	var lp1i: Vector2 = lp1.lerp(lp2, 0.2)
	var lp2i: Vector2 = lp2.lerp(lp1, 0.2)
	draw_polygon(PackedVector2Array([lp1i, l_tip_in, lp2i]),
		PackedColorArray([ear_in_col, ear_in_col, ear_in_col]))

	# Sağ kulak: simetrik, -80° ile -35°
	var ra1: float = deg_to_rad(-80.0)
	var ra2: float = deg_to_rad(-35.0)
	var r_mid_angle: float = (ra1 + ra2) * 0.5
	var rp1: Vector2 = Vector2(cos(ra1), sin(ra1)) * r
	var rp2: Vector2 = Vector2(cos(ra2), sin(ra2)) * r
	var r_tip: Vector2 = Vector2(cos(r_mid_angle), sin(r_mid_angle)) * (r + ear_h)
	draw_polygon(PackedVector2Array([rp1, r_tip, rp2]),
		PackedColorArray([ear_col, ear_col, ear_col]))
	var r_tip_in: Vector2 = Vector2(cos(r_mid_angle), sin(r_mid_angle)) * (r + ear_h * 0.75)
	var rp1i: Vector2 = rp1.lerp(rp2, 0.2)
	var rp2i: Vector2 = rp2.lerp(rp1, 0.2)
	draw_polygon(PackedVector2Array([rp1i, r_tip_in, rp2i]),
		PackedColorArray([ear_in_col, ear_in_col, ear_in_col]))

	# Kulak kenarlıkları — daire rimıyla aynı renkle, bütünleşik görünsün
	draw_line(lp1, l_tip, rim_col, BORDER_WIDTH)
	draw_line(l_tip, lp2, rim_col, BORDER_WIDTH)
	draw_line(rp1, r_tip, rim_col, BORDER_WIDTH)
	draw_line(r_tip, rp2, rim_col, BORDER_WIDTH)
