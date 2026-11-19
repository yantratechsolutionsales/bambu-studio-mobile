"""
Rigid Heavy-Duty Wall-Mount PC / CPU Bracket Pair (175 mm Breadth)
Engineered for Bambu Lab A1 Mini (180 x 180 x 180 mm) in PETG Filament.

Matches the sleek industrial design of the reference photos while optimizing
cross-sections, layer-line orientation, and 45-degree internal haunches for
maximum PETG structural rigidity and 100% support-free printability.

Key Specifications:
- Target CPU / PC Cabinet Breadth: 175.0 mm
- Clear Shelf Tray Pocket (Wall to Front Lip): 178.0 mm (+3.0 mm fit & PETG shrinkage allowance)
- Total Bracket Length (Wall to Front Outer Tip): 184.5 mm
- Bracket Height: 110.0 mm shelf top (120.0 mm total height including 10.0 mm retaining lips)
- Bracket Width (Print Z-Height): 56.0 mm (49.0 mm flat bearing shelf + 7.0 mm outer side rail)
- Solid Wall Thicknesses: 10.0 mm Shelf | 9.0 mm Wall Plate | 9.0 mm Outer Gusset | 6.5 mm Front Lip
- Zero-Overhang Stiffening: 20 mm 45-deg tapered under-shelf haunch + 12 mm 45-deg wall haunch + R6 root fillet
- Wall Mounting: 3 self-supporting teardrop holes (Ø6.2 mm for M5/#10/M6) aligned vertically at Z=38.0 mm
  with full drill-chuck clearance (28 mm below shelf underside, 29 mm clear of outer gusset).
- A1 Mini Fit: Pre-oriented flat on Z=0 and rotated diagonally (~21.3 deg) to ~176.6 x 176.6 x 56.0 mm.
"""

import os
import sys
import math
import zipfile
import datetime
import numpy as np
import trimesh
import manifold3d as m3d
import lib3mf
from shapely.geometry import Polygon
from shapely.geometry.polygon import orient
from shapely.ops import unary_union

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT_DIR)
from app.engine.printability import audit_mesh_printability


# ==============================================================================
# Helper Utilities
# ==============================================================================
def manifold_to_trimesh(m: m3d.Manifold) -> trimesh.Trimesh:
    mesh = m.to_mesh()
    verts = np.asarray(mesh.vert_properties[:, :3], dtype=np.float64)
    faces = np.asarray(mesh.tri_verts, dtype=np.int64)
    tm = trimesh.Trimesh(vertices=verts, faces=faces, process=False)
    tm.fix_normals()
    return tm


def shapely_to_cross_section(poly: Polygon) -> m3d.CrossSection:
    if poly.is_empty:
        raise ValueError("Empty polygon passed to shapely_to_cross_section")
    poly = orient(poly, sign=1.0)
    ext = np.asarray(poly.exterior.coords[:-1], dtype=np.float64)
    contours = [ext]
    for interior in poly.interiors:
        contours.append(np.asarray(interior.coords[:-1], dtype=np.float64))
    return m3d.CrossSection(contours)


def extrude_shapely(poly: Polygon, height: float, z_offset: float = 0.0) -> m3d.Manifold:
    cs = shapely_to_cross_section(poly)
    solid = m3d.Manifold.extrude(cs, height)
    if abs(z_offset) > 1e-9:
        solid = solid.translate([0.0, 0.0, z_offset])
    return solid


def arc_points(cx: float, cy: float, r: float, a0_deg: float, a1_deg: float, n: int = 18) -> list:
    angles = np.linspace(math.radians(a0_deg), math.radians(a1_deg), n)
    return [(cx + r * math.cos(a), cy + r * math.sin(a)) for a in angles]


def make_fillet_corner_cut(cx: float, cy: float, r: float, quadrant: str, n: int = 18) -> Polygon:
    """
    Creates an additive concave fillet wedge or subtractive convex corner cut.
    """
    if quadrant == "top_right_convex":
        # Removes sharp corner at (cx, cy) where edges go -X and -Y
        # Arc center at (cx - r, cy - r), from 0 to 90 deg
        pts = [(cx + 1.0, cy + 1.0), (cx - r, cy + 1.0), (cx - r, cy)]
        pts += arc_points(cx - r, cy - r, r, 90.0, 0.0, n)
        pts += [(cx, cy - r), (cx + 1.0, cy - r)]
        return Polygon(pts)
    raise ValueError(f"Unknown quadrant: {quadrant}")


def make_teardrop_hole_prism(
    y_center: float,
    z_center: float,
    radius: float,
    x_start: float,
    x_end: float,
    chamfer_x: float = 9.0,
    chamfer_size: float = 1.0,
    n_arc: int = 48
) -> m3d.Manifold:
    """
    Constructs a single watertight X-axis teardrop bore (45-deg self-supporting peak in +Z)
    with an integrated 45-deg entry chamfer at chamfer_x (no coplanar boolean overlaps).
    """
    def teardrop_pts(r: float) -> np.ndarray:
        thetas = np.linspace(math.radians(135.0), math.radians(405.0), n_arc)
        pts = [(y_center + r * math.cos(th), z_center + r * math.sin(th)) for th in thetas]
        pts.append((y_center, z_center + r * math.sqrt(2.0)))
        return np.asarray(pts, dtype=np.float64)

    p_core = teardrop_pts(radius)
    p_flare = teardrop_pts(radius + chamfer_size)
    n_pts = len(p_core)

    w_vals = [x_start, chamfer_x - chamfer_size, chamfer_x, x_end]
    rings_2d = [p_core, p_core, p_flare, p_flare]

    verts = []
    for w, ring in zip(w_vals, rings_2d):
        for u, v in ring:
            verts.append([u, v, w])

    bot_c = len(verts)
    verts.append([y_center, z_center, x_start])
    top_c = len(verts)
    verts.append([y_center, z_center, x_end])

    faces = []
    for r_idx in range(len(w_vals) - 1):
        b0 = r_idx * n_pts
        b1 = (r_idx + 1) * n_pts
        for i in range(n_pts):
            j = (i + 1) % n_pts
            faces.append([b0 + i, b0 + j, b1 + j])
            faces.append([b0 + i, b1 + j, b1 + i])

    last_b = (len(w_vals) - 1) * n_pts
    for i in range(n_pts):
        j = (i + 1) % n_pts
        faces.append([bot_c, j, i])
        faces.append([top_c, last_b + i, last_b + j])

    hole_mesh = m3d.Mesh64(
        vert_properties=np.asarray(verts, dtype=np.float64),
        tri_verts=np.asarray(faces, dtype=np.uint32)
    )
    hole_uvw = m3d.Manifold(hole_mesh)

    # Map (u=y, v=z, w=x) -> (x=w, y=u, z=v) (det = +1)
    M = np.array([
        [0.0, 0.0, 1.0, 0.0],
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 1.0, 0.0, 0.0],
    ], dtype=np.float64)
    return hole_uvw.transform(M)


# ==============================================================================
# 2. Exact Parametric Bracket Builder (Left Bracket in Local Print Space)
# ==============================================================================
def build_left_bracket(
    cpu_breadth: float = 175.0,
    fit_clearance: float = 3.0,     # 178.0 mm clear tray for 175 mm CPU + shrinkage/pad room
    t_front_lip: float = 6.5,       # 6.5 mm thick solid front lip -> L_total = 184.5 mm
    lip_height: float = 10.0,       # 10.0 mm retaining lip height above shelf surface
    t_shelf: float = 10.0,          # 10.0 mm thick horizontal shelf
    t_wall: float = 9.0,            # 9.0 mm thick vertical wall-mounting plate
    t_gusset: float = 9.0,          # 9.0 mm thick outer triangular gusset
    t_side_rail: float = 7.0,       # 7.0 mm thick outer side retaining rail
    bracket_width: float = 56.0,    # 56.0 mm total width (print Z height)
    h_shelf_top: float = 110.0,     # y = 110.0 mm shelf bearing top (120.0 mm total with lip)
    front_step: float = 32.0,       # Front overhang step beyond gusset (x_gusset = 152.5 mm)
    tab_height: float = 22.0,       # Bottom screw tab height below gusset diagonal
    gusset_front_drop: float = 14.0,# Vertical drop of gusset front edge below shelf underside
    haunch_shelf_depth: float = 20.0,# 45-deg tapered under-shelf haunch depth
    haunch_wall_depth: float = 12.0, # 45-deg tapered wall-plate haunch depth
    screw_z: float = 38.0,          # Vertical plumb line Z-offset for all 3 wall screws
    screw_hole_dia: float = 6.2     # Clearance for M5 / #10 / M6 screws
) -> tuple[m3d.Manifold, dict]:
    """
    Constructs the Left PC Wall-Mount Bracket cleanly on Z >= 0 (outer face at Z = 0).
    """
    L_clear = cpu_breadth + fit_clearance       # 178.0 mm
    L_total = L_clear + t_front_lip             # 184.5 mm
    y_shelf_bot = h_shelf_top - t_shelf         # 100.0 mm
    y_lip_top = h_shelf_top + lip_height        # 120.0 mm
    x_gusset_front = L_total - front_step       # 152.5 mm
    y_gusset_front_bot = y_shelf_bot - gusset_front_drop  # 86.0 mm

    # ------------------------------------------------------------------
    # A. Main L-Profile Body (Wall Plate + Top Shelf + Front Lip)
    #    Extruded across full width Z = 0 .. bracket_width (56.0 mm)
    # ------------------------------------------------------------------
    # Build crisp outer outline with explicit smooth corner fillets:
    r_bot_front = 3.5   # bottom-front of wall tab (x=t_wall, y=0)
    r_bot_back = 1.0    # tiny relief at bottom-wall corner (x=0, y=0)
    r_shelf_front_bot = 3.5 # front-bottom of shelf tip (x=L_total, y=y_shelf_bot)
    r_lip_front_top = 3.0   # front-top of front lip (x=L_total, y=y_lip_top)
    r_lip_inner_top = 2.0   # inner-top of front lip (x=L_clear, y=y_lip_top)
    r_lip_pocket = 1.5      # small inner corner fillet at pocket (x=L_clear, y=h_shelf_top)
    r_root = 6.0            # R6 mm smooth concave root fillet at wall-shelf corner (x=t_wall, y=y_shelf_bot)

    l_pts = []
    # Bottom-wall corner (x=0, y=0) -> tiny bevel
    l_pts.append((0.0, r_bot_back))
    l_pts.append((r_bot_back, 0.0))
    # Bottom of tab to bottom-front rounded corner (x=t_wall, y=0)
    l_pts.extend(arc_points(t_wall - r_bot_front, r_bot_front, r_bot_front, -90.0, 0.0, 14))
    # Straight up wall plate to root fillet start
    l_pts.append((t_wall, y_shelf_bot - r_root))
    # Concave R6 fillet into shelf underside (center at (t_wall + r_root, y_shelf_bot - r_root), 180 -> 90 deg)
    l_pts.extend(arc_points(t_wall + r_root, y_shelf_bot - r_root, r_root, 180.0, 90.0, 18))
    # Straight along shelf underside to front-bottom fillet
    l_pts.extend(arc_points(L_total - r_shelf_front_bot, y_shelf_bot + r_shelf_front_bot, r_shelf_front_bot, -90.0, 0.0, 14))
    # Straight up front outer face to top-front fillet
    l_pts.extend(arc_points(L_total - r_lip_front_top, y_lip_top - r_lip_front_top, r_lip_front_top, 0.0, 90.0, 14))
    # Top of front lip to inner-top fillet
    l_pts.extend(arc_points(L_clear + r_lip_inner_top, y_lip_top - r_lip_inner_top, r_lip_inner_top, 90.0, 180.0, 14))
    # Down inner face of front lip to small pocket fillet (center at (L_clear - r_lip_pocket, h_shelf_top + r_lip_pocket), 0 -> -90 deg)
    l_pts.extend(arc_points(L_clear - r_lip_pocket, h_shelf_top + r_lip_pocket, r_lip_pocket, 0.0, -90.0, 12))
    # Flat shelf top all the way back to wall (x=0, y=h_shelf_top)
    l_pts.append((0.0, h_shelf_top))

    l_poly = Polygon(l_pts)
    assert l_poly.is_valid, "Main L-profile polygon invalid"
    body_m = extrude_shapely(l_poly, bracket_width, 0.0)

    # ------------------------------------------------------------------
    # B. Outer Triangular Gusset (Z = 0 .. t_gusset = 9.0 mm)
    # ------------------------------------------------------------------
    # Diagonal line from P1=(t_wall, tab_height) to P2=(x_gusset_front, y_gusset_front_bot)
    # Smoothly filleted at P2 (convex R4.5) and concave blends at P1 and (x_gusset_front, y_shelf_bot)
    p1 = np.array([t_wall, tab_height], dtype=np.float64)
    p2 = np.array([x_gusset_front, y_gusset_front_bot], dtype=np.float64)
    v_diag = p2 - p1
    diag_len = np.linalg.norm(v_diag)
    u_diag = v_diag / diag_len
    diag_ang_deg = math.degrees(math.atan2(v_diag[1], v_diag[0]))

    # Construct raw gusset polygon (embedded cleanly inside wall plate and shelf),
    # then apply exact concave/convex fillets on diagonal vertices:
    # Let's place arc centers analytically for tangent continuity!
    # At P1 (wall corner): wall goes +Y (90 deg), diag goes u_diag (diag_ang_deg).
    # Actually concave blend between vertical wall (x=t_wall going down) and diag going (+u_diag):
    # Tangent circle of radius r_g_bot=8.0 inside the angle between x=t_wall (down) and diag:
    # Center is at x = t_wall + r_g_bot. Distance to diag = r_g_bot!
    r_g_bot = 8.0
    # Normal to diag pointing UP-LEFT (-sin, +cos):
    n_up_left = np.array([-u_diag[1], u_diag[0]])
    #Wait: we want center BELOW diag (outside triangle in +X,-Y), at x = t_wall + r_g_bot:
    # Signed distance from P1 to line along n_up_left is 0. Below line means dot(c - p1, -n_up_left) = r_g_bot.
    # Let c_x = t_wall + r_g_bot:
    # (c_x - t_wall)*u_diag[1] - (c_y - tab_height)*u_diag[0] = r_g_bot  -> solve for c_y!
    cx_bot = t_wall + r_g_bot
    cy_bot = tab_height + ((cx_bot - t_wall) * u_diag[1] - r_g_bot) / u_diag[0]
    # Tangent point on wall: (t_wall, cy_bot). Tangent angle from center to wall: 180 deg.
    # Tangent point on diag: (cx_bot, cy_bot) + r_g_bot * n_up_left. Angle: diag_ang_deg + 90 deg.
    ang_wall = 180.0
    ang_diag_bot = diag_ang_deg + 90.0

    # At P2 (front-bottom corner of gusset): diag arrives along +u_diag, front vertical goes +Y (90 deg).
    # Convex radius r_g_front = 4.5 mm inside triangle:
    r_g_front = 4.5
    cx_front = x_gusset_front - r_g_front
    # Distance from center (cx_front, cy_front) UP-LEFT to diag = r_g_front:
    # dot((cx_front, cy_front) - p2, n_up_left) = r_g_front
    # (cx_front - x_gusset_front)*(-u_diag[1]) + (cy_front - y_gusset_front_bot)*u_diag[0] = r_g_front
    cy_front = y_gusset_front_bot + (r_g_front - (cx_front - x_gusset_front) * (-u_diag[1])) / u_diag[0]
    ang_diag_front = diag_ang_deg - 90.0
    ang_vert_front = 0.0

    # At P3 (step root where gusset vertical front x=x_gusset_front meets shelf underside y=y_shelf_bot):
    # Concave fillet radius r_g_top = 6.0 mm:
    r_g_top = 6.0
    cx_top = x_gusset_front + r_g_top
    cy_top = y_shelf_bot - r_g_top

    g_pts = [
        (2.0, cy_bot),
        (t_wall, cy_bot),
    ]
    g_pts.extend(arc_points(cx_bot, cy_bot, r_g_bot, ang_wall, ang_diag_bot, 14))
    g_pts.extend(arc_points(cx_front, cy_front, r_g_front, ang_diag_front, ang_vert_front, 14))
    g_pts.append((x_gusset_front, cy_top))
    g_pts.extend(arc_points(cx_top, cy_top, r_g_top, 180.0, 90.0, 14))
    g_pts.extend([
        (x_gusset_front + r_g_top, h_shelf_top - 2.0),
        (2.0, h_shelf_top - 2.0),
    ])

    gusset_poly = Polygon(g_pts)
    assert gusset_poly.is_valid, "Gusset polygon invalid"
    gusset_m = extrude_shapely(gusset_poly, t_gusset, 0.0)

    # ------------------------------------------------------------------
    # C. Outer Side Retaining Rail (Z = 0 .. t_side_rail = 7.0 mm)
    #    With 1.0 mm 45-deg top-inner chamfer (z=6..7) & 1.0 mm 45-deg root chamfer (z=7..8)
    # ------------------------------------------------------------------
    r_rail_back = 3.0
    rail_base_pts = [
        (0.0, h_shelf_top - 3.0),
        (L_total - 2.0, h_shelf_top - 3.0),
        (L_total - 2.0, y_lip_top - 1.5),
        (L_total - 4.0, y_lip_top),
        (r_rail_back, y_lip_top),
    ]
    rail_base_pts.extend(arc_points(r_rail_back, y_lip_top - r_rail_back, r_rail_back, 90.0, 180.0, 12))
    rail_poly = Polygon(rail_base_pts)
    assert rail_poly.is_valid, "Side rail polygon invalid"

    # Extrude rail z = 0 .. t_side_rail, and trim top-inner edge (y=y_lip_top, z=t_side_rail) by 45-deg plane
    rail_full = extrude_shapely(rail_poly, t_side_rail, 0.0)
    n_bevel = np.array([0.0, 1.0, 1.0]) / math.sqrt(2.0)
    d_bevel = (y_lip_top + t_side_rail - 1.0) / math.sqrt(2.0)
    rail_full = rail_full.trim_by_plane(-n_bevel, -d_bevel)
    assert rail_full.status() == m3d.Error.NoError, f"rail_full error: {rail_full.status()}"

    # Root 45-deg fillet along shelf top (y=h_shelf_top, z=t_side_rail .. t_side_rail + 1.2)
    # Triangle in YZ: (y=h_shelf_top-2, z=t_side_rail-1) -> (y=h_shelf_top+1.2, z=t_side_rail) -> (y=h_shelf_top, z=t_side_rail+1.2) -> (y=h_shelf_top-2, z=t_side_rail+1.2)
    root_yz = Polygon([
        (h_shelf_top - 2.0, t_side_rail - 1.5),
        (h_shelf_top + 1.2, t_side_rail - 1.5),
        (h_shelf_top + 1.2, t_side_rail),
        (h_shelf_top, t_side_rail + 1.2),
        (h_shelf_top - 2.0, t_side_rail + 1.2),
    ])
    # Extrude along X = 0 .. L_clear + 1.0
    root_uvw = extrude_shapely(root_yz, L_clear + 1.0, 0.0)
    M_yz_to_xyz = np.array([
        [0.0, 0.0, 1.0, 0.0],
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 1.0, 0.0, 0.0],
    ], dtype=np.float64)
    rail_root_m = root_uvw.transform(M_yz_to_xyz)

    # ------------------------------------------------------------------
    # D. Zero-Overhang 45-Deg Tapered Internal Stiffening Haunches
    #    (Shrinks upward as Z increases -> 0 deg overhang!)
    # ------------------------------------------------------------------
    # 1. Under-Shelf Tapered Haunch: Z = t_gusset .. (t_gusset + haunch_shelf_depth)
    #    Clipped cleanly inside gusset_poly extruded up to Z = 35 so it never hangs outside gusset!
    gusset_clip_m = extrude_shapely(gusset_poly, haunch_shelf_depth + 4.0, t_gusset - 1.0)
    shelf_haunch_yz = Polygon([
        (h_shelf_top - 2.0, t_gusset - 1.0),
        (y_shelf_bot - haunch_shelf_depth, t_gusset - 1.0),
        (y_shelf_bot - haunch_shelf_depth, t_gusset),
        (y_shelf_bot, t_gusset + haunch_shelf_depth),
        (h_shelf_top - 2.0, t_gusset + haunch_shelf_depth),
    ])
    shelf_haunch_m = extrude_shapely(shelf_haunch_yz, x_gusset_front - 3.0, 3.0).transform(M_yz_to_xyz)
    shelf_haunch_m = shelf_haunch_m ^ gusset_clip_m

    # 2. Wall-Plate Tapered Haunch: Z = t_gusset .. (t_gusset + haunch_wall_depth)
    #    In (x, z) plane, extruded along Y from tab_height .. h_shelf_top - 2.0
    #    Map (x_2d, z_2d, y_extrude) -> (x, y, z):
    #    X = x_2d, Y = y_extrude, Z = z_2d (det = -1! Careful: use reflection-free or ensure positive!)
    #    Wait: det of [[1,0,0],[0,0,1],[0,1,0]] is -1! Instead map u=z_2d, v=x_2d, w=y_extrude -> det([[0,1,0],[0,0,1],[1,0,0]]) = +1!
    wall_haunch_zx = Polygon([
        (t_gusset - 1.0, t_wall + haunch_wall_depth),
        (t_gusset, t_wall + haunch_wall_depth),
        (t_gusset + haunch_wall_depth, t_wall),
        (t_gusset + haunch_wall_depth, 2.0),
        (t_gusset - 1.0, 2.0),
    ])
    M_zx_to_xyz = np.array([
        [0.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [1.0, 0.0, 0.0, 0.0],
    ], dtype=np.float64)
    wall_haunch_m = extrude_shapely(wall_haunch_zx, h_shelf_top - 2.0 - 15.0, 15.0).transform(M_zx_to_xyz)
    wall_haunch_m = wall_haunch_m ^ gusset_clip_m

    # Fuse structural body + gusset + side rail + haunches
    bracket_solid = body_m + gusset_m + rail_full + rail_root_m + shelf_haunch_m + wall_haunch_m

    # ------------------------------------------------------------------
    # E. Subtract 3 Self-Supporting Teardrop Wall Screw Holes (Z = screw_z)
    # ------------------------------------------------------------------
    y_screw_bot = 11.0
    y_screw_top = y_shelf_bot - 28.0    # 72.0 mm (28 mm below shelf underside for full drill chuck clearance)
    y_screw_mid = 0.5 * (y_screw_bot + y_screw_top)  # 41.5 mm
    screw_ys = [y_screw_bot, y_screw_mid, y_screw_top]

    r_screw = screw_hole_dia / 2.0
    holes_m = None
    for sy in screw_ys:
        hm = make_teardrop_hole_prism(
            y_center=sy,
            z_center=screw_z,
            radius=r_screw,
            x_start=-1.0,
            x_end=t_wall + 2.0,
            chamfer_x=t_wall,
            chamfer_size=1.0
        )
        holes_m = hm if holes_m is None else (holes_m + hm)

    bracket_final = bracket_solid - holes_m

    # Clean up subtle chamfer on outer wall-plate top-inner Z edge? Keep Z=56 crisp & clean.
    meta = {
        "L_clear": L_clear,
        "L_total": L_total,
        "H_shelf_top": h_shelf_top,
        "H_total": y_lip_top,
        "W_bracket": bracket_width,
        "t_wall": t_wall,
        "t_shelf": t_shelf,
        "t_gusset": t_gusset,
        "t_side_rail": t_side_rail,
        "t_front_lip": t_front_lip,
        "x_gusset_front": x_gusset_front,
        "front_step": front_step,
        "screw_z": screw_z,
        "screw_ys": screw_ys,
        "screw_hole_dia": screw_hole_dia,
    }
    return bracket_final, meta


# ==============================================================================
# 3. A1 Mini Bed Diagonal Optimizer & Native Bambu Studio 3MF Exporter
# ==============================================================================
def find_optimal_a1_mini_rotation(mesh: trimesh.Trimesh) -> tuple[float, trimesh.Trimesh]:
    """
    Finds the exact XY rotation angle (around Z) that minimizes max(X_span, Y_span)
    so the bracket fits comfortably inside the 180 x 180 mm Bambu Lab A1 Mini bed.
    Centers the rotated mesh at XY = (0, 0) with Z_min = 0.0.
    """
    pts_2d = mesh.vertices[:, :2]
    hull_pts = pts_2d[trimesh.convex.convex_hull(pts_2d).vertices] if False else pts_2d
    # Fast convex hull via scipy
    from scipy.spatial import ConvexHull
    hull = ConvexHull(pts_2d)
    hp = pts_2d[hull.vertices]

    best_deg = 0.0
    best_max_ext = 1e9
    for deg in np.linspace(0.0, 360.0, 7201):
        rad = math.radians(deg)
        c, s = math.cos(rad), math.sin(rad)
        rx = hp[:, 0] * c - hp[:, 1] * s
        ry = hp[:, 0] * s + hp[:, 1] * c
        m = max(rx.max() - rx.min(), ry.max() - ry.min())
        if m < best_max_ext:
            best_max_ext = m
            best_deg = deg

    # Fine search around best_deg
    for deg in np.linspace(best_deg - 0.1, best_deg + 0.1, 401):
        rad = math.radians(deg)
        c, s = math.cos(rad), math.sin(rad)
        rx = hp[:, 0] * c - hp[:, 1] * s
        ry = hp[:, 0] * s + hp[:, 1] * c
        m = max(rx.max() - rx.min(), ry.max() - ry.min())
        if m < best_max_ext:
            best_max_ext = m
            best_deg = deg

    rot_tm = mesh.copy()
    R = trimesh.transformations.rotation_matrix(math.radians(best_deg), [0, 0, 1])
    rot_tm.apply_transform(R)
    b = rot_tm.bounds
    rot_tm.apply_translation([
        -(b[0, 0] + b[1, 0]) / 2.0,
        -(b[0, 1] + b[1, 1]) / 2.0,
        -b[0, 2]
    ])
    return best_deg, rot_tm


def export_bambu_a1_mini_3mf(mesh: trimesh.Trimesh, out_3mf_path: str, name: str, title: str):
    model_lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02" xmlns:BambuStudio="http://schemas.bambulab.com/package/2021">',
        f'  <metadata name="Title">{title}</metadata>',
        '  <metadata name="Application">BambuStudio</metadata>',
        f'  <metadata name="CreationDate">{datetime.date.today().isoformat()}</metadata>',
        '  <resources>',
        '    <object id="1" type="model">',
        '      <mesh>',
        '        <vertices>',
    ]
    for v in mesh.vertices:
        model_lines.append(f'          <vertex x="{v[0]:.5f}" y="{v[1]:.5f}" z="{v[2]:.5f}" />')
    model_lines.append('        </vertices>')
    model_lines.append('        <triangles>')
    for f in mesh.faces:
        model_lines.append(f'          <triangle v1="{int(f[0])}" v2="{int(f[1])}" v3="{int(f[2])}" />')
    model_lines.extend([
        '        </triangles>',
        '      </mesh>',
        '    </object>',
        '  </resources>',
        '  <build>',
        '    <item objectid="1" transform="1 0 0 0 1 0 0 0 1 90.0000 90.0000 0.0000" printable="1" />',
        '  </build>',
        '</model>',
    ])

    settings_xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<config>
  <object id="1">
    <metadata key="name" value="{name}"/>
    <metadata key="extruder" value="1"/>
    <part id="1" subtype="normal_part">
      <metadata key="name" value="{name}"/>
      <metadata key="matrix" value="1 0 0 0 1 0 0 0 1 0 0 0"/>
      <metadata key="source_file" value="{name}.stl"/>
      <metadata key="source_object_id" value="0"/>
      <metadata key="source_volume_id" value="0"/>
    </part>
  </object>
  <plate>
    <metadata key="plater_id" value="1"/>
    <metadata key="plater_name" value="A1_Mini_180x180"/>
    <metadata key="locked" value="false"/>
    <metadata key="thumbnail_file" value=""/>
    <metadata key="top_file" value=""/>
    <metadata key="pick_file" value=""/>
    <metadata key="pattern" value="0"/>
  </plate>
</config>'''

    slice_info_xml = '''<?xml version="1.0" encoding="UTF-8"?>
<config>
  <header>
    <header_item key="X-BBL-Client-Type" value="slicer"/>
  </header>
  <plate>
    <metadata key="index" value="1"/>
    <metadata key="prediction" value="0"/>
    <metadata key="weight" value="0"/>
    <metadata key="flush_weight" value="0"/>
  </plate>
</config>'''

    content_types_xml = '''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2015/02/content-types">
</Types>'''
    content_types_xml = '''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml" />
  <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml" />
  <Default Extension="config" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml" />
</Types>'''

    rels_xml = '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel" />
</Relationships>'''

    with zipfile.ZipFile(out_3mf_path, 'w', compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr('[Content_Types].xml', content_types_xml)
        zf.writestr('_rels/.rels', rels_xml)
        zf.writestr('3D/3dmodel.model', '\n'.join(model_lines))
        zf.writestr('Metadata/model_settings.config', settings_xml)
        zf.writestr('Metadata/slice_info.config', slice_info_xml)


def verify_3mf_lib3mf(path: str):
    wrapper = lib3mf.get_wrapper()
    model = wrapper.CreateModel()
    reader = model.QueryReader("3mf")
    reader.ReadFromFile(path)
    unit = model.GetUnit().name
    meshes = model.GetMeshObjects()
    builds = model.GetBuildItems()
    print(f"[3MF CHECK] {os.path.basename(path)}: unit={unit}, objects={meshes.Count()}, builds={builds.Count()}")
    assert unit == "MilliMeter"
    assert meshes.Count() == 1
    assert builds.Count() == 1


# ==============================================================================
# 4. Main Build Pipeline
# ==============================================================================
def main():
    out_dir = os.path.dirname(os.path.abspath(__file__))
    print("=== Building Rigid PETG PC Wall-Mount Bracket Pair (175 mm CPU, Bambu A1 Mini) ===")

    left_m, meta = build_left_bracket()
    assert left_m.status() == m3d.Error.NoError, f"Left bracket manifold error: {left_m.status()}"

    # Mirror in X -> exact Right Bracket with Z=0 STILL flat on the bed!
    right_m = left_m.mirror([1.0, 0.0, 0.0]).translate([meta["L_total"], 0.0, 0.0])
    assert right_m.status() == m3d.Error.NoError, f"Right bracket manifold error: {right_m.status()}"

    left_raw_tm = manifold_to_trimesh(left_m)
    right_raw_tm = manifold_to_trimesh(right_m)

    # Verify manifoldness & watertightness before rotation
    for lbl, tm in [("Left_Raw", left_raw_tm), ("Right_Raw", right_raw_tm)]:
        assert tm.is_watertight and tm.is_volume, f"{lbl} not watertight/volume!"
        print(f"[{lbl}] watertight={tm.is_watertight}, volume={tm.volume:.1f} mm^3, raw_extents={np.round(tm.extents, 2).tolist()}")

    # Export canonical unrotated meshes (useful for CAD inspection/blueprints)
    left_raw_tm.export(os.path.join(out_dir, "pc_wall_bracket_left_canonical.stl"))
    right_raw_tm.export(os.path.join(out_dir, "pc_wall_bracket_right_canonical.stl"))

    # Rotate optimally to fit 180 x 180 x 180 mm A1 Mini Bed
    deg_l, left_plate_tm = find_optimal_a1_mini_rotation(left_raw_tm)
    deg_r, right_plate_tm = find_optimal_a1_mini_rotation(right_raw_tm)

    print(f"[A1 MINI FIT] Left  rotated {deg_l:.2f} deg -> extents {np.round(left_plate_tm.extents, 2).tolist()} mm <= [180, 180, 180]")
    print(f"[A1 MINI FIT] Right rotated {deg_r:.2f} deg -> extents {np.round(right_plate_tm.extents, 2).tolist()} mm <= [180, 180, 180]")
    assert np.all(left_plate_tm.extents <= np.array([178.5, 178.5, 180.0]))
    assert np.all(right_plate_tm.extents <= np.array([178.5, 178.5, 180.0]))

    # Audit printability using app.engine.printability
    for lbl, tm in [("Left_Bracket_A1Mini", left_plate_tm), ("Right_Bracket_A1Mini", right_plate_tm)]:
        rep = audit_mesh_printability(tm, printer_preset_key="bambu_a1_mini", nozzle_diameter_mm=0.4, layer_height_mm=0.20)
        print(f"[AUDIT {lbl}] status={rep['status']} | score={rep['printability_score']} | bed_contact={rep['bed_contact_area_mm2']} mm^2 | overhang={rep['overhang_percentage']}%")
        for w in rep["warnings"]:
            print("  WARN:", w)
        for e in rep["errors_detected"]:
            print("  ERR :", e)
        assert rep["status"] == "PRINT_READY", f"{lbl} failed printability audit!"

    # Export A1-Mini-ready STL and 3MF files
    stl_left = os.path.join(out_dir, "pc_wall_bracket_left_A1mini.stl")
    stl_right = os.path.join(out_dir, "pc_wall_bracket_right_A1mini.stl")
    left_plate_tm.export(stl_left)
    right_plate_tm.export(stl_right)

    threemf_left = os.path.join(out_dir, "pc_wall_bracket_left_A1mini.3mf")
    threemf_right = os.path.join(out_dir, "pc_wall_bracket_right_A1mini.3mf")
    export_bambu_a1_mini_3mf(left_plate_tm, threemf_left, "PC_Wall_Bracket_Left_175mm", "PC Wall Mount Bracket Left (175mm CPU) - A1 Mini PETG")
    export_bambu_a1_mini_3mf(right_plate_tm, threemf_right, "PC_Wall_Bracket_Right_175mm", "PC Wall Mount Bracket Right (175mm CPU) - A1 Mini PETG")
    verify_3mf_lib3mf(threemf_left)
    verify_3mf_lib3mf(threemf_right)

    # Also export upright mounted pair assembly preview (with 420 mm PC span)
    # In Wall-Mounted Coordinates:
    #   X_mount = Left-to-Right across wall
    #   Y_mount = Wall to Room (0 at wall -> +184.5 into room)
    #   Z_mount = Vertical Up (+120 top of lips)
    # Let's map local Left Bracket (x=wall->front, y=bot->top, z=outer->inner):
    #   X_mount = +z (left bracket outer at X=-210, inward toward center)
    #   Y_mount = +x (wall at Y=0, front at Y=184.5)
    #   Z_mount = +y (bottom at Z=0, top at Z=120)
    # Wait: check Right Bracket in mounted coordinates!
    # Right Bracket local was mirrored X -> -X + L_total, so local x goes from L_total (wall!) to 0 (front!)!!
    # Let's verify: in right_raw_tm, wall face is at x = L_total (184.5) and front lip is at x = 0!
    # So for Right Bracket mounted on the RIGHT (outer at X=+210, inward toward -X):
    #   X_mount = +210 - z
    #   Y_mount = L_total - x  (wall x=L_total -> Y=0; front x=0 -> Y=184.5)
    #   Z_mount = +y
    # Notice det for Left: [[0,0,1],[1,0,0],[0,1,0]] -> det = +1!
    # Notice det for Right: [[0,0,-1],[-1,0,0],[0,1,0]] -> det = -(-1)*1 = -1? Wait: det = -1 means mirror!
    # WAIT A SECOND! Why did Left have det=+1 and Right have det=-1? Because right_raw_tm ALREADY had a mirror applied!
    # Remember: right_m = left_m.mirror([1,0,0]) ALREADY reversed chirality in 3D, so placing it in world space with rigid rotation (det=+1) puts it as the exact Right Bracket!
    # Let's check rigid rotation (det=+1) for Right Bracket!
    # Right raw: wall at x=L_total, front at x=0, outer at z=0, inner at z=+56, bottom at y=0, top at y=120.
    # Rotate 180 deg around Y? No: we want +x (local 0->184.5) to go -Y_mount, +z (local 0->56) to go -X_mount, +y (local 0->120) to go +Z_mount!
    # Check matrix: X_mount = -z, Y_mount = -x + L_total, Z_mount = +y -> rows: [[0,0,-1], [-1,0,0], [0,1,0]]:
    # Compute det: 0 - 0 + (-1)*(0 - (-1)*(0)) -> wait: row1=[0,0,-1], row2=[-1,0,0], row3=[0,1,0]:
    # det = -1 * ((-1)*1 - 0*0) = -1 * (-1) = +1!! YES!! DET = +1 (PURE RIGID ROTATION)!!
    M_left_mount = np.array([
        [0.0, 0.0, 1.0, -210.0],
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ], dtype=np.float64)
    M_right_mount = np.array([
        [0.0, 0.0, -1.0, 210.0],
        [-1.0, 0.0, 0.0, meta["L_total"]],
        [0.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ], dtype=np.float64)

    lm = left_raw_tm.copy()
    lm.apply_transform(M_left_mount)
    rm = right_raw_tm.copy()
    rm.apply_transform(M_right_mount)
    pair_asm = trimesh.util.concatenate([lm, rm])
    pair_asm.export(os.path.join(out_dir, "pc_wall_bracket_pair_mounted_preview.stl"))

    # Print PETG filament & print weight estimate (1.27 g/cm^3, ~55% effective fill with 6 walls + 40% gyroid)
    vol_cm3 = left_raw_tm.volume / 1000.0
    est_grams = vol_cm3 * 1.27 * 0.65  # conservative estimate with 6 walls + 40% gyroid
    print(f"[MASS EST] Solid vol per bracket = {vol_cm3:.1f} cm^3 | Est PETG usage (6 walls, 40% gyroid) = ~{est_grams:.0f} g per bracket (~{2*est_grams:.0f} g pair)")
    print("All CAD files generated successfully in:", out_dir)


if __name__ == "__main__":
    main()
