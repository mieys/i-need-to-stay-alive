extends "res://scripts/enchant_behavior.gd"

## Endless Void (Arcane Asası) - bkz. EnchantDefs "endless_void". Her isabet 1 boşluk yükü; eşikte son vurulan düşmanın
## yerinde karadelik (enchant_area "black_hole" + void_hole sayfası): çeker, saniyede hasar; Final'de bitişte %250 patlama
## (void_collapse sayfası). Yük sayacı silah meta'sında (keep_*) - kart alınıp davranış yeniden kurulunca sıfırlanmasın.


func hit_extra(t: Node, _dmg: float, is_primary: bool, _proj: Node2D) -> void:
	if not is_primary or not is_enemy(t):
		return
	var stacks: int = int(keep_get("void_stacks", 0)) + 1
	if stacks < maxi(1, n("void_stacks", 20)):
		keep_set("void_stacks", stacks)
		return
	keep_set("void_stacks", 0)
	var r: float = f("void_radius", 80.0)
	var params: Dictionary = {"radius": r, "dps": ap() * f("void_dps"), "duration": f("void_dur", 3.0), "pull": f("void_pull", 1.0),
		"sheet": "void_hole", "sheet_scale": r / (66.0 * 1.212)}
	if f("void_collapse") > 0.0:
		params["blast"] = ap() * f("void_collapse")
		params["blast_sheet"] = "void_collapse"
	area("black_hole", (t as Node2D).global_position, params)
