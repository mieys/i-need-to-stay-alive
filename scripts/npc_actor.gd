extends Node2D
class_name NpcActor

## DÜKKAN NPC'leri (demirci + seyyar satıcı) için ortak taban - kullanıcı isteği (2026-10-13, madde 112). Tamamen YEREL/kozmetik:
## ağ trafiği yok, her istemci kendi kopyasını çalıştırır (davranış oyuncuların konumundan türetilir; oyuncu konumları zaten eşitlenir).
##
## Oyuncularla AYNI görünüm ölçüleri (remote_player.gd ile bire bir): kök 0,5 ölçekte, AnimatedSprite2D ölçeği = karakter ölçeği * EntityScale.SIZE,
## ofset (0,-5) - yani NPC bir oyuncunun yanında aynı boyda durur ve konuşma balonu (chat_bubble.gd) aynı yerel birimlerle çalışır.
## Düğüm adı "AnimatedSprite2D": depth_occluders.gd character_extent() gövde ölçüsünü bu adla okur; grup "npc_actors" derinlik
## sıralamasına (nesnenin arkasındayken altında) girmeyi sağlar (bkz. DepthOccluders.character_nodes).
##
## Konum kuralı: kök, ayak noktasının FEET_OFFSET yukarısındadır (oyuncu kökü gövde merkezidir). Bütün hareket API'si AYAK koordinatıyla ve
## EBEVEYNİN yerel uzayında çalışır (iç mekanda ebeveyn INTERIOR_OFFSET'te durur): feet() / set_feet() / walk_path().
## Sprite sayfaları: <klip>_<yon> (down/left/right/up), bkz. tools/import_ek_animasyonlar.py.

signal arrived

const DepthOccludersScript := preload("res://scripts/depth_occluders.gd")
const ChatBubbleScript := preload("res://scripts/chat_bubble.gd")

const GROUP := &"npc_actors"
const ROOT_SCALE := 0.5 ## main.tscn'deki Player/RemotePlayer kök ölçeği
const BASE_SPRITE_SCALE := 2.2368375 ## characters.gd standart "scale" (Matthew gibi istisnalar hariç)
const SPRITE_OFFSET := Vector2(0.0, -5.0) ## player.gd DEFAULT_ANIM_OFFSET
const FEET_OFFSET: float = DepthOccludersScript.FEET_OFFSET
const BUBBLE_Y := 70.0 ## chat_bubble.gd balonun ALT kenarını -136'ya koyar (oyuncunun isim etiketi için); NPC'de isim yok, baş hemen altında
const WALK_SPEED := 46.0 ## dünya px/sn (oyuncu yürüyüşü ~82): 6 karelik yürüme klibiyle (8 fps) ayaklar kaymayacak kadar yavaş/doğal
const ARRIVE_EPS := 1.5

var sprite: AnimatedSprite2D = null
var facing: String = "down"
var _path: PackedVector2Array = PackedVector2Array()
var _path_i: int = 0
var _speed: float = WALK_SPEED
var _bubble: Node2D = null
var _locked_clip: String = "" ## boş değilse yürürken/dururken bu klip oynar (ör. "strike", "think")


## frames: assets/npc/<ad>/<ad>_frames.tres. Düğüm ağaca girmeden de çağrılabilir.
func setup(frames: SpriteFrames) -> void:
	add_to_group(GROUP)
	scale = Vector2(ROOT_SCALE, ROOT_SCALE)
	z_index = 1 ## oyuncularla aynı katman (main.tscn Player z_index = 1)
	sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * BASE_SPRITE_SCALE * EntityScale.SIZE
	sprite.offset = SPRITE_OFFSET
	add_child(sprite)
	_bubble = Node2D.new()
	_bubble.name = "ChatBubble"
	_bubble.set_script(ChatBubbleScript)
	_bubble.position = Vector2(0.0, BUBBLE_Y)
	add_child(_bubble)
	play_idle()


func feet() -> Vector2:
	return position + Vector2(0.0, FEET_OFFSET)


func set_feet(p: Vector2) -> void:
	position = p - Vector2(0.0, FEET_OFFSET)


func is_walking() -> bool:
	return _path_i < _path.size()


## Sıradaki hedef noktalara (ayak, ebeveyn uzayı) yürür; varış sinyali `arrived`. Boş/tek noktalı yol da kabul edilir.
func walk_path(points: PackedVector2Array, speed: float = WALK_SPEED) -> void:
	_path = points
	_path_i = 0
	_speed = speed
	_locked_clip = ""
	if not is_walking():
		play_idle()
		arrived.emit()


func stop_walking() -> void:
	_path = PackedVector2Array()
	_path_i = 0
	if _locked_clip == "":
		play_idle()


## "idle_<yön>" ya da kilitli klip. Yönsüz çağrılırsa mevcut yönde kalır.
func play_idle(dir: String = "") -> void:
	if dir != "":
		facing = dir
	_play(_locked_clip if _locked_clip != "" else "idle")


## Bu klibi (ör. "strike", "think") bırakılana kadar yön değişse de oynatır; "" = serbest bırak. Yürüyüş başlarsa kilit kalkar.
func lock_clip(clip: String, dir: String = "") -> void:
	if dir != "":
		facing = dir
	_locked_clip = clip
	_path = PackedVector2Array()
	_path_i = 0
	_play(clip if clip != "" else "idle")


func unlock_clip() -> void:
	_locked_clip = ""
	play_idle()


## Hedef ayak noktasına (ebeveyn uzayı) döner; yürümüyorsa bekleme/kilit klibini yeni yönle yeniler.
func face_point(p: Vector2) -> void:
	var d: String = dir_from_vector(p - feet(), facing)
	if d != facing:
		facing = d
		if not is_walking():
			_play(_locked_clip if _locked_clip != "" else "idle")


## Konuşma balonu (chat_bubble.gd: ~4 sn görünür).
func say(text: String) -> void:
	if _bubble != null and _bubble.has_method("show_message"):
		_bubble.show_message(text)


func current_clip() -> String:
	return String(sprite.animation) if sprite != null else ""


## Büyük eksene göre yön; eksenler yakınsa (köşegen) mevcut yön korunur (yürürken titreme olmasın).
static func dir_from_vector(v: Vector2, current: String = "down") -> String:
	if v.length() < 0.001:
		return current
	var ax: float = absf(v.x)
	var ay: float = absf(v.y)
	var horizontal: bool = current == "left" or current == "right"
	if horizontal and ax > ay * 0.7:
		return "right" if v.x > 0.0 else "left"
	if not horizontal and ay > ax * 0.7:
		return "down" if v.y > 0.0 else "up"
	if ax > ay:
		return "right" if v.x > 0.0 else "left"
	return "down" if v.y > 0.0 else "up"


func _play(base: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var clip: String = "%s_%s" % [base, facing]
	if not sprite.sprite_frames.has_animation(clip):
		return
	if sprite.animation != StringName(clip) or not sprite.is_playing():
		sprite.play(clip)


func _process(delta: float) -> void:
	_step_walk(delta)
	_behave(delta)


func _step_walk(delta: float) -> void:
	if not is_walking():
		return
	var cur: Vector2 = feet()
	var target: Vector2 = _path[_path_i]
	var to: Vector2 = target - cur
	var dist: float = to.length()
	var step: float = _speed * delta
	if dist <= maxf(step, ARRIVE_EPS):
		set_feet(target)
		_path_i += 1
		if not is_walking():
			_path = PackedVector2Array()
			_path_i = 0
			play_idle()
			arrived.emit()
		return
	facing = dir_from_vector(to, facing)
	set_feet(cur + to / dist * step)
	_play("walk")


## Alt sınıflar davranışlarını buraya yazar (her karede, yürüyüş adımından SONRA).
func _behave(_delta: float) -> void:
	pass


## Oyuncu/kukla düğümleri (bu istemcide görünür olabilecek tüm gerçek oyuncular). Ölüler dahil edilmez.
static func live_players(tree: SceneTree) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for group_name in ["player", "remote_players"]:
		for n in tree.get_nodes_in_group(group_name):
			if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
				out.append(n as Node2D)
	return out
