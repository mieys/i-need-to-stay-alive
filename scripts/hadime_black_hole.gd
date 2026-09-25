extends Node2D

## Suriyeli Hadime E - Kara Delik (kullanıcı isteği 2026-09-25: "bulunduğu konuma kara delik bırakıp yaratıkları hafifçe
## içine doğru çekip kalkanlarını emerek verdiği hasarın %20'si kadar Hadime'ye kalkan yenilesin, 5 saniye sürecek, her
## saniye %80 saldırı gücü hasar, 18 sn bekleme, kalkan çekme efektine gerek yok").
##
## Dünya konumunda sabit (HadimeMath.spawn_black_hole). Görsel tamamen sprite sayfası (tools/gen_hadime_fx.py black_hole:
## intro -> loop -> outro). Kopyalar ve görevleri:
##  - authoritative (kasterin kendi kopyası): her HOLE_TICK'te on_tick(merkez) -> player.gd _on_hadime_hole_tick
##    (hasar + kalkan yenileme kasterde bir kez hesaplanır, istemciyse hasar host'a zaten take_damage yoluyla gider).
##  - pull_authority (host'taki kopya): yaratıklar host'ta simüle edildiği için çekim SADECE orada uygulanır; konumlar
##    normal yaratık senkronuyla herkese gider. Kaster host değilse bu kopya network_manager.gd
##    broadcast_hadime_black_hole'dan (reliable) gelir.
##  - diğer istemcilerdeki kopyalar sadece görseldir.

const HadimeMath := preload("res://scripts/hadime_math.gd")
const EnemyAbilities := preload("res://scripts/enemy_abilities.gd")
const HoleFrames: SpriteFrames = preload("res://assets/fx/hadime/black_hole_frames.tres")
## Sayfa karesinde kara delik merkezinin karenin ortasına göre konumu (sanat pikseli): 192x96, merkez (95.5, 50).
const CENTER_ART := Vector2(-0.5, 2.0)
## Görsel "outro" herhangi bir sebeple bitmezse (ağaç duraklatma vb.) güvenlik ömrü.
const SAFETY_EXTRA := 2.0

var authoritative: bool = false
var pull_authority: bool = false
var on_tick: Callable = Callable()

var _sprite: AnimatedSprite2D = null
var _t: float = 0.0
var _tick_timer: float = HadimeMath.HOLE_FIRST_TICK
var _ending: bool = false


func _ready() -> void:
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = HoleFrames
	_sprite.scale = Vector2.ONE * HadimeMath.TEXEL
	_sprite.offset = -CENTER_ART
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play(&"intro")
	## Zemin efekti: haritanın hemen arkasına - tüm karakter/yaratıkların ALTINDA (asit gölü / düşmelerle aynı çözüm).
	## Ertelenmiş: ebeveyn şu an bu düğümü eklemekle meşgulken move_child çağrılamaz (xp_orb.gd ile aynı).
	_place_on_ground.call_deferred()


func _place_on_ground() -> void:
	if is_inside_tree():
		EnemyAbilities.place_on_ground(get_tree(), self)


func _on_animation_finished() -> void:
	if _sprite.animation == &"intro" and not _ending:
		_sprite.play(&"loop")
	elif _sprite.animation == &"outro":
		queue_free()


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < HadimeMath.HOLE_DURATION:
		if authoritative:
			_tick_timer -= delta
			if _tick_timer <= 0.0:
				_tick_timer += HadimeMath.HOLE_TICK
				if on_tick.is_valid():
					on_tick.call(global_position)
		if pull_authority:
			_pull(delta)
	elif not _ending:
		_ending = true
		_sprite.play(&"outro")
	elif _t > HadimeMath.HOLE_DURATION + SAFETY_EXTRA:
		queue_free()


## Yarıçap içindeki yaratıkları merkeze doğru sabit ve yavaş kaydırır (yürüyüşlerine ek). Bosslar çekilmez; orman/uçurum
## karosuna girecekse o karede kaydırılmaz.
func _pull(delta: float) -> void:
	var c: Vector2 = global_position
	var r2: float = HadimeMath.HOLE_RADIUS * HadimeMath.HOLE_RADIUS
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not (e is Node2D) or e.get("is_dead") == true or e.get("is_boss") == true:
			continue
		var ep: Vector2 = (e as Node2D).global_position
		var to_c: Vector2 = c - ep
		var d2: float = to_c.length_squared()
		if d2 > r2:
			continue
		var d: float = sqrt(d2)
		if d <= HadimeMath.HOLE_PULL_DEADZONE:
			continue
		var np: Vector2 = ep + to_c / d * minf(HadimeMath.HOLE_PULL_SPEED * delta, d - HadimeMath.HOLE_PULL_DEADZONE)
		if GameManager.is_position_blocked_by_forest(np):
			continue
		(e as Node2D).global_position = np
