extends Sprite2D

## ZAMAN DONDU GÖSTERGESİ (madde 327, 2026-10-20; kullanıcı: "oyuncular demirciye veya seyyar satıcıya girdiğinde yeteneklerinin ve yenilenmelerinin durduğunu
## gösteren bir simge olsun can ve kalkan barlarının üstünde"). Güvenli alandaki (satıcı koruma bölgesi / demirci iç mekanı) oyuncunun can barının hemen üstünde
## küçük bir kum saati: o oyuncunun can/kalkan yenilenmesi, yetenek/eşya beklemeleri, pasifleri ve evcil hayvanı DURMUŞ demektir (player.gd is_safe_zone_frozen).
## Bar üstü göz simgesiyle (brush_status_icon.gd, madde 275) aynı dil/ölçek: 1 sanat pikseli = 1 dünya pikseli, siyah kontür + 1 px gölge, doku desenden kodda
## kurulur (load() yok -> ilk basışta takılma/ısınma listesi gerekmez). Her peer güvenli alan durumunu zaten biliyor (is_in_merchant_zone anlık görüntüde,
## demirci konumdan) -> ek RPC yok; oyuncu kendi simgesini de arkadaşlarınınkini de görür. Oyuncunun kendi buff/debuff satırındaki rozet: status_effect_badge.gd "time_frozen".

const TEXEL := 1.0 ## 1 sanat pikseli = bu kadar dünya pikseli (ebeveyn ölçeğinden bağımsız)
const GAP := 3.0   ## can barının üstüyle simgenin altı arası (çubuğun yerel birimi)
const POP_TIME := 0.22
const HIDE_TIME := 0.12

## o kontür, f çerçeve (buz çeliği), g cam, h cam parıltısı, s kum
const GLASS := [
	"ooooooooooo",
	"offfffffffo",
	"ooooooooooo",
	".ohggggggo.",
	".oggsssggo.",
	"..ossssso..",
	"...ossso...",
	"....oso....",
	"...ogsgo...",
	"..oggsggo..",
	".ogsssssgo.",
	".ossssssso.",
	"ooooooooooo",
	"offfffffffo",
	"ooooooooooo",
]
const PALETTE := {
	"o": Color8(18, 22, 34), "f": Color8(150, 176, 200), "g": Color8(196, 228, 248), "h": Color8(255, 255, 255), "s": Color8(244, 206, 96),
}

static var _tex_cache: Texture2D = null

var shown: bool = false
var _bar_top: float = -68.0
var _lift: float = 0.0
var _base_scale: float = 1.0
var _tween: Tween = null


## Dokunun görüntüsü (saf; testler çağırır): kum saati + 1 px yarı saydam gölge.
static func build_image() -> Image:
	var h: int = GLASS.size()
	var w: int = (GLASS[0] as String).length()
	var img := Image.create(w + 1, h + 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(h):
		var row: String = GLASS[y]
		for x in range(w):
			if row[x] != "." and img.get_pixel(x + 1, y + 1).a == 0.0:
				img.set_pixel(x + 1, y + 1, Color(0, 0, 0, 0.35))
	for y in range(h):
		var row: String = GLASS[y]
		for x in range(w):
			var k: String = row[x]
			if k != ".":
				img.set_pixel(x, y, PALETTE[k])
	return img


static func shared_texture() -> Texture2D:
	if _tex_cache == null:
		_tex_cache = ImageTexture.create_from_image(build_image())
	return _tex_cache


## Simgenin dokusunun yüksekliği (gölge satırı dahil) - brush simgesinin üstüne dizilirken kaç piksel yukarı kayacağını overhead_bar.gd hesaplar.
static func art_height() -> int:
	return GLASS.size() + 1


func _ready() -> void:
	name = "TimeFrozenIcon"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
	visible = false
	texture = shared_texture()
	## pivot alt-ortada (tam piksel): yaylanma alttan büyür, tek sayılı genişlik yarım piksele düşmez
	centered = false
	offset = Vector2(-floorf(float((GLASS[0] as String).length() + 1) * 0.5), -float(GLASS.size() + 1))


## overhead_bar.gd çağırır: on = oyuncu güvenli alanda mı, bar_top = can barının üst kenarı (çubuğun yerel y'si), lift = üstündeki başka simgenin kapladığı yükseklik.
func show_state(on: bool, bar_top: float, lift: float = 0.0) -> void:
	_bar_top = bar_top
	_lift = lift
	_place()
	if on == shown:
		return
	shown = on
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not on:
		if not visible:
			return
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(self, "scale", Vector2.ONE * _base_scale * 0.4, HIDE_TIME)
		_tween.tween_property(self, "modulate:a", 0.0, HIDE_TIME)
		_tween.chain().tween_callback(func() -> void: visible = false)
		return
	visible = true
	modulate.a = 1.0
	scale = Vector2.ONE * _base_scale * 0.35
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * _base_scale, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_bar_top(bar_top: float, lift: float = 0.0) -> void:
	_bar_top = bar_top
	_lift = lift
	_place()


## Ölçek: 1 sanat pikseli = TEXEL dünya pikseli (karakter kökü 0,5 ölçekli; kuklanın ölçeği farklı olabilir). Konum: dokunun altı can barının GAP üstünde, ortada.
func _place() -> void:
	var ps: float = absf(get_parent().global_scale.y) if get_parent() is Node2D else 1.0
	_base_scale = TEXEL / (ps if ps > 0.01 else 1.0)
	position = Vector2(0.0, _bar_top - GAP - _lift)
	if _tween == null or not _tween.is_valid():
		scale = Vector2.ONE * _base_scale
