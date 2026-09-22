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
	node.queue_redraw()
	return true


func _draw() -> void:
	PixelDraw.ground_shadow(self, Vector2.ZERO, radius, edge_color, core_color)
