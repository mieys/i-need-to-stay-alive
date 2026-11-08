## SİLAHLAR SIRTTA (madde 451; prototip madde 450, kullanıcı A3'ü seçti): görüşte düşman yokken / çalıda saklıyken silahlar göğse girip
## kaybolmak yerine karakterin sırtında çapraz (X) durur, yay/üçüncü silah belde yatay. Düşman görününce sırttan çıkıp yuvasına uçar,
## düşman gidince sırta döner (WeaponFollowMath.step_visibility / pose ile aynı durum makinesi; pose'a `mount` verilir).
## Sahibi ölü/yerdeyse eski kural: göğse çekilip kaybolur (sırtta görünmez).
##
## İKİ YER (MP): yerel silah weapon.gd _wf_update, kukla remote_player.gd _wf_update_all bu dosyanın AYNI fonksiyonlarını çağırır;
## ağ verisi yok (yön = sahibin AnimatedSprite2D klip adı, durum = her istemcinin kendi görüş taraması).
##
## Çizim: sırttaki görüntü sahibin ÇOCUĞU ayrı bir Sprite2D'dir (silah kökü top_level ve hep karakterin önünde çizilir). Arkadan
## bakışta (yüz yukarı) karakter sprite'ından SONRA, önden/yandan bakışta ÖNCE (gövde örter, yalnız omuz/baş üstünden taşan uçlar görünür).
extends RefCounted

const CharAnimScript := preload("res://scripts/char_anim.gd")

## Slot türü (WeaponFollowMath.slot_kind: 0 tepe, 1 sağ, 2 sol) -> (dünya dx, dünya dy, yukarı ucun açısı derece, göreli ölçek).
## Kanonik = ARKADAN bakış (sırt bize dönük), x ekran sağı. Önden bakışta x ve açı aynalanır; yandan bakışta x sırta sıkışır.
const MOUNTS: Array[Vector4] = [Vector4(3.0, -3.0, -42.0, 0.85), Vector4(-3.0, -3.0, -138.0, 0.85), Vector4(0.0, -0.5, -166.0, 0.80)]
const LOCAL_PER_WORLD := 2.0 ## sahip kökü 0,5 ölçekli: slotlarla aynı yerel birim
const STEP_BOB := 0.55 ## dünya px: yürürken adımda sekme
const STEP_HZ := 8.0 / 3.0 ## yürüme klibi 8 fps, 3 karede bir adım
const MOVING_SPEED := 25.0 ## dünya px/sn (WeaponFollowMath.MOVING_SPEED ile aynı)
const SIDE_SQUEEZE := 0.35 ## yandan bakışta ucun yatay bileşeni
const SIDE_LEAN := 0.30 ## yandan bakışta uçlar sırta doğru yatar
const SIDE_BACK_X := 3.5 ## dünya px: yandan bakışta sırtın yüzün tersindeki kayması
const SPRITE_NAME := &"AnimatedSprite2D"


## Yukarı taşan uçtan silahın UCUNA açı farkı (derece): kılıç/bıçakta kabza yukarı (uç aşağı), yayda üst kol yukarı (ok yönü kollara dik).
static func up_to_tip_deg(key: String) -> float:
	match key:
		"uzunkilic", "dagger":
			return 180.0
		"yay":
			return 90.0
	return 0.0


## Kalkan ve Yin Yang Kitabı dönmez, sırtta da dik durur.
static func is_upright(key: String) -> bool:
	return key == "kalkan" or key == "yinyang"


## Sahibin baktığı yön ("down"/"up"/"left"/"right"): AnimatedSprite2D klip adının son eki (yerel + kukla aynı).
static func face_of(owner: Node) -> String:
	var spr: Node = owner.get_node_or_null(NodePath(SPRITE_NAME)) if owner != null else null
	if spr is AnimatedSprite2D:
		return CharAnimScript.dir_of(str((spr as AnimatedSprite2D).animation))
	return "down"


## Sırttaki poz. Dönen {"pos": sahibe göre yerel (slotlarla aynı birim), "tip": ucun dünya açısı (rad), "scale": göreli ölçek,
## "front": karakterin önünde mi (arkadan bakış), "upright": dönmeyen silah}.
static func pose(kind: int, face: String, owner_vel: Vector2, now: float, key: String) -> Dictionary:
	var m: Vector4 = MOUNTS[clampi(kind, 0, MOUNTS.size() - 1)]
	var dx: float = m.x
	var dy: float = m.y
	var up: float = m.z
	var front: bool = false
	match face:
		"up":
			front = true
		"down":
			dx = -dx
			up = 180.0 - up
		_:
			var back: float = 1.0 if face == "left" else -1.0
			var v := Vector2.from_angle(deg_to_rad(up))
			v.x = v.x * SIDE_SQUEEZE + back * SIDE_LEAN
			up = rad_to_deg(v.angle())
			dx = back * SIDE_BACK_X + dx * 0.25
	if owner_vel.length() >= MOVING_SPEED:
		dy -= STEP_BOB * absf(sin(PI * now * STEP_HZ))
	var upright: bool = is_upright(key)
	return {"pos": Vector2(dx, dy) * LOCAL_PER_WORLD, "tip": deg_to_rad(up + up_to_tip_deg(key)), "scale": m.w,
			"front": front, "upright": upright}


## Sanatın ileri yönü (flip dahil, ikonun kendi dönüşü hariç). fwd_rad = sanatın ileri açısı.
static func flipped_forward(icon: Node2D, fwd_rad: float) -> Vector2:
	var v := Vector2.from_angle(fwd_rad)
	if "flip_h" in icon and bool(icon.get("flip_h")):
		v.x = -v.x
	if "flip_v" in icon and bool(icon.get("flip_v")):
		v.y = -v.y
	return v


## İkonun (flip dahil) ucunun, ikonun EBEVEYNİNE göre açısı.
static func icon_rel_tip(icon: Node2D, fwd_rad: float) -> float:
	return icon.transform.basis_xform(flipped_forward(icon, fwd_rad)).angle()


## Silah kökünün (yerel: kök, kukla: pivot) sırttaki açıya oturması için gereken dönüşü (ikon kendi nişan açısında kalırken).
static func root_rotation(mp: Dictionary, icon: Node2D, fwd_rad: float) -> float:
	if bool(mp.get("upright", false)):
		return -icon.rotation
	return float(mp["tip"]) - icon_rel_tip(icon, fwd_rad)


## Sırt sprite'ı (yoksa kurar). Sahibin çocuğu; silah silinince çağıran free eder.
static func ensure_sprite(owner: Node2D, existing: Sprite2D) -> Sprite2D:
	if existing != null and is_instance_valid(existing):
		return existing
	var s := Sprite2D.new()
	s.name = "WeaponOnBack"
	s.visible = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	owner.add_child(s)
	return s


## Sırt sprite'ını günceller. visible = durum GİZLİ ve sırtta görünmesi gerekiyor. base_scale = ikonun sahibe göre normal ölçeği.
static func place(back: Sprite2D, owner: Node2D, icon: Node2D, mp: Dictionary, base_scale: Vector2, fwd_rad: float, visible: bool) -> void:
	if back == null or not is_instance_valid(back):
		return
	var spr: CanvasItem = owner.get_node_or_null(NodePath(SPRITE_NAME)) as CanvasItem
	if not visible or icon == null or not is_instance_valid(icon) or (spr != null and not spr.visible):
		back.visible = false
		return
	_sync_art(back, icon)
	back.position = mp["pos"] as Vector2
	var art_angle: float = flipped_forward(icon, fwd_rad).angle() ## flip'li sanatın ucu (ikonun dönüşü hariç)
	back.rotation = 0.0 if bool(mp.get("upright", false)) else float(mp["tip"]) - art_angle
	back.scale = base_scale.abs() * float(mp["scale"])
	if spr != null:
		back.modulate = spr.modulate
		var si: int = spr.get_index()
		var bi: int = back.get_index()
		if bool(mp["front"]) and bi < si:
			owner.move_child(back, si) ## sprite'ın hemen arkasına (önünde çizilir)
		elif not bool(mp["front"]) and bi > si:
			owner.move_child(back, si) ## sprite'ın hemen önüne (arkasında çizilir)
	back.visible = true


static func _sync_art(back: Sprite2D, icon: Node2D) -> void:
	if icon is Sprite2D:
		var s := icon as Sprite2D
		if back.texture != s.texture:
			back.texture = s.texture
		if back.hframes != s.hframes or back.vframes != s.vframes:
			back.frame = 0
			back.hframes = s.hframes
			back.vframes = s.vframes
		back.frame = clampi(s.frame, 0, s.hframes * s.vframes - 1)
		back.region_enabled = s.region_enabled
		back.region_rect = s.region_rect
		back.offset = s.offset
		back.centered = s.centered
		back.flip_h = s.flip_h
		back.flip_v = s.flip_v
	elif icon is AnimatedSprite2D:
		var a := icon as AnimatedSprite2D
		if a.sprite_frames != null and a.sprite_frames.has_animation(a.animation) and a.sprite_frames.get_frame_count(a.animation) > 0:
			var tex: Texture2D = a.sprite_frames.get_frame_texture(a.animation, 0) ## yay: ip gergin değil (dinlenme karesi)
			if back.texture != tex:
				back.texture = tex
		if back.hframes != 1 or back.vframes != 1:
			back.frame = 0
			back.hframes = 1
			back.vframes = 1
		back.offset = a.offset
		back.centered = a.centered
		back.flip_h = a.flip_h
		back.flip_v = a.flip_v
	if back.material != icon.material:
		back.material = icon.material
