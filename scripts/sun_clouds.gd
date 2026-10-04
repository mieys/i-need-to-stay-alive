extends CanvasLayer

## Güneş ışığı + bulut gölgeleri (shaders/gunes_bulut.gdshader) - kullanıcı isteği (2026-09-26): "oyunuma güneş ışığı
## yansıması eklemeni istiyorum ayrıca bulut gölgeleri olacak. oyuncunun hareketine göre hafif şekillenmeli ve göz
## yormamalı."
##
## İki ekranı okumayan tam ekran geçiş (aynı shader, "gecis"): main.gd bulut gölgesini (bu katman) gün-gece renk geçişinin
## (atmosphere_overlay.gd) HEMEN önüne, güneş huzmesini (light_layer) sisin HEMEN arkasına koyar (aynı
## layer=1, çizim sırasını ağaç sırası belirler): dünya -> bulut gölgesi -> renk geçişi -> sis -> güneş -> HUD. Bulut
## gölgesi zemine düşer (gece rengi ona da uygulanır); güneş gökyüzünden gelir (sis köşeleri koyulaştırdığı için önce
## çizilen huzmeler görünmüyordu). Güneş sadece ışık ekler - sisin gizlediği hiçbir şeyi göstermez. HUD etkilenmez.
##
## Güç atmosferden (atmosphere.gd): güneş gündüz tam, akşam/gece söner, yağmur/sağanakta söner; bulut gölgeleri gündüz
## belirgin, gece neredeyse yok, yağmurda gökyüzü kapalı olduğu için daha geniş ama daha soluk. Rüzgar bulutları rüzgar
## yönünde sürükler. Ev içinde kapalı. Tamamen yerel/kozmetik (ağ yok).
## ESKİ bulut gölgesi (shaders/cloud_shadows.gdshader, main.gd _apply_cloud_shadows - kapalı) her harita katmanının
## materyalini DEĞİŞTİRİYORDU (çimen/ot shader'larıyla çakışırdı); bu sistem katmanlara dokunmaz.

const ShaderRes: Shader = preload("res://shaders/gunes_bulut.gdshader")
const AtmosphereMathRef: GDScript = preload("res://scripts/atmosphere_math.gd")

## Güneş: gündüz tam güç; karanlık (atmosphere_math.darkness) arttıkça söner.
## 2026-09-26: 0.3 (+ sabit köşe parıltısı) -> 0.19 (kullanıcı: "çok parlak"; köşe parıltısı da kaldırıldı)
## (Bir ara x0.8 -> 0.152 yapıldı; kullanıcı fikrini değiştirdi: genel güç 0.19'da kalsın, sadece çok parlak anlar kısılsın
## - bkz. shader'daki parlaklik_esigi / parlaklik_tavani.)
## Kullanıcı isteği (2026-09-27): "güneş ışığının parlaklığını (yansımalar) %15 kısar mısın çok dikkat çekiyor" - 0.19 -> 0.1615.
const SUN_STRENGTH := 0.1615
## Bulut gölgesi gücü / kaplaması: açık hava -> yağmur.
## Kullanıcı isteği (2026-09-26): "bulutların yarattığı karanlığın gücünü %50 azalt" - 0.19/0.1 -> yarısı.
const CLOUD_STRENGTH_CLEAR := 0.095
const CLOUD_STRENGTH_RAIN := 0.05
const CLOUD_COVER_CLEAR := 0.4
const CLOUD_COVER_WINDY := 0.45
const CLOUD_COVER_RAIN := 0.62
## Bulut sürüklenmesi (dünya px/sn): sakin havada bile çok yavaş kayar.
const DRIFT_BASE := 5.0
const DRIFT_WIND := 22.0
## Güç değişimleri yumuşak (hava/gün geçişlerinde ani sıçrama olmasın).
const FADE_RATE := 0.5
## PİŞİRME (2026-10-03, telefon FPS - bkz. shader "gecis 2"): bulut + güneş bir kez, 1 piksel = 1 dünya texel'i çözünürlükte
## küçük bir SubViewport'ta hesaplanır; iki ekran geçişi sadece o texel'i okur (görüntü aynı, telefonda ~10 kat az iş).
## Dünya görünümü ekranın bu oranından büyükse (kamera çok uzak) pişirme kapanır, geçişler eskisi gibi doğrudan hesaplar.
const BAKE_MAX_PIXEL_RATIO := 0.6

var _rect: ColorRect = null
var _mat: ShaderMaterial = null
## Güneş huzmesi SİSİN ÜSTÜNDE ayrı bir katmanda (bkz. shader "gecis"): main.gd bunu vision_fog'un hemen
## arkasına (HUD'dan önce) yerleştirir. Aynı değerleri bu script yazar.
var light_layer: CanvasLayer = null
var _light_rect: ColorRect = null
var _light_mat: ShaderMaterial = null
## false = pişirme kapalı, eski doğrudan hesaplama (A/B karşılaştırma).
var bake_enabled: bool = true
var _bake: SubViewport = null
var _bake_rect: ColorRect = null
var _bake_mat: ShaderMaterial = null
var _atmosphere: Node = null
var _drift: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _sun_k: float = 0.0
var _cloud_k: float = 0.0
var _cover: float = CLOUD_COVER_CLEAR


func _ready() -> void:
	layer = 1
	process_priority = 998 ## kameradan sonra (atmosphere_overlay 999, sis 1000)
	_mat = ShaderMaterial.new()
	_mat.shader = ShaderRes
	_rect = ColorRect.new()
	_rect.name = "GunesBulut"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mat.set_shader_parameter("gecis", 0)
	light_layer = CanvasLayer.new()
	light_layer.name = "SunLight"
	light_layer.layer = 1
	_light_mat = ShaderMaterial.new()
	_light_mat.shader = ShaderRes
	_light_mat.set_shader_parameter("gecis", 1)
	_light_rect = ColorRect.new()
	_light_rect.name = "GunesIsigi"
	_light_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light_rect.material = _light_mat
	light_layer.add_child(_light_rect)
	_light_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bake_mat = ShaderMaterial.new()
	_bake_mat.shader = ShaderRes
	_bake_mat.set_shader_parameter("gecis", 2)
	_bake = SubViewport.new()
	_bake.name = "GunesBulutPisirme"
	_bake.disable_3d = true
	_bake.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_bake_rect = ColorRect.new()
	_bake_rect.material = _bake_mat
	_bake.add_child(_bake_rect)
	add_child(_bake)
	for m: ShaderMaterial in [_mat, _light_mat]:
		m.set_shader_parameter("pisik", _bake.get_texture())
	## Rastgele başlangıç: her oyunda bulutlar farklı yerde.
	_drift = Vector2(randf_range(-5000.0, 5000.0), randf_range(-5000.0, 5000.0))


func _process(delta: float) -> void:
	if _atmosphere == null or not is_instance_valid(_atmosphere):
		_atmosphere = get_tree().get_first_node_in_group(&"atmosphere")
	var darkness: float = 0.0
	var rain: float = 0.0
	var storm: float = 0.0
	var wind: float = 0.0
	var wind_angle: float = 0.0
	if _atmosphere:
		darkness = AtmosphereMathRef.darkness(float(_atmosphere.get("cycle_time")))
		rain = float(_atmosphere.get("rain_intensity"))
		storm = float(_atmosphere.get("storm_intensity"))
		wind = float(_atmosphere.get("wind_intensity"))
		wind_angle = float(_atmosphere.get("wind_angle"))
	var indoors: bool = _local_player_indoors()
	var wet: float = clampf(maxf(rain, storm), 0.0, 1.0)
	var day: float = 1.0 - darkness
	var sun_target: float = 0.0 if indoors else day * day * (1.0 - wet)
	var cloud_target: float = 0.0 if indoors else day * lerpf(CLOUD_STRENGTH_CLEAR, CLOUD_STRENGTH_RAIN, wet) / CLOUD_STRENGTH_CLEAR
	var cover_target: float = lerpf(lerpf(CLOUD_COVER_CLEAR, CLOUD_COVER_WINDY, wind), CLOUD_COVER_RAIN, wet)
	var step: float = FADE_RATE * delta
	_sun_k = move_toward(_sun_k, sun_target, step)
	_cloud_k = move_toward(_cloud_k, cloud_target, step)
	## Grafik ayarı (UISound.gfx_sun_clouds, Düşük/Orta'da kapalı): ANINDA kapanır - iki tam ekran geçiş + pişirme hiç çizilmez.
	if not UISound.gfx_sun_clouds:
		_sun_k = 0.0
		_cloud_k = 0.0
	_cover = move_toward(_cover, cover_target, step * 0.2)
	_rect.visible = _cloud_k > 0.002
	_light_rect.visible = _sun_k > 0.002
	if not _rect.visible and not _light_rect.visible:
		_bake.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_time += delta
	_drift -= Vector2.from_angle(wind_angle) * (DRIFT_BASE + DRIFT_WIND * wind) * delta

	var vp: Viewport = get_viewport()
	var inv: Transform2D = vp.get_canvas_transform().affine_inverse()
	var size: Vector2 = vp.get_visible_rect().size
	var tl: Vector2 = inv * Vector2.ZERO
	var br: Vector2 = inv * size
	## Pişirme dokusu: görünen dünya texel'leri + 1 texel pay (tam sayı köşe).
	var koken: Vector2 = tl.floor() - Vector2.ONE
	var bake_size := Vector2i(ceili(br.x - koken.x) + 2, ceili(br.y - koken.y) + 2)
	var baked: bool = bake_enabled and float(bake_size.x * bake_size.y) <= size.x * size.y * BAKE_MAX_PIXEL_RATIO
	_bake.render_target_update_mode = SubViewport.UPDATE_ALWAYS if baked else SubViewport.UPDATE_DISABLED
	if baked:
		if _bake.size != bake_size:
			_bake.size = bake_size
			_bake_rect.size = Vector2(bake_size)
		_bake_mat.set_shader_parameter("pisik_koken", koken)
		_bake_mat.set_shader_parameter("pisik_boyut", Vector2(bake_size))
		_bake_mat.set_shader_parameter("gunes_hesapla", _light_rect.visible)
	for m: ShaderMaterial in [_mat, _light_mat]:
		m.set_shader_parameter("pisik_kullan", baked)
		m.set_shader_parameter("pisik_koken", koken)
	for m: ShaderMaterial in [_mat, _light_mat, _bake_mat]:
		m.set_shader_parameter("dunya_sol_ust", tl)
		m.set_shader_parameter("dunya_boyut", br - tl)
		m.set_shader_parameter("kamera", (tl + br) * 0.5)
		m.set_shader_parameter("zaman", _time)
		m.set_shader_parameter("bulut_ofset", _drift)
		m.set_shader_parameter("bulut_guc", CLOUD_STRENGTH_CLEAR * _cloud_k)
		m.set_shader_parameter("bulut_kaplama", _cover)
		m.set_shader_parameter("gunes_guc", SUN_STRENGTH * _sun_k)


func _local_player_indoors() -> bool:
	var p: Node = get_tree().get_first_node_in_group("player")
	return p != null and p.has_method("is_indoors_now") and bool(p.call("is_indoors_now"))
