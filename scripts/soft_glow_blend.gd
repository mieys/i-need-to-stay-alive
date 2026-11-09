extends RefCounted

## YUMUŞAK PARILTI karışımı (2026-11-08): dünyadaki toplamalı parıltıların (kalkan orbu, görev ışığı/eşyası, Ağacı Koru
## atışları, Kelebek atışı, Melek yükselişi) üst üste binince beyaza patlamaması için BLEND_MODE_ADD yerine bu paylaşılan
## materyal. Formül ve gerekçe: shaders/yumusak_parilti.gdshader. KULLANMAYANLAR: arayüz parıltıları (tier_card_fx,
## reward_rays), gece ışık haritası (atmosphere_overlay.gd, gerçek toplama gerekir), Final boss halesi (boss_glow.gd: tek
## kopya, büyük doygun mor hale - bu formül aydınlık zeminde baskın olmayan kanalları kısıp koyulaştırırdı), Ağacı Koru
## kristal maskesi (mission_tree_crystal_glow.gd: tek kopya, taşı parlatmak için gerçek toplama).
## Tuzak: m = en güçlü kanal olduğu için doygun renkli parıltı aydınlık zeminde biraz koyu kalır - beyazımsı parıltılar için.

const SHADER: Shader = preload("res://shaders/yumusak_parilti.gdshader")

static var _mat: ShaderMaterial = null


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
	return _mat
