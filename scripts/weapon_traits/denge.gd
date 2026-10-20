extends "res://scripts/enchant_behavior.gd"

## Denge (Yin Yang Kitabı, kalıcı özellik, madde 334) - bkz. WeaponTraits "denge". Kitabın kendi kuralı (isabet başına %10 SG kalkan, menzilsiz
## en boş oyuncuya) ve isabet çözümü scripts/yinyang_book.gd'de; bu script: atışta alıcıyı seçer (mermiye + ağa), Kara Mühür, FİNAL Tai Chi Mührü.
## Temel Yin/Yang sayıları (yin_ap, yang_th, yang_mult, ys_shield) YinYangBook.resolve_hit stats'tan okur.

const YinYang := preload("res://scripts/yinyang_book.gd")
## Mühür sayfası EnchantArea'da SpriteFx.frames() ile load() edilir: burada preload -> ilk mühürde diskten okuma takılması yok (önbellekten gelir).
const SEAL_FRAMES: SpriteFrames = preload("res://assets/fx/enchant/taichi_seal_frames.tres")

var _hits: int = 0
var _seals: Array = [] ## [konum, bitiş zamanı (sn, _clock), sonraki kalkan tiki]
var _clock: float = 0.0


## Atış: hedef + kalkan alıcısı mermiye; uzak kopya hedefi "home_id" ile bulur (projectile_look home_net_id'den yazar).
func projectile_extra(proj: Node2D, target: Node2D, _is_extra: bool) -> void:
	if proj == null or not proj.has_method("yy_setup"):
		return
	proj.call("yy_setup", target, YinYang.pick_recipient(owner_player()))
	if is_instance_valid(target):
		proj.set_meta("home_net_id", int(target.get_meta("network_enemy_id", 0)))


## Ağ: alıcının kimliği uzak kopyaya (EnchantFx.apply_projectile_look "props"); kutsal element renk tonu mermiyi boyamasın.
func look_extra(proj: Node2D, d: Dictionary) -> Dictionary:
	d.erase("tint")
	if proj != null and "yy_rcp_peer" in proj:
		var props: Dictionary = (d.get("props", {}) as Dictionary).duplicate()
		props["yy_rcp_peer"] = int(proj.get("yy_rcp_peer"))
		d["props"] = props
	return d


## Kara kürenin gerçek isabetinden (YinYangBook.resolve_hit, kalkan / Yin hasarından SONRA).
func on_yinyang_hit(body: Node) -> void:
	if f("km_pct") > 0.0:
		el(body, "weaken", {"pct": f("km_pct"), "dur": f("km_dur", 2.0)}) ## Kara Mühür: boss dahil daha az hasar verir
	_hits += 1
	if n("tc_every") > 0 and _hits % n("tc_every") == 0 and is_instance_valid(body) and body is Node2D:
		_seal((body as Node2D).global_position)


## FİNAL Tai Chi Mührü: hedefin altında dönen yer mührü. Hasar = "field" alanı (yetkili kopya, tik 0,5 sn, diğer oyunculara yayınlanır);
## saniyelik kalkan burada (en boş oyuncuya, kimse alamıyorsa mühürdeki düşmanlara Yin hasarı).
func _seal(pos: Vector2) -> void:
	var dur: float = f("tc_dur", 3.0)
	area("field", pos, {"radius": f("tc_r", 90.0), "duration": dur, "tick": 0.5, "damage": ap() * f("tc_ap", 0.35) * 0.5,
		"sheet": "taichi_seal", "sheet_scale": 0.5, "color": Color(1.0, 0.95, 0.82)})
	_seals.append([pos, _clock + dur, _clock + 1.0])


func process_extra(delta: float) -> void:
	_clock += delta
	if _seals.is_empty():
		return
	for s in _seals.duplicate():
		if _clock >= float(s[1]):
			_seals.erase(s)
			continue
		if _clock < float(s[2]):
			continue
		s[2] = float(s[2]) + 1.0
		var pl: Node = owner_player()
		var rcp: Node2D = YinYang.pick_recipient(pl)
		if rcp != null:
			YinYang.give_shield(pl, rcp, ap() * f("tc_shield", 0.05))
		else:
			for e in enemies_near(s[0] as Vector2, f("tc_r", 90.0)):
				hit(e, ap() * f("tc_yin", 0.1))
