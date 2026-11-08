# -*- coding: utf-8 -*-
"""Dil desteği metin çıkarıcı (madde 446).

Kaynak dil Türkçe; metnin kendisi msgid. Bu betik:
  1. scripts/**/*.gd + scenes/**/*.tscn içindeki ARAYÜZE BENZEYEN metinleri bulur -> localization/oyun.pot (#: dosya:satır)
  2. localization/<dil>.po dosyalarını birleştirir: var olan çeviri korunur, yeni metin boş msgstr ile eklenir,
     artık kodda olmayan çeviri "#~" ile saklanır (Godot yüklemez).
  3. Rapor: dosya başına aday / çevrilmiş sayısı + ELLE BAKILMASI gerekenler:
       BİRLEŞTİRME  - metin + / % ile birleşiyor: Label'ın kendiliğinden çevirisi tutmaz, tr("kalıp") % ... gerekir
       ÇİZİM        - draw_string ile çiziliyor: tr()/atr() gerekir

Kullanım:
  python -I tools/dil/dil_cikar.py                 # pot + po birleştir + kısa özet
  python -I tools/dil/dil_cikar.py --rapor         # dosya dosya tablo (en çok çevrilmemiş üstte)
  python -I tools/dil/dil_cikar.py --dosya scripts/main_menu.gd   # o dosyanın adayları + çeviri durumu + uyarılar

Satır atlama: satırda "dil:yok" geçen bir yorum varsa o satırın metinleri alınmaz (ör. düğüm adı, kimlik).
Fazladan aday ZARARSIZDIR (Godot yalnız ekrana basılan metni arar); eksik aday = o metin çevrilmez.
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LOC_DIR = os.path.join(ROOT, "localization")
POT_PATH = os.path.join(LOC_DIR, "oyun.pot")
SCAN_DIRS = ["scripts", "scenes"]
SKIP_DIRS = {"addons", "tests", "tools", ".godot"}
# Oyuncuya görünmeyen dosyalar (hata ayıklama menüsü, ölçüm, harita katman adları) - aday listesini kirletmesin
SKIP_FILES = {"scripts/debug_menu.gd", "scripts/perf_probe.gd", "scripts/terrain_collision.gd", "scripts/depth_occluders.gd",
              "scripts/map_color_grade.gd"}

TR_CHARS = set("çğıöşüÇĞİÖŞÜ")
# Bu çağrıların içindeki metinler ekrana gitmez (günlük, kimlik, yol, düğüm adı...)
SKIP_CALL = re.compile(
    r"\b(print|prints|printerr|print_debug|push_warning|push_error|assert|_log|log_line|NetLog\.\w+|get_node|get_node_or_null|"
    r"has_node|find_child|set_meta|get_meta|has_meta|remove_meta|connect|disconnect|emit_signal|has_method|call|call_deferred|"
    r"callv|rpc|rpc_id|has_signal|is_action_pressed|is_action_just_pressed|is_action_just_released|is_action|get_action_strength|"
    r"get_axis|get_vector|action_get_events|has_action|get_setting|set_setting|has_setting|get_environment|load|preload|"
    r"ResourceLoader\.\w+|FileAccess\.\w+|DirAccess\.\w+|play|travel|add_theme_\w+_override|get_theme_\w+|has_theme_\w+|"
    r"set_shader_parameter|get_shader_parameter|add_to_group|is_in_group|get_nodes_in_group|remove_from_group|"
    r"get_first_node_in_group|set_value|get_value|has_section_key|create_tween|tween_property|tween_method|set_animation|"
    r"has_animation|get_frame_texture|get_frame_count)\s*\(\s*$"
)
SKIP_ASSIGN = re.compile(r"\.(name|animation|layer_name|group|bus|stream_path|shader|resource_path)\s*=\s*$")


def is_candidate(s):
    """Arayüz metnine benziyor mu? Kimlik / yol / düğüm adı / biçim kalıbı gibi şeyleri atar."""
    if not s or not re.search(r"[A-Za-zÇĞİÖŞÜçğıöşü]", s):
        return False
    if s.startswith(("res://", "user://", "uid://", "http", "#")):
        return False
    if re.search(r"\.(gd|tscn|tres|png|wav|ogg|mp3|json|cfg|txt|gdshader|po|tmx|tsx)\b", s):
        return False
    if "shader_type" in s or "(?:" in s or "\\d" in s or "\\s" in s:   # shader kodu / düzenli ifade
        return False
    if re.search(r"([^.I])\1\1", s) and not re.search(r"[aeıioöuü]", s):  # piksel deseni: "..XXX..", "OGGGGO", "OO     "
        return False
    if s.startswith("@") or ("|" in s and " " not in s) or len(s.strip()) <= 1:  # "@anahtar", "tür|%s|%d" kimlikleri, tek harf
        return False
    if re.fullmatch(r"[ .A-Za-z0-9]{5,}", s) and s.strip()[:1] == "O" and s.strip()[-1:] == "O" and not re.search(r"[aeıioöuü]", s):
        return False  # piksel deseni "OGWGWWGGO", "OBO OBO O" (O = dış hat)
    has_tr = any(c in TR_CHARS for c in s)
    if " " not in s and not has_tr:
        # tek kelime, Türkçe harfsiz
        if re.fullmatch(r"[a-z0-9_./:\-]+", s):        # kimlik / yol / anahtar
            return False
        if re.search(r"[a-z0-9][A-Z]", s):             # CamelCase düğüm adı (Skill2Icon)
            return False
        if re.fullmatch(r"[A-Z0-9_]+", s) and "_" in s:  # SABIT_ADI
            return False
        if re.fullmatch(r"[%0-9dsf.:+\-]+", s):        # biçim kalıbı
            return False
        if len(s) <= 1:
            return False
    if re.fullmatch(r"[a-z_][a-z0-9_]*( [a-z_][a-z0-9_]*)*", s) and not has_tr and "_" in s:
        return False
    return True


def unescape(raw):
    out = []
    i = 0
    while i < len(raw):
        c = raw[i]
        if c == "\\" and i + 1 < len(raw):
            n = raw[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "'": "'", "\\": "\\"}.get(n, "\\" + n))
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def gd_literals(line):
    """Satırdaki dize sabitleri: (metin, önündeki kod, arkasındaki kod). Yorumdan sonrası atılır. &"" ve ^"" atlanır."""
    res = []
    i = 0
    n = len(line)
    while i < n:
        c = line[i]
        if c == "#":
            break
        if c in "\"'":
            q = c
            prefix_char = line[i - 1] if i > 0 else ""
            j = i + 1
            buf = []
            while j < n and line[j] != q:
                if line[j] == "\\" and j + 1 < n:
                    buf.append(line[j:j + 2])
                    j += 2
                    continue
                buf.append(line[j])
                j += 1
            raw = "".join(buf)
            if prefix_char not in "&^":
                res.append((unescape(raw), line[:i], line[j + 1:]))
            i = j + 1
            continue
        i += 1
    return res


def scan_gd(path, rel, found, warns):
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    for ln, line in enumerate(lines, 1):
        st = line.lstrip()
        if st.startswith("#") or "dil:yok" in line:
            continue
        if re.match(r"\s*(extends|class_name|signal|@export_enum|@export_file|@icon)\b", line):
            continue
        code = line.split("#", 1)[0]
        if "draw_string(" in code and "tr(" not in code:
            warns.append(("ÇİZİM", "%s:%d" % (rel, ln), code.strip()[:70]))
        for text, before, after in gd_literals(line):
            explicit = re.search(r"(?:\b(?:tr|atr|tr_n|translate)|Loc\.t)\(\s*$", before) is not None  # açık tr("...") her zaman alınır
            if not explicit and not is_candidate(text):
                continue
            if explicit:
                found.setdefault(text, []).append("%s:%d" % (rel, ln))
                continue
            if SKIP_CALL.search(before) or SKIP_ASSIGN.search(before) or re.search(r"\.name\s*=", before):
                continue
            if re.match(r"\s*:", after) and re.search(r"[{,]\s*$", before):  # sözlük anahtarı {"ad": ...}
                if re.fullmatch(r"[a-z0-9_]+", text):
                    continue
            if re.search(r"\b(match|==|!=|in)\s*$", before) or re.match(r"\s*(==|!=)", after):
                continue  # karşılaştırma: ekrana gitmez
            found.setdefault(text, []).append("%s:%d" % (rel, ln))
            ref = "%s:%d" % (rel, ln)
            if re.match(r"\s*[%+]", after) or re.search(r"\+\s*$", before):
                if "tr(" not in before[-12:]:
                    warns.append(("BİRLEŞTİRME", ref, text))


TSCN_TEXT = re.compile(r'^(text|tooltip_text|placeholder_text|title) = "((?:[^"\\]|\\.)*)"\s*$')


def scan_tscn(path, rel, found):
    with open(path, encoding="utf-8") as f:
        for ln, line in enumerate(f, 1):
            m = TSCN_TEXT.match(line.rstrip("\n"))
            if m:
                text = unescape(m.group(2))
                if is_candidate(text):
                    found.setdefault(text, []).append("%s:%d" % (rel, ln))


def collect():
    found = {}
    warns = []
    for d in SCAN_DIRS:
        for dp, dns, fns in os.walk(os.path.join(ROOT, d)):
            dns[:] = sorted(x for x in dns if x not in SKIP_DIRS)
            for fn in sorted(fns):
                p = os.path.join(dp, fn)
                rel = os.path.relpath(p, ROOT).replace("\\", "/")
                if rel in SKIP_FILES:
                    continue
                if fn.endswith(".gd"):
                    scan_gd(p, rel, found, warns)
                elif fn.endswith(".tscn"):
                    scan_tscn(p, rel, found)
    return found, warns


def po_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def po_unescape(s):
    return unescape(s)


def read_po(path):
    """msgid -> msgstr (yalnız etkin girdiler; '#~' de okunur ki geri gelen metin çevirisini bulsun)."""
    entries = {}
    if not os.path.exists(path):
        return entries
    cur_id = cur_str = None
    mode = None
    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n")
            obsolete = line.startswith("#~ ")
            if obsolete:
                line = line[3:]
            elif line.startswith("#"):
                continue
            if line.startswith("msgid "):
                if cur_id is not None:
                    entries[cur_id] = cur_str or ""
                cur_id = po_unescape(line[6:].strip()[1:-1])
                cur_str = None
                mode = "id"
            elif line.startswith("msgstr "):
                cur_str = po_unescape(line[7:].strip()[1:-1])
                mode = "str"
            elif line.startswith('"') and mode:
                part = po_unescape(line.strip()[1:-1])
                if mode == "id":
                    cur_id += part
                else:
                    cur_str += part
    if cur_id is not None:
        entries[cur_id] = cur_str or ""
    entries.pop("", None)
    return entries


def header(lang):
    h = 'msgid ""\nmsgstr ""\n"Content-Type: text/plain; charset=UTF-8\\n"\n'
    if lang:
        h += '"Language: %s\\n"\n' % lang
    return h + "\n"


def write_pot(found):
    with open(POT_PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write("# Otomatik üretildi: python -I tools/dil/dil_cikar.py (elle düzenleme)\n")
        f.write(header(""))
        for text, refs in found.items():
            for r in refs[:6]:
                f.write("#: %s\n" % r)
            if len(refs) > 6:
                f.write("#: ... (+%d)\n" % (len(refs) - 6))
            f.write('msgid "%s"\nmsgstr ""\n\n' % po_escape(text))


def merge_po(lang, found):
    path = os.path.join(LOC_DIR, lang + ".po")
    old = read_po(path)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("# %s çevirisi. Kaynak dil Türkçe (msgid). Boş msgstr = Türkçe görünür.\n" % lang)
        f.write("# Yeni metinler: python -I tools/dil/dil_cikar.py (çevirileri korur). Sözlük: localization/sozluk.md\n")
        f.write(header(lang))
        for text, refs in found.items():
            f.write("#: %s\n" % refs[0])
            f.write('msgid "%s"\nmsgstr "%s"\n\n' % (po_escape(text), po_escape(old.get(text, ""))))
        gone = [(k, v) for k, v in old.items() if k not in found and v]
        if gone:
            f.write("# --- Kodda artık yok (yüklenmez, çeviri saklanıyor) ---\n")
            for k, v in gone:
                f.write('#~ msgid "%s"\n#~ msgstr "%s"\n\n' % (po_escape(k), po_escape(v)))
    return read_po(path)


def main():
    args = sys.argv[1:]
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # Windows konsolu cp1254: "→" gibi harfler çökertiyordu
    except Exception:
        pass
    os.makedirs(LOC_DIR, exist_ok=True)
    found, warns = collect()
    write_pot(found)
    langs = sorted(fn[:-3] for fn in os.listdir(LOC_DIR) if fn.endswith(".po"))
    done = {}
    for lang in langs:
        done[lang] = merge_po(lang, found)
    print("aday metin: %d  (oyun.pot)" % len(found))
    for lang in langs:
        tr_n = sum(1 for k in found if done[lang].get(k))
        print("  %s.po: %d çevrili / %d (%%%.1f)" % (lang, tr_n, len(found), 100.0 * tr_n / max(len(found), 1)))
    print("elle bakılacak: %d birleştirme, %d çizim" % (sum(1 for w in warns if w[0] == "BİRLEŞTİRME"), sum(1 for w in warns if w[0] == "ÇİZİM")))
    main_lang = "en" if "en" in done else (langs[0] if langs else None)
    if "--rapor" in args and main_lang:
        per = {}
        for text, refs in found.items():
            for r in {x.rsplit(":", 1)[0] for x in refs}:
                a = per.setdefault(r, [0, 0])
                a[0] += 1
                if done[main_lang].get(text):
                    a[1] += 1
        print("\n%-60s %6s %6s" % ("dosya", "aday", main_lang))
        for r, (n, t) in sorted(per.items(), key=lambda kv: -(kv[1][0] - kv[1][1])):
            print("%-60s %6d %6d" % (r, n, t))
    if "--dosya" in args and main_lang:
        target = args[args.index("--dosya") + 1].replace("\\", "/")
        for text, refs in found.items():
            mine = [r for r in refs if r.rsplit(":", 1)[0] == target]
            if mine:
                tr_ = done[main_lang].get(text, "")
                print("%s	%s	%s" % (mine[0].rsplit(":", 1)[1], po_escape(text), po_escape(tr_) if tr_ else "(YOK)"))
        for kind, ref, text in warns:
            if ref.rsplit(":", 1)[0] == target:
                print("  ! %s %s %r" % (kind, ref, text))


if __name__ == "__main__":
    main()
