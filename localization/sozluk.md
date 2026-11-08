# Çeviri sözlüğü (madde 446)

Oyunun terimleri her yerde AYNI karşılıkla çevrilir. Yeni terim çıkınca önce buraya ekle, sonra .po'ya yaz.
İngilizcede aynı kalan metin (oyun adı, tuş adları, `%dx%d`) msgstr'ye msgid'in aynısı yazılır ki "çevrildi" sayılsın.

| Türkçe | English | Not |
|---|---|---|
| Kademe | Tier | "KADEME III BAŞLADI" -> "TIER III BEGINS" |
| Ruh Kıymığı / kıymık | Soul Shard / shard | |
| Ruh Mağazası | Soul Shop | |
| Mana Kalkanı | Mana Shield | |
| Kalkan (can üstü) | Shield | |
| Efsun | Enchant | |
| Silah parçacığı | Weapon Shard | |
| Seyyar Satıcı | Wandering Merchant | |
| Demirci | Blacksmith | |
| Yetenek (Q/E/R) | Ability | |
| Ulti | Ultimate | |
| Ruhani Yetenek | Spirit Ability | |
| Evrim | Evolution | |
| Takas kartı | Trade-off card | |
| Elit | Elite | |
| Saldırı Gücü (SG) | Attack Power (AP) | |
| Saldırı Hızı | Attack Speed | |
| Can Çalma | Lifesteal | |
| Sıvışma | Evasion | |
| Şans | Luck | |
| Diriltme hakkı / kalp | Revive / heart | |
| Rekor | Record | |
| Başarım | Achievement | |
| Koşu | Run | |
| Sonsuz Mod | Endless Mode | |
| Kopyanı Öldür | Kill Your Copy | görev |
| Ağacı Koru | Protect the Tree | görev |
| Saklanma çalılığı | Hiding brush | |
| Ev kuşatması | House siege | |
| Babaanne | Grandma | |
| Zindan | Dungeon | |

## Biçim kuralları
- Yüzde: Türkçe `%50` -> İngilizce `50%` (kalıp `"%%%d"` -> `"%d%%"`).
- Yer tutucular (`%d`, `%s`, `%02d`, `%.1f`) çeviride AYNI sayıda ve AYNI sırada olmalı (test denetler).
- Büyük harfli başlıklar büyük harfle çevrilir (GENEL -> GENERAL).

## Özel kalıplar (kod bunlara güvenir)
- Yetenek açıklamasındaki bekleme notu `(20sn bekleme)` İngilizcede `(20s cooldown)` yazılmalı: ipucu bu notu iki biçimde de silip
  bekleme süresini başlıkta canlı gösterir (`skill_icon.gd _strip_cooldown_note`).
- Kart cümlesi kalıbı `{stat} {amount} artar` -> `{stat} increases by {amount}`: `{stat}` ve `{amount}` AYNEN kalmalı (renklendirilir).
  Stat ifadeleri "senin ..." hâli: "canın" -> "your health".
- Yetenek ipucu renklendirdiği kelimeleri çevirisiyle arar: hasar=damage, can=health, kalkan=shield, zırh=armor, saldırı hızı=attack speed,
  bekleme=cooldown, ULTİ=ULTIMATE, TEMEL=BASIC, PASİF=PASSIVE. Açıklama çevirilerinde bu kelimeler aynen geçmeli ki renklensin.
- `sn` -> `s` ("%d sn" -> "%ds").
