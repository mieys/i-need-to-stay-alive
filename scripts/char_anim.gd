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
## "golem_slam"/"golem_jump_": Shaman'ın Elemental Golem formundaki darbe (slam + slam2 aynı kareler) ve sıçrayış klipleri
## (bkz. shaman_golem_math.gd - player.gd'nin golem dalı bunları zaten korur, liste kural gereği tek yerde dursun diye).
## "pickup_": Oakley R Hayat Ağacı'nda yere eğilip tohum ekme (madde 266; 4 kare, 0,4 sn) - bitmeden yürümeye geçmesin.
const ACTION_PREFIXES: Array[String] = ["attack", "spellcast", "shrug_", "hurt_", "eat_", "ghostrise_", "golem_slam", "golem_jump_", "pickup_"]

## Yetenek kullanım klibi: yeni sprite setlerinde "shrug_<yön>", eski (LPC) setlerde "spellcast_<yön>".
## Öncelik sırası bu; karakterde hangisi varsa o oynar. Odaklanarak kanal yapan yeteneklerde (Büyücü meteor,
## Şovalye ulti) klip bitince yeniden başlatılarak döngüde tutulur (bkz. player.gd _process_buyucu_meteor).
const CAST_PREFIXES: Array[String] = ["shrug_", "spellcast_"]

const DIRECTIONS: Array[String] = ["down", "left", "right", "up"]

## MADEN KAZMA (kullanıcı isteği 2026-10-14, bkz. mine_sites.gd + player.gd _process_mining): kazma klibi "strike_<yön>" (4 kare; 0-1 kaldır, 2 DARBE, 3 savrulma).
## Aksiyon klibi DEĞİL (yürümeye geçince hemen kesilir) ve loop=false: yerel oyuncu bitince yeniden başlatır, uzak kukla da aynısını yapar
## (remote_player.gd update_position_and_anim_from_net). Yavaş oynar (MINE_ANIM_SPEED) ki darbe başına ~0,8 sn düşsün.
## ASSASIN ULTİ ATILMA POZU (kullanıcı isteği 2026-10-16: "ulti esnasında sabit durmasın, koşarkenki atılmaya benzer framelerden
## biri olsun gittiği yöne doğru"): "dash_<yön>" = run_<yön> klibinin en geniş adımlı TEK karesi (DASH_POSE_RUN_FRAME). Gölge
## Hücumu sürerken player.gd her sıçrayışta yönü kurup bunu oynatır (aksiyon klibi DEĞİL, tek kare döngü); adı ağdan gider.
## Sıçrayış hayaletleri (fx_assasin_ult_streak.gd) de bu klipten çizilir. 2026-10-17: Talon Q atılışı da aynı pozu oynatır
## (player.gd _talon_dashing). Klip sadece assasin_frames.tres + talha_frames.tres'te (tools/add_dash_pose_clips.py).
const DASH_POSE_PREFIX := "dash_"
const DASH_POSE_RUN_FRAME := 2

const MINE_ANIM_PREFIX := "strike_"
const MINE_ANIM_SPEED := 0.5
const MINE_HIT_FRAME := 2


static func is_mine_anim(anim_name: String) -> bool:
	return anim_name.begins_with(MINE_ANIM_PREFIX)


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


## Bir hareket vektörünün klip yönü (baskın eksen, eşitlikte yatay). player.gd _update_facing'in 1,3 eşikli histerezi YOK -
## tek seferlik sıçrayış/atılma pozları için (Assasin dash_<yön>): yerelde ve uzak kopyada aynı vektörden AYNI yön çıkar.
static func dir_from_vector(v: Vector2) -> String:
	if v.length() < 0.001:
		return "down"
	if absf(v.x) >= absf(v.y):
		return "right" if v.x > 0.0 else "left"
	return "down" if v.y > 0.0 else "up"
