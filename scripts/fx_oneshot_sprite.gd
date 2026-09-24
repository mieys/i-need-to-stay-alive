extends AnimatedSprite2D

## Önceden pişirilmiş TEK SEFERLİK sprite efekti sahnesinin kök script'i: sprite_frames / ölçek (TEXEL) / z_index / animasyon
## sahnede ayarlanır, burası sadece oynatır ve bitince siler. Sahne yolu ağ üzerinden yayınlanabildiği için (player.gd
## "hitscan_impact" broadcast'i) dünya konumlu efektlerde kullanılır - ör. Necromancer çağırma efekti (fx_necro_summon.tscn).

const SAFETY_LIFETIME := 4.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animation_finished.connect(queue_free)
	play(animation)
	get_tree().create_timer(SAFETY_LIFETIME, false).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())
