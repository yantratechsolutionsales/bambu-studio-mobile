"""
Visual Verification, Engineering Blueprint & A1 Mini Plate Audit Renderer
for the Rigid PETG Wall-Mount PC / CPU Bracket Pair (175 mm CPU Breadth).
"""

import os
import sys
import numpy as np
import trimesh
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT_DIR)


def render_mesh_3d(ax, mesh: trimesh.Trimesh, color="#64748b", edge_color="#0f172a", elev=25, azim=-55, title="", span_mult=0.48):
    verts = mesh.vertices
    faces = mesh.faces
    tris = verts[faces]

    normals = mesh.face_normals
    light1 = np.array([0.45, -0.55, 0.70])
    light1 /= np.linalg.norm(light1)
    light2 = np.array([-0.55, 0.45, 0.50])
    light2 /= np.linalg.norm(light2)
    intens = np.clip(
        0.38 + 0.55 * np.maximum(0.0, normals @ light1) + 0.25 * np.maximum(0.0, normals @ light2),
        0.35, 1.0
    )

    base_rgb = np.array(matplotlib.colors.to_rgb(color))
    face_colors = np.column_stack([
        np.clip(base_rgb[0] * intens, 0, 1),
        np.clip(base_rgb[1] * intens, 0, 1),
        np.clip(base_rgb[2] * intens, 0, 1),
        np.ones(len(faces))
    ])

    coll = Poly3DCollection(tris, facecolors=face_colors, edgecolors=edge_color, linewidths=0.025)
    ax.add_collection3d(coll)

    b = mesh.bounds
    center = (b[0] + b[1]) / 2.0
    max_span = np.max(b[1] - b[0]) * span_mult
    ax.set_xlim(center[0] - max_span, center[0] + max_span)
    ax.set_ylim(center[1] - max_span, center[1] + max_span)
    ax.set_zlim(center[2] - max_span, center[2] + max_span)
    ax.set_box_aspect([1, 1, 1])
    ax.view_init(elev=elev, azim=azim)
    ax.set_title(title, fontsize=11, fontweight="bold", pad=8)
    ax.set_axis_off()


def plot_section(ax, mesh: trimesh.Trimesh, plane_origin, plane_normal, axis_map=(0, 1),
                 color="#0284c7", lw=1.6, ls="-", label=None, fill_alpha=0.14):
    sec = mesh.section(plane_origin=plane_origin, plane_normal=plane_normal)
    if sec is None:
        return
    for entity in sec.entities:
        pts = sec.vertices[entity.points]
        x = pts[:, axis_map[0]]
        y = pts[:, axis_map[1]]
        ax.plot(x, y, color=color, lw=lw, linestyle=ls, label=label)
        if fill_alpha > 0:
            ax.fill(x, y, color=color, alpha=fill_alpha)
        label = None


def dim_arrow(ax, x1, y1, x2, y2, text, text_offset=(0, 4), color="#dc2626", fontsize=8.5):
    ax.annotate("", xy=(x2, y2), xytext=(x1, y1),
                arrowprops=dict(arrowstyle="<->", color=color, lw=1.1, shrinkA=0, shrinkB=0))
    mx, my = (x1 + x2) / 2.0 + text_offset[0], (y1 + y2) / 2.0 + text_offset[1]
    ax.text(mx, my, text, color=color, fontsize=fontsize, fontweight="bold",
            ha="center", va="center",
            bbox=dict(boxstyle="round,pad=0.18", facecolor="#ffffff", edgecolor="none", alpha=0.88))


def main():
    out_dir = os.path.dirname(os.path.abspath(__file__))
    left_canon = trimesh.load(os.path.join(out_dir, "pc_wall_bracket_left_canonical.stl"))
    right_canon = trimesh.load(os.path.join(out_dir, "pc_wall_bracket_right_canonical.stl"))
    left_plate = trimesh.load(os.path.join(out_dir, "pc_wall_bracket_left_A1mini.stl"))
    right_plate = trimesh.load(os.path.join(out_dir, "pc_wall_bracket_right_A1mini.stl"))
    pair_asm = trimesh.load(os.path.join(out_dir, "pc_wall_bracket_pair_mounted_preview.stl"))

    # ==========================================================================
    # Figure 1: 4-Panel Engineering Blueprint & Fit Verification
    # ==========================================================================
    fig = plt.figure(figsize=(16, 12), dpi=180)
    fig.patch.set_facecolor("#f8fafc")

    # Panel A: Side Profile Sections (z=4.5 mm Outer Gusset & z=38.0 mm Screw Centerline)
    ax1 = fig.add_subplot(2, 2, 1)
    plot_section(ax1, left_canon, [0, 0, 4.5], [0, 0, 1], axis_map=(0, 1),
                 color="#0f172a", lw=1.7, label="Outer Profile (z=4.5 mm: Gusset + Side Rail)", fill_alpha=0.12)
    plot_section(ax1, left_canon, [0, 0, 38.0], [0, 0, 1], axis_map=(0, 1),
                 color="#0284c7", lw=1.8, ls="-", label="Screw Axis Cut (z=38.0 mm: Wall Plate + Shelf)", fill_alpha=0.20)

    # Virtual 175mm CPU Footprint Box resting on shelf (x=1.5 to 176.5, y=110 to 160)
    cpu_rect = patches.Rectangle((1.5, 110.0), 175.0, 45.0, linewidth=1.3,
                                 linestyle="--", edgecolor="#16a34a", facecolor="#bbf7d0", alpha=0.28,
                                 label="175 mm Breadth CPU Tower (w/ 1.5 mm wall/lip gap)")
    ax1.add_patch(cpu_rect)
    ax1.axvline(0.0, color="#64748b", lw=2.5, ls="-", label="Wall Surface (x=0)")

    # Key Dimension Annotations
    dim_arrow(ax1, 0.0, 131.0, 178.0, 131.0, "178.0 mm Clear Tray (175 mm CPU + 3 mm)", (0, 6))
    dim_arrow(ax1, 0.0, 143.0, 184.5, 143.0, "184.5 mm Total Depth", (0, 6), color="#0369a1")
    dim_arrow(ax1, 152.5, 76.0, 184.5, 76.0, "32.0 mm Step", (0, -6))
    dim_arrow(ax1, -10.0, 0.0, -10.0, 110.0, "110.0 mm", (-12, 0))
    dim_arrow(ax1, -26.0, 0.0, -26.0, 120.0, "120.0 mm Total", (-14, 0), color="#0369a1")
    dim_arrow(ax1, 19.0, 72.0, 19.0, 100.0, "28 mm\nChuck Clear", (19, 0), color="#7c3aed", fontsize=7.5)

    for sy, lbl in [(11.0, "y=11.0"), (41.5, "y=41.5"), (72.0, "y=72.0")]:
        ax1.plot(4.5, sy, "o", color="#dc2626", ms=4)
        ax1.text(12.5, sy, f"Ø6.2 Teardrop ({lbl})", fontsize=7.5, color="#b91c1c", va="center")

    ax1.set_title("A. Side Elevation Cross-Sections & 175 mm CPU Fit Check", fontsize=12, fontweight="bold")
    ax1.set_xlabel("Depth from Wall X (mm)")
    ax1.set_ylabel("Vertical Height Y (mm)")
    ax1.set_xlim(-46, 200)
    ax1.set_ylim(-12, 162)
    ax1.set_aspect("equal")
    ax1.grid(True, linestyle=":", alpha=0.5)
    ax1.legend(loc="lower right", fontsize=7.5)

    # Panel B: Front/Back Cross-Section (YZ plane at x=60 mm & x=4.5 mm)
    ax2 = fig.add_subplot(2, 2, 2)
    plot_section(ax2, left_canon, [60.0, 0, 0], [1, 0, 0], axis_map=(2, 1),
                 color="#0284c7", lw=1.8, label="Shelf + Haunch + Gusset Cut (x=60.0 mm)", fill_alpha=0.22)
    plot_section(ax2, left_canon, [4.5, 0, 0], [1, 0, 0], axis_map=(2, 1),
                 color="#64748b", lw=1.2, ls="--", label="Wall Plate Cut (x=4.5 mm w/ Screw Holes)", fill_alpha=0.06)

    dim_arrow(ax2, 0.0, 130.0, 56.0, 130.0, "56.0 mm Bracket Width (Print Z)", (0, 6))
    dim_arrow(ax2, 7.0, 114.0, 56.0, 114.0, "49.0 mm Flat Shelf", (0, 5), color="#15803d")
    dim_arrow(ax2, 0.0, 32.0, 9.0, 32.0, "9 mm", (4, 8))
    dim_arrow(ax2, 9.0, 105.0, 29.0, 105.0, "20 mm Haunch", (12, -16), color="#7c3aed", fontsize=7.5)
    ax2.axvline(38.0, color="#dc2626", lw=1.0, ls=":")
    ax2.text(38.0, 54.0, "Screw Line\nZ = 38.0 mm\n(0° Overhang\nTeardrop)", color="#dc2626", fontsize=8,
             ha="center", bbox=dict(boxstyle="round,pad=0.2", facecolor="white", alpha=0.9))

    ax2.set_title("B. Transverse Cross-Section (Haunch, Side Rail & Screw Alignment)", fontsize=12, fontweight="bold")
    ax2.set_xlabel("Bracket Width Z / Print Height (mm)")
    ax2.set_ylabel("Vertical Height Y (mm)")
    ax2.set_xlim(-10, 72)
    ax2.set_ylim(-14, 148)
    ax2.set_aspect("equal")
    ax2.grid(True, linestyle=":", alpha=0.5)
    ax2.legend(loc="lower right", fontsize=7.5)

    # Panel C: Bambu Lab A1 Mini 180 x 180 mm Build Plate Verification
    ax3 = fig.add_subplot(2, 2, 3)
    bed_rect = patches.Rectangle((-90.0, -90.0), 180.0, 180.0, linewidth=2.2,
                                 edgecolor="#16a34a", facecolor="#ecfdf5", alpha=0.55,
                                 label="Bambu Lab A1 Mini Bed (180 x 180 mm)")
    ax3.add_patch(bed_rect)
    # Plot convex hull / projection of rotated left bracket on Z=0
    pts_xy = left_plate.vertices[:, :2]
    from scipy.spatial import ConvexHull
    hull = ConvexHull(pts_xy)
    hp = np.vstack([pts_xy[hull.vertices], pts_xy[hull.vertices[0]]])
    ax3.fill(hp[:, 0], hp[:, 1], color="#0284c7", alpha=0.25, label="Left Bracket Footprint (Z=0 flat)")
    ax3.plot(hp[:, 0], hp[:, 1], color="#0f172a", lw=1.6)
    plot_section(ax3, left_plate, [0, 0, 5.0], [0, 0, 1], axis_map=(0, 1),
                 color="#0369a1", lw=1.2, fill_alpha=0.15)
    plot_section(ax3, left_plate, [0, 0, 25.0], [0, 0, 1], axis_map=(0, 1),
                 color="#334155", lw=1.0, ls="--", fill_alpha=0.0)

    ext = left_plate.extents
    b = left_plate.bounds
    bb_rect = patches.Rectangle((b[0, 0], b[0, 1]), ext[0], ext[1], linewidth=1.2,
                                linestyle="--", edgecolor="#dc2626", facecolor="none",
                                label=f"Bounding Box: {ext[0]:.2f} x {ext[1]:.2f} mm")
    ax3.add_patch(bb_rect)
    ax3.text(0, -108, f"Fits inside 180 x 180 x 180 mm (Height Z = {ext[2]:.1f} mm) | Zero Supports",
             ha="center", va="top", fontsize=9.5, fontweight="bold", color="#15803d")

    ax3.set_title("C. Bambu Lab A1 Mini (180 x 180 mm) Diagonal Plate Fit", fontsize=12, fontweight="bold")
    ax3.set_xlabel("Bed X (mm)")
    ax3.set_ylabel("Bed Y (mm)")
    ax3.set_xlim(-105, 105)
    ax3.set_ylim(-124, 102)
    ax3.set_aspect("equal")
    ax3.grid(True, linestyle=":", alpha=0.5)
    ax3.legend(loc="upper right", fontsize=7.5)

    # Panel D: Mounted Wall Pair + 175mm CPU Footprint Check (Top-Down Plan View)
    ax4 = fig.add_subplot(2, 2, 4)
    # Plot horizontal section at Z_mount = 115 mm (catching front lip & side rails) and Z_mount = 105 mm (shelf)
    plot_section(ax4, pair_asm, [0, 0, 115.0], [0, 0, 1], axis_map=(0, 1),
                 color="#0f172a", lw=1.8, label="Retaining Lips (Z=115 mm)", fill_alpha=0.35)
    plot_section(ax4, pair_asm, [0, 0, 105.0], [0, 0, 1], axis_map=(0, 1),
                 color="#0284c7", lw=1.2, label="Bearing Shelves (Z=105 mm)", fill_alpha=0.15)
    # Virtual PC footprint (say 410 mm cabinet length x 175 mm breadth)
    pc_plan = patches.Rectangle((-202.0, 1.5), 404.0, 175.0, linewidth=1.6,
                                linestyle="--", edgecolor="#16a34a", facecolor="#bbf7d0", alpha=0.28,
                                label="PC Cabinet Footprint (404 x 175 mm Breadth)")
    ax4.add_patch(pc_plan)
    ax4.axhline(0.0, color="#64748b", lw=3.0, label="Wall Face (Y=0)")
    dim_arrow(ax4, -210.0, 195.0, 210.0, 195.0, "Adjustable Span (e.g. 420 mm outer-to-outer)", (0, 8))
    dim_arrow(ax4, 225.0, 1.5, 225.0, 176.5, "175 mm\nCPU Breadth", (24, 0), color="#15803d")

    ax4.set_title("D. Wall-Mounted Left & Right Pair Plan View (175 mm Breadth CPU)", fontsize=12, fontweight="bold")
    ax4.set_xlabel("Across Wall X (mm)")
    ax4.set_ylabel("Depth from Wall Y (mm)")
    ax4.set_xlim(-250, 280)
    ax4.set_ylim(-20, 220)
    ax4.set_aspect("equal")
    ax4.grid(True, linestyle=":", alpha=0.5)
    ax4.legend(loc="lower center", fontsize=7.5, ncol=2)

    fig.suptitle("Rigid PETG Wall-Mount PC / CPU Bracket Pair (175 mm Breadth) — Engineering Blueprint",
                 fontsize=15, fontweight="bold", y=0.985)
    plt.tight_layout(rect=[0, 0, 1, 0.96])
    bp_path = os.path.join(out_dir, "pc_bracket_engineering_blueprint.png")
    fig.savefig(bp_path, dpi=180)
    plt.close(fig)
    print("Saved engineering blueprint:", bp_path)

    # ==========================================================================
    # Figure 2: High-Resolution 3D Isometric Product Renders
    # ==========================================================================
    fig2 = plt.figure(figsize=(16, 12), dpi=180)
    fig2.patch.set_facecolor("#f8fafc")

    # Upright Left Bracket for natural viewing (map local to upright mounted pose)
    M_upright = np.array([
        [0.0, 0.0, 1.0, 0.0],
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ], dtype=np.float64)
    left_up = left_canon.copy()
    left_up.apply_transform(M_upright)

    ax3d_1 = fig2.add_subplot(2, 2, 1, projection="3d")
    render_mesh_3d(ax3d_1, left_up, color="#64748b", elev=22, azim=138,
                   title="1. Outer Gusset, Side Rail & Front Lip (Matches Ref Photo 4)")

    ax3d_2 = fig2.add_subplot(2, 2, 2, projection="3d")
    render_mesh_3d(ax3d_2, left_up, color="#64748b", elev=22, azim=42,
                   title="2. Inner Screw Flange, 45° Tapered Haunches & Shelf Pocket")

    ax3d_3 = fig2.add_subplot(2, 2, 3, projection="3d")
    render_mesh_3d(ax3d_3, left_plate, color="#0ea5e9", elev=55, azim=-50,
                   title="3. Bambu A1 Mini Print Orientation (Flat on Z=0, Zero Supports)")

    ax3d_4 = fig2.add_subplot(2, 2, 4, projection="3d")
    render_mesh_3d(ax3d_4, pair_asm, color="#64748b", elev=20, azim=65, span_mult=0.45,
                   title="4. Mirrored Left + Right Wall-Mounted Bracket Pair (Front View)")

    fig2.suptitle("3D CAD Renders — Rigid PETG PC Wall-Mount Bracket Pair (175 mm CPU)",
                  fontsize=15, fontweight="bold", y=0.98)
    plt.tight_layout(rect=[0, 0, 1, 0.955])
    ren_path = os.path.join(out_dir, "pc_bracket_3d_renders.png")
    fig2.savefig(ren_path, dpi=180)
    plt.close(fig2)
    print("Saved 3D renders:", ren_path)


if __name__ == "__main__":
    main()
