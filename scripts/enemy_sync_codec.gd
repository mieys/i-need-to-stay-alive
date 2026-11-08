extends RefCounted

## (class_name YOK: yeni genel sınıflar başsız çalıştırmalarda editör içe aktarmasına kadar görünmez - preload ile kullan.)
## Host -> istemci yaratık durum paketinin SIKIŞTIRILMIŞ ikili biçimi (2026-10-08 MP denetimi bulgusu 5).
## Eskiden her yaratık [id, Vector2, bool, float, float, bool, int, int] dizisiydi: Godot Variant başlıklarıyla yaratık başına ~85 bayt.
## Şimdi yaratık başına 22 bayt (ölünce son vuran peer için +4): 100 yaratıkta ~8,5 KB -> ~2,2 KB/tur. Epic P2P paket sınırına (bkz.
## scripts/net/fragment_peer.gd, ~1100 bayt) bölünmeden sığması için paket başına en çok BATCH yaratık.
##
## Paket: [tick u16] + kayıtlar. Kayıt: net_id u32, x s32, y s32 (1/8 piksel), bayraklar u8 (bit0 ölü, bit1 öfkeli, bit2 son vuran var),
## chill u8, can f32, kalkan f32, [son vuran s32 - bit2 varsa].
## tick: host'un tur sayacı (uint16 sarar). Güvenilmez kanalda paketler sırasız gelebilir; istemci eski turu atar (bkz. is_stale).
## Madde 419 (ağ gecikmesi): bit3 (FLAG_NO_HP) = can/kalkan bu kayıtta YOK (14 bayt) - host değişmeyen can/kalkanı her tur yollamaz
## (değişince birkaç tur üst üste + seyrek yenileme; bkz. enemy_spawner.gd HP_REPEAT_TICKS). Çözümde can/kalkan -1 döner = "dokunma"
## (enemy.gd update_network_state zaten < 0'ı yok sayar). Paketler artık kayıt sayısına değil bayta göre bölünür (MAX_PACKET_BYTES).

const BATCH := 40
const POS_SCALE := 8.0
const FLAG_DEAD := 1
const FLAG_RAGING := 2
const FLAG_ATTACKER := 4
const FLAG_NO_HP := 8
const RECORD_BYTES := 22
const RECORD_BYTES_NO_HP := 14
const HEADER_BYTES := 2
## Paket başına en çok veri baytı (RPC başlığı ~30 bayt ile Epic/FragmentPeer'in 1100 bayt sınırının altında kalır).
const MAX_PACKET_BYTES := 1000


## Bir kaydın bayt boyutu (encode ile aynı kural) - paket bölme için.
static func record_size(s: Array) -> int:
	var n: int = RECORD_BYTES_NO_HP if (s.size() > 8 and s[8] == true) else RECORD_BYTES
	return n + (4 if int(s[7]) > 0 else 0)


## states'i her biri MAX_PACKET_BYTES'ı aşmayan dilimlere böler (sıra korunur).
static func split_by_bytes(states: Array, max_bytes: int = MAX_PACKET_BYTES) -> Array:
	var out: Array = []
	var cur: Array = []
	var size: int = HEADER_BYTES
	for s: Array in states:
		var r: int = record_size(s)
		if not cur.is_empty() and size + r > max_bytes:
			out.append(cur)
			cur = []
			size = HEADER_BYTES
		cur.append(s)
		size += r
	if not cur.is_empty():
		out.append(cur)
	return out


## states: [net_id, pos: Vector2, dead: bool, health, shield, raging: bool, chill: int, attacker: int, (no_hp: bool)] dizileri
## (enemy_spawner'ın eski biçimi; 9. alan isteğe bağlı: true = can/kalkan yazılmaz, bkz. FLAG_NO_HP).
static func encode(tick: int, states: Array) -> PackedByteArray:
	var buf := PackedByteArray()
	var size: int = HEADER_BYTES
	for s: Array in states:
		size += record_size(s)
	buf.resize(size)
	buf.encode_u16(0, tick & 0xFFFF)
	var o: int = HEADER_BYTES
	for s: Array in states:
		var pos: Vector2 = s[1] as Vector2
		var attacker: int = int(s[7])
		var no_hp: bool = s.size() > 8 and s[8] == true
		var flags: int = 0
		if no_hp:
			flags |= FLAG_NO_HP
		if s[2] == true:
			flags |= FLAG_DEAD
		if s[5] == true:
			flags |= FLAG_RAGING
		if attacker > 0:
			flags |= FLAG_ATTACKER
		buf.encode_u32(o, int(s[0]))
		buf.encode_s32(o + 4, roundi(pos.x * POS_SCALE))
		buf.encode_s32(o + 8, roundi(pos.y * POS_SCALE))
		buf.encode_u8(o + 12, flags)
		buf.encode_u8(o + 13, clampi(int(s[6]), 0, 255))
		if no_hp:
			o += RECORD_BYTES_NO_HP
		else:
			buf.encode_float(o + 14, float(s[3]))
			buf.encode_float(o + 18, float(s[4]))
			o += RECORD_BYTES
		if attacker > 0:
			buf.encode_s32(o, attacker)
			o += 4
	return buf


## -> {"tick": int, "states": Array (encode'a verilen biçimde)}. Bozuk/kısa paket: boş durum listesi.
static func decode(data: PackedByteArray) -> Dictionary:
	var out := {"tick": -1, "states": []}
	if data.size() < HEADER_BYTES:
		return out
	out["tick"] = data.decode_u16(0)
	var states: Array = []
	var o: int = HEADER_BYTES
	while o + RECORD_BYTES_NO_HP <= data.size():
		var flags: int = data.decode_u8(o + 12)
		var no_hp: bool = (flags & FLAG_NO_HP) != 0
		var base_len: int = RECORD_BYTES_NO_HP if no_hp else RECORD_BYTES
		if o + base_len > data.size():
			break
		var attacker: int = 0
		var rec_len: int = base_len
		if flags & FLAG_ATTACKER:
			if o + base_len + 4 > data.size():
				break
			attacker = data.decode_s32(o + base_len)
			rec_len += 4
		states.append([
			data.decode_u32(o),
			Vector2(float(data.decode_s32(o + 4)) / POS_SCALE, float(data.decode_s32(o + 8)) / POS_SCALE),
			(flags & FLAG_DEAD) != 0,
			-1.0 if no_hp else data.decode_float(o + 14),
			-1.0 if no_hp else data.decode_float(o + 18),
			(flags & FLAG_RAGING) != 0,
			data.decode_u8(o + 13),
			attacker,
		])
		o += rec_len
	out["states"] = states
	return out


## Sıra numarası eski mi? last: son uygulanan tur (-1 = henüz yok). Aynı tur (aynı turun başka paket grubu) ve bir tur gerisi kabul edilir
## (turun paketleri sırasız gelebilir); daha eskisi (uint16 sarmayı hesaba katarak) atılır.
static func is_stale(tick: int, last: int) -> bool:
	if last < 0 or tick < 0:
		return false
	var diff: int = (tick - last) & 0xFFFF
	if diff == 0:
		return false
	return diff > 0x8000 and diff < 0x10000 - 1


## uint16 sıra numarası `seq`, `last`'tan YENİ mi? (sarmayı hesaba katar; aynı numara yeni sayılmaz.) Oyuncu konum paketleri de bunu kullanır
## (bkz. main.gd _is_stale_transform) - sıra kuralı tek yerde.
static func seq_newer(seq: int, last: int) -> bool:
	var diff: int = (seq - last) & 0xFFFF
	return diff != 0 and diff <= 0x8000
