extends Node2D
class_name GroundShadow

## Karakterin AYAK GÖLGESİ (piksel elips) - kullanıcı isteği (2026-09-22): "Vampirin altına gölge ekle". Eski LPC karakterlerin gölgesi
## sprite karelerinin İÇİNE gömülü (bkz. player.gd "Generator'dan çıkan karakterlerin gölgesi karelerin içinde gömülü") ama yeni Vampir
## sayfalarında gölge yok; Characters.DEFS'te "ground_shadow" (yarıçap, px) + "ground_shadow_y" (ayak çizgisine göre konum) veren
## karakterler bunu kullanır. Yerel oyuncu (player.gd) ve uzak oyuncu (remote_player.gd) AYNI apply_to()'yu çağırır - iki taraf sapmaz
## (bkz. CLAUDE.md). Çizim: her satır 1 texel yüksekliğinde, genişliği texel ızgarasına oturtulmuş dikdörtgenler => sert pixel kenar
## (bulanık/yumuşak elips değil), kenarda hafif, ortada koyu iki kat.
##
## Düğüm karakterin AnimatedSprite2D'sinden ÖNCE çizilir (Shadow düğümü sahnede sprite'ın üstünde durur), yani sprite'ın altında kalır.

const PixelDraw := preload("res://scripts/pixel_draw.gd")

@export var radius: Vector2 = Vector2(19.0, 7.0)
@export var edge_color: Color = Color(0.0, 0.0, 0.0, 0.28)
@export var core_color: Color = Color(0.0, 0.0, 0.0, 0.2)

## ÖLÜM / YERE DÜŞME (kullanıcı isteği 2026-09-25: "karakter ölünce gölgesi genişlemeli çünkü yere uzanıyor ölürken"):
## yeni sayfalarda ölüm pozu HER yönde yatay uzanır (ölçüm: gövde ~35x11 sanat pikseli, standing ~14-16 genişlik) -
## gölge LYING_TIME içinde yatık gövdenin genişliğine açılır ve gövdenin ortasına kayar (aşağı/sol yönlerinde gövde
## karenin soluna, sağ/yukarı yönlerinde sağına uzanıyor). Ebeveynin (Player / RemotePlayer) is_dead/is_downed
## bayrağını okur - uzak kopya da aynı bayraklar senkronlandığı için AYNI görünür (bkz. CLAUDE.md).
const LYING_TIME := 0.35
const LYING_HALF_ART := 16.0 ## yatık gövdenin yarı genişliği (sanat pikseli)
const LYING_SHIFT_ART := {"down": -4.0, "left": -4.0, "right": 3.5, "up": 3.5}
## Yatık gölgenin ayak çizgisine göre dikey kayması (sanat pikseli, + = aşağı). Gerçek oyun görüntüsünde ölçüldü
## (2026-09-25): gölge gövdenin ortasına konunca yatan gövde onu TAMAMEN örtüyordu (sadece 1 px'lik çizgi kalıyordu) -
## hafif aşağı kaydırılıp dikeyde kalınlaştırılınca (LYING_RY_MULT) gövdenin altından belirgin şekilde taşar.
const LYING_DROP_ART := 1.0
const LYING_RY_MULT := 1.35
var _lying: float = 0.0
var _lie_dx: float = 0.0


## `node` sahnedeki mevcut "Shadow" düğümü (player.tscn / remote_player.tscn - eski blob gölgesi). DEFS'te "ground_shadow" yoksa
## çağıran taraf eskisi gibi davranır (player.gd gizler); varsa düğümün scriptini bununla değiştirir ve konumlar.
static func apply_to(node: Node2D, def: Dictionary) -> bool:
	if node == null or not is_instance_valid(node) or not def.has("ground_shadow"):
		return false
	node.set_script(load("res://scripts/ground_shadow.gd"))
	node.scale = Vector2.ONE
	node.position = Vector2(0.0, float(def.get("ground_shadow_y", 33.4)))
	node.visible = true
	node.set("radius", def["ground_shadow"])
	## Betik çalışma anında değiştirildiği için _process kendiliğinden açılmayabilir (bkz. ölüm gölgesi notu).
	node.set_process(true)
	node.queue_redraw()
	return true


func _process(delta: float) -> void:
	var host: Node = get_parent()
	var lying: bool = host != null and (host.get("is_dead") == true or host.get("is_downed") == true)
	if lying:
		var spr: AnimatedSprite2D = host.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if spr != null:
			var anim_name: String = String(spr.animation)
			var dir: String = anim_name.get_slice("_", anim_name.get_slice_count("_") - 1)
			_lie_dx = float(LYING_SHIFT_ART.get(dir, 0.0))
	var target: float = 1.0 if lying else 0.0
	if _lying != target:
		_lying = move_toward(_lying, target, delta / LYING_TIME)
		queue_redraw()


## Karakterin 1 sanat pikselinin dünya boyu (sprite ölçeği; yeni sayfalarda ~2.125).
func _art_px() -> float:
	var host: Node = get_parent()
	var spr: Node2D = host.get_node_or_null("AnimatedSprite2D") as Node2D if host != null else null
	return absf(spr.scale.x) if spr != null else 2.125


func _draw() -> void:
	var r: Vector2 = radius
	var center := Vector2.ZERO
	if _lying > 0.0:
		var e: float = _lying * _lying * (3.0 - 2.0 * _lying)
		var s: float = _art_px()
		var lying_r := Vector2(maxf(radius.x, LYING_HALF_ART * s * 0.95), radius.y * LYING_RY_MULT)
		r = radius.lerp(lying_r, e)
		center = Vector2(_lie_dx * s, LYING_DROP_ART * s) * e
	PixelDraw.ground_shadow(self, center, r, edge_color, core_color)
