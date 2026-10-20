extends Node

## Şovalye R kubbesi (Koruma Baloncuğu) içindeki herkesin silahları kubbenin TEPESİNDEKİ dairede toplanır. İlk istek (2026-10-14):
## "oyuncular şovalye adamın kalkan bariyerinin içine girince silahlar bariyerin üstünde dışında toplanacak. herkesin silahı orada
## sırayla dizilip ateş edecek. silahlar artık dışardan ateşleneceği için sesleri de dışardaki sesler gibi boğuk gelecek" -> önce
## kubbenin zemin elipsinin dış kenarına dizilmişti; 2026-10-17: "silahların kenarlara değil kubbenin üstünde daire şeklinde
## toplanmalarını istiyorum eşit olacak biçimde" -> TAÇ: kubbe tepesinin üstünde, silah sayısına göre büyüyen EKRAN dairesi.
## 2026-10-19 (kullanıcı: "müttefiklerin silahları eskisi gibi kalkanın kenarlarında görünsün üstünde görünmek yerine"): görünür konum yine
## KENAR halkası (rim_point = aim_point); arka yarıdaki silah kabuğun arkasında çizilir (rim_in_front). Aşağıdaki "taç" notları tarihçe.
##
## NASIL: her fizik karesinde (her istemcide AYRI, ağdan veri gitmez - kubbe durumu `paladin_zone_active` zaten herkese gidiyor)
## kubbeler (yerel Şovalye + uzak kuklalar) bulunur, içindeki oyuncular (yerel + kuklalar) kubbeye atanır; kubbedeki TÜM silahlar
## oyuncu no'suna (peer id), sonra silah sırasına göre dizilip taç dairesine eşit aralıkla (tepeden, saat yönünde) yerleştirilir.
## Yerel silahlara weapon.gd set_rim_target, kuklalara remote_player.gd set_dome_rim_targets konum verir (ikisi de yumuşak geçer).
## Taç kubbe tepesinin üstünde = zemin elipsinin çok dışında: dome_sound_muffle.gd'nin boğuk-ses halkasında kalır; halka silahlarının
## kendi sesleri ayrıca audio_buses.gd route_rim_sound ile boğuk + yankılı yoldan çalar.
## HEDEF ARAMA taçtan değil `aim_point`ten (eski kenar halkası, silah başına bir nokta): taç kubbenin ~1,3 yarıçap yukarısında,
## oradan ölçülen 168'lik menzil kubbenin güneyine yetişmezdi - menzil/hedef kuralı eskisiyle AYNI kaldı (denge değişmesin),
## mermi/savuruş taçtaki silahtan çıkar.
##
## Uzak kuklaların kubbe üyeliği kukla konumlarından (ağ interpolasyonu) çıkar, ekrandan ekrana birkaç px oynayabilir:
## kenarda titremesin diye girme/çıkma eşikleri farklı (ENTER_MARGIN/LEAVE_MARGIN). Hasarı atış yapanın KENDİ silah konumu
## belirler (kendi ekranında); diğer ekranlarda sadece görünüm.

## HEDEF ARAMA halkası (aim_point): kubbe elipsinin RIM_GAP dışında, RIM_LIFT yukarıda (madde 154/160'taki eski görünür halka).
const RIM_GAP := 12.0
const RIM_LIFT := 6.0
## TAÇ (görünür konum, 2026-10-17): kürenin silueti merkezin `radius` kadar yukarısına çıkar (madde 160 TUZAK) = kubbe tepesi.
## Dairenin en alt noktası tepenin CROWN_GAP üstünde; yarıçap komşu iki silah arası yay CROWN_SPACING olacak kadar (ikonlar ~24 px),
## en az CROWN_MIN_RADIUS. Tek silah dairenin ortasında durur.
const CROWN_GAP := 2.0
const CROWN_SPACING := 28.0
const CROWN_MIN_RADIUS := 26.0
const PaladinDome := preload("res://scripts/paladin_dome.gd")
const ENTER_MARGIN := 6.0 ## kubbeye girmiş sayılmak için yarıçaptan bu kadar içeride olmalı
const LEAVE_MARGIN := 14.0 ## çıkmış sayılmak için yarıçaptan bu kadar dışarıda olmalı

## üye node'un instance id'si -> atandığı kubbenin sahibinin instance id'si (kenarda gidip gelmesin diye eşik)
var _assigned: Dictionary = {}
## KUBBE GİRDABI (2026-10-15, talon_formation_math.gd DOME_SPIN_*): kubbenin üyelerinden bir Talon Silah Salvosu'ndaysa (E) halkadaki
## HERKESİN silahı halkayla döner, dışa bakar ve baktığı yöne ateş eder (yarı avantaj + -%40 hasar). Her istemci açıyı KENDİSİ ilerletir
## (Talon'un uzak dizilimi gibi, ağdan açı gitmez - faz istemciler arasında biraz kayabilir, hasarı herkesin KENDİ silahı verir).
## kubbe sahibinin instance id'si -> dönüş açısı
var _spin_angle: Dictionary = {}
## Bu karede halka konumu almış üyeler (kubbeden çıkınca/engellenince temizlenir)
var _rimmed: Array = []


static func _slot_angle(index: int, count: int, angle_offset: float) -> float:
	return -PI * 0.5 + TAU * float(index) / float(maxi(count, 1)) + angle_offset


## Taç dairesinin yarıçapı (`count` silah, eşit aralık).
static func crown_radius(count: int) -> float:
	return maxf(CROWN_MIN_RADIUS, float(count) * CROWN_SPACING / TAU)


## Taç dairesinin merkezi (dünya): kubbe tepesinin (center.y - radius) üstünde, alt noktası CROWN_GAP yukarıda.
static func crown_center(center: Vector2, radius: float, count: int) -> Vector2:
	return center + Vector2(0.0, -(radius + CROWN_GAP + crown_radius(count)))


## Silahın GÖRÜNÜR konumu. 2026-10-19 (kullanıcı: "şovalye adamın R sine giren müttefiklerin silahları eskisi gibi kalkanın kenarlarında görünsün
## üstünde görünmek yerine"): taçtan (crown_*, madde 218) eski KENAR halkasına dönüldü = aim_point (zemin elipsi + RIM_GAP, RIM_LIFT yukarıda;
## tepeden saat yönünde eşit açılı). Arka yarıdaki silah kubbenin arkasında çizilir (rim_in_front). crown_* yardımcıları geri dönmek için duruyor.
## radius = kubbe yarıçapı (paladin_zone_radius). angle_offset: kubbe girdabında halkanın dönüş açısı.
static func rim_point(center: Vector2, radius: float, index: int, count: int, angle_offset: float = 0.0) -> Vector2:
	return aim_point(center, radius, index, count, angle_offset)


## Halka noktası kubbenin ÖN yarısında mı (merkezin güneyi): önde = ön kabuğun üstünde (z 21), arkada = kabuğun altında (z 19).
static func rim_in_front(center: Vector2, pos: Vector2) -> bool:
	return pos.y >= center.y - RIM_LIFT


## Silahın HEDEF ARAMA merkezi (bkz. dosya başı): eski kenar halkasındaki `index`. nokta - elipsin yarıçapları + RIM_GAP, RIM_LIFT yukarıda.
static func aim_point(center: Vector2, radius: float, index: int, count: int, angle_offset: float = 0.0) -> Vector2:
	var a: float = _slot_angle(index, count, angle_offset)
	var r: Vector2 = PaladinDome.radii(radius) + Vector2(RIM_GAP, RIM_GAP)
	return center + Vector2(cos(a) * r.x, sin(a) * r.y - RIM_LIFT)


## Halka noktasının elipsten DIŞA bakan açısı (girdapta silah bu yöne bakıp ateş eder): elips normali (ry cos a, rx sin a).
static func rim_outward_angle(radius: float, index: int, count: int, angle_offset: float = 0.0) -> float:
	var a: float = _slot_angle(index, count, angle_offset)
	var r: Vector2 = PaladinDome.radii(radius) + Vector2(RIM_GAP, RIM_GAP)
	return wrapf(Vector2(r.y * cos(a), r.x * sin(a)).angle(), -PI, PI)


func _physics_process(delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var domes: Array = _find_domes(tree)
	var members: Array = _find_members(tree) if not domes.is_empty() else []
	var new_rimmed: Array = []
	var spinning_ids: Dictionary = {}
	var local_spinner: Node = null
	if not domes.is_empty():
		_assign_members(domes, members)
		for dome: Dictionary in domes:
			var list: Array = dome["members"]
			if list.is_empty():
				continue
			list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["pid"]) < int(b["pid"]))
			var total: int = 0
			var spinner: Node = null
			for m: Dictionary in list:
				total += (m["weapons"] as Array).size()
				var mn: Node = m["node"]
				if spinner == null and mn.has_method("is_talon_salvo") and bool(mn.call("is_talon_salvo")):
					spinner = mn
			var oid: int = (dome["owner"] as Object).get_instance_id()
			var spin: Dictionary = {}
			if spinner != null:
				spinning_ids[oid] = true
				if not spinner.is_in_group("remote_players"):
					local_spinner = spinner
				var spin_mult: float = TalonFormationMath.DOME_SPIN_SPEED_MULT 						* (TalonFormationMath.EVO_SALVO_SPIN_MULT if bool(spinner.call("has_evo", "talon_e2")) else 1.0)
				_spin_angle[oid] = TalonFormationMath.advance_salvo_angle(float(_spin_angle.get(oid, 0.0)), delta, spin_mult)
				spin = {"angle": _spin_angle[oid], "penalty": TalonFormationMath.SALVO_DAMAGE_PENALTY,
					"fire_mult": TalonFormationMath.salvo_fire_mult(bool(spinner.call("has_evo", "talon_e1")), TalonFormationMath.DOME_SPIN_ADVANTAGE)}
			var offset: float = float(spin.get("angle", 0.0))
			var idx: int = 0
			for m: Dictionary in list:
				var positions: Array = []
				var aims: Array = []
				var angles: Array = []
				var fronts: Array = []
				for _w in (m["weapons"] as Array):
					positions.append(rim_point(dome["center"], dome["radius"], idx, total, offset))
					fronts.append(rim_in_front(dome["center"], positions[positions.size() - 1]))
					aims.append(aim_point(dome["center"], dome["radius"], idx, total, offset))
					angles.append(rim_outward_angle(dome["radius"], idx, total, offset) if not spin.is_empty() else null)
					idx += 1
				## -%40 hasar cezası sadece girdabı döndüren Talon'un KENDİ silahlarına; halkadaki diğer oyuncularınkine işlemez.
				var member_spin: Dictionary = spin
				if not spin.is_empty() and m["node"] != spinner:
					member_spin = spin.duplicate()
					member_spin["penalty"] = 0.0
				_apply(m, positions, angles, member_spin, aims, fronts)
				new_rimmed.append(m["node"])
	for oid in _spin_angle.keys():
		if not spinning_ids.has(oid):
			_spin_angle.erase(oid)
	## Yerel Talon'a: halkayı o mu döndürüyor (player.gd talon_dome_spin - kendi çemberini kurmaz, avantajlar yarı).
	var local := tree.get_first_node_in_group("player")
	if local != null and is_instance_valid(local) and "talon_dome_spin" in local:
		var spinning_here: bool = local_spinner == local
		if bool(local.get("talon_dome_spin")) != spinning_here and bool(local.call("is_talon_salvo")):
			local.set("talon_dome_spin", spinning_here)
	## Bu karede halkada olmayan eski üyeler eski yerlerine döner.
	for n in _rimmed:
		if is_instance_valid(n) and not new_rimmed.has(n):
			_apply({"node": n, "remote": not n.is_in_group("player"), "weapons": []}, null)
	_rimmed = new_rimmed
	if domes.is_empty():
		_assigned.clear()


func _find_domes(tree: SceneTree) -> Array:
	var out: Array = []
	var local := tree.get_first_node_in_group("player") as Node2D
	if local != null and is_instance_valid(local) and local.get("paladin_zone_active") == true and local.get("is_dead") != true:
		out.append({"owner": local, "center": local.global_position, "radius": float(local.get("paladin_zone_radius")), "members": []})
	for n in tree.get_nodes_in_group("remote_players"):
		var rp := n as Node2D
		if rp != null and is_instance_valid(rp) and rp.get("paladin_zone_active") == true and rp.get("is_dead") != true:
			out.append({"owner": rp, "center": rp.global_position, "radius": float(rp.get("paladin_zone_radius")), "members": []})
	return out


## Halkaya silah yollayabilecek oyuncular: canlı, silahı olan, başka bir sistemin (Talon formasyonu, Vampir çekilmesi) silah
## konumunu yönetmediği oyuncular. "weapons" = silah node'ları (yerel) / ikon node'ları (kukla), sırayla.
func _find_members(tree: SceneTree) -> Array:
	var out: Array = []
	var local := tree.get_first_node_in_group("player") as Node2D
	if local != null and is_instance_valid(local) and not bool(local.call("dome_rim_blocked")):
		var ws: Array = []
		for w in local.get("owned_weapon_nodes"):
			if is_instance_valid(w) and w.has_method("set_rim_target") and w.get("icon_sprite") != null:
				ws.append(w)
		if not ws.is_empty():
			var my_pid: int = 1
			if NetworkManager.is_multiplayer_active:
				my_pid = tree.get_multiplayer().get_unique_id()
			out.append({"node": local, "pid": my_pid, "remote": false, "weapons": ws})
	for n in tree.get_nodes_in_group("remote_players"):
		var rp := n as Node2D
		if rp == null or not is_instance_valid(rp) or bool(rp.call("dome_rim_blocked")):
			continue
		var icons: Array = []
		for ic in rp.get("_weapon_icons"):
			icons.append(ic) ## geçersiz olsa da yerini korur: konumlar ikon sırasıyla eşleşir (remote_player.gd _update_dome_rim)
		if not icons.is_empty():
			out.append({"node": rp, "pid": int(rp.get("peer_id")), "remote": true, "weapons": icons})
	return out


## Her üyeyi kubbelerden birine atar (öncelik: önceki kubbesi hâlâ çıkış eşiği içindeyse o; yoksa girme eşiği içindeki en yakını).
func _assign_members(domes: Array, members: Array) -> void:
	var seen: Dictionary = {}
	for m: Dictionary in members:
		var node := m["node"] as Node2D
		var key: int = node.get_instance_id()
		seen[key] = true
		var chosen: Dictionary = {}
		var prev_owner_id: int = int(_assigned.get(key, 0))
		if prev_owner_id != 0:
			for dome: Dictionary in domes:
				if (dome["owner"] as Object).get_instance_id() == prev_owner_id \
						and PaladinDome.contains(dome["center"], float(dome["radius"]), node.global_position, LEAVE_MARGIN):
					chosen = dome
					break
		if chosen.is_empty():
			var best: float = INF
			for dome: Dictionary in domes:
				var d: float = node.global_position.distance_to(dome["center"])
				if PaladinDome.contains(dome["center"], float(dome["radius"]), node.global_position, -ENTER_MARGIN) and d < best:
					best = d
					chosen = dome
		if chosen.is_empty():
			_assigned.erase(key)
			continue
		_assigned[key] = (chosen["owner"] as Object).get_instance_id()
		(chosen["members"] as Array).append(m)
	for k in _assigned.keys():
		if not seen.has(k):
			_assigned.erase(k)


## angles/spin: kubbe girdabında ikon başına dışa bakış açısı + {"fire_mult", "penalty"} (boşsa girdap yok). aims: ikon başına hedef arama merkezi.
## fronts: ikon başına halka noktası kubbenin ön yarısında mı (rim_in_front - çizim katmanı).
func _apply(member: Dictionary, positions: Variant, angles: Array = [], spin: Dictionary = {}, aims: Array = [], fronts: Array = []) -> void:
	var node: Node = member["node"]
	if not is_instance_valid(node):
		return
	if bool(member["remote"]):
		node.call("set_dome_rim_targets", positions if positions != null else [], angles if not spin.is_empty() else [], aims if positions != null else [],
				fronts if positions != null else [])
		return
	var ws: Array = member["weapons"]
	if positions == null:
		## Temizlik: hâlâ geçerli TÜM yerel silahlar (kubbeden çıkarken listede olmayanlar da dahil).
		for w in node.get("owned_weapon_nodes"):
			if is_instance_valid(w) and w.has_method("set_rim_target"):
				w.set_rim_target(null)
		return
	for i in range(ws.size()):
		if is_instance_valid(ws[i]):
			ws[i].set_rim_target(positions[i], aims[i] if i < aims.size() else null, bool(fronts[i]) if i < fronts.size() else true)
			if spin.is_empty():
				ws[i].set_rim_spin(null)
			else:
				ws[i].set_rim_spin(angles[i], float(spin["fire_mult"]), float(spin["penalty"]))
