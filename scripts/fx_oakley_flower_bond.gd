extends Node2D

## Oakley'nin YENİ pasifi (kullanıcı isteği: "çiçek bırakırken bıraktığı yere
## doğru bıraktığı esnada ince bir sihirli bağ efekti oluşacak anlık") - bkz.
## player.gd _spawn_oakley_flower_auto. fx_wave_beam.gd (Melek'in can/kalkan
## dalgası) ile AYNI "iki nokta arası çizgi" fikrini kullanır, ama o dosya
## PAYLAŞILAN (Melek'in periyodik tik'leri ona bağımlı, kendi 0.8sn'lik
## süresi var) olduğu için dokunulmadı - bu, SADECE bu anlık efekt için ayrı,
## daha kısa ömürlü/ince bir dosya. Kalıcı bir bağ DEĞİL, tek seferlik/anlık.

const LIFETIME := 0.35
const LINE_COLOR := Color(0.55, 1.0, 0.6, 0.9) ## çiçeğin yeşil büyüsüyle aynı renk ailesi

var start_pos: Vector2 = Vector2.ZERO
var end_pos: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0


## p_start: Oakley'nin o anki konumu, p_end: çiçeğin düştüğü nokta - ikisi de
## SABİT (bu efekt anlık olduğu için hedefi karede karede takip etmesine
## gerek yok, bkz. fx_wave_beam.gd'nin AKSİNE).
func setup(p_start: Vector2, p_end: Vector2) -> void:
	global_position = p_start
	start_pos = p_start
	end_pos = p_end


func _ready() -> void:
	z_index = 6


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= LIFETIME:
		queue_free()


func _draw() -> void:
	var t: float = clamp(_elapsed / LIFETIME, 0.0, 1.0)
	var alpha: float = 1.0 - t
	var local_end: Vector2 = end_pos - start_pos
	draw_line(Vector2.ZERO, local_end, Color(LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b, LINE_COLOR.a * alpha), 1.5, true)
	## İnce parlaklık hissi için üstüne daha soluk/kalın ikinci bir çizgi.
	draw_line(Vector2.ZERO, local_end, Color(1.0, 1.0, 1.0, 0.3 * alpha), 3.5, true)
	## İki uçta küçük birer parıltı noktası.
	draw_circle(Vector2.ZERO, 3.0 * (1.0 - t), Color(0.7, 1.0, 0.75, alpha))
	draw_circle(local_end, 3.0 * (1.0 - t), Color(0.7, 1.0, 0.75, alpha))
