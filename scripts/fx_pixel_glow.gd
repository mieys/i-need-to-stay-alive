extends RefCounted

## HAFİF PARILTI malzemesi - TEK kaynak (2026-11-16, madde 723/739). Ateş Asası alevinin halesi (madde 642, flame_bend.gdshader) düz sprite
## için shaders/fx_pixel_glow.gdshader'da; bu dosya onu takan paylaşılan ShaderMaterial'ları verir (aynı ayar = aynı malzeme -> sprite'lar
## toplu çizilir). Gece ışığından (night_glow) ayrı: gündüz de görünür.
## Kullananlar: matthew_lightning.gd glow_material (Matthew şimşek efektleri), fx_arcane_blast.gd (Büyücü Arcane Patlama, toplamalı).

const SHADER := preload("res://shaders/fx_pixel_glow.gdshader")
const GLOW := 0.55 ## Ateş Asası alevindeki değer (madde 642); 0 = eski çiğ görünüm
const CORE := 0.22
const BREATH := 5.0

static var _mats: Dictionary = {}


## cell_px: sayfanın tek karesinin boyu (doku pikseli) - komşu kare haleye sızmasın. additive: sprite toplamalı çiziliyorsa (eski
## blend_add malzemesinin yerine; shaders/toplamali.gdshader ile aynı sonuç + hale).
static func material(cell_px: Vector2, additive: bool = false) -> ShaderMaterial:
	if GLOW <= 0.0:
		return null
	var key: String = "%s|%s" % [cell_px, additive]
	if _mats.has(key):
		return _mats[key]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("glow", GLOW)
	mat.set_shader_parameter("glow_core", CORE)
	mat.set_shader_parameter("breath_speed", BREATH)
	mat.set_shader_parameter("cell_px", cell_px)
	mat.set_shader_parameter("additive", additive)
	_mats[key] = mat
	return mat
