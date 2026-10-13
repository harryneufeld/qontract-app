"""Render the geometric SVG brand into platform icons. Requires Pillow.

Run from any directory: python tool/generate_brand_icons.py
The geometry below matches assets/brand/brand_icon.svg. Platform launcher
images use an opaque square so the operating system can apply its own mask.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SKY = '#7DD3FC'
INK = '#082F49'


def icon(size, rounded=False):
    scale = 4
    image = Image.new('RGBA', (1024 * scale, 1024 * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    def box(coords):
        return tuple(round(v * scale) for v in coords)
    draw.rounded_rectangle(box((0, 0, 1024, 1024)),
                           radius=(224 if rounded else 0) * scale, fill=SKY)
    draw.ellipse(box((244, 238, 688, 682)), fill=INK)
    draw.ellipse(box((332, 326, 600, 594)), fill=SKY)
    draw.line(box((586, 580, 684, 678)), fill=INK, width=88 * scale)
    for x, y in [(586, 580), (684, 678), (778, 678)]:
        draw.ellipse(box((x - 44, y - 44, x + 44, y + 44)), fill=INK)
    return image.resize((size, size), Image.Resampling.LANCZOS)


def save(path, size, rounded=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    image = icon(size, rounded)
    if not rounded:
        image = image.convert('RGB')
    image.save(path)


save(ROOT / 'assets/brand/brand_icon.png', 1024, True)
save(ROOT / 'web/favicon.png', 64, True)
save(ROOT / 'web/icons/Icon-192.png', 192)
save(ROOT / 'web/icons/Icon-512.png', 512)
save(ROOT / 'web/icons/apple-touch-icon.png', 180)
for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                      ('xxhdpi', 144), ('xxxhdpi', 192)]:
    save(ROOT / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png', size)
ios = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for entry in json.loads((ios / 'Contents.json').read_text())['images']:
    size = round(float(entry['size'].split('x')[0]) * float(entry['scale'][:-1]))
    save(ios / entry['filename'], size)
