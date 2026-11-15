extends RefCounted

## KORUMALI TAM SAYI (Cheat Engine karşı önlemi, kullanıcı isteği 2026-11-12). Altın / silah parçacığı gibi "değeri bellekte aranıp
## değiştirilen" sayılar için: değer HER yazışta yeni rastgele anahtarla XOR'lanıp saklanır (bellekte gerçek sayı yok, taramayla bulunamaz),
## yanında bir sağlama toplamı var. Dışarıdan biri `_enc`/`_key`yi bozarsa sağlama tutmaz -> `SecurityGuard.report` + değer 0'a düşer
## (hileli koşu kayıt yazmaz, bkz. security_guard.gd). Düz bir kopya SAKLANMAZ (o kopya da bulunup bozulabilirdi).
## DÜRÜST SINIR: ileri düzey araçlar (kodu yamayan) bunu aşar; ucuz değer-tarama/dondurma hilelerini keser. Okuma/yazma birkaç tamsayı işlemi.

const Guard := preload("res://scripts/security/security_guard.gd")

static var _rng: RandomNumberGenerator = _make_rng() ## oyunun küresel RNG'sine DOKUNMAZ (testler/tohumlu akış bozulmasın)

var tag: String = ""
var _enc: int = 0
var _key: int = 0
var _chk: int = 0


static func _make_rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r


func _init(tag_name: String = "", initial: int = 0) -> void:
	tag = tag_name
	set_value(initial)


static func _checksum(enc: int, key: int) -> int:
	return ((enc * 40503) ^ (key * 65599) ^ 0x5bd1e995) + ((enc >> 7) ^ (key << 3))


func set_value(v: int) -> void:
	_key = _rng.randi() | (_rng.randi() << 32)
	_enc = v ^ _key
	_chk = _checksum(_enc, _key)


func get_value() -> int:
	if _chk != _checksum(_enc, _key):
		Guard.report("korumalı değer bozuldu: %s" % tag)
		set_value(0)
		return 0
	return _enc ^ _key


func add(delta: int) -> int:
	var v: int = get_value() + delta
	set_value(v)
	return v
