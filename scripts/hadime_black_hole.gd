extends Node2D

## Yaratık aday sorgusu (yeni yolda C++ ızgarası, eski yolda tüm "enemies" grubu; süzgeçler çağıranda aynen kalır).
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")

## Suriyeli Hadime E - Kara Delik (kullanıcı isteği 2026-09-25: "bulunduğu konuma kara delik bırakıp yaratıkları hafifçe
## içine doğru çekip kalkanlarını emerek verdiği hasarın %20'si kadar Hadime'ye kalkan yenilesin, 5 saniye sürecek (2026-09-26: 6 sn, bkz. HadimeMath.HOLE_DURATION), her
## saniye %80 saldırı gücü hasar, 18 sn bekleme, kalkan çekme efektine gerek yok").
## 2026-09-28 yetenek evrimleri: kalkan emme temel yetenekten çıkıp "Kalkan Emici" evrimine geçti (player.gd
## _on_hadime_hole_tick). Bu script'teki evrim kancaları:
##  - radius_mult (Genişleyen Boşluk): çekim/hasar yarıçapı VE sayfanın ölçeği birlikte büyür.
##  - moving (Gezgin Delik): delik kalabalık yaratıklara doğru çekim hızıyla (HOLE_PULL_SPEED) ilerler ve yarıçapındaki
##    yaratıkları kendisiyle SÜRÜKLER (çekim kopyası deliğin o karedeki yer değiştirmesini onlara da ekler).
##  - on_end (Süpernova): ömrün sonunda yetkili kopya merkezi ve yarıçapı player.gd'ye bildirir (patlama hasarı + efekti orada).
##
## Dünya konumunda sabit (HadimeMath.spawn_black_hole). Görsel tamamen sprite sayfası (tools/gen_hadime_fx.py black_hole:
## intro -> loop -> outro). Kopyalar ve görevleri:
##  - authoritative (kasterin kendi kopyası): her HOLE_TICK'te on_tick(merkez, yarıçap) -> player.gd _on_hadime_hole_tick
##    (hasar + kalkan yenileme kasterde bir kez hesaplanır, istemciyse hasar host'a zaten take_damage yoluyla gider).
##    Hareketli delikte yolu da BU kopya belirler ve konumunu ~10 Hz yayınlar (NetworkManager.broadcast_hadime_hole_pos).
##  - pull_authority (host'taki kopya): yaratıklar host'ta simüle edildiği için çekim SADECE orada uygulanır; konumlar
##    normal yaratık senkronuyla herkese gider. Kaster host değilse bu kopya network_manager.gd
##    broadcast_hadime_black_hole'dan (reliable) gelir ve hareketli delikte kasterin yayınladığı konumu izler.
##  - diğer istemcilerdeki kopyalar sadece görseldir (hareketli delikte onlar da ağ konumunu izler).

const HadimeMath := preload("res://scripts/hadime_math.gd")
const EnemyAbilities := preload("res://scripts/enemy_abilities.gd")
const HoleFrames: SpriteFrames = preload("res://assets/fx/hadime/black_hole_frames.tres")
## Sayfa karesinde kara delik merkezinin karenin ortasına göre konumu (sanat pikseli): 192x96, merkez (95.5, 50).
const CENTER_ART := Vector2(-0.5, 2.0)
## Görsel "outro" herhangi bir sebeple bitmezse (ağaç duraklatma vb.) güvenlik ömrü.
const SAFETY_EXTRA := 2.0
## Hareketli deliğin ağ konumu yayın aralığı (sn) ve uzak kopyanın bu konuma yaklaşma hızı.
const NET_SEND_INTERVAL := 0.1
const NET_FOLLOW_RATE := 10.0

var authoritative: bool = false
var pull_authority: bool = false
var on_tick: Callable = Callable()
var radius_mult: float = 1.0
var moving: bool = false
var owner_peer: int = 0
var on_end: Callable = Callable()

var _sprite: AnimatedSprite2D = null
var _t: float = 0.0
var _tick_timer: float = HadimeMath.HOLE_FIRST_TICK
var _ending: bool = false
var _move_goal: Vector2 = Vector2.INF
var _retarget_timer: float = 0.0
var _net_send_timer: float = 0.0
var _net_target: Vector2 = Vector2.INF
var _prev_pos: Vector2 = Vector2.ZERO


func radius() -> float:
	return HadimeMath.HOLE_RADIUS * radius_mult


func _ready() -> void:
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = HoleFrames
	_sprite.scale = Vector2.ONE * HadimeMath.TEXEL * radius_mult
	_sprite.offset = -CENTER_ART
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play(&"intro")
	_prev_pos = global_position
	add_to_group("hadime_black_holes")
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


## Kasterin yayınladığı konum (hareketli delik - bkz. network_manager.gd broadcast_hadime_hole_pos).
func set_net_target(pos: Vector2) -> void:
	_net_target = pos


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < HadimeMath.HOLE_DURATION:
		_prev_pos = global_position
		if moving:
			_process_move(delta)
		if authoritative:
			_tick_timer -= delta
			if _tick_timer <= 0.0:
				_tick_timer += HadimeMath.HOLE_TICK
				if on_tick.is_valid():
					on_tick.call(global_position, radius())
		if pull_authority:
			_pull(delta, global_position - _prev_pos)
	elif not _ending:
		_ending = true
		_sprite.play(&"outro")
		## Süpernova: sayfanın çöküşüyle aynı anda patlama (hasar + efekt player.gd'de - yetkili kopya bir kez).
		if authoritative and on_end.is_valid():
			on_end.call(global_position, radius())
	elif _t > HadimeMath.HOLE_DURATION + SAFETY_EXTRA:
		queue_free()


## Gezgin Delik: yetkili kopya en kalabalık yaratık kümesine (yarıçapı içinde en çok komşusu olan yaratık) çekim hızıyla
## ilerler ve konumunu yayınlar; diğer kopyalar bu konumu yumuşakça izler (hasar/çekim kararları kendi kopyalarında).
func _process_move(delta: float) -> void:
	if authoritative:
		_retarget_timer -= delta
		if _retarget_timer <= 0.0:
			_retarget_timer = HadimeMath.EVO_HOLE_RETARGET
			_move_goal = _pick_crowd_goal()
		if _move_goal != Vector2.INF:
			var to_goal: Vector2 = _move_goal - global_position
			var step: float = minf(HadimeMath.HOLE_PULL_SPEED * delta, to_goal.length())
			if step > 0.01:
				var np: Vector2 = global_position + to_goal.normalized() * step
				if not GameManager.is_position_blocked_by_walls(np):
					global_position = np
		if NetworkManager.is_multiplayer_active:
			_net_send_timer -= delta
			if _net_send_timer <= 0.0:
				_net_send_timer = NET_SEND_INTERVAL
				NetworkManager.broadcast_hadime_hole_pos.rpc(owner_peer, global_position)
	elif _net_target != Vector2.INF:
		global_position = global_position.lerp(_net_target, 1.0 - exp(-NET_FOLLOW_RATE * delta))


func _pick_crowd_goal() -> Vector2:
	var r: float = radius()
	var r2: float = r * r
	var search2: float = HadimeMath.EVO_HOLE_MOVE_SEARCH * HadimeMath.EVO_HOLE_MOVE_SEARCH
	var cands: Array = []
	for e in EnemyQueryScript.candidates(get_tree(), global_position, HadimeMath.EVO_HOLE_MOVE_SEARCH + 1.0):
		if not is_instance_valid(e) or not (e is Node2D) or e.get("is_dead") == true:
			continue
		if global_position.distance_squared_to((e as Node2D).global_position) <= search2:
			cands.append((e as Node2D).global_position)
	var best: Vector2 = Vector2.INF
	var best_n: int = 0
	for p in cands:
		var n: int = 0
		for q in cands:
			if p.distance_squared_to(q) <= r2:
				n += 1
		if n > best_n:
			best_n = n
			best = p
	return best


## Yarıçap içindeki yaratıkları merkeze doğru sabit ve yavaş kaydırır (yürüyüşlerine ek). Bosslar çekilmez; orman/uçurum
## karosuna girecekse o karede kaydırılmaz. drag: deliğin bu karedeki yer değiştirmesi (Gezgin Delik - içindekiler de aynı
## kadar sürüklenir).
func _pull(delta: float, drag: Vector2) -> void:
	var c: Vector2 = global_position
	var r: float = radius()
	var r2: float = r * r
	for e in EnemyQueryScript.candidates(get_tree(), c - drag, r + 1.0):
		if not is_instance_valid(e) or not (e is Node2D) or e.get("is_dead") == true or e.get("is_boss") == true:
			continue
		var ep: Vector2 = (e as Node2D).global_position + drag
		var to_c: Vector2 = c - ep
		var d2: float = to_c.length_squared()
		if d2 > r2:
			continue
		var d: float = sqrt(d2)
		var np: Vector2 = ep
		if d > HadimeMath.HOLE_PULL_DEADZONE:
			np = ep + to_c / d * minf(HadimeMath.HOLE_PULL_SPEED * delta, d - HadimeMath.HOLE_PULL_DEADZONE)
		if GameManager.is_position_blocked_by_walls(np):
			continue
		(e as Node2D).global_position = np
