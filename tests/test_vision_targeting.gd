extends Node

## Kullanıcı isteği: "Arkadaşımızın gördüğü her şeyi ben de görebilmeliyim, ayrıca göremediğimiz
## yaratıklara saldıramamalıyız, silahlar ve yetenekler onları hedef alamamalı" - bkz.
## vision_fog.gd can_target. Takım görüşü (müttefik görüşü) sis tarafında zaten vardı
## (bkz. test_vision_fog.gd test_team_vision_*); burada: (1) can_target görünürlükle
## tutarlı, (2) takım görüşü hedeflenebilirliği de açıyor, (3) silah/totem/yetenek HEDEF
## SEÇİMİ görünmeyen yaratıkları atlıyor.
## Kapsam: hedef SEÇEN yerler. Alan hasarı (nova, itme, patlama), mermi/kılıç çarpışması
## ve hareket engelleme hedef seçmediği için bilerek değişmedi.

const VisionFogScript: GDScript = preload("res://scripts/vision_fog.gd")
const WeaponScene: PackedScene = preload("res://scenes/weapon_buz_asasi.tscn")
const TotemAttackScene: PackedScene = preload("res://scenes/totem_attack.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

const TICK_STEP := 0.05


class FakeActor extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false
	var is_indoors: bool = false

	func is_indoors_now() -> bool:
		return is_indoors


## weapon.gd/totem/player'ın hedef seçerken okuduğu alanlar + hasar kaydı.
class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var is_frozen: bool = false
	var is_boss: bool = false
	var health: float = 100.0
	var damage_taken: float = 0.0

	func take_damage(amount: float, _crit: bool = false, _pen: float = 0.0, _is_area: bool = false) -> void:
		damage_taken += amount


var _spawned: Array[Node] = []


func _cleanup() -> void:
	get_viewport().canvas_transform = Transform2D.IDENTITY
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _track(node: Node) -> Node:
	_spawned.append(node)
	return node


func _enemy(pos: Vector2, seen: float = 1.0) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	e.global_position = pos
	e.set_meta(VisionFogScript.VIS_META, seen)
	_track(e)
	return e


func _actor(group_name: String, pos: Vector2) -> FakeActor:
	var a := FakeActor.new()
	a.add_to_group(group_name)
	add_child(a)
	a.global_position = pos
	_track(a)
	return a


func _make_fog() -> CanvasLayer:
	var fog: CanvasLayer = VisionFogScript.new()
	add_child(fog)
	## bkz. test_vision_fog.gd _make_fog'taki AYNI DÜZELTME notu - vision_fog.gd process_mode = PROCESS_MODE_ALWAYS
	## olduğu için sahnedeki fog kendi _process()'inden de update_fog() çağırır; bu, testin ELLE yaptığı
	## çağrılarla yarışıp MANAGE_INTERVAL_FRAMES throttle'ının zamanlamasını bozabiliyordu (bir sonraki testin
	## nesnelerine "sızarak" onu da başarısız gösterebiliyordu). Tamamen kapatılıyor - belirlenimci.
	fog.set_process(false)
	_track(fog)
	return fog


func _tick(fog: CanvasLayer, seconds: float) -> void:
	for i: int in range(maxi(1, roundi(seconds / TICK_STEP))):
		fog.update_fog(TICK_STEP)


## bkz. test_vision_fog.gd _settle - throttle'ı bypass edip ilgili öğe(ler)i doğrudan yönetir, headless testte
## Engine.get_process_frames()'in GERÇEK duvar-saatine bağlı, belirlenimsiz ilerlemesinden etkilenmez.
func _settle(fog: CanvasLayer, items: Array = []) -> void:
	fog.update_fog(TICK_STEP)
	for item in items:
		fog._manage_item(item, TICK_STEP)


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size


func _far_outside_offset() -> Vector2:
	## Görüş elipsinin (yatay yarı-menzil) rahatça dışı.
	return Vector2(VisionFogScript.VISION_RADIUS * VisionFogScript.VISION_WIDTH_SCALE * 2.2, 0.0)


func test_can_target_follows_the_fog_visibility_value() -> void:
	var e := _enemy(Vector2.ZERO, 1.0)
	assert(VisionFogScript.can_target(e), "Tam görünür yaratık hedeflenebilmeli")
	e.set_meta(VisionFogScript.VIS_META, VisionFogScript.TARGETABLE_MIN_VISIBILITY)
	assert(VisionFogScript.can_target(e), "Eşikteki (0.5) yaratık hedeflenebilmeli")
	e.set_meta(VisionFogScript.VIS_META, VisionFogScript.TARGETABLE_MIN_VISIBILITY - 0.01)
	assert(not VisionFogScript.can_target(e), "Eşiğin altındaki (solmuş) yaratık hedeflenememeli")
	e.set_meta(VisionFogScript.VIS_META, 0.0)
	assert(not VisionFogScript.can_target(e), "Görünmez yaratık hedeflenememeli")
	_cleanup()


func test_everything_is_targetable_when_there_is_no_fog() -> void:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	_track(e)
	assert(VisionFogScript.can_target(e), "Sis yokken/meta yokken her yaratık hedeflenebilmeli (menü, testler, ev içi)")
	_cleanup()


func test_unmanaged_new_enemy_falls_back_to_the_live_fog_geometry() -> void:
	var fog := _make_fog()
	var center: Vector2 = _screen() * 0.5
	_actor("player", center)
	fog.update_fog(TICK_STEP) ## sis aktif olsun
	## Sis bu karede henüz çalışmadığı için VIS_META'sı olmayan yeni doğmuş yaratıklar:
	var near := FakeEnemy.new()
	near.add_to_group("enemies")
	add_child(near)
	near.global_position = center + Vector2(20.0, 0.0)
	_track(near)
	var far := FakeEnemy.new()
	far.add_to_group("enemies")
	add_child(far)
	far.global_position = center + _far_outside_offset()
	_track(far)
	assert(not near.has_meta(VisionFogScript.VIS_META) and not far.has_meta(VisionFogScript.VIS_META), "test kurulumu: meta olmamalı")
	assert(VisionFogScript.can_target(near), "Yakındaki yeni doğmuş yaratık hedeflenebilmeli")
	assert(not VisionFogScript.can_target(far), "Görüş dışındaki yeni doğmuş yaratık ilk karede bile hedeflenememeli")
	_cleanup()


## TAKIM GÖRÜŞÜ: benim göremediğim ama müttefiğimin gördüğü yaratık hedeflenebilir olmalı.
func test_team_vision_makes_the_enemy_targetable() -> void:
	var fog := _make_fog()
	var center: Vector2 = _screen() * 0.5
	_actor("player", center)
	var enemy_pos: Vector2 = center + _far_outside_offset()
	var enemy := FakeEnemy.new()
	enemy.add_to_group("enemies")
	add_child(enemy)
	enemy.global_position = enemy_pos
	_track(enemy)
	_settle(fog, [enemy])
	assert(not VisionFogScript.can_target(enemy), "Müttefik yokken uzaktaki yaratık hedeflenememeli")
	var ally := _actor("remote_players", enemy_pos - Vector2(30.0, 0.0))
	_settle(fog, [enemy])
	assert(fog.get_source_count() == 2, "Yerel oyuncu + müttefik = 2 görüş kaynağı")
	assert(VisionFogScript.can_target(enemy), "Müttefiğin gördüğü yaratık benim için de hedeflenebilir olmalı (takım görüşü)")
	## Müttefik ölürse görüş gider -> yaratık tekrar hedeflenemez (anında, artık solma yok).
	ally.is_dead = true
	_settle(fog, [enemy])
	assert(not VisionFogScript.can_target(enemy), "Müttefik görüşü kaybolunca yaratık tekrar hedeflenememeli")
	_cleanup()


func test_weapon_target_selection_skips_enemies_we_cannot_see() -> void:
	var weapon = WeaponScene.instantiate()
	add_child(weapon)
	_track(weapon)
	weapon.global_position = Vector2.ZERO
	weapon.attack_range = 0.0 ## sınırsız menzil: sadece görünürlüğü ölçelim
	var near_hidden := _enemy(Vector2(20.0, 0.0), 0.0)
	var far_seen := _enemy(Vector2(200.0, 0.0), 1.0)

	assert(weapon._get_nearest_enemy() == far_seen, "En yakın (görünmeyen) yaratık atlanıp görünen hedeflenmeli")
	assert(weapon._get_nearest_unfrozen_enemy() == far_seen, "Buz asası da görünmeyen yaratığı hedeflememeli")
	far_seen.health = 50.0
	near_hidden.health = 999.0
	assert(weapon._get_highest_health_enemy() == far_seen, "En canlı hedef seçimi de görünmeyeni atlamalı")

	far_seen.set_meta(VisionFogScript.VIS_META, 0.0)
	assert(weapon._get_nearest_enemy() == null, "Hiçbir yaratık görünmüyorsa hedef seçilmemeli (silah ateş etmemeli)")
	assert(weapon._get_nearest_unfrozen_enemy() == null, "Hiçbiri görünmüyorsa buz asası hedef seçmemeli")
	assert(weapon._get_highest_health_enemy() == null, "Hiçbiri görünmüyorsa en canlı hedef de boş olmalı")

	near_hidden.set_meta(VisionFogScript.VIS_META, 1.0)
	assert(weapon._get_nearest_enemy() == near_hidden, "Yaratık görünür olunca hedeflenebilmeli")
	_cleanup()


func test_arcane_burst_and_chain_jumps_skip_unseen_enemies() -> void:
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self ## zincir efekti current_scene'e ekleniyor
	var weapon = WeaponScene.instantiate()
	add_child(weapon)
	_track(weapon)
	weapon.global_position = Vector2.ZERO
	weapon.attack_range = 0.0
	weapon.chain_jump_count = 3
	var primary := _enemy(Vector2(100.0, 0.0), 1.0)
	var seen_neighbor := _enemy(Vector2(140.0, 0.0), 1.0)
	var hidden_neighbor := _enemy(Vector2(120.0, 0.0), 0.0)
	weapon._apply_chain_jumps(primary, 10.0, false, 0.0)
	assert(seen_neighbor.damage_taken > 0.0, "Görünen komşu zincire dahil olmalı")
	assert(hidden_neighbor.damage_taken == 0.0, "Görünmeyen komşuya zincir sıçramamalı")
	get_tree().current_scene = previous_scene
	_cleanup()


func test_totem_and_player_helpers_skip_unseen_enemies() -> void:
	var totem = TotemAttackScene.instantiate()
	add_child(totem)
	_track(totem)
	totem.global_position = Vector2.ZERO
	totem.totem_radius = 1000.0
	var hidden := _enemy(Vector2(10.0, 0.0), 0.0)
	var seen := _enemy(Vector2(300.0, 0.0), 1.0)
	assert(totem._find_nearest_enemy() == seen, "Saldırı totemi görünmeyen yaratığı hedeflememeli")
	seen.set_meta(VisionFogScript.VIS_META, 0.0)
	assert(totem._find_nearest_enemy() == null, "Hiçbiri görünmüyorsa totem hedef seçmemeli")

	GameManager.selected_char_id = 1
	GameManager.selected_character = 1
	var player = PlayerScene.instantiate()
	add_child(player)
	_track(player)
	seen.set_meta(VisionFogScript.VIS_META, 1.0)
	var found = player._find_closest_enemy_in_range(Vector2.ZERO, 1000.0)
	assert(found == seen, "Yetenek hedef yardımcısı (sekme/kaos oku vb.) görünmeyeni atlamalı")
	assert(hidden.damage_taken == 0.0)
	_cleanup()


## Regresyon koruması: hedef seçen fonksiyonlardaki görünürlük şartı kaldırılmasın.
func test_target_selection_sites_still_check_visibility() -> void:
	var expected := {
		"res://scripts/weapon.gd": 6,
		"res://scripts/totem_attack.gd": 1,
		"res://scripts/oakley_vine.gd": 1,
		"res://scripts/fx_buyucu_tornado.gd": 1,
		"res://scripts/player.gd": 4,
	}
	for path: String in expected:
		var src: String = FileAccess.get_file_as_string(path)
		var n: int = src.count("VisionFogScript.can_target(")
		assert(n >= int(expected[path]), "%s içinde en az %d görünürlük kontrolü olmalı, bulunan: %d" % [path, int(expected[path]), n])
