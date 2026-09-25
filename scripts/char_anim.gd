extends RefCounted

## Karakter animasyon klip adları için PAYLAŞILAN yardımcılar. player.gd (yerel oyuncu) VE remote_player.gd
## (diğer istemcilerdeki kukla) AYNI klip adı kurallarını kullanmak zorunda - CLAUDE.md'deki "kaster kendi
## ekranında doğru görür, diğerlerinde eski/hiç animasyon kalır" hata sınıfı tam olarak bu ikisinin
## birbirinden sapmasından çıkıyor, bu yüzden kurallar (ön ekler) TEK yerde.
##
## Klip adları "<ön ek>_<yön>" (yön: down/left/right/up). Klip adı ağdan olduğu gibi gider (bkz. main.gd
## _rpc_update_player_transform cur_anim), yani yeni bir klip player.gd'de oynatılınca uzak istemcide de
## KENDİLİĞİNDEN oynar - yeter ki karakterin SpriteFrames'inde o ad olsun (remote_player.gd has_animation
## kontrolü yoksa sessizce hiçbir şey yapmaz).

## Bitene kadar yürüme/bekleme animasyonunun ÜSTÜNE yazamadığı "aksiyon" klipleri (bkz. player.gd
## _update_animation): saldırı, yetenek (cast), hasar (hurt), yemek (eat). Hepsi tek seferlik (loop=false).
## "ghostrise_": Suriyeli Hadime'nin hayalet kalkışı (ölüm klibinin tersi, bkz. hadime_math.gd) - bitmeden bekleme/yürüme
## klibine geçerse kalkış yarıda kesilirdi.
const ACTION_PREFIXES: Array[String] = ["attack", "spellcast", "shrug_", "hurt_", "eat_", "ghostrise_"]

## Yetenek kullanım klibi: yeni sprite setlerinde "shrug_<yön>", eski (LPC) setlerde "spellcast_<yön>".
## Öncelik sırası bu; karakterde hangisi varsa o oynar. Odaklanarak kanal yapan yeteneklerde (Büyücü meteor,
## Şovalye ulti) klip bitince yeniden başlatılarak döngüde tutulur (bkz. player.gd _process_buyucu_meteor).
const CAST_PREFIXES: Array[String] = ["shrug_", "spellcast_"]

const DIRECTIONS: Array[String] = ["down", "left", "right", "up"]


static func is_action_anim(anim_name: String) -> bool:
	for p in ACTION_PREFIXES:
		if anim_name.begins_with(p):
			return true
	return false


static func is_cast_anim(anim_name: String) -> bool:
	for p in CAST_PREFIXES:
		if anim_name.begins_with(p):
			return true
	return false


## Yetenek klibi adayları (öncelik sırasıyla) - pick() ile birlikte kullanılır.
static func cast_candidates(facing: String) -> Array[String]:
	var out: Array[String] = []
	for p in CAST_PREFIXES:
		out.append(p + facing)
	return out


## Adaylardan SpriteFrames'te GERÇEKTEN var olan ilkini döner, hiçbiri yoksa "".
static func pick(frames: SpriteFrames, candidates: Array) -> String:
	if frames == null:
		return ""
	for c in candidates:
		if frames.has_animation(c):
			return c
	return ""


## "walk_left" -> "left" (tanınmayan/yönsüz adlarda "down").
static func dir_of(anim_name: String) -> String:
	for d in DIRECTIONS:
		if anim_name.ends_with("_" + d):
			return d
	return "down"
