extends AnimatedSprite2D

## Önceden pişirilmiş TEK SEFERLİK sprite efekti sahnesinin kök script'i: sprite_frames / ölçek (TEXEL) / z_index / animasyon
## sahnede ayarlanır, burası sadece oynatır ve bitince siler. Sahne yolu ağ üzerinden yayınlanabildiği için (player.gd
## "hitscan_impact" broadcast'i) dünya konumlu efektlerde kullanılır - ör. Necromancer çağırma efekti (fx_necro_summon.tscn).

const SAFETY_LIFETIME := 4.0

## Zemin efekti (yer çatlağı, toz halkası - ör. Shaman golem darbeleri): haritanın hemen arkasına taşınır, yani sonradan
## eklenen tüm yaratık/oyuncuların ALTINDA çizilir (enemy_abilities.gd place_on_ground ile aynı kural - sahnede y-sort yok,
## kardeşler ağaç sırasıyla çizilir). Uzak kopyalar da aynı sahneden kurulduğu için ("hitscan_impact") ikisinde de aynı katmanda.
@export var on_ground: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animation_finished.connect(queue_free)
	play(animation)
	if on_ground:
		_sink_to_ground.call_deferred()


func _sink_to_ground() -> void:
	if not is_inside_tree():
		return
	var root: Node = get_tree().current_scene
	if root == null or get_parent() != root:
		return
	var harita: Node = root.get_node_or_null("Harita")
	if harita != null:
		root.move_child(self, harita.get_index() + 1)
	get_tree().create_timer(SAFETY_LIFETIME, false).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())
