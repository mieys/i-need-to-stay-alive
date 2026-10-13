extends SceneTree

## Demirci iç mekanının yürünebilir hücre haritasını ASCII yazar ('.' yürünür, '#' çarpışma, ' ' zemin dışı, 'A' örs işaretçisi, 'D' kapı).
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var shop := Node2D.new()
	shop.set_script(load("res://scripts/weapon_shop.gd"))
	root.add_child(shop)
	await process_frame
	var smith: Node2D = shop.get_smith()
	var walk: Dictionary = smith._walkable
	var anvil: Vector2i = smith.cell_of(smith._anvil_local)
	var door: Vector2i = smith.cell_of(smith._door_local)
	var header := "      "
	for x in range(-11, 12):
		header += "%3d" % x
	print(header)
	for y in range(-8, 5):
		var row := "%4d  " % y
		for x in range(-11, 12):
			var c := Vector2i(x, y)
			var ch := " . " if walk.has(c) else (" # " if shop._collision_cells.has(c) else "   ")
			if c == anvil:
				ch = " A "
			elif shop._door_cells.has(c):
				ch = " D "
			row += ch
		print(row)
	quit()
