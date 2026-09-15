extends Control

## Level atlama kartlarındaki her stat için kullanıcının verdiği gerçek
## piksel-art ikonlar (bkz. assets/ui/level_up_icons/) - eskiden burada
## kodla çizilen geçici glyph'ler vardı (bkz. git geçmişi), artık gerçek
## sanat eserleriyle değiştirildi.
##
## "shield_protection" (Kalkan Soğurma) ve "shield_amount" (Kalkan Miktarı)
## için AYRI bir ikon verilmedi - ikisi de aynı "stat_shield.png" dosyasını
## kullanıyor (tek bir "Kalkan" ikonu gönderildiği için). Aynı sebeple
## "health_regen" (Can Yenilenmesi) de kendine özel bir ikon yerine
## "max_health" ile aynı kalp ikonunu ("stat_max_health.png") paylaşıyor.

var _stat_id: String = ""
var _color: Color = Color(0.85, 0.85, 0.9, 1.0)

const ICON_DIR := "res://assets/ui/level_up_icons/"

## DÜZELTME (kullanıcı isteği: "zırh statını ve zırhla ilgili herşeyi
## oyundan kaldır, zırh delme yerini kalkan delme alacak") - "armor" anahtarı
## kaldırıldı, "armor_pen_percent" -> "shield_pen_percent" olarak yeniden
## adlandırıldı (aynı görsel dosya, stat_armor_pen_percent.png, korundu -
## sadece hangi stat id'sine eşlendiği değişti).
const ICON_PATHS := {
	"speed": "stat_speed.png",
	"max_health": "stat_max_health.png",
	"damage": "stat_damage.png",
	"fire_rate": "stat_fire_rate.png",
	"health_regen": "stat_max_health.png",
	"shield_protection": "stat_shield.png",
	"crit_chance": "stat_crit_chance.png",
	"crit_damage": "stat_crit_damage.png",
	"pickup_range": "stat_pickup_range.png",
	"shield_pen_percent": "stat_armor_pen_percent.png",
	"exp_gain": "stat_exp_gain.png",
	"luck": "stat_luck.png",
	"range": "stat_range.png",
	"dodge": "stat_dodge.png",
	"knockback": "stat_knockback.png",
	"shield_amount": "stat_shield.png",
	"cooldown_reduction": "stat_speed.png",
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
