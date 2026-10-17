extends RefCounted

## Şovalye R (Koruma Baloncuğu) - İZOMETRİK kubbe: alan şekli + Şovalye'nin havada süzülüşü TEK yerde (2026-10-14, madde 160).
## Kullanıcı: izometrik kubbe "C - Işık Perdesi"; önce "koruma alanı ELİPS, bugünkü daireyle AYNI ALAN" (yatay 178) seçildi, oyunda
## görünce "bu çok büyük olmuş prototipte gösterdiğin gibi değil baya küçülmesi gerekiyor" -> PROTOTİP boyutu: `paladin_zone_radius`
## (player.gd PALADIN_ULTI_ZONE_RADIUS 126) = elipsin YATAY yarıçapı, dikey yarıçap r/2 (2:1). Alan eski dairenin YARISI.
## Görsel kubbe (tools/gen_paladin_iso_dome_fx.py) bu elipsin üstünde duran yarıçapı r olan yarım küre.
## C++ karşılığı: gdextension/enemy_world/src/enemy_world.cpp zone_r_along (yaratıklar elipsin kenarında durur/itilir).
## class_name YOK (headless'ta global sınıf önbelleği güncellenmiyor) - kullanan preload eder.

const X_MULT := 1.0
const Y_MULT := 0.5
## Şovalye'nin R klibi (tools/gen_paladin_iso_dome_fx.py: shrug'ın kollar açık karesi, mavi parlayan 6 kare nabız). Klip ADI ağdan
## gider (main.gd cur_anim) - uzak kopya klibi oynatır, süzülme/titremeyi de adından türetir (yeni ağ alanı yok).
const ANIM_PREFIX := "bariyer_"
## Hadime Q'daki gibi havaya süzülme (karakter sanat pikseli, tam sayı -> piksel ızgarası bozulmaz) + titreme. Kullanıcı (2026-10-14):
## "biraz daha yüksekte dursun ve hafif yukarı aşağı insin uçuyormuş gibi" -> 10 px yukarıda, ~2 sn'lik yavaş ±3 px iniş-çıkış.
const LIFT_ART_PX := 10.0
const LIFT_BOB_ART_PX := 3.0
const LIFT_BOB_SPEED := 3.0
const TREMBLE_HZ := 18.0 ## titreme adımı (saniyede)
## Titreme deseni (x, y) sanat pikseli - düzensiz görünsün diye karışık sıra, toplamı 0 (kaymaz).
const TREMBLE := [Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1),
	Vector2(-1, 0), Vector2(1, 0), Vector2(0, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(0, 0)]
## Kubbenin ÖN kabuğunun (fx_paladin_barrier.gd kökü) mutlak z'si: içerideki/arkadaki her şeyin üstünde. Kubbenin ÖNÜNDEKİ yaratık/oyuncu
## bunun üstüne çıkarılır (creature_depth.gd, in_front_of_shell) - yoksa kabuğun altında, camın içindeymiş gibi görünürdü.
const SHELL_Z := 20


## Aktif Şovalye kubbeleri (yerel oyuncu + uzak kuklalar; ölü sahibinki sayılmaz): Vector3(merkez x, merkez y, yarıçap).
static func active_domes(tree: SceneTree) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if tree == null:
		return out
	for n in tree.get_nodes_in_group("player") + tree.get_nodes_in_group("remote_players"):
		if n is Node2D and is_instance_valid(n) and n.get("paladin_zone_active") == true and n.get("is_dead") != true:
			var p: Vector2 = (n as Node2D).global_position
			out.append(Vector3(p.x, p.y, float(n.get("paladin_zone_radius"))))
	return out


## Saf kural (testler için): ayağı (x, foot_y)'de, gövdesi (half_w yarım genişlik, height boy) olan varlık kubbenin ÖN kabuğunun ÖNÜNDE mi
## (kabuğun üstüne çizilmeli mi). Kabuk = elipsin üstündeki yarım kürenin görünen ön yüzü: siluet yatayda ±r, aşağıda elipsin ön yarısında biter.
## Önde = elipsin DIŞINDA ve merkezin GÜNEYİNDE (aşağısında) + kabukla örtüşüyor. Elipsin içindeki camın içinde (kabuğun altında), kuzeydeki
## kubbenin arkasında kalır. margin: titreme koruması (+ = girmek için daha net dışarıda/aşağıda olmalı, - = zaten öndeyse biraz geri tolerans).
static func in_front_of_shell(center: Vector2, r: float, x: float, foot_y: float, half_w: float, height: float, margin: float = 0.0) -> bool:
	if foot_y <= center.y + margin:
		return false
	if contains(center, r, Vector2(x, foot_y), margin):
		return false
	if foot_y - height >= center.y + radii(r).y:
		return false ## görselin tamamı kubbenin en alt noktasından aşağıda: kabukla örtüşmüyor
	return absf(x - center.x) <= r * X_MULT + half_w


## Eşdeğer yarıçap r -> elipsin yarıçapları (x yatay, y dikey).
static func radii(r: float) -> Vector2:
	return Vector2(r * X_MULT, r * Y_MULT)


## Merkezden `dir` (birim olmayabilir) yönünde elipsin kenarına uzaklık.
static func radius_along(r: float, dir: Vector2) -> float:
	var l: float = dir.length()
	if l < 0.0001:
		return r
	var u: Vector2 = dir / l
	var d: float = u.x * u.x / (X_MULT * X_MULT) + u.y * u.y / (Y_MULT * Y_MULT)
	return r / sqrt(d) if d > 0.000001 else r


## `pos` elipsin içinde mi (margin: kenara eklenen pay, eksi = daha içeride).
static func contains(center: Vector2, r: float, pos: Vector2, margin: float = 0.0) -> bool:
	var d: Vector2 = pos - center
	return d.length() <= radius_along(r, d) + margin


## `node` aktif bir Şovalye baloncuğunun sahibiyse `pos` onun alanında mı (yerel oyuncu + uzak kukla; ölü sahibin baloncuğu sayılmaz).
static func node_contains(node: Node, pos: Vector2, margin: float = 0.0) -> bool:
	if node == null or not is_instance_valid(node) or not (node is Node2D):
		return false
	if node.get("paladin_zone_active") != true:
		return false
	return contains((node as Node2D).global_position, float(node.get("paladin_zone_radius")), pos, margin)


## `pos` aktif (sahibi canlı) bir Şovalye kubbesinin içinde mi - yerel oyuncu + uzak kuklalar; içindeyse kubbenin sahibi, değilse null.
static func owner_containing(tree: SceneTree, pos: Vector2) -> Node2D:
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("player") + tree.get_nodes_in_group("remote_players"):
		if n.get("is_dead") != true and node_contains(n, pos):
			return n as Node2D
	return null


## Elipsin kenarında `angle` (dünya açısı, merkezden bakış) yönündeki nokta - merkeze göre.
static func edge_offset(r: float, angle: float) -> Vector2:
	var dir: Vector2 = Vector2.from_angle(angle)
	return dir * radius_along(r, dir)


static func is_anim(anim_name: String) -> bool:
	return anim_name.begins_with(ANIM_PREFIX)


## Süzülme + titreme: anim.offset'e EKLENECEK değer (sanat pikseli, yukarı = eksi y). t = kubbe açıldığından beri geçen süre.
static func levitate_offset(t: float) -> Vector2:
	var lift: float = LIFT_ART_PX + roundf(sin(t * LIFT_BOB_SPEED) * LIFT_BOB_ART_PX)
	var tremble: Vector2 = TREMBLE[int(floor(t * TREMBLE_HZ)) % TREMBLE.size()]
	return Vector2(tremble.x, -lift + tremble.y)
