"""Статика build/web с fallback на index.html (go_router path URLs).

    python spa_server.py 5600

Supabase принимает запросы с любого адреса (CORS), порт может быть любым.
"""
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent / "build" / "web"


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def send_error(self, code, message=None, explain=None):
        if code == 404:
            self.path = "/index.html"
            return self.do_GET()
        return super().send_error(code, message, explain)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5600
    httpd = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"Serving {ROOT} on http://127.0.0.1:{port}/")
    httpd.serve_forever()
