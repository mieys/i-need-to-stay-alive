class_name WeaponJuice
extends RefCounted

## Süzülen silah ikonlarının "canlılık" animasyonları - TEK kaynak: weapon.gd (gerçek silah) VE remote_player.gd (diğer
## oyuncuların kozmetik kopyası) aynı fonksiyonu çağırır (CLAUDE.md madde 3: iki tarafa ayrı formül yazılmaz).
##
## Kullanıcı isteği (2026-09-25): "silah animasyonları fena değil ancak daha eğlenceli olabilirler. bu konuda insiyatifi sana
## bırakıyorum". Eskiden yerel ikon ateşte sadece geri tepiyordu, uzak kopya ise ayrıca düz %15 büyüyordu (iki taraf farklıydı).
## Artık ikisinde de "punch": ikon ateş yönünde ezilir (squash), sonra hafif esneyip taşar (stretch) ve yaylanarak yerine
## oturur - çizgi film "vuruş" hissi. Geri tepme (konum) değişmedi; bu SADECE ölçek.

## Ezilme (ikonun kendi x ekseni = namlu yönü boyunca kısa ve kalın) -> esneme (uzun ve ince) -> taban.
const PUNCH_SQUASH := Vector2(0.8, 1.2)
const PUNCH_STRETCH := Vector2(1.1, 0.93)
const PUNCH_IN := 0.035
const PUNCH_MID := 0.07
const PUNCH_OUT := 0.14


## target'ın ölçeğine punch tween'i kurar ve döndürür. base_scale: ikonun SABİT dinlenme ölçeği (o anki değil - hızlı
## ateşte üst üste binen tween'ler ölçeği büyütmesin; bkz. remote_player.gd _weapon_base_scales notu).
static func fire_punch(tween_owner: Node, target: Node2D, base_scale: Vector2) -> Tween:
	var tw: Tween = tween_owner.create_tween()
	tw.tween_property(target, "scale", base_scale * PUNCH_SQUASH, PUNCH_IN)
	tw.tween_property(target, "scale", base_scale * PUNCH_STRETCH, PUNCH_MID).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(target, "scale", base_scale, PUNCH_OUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


## Menzilli silahların normal atış geri tepmesi (kullanıcı isteği 2026-10-04: "yay, crossbow, tabanca, ateş asası, buz asası, tüfek,
## tüftüf silahları ateşlendiğinde biraz geri tepsin"). Eski tepme düz 10 px'ti (0.04 sn çıkış / 0.16 sn dönüş) ve tek karede gözden
## kayboluyordu: şimdi silah başına biraz daha uzun bir tepme + namlu kalkması (ikon ateş yönünde döner gibi yukarı yükselir) + yaylanarak
## dönüş. Kritik animasyonlar (weapon_crit_anim.gd) bundan HER ZAMAN daha sert kalır (kick 1.6-2.4x, dönüş/ezilme). weapon.gd (_do_recoil)
## ve remote_player.gd (_animate_weapon_fire_full) AYNI fonksiyonu çağırır; tabloda olmayan silah (arcane, bumerang, fişek...) eski yolda kalır.
## kick: recoil_distance'a çarpan; rot: namlu kalkması (radyan, artımlı eklenir - nişan her kare ikonu hedefe çevirdiği için).
const RANGED_RECOIL := {
	"yay": {"kick": 1.4, "rot": 0.10},
	"crossbow": {"kick": 1.4, "rot": 0.14},
	"tabanca": {"kick": 1.4, "rot": 0.26},
	"fire_staff": {"kick": 1.5, "rot": 0.12},
	"buz_asasi": {"kick": 1.4, "rot": 0.10},
	"tufek": {"kick": 1.7, "rot": 0.18},
	"tuftuf": {"kick": 1.5, "rot": 0.0},
}
const RECOIL_OUT := 0.045
const RECOIL_BACK := 0.22
const RECOIL_STRETCH_TIME := 0.1
const RECOIL_SETTLE := 0.1


static func has_ranged_recoil(weapon_key: String) -> bool:
	return RANGED_RECOIL.has(weapon_key)


## icon: ikon düğümü, base_pos: ikonun YEREL dinlenme konumu (yerelde Vector2.ZERO), base_scale: SABİT dinlenme ölçeği, dir: HEDEFE doğru yön
## (tepme bunun tersine), recoil_dist: silahın recoil_distance'ı. Döner: konum+ölçek tween'i (çağıran saklayıp sonraki atışta kesebilir).
static func ranged_recoil(tween_owner: Node, icon: Node2D, weapon_key: String, dir: Vector2, base_pos: Vector2, base_scale: Vector2,
		recoil_dist: float) -> Tween:
	var st: Dictionary = RANGED_RECOIL.get(weapon_key, {})
	var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var kick: Vector2 = -d * recoil_dist * float(st.get("kick", 1.0))
	var tw: Tween = tween_owner.create_tween()
	## 1) ani geri tepme + ezilme
	tw.tween_property(icon, "position", base_pos + kick, RECOIL_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(icon, "scale", base_scale * PUNCH_SQUASH, RECOIL_OUT)
	## 2) yaylanarak yerine dönüş (hafif aşar) + ikon esner
	tw.tween_property(icon, "position", base_pos, RECOIL_BACK).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(icon, "scale", base_scale * PUNCH_STRETCH, RECOIL_STRETCH_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	## 3) ölçek tabana oturur
	tw.tween_property(icon, "scale", base_scale, RECOIL_SETTLE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rot: float = float(st.get("rot", 0.0))
	if rot != 0.0:
		var up_sign: float = -1.0 if d.x >= 0.0 else 1.0 ## namlu ekranda yukarı kalkar (sağa bakan ikonda saat yönünün tersi)
		WeaponCritAnim.rotation_kick(tween_owner, icon, rot * up_sign, RECOIL_BACK, true)
	return tw


## Yıldırım asası aktifken (ışın hedefe kilitli) ikonun hafif titremesi (kullanıcı isteği 2026-10-04). Konum ofseti: TREMOR_HZ'de bir
## sahte-rastgele yeni nokta (dinlenme konumuna eklenir). weapon.gd (_apply_beam_tremor) ve remote_player.gd (_update_beam_tremor) çağırır.
const TREMOR_AMP := 1.6
const TREMOR_HZ := 30.0


static func tremor_offset(time_sec: float) -> Vector2:
	var n: float = floorf(time_sec * TREMOR_HZ)
	return Vector2(sin(n * 12.9898), cos(n * 78.233)) * TREMOR_AMP


## Büyücü Kız pasifi "Büyü Dalgası" (kullanıcı isteği 2026-10-04: "güçlü bir geri tepme olmasını istiyorum hedeflenecek yaratığın zıttına
## doğru") - güçlendirilmiş atışta silah ikonu hedefin TERSİNE sertçe geri tepip (namlu boyunca ezilir) yaylanarak yerine oturur;
## ikon mor parlar ve ucunda mor kıvılcım patlaması çıkar. (İlk sürümde ikon hedefe doğru ileri fırlıyordu - beğenilmedi.)
## weapon.gd (_do_recoil / _surge_visual) ve remote_player.gd ("weapon_fire" "surge" + "weapon_surge" yayını) AYNI fonksiyonları
## çağırır. dir: HEDEFE doğru yön (geri tepme bunun tersine). base_pos: ikonun dinlenme konumu (yerelde Vector2.ZERO).
## Mesafe DÜNYA biriminde verilip ebeveynin ölçeğine bölünür (asalarda silah düğümü çok küçük - yerel birimde verilince ekranda ~2 px
## kalıyordu, 2026-10-04 "pasifin aktifleştiği hiç hissedilmiyor").
const SURGE_KICK_WORLD := 46.0 ## hedefin tersine geri tepme (dünya birimi)
const SURGE_OVERSHOOT_WORLD := 8.0 ## yerine dönerken hedef yönünde hafif aşma
const SURGE_SQUASH := Vector2(0.72, 1.3) ## geri tepmede namlu boyunca ezilir
const SURGE_OUT := 0.045
const SURGE_HOLD := 0.07
const SURGE_BACK := 0.12
const SURGE_SETTLE := 0.32
const SURGE_FLASH := Color(1.9, 1.2, 2.4)
const SURGE_FLASH_TIME := 0.5
const SURGE_SPARK_SCENE := "res://scenes/fx_buyucu_surge_spark.tscn"


## Dünya biriminde bir uzaklığı, ikonun ebeveynindeki (silah düğümü / kukla kökü) yerel birime çevirir.
static func _world_to_local(icon: Node2D, world_len: float) -> float:
	var parent: Node2D = icon.get_parent() as Node2D
	var ps: float = absf(parent.global_scale.x) if parent != null else 1.0
	return world_len / maxf(ps, 0.01)


static func arcane_surge(tween_owner: Node, icon: Node2D, dir: Vector2, base_pos: Vector2, base_scale: Vector2, _recoil_dist: float = 0.0) -> Tween:
	var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var kick: float = _world_to_local(icon, SURGE_KICK_WORLD)
	var over: float = _world_to_local(icon, SURGE_OVERSHOOT_WORLD)
	var tw: Tween = tween_owner.create_tween()
	## 1) ani, sert geri tepme (hedefin tersine) + ezilme
	tw.tween_property(icon, "position", base_pos - d * kick, SURGE_OUT).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(icon, "scale", base_scale * SURGE_SQUASH, SURGE_OUT)
	tw.tween_interval(SURGE_HOLD)
	## 2) geri dönüş: hedef yönünde hafif aşar
	tw.tween_property(icon, "position", base_pos + d * over, SURGE_BACK).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(icon, "scale", base_scale * PUNCH_STRETCH, SURGE_BACK)
	## 3) yaylanarak yerine oturur
	tw.tween_property(icon, "position", base_pos, SURGE_SETTLE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(icon, "scale", base_scale, SURGE_SETTLE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	surge_flash(tween_owner, icon)
	spawn_surge_spark(tween_owner, icon)
	return tw


## Kısa mor-beyaz parlama (self_modulate rgb; alfa - ölüm solması vb. - korunur). Yakın dövüşte tek başına (savuruş zaten ileri atılış).
static func surge_flash(tween_owner: Node, icon: Node2D) -> void:
	var old: Variant = icon.get_meta("surge_flash_tween") if icon.has_meta("surge_flash_tween") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw: Tween = tween_owner.create_tween()
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(icon):
			var c: Color = Color.WHITE.lerp(SURGE_FLASH, k)
			c.a = icon.self_modulate.a
			icon.self_modulate = c
	, 1.0, 0.0, SURGE_FLASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	icon.set_meta("surge_flash_tween", tw)


## İkonun bulunduğu dünya noktasında mor kıvılcım patlaması (tek seferlik sahne; kaster ve uzak kopya aynı fonksiyonu çağırır).
static func spawn_surge_spark(tween_owner: Node, icon: Node2D) -> void:
	if not is_instance_valid(icon) or not icon.is_inside_tree() or not ResourceLoader.exists(SURGE_SPARK_SCENE):
		return
	var scene: Node = (load(SURGE_SPARK_SCENE) as PackedScene).instantiate()
	var tree: SceneTree = tween_owner.get_tree()
	if tree == null or tree.current_scene == null:
		scene.queue_free()
		return
	tree.current_scene.add_child(scene)
	(scene as Node2D).global_position = icon.global_position
