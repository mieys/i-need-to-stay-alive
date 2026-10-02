extends RefCounted

## Silah ikonunun (Sprite2D) ÇİZİLİ UCU - hem yerel weapon.gd ikonunda hem uzak kuklanın ikon kopyasında
## (remote_player.gd _weapon_icons) AYNI hesap, böylece uçtan çıkan efekt iki ekranda da asanın ucuna oturur.
## Kullanıcı bildirimi (2026-09-30): "ejder nefesi efsunundaki ateş ve buz püskürtme efekti silahı takip etmiyor, konumu
## yanlış" - püskürtme silah kökünden (asanın ORTASI) dünyaya sabit bırakılıyordu. Uç, dokudaki opak piksellerin ikonun
## ileri ekseni (sprite_forward_angle_deg) boyunca EN UZAK olanı; doku başına bir kez ölçülüp önbelleğe alınır.

const PULL_BACK_PX := 6.0 ## ucun en dış pikselinden biraz içeri (asanın küresinin/ağzının ortası)

static var _cache: Dictionary = {}


## İkonun yerel (doku) uzayında ucu - centered/offset/flip hesaba katılmış, ikonun kendi transform'u UYGULANMAMIŞ.
static func tip_in_icon(icon: Sprite2D, forward_deg: float) -> Vector2:
	if icon == null or icon.texture == null:
		return Vector2.ZERO
	var tex: Texture2D = icon.texture
	var key: String = "%s|%d|%.2f" % [tex.resource_path, tex.get_instance_id() if tex.resource_path.is_empty() else 0, forward_deg]
	if not _cache.has(key):
		_cache[key] = _measure_tip(tex, forward_deg)
	var p: Vector2 = _cache[key]
	if not icon.centered:
		p += tex.get_size() * 0.5
	p += icon.offset
	if icon.flip_h:
		p.x = -p.x
	if icon.flip_v:
		p.y = -p.y
	return p


## Uç, ikonun ebeveyninin uzayında.
static func tip_in_parent(icon: Sprite2D, forward_deg: float) -> Vector2:
	return icon.transform * tip_in_icon(icon, forward_deg)


## Uç, dünya uzayında (efsun hasar konisinin kökü gibi hesaplar için).
static func tip_global(icon: Sprite2D, forward_deg: float) -> Vector2:
	return icon.global_transform * tip_in_icon(icon, forward_deg)


static func _measure_tip(tex: Texture2D, forward_deg: float) -> Vector2:
	var img: Image = tex.get_image()
	if img == null:
		return Vector2.ZERO
	if img.is_compressed():
		img.decompress()
	var fwd: Vector2 = Vector2.from_angle(deg_to_rad(forward_deg))
	var half: Vector2 = Vector2(img.get_width(), img.get_height()) * 0.5
	var pts: Array[Vector2] = []
	var best_d: float = -INF
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a < 0.5:
				continue
			var p: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5) - half
			pts.append(p)
			best_d = maxf(best_d, p.dot(fwd))
	if pts.is_empty():
		return Vector2.ZERO
	## Ucun ön yüzündeki piksellerin ortası (asa ekseni doku merkezinden geçmese de doğru yer), biraz içeri çekilmiş.
	var sum: Vector2 = Vector2.ZERO
	var cnt: int = 0
	for p in pts:
		if p.dot(fwd) >= best_d - 3.0:
			sum += p
			cnt += 1
	return sum / float(cnt) - fwd * PULL_BACK_PX
