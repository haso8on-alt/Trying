"""
Farm walkway overlay: detects ground plane per image and overlays
realistic herringbone paver walkways with concrete curb borders.
"""

import cv2
import numpy as np
from PIL import Image
from pathlib import Path
import sys

OUT_DIR = Path("farm_walkway_output")
OUT_DIR.mkdir(exist_ok=True)

# ---------------------------------------------------------------------------
# Herringbone paver texture generator
# ---------------------------------------------------------------------------

def make_herringbone_texture(width: int, height: int,
                              base_color=(195, 175, 140),
                              mortar_color=(210, 205, 195)) -> np.ndarray:
    """Return an RGBA herringbone paver tile as uint8 numpy array (H,W,4)."""
    tex = np.zeros((height, width, 4), dtype=np.uint8)
    tex[:, :, 3] = 255  # fully opaque

    brick_w, brick_h = 40, 20   # brick dimensions in texture space
    mortar = 2

    # work on a contiguous RGB canvas, copy back at end
    rgb = np.full((height, width, 3), mortar_color, dtype=np.uint8)

    rng = np.random.default_rng(42)

    def draw_brick(canvas, x, y, w, h):
        # slight per-brick colour variation for realism
        var = rng.integers(-18, 19, 3)
        c = np.clip(np.array(base_color, dtype=int) + var, 0, 255).tolist()
        cv2.rectangle(canvas, (x + mortar, y + mortar),
                      (x + w - mortar, y + h - mortar),
                      (int(c[0]), int(c[1]), int(c[2])), -1)
        # subtle highlight on top edge
        cv2.line(canvas, (x + mortar, y + mortar),
                 (x + w - mortar, y + mortar),
                 (min(c[0] + 25, 255), min(c[1] + 25, 255), min(c[2] + 25, 255)), 1)
        # subtle shadow on bottom edge
        cv2.line(canvas, (x + mortar, y + h - mortar),
                 (x + w - mortar, y + h - mortar),
                 (max(c[0] - 25, 0), max(c[1] - 25, 0), max(c[2] - 25, 0)), 1)

    # Herringbone pattern: alternating H and V bricks
    for row in range(-2, height // brick_h + 4):
        for col in range(-2, width // brick_w + 4):
            cx = col * brick_w * 2
            cy = row * brick_h * 2

            draw_brick(rgb, cx, cy, brick_w * 2, brick_h)
            draw_brick(rgb, cx, cy + brick_h, brick_h, brick_w * 2)

            ox = cx + brick_w
            oy = cy + brick_h
            draw_brick(rgb, ox, oy, brick_w * 2, brick_h)
            draw_brick(rgb, ox, oy - brick_h, brick_h, brick_w * 2)

    tex[:, :, :3] = rgb
    return tex


# pre-generate a large texture tile we'll tile as needed
_TEX_TILE = make_herringbone_texture(400, 400)


def get_tiled_texture(width: int, height: int) -> np.ndarray:
    th, tw = _TEX_TILE.shape[:2]
    reps_x = width // tw + 2
    reps_y = height // th + 2
    row = np.concatenate([_TEX_TILE] * reps_x, axis=1)
    tiled = np.concatenate([row] * reps_y, axis=0)
    return tiled[:height, :width]


# ---------------------------------------------------------------------------
# Vanishing-point estimation via Hough lines
# ---------------------------------------------------------------------------

def estimate_vanishing_point(gray: np.ndarray, width: int, height: int):
    """Return (vp_x, vp_y) best-effort vanishing point."""
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    edges = cv2.Canny(blurred, 50, 150, apertureSize=3)

    lines = cv2.HoughLinesP(edges, 1, np.pi / 180, 80,
                             minLineLength=60, maxLineGap=20)

    if lines is None:
        return width // 2, int(height * 0.35)

    # keep lines with shallow angles (< 45° from horizontal) – walkway edges
    candidates = []
    for line in lines:
        x1, y1, x2, y2 = line[0]
        angle = abs(np.degrees(np.arctan2(y2 - y1, x2 - x1)))
        if 5 < angle < 75:
            candidates.append((x1, y1, x2, y2))

    if len(candidates) < 2:
        return width // 2, int(height * 0.35)

    # compute pairwise intersections of candidate lines
    intersections = []
    for i in range(len(candidates)):
        for j in range(i + 1, len(candidates)):
            x1, y1, x2, y2 = candidates[i]
            x3, y3, x4, y4 = candidates[j]
            denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
            if abs(denom) < 1e-6:
                continue
            t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
            ix = x1 + t * (x2 - x1)
            iy = y1 + t * (y2 - y1)
            # only keep intersections in the upper half of the image
            if 0 < ix < width and 0 < iy < height * 0.65:
                intersections.append((ix, iy))

    if not intersections:
        return width // 2, int(height * 0.35)

    xs, ys = zip(*intersections)
    return int(np.median(xs)), int(np.median(ys))


# ---------------------------------------------------------------------------
# Per-image walkway geometry (hand-tuned per perspective)
# ---------------------------------------------------------------------------

# For each image we define the four ground-plane corners of the walkway
# in image coordinates (bottom-left, bottom-right, top-right, top-left)
# These are expressed as fractions of (width, height) so they scale.
# Values were derived by inspecting each photo.

IMAGE_CONFIGS = {
    "image1.jpg": {
        # Long straight avenue between two rows of palms, gate at far end
        "walkway_frac": [
            (0.25, 0.98),   # BL
            (0.75, 0.98),   # BR
            (0.58, 0.52),   # TR
            (0.42, 0.52),   # TL
        ],
        "walkway_width_frac": 0.50,
    },
    "image2.jpg": {
        # Barn/enclosure in background, palms on left, open ground
        "walkway_frac": [
            (0.15, 0.98),
            (0.85, 0.98),
            (0.65, 0.55),
            (0.35, 0.55),
        ],
        "walkway_width_frac": 0.55,
    },
    "image3.jpg": {
        # Single palm in foreground, enclosure behind
        "walkway_frac": [
            (0.20, 0.98),
            (0.80, 0.98),
            (0.62, 0.58),
            (0.38, 0.58),
        ],
        "walkway_width_frac": 0.50,
    },
    "image4.jpg": {
        # Open area between palms, worker and barrel visible
        "walkway_frac": [
            (0.22, 0.98),
            (0.78, 0.98),
            (0.60, 0.50),
            (0.40, 0.50),
        ],
        "walkway_width_frac": 0.50,
    },
    "image5.jpg": {
        # Large mesh enclosure on left, small pen on right
        "walkway_frac": [
            (0.18, 0.98),
            (0.72, 0.98),
            (0.58, 0.53),
            (0.32, 0.53),
        ],
        "walkway_width_frac": 0.48,
    },
    "image6.jpg": {
        # Similar open ground, enclosure left, palms
        "walkway_frac": [
            (0.20, 0.98),
            (0.80, 0.98),
            (0.62, 0.55),
            (0.38, 0.55),
        ],
        "walkway_width_frac": 0.52,
    },
}


# ---------------------------------------------------------------------------
# Ground mask via colour segmentation (sandy / dirt tones)
# ---------------------------------------------------------------------------

def make_ground_mask(bgr: np.ndarray) -> np.ndarray:
    """Return binary mask of sandy/dirt ground pixels."""
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    # sandy/brown hues: H 10-35, moderate-high S, moderate-high V
    mask = cv2.inRange(hsv,
                       np.array([5,  20,  60]),
                       np.array([35, 180, 220]))
    kernel = np.ones((15, 15), np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
    return mask


# ---------------------------------------------------------------------------
# Lighting / shadow transfer: match paver brightness to ground
# ---------------------------------------------------------------------------

def match_luminance(src_bgr: np.ndarray,
                    target_bgr: np.ndarray,
                    mask: np.ndarray) -> np.ndarray:
    """Scale src_bgr luminance to match mean/std of target within mask."""
    src_lab = cv2.cvtColor(src_bgr, cv2.COLOR_BGR2LAB).astype(np.float32)
    tgt_lab = cv2.cvtColor(target_bgr, cv2.COLOR_BGR2LAB).astype(np.float32)

    if mask.sum() == 0:
        return src_bgr

    for ch in range(3):
        src_ch = src_lab[:, :, ch]
        tgt_ch = tgt_lab[:, :, ch]
        tgt_vals = tgt_ch[mask > 0]
        src_vals = src_ch[mask > 0]
        if src_vals.std() < 1e-3:
            continue
        scale = tgt_vals.std() / (src_vals.std() + 1e-6)
        shift = tgt_vals.mean() - scale * src_vals.mean()
        src_lab[:, :, ch] = np.clip(src_ch * scale + shift, 0, 255)

    return cv2.cvtColor(src_lab.astype(np.uint8), cv2.COLOR_LAB2BGR)


# ---------------------------------------------------------------------------
# Shadow map from original image
# ---------------------------------------------------------------------------

def extract_shadow_map(bgr: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Return a float32 shadow multiplier in [0.5, 1.2] for the masked region."""
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY).astype(np.float32)
    # normalise luminance within ground region
    vals = gray[mask > 0]
    if len(vals) == 0:
        return np.ones(gray.shape, np.float32)
    mn, mx = vals.min(), vals.max()
    rng = max(mx - mn, 1)
    normalised = (gray - mn) / rng   # 0..1
    shadow = 0.55 + normalised * 0.65   # map to 0.55..1.20
    return shadow.astype(np.float32)


# ---------------------------------------------------------------------------
# Curb drawing
# ---------------------------------------------------------------------------

def draw_curb(canvas: np.ndarray, pts_left: list, pts_right: list,
              thickness: int = 12):
    """Draw concrete curb borders along walkway edges."""
    curb_color = (195, 195, 190)   # light gray BGR
    def draw_edge(pts):
        for i in range(len(pts) - 1):
            p1 = (int(pts[i][0]), int(pts[i][1]))
            p2 = (int(pts[i + 1][0]), int(pts[i + 1][1]))
            cv2.line(canvas, p1, p2, curb_color, thickness, cv2.LINE_AA)
            # highlight on top of curb
            cv2.line(canvas, p1, p2,
                     (215, 215, 210), max(1, thickness // 3), cv2.LINE_AA)
    draw_edge(pts_left)
    draw_edge(pts_right)


# ---------------------------------------------------------------------------
# Main processing function
# ---------------------------------------------------------------------------

def process_image(img_path: Path, config: dict) -> tuple[np.ndarray, np.ndarray]:
    bgr_orig = cv2.imread(str(img_path))
    if bgr_orig is None:
        raise FileNotFoundError(img_path)

    h, w = bgr_orig.shape[:2]
    result = bgr_orig.copy()

    # --- define walkway quad in image space ---
    frac = config["walkway_frac"]
    quad = np.array([[fx * w, fy * h] for fx, fy in frac], dtype=np.float32)
    bl, br, tr, tl = quad   # bottom-left, bottom-right, top-right, top-left

    # --- generate large paver texture and warp it into perspective ---
    tex_h, tex_w = 800, 600
    texture_bgr = get_tiled_texture(tex_w, tex_h)[:, :, :3]

    # destination corners in texture space
    src_pts = np.float32([[0, tex_h],           # BL
                           [tex_w, tex_h],       # BR
                           [tex_w, 0],           # TR
                           [0, 0]])              # TL
    dst_pts = np.float32([bl, br, tr, tl])

    M = cv2.getPerspectiveTransform(src_pts, dst_pts)
    warped_tex = cv2.warpPerspective(texture_bgr, M, (w, h),
                                     flags=cv2.INTER_LINEAR,
                                     borderMode=cv2.BORDER_CONSTANT,
                                     borderValue=(0, 0, 0))

    # --- create walkway mask from quad ---
    walk_mask = np.zeros((h, w), dtype=np.uint8)
    pts_int = quad.astype(np.int32)
    cv2.fillPoly(walk_mask, [pts_int], 255)

    # limit to actual ground pixels
    ground_mask = make_ground_mask(bgr_orig)
    combined_mask = cv2.bitwise_and(walk_mask, ground_mask)

    # fallback: if ground mask is too restrictive, use walk_mask alone
    # but only in the lower 60% of the image
    lower_mask = np.zeros((h, w), np.uint8)
    lower_mask[int(h * 0.4):, :] = 255
    walk_lower = cv2.bitwise_and(walk_mask, lower_mask)
    if combined_mask.sum() < walk_lower.sum() * 0.35:
        combined_mask = walk_lower

    # --- luminance matching ---
    matched_tex = match_luminance(warped_tex, bgr_orig, combined_mask)

    # --- shadow transfer ---
    shadow = extract_shadow_map(bgr_orig, combined_mask)

    # --- soft edge feathering ---
    feather_kernel = np.ones((31, 31), np.uint8)
    feathered = cv2.erode(combined_mask, feather_kernel, iterations=1)
    feathered = cv2.GaussianBlur(feathered.astype(np.float32), (61, 61), 0)
    feathered = (feathered / feathered.max()).clip(0, 1) if feathered.max() > 0 else feathered

    # --- blend ---
    alpha = feathered[:, :, np.newaxis]
    shadow_map = shadow[:, :, np.newaxis]

    orig_f = bgr_orig.astype(np.float32)
    tex_f = matched_tex.astype(np.float32) * shadow_map

    blended = orig_f * (1 - alpha) + tex_f * alpha
    blended = np.clip(blended, 0, 255).astype(np.uint8)

    # --- draw curbs ---
    # left edge: tl -> bl  |  right edge: tr -> br  (4-5 intermediate pts)
    def edge_pts(p1, p2, n=6):
        return [(p1[0] + t * (p2[0] - p1[0]),
                 p1[1] + t * (p2[1] - p1[1])) for t in np.linspace(0, 1, n)]

    curb_thick = max(6, int(w * 0.008))
    draw_curb(blended, edge_pts(tl, bl), edge_pts(tr, br), curb_thick)

    return bgr_orig, blended


# ---------------------------------------------------------------------------
# Side-by-side comparison
# ---------------------------------------------------------------------------

def make_comparison(orig: np.ndarray, result: np.ndarray,
                    label: str) -> np.ndarray:
    h, w = orig.shape[:2]
    gap = 20
    canvas = np.full((h + 60, w * 2 + gap, 3), 240, dtype=np.uint8)
    canvas[0:h, 0:w] = orig
    canvas[0:h, w + gap:] = result

    font = cv2.FONT_HERSHEY_SIMPLEX
    cv2.putText(canvas, "BEFORE", (30, h + 40), font, 1.0, (60, 60, 60), 2)
    cv2.putText(canvas, "AFTER  (Paved Walkway)",
                (w + gap + 30, h + 40), font, 1.0, (30, 100, 30), 2)
    cv2.putText(canvas, label, (w - 80, h + 40), font, 0.5, (120, 120, 120), 1)
    return canvas


# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    images = sorted(Path(".").glob("image*.jpg"))
    if not images:
        sys.exit("No image*.jpg files found in current directory.")

    print(f"Processing {len(images)} images → {OUT_DIR}/")

    for img_path in images:
        cfg = IMAGE_CONFIGS.get(img_path.name)
        if cfg is None:
            print(f"  SKIP {img_path.name} – no config")
            continue

        print(f"  {img_path.name} ...", end=" ", flush=True)
        try:
            orig, result = process_image(img_path, cfg)
        except Exception as e:
            print(f"ERROR: {e}")
            continue

        out_result = OUT_DIR / f"{img_path.stem}_paved.jpg"
        out_cmp    = OUT_DIR / f"{img_path.stem}_comparison.jpg"

        cv2.imwrite(str(out_result), result, [cv2.IMWRITE_JPEG_QUALITY, 93])
        cmp = make_comparison(orig, result, img_path.name)
        cv2.imwrite(str(out_cmp), cmp, [cv2.IMWRITE_JPEG_QUALITY, 90])

        print(f"saved → {out_result.name} + {out_cmp.name}")

    print("Done.")
