"""Generate serif brand icons from the bundled Roboto Slab Bold font.

Run: python tool/generate_brand_icons.py (requires Pillow and fontTools).
The same font outlines produce SVG, Android vectors and all platform PNGs.
"""
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw
from fontTools.ttLib import TTFont
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.basePen import BasePen

ROOT = Path(__file__).resolve().parents[1]
BLUE = '#0369A1'
FOREGROUND = '#FFFFFF'
font = TTFont(ROOT / 'assets/fonts/RobotoSlab-Bold.ttf')
glyphs = font.getGlyphSet()
cmap = font.getBestCmap()
placed = []
advance = 0
bounds = []
for character in 'q.':
    glyph = glyphs[cmap[ord(character)]]
    pen = BoundsPen(glyphs)
    glyph.draw(TransformPen(pen, (1, 0, 0, 1, advance, 0)))
    bounds.append(pen.bounds)
    placed.append((glyph, advance))
    advance += glyph.width
left = min(b[0] for b in bounds)
bottom = min(b[1] for b in bounds)
right = max(b[2] for b in bounds)
top = max(b[3] for b in bounds)
factor = min(580 / (right - left), 580 / (top - bottom))
dx = 512 - (left + right) * factor / 2
dy = 512 + (top + bottom) * factor / 2


def transformed(pen, offset):
    return TransformPen(pen, (factor, 0, 0, -factor, dx + offset * factor, dy))


paths = []
for glyph, offset in placed:
    pen = SVGPathPen(glyphs)
    glyph.draw(transformed(pen, offset))
    paths.append(pen.getCommands())
svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">\n'
svg += '  <title>qontract - lowercase serif q</title>\n'
svg += f'  <rect width="1024" height="1024" rx="224" fill="{BLUE}"/>\n'
for path in paths:
    svg += f'  <path fill="{FOREGROUND}" d="{path}"/>\n'
svg += '</svg>\n'
(ROOT / 'assets/brand/brand_icon.svg').write_text(svg, encoding='utf-8')
vector = '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
vector += '    android:width="108dp" android:height="108dp"\n'
vector += '    android:viewportWidth="1024" android:viewportHeight="1024">\n'
for path in paths:
    vector += f'    <path android:fillColor="{FOREGROUND}" android:pathData="{path}" />\n'
vector += '</vector>\n'
(ROOT / 'android/app/src/main/res/drawable/ic_launcher_foreground.xml').write_text(vector, encoding='utf-8')


class RasterPen(BasePen):
    """Flatten font curves for antialiased raster exports."""
    def __init__(self):
        super().__init__(glyphs)
        self.contours = []
        self.points = []

    def _moveTo(self, point):
        self.points = [point]

    def _lineTo(self, point):
        self.points.append(point)

    def _qCurveToOne(self, control, end):
        start = self.points[-1]
        steps = max(12, math.ceil((math.dist(start, control) + math.dist(control, end)) / 2))
        for step in range(1, steps + 1):
            t = step / steps
            self.points.append(tuple((1-t)**2 * start[i] + 2*(1-t)*t * control[i] + t*t * end[i] for i in range(2)))

    def _curveToOne(self, c1, c2, end):
        start = self.points[-1]
        for step in range(1, 65):
            t = step / 64
            self.points.append(tuple((1-t)**3*start[i] + 3*(1-t)**2*t*c1[i] + 3*(1-t)*t*t*c2[i] + t**3*end[i] for i in range(2)))

    def _closePath(self):
        self.contours.append(self.points)
        self.points = []

    _endPath = _closePath


def signed_area(points):
    return sum(a[0]*b[1] - b[0]*a[1] for a, b in zip(points, points[1:] + points[:1]))


mask = Image.new('L', (4096, 4096))
mask_draw = ImageDraw.Draw(mask)
for glyph, offset in placed:
    pen = RasterPen()
    glyph.draw(transformed(pen, offset))
    contours = sorted(pen.contours, key=lambda points: abs(signed_area(points)), reverse=True)
    direction = signed_area(contours[0])
    for points in contours:
        mask_draw.polygon([(round(x*4), round(y*4)) for x, y in points],
                          fill=255 if signed_area(points)*direction > 0 else 0)


def icon(size, rounded=False):
    image = Image.new('RGBA', (4096, 4096), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((0, 0, 4095, 4095), radius=896 if rounded else 0, fill=BLUE)
    image.paste(FOREGROUND, (0, 0, 4096, 4096), mask)
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
for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    save(ROOT / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png', size)
ios = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for entry in json.loads((ios / 'Contents.json').read_text())['images']:
    size = round(float(entry['size'].split('x')[0]) * float(entry['scale'][:-1]))
    save(ios / entry['filename'], size)
font.close()
