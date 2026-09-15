## Uzunkılıç (karakter etrafında dönen silah - "orbit sword") efektinin
## ORTAK matematiği ve trail (slash streak) sahnesi.
##
## KÖK NEDEN NOTU: weapon.gd (gerçek/yetkili silah - dönüş açısını hesaplar,
## hasar verir) ve remote_player.gd (diğer oyunculardaki KOZMETİK kopya -
## aynı görseli üretir ama hasar vermez) bu formülü eskiden AYRI AYRI elle
## kopyalayıp tutuyordu. Biri güncellenip (dönüş hızı, yarıçap, trail rengi
## vb.) diğeri unutulunca diğer oyuncularda ESKİ animasyon/görsel kalıyordu -
## kullanıcı bildirimi: "kılıç silahının dönme animasyonu multiplayer'da
## farklı görünüyor". Artık TEK kaynak burada - weapon.gd ve remote_player.gd
## SADECE bu static fonksiyonları çağırıyor, formül iki dosyada bir daha asla
## birbirinden sapamaz.
##
## YENİ "etrafında dönen silah" tipi bir şey eklersen: formülü SADECE burada
## değiştir, iki çağıran dosyaya da DOKUNMAN gerekmez.
class_name WeaponOrbitMath
extends RefCounted

const BASE_ORBIT_RADIUS: float = 130.0
const ROTATION_SPEED_MULT: float = 0.28
const TRAIL_INTERVAL: float = 0.045
const TRAIL_SCALE: float = 0.85
const TRAIL_COLOR := Color(1.0, 0.9, 0.5, 0.8)
const TRAIL_SPEED_SCALE: float = 1.4
const TRAIL_SCENE_PATH := "res://scenes/fx_hit_slash_streak.tscn"


## Bir karelik dönüş adımını hesaplar.
## delta: physics delta. angle_in: bir önceki karedeki açı. fire_rate:
## silahın atış hızı (dönüş hızını belirler). range_mult: attack_range /
## base_attack_range. parent_scale_x: silahın etrafında döndüğü node'un
## (karakterin) scale.x'i.
## Döner: {"angle": yeni açı, "offset": Vector2 (parent'a göre yerel/izafi
## konum), "rotation": ikonun rotasyonu, "orbit_radius": hesaplanan yarıçap}.
static func compute(delta: float, angle_in: float, fire_rate: float, range_mult: float, parent_scale_x: float) -> Dictionary:
	var rotation_speed: float = (TAU / max(0.05, fire_rate)) * ROTATION_SPEED_MULT
	var angle: float = angle_in + delta * rotation_speed
	var orbit_radius: float = BASE_ORBIT_RADIUS * range_mult * parent_scale_x
	var offset: Vector2 = Vector2(cos(angle), sin(angle)) * orbit_radius
	return {
		"angle": angle,
		"offset": offset,
		"rotation": angle + PI * 0.5,
		"orbit_radius": orbit_radius,
	}


## Kılıç sallanırken periyodik olarak bırakılan "slash streak" trail efektini
## spawn eder - hem weapon.gd (yerel/yetkili silah) hem remote_player.gd
## (kozmetik kopya) tarafından çağrılır, İKİSİNDE DE AYNI sahne/renk/ölçek.
## `parent`: efektin ekleneceği node (genelde get_tree().current_scene).
static func spawn_trail(parent: Node, global_pos: Vector2, icon_rotation: float, range_mult: float, parent_scale_x: float) -> void:
	if not parent or not ResourceLoader.exists(TRAIL_SCENE_PATH):
		return
	var trail_scene: PackedScene = load(TRAIL_SCENE_PATH) as PackedScene
	if not trail_scene:
		return
	var slash_fx: AnimatedSprite2D = trail_scene.instantiate() as AnimatedSprite2D
	if not slash_fx:
		return
	slash_fx.top_level = true
	slash_fx.z_index = 5
	slash_fx.global_position = global_pos
	slash_fx.rotation = icon_rotation + deg_to_rad(90.0)
	slash_fx.scale = Vector2(TRAIL_SCALE, TRAIL_SCALE) * range_mult * parent_scale_x
	slash_fx.modulate = TRAIL_COLOR
	if "speed_scale" in slash_fx:
		slash_fx.speed_scale = TRAIL_SPEED_SCALE
	parent.add_child(slash_fx)
