#!/usr/bin/env python3
"""
Arabic Video Promo Generator — v4
Ken Burns (subtle, max 1.05×), cinematic grade,
animated rain/lantern/cloth/wind effects,
Arabic TTS voice (gTTS) per scene replacing on-screen captions,
synthesised ambient audio (rain / wind / oud drone).

Requirements: moviepy, opencv-python-headless, pillow,
              arabic-reshaper, python-bidi, scipy, numpy, gtts
"""

import os
import io
import subprocess
import tempfile
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont
import arabic_reshaper
from bidi.algorithm import get_display
from moviepy import VideoClip, CompositeVideoClip, AudioArrayClip
import scipy.signal as sig
import scipy.io.wavfile as wavfile
from gtts import gTTS
import imageio_ffmpeg

# ─────────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────────
OUTPUT_SIZE  = (1920, 1080)
W, H         = OUTPUT_SIZE
CANVAS_SCALE = 1.15          # smaller canvas — subtle KB only needs ~1.15×
CANVAS_SIZE  = (int(W * CANVAS_SCALE), int(H * CANVAS_SCALE))
CW, CH       = CANVAS_SIZE
FPS          = 25
SCENE_DUR    = 5.5
FADE_DUR     = 0.80
SAMPLE_RATE  = 44100
FFMPEG       = imageio_ffmpeg.get_ffmpeg_exe()

AMIRI        = "/usr/share/fonts/opentype/fonts-hosny-amiri/Amiri-Bold.ttf"
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE  = os.path.join(SCRIPT_DIR, "promo.mp4")
TTS_CACHE    = os.path.join(SCRIPT_DIR, "tts_cache")
os.makedirs(TTS_CACHE, exist_ok=True)

# ─────────────────────────────────────────────────────────────
# Scene definitions  (filename, tts_text, audio_type, effects)
# ─────────────────────────────────────────────────────────────
SCENES = [
    ("image5.jpg",
     "وُلدت لي كوثر ياسيد روح",
     "wind",
     {"wind", "cloth"}),

    ("image2.jpg",
     "الرجل صار مارقا",
     "wind",
     {"lantern", "cloth"}),

    ("image3.jpg",
     "ولا تقفُ ماليس لك به علم",
     "indoor",
     {"lantern", "cloth"}),

    ("image6.jpg",
     "مدينة الفقهاء تحولت مدينة عجائب",
     "wind",
     {"lantern", "cloth"}),

    ("image4.jpg",
     "انتِ فتاة! وانا رجل لي مقامي ومجلسي",
     "wind",
     {"wind", "cloth"}),

    ("image1.jpg",
     "لقد كانت تهطل هكذا بغزارة حينما خرجت وعمي من القرية",
     "rain",
     {"rain", "cloth"}),
]

# ── Ken Burns — very subtle, max 1.05× zoom ──────────────────
# (zoom_start, zoom_end, pan_x, pan_y)
ZOOM_CONFIGS = [
    (1.04, 1.00,  0.025,  0.000),   # slow zoom-out + gentle right drift
    (1.00, 1.05, -0.020,  0.015),   # slow zoom-in + left-down
    (1.05, 1.01,  0.000,  0.020),   # zoom-out + pull down
    (1.00, 1.05,  0.022, -0.015),   # zoom-in + right-up
    (1.04, 1.00, -0.022,  0.000),   # zoom-out + left drift
    (1.00, 1.04,  0.015,  0.022),   # zoom-in + sink
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
    """Cover-scale to CANVAS_SIZE with Lanczos (sharp) resampling."""
    iw, ih = img_pil.size
    scale = max(CW / iw, CH / ih)
    nw, nh = int(iw*scale+.5), int(ih*scale+.5)
    img_r = img_pil.resize((nw, nh), Image.LANCZOS)
    l, t = (nw-CW)//2, (nh-CH)//2
    return np.array(img_r.crop((l, t, l+CW, t+CH)))


# ─────────────────────────────────────────────────────────────
# Ken Burns  (subtle smoothstep)
# ─────────────────────────────────────────────────────────────

def ken_burns_frame(canvas_np, t, z_start, z_end, pan_x, pan_y):
    p = t / max(SCENE_DUR, 1e-6)
    p = p*p*(3 - 2*p)                       # smoothstep easing
    zoom   = z_start + (z_end - z_start) * p
    crop_w = int(W / zoom)
    crop_h = int(H / zoom)
    off_x  = int(pan_x * W * p)
    off_y  = int(pan_y * H * p)
    cx, cy = CW//2 + off_x, CH//2 + off_y
    l, top = cx - crop_w//2, cy - crop_h//2
    r, bot = l + crop_w, top + crop_h
    if l < 0:    r -= l;        l = 0
    if top < 0:  bot -= top;    top = 0
    if r > CW:   l -= r-CW;     r = CW
    if bot > CH: top -= bot-CH; bot = CH
    crop = canvas_np[top:bot, l:r]
    # INTER_LANCZOS4 for sharpest quality
    return cv2.resize(crop, OUTPUT_SIZE, interpolation=cv2.INTER_LANCZOS4)


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


_vy, _vx = np.ogrid[:H, :W]
_vdist   = np.sqrt(((_vx-W/2)/(W/2))**2 + ((_vy-H/2)/(H/2))**2)
_vignette = np.clip(1 - 0.60*_vdist**1.7, 0, 1)[:,:,np.newaxis].astype(np.float32)


def apply_vignette(f):
    return (f.astype(np.float32) * _vignette).astype(np.uint8)


# ─────────────────────────────────────────────────────────────
# Effect 1 — Lantern flicker
# ─────────────────────────────────────────────────────────────

def _make_flicker_lut(scene_idx):
    rng  = np.random.RandomState(scene_idx * 7 + 13)
    n    = int(SCENE_DUR * FPS) + 4
    t    = np.linspace(0, SCENE_DUR, n)
    slow = 0.04*np.sin(2*np.pi*0.35*t+0.5) + 0.025*np.sin(2*np.pi*0.72*t+1.1)
    walk = np.cumsum(rng.randn(n)*0.007)
    walk = np.clip(walk, -0.10, 0.10)
    return np.clip(1.0 + slow + walk, 0.84, 1.10).astype(np.float32)


def apply_lantern(frame, fv):
    f = frame.astype(np.float32)
    warmth = (fv - 0.84) / (1.10 - 0.84)
    f[:,:,0] *= fv + 0.04*warmth
    f[:,:,1] *= fv - 0.01*warmth
    f[:,:,2] *= fv - 0.06*warmth
    return np.clip(f, 0, 255).astype(np.uint8)


# ─────────────────────────────────────────────────────────────
# Effect 2 — Cloth warp  (all scenes)
# ─────────────────────────────────────────────────────────────

_cx = np.tile(np.arange(W, dtype=np.float32), (H, 1))
_cy = np.tile(np.arange(H, dtype=np.float32), (W, 1)).T


def apply_cloth_warp(frame, t, scene_idx):
    phase = t * 0.9 + scene_idx * 1.3
    dx = 2.2 * np.sin(_cy*(2*np.pi/190) + phase) * np.sin(_cx*(2*np.pi/420) + t*0.4)
    dy = 1.4 * np.sin(_cx*(2*np.pi/280) + phase+0.8) * np.cos(_cy*(2*np.pi/150) + t*0.6)
    return cv2.remap(frame,
                     (_cx + dx).astype(np.float32),
                     (_cy + dy).astype(np.float32),
                     cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)


# ─────────────────────────────────────────────────────────────
# Effect 3 — Rain  (scene 5)
# ─────────────────────────────────────────────────────────────

class RainSystem:
    N = 420
    def __init__(self, seed=0):
        rng = np.random.RandomState(seed)
        self.x0     = rng.uniform(0, W, self.N).astype(np.float32)
        self.y0     = rng.uniform(-H, H, self.N).astype(np.float32)
        self.vy     = rng.uniform(520, 880, self.N).astype(np.float32)
        self.vx     = rng.uniform(-110, -45, self.N).astype(np.float32)
        self.length = rng.randint(18, 52, self.N)
        self.alpha  = rng.uniform(0.12, 0.45, self.N).astype(np.float32)
        self.phase  = rng.uniform(0, 1, self.N).astype(np.float32)

    def render(self, frame, t):
        overlay = frame.astype(np.float32)
        for i in range(self.N):
            elapsed = t + self.phase[i] * ((H*2) / self.vy[i])
            x  = int((self.x0[i] + self.vx[i]*elapsed) % W)
            y  = int((self.y0[i] + self.vy[i]*elapsed) % (H+60)) - 30
            dx = int(self.vx[i] / self.vy[i] * self.length[i])
            dy = self.length[i]
            cv2.line(overlay,
                     (np.clip(x,0,W-1),    np.clip(y,0,H-1)),
                     (np.clip(x+dx,0,W-1), np.clip(y+dy,0,H-1)),
                     (200, 215, 235), 1)
        return np.clip(frame*0.45 + overlay*0.55, 0, 255).astype(np.uint8)


_rain = RainSystem(seed=42)


# ─────────────────────────────────────────────────────────────
# Effect 4 — Wind / dust  (outdoor scenes 0, 4)
# ─────────────────────────────────────────────────────────────

class WindSystem:
    N = 260
    def __init__(self, seed=1):
        rng = np.random.RandomState(seed)
        self.x0     = rng.uniform(0, W, self.N).astype(np.float32)
        self.y0     = rng.uniform(H*0.25, H*0.95, self.N).astype(np.float32)
        self.vx     = rng.uniform(90, 280, self.N).astype(np.float32)
        self.vy     = rng.uniform(-22, 22, self.N).astype(np.float32)
        self.size   = rng.randint(1, 4, self.N)
        self.alpha  = rng.uniform(0.08, 0.38, self.N).astype(np.float32)
        self.phase  = rng.uniform(0, 1, self.N).astype(np.float32)
        self.streak = rng.random(self.N) < 0.45

    def render(self, frame, t):
        out = frame.astype(np.float32)
        for i in range(self.N):
            elapsed = t + self.phase[i] * (W / abs(self.vx[i]))
            x = int((self.x0[i] + self.vx[i]*elapsed) % W)
            y = int(np.clip(self.y0[i] + self.vy[i]*elapsed, 0, H-1))
            a = float(self.alpha[i])
            if self.streak[i]:
                sx = int(self.vx[i]*0.03); sy = int(self.vy[i]*0.03)
                cv2.line(out, (x,y),
                         (np.clip(x+sx,0,W-1), np.clip(y+sy,0,H-1)),
                         (120+int(a*80), 110+int(a*70), 80+int(a*50)), 1)
            else:
                s = self.size[i]
                out[max(0,y-s):min(H,y+s), max(0,x-s):min(W,x+s)] = (
                    out[max(0,y-s):min(H,y+s), max(0,x-s):min(W,x+s)] * (1-a)
                    + np.array([120,110,80], np.float32) * a
                )
        return np.clip(out, 0, 255).astype(np.uint8)


_wind = [WindSystem(seed=s) for s in [1, 3]]


# ─────────────────────────────────────────────────────────────
# TTS  — gTTS Arabic, cached as WAV numpy arrays
# ─────────────────────────────────────────────────────────────

def tts_to_array(text, scene_idx):
    """Return numpy float32 array for Arabic TTS.
    Tries gTTS (Google) first; falls back to espeak-ng for offline use."""
    cache_wav = os.path.join(TTS_CACHE, f"scene{scene_idx:02d}.wav")

    if not os.path.exists(cache_wav):
        print(f"  TTS → generating scene {scene_idx+1} …")
        generated = False

        # Try gTTS first (requires internet)
        try:
            from gtts import gTTS as _gTTS
            mp3_tmp = cache_wav.replace(".wav", ".mp3")
            tts = _gTTS(text=text, lang="ar", slow=False)
            tts.save(mp3_tmp)
            subprocess.run([
                FFMPEG, "-y", "-i", mp3_tmp,
                "-ar", str(SAMPLE_RATE), "-ac", "1",
                "-sample_fmt", "s16", cache_wav
            ], capture_output=True, check=True)
            os.remove(mp3_tmp)
            generated = True
        except Exception as e:
            print(f"    gTTS unavailable ({type(e).__name__}), using espeak-ng …")

        # Fallback: espeak-ng (offline, Arabic formant synthesis)
        if not generated:
            tmp_wav = cache_wav.replace(".wav", "_raw.wav")
            subprocess.run([
                "espeak-ng",
                "-v", "ar",      # Arabic voice
                "-s", "135",     # speed (WPM) — slightly slower for clarity
                "-p", "45",      # pitch
                "-a", "180",     # amplitude
                "-w", tmp_wav,
                text
            ], check=True, capture_output=True)
            # Resample to SAMPLE_RATE stereo via ffmpeg
            subprocess.run([
                FFMPEG, "-y", "-i", tmp_wav,
                "-ar", str(SAMPLE_RATE), "-ac", "1",
                "-sample_fmt", "s16", cache_wav
            ], capture_output=True, check=True)
            os.remove(tmp_wav)

    sr, data = wavfile.read(cache_wav)
    if data.dtype == np.int16:
        data = data.astype(np.float32) / 32768.0
    elif data.dtype == np.int32:
        data = data.astype(np.float32) / 2147483648.0
    # Resample if needed
    if sr != SAMPLE_RATE:
        ratio   = SAMPLE_RATE / sr
        new_len = int(len(data) * ratio)
        data    = np.interp(
            np.linspace(0, len(data)-1, new_len),
            np.arange(len(data)), data
        ).astype(np.float32)
    return data


# ─────────────────────────────────────────────────────────────
# Audio  (rain / wind / oud + TTS voice mixed per scene)
# ─────────────────────────────────────────────────────────────

def _norm(s, vol):
    p = np.abs(s).max()
    return s / p * vol if p > 1e-9 else s


def gen_rain(dur, vol=0.18):
    n     = int(dur * SAMPLE_RATE)
    noise = np.random.RandomState(5).randn(n).astype(np.float32)
    bp    = sig.butter(6, [350,8000], btype='bandpass', fs=SAMPLE_RATE, output='sos')
    lp    = sig.butter(4, 100,       btype='lowpass',  fs=SAMPLE_RATE, output='sos')
    return _norm(sig.sosfilt(bp,noise)*0.80 + sig.sosfilt(lp,noise)*0.20, vol)


def gen_wind(dur, vol=0.15):
    n     = int(dur * SAMPLE_RATE)
    noise = np.random.RandomState(7).randn(n).astype(np.float32)
    lp    = sig.butter(5, 320,     btype='lowpass',  fs=SAMPLE_RATE, output='sos')
    bp    = sig.butter(4, [380,860],btype='bandpass', fs=SAMPLE_RATE, output='sos')
    t_arr = np.linspace(0, dur, n, dtype=np.float32)
    lfo   = 0.52 + 0.48*np.sin(2*np.pi*0.28*t_arr + 1.0)
    return _norm((sig.sosfilt(lp,noise)*0.75 + sig.sosfilt(bp,noise)*0.25)*lfo, vol)


def gen_indoor(dur, vol=0.05):
    n     = int(dur * SAMPLE_RATE)
    noise = np.random.RandomState(9).randn(n).astype(np.float32)
    hp    = sig.butter(3, 80,   btype='highpass', fs=SAMPLE_RATE, output='sos')
    lp    = sig.butter(3, 2800, btype='lowpass',  fs=SAMPLE_RATE, output='sos')
    return _norm(sig.sosfilt(lp, sig.sosfilt(hp, noise)), vol)


def gen_oud_drone(dur, vol=0.08):
    n   = int(dur * SAMPLE_RATE)
    t   = np.linspace(0, dur, n, dtype=np.float32)
    vib = 1.0 + 0.0028*np.sin(2*np.pi*5.6*t)
    d2  = 73.42
    toneD = sum(a*np.sin(2*np.pi*d2*k*vib*t)
                for k,a in enumerate([1.0,0.62,0.38,0.22,0.13,0.07,0.04], 1))
    a2  = 110.0
    toneA = sum(a*np.sin(2*np.pi*a2*k*vib*t)
                for k,a in enumerate([0.5,0.28,0.14,0.07], 1))
    tone = (toneD + toneA) * (0.55 + 0.45*np.sin(2*np.pi*0.14*t + 0.3))
    lp   = sig.butter(4, 1800, btype='lowpass', fs=SAMPLE_RATE, output='sos')
    return _norm(sig.sosfilt(lp, tone.astype(np.float32)), vol)


def build_audio_track(tts_arrays, total_dur):
    print("  Mixing audio track …")
    n_total = int(total_dur * SAMPLE_RATE)
    full    = np.zeros(n_total, dtype=np.float32)

    # Global oud drone underneath everything
    oud = gen_oud_drone(total_dur)[:n_total]
    full += oud

    cursor = 0
    for i, (_, _, audio_type, _) in enumerate(SCENES):
        seg_n = int(SCENE_DUR * SAMPLE_RATE)

        # Ambient bed (lower volume to not compete with voice)
        if audio_type == "rain":
            amb = gen_rain(SCENE_DUR)
        elif audio_type == "indoor":
            amb = gen_indoor(SCENE_DUR)
        else:
            amb = gen_wind(SCENE_DUR)

        # Fade ambient edges
        fade = int(FADE_DUR * SAMPLE_RATE)
        amb[:fade]  *= np.linspace(0, 1, fade, dtype=np.float32)
        amb[-fade:] *= np.linspace(1, 0, fade, dtype=np.float32)

        end = min(cursor + len(amb), n_total)
        full[cursor:end] += amb[:end-cursor]

        # TTS voice — centre within scene window
        voice = tts_arrays[i]
        voice_n  = len(voice)
        scene_n  = seg_n
        # Clamp voice to scene length; centre it
        if voice_n >= scene_n:
            voice = voice[:scene_n]
            v_off = cursor
        else:
            v_off = cursor + max(0, (scene_n - voice_n) // 2)

        v_end = min(v_off + len(voice), n_total)
        full[v_off:v_end] += voice[:v_end-v_off] * 0.88   # voice at 88%

        if i < len(SCENES)-1:
            cursor += int((SCENE_DUR - FADE_DUR) * SAMPLE_RATE)

    full   = np.clip(full, -1, 1)
    stereo = np.stack([full, full], axis=1)
    return AudioArrayClip(stereo, fps=SAMPLE_RATE)


# ─────────────────────────────────────────────────────────────
# Scene clip builder  (no text captions — voice only)
# ─────────────────────────────────────────────────────────────

def make_scene_clip(canvas_np, scene_idx, effects):
    z_start, z_end, pan_x, pan_y = ZOOM_CONFIGS[scene_idx]
    flicker_lut = _make_flicker_lut(scene_idx) if "lantern" in effects else None
    wind_sys    = _wind[scene_idx % len(_wind)]  if "wind"    in effects else None

    def make_frame(t):
        f = ken_burns_frame(canvas_np, t, z_start, z_end, pan_x, pan_y)
        f = cinematic_grade(f)
        f = apply_vignette(f)
        if flicker_lut is not None:
            fi = min(int(t*FPS), len(flicker_lut)-1)
            f  = apply_lantern(f, flicker_lut[fi])
        if "cloth" in effects:
            f = apply_cloth_warp(f, t, scene_idx)
        if "rain" in effects:
            f = _rain.render(f, t)
        if wind_sys is not None:
            f = wind_sys.render(f, t)
        # Fade in / out
        if t < FADE_DUR:
            alpha = t / FADE_DUR
        elif t > SCENE_DUR - FADE_DUR:
            alpha = (SCENE_DUR - t) / FADE_DUR
        else:
            alpha = 1.0
        if alpha < 1.0:
            f = (f * max(0.0, min(1.0, alpha))).astype(np.uint8)
        return f

    return VideoClip(make_frame, duration=SCENE_DUR)


# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────

def main():
    print("Arabic Video Promo Generator  v4")
    print("=" * 52)
    print(f"Output  : {OUTPUT_FILE}")
    print(f"Size    : {W}×{H} @ {FPS} fps  |  KB max zoom: 1.05×")
    print(f"Captions: Arabic TTS (gTTS lang='ar')")
    print()

    # Step 1 — generate / load TTS
    print("── TTS generation ──")
    tts_arrays = []
    for i, (_, text, _, _) in enumerate(SCENES):
        arr = tts_to_array(text, i)
        dur = len(arr) / SAMPLE_RATE
        print(f"  Scene {i+1}: {dur:.2f}s  '{text[:30]}…'" if len(text)>30
              else f"  Scene {i+1}: {dur:.2f}s  '{text}'")
        tts_arrays.append(arr)
    print()

    # Step 2 — build video clips
    print("── Video scenes ──")
    clips      = []
    start_time = 0.0

    for i, (filename, _, audio_type, effects) in enumerate(SCENES):
        eff_str = ", ".join(sorted(effects))
        print(f"Scene {i+1}/{len(SCENES)}: {filename}  [{eff_str}]")
        img       = load_image(filename, i)
        canvas_np = prepare_canvas(img)
        clip      = make_scene_clip(canvas_np, i, effects)
        clip      = clip.with_start(start_time)
        clips.append(clip)
        if i < len(SCENES)-1:
            start_time += SCENE_DUR - FADE_DUR

    total_dur = start_time + SCENE_DUR
    print(f"\nTotal duration : {total_dur:.1f}s")

    # Step 3 — audio
    audio = build_audio_track(tts_arrays, total_dur)
    audio = audio.with_duration(total_dur)

    # Step 4 — render
    print("\nRendering … (takes several minutes)\n")
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
        ffmpeg_params=["-crf", "18"],   # slightly higher quality
    )

    size_mb = os.path.getsize(OUTPUT_FILE) / 1_048_576
    print(f"\nDone!  {OUTPUT_FILE}  ({size_mb:.1f} MB)")


if __name__ == "__main__":
    main()
