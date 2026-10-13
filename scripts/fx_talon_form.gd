extends Node2D

## Talon'un Ayna Formu (R): kırmızı-siyah form (kullanıcı 2026-10-12: "ultisinde kırmızı-siyah bir forma geçip gözleri beyaz parıldayacak ve
## silahlar da kırmızı beyaz görünecek kendisi gibi" -> prototip A · Kızıl; "arkasındaki ateş efekti yerine partikül tarzı basit bir efekt").
##  - KARAKTER: shaders/talon_form.gdshader karakterin AnimatedSprite2D'sine takılır (gövde siyahtan kızıla rampa, gözler beyaz + hale + çakma,
##    dışta 1 piksel kızıl ışıma); 0,25 sn'de açılır, biterken FADE_OUT'ta geri döner
##  - SİLAHLAR: shaders/talon_form_weapon.gdshader tüm silah ikonlarına (ayna kopyaları dahil) takılır: kırmızı gövde, parlak yerler beyaz
##  - PARTİKÜL (eski alev aurası + zikzakların yerine): ayak hizasından doğup salınarak yükselen kor pikselleri (çoğu arkada, %35'i önde),
##    gövdede ara ara beyaz "+" parıltısı, silahların üstünde "+" parıltıları
##  - DÖNÜŞÜM ANI: 0,09 sn beyaz siluet çakması + merkezden dışa saçılan 28 piksel
## Boyut %10 artışı (karakter + silahlar) player.gd/remote_player.gd'de (TalonFormationMath.FORM_SCALE_MULT).
## Player ya da RemotePlayer'ın ÇOCUĞU olarak doğar (yerel + diğer oyuncular AYNI sahne); ömrü ebeveynin form bayrağını izler
## (yerel: _talon_mirror_form_active, uzak: _talon_form_active - bkz. main.gd extra["talon_form"]). Boyama da BURADA yapıldığı için iki
## tarafta ayrı kod yok (bkz. CLAUDE.md "MP iki-yer hatası"). Görünüm prototipi: tools/proto_20261012/gen_talon_form_zincir.py.
##
## PERF: eski sürüm iki katman pişmiş AnimatedSprite2D idi (ondan önce binlerce draw_rect, bkz. git geçmişi); şimdi kare başına ~35 draw_rect
## + iki küçük shader. assets/fx/talon_form/ sayfaları ve tools/gen_talon_form_sprites.py artık KULLANILMIYOR.

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const FormShader: Shader = preload("res://shaders/talon_form.gdshader")
const WeaponShader: Shader = preload("res://shaders/talon_form_weapon.gdshader")

const FADE_IN := 0.25
const FLASH_TIME := 0.09
const BURST_TIME := 0.45
const BURST_COUNT := 28
const FADE_OUT := 0.35
const NO_FLAG_GRACE := 2.0 ## uzak kopyada durum paketi gecikirse bayrak henüz true olmayabilir
const EMBER_RATE := 26.0 ## sn'de doğan kor (ömür 0,9-1,4 sn -> aynı anda ~30)
const TWINKLE_EVERY := 0.22
const TWINKLE_LIFE := 0.3
## Partikül rengi yaşa göre BASAMAKLI (yumuşak saydamlık yok - piksel sanatı): açık kırmızı -> kızıl -> koyu kızıl -> siyaha yakın.
const P_COLS: Array[Color] = [Color8(255, 96, 84), Color8(214, 30, 34), Color8(120, 10, 18), Color8(40, 4, 10)]
const P_WHITE := Color8(255, 240, 236)
const TWINKLE_ARM := Color8(255, 204, 198)

var _host: Node2D = null
var _anim: AnimatedSprite2D = null ## ebeveynin karakter sprite'ı
var _t: float = 0.0
var _seen_on: bool = false
var _off_time: float = 0.0
var _closing: float = 0.0 ## 0 = açık, >0 = kapanıyor (sn)
var _front: Node2D = null
var _char_mat: ShaderMaterial = null
var _weapon_mat: ShaderMaterial = null ## tüm ikonlar AYNI materyali paylaşır (tek "amount")
var _tinted: Array = [] ## materyali bizim taktığımız ikonlar (kapanışta sadece bunlar geri alınır)
## Kor: [x, y, vy, salınım genliği, frekans, faz, ömür, yaş, beyaz mı, büyük mü, önde mi] - birimler karakter sanat pikseli, kök = karakter kökü
var _embers: Array = []
var _ember_acc: float = 0.0
var _twinkles: Array = [] ## gövde parıltıları: [x, y, yaş] (sanat pikseli)
var _twinkle_acc: float = 0.0
var _sparks: Array = [] ## silah parıltıları: [pos (host yereli), age, life]


func _ready() -> void:
	show_behind_parent = true ## arka katman karakterin ARKASINDA (siblings: anim/silahlar sonra çizilir)
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_host = get_parent() as Node2D
	if _host != null:
		_anim = _host.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_char_mat = ShaderMaterial.new()
	_char_mat.shader = FormShader
	_char_mat.set_shader_parameter("amount", 0.0)
	_char_mat.set_shader_parameter("flash", 1.0)
	_weapon_mat = ShaderMaterial.new()
	_weapon_mat.shader = WeaponShader
	_weapon_mat.set_shader_parameter("amount", 0.0)
	## Ön katman: öndeki partiküller/parıltılar karakterin ve silahların ÖNÜNDE. show_behind_parent'lı bu düğümün çocuğu olsaydı o da arkada
	## kalırdı - bu yüzden ebeveynin (karakterin) KARDEŞİ olarak eklenir (doğum anında ebeveyn meşgul: call_deferred).
	_front = Node2D.new()
	_front.z_index = 0
	_front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_front.draw.connect(_draw_front)
	if _host != null:
		_host.add_child.call_deferred(_front)
	_apply_materials()


func _exit_tree() -> void:
	_restore_materials()
	if _front != null and is_instance_valid(_front):
		_front.queue_free()


func _flag_on() -> bool:
	if _host == null or not is_instance_valid(_host):
		return false
	if "_talon_mirror_form_active" in _host:
		return bool(_host._talon_mirror_form_active)
	if "_talon_form_active" in _host:
		return bool(_host._talon_form_active)
	return true


## Silah ikonları: yerel oyuncuda her silahın icon_sprite'ı, uzak kuklada _weapon_icons.
func _weapon_icon_nodes() -> Array:
	var out: Array = []
	if _host == null or not is_instance_valid(_host):
		return out
	if "owned_weapon_nodes" in _host:
		for w in _host.owned_weapon_nodes:
			if is_instance_valid(w) and "icon_sprite" in w and is_instance_valid(w.icon_sprite):
				out.append(w.icon_sprite)
	elif "_weapon_icons" in _host:
		for ic in _host._weapon_icons:
			if is_instance_valid(ic):
				out.append(ic)
	return out


## Boyama materyallerini takar. Her karede çağrılır: ayna kopyaları bir kare sonra doğar, silah sayısı form sürerken değişebilir.
## Başka bir sistem kendi materyalini takmışsa (boş değilse) dokunmaz.
func _apply_materials() -> void:
	if _anim != null and is_instance_valid(_anim) and _anim.material == null:
		_anim.material = _char_mat
	for ic in _weapon_icon_nodes():
		var ci := ic as CanvasItem
		if ci != null and ci.material == null:
			ci.material = _weapon_mat
			_tinted.append(ci)


func _restore_materials() -> void:
	if _anim != null and is_instance_valid(_anim) and _anim.material == _char_mat:
		_anim.material = null
	for ci in _tinted:
		if is_instance_valid(ci) and (ci as CanvasItem).material == _weapon_mat:
			(ci as CanvasItem).material = null
	_tinted.clear()


func _weapon_points() -> Array:
	var pts: Array = []
	if _host == null or not is_instance_valid(_host):
		return pts
	if "owned_weapon_nodes" in _host:
		for w in _host.owned_weapon_nodes:
			if is_instance_valid(w) and w.has_method("set_icon_offset"):
				pts.append((w as Node2D).global_position)
	elif "_weapon_icons" in _host:
		for ic in _host._weapon_icons:
			if is_instance_valid(ic):
				pts.append((ic as Node2D).global_position)
	return pts


func _process(delta: float) -> void:
	_t += delta
	if _host == null or not is_instance_valid(_host):
		queue_free()
		return
	var on: bool = _flag_on()
	if on:
		_seen_on = true
		_off_time = 0.0
	else:
		_off_time += delta
	var should_close: bool = (_seen_on and _off_time > 0.4) or ((not _seen_on) and _t > NO_FLAG_GRACE)
	if should_close and _closing <= 0.0:
		_closing = 0.0001
	var fade: float = 1.0
	if _closing > 0.0:
		_closing += delta
		if _closing >= FADE_OUT:
			queue_free()
			return
		fade = clampf(1.0 - _closing / FADE_OUT, 0.0, 1.0)
		modulate.a = fade
		if _front and is_instance_valid(_front):
			_front.modulate.a = fade
	else:
		_apply_materials()
	var amount: float = clampf(_t / FADE_IN, 0.0, 1.0) * fade
	_char_mat.set_shader_parameter("amount", amount)
	_char_mat.set_shader_parameter("flash", 1.0 if _t < FLASH_TIME else 0.0)
	_weapon_mat.set_shader_parameter("amount", amount)
	## Kor + gövde parıltıları
	if _closing <= 0.0:
		_ember_acc += delta * EMBER_RATE
		while _ember_acc >= 1.0:
			_ember_acc -= 1.0
			_embers.append([randf_range(-17.0, 17.0), randf_range(6.0, 15.0), -randf_range(24.0, 40.0), randf_range(1.0, 2.5),
					randf_range(3.0, 5.0), randf_range(0.0, TAU), randf_range(0.9, 1.4), 0.0, randf() < 0.15, randf() < 0.7, randf() < 0.35])
		if _t > 0.3:
			_twinkle_acc += delta
			while _twinkle_acc >= TWINKLE_EVERY:
				_twinkle_acc -= TWINKLE_EVERY
				_twinkles.append([randf_range(-7.0, 7.0), randf_range(-18.0, 12.0), 0.0])
	for e in _embers:
		e[7] += delta
	_embers = _embers.filter(func(e): return float(e[7]) < float(e[6]))
	for tw in _twinkles:
		tw[2] += delta
	_twinkles = _twinkles.filter(func(tw): return float(tw[2]) < TWINKLE_LIFE)
	## Silah parıltıları (silah konumuna bağlı)
	if _closing <= 0.0 and randf() < delta * 10.0:
		var wp: Array = _weapon_points()
		if not wp.is_empty():
			var w: Vector2 = wp[randi() % wp.size()]
			_sparks.append([w - _host.global_position + Vector2(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0)), 0.0, randf_range(0.25, 0.4)])
	for s in _sparks:
		s[1] += delta
	_sparks = _sparks.filter(func(s): return float(s[1]) < float(s[2]))
	queue_redraw()
	if _front and is_instance_valid(_front):
		_front.queue_redraw()


static func _p_color(k: float, white: bool) -> Color:
	if k < 0.25:
		return P_WHITE if white else P_COLS[0]
	return P_COLS[1] if k < 0.6 else (P_COLS[2] if k < 0.85 else P_COLS[3])


## Karakterin bir sanat pikselinin ebeveyn yerelindeki boyu (form büyümesi dahil) - partiküller karakterin piksel ızgarasına oturur.
func _art_px() -> float:
	if _anim != null and is_instance_valid(_anim):
		return maxf(absf(_anim.scale.x), 0.01)
	return PixelDraw.TEXEL


func _draw_px(ci: CanvasItem, x: float, y: float, n: int, col: Color, art: float, grid: Vector2) -> void:
	ci.draw_rect(Rect2((Vector2(roundf(x), roundf(y)) + grid) * art, Vector2(n, n) * art), col)


func _draw_particles(ci: CanvasItem, front: bool) -> void:
	var art: float = _art_px()
	## Karakter karesinin piksel sınırları köke göre kesirli olabilir (characters.gd "offset") - aynı kaymayı uygula.
	var grid := Vector2.ZERO
	if _anim != null and is_instance_valid(_anim):
		grid = Vector2(fposmod(_anim.offset.x, 1.0), fposmod(_anim.offset.y, 1.0))
	for e in _embers:
		if bool(e[10]) != front:
			continue
		var age: float = e[7]
		var k: float = age / float(e[6])
		var x: float = float(e[0]) + float(e[3]) * sin(float(e[4]) * age + float(e[5]))
		var y: float = float(e[1]) + float(e[2]) * age * (1.0 - 0.25 * k)
		_draw_px(ci, x, y, 2 if (bool(e[9]) and k < 0.7) else 1, _p_color(k, bool(e[8])), art, grid)
	if _t < BURST_TIME: ## dönüşüm anı: dışa saçılan pikseller
		var bk: float = _t / BURST_TIME
		var ease_out: float = 1.0 - pow(1.0 - bk, 3.0)
		for i in range(BURST_COUNT):
			var a: float = TAU * float(i) / float(BURST_COUNT) + float(i % 3) * 0.11
			if (sin(a) > 0.0) != front:
				continue
			var r: float = 6.0 + (26.0 + 10.0 * float(i % 2)) * ease_out
			_draw_px(ci, cos(a) * r, -6.0 + sin(a) * r * 0.8, 2 if bk < 0.6 else 1, _p_color(bk, i % 5 == 0), art, grid)
	if front:
		for tw in _twinkles:
			var tx: float = roundf(float(tw[0]))
			var ty: float = roundf(float(tw[1]))
			_draw_px(ci, tx, ty, 1, Color.WHITE, art, grid)
			var tk: float = float(tw[2]) / TWINKLE_LIFE
			if tk > 0.25 and tk < 0.75:
				_draw_px(ci, tx + 1.0, ty, 1, TWINKLE_ARM, art, grid)
				_draw_px(ci, tx - 1.0, ty, 1, TWINKLE_ARM, art, grid)
				_draw_px(ci, tx, ty + 1.0, 1, TWINKLE_ARM, art, grid)
				_draw_px(ci, tx, ty - 1.0, 1, TWINKLE_ARM, art, grid)


## --- ARKA KATMAN: karakterin arkasındaki korlar ---
func _draw() -> void:
	_draw_particles(self, false)


## --- ÖN KATMAN: öndeki korlar, gövde parıltıları, silah parıltıları ---
func _draw_front() -> void:
	_draw_particles(_front, true)
	var texel: float = PixelDraw.TEXEL
	for s in _sparks:
		var k: float = float(s[1]) / float(s[2])
		var p: Vector2 = s[0]
		PixelDraw.px(_front, p, 1, Color.WHITE)
		if k > 0.25 and k < 0.75:
			PixelDraw.px(_front, p + Vector2(texel * 2.0, 0), 1, TWINKLE_ARM)
			PixelDraw.px(_front, p - Vector2(texel * 2.0, 0), 1, TWINKLE_ARM)
			PixelDraw.px(_front, p + Vector2(0, texel * 2.0), 1, TWINKLE_ARM)
			PixelDraw.px(_front, p - Vector2(0, texel * 2.0), 1, TWINKLE_ARM)
