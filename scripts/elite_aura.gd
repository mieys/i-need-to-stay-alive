extends Node2D

## Elit yaratık aurası - "B - Yükselen Kıvılcımlar" (kullanıcı seçimi 2026-10-02, 4 prototipten;
## https://claude.ai/artifact/Wavi4u7gKgLhAUwiXEYM6D). Sayfa tools/gen_elite_aura.py ile üretilir
## (assets/fx/elite/elite_aura.png: 16 kare x 2 satır - üst ARKA, alt ÖN katman).
##
## enemy.gd make_elite() ekler; host'taki gerçek yaratık ve istemcideki kopya AYNI yoldan geçtiği için herkes aynı aurayı
## görür, ağdan veri gitmez. Bu düğüm ÖN katmandır (yaratığın sprite'ından SONRA eklenir -> önünde); ARKA katman ayrı bir
## Sprite2D olarak yaratığın ilk çocuğu yapılır (sprite'ın altında). Düğüm ayak noktasında durur (gece ışığı da orada).
## Gece ışığı: night_glow_catalog.gd BY_SCRIPT (mor, sisteyken çizilmez - gizli yaratığın yerini ele vermesin).
## Yaratık ölünce ya da hayalet görünmezliğindeyken (is_ability_invisible) aura da gizlenir.

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const SHEET := preload("res://assets/fx/elite/elite_aura.png")
const FRAMES := 16
const FPS := 10.0
## Sayfadaki ayak merkezi ve referans ayak elipsinin yarı genişliği (texel) - gen_elite_aura.py CX/FY/REF_RX ile aynı.
const FOOT := Vector2(40.0, 60.0)
const REF_RX := 22.0
## Aura elipsinin yarı genişliği = gövde genişliğinin bu kadarı (prototipte onaylanan oran).
const BODY_FILL := 0.42

## Gece ışığı yarıçapı (night_glow_catalog "rp").
var glow_radius: float = 40.0

var _back: Sprite2D = null
var _front: Sprite2D = null
var _t: float = 0.0


## foot: yaratık kökü koordinatında ayak (gölge) merkezi; body_width: görünen gövde genişliği (dünya birimi).
func setup(host: Node2D, foot: Vector2, body_width: float) -> void:
	position = foot
	## Ölçek yarım adımlarla (1, 1.5, 2...) - piksel ızgarası düzensizleşmesin; küçük yaratıklarda en az 1.
	var aura_scale: float = maxf(1.0, roundf(body_width * BODY_FILL / (REF_RX * PixelDraw.TEXEL) * 2.0) / 2.0)
	var s: float = aura_scale * PixelDraw.TEXEL
	glow_radius = REF_RX * s * 1.6
	_front = _make_sprite(s)
	add_child(_front)
	_back = _make_sprite(s)
	_back.name = "EliteAuraBack"
	_back.position = foot
	host.add_child(_back)
	host.move_child(_back, 0) ## yaratığın sprite'ından ÖNCE çizilsin
	_t = randf() * float(FRAMES) / FPS
	_apply_frame()


func _make_sprite(s: float) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = SHEET
	spr.hframes = FRAMES
	spr.vframes = 2
	spr.centered = false
	spr.offset = -FOOT
	spr.scale = Vector2(s, s)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return spr


func _process(delta: float) -> void:
	var host: Node = get_parent()
	if host == null or host.get("is_dead") == true:
		_free_all()
		return
	var hidden_now: bool = host.get("is_ability_invisible") == true
	visible = not hidden_now
	if _back and is_instance_valid(_back):
		_back.visible = not hidden_now
	_t += delta
	_apply_frame()


func _apply_frame() -> void:
	var f: int = int(_t * FPS) % FRAMES
	if _back and is_instance_valid(_back):
		_back.frame = f
	if _front and is_instance_valid(_front):
		_front.frame = FRAMES + f


func _free_all() -> void:
	if _back and is_instance_valid(_back):
		_back.queue_free()
	_back = null
	queue_free()
