extends Node2D

## KARA BATAKLIK gece ışığı noktası (bataklik_fx.gd kurar): meşale alevi, cadı kulübesi feneri, kazan, ateş böceği sürüsü. Kendisi hiçbir şey
## çizmez - atmosphere.gd sahneye eklenen düğümleri night_glow_catalog.gd BY_SCRIPT'ten tanır ve bu betiğin yolu için ışık takar (renk
## glow_color, yarıçap glow_radius; "perm": ışık bütçesine sayılmaz, haritada hep durur).

var glow_color: Color = Color(0.5, 1.0, 0.85)
var glow_radius: float = 48.0
