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

##
## ŞOVALYE KUBBESİ (2026-10-17, kullanıcı: "şovalye adamın bariyerinin altında gibi görünüyor yaratıklar. y eksenine tabi değil bu bariyer"): kubbenin ön
## kabuğu sabit z 20'de (PaladinDome.SHELL_Z) - içerideki/arkadaki her şeyi örtmesi doğru ama ÖNÜNDEKİ (elipsin dışında, merkezin güneyinde) yaratıklar
## da camın altında kalıyordu. Artık kabukla örtüşen önündeki yaratık SHELL_Z + 1'e çıkar (oyuncunun önündeyse + FRONT_Z), önündeki oyuncu/kukla
## SHELL_Z + 2'ye (iki yaratık katmanının arası: oyuncu-yaratık kuralı aynen işler). Kubbe kümesi de aşağıya doğru KAPALI (close_over) ve önündeki
## oyuncunun önündeki yaratıklar da kümeye girer -> z bileşenleri ayak sırasında hep artan, yaratıkların kendi sırası bozulmaz.
## Bilinen bedel: kabuğun önündeki yaratık/oyuncu ağaç ön kopyalarının (z 3) ve z 4-20 arası efektlerin (düşman mermisi z 11) üstüne çizilir.
## Duvar geçen (uçan, forest_canopy.gd) oyuncunun z'sine dokunulmaz.

const DepthScript := preload("res://scripts/depth_occluders.gd")
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const PaladinDome := preload("res://scripts/paladin_dome.gd")
const ForestCanopyScript := preload("res://scripts/forest_canopy.gd")

const FRONT_Z := 2
const DOME_FRONT_Z := PaladinDome.SHELL_Z + 1 ## kabuğun önündeki yaratık (oyuncunun da önündeyse + FRONT_Z)
const DOME_FRONT_CHAR_Z := PaladinDome.SHELL_Z + 2 ## kabuğun önündeki oyuncu/kukla
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
var _was_front: Dictionary = {} ## son güncellemede oyuncunun önünde yükselen yaratıklar (histerezis)
var _was_dome: Dictionary = {} ## son güncellemede kubbe kabuğunun önünde yükselen yaratıklar (histerezis)
var _raised_chars: Dictionary = {} ## kabuğun önüne çıkarılan oyuncu/kukla -> önceki z_index


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
	var tree := get_tree()
	var want: Dictionary = {}
	var pool: Dictionary = {} ## düğüm -> [ayak y, x, yarım genişlik, boy] (kapanış için)
	var char_nodes: Array[Node2D] = DepthScript.character_nodes(tree)
	var chars: Array[Vector4] = DepthScript.collect_characters(tree)
	for c in chars:
		for e in EnemyQueryScript.candidates(tree, Vector2(c.x, c.y), SCAN_RADIUS + CLOSURE_PAD):
			var n := e as Node2D
			if n == null or not is_instance_valid(n) or not n.visible or n.get("is_dead") == true:
				continue
			var adx: float = absf(n.global_position.x - c.x)
			var ady: float = absf(n.global_position.y - c.y)
			if adx > SCAN_RADIUS + CLOSURE_PAD or ady > SCAN_RADIUS + CLOSURE_PAD or n.global_position.y < c.y - ABOVE_SKIP:
				continue
			_pool_add(pool, n)
			if adx <= SCAN_RADIUS and ady <= SCAN_RADIUS and not want.has(n):
				var info: Array = pool[n]
				if should_cover(float(info[0]), float(info[3]), n.global_position.x - c.x, c.y, _was_front.has(n)):
					want[n] = true
	close_over(want, pool)
	## Şovalye kubbesi: kabuğun önündeki yaratıklar + oyuncular (bkz. dosya başı).
	var dome_want: Dictionary = {}
	var front_chars: Dictionary = {}
	var domes: Array[Vector3] = PaladinDome.active_domes(tree)
	if not domes.is_empty():
		for d: Vector3 in domes:
			var center := Vector2(d.x, d.y)
			for e in EnemyQueryScript.candidates(tree, center, d.z + CLOSURE_PAD):
				var n := e as Node2D
				if n == null or not is_instance_valid(n) or not n.visible or n.get("is_dead") == true or n.global_position.y < center.y - ABOVE_SKIP:
					continue
				_pool_add(pool, n)
				var info: Array = pool[n]
				if not dome_want.has(n) and PaladinDome.in_front_of_shell(center, d.z, float(info[1]), float(info[0]), float(info[2]), float(info[3]),
						-HYSTERESIS if _was_dome.has(n) else HYSTERESIS):
					dome_want[n] = true
			for i in range(mini(char_nodes.size(), chars.size())):
				var cn: Node2D = char_nodes[i]
				var c: Vector4 = chars[i]
				if not front_chars.has(cn) and (cn.is_in_group("player") or cn.is_in_group("remote_players")) \
						and PaladinDome.in_front_of_shell(center, d.z, c.x, c.y, c.z, c.w, -HYSTERESIS if _raised_chars.has(cn) else HYSTERESIS):
					front_chars[cn] = c
		## Kabuğun önüne çıkan oyuncunun önündeki yaratık da kabuğun önündedir (yoksa oyuncu [SHELL_Z + 2] onun üstüne çizilirdi).
		for cn: Node2D in front_chars:
			var c: Vector4 = front_chars[cn]
			for n: Node2D in pool:
				var info: Array = pool[n]
				if not dome_want.has(n) and should_cover(float(info[0]), float(info[3]), float(info[1]) - c.x, c.y, _was_dome.has(n)):
					dome_want[n] = true
		close_over(dome_want, pool)
	_apply_creature_z(want, dome_want)
	_apply_char_z(front_chars)


## pool'a yaratığın [ayak y, x, yarım genişlik, boy] bilgisini ekler (zaten varsa dokunmaz).
func _pool_add(pool: Dictionary, n: Node2D) -> void:
	if pool.has(n):
		return
	var ext: Vector2 = _extent(n)
	pool[n] = [_foot_y(n), n.global_position.x, ext.x, ext.y]


## Yaratık z'si = (kabuğun önündeyse DOME_FRONT_Z) + (oyuncunun önündeyse FRONT_Z); ikisi de değilse eski z'ye döner.
func _apply_creature_z(want: Dictionary, dome_want: Dictionary) -> void:
	for n: Node2D in want.keys() + dome_want.keys():
		if not _raised.has(n):
			_raised[n] = n.z_index
		n.z_index = (DOME_FRONT_Z if dome_want.has(n) else 0) + (FRONT_Z if want.has(n) else 0)
	for n in _raised.keys():
		if want.has(n) or dome_want.has(n):
			continue
		if is_instance_valid(n):
			(n as Node2D).z_index = int(_raised[n])
		_raised.erase(n)
	_was_front = want
	_was_dome = dome_want


## Kabuğun önündeki oyuncu/kukla DOME_FRONT_CHAR_Z'ye çıkar, ayrılınca eski z'ye döner. Duvar geçen (uçan) karakterin z'si forest_canopy.gd'nin:
## ona dokunulmaz; uçmaya başladığında bizim yükselttiğimizse forest_canopy'nin saklayacağı "eski z" bizim sakladığımızla düzeltilir.
func _apply_char_z(front_chars: Dictionary) -> void:
	for cn: Node2D in front_chars:
		if cn.has_meta(ForestCanopyScript.META_BASE_Z):
			continue
		if not _raised_chars.has(cn):
			_raised_chars[cn] = cn.z_index
		cn.z_index = DOME_FRONT_CHAR_Z
	for cn in _raised_chars.keys():
		if not is_instance_valid(cn):
			_raised_chars.erase(cn)
			continue
		var node := cn as Node2D
		if node.has_meta(ForestCanopyScript.META_BASE_Z):
			node.set_meta(ForestCanopyScript.META_BASE_Z, int(_raised_chars[cn]))
			_raised_chars.erase(cn)
		elif not front_chars.has(cn):
			node.z_index = int(_raised_chars[cn])
			_raised_chars.erase(cn)


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
	_was_front.clear()
	_was_dome.clear()
	_apply_char_z({})
