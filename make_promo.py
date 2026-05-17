#!/usr/bin/env python3
"""
Arabic Video Promo Generator
Ken Burns effect, cinematic grade, Arabic captions, fade transitions.

Place images as image1.jpg ... image6.jpg in the same directory,
or run as-is to generate a demo with colored gradient placeholders.
"""

import os
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import arabic_reshaper
from bidi.algorithm import get_display
from moviepy import VideoClip, CompositeVideoClip

# ── Output settings ──────────────────────────────────────────────────────────
OUTPUT_SIZE   = (1920, 1080)
CANVAS_SCALE  = 1.40          # source image is this much larger than output
CANVAS_SIZE   = (int(OUTPUT_SIZE[0] * CANVAS_SCALE),
                 int(OUTPUT_SIZE[1] * CANVAS_SCALE))
FPS           = 25
SCENE_DURATION = 5.5          # seconds per scene
FADE_DURATION  = 0.80         # crossfade duration (seconds)
FONT_PATH = "/usr/share/fonts/truetype/noto/NotoNaskhArabic-Bold.ttf"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE   = os.path.join(SCRIPT_DIR, "promo.mp4")

# ── Scene definitions ────────────────────────────────────────────────────────
# Order: image_filename, arabic_caption
SCENES = [
    ("image5.jpg", "وُلدت لي كوثر ياسيد روح"),
    ("image2.jpg", "الرجل صار مارقا"),
    ("image3.jpg", "ولاتقف ماليس لم به علم"),
    ("image6.jpg", "مدينة الفقهاء استأحلت فيها العجائب"),
    ("image4.jpg", "انتِ فتاة! وانا رجل لي مقامي ومجلسي"),
    ("image1.jpg", "لقد كانت تهطل هكذا بغزارة حينما خرجت وعمي من القرية"),
]

# Ken Burns per scene: (zoom_start, zoom_end, pan_x, pan_y)
# zoom > 1 → zoomed in; pan_x/y fraction of output width/height over full duration
ZOOM_CONFIGS = [
    (1.25, 1.05,  0.04,  0.00),   # scene 1: slow zoom-out + pan right
    (1.05, 1.25, -0.04,  0.02),   # scene 2: slow zoom-in + pan left+down
    (1.20, 1.05,  0.00,  0.03),   # scene 3: zoom-out + pan down
    (1.05, 1.20,  0.04, -0.02),   # scene 4: zoom-in + pan right+up
    (1.25, 1.05, -0.04,  0.00),   # scene 5: zoom-out + pan left
    (1.05, 1.25,  0.02,  0.03),   # scene 6: zoom-in + drift down-right
]

# Gradient colors for placeholder images (top, bottom) per scene
PLACEHOLDER_COLORS = [
    ((90, 55, 20),  (140, 80, 35)),   # warm sunset orange
    ((20, 30, 55),  (35, 55, 90)),    # cool stable blue
    ((55, 42, 22),  (90, 72, 42)),    # warm indoor amber
    ((12, 18, 32),  (28, 38, 65)),    # night indigo
    ((65, 48, 18),  (115, 85, 38)),   # market warm gold
    ((18, 22, 38),  (32, 42, 62)),    # rain-window slate
]

# ── Image helpers ─────────────────────────────────────────────────────────────

def create_placeholder(top_color, bot_color, size):
    w, h = size
    arr = np.zeros((h, w, 3), dtype=np.uint8)
    for y in range(h):
        t = y / h
        arr[y] = [int(top_color[c] * (1 - t) + bot_color[c] * t) for c in range(3)]
    return Image.fromarray(arr)


def load_image(filename, idx):
    path = os.path.join(SCRIPT_DIR, filename)
    if os.path.exists(path):
        print(f"  Loaded  : {path}")
        return Image.open(path).convert("RGB")
    print(f"  Missing : {filename}  →  using gradient placeholder")
    tc, bc = PLACEHOLDER_COLORS[idx % len(PLACEHOLDER_COLORS)]
    return create_placeholder(tc, bc, (1920, 1080))


def prepare_canvas(img_pil):
    """Cover-scale image to CANVAS_SIZE so Ken Burns always has room to pan."""
    w, h = img_pil.size
    cw, ch = CANVAS_SIZE
    scale = max(cw / w, ch / h)
    nw, nh = int(w * scale + 0.5), int(h * scale + 0.5)
    img_r = img_pil.resize((nw, nh), Image.LANCZOS)
    l, t = (nw - cw) // 2, (nh - ch) // 2
    return img_r.crop((l, t, l + cw, t + ch))

# ── Ken Burns ─────────────────────────────────────────────────────────────────

def ken_burns_frame(canvas, t, duration, z_start, z_end, pan_x, pan_y):
    cw, ch = CANVAS_SIZE
    ow, oh = OUTPUT_SIZE
    progress = t / max(duration, 1e-6)

    zoom  = z_start + (z_end - z_start) * progress
    crop_w = int(ow / zoom)
    crop_h = int(oh / zoom)

    off_x = int(pan_x * ow * progress)
    off_y = int(pan_y * oh * progress)
    cx = cw // 2 + off_x
    cy = ch // 2 + off_y

    l = cx - crop_w // 2
    t_ = cy - crop_h // 2
    r = l + crop_w
    b = t_ + crop_h

    # Clamp to canvas bounds
    if l < 0:   r -= l;      l = 0
    if t_ < 0:  b -= t_;     t_ = 0
    if r > cw:  l -= r - cw; r = cw
    if b > ch:  t_ -= b - ch; b = ch

    cropped = canvas.crop((l, t_, r, b))
    return cropped.resize(OUTPUT_SIZE, Image.LANCZOS)

# ── Color grade ───────────────────────────────────────────────────────────────

def cinematic_grade(frame):
    f = frame.astype(np.float32)
    f *= 0.78                                         # overall darkening
    lum = frame.max(axis=2).astype(np.float32) / 255
    shadow = (1 - lum)
    f[:, :, 2] += shadow * 22                        # cool blue in shadows
    f[:, :, 0] += lum * 8                            # subtle warmth in highlights
    return np.clip(f, 0, 255).astype(np.uint8)


def apply_vignette(frame, strength=0.60):
    h, w = frame.shape[:2]
    Y, X = np.ogrid[:h, :w]
    dist = np.sqrt(((X - w/2) / (w/2))**2 + ((Y - h/2) / (h/2))**2)
    v = np.clip(1 - strength * dist**1.7, 0, 1)[:, :, np.newaxis]
    return (frame * v).astype(np.uint8)

# ── Arabic caption renderer ───────────────────────────────────────────────────

def _font(size):
    return ImageFont.truetype(FONT_PATH, size)


def render_caption(frame_arr, text, base_size=82):
    img  = Image.fromarray(frame_arr).convert("RGBA")
    draw = ImageDraw.Draw(img)
    W, H = img.size

    # Arabic shaping + bidi reorder
    bidi_text = get_display(arabic_reshaper.reshape(text))

    # Auto-shrink font if text is too wide
    font      = _font(base_size)
    max_width = int(W * 0.88)
    bbox      = draw.textbbox((0, 0), bidi_text, font=font)
    tw, th    = bbox[2] - bbox[0], bbox[3] - bbox[1]
    if tw > max_width:
        base_size = max(44, int(base_size * max_width / tw))
        font  = _font(base_size)
        bbox  = draw.textbbox((0, 0), bidi_text, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]

    x = (W - tw) // 2
    y = H - th - 68

    # Semi-transparent dark band behind text
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.rectangle([(0, y - 22), (W, y + th + 28)], fill=(0, 0, 0, 130))
    img = Image.alpha_composite(img, overlay)
    draw = ImageDraw.Draw(img)

    # Shadow (8 directions)
    for dx, dy in [(-3,-3),(-3,3),(3,-3),(3,3),(0,4),(4,0),(-4,0),(0,-4)]:
        draw.text((x+dx, y+dy), bidi_text, font=font, fill=(0, 0, 0, 230))

    # White text
    draw.text((x, y), bidi_text, font=font, fill=(255, 255, 255, 255))

    return np.array(img.convert("RGB"))

# ── Scene clip builder ────────────────────────────────────────────────────────

def make_scene_clip(canvas, caption, scene_idx):
    z_start, z_end, pan_x, pan_y = ZOOM_CONFIGS[scene_idx % len(ZOOM_CONFIGS)]
    dur = SCENE_DURATION

    def make_frame(t):
        pil_f = ken_burns_frame(canvas, t, dur, z_start, z_end, pan_x, pan_y)
        f     = np.array(pil_f)
        f     = cinematic_grade(f)
        f     = apply_vignette(f)
        f     = render_caption(f, caption)

        # Fade in / fade out
        if t < FADE_DURATION:
            alpha = t / FADE_DURATION
        elif t > dur - FADE_DURATION:
            alpha = (dur - t) / FADE_DURATION
        else:
            alpha = 1.0
        alpha = max(0.0, min(1.0, alpha))
        if alpha < 1.0:
            f = (f * alpha).astype(np.uint8)

        return f

    return VideoClip(make_frame, duration=dur)

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("Arabic Video Promo Generator")
    print("=" * 50)
    print(f"Output  : {OUTPUT_FILE}")
    print(f"Size    : {OUTPUT_SIZE[0]}×{OUTPUT_SIZE[1]} @ {FPS} fps")
    print(f"Scenes  : {len(SCENES)}  ×  {SCENE_DURATION}s  +  {FADE_DURATION}s crossfade")
    print()

    clips      = []
    start_time = 0.0

    for i, (filename, caption) in enumerate(SCENES):
        print(f"Scene {i+1}/{len(SCENES)}: {filename}")
        img    = load_image(filename, i)
        canvas = prepare_canvas(img)
        clip   = make_scene_clip(canvas, caption, i)
        clip   = clip.with_start(start_time)
        clips.append(clip)
        if i < len(SCENES) - 1:
            start_time += SCENE_DURATION - FADE_DURATION

    total_duration = start_time + SCENE_DURATION
    print(f"\nTotal duration : {total_duration:.1f}s")
    print("Rendering (this takes a few minutes) …\n")

    final = CompositeVideoClip(clips, size=OUTPUT_SIZE)
    final = final.with_duration(total_duration)

    final.write_videofile(
        OUTPUT_FILE,
        fps=FPS,
        codec="libx264",
        audio=False,
        preset="medium",
        ffmpeg_params=["-crf", "20"],
    )

    size_mb = os.path.getsize(OUTPUT_FILE) / 1_048_576
    print(f"\nDone!  {OUTPUT_FILE}  ({size_mb:.1f} MB)")


if __name__ == "__main__":
    main()
