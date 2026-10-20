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
##
## FPS (2026-10-18): 200 yaratıkta bu güncelleme çağrı başına 2-5 ms'ydi (2 karede bir -> kare başına 1-2,5 ms). Davranış AYNI, maliyet düştü:
##  - aday başına dinamik çağrılar (get("is_dead"), has_method + call, 5 meta okuma, 4 elemanlı Array tahsisi) yerine tipli erişim (Enemy) + düğüm başına
##    önbellek (DepthInfo: ayak görseli, ayağın görsel yereli, yarım genişlik, boy - main.gd _creature_foot_y / _extent'in yazdığı AYNI değerler),
##  - havuz paralel PackedFloat64Array'lerde (tahsis yok),
##  - close_over: yükseltilenler ayak sırasında eklendiği için ikili aramayla SADECE "ayak - boy < a.ayak < ayak - 0,5" bandındakiler taranır (eskiden hepsi).
##
## C++ (2026-10-19, madde 286): kayıtlı yaratıkların taraması (ayak, should_cover, kapanış) EnemyWorld.depth_scan'e taşındı (aday başına ~7 us GDScript -> ~0,1 us).
## Kural BİREBİR aynı (yukarıdaki should_cover / _close_core; ikisi de testler ve kubbeli yol için burada duruyor). C++ yolu: kayıtlı yaratıklar C++'ta taranır,
## kayıtsızlar (görev kopyaları) burada ölçülüp havuza verilir; düğüm başına ölçü kaydı (DepthInfo) eksik slotlar için GDScript doldurur (depth_pending / depth_set).
## Şovalye kubbesi AKTİFKEN eski GDScript yolu çalışır (kubbe kuralı havuzu karakter + kubbe adaylarıyla birlikte kullanıyor; nadir). ENEMY_CPP_DEPTH=0 ortam
## değişkeni her zaman eski yolu açar (süreç düzeyi A/B hakemi: tools/fps_micro/proc_ab.ps1).

const DepthScript := preload("res://scripts/depth_occluders.gd")
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const PaladinDome := preload("res://scripts/paladin_dome.gd")
const ForestCanopyScript := preload("res://scripts/forest_canopy.gd")
const EnemyWorldBridgeScript := preload("res://scripts/enemy_world/enemy_world_bridge.gd")

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
## Düğüm başına önbellek tablosu bu kadar çağrıda bir süpürülür (silinmiş yaratıkların kayıtları atılır).
const CACHE_SWEEP_EVERY := 300

static var _cpp_on: bool = OS.get_environment("ENEMY_CPP_DEPTH") != "0"

var _raised: Dictionary = {} ## yaratık düğümü -> yükselmeden önceki z_index
var _was_front: Dictionary = {} ## son güncellemede oyuncunun önünde yükselen yaratıklar (histerezis)
var _was_dome: Dictionary = {} ## son güncellemede kubbe kabuğunun önünde yükselen yaratıklar (histerezis)
var _raised_chars: Dictionary = {} ## kabuğun önüne çıkarılan oyuncu/kukla -> önceki z_index

## Düğüm başına ölçü önbelleği: instance_id -> DepthInfo. Bu değerler zaten düğüm başına BİR KEZ ölçülüp meta'ya yazılıyordu
## (main.gd _creature_foot_y: _foot_visual/_foot_local, _extent: _depth_extent) - burada sadece okuması hızlandırıldı.
class DepthInfo:
	var vis: Node2D ## ayağı ölçülen görsel (Sprite2D / AnimatedSprite2D)
	var foot_local: float ## ayağın görselin YEREL koordinatındaki y'si (ölçekten önce)
	var half_w: float
	var height: float

var _info: Dictionary = {}
var _calls: int = 0

## Havuz (güncelleme boyunca; çağrılar arasında yeniden kullanılır): paralel diziler + düğüm -> indeks.
var _p_nodes: Array = []
var _p_foot := PackedFloat64Array()
var _p_x := PackedFloat64Array()
var _p_hw := PackedFloat64Array()
var _p_h := PackedFloat64Array()
var _p_idx: Dictionary = {}


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
	var nodes: Array = pool.keys()
	var foot := PackedFloat64Array()
	var xs := PackedFloat64Array()
	var hws := PackedFloat64Array()
	var hs := PackedFloat64Array()
	for n in nodes:
		var info: Array = pool[n]
		foot.append(float(info[0]))
		xs.append(float(info[1]))
		hws.append(float(info[2]))
		hs.append(float(info[3]))
	return _close_core(want, nodes, foot, xs, hws, hs)


## close_over'ın çekirdeği (paralel dizilerle). Kural (eski çift döngüyle birebir): düğümler (ayak, sıra) artan sırada gezilir; yükseltilmemiş bir düğüm, daha önce
## yükseltilenlerden (a) biri için  a.ayak < ayak - 0,5  VE  |a.x - x| < a.yarım_gen + yarım_gen  VE  ayak - boy < a.ayak  ise yükseltilir ve o da listeye girer.
## Yükseltilenler artan ayakla eklendiğinden a.ayak ∈ (ayak - boy, ayak - 0,5) penceresi ikili aramayla bulunur; eskiden her düğüm TÜM yükseltilenlerle karşılaştırılıyordu.
static func _close_core(want: Dictionary, nodes: Array, foot: PackedFloat64Array, xs: PackedFloat64Array, hws: PackedFloat64Array, hs: PackedFloat64Array) -> int:
	var n_all: int = nodes.size()
	if want.is_empty() or n_all <= want.size():
		return 0
	var keys: Array = [] ## Vector2(ayak y, sıra) - Array.sort() yerleşik karşılaştırmayla sıralar
	keys.resize(n_all)
	for i in range(n_all):
		keys[i] = Vector2(foot[i], float(i))
	keys.sort()
	var r_foot := PackedFloat64Array() ## yükseltilmişler, artan ayak sırasında
	var r_x := PackedFloat64Array()
	var r_hw := PackedFloat64Array()
	var added: int = 0
	for k: Vector2 in keys:
		var i: int = int(k.y)
		var f: float = foot[i]
		var node: Variant = nodes[i]
		if want.has(node):
			r_foot.append(f)
			r_x.append(xs[i])
			r_hw.append(hws[i])
			continue
		var hi: float = f - 0.5
		var j: int = r_foot.bsearch(f - hs[i], false) ## ilk r_foot > ayak - boy
		var rn: int = r_foot.size()
		var joined: bool = false
		while j < rn and r_foot[j] < hi:
			if absf(r_x[j] - xs[i]) < r_hw[j] + hws[i]:
				joined = true
				break
			j += 1
		if joined:
			want[node] = true
			r_foot.append(f)
			r_x.append(xs[i])
			r_hw.append(hws[i])
			added += 1
	return added


func update_now() -> void:
	var tree := get_tree()
	var ew: Object = EnemyWorldBridgeScript.fog_world(tree) if _cpp_on else null
	if ew != null:
		if PaladinDome.active_domes(tree).is_empty():
			_update_cpp(tree, ew)
			return
		_update_legacy(tree)
		var ids := PackedInt64Array() ## C++ titreme belleği: son yükseltilenler (bu güncellemede C++ çalışmadı)
		for n in _was_front:
			ids.append((n as Node2D).get_instance_id())
		ew.call("depth_seed", ids)
		return
	_update_legacy(tree)


## C++ yolu (bkz. dosya başı). Kayıtlı yaratıklar C++'ta; kayıtsız adaylar (görev kopyaları, nadiren boş değil) burada.
func _update_cpp(tree: SceneTree, ew: Object) -> void:
	_calls += 1
	if _calls % CACHE_SWEEP_EVERY == 0:
		_sweep_info()
	var chars: Array[Vector4] = DepthScript.collect_characters(tree)
	var cxy := PackedFloat64Array()
	for c in chars:
		cxy.append(c.x)
		cxy.append(c.y)
	var ex_nodes: Array = []
	var ex_data := PackedFloat64Array()
	var ex_want := PackedByteArray()
	var copies: Array[Node] = tree.get_nodes_in_group("mission_copies")
	if not copies.is_empty() and not chars.is_empty():
		_collect_extras(copies, chars, ex_nodes, ex_data, ex_want)
	var params := PackedFloat64Array([SCAN_RADIUS, CLOSURE_PAD, ABOVE_SKIP, HYSTERESIS, DepthScript.BODY_HALF_WIDTH, EnemyQueryScript.MOVE_SLACK])
	var res: Array = ew.call("depth_scan", cxy, ex_nodes, ex_data, ex_want, params, false)
	var need: Array = ew.call("depth_pending")
	if not need.is_empty():
		for e in need: ## ölçü kaydı eksik slotlar: eski _info_of (main.gd _creature_foot_y + _extent) ile bir kez ölçülüp C++'a verilir
			var n := e as Enemy
			if n == null:
				continue
			var rec: DepthInfo = _info_of(n)
			ew.call("depth_set", n._ew_slot, rec.vis, rec.foot_local, rec.half_w, rec.height, _info.has(n.get_instance_id()))
		res = ew.call("depth_scan", cxy, ex_nodes, ex_data, ex_want, params, true)
	var want: Dictionary = {}
	for n in res:
		want[n] = true
	_apply_creature_z(want, {})
	_apply_char_z({})


## Kayıtsız adaylar (EnemyQuery.candidates'in görev kopyaları kolu): eski update_now süzgeçleriyle AYNI; havuza girenler + ilk yükseltme kararı C++'a verilir.
func _collect_extras(copies: Array[Node], chars: Array[Vector4], ex_nodes: Array, ex_data: PackedFloat64Array, ex_want: PackedByteArray) -> void:
	var reach: float = SCAN_RADIUS + CLOSURE_PAD
	var r2: float = (reach + EnemyQueryScript.MOVE_SLACK) * (reach + EnemyQueryScript.MOVE_SLACK)
	var index: Dictionary = {}
	var foots := PackedFloat64Array()
	var heights := PackedFloat64Array()
	for c in chars:
		var cpos := Vector2(c.x, c.y)
		for e in copies:
			if not is_instance_valid(e) or not e.is_in_group("enemies") or e.get("is_dead") == true 					or cpos.distance_squared_to((e as Node2D).global_position) > r2:
				continue
			var n := e as Node2D
			if n == null or not n.visible:
				continue
			var en := e as Enemy
			if (en.is_dead if en != null else n.get("is_dead") == true):
				continue
			var gp: Vector2 = n.global_position
			var adx: float = absf(gp.x - c.x)
			var ady: float = absf(gp.y - c.y)
			if adx > reach or ady > reach or gp.y < c.y - ABOVE_SKIP:
				continue
			var pi: int = index.get(n, -1)
			if pi < 0:
				var info: DepthInfo = _info_of(n)
				pi = ex_nodes.size()
				index[n] = pi
				ex_nodes.append(n)
				var foot: float = gp.y if info.vis == null else info.vis.global_position.y + info.foot_local * absf(info.vis.global_scale.y)
				ex_data.append(gp.x)
				ex_data.append(foot)
				ex_data.append(info.half_w)
				ex_data.append(info.height)
				ex_want.append(0)
				foots.append(foot)
				heights.append(info.height)
			if adx <= SCAN_RADIUS and ady <= SCAN_RADIUS and ex_want[pi] == 0:
				if should_cover(foots[pi], heights[pi], gp.x - c.x, c.y, _was_front.has(n)):
					ex_want[pi] = 1


## Eski (tam GDScript) yol: kubbe aktifken ve ENEMY_CPP_DEPTH=0 / C++ dünyası yokken.
func _update_legacy(tree: SceneTree) -> void:
	var want: Dictionary = {}
	_pool_clear()
	_calls += 1
	if _calls % CACHE_SWEEP_EVERY == 0:
		_sweep_info()
	var char_nodes: Array[Node2D] = DepthScript.character_nodes(tree)
	var chars: Array[Vector4] = DepthScript.collect_characters(tree)
	var reach: float = SCAN_RADIUS + CLOSURE_PAD
	for c in chars:
		for e in EnemyQueryScript.candidates(tree, Vector2(c.x, c.y), reach):
			if not is_instance_valid(e):
				continue
			var n := e as Node2D
			if n == null or not n.visible:
				continue
			var en := e as Enemy
			if (en.is_dead if en != null else n.get("is_dead") == true):
				continue
			var gp: Vector2 = n.global_position
			var adx: float = absf(gp.x - c.x)
			var ady: float = absf(gp.y - c.y)
			if adx > reach or ady > reach or gp.y < c.y - ABOVE_SKIP:
				continue
			var pi: int = _pool_index(n, gp)
			if adx <= SCAN_RADIUS and ady <= SCAN_RADIUS and not want.has(n):
				if should_cover(_p_foot[pi], _p_h[pi], gp.x - c.x, c.y, _was_front.has(n)):
					want[n] = true
	_close_core(want, _p_nodes, _p_foot, _p_x, _p_hw, _p_h)
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
				var pi: int = _pool_index(n, n.global_position)
				if not dome_want.has(n) and PaladinDome.in_front_of_shell(center, d.z, _p_x[pi], _p_foot[pi], _p_hw[pi], _p_h[pi],
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
			for pi in range(_p_nodes.size()):
				var n: Node2D = _p_nodes[pi]
				if not dome_want.has(n) and should_cover(_p_foot[pi], _p_h[pi], _p_x[pi] - c.x, c.y, _was_dome.has(n)):
					dome_want[n] = true
		_close_core(dome_want, _p_nodes, _p_foot, _p_x, _p_hw, _p_h)
	_apply_creature_z(want, dome_want)
	_apply_char_z(front_chars)
	_pool_clear() ## düğüm referansları çağrılar arasında tutulmasın


func _pool_clear() -> void:
	_p_nodes.clear()
	_p_idx.clear()
	_p_foot.clear()
	_p_x.clear()
	_p_hw.clear()
	_p_h.clear()


## Havuzda düğümün indeksi (yoksa [ayak y, x, yarım genişlik, boy] ile ekler). x: dünya x'i (gp), çağıranın okuduğu konum.
func _pool_index(n: Node2D, gp: Vector2) -> int:
	var idx: int = _p_idx.get(n, -1)
	if idx >= 0:
		return idx
	var info: DepthInfo = _info_of(n)
	idx = _p_nodes.size()
	_p_idx[n] = idx
	_p_nodes.append(n)
	if info.vis == null:
		_p_foot.append(gp.y) ## ayak görseli yok: kök noktası (main.gd _creature_foot_y ile aynı)
	else:
		_p_foot.append(info.vis.global_position.y + info.foot_local * absf(info.vis.global_scale.y))
	_p_hw.append(info.half_w)
	_p_h.append(info.height)
	_p_x.append(gp.x)
	return idx


## Yaratığın ölçü kaydı. İlk karşılaşmada main.gd _creature_foot_y + _extent çalışır (meta'ları yazarlar), sonuç okunup saklanır. Ayak görseli
## ya da gerçek ölçü yoksa (görsel bulunamadı / doku henüz yok) kayıt SAKLANMAZ ve eski yol gibi her güncellemede yeniden denenir (vis null = kök noktası).
func _info_of(n: Node2D) -> DepthInfo:
	var id: int = n.get_instance_id()
	var cached: DepthInfo = _info.get(id)
	if cached != null and is_instance_valid(cached.vis):
		return cached
	_foot_y(n) ## meta'ları doldurur (_foot_visual / _foot_local)
	var ext: Vector2 = _extent(n)
	var rec := DepthInfo.new()
	rec.half_w = ext.x
	rec.height = ext.y
	var vis_v: Variant = n.get_meta("_foot_visual") if n.has_meta("_foot_visual") else null
	if is_instance_valid(vis_v) and n.has_meta("_foot_local"):
		rec.vis = vis_v
		rec.foot_local = float(n.get_meta("_foot_local"))
		if n.has_meta("_depth_extent"): ## ölçü gerçekten ölçüldüyse (yedek değer değilse) sakla
			_info[id] = rec
	return rec


func _sweep_info() -> void:
	for id in _info.keys():
		var rec: DepthInfo = _info[id]
		if not is_instance_valid(rec.vis):
			_info.erase(id)


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
	_info.clear()
	_pool_clear()
	_apply_char_z({})
