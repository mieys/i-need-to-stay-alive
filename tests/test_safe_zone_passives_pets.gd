extends Node

## Madde 327 (2026-10-20): güvenli alanda (seyyar satıcı koruması / demirci iç mekanı) PASİFLER + EVCİL HAYVANLAR da durur + oyuncunun can barının üstünde
## kum saati simgesi + buff/debuff satırında "Zaman Durdu" rozeti. Madde 325 yenilenme/bekleme donmasını yapmıştı; bu test onun üstüne gelen kapıları sınar.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
const OverheadBarScript: GDScript = preload("res://scripts/overhead_bar.gd")
const TimeIconScript: GDScript = preload("res://scripts/time_frozen_status_icon.gd")
const BadgeScript: GDScript = preload("res://scripts/status_effect_badge.gd")
const WeaponShopScript: GDScript = preload("res://scripts/weapon_shop.gd")
const S: GDScript = preload("res://scripts/spiritual_skills.gd")
const PlayerScript: GDScript = preload("res://scripts/player.gd")
const BrushIconScript: GDScript = preload("res://scripts/brush_status_icon.gd")

var _spawned: Array = []
var _prev_char_id: int = 1
var _prev_character: int = 1
var _prev_spirit: String = ""
var _prev_pet: String = ""
var _prev_gold: int = 0


## Hasar sayan sahte yaratık (enemy.gd take_damage imzası).
class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var taken: Array = []

	func _ready() -> void:
		add_to_group("enemies")

	func take_damage(amount: float, _is_crit: bool = false, _shield_pen: float = 0.0, _is_area: bool = false) -> void:
		taken.append(amount)


func _make_player(char_id: int = 1, pet: String = "") -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	_prev_spirit = GameManager.selected_spiritual
	_prev_pet = GameManager.selected_pet
	_prev_gold = GameManager.gold
	GameManager.selected_char_id = char_id
	GameManager.selected_character = Characters.get_def(char_id)["skill"]
	GameManager.selected_spiritual = S.PARA
	GameManager.selected_pet = pet
	NetworkManager.is_multiplayer_active = false
	GameManager.merchant_zone_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(1000.0, 1000.0)
	player.item_shield_hp = 0.0
	player.item_shield_max = 0.0
	return player


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.merchant_zone_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	GameManager.selected_spiritual = _prev_spirit
	GameManager.selected_pet = _prev_pet
	GameManager.gold = _prev_gold
	for n in _spawned:
		if is_instance_valid(n):
			if n.is_in_group("enemies"):
				n.remove_from_group("enemies")
			n.free()
	_spawned.clear()


# ------------------------------------------------------------------ karakter pasifleri

func test_melek_passive_tick_does_not_advance_in_safe_zone() -> void:
	var player: Node = _make_player(10)
	player._melek_passive_tick_timer = 0.0
	player._process_character_passive(0.4)
	assert(is_equal_approx(player._melek_passive_tick_timer, 0.4), "açık haritada Melek pasif sayacı akar: %s" % player._melek_passive_tick_timer)
	player.is_in_merchant_zone = true
	player._melek_passive_tick_timer = 0.0
	player._process_character_passive(5.0)
	assert(player._melek_passive_tick_timer == 0.0, "güvenli alanda Melek pasifi hiç tik atmaz: %s" % player._melek_passive_tick_timer)
	_cleanup()


func test_oakley_flower_timer_freezes_in_smithy() -> void:
	var player: Node = _make_player(2)
	var start: float = player._oakley_flower_auto_timer
	player._process_character_passive(0.5)
	assert(is_equal_approx(player._oakley_flower_auto_timer, start - 0.5), "açık haritada çiçek sayacı akar")
	player.global_position = WeaponShopScript.INTERIOR_OFFSET + Vector2(80.0, 40.0)
	var frozen_at: float = player._oakley_flower_auto_timer
	player._process_character_passive(10.0)
	assert(is_equal_approx(player._oakley_flower_auto_timer, frozen_at), "demircide çiçek sayacı donar (çiçek bırakmaz)")
	_cleanup()


func test_talon_stack_decay_freezes_in_safe_zone() -> void:
	var player: Node = _make_player(1)
	player._talon_passive_stacks = 3
	player._talon_passive_grace_timer = 0.0
	player._talon_passive_decay_timer = 0.0
	player._process_character_passive(0.5)
	assert(is_equal_approx(player._talon_passive_decay_timer, 0.5), "açık haritada yük azalma sayacı akar")
	player.is_in_merchant_zone = true
	player._process_character_passive(10.0)
	assert(is_equal_approx(player._talon_passive_decay_timer, 0.5) and player._talon_passive_stacks == 3, "güvenli alanda yükler azalmaz")
	_cleanup()


func test_matthew_momentum_freezes_and_trail_goes_dark_in_safe_zone() -> void:
	var player: Node = _make_player(3)
	player._matthew_momentum = 0.15
	player._process_character_passive(1.0)
	assert(player._matthew_momentum < 0.15, "açık haritada durunca momentum söner")
	player._matthew_momentum = 0.15
	player.is_in_merchant_zone = true
	player._matthew_trail.set("level", 2) ## tam hız izi açıkmış
	player._process_character_passive(1.0)
	assert(is_equal_approx(player._matthew_momentum, 0.15), "güvenli alanda momentum donuk: %s" % player._matthew_momentum)
	assert(int(player._matthew_trail.get("level")) == 0, "yıldırım izi kapanır")
	var frozen: Variant = player.matthew_net_state()
	player.is_in_merchant_zone = false
	var open: Variant = player.matthew_net_state()
	assert(str(frozen) != str(open), "kuklaya 'güçlü iz' bayrağı güvenli alanda gitmez: %s / %s" % [str(frozen), str(open)])
	_cleanup()


# ------------------------------------------------------------------ öldürme pasifleri

func test_kill_passives_do_not_trigger_in_safe_zone() -> void:
	var player: Node = _make_player(PlayerScript.KORSAN_CHAR_ID)
	GameManager.gold = 0
	player._korsan_gold_on_kill()
	assert(GameManager.gold == 1, "açık haritada Altın Avcısı 1 altın verir")
	player.is_in_merchant_zone = true
	player._korsan_gold_on_kill()
	assert(GameManager.gold == 1, "güvenli alanda Altın Avcısı çalışmaz")
	_cleanup()
	var necro: Node = _make_player(11)
	necro.necro_souls = 0
	necro._necro_on_kill(false)
	assert(necro.necro_souls > 0, "açık haritada ruh birikir")
	var before: int = necro.necro_souls
	necro.global_position = WeaponShopScript.INTERIOR_OFFSET
	necro._necro_on_kill(true)
	assert(necro.necro_souls == before, "demircide ruh pasifi çalışmaz")
	_cleanup()


# ------------------------------------------------------------------ evcil hayvanlar

func test_peri_does_not_cast_or_count_down_in_safe_zone() -> void:
	var player: Node = _make_player(1, "peri")
	var peri: Node = player.get_node("Peri")
	player.damage_bonus = 50.0
	player.health = player.max_health - 30.0
	peri._cooldown = 3.0
	player.is_in_merchant_zone = true
	var hp: float = player.health
	peri.process_heal(10.0)
	assert(is_equal_approx(player.health, hp) and not peri._casting, "güvenli alanda Peri büyü yapmaz")
	assert(is_equal_approx(peri._cooldown, 3.0), "bekleme sayacı da donar: %s" % peri._cooldown)
	player.is_in_merchant_zone = false
	peri.process_heal(10.0)
	assert(player.health > hp and peri._casting, "alandan çıkınca büyü yeniden çalışır")
	_cleanup()


func test_kirpi_does_not_reflect_or_cut_damage_in_safe_zone() -> void:
	var player: Node = _make_player(1, "kirpi")
	player.item_shield_max = 400.0
	player.item_shield_hp = 400.0
	var e := FakeEnemy.new()
	add_child(e)
	_spawned.append(e)
	assert(is_equal_approx(player._kirpi_on_hit(100.0, e), 95.0) and e.taken.size() == 1, "açık haritada Kirpi çalışır")
	player.is_in_merchant_zone = true
	assert(is_equal_approx(player._kirpi_on_hit(100.0, e), 100.0) and e.taken.size() == 1, "güvenli alanda Kirpi ne yansıtır ne azaltır")
	var kirpi: Node = player.get_node("Kirpi")
	kirpi._scan_cd = 0.0
	kirpi.process_spikes(1.0)
	assert(kirpi._scan_cd == 0.0, "diken taraması da durur (sayaç ilerlemez)")
	_cleanup()


func test_kelebek_does_not_shoot_in_safe_zone() -> void:
	var player: Node = _make_player(1, "kelebek")
	var kelebek: Node = player.get_node("KelebekRuhu")
	var e := FakeEnemy.new()
	add_child(e)
	e.global_position = player.global_position + Vector2(60.0, 0.0)
	_spawned.append(e)
	player.is_in_merchant_zone = true
	kelebek.fire_at(e)
	assert(kelebek._bolts == 0, "güvenli alanda Kelebek Ruhu atış yapmaz")
	player.is_in_merchant_zone = false
	kelebek.fire_at(e)
	assert(kelebek._bolts == 1, "alandan çıkınca atış yeniden çalışır")
	_cleanup()


func test_parrot_stays_perched_and_counters_freeze_in_safe_zone() -> void:
	var player: Node = _make_player(1, "papagan")
	var parrot: Node = player.get_node("KorsanParrot")
	parrot.state = parrot.State.PERCH
	parrot._cooldown = 3.0
	player.global_position = WeaponShopScript.INTERIOR_OFFSET + Vector2(10.0, 10.0)
	parrot._process_local(1.0)
	assert(is_equal_approx(parrot._cooldown, 3.0) and parrot.state == parrot.State.PERCH, "demircide papağan gagalamaya çıkmaz, sayacı donar")
	player.global_position = Vector2(1000.0, 1000.0)
	parrot._process_local(1.0)
	assert(parrot._cooldown < 3.0, "dışarıda sayaç akar: %s" % parrot._cooldown)
	_cleanup()


func test_dog_totem_and_necro_skull_use_the_same_safe_zone_rule() -> void:
	var player: Node = _make_player(1)
	## köpek (player_pet.gd): sahibi demircideyken artık saldırmaz/kovalamaz (eskiden yalnız satıcı bölgesine bakıyordu)
	var dog: Node = (load("res://scripts/player_pet.gd") as GDScript).new()
	dog.owner_player = player
	assert(not dog._owner_in_safe_zone(), "açık haritada köpek serbest")
	player.global_position = WeaponShopScript.INTERIOR_OFFSET + Vector2(10.0, 10.0)
	assert(dog._owner_in_safe_zone(), "sahibi demircideyken köpek güvenli alanda sayılır")
	## totem: sahibi demircideyken tik atmaz
	var totem: Node = (load("res://scripts/totem_base.gd") as GDScript).new()
	totem.caster = player
	assert(totem._caster_in_safe_zone(), "sahibi demircideyken totem durur")
	player.global_position = Vector2(1000.0, 1000.0)
	assert(not totem._caster_in_safe_zone(), "dışarıda totem çalışır")
	## Necro kafatası: satıcı bölgesinde sahibiyle birlikte askıya alınır
	var skull: Node = (load("res://scripts/necro_skull.gd") as GDScript).new()
	assert(not skull._suspended(player), "açık haritada kafatası çalışır")
	player.is_in_merchant_zone = true
	assert(skull._suspended(player), "güvenli alanda kafatası askıda")
	dog.free()
	totem.free()
	skull.free()
	_cleanup()


# ------------------------------------------------------------------ bar üstü simge + buff/debuff rozeti

func test_overhead_bar_shows_hourglass_above_bar_and_stacks_above_brush_icon() -> void:
	var holder := Node2D.new()
	holder.scale = Vector2(0.5, 0.5) ## oyuncu kökü gibi
	add_child(holder)
	_spawned.append(holder)
	var bar: Node2D = OverheadBarScript.new()
	holder.add_child(bar)
	bar.set_offset(OverheadBarScript.CHARACTER_Y_OFFSET)
	bar.set_time_frozen(false)
	assert(bar.get_node_or_null("TimeFrozenIcon") == null, "hiç donmadıysa simge kurulmaz (yaratık barları)")
	bar.set_time_frozen(true)
	var icon = bar.get_node_or_null("TimeFrozenIcon")
	assert(icon != null and icon.visible and icon.texture == TimeIconScript.shared_texture(), "donukken kum saati görünür")
	assert(absf(icon.position.y - (OverheadBarScript.CHARACTER_Y_OFFSET - TimeIconScript.GAP)) < 0.01 and icon.position.y < bar.y_offset, "can barının hemen ÜSTÜNDE")
	var img: Image = TimeIconScript.build_image()
	assert(img.get_width() == (TimeIconScript.GLASS[0] as String).length() + 1 and img.get_height() == TimeIconScript.GLASS.size() + 1, "desen + 1 px gölge")
	## saklanma gözü de varsa kum saati onun üstüne dizilir
	bar.set_brush_state(1)
	var lift: float = float(BrushIconScript.EYE.size() + 2) ## overhead_bar.gd _time_icon_lift ile aynı formül
	assert(absf(icon.position.y - (OverheadBarScript.CHARACTER_Y_OFFSET - TimeIconScript.GAP - lift)) < 0.01, "göz simgesinin üstünde: %s" % icon.position.y)
	bar.set_time_frozen(false)
	assert(not icon.shown, "güvenli alandan çıkınca simge kapanır")
	_cleanup()


func test_local_and_remote_player_sync_hourglass_with_safe_zone() -> void:
	var player: Node = _make_player(1)
	player._sync_safe_zone_icon()
	assert(player.overhead_bar.get_node_or_null("TimeFrozenIcon") == null, "açık haritada simge yok")
	player.is_in_merchant_zone = true
	player._sync_safe_zone_icon()
	var icon = player.overhead_bar.get_node_or_null("TimeFrozenIcon")
	assert(icon != null and icon.shown, "satıcı bölgesinde kendi barında kum saati")
	player.is_in_merchant_zone = false
	player._sync_safe_zone_icon()
	assert(not icon.shown, "bölgeden çıkınca kapanır")
	var rp: Node = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.global_position = Vector2(1000.0, 1000.0)
	assert(not rp.is_safe_zone_frozen(), "kukla açık haritada serbest")
	rp.is_in_merchant_zone = true
	assert(rp.is_safe_zone_frozen(), "kukla satıcı bölgesinde donuk (anlık görüntüden)")
	rp.is_in_merchant_zone = false
	rp.global_position = WeaponShopScript.INTERIOR_OFFSET + Vector2(30.0, 30.0)
	assert(rp.is_safe_zone_frozen(), "kukla demirci iç mekanında donuk (konumdan)")
	rp._sync_safe_zone_icon()
	var rp_icon = rp.overhead_bar.get_node_or_null("TimeFrozenIcon")
	assert(rp_icon != null and rp_icon.shown, "arkadaşların barında da kum saati görünür")
	_cleanup()


func test_status_row_lists_time_frozen_debuff_with_tooltip_text() -> void:
	var player: Node = _make_player(1)
	var ids: Array = []
	for e in player.get_status_effects():
		ids.append(e["id"])
	assert(not ids.has("time_frozen"), "açık haritada rozet yok")
	player.is_in_merchant_zone = true
	var entry: Dictionary = {}
	for e in player.get_status_effects():
		if e["id"] == "time_frozen":
			entry = e
	assert(not entry.is_empty() and entry["kind"] == "time_frozen" and entry["is_buff"] == false, "güvenli alanda debuff satırında 'Zaman Durdu' rozeti")
	assert(float(entry["remaining"]) < 0.0, "süresiz (alandan çıkana kadar)")
	assert(BadgeScript.INFO.has("time_frozen") and str(BadgeScript.INFO["time_frozen"][1]).contains("pasif") and str(BadgeScript.INFO["time_frozen"][1]).contains("evcil"), "ipucu pasif + evcil dahil ne durduğunu söyler")
	assert(FileAccess.file_exists("res://assets/ui/status/time_frozen.png"), "rozet ikon dosyası var (editör açılınca içe aktarılır)")
	player.is_in_merchant_zone = false
	var after: Array = []
	for e in player.get_status_effects():
		after.append(e["id"])
	assert(not after.has("time_frozen"), "alandan çıkınca rozet kalkar")
	_cleanup()
