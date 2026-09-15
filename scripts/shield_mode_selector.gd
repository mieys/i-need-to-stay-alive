extends HBoxContainer

## Bigger icon-button selector next to the shield bar: one button per shield
## mode the player has bought (leveled up at least once) from the shop's
## "Modlar" category, each showing the same tinted shield icon used in the
## shop row. Only owned modes are visible; pressing a mode activates it,
## pressing the already active one turns it back off
## (GameManager.active_shield_mode = "").

const MODES := ["resilience", "thorny", "turtle", "aggressive", "lightning", "piercing", "tank"]

@onready var buttons: Dictionary = {
	"resilience": $ResilienceButton,
	"thorny": $ThornyButton,
	"turtle": $TurtleButton,
	"aggressive": $AggressiveButton,
	"lightning": $LightningButton,
	"piercing": $PiercingButton,
	"tank": $TankButton,
}

var player: Node = null


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	for mode in MODES:
		buttons[mode].pressed.connect(_on_button_pressed.bind(mode))
	_refresh()


func _on_button_pressed(mode: String) -> void:
	if not player or not is_instance_valid(player):
		return
	var new_mode: String = "" if GameManager.active_shield_mode == mode else mode
	if player.has_method("set_active_shield_mode"):
		player.set_active_shield_mode(new_mode)
	_refresh()


## Cheap polling refresh (same pattern the shop panel already uses) so newly
## bought modes show up here without extra signal plumbing.
func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	var any_owned: bool = false
	for mode in MODES:
		var owned: bool = GameManager.get("shield_mod_" + mode + "_level") > 0
		var btn: Button = buttons[mode]
		btn.visible = owned
		btn.button_pressed = owned and GameManager.active_shield_mode == mode
		any_owned = any_owned or owned
	visible = any_owned
