extends Node

## Kullanıcı bildirimi: "yıldırım asası diğer yaratıklara sıçrarken çıkan
## efektler bozulmuş" - kök neden, weapon.gd _apply_chain_jumps()'ın hasar
## verirken HİÇ görsel efekt (fx_lightning_chain.tscn) oluşturmamasıydı; sahne
## dosyası mevcuttu ama hiçbir yerden çağrılmıyordu. Bu test, silahın artık bu
## efekt sahnesine bir referansı olduğunu ve efektin iki nokta arasında
## (setup_positions) doğru şekilde kurulabildiğini doğrular.
##
## NOT: weapon.gd _apply_chain_jumps() get_tree().get_nodes_in_group() içerdiği
## için (bkz. test_dagger_bleed.gd üstündeki benzer not) bu test ortamında
## instantiate edilen node'lar canlı bir SceneTree'ye girmediğinden tam
## entegrasyon burada test edilemiyor - bunun yerine ilgili parçalar
## (silahın FX referansı + FX'in kendi kurulum mantığı) izole test ediliyor.

const WeaponScene: PackedScene = preload("res://scenes/weapon_lightning.tscn")
const ChainFxScene: PackedScene = preload("res://scenes/fx_lightning_chain.tscn")


func test_weapon_has_chain_fx_scene_reference() -> void:
	var w: Node = WeaponScene.instantiate()
	add_child(w)
	assert(w.FxLightningChainScene != null, "Weapon, chain lightning FX sahnesine bir referans tutmalı")
	assert(w.has_method("_spawn_chain_lightning_fx"), "Weapon, sıçrama FX'i oluşturan bir fonksiyona sahip olmalı")


func test_chain_fx_setup_positions_builds_zigzag_path() -> void:
	var fx = ChainFxScene.instantiate()
	add_child(fx)
	fx.setup_positions(Vector2(0, 0), Vector2(100, 0))
	assert(fx.global_position == Vector2(100, 0), "FX, hedef (to) pozisyonunda durmalı")
	assert(fx._zigzag_points.size() >= 2, "Zikzak elektrik hattı oluşturulmalı")
	assert(fx._particles.size() > 0, "İsabet kıvılcımları oluşturulmalı")


func test_chain_fx_setup_with_nodes_tracks_them() -> void:
	var from_node := Node2D.new()
	from_node.global_position = Vector2(10, 10)
	add_child(from_node)
	var to_node := Node2D.new()
	to_node.global_position = Vector2(200, 10)
	add_child(to_node)

	var fx = ChainFxScene.instantiate()
	add_child(fx)
	fx.setup(from_node, to_node)
	assert(fx.global_position == Vector2(200, 10), "FX, to_node'un konumunda durmalı")
	assert(fx._zigzag_points.size() >= 2, "Zikzak elektrik hattı oluşturulmalı")
