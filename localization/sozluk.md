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

## Almanca (de.po, 2026-11-09)
- "du" hitabı; büyük harf başlıklar Almanca büyük harf (FÄHIGKEIT / BASIS / ULTI / PASSIV).
- Bekleme notu "(20 s Abklingzeit)", ondalık VİRGÜL ("1,5 Sekunden"); `_strip_cooldown_note` bu kalıbı da siler.
- Terimler: Kademe = Stufe, Ruh Kıymığı = Seelensplitter, Ruh Mağazası = Seelenladen, Mana Kalkanı = Manaschild, Seyyar Satıcı = Wanderhändler,
  Demirci = Schmied, Silah Parçacığı = Waffensplitter, XP = EP, Efsun = Verzauberung, Can Çalma = Lebensraub, Sıvışma = Ausweichen,
  Saldırı Gücü = Angriffskraft, Saldırı Hızı = Angriffstempo, Hız = Tempo, Babaanne = Oma.
- İpucu renk kelimeleri: hasar=Schaden, can=Leben, kalkan=Schild, zırh=Rüstung, bekleme=Abklingzeit.

## Yedi yeni dil (es / fr / it / pt / pl / ru / zh, 2026-11-09)
- Kodlar: es, fr, it, pt (Brezilya Portekizcesi, `Português (BR)`), pl, ru, zh (Basitleştirilmiş Çince). İşletim sistemi dili
  `OS.get_locale_language()` yalnız dil kodu verdiği için bölge eki yok (pt, zh).
- Hitap: es tú, fr tu, it tu, pt você, pl ty, ru ты, zh 你. Başlık önekleri (ipucu türü): HABILIDAD/BÁSICA/DEFINITIVA/PASIVA,
  COMPÉTENCE/BASE/ULTIME/PASSIF, ABILITÀ/BASE/SUPREMA/PASSIVA, HABILIDADE/BÁSICA/SUPREMA/PASSIVA,
  UMIEJĘTNOŚĆ/PODSTAWOWA/SUPERMOC/PASYWNA, СПОСОБНОСТЬ/БАЗОВАЯ/УЛЬТА/ПАССИВ, 技能/基础/终极/被动 (Çincede önek sonrası ASCII ": ").
- Bekleme notu kalıpları (`skill_icon.gd _strip_cooldown_note` hepsini siler): "(10 s de enfriamiento)", "(10 s de recharge)",
  "(10 s di ricarica)", "(10 s de recarga)", "(10 s odnowienia)", "(10 с перезарядки)", "(10秒冷却)". Yeni dil = buraya + regex'e ekle.
- Kart cümlesi `{stat} {amount} artar`: es "{stat} sube {amount}", fr "{stat} augmente de {amount}", it "{stat} aumenta di {amount}",
  pt "{stat} aumenta {amount}", pl "{stat} rośnie o {amount}", ru "{stat} увеличивается на {amount}", zh "{stat}提高 {amount}".
- Terim tablosu (Kademe / Ruh Kıymığı / Mana Kalkanı / Seyyar Satıcı / Saldırı Gücü):
  es Fase / Fragmento de alma / Escudo de maná / Mercader ambulante / Poder de ataque;
  fr Palier / Éclat d'âme / Bouclier de mana / Marchand ambulant / Puissance d'attaque;
  it Fase / Frammento d'Anima / Scudo di mana / Mercante Ambulante / Potenza d'attacco;
  pt Fase / Fragmento de Alma / Escudo de mana / Mercador ambulante / Poder de ataque;
  pl Etap / Odłamek Duszy / Tarcza many / Wędrowny Kupiec / Siła ataku;
  ru Этап / Осколок души / Щит маны / Странствующий торговец / Сила атаки;
  zh 阶段 / 灵魂碎片 / 法力护盾 / 流浪商人 / 攻击力.
- Büyücü Kız ile Cadı ayrı kalsın: fr Magicienne / Sorcière, es Hechicera / Bruja, ru Чародейка / Ведьма, zh 女术士 / 女巫.
- Karakter özel adları (Talon, Oakley, Matthew, Elara, Necromancer, Shaman, Hadime) her dilde Latin harfli aynen kalır (İngilizcedeki gibi).
- Fransızcada yüzde boşluklu ("50 %"); biçim dizgesi (`%d` içeren) metinde düz yüzde MUTLAKA `%%` ("%d %%"). Ondalık: Çince nokta,
  diğerleri virgül (yalnız elle yazılan metinde; koddan üretilen sayılar hâlâ nokta).
- Çincede "——" ve "—" kullanma (eski font kontrolünde Vonwaon'da yoktu; şimdi monogram yedeği çiziyor ama gerek yok), noktalama tam genişlik (，。：（）).
