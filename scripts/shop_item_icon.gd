extends Control

@export var item_type: String = "mine"
@export var item_key: String = "":
	set(val):
		item_key = val
		if item_key != "":
			var path: String = "res://assets/generated/item_" + item_key + "_frame_0.png"
			## DÜZELTME (export günlüğü kirliliği): her eşyanın hazır
			## çizilmiş bir PNG'si YOK - bir kısmı aşağıdaki _draw_*()
			## fonksiyonlarıyla prosedürel olarak çiziliyor (ör. "vampir_disi",
			## "yetenek_kitabi" ikonlarının dosyası hiç üretilmemiş). Dosya
			## yokken doğrudan load() çağırmak hem editör hem EXPORT günlüğüne
			## "No loader found for resource: res://assets/generated/item_..."
			## hatası basıyordu (oyunu bozmuyor ama gerçek hataları gizliyor).
			## Artık yalnızca dosya VARSA yükleniyor, yoksa prosedürel çizim
			## devrede kalıyor.
			texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
			queue_redraw()

var texture: Texture2D = null


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var s: float = min(size.x, size.y) * 0.5
	match item_type:
		"mine":
			_draw_coin(c, s)
		"spray":
			_draw_spray(c, s)
		"shield":
			_draw_shield(c, s)
		"trinket":
			_draw_trinket(c, s)
		"gold_collector":
			_draw_gold_collector(c, s)


## Altın Toplama Cihazı - Maden'in altın rengiyle karışmasın diye ayrı bir
## siluet: bir mıknatıs (altını "çeken" bir alet hissi) + üstünde küçük bir
## altın parçası. _draw_coin ile aynı sarı tonlarını paylaşır ki "bu da
## altınla ilgili" bağlantısı görsel olarak net kalsın.
func _draw_gold_collector(c: Vector2, s: float) -> void:
	var magnet_col := Color(0.55, 0.15, 0.12)
	var magnet_col_dark := Color(0.35, 0.09, 0.07)
	var tip_col := Color(0.75, 0.75, 0.78)
	## U şeklinde mıknatıs gövdesi (iki bacak + üst kavis).
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.55, s * 0.85), c + Vector2(-s * 0.55, -s * 0.1),
		c + Vector2(-s * 0.3, -s * 0.45), c + Vector2(0, -s * 0.55),
		c + Vector2(s * 0.3, -s * 0.45), c + Vector2(s * 0.55, -s * 0.1),
		c + Vector2(s * 0.55, s * 0.85), c + Vector2(s * 0.3, s * 0.85),
		c + Vector2(s * 0.3, -s * 0.05), c + Vector2(0, -s * 0.28),
		c + Vector2(-s * 0.3, -s * 0.05), c + Vector2(-s * 0.3, s * 0.85),
	]), magnet_col)
	draw_line(c + Vector2(-s * 0.55, s * 0.4), c + Vector2(-s * 0.3, s * 0.4), magnet_col_dark, 2.0)
	draw_line(c + Vector2(s * 0.3, s * 0.4), c + Vector2(s * 0.55, s * 0.4), magnet_col_dark, 2.0)
	## Bacak uçları (metal parlaklık).
	draw_rect(Rect2(c.x - s * 0.55, c.y + s * 0.65, s * 0.25, s * 0.2), tip_col, true)
	draw_rect(Rect2(c.x + s * 0.3, c.y + s * 0.65, s * 0.25, s * 0.2), tip_col, true)
	## Çekilen küçük altın parçası - mıknatısın hemen üstünde.
	draw_circle(c + Vector2(0, -s * 0.82), s * 0.28, Color(0.5, 0.36, 0.06))
	draw_circle(c + Vector2(0, -s * 0.82), s * 0.22, Color(1.0, 0.82, 0.2))
	draw_circle(c + Vector2(-s * 0.06, -s * 0.88), s * 0.08, Color(1, 0.97, 0.75, 0.85))


func _draw_coin(c: Vector2, s: float) -> void:
	draw_circle(c, s, Color(0.5, 0.36, 0.06))
	draw_circle(c, s * 0.88, Color(1.0, 0.82, 0.2))
	draw_circle(c, s * 0.64, Color(0.88, 0.66, 0.12))
	draw_circle(c, s * 0.46, Color(0.98, 0.8, 0.25))
	draw_circle(c + Vector2(-s * 0.28, -s * 0.28), s * 0.2, Color(1, 0.97, 0.75, 0.85))


func _draw_spray(c: Vector2, s: float) -> void:
	var body_col := Color(0.35, 0.68, 0.6)
	draw_rect(Rect2(c.x - s * 0.32, c.y - s * 0.2, s * 0.64, s * 0.85), body_col, true)
	draw_rect(Rect2(c.x - s * 0.14, c.y - s * 0.58, s * 0.28, s * 0.38), Color(0.65, 0.7, 0.72), true)
	draw_rect(Rect2(c.x - s * 0.06, c.y - s * 0.74, s * 0.12, s * 0.2), Color(0.5, 0.55, 0.58), true)
	draw_circle(c + Vector2(0, s * 0.12), s * 0.12, Color(0.7, 0.95, 0.85, 0.9))
	# Arrows kept within the icon's own bounds (s*1.0 max) so they don't spill
	# into neighboring rows/UI.
	var arrow_col := Color(0.55, 0.95, 0.8)
	for ang in [PI * 1.15, PI * 1.55, PI * 1.85]:
		var dir := Vector2(cos(ang), sin(ang))
		var base: Vector2 = c + dir * s * 0.62
		var tip: Vector2 = c + dir * s * 0.92
		var side: Vector2 = dir.orthogonal() * s * 0.11
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), arrow_col)


func _draw_shield(c: Vector2, s: float) -> void:
	var col := Color(0.35, 0.65, 1.0)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.75, -s * 0.6), c + Vector2(s * 0.75, -s * 0.6), c + Vector2(s * 0.75, s * 0.1),
		c + Vector2(0, s * 1.0), c + Vector2(-s * 0.75, s * 0.1)
	]), Color(0.6, 0.6, 0.65))
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.6, -s * 0.48), c + Vector2(s * 0.6, -s * 0.48), c + Vector2(s * 0.6, s * 0.06),
		c + Vector2(0, s * 0.85), c + Vector2(-s * 0.6, s * 0.06)
	]), col)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.32, -s * 0.28), c + Vector2(s * 0.32, -s * 0.28), c + Vector2(s * 0.32, 0),
		c + Vector2(0, s * 0.5), c + Vector2(-s * 0.32, 0)
	]), Color(0.65, 0.85, 1.0))
	## Kıvılcımlar artık ikonun kendi sınırları içinde kalıyor (s*1.0 maks,
	## çapraz uzunluk da s ile ölçekleniyor - eskiden sabit 4px'ti, küçük
	## ikonlarda sorun değildi ama büyük önizleme ikonunda (140px) kutudan
	## taşıyordu, bkz. kullanıcı bildirimi "dükkan arayüzünde kalkan ikonları
	## dışarı taşmış"). _draw_spray'deki aynı desen.
	var spark_col := Color(0.7, 0.9, 1.0, 0.9)
	var cross: float = s * 0.06
	for off in [Vector2(-s * 0.82, -s * 0.15), Vector2(s * 0.8, -s * 0.35), Vector2(s * 0.72, s * 0.38), Vector2(-s * 0.72, s * 0.42)]:
		var p: Vector2 = c + off
		draw_line(p + Vector2(-cross, 0), p + Vector2(cross, 0), spark_col, 2.0)
		draw_line(p + Vector2(0, -cross), p + Vector2(0, cross), spark_col, 2.0)


## Eşyalar (bkz. scripts/items.gd) için paylaşılan tek vektör ikonu - kalkan
## MODLARIYLA (bkz. yukarıdaki "shield" case'i, ModsPage) BİREBİR AYNI desen:
## tek bir taban şekil, her eşya kendi satırında farklı bir "modulate" tonuyla
## tekrar kullanılıyor (bkz. shop_panel.tscn ItemsPage). Basit bir mühür/muska
## şekli - köşeli bir madalyon içinde küçük bir taş.
func _draw_trinket(c: Vector2, s: float) -> void:
	if texture:
		var tex_size = texture.get_size()
		var scale_factor = min(s * 2.0 / tex_size.x, s * 2.0 / tex_size.y)
		var draw_size = tex_size * scale_factor
		var draw_pos = c - draw_size * 0.5
		draw_texture_rect(texture, Rect2(draw_pos, draw_size), false)
		return
	var outline_col := Color(0.4, 0.32, 0.18)
	var body_col := Color(0.85, 0.7, 0.4)
	## Dış madalyon (elmas/mühür şekli).
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s * 0.95), c + Vector2(s * 0.8, 0),
		c + Vector2(0, s * 0.95), c + Vector2(-s * 0.8, 0)
	]), outline_col)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s * 0.75), c + Vector2(s * 0.62, 0),
		c + Vector2(0, s * 0.75), c + Vector2(-s * 0.62, 0)
	]), body_col)
	## İçteki taş.
	draw_circle(c, s * 0.32, Color(0.55, 0.85, 0.95, 0.95))
	draw_circle(c + Vector2(-s * 0.1, -s * 0.1), s * 0.12, Color(1, 1, 1, 0.8))
