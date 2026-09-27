extends "res://scripts/fx_animation.gd"

## Yaratık isabet kanı (fx_hit_blood_1/2/3.tscn). fx_animation.gd'nin tek seferlik oynatması + yaratığın rengine boyanma
## (kullanıcı isteği 2026-09-27, bkz. scripts/creature_blood.gd + shaders/blood_tint.gdshader).
## Renk efektin KENDİSİNDE seçilir: bu sahneler silah isabeti, mermi/bumerang çarpması, kanama tiki VE uzak oyuncuların
## "melee_hit" kopyası gibi çok yerden doğuyor - hepsi aynı sahneyi kullandığı için ayrıca kod gerekmez (CLAUDE.md "iki ayrı
## yer" hata sınıfı). Çağıranlar konumu add_child'dan SONRA verdiği için seçim bir sonraki boşta (çizimden önce) yapılır.

const CreatureBlood := preload("res://scripts/creature_blood.gd")
const TintShader: Shader = preload("res://shaders/blood_tint.gdshader")
static var _shared_material: ShaderMaterial = null


func _ready() -> void:
	if _shared_material == null:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = TintShader
	material = _shared_material
	super._ready()
	_pick_color.call_deferred()


func _pick_color() -> void:
	if not is_inside_tree():
		return
	var enemy: Node = CreatureBlood.nearest_enemy(get_tree(), global_position)
	var c: Color = CreatureBlood.color_for(enemy)
	self_modulate = Color(c.r, c.g, c.b, self_modulate.a)
