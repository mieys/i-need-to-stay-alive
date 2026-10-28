# bake_harita.gd'nin yazdığı scenes/harita_baked_new.tscn'e eski scenes/harita_baked.tscn'in uid'lerini geri yazar (sahne başlığı + ext_resource;
# yeni kaynaklar için .import / .uid dosyalarından), TileSet sayısını ve katman farkını yazdırır. Yerine koymayı (mv) çağıran yapar.
# Kullanım: python tools/derin_orman/uid_geri_yaz.py   (bkz. hafıza notu map-rebake-procedure)
import os
import re

OLD = 'scenes/harita_baked.tscn'
NEW = 'scenes/harita_baked_new.tscn'


def main():
    old = open(OLD, encoding='utf-8').read()
    new = open(NEW, encoding='utf-8').read()
    uid_scene = re.search(r'uid="([^"]+)"', re.match(r'\[gd_scene[^\]]*\]', old).group(0)).group(1)
    by_path = {m.group(2): m.group(1) for m in re.finditer(r'\[ext_resource[^\]]*uid="([^"]+)"[^\]]*path="([^"]+)"', old)}

    def uid_for(path):
        if path in by_path:
            return by_path[path]
        p = path.replace('res://', '')
        for cand in (p + '.import', p + '.uid'):
            if os.path.exists(cand):
                m = re.search(r'uid="?(uid://[a-z0-9]+)', open(cand, encoding='utf-8').read())
                if m:
                    return m.group(1)
        return None
    hdr = re.match(r'\[gd_scene[^\]]*\]', new).group(0)
    if 'uid=' not in hdr:
        new = new.replace(hdr, hdr[:-1] + ' uid="%s"]' % uid_scene, 1)
    missing = []

    def fix(m):
        line = m.group(0)
        if 'uid=' in line:
            return line
        path = re.search(r'path="([^"]+)"', line).group(1)
        u = uid_for(path)
        if u is None:
            missing.append(path)
            return line
        return line.replace(' path=', ' uid="%s" path=' % u, 1)
    new = re.sub(r'\[ext_resource[^\]]*\]', fix, new)
    open(NEW, 'w', encoding='utf-8', newline='\n').write(new)
    print('sahne uid', uid_scene, '| uid eksik:', missing)
    print('TileSet:', len(re.findall(r'\[sub_resource type="TileSet"', new)), '| ext_resource eski/yeni:',
          len(re.findall(r'\[ext_resource', old)), len(re.findall(r'\[ext_resource', new)))


if __name__ == '__main__':
    main()
