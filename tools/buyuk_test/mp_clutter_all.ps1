# MP gorsel karmasa: iki parti x (3 oyunculu + tek oyunculu taban). Sirayla (ayni anda iki Godot grubu baslatma).
$run = Join-Path $PSScriptRoot "mp_clutter.ps1"
& powershell -ExecutionPolicy Bypass -File $run -Label ags_fx3 -Chars "4,12,10" -Weapons "fire_staff,uzunkilic,tabanca;yay,buz_asasi,topuz;lightning_staff,pence,arcane" -Secs 70
& powershell -ExecutionPolicy Bypass -File $run -Label ags_fx_solo -Solo -Chars "4,12,10" -Weapons "fire_staff,uzunkilic,tabanca;yay,buz_asasi,topuz;lightning_staff,pence,arcane" -Secs 70
& powershell -ExecutionPolicy Bypass -File $run -Label ags_den3 -Chars "1,7,8" -Weapons "uzunkilic,tabanca,yinyang;kalkan,topuz,mizrak;yay,buz_asasi,crossbow" -Secs 70
& powershell -ExecutionPolicy Bypass -File $run -Label ags_den_solo -Solo -Chars "1,7,8" -Weapons "uzunkilic,tabanca,yinyang;kalkan,topuz,mizrak;yay,buz_asasi,crossbow" -Secs 70
Write-Host "HEPSI BITTI"
