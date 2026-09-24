extends Node

## Kullanıcı isteği doğrulaması: LoL tarzı görüş alanı / savaş sisi (bkz.
## scripts/vision_fog.gd) - "görünmeyen kısımlar koyu olsun, orada düşman
## varsa göremeyelim; direkt vinyet gibi değil LoL'deki gibi", "görüş
## genişliğini vision radius'un yanında ayarlayabileyim" ve "görüntü yavaşça
## açılıp yavaşça sönsün, sert bir spot ışığı gibi durmasın".
##
## Doğrulananlar:
##  - görüş alanı VISION_RADIUS (dikey) x VISION_WIDTH_SCALE (yatay çarpan)
##    elipsi; genişlik 1.0 iken tam daire. Çizimde ve gizleme mantığında AYNI,
##  - genişlik ayarı SADECE yatay menzili çarpıyor (sabiti değiştirmeden,
##    static normalized_distance ile),
##  - anlık hedef görünürlük: içeride 1, dışarıda 0, sınırda 0.5 (shader formülü),
##  - düşmanlar (ve yerdeki eşyalar - xp/altın/yemek/sandık/mıknatıs) görüşe GİRİNCE/ÇIKINCA
##    ANINDA belirir/gizlenir - kullanıcı isteği (2026-09-23): "opaklaşarak görünmesin bir anda görünsün",
##    ara bir yarı saydam durum YOK (eski FADE_IN_TIME/FADE_OUT_TIME'lı yumuşak açılma/sönme kaldırıldı -
##    o iki sabit hâlâ var ama artık SADECE arka plandaki karartma maskesinin (shader) geçiş hızı için),
##  - yeni doğan düşman ilk karede hedefte başlar (sisin içinde "parlamaz"),
##  - sis kapanınca (ev içi) soluk/gizli her şey eski hâline döner,
##  - TAKIM GÖRÜŞÜ: müttefikin yanındaki düşman, biz uzaktayken de görünüyor,
##  - ölü müttefik görüş VERMİYOR, yerde yatan (downed) VERİYOR,
##  - başka bir sistemin gizlediği düğüme dokunmuyor,
##  - kaynak sayısı MAX_SOURCES'ta sınırlanıyor,
##  - minimap ve hasar yazısı, sisteki/solmuş düşmanı sızdırmıyor,
##  - düşman mermileri gizlenebilir gruba giriyor,
##  - MASKE: geri besleme ayarlı (clear NEVER), boyutu ekranın 1/4'ü, sis
##    kapalıyken GPU durur, kamera küçük kayınca geçmiş korunur / sıçrayınca
##    unutulur (karanlıktan yavaşça açılır), duraklatınca donar.
##
## Testler VISION_RADIUS/VISION_WIDTH_SCALE/EDGE_SOFTNESS hangi değerde olursa
## olsun geçmeli (mesafeler bu sabitlerden türetiliyor). Koordinatlar: testte
## kamera yok, canvas transform birim matris (zoom 1) - yani dünya birimi = piksel.
## GPU'daki maskenin GERÇEK kare kare davranışı headless'ta çizilemediği için burada
## değil, gerçek renderer ile ekran görüntüsü/piksel okumasıyla doğrulanır.

const VisionFogScript: GDScript = preload("res://scripts/vision_fog.gd")
const VisionOccludersScript: GDScript = preload("res://scripts/vision_occluders.gd")
const WallLayerFactory: GDScript = preload("res://tests/wall_layer_factory.gd")
const MinimapScript: GDScript = preload("res://scripts/minimap.gd")
const EnemyProjectileScene: PackedScene = preload("res://scenes/enemy_projectile.tscn")
const FloatingTextScene: PackedScene = preload("res://scenes/floating_text.tscn")

## tick() adım süresi: vision_fog.gd MAX_STEP'in (0.1) altında olmalı.
const TICK_STEP := 0.05


## vision_fog.gd'nin okuduğu alanların (is_dead/is_downed/is_indoors) ve yerel
## oyuncunun is_indoors_now() metodunun sahte hali.
class FakeActor extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false
	var is_indoors: bool = false

	func is_indoors_now() -> bool:
		return is_indoors


var _spawned: Array[Node] = []


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size


## Dikey yarı-menzil (VISION_RADIUS).
func _half_height() -> float:
	return VisionFogScript.VISION_RADIUS


## Yatay yarı-menzil (VISION_RADIUS x VISION_WIDTH_SCALE).
func _half_width() -> float:
	return VisionFogScript.VISION_RADIUS * VisionFogScript.VISION_WIDTH_SCALE


func _half_band() -> float:
	return maxf(VisionFogScript.EDGE_SOFTNESS, 0.01) * 0.5


## Geçiş bandının TAM İÇİNDE (hedef görünürlük 1) ve TAM DIŞINDA (hedef 0)
## normalize mesafe çarpanları.
func _inside_factor() -> float:
	return maxf(1.0 - _half_band() - 0.05, 0.05)


func _outside_factor() -> float:
	return 1.0 + _half_band() + 0.05


func _approx(a: float, b: float, tolerance: float) -> bool:
	return absf(a - b) <= tolerance


func _make_fog() -> CanvasLayer:
	var fog: CanvasLayer = VisionFogScript.new()
	add_child(fog)
	## DÜZELTME: vision_fog.gd process_mode = PROCESS_MODE_ALWAYS, yani sahnedeki gerçek fog CanvasLayer'ı
	## _process() üzerinden KENDİ KENDİNE de update_fog() çağırır. Bu test dosyası tüm ilerlemeyi ELLE
	## (fog.update_fog(TICK_STEP)) yönetiyor - motor arka planda gerçek zamanlı kare(ler) geçirirse (headless
	## bile olsa, ağır kurulum çağrıları - SubViewport/ShaderMaterial - sırasında gerçek duvar-saati süresi
	## geçebiliyor) bu otomatik çağrı ELLE yapılan çağrılarla YARIŞA girip MANAGE_INTERVAL_FRAMES throttle'ının
	## "kare eşleşmesi"ni beklenmedik şekilde kaydırabiliyordu (Görüş/görünürlük testlerinde ara sıra
	## açıklanamayan başarısızlıklara yol açtığı bulundu). set_process(false) ile bu otomatik çağrı tamamen
	## kapatılıyor - fog artık SADECE testin çağırdığı update_fog() kadar ilerliyor, tamamen belirlenimci.
	fog.set_process(false)
	_spawned.append(fog)
	return fog


func _add_actor(group_name: String, pos: Vector2) -> FakeActor:
	var actor := FakeActor.new()
	actor.add_to_group(group_name)
	add_child(actor)
	actor.global_position = pos
	_spawned.append(actor)
	return actor


func _add_enemy(pos: Vector2) -> Node2D:
	var enemy := Node2D.new()
	enemy.add_to_group("enemies")
	add_child(enemy)
	enemy.global_position = pos
	_spawned.append(enemy)
	return enemy


## `seconds` kadar oyun zamanını TICK_STEP adımlarıyla ilerletir.
func _tick(fog: CanvasLayer, seconds: float) -> void:
	var steps: int = maxi(1, roundi(seconds / TICK_STEP))
	for i: int in range(steps):
		fog.update_fog(TICK_STEP)


## Bir konum/kaynak değişikliğinden sonra bir (ya da birkaç) öğenin görünürlüğünü GARANTİLİ şekilde tazeler.
## _apply_enemy_visibility'nin PERF throttle'ı (MANAGE_INTERVAL_FRAMES'te bir, instance_id'ye göre kaydırmalı)
## GERÇEK oyunda sorun değil (en fazla birkaç kare/~50ms gecikme, fark edilmez) ama Engine.get_process_frames()
## bu headless test sürecinde GERÇEK duvar-saati zamanına bağlı ilerliyor (SubViewport/ShaderMaterial kurulumu
## gibi ağır çağrılar sırasında motor arka planda kare "çiziyor") - yani testte kaç kez update_fog() çağrıldığı
## ile throttle'ın "sırası geldi mi" sonucu ARASINDA belirlenimli bir ilişki YOK. Bu yüzden önce update_fog()
## ile paylaşılan durumu (world_sources/_active) tazeleyip SONRA ilgili öğe(ler)i throttle'ı bypass ederek
## DOĞRUDAN _manage_item() ile yönetiyoruz - test, _manage_item()'ın kendi mantığını (bu görevin asıl konusu)
## doğruluyor, orkestrasyon katmanındaki performans throttle'ının ZAMANLAMASINI değil (o ayrı, dokunulmamış).
func _settle(fog: CanvasLayer, items: Array = []) -> void:
	fog.update_fog(TICK_STEP)
	for item in items:
		fog._manage_item(item, TICK_STEP)


## free() (queue_free DEĞİL): bir sonraki testin grupları önceki testten
## kalan düğümleri görüp yanlış sonuç vermesin.
func _cleanup() -> void:
	get_viewport().canvas_transform = Transform2D.IDENTITY
	get_tree().paused = false
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func test_drawn_shape_matches_radius_and_width_scale() -> void:
	var fog: CanvasLayer = _make_fog()
	var size: Vector2 = _screen()
	_add_actor("player", size * 0.5)
	fog.update_fog(TICK_STEP)
	## UV yarı-ekseni * ekran boyutu = piksel yarı-ekseni (zoom 1): yatay
	## VISION_RADIUS x VISION_WIDTH_SCALE, dikey VISION_RADIUS olmalı. Genişlik
	## 1.0 iken ikisi eşit = ekranda elips değil gerçek daire.
	var px: Vector2 = Vector2(fog._half_extent.x * size.x, fog._half_extent.y * size.y)
	assert(absf(px.x - _half_width()) < 0.01 and absf(px.y - _half_height()) < 0.01,
		"Çizilen görüş alanı yanlış: piksel yarı-eksenleri %s, beklenen (%.1f, %.1f)" % [px, _half_width(), _half_height()])
	_cleanup()


func test_width_scale_stretches_only_horizontal_reach() -> void:
	var norm: Callable = VisionFogScript.normalized_distance
	## genişlik 1.0: tam daire - iki eksende de radius uzaklık = sınır (1.0).
	assert(absf(norm.call(Vector2(100.0, 0.0), 100.0, 1.0) - 1.0) < 0.0001, "1.0 genişlikte yatay sınır radius olmalı")
	assert(absf(norm.call(Vector2(0.0, 100.0), 100.0, 1.0) - 1.0) < 0.0001, "1.0 genişlikte dikey sınır radius olmalı")
	## genişlik 2.0: yatay sınır 2x uzakta, dikey sınır DEĞİŞMEZ.
	assert(absf(norm.call(Vector2(200.0, 0.0), 100.0, 2.0) - 1.0) < 0.0001, "2.0 genişlikte yatay sınır 2x radius olmalı")
	assert(absf(norm.call(Vector2(100.0, 0.0), 100.0, 2.0) - 0.5) < 0.0001, "2.0 genişlikte 1x radius yatayda yarı yoldur")
	assert(absf(norm.call(Vector2(0.0, 100.0), 100.0, 2.0) - 1.0) < 0.0001, "Genişlik ayarı dikey menzili değiştirmemeli")
	## genişlik 0.5: yatay sınır yarıya iner, dikey aynı.
	assert(absf(norm.call(Vector2(50.0, 0.0), 100.0, 0.5) - 1.0) < 0.0001, "0.5 genişlikte yatay sınır yarım radius olmalı")
	assert(absf(norm.call(Vector2(0.0, 100.0), 100.0, 0.5) - 1.0) < 0.0001, "Genişlik ayarı dikey menzili değiştirmemeli")
	## Bozuk değer (0 ya da negatif) sıfıra bölüp sonsuz/NaN üretmemeli.
	assert(is_finite(norm.call(Vector2(10.0, 10.0), 100.0, 0.0)), "Genişlik 0 iken mesafe sonlu kalmalı")
	assert(is_finite(norm.call(Vector2(10.0, 10.0), 100.0, -3.0)), "Negatif genişlikte mesafe sonlu kalmalı")


func test_target_visibility_shape() -> void:
	var soft: float = 0.4 ## band 0.8 .. 1.2
	var vis: Callable = VisionFogScript.visibility_from_distance
	assert(_approx(vis.call(0.0, soft), 1.0, 0.0001), "Merkezde görünürlük 1 olmalı")
	assert(_approx(vis.call(0.79, soft), 1.0, 0.0001), "Bandın içinde görünürlük 1 olmalı")
	assert(_approx(vis.call(1.0, soft), 0.5, 0.0001), "Sınırın tam üstünde görünürlük 0.5 olmalı (band ortası)")
	assert(_approx(vis.call(1.21, soft), 0.0, 0.0001), "Bandın dışında görünürlük 0 olmalı")
	assert(vis.call(0.9, soft) > vis.call(1.0, soft) and vis.call(1.0, soft) > vis.call(1.1, soft),
		"Görünürlük mesafeyle azalmalı")
	assert(is_finite(vis.call(1.0, 0.0)), "Yumuşaklık 0 iken (sert kenar) sonlu kalmalı")


func test_vision_matches_configured_radius_and_width() -> void:
	var fog: CanvasLayer = _make_fog()
	var center: Vector2 = _screen() * 0.5
	var w: float = _half_width()
	var h: float = _half_height()
	var fin: float = _inside_factor()
	var fout: float = _outside_factor()
	_add_actor("player", center)
	## İçeride: dört yönde + bir köşegen (her iki bileşen de yarı-menzilin İÇİNDE).
	var in_right: Node2D = _add_enemy(center + Vector2(w * fin, 0.0))
	var in_left: Node2D = _add_enemy(center + Vector2(-w * fin, 0.0))
	var in_down: Node2D = _add_enemy(center + Vector2(0.0, h * fin))
	var in_up: Node2D = _add_enemy(center + Vector2(0.0, -h * fin))
	var in_diag: Node2D = _add_enemy(center + Vector2(w, h) * fin * 0.7071)
	## Dışarıda: dört yönde + bir köşegen. Köşegenin her bileşeni yarı-menzilden
	## KÜÇÜK (kare olsaydı içeride sayılırdı) ama elips/daire olduğu için dışarıda.
	var out_right: Node2D = _add_enemy(center + Vector2(w * fout, 0.0))
	var out_left: Node2D = _add_enemy(center + Vector2(-w * fout, 0.0))
	var out_down: Node2D = _add_enemy(center + Vector2(0.0, h * fout))
	var out_up: Node2D = _add_enemy(center + Vector2(0.0, -h * fout))
	var out_diag: Node2D = _add_enemy(center + Vector2(w, h) * fout * 0.7071)
	fog.update_fog(TICK_STEP)
	assert(fog.is_active(), "Yerel oyuncu varken sis aktif olmalı")
	for inside: Node2D in [in_right, in_left, in_down, in_up, in_diag]:
		assert(inside.visible and inside.modulate.a > 0.99,
			"Görüş içindeki düşman görünmüyor/soluk: %s" % inside.global_position)
	for outside: Node2D in [out_right, out_left, out_down, out_up, out_diag]:
		assert(not outside.visible, "Görüş dışındaki düşman görünüyor: %s" % outside.global_position)
	_cleanup()


func test_enemy_in_edge_band_is_fully_visible_not_faded() -> void:
	## DÜZELTME (kullanıcı isteği 2026-09-23: "opaklaşarak görünmesin"): sınırdaki (hedef=0.5) düşman artık
	## yarı saydam DEĞİL - ikili model, hedef HIDE_BELOW'ün üzerindeyse tam opak görünür.
	var fog: CanvasLayer = _make_fog()
	var center: Vector2 = _screen() * 0.5
	_add_actor("player", center)
	var enemy: Node2D = _add_enemy(center + Vector2(_half_width(), 0.0)) ## tam sınır -> hedef 0.5
	fog.update_fog(TICK_STEP)
	assert(enemy.visible, "Sınırdaki düşman gizlenmemeli")
	assert(_approx(enemy.modulate.a, 1.0, 0.001), "Sınırdaki düşman soluklaşmadan tam opak görünmeli: %.3f" % enemy.modulate.a)
	_cleanup()


func test_enemy_appears_instantly_after_entering_vision() -> void:
	## DÜZELTME (kullanıcı isteği 2026-09-23: "görüş alanına giren şeyler opaklaşarak görünmesin bir anda
	## görünsün") - eski FADE_IN_TIME'lı yavaş açılma kaldırıldı, TEK karede tam görünür olmalı.
	var fog: CanvasLayer = _make_fog()
	var center: Vector2 = _screen() * 0.5
	var w: float = _half_width()
	_add_actor("player", center)
	var enemy: Node2D = _add_enemy(center + Vector2(w * _outside_factor() * 1.3, 0.0))
	fog.update_fog(TICK_STEP)
	assert(not enemy.visible, "Sisteki düşman başta gizli olmalı")
	## Görüşe gir.
	enemy.global_position = center + Vector2(w * 0.3, 0.0)
	_settle(fog, [enemy])
	assert(enemy.visible and _approx(enemy.modulate.a, 1.0, 0.001),
		"Görüşe giren düşman (yavaş açılma olmadan, en fazla birkaç kare içinde) tam görünür olmalı, alfa=%.3f" % enemy.modulate.a)
	assert(not enemy.has_meta(VisionFogScript.HIDDEN_META), "Görününce gizli işareti temizlenmeli")
	_cleanup()


func test_enemy_disappears_instantly_after_leaving_vision() -> void:
	## DÜZELTME (kullanıcı isteği 2026-09-23) - eski FADE_OUT_TIME'lı yavaş sönme kaldırıldı, TEK karede gizlenmeli.
	var fog: CanvasLayer = _make_fog()
	var center: Vector2 = _screen() * 0.5
	var w: float = _half_width()
	_add_actor("player", center)
	var enemy: Node2D = _add_enemy(center + Vector2(w * 0.3, 0.0))
	fog.update_fog(TICK_STEP)
	assert(enemy.visible and _approx(enemy.modulate.a, 1.0, 0.001), "Görüş içindeki düşman başta tam görünür olmalı")
	## Görüşten çık.
	enemy.global_position = center + Vector2(w * _outside_factor() * 1.3, 0.0)
	_settle(fog, [enemy])
	assert(not enemy.visible, "Görüşten çıkan düşman (yavaş sönme olmadan, en fazla birkaç kare içinde) gizlenmeli")
	assert(enemy.has_meta(VisionFogScript.HIDDEN_META), "Sisin gizlediği düşman işaretlenmeli")
	_cleanup()


func test_new_enemy_starts_at_target_without_flash() -> void:
	var fog: CanvasLayer = _make_fog()
	var center: Vector2 = _screen() * 0.5
	var w: float = _half_width()
	_add_actor("player", center)
	## Sisin içinde doğan: ilk karede zaten gizli olmalı (fade-in'le görünüp sönmemeli).
	var hidden_newcomer: Node2D = _add_enemy(center + Vector2(w * _outside_factor() * 1.3, 0.0))
	## Görüşün içinde doğan: ilk karede zaten tam görünür (yavaş belirmemeli).
	var visible_newcomer: Node2D = _add_enemy(center + Vector2(w * 0.2, 0.0))
	fog.update_fog(TICK_STEP)
	assert(not hidden_newcomer.visible, "Sisin içinde doğan düşman ilk karede görünüyor (parlama)")
	assert(visible_newcomer.visible and _approx(visible_newcomer.modulate.a, 1.0, 0.001),
		"Görüşün içinde doğan düşman ilk karede tam görünür olmalı")
	_cleanup()


func test_team_vision_reveals_enemy_near_ally() -> void:
	var fog: CanvasLayer = _make_fog()
	var center: Vector2 = _screen() * 0.5
	var w: float = _half_width()
	_add_actor("player", center)
	var enemy_pos: Vector2 = center + Vector2(w * _outside_factor() * 1.3, 0.0)
	var enemy: Node2D = _add_enemy(enemy_pos)
	fog.update_fog(TICK_STEP)
	assert(not enemy.visible, "Müttefik yokken uzaktaki düşman gizli olmalı")
	_add_actor("remote_players", enemy_pos - Vector2(w * 0.2, 0.0))
	_settle(fog, [enemy])
	assert(fog.get_source_count() == 2, "Yerel oyuncu + müttefik = 2 görüş kaynağı olmalı")
	assert(enemy.visible and _approx(enemy.modulate.a, 1.0, 0.001),
		"Müttefiğin görüşündeki düşman (takım görüşü) görünmedi")
	_cleanup()


func test_dead_ally_gives_no_vision_but_downed_ally_does() -> void:
	var fog: CanvasLayer = _make_fog()
	var center: Vector2 = _screen() * 0.5
	var w: float = _half_width()
	_add_actor("player", center)
	var enemy_pos: Vector2 = center + Vector2(w * _outside_factor() * 1.3, 0.0)
	var enemy: Node2D = _add_enemy(enemy_pos)
	var ally: FakeActor = _add_actor("remote_players", enemy_pos)
	ally.is_dead = true
	fog.update_fog(TICK_STEP)
	assert(fog.get_source_count() == 1, "Ölü müttefik görüş vermemeli")
	assert(not enemy.visible, "Ölü müttefiğin yanındaki düşman görünüyor")
	## Yerde yatan: is_dead=true AMA is_downed=true (bkz. player.gd is_downed notu)
	ally.is_downed = true
	_settle(fog, [enemy])
	assert(fog.get_source_count() == 2, "Yerde yatan (diriltilebilir) müttefik görüş vermeli")
	assert(enemy.visible, "Yerde yatan müttefiğin yanındaki düşman görünmedi")
	_cleanup()


func test_indoors_disables_fog_and_restores_enemies() -> void:
	var fog: CanvasLayer = _make_fog()
	var center: Vector2 = _screen() * 0.5
	var w: float = _half_width()
	var player: FakeActor = _add_actor("player", center)
	var hidden_enemy: Node2D = _add_enemy(center + Vector2(w * _outside_factor() * 1.3, 0.0))
	var edge_enemy: Node2D = _add_enemy(center + Vector2(w, 0.0)) ## sınır -> hedef 0.5, ama artık İKİLİ (tam opak)
	fog.update_fog(TICK_STEP)
	assert(not hidden_enemy.visible, "Dışarıdayken uzak düşman gizli olmalı")
	assert(edge_enemy.visible and _approx(edge_enemy.modulate.a, 1.0, 0.001),
		"Sınırdaki düşman soluklaşmadan tam opak görünmeli (kullanıcı isteği: opaklaşarak görünmesin)")
	player.is_indoors = true
	fog.update_fog(TICK_STEP)
	assert(not fog.is_active(), "Ev içindeyken sis kapalı olmalı")
	assert(not fog._rect.visible, "Ev içindeyken karartma katmanı gizli olmalı")
	assert(hidden_enemy.visible, "Ev içindeyken sis kapanınca gizlenen düşman geri açılmalı")
	assert(_approx(edge_enemy.modulate.a, 1.0, 0.001), "Ev içindeyken düşman tam görünür kalmalı")
	assert(not hidden_enemy.has_meta(VisionFogScript.VIS_META) and not edge_enemy.has_meta(VisionFogScript.VIS_META),
		"Sis kapanınca tüm işaretler temizlenmeli")
	player.is_indoors = false
	fog.update_fog(TICK_STEP)
	assert(fog.is_active(), "Dışarı çıkınca sis geri gelmeli")
	assert(not hidden_enemy.visible, "Dışarı çıkınca uzak düşman tekrar gizlenmeli")
	_cleanup()


func test_fog_does_not_unhide_nodes_hidden_by_someone_else() -> void:
	var fog: CanvasLayer = _make_fog()
	var center: Vector2 = _screen() * 0.5
	var w: float = _half_width()
	_add_actor("player", center)
	var enemy: Node2D = _add_enemy(center + Vector2(w * 0.3, 0.0))
	enemy.visible = false ## başka bir sistem gizlemiş
	fog.update_fog(TICK_STEP)
	fog.update_fog(TICK_STEP)
	assert(not enemy.visible, "Sis, başkasının gizlediği düğümü geri açmamalı")
	assert(not enemy.has_meta(VisionFogScript.HIDDEN_META), "Sis kendi yapmadığı gizlemeyi işaretlememeli")
	_cleanup()


func test_no_sources_means_inactive_and_everything_visible() -> void:
	var fog: CanvasLayer = _make_fog()
	var enemy: Node2D = _add_enemy(_screen() * 0.9)
	fog.update_fog(TICK_STEP)
	assert(not fog.is_active(), "Görüş kaynağı yokken (ör. herkes öldü) sis kapalı olmalı")
	assert(enemy.visible, "Sis kapalıyken düşman gizlenmemeli")
	assert(fog.is_world_pos_visible(Vector2(123456.0, -98765.0)),
		"Sis kapalıyken her konum görünür sayılmalı (minimap eski davranışta kalır)")
	_cleanup()


func test_source_count_is_capped() -> void:
	var fog: CanvasLayer = _make_fog()
	var center: Vector2 = _screen() * 0.5
	_add_actor("player", center)
	for i: int in range(VisionFogScript.MAX_SOURCES + 3):
		_add_actor("remote_players", center + Vector2(float(i) * 10.0, 0.0))
	fog.update_fog(TICK_STEP)
	assert(fog.get_source_count() == VisionFogScript.MAX_SOURCES,
		"Kaynak sayısı shader dizisinin boyutunu (MAX_SOURCES) aşmamalı")
	_cleanup()


func test_indoor_remote_player_gives_no_vision() -> void:
	var fog: CanvasLayer = _make_fog()
	var center: Vector2 = _screen() * 0.5
	_add_actor("player", center)
	var indoors_ally: FakeActor = _add_actor("remote_players", center)
	indoors_ally.is_indoors = true
	fog.update_fog(TICK_STEP)
	assert(fog.get_source_count() == 1, "Evin içindeki uzak oyuncu dünyada görüş vermemeli")
	_cleanup()


func test_fog_visibility_of_defaults_to_one() -> void:
	var node := Node2D.new()
	assert(_approx(VisionFogScript.fog_visibility_of(node), 1.0, 0.0001), "Sisin yönetmediği düğüm görünür sayılmalı")
	node.set_meta(VisionFogScript.VIS_META, 0.3)
	assert(_approx(VisionFogScript.fog_visibility_of(node), 0.3, 0.0001), "fog_visibility_of meta değerini döndürmeli")
	node.free()


func test_release_on_exit_restores_visibility_and_metas() -> void:
	var fog: CanvasLayer = _make_fog()
	var center: Vector2 = _screen() * 0.5
	var w: float = _half_width()
	_add_actor("player", center)
	var enemy: Node2D = _add_enemy(center + Vector2(w * _outside_factor() * 1.3, 0.0)) ## sis içinde -> gizli
	fog.update_fog(TICK_STEP)
	assert(not enemy.visible and enemy.has_meta(VisionFogScript.HIDDEN_META), "Ön koşul: düşman sisin içinde gizli olmalı")
	_spawned.erase(fog)
	fog.free() ## _exit_tree -> hepsi eski hâline dönmeli
	assert(enemy.visible, "Sis kalkınca gizlenen düşman geri açılmalı")
	assert(_approx(enemy.modulate.a, 1.0, 0.001), "Sis kalkınca düşmanın alfası 1'de kalmalı")
	assert(not enemy.has_meta(VisionFogScript.HIDDEN_META) and not enemy.has_meta(VisionFogScript.VIS_META),
		"Sis kalkınca işaretler temizlenmeli")
	_cleanup()


func test_minimap_skips_fogged_enemies() -> void:
	var fog: CanvasLayer = _make_fog()
	var center: Vector2 = _screen() * 0.5
	var w: float = _half_width()
	var player: FakeActor = _add_actor("player", center)
	_add_enemy(center + Vector2(w * 0.3, 0.0)) ## görünür
	_add_enemy(center + Vector2(w * _outside_factor() * 1.3, 0.0)) ## sisin içinde
	fog.update_fog(TICK_STEP)

	var minimap: Control = MinimapScript.new()
	add_child(minimap)
	_spawned.append(minimap)
	minimap._player = player
	minimap._process(1.0) ## ENEMY_REFRESH_INTERVAL'i aşar -> nokta listesi yenilenir
	assert(minimap._enemy_dots.size() == 1,
		"Minimap sisteki düşmanı da çiziyor (%d nokta) - karanlıktaki düşmanı ele verir" % minimap._enemy_dots.size())

	## Sis kapanınca (ör. oyuncu ölünce kaynak kalmadı) eski davranış: hepsi görünür.
	player.remove_from_group("player")
	fog.update_fog(TICK_STEP)
	minimap._player = null
	minimap._process(1.0)
	assert(minimap._enemy_dots.size() == 2, "Sis kapalıyken minimap tüm düşmanları göstermeli")
	_cleanup()


func test_floating_text_hides_only_with_fog_hidden_target() -> void:
	var target := Node2D.new()
	add_child(target)
	_spawned.append(target)
	var text: Node2D = FloatingTextScene.instantiate()
	add_child(text)
	_spawned.append(text)
	text.follow_target = target
	text._process(0.0)
	assert(text.visible, "Normal bir hedefin hasar sayısı görünür olmalı")
	target.set_meta(VisionFogScript.VIS_META, 0.2) ## sisin içinde / neredeyse gizli
	text._process(0.0)
	assert(not text.visible, "Sisteki düşmanın hasar sayısı karanlıkta süzülmemeli")
	target.set_meta(VisionFogScript.VIS_META, 0.9) ## görüşe girmiş
	text._process(0.0)
	assert(text.visible, "Görüşe giren düşmanın hasar sayısı görünmeli")
	target.remove_meta(VisionFogScript.VIS_META)
	target.visible = false ## sis DIŞI bir sebeple gizli (ör. görünmez oyuncu)
	text._process(0.0)
	assert(text.visible, "Sis dışı sebeple gizlenen hedefin sayıları eskisi gibi görünmeye devam etmeli")
	_cleanup()


func test_enemy_projectile_is_hideable() -> void:
	var projectile: Node = EnemyProjectileScene.instantiate()
	add_child(projectile)
	_spawned.append(projectile)
	assert(projectile.is_in_group("enemy_projectiles"),
		"Düşman mermisi 'enemy_projectiles' grubunda olmalı ki sisin içinde gizlenebilsin")
	assert("enemy_projectiles" in VisionFogScript.HIDEABLE_GROUPS,
		"vision_fog.gd 'enemy_projectiles' grubunu gizlemiyor")
	_cleanup()


func test_mask_viewport_is_configured_for_feedback() -> void:
	var fog: CanvasLayer = _make_fog()
	var mask: SubViewport = fog._mask_viewport
	assert(mask != null, "Maske SubViewport'u kurulmalı")
	assert(mask.render_target_clear_mode == SubViewport.CLEAR_MODE_NEVER,
		"Maske önceki karesini hatırlamalı (clear NEVER) - yoksa yumuşak açılma/sönme olmaz")
	var size: Vector2 = _screen()
	var wanted := Vector2i(ceili(size.x / float(VisionFogScript.MASK_DOWNSCALE)), ceili(size.y / float(VisionFogScript.MASK_DOWNSCALE)))
	assert(mask.size == wanted, "Maske ekranın 1/%d'i boyutunda olmalı: %s, beklenen %s" % [VisionFogScript.MASK_DOWNSCALE, mask.size, wanted])
	assert(mask.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Sis başlamadan maske GPU'yu çalıştırmamalı")
	_cleanup()


func test_mask_runs_only_while_fog_is_active() -> void:
	var fog: CanvasLayer = _make_fog()
	var player: FakeActor = _add_actor("player", _screen() * 0.5)
	fog.update_fog(TICK_STEP)
	assert(fog._mask_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Sis aktifken maske her kare güncellenmeli")
	player.is_indoors = true
	fog.update_fog(TICK_STEP)
	assert(fog._mask_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Ev içindeyken maske GPU'yu boşuna çalıştırmamalı")
	assert(fog._needs_reset, "Sis kapanınca maske tekrar açılışta geçmişi unutmalı")
	_cleanup()


func test_mask_steps_follow_fade_times() -> void:
	var fog: CanvasLayer = _make_fog()
	_add_actor("player", _screen() * 0.5)
	fog.update_fog(TICK_STEP)
	var up: float = fog._mask_material.get_shader_parameter("up_step")
	var down: float = fog._mask_material.get_shader_parameter("down_step")
	assert(_approx(up, TICK_STEP / VisionFogScript.FADE_IN_TIME, 0.0001), "up_step = delta / FADE_IN_TIME olmalı: %.4f" % up)
	assert(_approx(down, TICK_STEP / VisionFogScript.FADE_OUT_TIME, 0.0001), "down_step = delta / FADE_OUT_TIME olmalı: %.4f" % down)
	## Devasa bir delta (oyun takıldı) tek karede sisi sıçratmamalı: MAX_STEP ile sınırlı.
	fog.update_fog(5.0)
	var clamped_up: float = fog._mask_material.get_shader_parameter("up_step")
	assert(_approx(clamped_up, VisionFogScript.MAX_STEP / VisionFogScript.FADE_IN_TIME, 0.0001),
		"Büyük delta MAX_STEP ile sınırlanmalı: %.4f" % clamped_up)
	_cleanup()


func test_mask_history_kept_for_small_moves_and_reset_on_jumps() -> void:
	var fog: CanvasLayer = _make_fog()
	var size: Vector2 = _screen()
	_add_actor("player", size * 0.5)
	fog.update_fog(TICK_STEP)
	assert(_approx(fog._mask_material.get_shader_parameter("history_keep"), 0.0, 0.0001),
		"İlk karede geçmiş unutulmalı (maske karanlıktan yavaşça açılır)")
	fog.update_fog(TICK_STEP)
	assert(_approx(fog._mask_material.get_shader_parameter("history_keep"), 1.0, 0.0001), "Sonraki karede geçmiş korunmalı")
	## Kamera küçük kayar: geçmiş korunur ve kayma UV olarak doğru hesaplanır.
	var vp: Viewport = get_viewport()
	vp.canvas_transform = Transform2D(0.0, Vector2(-20.0, 0.0))
	fog.update_fog(TICK_STEP)
	assert(_approx(fog._mask_material.get_shader_parameter("history_keep"), 1.0, 0.0001), "Küçük kamera kaymasında geçmiş korunmalı")
	var shift: Vector2 = fog._mask_material.get_shader_parameter("shift_uv")
	assert(_approx(shift.x, 20.0 / size.x, 0.0001) and _approx(shift.y, 0.0, 0.0001),
		"Geçmiş, kameranın kaydığı kadar kaydırılmış okunmalı: %s" % shift)
	## Kamera ışınlanır (ev çıkışı, yeniden doğuş): geçmiş anlamsız, unutulur.
	vp.canvas_transform = Transform2D(0.0, Vector2(-size.x * 3.0, 0.0))
	fog.update_fog(TICK_STEP)
	assert(_approx(fog._mask_material.get_shader_parameter("history_keep"), 0.0, 0.0001),
		"Kamera sıçrayınca geçmiş unutulmalı (bayat maske ekrana yayılmasın)")
	_cleanup()


func test_fog_freezes_while_game_is_paused() -> void:
	var fog: CanvasLayer = _make_fog()
	var center: Vector2 = _screen() * 0.5
	var w: float = _half_width()
	_add_actor("player", center)
	var enemy: Node2D = _add_enemy(center + Vector2(w * 0.3, 0.0))
	fog.update_fog(TICK_STEP)
	enemy.global_position = center + Vector2(w * _outside_factor() * 1.3, 0.0)
	get_tree().paused = true
	fog.update_fog(TICK_STEP)
	fog.update_fog(TICK_STEP)
	## DÜZELTME (kullanıcı isteği 2026-09-23: görünürlük artık ikili/anlık, bkz. _manage_item) - duraklatılmışken
	## düşman hâlâ TAM görünür kalmalı (update_fog() paused iken hiçbir şeye dokunmuyor).
	assert(enemy.visible and _approx(enemy.modulate.a, 1.0, 0.001), "Oyun duraklatılmışken düşman gizlenmeye başlamamalı")
	assert(fog._mask_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"Oyun duraklatılmışken maske durmalı (donmuş dünyada sis kaymasın)")
	get_tree().paused = false
	_settle(fog, [enemy])
	assert(not enemy.visible, "Duraklatma bitince görüş dışındaki düşman gizlenmeli")
	_cleanup()


## ---------------------------------------------------------------------------------
## GÖRÜŞÜ KESEN DUVARLAR (kullanıcı isteği: "orman parçaları layerı ... görüş alanını
## da kısıtlayacak, bunun ardındaki hiçbir şeyi görememeliyiz" - bkz.
## vision_occluders.gd). Testte kamera yok: dünya = piksel; duvar katmanı (0,0)'da.
## ---------------------------------------------------------------------------------

## `wall_cells` (hücre koordinatı, 16px) ile bir engel ızgarası kurup sise verir.
func _give_fog_a_wall(fog: CanvasLayer, wall_cells: Array[Vector2i]) -> RefCounted:
	var layer: TileMapLayer = WallLayerFactory.make_layer(self, wall_cells)
	_spawned.append(layer)
	var occluders: RefCounted = VisionOccludersScript.new()
	occluders.build(layer)
	fog.set_occluders(occluders)
	return occluders


## Ekranın ortasına yakın, bir karonun tam ortasında bir kaynak konumu + o karonun hücresi.
func _source_cell_center() -> Dictionary:
	var cell := Vector2i((_screen() * 0.5 / 16.0).floor())
	return {"cell": cell, "pos": (Vector2(cell) + Vector2(0.5, 0.5)) * 16.0}


## Kaynağın 3 karo üstünde, 13 karo genişliğinde tek karo kalınlığında yatay duvar.
func _wall_three_cells_above(cell: Vector2i) -> Array[Vector2i]:
	return WallLayerFactory.rect_cells(cell.x - 6, cell.y - 3, cell.x + 6, cell.y - 3)


func test_wall_hides_enemy_behind_it_but_not_in_front_or_on_it() -> void:
	var fog: CanvasLayer = _make_fog()
	var src: Dictionary = _source_cell_center()
	var center: Vector2 = src["pos"]
	_add_actor("player", center)
	_give_fog_a_wall(fog, _wall_three_cells_above(src["cell"]))
	fog.update_fog(TICK_STEP)
	assert(fog._target_visibility(center + Vector2(0.0, -80.0)) == 0.0, "Duvarın ARKASINDAKİ nokta görünür kaldı")
	assert(fog._target_visibility(center + Vector2(0.0, 80.0)) > 0.99, "Duvarın ÖNÜNDEKİ (arka taraftaki) nokta gizlendi")
	assert(fog._target_visibility(center + Vector2(0.0, -48.0)) > 0.99, "Duvarın KENDİSİ gizlendi (duvar görünür kalmalı)")
	assert(fog._target_visibility(center + Vector2(0.0, -30.0)) > 0.99, "Duvarın önündeki açık nokta gizlendi")
	_cleanup()


func test_enemy_behind_wall_fades_out_and_reappears_when_wall_is_gone() -> void:
	var fog: CanvasLayer = _make_fog()
	var src: Dictionary = _source_cell_center()
	var center: Vector2 = src["pos"]
	_add_actor("player", center)
	var behind: Node2D = _add_enemy(center + Vector2(0.0, -80.0))
	var front: Node2D = _add_enemy(center + Vector2(0.0, 80.0))
	fog.set_occluders(null)
	fog.update_fog(TICK_STEP)
	assert(behind.visible and _approx(behind.modulate.a, 1.0, 0.001), "Duvar yokken düşman görünür olmalı")

	_give_fog_a_wall(fog, _wall_three_cells_above(src["cell"]))
	_settle(fog, [behind, front])
	assert(not behind.visible, "Duvarın arkasındaki düşman sonunda gizlenmeliydi")
	assert(front.visible and _approx(front.modulate.a, 1.0, 0.001), "Duvarın önündeki düşman etkilenmemeli")
	assert(VisionFogScript.fog_visibility_of(behind) < VisionFogScript.SIDE_ELEMENT_MIN_VISIBILITY,
		"Duvarın arkasındaki düşman minimap/hasar yazısı için de gizli sayılmalı")

	fog.set_occluders(null)
	_settle(fog, [behind])
	assert(behind.visible and _approx(behind.modulate.a, 1.0, 0.001), "Duvar kalkınca düşman yeniden görünmeliydi")
	_cleanup()


func test_team_vision_sees_past_the_wall() -> void:
	var fog: CanvasLayer = _make_fog()
	var src: Dictionary = _source_cell_center()
	var center: Vector2 = src["pos"]
	_add_actor("player", center)
	_give_fog_a_wall(fog, _wall_three_cells_above(src["cell"]))
	var behind_pos: Vector2 = center + Vector2(0.0, -80.0)
	fog.update_fog(TICK_STEP)
	assert(fog._target_visibility(behind_pos) == 0.0, "Ön koşul: duvarın arkası tek kaynakla görünmez")
	## Müttefik duvarın öbür tarafında: onun görüşü o noktayı açar.
	_add_actor("remote_players", center + Vector2(0.0, -112.0))
	fog.update_fog(TICK_STEP)
	assert(fog._target_visibility(behind_pos) > 0.99, "Duvarın arkasındaki müttefiğin görüşü noktayı açmalıydı")
	assert(fog.is_world_pos_visible(behind_pos), "is_world_pos_visible duvarın arkasındaki müttefik görüşünü yansıtmalı")
	_cleanup()


func test_wall_beyond_vision_range_changes_nothing() -> void:
	var fog: CanvasLayer = _make_fog()
	var src: Dictionary = _source_cell_center()
	var center: Vector2 = src["pos"]
	_add_actor("player", center)
	## Duvar çok uzakta (görüş dışında): yakındaki noktalar etkilenmez.
	var far_cell: Vector2i = src["cell"] + Vector2i(0, -60)
	_give_fog_a_wall(fog, WallLayerFactory.rect_cells(far_cell.x - 5, far_cell.y, far_cell.x + 5, far_cell.y))
	fog.update_fog(TICK_STEP)
	assert(fog._target_visibility(center + Vector2(0.0, -80.0)) > 0.99, "Uzaktaki duvar yakındaki noktayı gizledi")
	_cleanup()


func test_mask_receives_occluder_uniforms_that_map_uv_to_cells() -> void:
	## GPU'nun kullandığı UV -> karo dönüşümü, CPU'nun dünya -> karo dönüşümüyle AYNI olmalı;
	## aksi hâlde gölge, duvarın yanlış yerinden başlar (ışın CPU'da doğru, ekranda kaymış görünür).
	var fog: CanvasLayer = _make_fog()
	var src: Dictionary = _source_cell_center()
	var center: Vector2 = src["pos"]
	_add_actor("player", center)
	var occluders: RefCounted = _give_fog_a_wall(fog, _wall_three_cells_above(src["cell"]))

	## Üç kamera durumu: birim, sadece kaydırma, zoom 2 + kaydırma (oyundaki gibi).
	var transforms: Array[Transform2D] = [
		Transform2D.IDENTITY,
		Transform2D(0.0, Vector2(-37.0, 12.0)),
		Transform2D(0.0, Vector2(2.0, 2.0), 0.0, Vector2(-410.0, -95.0)),
	]
	for xform: Transform2D in transforms:
		get_viewport().canvas_transform = xform
		fog.update_fog(TICK_STEP)
		var mat: ShaderMaterial = fog._mask_material
		assert(mat.get_shader_parameter("occluder_enabled") == true, "Engel varken occluder_enabled açık olmalı")
		var scale: Vector2 = mat.get_shader_parameter("uv_to_cell_scale")
		var offset: Vector2 = mat.get_shader_parameter("uv_to_cell_offset")
		var uv_sources: PackedVector2Array = mat.get_shader_parameter("sources")
		var cell_sources: PackedVector2Array = mat.get_shader_parameter("source_cells")
		var expected: Vector2 = occluders.world_to_cell_f(center)
		var from_uv: Vector2 = uv_sources[0] * scale + offset
		assert(from_uv.distance_to(expected) < 0.001, "UV -> karo dönüşümü kaynağı yanlış hücreye koydu: %s / beklenen %s (kamera %s)" % [from_uv, expected, xform])
		assert(cell_sources[0].distance_to(expected) < 0.001, "source_cells[0] kaynağın karo koordinatı olmalı: %s / %s" % [cell_sources[0], expected])
		assert(mat.get_shader_parameter("occluder_grid_size") == Vector2(occluders.get_grid_size()), "Izgara boyu shader'a verilmeli")
		assert(mat.get_shader_parameter("occluders") != null, "Engel texture'ı maskeye verilmeli")
	_cleanup()


func test_wall_shadow_edges_are_softened_only_when_walls_exist() -> void:
	## Kullanıcı bildirimi: duvar kaynaklı görüş kısıtı "keskin ve anormal" durmasın -
	## sis çizilirken maske MASK_BLUR_WORLD yarıçapıyla yumuşatılır (zoom/ekrana göre UV'ye çevrilir).
	## Duvar yokken yumuşatma KAPALI: sis eskisiyle birebir aynı kalır.
	var fog: CanvasLayer = _make_fog()
	var src: Dictionary = _source_cell_center()
	_add_actor("player", src["pos"])
	fog.set_occluders(null)
	fog.update_fog(TICK_STEP)
	assert(fog._material.get_shader_parameter("mask_blur_uv") == Vector2.ZERO, "Duvar yokken maske yumuşatılmamalı")

	_give_fog_a_wall(fog, _wall_three_cells_above(src["cell"]))
	var size: Vector2 = _screen()
	for zoom: float in [1.0, 2.0]:
		get_viewport().canvas_transform = Transform2D(0.0, Vector2(zoom, zoom), 0.0, Vector2.ZERO)
		fog.update_fog(TICK_STEP)
		var blur: Vector2 = fog._material.get_shader_parameter("mask_blur_uv")
		var expected := Vector2(VisionFogScript.MASK_BLUR_WORLD * zoom / size.x, VisionFogScript.MASK_BLUR_WORLD * zoom / size.y)
		assert(blur.distance_to(expected) < 0.00001, "Yumuşatma yarıçapı dünya biriminde sabit kalmalı (zoom %.1f): %s / beklenen %s" % [zoom, blur, expected])
	assert(_approx(fog._mask_material.get_shader_parameter("min_wall_crossing"), VisionOccludersScript.MIN_WALL_CROSSING, 0.0001),
		"min_wall_crossing CPU ile AYNI değerle shader'a verilmeli")
	_cleanup()


func test_mask_occluders_disabled_without_walls() -> void:
	var fog: CanvasLayer = _make_fog()
	_add_actor("player", _screen() * 0.5)
	fog.set_occluders(null)
	fog.update_fog(TICK_STEP)
	assert(fog._mask_material.get_shader_parameter("occluder_enabled") == false, "Duvar yokken occluder_enabled kapalı olmalı")
	assert(fog._mask_material.get_shader_parameter("occluders") == null, "Duvar yokken texture verilmemeli")
	_cleanup()
