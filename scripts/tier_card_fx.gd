extends RefCounted

## Tier SAVAŞ kartlarının (assets/ui/game/tier_card_1..4.png, tools/gen_menu_kit.py tier_card) ortak yerleşimi + ışıltısı.
## Kullanıcı isteği (2026-09-25): kartlar tamamen tier renginde, savaşla ilgili (kılıçlı arma, kurdele, perçinli metal çerçeve)
## ve "bir kartı seçince parıltı ve ödüllendirici bir ses efekti çıksın ve 1 saniye boyunca kart parıldasın sonrasında level
## kart seçim ekranı kapansın". Level atlama (level_up_screen.gd) ve sandık ödülü (chest_menu.gd) kartları AYNI dokuyu
## kullandığı için bölge ölçüleri TEK yerde: dokudaki kalkan arması / kurdele / parşömen levha bu dikdörtgenlerle hizalı
## (sanat px x 3; tools/gen_menu_kit.py CARD_CREST_* / CARD_RIBBON_* / CARD_PLAQUE_* ile eşleşir - birini değiştiren ikisini de
## değiştirmeli).

const CARD_SIZE := Vector2(300, 480)
## Üst satır (level kartında kategori, sandıkta eşya adı): koyu tier zemini üstünde krem yazı.
const HEADER_RECT := Rect2(24, 21, 252, 33)
## Kalkan armasının parşömen yüzü - ikon bunun ortasına oturur (merkez y = 41 sanat px = 123 ekran px).
const CREST_CENTER := Vector2(150, 123)
## Tier adı kurdelesinin ön şeridi (sanat px 17..82 x, 67..79 y) - yazı alanı çerçeve konturunun içi.
const RIBBON_RECT := Rect2(54, 201, 192, 39)
## Parşömen açıklama levhası (sanat px 9..90 x, 83..151 y) - İÇ yazı alanı (metal kenar + koyu çizgi payı düşülmüş).
const PLAQUE_INNER_RECT := Rect2(42, 263, 216, 179)

## Tier başına parıltı rengi (seçim halesi + kıvılcımlar): Sıradan pirinç, Nadir mavi, Epik mor, Efsanevi altın.
const GLOW_COLORS := [Color("#ffd98a"), Color("#9cc4ff"), Color("#dcb0ff"), Color("#ffc65a")]
## Boşta ışıltı: tier 2+ kartların üstünden ara ara geçen parlama (üst tier daha sık/parlak - "heyecan" ama göz yormadan).
const IDLE_SHINE_INTERVAL := [0.0, 4.2, 3.2, 2.4]
const IDLE_SHINE_STRENGTH := [0.0, 0.16, 0.22, 0.3]
const SHINE_SWEEP_TIME := 0.6

const PICK_DURATION := 1.0
const PICK_SOUND := preload("res://assets/audio/card_pick.wav")
const GLOW_TEXTURE := preload("res://assets/ui/game/tier_card_glow.png")
const SHINE_SHADER := preload("res://shaders/tier_card_shine.gdshader")
const SparklesScript := preload("res://scripts/ui_pixel_sparkles.gd")
## Hale dokusu kartın her yanından 5 sanat px (15 ekran px) taşar (bkz. gen_menu_kit.py tier_card_glow pad).
const GLOW_PAD := 15.0


## Frame'e tier dokusunu + ışıltı shader'ını (kart başına AYRI materyal - uniform'lar kartlar arasında paylaşılmasın) verir.
static func apply_frame(frame: TextureRect, tier: int) -> void:
	if not is_instance_valid(frame):
		return
	frame.texture = TierSystem.FRAME_TEXTURES[clampi(tier, 1, 4) - 1]
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := frame.material as ShaderMaterial
	if mat == null or mat.shader != SHINE_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = SHINE_SHADER
		frame.material = mat
	mat.set_shader_parameter("shine_pos", -1.0)
	mat.set_shader_parameter("shine_strength", 0.0)
	mat.set_shader_parameter("flash", 0.0)


static func _set_param(frame: TextureRect, param: String, value: float) -> void:
	if is_instance_valid(frame) and frame.material is ShaderMaterial:
		(frame.material as ShaderMaterial).set_shader_parameter(param, value)


## Tier 2+ için sonsuz döngülü boşta parlama. Dönen tween'i çağıran tutar ve yeniden çekilişte/seçimde öldürür.
static func start_idle_shine(owner: Node, frame: TextureRect, tier: int, first_delay: float = 0.0) -> Tween:
	var t: int = clampi(tier, 1, 4)
	if t <= 1 or not is_instance_valid(frame):
		return null
	_set_param(frame, "shine_strength", IDLE_SHINE_STRENGTH[t - 1])
	var tw: Tween = owner.create_tween().set_loops()
	tw.tween_interval(first_delay + 0.01)
	tw.tween_method(func(v: float) -> void: _set_param(frame, "shine_pos", v), -0.15, 1.15, SHINE_SWEEP_TIME)
	tw.tween_interval(maxf(0.1, IDLE_SHINE_INTERVAL[t - 1] - SHINE_SWEEP_TIME - first_delay))
	return tw


## Kartın ışıltı rengi: kart "glow_colors" meta'sı verdiyse o (level atlama satırlarında Tier 1 gri/gümüş), yoksa GLOW_COLORS.
static func glow_color(card: Node, tier: int) -> Color:
	var cols: Array = card.get_meta("glow_colors", GLOW_COLORS)
	return cols[clampi(tier, 1, 4) - 1]


## Kartın dışına taşan hale (kartın çocuğu, Frame'in hemen üstünde). Kart clip_contents'i kapatılır ki hale kırpılmasın.
## Hale dokusu/kart boyutu kart başına "glow_texture" / "glow_card_size" meta'larıyla değiştirilebilir (level atlama
## satırları 804x150 - bkz. level_up_screen.gd _layout_rows); verilmezse savaş kartının 300x480 silüeti.
static func ensure_glow(card: Control) -> TextureRect:
	var glow: TextureRect = card.get_node_or_null("PickGlow") as TextureRect
	if glow:
		return glow
	card.clip_contents = false
	glow = TextureRect.new()
	glow.name = "PickGlow"
	glow.texture = card.get_meta("glow_texture", GLOW_TEXTURE)
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.position = Vector2(-GLOW_PAD, -GLOW_PAD)
	glow.size = (card.get_meta("glow_card_size", CARD_SIZE) as Vector2) + Vector2(GLOW_PAD, GLOW_PAD) * 2.0
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	glow.modulate = Color(1, 1, 1, 0)
	card.add_child(glow)
	var frame: Node = card.get_node_or_null("Frame")
	card.move_child(glow, (frame.get_index() + 1) if frame else 0)
	return glow


## Fare üstündeyken hafif hale (seçim halesinin sönük hali).
static func set_hover_glow(card: Control, tier: int, on: bool) -> void:
	var glow := ensure_glow(card)
	var c: Color = glow_color(card, tier)
	glow.modulate = Color(c.r, c.g, c.b, 0.32 if on else 0.0)


## Seçim kutlaması (PICK_DURATION): ödül sesi, beyaz-altın parlama, kartın hafifçe büyüyüp oturması, nabız gibi atan hale,
## kartın üstünden hızlı bir parlama geçişi ve dışa saçılan piksel kıvılcımlar. Dönen tween PICK_DURATION sonunda biter -
## ekranı kapatma işini çağıran onun sonuna ekler (owner'a bağlı: ekran serbest kalırsa tween de kendiliğinden ölür).
static func celebrate(owner: Node, card: Control, frame: TextureRect, tier: int, fx_parent: Control) -> Tween:
	var t: int = clampi(tier, 1, 4)
	var col: Color = glow_color(card, t)
	var player := AudioStreamPlayer.new()
	player.stream = PICK_SOUND
	player.volume_db = -3.0
	player.pitch_scale = 1.0 + 0.03 * float(t - 1)
	owner.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

	card.pivot_offset = card.size * 0.5
	card.z_index = 5
	var glow := ensure_glow(card)
	glow.modulate = Color(col.r, col.g, col.b, 0.0)
	_set_param(frame, "shine_strength", 0.3)

	var tw: Tween = owner.create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(v: float) -> void: _set_param(frame, "flash", v), 0.85, 0.0, 0.35)
	tw.tween_property(card, "scale", Vector2(1.09, 1.09), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(1.05, 1.05), 0.25).set_delay(0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(glow, "modulate:a", 1.0, 0.1)
	tw.tween_property(glow, "modulate:a", 0.5, 0.22).set_delay(0.1)
	tw.tween_property(glow, "modulate:a", 1.0, 0.22).set_delay(0.32)
	tw.tween_property(glow, "modulate:a", 0.55, 0.22).set_delay(0.54)
	tw.tween_property(glow, "modulate:a", 0.95, 0.2).set_delay(0.76)
	tw.tween_method(func(v: float) -> void: _set_param(frame, "shine_pos", v), -0.15, 1.15, 0.45).set_delay(0.08)
	tw.tween_interval(PICK_DURATION)

	if is_instance_valid(fx_parent):
		var sparkles := Control.new()
		sparkles.set_script(SparklesScript)
		sparkles.name = "PickSparkles"
		sparkles.set_anchors_preset(Control.PRESET_FULL_RECT)
		fx_parent.add_child(sparkles)
		var rect := Rect2(fx_parent.get_global_transform().affine_inverse() * card.get_global_rect().position, card.get_global_rect().size)
		sparkles.call("burst", rect, [col, Color(1, 0.96, 0.8), col.lightened(0.35)], 30, 14, PICK_DURATION)
	return tw
