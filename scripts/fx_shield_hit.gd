extends Node2D

## Kalkan "isabet" efekti: hasarın geldiği taraftan, kalkanın kenarında beliren
## yönlü bir kavis+patlama sprite animasyonu (bkz. assets/fx/shield_impact_arc/
## shield_impact_arc_frames.tres). Eskiden tamamen prosedürel draw_arc/
## draw_line ile çiziliyordu, artık gerçek bir sprite sheet kullanıyor.
##
## Bu script hem KASTERİN kendi ekranında (bkz. player.gd _spawn_shield_hit_fx)
## HEM DE uzak oyuncularda (bkz. network_manager.gd broadcast_player_vfx
## "shield_hit_flash" dalı) AYNI dosyadan yükleniyor - görünüm tek bir yerde
## (burada) tanımlı olduğu için iki taraf birbirinden sapamaz (bkz. proje
## kökündeki CLAUDE.md).

## DÜZELTME (kullanıcı bildirimi: "biraz daha içe doğru sürükle kalkanla
## bütünleşmesi gerek, çok az büyütürsen iyi olur") - eskiden 62 idi, kalkanın
## görsel kenarının biraz dışına taşıp ayrık duruyordu; 54'e çekilince kalkan
## yüzeyiyle çakışıyor/bütünleşiyor. FX_SCALE de hafifçe büyütüldü.
const RADIUS := 54.0
const FX_SCALE := 1.55

const IMPACT_FRAMES: SpriteFrames = preload("res://assets/fx/shield_impact_arc/shield_impact_arc_frames.tres")

var impact_angle: float = 0.0
var _sprite: AnimatedSprite2D = null


func _ready() -> void:
	z_index = 60
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = IMPACT_FRAMES
	_sprite.scale = Vector2(FX_SCALE, FX_SCALE)
	_sprite.animation_finished.connect(queue_free)
	add_child(_sprite)
	## Diğer VFX'lerdeki "kaçak node" güvenlik zamanlayıcısıyla aynı desen
	## (bkz. fx_animation.gd) - animation_finished bir sebeple hiç gelmezse
	## bile bu efekt sonsuza kadar sahnede asılı kalmasın.
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)


## angle is in radians, measured from the character toward whatever hit it.
## DÜZELTME (kullanıcı bildirimi: "splash efektini ters yerleştirmişsin") -
## sanattaki patlama/kıvılcım sağa değil SOLA doğru fışkırıyor (kavis sağda
## sabit duruyor, kıvılcımlar sola doğru büyüyor) - `impact_angle` düz
## kullanılırsa kıvılcımlar karaktere doğru İÇE fışkırıyormuş gibi görünüyordu,
## oysa hasarın geldiği taraftan DIŞARI (vurana doğru) fışkırması gerekiyor.
## +PI ile 180° çevrilince kıvılcımlar doğru yöne (dışa) bakıyor.
func setup(angle: float) -> void:
	impact_angle = angle
	if not _sprite:
		return
	_sprite.rotation = impact_angle + PI
	_sprite.position = Vector2.RIGHT.rotated(impact_angle) * RADIUS
	_sprite.play("burst")
