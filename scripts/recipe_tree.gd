extends RefCounted
const Loc := preload("res://scripts/localization.gd") ## dil desteği: Loc.t / Loc.pct (madde 446)

## TARİF AĞACI - seyyar satıcının ayrıntısı (madde 197) ile level pazarının ayrıntısı (madde 433 ek 5) ORTAK. Kod eskiden
## merchant_shop_screen.gd içindeydi; yerleşim, renkler ve durumlar birebir aynı taşındı (satıcı artık buraya devreder).
##   k        = shop_dark_kit.gd örneği (yuva/yazı/çizgi çizimi)
##   in_stock = func(key) -> bool: alt parça satıcının vitrininde var mı (yuvada "stok" işareti); pazarda verilmez.
## Düğüm durumu: owned = sendeki parça (tüketilecek, Items._obtain ile AYNI sıra), covered = sendeki bir parçanın alt parçası (soluk),
## need = alınması gereken (altında fiyat).

const DarkKit := preload("res://scripts/shop_dark_kit.gd")


## Sahip olunan eşyaların anahtarları (ağaçta "SENDE" eşleşmesi için; her eşleşme havuzdan bir kopya düşer).
static func owned_pool() -> Array:
	var pool: Array = []
	for e in GameManager.owned_items:
		pool.append(str((e as Dictionary).get("key", "")))
	return pool


## levels: kökün altında kaç kat gösterilsin (-1 = hepsi; pazar 1 = yalnız doğrudan alt eşyalar, madde 433 ek 7). Kesilen düğümün
## kendi parçaları ipucunda "Tarif: ..." yazar.
static func data(key: String, pool: Array, covered: bool = false, is_root: bool = true, levels: int = -1) -> Dictionary:
	var st: String = "need"
	if covered:
		st = "covered"
	elif not is_root and pool.has(key):
		pool.erase(key)
		st = "owned"
	var n: Dictionary = {"key": key, "state": st, "kids": []}
	if levels == 0:
		return n
	for comp in Items.recipe(key):
		(n["kids"] as Array).append(data(str(comp), pool, st == "owned" or st == "covered", false, levels - 1 if levels > 0 else -1))
	return n


## Düğüm genişliği = yuva ya da altındaki fiyat/SENDE yazısı (hangisi genişse).
static func width(k, n: Dictionary, s: float, gx: float, fs: int) -> float:
	var own: float = s
	match str(n["state"]):
		"owned":
			own = maxf(s, k.tw("SENDE", fs))
		"need":
			own = maxf(s, k.amt_w(Items.cost(str(n["key"])), fs))
	var kids: Array = n["kids"]
	if kids.is_empty():
		return own
	var w: float = 0.0
	for c: Dictionary in kids:
		w += width(k, c, s, gx, fs)
	w += gx * (kids.size() - 1)
	return maxf(own, w)


static func depth(n: Dictionary) -> int:
	var d: int = 0
	for c: Dictionary in n["kids"]:
		d = maxi(d, depth(c))
	return d + 1


static func height(n: Dictionary, s: float, fs: int) -> float:
	var dep: int = depth(n)
	return dep * (s + fs + 8.0) + (dep - 1) * 8.0 + 6.0


static func gap_for(s: float) -> float:
	return 12.0 if s > 50.0 else 8.0


static func view(k, d: Dictionary, s: float, gx: float, fs: int, in_stock: Callable = Callable()) -> Control:
	var lh: float = fs + 8.0
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ln := DarkKit.Lines.new()
	host.add_child(ln)
	var w: float = width(k, d, s, gx, fs)
	host.custom_minimum_size = Vector2(w + 12.0, height(d, s, fs))
	ln.size = host.custom_minimum_size
	_place(k, d, 6.0, 0, host, ln, Vector2.INF, s, gx, lh, fs, in_stock)
	return host


## Alana (area) sığan EN BÜYÜK yuva boyuyla ağaç (sizes büyükten küçüğe); her boyda önce normal aralık, sığmazsa dar aralık (4 px; geniş
## satırda yer kaplayan fiyat yazılarıdır, yuva değil - madde 433 ek 7); hiçbiri sığmazsa en küçük boy + dar aralık.
const TIGHT_GAP := 4.0
static func fit_view(k, d: Dictionary, area: Vector2, sizes: Array, fs: int, in_stock: Callable = Callable()) -> Control:
	for c in sizes:
		var cs: float = float(c)
		for gx: float in [gap_for(cs), TIGHT_GAP]:
			if width(k, d, cs, gx, fs) + 12.0 <= area.x and height(d, cs, fs) <= area.y:
				return view(k, d, cs, gx, fs, in_stock)
	return view(k, d, float(sizes[sizes.size() - 1]), TIGHT_GAP, fs, in_stock)


## Kök OLMADAN yalnız doğrudan alt eşyaların sırası (level pazarı, madde 433 ek 7: kök zaten ayrıntı başlığında; yer açılınca yuva 104 =
## 48 px sanat 2 kat). d = data(..., levels 1). Sıraya sığan en büyük boy (sizes büyükten küçüğe), her boyda normal sonra dar aralık.
static func fit_row(k, d: Dictionary, area: Vector2, sizes: Array, fs: int) -> Control:
	var kids: Array = d["kids"]
	for c in sizes:
		var cs: float = float(c)
		for gx: float in [gap_for(cs), TIGHT_GAP]:
			if _row_w(k, kids, cs, gx, fs) + 12.0 <= area.x and cs + fs + 14.0 <= area.y:
				return _row_view(k, kids, cs, gx, fs)
	return _row_view(k, kids, float(sizes[sizes.size() - 1]), TIGHT_GAP, fs)


static func _row_w(k, kids: Array, s: float, gx: float, fs: int) -> float:
	var w: float = 0.0
	for c: Dictionary in kids:
		w += width(k, c, s, gx, fs)
	return w + gx * maxi(0, kids.size() - 1)


static func _row_view(k, kids: Array, s: float, gx: float, fs: int) -> Control:
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.custom_minimum_size = Vector2(_row_w(k, kids, s, gx, fs) + 12.0, s + fs + 14.0)
	var ln := DarkKit.Lines.new() ## _place ister; sırada çizgi yok
	var x: float = 6.0
	for c: Dictionary in kids:
		_place(k, c, x, 0, host, ln, Vector2.INF, s, gx, fs + 8.0, fs, Callable())
		x += width(k, c, s, gx, fs) + gx
	ln.free()
	return host


static func _place(k, n: Dictionary, x0: float, d: int, host: Control, ln: DarkKit.Lines, anchor: Vector2, s: float, gx: float, lh: float,
		fs: int, in_stock: Callable) -> void:
	var w: float = width(k, n, s, gx, fs)
	var cx: float = floorf(x0 + w * 0.5)
	var y: float = 6.0 + d * (s + lh + 8.0)
	var key: String = n["key"]
	var st: String = n["state"]
	var stock: bool = d > 0 and st == "need" and in_stock.is_valid() and bool(in_stock.call(key))
	var t: Control = k.tile(Items.icon(key), s, DarkKit.TIER_COL[clampi(Items.kademe(key), 1, 3) - 1],
			{"dim": st == "covered", "owned": st == "owned", "stock": stock})
	t.position = Vector2(cx - s * 0.5, y)
	t.mouse_filter = Control.MOUSE_FILTER_PASS
	t.tooltip_text = Loc.t("%s (%d altın)") % [Loc.t(Items.item_name(key)), Items.cost(key)] + ("  - " + Loc.t("sende var") if st == "owned" else "")
	var rec: Array = Items.recipe(key)
	if (n["kids"] as Array).is_empty() and not rec.is_empty(): ## kat sınırında kesilen düğüm: parçaları ipucunda
		t.tooltip_text += "\n" + Loc.t("Tarif:") + " " + " + ".join(rec.map(func(c) -> String: return Loc.t(Items.item_name(str(c)))))
	host.add_child(t)
	if st != "covered":
		var pl: Control
		var pw: float
		if st == "owned":
			pl = k.lbl("SENDE", fs, k.c("good"))
			pw = k.tw("SENDE", fs)
		else:
			pl = k.amt(Items.cost(key), fs, k.c("price"))
			pw = k.amt_w(Items.cost(key), fs)
		pl.position = Vector2(floorf(cx - pw * 0.5), y + s + 2.0)
		host.add_child(pl)
	if anchor != Vector2.INF:
		var midy: float = floorf((anchor.y + y) * 0.5)
		var col: Color = k.c("good") if st == "owned" else (k.c("line") if st == "covered" else k.c("line_hi"))
		ln.segs.append([PackedVector2Array([anchor, Vector2(anchor.x, midy), Vector2(cx, midy), Vector2(cx, y)]), col, 3.0])
	var kids: Array = n["kids"]
	var kw: float = 0.0
	for c: Dictionary in kids:
		kw += width(k, c, s, gx, fs)
	kw += gx * maxi(0, kids.size() - 1)
	var xs: float = x0 + (w - kw) * 0.5
	for c: Dictionary in kids:
		_place(k, c, xs, d + 1, host, ln, Vector2(cx, y + s + lh - 2.0), s, gx, lh, fs, in_stock)
		xs += width(k, c, s, gx, fs) + gx
