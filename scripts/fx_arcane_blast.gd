extends Node2D
class_name FxArcaneBlast

## Büyücü "Arcane Patlama" (E1) patlaması - "M1 Yıldız Tozu" (2026-11-11, madde 563; kullanıcı 3 turdan sonra seçti: "dümdüz bir halka
## büyüyormuş gibi değil, hafif sihir patlaması"). Eski "Kadim Patlama" mühür efektinin (fx_mage_passive_burst, silindi) yerine.
##   ön (z 50, yaratıkların üstü): merkezde 8 kollu parıltı + 16 ışık tozu hafif sarmal çizip alanın kenarına konar, pırıldayıp yükselir
##   zemin (GroundSlot.place: haritanın üstü, yaratıkların altı): tozun konduğu yerde kısa yatay pırıltı
## İkisi TOPLAMALI (BuyucuFx.add_material). Sayfa DRAWN_RADIUS yarıçap için çizildi; bu düğümün ölçeği = gerçek yarıçap / DRAWN_RADIUS
## (Efsunlu Büyü büyütür). Kaster (player.gd _spawn_world_explosion_fx) ve uzak kopya (network_manager "hitscan_impact" scene_path +
## fx_scale) AYNI sahne; global_position add_child'dan SONRA kurulduğu için sayfalar bir sonraki karede (call_deferred) doğar.
## Müttefik efekt yoğunluğu (ally_fx_density.gd soften) bu düğümün modulate'ini kısar -> sayfalara kopyalanır.
## Sanat: tools/gen_arcane_blast_fx.py (prototip çizimi birebir).

const BuyucuFxScript := preload("res://scripts/buyucu_fx.gd")
const GroundSlotScript := preload("res://scripts/ground_slot.gd")
const FPS := 20.0
const FRAMES := 12
const DRAWN_RADIUS := 52.5 ## tools/gen_arcane_blast_fx.py / prototip BLAST_WORLD ile aynı
const FRONT_Z := 50
## İlk patlamada diskten okuma takılması olmasın: sayfalar burada tutulur (player.gd sahneyi preload eder -> oyun açılırken yüklenir;
## BuyucuFx.tex aynı kaynağı önbellekten alır). fx_warmup_list toplayıcısı E1 evrimini tetiklemediği için listeye giremezdi.
const _HELD_SHEETS: Array[Texture2D] = [
	preload("res://assets/fx/buyucu/patlama_front.png"),
	preload("res://assets/fx/buyucu/patlama_ground.png"),
]

var _life: float = 0.0


func _ready() -> void:
	call_deferred("_spawn_sheets")


func _spawn_sheets() -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	var size: float = absf(scale.x)
	for sheet in ["patlama_ground", "patlama_front"]:
		var s: Sprite2D = BuyucuFxScript.spawn_world(tree, sheet, global_position, FRONT_Z, FPS, size)
		if s == null:
			continue
		s.material = BuyucuFxScript.add_material()
		s.modulate = modulate
		if sheet == "patlama_ground":
			GroundSlotScript.place(s)


## Düğüm sayfa süresince yaşar (gece parıltısı - night_glow_catalog - buna bağlı), sonra kendini siler.
func _process(delta: float) -> void:
	_life += delta
	if _life >= float(FRAMES) / FPS:
		queue_free()
