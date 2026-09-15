extends Node2D

## Necromancer'ın yeni 3. yeteneği (Yarasa Sürüsü, skill3 id 35, R - basılıp
## kapanabilen bir "toggle", bkz. player.gd _necro_toggle_bats) ile
## gönderilen TEK bir yarasa: hedef yaratığa doğru uçar (homing), bir kez
## çarpıp hasar verir, sonra Necromancer'ın GÜNCEL (hareket ediyor olabilir)
## konumuna geri döner - boomerang_projectile.gd'nin dönüş bacağıyla AYNI
## "her karede güncel konuma doğru yön hesapla" tekniği, ama gidiş bacağı
## SABİT bir yön yerine hedefi TAKİP EDİYOR.
##
## Sadece GERÇEKTEN döken (caster) istemcide var olur ve hasar verir - Korsan'ın
## bombaları/Necromancer'ın iskelet-hortlaklarıyla AYNI mimari (bkz. korsan_
## bomb.gd dosya başı notu). Diğer istemcilere yarasanın TAM uçuş yolu
## senkronize EDİLMİYOR - sadece isabet anında player.gd _spawn_world_
## explosion_fx üzerinden paylaşılan bir "hitscan_impact" VFX'i yayınlanıyor.
## Bu CLAUDE.md'nin uyardığı "yarım senkron" hata sınıfına GİRMİYOR: hiçbir
## kalıcı/donuk/yanlış durum bırakmıyor, sadece uçuşun kendisi (görsel detay)
## uzak ekranlarda görünmüyor - vurulan yaratıkların canı zaten host
## üzerinden herkese normal şekilde senkronize oluyor.

@export var speed: float = 260.0
@export var hit_distance: float = 22.0
@export var return_arrival_distance: float = 24.0
## Güvenlik zaman aşımı - hedef kaybolur/oyuncu sahneden ayrılırsa sonsuza
## kadar havada asılı kalmasın.
@export var lifetime: float = 5.0

var target: Node2D = null
var caster: Node2D = null
var damage: float = 0.0
var is_crit: bool = false

var _returning: bool = false
var _has_hit: bool = false


func _ready() -> void:
	get_tree().create_timer(lifetime).timeout.connect(_on_timeout)


func _process(delta: float) -> void:
	if not _returning:
		if not is_instance_valid(target) or target.get("is_dead") == true:
			_returning = true
			return
		var to_target: Vector2 = target.global_position - global_position
		if to_target.length() <= hit_distance:
			_apply_hit()
			_returning = true
			return
		global_position += to_target.normalized() * speed * delta
		rotation = to_target.angle()
		return

	if not is_instance_valid(caster):
		queue_free()
		return
	var to_caster: Vector2 = caster.global_position - global_position
	if to_caster.length() <= return_arrival_distance:
		queue_free()
		return
	global_position += to_caster.normalized() * speed * delta
	rotation = to_caster.angle()


func _apply_hit() -> void:
	if _has_hit or not is_instance_valid(target):
		return
	_has_hit = true
	if target.get("is_dead") != true and target.has_method("take_damage"):
		target.take_damage(damage, is_crit)
	if is_instance_valid(caster) and caster.has_method("_spawn_world_explosion_fx"):
		caster._spawn_world_explosion_fx(global_position)


func _on_timeout() -> void:
	if is_instance_valid(self):
		queue_free()


## Sprite/atlas asseti yok - küçük, koyu mor bir yarasa silueti tamamen
## prosedürel çiziliyor (bkz. fx_projectile_orb.gd'nin AYNI yaklaşımı).
func _draw() -> void:
	var body_color := Color(0.55, 0.15, 0.65, 0.95)
	var wing_color := Color(0.32, 0.08, 0.42, 0.85)
	draw_polygon(PackedVector2Array([Vector2(-3, -2), Vector2(-15, -9), Vector2(-5, 5)]), PackedColorArray([wing_color]))
	draw_polygon(PackedVector2Array([Vector2(3, -2), Vector2(15, -9), Vector2(5, 5)]), PackedColorArray([wing_color]))
	draw_circle(Vector2.ZERO, 5.0, body_color)
