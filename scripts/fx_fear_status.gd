extends AnimatedSprite2D
class_name FearStatusFx

## Korkmuş yaratığın başının üstünde titreyen küçük hayalet (tools/gen_necro_fx.py "fear" - 16x16, 6 kare döngü).
## enemy.gd _spawn_fear_status_fx/_remove_fear_status_fx kullanır: Necromancer ULTİ (Lanetli Kafatası, rastgele yürüyen
## korku) VE Melek'in Kutsal Korku'su (kaçan korku) aynı göstergeyi paylaşır. Host başlatır, broadcast_enemy_vfx
## "fear_start"/"fear_stop" ile diğer istemcilere yayınlanır. Stun yıldızlarıyla (fx_stun_stars.gd) aynı yaşam döngüsü deseni.

const TEXEL := 1.212 ## 1 sanat pikseli = bu kadar dünya birimi (ebeveyn ölçeğinden bağımsız tutulur)
## get_overhead_bar_offset() boss çubuğu içindir (hücre boyunun yarısı + 26 - gövdenin çok üstü); gösterge başın hemen
## üstüne otursun diye onun bu oranı kullanılır (zehir göstergesi 0.5 kullanıyor, bkz. enemy.gd _poison_status_fx).
const HEAD_RATIO := 0.45

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
