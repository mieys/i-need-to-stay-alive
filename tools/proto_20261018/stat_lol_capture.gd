extends SceneTree

## Mini stat paneli LoL tarzı prototip yakalaması (2026-10-18): gerçek hud.tscn 1920x1080 SubViewport'ta, sahte oyuncuyla.
## Ortam: CAP_TAG=dosya öneki (prototip turunda STAT_STYLE=A|B|C vardı; B seçildi, stil anahtarı kalktı). Çıktı: out/stat_lol/<tag>_sayfa{1,2}.png (1:1)
## Kullanım: Godot --path . --windowed --resolution 640x360 -s tools/proto_20261018/stat_lol_capture.gd

const OUT := "res://tools/proto_20261018/out/stat_lol/"
const STUB_SRC := """extends Node
class FakeWeapon:
	var damage: float = 86.0
	var crit_chance: float = 0.25
	var crit_damage: float = 1.75
var luck: float = 12.0
var dodge_chance: float = 0.12
var shield_pen_percent: float = 0.15
var weapon_range_bonus: float = 0.2
var shield_protection: float = 0.6
var shield_max_percent: float = 0.3
var item_shield_regen_flat: float = 3.5
var heal_regen_card_bonus: float = 2.0
var item_health_regen: float = 2.5
var _w := FakeWeapon.new()
func get_primary_weapon(): return _w
func get_attack_speed_bonus_percent() -> float: return 45.0
func get_cooldown_reduction() -> float: return 0.2
func get_total_lifesteal() -> float: return 0.06
func get_base_move_speed() -> float: return 96.0
func get_heal_shield_power() -> float: return 0.25
"""


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(vp: SubViewport, crop: Rect2i, file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().get_region(crop).save_png(ProjectSettings.globalize_path(OUT + file))


func _run() -> void:
	await process_frame
	var tag: String = OS.get_environment("CAP_TAG")
	if tag == "":
		tag = "stat_son"
	var gm: Node = root.get_node("GameManager")
	gm.set("selected_char_id", 0)
	gm.set("selected_spiritual", "can")
	gm.set("selected_pet", "peri")
	gm.set("owned_items", [{"key": "ruzgar_eldiveni"}, {"key": "anka_kusunun_kalbi"}, {"key": "ilidaricin_kilici"}])
	gm.set("shield_standart_level", 1)
	var stub_script := GDScript.new()
	stub_script.source_code = STUB_SRC
	stub_script.reload()
	var stub := Node.new()
	stub.set_script(stub_script)
	root.add_child(stub)
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#4f7a3a")
	bg.size = Vector2(1920, 1080)
	vp.add_child(bg)
	var hud: Node = (load("res://scenes/hud.tscn") as PackedScene).instantiate()
	vp.add_child(hud)
	await _wait(0.5)
	hud.call("update_health", 1284.0, 2150.0)
	hud.call("_on_item_shield_changed", 356.0, 900.0)
	hud.call("update_level", 12)
	hud.get_node("ReviveHearts").call("set_revives", 2)
	stub.add_to_group("player")
	var panel: Control = hud.get_node("DockStats") as Control
	var toggle: Control = hud.get_node("DockStatsToggle") as Control
	toggle.call("set_open", true)
	await _wait(0.4)
	var pr: Rect2 = panel.get_global_rect()
	var dock: Rect2 = (hud.get_node("DockFrame") as Control).get_global_rect()
	var crop := Rect2i(int(pr.position.x) - 10, int(pr.position.y) - 10, 0, 0)
	crop.size = Vector2i(int(dock.position.x) + 130 - crop.position.x, 1080 - crop.position.y)
	print("PANEL ", pr, " DOCK ", dock)
	await _shot(vp, crop, tag + "_sayfa1.png")
	panel.call("set_page", 1)
	await _shot(vp, crop, tag + "_sayfa2.png")
	quit()
