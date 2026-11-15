extends Node2D

## AYAZ DAĞI ateş ışığı noktası (kis_fx.gd kurar): meşale, mangal, büyük mangal, kamp ateşi. Kendisi hiçbir şey çizmez - atmosphere.gd sahneye
## eklenen düğümleri night_glow_catalog.gd BY_SCRIPT'ten tanır ve bu betiğin yolu için TİTREK, sıcak bir ışık takar (renk glow_color, yarıçap
## glow_radius; "perm": ışık bütçesine sayılmaz, haritada hep durur). Bataklık ışığının (bataklik_isik.gd) ateş karşılığı.

var glow_color: Color = Color(1.0, 0.62, 0.28)
var glow_radius: float = 48.0
