extends SceneTree

func _init():
	var s: GDScript = load("res://scripts/game_manager.gd")
	print("game_manager.gd loaded OK: ", s != null)
	quit()
