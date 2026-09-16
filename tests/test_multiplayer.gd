extends Node

func test_network_manager_exists() -> void:
	assert(NetworkManager != null, "NetworkManager autoload should exist")
	assert(NetworkManager.has_method("create_room"), "NetworkManager should have create_room")
	assert(NetworkManager.has_method("join_room"), "NetworkManager should have join_room")
	assert(NetworkManager.has_method("disconnect_from_room"), "NetworkManager should have disconnect_from_room")


func test_lobby_scene_loads() -> void:
	var lobby_scene = load("res://scenes/lobby_menu.tscn")
	assert(lobby_scene != null, "Lobby scene should load successfully")
	var instance = lobby_scene.instantiate()
	assert(instance != null, "Lobby scene should instantiate")
	instance.free()


func test_remote_player_scene_loads() -> void:
	var rp_scene = load("res://scenes/remote_player.tscn")
	assert(rp_scene != null, "Remote player scene should load successfully")
	var instance = rp_scene.instantiate()
	assert(instance != null, "Remote player scene should instantiate")
	assert(instance.is_in_group("player"), "Remote player should be in 'player' group")
	assert(instance.is_in_group("player_ally"), "Remote player should be in 'player_ally' group")
	instance.free()
