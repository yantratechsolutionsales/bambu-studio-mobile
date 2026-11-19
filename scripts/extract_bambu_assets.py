import json
import os
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BAMBU_RES = ROOT / "BambuStudio" / "resources"
OUT_ASSETS = ROOT / "bambu_studio_flutter" / "assets" / "bambu_data"
OUT_IMAGES = OUT_ASSETS / "printers"
OUT_MODELS = OUT_ASSETS / "models"


def load_json(path: Path):
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        return json.load(f)


def resolve_inheritance(name: str, pool: dict, visited=None) -> dict:
    if visited is None:
        visited = set()
    if name in visited or name not in pool:
        return {}
    visited.add(name)
    raw = pool[name]
    parent_name = raw.get("inherits")
    merged = {}
    if parent_name:
        merged.update(resolve_inheritance(parent_name, pool, visited))
    merged.update(raw)
    return merged


def first_val(v, default=None):
    if isinstance(v, list):
        return v[0] if v else default
    return v if v is not None else default


def to_float(v, default=0.0):
    val = first_val(v, default)
    if val in (None, "", "nil"):
        return default
    try:
        return float(str(val).replace("%", "").strip())
    except Exception:
        return default


def to_int(v, default=0):
    return int(round(to_float(v, float(default))))


def extract_printers():
    machine_dir = BAMBU_RES / "profiles" / "BBL" / "machine"
    pool = {}
    models = {}
    for p in machine_dir.glob("*.json"):
        try:
            data = load_json(p)
        except Exception:
            continue
        name = data.get("name", p.stem)
        if data.get("type") == "machine_model":
            models[name] = data
        else:
            pool[name] = data

    # Map bed sizes from image_bed_type or printable_area
    bed_defaults = {
        "180": [180, 180, 180],
        "256": [256, 256, 256],
        "350": [350, 320, 325],
    }

    printers = []
    for model_name, mdata in sorted(models.items()):
        nozzles = [n.strip() for n in str(mdata.get("nozzle_diameter", "0.4")).split(";") if n.strip()]
        # Find corresponding 0.4 nozzle machine profile for printable_area / printable_height
        prof_name = f"{model_name} 0.4 nozzle"
        resolved = resolve_inheritance(prof_name, pool) if prof_name in pool else {}
        bed_x, bed_y, bed_z = bed_defaults.get(str(mdata.get("image_bed_type", "256")), [256, 256, 256])

        pa = resolved.get("printable_area")
        if isinstance(pa, list) and len(pa) >= 3:
            try:
                xs = [float(pt.split("x")[0]) for pt in pa]
                ys = [float(pt.split("x")[1]) for pt in pa]
                bed_x = int(round(max(xs) - min(xs)))
                bed_y = int(round(max(ys) - min(ys)))
            except Exception:
                pass
        if resolved.get("printable_height"):
            bed_z = to_int(resolved.get("printable_height"), bed_z)

        # Copy cover image if present
        cover_src = BAMBU_RES / "profiles" / "BBL" / f"{model_name}_cover.png"
        cover_asset = None
        if cover_src.exists():
            safe_name = model_name.lower().replace(" ", "_") + "_cover.png"
            shutil.copy2(cover_src, OUT_IMAGES / safe_name)
            cover_asset = f"assets/bambu_data/printers/{safe_name}"

        has_chamber = any(k in model_name for k in ("X1", "X2", "H2", "H3", "P1S", "P2S"))
        has_lidar = any(k in model_name for k in ("X1", "X2", "H2", "H3"))
        dual_extruder = any(k in model_name for k in ("H2D", "H2C", "H3C", "X2D"))

        printers.append({
            "id": mdata.get("model_id", model_name.lower().replace(" ", "_")),
            "name": model_name,
            "family": mdata.get("family", "BBL-3DP"),
            "nozzles": nozzles,
            "defaultBedType": mdata.get("default_bed_type", "Textured PEI Plate"),
            "defaultPrintProfile": resolved.get("default_print_profile", "0.20mm Standard @BBL X1C"),
            "bedX": bed_x,
            "bedY": bed_y,
            "bedZ": bed_z,
            "maxSpeed": to_int(resolved.get("machine_max_speed_x"), 500),
            "maxAccel": to_int(resolved.get("machine_max_acceleration_x"), 20000),
            "hasEnclosedChamber": has_chamber,
            "hasLidar": has_lidar,
            "isDualExtruder": dual_extruder,
            "coverAsset": cover_asset,
        })

    return printers


def extract_filaments():
    fil_dir = BAMBU_RES / "profiles" / "BBL" / "filament"
    pool = {}
    for p in fil_dir.rglob("*.json"):
        try:
            data = load_json(p)
        except Exception:
            continue
        name = data.get("name", p.stem)
        pool[name] = data

    # Deduplicate by clean display name (prefer @BBL X1C or @base)
    seen = {}
    for name, raw in pool.items():
        if raw.get("type") != "filament":
            continue
        clean = name.split(" @")[0].strip()
        is_preferred = "@BBL X1C" in name or "@base" in name or name == clean
        if clean not in seen or is_preferred:
            resolved = resolve_inheritance(name, pool)
            ftype = str(first_val(resolved.get("filament_type"), "PLA"))
            if not ftype:
                ftype = "PLA"
            color_hex = str(first_val(resolved.get("default_filament_colour"), "")).strip()
            if not color_hex.startswith("#"):
                color_map = {
                    "PLA": "#00AE42",
                    "PETG": "#0078D4",
                    "ABS": "#E85D04",
                    "ASA": "#D00000",
                    "TPU": "#9B5DE5",
                    "PA": "#3A3A3C",
                    "PA-CF": "#2B2D42",
                    "PC": "#A8DADC",
                    "PVA": "#F4D35E",
                    "SUPPORT": "#E9ECEF",
                }
                color_hex = color_map.get(ftype.upper(), "#00AE42")
            seen[clean] = {
                "id": str(first_val(resolved.get("filament_id"), clean.lower().replace(" ", "_"))),
                "name": clean,
                "vendor": str(first_val(resolved.get("filament_vendor"), "Bambu")),
                "type": ftype,
                "nozzleTemp": to_int(resolved.get("nozzle_temperature"), 220),
                "nozzleTempInitial": to_int(resolved.get("nozzle_temperature_initial_layer"), 220),
                "bedTemp": to_int(resolved.get("textured_plate_temp"), to_int(resolved.get("hot_plate_temp"), 55)),
                "flowRatio": to_float(resolved.get("filament_flow_ratio"), 0.98),
                "maxVolumetricSpeed": to_float(resolved.get("filament_max_volumetric_speed"), 21.0),
                "density": to_float(resolved.get("filament_density"), 1.24),
                "costPerKg": to_float(resolved.get("filament_cost"), 24.99),
                "pressureAdvanceK": 0.02,
                "fanMin": to_int(resolved.get("fan_min_speed"), 60),
                "fanMax": to_int(resolved.get("fan_max_speed"), 100),
                "defaultColor": color_hex,
            }

    filaments = sorted(seen.values(), key=lambda x: (0 if "Bambu" in x["name"] else 1, x["name"]))
    return filaments[:80]


def extract_processes():
    proc_dir = BAMBU_RES / "profiles" / "BBL" / "process"
    pool = {}
    for p in proc_dir.glob("*.json"):
        try:
            data = load_json(p)
        except Exception:
            continue
        pool[data.get("name", p.stem)] = data

    seen = {}
    for name, raw in pool.items():
        if raw.get("type") != "process" or raw.get("instantiation") != "true":
            continue
        if "@BBL X1C" not in name and "@BBL A1" not in name:
            continue
        clean = name.split(" @")[0].strip()
        if clean in seen and "@BBL X1C" not in name:
            continue
        r = resolve_inheritance(name, pool)
        seen[clean] = {
            "name": clean,
            "description": str(r.get("description", "")),
            "layerHeight": to_float(r.get("layer_height"), 0.20),
            "initialLayerHeight": to_float(r.get("initial_layer_print_height"), 0.20),
            "lineWidth": to_float(r.get("line_width"), 0.42),
            "outerWallLineWidth": to_float(r.get("outer_wall_line_width"), 0.42),
            "innerWallLineWidth": to_float(r.get("inner_wall_line_width"), 0.45),
            "wallLoops": to_int(r.get("wall_loops"), 2),
            "topShellLayers": to_int(r.get("top_shell_layers"), 4),
            "bottomShellLayers": to_int(r.get("bottom_shell_layers"), 3),
            "sparseInfillDensity": to_int(r.get("sparse_infill_density"), 15),
            "sparseInfillPattern": str(first_val(r.get("sparse_infill_pattern"), "grid")),
            "outerWallSpeed": to_int(r.get("outer_wall_speed"), 200),
            "innerWallSpeed": to_int(r.get("inner_wall_speed"), 300),
            "sparseInfillSpeed": to_int(r.get("sparse_infill_speed"), 270),
            "topSurfaceSpeed": to_int(r.get("top_surface_speed"), 200),
            "initialLayerSpeed": to_int(r.get("initial_layer_speed"), 50),
            "travelSpeed": to_int(r.get("travel_speed"), 500),
            "defaultAcceleration": to_int(r.get("default_acceleration"), 10000),
            "outerWallAcceleration": to_int(r.get("outer_wall_acceleration"), 5000),
            "enableSupport": str(first_val(r.get("enable_support"), "0")) == "1",
            "supportType": str(first_val(r.get("support_type"), "normal(auto)")),
            "brimType": str(first_val(r.get("brim_type"), "auto_brim")),
            "enableArcFitting": str(first_val(r.get("enable_arc_fitting"), "1")) == "1",
            "seamPosition": str(first_val(r.get("seam_position"), "aligned")),
            "wallGenerator": str(first_val(r.get("wall_generator"), "classic")),
        }

    return sorted(seen.values(), key=lambda x: (x["layerHeight"], x["name"]))


def extract_hms():
    hms_dir = BAMBU_RES / "hms"
    entries = {}
    for p in sorted(hms_dir.glob("hms_en_*.json")):
        try:
            data = load_json(p)
            items = data.get("data", {}).get("device_hms", {}).get("en", [])
            for item in items:
                code = item.get("ecode", "").strip()
                intro = item.get("intro", "").strip()
                if code and intro and code not in entries:
                    # Format code as 0C00-0200-0001-0001
                    pretty = "-".join([code[i:i+4] for i in range(0, len(code), 4)]) if len(code) == 16 else code
                    module_prefix = code[:4]
                    module_map = {
                        "0300": "Motion / Toolhead",
                        "0500": "Network / System",
                        "0700": "AMS / Filament",
                        "0C00": "LiDAR / Vision / AI",
                        "0D00": "Heatbed / Thermal",
                        "1200": "AMS Hub / Buffer",
                    }
                    severity = "Error" if code[8:12] in ("0001", "0003") else "Warning"
                    entries[code] = {
                        "code": pretty,
                        "rawCode": code,
                        "module": module_map.get(module_prefix, "Printer Core"),
                        "severity": severity,
                        "message": intro,
                    }
        except Exception:
            continue
    return list(entries.values())[:250]


def copy_sample_models():
    model_dir = BAMBU_RES / "model"
    wanted = ["Bambu_Cube.stl", "3DBenchy.stl", "cone.stl", "torus.stl", "Disc.stl"]
    copied = []
    for fname in wanted:
        src = model_dir / fname
        if src.exists():
            shutil.copy2(src, OUT_MODELS / fname)
            copied.append(f"assets/bambu_data/models/{fname}")
    return copied


def main():
    OUT_IMAGES.mkdir(parents=True, exist_ok=True)
    OUT_MODELS.mkdir(parents=True, exist_ok=True)

    printers = extract_printers()
    filaments = extract_filaments()
    processes = extract_processes()
    hms = extract_hms()
    flush_src = BAMBU_RES / "flush" / "flush_data_material_pair.json"
    flush_data = load_json(flush_src) if flush_src.exists() else {"pairs": []}
    models = copy_sample_models()

    (OUT_ASSETS / "printers.json").write_text(json.dumps(printers, indent=2), encoding="utf-8")
    (OUT_ASSETS / "filaments.json").write_text(json.dumps(filaments, indent=2), encoding="utf-8")
    (OUT_ASSETS / "processes.json").write_text(json.dumps(processes, indent=2), encoding="utf-8")
    (OUT_ASSETS / "hms_en.json").write_text(json.dumps(hms, indent=2), encoding="utf-8")
    (OUT_ASSETS / "flush_matrix.json").write_text(json.dumps(flush_data, indent=2), encoding="utf-8")

    print(f"Extracted {len(printers)} printers, {len(filaments)} filaments, {len(processes)} processes, {len(hms)} HMS codes, {len(models)} STL models.")


if __name__ == "__main__":
    main()
