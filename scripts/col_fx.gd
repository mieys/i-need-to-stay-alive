extends Node2D

## ALTIN KUMLAR (çöl) atmosfer efektleri (2026-11-09; main.gd kurar, MapProfiles "col_fx" bayrağı). Tamamen kozmetik + yerel: ağ gerekmez
## (gün saati zaten eşitli, konumlar haritanın sabit verisi scripts/col_meta.gd).
##  - GECE IŞIĞI: küre tapınağının mavi küresi -> bataklik_isik.gd noktası (genel gece ışığı noktası: night_glow_catalog.gd BY_SCRIPT ışığı
##    takar, renk / yarıçap düğümde, "perm": bütçeye sayılmaz).

const MetaScript := preload("res://scripts/col_meta.gd")
const LightScript := preload("res://scripts/bataklik_isik.gd")

const LIGHT_PROFILES := {
	"kure": {"c": Color(0.45, 0.85, 1.0), "r": 52.0},
}


func _ready() -> void:
	for l: Array in MetaScript.LIGHTS:
		var kind: String = l[0]
		var prof: Dictionary = LIGHT_PROFILES.get(kind, LIGHT_PROFILES["kure"])
		var n: Node2D = LightScript.new()
		n.name = "Isik_" + kind
		n.glow_color = prof["c"]
		n.glow_radius = prof["r"]
		n.position = l[1]
		add_child(n)
