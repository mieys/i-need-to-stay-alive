extends RefCounted

## ENGELE TAKILINCA KAYMA (2026-10-11, kullanıcı: "oyuncu bir yere takılınca hafifçe gidebileceği doğru yöne doğru kayacak smooth bir oynanış").
## Hareket engeli bir hücre sorgusu (bkz. terrain_collision.gd); oyuncu ekseni engelli bulunca o eksen hızını sıfırlıyordu - köşeye/kıyı basamağına
## dik yürüyünce direkt kilitleniyordu. Burada engelli eksende hız sıfırlanır ve (neredeyse) tam karşıdan gidiyorsa, birkaç px yandaki şerit
## açıksa o yana doğru KAYILIR. Engel geniş bir duvarsa (MAX_SHIFT'ten uzun) kayma yok, eskisi gibi durulur. Saf işlev: testlenebilir.

const PROBE := 10.0        ## kökten ileriye yoklama mesafesi (player.gd'nin eski probe_dist'i)
const MAX_SHIFT := 6.0     ## bu kadar px yandaki boşluğa kayılır (köşe/basamak boyu; hücre ortasından bir hücrelik engelin etrafından DOLANMASIN)
const STEP := 2.0
const SLIDE_RATIO := 0.8   ## kayma hızı = engelli eksendeki hızın bu oranı
const HEAD_ON := 0.5       ## yandaki hız, engelli eksen hızının bu oranından küçükse "karşıdan" sayılır (yoksa oyuncu zaten kayıyor)


## pos: oyuncu kökü, vel: istenen hız, blocked: Callable(Vector2) -> bool. Ayarlanmış hızı döndürür.
static func resolve(pos: Vector2, vel: Vector2, blocked: Callable) -> Vector2:
	var out: Vector2 = vel
	var bx: bool = vel.x != 0.0 and blocked.call(pos + Vector2(signf(vel.x) * PROBE, 0.0))
	var by: bool = vel.y != 0.0 and blocked.call(pos + Vector2(0.0, signf(vel.y) * PROBE))
	if bx:
		out.x = 0.0
	if by:
		out.y = 0.0
	if bx and not by and absf(vel.y) < absf(vel.x) * HEAD_ON:
		var d: float = _slide_dir(pos, Vector2(signf(vel.x), 0.0), signf(vel.y), blocked)
		if d != 0.0:
			out.y = d * absf(vel.x) * SLIDE_RATIO
	elif by and not bx and absf(vel.x) < absf(vel.y) * HEAD_ON:
		var d2: float = _slide_dir(pos, Vector2(0.0, signf(vel.y)), signf(vel.x), blocked)
		if d2 != 0.0:
			out.x = d2 * absf(vel.y) * SLIDE_RATIO
	return out


## forward: engelli yöndeki birim vektör (eksen hizalı). Yan eksende -1/+1 (ya da 0 = kayma yok): en kısa kaymayla yoklaması açılan taraf;
## eşitlikte oyuncunun zaten bastığı yan yön (pref), o da yoksa +1.
static func _slide_dir(pos: Vector2, forward: Vector2, pref: float, blocked: Callable) -> float:
	var side := Vector2(forward.y, forward.x) ## forward yatayse (0,±1)'in mutlak hali: yan eksen birim vektörü
	side = Vector2(absf(side.x), absf(side.y))
	var s: float = STEP
	while s <= MAX_SHIFT:
		var free_pos: bool = not blocked.call(pos + side * s + forward * PROBE) and not blocked.call(pos + side * s)
		var free_neg: bool = not blocked.call(pos - side * s + forward * PROBE) and not blocked.call(pos - side * s)
		## Kaymanın kendi yönü de (PROBE kadar) açık olmalı, yoksa kayacağı yerde yine engele çarpar.
		free_pos = free_pos and not blocked.call(pos + side * PROBE)
		free_neg = free_neg and not blocked.call(pos - side * PROBE)
		if free_pos and free_neg:
			return pref if pref != 0.0 else 1.0
		if free_pos:
			return 1.0
		if free_neg:
			return -1.0
		s += STEP
	return 0.0


## ---------------------------------------------------------------------------------------------------------------------------------------
## TAKILINCA YÖN ARAMA (2026-11-13, kullanıcı: "oyuncu bir yere sıkışınca ordan kayarak çıkma sistemi iyi çalışmıyor, gerekirse dönüp o yöne
## doğru gidebileceği bir yön bulana kadar sağa sola yürümeli, engellere doğru sıkışmamalı"). resolve() yalnız 6 px'lik köşeye kayıyordu; ağaç
## gövdesine / bina köşesine / kıyı çıkıntısına karşıdan yürüyen oyuncu orada çakılı kalıyordu. Burada: resolve() oyuncuyu neredeyse durdurduysa
## (ilerleme < STUCK_RATIO), engelli eksenin iki yanı DETOUR_SEARCH px'e kadar taranır; yürünebilir yan yolun sonunda istenen yön açılıyorsa en
## kısa (oyuncunun bastığı yan yönle çelişmeyen) taraf seçilir ve o yana yürünür. Seçim `state`te tutulur (her karede taraf değiştirip titremesin):
## girdi aynı kaldıkça o yana devam, ileri açılınca bırakılır (oyuncu yine istediği yöne yürür), yan yol kapanırsa (çıkmaz) yeniden aranır.
## Bu menzilde açıklık yoksa (geniş duvar, göl) eskisi gibi durulur. Saf işlev + çağıranın tuttuğu sözlük: testlenebilir.

const DETOUR_SEARCH := 80.0       ## yanlara en çok bu kadar px bakılır (5 hücre: ağaç gövdesi, bina köşesi, kaya, kıyı çıkıntısı)
const DETOUR_STEP := 4.0
const DETOUR_RATIO := 0.9         ## yana yürüme hızı = istenen hızın bu oranı
const STUCK_RATIO := 0.5          ## resolve() sonrası hız istenenin bu oranından azsa "takıldı" sayılır
const KEEP_DOT := 0.95            ## girdi yönü bu kadar aynı kaldıkça seçilen tarafa devam (yoksa seçim bırakılır)
const DETOUR_MAX_TRAVEL := 120.0  ## tek bir dolanmada en çok bu kadar yan yürünür (güvenlik)


## state: çağıranın sakladığı boş sözlük (player.gd _wall_detour). Dolanma sürerken state["side"] yürünen yan yöndür (yüz yönü için).
static func resolve_detour(pos: Vector2, vel: Vector2, blocked: Callable, state: Dictionary) -> Vector2:
	var out: Vector2 = resolve(pos, vel, blocked)
	var spd: float = vel.length()
	if spd < 0.1:
		state.clear()
		return out
	var want: Vector2 = vel / spd
	if not state.is_empty():
		var keep: bool = want.dot(state["want"]) >= KEEP_DOT and pos.distance_to(state["start"]) < DETOUR_MAX_TRAVEL
		if keep:
			var fwd: Vector2 = state["fwd"]
			if _opens(pos, fwd, blocked):
				state.clear()
				return out ## yol açıldı: istenen yöne devam
			var side: Vector2 = state["side"]
			if not blocked.call(pos + side * PROBE):
				return side * spd * DETOUR_RATIO
		state.clear() ## girdi değişti / çıkmaz / çok uzadı: baştan ara
	if out.length() >= spd * STUCK_RATIO:
		return out
	var best_cost: float = INF
	var best_fwd := Vector2.ZERO
	var best_side := Vector2.ZERO
	for axis in [0, 1]:
		var comp: float = vel.x if axis == 0 else vel.y
		if absf(comp) < 0.01:
			continue
		var fwd2: Vector2 = Vector2(signf(comp), 0.0) if axis == 0 else Vector2(0.0, signf(comp))
		if not blocked.call(pos + fwd2 * PROBE):
			continue ## bu eksen engelli değil
		var side_axis: Vector2 = Vector2(0.0, 1.0) if axis == 0 else Vector2(1.0, 0.0)
		var side_comp: float = vel.y if axis == 0 else vel.x
		for sgn: float in [1.0, -1.0]:
			var side2: Vector2 = side_axis * sgn
			var s: float = _opening_distance(pos, fwd2, side2, blocked)
			if s < 0.0:
				continue
			var cost: float = s
			if side_comp * sgn < 0.0:
				cost += absf(side_comp) / spd * DETOUR_SEARCH ## oyuncunun bastığı yanın tersine gitmek pahalı
			if absf(comp) < spd * 0.5:
				cost += DETOUR_SEARCH * 0.25 ## ikincil eksenin dolanması (çapraz girdide) ana eksenden sonra
			if cost < best_cost:
				best_cost = cost
				best_fwd = fwd2
				best_side = side2
	if best_side == Vector2.ZERO:
		return out ## menzilde açıklık yok (geniş duvar / göl): dur
	state["want"] = want
	state["fwd"] = best_fwd
	state["side"] = best_side
	state["start"] = pos
	return best_side * spd * DETOUR_RATIO


## İleri yön buradan gerçekten açık mı (tek piksellik çentiğe girip yeniden takılmasın diye bir adım daha derin bakılır).
static func _opens(q: Vector2, fwd: Vector2, blocked: Callable) -> bool:
	return not blocked.call(q + fwd * PROBE) and not blocked.call(q + fwd * (PROBE + DETOUR_STEP))


## side yönünde yürüyerek kaç px sonra ileri (fwd) açılıyor; yan yol önce kapanırsa ya da menzilde açılmıyorsa -1.
## Yürüme kuralı resolve() ile aynı: kökten PROBE ilerisi boş olmalı.
static func _opening_distance(pos: Vector2, fwd: Vector2, side: Vector2, blocked: Callable) -> float:
	var s: float = 0.0
	while s < DETOUR_SEARCH:
		if blocked.call(pos + side * (s + PROBE)):
			return -1.0
		s += DETOUR_STEP
		if _opens(pos + side * s, fwd, blocked):
			return s
	return -1.0
