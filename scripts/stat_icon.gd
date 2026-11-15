extends Control

## Oyundaki TÜM stat ikonlarının tek kaynağı (2026-11-13, kullanıcı seçimi):
## assets/ui/stat_icons/<id>.png - "Free - Raven Fantasy Icons" paketinin 16x16
## ikonları, en yakın komşu ile 3x (48x48, 1 sanat px = 3 ekran px). Seçim
## listesi: madde 661 (docs/notlar/madde_161-170.md). HUD mini paneli, envanter,
## satıcı, ruh dükkanı, karakter seçimi, yetenek ipucu ve oyun sonu da buraya bakar.

var _stat_id: String = ""
var _color: Color = Color(0.85, 0.85, 0.9, 1.0)

const ICON_DIR := "res://assets/ui/stat_icons/"

## stat id -> ICON_DIR içindeki dosya (her stat kendi ikonu; shield_max = shield_amount).
const ICON_PATHS := {
	"speed": "speed.png",
	"max_health": "max_health.png",
	"damage": "damage.png",
	"fire_rate": "fire_rate.png",
	"health_regen": "health_regen.png",
	"heal_power": "heal_power.png",
	"shield_protection": "shield_protection.png",
	"crit_chance": "crit_chance.png",
	"crit_damage": "crit_damage.png",
	"pickup_range": "pickup_range.png",
	"shield_pen_percent": "shield_pen_percent.png",
	"exp_gain": "exp_gain.png",
	"luck": "luck.png",
	"range": "range.png",
	"dodge": "dodge.png",
	"knockback": "knockback.png",
	"shield_amount": "shield_amount.png",
	"cooldown_reduction": "cooldown_reduction.png",
	"lifesteal": "lifesteal.png",
	"shield_regen": "shield_regen.png",
	"shield_max": "shield_amount.png",
	## Ruh dükkanı (meta_upgrades.gd "icon") - stat değil ama aynı set (kullanıcı seçimi 2026-11-13).
	"discount": "discount.png",
	"free_reroll": "free_reroll.png",
	"evo_reroll": "evo_reroll.png",
	"revive": "revive.png",
}

## stat_id -> Texture2D önbelleği, her setup() çağrısında yeniden yüklemesin diye.
static var _texture_cache: Dictionary = {}

var _texture: Texture2D = null


func setup(stat_id: String, badge_color: Color) -> void:
	_stat_id = stat_id
	_color = badge_color
	_texture = _load_texture(stat_id)
	queue_redraw()


func _load_texture(stat_id: String) -> Texture2D:
	if _texture_cache.has(stat_id):
		return _texture_cache[stat_id]
	var filename: String = ICON_PATHS.get(stat_id, "")
	var tex: Texture2D = null
	if filename != "":
		tex = load(ICON_DIR + filename) as Texture2D
	_texture_cache[stat_id] = tex
	return tex


func _draw() -> void:
	var r: float = min(size.x, size.y) * 0.5
	var c: Vector2 = size * 0.5

	if _texture:
		## En-boy oranını koruyarak, Control'ün sınırları içine ortalanmış
		## şekilde çiz (kullanıcının verdiği ikonlar kare değil, bkz. Hız.png
		## 201x167 gibi farklı oranlar - stretch etmek bozardı).
		var tex_size: Vector2 = _texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			var fit_scale: float = min(size.x / tex_size.x, size.y / tex_size.y)
			var draw_size: Vector2 = tex_size * fit_scale
			var draw_pos: Vector2 = (size - draw_size) * 0.5
			draw_texture_rect(_texture, Rect2(draw_pos, draw_size), false)
	else:
		## İkon dosyası bulunamazsa (eksik eşleme vb.) sessizce eski basit
		## daire+nokta yerine kategori renginde bir uyarı halkası göster.
		if r > 1.5:
			draw_arc(c, r - 1.5, 0, TAU, 40, _color, 2.5)
		if r > 0.0:
			draw_circle(c, r * 0.15, _color)
