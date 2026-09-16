extends Control

## Parti panelindeki (bkz. party_panel.gd) can/kalkan çubukları için küçük,
## bağımsız bir Control çizim yardımcısı. overhead_bar.gd'deki
## _draw_pixel_bar ile AYNI piksel-sanatı görsel dilini (kalın siyah çerçeve,
## hafif yuvarlak köşe, üstte parlama şeridi) kullanır - ama o script Node2D
## (karakterin üstünde sabit 44px genişlikte çizilir), burada ise UI
## Control'ün kendi `size`ına göre ölçeklenen YATAY bir bar gerekiyor, bu
## yüzden aynı çizim mantığı bağımsız bir Control olarak tekrar uygulandı.

const OUTLINE := 1.5
const CORNER_RATIO := 0.28

var ratio: float = 1.0
var fill_color: Color = Color(0.30, 0.82, 0.24, 1.0)
var bg_color: Color = Color(0.12, 0.04, 0.04, 1.0)


func set_ratio(r: float) -> void:
	var clamped: float = clamp(r, 0.0, 1.0)
	if is_equal_approx(clamped, ratio):
		return
	ratio = clamped
	queue_redraw()


func set_colors(fill: Color, bg: Color) -> void:
	fill_color = fill
	bg_color = bg
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size.round())
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var corner: float = r.size.y * CORNER_RATIO

	var outline_style := StyleBoxFlat.new()
	outline_style.bg_color = Color(0, 0, 0, 1.0)
	outline_style.set_corner_radius_all(int(corner + OUTLINE))
	draw_style_box(outline_style, r.grow(OUTLINE))

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = bg_color
	bg_style.set_corner_radius_all(int(corner))
	draw_style_box(bg_style, r)

	if ratio > 0.0:
		var fill_w: float = round(r.size.x * ratio)
		if fill_w > 0.0:
			var fill_rect := Rect2(r.position, Vector2(fill_w, r.size.y))
			var fill_style := StyleBoxFlat.new()
			fill_style.bg_color = fill_color
			fill_style.set_corner_radius_all(int(corner))
			draw_style_box(fill_style, fill_rect)
			var glow_rect := Rect2(r.position, Vector2(fill_w, max(1.0, r.size.y * 0.35)))
			var glow_style := StyleBoxFlat.new()
			glow_style.bg_color = fill_color.lightened(0.4)
			glow_style.corner_radius_top_left = int(corner)
			glow_style.corner_radius_top_right = int(corner)
			draw_style_box(glow_style, glow_rect)
