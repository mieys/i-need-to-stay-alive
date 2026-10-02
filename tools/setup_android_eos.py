"""Android gradle şablonuna Epic Online Services (EOS) kütüphanesini ekler (2026-10-02, internet odası / crossplay).

Neden araç: res://android/ .gitignore'da (Godot şablonu ~200 MB, her makinede kurulur). Şablon kurulunca / Godot sürümü
değişince bu betiği BİR kez çalıştır; tekrar çalıştırmak güvenlidir (zaten ekli olanı atlar).

  1) Şablonu kur: Godot editörü -> Proje -> Android Derleme Şablonunu Yükle
     (ya da elle: export_templates/<sürüm>/android_source.zip -> res://android/build, android/.build_version = sürüm)
  2) python tools/setup_android_eos.py
  3) Android export (export_presets.cfg "Android" preset'i gradle derlemesi açık)

Yaptıkları (EOSG README "Exporting for Android" adımları):
  - build.gradle: EOS'un androidx bağımlılıkları + addons/epic-online-services-godot/bin/android/eossdk-StaticSTDC-release.aar
  - build.gradle defaultConfig: eos_login_protocol_scheme = "eos.<client_id>" (eos_credentials.cfg'den derleme anında
    okunur; dosya yoksa yer tutucu - anonim/cihaz girişi bu adresi kullanmaz)
  - GodotApp.java: EOSSDK yerel kütüphanesini yükle + onCreate'te EOSSDK.init
  - config.gradle minSdk >= 23 (EOS Android SDK şartı; şablon zaten 24)
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "android", "build")
MARK = "// EOS (tools/setup_android_eos.py)"


def read(p):
    with io.open(p, encoding="utf-8", newline="") as f:
        return f.read()


def write(p, s):
    with io.open(p, "w", encoding="utf-8", newline="") as f:
        f.write(s)


def insert_after(s, anchor, text, path):
    i = s.find(anchor)
    if i < 0:
        sys.exit("HATA: '%s' içinde beklenen satır yok: %s" % (path, anchor))
    j = i + len(anchor)
    return s[:j] + text + s[j:]


def main():
    if not os.path.isdir(BUILD):
        sys.exit("HATA: android/build yok - önce Android derleme şablonunu kur (bkz. dosya başı).")

    # --- build.gradle
    p = os.path.join(BUILD, "build.gradle")
    s = read(p)
    nl = "\r\n" if "\r\n" in s else "\n"
    if MARK not in s:
        deps = nl.join([
            "",
            "",
            "    " + MARK + " - EOS Android SDK bağımlılıkları",
            "    implementation 'androidx.appcompat:appcompat:1.5.1'",
            "    implementation 'androidx.constraintlayout:constraintlayout:2.1.4'",
            "    implementation 'androidx.security:security-crypto:1.0.0'",
            "    implementation 'androidx.browser:browser:1.4.0'",
            "    implementation 'androidx.webkit:webkit:1.7.0'",
            "    implementation files('../../addons/epic-online-services-godot/bin/android/eossdk-StaticSTDC-release.aar')",
        ])
        s = insert_after(s, 'implementation "androidx.documentfile:documentfile:$versions.documentfileVersion"', deps, p)
        scheme = nl.join([
            "",
            "",
            "        " + MARK + " - EOS Android SDK bu kaynağı ister (Epic hesabıyla girişte geri dönüş adresi).",
            "        def eosClientId = \"placeholder\"",
            "        def eosCfg = file(\"../../eos_credentials.cfg\")",
            "        if (eosCfg.exists()) {",
            "            def m = (eosCfg.text =~ /(?m)^client_id\\s*=\\s*\"([^\"]*)\"/)",
            "            if (m.find() && !m.group(1).trim().isEmpty()) {",
            "                eosClientId = m.group(1).trim()",
            "            }",
            "        }",
            "        resValue(\"string\", \"eos_login_protocol_scheme\", \"eos.\" + eosClientId.toLowerCase())",
        ])
        s = insert_after(s, "missingDimensionStrategy 'products', 'template'", scheme, p)
        write(p, s)
        print("build.gradle: EOS eklendi")
    else:
        print("build.gradle: zaten ekli")
    # EOS aar'ı "core library desugaring" ister (yoksa: "requires core library desugaring to be enabled").
    s = read(p)
    if "coreLibraryDesugaringEnabled" not in s:
        s = insert_after(s, "        targetCompatibility versions.javaVersion",
                         nl + "        coreLibraryDesugaringEnabled true " + MARK, p)
        s = insert_after(s, "    " + MARK + " - EOS Android SDK bağımlılıkları",
                         nl + "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'", p)
        write(p, s)
        print("build.gradle: desugaring eklendi")

    # --- GodotApp.java
    p = os.path.join(BUILD, "src", "main", "java", "com", "godot", "game", "GodotApp.java")
    s = read(p)
    nl = "\r\n" if "\r\n" in s else "\n"
    if "EOSSDK" not in s:
        s = insert_after(s, "import org.godotengine.godot.GodotActivity;",
                         nl + "import com.epicgames.mobile.eossdk.EOSSDK; " + MARK, p)
        s = insert_after(s, "public class GodotApp extends GodotActivity {" + nl + "\tstatic {",
                         nl + "\t\t" + MARK + " - Epic yerel kütüphanesi, EOSG eklentisi (libeosg) yüklenmeden ÖNCE." + nl
                         + "\t\tSystem.loadLibrary(\"EOSSDK\");", p)
        s = insert_after(s, "public void onCreate(Bundle savedInstanceState) {",
                         nl + "\t\tEOSSDK.init(this); " + MARK, p)
        write(p, s)
        print("GodotApp.java: EOS eklendi")
    else:
        print("GodotApp.java: zaten ekli")

    # --- gradle.properties: arka planda kalan gradle süreci (daemon) bir sonraki export'un ':clean' adımında android/build/build
    # klasörünü kilitli tutup "Unable to delete directory" ile derlemeyi düşürüyordu (2026-10-02) - daemon kapalı.
    p = os.path.join(BUILD, "gradle.properties")
    s = read(p)
    nl = "\r\n" if "\r\n" in s else "\n"
    if "org.gradle.daemon" not in s:
        if not s.endswith(nl):
            s += nl
        s += "# " + MARK[3:] + " - bkz. tools/setup_android_eos.py" + nl + "org.gradle.daemon=false" + nl
        write(p, s)
        print("gradle.properties: daemon kapatıldı")
    else:
        print("gradle.properties: daemon ayarı zaten var")

    # --- config.gradle minSdk >= 23
    p = os.path.join(BUILD, "config.gradle")
    s = read(p)
    m = re.search(r"minSdk\s*:\s*(\d+)", s)
    if m and int(m.group(1)) < 23:
        s = s[:m.start(1)] + "23" + s[m.end(1):]
        write(p, s)
        print("config.gradle: minSdk 23")
    else:
        print("config.gradle: minSdk zaten >= 23")


if __name__ == "__main__":
    main()
