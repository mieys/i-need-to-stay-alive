extends TotemBase
class_name TotemArea

## Alan Saldırı Totemi (Shaman R, skill3 id 28): "Totem etrafına bir alan
## açar, o alanın içine giren düşmanlar %20 + shaman'ın saldırı gücünün
## %20'si kadar yavaşlar (10 saldırı gücü = %2 yavaşlatma, en fazla %80).
## Ayrıca alanın içinde duran düşmanlar her saniye shaman'ın saldırı
## gücünün %20'si kadar hasar alır."
##
## Yavaşlatma enemy.gd'nin GENEL apply_slow(percent, duration) fonksiyonuna
## (bkz. orada - "aynı vuruşta en güçlüsü kalır" deseni, zaten var olan bir
## mekanizma, ikinci bir kopya yazılmadı) kısa bir süreyle (bu totem'in kendi
## TICK_INTERVAL'inden biraz uzun) her tik yeniden uygulanıyor - düşman
## alanda durduğu sürece sürekli tazelenir, çıkınca kendiliğinden biter.
## NOT: apply_slow() kendi içinde %75 ile sınırlıyor - kullanıcının istediği
## %80 tavanı bu yüzden pratikte %75'te kalıyor (mevcut genel mekanizmaya
## ikinci bir paralel sistem eklemek yerine kabul edilen küçük bir sapma).
const BASE_SLOW_PERCENT := 0.20
const SLOW_PER_ATTACK_POWER := 0.002 ## 10 saldırı gücü = %2 (0.002*10=0.02)
const MAX_SLOW_PERCENT := 0.80
const DAMAGE_ATTACK_POWER_RATIO := 0.20
const SLOW_REFRESH_DURATION := 1.5 ## TICK_INTERVAL'den (1.0sn) biraz uzun - alanda duran düşmanda hiç boşluk kalmaz

## Yeteneğe özgü efektler (KOZMETİK - yavaşlatma/hasar hesaplarıyla ilgisi yok). Kullanıcı isteği (2026-09-24): "Alan hasarı veren
## mor totemin de daha minimalist bir alana sahip olmasını istiyorum ... pixel tarzda ... sprite'a dönüştür performans kaybı olmasın".
## Eski: shaders/totem_void_aura.gdshader (her karede ~376x376 ekran karesi için dither girdap + 16 rün + çift halka), her tikte
## prosedürel _draw nabız halkası (TotemShieldWave.spawn_pulse) ve düşmanlarda prosedürel PixelDraw "void" patlaması.
## Yeni: üçü de tools/gen_shaman_area_fx.py'nin pişirdiği spritesheet'ler, her biri TEK AnimatedSprite2D (bkz. fx_enemy_ability.gd):
##  - AURA: keskin 1 texel mor çember + çok soluk düz dolgu + çemberde sırayla parlayan 6 küçük ay rünü (döngü, 12 kare / 6 fps)
##  - NABIZ: her tikte totem dibinden yayılan ince halka (tek seferlik)
##  - RUH: alan hasarı yiyen düşmanın üstünde kıvrılarak yükselen küçük mor ruh (tek seferlik)
## Hepsi hem gerçek totemde hem ağ görsel kopyasında kurulur (salt görsel) - diğer oyuncular da aynı alanı görür.
const AURA_FRAMES := preload("res://assets/fx/shaman_area/aura_frames.tres")
const PULSE_FRAMES := preload("res://assets/fx/shaman_area/pulse_frames.tres")
const WISP_FRAMES := preload("res://assets/fx/shaman_area/wisp_frames.tres")
const FxSprite := preload("res://scripts/fx_enemy_ability.gd")
const WISP_OFFSET := Vector2(0, -10)
var _aura: AnimatedSprite2D = null


func _init() -> void:
	totem_kind = "area"
	totem_color = Color(0.65, 0.35, 0.85)
	totem_radius = 180.0
	aura_fill_alpha = 0.0
	use_custom_aura = true ## menzil halkası/dolgu artık TotemBase._draw'da değil, aşağıdaki sprite aurada (bkz. _build_area_aura)


func _ready() -> void:
	super()
	_build_area_aura()


func _build_area_aura() -> void:
	_aura = AnimatedSprite2D.new()
	_aura.name = "AreaAura"
	_aura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_aura.sprite_frames = AURA_FRAMES
	_aura.scale = Vector2.ONE * PixelDraw.TEXEL ## 148 sanat px yarıçap * 1.212 = ~180 birim (totem_radius)
	add_child(_aura)
	move_child(_aura, 0) ## totem gövdesinin (TotemSprite) ARKASINDA çizilsin
	_aura.play(&"loop")
	_aura.modulate.a = 0.0
	create_tween().tween_property(_aura, "modulate:a", 1.0, 0.8)


## Her tik'te (TICK_INTERVAL) totemin dibinden ince nabız halkası + alçak "vızıltı". Gerçek totemde de, ağ kopyasında da çalışır
## (salt görsel/ses - oyun durumu paylaşmaz), yani herkes alanın "çalıştığını" görür ve duyar.
var _pulse_timer: float = 0.0

func _process(delta: float) -> void:
	super(delta)
	_pulse_timer -= delta
	if _pulse_timer > 0.0:
		return
	_pulse_timer += TICK_INTERVAL
	var scene: Node = get_tree().current_scene
	if scene == null or not is_instance_valid(scene):
		return
	var pulse: Node2D = FxSprite.spawn(self, global_position, PULSE_FRAMES, &"play", 0)
	if pulse:
		move_child(pulse, 1) ## auranın üstünde, totem gövdesinin altında (zemindeki halka)
	ShamanSfx.play_at(scene, ShamanSfx.AREA_PULSE, global_position, -18.0, 0.05)
	## Ağ görsel kopyası hasar tikini çalıştırmaz (_tick sadece dikenin client'ında) - diğer oyuncular da "alan hasar veriyor"
	## sinyalini görsün diye kopya, alandaki düşmanların üstünde AYNI ruh efektini kendi nabzında oynatır (salt görsel).
	if _is_network_visual:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Node2D and is_instance_valid(e) and e.get("is_dead") != true 					and global_position.distance_to((e as Node2D).global_position) <= totem_radius:
				_spawn_void_wisp((e as Node2D).global_position)


## Hasar tikinde düşmanın üstünde kısa süreli mor ruh - "bu düşman şu an alan hasarı yiyor" sinyali. Salt kozmetik.
func _spawn_void_wisp(enemy_pos: Vector2) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or not is_instance_valid(scene):
		return
	FxSprite.spawn(scene, enemy_pos + WISP_OFFSET, WISP_FRAMES, &"play", 2)


func _tick() -> void:
	if not ("damage_bonus" in caster):
		return
	var attack_power: float = float(caster.damage_bonus)
	var slow_percent: float = clamp(BASE_SLOW_PERCENT + attack_power * SLOW_PER_ATTACK_POWER, 0.0, MAX_SLOW_PERCENT)
	var dmg: float = attack_power * DAMAGE_ATTACK_POWER_RATIO
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if not (e is Node2D):
			continue
		if global_position.distance_to((e as Node2D).global_position) > totem_radius:
			continue
		if e.has_method("apply_slow"):
			e.apply_slow(slow_percent, SLOW_REFRESH_DURATION)
		if dmg > 0.0 and e.has_method("take_damage"):
			var is_crit: bool = false
			if caster.has_method("_roll_ability_crit"):
				is_crit = caster._roll_ability_crit()
			var hit_dmg: float = dmg
			if caster.has_method("_apply_ability_crit"):
				hit_dmg = caster._apply_ability_crit(dmg, is_crit)
			e.call("take_damage", hit_dmg, is_crit)
			## Yetenek efekti: hasar yiyen düşmanın üstünde boşluk perisi.
			_spawn_void_wisp((e as Node2D).global_position)
