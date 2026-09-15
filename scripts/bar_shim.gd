extends Control
var max_value: float = 100.0 : set = set_mv
var value: float = 100.0 : set = set_v
func set_mv(v): max_value = v; if has_node("Prog"): $Prog.max_value = v
func set_v(v): value = v; if has_node("Prog"): $Prog.value = v
