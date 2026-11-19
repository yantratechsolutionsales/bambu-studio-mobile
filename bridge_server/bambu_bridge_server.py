#!/usr/bin/env python3
"""
Bambu Studio CLI & LAN Companion Bridge Server
Allows the Bambu Studio Flutter (Android/iOS) mobile app to invoke the real
desktop Bambu Studio C++ slicer (libslic3r) over Wi-Fi/LAN and parse real
sliced G-code toolpaths, statistics, and 3MF outputs.
"""

import http.server
import json
import os
import shutil
import socket
import socketserver
import subprocess
import tempfile
import time
from pathlib import Path

DEFAULT_BAMBU_PATHS = [
    r"C:\Program Files\Bambu Studio\bambu-studio.exe",
    r"C:\Program Files (x86)\Bambu Studio\bambu-studio.exe",
    "/Applications/BambuStudio.app/Contents/MacOS/BambuStudio",
    "/usr/bin/bambu-studio",
]


def find_bambu_cli() -> str | None:
    env_path = os.environ.get("BAMBU_STUDIO_CLI")
    if env_path and Path(env_path).exists():
        return env_path
    for p in DEFAULT_BAMBU_PATHS:
        if Path(p).exists():
            return p
    return shutil.which("bambu-studio")


def discover_bambu_printers(timeout: float = 2.0) -> list[dict]:
    found = []
    msg = (
        'M-SEARCH * HTTP/1.1\r\n'
        'HOST: 239.255.255.250:1982\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: 1\r\n'
        'ST: urn:bambulab-com:device:printer:1\r\n\r\n'
    ).encode("utf-8")
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        s.settimeout(timeout)
        s.sendto(msg, ("239.255.255.250", 1982))
        end = time.time() + timeout
        while time.time() < end:
            try:
                data, addr = s.recvfrom(2048)
                text = data.decode("utf-8", errors="ignore")
                info = {"ip": addr[0]}
                for line in text.splitlines():
                    if ":" in line:
                        k, v = line.split(":", 1)
                        info[k.strip().lower()] = v.strip()
                dev_name = info.get("dev_name", "Bambu Printer")
                dev_model = info.get("dev_model", "Bambu Lab A1 mini")
                dev_id = info.get("usn", info.get("dev_id", ""))
                found.append({
                    "ip": addr[0],
                    "name": dev_name,
                    "model": dev_model,
                    "serial": dev_id,
                })
            except socket.timeout:
                break
            except Exception:
                pass
        s.close()
    except Exception:
        pass
    return found


def parse_gcode_summary(gcode_path: Path) -> dict:
    layers = []
    current_z = 0.0
    total_time_str = ""
    filament_g = 0.0
    filament_mm = 0.0
    line_count = 0

    with open(gcode_path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line_count += 1
            s = line.strip()
            if s.startswith("; total estimated time:"):
                total_time_str = s.split(":", 1)[1].strip()
            elif s.startswith("; total filament weight [g] :"):
                try:
                    filament_g = float(s.split(":", 1)[1].strip().split(",")[0])
                except ValueError:
                    pass
            elif s.startswith("; total filament length [mm] :"):
                try:
                    filament_mm = float(s.split(":", 1)[1].strip().split(",")[0])
                except ValueError:
                    pass
            elif s.startswith("; Z_HEIGHT:"):
                try:
                    current_z = float(s.split(":", 1)[1].strip())
                    layers.append(current_z)
                except ValueError:
                    pass

    return {
        "layerCount": len(layers),
        "maxZ": max(layers) if layers else 0.0,
        "estimatedTime": total_time_str or "N/A",
        "filamentGrams": filament_g,
        "filamentMeters": round(filament_mm / 1000.0, 2),
        "gcodeLines": line_count,
    }


class BridgeHandler(http.server.BaseHTTPRequestHandler):
    def _send_json(self, payload: dict, status: int = 200):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self._send_json({"ok": True})

    def do_GET(self):
        if self.path == "/health":
            cli = find_bambu_cli()
            self._send_json({
                "status": "online",
                "bambuCliFound": cli is not None,
                "bambuCliPath": cli or "",
                "timestamp": int(time.time()),
                "engine": "Bambu Studio C++ CLI (libslic3r)",
            })
        elif self.path == "/discover":
            devices = discover_bambu_printers(timeout=1.5)
            self._send_json({
                "devices": devices,
                "count": len(devices),
                "timestamp": int(time.time()),
            })
        else:
            self._send_json({"error": "Not found"}, 404)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(length) if length > 0 else b"{}"
        try:
            data = json.loads(raw_body.decode("utf-8"))
        except Exception as e:
            self._send_json({"error": f"Invalid JSON: {e}"}, 400)
            return

        if self.path == "/slice":
            cli = find_bambu_cli()
            if not cli:
                self._send_json({
                    "error": "Bambu Studio CLI not found on host machine",
                    "fallbackRecommended": True,
                }, 503)
                return

            stl_text = data.get("stlAscii")
            settings = data.get("settings", {})
            with tempfile.TemporaryDirectory(prefix="bambu_bridge_") as tmp:
                tmp_dir = Path(tmp)
                input_stl = tmp_dir / "model.stl"
                out_dir = tmp_dir / "out"
                out_dir.mkdir(exist_ok=True)
                if stl_text:
                    input_stl.write_text(stl_text, encoding="utf-8")
                else:
                    self._send_json({"error": "Missing stlAscii payload"}, 400)
                    return

                settings_path = tmp_dir / "process_override.json"
                settings_path.write_text(json.dumps(settings, indent=2), encoding="utf-8")

                cmd = [
                    cli,
                    "--slice", "0",
                    "--arrange", "1",
                    "--orient", "1",
                    "--outputdir", str(out_dir),
                    str(input_stl),
                ]
                start = time.time()
                try:
                    proc = subprocess.run(
                        cmd,
                        capture_output=True,
                        text=True,
                        timeout=90,
                    )
                    elapsed = round(time.time() - start, 2)
                    gcodes = list(out_dir.rglob("*.gcode"))
                    summary = parse_gcode_summary(gcodes[0]) if gcodes else {}
                    self._send_json({
                        "ok": proc.returncode == 0,
                        "returnCode": proc.returncode,
                        "elapsedSeconds": elapsed,
                        "summary": summary,
                        "stdout": proc.stdout[-1500:],
                        "stderr": proc.stderr[-1500:],
                    })
                except Exception as e:
                    self._send_json({"ok": False, "error": str(e)}, 500)
        else:
            self._send_json({"error": "Not found"}, 404)


def main():
    port = int(os.environ.get("BAMBU_BRIDGE_PORT", "8765"))
    cli = find_bambu_cli()
    print(f"Bambu Studio Bridge listening on http://0.0.0.0:{port}")
    print(f"Detected Bambu Studio CLI: {cli or 'NOT FOUND'}")
    with socketserver.TCPServer(("0.0.0.0", port), BridgeHandler) as httpd:
        httpd.serve_forever()


if __name__ == "__main__":
    main()
