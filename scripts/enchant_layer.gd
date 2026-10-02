extends RefCounted

## Efsun efektlerinin çizim katmanı - TEK KAYNAK (kullanıcı bildirimi 2026-10-02: "silah efsunları effectleri karakterlerin
## üstünde gözüküyor, katman olarak altında gözükmeli").
##
## Oyuncular (yerel Player + uzak kuklalar) z_index = 1'de (main.tscn, main.gd _update_character_draw_order). Efsun
## efektleri eskiden 2..12 arasındaydı (alanlar 3/9, halkalar 8, sprite'lar 2/8/9, patlama 12, kıvılcım 20) -> karakterin
## üstüne biniyordu. Artık hepsi Z'de: oyuncuların ALTINDA, zeminin ve kendinden önce doğmuş yaratıkların üstünde
## (vuruş efekti yaratığın üzerinde görünmeye devam eder). "ground" işaretli olanlar ayrıca haritanın hemen arkasına
## taşınır (EnemyAbilities.place_on_ground). Ayrı dosya: enchant_fx.gd <-> fx_enchant_*.gd döngüsel preload olmasın diye.
## Kullananlar: enchant_fx.gd spawn, fx_enchant_sprite.gd, fx_enchant_pixel.gd, enchant_area.gd.
const Z := 0


## Düğümü efsun katmanına indir (düğümün kendi _ready'si z_index'i ezdiği için add_child'DAN SONRA çağrılır).
static func apply(node: CanvasItem) -> void:
	if node != null and is_instance_valid(node):
		node.z_index = Z
		node.z_as_relative = true
