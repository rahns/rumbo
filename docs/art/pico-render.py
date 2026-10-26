# Preview of Pico's geometry on the same 100x100 canvas the Swift Canvas uses.
import math
from PIL import Image, ImageDraw

S = 8  # supersampling
def P(x, y): return (x * S, y * S)

GREEN = (46, 196, 140); GREEN_D = (22, 140, 110); TEAL = (24, 150, 140)
MINT = (210, 245, 225); CORAL = (242, 92, 74); SUN = (255, 190, 26)
INK = (30, 42, 74); BLUSH = (255, 140, 150); WHITE = (255, 255, 255)

def rot(pts, deg, cx, cy):
    a = math.radians(deg); c, s = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]

def ellipse_pts(cx, cy, w, h, deg=0, n=64):
    pts = [(cx + w / 2 * math.cos(t), cy + h / 2 * math.sin(t)) for t in [2 * math.pi * i / n for i in range(n)]]
    return rot(pts, deg, cx, cy) if deg else pts

def feather(px, py, length, width, deg):
    # teardrop pointing away from (px,py) at angle deg
    pts = []
    for i in range(41):
        t = i / 40
        x = -length * t
        w = width * math.sin(math.pi * t) * (1 - 0.35 * t)
        pts.append((x, -w / 2))
    for i in range(40, -1, -1):
        t = i / 40
        x = -length * t
        w = width * math.sin(math.pi * t) * (1 - 0.35 * t)
        pts.append((x, w / 2))
    return rot([(px + x, py + y) for x, y in pts], deg, px, py)

def poly(d, pts, fill): d.polygon([P(x, y) for x, y in pts], fill=fill)

def draw(mood, flap=35):
    img = Image.new("RGB", (100 * S, 100 * S), (247, 248, 252))
    d = ImageDraw.Draw(img)
    happy = mood in ("cheer",)
    sleepy = mood == "sleepy"
    # tail: three fanned feathers pointing down-back, coral tip on the middle one
    for deg, col, l in [(-15, GREEN_D, 26), (-32, TEAL, 30), (-50, GREEN_D, 25)]:
        poly(d, feather(36, 66, l, 8, deg), col)
    poly(d, feather(36, 66, 30, 8, -32)[30:52], CORAL)
    # body, slimmer and more upright, with darker underside
    poly(d, ellipse_pts(50, 61, 46, 29, -32), GREEN_D)
    poly(d, ellipse_pts(50, 59.5, 44, 27, -32), GREEN)
    poly(d, ellipse_pts(56, 66, 24, 12, -32), MINT)
    # head
    poly(d, ellipse_pts(66, 36, 34, 33), GREEN_D)
    poly(d, ellipse_pts(66, 35, 32, 31), GREEN)
    # crest: three tufts sweeping back, middle one coral
    for deg, col, l in [(35, GREEN_D, 13), (60, CORAL, 15), (85, GREEN_D, 11)]:
        poly(d, feather(62, 23, l, 6, deg), col)
    # gorget (coral bib) with shine
    poly(d, ellipse_pts(67, 47.5, 20, 11, -12), CORAL)
    poly(d, ellipse_pts(71, 45.5, 5, 2.4, -20), SUN)
    # beak
    poly(d, [(80, 35.5), (99, 34), (99.5, 35.5), (80, 40.5)], INK)
    # eye
    if sleepy:
        d.arc([P(66, 29), P(77, 38)], 20, 160, fill=INK, width=2 * S)
    elif happy:
        d.arc([P(66, 30), P(77, 40)], 200, 340, fill=INK, width=int(2.4 * S))
    else:
        poly(d, ellipse_pts(71.5, 33, 12, 13), WHITE)
        poly(d, ellipse_pts(73.5, 34, 7.5, 8.5), INK)
        poly(d, ellipse_pts(75, 31.5, 2.8, 2.8), WHITE)
        poly(d, ellipse_pts(72, 36.5, 1.4, 1.4), WHITE)
        d.line([P(66.5, 24.5), P(76.5, 23)], fill=GREEN_D, width=int(2.2 * S))
    # blush
    poly(d, ellipse_pts(77, 42, 6, 3.5), BLUSH)
    # wing: three feathers from the shoulder, sweeping up and back
    for i, col in enumerate([GREEN_D, TEAL, GREEN]):
        poly(d, feather(52, 50, 36 - i * 6, 13 - i * 2, flap + i * 7), col)
    return img.resize((400, 400), Image.LANCZOS)

row = Image.new("RGB", (1200, 400), (247, 248, 252))
for i, (m, f) in enumerate([("hover", 45), ("cheer", 75), ("sleepy", -18)]):
    row.paste(draw(m, f), (i * 400, 0))
row.save("pico.png")
