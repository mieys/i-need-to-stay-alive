extends Control

## TELEFON grup paneli KATLIYKEN (kullanıcı onayı 2026-10-18, madde 253/273; prototip tools/proto_20261018/mobil_proto.gd
## _ml_team kapalı hâli): minimapin altında müttefik sütunu - kare portre (PC grup satırıyla aynı: 3 px koyu çerçeve + kuyu +
## portrenin baş bölgesi 2x) ve altında PC'nin karakter üstü can/kalkan çubuğu (overhead_bar.gd draw_pixel_bar, 2x).
## Yerde/ölü: soluk portre + kırmızı çerçeve, çubuk boş. Dokunulmaz - paneli açmak hud.gd'nin katlama sekmesiyle.

const OverheadBarScript := preload("res://scripts/overhead_bar.gd")
const HudTheme := preload("res://scripts/hud_theme.gd")
const FACE := 54.0 ## iç 48 = 24 px baş bölgesi x2
const STEP := 80.0 ## portre + çubuklar + aralık
const BAR_K := 2.0
const BAR_W := 27.0 ## x2 = portre genişliği
const HP_COL := Color(0.30, 0.82, 0.24) ## overhead_bar.gd ile aynı
const HP_BG := Color(0.12, 0.04, 0.04)
const SH_COL := Color(0.35, 0.72, 1.0)
const SH_BG := Color(0.04, 0.08, 0.14)
const DOWN_TINT := Color(0.45, 0.45, 0.5)

var _portraits: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	if visible and Engine.get_process_frames() % 6 == 0:
		queue_redraw()


func _draw() -> void:
	var y: float = 0.0
	for ally: Node in get_tree().get_nodes_in_group("remote_players"):
		if not is_instance_valid(ally) or int(ally.get("peer_id")) <= 0:
			continue
		if y + FACE > size.y:
			break
		var down: bool = ally.get("is_dead") == true or ally.get("is_downed") == true
		var r := Rect2(0, y, FACE, FACE)
		draw_rect(r, HudTheme.BAD if down else HudTheme.OUTLINE)
		var inner: Rect2 = r.grow(-3.0)
		draw_rect(inner, HudTheme.INSET)
		var tex: Texture2D = _portrait(int(ally.get("char_id")))
		if tex:
			draw_texture_rect_region(tex, inner, Rect2(12, 3, 24, 24), DOWN_TINT if down else Color.WHITE)
		var mhp: float = maxf(1.0, float(ally.get("max_health")))
		var hp: float = 0.0 if down else clampf(float(ally.get("health")) / mhp, 0.0, 1.0)
		draw_set_transform(Vector2(0.0, y + FACE + 4.0), 0.0, Vector2.ONE * BAR_K)
		OverheadBarScript.draw_pixel_bar(self, Rect2(0, 0, BAR_W, 4), hp, HP_COL, HP_BG)
		var msh: float = float(ally.get("item_shield_max"))
		if msh > 0.0:
			var sh: float = 0.0 if down else clampf(float(ally.get("item_shield_hp")) / msh, 0.0, 1.0)
			OverheadBarScript.draw_pixel_bar(self, Rect2(0, 6, BAR_W, 3), sh, SH_COL, SH_BG)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		y += STEP


func _portrait(cid: int) -> Texture2D:
	if _portraits.has(cid):
		return _portraits[cid]
	var tex: Texture2D = null
	var path: String = str(Characters.get_def(cid).get("portrait", ""))
	if path != "" and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_portraits[cid] = tex
	return tex
