#!/usr/bin/env python3
"""
Zurvan OS — Brand Suite Generator
==================================
Single source of truth for all branding image generation.
Uses an Anchor Image Pipeline (Image-to-Image prompting) to guarantee
visual uniformity across every touchpoint.

Usage:
    python3 branding/scripts/generate.py              # generate all assets (logo first, then derived)
    python3 branding/scripts/generate.py logo         # generate anchor logo only
    python3 branding/scripts/generate.py wallpaper_dark # generate single asset using existing anchor logo
    python3 branding/scripts/generate.py --list       # print all asset keys

Requirements:
    GEMINI_API_KEY set in .env or environment variable.
"""

import base64
import io
import json
import os
import sys
import time
import urllib.request
import urllib.error
from PIL import Image

# ─────────────────────────────────────────────────────────────────────────────
# PATHS
# ─────────────────────────────────────────────────────────────────────────────
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

ASSETS_DIR       = f"{ROOT}/assets"
PIXMAPS          = f"{ROOT}/../config/includes.chroot/usr/share/pixmaps"
WALLPAPERS       = f"{ROOT}/../config/includes.chroot/usr/share/wallpapers/Zurvan/contents/images"
GRUB_THEME       = f"{ROOT}/../config/includes.chroot/boot/grub/themes/zurvan"
PLYMOUTH_THEME   = f"{ROOT}/../config/includes.chroot/usr/share/plymouth/themes/zurvan"
BINARY_GRUB      = f"{ROOT}/../config/includes.binary/boot/grub"
BINARY_ISOLINUX  = f"{ROOT}/../config/includes.binary/isolinux"

ANCHOR_IMAGE_PATH = f"{ASSETS_DIR}/zurvan_logo.png"

for d in [ASSETS_DIR, PIXMAPS, WALLPAPERS, GRUB_THEME, PLYMOUTH_THEME, BINARY_GRUB, BINARY_ISOLINUX]:
    os.makedirs(d, exist_ok=True)

# ─────────────────────────────────────────────────────────────────────────────
# BRAND DNA  ← single shared style preamble injected into every prompt
# ─────────────────────────────────────────────────────────────────────────────
BRAND_DNA = """\
Zurvan OS Visual Identity Rules (apply strictly to this image):
• Aesthetics: Flat 2D vector graphic, ultra-crisp line art, Google Material Design 3 aesthetic — STRICTLY NO 3D rendering, NO glassmorphism, NO drop shadows, NO photorealism.
• Palette: Background deep cosmic indigo #0F172A → void violet #1E1B4B; Primary accent electric cyan #00F2FE; Secondary accent soft purple #C084FC; Text primary crisp white #F8FAFC; Text secondary cyan #80DEEA.
• Core Motif: A clean, bold, mathematically symmetrical 2D vector infinity loop (∞) with uniform stroke thickness, rendered in a smooth gradient from Electric Cyan #00F2FE to Soft Purple #C084FC.
• Central Starpoint: At the exact optical central crossover point of the infinity loop, a single, razor-sharp 4-point white (#FFFFFF) diamond starpoint shines cleanly with crisp edges.
• Accent Details: 3 to 5 tiny, microscopic pinpoint starlight dots in the cosmic background for atmospheric depth.
• Typography Rules: Bilingual layout — "ZURVAN OS" in bold geometric sans-serif (#F8FAFC); "زروان" in modern geometric Persian script without vocalization diacritics (#00F2FE).
• Mood: Pristine, cosmic, infinite, serene, executive tech brand identity.
"""

def build_prompt(asset_brief: str, has_reference: bool = False) -> str:
    """Combine brand DNA with asset brief and reference instructions."""
    ref_instruction = ""
    if has_reference:
        ref_instruction = (
            "\n• VISUAL CONSISTENCY MANDATE: The attached reference image contains the official "
            "Zurvan OS master logo and emblem. You MUST copy the exact shape, line weight, vector geometry, "
            "color hexes, and typography style of the emblem and text from the reference image into this "
            "new composition. Maintain 100% brand consistency.\n"
        )
    return f"{BRAND_DNA}{ref_instruction}\nAsset-specific instructions:\n{asset_brief}"


# ─────────────────────────────────────────────────────────────────────────────
# ASSET REGISTRY
# Each entry: key → { brief, outputs }
# ─────────────────────────────────────────────────────────────────────────────
ASSETS: dict[str, dict] = {

"logo": {
        "brief": (
            "Pristine, mathematically perfect 10/10 2D vector brand logo for Zurvan OS on 1:1 square canvas. "
            "CENTRE: Completely symmetrical vector infinity loop (∞) with equal stroke thickness on both lobes. "
            "Flawless gradient: Electric Cyan #00F2FE on left loop transitioning to Soft Purple #C084FC on right loop. "
            "At the exact geometric center nexus: a razor-sharp pure white (#FFFFFF) 4-point diamond star with clean edges. "
            "TYPOGRAPHY: Generous breathing room below. 'ZURVAN OS' in bold geometric sans-serif white (#F8FAFC). "
            "Below English text: 'زروان' in modern geometric Persian script in solid cyan (#00F2FE) with balanced spacing. "
            "BACKGROUND: Smooth cosmic dark gradient (#0F172A → #1E1B4B) with 3 microscopic pinpoint starlight dots. "
            "Flat 2D vector style, ultra-crisp edges, high contrast, NO 3D rendering, NO drop shadows."
        ),
        "outputs": [
            ANCHOR_IMAGE_PATH,
            f"{PIXMAPS}/zurvan-logo.png",
            f"{PLYMOUTH_THEME}/logo.png",
        ],
    },

    "icon": {
        "brief": (
            "512×512 app launcher icon inside a rounded squircle canvas. "
            "Background: dark cosmic gradient (#0F172A → #1E1B4B). "
            "Centre: The Zurvan 'Z-Infinity' Mobius ribbon monogram, electric cyan #00F2FE and soft purple #C084FC gradient, "
            "with the white diamond starpoint in the upper loop. "
            "Icon ONLY — no text, no wordmarks. Sharp flat 2D vector, no 3D bevels."
        ),
        "outputs": [
            f"{ASSETS_DIR}/zurvan_icon.png",
            f"{PIXMAPS}/zurvan-icon.png",
        ],
    },

    "wallpaper_dark": {
        "brief": (
            "4K dark-mode desktop wallpaper, 16:9 landscape. "
            "Full brand gradient background filling the entire canvas. "
            "Incorporate the orbital ring emblem geometry from the reference image in the centre at subtle low opacity (~20%). "
            "Scattered starlight dots across the canvas. "
            "Small bilingual watermark 'ZURVAN OS' / 'زروان' matching reference font bottom-right corner, 10% opacity. "
            "Plenty of clean empty space — this is behind app windows."
        ),
        "outputs": [
            f"{ASSETS_DIR}/zurvan_wallpaper_dark.png",
            f"{WALLPAPERS}/1920x1080.png",
        ],
    },

    "wallpaper_light": {
        "brief": (
            "4K light-mode desktop wallpaper, 16:9 widescreen landscape (3840x2160). "
            "BACKGROUND: Smooth, airy platinum-white gradient (#F8FAFC) fading gently to pale slate (#E2E8F0) near the edges. "
            "ATMOSPHERIC GEOMETRY: Ultra-subtle, smooth, low-opacity (~10%) concentric circular orbit rings radiating from the center. "
            "CENTER EMBLEM: Centered in the middle of the canvas, render ONLY the solid 2D vector infinity loop emblem (∞) "
            "in ocean cyan (#00B4D8) and soft lavender (#9D4EDD) with a white 4-point starpoint at the intersection. "
            "STRICTLY NO centered text, NO wordmarks under the central emblem — keep the canvas clean and empty for application windows. "
            "WATERMARK: In the bottom-right corner only, a small, subtle bilingual watermark 'ZURVAN OS' / 'زروان' in dark slate (#0F172A) at 15% opacity. "
            "Pristine, serene, airy, Google Material Design 3 light wallpaper aesthetic."
        ),
        "outputs": [
            f"{ASSETS_DIR}/zurvan_wallpaper_light.png",
        ],
    },

    "grub": {
        "brief": (
            "GRUB bootloader background, 16:9 landscape. "
            "Full brand gradient background. "
            "Incorporate the orbital ring emblem from reference image on the LEFT third of the canvas only (leaves clean dark space "
            "in the centre and right where GRUB renders white text menu entries). "
            "Bilingual wordmark 'ZURVAN OS' / 'زروان' top-left corner, small, subtle. "
            "High contrast — text will overlay the dark right two-thirds."
        ),
        "outputs": [
            f"{ASSETS_DIR}/zurvan_grub.png",
            f"{GRUB_THEME}/background.png",
            f"{BINARY_GRUB}/splash.png",
            f"{BINARY_ISOLINUX}/splash.png",
        ],
    },

    "plymouth": {
        "brief": (
            "Plymouth boot-splash background, 16:9 landscape. "
            "Full brand gradient background — same as dark wallpaper but slightly darker. "
            "Place the reference Zurvan infinity emblem centred at medium scale with glowing cyan rings. "
            "Bilingual 'ZURVAN OS' / 'زروان' wordmark matching reference typography just below the emblem. "
            "Lower quarter of canvas is clear dark space — Plymouth will render a progress bar there."
        ),
        "outputs": [
            f"{ASSETS_DIR}/zurvan_plymouth.png",
            f"{PLYMOUTH_THEME}/watermark.png",
        ],
    },

    "calamares_banner": {
        "brief": (
            "Calamares OS-installer horizontal header banner, 5:1 wide landscape (1000×200). "
            "Brand gradient as background. "
            "Left side: small exact Zurvan infinity emblem icon + 'ZURVAN OS' wordmark from reference image. "
            "Right side: Persian tagline 'سیستم‌عامل زروان — سادگی، قدرت و زیبایی بی‌کران' in #80DEEA. "
            "Thin electric-cyan (#00F2FE) line along the very bottom edge as a separator."
        ),
        "outputs": [
            f"{ASSETS_DIR}/zurvan_calamares_banner.png",
        ],
    },

    "lockscreen": {
        "brief": (
            "SDDM / KDE lock-screen background, 16:9 landscape. "
            "Brand gradient, slightly darker than wallpaper. "
            "Reference orbital ring geometry very large and centred but low opacity (~15%) — purely atmospheric. "
            "Centre of canvas kept clean and dark: SDDM will render the login card there. "
            "No text, keep it maximally clean for UI overlay."
        ),
        "outputs": [
            f"{ASSETS_DIR}/zurvan_lockscreen.png",
        ],
    },
}

# ─────────────────────────────────────────────────────────────────────────────
# GEMINI API
# ─────────────────────────────────────────────────────────────────────────────
ENV_FILE = f"{ROOT}/../.env"
MODEL    = "gemini-3.1-flash-image"

def load_api_key() -> str:
    key = os.environ.get("GEMINI_API_KEY", "")
    if not key and os.path.exists(ENV_FILE):
        with open(ENV_FILE, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    if k.strip() == "GEMINI_API_KEY":
                        key = v.strip().strip('"').strip("'")
                        break
    return key


def generate_image(api_key: str, prompt: str, reference_image_bytes: bytes | None = None) -> bytes | None:
    """Sends prompt + optional reference image to Gemini API."""
    url = (
        f"https://generativelanguage.googleapis.com/v1beta"
        f"/models/{MODEL}:generateContent?key={api_key}"
    )

    parts = []
    
    # Pass anchor image as inlineData part if provided
    if reference_image_bytes:
        parts.append({
            "inlineData": {
                "mimeType": "image/png",
                "data": base64.b64encode(reference_image_bytes).decode("utf-8")
            }
        })
        
    parts.append({"text": prompt})

    payload = {
        "contents": [{"parts": parts}],
        "generationConfig": {"responseModalities": ["IMAGE"]},
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            for part in data["candidates"][0]["content"]["parts"]:
                if "inlineData" in part:
                    return base64.b64decode(part["inlineData"]["data"])
    except urllib.error.HTTPError as e:
        print(f"     HTTP {e.code}: {e.read().decode()[:200]}")
    except Exception as e:
        print(f"     Error: {e}")
    return None


def save(img_bytes: bytes, paths: list[str]):
    image = Image.open(io.BytesIO(img_bytes))
    png_buffer = io.BytesIO()
    image.save(png_buffer, format="PNG")
    png_bytes = png_buffer.getvalue()

    for path in paths:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(png_bytes)
        print(f"     ✓ {path}")


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
def main():
    if "--list" in sys.argv:
        print("Available asset keys:")
        for k in ASSETS:
            print(f"  {k}")
        return

    api_key = load_api_key()
    if not api_key or api_key == "your_gemini_api_key_here":
        print("❌  Set GEMINI_API_KEY in .env or environment.")
        sys.exit(1)
    print(f"🔑  API key loaded ({len(api_key)} chars)  |  model: {MODEL}\n")

    # Which assets to generate
    requested = [a for a in sys.argv[1:] if not a.startswith("-")]
    keys = requested if requested else list(ASSETS.keys())

    unknown = [k for k in keys if k not in ASSETS]
    if unknown:
        print(f"❌  Unknown asset key(s): {unknown}. Run --list to see valid keys.")
        sys.exit(1)

    # Reorder keys if full batch run to ensure 'logo' generates first as the anchor
    if not requested and "logo" in keys:
        keys.remove("logo")
        keys.insert(0, "logo")

    # Check for existing anchor image on disk
    anchor_bytes = None
    if os.path.exists(ANCHOR_IMAGE_PATH):
        with open(ANCHOR_IMAGE_PATH, "rb") as f:
            anchor_bytes = f.read()

    total = len(keys)
    for idx, key in enumerate(keys, 1):
        asset = ASSETS[key]
        
        # Determine if we pass the reference anchor image
        use_ref = (key != "logo") and (anchor_bytes is not None)
        prompt = build_prompt(asset["brief"], has_reference=use_ref)
        outputs = asset["outputs"]

        ref_status = " [Using Master Logo Anchor]" if use_ref else ""
        print(f"[{idx}/{total}] {key}{ref_status}")
        
        img = generate_image(api_key, prompt, reference_image_bytes=anchor_bytes if use_ref else None)
        
        if img:
            save(img, outputs)
            # If we just generated the primary logo, update the anchor_bytes for remaining assets
            if key == "logo":
                anchor_bytes = img
        else:
            print(f"     ❌ Failed to generate '{key}'")

        if idx < total:
            time.sleep(2)   # Rate-limit delay

    print("\n🎉  Brand suite generation complete!")


if __name__ == "__main__":
    main()
