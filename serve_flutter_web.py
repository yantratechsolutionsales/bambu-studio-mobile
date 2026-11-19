import http.server
import mimetypes
import os
import socketserver
from pathlib import Path

WEB_DIR = Path(__file__).resolve().parent / "build" / "web"

class SPAServer(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_DIR), **kwargs)

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def do_GET(self):
        req_path = self.path.split("?")[0].lstrip("/")
        full_path = WEB_DIR / req_path
        if not full_path.exists() and "." not in req_path:
            self.path = "/index.html"
        return super().do_GET()

if __name__ == "__main__":
    mimetypes.add_type("application/javascript", ".js")
    mimetypes.add_type("application/wasm", ".wasm")
    port = 8088
    print(f"Flutter Web SPA Server starting on http://0.0.0.0:{port} from {WEB_DIR}")
    with socketserver.TCPServer(("0.0.0.0", port), SPAServer) as httpd:
        httpd.serve_forever()
