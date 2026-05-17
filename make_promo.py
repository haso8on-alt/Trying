#!/usr/bin/env python3
"""
Arabic Video Promo Generator — v3
Ken Burns, cinematic grade, Arabic captions (Amiri Bold),
animated rain, lantern flicker, cloth warp, wind dust,
and synthesised ambient audio (rain / wind / oud drone).

Requirements: moviepy, opencv-python-headless, pillow,
              arabic-reshaper, python-bidi, scipy, numpy
"""

import os
import math
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont
import arabic_reshaper
from bidi.algorithm import get_display
from moviepy import VideoClip, CompositeVideoClip, AudioArrayClip
import scipy.signal as sig

# ─────────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────────
OUTPUT_SIZE    = (1920, 1080)
W, H           = OUTPUT_SIZE
CANVAS_SCALE   = 1.75
CANVAS_SIZE    = (int(W * CANVAS_SCALE), int(H * CANVAS_SCALE))
CW, CH         = CANVAS_SIZE
FPS            = 25
SCENE_DUR      = 5.5        # seconds per scene
FADE_DUR       = 0.80       # crossfade overlap
SAMPLE_RATE    = 44100

AMIRI          = "/usr/share/fonts/opentype/fonts-hosny-amiri/Amiri-Bold.ttf"
SCRIPT_DIR     = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE    = os.path.join(SCRIPT_DIR, "promo.mp4")

# ─────────────────────────────────────────────────────────────
# Scene definitions
# (filename, arabic_caption, audio_type, effects_set)
# effects: "rain" | "lantern" | "wind" | "cloth" (cloth on all)
# ─────────────────────────────────────────────────────────────
SCENES = [
    ("image5.jpg",
     "وُلدت لي كوثر ياسيد روح",
     "wind",
     {"wind", "cloth"}),

    ("image2.jpg",
     "الرجل صار مارقاً",
     "wind",
     {"lantern", "cloth"}),

    ("image3.jpg",
     "ولا تقف ما ليس لك به علم",
     "indoor",
     {"lantern", "cloth"}),

    ("image6.jpg",
     "مدينة الفقهاء استأحلت فيها العجائب",
     "wind",
     {"lantern", "cloth"}),

    ("image4.jpg",
     "أنتِ فتاة! وأنا رجل لي مقامي ومجلسي",
     "wind",
     {"wind", "cloth"}),

    ("image1.jpg",
     "لقد كانت تهطل هكذا بغزارة حينما خرجت وعمي من القرية",
     "rain",
     {"rain", "cloth"}),
]

# Ken Burns — (zoom_start, zoom_end, pan_x, pan_y)
ZOOM_CONFIGS = [
    (1.55, 1.00,  0.10,  0.00),
    (1.00, 1.60, -0.10,  0.05),
    (1.60, 1.05,  0.00,  0.09),
    (1.00, 1.65,  0.10, -0.06),
    (1.55, 1.00, -0.10,  0.00),
    (1.00, 1.55,  0.06,  0.10),
]

PLACEHOLDER_COLORS = [
    ((90,55,20),(140,80,35)),
    ((20,30,55),(35,55,90)),
    ((55,42,22),(90,72,42)),
    ((12,18,32),(28,38,65)),
    ((65,48,18),(115,85,38)),
    ((18,22,38),(32,42,62)),
]


# ─────────────────────────────────────────────────────────────
# Image helpers
# ─────────────────────────────────────────────────────────────

def create_placeholder(top, bot, size):
    pw, ph = size
    arr = np.zeros((ph, pw, 3), dtype=np.uint8)
    for y in range(ph):
        t = y / ph
        arr[y] = [int(top[c]*(1-t) + bot[c]*t) for c in range(3)]
    return Image.fromarray(arr)


def load_image(filename, idx):
    path = os.path.join(SCRIPT_DIR, filename)
    if os.path.exists(path):
        print(f"  Loaded  : {path}")
        return Image.open(path).convert("RGB")
    print(f"  Missing : {filename}  → gradient placeholder")
    tc, bc = PLACEHOLDER_COLORS[idx % len(PLACEHOLDER_COLORS)]
    return create_placeholder(tc, bc, (1920, 1080))


def prepare_canvas(img_pil):
    iw, ih = img_pil.size
    scale = max(CW / iw, CH / ih)
    nw, nh = int(iw*scale+.5), int(ih*scale+.5)
    img_r = img_pil.resize((nw, nh), Image.LANCZOS)
    l, t = (nw-CW)//2, (nh-CH)//2
    return np.array(img_r.crop((l, t, l+CW, t+CH)))


# ─────────────────────────────────────────────────────────────
# Ken Burns
# ─────────────────────────────────────────────────────────────

def ken_burns_frame(canvas_np, t, z_start, z_end, pan_x, pan_y):
    p = t / max(SCENE_DUR, 1e-6)
    p = p*p*(3 - 2*p)                          # smoothstep
    zoom   = z_start + (z_end - z_start) * p
    crop_w = int(W / zoom)
    crop_h = int(H / zoom)
    off_x  = int(pan_x * W * p)
    off_y  = int(pan_y * H * p)
    cx, cy = CW//2 + off_x, CH//2 + off_y
    l, top = cx - crop_w//2, cy - crop_h//2
    r, bot = l + crop_w,     top + crop_h
    if l < 0:    r -= l;      l = 0
    if top < 0:  bot -= top;  top = 0
    if r > CW:   l -= r-CW;   r = CW
    if bot > CH: top -= bot-CH; bot = CH
    crop = canvas_np[top:bot, l:r]
    return cv2.resize(crop, OUTPUT_SIZE, interpolation=cv2.INTER_LINEAR)


# ─────────────────────────────────────────────────────────────
# Cinematic grade + vignette
# ─────────────────────────────────────────────────────────────

def cinematic_grade(f):
    f = f.astype(np.float32)
    f *= 0.78
    lum    = f.max(axis=2) / 255
    shadow = 1 - lum
    f[:,:,2] += shadow * 22
    f[:,:,0] += lum    * 8
    return np.clip(f, 0, 255).astype(np.uint8)


# Pre-build vignette mask once
_vig_Y, _vig_X = np.ogrid[:H, :W]
_vig_dist = np.sqrt(((_vig_X-W/2)/(W/2))**2 + ((_vig_Y-H/2)/(H/2))**2)
_vignette = np.clip(1 - 0.60*_vig_dist**1.7, 0, 1)[:,:,np.newaxis].astype(np.float32)


def apply_vignette(f):
    return (f.astype(np.float32) * _vignette).astype(np.uint8)


# ─────────────────────────────────────────────────────────────
# Effect 1 — Lantern flicker
# ─────────────────────────────────────────────────────────────

def _make_flicker_lut(scene_idx):
    """Pre-generate per-frame brightness multiplier for a scene."""
    rng  = np.random.RandomState(scene_idx * 7 + 13)
    n    = int(SCENE_DUR * FPS) + 4
    t    = np.linspace(0, SCENE_DUR, n)
    slow = 0.04*np.sin(2*np.pi*0.35*t+0.5) + 0.025*np.sin(2*np.pi*0.72*t+1.1)
    walk = np.cumsum(rng.randn(n)*0.007)
    walk = np.clip(walk, -0.10, 0.10)
    return np.clip(1.0 + slow + walk, 0.84, 1.10).astype(np.float32)


def apply_lantern(frame, flicker_val):
    f = frame.astype(np.float32)
    # Warm orange tint for brighter moments, cooler for dimmer
    warmth = (flicker_val - 0.84) / (1.10 - 0.84)   # 0→1
    f[:,:,0] *= flicker_val + 0.04*warmth            # red channel slightly boosted
    f[:,:,1] *= flicker_val - 0.01*warmth
    f[:,:,2] *= flicker_val - 0.06*warmth            # blue slightly dimmed
    return np.clip(f, 0, 255).astype(np.uint8)


# ─────────────────────────────────────────────────────────────
# Effect 2 — Cloth / fabric warp  (all scenes)
# ─────────────────────────────────────────────────────────────

# Base coordinate grids
_cx = np.tile(np.arange(W, dtype=np.float32), (H, 1))
_cy = np.tile(np.arange(H, dtype=np.float32), (W, 1)).T


def apply_cloth_warp(frame, t, scene_idx):
    phase = t * 0.9 + scene_idx * 1.3
    # Gentle diagonal ripple: 2-3 px peak displacement
    disp_x = 2.2 * np.sin(_cy * (2*np.pi/190) + phase) \
                 * np.sin(_cx * (2*np.pi/420) + t*0.4)
    disp_y = 1.4 * np.sin(_cx * (2*np.pi/280) + phase + 0.8) \
                 * np.cos(_cy * (2*np.pi/150) + t*0.6)
    map_x = (_cx + disp_x).astype(np.float32)
    map_y = (_cy + disp_y).astype(np.float32)
    return cv2.remap(frame, map_x, map_y,
                     cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)


# ─────────────────────────────────────────────────────────────
# Effect 3 — Rain particles  (scene 5 — image1)
# ─────────────────────────────────────────────────────────────

class RainSystem:
    N = 420

    def __init__(self, seed=0):
        rng        = np.random.RandomState(seed)
        self.x0    = rng.uniform(0, W, self.N).astype(np.float32)
        self.y0    = rng.uniform(-H, H, self.N).astype(np.float32)
        self.vy    = rng.uniform(520, 880, self.N).astype(np.float32)
        self.vx    = rng.uniform(-110, -45, self.N).astype(np.float32)  # wind-blown left
        self.length = rng.randint(18, 52, self.N)
        self.alpha  = rng.uniform(0.12, 0.45, self.N).astype(np.float32)
        self.phase  = rng.uniform(0, 1, self.N).astype(np.float32)

    def render(self, frame, t):
        overlay = frame.astype(np.float32)
        cycle_h = (H * 2)
        for i in range(self.N):
            elapsed = t + self.phase[i] * (cycle_h / self.vy[i])
            x = int((self.x0[i] + self.vx[i] * elapsed) % W)
            y = int((self.y0[i] + self.vy[i] * elapsed) % (H + 60)) - 30

            # Streak end points
            dx = int(self.vx[i] / self.vy[i] * self.length[i])
            dy = self.length[i]
            x2 = np.clip(x + dx, 0, W-1)
            y2 = np.clip(y + dy, 0, H-1)
            x  = np.clip(x,      0, W-1)
            y  = np.clip(y,      0, H-1)

            a = float(self.alpha[i])
            # Blue-white rain color
            cv2.line(overlay, (x, y), (x2, y2), (200, 215, 235), 1)
        # Blend: soft alpha so rain is translucent
        alpha_blend = 0.55
        return np.clip(frame*(1-alpha_blend) + overlay*alpha_blend,
                       0, 255).astype(np.uint8)


_rain = RainSystem(seed=42)


# ─────────────────────────────────────────────────────────────
# Effect 4 — Wind / dust particles  (outdoor scenes 0, 4)
# ─────────────────────────────────────────────────────────────

class WindSystem:
    N = 260

    def __init__(self, seed=1, direction=1):
        rng         = np.random.RandomState(seed)
        self.x0     = rng.uniform(0, W, self.N).astype(np.float32)
        self.y0     = rng.uniform(H*0.25, H*0.95, self.N).astype(np.float32)
        self.vx     = rng.uniform(90, 280, self.N).astype(np.float32) * direction
        self.vy     = rng.uniform(-22, 22, self.N).astype(np.float32)
        self.size   = rng.randint(1, 4, self.N)
        self.alpha  = rng.uniform(0.08, 0.38, self.N).astype(np.float32)
        self.phase  = rng.uniform(0, 1, self.N).astype(np.float32)
        self.streak = rng.random(self.N) < 0.45    # 45 % are short streaks

    def render(self, frame, t):
        overlay = frame.copy().astype(np.float32)
        for i in range(self.N):
            cycle_w = W / abs(self.vx[i])
            elapsed  = t + self.phase[i] * cycle_w
            x = int((self.x0[i] + self.vx[i]*elapsed) % W)
            y = int(np.clip(self.y0[i] + self.vy[i]*elapsed, 0, H-1))
            a = float(self.alpha[i])
            # Warm sand colour
            color = (int(195*a + frame[y,x,2]*(1-a)),
                     int(172*a + frame[y,x,1]*(1-a)),
                     int(120*a + frame[y,x,0]*(1-a)))
            if self.streak[i] and t > 0:
                sx  = int(self.vx[i] * 0.03)
                sy  = int(self.vy[i] * 0.03)
                x2  = np.clip(x + sx, 0, W-1)
                y2  = np.clip(y + sy, 0, H-1)
                cv2.line(overlay, (x, y), (x2, y2),
                         (120+int(a*80), 110+int(a*70), 80+int(a*50)), 1)
            else:
                s = self.size[i]
                x1c, y1c = max(0,x-s), max(0,y-s)
                x2c, y2c = min(W,x+s), min(H,y+s)
                overlay[y1c:y2c, x1c:x2c] = (
                    overlay[y1c:y2c, x1c:x2c] * (1-a)
                    + np.array([120,110,80], np.float32) * a
                )
        return np.clip(overlay, 0, 255).astype(np.uint8)


_wind = [WindSystem(seed=s, direction=1) for s in [1, 3]]   # two presets


# ─────────────────────────────────────────────────────────────
# Arabic caption renderer  (Amiri Bold)
# ─────────────────────────────────────────────────────────────

_reshaper = arabic_reshaper.ArabicReshaper(configuration={
    'delete_harakat':  False,
    'support_zwj':     True,
    'use_unsupported_chars_as_unshaped': True,
})


def _font(size):
    return ImageFont.truetype(AMIRI, size)


def render_caption(frame_arr, text, base_size=90):
    img  = Image.fromarray(frame_arr).convert("RGBA")
    draw = ImageDraw.Draw(img)
    IW, IH = img.size

    bidi_text = get_display(_reshaper.reshape(text))
    font      = _font(base_size)
    max_w     = int(IW * 0.86)
    bbox      = draw.textbbox((0,0), bidi_text, font=font)
    tw, th    = bbox[2]-bbox[0], bbox[3]-bbox[1]

    if tw > max_w:
        base_size = max(50, int(base_size * max_w / tw))
        font  = _font(base_size)
        bbox  = draw.textbbox((0,0), bidi_text, font=font)
        tw, th = bbox[2]-bbox[0], bbox[3]-bbox[1]

    x = (IW - tw) // 2
    y = IH - th - 72

    overlay = Image.new("RGBA", img.size, (0,0,0,0))
    od = ImageDraw.Draw(overlay)
    od.rectangle([(0, y-28), (IW, y+th+36)], fill=(0,0,0,148))
    img  = Image.alpha_composite(img, overlay)
    draw = ImageDraw.Draw(img)

    for dx, dy in [(-4,-4),(-4,4),(4,-4),(4,4),(0,5),(5,0),(-5,0),(0,-5)]:
        draw.text((x+dx, y+dy), bidi_text, font=font, fill=(0,0,0,240))
    draw.text((x, y), bidi_text, font=font, fill=(255,255,255,255))

    return np.array(img.convert("RGB"))


# ─────────────────────────────────────────────────────────────
# Audio  (rain / wind / oud drone)
# ─────────────────────────────────────────────────────────────

def _norm(s, vol):
    p = np.abs(s).max()
    return s / p * vol if p > 1e-9 else s


def gen_rain(dur, vol=0.30):
    n     = int(dur * SAMPLE_RATE)
    noise = np.random.RandomState(5).randn(n).astype(np.float32)
    bp    = sig.butter(6, [350, 8000], btype='bandpass', fs=SAMPLE_RATE, output='sos')
    lp    = sig.butter(4, 100, btype='lowpass',          fs=SAMPLE_RATE, output='sos')
    mix   = sig.sosfilt(bp, noise)*0.80 + sig.sosfilt(lp, noise)*0.20
    return _norm(mix.astype(np.float32), vol)


def gen_wind(dur, vol=0.24):
    n     = int(dur * SAMPLE_RATE)
    noise = np.random.RandomState(7).randn(n).astype(np.float32)
    lp    = sig.butter(5, 320, btype='lowpass',         fs=SAMPLE_RATE, output='sos')
    bp    = sig.butter(4, [380,860], btype='bandpass',  fs=SAMPLE_RATE, output='sos')
    t     = np.linspace(0, dur, n, dtype=np.float32)
    lfo   = 0.52 + 0.48*np.sin(2*np.pi*0.28*t + 1.0)
    mix   = (sig.sosfilt(lp,noise)*0.75 + sig.sosfilt(bp,noise)*0.25) * lfo
    return _norm(mix.astype(np.float32), vol)


def gen_indoor(dur, vol=0.06):
    n     = int(dur * SAMPLE_RATE)
    noise = np.random.RandomState(9).randn(n).astype(np.float32)
    hp    = sig.butter(3, 80,   btype='highpass', fs=SAMPLE_RATE, output='sos')
    lp    = sig.butter(3, 2800, btype='lowpass',  fs=SAMPLE_RATE, output='sos')
    tone  = sig.sosfilt(lp, sig.sosfilt(hp, noise))
    return _norm(tone.astype(np.float32), vol)


def gen_oud_drone(dur, vol=0.13):
    """
    Synthesised oud: D2 (73.4 Hz) + A2 (110 Hz) fundamentals,
    rich harmonics, slow vibrato and amplitude breath.
    """
    n    = int(dur * SAMPLE_RATE)
    t    = np.linspace(0, dur, n, dtype=np.float32)
    vib  = 1.0 + 0.0028 * np.sin(2*np.pi*5.6*t)

    d2   = 73.42
    toneD = sum(
        amp * np.sin(2*np.pi * d2 * k * vib * t)
        for k, amp in enumerate([1.0, 0.62, 0.38, 0.22, 0.13, 0.07, 0.04], 1)
    )
    a2   = 110.0
    toneA = sum(
        amp * np.sin(2*np.pi * a2 * k * vib * t)
        for k, amp in enumerate([0.5, 0.28, 0.14, 0.07], 1)
    )
    tone = toneD + toneA

    # Slow breath envelope
    breath  = 0.55 + 0.45*np.sin(2*np.pi*0.14*t + 0.3)
    # Pluck-like attack on every ~4 s
    pluck_period = 4.0
    pluck_phase  = (t % pluck_period) / pluck_period
    pluck_env    = np.exp(-pluck_phase * 5.5) * 0.4 + 0.6
    tone *= breath * pluck_env

    # Soft low-pass to remove harsh harmonics
    lp   = sig.butter(4, 1800, btype='lowpass', fs=SAMPLE_RATE, output='sos')
    tone = sig.sosfilt(lp, tone.astype(np.float32))
    return _norm(tone.astype(np.float32), vol)


def build_audio_track(total_dur):
    print("  Synthesising ambient audio …")
    full = np.zeros(int(total_dur * SAMPLE_RATE), dtype=np.float32)
    oud  = gen_oud_drone(total_dur, vol=0.13)[:len(full)]
    full += oud

    cursor = 0
    for i, (_, _, audio_type, _) in enumerate(SCENES):
        seg_n = int(SCENE_DUR * SAMPLE_RATE)
        if audio_type == "rain":
            seg = gen_rain(SCENE_DUR)
        elif audio_type == "indoor":
            seg = gen_indoor(SCENE_DUR)
        else:
            seg = gen_wind(SCENE_DUR)

        # Fade edges to avoid clicks
        fade  = int(FADE_DUR * SAMPLE_RATE)
        ramp  = np.linspace(0, 1, fade, dtype=np.float32)
        seg[:fade]  *= ramp
        seg[-fade:] *= ramp[::-1]

        end = min(cursor + len(seg), len(full))
        full[cursor:end] += seg[:end-cursor]
        if i < len(SCENES)-1:
            cursor += int((SCENE_DUR - FADE_DUR) * SAMPLE_RATE)

    full  = np.clip(full, -1, 1)
    stereo = np.stack([full, full], axis=1)
    return AudioArrayClip(stereo, fps=SAMPLE_RATE)


# ─────────────────────────────────────────────────────────────
# Scene clip builder
# ─────────────────────────────────────────────────────────────

def make_scene_clip(canvas_np, caption, scene_idx, effects):
    z_start, z_end, pan_x, pan_y = ZOOM_CONFIGS[scene_idx]
    flicker_lut = (_make_flicker_lut(scene_idx)
                   if "lantern" in effects else None)
    wind_sys    = _wind[scene_idx % len(_wind)] if "wind" in effects else None

    def make_frame(t):
        # 1 — Ken Burns
        f = ken_burns_frame(canvas_np, t, z_start, z_end, pan_x, pan_y)
        # 2 — Grade
        f = cinematic_grade(f)
        # 3 — Vignette
        f = apply_vignette(f)
        # 4 — Lantern flicker
        if flicker_lut is not None:
            fi  = min(int(t * FPS), len(flicker_lut)-1)
            f   = apply_lantern(f, flicker_lut[fi])
        # 5 — Cloth warp
        if "cloth" in effects:
            f = apply_cloth_warp(f, t, scene_idx)
        # 6 — Rain overlay
        if "rain" in effects:
            f = _rain.render(f, t)
        # 7 — Wind particles
        if wind_sys is not None:
            f = wind_sys.render(f, t)
        # 8 — Caption
        f = render_caption(f, caption)
        # 9 — Fade in/out
        if t < FADE_DUR:
            alpha = t / FADE_DUR
        elif t > SCENE_DUR - FADE_DUR:
            alpha = (SCENE_DUR - t) / FADE_DUR
        else:
            alpha = 1.0
        alpha = max(0.0, min(1.0, alpha))
        if alpha < 1.0:
            f = (f * alpha).astype(np.uint8)
        return f

    return VideoClip(make_frame, duration=SCENE_DUR)


# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────

def main():
    print("Arabic Video Promo Generator  v3")
    print("=" * 52)
    print(f"Output  : {OUTPUT_FILE}")
    print(f"Font    : Amiri Bold")
    print(f"Size    : {W}×{H} @ {FPS} fps")
    print(f"Scenes  : {len(SCENES)} × {SCENE_DUR}s  (crossfade {FADE_DUR}s)")
    print()

    clips      = []
    start_time = 0.0

    for i, (filename, caption, audio_type, effects) in enumerate(SCENES):
        eff_str = ", ".join(sorted(effects))
        print(f"Scene {i+1}/{len(SCENES)}: {filename}  [{eff_str}]")
        img        = load_image(filename, i)
        canvas_np  = prepare_canvas(img)
        clip       = make_scene_clip(canvas_np, caption, i, effects)
        clip       = clip.with_start(start_time)
        clips.append(clip)
        if i < len(SCENES)-1:
            start_time += SCENE_DUR - FADE_DUR

    total_dur  = start_time + SCENE_DUR
    print(f"\nTotal duration : {total_dur:.1f}s")

    audio = build_audio_track(total_dur)
    audio = audio.with_duration(total_dur)

    print("Rendering … (takes several minutes)\n")
    final = CompositeVideoClip(clips, size=OUTPUT_SIZE)
    final = final.with_duration(total_dur)
    final = final.with_audio(audio)

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
