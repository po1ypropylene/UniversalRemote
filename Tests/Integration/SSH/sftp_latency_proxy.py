"""Owned loopback transport proxy with fixed 10 ms delay in each direction."""
import asyncio
from pathlib import Path
import sys

async def main():
    async def handle(reader, writer):
        peer_reader, peer_writer = await asyncio.open_connection('127.0.0.1', int(sys.argv[1]))
        async def relay(source, destination):
            pending = asyncio.Queue()
            async def read():
                try:
                    while data := await source.read(65536):
                        await pending.put((asyncio.get_running_loop().time() + 0.010, data))
                finally: await pending.put((0, None))
            async def write():
                while True:
                    when, data = await pending.get()
                    if data is None: break
                    await asyncio.sleep(max(0, when-asyncio.get_running_loop().time()))
                    destination.write(data)
                    await destination.drain()
            try: await asyncio.gather(read(), write())
            finally: destination.close()
        await asyncio.gather(relay(reader, peer_writer), relay(peer_reader, writer), return_exceptions=True)
    server = await asyncio.start_server(handle, '127.0.0.1', 0)
    Path(sys.argv[2]).write_text(str(server.sockets[0].getsockname()[1]))
    async with server: await server.serve_forever()
asyncio.run(main())
