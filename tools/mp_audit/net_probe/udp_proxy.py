"""UDP gecikme/jitter/kayıp vekili (madde 349, net_probe). Kullanım: python -I udp_proxy.py LISTEN_PORT TARGET_PORT ONEWAY_MS JITTER_MS LOSS_PCT [SEED] [BW_KBPS] [QUEUE_MS]
İstemci vekile bağlanır; vekil paketleri (iki yönde) rastgele gecikmeyle (ONEWAY_MS +- JITTER_MS) iletir, LOSS_PCT yüzdesini düşürür.
Paket sırası bozulabilir (jitter yüzünden) - gerçek internet gibi.
BW_KBPS > 0 (madde 419): her yön için hat kapasitesi (kilobit/sn, ör. 1000 = 1 Mbps). Kapasiteyi aşan paketler sırayla bekler
(kuyruk gecikmesi = dar yükleme hattı / relay gibi); kuyruk QUEUE_MS'den (varsayılan 400) uzunsa yeni paket düşer (yönlendirici tamponu dolu)."""
import asyncio, random, sys

listen_port = int(sys.argv[1]); target_port = int(sys.argv[2])
oneway = float(sys.argv[3]) / 1000.0; jitter = float(sys.argv[4]) / 1000.0; loss = float(sys.argv[5]) / 100.0
rng = random.Random(int(sys.argv[6]) if len(sys.argv) > 6 else 1)
bw = float(sys.argv[7]) * 1000.0 / 8.0 if len(sys.argv) > 7 else 0.0  # bayt/sn
queue_max = (float(sys.argv[8]) if len(sys.argv) > 8 else 400.0) / 1000.0
stats = {"c2s": 0, "s2c": 0, "drop_c2s": 0, "drop_s2c": 0, "qdrop_c2s": 0, "qdrop_s2c": 0, "qmax_ms_c2s": 0, "qmax_ms_s2c": 0}
_busy_until = {"c2s": 0.0, "s2c": 0.0}  # hattın boşalacağı an (döngü saati)


def _link_delay(direction, size):
    """Kapasite sınırı: paket hattın boşalmasını bekler + kendi iletim süresi. None = kuyruk dolu, düşür."""
    if bw <= 0.0:
        return 0.0
    now = asyncio.get_running_loop().time()
    start = max(now, _busy_until[direction])
    wait = start - now
    if wait > queue_max:
        stats["qdrop_" + direction] += 1
        return None
    _busy_until[direction] = start + (size + 28) / bw  # +28: IP/UDP başlığı
    stats["qmax_ms_" + direction] = max(stats["qmax_ms_" + direction], int(wait * 1000))
    return _busy_until[direction] - now


class Front(asyncio.DatagramProtocol):
    def __init__(self):
        self.transport = None
        self.client = None
        self.back = None

    def connection_made(self, t):
        self.transport = t

    def datagram_received(self, data, addr):
        self.client = addr
        stats["c2s"] += 1
        if rng.random() < loss:
            stats["drop_c2s"] += 1
            return
        q = _link_delay("c2s", len(data))
        if q is None:
            return
        d = max(0.0, oneway + rng.uniform(-jitter, jitter)) + q
        asyncio.get_running_loop().call_later(d, self.back.transport.sendto, data)


class Back(asyncio.DatagramProtocol):
    def __init__(self, front):
        self.front = front
        self.transport = None

    def connection_made(self, t):
        self.transport = t

    def datagram_received(self, data, addr):
        stats["s2c"] += 1
        if rng.random() < loss:
            stats["drop_s2c"] += 1
            return
        if self.front.client is None:
            return
        q = _link_delay("s2c", len(data))
        if q is None:
            return
        d = max(0.0, oneway + rng.uniform(-jitter, jitter)) + q
        asyncio.get_running_loop().call_later(d, self.front.transport.sendto, data, self.front.client)


async def main():
    loop = asyncio.get_running_loop()
    front = Front()
    await loop.create_datagram_endpoint(lambda: front, local_addr=("127.0.0.1", listen_port))
    back = Back(front)
    await loop.create_datagram_endpoint(lambda: back, remote_addr=("127.0.0.1", target_port))
    front.back = back
    print(f"proxy {listen_port} -> {target_port} bir-yon={oneway*1000:.0f}ms jitter=+-{jitter*1000:.0f}ms kayip={loss*100:.1f}% hat={bw*8/1000:.0f}kbps", flush=True)
    while True:
        await asyncio.sleep(5)
        print("proxy stats", stats, flush=True)

asyncio.run(main())
