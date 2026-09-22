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

## Yeteneğe özgü efekt (KOZMETİK - yavaşlatma/hasar hesaplarıyla ilgisi yok):
## alanın içinde dönen boşluk girdabı (_draw) + alandaki düşmanların her tik
## hasarında üstlerine kısa birer boşluk perisi (_spawn_void_wisp).
const WISP_PARTICLES := 5


func _init() -> void:
	totem_kind = "area"
	totem_color = Color(0.65, 0.35, 0.85)
	totem_radius = 180.0
	## Yavaşlatma bölgesinin İÇİ hafif mor pixel "toz" noktalarıyla dolsun (TotemBase._draw - aura_fill_alpha > 0 ise).
	aura_fill_alpha = 0.0
	use_custom_aura = true ## menzil halkası/dolgu/spiral artık TotemBase'te değil, aşağıdaki shader aurada (bkz. _build_void_aura)


## Kullanıcı isteği (2026-09-22): "mor totemin etrafında açtığı aura çok kötü, pixel tarzda yeniden tasarla" - eski aura seyrek noktalı soluk halka +
## dağınık spiral noktalarıydı. Yeni: shaders/totem_void_aura.gdshader (texel ızgarasına oturan büyü çemberi + dönen rünler + dither boşluk
## girdabı + yükselen kıvılcımlar). Gerçek totemde de, ağ kopyasında da AYNI kurulur (salt görsel).
const AURA_SHADER := preload("res://shaders/totem_void_aura.gdshader")
var _aura: ColorRect = null


func _ready() -> void:
	super()
	_build_void_aura()


func _build_void_aura() -> void:
	var size_px: float = totem_radius * 2.0 + 20.0
	_aura = ColorRect.new()
	_aura.name = "VoidAura"
	_aura.color = Color(1, 1, 1, 1)
	_aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aura.size = Vector2(size_px, size_px)
	_aura.position = -_aura.size * 0.5
	var mat := ShaderMaterial.new()
	mat.shader = AURA_SHADER
	mat.set_shader_parameter("radius_px", totem_radius)
	mat.set_shader_parameter("texel", PixelDraw.TEXEL)
	mat.set_shader_parameter("quad_size", Vector2(size_px, size_px))
	_aura.material = mat
	add_child(_aura)
	move_child(_aura, 0) ## totem gövdesinin (TotemSprite) ARKASINDA çizilsin
	_aura.modulate.a = 0.0
	create_tween().tween_property(_aura, "modulate:a", 1.0, 0.8)


## Her tik'te (TICK_INTERVAL) girdap nabzı: totemin etrafında yayılan mor pixel halka + alçak "vızıltı". Gerçek totemde de, ağ
## kopyasında da çalışır (salt görsel/ses - oyun durumu paylaşmaz), yani herkes alanın "çalıştığını" görür ve duyar.
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
	TotemShieldWave.spawn_pulse(scene, global_position, totem_color)
	ShamanSfx.play_at(scene, ShamanSfx.AREA_PULSE, global_position, -18.0, 0.05)


const TotemShieldWave := preload("res://scripts/totem_shield_wave.gd")


## Hasar tikinde düşmanın üstünde kısa süreli boşluk perisi - "bu düşman şu
## an alan hasarı yiyor" sinyali. Salt kozmetik, hasar hesabı _tick'te bitti.
func _spawn_void_wisp(enemy_pos: Vector2) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or not is_instance_valid(scene):
		return
	PixelDraw.spawn_burst(scene, enemy_pos + Vector2(0, -10), "void", WISP_PARTICLES + 3, 70.0, 0.45)


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
