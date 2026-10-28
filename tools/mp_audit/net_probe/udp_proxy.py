"""UDP gecikme/jitter/kayıp vekili (madde 349, net_probe). Kullanım: python -I udp_proxy.py LISTEN_PORT TARGET_PORT ONEWAY_MS JITTER_MS LOSS_PCT [SEED]
İstemci vekile bağlanır; vekil paketleri (iki yönde) rastgele gecikmeyle (ONEWAY_MS +- JITTER_MS) iletir, LOSS_PCT yüzdesini düşürür.
Paket sırası bozulabilir (jitter yüzünden) - gerçek internet gibi."""
import asyncio, random, sys

listen_port = int(sys.argv[1]); target_port = int(sys.argv[2])
oneway = float(sys.argv[3]) / 1000.0; jitter = float(sys.argv[4]) / 1000.0; loss = float(sys.argv[5]) / 100.0
rng = random.Random(int(sys.argv[6]) if len(sys.argv) > 6 else 1)
stats = {"c2s": 0, "s2c": 0, "drop_c2s": 0, "drop_s2c": 0}


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
        d = max(0.0, oneway + rng.uniform(-jitter, jitter))
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
        d = max(0.0, oneway + rng.uniform(-jitter, jitter))
        asyncio.get_running_loop().call_later(d, self.front.transport.sendto, data, self.front.client)


async def main():
    loop = asyncio.get_running_loop()
    front = Front()
    await loop.create_datagram_endpoint(lambda: front, local_addr=("127.0.0.1", listen_port))
    back = Back(front)
    await loop.create_datagram_endpoint(lambda: back, remote_addr=("127.0.0.1", target_port))
    front.back = back
    print(f"proxy {listen_port} -> {target_port} bir-yon={oneway*1000:.0f}ms jitter=+-{jitter*1000:.0f}ms kayip={loss*100:.1f}%", flush=True)
    while True:
        await asyncio.sleep(5)
        print("proxy stats", stats, flush=True)

asyncio.run(main())
