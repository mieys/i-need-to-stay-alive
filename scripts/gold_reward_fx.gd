extends CanvasLayer

## Slot makinesi gibi altın ödülü (kullanıcı isteği 2026-10-02): "karakter sandık açtığında görev tamamladığında v.b altın
## miktarındaki barının slot oyunlarındaki gibi altınla dolmasını istiyorum. yani sandığı alınca sandıktan çıkan altınlar
## ordan sol üstteki altın paneline doğru gitsin ve altını yavaşça arttırsın bu esnada oyundaki altın toplama sesi
## spamlansın üst üste." + aynı gün: "sandıktan para paneline doğru gitmesini istiyorum. görev tamamlanınca da görev
## tamamlandı penceresi açılmasını ve o pencereden aynı şekilde para paneline gitmesini istiyorum".
##
## Altın GameManager.gold'a HEMEN eklenir (harcama, testler, ağ eskisi gibi çalışır); HUD sayacı (hud.gd) ise
## display_gold() okur = henüz panele varmamış paralar (_pending) hariç. Her para vardığında payı sayaca akar, sayı
## tıkır tıkır yükselir ve altın toplama sesi (gold_drop.tscn ile aynı dosya/ses seviyesi) üst üste çalar.
##
## Kullanım (altını ekleyen de bu çağrılar):
##   GoldRewardFx.give(get_tree(), miktar, dünya_konumu)                 # boss payı, Para ruhani yeteneği, hediye
##   GoldRewardFx.give_from_screen(get_tree(), miktar, ekran_konumu, &"chest" / &"elite_chest")
##       # sandık: kaynak noktada açık bir sandık belirir, paralar onun ağzından fışkırır (sandık ekranındaki sandığın yeri)
##   GoldRewardFx.hold(get_tree(), miktar, &"mission", yedek_dünya_konumu) + release(&"mission", ekran_konumu)
##       # görev: altın hemen eklenir ama paralar "Görev Tamamlandı" penceresi açılınca ondan fırlar
##       # (mission_complete_window.gd); pencere HOLD_TIMEOUT içinde gelmezse yedek konumdan fırlar.
## Düşman altınları (gold_drop.gd, papağan) bunu KULLANMAZ - onlar zaten dünyada oyuncuya uçuyor.
## Oyun duraklatılmışken (sandık/efsun ekranı açık) paralar bekler, ekran kapanınca fırlar - give_now_from_screen hariç
## (sandık altını: kart inince duraklatılmış ekranın üstünden hemen fırlar, HUD sayacı da burada güncellenir).

const COIN_FRAMES := preload("res://assets/pickups/gold/gold_coin_frames.tres")
const PICKUP_SOUND := preload("res://assets/audio/gold_pickup.mp3")
const SOUND_DB := -10.0 ## gold_drop.tscn PickupSound ile aynı
const MAX_VOICES := 12
const LAYER := 41 ## HUD (1) ve sohbetin (40) üstünde, modal ekranların (90+) altında

const COIN_SCALE := 2.0 ## 16 px para -> 32 px (HUD ikonları ~28 px)
const MIN_COINS := 3
const MAX_COINS := 24
const LAUNCH_GAP := 0.045 ## paralar arası fırlama aralığı -> sesler de bu sıklıkta üst üste biner
const FLIGHT_TIME := 0.62
const SPRAY_DIST := 70.0 ## önce kaynağın çevresine saçılır, sonra panele kıvrılır
const HOLD_TIMEOUT := 3.0

## Sandık kaynağı: chest_open_anim.gd'nin sayfası (20 kare x 48 px; 12 = kapak açıldı, 16-19 açık bekleme döngüsü).
const CHEST_SHEETS := {
	&"chest": preload("res://assets/sprites/chests/chest_normal_t1.png"),
	&"elite_chest": preload("res://assets/sprites/chests/chest_elite.png"),
}
const CHEST_FRAMES := 20
const CHEST_OPEN_FRAME := 12
const CHEST_LOOP := [16, 17, 18, 19]
const CHEST_LOOP_STEP := 0.12
const CHEST_SCALE := 5.0
const CHEST_POP_TIME := 0.2 ## sandık belirdikten sonra ilk para bu kadar sonra fışkırır
const CHEST_COINS_SFX := preload("res://Sound FX Starter Pack Vol. 1/Medieval/Loot Gold.wav")

static var _inst: Node = null

var _rewards: Array = [] ## henüz fırlamamış: {amount, from, world, source}
var _held: Dictionary = {} ## anahtar -> {amount, fallback, t}
var _coins: Array = [] ## uçanlar: {node, p0, p1, t, dur, share, idx}
var _chests: Array = [] ## {node, t, life}
var _pending: int = 0
var _shown: float = 0.0
## Panele VARAN uçan paraların henüz sayaca akmamış kısmı (tıkır tıkır sayılır). Kullanıcı isteği (2026-10-02): "karakter
## altın toplayınca topladığımız altının hemen altın barına gitmesini istiyorum gecikmeli değil" - yerden toplanan altın,
## hediye vb. doğrudan eklenen her şey sayaca ANINDA yansır; sadece uçan ödül paraları yavaşça sayılır.
var _count_left: float = 0.0
var _voices: Array[AudioStreamPlayer] = []
var _voice_i: int = 0
var _launch_cd: float = 0.0
var _pulse_tw: Tween = null


static func give(tree: SceneTree, amount: int, from_world: Vector2) -> void:
	_give(tree, amount, from_world, true, &"")


## Oyun duraklatılmış olsa bile hemen fırlar (sandık/efsun ekranındaki kartın yerinden, bkz. chest_menu.gd).
static func give_now_from_screen(tree: SceneTree, amount: int, from_screen: Vector2) -> void:
	_give(tree, amount, from_screen, false, &"", true)


static func give_from_screen(tree: SceneTree, amount: int, from_screen: Vector2, source: StringName = &"") -> void:
	_give(tree, amount, from_screen, false, source)


## Altını hemen ekler, paraları release() gelene kadar tutar (görev penceresi). Aynı anahtarda birikir.
static func hold(tree: SceneTree, amount: int, key: StringName, fallback_world: Vector2) -> void:
	if amount <= 0:
		return
	var inst: Node = _ensure(tree)
	GameManager.gold += amount
	if inst != null:
		inst.call("_add_held", amount, key, fallback_world)


static func held_amount(key: StringName) -> int:
	if _inst != null and is_instance_valid(_inst):
		return int(_inst.call("_held_amount", key))
	return 0


static func release(key: StringName, from_screen: Vector2) -> void:
	if _inst != null and is_instance_valid(_inst):
		_inst.call("_release", key, from_screen)


## HUD altın sayacının göstereceği değer (yolda olan paralar hariç).
static func display_gold() -> int:
	if _inst != null and is_instance_valid(_inst):
		return int(_inst.call("_display_value"))
	return GameManager.gold


static func _give(tree: SceneTree, amount: int, from: Vector2, world: bool, source: StringName, now: bool = false) -> void:
	if amount <= 0:
		return
	var inst: Node = _ensure(tree)
	GameManager.gold += amount
	if inst == null:
		return
	inst.call("_add_reward", amount, from, world, source, now)


static func _ensure(tree: SceneTree) -> Node:
	if _inst != null and is_instance_valid(_inst) and _inst.is_inside_tree():
		return _inst
	if tree == null or tree.current_scene == null or DisplayServer.get_name() == "headless":
		return null
	var node: CanvasLayer = (load("res://scripts/gold_reward_fx.gd") as GDScript).new()
	node.name = "GoldRewardFx"
	tree.current_scene.add_child(node)
	_inst = node
	return node


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shown = float(GameManager.gold)
	for i in MAX_VOICES:
		var v := AudioStreamPlayer.new()
		v.stream = PICKUP_SOUND
		v.volume_db = SOUND_DB
		add_child(v)
		_voices.append(v)


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


func _add_reward(amount: int, from: Vector2, world: bool, source: StringName, now: bool = false) -> void:
	_pending += amount
	_rewards.append({"amount": amount, "from": from, "world": world, "source": source, "now": now})


func _add_held(amount: int, key: StringName, fallback_world: Vector2) -> void:
	_pending += amount
	var h: Dictionary = _held.get(key, {"amount": 0, "fallback": fallback_world, "t": 0.0})
	h["amount"] = int(h["amount"]) + amount
	_held[key] = h


func _held_amount(key: StringName) -> int:
	return int((_held.get(key, {}) as Dictionary).get("amount", 0))


## Tutulan paralar pencereden fırlar (_pending zaten sayılmıştı - _add_reward'ı tekrar saymadan sıraya alır).
func _release(key: StringName, from_screen: Vector2) -> void:
	if not _held.has(key):
		return
	var h: Dictionary = _held[key]
	_held.erase(key)
	_rewards.append({"amount": int(h["amount"]), "from": from_screen, "world": false, "source": &""})


func _display_value() -> int:
	return int(floor(_shown + 0.001))


func _process(delta: float) -> void:
	## Harcama yolda olan altını da yediyse (çok nadir) sayaç eksiye düşmesin.
	_pending = mini(_pending, GameManager.gold)
	for key in _held.keys():
		var h: Dictionary = _held[key]
		h["t"] = float(h["t"]) + delta
		if float(h["t"]) >= HOLD_TIMEOUT:
			_held.erase(key)
			_rewards.append({"amount": int(h["amount"]), "from": h["fallback"], "world": true, "source": &""})
	var paused: bool = get_tree().paused
	_launch_cd -= delta
	while _launch_cd <= 0.0:
		var idx: int = _next_launchable(paused)
		if idx < 0:
			break
		_launch_reward(_rewards.pop_at(idx))
	_update_chests(delta)
	_update_coins(delta)
	var target: float = float(maxi(0, GameManager.gold - _pending))
	_count_left = clampf(_count_left, 0.0, target)
	if _count_left > 0.0:
		_count_left = move_toward(_count_left, 0.0, maxf(24.0 * delta, _count_left * 9.0 * delta))
	_shown = target - _count_left
	## HUD duraklatılınca kendi _process'i durur - sandık ekranı açıkken sayaç buradan yükselir.
	if paused:
		var scene: Node = get_tree().current_scene
		var hud: Node = scene.get_node_or_null("HUD") if scene else null
		if hud and "gold_indicator_label" in hud:
			var lbl: Label = hud.get("gold_indicator_label") as Label
			if lbl:
				lbl.text = str(_display_value())


## Duraklatılmışken sadece "now" (sandık kartı) ödülleri fırlar; diğerleri ekran kapanınca sırayla.
func _next_launchable(paused: bool) -> int:
	if not paused:
		return 0 if not _rewards.is_empty() else -1
	for i in range(_rewards.size()):
		if bool((_rewards[i] as Dictionary).get("now", false)):
			return i
	return -1


func _launch_reward(r: Dictionary) -> void:
	var amount: int = int(r["amount"])
	var from: Vector2 = r["from"]
	if bool(r["world"]):
		from = get_viewport().get_canvas_transform() * from
	var n: int = clampi(int(round(sqrt(float(amount)) * 2.5)), MIN_COINS, MAX_COINS)
	n = mini(n, amount)
	var base_share: int = amount / n
	var extra: int = amount % n
	var lead: float = 0.0
	var source: StringName = r.get("source", &"")
	if CHEST_SHEETS.has(source):
		_spawn_chest(source, from, CHEST_POP_TIME + LAUNCH_GAP * float(n) + 0.45)
		lead = CHEST_POP_TIME
	for i in n:
		var coin := AnimatedSprite2D.new()
		coin.sprite_frames = COIN_FRAMES
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		coin.scale = Vector2.ONE * COIN_SCALE
		coin.position = from
		coin.visible = false
		coin.play("spin")
		coin.frame = randi() % maxi(1, COIN_FRAMES.get_frame_count("spin"))
		add_child(coin)
		var ang: float = randf_range(-PI * 0.95, -PI * 0.05) ## çoğunlukla yukarı/yana saçılır
		var spray: Vector2 = Vector2(cos(ang), sin(ang)) * SPRAY_DIST * randf_range(0.6, 1.25)
		_coins.append({
			"node": coin, "p0": from + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)), "p1": from + spray,
			"t": -lead - LAUNCH_GAP * float(i), "dur": FLIGHT_TIME * randf_range(0.9, 1.15),
			"share": base_share + (1 if i < extra else 0), "idx": i,
		})
	## Bir sonraki ödül bu partinin fırlaması bitince başlar (aynı anda gelen iki ödül iç içe geçmesin).
	_launch_cd = lead + LAUNCH_GAP * float(n)


## Kaynak noktada açık bir sandık belirir (sandık ekranındaki sandığın küçük hali), paralar ağzından fışkırır, sonra
## aşağı kayarak söner (chest_menu.gd _hide_chest ile aynı çıkış).
func _spawn_chest(source: StringName, at: Vector2, life: float) -> void:
	var spr := Sprite2D.new()
	spr.texture = CHEST_SHEETS[source]
	spr.hframes = CHEST_FRAMES
	spr.frame = CHEST_OPEN_FRAME
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = at
	spr.scale = Vector2.ONE * CHEST_SCALE * 0.7
	spr.modulate.a = 0.0
	add_child(spr)
	move_child(spr, 0) ## paraların arkasında
	_chests.append({"node": spr, "t": 0.0, "life": life, "y": at.y})
	var sfx := AudioStreamPlayer.new()
	sfx.stream = CHEST_COINS_SFX
	sfx.volume_db = -8.0
	add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	get_tree().create_timer(CHEST_POP_TIME, true).timeout.connect(func() -> void:
		if is_instance_valid(sfx):
			sfx.play())


func _update_chests(delta: float) -> void:
	var i: int = 0
	while i < _chests.size():
		var c: Dictionary = _chests[i]
		var spr: Sprite2D = c["node"]
		c["t"] = float(c["t"]) + delta
		var t: float = c["t"]
		var life: float = c["life"]
		if t >= life + 0.35 or not is_instance_valid(spr):
			if is_instance_valid(spr):
				spr.queue_free()
			_chests.remove_at(i)
			continue
		var pop: float = clampf(t / CHEST_POP_TIME, 0.0, 1.0)
		var back: float = 1.0 + 2.7 * pow(pop - 1.0, 3.0) + 1.7 * pow(pop - 1.0, 2.0) ## easeOutBack
		spr.scale = Vector2.ONE * CHEST_SCALE * lerpf(0.7, 1.0, back)
		spr.modulate.a = pop
		if t >= CHEST_POP_TIME:
			spr.frame = CHEST_LOOP[int((t - CHEST_POP_TIME) / CHEST_LOOP_STEP) % CHEST_LOOP.size()]
		if t > life:
			var k: float = clampf((t - life) / 0.35, 0.0, 1.0)
			spr.modulate.a = 1.0 - k
			spr.position.y = float(c["y"]) + 40.0 * k * k
		i += 1


func _update_coins(delta: float) -> void:
	if _coins.is_empty():
		return
	var target: Vector2 = _panel_target()
	var i: int = 0
	while i < _coins.size():
		var c: Dictionary = _coins[i]
		c["t"] = float(c["t"]) + delta
		var node: AnimatedSprite2D = c["node"]
		if float(c["t"]) < 0.0:
			i += 1
			continue
		var k: float = clampf(float(c["t"]) / float(c["dur"]), 0.0, 1.0)
		## Önce hızlı saçılma, sonra hızlanarak panele dalış (ikinci dereceden Bezier, kontrol = saçılma noktası).
		var e: float = k * k * (3.0 - 2.0 * k)
		var a: Vector2 = (c["p0"] as Vector2).lerp(c["p1"], e)
		var b: Vector2 = (c["p1"] as Vector2).lerp(target, e)
		node.position = a.lerp(b, e)
		node.visible = true
		node.scale = Vector2.ONE * COIN_SCALE * lerpf(1.0, 0.75, k)
		if k >= 1.0:
			_arrive(c)
			node.queue_free()
			_coins.remove_at(i)
			continue
		i += 1


func _arrive(c: Dictionary) -> void:
	_pending = maxi(0, _pending - int(c["share"]))
	_count_left += float(c["share"])
	var v: AudioStreamPlayer = _voices[_voice_i]
	_voice_i = (_voice_i + 1) % _voices.size()
	## Slot makinesi hissi: parti ilerledikçe ses hafifçe tizleşir.
	v.pitch_scale = 1.0 + 0.012 * float(mini(int(c["idx"]), 16)) + randf_range(-0.03, 0.04)
	v.play()
	_pulse_panel()


func _gold_panel() -> Control:
	var scene: Node = get_tree().current_scene
	var hud: Node = scene.get_node_or_null("HUD") if scene else null
	if hud == null or not ("gold_indicator" in hud):
		return null
	return hud.get("gold_indicator") as Control


func _panel_target() -> Vector2:
	var panel: Control = _gold_panel()
	if panel == null or not panel.is_visible_in_tree():
		return Vector2(80.0, 140.0)
	var icon: Control = panel.get_node_or_null("GoldMargin/GoldHBox/Icon") as Control
	var ref: Control = icon if icon else panel
	return ref.get_global_transform_with_canvas() * (ref.size * 0.5)


func _pulse_panel() -> void:
	var panel: Control = _gold_panel()
	if panel == null:
		return
	if _pulse_tw and _pulse_tw.is_valid():
		_pulse_tw.kill()
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * 1.08
	panel.modulate = Color(1.25, 1.18, 0.9)
	_pulse_tw = panel.create_tween().set_parallel(true)
	_pulse_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_pulse_tw.tween_property(panel, "scale", Vector2.ONE, 0.14)
	_pulse_tw.tween_property(panel, "modulate", Color.WHITE, 0.18)
