---
name: yaratik-yeniden-yazim
description: Yaratık (düşman) sistemini veri odaklı mimariye taşıyan çok oturumlu yeniden yazım işine devam et. Kullanıcı "yeniden yazıma devam", "yaratık sistemine devam et", "kaldığın yerden devam" dediğinde ya da enemy.gd / enemy_spawner.gd / EnemyWorld üzerinde bu işin parçası olan bir değişiklik istendiğinde kullan.
---

# Yaratık yeniden yazımına devam

Bu iş birden çok oturuma ve birden çok Claude hesabına yayılıyor. Önceki oturumun ne yaptığını HAFIZADAN değil
depodaki kayıtlardan öğrenirsin.

## Oturum başı (sırayla, atlama)

1. `git fetch` + `git status`; yerel değişiklik yoksa `git pull` (CLAUDE.md kuralı). Commit edilmemiş değişiklik
   varsa ne olduklarına bak; bu işe ait değilse kullanıcıya sor.
2. `docs/yaratik_yeniden_yazim/PLAN.md` ve `docs/yaratik_yeniden_yazim/ILERLEME.md` dosyalarını BAŞTAN SONA oku.
3. `ILERLEME.md` "Şu an" bölümündeki aşamayı ve sıradaki adımı kullanıcıya bir-iki cümleyle söyle ve DURMADAN işe başla
   (kullanıcı kararı, PLAN §7: aşamalar arasında onay bekleme). Sadece gerçekten kullanıcının vermesi gereken bir karar
   (oyun davranışının değişmesi gibi) varsa sor.
4. Son kayıtta "doğrulanmadı" denen bir şey varsa, üstüne iş koymadan önce onu doğrula.

## Çalışırken

- Planın §4 mimarisine ve §8 tuzaklarına uy. Plandan sapman gerekiyorsa kullanıcıya sor, kabul edilirse PLAN.md'yi güncelle.
- Master hep oynanabilir kalmalı: yeni kod `USE_ENEMY_WORLD` geçiş anahtarının arkasında, aşama doğrulanana kadar varsayılan eski yol.
- Ölçüm/test betiklerini geçici klasöre DEĞİL `tools/enemy_rewrite/` altına koy (sonraki oturum görebilsin).
- Bir alt maddeyi bitirdiğin anda `ILERLEME.md`'de işaretle; kotanın ya da oturumun ne zaman biteceği bilinmez.
- Ölçtüğün her sayıyı `ILERLEME.md` ölçüm tablosuna yaz (tarih, senaryo, yaratık sayısı, ms, µs/yaratık).

## Oturum sonu (ya da bağlam/kota azalıyorsa HEMEN)

1. `ILERLEME.md`: "Şu an" bölümünü güncelle (aşama, tam olarak sıradaki adım, yarım kalan dosya/fonksiyon, bekleyen
   kararlar) ve en üste bir oturum kaydı ekle: ne yapıldı, ne doğrulandı (nasıl), ne doğrulanmadı, ne öğrenildi.
2. Commit/push YOK ve bunun için SORU da yok - kullanıcı söyleyince yapılır (PLAN §7). Kota/oturum aniden biterse
   commit edilmemiş iş diskte kalır; bir sonraki oturum `git status` ile görür - bu yüzden ILERLEME.md'yi HER alt
   maddeden sonra güncel tut. Kullanıcı commit isterse mesaj: "Yaratık yeniden yazımı - Aşama N: ...".
3. Kullanıcıya kısa özet: bu oturumda ne bitti, sıradaki adım ne.
