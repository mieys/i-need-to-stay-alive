extends RefCounted

## Çalışma anında kurulan ses yolları (proje default_bus_layout.tres kullanmıyor - sadece Master var). TEK kaynak:
##  - AMBIENT: dünyanın konumsuz ortam sesleri (yağmur/rüzgar/fırtına döngüleri, uzak gök gürültüsü, orman ambiyansı).
##    Şovalye Koruma Baloncuğu'nun içindeyken alçak geçiren filtresi açılır (bkz. fx_paladin_barrier.gd). Kullanıcı
##    bildirimi (2026-09-25): "şovalye adamın kalkanının içindeyken sesler boğuklaşmıyor" - konumlu (2D) sesler Area2D
##    bus-override'la zaten boğuluyordu (ölçüldü: kubbe dışındaki noktada alan bulunuyor, içinde bulunmuyor), ama
##    dışarıyı en çok belli eden bu ortam sesleri konumsuz AudioStreamPlayer'dı ve hiç etkilenmiyordu.
##  - MUFFLE: kubbenin dışında çalan konumlu (2D) sesler (Area2D audio_bus_override ile yönlenir).
## İkisi de Master'a gönderir -> ana ses ayarı (ui_sound.gd Master) aynen geçerli.

const AMBIENT_BUS := &"Ambient"
const MUFFLE_BUS := &"BarrierMuffle"
## Kullanıcı bildirimi (2026-09-26): "kalkanın içindeyken dışardan içeri hiç ses çıkmıyor, yağmur boğuk gelmiyor" - eski
## 500 Hz + -6 dB, kulağın en duyarlı olduğu 2-5 kHz'i silip sesi neredeyse YOK ediyordu. Ölçüm (ses dosyalarının kendisi,
## Godot'nun biquad alçak geçireni rezonans 0.5, A-ağırlıklı = algılanan): yağmur -19.6 dB, fırtına rüzgarı -16.2, rüzgar
## -12.6. Şimdi 1200 Hz (tek aşama = varsayılan) + -1 dB: tizler hâlâ sert kesilir (4 kHz'de ~-22 dB, boğuk "duvarın
## arkasından" tını) ama sesin gövdesi kalır - yağmur -8.0, fırtına rüzgarı -5.4, rüzgar -3.3 dB.
const MUFFLE_CUTOFF_HZ := 1200.0
const MUFFLE_VOLUME_DB := -1.0


static func _ensure(bus_name: StringName) -> int:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = MUFFLE_CUTOFF_HZ
	AudioServer.add_bus_effect(idx, lp)
	## Ambient'in filtresi varsayılan KAPALI (sadece kubbe içindeyken açılır); Muffle yolu zaten sadece dış sesleri taşır.
	AudioServer.set_bus_effect_enabled(idx, 0, bus_name == MUFFLE_BUS)
	AudioServer.set_bus_volume_db(idx, MUFFLE_VOLUME_DB if bus_name == MUFFLE_BUS else 0.0)
	return idx


## Konumsuz ortam sesi çalarları bus = ambient_bus() ile kurulur.
static func ambient_bus() -> StringName:
	_ensure(AMBIENT_BUS)
	return AMBIENT_BUS


static func muffle_bus() -> StringName:
	_ensure(MUFFLE_BUS)
	return MUFFLE_BUS


static func set_ambient_muffled(on: bool) -> void:
	var idx: int = _ensure(AMBIENT_BUS)
	AudioServer.set_bus_effect_enabled(idx, 0, on)
	AudioServer.set_bus_volume_db(idx, MUFFLE_VOLUME_DB if on else 0.0)
