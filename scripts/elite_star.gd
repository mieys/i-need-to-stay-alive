extends Node2D

## Elit yaratığın başının üstündeki mor piksel yıldız (kullanıcı isteği 2026-10-02: "yaratığın görünümü asla değişmeyecek
## sadece üst tarafına mor bi pixel yıldız gözükecek"). enemy.gd make_elite() ekler - host'taki gerçek yaratık ve
## istemcilerdeki kopya AYNI fonksiyondan geçtiği için (enemy_spawner.gd _apply_elite) herkes aynı yıldızı görür.
## Çizim 1 texel = PixelDraw.TEXEL (karakter piksel yoğunluğu); yaratık kökü ölçeklenmez (büyütme sprite/çarpışmada), yıldız hep aynı boyda.

const PixelDraw := preload("res://scripts/pixel_draw.gd")

## 9x9: koyu mor kontur (o), mor gövde (p), açık mor ışık (l), beyaz parıltı (w).
const STAR := [
	"....o....",
	"...opo...",
	"oooplpooo",
	"opplwlppo",
	".opppppo.",
	"..opppo..",
	".oppoppo.",
	".opo.opo.",
	".oo...oo.",
]
const PALETTE := {
	"o": Color(0.20, 0.06, 0.32),
	"p": Color(0.62, 0.26, 0.92),
	"l": Color(0.84, 0.60, 1.0),
	"w": Color(1.0, 0.96, 1.0),
}
const BOB_AMP := 1.5 ## texel
const BOB_SPEED := 2.4

var base_y: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_t = randf() * TAU
	position.y = base_y


func _process(delta: float) -> void:
	var host: Node = get_parent()
	if host != null and host.get("is_dead") == true:
		queue_free()
		return
	## Hayalet görünmezliğinde (enemy.gd set_ability_invisible) yıldız da gizlenir - gizli yaratığın yerini ele vermesin.
	visible = host == null or host.get("is_ability_invisible") != true
	_t += delta * BOB_SPEED
	position.y = base_y + roundf(sin(_t) * BOB_AMP) * PixelDraw.TEXEL


func _draw() -> void:
	PixelDraw.art(self, Vector2.ZERO, STAR, PALETTE)
