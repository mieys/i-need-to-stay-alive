extends RefCounted

## SANDIKTAN FIRLAYAN ÖDÜL KARTI - normal sandık (chest_menu.gd) ve elit sandık (enchant_screen.gd intro_chest) ortak
## hareketi ve iniş parıltısı. Kullanıcı isteği (2026-09-25): "sandıklar açıldığında kart içinden fırlamış gibi görünmüyor
## ayrıca kartın parıltılı ve ödüllendirici gözükmesi gerekiyor elitte daha da ödüllendirici".
## Sıra: sandığın kapağı patladığı an (chest_open_anim.gd burst) kart sandığın ağzından küçük ve saydam çıkar, yukarı fırlar
## (hedefinin biraz üstüne, hafif eğilerek), düşüp yerine oturur; indiği an beyaz-altın flaş, çapraz parlama, piksel
## kıvılcımlar ve arkasındaki ışık huzmeleri (reward_rays.gd) yanar. Kartın son konumu kapsayıcı yerleşiminden gelir: fly_out
## çağrılmadan önce kart yerleşmiş olmalı (bir kare beklenir) - hareket bitince tam o konuma döner.

const SparklesScript := preload("res://scripts/ui_pixel_sparkles.gd")
const RewardRays := preload("res://scripts/reward_rays.gd")
const LAND_SOUND := preload("res://assets/audio/card_pick.wav")
const RISE_TIME := 0.32
const FALL_TIME := 0.2
const SETTLE_TIME := 0.16
const APEX_LIFT := 90.0


static func tier_color(tier: int) -> Color:
	return RewardRays.TIER_COLORS[clampi(tier, 1, 5) - 1]


## Sandık animasyonunun (chest_open_anim.gd) ağzı - açık kutunun üst kenarı, karenin ortasının biraz altı.
static func chest_mouth(chest: Control) -> Vector2:
	var r: Rect2 = chest.get_global_rect()
	return r.position + r.size * Vector2(0.5, 0.52)


## Kartı from_global noktasından fırlatıp şu anki (yerleşmiş) konumuna indirir. Dönen tween inişte biter.
## spin: fırlarken hafif eğilme (radyan, işaret yönü), kart yere inince 0'a döner. pivot: büyüme/dönme merkezi (yerel;
## verilmezse düğümün ortası) - sandığın ağzına bu nokta oturur (sandık kartında AL/SAT satırları altta, merkez kartın ortası).
static func fly_out(owner: Node, card: Control, from_global: Vector2, delay: float = 0.0, spin: float = 0.1, pivot: Vector2 = Vector2(-1, -1)) -> Tween:
	var final_pos: Vector2 = card.position
	var final_scale: Vector2 = card.scale
	card.pivot_offset = card.size * 0.5 if pivot.x < 0.0 else pivot
	var parent: CanvasItem = card.get_parent() as CanvasItem
	var start_local: Vector2 = parent.get_global_transform().affine_inverse() * from_global if parent else from_global
	var apex: Vector2 = final_pos + Vector2(0.0, -APEX_LIFT)
	card.position = start_local - card.pivot_offset
	card.scale = final_scale * 0.12
	card.rotation = 0.0
	card.modulate.a = 0.0
	var tw: Tween = owner.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(card, "modulate:a", 1.0, 0.07)
	tw.parallel().tween_property(card, "position", apex, RISE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	## Yükselirken önce küçük kalır (sandığın ağzından çıktığı okunsun), büyümesi sona doğru hızlanır.
	tw.parallel().tween_property(card, "scale", final_scale * 0.8, RISE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(card, "rotation", spin, RISE_TIME)
	tw.tween_property(card, "position", final_pos, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(card, "rotation", 0.0, FALL_TIME)
	tw.parallel().tween_property(card, "scale", final_scale * 1.06, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", final_scale, SETTLE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


## İniş parıltısı: kart çerçevesinde flaş + çapraz parlama (tier_card_shine shader'ı), çevreye piksel kıvılcımlar, ışığın
## açılması ve (tier 3+ / elit) hafif ses. rays null olabilir. fx_parent: kıvılcımların çizileceği tam ekran Control.
static func land_fx(owner: Node, card: Control, frame: TextureRect, tier: int, elite: bool, fx_parent: Control, rays: Node) -> void:
	var t: int = clampi(tier, 1, 5)
	var col: Color = tier_color(t)
	if is_instance_valid(frame) and frame.material is ShaderMaterial:
		var mat := frame.material as ShaderMaterial
		## Boşta parlama döngüsünün (TierCardFx.start_idle_shine) gücü iniş parlamasından sonra geri gelir.
		var idle_strength: float = float(mat.get_shader_parameter("shine_strength"))
		mat.set_shader_parameter("shine_strength", 0.35)
		var tw: Tween = owner.create_tween()
		tw.tween_method(func(v: float) -> void:
			if is_instance_valid(frame):
				mat.set_shader_parameter("flash", v)
		, 0.9, 0.0, 0.4)
		tw.parallel().tween_method(func(v: float) -> void:
			if is_instance_valid(frame):
				mat.set_shader_parameter("shine_pos", v)
		, -0.15, 1.15, 0.5).set_delay(0.05)
		tw.tween_callback(func() -> void:
			if is_instance_valid(frame):
				mat.set_shader_parameter("shine_strength", idle_strength)
		)
	if is_instance_valid(rays):
		rays.set("fade", 0.0)
		var rt: Tween = owner.create_tween()
		rt.tween_property(rays, "fade", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	if is_instance_valid(fx_parent):
		var g: Rect2 = card.get_global_rect()
		var rect := Rect2(fx_parent.get_global_transform().affine_inverse() * g.position, g.size)
		var count: int = 14 + 8 * t
		var twinkles: int = 6 + 4 * t
		var colors: Array = [col, Color(1, 0.96, 0.8), col.lightened(0.35)]
		if elite:
			count = int(count * 1.6)
			twinkles = int(twinkles * 1.6)
			colors.append(RewardRays.ELITE_COLOR)
		_sparkles(fx_parent, rect, colors, count, twinkles, 1.2 if elite else 0.9)
	if t >= 3 or elite:
		var p := AudioStreamPlayer.new()
		p.stream = LAND_SOUND
		p.volume_db = -10.0 + float(t)
		p.pitch_scale = 1.0 + 0.04 * float(t - 1)
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		owner.add_child(p)
		p.play()
		p.finished.connect(p.queue_free)


## Sandığın ağzından fırlama anında yukarı saçılan kıvılcımlar (kartın izi).
static func launch_sparks(fx_parent: Control, from_global: Vector2, tier: int, elite: bool) -> void:
	if not is_instance_valid(fx_parent):
		return
	var local: Vector2 = fx_parent.get_global_transform().affine_inverse() * from_global
	var colors: Array = [tier_color(tier), Color(1, 0.96, 0.8)]
	if elite:
		colors.append(RewardRays.ELITE_COLOR)
	_sparkles(fx_parent, Rect2(local - Vector2(40, 10), Vector2(80, 20)), colors, 22 if elite else 14, 4, 0.6)


## Kıvılcım düğümü işini bitirince kendini gizliyor ama ağaçta kalıyor - süre sonunda temizlenir.
static func _sparkles(fx_parent: Control, rect: Rect2, colors: Array, count: int, twinkles: int, duration: float) -> void:
	var sparkles := Control.new()
	sparkles.set_script(SparklesScript)
	sparkles.set_anchors_preset(Control.PRESET_FULL_RECT)
	sparkles.process_mode = Node.PROCESS_MODE_ALWAYS
	fx_parent.add_child(sparkles)
	sparkles.call("burst", rect, colors, count, twinkles, duration)
	## Temizlik zamanlayıcısı düğümün ÇOCUĞU: ekran önce kapanırsa onunla birlikte gider (SceneTreeTimer + lambda serbest
	## bırakılmış düğümü yakalayıp "Lambda capture was freed" hatası veriyordu).
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = duration + 1.0
	t.process_mode = Node.PROCESS_MODE_ALWAYS
	t.autostart = true
	sparkles.add_child(t)
	t.timeout.connect(sparkles.queue_free)
