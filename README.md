# Bambu Studio Mobile & PC Wall Bracket Suite

A cross-platform mobile (Android APK) and Web application engineered for Bambu Lab 3D printers (**A1 mini**, **A1**, **P1S**, **P1P**, **X1 Carbon**, and **X1E**), paired with precision parametric 3D print designs for desktop CPU wall mounting.

---

## 🚀 Key Features

### 1. 3D Model Prepare & Scene Viewport
- **Authentic Multi-Object Support:** Seamlessly imports Bambu Studio `.3mf` project files, binary/ASCII `.stl`, and Wavefront `.obj` models.
- **Interactive 3D Viewport:** Perspective projection, orbital pan/zoom/rotate controls, build-plate grid boundary visualization, and transform gizmos (Translate, Rotate, Scale).
- **Built-in Presets:** Pre-loaded with **CPU Wall Mount Brackets (Left & Right)**, **Tilt Phone Stand v3**, **Bambu A1 mini Scraper**, **Photo Wall Mounting Clip**, **3DBenchy**, and geometric calibration primitives.

### 2. Hybrid Slicing Engine & G-code Layer Preview
- **Desktop C++ Companion Bridge:** Connects to PC running `bambu_bridge_server.py` to invoke desktop Bambu Studio's native `libslic3r` C++ CLI over local Wi-Fi.
- **Offline / On-Device Slicing:** Lightweight procedural path generator for mobile standalone use.
- **Interactive 3D G-code Preview:** Layer-by-layer slider, toolpath velocity visualization, travel line display, and print statistics (estimated print time, filament weight, layer count).

### 3. Direct LAN-Only Mode Printer Control
- **True MQTTS (Port 8883) Communication:** Direct communication with Bambu Lab printers over local Wi-Fi without relying on cloud servers.
- **Tailored for Bambu Lab A1 mini:** Step-by-step connection guide using IP address and 8-digit LAN access code.
- **Real-Time Telemetry:** Live nozzle and heated bed temperatures, fan speeds, chamber LED toggle, print progress, layer counter, and emergency pause/resume/stop controls.
- **AMS & AMS lite Integration:** Tray filament type, color preview, loaded status, and remaining filament percentages.
- **HMS Error Diagnostic Dictionary:** Integrated lookup for Bambu Health Management System diagnostic error codes.

### 4. Multi-Device Print Farm
- Batch control across multiple printers simultaneously (batch pause, batch resume, batch lighting control).
- Status filtering by Printing, Idle, and Attention.

---

## 🖥️ PC Case Wall Mount Bracket (175mm Breadth)

Specially designed for mounting a 175mm wide CPU chassis securely to a wall using **PETG filament** on the **Bambu Lab A1 mini** (180 × 180 × 180 mm build volume):

| Specification | Value |
| :--- | :--- |
| **Compatible Printer** | Bambu Lab A1 mini (fits within 180×180 mm bed) |
| **Material** | PETG (High layer adhesion, creep resistance & thermal stability) |
| **Recommended Infill** | 35% - 40% Gyroid infill |
| **Wall Loops** | 4 - 5 perimeters for maximum load capacity |
| **Retention Lip** | Integrated safety edge prevents chassis slippage |
| **Files** | `models/pc_wall_bracket_design/pc_wall_bracket_left_A1mini.3mf`<br>`models/pc_wall_bracket_design/pc_wall_bracket_right_A1mini.3mf` |

---

## 📦 APK Installation & Web Access

### Universal Android Release APK
- **Latest Release:** `v1.0.1`
- **File:** `bambu_studio_mobile.apk` (61.4 MB)
- **Minimum Android Version:** Android 8.0 (API 26+)
- **Target Android Version:** Android 14+ (API 34/36)

### Running on Local Web
```bash
cd bambu_studio_flutter
python serve_flutter_web.py
```
Open `http://localhost:8088` in any browser.

### Starting the Bambu CLI Companion Bridge (Optional)
```bash
python bridge_server/bambu_bridge_server.py
```
Bridge server listens on port `8765` for slicing and LAN discovery.

---

## 🛠️ Building from Source

### Prerequisites
- Flutter SDK (v3.24+ or v3.50+)
- OpenJDK 17
- Android SDK (Platform 34+, Build-Tools 34.0.0+)

### Commands
```bash
# Get dependencies
flutter pub get

# Run static analysis
flutter analyze

# Build Web release
flutter build web --release

# Build Android APK release
flutter build apk --release
```

---

## 📄 License
MIT License. Free for personal and commercial 3D printing workflows.
