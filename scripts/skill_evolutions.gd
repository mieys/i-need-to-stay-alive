extends RefCounted

## ==============================================================================
## YETENEK EVRİMLERİ (kullanıcı isteği 2026-09-28)
## ==============================================================================
## (2026-09-30: Assasin Çocuk da eklendi - 9 karakter. 2026-10-04: Shaman da - 10 karakter; aynı gün Büyücü Kız - 11 karakter.)
## "her 5 levelde bir her karaktere oynadığı karaktere göre 3 kart sunulacak ... kartlar rasgele olacak ... Bir skillin 4
## geliştirmesini de aldığında final geliştirme kartların arasına karışıp şans eseri denk gelebilecek. Temel skillerin 5
## ultinin 3 geliştirmesi bulunur". Soru-cevapla netleşenler:
##  - Evrim kartları 5/10/15... seviyelerde NORMAL level kartlarının YERİNE gelir (o seviyede stat kartı çıkmaz). Havuzda
##    evrim kalmadıysa (ya da karakterin evrimi henüz yazılmadıysa) o seviyede normal kartlar gösterilir.
##  - Sadece AÇIK yeteneklerin evrimleri çıkar (R 10. seviyede açılır - bkz. Characters.skill_unlock_level).
##  - Geliştirmelerin sırası yok (1-4 rastgele); FİNAL ancak o yeteneğin diğer TÜM geliştirmeleri alınınca havuza girer.
##    Elara R / Matthew R'de "final" yazmıyordu - kullanıcı: 3. geliştirme final sayılsın.
##  - Evrim ekranında karıştırma (reroll) YOK.
##
## TEK KAYNAK: kart metinleri, ad/kimlikler ve havuz kuralı burada. Etkiler player.gd'de has_evo("<id>") ile okunur (ağdaki
## kopya için remote_player.gd has_evo - main.gd extra["evo"] listesinden), yani bir evrimin sayısını değiştiren hem buradaki
## metni hem player.gd'deki "EVO_*" sabitini güncellemeli (ikisi yan yana, aynı adla aranabilir).
## Yeni bir karakterin evrimlerini eklemek: DEFS'e roster id'siyle "skill"/"skill2"/"skill3" listeleri (son eleman
## "final": true) + player.gd'de etkiler. Liste boşsa o karakter evrim kartı görmez.

const LEVEL_INTERVAL := 5
## level_up_screen.gd evrim kartının upgrade_chosen kimliği: "evo:<evrim id>" (main.gd _on_upgrade_chosen ayırır).
const CHOICE_PREFIX := "evo:"
const OFFER_COUNT := 3
const SLOTS := ["skill", "skill2", "skill3"]
const SLOT_KEYS := {"skill": "Q", "skill2": "E", "skill3": "R"}

## roster id -> yuva -> [ {id, name, desc, final?} ... ] (final her zaman listenin sonunda)
const DEFS := {
	## ---------------------------------------------------------------- Suriyeli Hadime
	14: {
		"skill": [
			{"id": "hadime_q1", "name": "Patlayan Lanet", "desc": "Lanet isabet ettiğinde patlar ve çevresindeki yaratıklara verdiği hasarın %70'i kadar hasar verir."},
			{"id": "hadime_q2", "name": "Hafif Süzülüş", "desc": "Lanet Kitabı artık seni yavaşlatmaz; açıkken %10 hareket hızı kazanırsın."},
			{"id": "hadime_q3", "name": "Tutumlu Okuma", "desc": "Lanet Kitabı saniyede %50 daha az kalkan harcar."},
			{"id": "hadime_q4", "name": "Hızlı Okuma", "desc": "Saldırı hızına bağlı olarak lanetleri daha hızlı yaratıp gönderirsin."},
			{"id": "hadime_qf", "name": "Çifte Lanet", "desc": "Her seferinde gönderdiğin lanet sayısı 2 katına çıkar (3 yerine 6).", "final": true},
		],
		"skill2": [
			{"id": "hadime_e1", "name": "Genişleyen Boşluk", "desc": "Kara deliğin boyutu %50 artar."},
			{"id": "hadime_e2", "name": "Gezgin Delik", "desc": "Kara delik kalabalık yaratıklara doğru ilerler ve içine çektiklerini kendisiyle sürükler."},
			{"id": "hadime_e3", "name": "Kalkan Emici", "desc": "Kara delik verdiği hasarın %20'si kadar kalkanını yeniler."},
			{"id": "hadime_e4", "name": "Hızlı Çöküş", "desc": "Kara deliğin bekleme süresi %30 azalır."},
			{"id": "hadime_ef", "name": "Süpernova", "desc": "Kara delik ömrünün sonunda patlar ve içindeki yaratıklara saldırı gücünün %150'si kadar hasar verir.", "final": true},
		],
		"skill3": [
			{"id": "hadime_r1", "name": "Uzun Kabus", "desc": "Karabasan formunun süresi 5 saniye artar."},
			{"id": "hadime_r2", "name": "Tekrarlayan Kabus", "desc": "Karabasan formunun bekleme süresi %25 azalır."},
			{"id": "hadime_rf", "name": "Bedelsiz Kabus", "desc": "Karabasan formu aktifken yeteneklerin kalkan harcamaz.", "final": true},
		],
	},
	## ---------------------------------------------------------------- Vampir Çocuk
	13: {
		"skill": [
			{"id": "vampir_q1", "name": "Kan Bağı", "desc": "Kan Emme'yi her kullandığında maksimum canın kalıcı olarak 1 artar."},
			{"id": "vampir_q2", "name": "Açlık", "desc": "Kan Emme'nin bekleme süresi %50 azalır."},
			{"id": "vampir_q3", "name": "Kanla Beslenme", "desc": "Kan Emme ile verdiğin hasarın %3'ü kadar can yenilersin."},
			{"id": "vampir_q4", "name": "Kan Kalkanı", "desc": "Kan Emme ile verdiğin hasarın %6'sı kadar kalkan yenilersin."},
			{"id": "vampir_qf", "name": "Kan Ziyafeti", "desc": "Kan Emme 4 yerine 5 yaratığın kanını emer.", "final": true},
		],
		"skill2": [
			{"id": "vampir_e1", "name": "Gölge Kanatlar", "desc": "Yarasa formundayken aldığın hasar %70 azalır."},
			{"id": "vampir_e2", "name": "Gece Uçuşu", "desc": "Yarasa formunun hareket hızı bonusu %60'a çıkar ve duvarların üstünden uçabilirsin."},
			{"id": "vampir_e3", "name": "Çabuk Dönüşüm", "desc": "Yarasa formunun bekleme süresi %25 azalır."},
			{"id": "vampir_e4", "name": "Kanat Darbesi", "desc": "Yarasa formundayken çarptığın yaratıkları yolundan savurursun."},
			{"id": "vampir_ef", "name": "Silahlı Yarasa", "desc": "Yarasa formundayken silahlarını kullanabilirsin.", "final": true},
		],
		"skill3": [
			{"id": "vampir_r1", "name": "Büyüyen Sürü", "desc": "Yarasa sayısı 2 artar."},
			{"id": "vampir_r2", "name": "Hızlı Kanatlar", "desc": "Yarasaların uçuş hızı %40 artar."},
			{"id": "vampir_rf", "name": "Kan Patlaması", "desc": "Yarasalar vurdukları yaratığın çevresinde kan patlatır; her patlama saldırı gücünün %10'u kadar hasar verir.", "final": true},
		],
	},
	## ---------------------------------------------------------------- Melek (dostlarına verdiği güçlendirmeler kendisinde de geçerli)
	10: {
		"skill": [
			{"id": "melek_q1", "name": "İtici Işık", "desc": "Can bağı sürerken bağlı dostunun ve senin saldırıların yaratıkları kısa bir mesafe geri iter."},
			{"id": "melek_q2", "name": "Çabuk Dua", "desc": "Can Basma'nın bekleme süresi %25 azalır."},
			{"id": "melek_q3", "name": "Kopmaz Bağ", "desc": "Can verme menzili %50 artar ve kurulan iyileştirme bağı bir daha kopmaz."},
			{"id": "melek_q4", "name": "Bereket", "desc": "Can Basma'nın iyileştirmesi %20 artar."},
			{"id": "melek_qf", "name": "İkiz Şifa", "desc": "Aynı anda 2 dosta can verirsin (ikinci dost bu yeteneğin sağladığının %50'si kadar iyileşir).", "final": true},
		],
		"skill2": [
			{"id": "melek_e1", "name": "Kutsal Zırh", "desc": "Kalkan bağı sürerken bağlı dostun ve sen %10 kalkan soğurma kazanırsınız, aldığınız hasar %15 azalır."},
			{"id": "melek_e2", "name": "Çabuk Kalkan", "desc": "Kalkan Yenileme'nin bekleme süresi %25 azalır."},
			{"id": "melek_e3", "name": "Güçlü Kalkan", "desc": "Kalkan Yenileme'nin verdiği kalkan %25 artar."},
			{"id": "melek_e4", "name": "Sarsılmaz Bağ", "desc": "Kalkan verme menzili %50 artar ve kurulan kalkan bağı bir daha kopmaz."},
			{"id": "melek_ef", "name": "Kanatlı Adımlar", "desc": "Kalkan bağı sürerken bağlı dostun ve sen %25 hareket hızı kazanırsınız.", "final": true},
		],
		"skill3": [
			{"id": "melek_r1", "name": "Çabuk Korku", "desc": "Kutsal Korku'nun bekleme süresi %25 azalır."},
			{"id": "melek_r2", "name": "Kutsal Işık", "desc": "Kullandığında etki alanındaki dostların ve sen saldırı gücünün %50'si kadar can yenilersiniz."},
			{"id": "melek_rf", "name": "Yeniden Doğuş", "desc": "Kullandığında Can Basma (Q) ve Kalkan Yenileme (E) bekleme süreleri anında sıfırlanır.", "final": true},
		],
	},
	## ---------------------------------------------------------------- Talon
	1: {
		"skill": [
			{"id": "talon_q1", "name": "Kalkan Hamlesi", "desc": "Hamleyle hasar verdiğin her yaratık için eksik kalkanının %3'ü yenilenir."},
			{"id": "talon_q2", "name": "Çevik Hamle", "desc": "Hamle Vuruşu'nun bekleme süresi %30 azalır."},
			{"id": "talon_q3", "name": "Sert Duruş", "desc": "Hamleden sonra 3 saniye boyunca %15 kalkan soğurma kazanırsın."},
			{"id": "talon_q4", "name": "Sarsıcı Hamle", "desc": "Hamle isabet ettiği yaratıkları 2 saniye sersemletir ve vuruş alanı %30 artar."},
			{"id": "talon_qf", "name": "Hayalet Hamle", "desc": "Hamle sırasında %100 sıvışma kazanırsın (sıvışma sınırını aşar).", "final": true},
		],
		"skill2": [
			{"id": "talon_e1", "name": "Ateş Seli", "desc": "Silah Salvosu'nun saldırı hızı bonusu %400'den %500'e çıkar."},
			{"id": "talon_e2", "name": "Uzun Girdap", "desc": "Silahların dönüş hızı %20 artar ve salvo 2 saniye daha uzun sürer."},
			{"id": "talon_e3", "name": "Keskin Çember", "desc": "Dönen silahlar çarptıkları yaratıklara isabet başına saldırı gücünün %50'si kadar hasar verir."},
			{"id": "talon_e4", "name": "Koşan Salvo", "desc": "Salvo sürerken hareket hızın %20 artar."},
			{"id": "talon_ef", "name": "Kalkan Çemberi", "desc": "Salvo sürerken silahların çizdiği çember sana gelen tüm yaratık atışlarını ve yetenek mermilerini yok eder.", "final": true},
		],
		"skill3": [
			{"id": "talon_r1", "name": "Yansıyan Hız", "desc": "Ayna Formu'nu kullandığında Silah Salvosu'nun (E) bekleme süresi sıfırlanır."},
			{"id": "talon_r2", "name": "Uzun Yansıma", "desc": "Ayna Formu 4 saniye daha uzun sürer."},
			{"id": "talon_rf", "name": "Kan Aynası", "desc": "Ayna Formu'nun kopyaladığı silahlar %20 can çalma kazanır.", "final": true},
		],
	},
	## ---------------------------------------------------------------- Elara
	8: {
		"skill": [
			{"id": "elara_q1", "name": "Rüzgar Adımı", "desc": "Sıvışma aktifken %50 sıvışma kazanırsın (sıvışma sınırını aşabilir)."},
			{"id": "elara_q2", "name": "Rüzgar Koşusu", "desc": "Sıvışma'nın hareket hızı bonusu %60'a çıkar."},
			{"id": "elara_q3", "name": "Akışta Kal", "desc": "Bir yaratığa her hasar verdiğinde Sıvışma'nın kalan bekleme süresi %2 azalır."},
			{"id": "elara_q4", "name": "Atılım", "desc": "Sıvışma'yı kullandığında kısa bir mesafe ileri atılırsın."},
			{"id": "elara_qf", "name": "Kaybolan Gölge", "desc": "Sıvışma'yı her kullandığında 1,5 saniyeliğine görünmez olursun.", "final": true},
		],
		"skill2": [
			{"id": "elara_e1", "name": "Delici Oklar", "desc": "Yetenek aktifken saldırıların fazladan %15 gerçek hasar verir (kalkanı yok sayar)."},
			{"id": "elara_e2", "name": "Kan Oku", "desc": "Yetenek aktifken %10 can çalma kazanırsın."},
			{"id": "elara_e3", "name": "Ağır Atış", "desc": "Yetenek aktifken saldırıların yaratıkları kısa bir mesafe geri iter."},
			{"id": "elara_e4", "name": "Uzun Odak", "desc": "Yeteneğin etki süresi 2 saniye uzar."},
			{"id": "elara_ef", "name": "Tam Odak", "desc": "Saldırı hızı bonusu TOPLAM saldırı hızına uygulanır.", "final": true},
		],
		"skill3": [
			{"id": "elara_r1", "name": "Çabuk Tetik", "desc": "Çift Tetik'in bekleme süresi %20 azalır."},
			{"id": "elara_r2", "name": "Güçlü Tetik", "desc": "Çift Tetik aktifken %20 saldırı gücü kazanırsın."},
			{"id": "elara_rf", "name": "Kalkan Tetiği", "desc": "Çift Tetik kalkan harcamaz ve kullandığında kalkanın anında tamamen dolar.", "final": true},
		],
	},
	## ---------------------------------------------------------------- Korsan
	9: {
		"skill": [
			{"id": "korsan_q1", "name": "Büyük Barut", "desc": "Bombaların patlama alanı %30 artar."},
			{"id": "korsan_q2", "name": "Sersemleten Patlama", "desc": "Bombalar patladığında yaratıklar 1 saniye sersemler."},
			{"id": "korsan_q3", "name": "Ganimet", "desc": "Bombalarınla öldürdüğün her yaratık için 1 altın kazanırsın."},
			{"id": "korsan_q4", "name": "Patlama Rüzgarı", "desc": "Bombaların patladığında 2 saniyeliğine %30 hareket hızı kazanırsın."},
			{"id": "korsan_qf", "name": "Cehennem Ateşi", "desc": "Patlayan bombalar yere 4 saniyelik ateş alanı bırakır; alana giren yaratıklar yanarak saniyede saldırı gücünün %20'si kadar hasar alır.", "final": true},
		],
		"skill2": [
			{"id": "korsan_e1", "name": "Dolu Cephanelik", "desc": "Bomba yük sayısı 5'e yükselir."},
			{"id": "korsan_e2", "name": "Hızlı Dolum", "desc": "Bomba yüklerinin yenilenme hızı %25 artar."},
			{"id": "korsan_e3", "name": "Kuvvetli Barut", "desc": "Bomba hasarı artar (saldırı gücü oranı +%20)."},
			{"id": "korsan_e4", "name": "Barut Deposu", "desc": "Yerde aynı anda en fazla 6 bomba olabilir sınırı kalkar."},
			{"id": "korsan_ef", "name": "Mayın Saçan", "desc": "Patlayan bombalar etrafa küçük mayınlar saçar; mayına basan yaratık saldırı gücünün %30'u kadar hasar alır ve %30 yavaşlar.", "final": true},
		],
		"skill3": [
			{"id": "korsan_r1", "name": "Geniş Bombardıman", "desc": "Bombardıman alanı %50 genişler."},
			{"id": "korsan_r2", "name": "Ağır Ateş", "desc": "Bombardıman alanındaki yaratıklar %50 yavaşlar."},
			{"id": "korsan_rf", "name": "Seyyar Bombardıman", "desc": "Bombardıman alanı seninle birlikte hareket eder.", "final": true},
		],
	},
	## ---------------------------------------------------------------- Şovalye Adam
	7: {
		"skill": [
			{"id": "sovalye_q1", "name": "Meydan Okuma", "desc": "Kullandığında çevrendeki yaratıkları kışkırtıp sana saldırtırsın; kışkırtılan yaratıklar %10 fazla hasar alır."},
			{"id": "sovalye_q2", "name": "Demir İrade", "desc": "Yetenek aktifken %20 kalkan soğurma kazanırsın (kalkan soğurma sınırını aşabilir)."},
			{"id": "sovalye_q3", "name": "Güçlü Yenilenme", "desc": "Yeteneğin yenilediği kalkan %25 artar."},
			{"id": "sovalye_q4", "name": "Uzun Nöbet", "desc": "Yeteneğin etki süresi 2 saniye artar."},
			{"id": "sovalye_qf", "name": "Anında Kalkan", "desc": "Kullandığında anında maksimum kalkanının %15'i kadar kalkan yenilersin.", "final": true},
		],
		"skill2": [
			{"id": "sovalye_e1", "name": "Çabuk Bariyer", "desc": "Koruma Bariyeri'nin bekleme süresi %25 azalır."},
			{"id": "sovalye_e2", "name": "Büyük Fedakarlık", "desc": "Dostların aldığı hasarı emme oranı %50'ye çıkar."},
			{"id": "sovalye_e3", "name": "Sağlam Duruş", "desc": "Yetenek aktifken aldığın tüm hasar %25 azalır (emdiğin hasar da bu azaltmadan sonra hesaplanır)."},
			{"id": "sovalye_e4", "name": "Koruyucu Adım", "desc": "Yetenek aktifken hareket hızın %20 artar."},
			{"id": "sovalye_ef", "name": "İntikam Patlaması", "desc": "Yetenek aktifken aldığın tüm hasar birikir; yetenek bitince patlayarak çevrendeki yaratıklara verilir.", "final": true},
		],
		"skill3": [
			{"id": "sovalye_r1", "name": "Sarsıcı Patlama", "desc": "Kalkan patladığında yaratıkları çok uzağa iter."},
			{"id": "sovalye_r2", "name": "Yansıtan Kubbe", "desc": "Yetenek aktifken kalkana vuran yaratıklar vurdukları hasarın %50'sini geri alır."},
			{"id": "sovalye_rf", "name": "Yürüyen Kale", "desc": "Yetenek aktifken hareket hızının %30'uyla kalkanla birlikte yürüyebilirsin.", "final": true},
		],
	},
	## ---------------------------------------------------------------- Matthew
	3: {
		"skill": [
			{"id": "matthew_q1", "name": "Savuran Pençe", "desc": "Tilki vurduğu yaratıkları senden uzağa iter."},
			{"id": "matthew_q2", "name": "Bedava Av", "desc": "Tilki Hücumu kalkan harcamaz."},
			{"id": "matthew_q3", "name": "Keskin Dişler", "desc": "Tilki Hücumu'nun hasarı %30 artar."},
			{"id": "matthew_q4", "name": "Çevik Tilki", "desc": "Tilki Hücumu'nun bekleme süresi %30 azalır."},
			{"id": "matthew_qf", "name": "Sürü Avı", "desc": "Tilki Hücumu'nun hedef sayısı 6'dan 10'a çıkar.", "final": true},
		],
		"skill2": [
			{"id": "matthew_e1", "name": "Vahşi Koşu", "desc": "Hareket hızı bonusu %30'a, saldırı hızı bonusu %50'ye çıkar."},
			{"id": "matthew_e2", "name": "Uzun Av", "desc": "Vahşi Hız'ın etki süresi 4 saniye artar."},
			{"id": "matthew_e3", "name": "Tilki Ruhu", "desc": "Tilkin Vahşi Hız'ın sağladığı bonusların 2 katını kazanır."},
			{"id": "matthew_e4", "name": "Sersemleten Isırık", "desc": "Vahşi Hız aktifken tilkinin saldırıları yaratıkları 1 saniye sersemletir."},
			{"id": "matthew_ef", "name": "Avcı Sabrı", "desc": "Vahşi Hız aktif değilken 3 saniye hasar almazsan %15 hareket hızı kazanırsın; hasar alınca kaybolur.", "final": true},
		],
		"skill3": [
			{"id": "matthew_r1", "name": "Kalın Kürk", "desc": "Feda Kalkanı'nın koruma kapasitesi %50 artar."},
			{"id": "matthew_r2", "name": "Çabuk Fedakarlık", "desc": "Feda Kalkanı'nın bekleme süresi %25 azalır."},
			{"id": "matthew_rf", "name": "Ağır Pençeler", "desc": "Feda Kalkanı aktifken saldırıların yaratıkları %30 yavaşlatır.", "final": true},
		],
	},
	## ---------------------------------------------------------------- Assasin Çocuk (kullanıcı isteği 2026-09-30)
	## Temel kesintiler "çünkü geliştirmelere eklenecek": Gölge Adımı artık saldırı gücü vermez (E2'de), Şahin Hamlesi 3 yerine
	## 2 yük (Q1'de), Gölge Hücumu'nun tempusu saldırı hızıyla artmaz (R1'de). Aynı gün Q ile E yer değiştirdi (kullanıcı: "E
	## yeteneği artık Q, Q yeteneği de artık E olsun") - evrimler yetenekleriyle birlikte taşındı, id'ler yeni yuvaya göre
	## (assasin_q* = Şahin Hamlesi, assasin_e* = Gölge Adımı). Kullanıcının ilk metnindeki "Q yeteneğin fazladan 1 yüke sahip
	## olur" (hamle listesindeydi) bu değişimle birebir doğru hale geldi.
	5: {
		"skill": [
			{"id": "assasin_q1", "name": "Üçüncü Hamle", "desc": "Şahin Hamlesi fazladan 1 yüke sahip olur (2 yerine 3 yük)."},
			{"id": "assasin_q2", "name": "Av Zinciri", "desc": "Bu yetenekle öldürdüğün her yaratık, dolmakta olan yükün bekleme süresini 0,2 saniye azaltır."},
			{"id": "assasin_q3", "name": "Keskin Pençe", "desc": "Şahin Hamlesi'nin hasar oranı %30 artar."},
			{"id": "assasin_q4", "name": "Rüzgar Gibi", "desc": "Hamle attığında 0,75 saniye boyunca %100 sıvışma kazanırsın (sıvışma sınırını aşar)."},
			{"id": "assasin_qf", "name": "Kunai Yağmuru", "desc": "Hamle attığında çevrene 6 kunai fırlatırsın; her kunai isabet ettiği yaratıkları delip geçerek saldırı gücünün %50'si kadar hasar verir.", "final": true},
		],
		"skill2": [
			{"id": "assasin_e1", "name": "Uzun Gölge", "desc": "Görünmezliğin süresi 2 saniye uzar."},
			{"id": "assasin_e2", "name": "Pusu", "desc": "Gölge Adımı aktifken %25 saldırı gücü kazanırsın."},
			{"id": "assasin_e3", "name": "Gölge Nefesi", "desc": "Görünmezlik aktifleştiğinde kalkan yenilenmesinin bekleme süresi sıfırlanır; kalkanın hemen dolmaya başlar."},
			{"id": "assasin_e4", "name": "Sessiz Adımlar", "desc": "Görünmezken %20 hareket hızı kazanırsın."},
			{"id": "assasin_ef", "name": "Gölge Kopyası", "desc": "Görünmezliği aktifleştirdiğinde bulunduğun yere bir gölge kopyanı bırakırsın; görünmezlik sürerken E'ye tekrar basmak seni kopyana geri ışınlar.", "final": true},
		],
		"skill3": [
			{"id": "assasin_r1", "name": "Hızlanan Hücum", "desc": "Gölge Hücumu'nun saldırı sıklığı saldırı hızına bağlı olarak artar."},
			{"id": "assasin_r2", "name": "Çabuk Gölge", "desc": "Gölge Hücumu'nun bekleme süresi %25 azalır."},
			{"id": "assasin_rf", "name": "Gölge İzi", "desc": "Gölge Hücumu sırasında arkanda 1 saniye süren bir gölge izi bırakırsın; ize temas eden yaratıklar saldırı gücünün %80'i kadar hasar alır.", "final": true},
		],
	},
	## ---------------------------------------------------------------- Shaman (kullanıcı isteği 2026-10-04)
	## Q = Saldırı Totemi (27), E = Kalkan Totemi (26), R = Elemental Golem (49). Kullanıcının metninde E3 "Yavaşlatma oranı %70
	## seviyesine yükselir" yazıyordu ama Kalkan Totemi'nin yavaşlatması yok (2026-09-29'da tüm totemlerden kaldırıldı) - bu
	## yüzden E3 alandaki yaratıklara %70 yavaşlatmayı İLK KEZ getirir (temel yavaşlatma yok).
	12: {
		"skill": [
			{"id": "shaman_q1", "name": "Üçüncü Totem", "desc": "Saldırı Totemi'nin yük sayısı 3'e çıkar."},
			{"id": "shaman_q2", "name": "Alev Dokunuşu", "desc": "Totemin saldırıları senin pasifinden yararlanır: her saldırı hedefi yakar (3 saniye boyunca saniyede saldırı gücünün %10'u)."},
			{"id": "shaman_q3", "name": "Çabuk Totem", "desc": "Saldırı Totemi'nin bekleme süresi %20 azalır."},
			{"id": "shaman_q4", "name": "Ruh Emici", "desc": "Totemin saldırıları %5 can çalma kazanır ve can çalma statlarından da faydalanır; çalınan can sana yenilenir."},
			{"id": "shaman_qf", "name": "Patlayan Alev", "desc": "Totemin saldırıları isabet ettiği hedefte patlar ve etrafındaki yaratıklara hasarın %50'si kadar hasar verir.", "final": true},
		],
		"skill2": [
			{"id": "shaman_e1", "name": "Geniş Alan", "desc": "Kalkan Totemi'nin alanı %30 büyür."},
			{"id": "shaman_e2", "name": "Savaş Ritmi", "desc": "Alanın içindeki oyuncular %15 saldırı hızı kazanır."},
			{"id": "shaman_e3", "name": "Yapışkan Zemin", "desc": "Alandaki yaratıklar %70 yavaşlar."},
			{"id": "shaman_e4", "name": "Güçlü Kalkan", "desc": "Totemin verdiği kalkan %50 artar."},
			{"id": "shaman_ef", "name": "İtici Dalga", "desc": "Alan her hasar verdiğinde yaratıkları totemin merkezinden bir miktar dışarı iter.", "final": true},
		],
		"skill3": [
			{"id": "shaman_r1", "name": "Taş Deri", "desc": "Golem formundayken hasar azaltma %60 seviyesine yükselir."},
			{"id": "shaman_r2", "name": "Taşın Dirilişi", "desc": "Golem formundayken öldürdüğün her yaratık başına eksik canının %1'i kadar can yenilersin."},
			{"id": "shaman_rf", "name": "Dev Golem", "desc": "Golem formundayken boyutun %30 büyür, %15 saldırı gücü kazanırsın ve golem yeteneklerinin alanı %30 artar.", "final": true},
		],
	},
	## ---------------------------------------------------------------- Büyücü Kız (kullanıcı isteği 2026-10-04)
	## Q = Büyü Değişimi (set değiştirir), E = Arcane Lanet / Hortum (set 1 / set 2), R = Don Nova / Meteor Patlaması. E ve R
	## evrimleri yuvadaki İKİ varyasyonu birden güçlendirir. Temel değişiklik "çünkü donma olayı geliştirmelere eklenecek": Don
	## Nova artık dondurmaz, 6 sn %80 yavaşlatır (R finali ilk 3 sn dondurur). Sayılar player.gd EVO_BUYUCU_* sabitlerinde.
	4: {
		"skill": [
			{"id": "buyucu_q1", "name": "Kalkan Akışı", "desc": "Her set değiştirdiğinde maksimum kalkanının %10'u yenilenir (bu etkinin 10 saniye bekleme süresi vardır)."},
			{"id": "buyucu_q2", "name": "Büyü Rüzgarı", "desc": "E veya ulti yeteneğini kullandığında 2 saniye boyunca %20 hareket hızı kazanırsın."},
			{"id": "buyucu_q3", "name": "Akıcı Büyü", "desc": "Tüm yeteneklerinin bekleme süresi %15 azalır."},
			{"id": "buyucu_q4", "name": "Tutumlu Büyü", "desc": "Yeteneklerinin kalkan bedeli %25 azalır."},
			{"id": "buyucu_qf", "name": "Efsunlu Büyü", "desc": "Her 5 yetenek kullanımında (Q hariç) yeteneklerinden biri efsunlanır ve butonu parıldar: bir sonraki kullanımında boyutu ve hasarı %25 artar.", "final": true},
		],
		"skill2": [
			{"id": "buyucu_e1", "name": "Arcane Patlama", "desc": "Arcane Lanet her isabette patlar ve çevresindeki yaratıklara verdiği hasarın %75'i kadar hasar verir. Hortuma yakalanan yaratıklar %20 daha fazla hasar alır."},
			{"id": "buyucu_e2", "name": "Çabuk Büyü", "desc": "Arcane Lanet'in ve Hortum'un bekleme süresi %20 azalır."},
			{"id": "buyucu_e3", "name": "Güçlü Büyü", "desc": "Arcane Lanet'in ve Hortum'un saldırı gücü oranları %30 artar."},
			{"id": "buyucu_e4", "name": "Savuran Büyü", "desc": "Arcane Lanet'in çarptığı yaratıklar geriye itilir; hortuma yakalanan yaratıklar 1 saniye sersemler."},
			{"id": "buyucu_ef", "name": "Büyü Fırtınası", "desc": "Arcane Lanet 4 yerine 7 yaratığa seker. Hortum sayısı 5'e çıkar.", "final": true},
		],
		"skill3": [
			{"id": "buyucu_r1", "name": "Yükseliş", "desc": "Meteor Patlaması süresince havaya yükselir ve hedef alınamaz olursun. Don Nova yaratıkları etki alanının dışına iter."},
			{"id": "buyucu_r2", "name": "Meteor Sağanağı", "desc": "Meteorlar %30 daha sık düşer. Don Nova kalkan harcamaz."},
			{"id": "buyucu_rf", "name": "Ateş ve Buz", "desc": "Meteorlar yere krater bırakır; üstüne basan yaratıklar yanarak 3 saniye boyunca saniyede saldırı gücünün %30'u kadar hasar alır. Don Nova yaratıkları ilk 3 saniye dondurur.", "final": true},
		],
	},
}


static func has_evolutions(char_id: int) -> bool:
	return DEFS.has(char_id)


static func slot_list(char_id: int, slot: String) -> Array:
	return (DEFS.get(char_id, {}) as Dictionary).get(slot, [])


## Bir evrimin tanımı + nerede olduğu ({} = yok): "slot", "index" (1-tabanlı, final dahil sıra), "count" (yuvadaki toplam).
static func find(evo_id: String) -> Dictionary:
	for char_id in DEFS:
		for slot in SLOTS:
			var list: Array = slot_list(int(char_id), slot)
			for i in range(list.size()):
				var e: Dictionary = list[i]
				if str(e["id"]) == evo_id:
					var out: Dictionary = e.duplicate()
					out["char_id"] = int(char_id)
					out["slot"] = slot
					out["index"] = i + 1
					out["count"] = list.size()
					return out
	return {}


## Bu seviyede kart olarak çıkabilecek evrimler: yuva açık (unlock_level_fn(slot) <= seviye), alınmamış, final ise o yuvanın
## diğer TÜM evrimleri alınmış. owned: {evo_id: true}.
static func available(char_id: int, owned: Dictionary, level: int) -> Array:
	var out: Array = []
	for slot in SLOTS:
		if Characters.skill_unlock_level(char_id, slot) > level:
			continue
		var list: Array = slot_list(char_id, slot)
		var regular_missing: bool = false
		for e in list:
			if not bool(e.get("final", false)) and not owned.has(str(e["id"])):
				regular_missing = true
		for e in list:
			if owned.has(str(e["id"])):
				continue
			if bool(e.get("final", false)) and regular_missing:
				continue
			var entry: Dictionary = e.duplicate()
			entry["slot"] = slot
			out.append(entry)
	return out


## Rastgele, tekrarsız en fazla `count` evrim (hepsi eşit ağırlıklı - kullanıcı: "şans eseri denk gelebilecek").
static func roll_offer(char_id: int, owned: Dictionary, level: int, count: int = OFFER_COUNT) -> Array:
	var pool: Array = available(char_id, owned, level)
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


## Bu seviye bir evrim seviyesi mi (5, 10, 15 ...).
static func is_evolution_level(level: int) -> bool:
	return level > 0 and level % LEVEL_INTERVAL == 0


## Bir yuvada sahip olunan evrim sayısı / toplam.
static func owned_count(char_id: int, slot: String, owned: Dictionary) -> int:
	var n: int = 0
	for e in slot_list(char_id, slot):
		if owned.has(str(e["id"])):
			n += 1
	return n


## HUD ipucu için: bu yuvada sahip olunan evrimlerin (ad, açıklama) listesi, tanımdaki sırayla.
static func owned_in_slot(char_id: int, slot: String, owned: Dictionary) -> Array:
	var out: Array = []
	for e in slot_list(char_id, slot):
		if owned.has(str(e["id"])):
			out.append(e)
	return out
