# Yaratık sistemi yeniden yazımı - İLERLEME

> Plan: `PLAN.md`. Her oturumun SONUNDA en üste yeni bir kayıt ekle (en yeni üstte). "Şu an" bölümünü her zaman güncel
> tut - bir sonraki oturum (başka hesap olabilir) SADECE bunu okuyarak devam edebilmeli. Yarım kalan iş varsa tam olarak
> hangi dosyada, hangi fonksiyonda kaldığını yaz; doğrulanmamış şeyi "doğrulandı" diye yazma.

## Şu an

- **Aşama:** 0 (başlamadı)
- **Sıradaki adım:** Aşama 0'ın ilk maddesi - `tools/enemy_rewrite/bench_current.gd` (bugünkü sistemin ölçümü).
- **Bekleyen kullanıcı kararları:** yok. Alınanlar (PLAN §7): master + geçiş anahtarı; commit/push SADECE kullanıcı söyleyince (sorma); aşamalar arasında durmadan devam; dil kararını Aşama 0 ölçümüne göre Claude verir.
- **Başlangıç noktası:** yeniden yazım öncesi tüm iş 2026-10-03'te commit + push edildi (kullanıcı isteğiyle) - commit mesajı "Yeniden yazım öncesi" ile başlıyor; geri dönüş noktası o.
- **Geçiş anahtarı:** henüz yok (Aşama 1'de `scripts/enemy_world/enemy_world_config.gd`).

## Aşama kontrol listesi

Aşama 0: [ ] bench_current  [ ] bench_soa_gd  [ ] (bench_soa_cpp)  [ ] sonuç tablosu  [ ] dil kararı
Aşama 1: [ ] diziler+ızgara  [ ] akış alanı  [ ] hareket/itilme/duvar/knockback  [ ] hedef+yakın saldırı  [ ] ince düğüm+animasyon+y-sort  [ ] 1000 yaratık ölçümü
Aşama 2: [ ] arayüz §3.1  [ ] hasar/ölüm/düşmeler/elit/boss  [ ] durum etkileri  [ ] 70 isabet yakalayıcısı  [ ] grup taramaları
Aşama 3: [ ] görsel ayrıntılar  [ ] sürü çizim ölçümü
Aşama 4: [ ] aile yetenekleri  [ ] boss/kademe/elit/görev/debug
Aşama 5: [ ] multiplayer  [ ] testler+Android  [ ] eski yolu sil

## Ölçümler

| Tarih | Senaryo | Yaratık | Sistem | Ortalama kare (ms) | p95 (ms) | Yaratık başına (µs) | Not |
|---|---|---|---|---|---|---|---|
| 2026-09-27 | eski ölçüm, Korsan, yürüyüş | 160 | eski | 9,7 | 15,6 | ~30 | taban (bkz. PLAN §2) |

## Oturum kayıtları (en yeni üstte)

### 2026-10-03 - plan kuruldu (hesap: ilk hesap)
- Kullanıcı tam yeniden yazıma karar verdi; kotası bitince başka hesaptan devam edeceğini söyledi -> devir düzeni kuruldu:
  `docs/yaratik_yeniden_yazim/PLAN.md` + bu dosya + `.claude/skills/yaratik-yeniden-yazim/SKILL.md` + CLAUDE.md §9.
- Kapsam ölçüldü (PLAN §3). Kod değişikliği yok.
