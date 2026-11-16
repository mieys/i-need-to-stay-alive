extends Node2D

## YER EVCİLİ DERİNLİK VEKİLİ (2026-11-16, kullanıcı: "hala Y ekseni sorunları var yaratıklar arasında" - ekranda oyuncunun önünde z 2'ye çıkan
## sıçan, ÖNÜNDEKİ Minik Cadı'nın üstüne çiziliyordu). Kirpi / Minik Cadı sahibin `top_level` çocuğu: Godot'ta top_level öğe tuvalin KÖKÜNE
## asılır (mutlak z 0, Main'in z 0 alt ağacının hep üstünde) - yaratıkların ayak sırasına (main.gd _update_creature_draw_order, C++ draw index)
## ve creature_depth.gd'nin z 2 yükseltmesine hiç girmiyordu; sahibin çocuk sırası (eski `_update_draw_order` move_child) da etkisizdi.
## Çözüm: hayvanın GÖRSELİ bu vekile (Main'in doğrudan çocuğu, "ysort_pets" grubu) taşınır; vekil her kare hayvanın konumunu/ölçeğini/görünürlüğünü
## izler. Hayvanın mantığı (takip, ağ, büyü) sahibin altında aynen kalır. Böylece hayvan yaratıklarla aynı ayak sırasında + oyuncunun önündeyken
## creature_depth.gd ile z 2'ye çıkar (ALLY_DEPTH_GROUPS).

const GROUP := "ysort_pets"

var pet: Node2D = null


## Görseli vekile taşır. Sahibin ebeveyni Main değilse (menü / test sahnesi) null döner: çağıran görseli eskisi gibi kendine ekler.
static func host(proxy_script: GDScript, p: Node2D, owner_node: Node2D, visual: Node2D) -> Node2D:
	var main: Node = owner_node.get_parent() if owner_node != null else null
	if main == null or not main.has_method("_creature_foot_y"):
		return null
	var h: Node2D = proxy_script.new()
	h.pet = p
	h.name = "PetDepth_" + str(p.name)
	h.add_to_group(GROUP)
	h.process_priority = 100 ## hayvan (öncelik 0) bu karede hareket ettikten SONRA izler
	visual.name = "AnimatedSprite2D" ## main.gd _find_creature_visual / creature_depth _extent bu adla bulur
	h.add_child(visual)
	h.visible = false ## ilk eşitlemeye kadar (0,0'da bir kare görünmesin)
	main.add_child.call_deferred(h) ## sahibin _ready'sinden çağrılabilir: Main çocuk kurarken add_child reddedilir
	return h


func _ready() -> void:
	sync()


func _process(_delta: float) -> void:
	sync()


func sync() -> void:
	if not is_instance_valid(pet):
		queue_free()
		return
	if not pet.is_inside_tree():
		visible = false
		return
	global_position = pet.global_position
	global_scale = pet.global_scale
	modulate = pet.modulate
	visible = pet.is_visible_in_tree()
