#!/usr/bin/env python3
"""
Arabic Video Promo Generator
Ken Burns effect, cinematic grade, Arabic captions, fade transitions, ambient audio.

Place images as image1.jpg ... image6.jpg in the same directory,
or run as-is to generate a demo with colored gradient placeholders.
"""

import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import arabic_reshaper
from bidi.algorithm import get_display
from moviepy import VideoClip, CompositeVideoClip, AudioArrayClip
import scipy.signal as signal

# ── Output settings ──────────────────────────────────────────────────────────
OUTPUT_SIZE    = (1920, 1080)
CANVAS_SCALE   = 1.75          # larger canvas → more room for dramatic KB motion
CANVAS_SIZE    = (int(OUTPUT_SIZE[0] * CANVAS_SCALE),
                  int(OUTPUT_SIZE[1] * CANVAS_SCALE))
FPS            = 25
SCENE_DURATION = 5.5
FADE_DURATION  = 0.80
SAMPLE_RATE    = 44100

FONT_PATH  = "/usr/share/fonts/opentype/fonts-hosny-amiri/Amiri-Bold.ttf"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(SCRIPT_DIR, "promo.mp4")

# ── Scene definitions ────────────────────────────────────────────────────────
# (image_filename, arabic_caption, audio_type)
# audio_type: "rain" | "wind" | "indoor"
SCENES = [
    ("image5.jpg", "وُلدت لي كوثر ياسيد روح",                                "wind"),
    ("image2.jpg", "الرجل صار مارقا",                                          "wind"),
    ("image3.jpg", "ولا تقف ما ليس لك به علم",                                "indoor"),
    ("image6.jpg", "مدينة الفقهاء استأحلت فيها العجائب",                      "wind"),
    ("image4.jpg", "أنتِ فتاة! وأنا رجل لي مقامي ومجلسي",                    "wind"),
    ("image1.jpg", "لقد كانت تهطل هكذا بغزارة حينما خرجت وعمي من القرية",    "rain"),
]

# ── Ken Burns per scene: (zoom_start, zoom_end, pan_x, pan_y) ─────────────
# Dramatically wider range than before for cinematic feel
ZOOM_CONFIGS = [
    (1.55, 1.00,  0.10,  0.00),   # scene 1: strong zoom-out + drift right
    (1.00, 1.60, -0.10,  0.05),   # scene 2: strong zoom-in + pan left-down
    (1.60, 1.05,  0.00,  0.09),   # scene 3: zoom-out + pull down
    (1.00, 1.65,  0.10, -0.06),   # scene 4: zoom-in + pan right-up
    (1.55, 1.00, -0.10,  0.00),   # scene 5: zoom-out + drift left
    (1.00, 1.55,  0.06,  0.10),   # scene 6: zoom-in + sink down
]

# Gradient placeholder colors (top, bottom) per scene
PLACEHOLDER_COLORS = [
    ((90, 55, 20),  (140, 80, 35)),
    ((20, 30, 55),  (35, 55, 90)),
    ((55, 42, 22),  (90, 72, 42)),
    ((12, 18, 32),  (28, 38, 65)),
    ((65, 48, 18),  (115, 85, 38)),
    ((18, 22, 38),  (32, 42, 62)),
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
    # Ease-in-out curve (smoothstep) for more cinematic motion feel
    p = t / max(duration, 1e-6)
    progress = p * p * (3 - 2 * p)

    zoom   = z_start + (z_end - z_start) * progress
    crop_w = int(ow / zoom)
    crop_h = int(oh / zoom)

    off_x = int(pan_x * ow * progress)
    off_y = int(pan_y * oh * progress)
    cx = cw // 2 + off_x
    cy = ch // 2 + off_y

    l  = cx - crop_w // 2
    t_ = cy - crop_h // 2
    r  = l + crop_w
    b  = t_ + crop_h

    if l < 0:   r -= l;      l = 0
    if t_ < 0:  b -= t_;     t_ = 0
    if r > cw:  l -= r - cw; r = cw
    if b > ch:  t_ -= b - ch; b = ch

    cropped = canvas.crop((l, t_, r, b))
    return cropped.resize(OUTPUT_SIZE, Image.LANCZOS)

# ── Color grade ───────────────────────────────────────────────────────────────

def cinematic_grade(frame):
    f = frame.astype(np.float32)
    f *= 0.78
    lum    = frame.max(axis=2).astype(np.float32) / 255
    shadow = (1 - lum)
    f[:, :, 2] += shadow * 22
    f[:, :, 0] += lum * 8
    return np.clip(f, 0, 255).astype(np.uint8)


def apply_vignette(frame, strength=0.60):
    h, w = frame.shape[:2]
    Y, X = np.ogrid[:h, :w]
    dist = np.sqrt(((X - w/2) / (w/2))**2 + ((Y - h/2) / (h/2))**2)
    v = np.clip(1 - strength * dist**1.7, 0, 1)[:, :, np.newaxis]
    return (frame * v).astype(np.uint8)

# ── Arabic caption renderer ───────────────────────────────────────────────────

# Configure reshaper to keep all diacritics and use full ligatures
_reshaper = arabic_reshaper.ArabicReshaper(configuration={
    'delete_harakat':              False,
    'support_zwj':                 True,
    'use_unsupported_chars_as_unshaped': True,
    'ALEF_WASLA_LETTER_ABOVE_WITH_FATHAH_AND_LETTER': True,
})


def _font(size):
    return ImageFont.truetype(FONT_PATH, size)


def render_caption(frame_arr, text, base_size=90):
    img  = Image.fromarray(frame_arr).convert("RGBA")
    draw = ImageDraw.Draw(img)
    W, H = img.size

    # Shape Arabic + apply bidi for correct visual order
    shaped    = _reshaper.reshape(text)
    bidi_text = get_display(shaped)

    font      = _font(base_size)
    max_width = int(W * 0.86)
    bbox      = draw.textbbox((0, 0), bidi_text, font=font)
    tw, th    = bbox[2] - bbox[0], bbox[3] - bbox[1]

    if tw > max_width:
        base_size = max(50, int(base_size * max_width / tw))
        font  = _font(base_size)
        bbox  = draw.textbbox((0, 0), bidi_text, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]

    x = (W - tw) // 2
    y = H - th - 72

    # Gradient dark band behind text (taller padding for Amiri descenders)
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.rectangle([(0, y - 28), (W, y + th + 36)], fill=(0, 0, 0, 145))
    img  = Image.alpha_composite(img, overlay)
    draw = ImageDraw.Draw(img)

    # Drop shadow (8 directions, slightly heavier than before)
    for dx, dy in [(-4,-4),(-4,4),(4,-4),(4,4),(0,5),(5,0),(-5,0),(0,-5)]:
        draw.text((x+dx, y+dy), bidi_text, font=font, fill=(0, 0, 0, 240))

    # Main white text
    draw.text((x, y), bidi_text, font=font, fill=(255, 255, 255, 255))

    return np.array(img.convert("RGB"))

# ── Ambient audio generation ──────────────────────────────────────────────────

def _normalize(sig, volume):
    peak = np.abs(sig).max()
    if peak < 1e-9:
        return sig
    return sig / peak * volume


def generate_rain(duration, volume=0.28):
    """Bandpass-filtered white noise (rain drops sit in 400 Hz – 8 kHz)."""
    n = int(duration * SAMPLE_RATE)
    noise = np.random.randn(n).astype(np.float32)
    sos   = signal.butter(6, [400, 8000], btype='bandpass',
                          fs=SAMPLE_RATE, output='sos')
    filtered = signal.sosfilt(sos, noise).astype(np.float32)
    # Add a quieter low-frequency rumble for realism
    sos_lo   = signal.butter(4, 120, btype='lowpass',
                              fs=SAMPLE_RATE, output='sos')
    rumble   = signal.sosfilt(sos_lo, noise).astype(np.float32)
    mix = filtered * 0.80 + rumble * 0.20
    return _normalize(mix, volume)


def generate_wind(duration, volume=0.22):
    """Low-pass filtered noise with a slow LFO for gusting motion."""
    n = int(duration * SAMPLE_RATE)
    noise = np.random.randn(n).astype(np.float32)
    sos   = signal.butter(5, 350, btype='lowpass',
                          fs=SAMPLE_RATE, output='sos')
    wind  = signal.sosfilt(sos, noise).astype(np.float32)
    # Add a mid-frequency whistle layer
    sos_mid = signal.butter(4, [400, 900], btype='bandpass',
                             fs=SAMPLE_RATE, output='sos')
    whistle = signal.sosfilt(sos_mid, noise).astype(np.float32)
    # Slow LFO (0.2 – 0.4 Hz) to simulate gusts
    t   = np.linspace(0, duration, n, dtype=np.float32)
    lfo = 0.55 + 0.45 * np.sin(2 * np.pi * 0.28 * t + np.random.uniform(0, np.pi))
    mix = (wind * 0.75 + whistle * 0.25) * lfo
    return _normalize(mix, volume)


def generate_indoor(duration, volume=0.08):
    """Very quiet room tone – high-pass killed noise."""
    n = int(duration * SAMPLE_RATE)
    noise = np.random.randn(n).astype(np.float32)
    sos   = signal.butter(3, 80, btype='highpass',
                          fs=SAMPLE_RATE, output='sos')
    tone  = signal.sosfilt(sos, noise).astype(np.float32)
    sos2  = signal.butter(3, 3000, btype='lowpass',
                          fs=SAMPLE_RATE, output='sos')
    tone  = signal.sosfilt(sos2, tone).astype(np.float32)
    return _normalize(tone, volume)


def build_audio_track(scenes, total_duration):
    """Stitch per-scene ambient audio into one mono track, then duplicate to stereo."""
    print("  Building ambient audio track …")
    full = np.zeros(int(total_duration * SAMPLE_RATE), dtype=np.float32)
    cursor = 0
    for i, (_, _, audio_type) in enumerate(scenes):
        seg_dur = SCENE_DURATION
        if audio_type == "rain":
            seg = generate_rain(seg_dur)
        elif audio_type == "indoor":
            seg = generate_indoor(seg_dur)
        else:
            seg = generate_wind(seg_dur)

        # Fade the audio segment edges to avoid clicks at crossfade points
        fade_len = int(FADE_DURATION * SAMPLE_RATE)
        ramp_in  = np.linspace(0, 1, fade_len, dtype=np.float32)
        ramp_out = np.linspace(1, 0, fade_len, dtype=np.float32)
        seg[:fade_len]  *= ramp_in
        seg[-fade_len:] *= ramp_out

        end = min(cursor + len(seg), len(full))
        full[cursor:end] += seg[:end - cursor]

        if i < len(scenes) - 1:
            cursor += int((SCENE_DURATION - FADE_DURATION) * SAMPLE_RATE)

    full = np.clip(full, -1, 1)
    # Stereo: duplicate mono channel → shape (n_samples, 2)
    stereo = np.stack([full, full], axis=1)
    return AudioArrayClip(stereo, fps=SAMPLE_RATE)

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
    print(f"Font    : Amiri Bold (calligraphic Arabic)")
    print(f"Size    : {OUTPUT_SIZE[0]}×{OUTPUT_SIZE[1]} @ {FPS} fps")
    print(f"Scenes  : {len(SCENES)}  ×  {SCENE_DURATION}s  +  {FADE_DURATION}s crossfade")
    print()

    clips      = []
    start_time = 0.0

    for i, (filename, caption, audio_type) in enumerate(SCENES):
        print(f"Scene {i+1}/{len(SCENES)}: {filename}  [{audio_type}]")
        img    = load_image(filename, i)
        canvas = prepare_canvas(img)
        clip   = make_scene_clip(canvas, caption, i)
        clip   = clip.with_start(start_time)
        clips.append(clip)
        if i < len(SCENES) - 1:
            start_time += SCENE_DURATION - FADE_DURATION

    total_duration = start_time + SCENE_DURATION
    print(f"\nTotal duration : {total_duration:.1f}s")

    audio_clip = build_audio_track(SCENES, total_duration)
    audio_clip = audio_clip.with_duration(total_duration)

    print("Rendering (this takes a few minutes) …\n")

    final = CompositeVideoClip(clips, size=OUTPUT_SIZE)
    final = final.with_duration(total_duration)
    final = final.with_audio(audio_clip)

    final.write_videofile(
        OUTPUT_FILE,
        fps=FPS,
        codec="libx264",
        audio_codec="aac",
        audio_bitrate="128k",
        preset="medium",
        ffmpeg_params=["-crf", "20"],
    )

    size_mb = os.path.getsize(OUTPUT_FILE) / 1_048_576
    print(f"\nDone!  {OUTPUT_FILE}  ({size_mb:.1f} MB)")


if __name__ == "__main__":
    main()
