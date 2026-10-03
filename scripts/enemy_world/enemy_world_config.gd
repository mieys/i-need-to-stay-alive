extends RefCounted

## Yaratık yeniden yazımı (bkz. docs/yaratik_yeniden_yazim/PLAN.md). 2026-10-03'ten beri host / tek oyunculuda yaratık
## hareketi + AI TEK yoldan: C++ EnemyWorld (gdextension/enemy_world) + köprü (enemy_world_bridge.gd). Eski GDScript host
## simülasyonu silindi (kullanıcı onayıyla), yani geçiş anahtarı yok: enabled() sadece eklentinin yüklü olup olmadığını
## söyler. Eklenti yoksa (derlemesi olmayan platform) yaratıklar kaydolamaz ve hareket etmez - enemy.gd uyarı basar.


static var _resolved: bool = false
static var _enabled: bool = false


static func enabled() -> bool:
	if not _resolved:
		_resolved = true
		_enabled = ClassDB.class_exists("EnemyWorld")
		if not _enabled:
			push_error("EnemyWorld eklentisi yüklü değil (gdextension/enemy_world bu platform için derlenmemiş?) - yaratıklar hareket etmeyecek")
		print("[Yaratık sistemi] ", "C++ EnemyWorld" if _enabled else "EKLENTİ YOK")
	return _enabled


## İstemci (host olmayan) kuklalarının C++'a kaydı (2026-10-03). Ortam değişkeni ENEMY_WORLD_PUPPET=0 kapatır: istemci eski
## GDScript kukla dalına döner (enemy.gd _physics_process istemci dalı - ölüm animasyonu için zaten duruyor). A/B ölçümü ve
## sorun çıkarsa yedek.
static func puppets_enabled() -> bool:
	return OS.get_environment("ENEMY_WORLD_PUPPET") != "0"


## Testler: anahtarı çalışma anında zorla (yeni doğan yaratıklar için geçerli).
static func set_enabled_for_tests(value: bool) -> void:
	_resolved = true
	_enabled = value and ClassDB.class_exists("EnemyWorld")
