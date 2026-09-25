extends Control

## Sandık açılış animasyonu - ödül ekranında (normal: chest_menu.gd, elit: enchant_screen.gd intro_chest). Kartlar burst
## anında sandığın ağzından fırlar (reward_reveal.gd). Kullanıcı isteği
## (2026-09-25): "sandık açarken daha iyi ve ödüllendirici heyecan uyandırıcı sandık açma animasyonu ... pixel tarzda
## sprite sheet olarak". Sayfa: tools/gen_chest_sprites.py (20 kare x 48x48, kare düzeni o dosyanın başında). Sırası:
## kısa bekleme -> sallanma + aralıktan ışık -> kapak patlar (ekran flaşı + sarsıntı + ses) -> ışınlar/altınlar -> açık
## bekleme. Normal sandıkta ışığın rengi ÇIKACAK eşyanın nadirliği (tier 1-4) - kart görünmeden önce ipucu.
## Tıklama / herhangi bir tuş animasyonu atlar (çok oyunculuda 25 sn'lik sandık süresi zaten işliyor).
## Oyun duraklatılmışken çalışır: süreyi kendi _process'i sayar (sahibi PROCESS_MODE_ALWAYS bir CanvasLayer).

signal burst ## kapağın açıldığı an (8. kare) - sahibi ödülü hazırlamaya başlayabilir
signal finished ## animasyon (ya da atlama) bitti

const FRAME := 48
const DISPLAY_SCALE := 8 ## 48 px kare -> 384 px (sandık ~176-208 px) - heyecan anında ekranda iri dursun
const BURST_FRAME := 8
const OPEN_LOOP := [16, 17, 18, 19]
const OPEN_LOOP_STEP := 0.12
const HOLD_AFTER := 0.3 ## açık beklemede ne kadar kalınır (finished'dan önce)
## [kare, süre sn]: bekleme 0.46 + heyecan 0.52 + patlama 0.55 -> ~1.5 sn, + HOLD_AFTER.
const TIMELINE := [
	[0, 0.18], [1, 0.12], [2, 0.08], [3, 0.08],
	[4, 0.14], [5, 0.12], [6, 0.12], [7, 0.14],
	[8, 0.07], [9, 0.06], [10, 0.06], [11, 0.06], [12, 0.07], [13, 0.07], [14, 0.08], [15, 0.08],
]
const NORMAL_SHEETS := [
	preload("res://assets/sprites/chests/chest_normal_t1.png"),
	preload("res://assets/sprites/chests/chest_normal_t2.png"),
	preload("res://assets/sprites/chests/chest_normal_t3.png"),
	preload("res://assets/sprites/chests/chest_normal_t4.png"),
]
const ELITE_SHEET := preload("res://assets/sprites/chests/chest_elite.png")
## Işık renkleri gen_chest_sprites.py LIGHTS ile aynı (ekran flaşı bu renkte).
const LIGHT_COLORS := [Color("#e6ebf2"), Color("#9cc4ff"), Color("#dcb0ff"), Color("#ffc65a")]
const ELITE_LIGHT := Color("#c77dff")

const SFX_KNOCK := preload("res://Sound FX Starter Pack Vol. 1/Motions and Impacts/Impact Redwood.wav")
const SFX_COINS := preload("res://Sound FX Starter Pack Vol. 1/Medieval/Loot Gold.wav")
const SFX_REWARD := preload("res://Sound FX Starter Pack Vol. 1/Hollywood/Reward.wav")
const SFX_ELITE := preload("res://Sound FX Starter Pack Vol. 1/Magic/Magic Seal.wav")

var _sheet: Texture2D = null
var _light: Color = Color.WHITE
var _elite: bool = false
var _tier: int = 1
var _rect: TextureRect = null
var _atlas: AtlasTexture = null
var _step: int = -1
var _t: float = 0.0
var _last_us: int = 0
var _loop_t: float = 0.0
var _hold_left: float = -1.0
var _burst_sent: bool = false
var _done: bool = false


## elite=false: reward_tier (1-4) ışığın rengini seçer.
func setup(elite: bool, reward_tier: int = 1) -> void:
	_elite = elite
	_tier = clampi(reward_tier, 1, 4)
	_sheet = ELITE_SHEET if elite else NORMAL_SHEETS[_tier - 1]
	_light = ELITE_LIGHT if elite else LIGHT_COLORS[_tier - 1]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(FRAME, FRAME) * DISPLAY_SCALE
	if _sheet == null:
		setup(false, 1)
	_atlas = AtlasTexture.new()
	_atlas.atlas = _sheet
	_rect = TextureRect.new()
	_rect.texture = _atlas
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.size = custom_minimum_size
	_rect.pivot_offset = custom_minimum_size * 0.5
	add_child(_rect)
	_show_frame(0)
	_advance(0)


func _show_frame(i: int) -> void:
	_atlas.region = Rect2(i * FRAME, 0, FRAME, FRAME)


func _advance(step: int) -> void:
	_step = step
	_t = 0.0
	if step >= TIMELINE.size():
		_hold_left = HOLD_AFTER
		_show_frame(OPEN_LOOP[0])
		return
	var f: int = int(TIMELINE[step][0])
	_show_frame(f)
	if f == 4 or f == 6:
		_play(SFX_KNOCK, -10.0, 1.5 if f == 4 else 1.7)
	if f == BURST_FRAME:
		_on_burst()


## Süre GERÇEK saatle sayılır (motorun delta'sıyla değil): oyun duraklatılmışken ölçümde delta gerçek zamanın ~%60'ında
## kaldı (patlama 0,98 sn yerine 1,67 sn'de geldi). Kare düşse bile biriken süre kadar adım atlanır; patlama anı yine
## _advance içinde tetiklenir.
func _process(_delta: float) -> void:
	if _done:
		return
	var now: int = Time.get_ticks_usec()
	var dt: float = 0.0 if _last_us == 0 else float(now - _last_us) / 1000000.0
	_last_us = now
	if _hold_left >= 0.0:
		_loop_t += dt
		_show_frame(OPEN_LOOP[int(_loop_t / OPEN_LOOP_STEP) % OPEN_LOOP.size()])
		_hold_left -= dt
		if _hold_left < 0.0:
			_finish()
		return
	_t += dt
	while _hold_left < 0.0 and _t >= float(TIMELINE[_step][1]):
		var carry: float = _t - float(TIMELINE[_step][1])
		_advance(_step + 1)
		_t = carry


func skip() -> void:
	if _done or _hold_left >= 0.0:
		return
	if not _burst_sent:
		_on_burst()
	_advance(TIMELINE.size())
	_hold_left = 0.12


func _input(event: InputEvent) -> void:
	if _done or _hold_left >= 0.0 or not is_visible_in_tree():
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo)
	if pressed:
		get_viewport().set_input_as_handled()
		skip()


func _on_burst() -> void:
	if _burst_sent:
		return
	_burst_sent = true
	_play(SFX_COINS, -2.0, 1.0)
	if _elite:
		_play(SFX_ELITE, -7.0, 1.0)
	else:
		## Nadirlik arttıkça ödül sesi biraz daha tiz ve güçlü.
		_play(SFX_REWARD, -8.0 + float(_tier), 0.94 + 0.04 * float(_tier))
	_flash_screen()
	## Sarsıntı: 3 kısa itme (sprite, kutunun kendisi değil - yerleşim bozulmasın).
	var tw := create_tween()
	for off: Vector2 in [Vector2(-6, 3), Vector2(5, -3), Vector2(-3, 2), Vector2.ZERO]:
		tw.tween_property(_rect, "position", off, 0.035)
	var pop := create_tween()
	pop.tween_property(_rect, "scale", Vector2(1.08, 1.08), 0.06)
	pop.tween_property(_rect, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	burst.emit()


## Tüm ekranı kısa süre sandığın ışık renginde aydınlatır (CanvasLayer'ın en üstünde, tıklamayı engellemez).
func _flash_screen() -> void:
	var layer: Node = get_parent()
	while layer != null and not (layer is CanvasLayer):
		layer = layer.get_parent()
	if layer == null:
		return
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(_light.r, _light.g, _light.b, 0.32 if _elite or _tier >= 3 else 0.22)
	layer.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_callback(flash.queue_free)


## Ses kökte çalar: sandık görseli kart çıkınca silinir, 2 sn'lik ödül sesi yarıda kesilmesin. Oyun duraklatılmışken de çalsın.
func _play(stream: AudioStream, volume_db: float, pitch: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _finish() -> void:
	_done = true
	_show_frame(OPEN_LOOP[0])
	finished.emit()
