extends AnimatedSprite2D
class_name TauntStatusFx

## Kışkırtılmış yaratığın başının üstünde nabız atan öfke damarı (💢) - Şovalye Adam Q (Kışkırtma), kullanıcı isteği
## 2026-09-25: "yaratıkların üstünde de kışkırtma durum efekti yapman gerek". tools/gen_sovalye_fx.py "taunt_status"
## (16x16, 6 kare döngü, açık kırmızı). fx_fear_status.gd ile AYNI yaşam döngüsü: enemy.gd _spawn_taunt_status_fx/
## _remove_taunt_status_fx; host (ya da tek oyunculu) karar verir, broadcast_enemy_vfx "taunt_start"/"taunt_stop" ile
## diğer istemcilere yayınlanır.

const TEXEL := 1.212 ## 1 sanat pikseli = bu kadar dünya birimi (ebeveyn ölçeğinden bağımsız tutulur)
const HEAD_RATIO := 0.45 ## bkz. fx_fear_status.gd AYNI not

var _timer: float = 0.0
var _parent_body: Node2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_parent_body = get_parent() as Node2D
	if _parent_body:
		var ps: float = absf(_parent_body.global_scale.x)
		scale = Vector2.ONE * (TEXEL / (ps if ps > 0.01 else 1.0))
	_update_position()
	play(&"loop")


func setup(duration: float) -> void:
	_timer = maxf(_timer, duration)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0 or (is_instance_valid(_parent_body) and _parent_body.get("is_dead") == true):
		queue_free()
		return
	_update_position()


func _update_position() -> void:
	if is_instance_valid(_parent_body) and _parent_body.has_method("get_overhead_bar_offset"):
		position = Vector2(0, roundf(_parent_body.get_overhead_bar_offset() * HEAD_RATIO))
