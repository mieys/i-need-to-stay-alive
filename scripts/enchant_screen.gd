extends CanvasLayer

## EFSUN EKRANI (tasarım belgesi "Efsun ekranı akışı"). Kullanıcının efsun sistemi için sakladığı "A9 - İpucu Tarzı" koyu
## kart (hafıza: project-enchant-system-card-style) - doku tools/gen_enchant_card.py (360x540, 3 ekran px = 1 sanat px).
## Kart 4x ölçekte (480x720 - 120x180 sanat pikseli, tam sayı ölçek): açık metinler (efsun ne yapar / bu kart ne verir /
## efsun gücü önce -> sonra / Final eşyası) 3x kartın dar metin alanına sığmıyordu (kullanıcı: "açıklamalar belirsiz").
## Tamamen kodla kurulur (sahne dosyası yok - açık editör .tscn'yi eski hâliyle ezemesin). main.gd açar; seçim
## enchant_chosen ile döner ({"type": "skip"} = geç). Oyun zaten duraklatılmış (process_mode ALWAYS).
## Kısayollar level ekranıyla aynı: 1/2/3 kart, Space karıştır. Çok oyunculuda level ekranının 25 sn geri sayımı kullanılır.
## Elit sandıktan açılınca (intro_chest, main.gd _show_elite_chest) ekran önce elit sandığın açılış animasyonunu kendisi
## oynatır; kapak patlayınca üç kart sandığın ağzından yelpaze gibi fırlayıp yerlerine iner (reward_reveal.gd), arkalarında
## tier'a göre ışık huzmeleri yanar (reward_rays.gd - elitte daha parlak + mor hale). Kullanıcı isteği 2026-09-25: "kart
## içinden fırlamış gibi görünmüyor ... elitte daha da ödüllendirici gözükmesi gerekiyor".

signal enchant_chosen(choice: Dictionary)

const EnchantPool := preload("res://scripts/enchant_pool.gd")
const ChestOpenAnim := preload("res://scripts/chest_open_anim.gd")
const RewardReveal := preload("res://scripts/reward_reveal.gd")
const RewardRays := preload("res://scripts/reward_rays.gd")
## Kullanıcı isteği (2026-10-02): "yetenek evrimlerindeki kart panelinin ve efsun panelinin kartların vb biraz küçülmesini
## istiyorum nerdeyse tüm ekranı kaplıyorlar %20 küçülsünler" - kart 4x -> 3x (480x720 -> 360x540, %25). %20 = 3.2x olurdu ve
## piksel sanatını/yazıyı düzensizleştirirdi (seyyar satıcı 0.75 ölçeğinde yaşandı); 3x tam sayı ve kart dokusunun
## (levelup_enchant_card_*.png 360x540, hale 390x570) KENDİ boyutu - artık esnetilmeden birebir çiziliyor. Evrim kartları
## (level_up_screen.gd) bu sabitleri okur, ikisi birlikte küçüldü.
const CARD_TEXEL := 3.0 ## kart 3x ölçekte (120x180 sanat px)
const FAN_SPIN := [-0.12, 0.0, 0.12]
const FAN_DELAY := 0.1
const RAYS_REACH_SCALE := 0.75 ## üç büyük kart yan yana - ışık ekranın tepesine/dibine taşmasın
const TierCardFx := preload("res://scripts/tier_card_fx.gd")
const MerchantShopScript := preload("res://scripts/merchant_shop_screen.gd")
const ReadingUiWatcher := preload("res://scripts/reading_ui_watcher.gd")
const SHINE_SHADER := preload("res://shaders/tier_card_shine.gdshader")

const CARD_SIZE := Vector2(360, 540)
const CARD_ART_SIZE := Vector2(120, 180)
const CARD_GAP := 30
const CARD_TEXTURES := [
	preload("res://assets/ui/game/levelup_enchant_card_1.png"),
	preload("res://assets/ui/game/levelup_enchant_card_2.png"),
	preload("res://assets/ui/game/levelup_enchant_card_3.png"),
	preload("res://assets/ui/game/levelup_enchant_card_4.png"),
	preload("res://assets/ui/game/levelup_enchant_card_5.png"),
]
const GLOW_TEXTURE := preload("res://assets/ui/game/levelup_enchant_glow.png")
## Tier yazı rengi (dokudaki tier "hi" tonu; 5 = Final altını) ve seçim halesi renkleri.
const TIER_TEXT := [Color("#cdd1d6"), Color("#a6c6f4"), Color("#d8aef4"), Color("#f8a890"), Color("#ffe39a")]
const GLOW_COLORS := [Color("#dfe4ea"), Color("#9cc4ff"), Color("#dcb0ff"), Color("#ffc65a")]
const DIM_COLOR := Color("#e6d2b0")
const LEAD_COLOR := Color("#b9a78c")
const HEAD_COLOR := Color("#ffd66e")
const POWER_COLOR := Color("#9cc4ff")
const NOTE_COLOR := Color("#ffb070")
## Kart içi yerleşim (ekran px, 3x - eski 4x değerlerin 3/4'ü): ikon yuvası, sağında nadirlik·aşama / silah; gömük metin
## alanı. İkon 64 px = 32 px ikonların tam 2 katı (yuvanın ortasında).
const ICON_RECT := Rect2(34, 34, 64, 64)
const BADGE_RECT := Rect2(84, 84, 18, 18)
const TIER_RECT := Rect2(120, 30, 225, 38)
const CATEGORY_RECT := Rect2(120, 66, 225, 38)
const TEXT_RECT := Rect2(42, 132, 276, 366)
const BODY_FONT := 32
const BODY_MIN_FONT := 24
const HEADER_FONTS := [32, 24]
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
## Telefon (kullanıcı seçimi 2026-10-03, prototip "A - ekranı dolduran kartlar"): kart 3x yerine k katı (k = 5/3 -> 600x900,
## sığmazsa 4/3) - doku tam sayı sanat pikseli katında, iç dikdörtgenler k ile ölçeklenir, yazılar telefon boylarında
## (mobile_ui.gd CHOICE_*). Karıştır solda, Geç + geri sayım sağda dikey büyük düğmeler; Yasakla kartın alt kenarında.
## Masaüstünde k = 1, her şey eskisi gibi. Evrim kartları (level_up_screen.gd) aynı yardımcıları kullanır.
const MOBILE_CARD_GAP := 48.0


## Kartın k katı dikdörtgeni (k = 1 masaüstü 3x).
static func card_rect(r: Rect2, k: float) -> Rect2:
	return Rect2((r.position * k).round(), (r.size * k).round())


static func header_fonts(k: float) -> Array:
	return HEADER_FONTS if k <= 1.0 else MobileUIScript.CHOICE_HEADER_FONTS


static func body_fonts(k: float) -> Array:
	return [BODY_FONT, BODY_MIN_FONT] if k <= 1.0 else MobileUIScript.CHOICE_BODY_FONTS

var player_ref: Node = null
var use_chest_timer: bool = false
## true: elit sandık girişi (sandık -> kartlar fırlar). false: kartlar doğrudan belirir (debug menüsü).
var intro_chest: bool = false
var _revealed: bool = true
var _rays: Array = []
var _rays_layer: Control = null
var _stage: Control = null
var _chest_anim: Control = null
var _hint: Label = null
var _title: Label = null
var _bar: Control = null
var _choices: Array = []
var _cards: Array = []
var _banish_buttons: Array = []
var _shown_keys: Array = []
var _has_chosen: bool = false
var _rerolls: int = 0
var _reroll_button: Button = null
var _skip_button: Button = null
var _countdown_label: Label = null
var _owned_label: Label = null
var _fx_layer: Control = null
var _shine_tweens: Array = [null, null, null]
var _chest_center: Vector2 = Vector2(960.0, 540.0)
var _k: float = 1.0
var _card_size: Vector2 = CARD_SIZE


func _enter_tree() -> void:
	add_to_group(ReadingUiWatcher.GROUP)


func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_ALWAYS
	if player_ref == null:
		player_ref = get_tree().get_first_node_in_group("player")
	_revealed = not intro_chest
	_build()
	_roll_choices()
	if intro_chest:
		_start_chest_intro()
	else:
		for r in _rays:
			r.fade = 1.0
	UISound.connect_all_buttons(self)
	if NetworkManager.is_multiplayer_active:
		## Level akışında level ekranının, sandık akışında (efsun sandığı) sandığın geri sayımı - süre dolunca ilk kart.
		if use_chest_timer:
			NetworkManager.chest_countdown_tick.connect(_on_timer_tick)
		else:
			NetworkManager.multiplayer_level_up_timer_tick.connect(_on_timer_tick)
			if _countdown_label:
				_countdown_label.visible = NetworkManager.level_up_timer_active
				_countdown_label.text = "%ds" % int(ceil(NetworkManager.level_up_countdown))


func _build() -> void:
	var game_theme: Theme = UIKit.theme()
	_k = MobileUIScript.choice_card_scale(get_viewport(), CARD_SIZE, 3, MOBILE_CARD_GAP)
	_card_size = (CARD_SIZE * _k).round()
	var mobile: bool = _k > 1.0
	var view: Vector2 = get_viewport().get_visible_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.04, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	## Kartların arkası: sandık sahnesi, sonra ışık huzmeleri (kartlar her şeyin önünde).
	_stage = _make_layer("ChestStage")
	_rays_layer = _make_layer("RewardRays")

	var title := Label.new()
	title.text = "EFSUN"
	title.theme = game_theme
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_stylebox_override("normal", UIKit.panel_style("banner"))
	UIKit.style_label(title, UIKit.FS_TITLE, UIKit.C_TEXT, 0)
	var tw: float = MenuKit.font().get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FS_TITLE).x + 132.0
	title.offset_left = -roundf(tw * 0.5)
	title.offset_right = roundf(tw * 0.5)
	title.offset_top = 8.0 if mobile else 16.0
	title.offset_bottom = title.offset_top + 72.0
	add_child(title)
	_title = title

	## Sahip olunan efsunlar - hangi silahta hangi efsun, hangi aşamada (kartların neyi ilerlettiği anlaşılsın).
	_owned_label = Label.new()
	_owned_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_owned_label.offset_left = -900.0
	_owned_label.offset_right = 900.0
	_owned_label.offset_top = 82.0 if mobile else 94.0
	_owned_label.offset_bottom = _owned_label.offset_top + 40.0
	_owned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_owned_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_owned_label.clip_text = true
	UIKit.style_label(_owned_label, 24, UIKit.C_TEXT, 0)
	## Kartların ışık huzmeleri bu satırın arkasından geçer - koyu gömük zemin okunur kalsın (genişlik metne göre, bkz. _roll_choices).
	_owned_label.add_theme_stylebox_override("normal", UIKit.panel_style("inset_tight"))
	add_child(_owned_label)

	var row := HBoxContainer.new()
	row.name = "Cards"
	row.theme = game_theme
	var gap: float = MOBILE_CARD_GAP if mobile else float(CARD_GAP)
	row.add_theme_constant_override("separation", int(gap))
	row.set_anchors_preset(Control.PRESET_CENTER)
	var total_w: float = _card_size.x * 3.0 + gap * 2.0
	row.offset_left = -total_w * 0.5
	row.offset_right = total_w * 0.5
	row.offset_top = -_card_size.y * 0.5 - 20.0
	row.offset_bottom = _card_size.y * 0.5 - 20.0
	if mobile:
		## Telefonda kartlar başlığın altından ekranın dibine kadar (bkz. mobile_ui.gd CHOICE_TOP).
		row.offset_top = MobileUIScript.CHOICE_TOP - view.y * 0.5
		row.offset_bottom = row.offset_top + _card_size.y
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for i in range(3):
		var col := VBoxContainer.new()
		## Telefonda Yasakla kartın alt kenarının üstüne biner (kart ekranın boyu kadar - altında yer yok).
		col.add_theme_constant_override("separation", -40 if mobile else 10)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(col)
		var card := _make_card()
		col.add_child(card)
		card.pressed.connect(_on_card_pressed.bind(i))
		card.mouse_entered.connect(_on_card_hover.bind(i, true))
		card.mouse_exited.connect(_on_card_hover.bind(i, false))
		card.focus_entered.connect(_on_card_hover.bind(i, true))
		card.focus_exited.connect(_on_card_hover.bind(i, false))
		_cards.append(card)
		var rays: Control = RewardRays.new()
		_rays_layer.add_child(rays)
		rays.setup(card, _card_size, CARD_TEXEL * _k, 1, intro_chest, RAYS_REACH_SCALE)
		_rays.append(rays)
		var ban := Button.new()
		ban.text = "Yasakla"
		ban.custom_minimum_size = Vector2(_card_size.x * 0.6, 72) if mobile else Vector2(CARD_SIZE.x, 44)
		if mobile:
			ban.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		UIKit.style_button(ban, "dark", true, 32 if mobile else 24)
		ban.pressed.connect(_on_banish_pressed.bind(i))
		col.add_child(ban)
		_banish_buttons.append(ban)

	var bar := HBoxContainer.new()
	bar.theme = game_theme
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 24)
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -500.0
	bar.offset_right = 500.0
	bar.offset_top = -80.0
	bar.offset_bottom = -28.0
	add_child(bar)
	_bar = bar
	_reroll_button = Button.new()
	_reroll_button.custom_minimum_size = Vector2(420, 52)
	UIKit.style_button(_reroll_button, "wood", false, UIKit.FS_BODY)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	bar.add_child(_reroll_button)
	_skip_button = Button.new()
	_skip_button.custom_minimum_size = Vector2(300, 52)
	UIKit.style_button(_skip_button, "dark", false, UIKit.FS_BODY)
	_skip_button.text = "Geç (+%d altın)" % GameManager.LEVEL_UP_GOLD_REWARD
	_skip_button.pressed.connect(_on_skip_pressed)
	bar.add_child(_skip_button)
	_countdown_label = Label.new()
	UIKit.style_label(_countdown_label, UIKit.FS_BODY, UIKit.C_CREAM, 4)
	_countdown_label.visible = false
	bar.add_child(_countdown_label)
	if mobile:
		_layout_mobile_bar(bar)

	_fx_layer = Control.new()
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)


## Telefon: alt çubuk yerine ekranın iki yanında dikey büyük düğmeler (karıştır solda, geç + geri sayım sağda). _bar tüm
## ekranı kaplayan saydam bir kap olur (giriş animasyonundaki görünürlük geçişi aynen çalışsın).
func _layout_mobile_bar(bar: HBoxContainer) -> void:
	var holder := Control.new()
	holder.name = "SideButtons"
	holder.theme = bar.theme
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	move_child(holder, bar.get_index())
	var vp: Viewport = get_viewport()
	var slots: Array = [[_reroll_button, MobileUIScript.choice_side_rect(vp, true, 0, 1, 300.0)],
		[_skip_button, MobileUIScript.choice_side_rect(vp, false, 0, 1, 300.0)]]
	for s in slots:
		var b: Button = s[0]
		var r: Rect2 = s[1]
		b.reparent(holder, false)
		b.custom_minimum_size = Vector2.ZERO
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 40)
		b.position = r.position
		b.size = r.size
	_skip_button.text = "Geç\n+%d altın" % GameManager.LEVEL_UP_GOLD_REWARD
	_countdown_label.reparent(holder, false)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var skip_r: Rect2 = slots[1][1]
	_countdown_label.position = Vector2(skip_r.position.x, skip_r.end.y + 16.0)
	_countdown_label.size = Vector2(skip_r.size.x, 48.0)
	bar.queue_free()
	_bar = holder


func _make_layer(layer_name: String) -> Control:
	var c := Control.new()
	c.name = layer_name
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _set_title(text: String) -> void:
	if not is_instance_valid(_title):
		return
	_title.text = text
	var tw: float = MenuKit.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FS_TITLE).x + 132.0
	_title.offset_left = -roundf(tw * 0.5)
	_title.offset_right = roundf(tw * 0.5)


## Elit sandık girişi: kartlar/butonlar gizli, ekranın ortasında elit sandık açılır (chest_open_anim.gd - tıklama/tuş atlar).
func _start_chest_intro() -> void:
	_set_title("ELİT SANDIK")
	for card in _cards:
		card.modulate.a = 0.0
	for ban in _banish_buttons:
		ban.modulate.a = 0.0
	_bar.modulate.a = 0.0
	if _owned_label:
		_owned_label.modulate.a = 0.0
	var anim: Control = ChestOpenAnim.new()
	anim.setup(true)
	_stage.add_child(anim)
	var view: Vector2 = get_viewport().get_visible_rect().size
	anim.size = anim.custom_minimum_size
	anim.position = Vector2((view.x - anim.size.x) * 0.5, view.y * 0.5 - 20.0 - anim.size.y * 0.55)
	_chest_center = anim.position + anim.size * Vector2(0.5, 0.52) ## altın kesesi buradan fışkırır (bkz. _on_card_pressed)
	anim.pivot_offset = anim.size * 0.5
	anim.scale = Vector2(0.6, 0.6)
	anim.modulate.a = 0.0
	_chest_anim = anim
	var pop_in := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	pop_in.tween_property(anim, "modulate:a", 1.0, 0.2)
	pop_in.tween_property(anim, "scale", Vector2.ONE, 0.3)
	_hint = Label.new()
	_hint.text = "İçinden efsun çıkacak"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(_hint, UIKit.FS_BODY, UIKit.C_CREAM, 4)
	_stage.add_child(_hint)
	_hint.position = Vector2(0.0, anim.position.y + anim.size.y - 30.0)
	_hint.size = Vector2(view.x, 48.0)
	anim.burst.connect(_reveal_from_chest, CONNECT_ONE_SHOT)


## Kapak patladı: kartlar sandığın ağzından sırayla (sol, orta, sağ) fırlar; her biri inince parlar ve ışığı yanar.
func _reveal_from_chest() -> void:
	if _revealed:
		return
	_set_title("EFSUN")
	var mouth: Vector2 = RewardReveal.chest_mouth(_chest_anim) if is_instance_valid(_chest_anim) else get_viewport().get_visible_rect().size * 0.5
	var best: int = 1
	for card in _cards:
		best = maxi(best, int(card.get_meta("ray_tier", 1)))
	RewardReveal.launch_sparks(_fx_layer, mouth, best, true)
	var last: Tween = null
	for i in range(_cards.size()):
		var card: Button = _cards[i]
		last = RewardReveal.fly_out(self, card, mouth, FAN_DELAY * float(i), FAN_SPIN[i % FAN_SPIN.size()])
		last.tween_callback(_on_card_landed.bind(i))
	if last:
		last.tween_callback(_finish_reveal)
	else:
		_finish_reveal()


func _on_card_landed(i: int) -> void:
	if i >= _cards.size():
		return
	var card: Button = _cards[i]
	RewardReveal.land_fx(self, card, card.get_node("Frame") as TextureRect, int(card.get_meta("ray_tier", 1)), true, _fx_layer, _rays[i])


## Kartlar indi (ya da süre doldu): butonlar/başlık satırı belirir, sandık aşağı kayarak söner, seçim açılır.
func _finish_reveal() -> void:
	if _revealed:
		return
	_revealed = true
	var tw := create_tween().set_parallel(true)
	for ban in _banish_buttons:
		tw.tween_property(ban, "modulate:a", 1.0, 0.25)
	tw.tween_property(_bar, "modulate:a", 1.0, 0.25)
	if _owned_label:
		tw.tween_property(_owned_label, "modulate:a", 1.0, 0.25)
	for card in _cards:
		if card.modulate.a < 0.99:
			tw.tween_property(card, "modulate:a", 1.0, 0.2)
	for r in _rays:
		if float(r.fade) < 0.99:
			tw.tween_property(r, "fade", 1.0, 0.3)
	for node in [_chest_anim, _hint]:
		if is_instance_valid(node):
			tw.tween_property(node, "modulate:a", 0.0, 0.3).set_delay(0.1)
			tw.tween_property(node, "position:y", (node as Control).position.y + 40.0, 0.4).set_delay(0.1).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		for node in [_chest_anim, _hint]:
			if is_instance_valid(node):
				node.queue_free()
	)
	_refresh_buttons()


func _make_card() -> Button:
	var card := Button.new()
	card.custom_minimum_size = _card_size
	card.flat = true
	## Kumandayla seçilebilsin (bkz. gamepad_ui.gd - odak sadece kumanda kullanılırken verilir, Space/fare akışı aynı).
	card.focus_mode = Control.FOCUS_ALL
	card.add_to_group(&"gamepad_first_focus")
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		card.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	card.clip_contents = false
	card.set_meta("glow_texture", GLOW_TEXTURE)
	card.set_meta("glow_card_size", _card_size)
	card.set_meta("glow_pad", TierCardFx.GLOW_PAD * _k)
	card.set_meta("glow_colors", GLOW_COLORS)
	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.size = _card_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHINE_SHADER
	mat.set_shader_parameter("art_size", CARD_ART_SIZE)
	mat.set_shader_parameter("shine_pos", -1.0)
	mat.set_shader_parameter("shine_strength", 0.0)
	mat.set_shader_parameter("flash", 0.0)
	frame.material = mat
	card.add_child(frame)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = card_rect(ICON_RECT, _k).position
	icon.size = card_rect(ICON_RECT, _k).size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)
	var badge := ColorRect.new()
	badge.name = "Badge"
	badge.position = card_rect(BADGE_RECT, _k).position
	badge.size = card_rect(BADGE_RECT, _k).size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(badge)
	_label(card, "TierLabel", card_rect(TIER_RECT, _k), header_fonts(_k)[0])
	_label(card, "Category", card_rect(CATEGORY_RECT, _k), header_fonts(_k)[0])
	var text := RichTextLabel.new()
	text.name = "Text"
	text.bbcode_enabled = true
	text.fit_content = false
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.position = card_rect(TEXT_RECT, _k).position
	text.size = card_rect(TEXT_RECT, _k).size
	text.add_theme_color_override("default_color", DIM_COLOR)
	text.add_theme_constant_override("line_separation", 2)
	card.add_child(text)
	return card


func _label(card: Control, lbl_name: String, rect: Rect2, fs: int) -> void:
	var lbl := Label.new()
	lbl.name = lbl_name
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.clip_text = true
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.style_label(lbl, fs, UIKit.C_CREAM, 0)
	card.add_child(lbl)
	lbl.position = rect.position
	lbl.size = rect.size
	lbl.set_deferred("size", rect.size)


func _roll_choices() -> void:
	_choices = EnchantPool.build(player_ref, _shown_keys)
	for c in _choices:
		_shown_keys.append(EnchantPool.card_key(c))
	for i in range(3):
		_fill_card(i)
	if _owned_label:
		var summary: String = EnchantPool.owned_summary()
		_owned_label.text = "Efsunların:  " + summary if summary != "" else ""
		_owned_label.visible = summary != ""
		_fit_header(_owned_label, 1760.0)
		var fs: int = _owned_label.get_theme_font_size("font_size")
		var w: float = minf(1800.0, MenuKit.font().get_string_size(_owned_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 48.0)
		_owned_label.offset_left = -roundf(w * 0.5)
		_owned_label.offset_right = roundf(w * 0.5)
	_refresh_buttons()
	if _revealed:
		_animate_in()


func _fill_card(i: int) -> void:
	var card: Button = _cards[i]
	var c: Dictionary = _choices[i] if i < _choices.size() else {}
	var d: Dictionary = EnchantPool.describe(c)
	## 2026-09-30: nadirlik yok - efsun kartları mor (Tier 3), Final kırmızı (Tier 4); havuz kartın "tier"ini zaten böyle yazar.
	var tier: int = clampi(int(c.get("tier", 1)), 1, 4)
	var frame: TextureRect = card.get_node("Frame")
	frame.texture = CARD_TEXTURES[tier - 1]
	frame.modulate = Color.WHITE
	(frame.material as ShaderMaterial).set_shader_parameter("shine_pos", -1.0)
	if _shine_tweens[i] and _shine_tweens[i].is_valid():
		_shine_tweens[i].kill()
	_shine_tweens[i] = TierCardFx.start_idle_shine(self, frame, mini(tier, 4), 0.4 + 0.3 * i)
	var icon_path: String = str(d["icon"])
	(card.get_node("Icon") as TextureRect).texture = load(icon_path) if icon_path != "" and ResourceLoader.exists(icon_path) else null
	(card.get_node("Badge") as ColorRect).color = Color(d["color"])
	var tier_lbl: Label = card.get_node("TierLabel")
	tier_lbl.text = str(d["tier_line"])
	tier_lbl.add_theme_color_override("font_color", TIER_TEXT[tier - 1])
	_fit_header(tier_lbl, card_rect(TIER_RECT, _k).size.x, header_fonts(_k))
	var cat: Label = card.get_node("Category")
	cat.text = str(d["category"])
	cat.add_theme_color_override("font_color", DIM_COLOR)
	_fit_header(cat, card_rect(CATEGORY_RECT, _k).size.x, header_fonts(_k))
	var text: RichTextLabel = card.get_node("Text")
	text.text = _card_bbcode(d)
	_set_text_size(text, body_fonts(_k)[0])
	_fit_text.call_deferred(text)
	card.set_meta("tier", mini(tier, 4))
	card.set_meta("ray_tier", tier)
	if i < _rays.size():
		_rays[i].set_tier(tier, intro_chest)
	TierCardFx.set_hover_glow(card, mini(tier, 4), false)
	card.modulate = Color.WHITE
	card.scale = Vector2.ONE
	card.disabled = c.is_empty()
	var ban: Button = _banish_buttons[i]
	ban.visible = bool(d["banishable"])
	ban.disabled = GameManager.enchant_banish_left <= 0
	ban.text = "Yasakla (%d)" % GameManager.enchant_banish_left


## Kart metni: ad + tek metin (başlangıçta nasıl çalıştığı, geliştirmede ne değiştiği - bkz. EnchantPool.describe sade kart
## notu). lead/head/power/note boşsa çizilmez (altın kartı lead kullanır).
static func _card_bbcode(d: Dictionary) -> String:
	var parts: Array = ["[color=#fff0d6]%s[/color]" % str(d["title"])]
	if str(d["lead"]) != "":
		parts.append("[color=#%s]%s[/color]" % [LEAD_COLOR.to_html(false), str(d["lead"])])
	if str(d["head"]) != "":
		parts.append("[color=#%s]%s[/color]\n%s" % [HEAD_COLOR.to_html(false), str(d["head"]), str(d["body"])])
	elif str(d["body"]) != "":
		parts.append(str(d["body"]))
	if str(d["power"]) != "":
		parts.append("[color=#%s]%s[/color]" % [POWER_COLOR.to_html(false), str(d["power"])])
	if str(d["note"]) != "":
		parts.append("[color=#%s]%s[/color]" % [NOTE_COLOR.to_html(false), str(d["note"])])
	return "\n\n".join(parts)


## Tek satırlık başlık etiketi sığmıyorsa 32 -> 24 px (piksel yazı tipi 8'in katlarında net kalır).
static func _fit_header(lbl: Label, width: float, fonts: Array = HEADER_FONTS) -> void:
	for fs in fonts:
		lbl.add_theme_font_size_override("font_size", fs)
		if MenuKit.font().get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
			return


static func _set_text_size(text: RichTextLabel, fs: int) -> void:
	for key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		text.add_theme_font_size_override(key, fs)


func _fit_text(text: RichTextLabel) -> void:
	if not is_instance_valid(text) or not text.is_inside_tree():
		return
	var sizes: Array = body_fonts(_k)
	var fs: int = int(sizes[0])
	while fs > int(sizes[-1]) and float(text.get_content_height()) > card_rect(TEXT_RECT, _k).size.y:
		fs -= 8
		_set_text_size(text, fs)
		## İçerik yüksekliği bir sonraki karede güncellenir - hemen tekrar ölçmek eski değeri okur.
		await get_tree().process_frame
		if not is_instance_valid(text):
			return


func _animate_in() -> void:
	for card in _cards:
		card.modulate.a = 0.0
	await get_tree().process_frame
	if not is_inside_tree():
		return
	for i in range(_cards.size()):
		var card: Control = _cards[i]
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.92, 0.92)
		var t := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(card, "modulate:a", 1.0, 0.26).set_delay(i * 0.07)
		t.tween_property(card, "scale", Vector2.ONE, 0.26).set_delay(i * 0.07)


func _reroll_cost() -> int:
	return MerchantShopScript.reroll_cost(_rerolls)


func _refresh_buttons() -> void:
	var cost: int = _reroll_cost()
	_reroll_button.text = ("Karıştır\n%d altın" if _k > 1.0 else "Yeniden Karıştır (%d altın)") % cost
	_reroll_button.disabled = _has_chosen or not _revealed or GameManager.gold < cost
	_skip_button.disabled = _has_chosen or not _revealed


func _on_card_hover(i: int, entered: bool) -> void:
	if _has_chosen or not _revealed or i >= _cards.size():
		return
	var card: Button = _cards[i]
	(card.get_node("Frame") as TextureRect).modulate = Color(1.12, 1.12, 1.12) if entered else Color.WHITE
	TierCardFx.set_hover_glow(card, int(card.get_meta("tier", 1)), entered)


func _on_reroll_pressed() -> void:
	var cost: int = _reroll_cost()
	if _has_chosen or not _revealed or GameManager.gold < cost:
		return
	GameManager.gold -= cost
	_rerolls += 1
	_roll_choices()


func _on_banish_pressed(i: int) -> void:
	if _has_chosen or not _revealed or GameManager.enchant_banish_left <= 0 or i >= _choices.size():
		return
	var c: Dictionary = _choices[i]
	if str(c.get("type", "")) != "temel":
		return
	GameManager.enchant_banish_left -= 1
	GameManager.enchant_banished.append("%d:%s" % [int(c["slot"]), str(c["id"])])
	## Sadece o kart yenilenir: havuzdan ekranda olmayan yeni bir kart.
	var visible_keys: Array = _shown_keys.duplicate()
	var fresh: Array = EnchantPool.build(player_ref, visible_keys)
	var replacement: Dictionary = {}
	for f in fresh:
		var k: String = EnchantPool.card_key(f)
		var dup: bool = false
		for other in _choices:
			if EnchantPool.card_key(other) == k:
				dup = true
		if not dup:
			replacement = f
			break
	if replacement.is_empty():
		replacement = {"type": "gold", "gold": EnchantPool.GOLD_CARD_AMOUNT, "tier": 1}
	_choices[i] = replacement
	_shown_keys.append(EnchantPool.card_key(replacement))
	for j in range(3):
		_fill_card(j)


func _on_skip_pressed() -> void:
	if _has_chosen or not _revealed:
		return
	_has_chosen = true
	GameManager.gold += GameManager.LEVEL_UP_GOLD_REWARD
	enchant_chosen.emit({"type": "skip"})


func _on_card_pressed(i: int) -> void:
	if _has_chosen or not _revealed or i >= _choices.size():
		return
	_has_chosen = true
	_refresh_buttons()
	for j in range(_cards.size()):
		if _shine_tweens[j] and _shine_tweens[j].is_valid():
			_shine_tweens[j].kill()
		_banish_buttons[j].disabled = true
		if j == i:
			continue
		var other: Control = _cards[j]
		other.pivot_offset = other.size * 0.5
		var fade := create_tween().set_parallel(true)
		fade.tween_property(other, "modulate", Color(0.55, 0.52, 0.5, 0.35), 0.3)
		fade.tween_property(other, "scale", Vector2(0.94, 0.94), 0.3)
	var card: Button = _cards[i]
	card.modulate = Color.WHITE
	var tw: Tween = TierCardFx.celebrate(self, card, card.get_node("Frame") as TextureRect, int(card.get_meta("tier", 1)), _fx_layer)
	tw.chain().tween_callback(func() -> void:
		var choice: Dictionary = _choices[i]
		## Altın kesesi kartı: ekran kapanınca elit sandık yerinde yeniden belirir, altın ağzından sol üstteki altın paneline
		## fışkırır (player.apply_enchant_choice -> gold_reward_fx.gd). Sandıksız açılışta (debug) kartın yerinden.
		if str(choice.get("type", "")) == "gold" and is_instance_valid(card):
			choice = choice.duplicate()
			choice["fx_from"] = _chest_center if intro_chest else card.get_global_transform_with_canvas() * (card.size * 0.5)
			choice["fx_source"] = "elite_chest" if intro_chest else ""
		enchant_chosen.emit(choice))


func _unhandled_input(event: InputEvent) -> void:
	if _has_chosen or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if player_ref and bool(player_ref.get("is_chat_typing")):
		return
	match event.keycode:
		KEY_1:
			_on_card_pressed(0)
		KEY_2:
			_on_card_pressed(1)
		KEY_3:
			_on_card_pressed(2)


func _input(event: InputEvent) -> void:
	if _has_chosen or not _revealed or not (event is InputEventKey) or not event.pressed or event.echo or event.keycode != KEY_SPACE:
		return
	if player_ref and bool(player_ref.get("is_chat_typing")):
		return
	get_viewport().set_input_as_handled()
	if not _reroll_button.disabled:
		_on_reroll_pressed()


func _on_timer_tick(remaining: float) -> void:
	if _countdown_label:
		_countdown_label.visible = true
		_countdown_label.text = "%ds" % int(ceil(remaining))
	if remaining <= 0.0 and not _has_chosen:
		if not _revealed:
			## Süre giriş animasyonunda dolduysa (neredeyse imkânsız, 25 sn) kartları anında göster ve ilkini seç.
			for c in _cards:
				c.modulate.a = 1.0
			_finish_reveal()
		_on_card_pressed(0)
