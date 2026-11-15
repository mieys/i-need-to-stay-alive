extends "res://scripts/creature_shot.gd"

## ÜÇ KARDEŞ mermileri (kardes_boss.gd _shot; dünya efekti "kardes_shot"). Uçuş / isabet / kubbe / Talon çemberi / kalkan baloncuğu kuralları
## creature_shot.gd'den AYNEN gelir; burada yalnız görünüm (craftpix sprite'ları) ve bitiş patlaması değişir.
## data.style: "arrow" (Ok Kardeş), "fireball" (Büyü: vurduğu yerde patlama + çevresine alan hasarı data.splash), "ice" (Büyü: buz oku, yavaşlatır).
## data.kind: oyuncuya giden hasar türü (player.gd take_special_damage: "fireball" yanma, "kardes_frost" yavaşlatma, "kardes_arrow" düz).

const SheetFx := preload("res://scripts/kardes_sheet_fx.gd")
const TEX_ARROW := preload("res://assets/enemies/kardesler/fx_arrow.png")
const TEX_FIREBALL := preload("res://assets/enemies/kardesler/fx_fireball.png")
const TEX_FIRE_BOOM := preload("res://assets/enemies/kardesler/fx_fireball_boom.png")
const TEX_ICE := preload("res://assets/enemies/kardesler/fx_ice_arrow.png")
const TEX_ICE_BOOM := preload("res://assets/enemies/kardesler/fx_ice_boom.png")
const SPLASH_RADIUS := 56.0

var _vis: String = "arrow"


func _ready() -> void:
	super()
	_vis = str(data.get("style", "arrow"))
	_style = str(data.get("kind", "kardes_arrow")) ## creature_shot isabette _style'ı hasar türü olarak geçer
	match _vis:
		"fireball":
			_sprite.texture = TEX_FIREBALL
			_sprite.hframes = 7
			_sprite.scale = Vector2.ONE * SheetFx.ART
		"ice":
			_sprite.texture = TEX_ICE
			_sprite.scale = Vector2.ONE * SheetFx.ART
		_:
			_sprite.texture = TEX_ARROW
			_sprite.scale = Vector2.ONE * SheetFx.ART ## okçunun kendi saldırı klibindeki okla aynı piksel yoğunluğu


func _process(_delta: float) -> void:
	if _sprite and _sprite.hframes > 1 and _poof < 0.0:
		_sprite.frame = int(_life * 14.0) % _sprite.hframes


func _break() -> void:
	if _poof >= 0.0:
		return
	var at: Vector2 = global_position
	var ang: float = _dir.angle()
	super()
	var parent: Node = get_parent()
	match _vis:
		"fireball":
			SheetFx.play(parent, at, TEX_FIRE_BOOM, 6, 16.0, 1.0, ang)
			var splash: float = float(data.get("splash", 0.0))
			if authoritative and splash > 0.0 and is_inside_tree():
				for p in AbilitiesScript.damageable_players(get_tree()):
					if (p as Node2D).global_position.distance_to(at) <= SPLASH_RADIUS + AbilitiesScript.TARGET_BODY_RADIUS:
						AbilitiesScript.deal_special_damage(p, splash, source, "fireball")
		"ice":
			SheetFx.play(parent, at, TEX_ICE_BOOM, 5, 16.0, 1.0, ang)


func _draw() -> void:
	if _vis == "arrow":
		super()
