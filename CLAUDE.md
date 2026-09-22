# Proje notu: Multiplayer'da "yeni yetenek eklerken eskisi kalıyor" hatası

Bu proje Godot 4 tabanlı, co-op multiplayer bir top-down 2D oyun
(`scripts/network_manager.gd` + `scripts/player.gd` + `scripts/remote_player.gd`
üçlüsü ağ senkronunu yönetiyor). Bu dosya, tekrar tekrar karşılaşılan TEK bir
hata sınıfını ve onu nasıl önleyeceğini anlatıyor — yeni bir yetenek/efekt/
animasyon eklerken **mutlaka** oku.

## Hata sınıfı

Kaster (yeteneği kullanan oyuncu) kendi ekranında yeni efekti/animasyonu
doğru görür, ama **diğer oyuncularda eski efekt kalır ya da hiçbir şey
görünmez.** `scripts/player.gd` içindeki geçmiş yorumlarda bunun tam olarak
aynı kök nedenle defalarca yaşandığı görülüyor (ör. `_spawn_buyucu_meteor_
strike`'ın üstündeki "ziva agent" notu, `remote_player.gd`'deki "Meteor
kanalı uzak ekranlarda donuyor" notu, `_weapon_is_orbit_sword` notu).

**Kök neden:** Bu proje mimarisinde her oyuncunun görsel efektleri/
animasyonları KENDİ istemcisinde üretilir, sonra `NetworkManager.
broadcast_player_vfx` RPC'siyle (ya da senkronize edilen bir state/anim
adıyla) diğer istemcilere AYRICA bildirilir. Yani neredeyse her yeni yetenek
için **iki ayrı yerde** aynı bilgiye (bir sahne yolu, bir animasyon adı, bir
formül) referans verilir. Biri eklenirken/değiştirilirken diğeri unutulursa,
diğer oyuncularda eski/hiç görsel kalır.

## Yeni bir yetenek/efekt eklerken kontrol listesi

1. **Tek seferlik, karaktere bağlı bir FX sahnesi mi?** (ör. bir büyü
   overlay'i, bir buff parıltısı) → `player.gd`'deki
   **`_play_and_broadcast_skill_fx(scene: PackedScene)`** yardımcısını
   kullan. Bu fonksiyon local `instantiate()`'ı VE broadcast'i tek çağrıda
   yapar, yolu `scene.resource_path`'ten okur — elle ikinci bir String yol
   yazmana gerek YOK, yani bu iki yer birbirinden sapamaz.
   ```gdscript
   # Eskiden (İKİ ayrı referans, biri unutulabilir):
   if FxYeniEfekt:
       var fx := FxYeniEfekt.instantiate() as Node2D
       add_child(fx)
   _broadcast_skill_scene("res://scenes/fx_yeni_efekt.tscn")

   # Şimdi (TEK referans):
   _play_and_broadcast_skill_fx(FxYeniEfekt)
   ```

2. **Dünya konumunda sabit duran bir efekt mi?** (meteor, patlama,
   telegraph halkası) → `_spawn_world_explosion_fx` / `_spawn_local_
   telegraph_ring` gibi mevcut konum-tabanlı yardımcıları örnek al; bunlar
   zaten `NetworkManager.broadcast_player_vfx.rpc(...)` çağırıyor.
   `network_manager.gd`'deki `broadcast_player_vfx` fonksiyonunun `match
   vfx_type:` bloğuna yeni bir dal eklemen gerekebilir — eklersen, o dalın
   üstündeki yorumdaki `vfx_type` listesine de ekle (bkz. fonksiyonun
   hemen üstündeki liste).

3. **Sürekli/karede-karede simüle edilen bir görsel mi?** (ör. dönen
   silah, orbit eden bir mermi) → Bunlar performans için AĞDAN POZİSYON
   ALMAZ, her istemci KENDİ kopyasını AYNI formülle hesaplar (bkz.
   `scripts/weapon_orbit_math.gd`). Bu tür bir şey eklersen, formülü
   `weapon.gd` (yetkili/gerçek) VE `remote_player.gd` (kozmetik kopya)
   içine AYRI AYRI YAZMA — `weapon_orbit_math.gd` gibi paylaşılan bir
   `static func` çıkar, iki taraf da onu çağırsın. Böylece formülü
   değiştirdiğinde tek yeri değiştirmen yeterli olur.

4. **Yeni bir animasyon adı mı ekliyorsun?** (ör. yeni bir `spellcast_*`
   ya da `attack_*` klibi) → `remote_player.gd`'nin `update_position_and_
   anim_from_net` fonksiyonu, gelen animasyon adı o karakterin
   `SpriteFrames`'inde YOKSA **sessizce hiçbir şey yapmaz** (`anim.sprite_
   frames.has_animation(cur_anim)` kontrolü) — hata vermez, sadece diğer
   oyuncuda eski kare donmuş kalır. Yeni animasyonu eklerken karakterin
   `SpriteFrames` kaynağına da (bkz. `characters.gd`) eklediğinden emin ol,
   yoksa bu TAM OLARAK "yanlış/eski animasyon" belirtisini verir.

5. **Sürekli döngüde oynaması gereken bir animasyon mu?** (kanal/channel
   efektleri, örn. büyücünün meteor kanalı) → `update_position_and_anim_
   from_net`, animasyon ADI DEĞİŞMEDİĞİ sürece `anim.play()` çağırmaz.
   Kanal boyunca aynı animasyon adını tekrar tekrar gönderiyorsan, bitince
   kendi kendine döngü yapmayan (`loop=false` / tek karede duran) bir
   animasyonsa, `player.gd`'deki ilgili `_process_*` fonksiyonunda
   `anim.play(...)`'ı `not anim.is_playing()` kontrolüyle yeniden
   tetiklediğinden VE `remote_player.gd`'de de aynı `elif cur_anim.begins_
   with("...") and not anim.is_playing(): anim.play(cur_anim)` dalının
   olduğundan emin ol (bkz. `_process_buyucu_meteor` / `update_position_
   and_anim_from_net` içindeki mevcut örnek — meteor kanalı bu yüzden
   donuyordu, aynı deseni yeni yetenekte de tekrarlama).

6. **Klip ADI kuralları artık TEK yerde: `scripts/char_anim.gd`.** Yetenek
   klibi (`shrug_<yön>` yeni setlerde, `spellcast_<yön>` eskilerde) ve
   "bitene kadar ezilmez" aksiyon klipleri (`attack`/`spellcast`/`shrug_`/
   `hurt_`/`eat_`) buradaki `CAST_PREFIXES`/`ACTION_PREFIXES`'ten okunur —
   hem `player.gd` (`_update_animation`, `_play_cast_animation`) hem
   `remote_player.gd` (`is_cast_anim`) aynı listeyi kullanır. Yeni bir
   tek seferlik aksiyon klibi (ör. `pickup_`/`strike_`) oyuna bağlarsan ön
   ekini `ACTION_PREFIXES`'e ekle, yoksa yürüme/bekleme klibi onu yarıda
   keser. Bir yetenek `_activate_skill*` makinesini bypass ediyorsa
   (Vampir R gibi toggle'lar) cast klibini kendi fonksiyonunda
   `_play_cast_animation()` ile elle oynat.
   Dükkan/kart ekranı açıkken oynayan `read_` klibi bir ekran-grubuna
   bağlıdır: yeni bir dükkan/kart ekranı eklersen `_enter_tree()`'de
   `add_to_group(ReadingUiWatcher.GROUP)` yap (bkz.
   `scripts/reading_ui_watcher.gd`) — `get_tree().paused` yapan ekranlarda
   bile çalışır, ekran kapanınca kendiliğinden biter.

## Test/doğrulama

Yeni bir yetenek/efekt eklediğinde, TEK bilgisayarda iki pencere açıp
(host + client, ya da `Co-op.exe` ile ikinci bir istemci) yeteneği HOST
OLMAYAN oyuncuyla kullan ve diğer pencerede doğru göründüğünü kontrol et —
kendi ekranında (kaster tarafında) her zaman doğru görünür, gerçek test
DİĞER istemcide izlemektir.

## Kod değişikliği = exe'ye otomatik yansımaz (export ELLE/KOMUTLA yapılan ayrı bir adım)

Kullanıcı bildirimi (2026-09-16): kod dosyalarını düzelttikten sonra
kullanıcı oyunu exportlayıp oynadığında değişiklikler bazen hiç görünmüyordu
- "aynı eski sürümü oynamak gibi" hissi veriyordu. Kök neden KOD hatası
DEĞİLDİ: Godot'ta script/sahne dosyalarını değiştirmek exportlanmış .exe'yi
OTOMATİK güncellemiyor - export, o ANKİ proje durumunun ELLE/KOMUTLA alınan
bir "anlık görüntüsü". Masaüstünde kullanıcının test ettiği en az iki ayrı
.exe kopyası var:
- `../../Oynanabilir versiyon/I need to stay alive.exe` (export_presets.cfg
  "Windows Desktop" preset'inin gerçek export_path'i - tek oyunculu/genel
  test için kullanılan "asıl" build)
- Proje klasörünün İÇİNDE bir "Co-op (isim değişebilir).exe" - yukarıdaki
  "Test/doğrulama" bölümünün bahsettiği İKİNCİ multiplayer test istemcisi
  (aynı .exe'nin ikinci bir kopyası, host olmayan oyuncu rolünde açılıyor)

**DÜZELTME (kullanıcı bildirimi, aynı gün): "bundan sonra bir değişiklik
yaptığında... projeyi exportlamıyosundur umarım, ben sadece export ayarı
olarak projenin güncel halini exportlasın istedim, her seferinde ben
exportladığımda Godot'tan."** - yukarıdaki "her görev sonunda otomatik
export al" kuralı YANLIŞ anlaşılmıştı ve GERİ ALINDI. Claude BUNDAN SONRA
kod değiştirdikten sonra KENDİLİĞİNDEN export ALMAZ/exe'nin üzerine
YAZMAZ - export tamamen kullanıcının kendi kontrolünde, Godot editöründen
kendisi ne zaman isterse o zaman alır. Yukarıdaki export komutu/yol bilgisi
sadece REFERANS için burada duruyor (kullanıcı "export'u sen al" diye
AÇIKÇA isterse kullanılır) - varsayılan davranış DEĞİL. Kod bir görevi
bitirdiğinde kullanıcıya sadece "değişiklikler kaydedildi, test etmeden
önce Godot'tan yeniden export almayı unutma" gibi bir hatırlatma yeterli.

Ayrıca: kullanıcı Godot EDİTÖRÜNÜ projede AÇIK tutuyor olabilir. Bir .tscn
dosyasını editör dışından (metin olarak) düzenlersen ve o sahne editörde
AÇIKKA kalıp kullanıcı sonradan editörden "Kaydet"e basarsa, editördeki ESKİ
bellek içi hali senin değişikliğinin ÜZERİNE yazıp onu sessizce geri
alabilir - bu ihtimali unutma, şüpheli bir "değişiklik kayboldu" durumunda
bunu da sorgula.

## Proje artık paylaşılıyor: arkadaşla birlikte, ikisi de kendi Claude'uyla

Kullanıcı bildirimi (2026-09-17): GitHub'daki mieys/i-need-to-stay-alive
reposu bir arkadaşla (collaborator olarak) paylaşılıyor - o da kendi Claude
Code oturumundan bu projede değişiklik yapacak. Bilinçli tercih: branch/PR
akışı YOK, ikisi de DOĞRUDAN master'a push ediyor. Bu dosyayı okuyan HER
Claude oturumu (kullanıcının ya da arkadaşının) şunları uygulamalı:

1. **Bir göreve başlamadan ÖNCE `git fetch` + `git status` çalıştır, yerel
   değişiklik yoksa `git pull` ile çek.** Diğer kişi senin son
   baktığından beri push etmiş olabilir; onu çekmeden üstüne kod yazarsan
   ya push reddedilir ya da (daha kötüsü) onun değişikliğinin üzerine
   yazarsın. Bu adım salt-okunur/geri alınabilir (fast-forward) olduğu
   için ayrıca onay gerektirmez.
2. **Görev bitince commit edilmemiş değişiklik varsa kullanıcıya söyle ve
   push etmek isteyip istemediğini SOR** - otomatik commit/push YOK, genel
   kural budur (yalnızca kullanıcı açıkça isteyince commit/push et). Ama
   bu repo artık paylaşıldığı için bu hatırlatmayı ATLAMA: değişiklik push
   edilmeden diğer kişide GÖRÜNMEZ - "sürekli güncel kalma" beklentisi tam
   burada kırılıyor.
3. **Push reddedilirse ("! [rejected]" / "fetch first")** asla `--force`
   KULLANMA - diğer kişinin işini SİLEBİLİR. Bunun yerine `git pull`
   (merge) yap; gerçek bir çakışma çıkarsa kullanıcıya göster, kendi
   başına "kazananı" seçme.
4. **Binary asset dosyaları (`.png`, ses dosyaları, `.import`) git'te satır
   satır BİRLEŞTİRİLEMEZ** - iki taraf aynı asset'i aynı anda değiştirirse
   biri diğerini sessizce ezer, git bunu bir "conflict" olarak bile
   göstermeyebilir (sadece son push kazanır). `git pull` sonrası "both
   modified" bir binary dosya görürsen kullanıcıya sor, tahmin etme.
