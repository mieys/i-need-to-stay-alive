' Gorev Zamanlayici'dan pencere yanip sonmeden izleyici.ps1'i calistirir (madde 420).
' Bekler (True): Gorev Zamanlayici ayni anda ikinci bir ornek baslatmasin.
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & dir & "\izleyici.ps1""", 0, True
