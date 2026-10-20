extends SceneTree

## ENVANTER PROTOTİPLERİ (2026-10-20). Kullanıcı: "envanter arayüzünü oyunla uyumlu olacak şekilde güncelle 4 prototip hazırla ayrıca
## ikonlar v.b eski görünüyor herşey eski güncellenmesi gerek".
## Şu anki: inventory_panel.gd + stats_panel.gd (bej UIKit penceresi, eski 250 px silah ikonları, "Sv1", eski level_up_icons stat
## simgeleri, Sprey yuvaları, onay penceresiyle satış). Oyunun geri kalanı koyu kitlere geçti (Seyyar Satıcı/Oyun Bitti kayrak,
## demirci ahşap, ESC/Ayarlar Ateş Işığı, telefon/menüler Gece Sıvası, HUD Kısık Ahşap).
## Oyuna BAĞLI DEĞİL: gerçek SP main.tscn açılır, gerçek oyuncuya gerçek yollarla 3 silah + 9 eşya verilir (statlar gerçek),
## önce ŞU ANKİ envanter (hud._on_envanter_toggle) çekilir, sonra her yön ayrı CanvasLayer'da AYNI veriyle çizilir.
## Yeni simgeler her yönde: silah = Zanaatkâr kademe sanatı + efsun kontürü (demirci gibi), stat = stat_mini_lol düz glifleri
## (HUD mini stat paneli gibi), eşya = kademe renkli yuva (satıcı gibi), kalkan türü / evcil / altın / parçacık / XP güncel dokular.
##  A Kayrak Çanta (Seyyar Satıcı "Klasik Pazar" dili, PAL_SLATE) - 3 sütun: karakter+özellikler / silah+donanım+eşya / ayrıntı+SAT
##  B Kahraman Sandığı (demirci ahşabı, PAL_WOOD) - ortada ışık havuzunda karakter, silahlar çevresinde yay, solda gruplu özellikler
##  C Ateş Işığı (ESC/Ayarlar dili, fire_menu_kit) - tam ekran, kutusuz, solda sekmeler (ÇANTA / SİLAHLAR / ÖZELLİKLER / DONANIM)
##  D Gece Sıvası Yan Çanta (telefon + menülerle aynı PAL_NIGHT) - sola yaslı dar panel, oyun sağda görünür, LoL tarzı ipucu kartı
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261020/envanter_proto.gd
##   ENVANTER_ONLY = "simdi,A" gibi seçili çekimler (boşsa hepsi). Özet: python tools/proto_20261020/envanter_ozet.py

const OUT := "res://tools/proto_20261020/out/envanter/"
var DarkKit = null
var FMK = null
var HT = null
var HSP = null
var WTA = null
var WC = null
var PetCat = null
var Logic = null
var CharsScript = null

const CHAR_ID := 2 ## Oakley
const PET := "kirpi"
## [anahtar, alınan geliştirme, final, güçlendirme]
const WEAPONS := [["uzunkilic", 3, false, 0], ["fire_staff", 1, false, 0], ["tabanca", 4, true, 2]]
const WANT_ITEMS := {
	3: ["kiyamet_bicagi", "aegisin_muhafizi"],
	2: ["ruh_emici", "savascinin_kilici", "kizil_hasat"],
	1: ["bile_tasi", "ceviklik_yuzugu", "yasam_kristali", "kan_disi"],
}
const SEL_ITEM := "kiyamet_bicagi"
const GOLD := 1480
const SHARDS := 17
const LEVEL := 14
const XP := 1840.0
const XP_NEXT := 2600.0

## Eşya stat anahtarı -> stat_mini_lol simgesi ("" = kendi glifi).
const STAT_ICON := {
	"damage_bonus": "damage", "item_flat_hit_damage": "damage", "item_damage_mult_bonus": "damage", "item_ap_percent": "damage",
	"item_fire_rate_percent": "fire_rate", "crit_chance_bonus": "crit_chance", "item_crit_damage_bonus": "crit_damage",
	"cooldown_reduction_percent": "cooldown_reduction", "lifesteal_percent": "lifesteal", "item_extra_lifesteal": "lifesteal",
	"dodge_chance": "dodge", "item_speed_percent": "speed", "shield_pen_percent": "shield_pen_percent",
	"item_pickup_range_percent": "range", "shield_protection_bonus": "shield_protection", "item_shield_power_flat": "shield_amount",
	"item_shield_regen_flat": "shield_regen", "item_shield_regen_percent": "shield_regen", "item_shield_delay_reduction": "shield_regen",
	"item_health_regen": "health_regen", "item_vitamin_regen_bonus": "health_regen", "heal_shield_power": "heal_power", "luck": "luck",
	"max_health": "", "exp_gain_percent": "",
}
## B: özellik grupları
const GROUPS := [
	["SALDIRI", ["damage", "fire_rate", "crit_chance", "crit_damage", "shield_pen_percent", "range"]],
	["SAVUNMA", ["shield_protection", "shield_amount", "shield_regen", "health_regen", "lifesteal", "dodge"]],
	["DESTEK", ["cooldown_reduction", "heal_power", "speed", "luck"]],
]
const G_PAW := [".#...#.", ".#.#.#.", "...#...", "..###..", ".#####.", ".#####.", "..###.."]
const G_HEART := [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]
const C_HEART := Color("#e8735e")
const XP_GEM := "res://assets/ui/newui/icon_xp_gem.png"

var D: Dictionary = {}
var IT = null
var ED = null
var SED = null
var GM = null
var _only: Array = []
var _player: Node = null


func _initialize() -> void:
	var env: String = OS.get_environment("ENVANTER_ONLY")
	if env != "":
		_only = Array(env.split(","))
	_run.call_deferred()


func _want(n: String) -> bool:
	return _only.is_empty() or _only.has(n)


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.get_width() != 1920: ## gizli masaüstünde kök doku x2 gelebilir (hafıza: capture-script-autoload-compile)
		img.resize(1920, 1080, Image.INTERPOLATE_BILINEAR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	img.save_png(ProjectSettings.globalize_path(OUT + name))
	print("SHOT %s" % name)


## ---------------------------------------------------------------- kurulum
func _load_scripts() -> void:
	DarkKit = load("res://scripts/shop_dark_kit.gd")
	FMK = load("res://scripts/fire_menu_kit.gd")
	HT = load("res://scripts/hud_theme.gd")
	HSP = load("res://scripts/hud_stat_panel.gd")
	WTA = load("res://scripts/weapon_tier_art.gd")
	WC = load("res://scripts/weapon_catalog.gd")
	PetCat = load("res://scripts/pet_catalog.gd")
	Logic = load("res://scripts/weapon_shop_logic.gd")
	CharsScript = load("res://scripts/characters.gd")
	IT = load("res://scripts/items.gd")
	ED = load("res://scripts/enchant_defs.gd")
	SED = load("res://scripts/shield_enchant_defs.gd")
	GM = root.get_node("GameManager")


func _run() -> void:
	await process_frame
	_load_scripts()
	AudioServer.set_bus_mute(0, true)
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	nm.call("disconnect_from_room")
	gm.call("reset")
	gm.set("selected_char_id", CHAR_ID)
	gm.set("selected_character", CharsScript.get_def(CHAR_ID).get("skill", 1))
	gm.set("selected_start_weapon", WEAPONS[0][0])
	gm.set("selected_pet", PET)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	await _wait(2.5)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
	var main: Node = current_scene
	var house: Node = main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.0)
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	_player = main.get_node_or_null("Player")
	_setup_state(_player)
	await _wait(1.0)
	_collect(_player)

	if _want("simdi"):
		var hud: Node = main.get_node_or_null("HUD")
		hud.call("_on_envanter_toggle")
		await _wait(0.8)
		await _shot("simdi.png")
		hud.call("_on_envanter_toggle")
		await _wait(0.3)

	## "oyun": OYUNA ALINAN B (madde 341) gerçek HUD düğmesiyle; eşya / silah / kalkan seçili üç çekim (ENVANTER_ONLY=oyun).
	if _only.has("oyun"):
		var hud2: Node = main.get_node_or_null("HUD")
		hud2.call("_on_envanter_toggle")
		await _wait(0.8)
		await _shot("oyun.png")
		var inv: Node = hud2.get("inventory_panel_instance")
		inv.call("_ch_select", "weapon", 2)
		await _wait(0.3)
		await _shot("oyun_silah.png")
		inv.call("_ch_select", "shield", 0)
		await _wait(0.3)
		await _shot("oyun_kalkan.png")
		hud2.call("_on_envanter_toggle")
		await _wait(0.3)

	for k: String in ["A", "B", "C", "C2", "D"]:
		if not _want(k):
			continue
		var layer := CanvasLayer.new()
		layer.layer = 120
		root.add_child(layer)
		var host := Control.new()
		host.set_anchors_preset(Control.PRESET_FULL_RECT)
		host.size = Vector2(1920, 1080)
		host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(host)
		match k:
			"A": _build_a(host)
			"B": _build_b(host)
			"C": _build_c(host, 0)
			"C2": _build_c(host, 2)
			"D": _build_d(host)
		await _wait(0.6)
		await _shot("%s.png" % k)
		layer.queue_free()
		await _wait(0.2)
	quit()


func _setup_state(p: Node) -> void:
	GM.gold = 99999
	GM.weapon_shards = 999
	for i in range(1, WEAPONS.size()):
		if not Logic.buy_weapon(p, str(WEAPONS[i][0])):
			print("!! silah alınamadı: ", WEAPONS[i][0], " ", Logic.weapon_block_reason(p, str(WEAPONS[i][0])))
	for i in GM.owned_weapons.size():
		var e: Dictionary = GM.owned_weapons[i]
		ED.ensure_trait(e)
		var spec: Array = []
		for w: Array in WEAPONS:
			if w[0] == e.get("key", ""):
				spec = w
		if spec.is_empty() or not e.has("enchant"):
			continue
		var ups: Array = []
		for n in int(spec[1]):
			ups.append(n)
		(e["enchant"] as Dictionary)["ups"] = ups
		(e["enchant"] as Dictionary)["final"] = bool(spec[2])
		(e["enchant"] as Dictionary)["plus"] = int(spec[3])
		e["shards_spent"] = int(e.get("shards_spent", 0)) + 5 * ups.size()
	if "max_item_slots" in p:
		p.set("max_item_slots", 9)
	for kd: int in [3, 2, 1]:
		for key: String in WANT_ITEMS[kd]:
			if not p.call("buy_item", key):
				print("!! eşya alınamadı: ", key)
	GM.gold = GOLD
	GM.add_weapon_shards(SHARDS - int(GM.weapon_shards))
	p.set("level", LEVEL)
	p.set("xp", XP)
	p.set("xp_to_next_level", XP_NEXT)


func _collect(p: Node) -> void:
	var cd: Dictionary = CharsScript.get_def(CHAR_ID)
	D["char_name"] = str(cd.get("name", ""))
	D["portrait"] = load(str(cd.get("portrait", ""))) as Texture2D
	D["frames"] = load(str(cd.get("frames", ""))) as SpriteFrames
	D["level"] = int(p.get("level"))
	D["xp"] = float(p.get("xp"))
	D["xp_next"] = maxf(1.0, float(p.get("xp_to_next_level")))
	D["gold"] = GM.gold
	D["shards"] = GM.weapon_shards
	var ws: Array = []
	for i in GM.owned_weapons.size():
		var e: Dictionary = GM.owned_weapons[i]
		var key: String = str(e.get("key", ""))
		var ench: Dictionary = e.get("enchant", {})
		var tier: int = 1
		if not ench.is_empty():
			tier = 5 if bool(ench.get("final", false)) else mini(4, 1 + (ench.get("ups", []) as Array).size())
		var tdef: Dictionary = ED.get_def(str(ench.get("id", "")))
		ws.append({"key": key, "name": WC.display_name(key), "tier": tier, "plus": ED.plus_count(ench),
			"done": (ench.get("ups", []) as Array).size() + (1 if bool(ench.get("final", false)) else 0),
			"trait": str(tdef.get("name", "")), "trait_desc": str(tdef.get("desc", "")), "cat": WC.category_label(key),
			"tex": WTA.texture(key, tier), "refund": ED.sell_refund_gold(e), "shard_refund": ED.sell_refund_shards(e)})
	D["weapons"] = ws
	D["max_weapons"] = int(p.call("get_max_owned_weapons"))
	var st: String = SED.owned_type()
	var ss: Dictionary = SED.stats()
	var summ: String = "%d güç, %%%d soğurma, %s sn bekleme" % [int(ss.get("power", 0)), int(round(float(ss.get("absorption", 0)) * 100.0)),
		String.num(snappedf(float(ss.get("delay", 0)), 0.1), 1).trim_suffix(".0").replace(".", ",")]
	D["shield"] = {"type": st, "name": SED.type_name(st), "summary": summ, "tex": DarkKit.tex(str(SED.ICONS.get(st, "")))}
	D["pet"] = {"key": PET, "name": PetCat.display_name(PET), "desc": str(PetCat.DESCRIPTIONS.get(PET, "")), "tex": PetCat.icon(PET)}
	D["stats"] = HSP.values_for(p)
	var items: Dictionary = {1: [], 2: [], 3: []}
	for e: Dictionary in GM.owned_items:
		var key: String = str(e.get("key", ""))
		(items[IT.kademe(key)] as Array).append(key)
	D["items"] = items
	D["part_slots"] = int(p.call("get_max_item_slots"))
	D["sel"] = SEL_ITEM if GM.owned_items.any(func(e: Dictionary) -> bool: return e.get("key", "") == SEL_ITEM) \
		else str((GM.owned_items[0] as Dictionary).get("key", ""))
	print("DATA weapons=%d items=%d shield=%s summary=%s" % [ws.size(), GM.owned_items.size(), st, D["shield"]["summary"]])


## ---------------------------------------------------------------- ortak veri yardımcıları
func _stat_name(id: String) -> String:
	for s: Array in HSP.STATS:
		if s[0] == id:
			return str(s[1])
	return id


func _stat_tex(id: String) -> Texture2D:
	return DarkKit.tex(HSP.ICON_DIR + id + ".png")


func _limit(kd: int) -> int:
	return IT.slot_limit(kd, int(D["part_slots"]))


func _item_count() -> int:
	return (D["items"][1] as Array).size() + (D["items"][2] as Array).size() + (D["items"][3] as Array).size()


func _slot_total() -> int:
	return _limit(1) + _limit(2) + _limit(3)


## [[simge anahtarı (stat id | "heart" | "xp"), metin]]
func _item_lines(key: String) -> Array:
	var def: Dictionary = IT.get_def(key)
	var stats: Dictionary = def.get("stats", {})
	var keys: Array = []
	for s in stats:
		if IT.STAT_LABELS.has(s):
			keys.append(str(s))
	var out: Array = []
	if keys.is_empty():
		return out
	var lines: PackedStringArray = IT.describe(key).split("\n\n")[0].split("\n")
	for i in mini(keys.size(), lines.size()):
		var ic: String = str(STAT_ICON.get(keys[i], ""))
		if ic == "":
			ic = "heart" if keys[i] == "max_health" else "xp"
		out.append([ic, lines[i]])
	return out


func _passive(key: String) -> String:
	return str(IT.get_def(key).get("passive", ""))


## Simge kutusu: stat id / "heart" / "xp".
func _sicon(k, id: String, bx: float) -> Control:
	if id == "heart":
		return k.center(k.glyph(G_HEART, C_HEART, int(maxf(2.0, floorf(bx / 8.0)))))
	if id == "xp":
		return k.icon(DarkKit.tex(XP_GEM), bx)
	return k.icon(_stat_tex(id), bx)


func _tier_col(t: int, k) -> Color:
	return DarkKit.ENCH_COL[t] if t >= 2 else k.c("dim")


func _roman(w: Dictionary) -> String:
	return DarkKit.ROMAN[int(w["tier"]) - 1] + ((" +%d" % int(w["plus"])) if int(w["plus"]) > 0 else "")


func _pips(k, w: Dictionary, wd: float, ht: float = 10.0) -> Control:
	var cols: Array = [DarkKit.ENCH_COL[2], DarkKit.ENCH_COL[3], DarkKit.ENCH_COL[4], DarkKit.ENCH_COL[4], DarkKit.ENCH_COL[5]]
	return DarkKit.TierPips.new(cols, int(w["done"]), k.c("inset"), wd, ht)


func _bar(k, wd: float, ht: float = 14.0) -> Control:
	return DarkKit.Bar.new(float(D["xp"]) / float(D["xp_next"]), Color("#c9a2f0"), k.c("inset"), ht, wd)


func _x_btn(k, s: float = 56.0) -> Button:
	var b: Button = k.btn("", "ghost", 32, s, s)
	var g = k.glyph(DarkKit.G_X, k.c("text"), 4)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(g)
	b.add_child(cc)
	return b


func _sec_head(k, pat: Array, title: String, right: String, col: Color = Color(0, 0, 0, 0)) -> HBoxContainer:
	var r: HBoxContainer = k.h(12)
	r.add_child(k.glyph(pat, col if col.a > 0 else k.c("accent"), 3))
	r.add_child(k.lbl(title, 32, col if col.a > 0 else k.c("accent")))
	r.add_child(k.sp(0, 0, true))
	if right != "":
		r.add_child(k.lbl(right, 24, k.c("dim")))
	return r


func _stat_row(k, id: String, wd: float, fs: int = 24, ic: float = 24.0, stripe: bool = false) -> Control:
	var r: HBoxContainer = k.h(10)
	r.add_child(k.icon(_stat_tex(id), ic))
	r.add_child(k.expand(k.lbl(_stat_name(id), fs, k.c("text"))))
	r.add_child(k.lbl(str(D["stats"].get(id, "-")), fs, k.c("price"), HORIZONTAL_ALIGNMENT_RIGHT))
	r.custom_minimum_size = Vector2(wd, ic + 6)
	if not stripe:
		return r
	var p: PanelContainer = k.box(Color(k.c("panel3"), 0.45), Color(0, 0, 0, 0), 0, 0, 2)
	var sbx: StyleBoxFlat = p.get_theme_stylebox("panel") as StyleBoxFlat
	sbx.content_margin_left = 8
	sbx.content_margin_right = 8
	p.add_child(r)
	return p


func _item_tile(k, key: String, s: float) -> Control:
	var kd: int = IT.kademe(key)
	return k.tile(IT.icon(key), s, DarkKit.TIER_COL[kd - 1], {"sel": key == D["sel"]})


## Kademe satırı: [başlık sütunu] + sahip olunanlar + boş yuvalar (en çok maxn).
func _tier_row(k, kd: int, s: float, maxn: int, head_w: float = 0.0, fs: int = 24, gap: int = 8) -> Control:
	var have: Array = D["items"][kd]
	var lim: int = _limit(kd)
	var box: Container = k.h(8) if head_w > 0 else k.v(6)
	var head: HBoxContainer = k.h(8)
	head.add_child(k.lbl(DarkKit.TIER_NAME[kd - 1], fs, DarkKit.TIER_COL[kd - 1]))
	head.add_child(k.lbl("%d/%d" % [have.size(), lim], fs, k.c("dim")))
	if head_w > 0:
		head.custom_minimum_size.x = head_w
	box.add_child(head)
	var row: HBoxContainer = k.h(gap)
	for key: String in have:
		row.add_child(_item_tile(k, key, s))
	for n in mini(lim, maxn) - have.size():
		row.add_child(k.empty_slot(s))
	box.add_child(row)
	return box


func _detail_body(k, key: String, wd: float, fs: int = 24) -> VBoxContainer:
	var v: VBoxContainer = k.v(8)
	var kd: int = IT.kademe(key)
	var lines: Array = _item_lines(key)
	if not lines.is_empty():
		for ln: Array in lines:
			var r: HBoxContainer = k.h(10)
			r.add_child(_sicon(k, str(ln[0]), 24))
			r.add_child(k.lbl(str(ln[1]), fs, k.c("good")))
			v.add_child(r)
	var pas: String = _passive(key)
	if pas != "":
		var pb: PanelContainer = k.box(k.c("inset"), k.c("line"), 12, 2, 4)
		var pv: VBoxContainer = k.v(4)
		pv.add_child(k.lbl("PASİF", 24, DarkKit.TIER_COL[kd - 1]))
		pv.add_child(k.wrap(pas, fs, k.c("text"), wd - 30))
		pb.add_child(pv)
		v.add_child(pb)
	return v


## Satınca kaybedilenler (eşyanın kendi stat satırları, eksi işaretli) + pasif.
func _lose_block(k, key: String, wd: float) -> VBoxContainer:
	var v: VBoxContainer = k.v(4)
	v.add_child(k.lbl("SATARSAN", 24, k.c("dim")))
	for ln: Array in _item_lines(key):
		var r: HBoxContainer = k.h(10)
		r.add_child(_sicon(k, str(ln[0]), 24))
		r.add_child(k.lbl(str(ln[1]).replace("+", "-"), 24, k.c("bad")))
		v.add_child(r)
	if _passive(key) != "":
		v.add_child(k.wrap("Pasifi kaybolur. Eşyayı yeniden almak tam fiyat ister.", 24, k.c("dim"), wd))
	return v


func _sell_btn(k, refund: int, wd: float, ht: float = 64.0) -> Button:
	var r: HBoxContainer = k.h(10)
	r.add_child(k.lbl("SAT", 32, k.c("accent_text")))
	r.add_child(k.coin(32))
	r.add_child(k.lbl("+%d" % refund, 32, k.c("accent_text")))
	return k.row_btn(r, "primary", ht, wd)


func _weapon_tex(w: Dictionary) -> Texture2D:
	return w["tex"] if w["tex"] != null else WC.icon(str(w["key"]))


func _place(parent: Control, n: Control, pos: Vector2, sz: Vector2 = Vector2.ZERO) -> Control:
	parent.add_child(n)
	n.position = pos
	if sz != Vector2.ZERO:
		n.size = sz
	return n


func _dim(host: Control, a: float) -> void:
	var r := ColorRect.new()
	r.color = Color(0.02, 0.02, 0.04, a)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.size = Vector2(1920, 1080)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(r)


## ================================================================ A - KAYRAK ÇANTA (Seyyar Satıcı dili)
func _build_a(host: Control) -> void:
	var k = DarkKit.new(DarkKit.PAL_SLATE)
	_dim(host, 0.45)
	var win: PanelContainer = k.box(k.c("panel"), k.c("line_hi"), 24, 3, 8)
	win.theme = k.theme()
	_place(host, win, Vector2(92, 36), Vector2(1736, 1008))
	var col: VBoxContainer = k.v(16)
	win.add_child(col)
	## başlık
	var head: HBoxContainer = k.h(16)
	head.add_child(k.glyph(DarkKit.G_BAG, k.c("accent"), 5))
	head.add_child(k.lbl("ENVANTER", 48, k.c("accent")))
	head.add_child(k.sp(0, 0, true))
	var cg: PanelContainer = k.chip("gold", "ALTIN")
	(cg.get_meta("label") as Label).text = str(D["gold"])
	head.add_child(cg)
	var cs: PanelContainer = k.chip("shard", "PARÇACIK")
	(cs.get_meta("label") as Label).text = str(D["shards"])
	head.add_child(cs)
	head.add_child(k.sp(8))
	head.add_child(_x_btn(k))
	col.add_child(head)
	col.add_child(k.hline())
	var body: HBoxContainer = k.h(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	## sol: karakter + özellikler
	var left: PanelContainer = k.box(k.c("panel2"), k.c("line"), 16)
	left.custom_minimum_size.x = 396
	body.add_child(left)
	var lv: VBoxContainer = k.v(6)
	left.add_child(lv)
	var ch: HBoxContainer = k.h(14)
	var pf: PanelContainer = k.box(k.c("inset"), k.c("line_hi"), 4, 3, 4)
	pf.add_child(k.icon(D["portrait"], 96))
	ch.add_child(pf)
	var cv: VBoxContainer = k.v(4)
	cv.add_child(k.lbl(str(D["char_name"]), 40, k.c("text")))
	cv.add_child(k.lbl("Seviye %d" % int(D["level"]), 24, k.c("dim")))
	cv.add_child(_bar(k, 240, 14))
	cv.add_child(k.lbl("%d / %d XP" % [int(D["xp"]), int(D["xp_next"])], 24, Color("#d0a8f6")))
	ch.add_child(cv)
	lv.add_child(ch)
	lv.add_child(k.hline())
	lv.add_child(_sec_head(k, DarkKit.G_STAR, "ÖZELLİKLER", ""))
	for i in HSP.STATS.size():
		lv.add_child(_stat_row(k, str(HSP.STATS[i][0]), 364, 24, 24, i % 2 == 0))

	## orta: silahlar + donanım + eşyalar
	var mid: VBoxContainer = k.v(12)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(mid)
	mid.add_child(_sec_head(k, DarkKit.G_SWORD, "SİLAHLAR", "%d / %d" % [(D["weapons"] as Array).size(), int(D["max_weapons"])]))
	var wr: HBoxContainer = k.h(12)
	for w: Dictionary in D["weapons"]:
		var wb: PanelContainer = k.box(k.c("panel2"), k.c("line"), 12)
		wb.custom_minimum_size.x = 260
		var wv: VBoxContainer = k.v(6)
		wv.add_child(k.center(k.wicon(_weapon_tex(w), 104, int(w["tier"]))))
		wv.add_child(k.lbl(str(w["name"]), 32, k.c("text"), HORIZONTAL_ALIGNMENT_CENTER))
		var tr: HBoxContainer = k.h(8)
		tr.alignment = BoxContainer.ALIGNMENT_CENTER
		var pill: PanelContainer = k.box(k.c("inset"), _tier_col(int(w["tier"]), k), 4, 2, 4)
		pill.add_child(k.lbl("KADEME " + _roman(w), 24, _tier_col(int(w["tier"]), k)))
		tr.add_child(pill)
		wv.add_child(tr)
		wv.add_child(k.lbl(str(w["trait"]), 24, k.c("dim"), HORIZONTAL_ALIGNMENT_CENTER))
		wv.add_child(k.center(_pips(k, w, 200, 10)))
		wb.add_child(wv)
		wr.add_child(wb)
	mid.add_child(wr)
	var eq: HBoxContainer = k.h(12)
	var sh: Dictionary = D["shield"]
	var pet: Dictionary = D["pet"]
	for spec: Array in [[sh["tex"], str(sh["name"]), "Mana Kalkanı türü", str(sh["summary"]).split("\n")[0]],
			[pet["tex"], str(pet["name"]), "Evcil hayvan", str(pet["desc"]).split(". ")[0].trim_suffix(".") + "."]]:
		var eb: PanelContainer = k.box(k.c("panel2"), k.c("line"), 12)
		eb.custom_minimum_size.x = 392
		var er: HBoxContainer = k.h(12)
		var ef: PanelContainer = k.box(k.c("inset"), k.c("line_hi"), 6, 2, 4)
		ef.add_child(k.icon(spec[0], 64))
		er.add_child(ef)
		var ev: VBoxContainer = k.v(2)
		ev.add_child(k.lbl(spec[2], 24, k.c("dim")))
		ev.add_child(k.lbl(spec[1], 32, k.c("text")))
		ev.add_child(k.wrap(spec[3], 24, k.c("dim"), 270))
		er.add_child(ev)
		eb.add_child(er)
		eq.add_child(eb)
	mid.add_child(eq)
	mid.add_child(_sec_head(k, DarkKit.G_BAG, "EŞYALAR", "%d / %d yuva" % [_item_count(), _slot_total()]))
	var ib: PanelContainer = k.box(k.c("panel2"), k.c("line"), 14)
	var iv: VBoxContainer = k.v(12)
	for kd: int in [3, 2, 1]:
		iv.add_child(_tier_row(k, kd, 72, 10, 0.0, 24, 6))
	ib.add_child(iv)
	mid.add_child(ib)

	## sağ: ayrıntı
	var right: PanelContainer = k.box(k.c("panel2"), k.c("line_hi"), 18)
	right.custom_minimum_size.x = 404
	body.add_child(right)
	var rv: VBoxContainer = k.v(12)
	right.add_child(rv)
	var key: String = D["sel"]
	var kd2: int = IT.kademe(key)
	var top: HBoxContainer = k.h(14)
	top.add_child(k.tile(IT.icon(key), 96, DarkKit.TIER_COL[kd2 - 1]))
	var tv: VBoxContainer = k.v(2)
	tv.add_child(k.wrap(IT.item_name(key), 40, k.c("text"), 250))
	tv.add_child(k.lbl(DarkKit.TIER_NAME[kd2 - 1], 24, DarkKit.TIER_COL[kd2 - 1]))
	top.add_child(tv)
	rv.add_child(top)
	rv.add_child(k.hline())
	rv.add_child(_detail_body(k, key, 368))
	var rec: Array = IT.recipe(key)
	if not rec.is_empty():
		rv.add_child(k.lbl("TARİF", 24, k.c("dim")))
		var rr: HBoxContainer = k.h(8)
		for rk in rec:
			rr.add_child(k.tile(IT.icon(str(rk)), 48, DarkKit.TIER_COL[IT.kademe(str(rk)) - 1]))
		rv.add_child(rr)
	rv.add_child(k.sp(0, 0, false, true))
	rv.add_child(_lose_block(k, key, 360))
	rv.add_child(k.hline())
	var vr: HBoxContainer = k.h(8)
	vr.add_child(k.lbl("Değeri", 24, k.c("dim")))
	vr.add_child(k.sp(0, 0, true))
	vr.add_child(k.amt(IT.cost(key), 24, k.c("dim")))
	rv.add_child(vr)
	rv.add_child(_sell_btn(k, IT.sell_refund(key), 368))


## ================================================================ B - KAHRAMAN SANDIĞI (demirci ahşabı)
func _build_b(host: Control) -> void:
	var k = DarkKit.new(DarkKit.PAL_WOOD)
	_dim(host, 0.5)
	## ahşap kenar (HUD Kısık Ahşap) + iç panel
	var rim: PanelContainer = k.box(HT.RIM, HT.OUTLINE, 8, 4, 6)
	_place(host, rim, Vector2(84, 48), Vector2(1752, 984))
	var win: PanelContainer = k.box(k.c("panel"), HT.RIM_LO, 20, 3, 4)
	win.theme = k.theme()
	rim.add_child(win)
	var col: VBoxContainer = k.v(14)
	win.add_child(col)
	var head: HBoxContainer = k.h(16)
	var plaque: PanelContainer = k.box(HT.INSET, HT.RIM_HI, 10, 3, 4)
	var pr: HBoxContainer = k.h(12)
	pr.add_child(k.sp(6))
	pr.add_child(k.glyph(DarkKit.G_BAG, HT.ACCENT, 4))
	pr.add_child(k.lbl("KAHRAMAN ÇANTASI", 40, HT.ACCENT))
	pr.add_child(k.sp(6))
	plaque.add_child(pr)
	head.add_child(plaque)
	head.add_child(k.sp(0, 0, true))
	head.add_child(k.amt(int(D["gold"]), 32, k.c("price")))
	head.add_child(k.sp(10))
	head.add_child(k.amt(int(D["shards"]), 32, DarkKit.SHARD_TEXT, "shard"))
	head.add_child(k.sp(10))
	head.add_child(_x_btn(k))
	col.add_child(head)
	var body: HBoxContainer = k.h(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	## sol: gruplu özellikler
	var left: PanelContainer = k.box(k.c("inset"), k.c("line"), 14)
	left.custom_minimum_size.x = 380
	body.add_child(left)
	var lv: VBoxContainer = k.v(6)
	left.add_child(lv)
	for g: Array in GROUPS:
		var gh: HBoxContainer = k.h(10)
		gh.add_child(k.lbl(str(g[0]), 24, k.c("accent")))
		var ln: ColorRect = k.hline(k.c("line"), 3)
		ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ln.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		gh.add_child(ln)
		lv.add_child(gh)
		var gi: int = 0
		for id: String in g[1]:
			lv.add_child(_stat_row(k, id, 350, 24, 24, gi % 2 == 0))
			gi += 1
		lv.add_child(k.sp(0, 6))

	## orta: ışık havuzunda karakter, silahlar yay çiziyor
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(560, 820)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(stage)
	var spot = DarkKit.Spot.new(k.c("spot"), 0.72)
	_place(stage, spot, Vector2(0, 40), Vector2(560, 640))
	var fr: SpriteFrames = D["frames"]
	var anim: String = "idle_down" if fr.has_animation("idle_down") else String(fr.get_animation_names()[0])
	var ftex: Texture2D = fr.get_frame_texture(anim, 0)
	var sc: float = floorf(300.0 / ftex.get_size().y)
	var spr := TextureRect.new()
	spr.texture = ftex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_SCALE
	var ssz: Vector2 = ftex.get_size() * sc
	_place(stage, spr, Vector2(floorf(280 - ssz.x * 0.5), floorf(440 - ssz.y * 0.62)), ssz)
	## silah yuvaları: sol, tepe, sağ (oyunda silahlar karakterin çevresinde süzülür)
	var spots: Array = [Vector2(28, 210), Vector2(224, 52), Vector2(420, 210)]
	var lines = DarkKit.Lines.new()
	_place(stage, lines, Vector2.ZERO, stage.custom_minimum_size)
	var chest: Vector2 = Vector2(280, 360)
	for i in D["max_weapons"]:
		var p: Vector2 = spots[i]
		var c: Vector2 = p + Vector2(56, 56)
		lines.segs.append([PackedVector2Array([c, c.lerp(chest, 0.42)]), Color(k.c("line_hi"), 0.7), 3.0])
		var slot: PanelContainer = k.box(k.c("inset"), k.c("line_hi"), 4, 3, 6)
		if i < (D["weapons"] as Array).size():
			var w: Dictionary = D["weapons"][i]
			(slot.get_theme_stylebox("panel") as StyleBoxFlat).border_color = _tier_col(int(w["tier"]), k).darkened(0.15)
			slot.add_child(k.wicon(_weapon_tex(w), 104, int(w["tier"])))
			_place(stage, slot, p, Vector2(112, 112))
			var badge: PanelContainer = k.box(HT.OUTLINE, _tier_col(int(w["tier"]), k), 2, 2, 3)
			badge.add_child(k.lbl(" " + _roman(w) + " ", 24, _tier_col(int(w["tier"]), k)))
			_place(stage, badge, p + Vector2(76, -14))
			var nl: Label = k.lbl(str(w["name"]), 24, k.c("text"), HORIZONTAL_ALIGNMENT_CENTER)
			_place(stage, nl, p + Vector2(-34, 116), Vector2(180, 26))
			var tl: Label = k.lbl(str(w["trait"]), 24, k.c("dim"), HORIZONTAL_ALIGNMENT_CENTER)
			_place(stage, tl, p + Vector2(-34, 140), Vector2(180, 26))
		else:
			_place(stage, k.empty_slot(112), p, Vector2(112, 112))
	lines.queue_redraw()
	## kalkan + evcil yuvaları
	var sh: Dictionary = D["shield"]
	var pet: Dictionary = D["pet"]
	var eqs: Array = [[sh["tex"], str(sh["name"]), "MANA KALKANI", Vector2(70, 560)], [pet["tex"], str(pet["name"]), "EVCİL", Vector2(394, 560)]]
	for e: Array in eqs:
		var es: PanelContainer = k.box(k.c("inset"), HT.RIM_HI, 6, 3, 6)
		es.add_child(k.icon(e[0], 72))
		_place(stage, es, e[3], Vector2(96, 96))
		_place(stage, k.lbl(e[2], 24, k.c("accent"), HORIZONTAL_ALIGNMENT_CENTER), e[3] + Vector2(-42, 100), Vector2(180, 26))
		_place(stage, k.lbl(e[1], 24, k.c("text"), HORIZONTAL_ALIGNMENT_CENTER), e[3] + Vector2(-42, 124), Vector2(180, 26))
	## ad + seviye + XP
	var nv: VBoxContainer = k.v(4)
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	var nr: HBoxContainer = k.h(12)
	nr.alignment = BoxContainer.ALIGNMENT_CENTER
	nr.add_child(k.lbl(str(D["char_name"]), 40, k.c("text")))
	var lvp: PanelContainer = k.box(HT.INSET, HT.ACCENT, 2, 2, 3)
	lvp.add_child(k.lbl(" Sv %d " % int(D["level"]), 24, HT.ACCENT))
	nr.add_child(lvp)
	nv.add_child(nr)
	nv.add_child(k.center(_bar(k, 360, 16)))
	nv.add_child(k.lbl("%d / %d XP" % [int(D["xp"]), int(D["xp_next"])], 24, Color("#d0a8f6"), HORIZONTAL_ALIGNMENT_CENTER))
	_place(stage, nv, Vector2(60, 718), Vector2(440, 100))

	## sağ: heybe + seçili eşya
	var right: VBoxContainer = k.v(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var bag: PanelContainer = k.box(k.c("inset"), k.c("line"), 14)
	var bv: VBoxContainer = k.v(12)
	bv.add_child(_sec_head(k, DarkKit.G_BAG, "HEYBE", "%d / %d yuva" % [_item_count(), _slot_total()]))
	for kd: int in [3, 2, 1]:
		bv.add_child(_tier_row(k, kd, 72, 7))
	bag.add_child(bv)
	right.add_child(bag)
	var key: String = D["sel"]
	var kd2: int = IT.kademe(key)
	var card: PanelContainer = k.box(k.c("panel2"), DarkKit.TIER_COL[kd2 - 1].darkened(0.2), 16, 3, 6)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cv: VBoxContainer = k.v(10)
	var top: HBoxContainer = k.h(14)
	top.add_child(k.tile(IT.icon(key), 80, DarkKit.TIER_COL[kd2 - 1]))
	var tv: VBoxContainer = k.v(2)
	tv.add_child(k.lbl(IT.item_name(key), 40, k.c("text")))
	var trr: HBoxContainer = k.h(14)
	trr.add_child(k.lbl(DarkKit.TIER_NAME[kd2 - 1], 24, DarkKit.TIER_COL[kd2 - 1]))
	trr.add_child(k.amt(IT.cost(key), 24, k.c("dim")))
	tv.add_child(trr)
	top.add_child(tv)
	cv.add_child(top)
	cv.add_child(_detail_body(k, key, 600))
	cv.add_child(k.sp(0, 0, false, true))
	var br: HBoxContainer = k.h(12)
	br.add_child(_lose_block(k, key, 360))
	br.add_child(k.sp(0, 0, true))
	var rec: Array = IT.recipe(key)
	if not rec.is_empty():
		var rcv: VBoxContainer = k.v(4)
		rcv.add_child(k.lbl("TARİF", 24, k.c("dim")))
		var rr: HBoxContainer = k.h(6)
		for rk in rec:
			rr.add_child(k.tile(IT.icon(str(rk)), 48, DarkKit.TIER_COL[IT.kademe(str(rk)) - 1]))
		rcv.add_child(rr)
		br.add_child(rcv)
	cv.add_child(br)
	var br2: HBoxContainer = k.h(12)
	br2.alignment = BoxContainer.ALIGNMENT_END
	br2.add_child(_sell_btn(k, IT.sell_refund(key), 260))
	cv.add_child(br2)
	card.add_child(cv)
	right.add_child(card)


## ================================================================ C - ATEŞ IŞIĞI (ESC / Ayarlar dili)
## tab: 0 ÇANTA, 2 ÖZELLİKLER
func _build_c(host: Control, tab: int) -> void:
	FMK.use_phone_palette(false)
	var k = DarkKit.new(DarkKit.PAL_WOOD)
	var shade = FMK.StepShade.new()
	shade.col = Color(0.05, 0.035, 0.025, 0.92)
	shade.x0 = 1920
	shade.size = Vector2(1920, 1080)
	host.add_child(shade)
	host.add_child(FMK.left_shade())
	host.theme = k.theme()
	## başlık
	var sub: HBoxContainer = k.h(14)
	sub.add_child(k.amt(int(D["gold"]), 32, FMK.C_GOLD))
	sub.add_child(k.sp(8))
	sub.add_child(k.amt(int(D["shards"]), 32, DarkKit.SHARD_TEXT, "shard"))
	sub.add_child(k.sp(8))
	sub.add_child(FMK.lbl("%s  Seviye %d" % [str(D["char_name"]), int(D["level"])], 32, FMK.C_SUB))
	_place(host, FMK.title_block("ENVANTER", sub), FMK.TITLE_POS)
	## sol sekmeler
	var wmax: int = 1
	for w: Dictionary in D["weapons"]:
		wmax = maxi(wmax, int(w["tier"]))
	var tabs: Array = [
		["ÇANTA", "%d eşya, %d boş yuva" % [_item_count(), _slot_total() - _item_count()], FMK.tex_icon(IT.icon(str(D["sel"])), 48)],
		["SİLAHLAR", "%d / %d silah, en yüksek kademe %s" % [(D["weapons"] as Array).size(), int(D["max_weapons"]), DarkKit.ROMAN[wmax - 1]],
			FMK.tex_icon(_weapon_tex(D["weapons"][0]), 48)],
		["ÖZELLİKLER", "16 özellik", FMK.tex_icon(_stat_tex("damage"), 48)],
		["DONANIM", "Mana kalkanı ve evcil hayvan", FMK.tex_icon(D["shield"]["tex"], 48)],
	]
	var menu: VBoxContainer = k.v(4)
	_place(host, menu, FMK.COL_POS)
	var btns: Array = []
	for t: Array in tabs:
		var b: Button = FMK.item(t[0], t[1], t[2], false, false)
		menu.add_child(b)
		btns.append(b)
	menu.add_child(k.sp(0, 24))
	var back: Button = FMK.item("GERİ", "Oyuna dön", k.glyph(DarkKit.G_BACK, FMK.C_CREAM, 5), false, false)
	menu.add_child(back)
	FMK.set_selected(btns[tab], true)
	## sağ içerik
	var area: VBoxContainer = k.v(6)
	_place(host, area, Vector2(680, 80), Vector2(1160 if tab != 0 else 700, 900))
	if tab == 0:
		_c_bag(k, area)
		_c_detail(k, host)
	else:
		_c_stats(k, area)
	var hint: HBoxContainer = FMK.hint([["Tık", "Ayrıntı"], ["Sağ Tık", "Sat"], ["ESC", "Kapat"]]) if tab == 0 \
		else FMK.hint([["Q / E", "Sekme"], ["ESC", "Kapat"]])
	_place(host, hint, Vector2(1440 if tab == 0 else 1620, 1010))


func _c_rowline(k, col: Color) -> ColorRect:
	var ln: ColorRect = k.hline(Color(col, 0.35), 2)
	ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ln.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return ln


func _c_bag(k, area: VBoxContainer) -> void:
	for kd: int in [3, 2, 1]:
		var have: Array = D["items"][kd]
		var hh: HBoxContainer = k.h(12)
		hh.add_child(FMK.lbl(DarkKit.TIER_NAME[kd - 1], 32, DarkKit.TIER_COL[kd - 1]))
		hh.add_child(FMK.lbl("%d / %d" % [have.size(), _limit(kd)], 24, FMK.C_SUB))
		for n in mini(_limit(kd) - have.size(), 8):
			var es: Panel = k.empty_slot(20)
			(es.get_theme_stylebox("panel") as StyleBoxFlat).border_color = FMK.C_LINE.lightened(0.25)
			hh.add_child(es)
		hh.add_child(_c_rowline(k, DarkKit.TIER_COL[kd - 1]))
		area.add_child(hh)
		for key: String in have:
			var sel: bool = key == D["sel"]
			var row: HBoxContainer = k.h(16)
			var candle_slot := CenterContainer.new()
			candle_slot.custom_minimum_size = Vector2(32, 72)
			if sel:
				candle_slot.add_child(k.glyph(FMK.G_DIAMOND, FMK.C_GOLD, 4))
			row.add_child(candle_slot)
			row.add_child(k.tile(IT.icon(key), 72, DarkKit.TIER_COL[kd - 1]))
			var nv: VBoxContainer = k.v(0)
			nv.alignment = BoxContainer.ALIGNMENT_CENTER
			var nl: Label = FMK.lbl(IT.item_name(key), 32, FMK.C_GOLD if sel else FMK.C_CREAM)
			if sel:
				nl.add_theme_color_override("font_outline_color", Color(0.35, 0.16, 0.04, 1))
				nl.add_theme_constant_override("outline_size", 6)
			nv.add_child(nl)
			var summ: Array = []
			for ln: Array in _item_lines(key):
				summ.append(str(ln[1]))
			nv.add_child(FMK.lbl("  ".join(summ.slice(0, 3)), 24, FMK.C_GOLD_DIM if sel else FMK.C_SUB))
			row.add_child(k.expand(nv))
			row.add_child(k.amt(IT.sell_refund(key), 24, FMK.C_SUB))
			area.add_child(row)
		area.add_child(k.sp(0, 6))


## Sağ sütun: seçili eşya (kutusuz, Ayarlar sağ tarafı gibi ince çizgilerle).
func _c_detail(k, host: Control) -> void:
	var key: String = D["sel"]
	var kd: int = IT.kademe(key)
	var v: VBoxContainer = k.v(10)
	_place(host, v, Vector2(1440, 92), Vector2(420, 880))
	var big: Control = k.tile(IT.icon(key), 104, DarkKit.TIER_COL[kd - 1])
	big.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(big)
	var nl: Label = FMK.lbl(IT.item_name(key), 48, FMK.C_GOLD)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size.x = 420
	v.add_child(nl)
	var tr: HBoxContainer = k.h(14)
	tr.add_child(FMK.lbl(DarkKit.TIER_NAME[kd - 1], 24, DarkKit.TIER_COL[kd - 1]))
	tr.add_child(k.amt(IT.cost(key), 24, FMK.C_SUB))
	v.add_child(tr)
	v.add_child(_c_rowline(k, FMK.C_GOLD))
	for ln: Array in _item_lines(key):
		var r: HBoxContainer = k.h(10)
		r.add_child(_sicon(k, str(ln[0]), 32))
		r.add_child(FMK.lbl(str(ln[1]), 32, Color("#b5d98a")))
		v.add_child(r)
	var pas: String = _passive(key)
	if pas != "":
		v.add_child(FMK.lbl("PASİF", 24, DarkKit.TIER_COL[kd - 1]))
		var pl: Label = FMK.lbl(pas, 32, FMK.C_CREAM)
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pl.custom_minimum_size.x = 420
		v.add_child(pl)
	var rec: Array = IT.recipe(key)
	if not rec.is_empty():
		v.add_child(FMK.lbl("TARİF", 24, FMK.C_SUB))
		var rr: HBoxContainer = k.h(8)
		for rk in rec:
			rr.add_child(k.tile(IT.icon(str(rk)), 56, DarkKit.TIER_COL[IT.kademe(str(rk)) - 1]))
		v.add_child(rr)
	v.add_child(k.sp(0, 18))
	var sell: Button = FMK.item("SAT", "+%d altın (değerinin yarısı)" % IT.sell_refund(key), k.coin(48), false, false)
	sell.custom_minimum_size.x = 420
	v.add_child(sell)


func _c_stats(k, area: VBoxContainer) -> void:
	var hh: HBoxContainer = k.h(12)
	hh.add_child(FMK.lbl("ÖZELLİKLER", 32, FMK.C_GOLD))
	hh.add_child(_c_rowline(k, FMK.C_GOLD))
	area.add_child(hh)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 56)
	grid.add_theme_constant_override("v_separation", 10)
	for s: Array in HSP.STATS:
		var r: HBoxContainer = k.h(14)
		r.custom_minimum_size = Vector2(520, 48)
		r.add_child(k.icon(_stat_tex(str(s[0])), 32))
		r.add_child(k.expand(FMK.lbl(str(s[1]), 32, FMK.C_CREAM)))
		r.add_child(FMK.lbl(str(D["stats"].get(s[0], "-")), 32, FMK.C_GOLD))
		grid.add_child(r)
	area.add_child(grid)
	area.add_child(k.sp(0, 20))
	var hh2: HBoxContainer = k.h(12)
	hh2.add_child(FMK.lbl("SİLAHLAR", 32, FMK.C_GOLD))
	hh2.add_child(_c_rowline(k, FMK.C_GOLD))
	area.add_child(hh2)
	var wr: HBoxContainer = k.h(40)
	for w: Dictionary in D["weapons"]:
		var r: HBoxContainer = k.h(12)
		r.add_child(k.wicon(_weapon_tex(w), 80, int(w["tier"])))
		var v: VBoxContainer = k.v(0)
		v.add_child(FMK.lbl(str(w["name"]), 32, FMK.C_CREAM))
		v.add_child(FMK.lbl("Kademe " + _roman(w), 24, _tier_col(int(w["tier"]), k)))
		v.add_child(FMK.lbl(str(w["trait"]), 24, FMK.C_SUB))
		r.add_child(v)
		wr.add_child(r)
	area.add_child(wr)


## ================================================================ D - GECE SIVASI YAN ÇANTA (telefon + menülerle aynı)
func _build_d(host: Control) -> void:
	var k = DarkKit.new(DarkKit.PAL_NIGHT)
	var win: PanelContainer = k.box(Color(k.c("panel"), 0.97), k.c("line_hi"), 18, 3, 8)
	win.theme = k.theme()
	_place(host, win, Vector2(16, 16), Vector2(712, 1048))
	var col: VBoxContainer = k.v(10)
	win.add_child(col)
	var head: HBoxContainer = k.h(12)
	head.add_child(k.glyph(DarkKit.G_BAG, k.c("accent"), 4))
	head.add_child(k.lbl("ÇANTA", 40, k.c("accent")))
	head.add_child(k.sp(0, 0, true))
	head.add_child(k.amt(int(D["gold"]), 32, k.c("price")))
	head.add_child(k.sp(6))
	head.add_child(k.amt(int(D["shards"]), 32, DarkKit.SHARD_TEXT, "shard"))
	head.add_child(k.sp(6))
	head.add_child(_x_btn(k, 48))
	col.add_child(head)
	## karakter şeridi
	var cs: PanelContainer = k.box(k.c("inset"), k.c("line"), 10, 2, 6)
	var cr: HBoxContainer = k.h(12)
	cr.add_child(k.icon(D["portrait"], 48))
	var cv: VBoxContainer = k.v(0)
	cv.add_child(k.lbl(str(D["char_name"]), 32, k.c("text")))
	cv.add_child(k.lbl("Seviye %d" % int(D["level"]), 24, k.c("dim")))
	cr.add_child(cv)
	cr.add_child(k.sp(0, 0, true))
	var xv: VBoxContainer = k.v(2)
	xv.alignment = BoxContainer.ALIGNMENT_CENTER
	xv.add_child(_bar(k, 260, 14))
	xv.add_child(k.lbl("%d / %d XP" % [int(D["xp"]), int(D["xp_next"])], 24, Color("#d0a8f6"), HORIZONTAL_ALIGNMENT_RIGHT))
	cr.add_child(xv)
	cs.add_child(cr)
	col.add_child(cs)
	## silahlar
	col.add_child(_sec_head(k, DarkKit.G_SWORD, "SİLAHLAR", "%d / %d" % [(D["weapons"] as Array).size(), int(D["max_weapons"])]))
	for w: Dictionary in D["weapons"]:
		var wb: PanelContainer = k.box(k.c("panel2"), k.c("line"), 8, 2, 6)
		var wr: HBoxContainer = k.h(12)
		wr.add_child(k.wicon(_weapon_tex(w), 72, int(w["tier"])))
		var wv: VBoxContainer = k.v(0)
		wv.alignment = BoxContainer.ALIGNMENT_CENTER
		wv.add_child(k.lbl(str(w["name"]), 32, k.c("text")))
		wv.add_child(k.lbl("%s  %s" % [str(w["cat"]), str(w["trait"])], 24, k.c("dim")))
		wr.add_child(k.expand(wv))
		var tv: VBoxContainer = k.v(4)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_child(k.lbl(_roman(w), 32, _tier_col(int(w["tier"]), k), HORIZONTAL_ALIGNMENT_RIGHT))
		tv.add_child(_pips(k, w, 130, 8))
		wr.add_child(tv)
		wr.add_child(k.sp(4))
		wb.add_child(wr)
		col.add_child(wb)
	## kalkan + evcil
	var eq: HBoxContainer = k.h(10)
	var sh: Dictionary = D["shield"]
	var pet: Dictionary = D["pet"]
	for e: Array in [[sh["tex"], str(sh["name"]), "Mana Kalkanı"], [pet["tex"], str(pet["name"]), "Evcil"]]:
		var eb: PanelContainer = k.box(k.c("panel2"), k.c("line"), 8, 2, 6)
		eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var er: HBoxContainer = k.h(10)
		er.add_child(k.icon(e[0], 48))
		var ev: VBoxContainer = k.v(-4)
		ev.add_child(k.lbl(e[2], 24, k.c("dim")))
		ev.add_child(k.lbl(e[1], 32, k.c("text")))
		er.add_child(ev)
		eb.add_child(er)
		eq.add_child(eb)
	col.add_child(eq)
	## eşyalar
	col.add_child(_sec_head(k, DarkKit.G_BAG, "EŞYALAR", "%d / %d yuva" % [_item_count(), _slot_total()]))
	var ib: PanelContainer = k.box(k.c("inset"), k.c("line"), 10, 2, 6)
	var iv: VBoxContainer = k.v(8)
	for kd: int in [3, 2, 1]:
		iv.add_child(_tier_row(k, kd, 60, 7, 140))
	ib.add_child(iv)
	col.add_child(ib)
	## özellikler: LoL tarzı ızgara (simge + değer, ad ipucunda)
	col.add_child(_sec_head(k, DarkKit.G_STAR, "ÖZELLİKLER", "üstüne gel: açıklama"))
	var sb: PanelContainer = k.box(k.c("inset"), k.c("line"), 10, 2, 6)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	for s: Array in HSP.STATS:
		var r: HBoxContainer = k.h(8)
		r.custom_minimum_size = Vector2(152, 30)
		r.add_child(k.icon(_stat_tex(str(s[0])), 24))
		r.add_child(k.lbl(str(D["stats"].get(s[0], "-")), 24, k.c("text")))
		grid.add_child(r)
	sb.add_child(grid)
	col.add_child(sb)
	## ipucu kartı (seçili/üstündeki eşya) - panelin sağında, oyunun üstünde
	var key: String = D["sel"]
	var kd2: int = IT.kademe(key)
	var tip: PanelContainer = k.box(k.c("panel2"), DarkKit.TIER_COL[kd2 - 1], 16, 3, 6)
	tip.theme = k.theme()
	var tvv: VBoxContainer = k.v(8)
	var th: HBoxContainer = k.h(12)
	th.add_child(k.tile(IT.icon(key), 72, DarkKit.TIER_COL[kd2 - 1]))
	var tn: VBoxContainer = k.v(0)
	tn.add_child(k.lbl(IT.item_name(key), 32, k.c("text")))
	tn.add_child(k.lbl(DarkKit.TIER_NAME[kd2 - 1], 24, DarkKit.TIER_COL[kd2 - 1]))
	th.add_child(tn)
	tvv.add_child(th)
	tvv.add_child(_detail_body(k, key, 420))
	var sr: HBoxContainer = k.h(8)
	var hk: PanelContainer = k.box(k.c("inset"), k.c("line_hi"), 4, 2, 3)
	hk.add_child(k.lbl(" Sağ Tık ", 24, k.c("text")))
	sr.add_child(hk)
	sr.add_child(k.lbl("Sat", 24, k.c("dim")))
	sr.add_child(k.sp(0, 0, true))
	sr.add_child(k.amt(IT.sell_refund(key), 24, k.c("price")))
	tvv.add_child(sr)
	tip.add_child(tvv)
	tip.custom_minimum_size.x = 452
	_place(host, tip, Vector2(744, 560))
