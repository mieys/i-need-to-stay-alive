extends Area2D

const DropAttractionScript := preload("res://scripts/drop_attraction.gd")
const DropShadowScript := preload("res://scripts/drop_shadow.gd")

## KALKAN ORBU (kullanıcı isteği 2026-10-14: "tıpkı yiyecek gibi kalkan veren 2 adet yere düşen toplanabilir": 1. orb %15,
## 2. orb %30 kalkan yeniler). food_drop.gd ile AYNI desen (kök zıplar, gölge yerde, 300 sn sonra kaybolur, istemcideki
## görsel kopya host'a request_drop_pickup yollar, "claimed" tek kapı). Yüzde, toplayanın AZAMİ kalkanı üzerinden.
## TEK kaynak burası: enemy.gd (düşme) ve network_manager.gd (host'un istemci adına işlediği yol) buradan okur.
const TIER_SHIELD_PERCENT: Dictionary = {
	1: 0.15,
	2: 0.30,
}
const TIER_TEXTURES: Dictionary = {
	1: "res://assets/pickups/shield_orb/shield_orb_small.png",
	2: "res://assets/pickups/shield_orb/shield_orb_large.png",
}
const DEFAULT_TIER := 1
const TIER_COUNT := 2
## Bir orb düştüğünde büyük (%30) olma ihtimali (bkz. enemy.gd _drop_shield_orb).
const LARGE_CHANCE := 0.30
## bkz. food_drop.gd EXPIRE_SECONDS.
const EXPIRE_SECONDS := 300.0

@export var tier: int = DEFAULT_TIER:
	set(val):
		tier = val
		_update_visual()

var bob_time: float = 0.0
var _last_bob_offset: float = 0.0
var sprite: Sprite2D = null

## PARILTI (kullanıcı isteği 2026-10-14: "orb parıltılı görünmeli"): orbun üstünde ayrı bir düğüm (gölge ölçüsünü bozmasın diye dokuya
## gömülmedi) - nabız gibi atan hale, küreyi çaprazlama geçen cam parlaması ve kenarda yanıp sönen dört köşeli yıldızlar. Büyük orbda
## bir yıldız fazla + altın tonlu. FPS (2026-10-15): eskiden orb başına 12 Hz'de ~70 draw_rect + 480 hücrelik tarama (_draw) vardı;
## artık 48 adımlık (12 FPS, 4 sn) döngü SPRITE SHEET (tools/gen_shield_orb_sparkle.py, assets/pickups/shield_orb/sparkle_t1/t2.png),
## kare numarası adım değişince yazılır. Döngü dikişsiz olsun diye cam parlaması dönemi 22 -> 24, nabız ~25,1 -> 24 adım oldu.
const SPARKLE_FPS := 12.0
const SPARKLE_FRAMES := 48
const SPARKLE_SHEETS := {1: "res://assets/pickups/shield_orb/sparkle_t1.png", 2: "res://assets/pickups/shield_orb/sparkle_t2.png"}
static var _sheet_cache: Dictionary = {}
var _fx: Sprite2D = null
var _fx_step: int = -1


static func roll_tier() -> int:
	return 2 if randf() < LARGE_CHANCE else 1


func get_shield_percent() -> float:
	return TIER_SHIELD_PERCENT.get(tier, TIER_SHIELD_PERCENT[DEFAULT_TIER])


## collector_max_shield: toplayan oyuncunun azami kalkanı (item_shield_max).
func get_shield_amount(collector_max_shield: float) -> float:
	return get_shield_percent() * maxf(0.0, collector_max_shield)


func _ready() -> void:
	add_to_group("shield_orb_drops")
	body_entered.connect(_on_body_entered)
	if not sprite:
		sprite = get_node_or_null("Sprite2D")
	_update_visual()
	DropShadowScript.attach(self, sprite, true)
	_fx = Sprite2D.new()
	_fx.name = "Sparkle"
	_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var fx_mat := CanvasItemMaterial.new()
	fx_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fx.material = fx_mat
	_fx.hframes = SPARKLE_FRAMES
	_fx.texture = _sparkle_sheet(tier)
	add_child(_fx)
	bob_time = randf() * 4.0 ## yan yana düşen orblar aynı anda yanıp sönmesin
	get_tree().create_timer(EXPIRE_SECONDS).timeout.connect(_on_expire)
	_place_on_ground.call_deferred()


func _place_on_ground() -> void:
	DropAttractionScript.place_on_ground(self)


func _on_expire() -> void:
	if not is_instance_valid(self) or get_meta("network_spawned", false):
		return
	if NetworkManager.is_multiplayer_active:
		if not NetworkManager.is_host:
			return
		var drop_id: int = int(get_meta("drop_network_id", 0))
		if drop_id > 0:
			NetworkManager.queue_remove_drop(drop_id)
	queue_free()


## bkz. food_drop.gd _update_visual: .import henüz yoksa ham dosyadan yüklenir.
func _update_visual() -> void:
	var s: Sprite2D = sprite if sprite else get_node_or_null("Sprite2D") as Sprite2D
	if not s:
		return
	var path: String = TIER_TEXTURES.get(tier, TIER_TEXTURES[DEFAULT_TIER]) as String
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if not tex:
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			tex = ImageTexture.create_from_image(img)
	if tex:
		s.texture = tex
	if _fx != null:
		_fx.texture = _sparkle_sheet(tier)


var _zone_blocked_body: Node = null ## güvenli bölgedeyken dokunan oyuncu (madde 325): bölgeden çıkınca yeniden denenir


func _process(delta: float) -> void:
	bob_time += delta
	var bob_offset: float = sin(bob_time * 4.0) * 3.0
	position.y += bob_offset - _last_bob_offset
	_last_bob_offset = bob_offset
	var step: int = int(bob_time * SPARKLE_FPS)
	if step != _fx_step and _fx != null:
		_fx_step = step
		_fx.frame = step % SPARKLE_FRAMES
	if _zone_blocked_body != null:
		var b: Node = _zone_blocked_body
		if not is_instance_valid(b) or not overlaps_body(b as PhysicsBody2D):
			_zone_blocked_body = null
		elif b.get("is_in_merchant_zone") != true:
			_zone_blocked_body = null
			_on_body_entered(b)


## bkz. _update_visual: .import henüz yoksa ham dosyadan yüklenir.
static func _sparkle_sheet(t: int) -> Texture2D:
	var key: int = 2 if t >= 2 else 1
	if _sheet_cache.has(key):
		return _sheet_cache[key]
	var path: String = SPARKLE_SHEETS[key]
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if tex == null:
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			tex = ImageTexture.create_from_image(img)
	_sheet_cache[key] = tex
	return tex


func _on_body_entered(body: Node) -> void:
	if not is_instance_valid(body):
		return
	## Satıcının güvenli bölgesinde kalkan basılmaz (madde 325): orb yerde kalsın, oyuncu bölgeden çıkınca alır (boşa gitmesin).
	if body.get("is_in_merchant_zone") == true:
		_zone_blocked_body = body
		return

	## İstemcideki GÖRSEL KOPYA: sadece bu istemcinin KENDİ oyuncusu tetikler, kalkanı host dağıtır (bkz. food_drop.gd aynı not).
	if NetworkManager.is_multiplayer_active and get_meta("network_spawned", false):
		if not body.is_in_group("player"):
			return
		var visual_id: int = int(get_meta("drop_network_id", 0))
		if visual_id > 0:
			NetworkManager.request_drop_pickup.rpc_id(NetworkManager._host_peer_id(), visual_id, "shield_orb")
			NetworkManager.discard_visual_drop(visual_id)
		queue_free()
		return

	## Host teması + istemci isteği aynı karede gelirse ödül iki kez verilmesin (bkz. food_drop.gd "claimed").
	if get_meta("claimed", false):
		return
	if body.is_in_group("player"):
		apply_to_local_player(body)
	elif body.is_in_group("remote_players"):
		## Host'un fiziksel teması (güvenlik ağı): gerçek kalkan hedefin kendi istemcisinde artar.
		var amount: float = get_shield_amount(float(body.item_shield_max) if "item_shield_max" in body else 0.0)
		if body.has_method("heal_shield"):
			body.heal_shield(amount)
		var target_peer: int = int(body.peer_id) if "peer_id" in body else 0
		if amount > 0.0 and target_peer > 0 and NetworkManager.is_multiplayer_active:
			NetworkManager.sync_ally_shield_heal.rpc(target_peer, amount)
	else:
		return

	set_meta("claimed", true)
	if NetworkManager.is_multiplayer_active:
		var drop_id: int = int(get_meta("drop_network_id", 0))
		if drop_id > 0:
			NetworkManager.queue_remove_drop(drop_id)
	queue_free()


## Yerel oyuncuya (tek oyunculu / host'un kendisi) kalkanı verir: mavi sayı + tam yüzde (İyileştirme ve Kalkan Gücü ile büyümez).
func apply_to_local_player(p: Node) -> void:
	if p == null or not p.has_method("heal_shield") or not ("item_shield_max" in p):
		return
	var amount: float = get_shield_amount(float(p.item_shield_max))
	if amount <= 0.0:
		return
	if p.has_method("show_received_shield_number"):
		p.show_received_shield_number(amount)
	p.heal_shield(amount, true, false)
