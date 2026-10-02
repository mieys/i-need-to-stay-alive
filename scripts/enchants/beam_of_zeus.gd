extends "res://scripts/enchant_behavior.gd"

## Beam of Zeus (Yıldırım Asası) - bkz. EnchantDefs "beam_of_zeus". Bekleme süresi dolunca (kullanıcı: kendiliğinden) en
## kalabalık yöne sahibini izleyen kalın, delip geçen bir ışın (enchant_area "zeus" + zeus_tile karoları). Asanın normal ince
## ışını aynen devam eder. Final: bekleme 20 sn, ışının değdikleri bitişte patlayıp zincirleme şimşek (zeus_burst).
## Bekleme sayacı silah meta'sında (kart alınınca sıfırlanmasın).

const DIR_SAMPLES := 16
const SHEET_WIDTH := 18.0 ## zeus_tile karosundaki çekirdek kalınlığı (dünya)


func _on_setup() -> void:
	if float(keep_get("zeus_cd_left", -1.0)) < 0.0:
		keep_set("zeus_cd_left", 3.0) ## efsun ilk alındığında ilk ışın kısa süre sonra
	## Beklemeyi kısaltan kart sonradan alınırsa kalan süre yeni tavanı aşmasın.
	keep_set("zeus_cd_left", minf(float(keep_get("zeus_cd_left", 0.0)), _cooldown()))


func _cooldown() -> float:
	if f("zeus_cd_final") > 0.0:
		return f("zeus_cd_final")
	return maxf(5.0, f("zeus_cd", 60.0))


func process_extra(delta: float) -> void:
	var left: float = float(keep_get("zeus_cd_left", 0.0)) - delta
	if left > 0.0:
		keep_set("zeus_cd_left", left)
		return
	var pl: Node2D = owner_player() as Node2D
	if pl == null or not can_act():
		keep_set("zeus_cd_left", 0.0)
		return
	var beam_len: float = f("zeus_len", 320.0)
	var width: float = f("zeus_width", 18.0)
	var dir: Vector2 = _best_dir(pl.global_position, beam_len, width)
	if dir == Vector2.ZERO:
		keep_set("zeus_cd_left", 0.0) ## menzilde düşman yok - hazır bekler
		return
	keep_set("zeus_cd_left", _cooldown())
	area("zeus", pl.global_position, {"follow": true, "dir": dir, "tile_len": beam_len, "width": width, "tick": f("zeus_tick", 0.25),
		"damage": ap() * f("zeus_ap"), "push": f("zeus_push"), "overcharge": flag("overcharge"), "oc_dmg": ap() * 0.8,
		"chain_dmg": ap() * 0.5, "duration": f("zeus_dur", 2.0), "sheet": "zeus_tile",
		"sheet_scale": Vector2(1.0, width / SHEET_WIDTH)})


## En çok düşmanı kesen yön (16 yön örneklenir). Hiç düşman yoksa ZERO.
func _best_dir(origin: Vector2, beam_len: float, width: float) -> Vector2:
	var near: Array = []
	for e in enemies_near(origin, beam_len):
		if VisionFogScript.can_target(e):
			near.append(e)
	if near.is_empty():
		return Vector2.ZERO
	var best: Vector2 = Vector2.ZERO
	var best_n: int = -1
	for i in range(DIR_SAMPLES):
		var d: Vector2 = Vector2.RIGHT.rotated(TAU * float(i) / float(DIR_SAMPLES))
		var b: Vector2 = origin + d * beam_len
		var c: int = 0
		for e in near:
			var ep: Vector2 = e.global_position
			if ep.distance_to(Geometry2D.get_closest_point_to_segment(ep, origin, b)) <= width + 10.0:
				c += 1
		if c > best_n:
			best_n = c
			best = d
	return best
