extends RefCounted

## HOST DEVRİ - saf yardımcılar (2026-10-08, kullanıcı isteği: "host çıkınca host devri de olsun"). Ağ/sahne işi network_manager.gd'de
## ("HOST DEVRİ" bloğu); burada sadece testlenebilen kurallar durur.
##
## ÖZET: oyun sürerken host düşerse (kapattı, çöktü, bağlantısı koptu) kalan oyuncular AYNI sırayla yeni host'u seçer (sıra listesi host'tan
## önceden herkese gelmiş olur), yeni host aynı portta yeni bir sunucu kurar, diğerleri ona bağlanıp "geri katılım" (rejoin) akışından geçer:
## herkes kendi kaydedilmiş durumuyla (kartlar, silahlar, seviye, altın) birkaç saniyelik yükleme ekranından sonra kaldığı yerden devam eder.
## Dünya durumu (yaratıklar, yerdeki drop'lar, süren görevler) yeni Main'de taze kurulur; host'un gizli sayaçları (hangi boss doğdu...) host'un
## periyodik yayınladığı "devir paketi"nden gelir (enemy_spawner.gd export_handover/import_handover).

## Bir aday için bağlanma penceresi: bu sürede yeni host'a girilemezse sıradaki adaya geçilir.
const ATTEMPT_WINDOW_SEC := 10.0
## Tüm devir çabasının üst sınırı: aşılırsa eski davranışa (ana menüye dön) düşülür.
const TOTAL_TIMEOUT_SEC := 55.0
## İnternet odası (Epic P2P): yeni bir eşle ilk bağlantı (NAT delme / Epic relay) LAN'dan çok yavaş olabilir - pencereler uzun.
const ATTEMPT_WINDOW_ONLINE_SEC := 30.0
const TOTAL_TIMEOUT_ONLINE_SEC := 100.0
## Epic: aday henüz sunucuyu kurmadan gönderilen bağlantı isteği ENet gibi kendiliğinden yeniden denemez (asılı kalır) - bu aralıkla yeni istek.
const ONLINE_RETRY_SEC := 5.0
## Bağlantı denemesi başarısız/askıdaysa yeniden deneme aralığı.
const RETRY_INTERVAL_SEC := 1.5
## Host'tan bu kadar süre hiç ağ iletisi (kalp atışı) gelmezse host düşmüş sayılır (ENet'in kendi zaman aşımı 5-30 sn sürebilir).
const HOST_SILENCE_LIMIT_MSEC := 12000
const HEARTBEAT_INTERVAL_SEC := 1.0


## Sıra listesi: bağlı oyunların kimlikleri, katılım sırasıyla (host İLK). players: peer -> {name, char_id,...} (lobby_players),
## peer_uid: peer -> kalıcı kimlik, addr/eos: peer -> adres / Epic kimliği, order: kimliklerin kalıcı sırası, connected: bağlı oyun peer'leri.
## Dönüş: [{"uid", "name", "addr", "eos", "char"}] - order'daki sırayla, sadece bağlı olanlar; order'da olmayan bağlı kimlikler sona eklenir.
static func build_roster(players: Dictionary, peer_uid: Dictionary, addr: Dictionary, eos: Dictionary, order: Array, connected: Array) -> Array:
	var by_uid: Dictionary = {}
	for pid in connected:
		var uid: String = str(peer_uid.get(int(pid), ""))
		if uid == "":
			continue
		var info: Dictionary = players.get(int(pid), {})
		by_uid[uid] = {"uid": uid, "name": str(info.get("name", "Oyuncu")), "addr": str(addr.get(int(pid), "")), "eos": str(eos.get(int(pid), "")),
			"char": int(info.get("char_id", 1))}
	var out: Array = []
	for uid in order:
		if by_uid.has(str(uid)):
			out.append(by_uid[str(uid)])
			by_uid.erase(str(uid))
	for uid in by_uid.keys():
		out.append(by_uid[uid])
	return out


## Düşen host'un kimliği çıkarılmış aday listesi (sıra korunur). Herkes AYNI listeyi görür -> aynı kişiyi seçer.
static func candidates(roster: Array, lost_uid: String) -> Array:
	var out: Array = []
	for e in roster:
		if str((e as Dictionary).get("uid", "")) != lost_uid:
			out.append(e)
	return out


## Roster'ın ilk girişi host'tur (build_roster host'u order'ın başına koyar). Boş roster: "".
static func host_uid(roster: Array) -> String:
	return str((roster[0] as Dictionary).get("uid", "")) if not roster.is_empty() else ""


## Bu oyuncu (my_uid) adaylar arasında kaçıncı? Yoksa -1.
static func index_of(cands: Array, my_uid: String) -> int:
	for i in range(cands.size()):
		if str((cands[i] as Dictionary).get("uid", "")) == my_uid:
			return i
	return -1


## "ip:port" ya da "LAN:port" oda kodundan port; çözülemezse fallback.
static func parse_port(room_code: String, fallback: int = 7777) -> int:
	var idx: int = room_code.rfind(":")
	if idx < 0:
		return fallback
	var tail: String = room_code.substr(idx + 1)
	return int(tail) if tail.is_valid_int() and int(tail) > 0 else fallback


## ENet'in bildirdiği uzak adres boş/yerel ise (host kendi makinesindeki bir süreçle konuşuyorsa) 127.0.0.1 kullanılır.
static func usable_addr(addr: String) -> String:
	return addr if addr != "" else "127.0.0.1"
