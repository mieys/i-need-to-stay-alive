extends Node

## YARATIK - OYUNCU çizim sırası (y-sıralama) - kullanıcı isteği (2026-10-08): "bir şeyin arkasındayken karakter onun altında, önündeyken üstünde görünsün".
## Oyuncular z_index 1'de, yaratıklar z 0'da: oyuncu bir yaratığın ÖNÜNDEYKEN (ayağı yaratığın ayağından aşağıda) üstte doğru görünüyordu ama
## ARKASINDAYKEN de üstte kalıyordu. Burada oyuncunun gövdesiyle örtüşen ve AYAĞI oyuncunun ayağından aşağıda olan (yani oyuncunun önünde duran)
## yaratıklar geçici olarak z_index 2'ye alınır (oyuncunun üstüne çizilir), önlerinden ayrılınca eski z'ye döner. Yaratıkların kendi aralarındaki
## sıra aynen kalır (main.gd _update_creature_draw_order, C++ draw_order); harita nesneleri için bkz. depth_occluders.gd.
## Karakterler = yerel oyuncu + uzak oyuncu kuklaları (depth_occluders.gd collect_characters). Tamamen yerel/kozmetik, ağ gerekmez.
## Sadece "enemies" (+ görev kopyaları, EnemyQuery.candidates'in döndürdüğü): evcil hayvan/müttefik (player_ally*) oyuncunun altında KALIR (eskisi gibi).
## Ölüm animasyonundaki (is_dead) yaratık yerde yatar - hep oyuncunun altında kalır.
## Titreme koruması: yükselme ayak farkı > +HYSTERESIS, inme < -HYSTERESIS (yan yana yürürken z her karede gidip gelmesin).
##
## KAPANIŞ (2026-10-09, kullanıcı: "yeraltı canavarı yan yana dizilince birbirinin üzerinde görünüyor, eksenler yanlış"): yükseltilen yaratıklar (z 2) HER ZAMAN yükseltilmeyenlerin
## (z 0) üstüne çizilir - yükseltilen yaratık ARKADAYSA ve ayağı daha aşağıdaki (önündeki) komşusu yükseltilmediyse (oyuncuyla örtüşmüyor / tarama yarıçapının dışında), arkadaki yaratık
## öndekinin ÜSTÜNE çiziliyordu (Yeraltı Canavarı uzuvları: büyük sprite, sıra boyunca bir kısmı oyuncunun yanında). Çözüm: oyuncuyla örtüşen yaratıklardan başlayıp, ayağı daha aşağıda olan VE
## onunla örtüşebilen her yaratık da yükseltilir (`close_over`; yükseltilen bir yaratığın önündeki her şey de oyuncunun önündedir, yani yükseltmek hep doğrudur). Böylece yükseltilen küme,
## ayak sırasında "aşağıya doğru kapalı" kalır ve yaratıkların kendi aralarındaki sıra (main.gd _update_creature_draw_order) bozulmaz.

const DepthScript := preload("res://scripts/depth_occluders.gd")
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")

const FRONT_Z := 2
## Karaktere bu uzaklıktan (kök noktası, x ve y ayrı ayrı) yakın yaratıklar incelenir; çok büyük gövdeler (boss ~71 px) için geniş tutuldu.
const SCAN_RADIUS := 130.0
const HYSTERESIS := 2.0
const FALLBACK_HEIGHT := 48.0
const FALLBACK_HALF_WIDTH := 24.0
## Kapanış taraması doğrudan tarama yarıçapından bu kadar geniş (oyuncuyla örtüşen yaratığın önündeki komşular bu bandın içinde aranır).
const CLOSURE_PAD := 240.0
## Konumu karakterin ayağından bu kadar YUKARIDA olan yaratık ne yükselir ne de yükselen birinin önünde olabilir (ayak - konum farkı en çok ~70 px): hiç hesaplanmaz.
const ABOVE_SKIP := 130.0

var _raised: Dictionary = {} ## yaratık düğümü -> yükselmeden önceki z_index


## Saf kural (testler için): bu yaratık oyuncunun ÜSTÜNE çizilmeli mi?
##  foot_y/height: yaratığın ayağının dünya y'si ve görsel boyu; dx: yaratığın x'i - oyuncunun x'i; feet_y: oyuncunun ayağı; raised: şu an yükseltilmiş mi.
static func should_cover(foot_y: float, height: float, dx: float, feet_y: float, raised: bool) -> bool:
	var margin: float = -HYSTERESIS if raised else HYSTERESIS
	if foot_y <= feet_y + margin:
		return false ## ayağı oyuncununkinden yukarıda ya da aynı hizada: yaratık oyuncunun ARKASINDA, altında kalır
	if foot_y - height >= feet_y:
		return false ## görselin tamamı oyuncunun ayağından aşağıda: örtüşme yok, z'ye dokunma
	return absf(dx) <= DepthScript.BODY_HALF_WIDTH + maxf(height * 0.5, 20.0)


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 2 != 0:
		return
	update_now()


## Saf kural (testler için): `want` (yükseltilecek düğümler) kümesini AYAK SIRASINDA aşağıya doğru kapatır. pool: düğüm -> [ayak y, x, yarım genişlik, boy]. Bir yaratık, kendisinden
## YUKARIDA (ayağı daha küçük) ve onunla örtüşebilen yükseltilmiş bir yaratık varsa o da yükseltilir. Döner: eklenen yaratık sayısı.
static func close_over(want: Dictionary, pool: Dictionary) -> int:
	if want.is_empty() or pool.size() <= want.size():
		return 0
	var keys: Array = [] ## Vector2(ayak y, sıra) - Array.sort() yerleşik karşılaştırmayla sıralar
	var nodes: Array = pool.keys()
	for i in range(nodes.size()):
		keys.append(Vector2(float((pool[nodes[i]] as Array)[0]), float(i)))
	keys.sort()
	var raised: Array = [] ## yükseltilmiş yaratıkların bilgisi
	var added: int = 0
	for k: Vector2 in keys:
		var n: Variant = nodes[int(k.y)]
		var info: Array = pool[n]
		if want.has(n):
			raised.append(info)
			continue
		for a: Array in raised:
			if float(a[0]) < float(info[0]) - 0.5 and absf(float(a[1]) - float(info[1])) < float(a[2]) + float(info[2]) and float(info[0]) - float(info[3]) < float(a[0]):
				want[n] = true
				raised.append(info)
				added += 1
				break
	return added


func update_now() -> void:
	var want: Dictionary = {}
	var pool: Dictionary = {} ## düğüm -> [ayak y, x, yarım genişlik, boy] (kapanış için)
	var chars: Array[Vector4] = DepthScript.collect_characters(get_tree())
	for c in chars:
		for e in EnemyQueryScript.candidates(get_tree(), Vector2(c.x, c.y), SCAN_RADIUS + CLOSURE_PAD):
			var n := e as Node2D
			if n == null or not is_instance_valid(n) or not n.visible or n.get("is_dead") == true:
				continue
			var adx: float = absf(n.global_position.x - c.x)
			var ady: float = absf(n.global_position.y - c.y)
			if adx > SCAN_RADIUS + CLOSURE_PAD or ady > SCAN_RADIUS + CLOSURE_PAD or n.global_position.y < c.y - ABOVE_SKIP:
				continue
			var foot: float = _foot_y(n)
			var ext: Vector2 = _extent(n)
			if not pool.has(n):
				pool[n] = [foot, n.global_position.x, ext.x, ext.y]
			if adx <= SCAN_RADIUS and ady <= SCAN_RADIUS and not want.has(n):
				if should_cover(foot, ext.y, n.global_position.x - c.x, c.y, _raised.has(n)):
					want[n] = true
	close_over(want, pool)
	for n: Node2D in want:
		if not _raised.has(n):
			_raised[n] = n.z_index
			n.z_index = FRONT_Z
	for n in _raised.keys():
		if want.has(n):
			continue
		if is_instance_valid(n):
			(n as Node2D).z_index = int(_raised[n])
		_raised.erase(n)


## Yaratığın ayağının dünya y'si: main.gd'nin ölçtüğü (sprite karesindeki en alt dolu satır) değer; main yoksa kök noktası.
func _foot_y(n: Node2D) -> float:
	var main: Node = get_parent()
	if main != null and main.has_method("_creature_foot_y"):
		return float(main.call("_creature_foot_y", n))
	return n.global_position.y


## Yaratık görselinin ekrandaki (yarım genişlik, boy) ölçüsü (px): Sprite2D / AnimatedSprite2D KARESİ x ölçek (opak alan değil, kare). Bulunamazsa FALLBACK_*.
func _extent(n: Node2D) -> Vector2:
	if n.has_meta("_depth_extent"):
		return n.get_meta("_depth_extent")
	var vis: Node2D = null
	var vis_v: Variant = n.get_meta("_depth_vis") if n.has_meta("_depth_vis") else null
	if is_instance_valid(vis_v):
		vis = vis_v
	else:
		for child_name in ["Sprite2D", "AnimatedSprite2D"]:
			var c: Node = n.get_node_or_null(child_name)
			if c is Sprite2D or c is AnimatedSprite2D:
				vis = c as Node2D
				n.set_meta("_depth_vis", vis)
				break
	if vis == null:
		return Vector2(FALLBACK_HALF_WIDTH, FALLBACK_HEIGHT)
	var size := Vector2.ZERO
	if vis is Sprite2D:
		var s := vis as Sprite2D
		if s.texture != null:
			size = s.texture.get_size() / Vector2(maxi(s.hframes, 1), maxi(s.vframes, 1))
	else:
		var a := vis as AnimatedSprite2D
		if a.sprite_frames != null and a.sprite_frames.has_animation(a.animation) and a.sprite_frames.get_frame_count(a.animation) > 0:
			var t: Texture2D = a.sprite_frames.get_frame_texture(a.animation, 0)
			if t != null:
				size = t.get_size()
	if size.y <= 0.0:
		return Vector2(FALLBACK_HALF_WIDTH, FALLBACK_HEIGHT)
	var sc: Vector2 = vis.global_scale.abs()
	var ext := Vector2(size.x * sc.x * 0.5, size.y * sc.y)
	n.set_meta("_depth_extent", ext) ## düğüm başına bir kez (ölçek doğuşta belli; poz/animasyon sayfaları aynı kare boyunda)
	return ext


func _exit_tree() -> void:
	for n in _raised.keys():
		if is_instance_valid(n):
			(n as Node2D).z_index = int(_raised[n])
	_raised.clear()
