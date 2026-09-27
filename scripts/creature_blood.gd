extends RefCounted

## Yaratık kanı renkleri - TEK kaynak (kullanıcı isteği 2026-09-27: "yaratıklara birşey isabet edince çıkan kanların rengi
## yaratığın rengiyle benzer olsun (mesela slime kırmızı kan çıkarıyor slime'ın rengiyle olmalı)").
## Renkler her yaratığın yürüme dokusundaki baskın gövde renginden çıkarıldı; kemik/ten/saç karışan birkaç tanesi elle
## düzeltildi (iskelet/lich = kemik tozu, zombi1/3 = soluk yeşil ten, ork2 = turkuaz ten). Kan efekti (fx_hit_blood.gd)
## doğduğu yerdeki yaratığa bakıp rengi buradan alır; listede olmayan yaratıkta kan kırmızı kalır.
## Yeni bir yaratık eklersen buraya da bir satır ekle (anahtar = scenes/creatures/enemy_<id>.tscn'deki <id>).

const BONE := Color(0.86, 0.83, 0.74)

const BY_ID := {
	"rat1": Color(0.52, 0.46, 0.42), "rat2": Color(0.65, 0.27, 0.22), "rat3": Color(0.33, 0.36, 0.47),
	"slime1": Color(0.36, 0.72, 0.59), "slime2": Color(0.27, 0.41, 0.59), "slime3": Color(0.91, 0.65, 0.21),
	"slime4": Color(0.44, 0.85, 0.97), "slime5": Color(0.9, 0.67, 0.19), "slime6": Color(0.44, 0.85, 0.97),
	"slime7": Color(0.42, 0.1, 0.13),
	"iskelet1": BONE, "iskelet2": BONE, "iskelet3": BONE,
	"lich1": BONE, "lich2": BONE, "lich3": BONE,
	"zombie1": Color(0.55, 0.62, 0.45), "zombie2": Color(0.34, 0.36, 0.45), "zombie3": Color(0.55, 0.62, 0.45),
	"ork1": Color(0.42, 0.53, 0.19), "ork2": Color(0.3, 0.56, 0.5), "ork3": Color(0.3, 0.52, 0.37),
	"agac1": Color(0.45, 0.32, 0.17), "agac2": Color(0.5, 0.28, 0.22), "agac3": Color(0.15, 0.47, 0.28),
	"bitki1": Color(0.66, 0.26, 0.21), "bitki2": Color(0.37, 0.61, 0.77), "bitki3": Color(0.53, 0.25, 0.71),
	"golem1": Color(0.63, 0.43, 0.31), "golem2": Color(0.58, 0.3, 0.75), "golem3": Color(0.25, 0.4, 0.7),
	"mantar1": Color(0.58, 0.42, 0.34), "mantar2": Color(0.54, 0.23, 0.2), "mantar3": Color(0.58, 0.42, 0.34),
	"demon1": Color(0.64, 0.52, 0.72), "demon2": Color(0.68, 0.29, 0.22), "demon3": Color(0.53, 0.31, 0.21),
	"hayalet1": Color(0.53, 0.78, 1.0), "hayalet2": Color(0.26, 0.37, 0.53), "hayalet3": Color(0.54, 0.2, 0.24),
	"rontgen1": Color(0.77, 0.64, 0.57), "rontgen2": Color(0.66, 0.31, 0.24), "rontgen3": Color(0.67, 0.27, 0.84),
	"vampire1": Color(0.43, 0.23, 0.2), "vampire2": Color(0.26, 0.35, 0.52), "vampire3": Color(0.68, 0.27, 0.22),
	"iblis1": Color(0.7, 0.55, 0.45), "iblis2": Color(0.66, 0.46, 0.33), "iblis3": Color(0.59, 0.22, 0.25),
}

const SCENE_PREFIX := "res://scenes/creatures/enemy_"
## Kan efekti bu yarıçaptaki en yakın yaratığın rengini alır (efektler hedefin konumunda ya da mermi çarpma noktasında doğar).
const PICK_RADIUS := 48.0


## Yaratığın kan rengi; bilinmiyorsa BEYAZ (= blood_tint.gdshader dokuyu olduğu gibi, kırmızı çizer).
static func color_for(enemy: Node) -> Color:
	if enemy == null or not is_instance_valid(enemy):
		return Color.WHITE
	var path: String = enemy.scene_file_path
	if not path.begins_with(SCENE_PREFIX):
		return Color.WHITE
	var id: String = path.substr(SCENE_PREFIX.length()).get_basename()
	return BY_ID.get(id, Color.WHITE)


## pos'a en yakın yaratık (PICK_RADIUS içinde) ya da null. Enemy.get_enemies_near kullanılmıyor: o ızgara ÖLÜ yaratıkları
## atlıyor ve fizik karesi başına bir kez kuruluyor - öldürücü vuruşun kanı rengini bulamayıp kırmızı kalırdı. Grup taraması
## (ölmekte olanlar dahil) yaratık tavanında (~200) bile ihmal edilebilir.
static func nearest_enemy(tree: SceneTree, pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d: float = PICK_RADIUS * PICK_RADIUS
	for e in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		var d: float = (e as Node2D).global_position.distance_squared_to(pos)
		if d <= best_d:
			best_d = d
			best = e
	return best
