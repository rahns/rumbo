# Reference render of Pico the toucan on the same 100x100 canvas as the Swift Canvas.
# Shapes are cubic Bezier paths (identical control points go into Path.addCurve in Swift).
import math, numpy as np
from PIL import Image, ImageDraw

S = 8
N = 100 * S

def hexc(h, a=1.0):
    h = h.lstrip('#'); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), int(a * 255))

def cubic(p0, p1, p2, p3, n=24):
    return [((1-t)**3*p0[0] + 3*(1-t)**2*t*p1[0] + 3*(1-t)*t**2*p2[0] + t**3*p3[0],
             (1-t)**3*p0[1] + 3*(1-t)**2*t*p1[1] + 3*(1-t)*t**2*p2[1] + t**3*p3[1]) for t in [i/n for i in range(n+1)]]

def path(start, *segs):
    """segs: ('c', c1, c2, p) or ('l', p)"""
    pts = [start]; cur = start
    for s in segs:
        if s[0] == 'c': pts += cubic(cur, s[1], s[2], s[3])[1:]; cur = s[3]
        else: pts.append(s[1]); cur = s[1]
    return pts

def ellipse(cx, cy, w, h, n=72):
    return [(cx + w/2*math.cos(2*math.pi*i/n), cy + h/2*math.sin(2*math.pi*i/n)) for i in range(n)]

def rot(pts, deg, c):
    a = math.radians(deg); cs, sn = math.cos(a), math.sin(a)
    return [(c[0] + (x-c[0])*cs - (y-c[1])*sn, c[1] + (x-c[0])*sn + (y-c[1])*cs) for x, y in pts]

def shift(pts, dx, dy): return [(x+dx, y+dy) for x, y in pts]

class Canvas:
    def __init__(self, background=None, ox=0.0, oy=0.0, sc=1.0):
        self.ox, self.oy, self.sc = ox, oy, sc
        self.img = background.copy() if background is not None else Image.new("RGBA", (N, N), (247, 248, 252, 255))
        yy, xx = np.mgrid[0:N, 0:N]
        self.xx, self.yy = (xx / S - ox) / sc, (yy / S - oy) / sc

    def _px(self, x, y): return ((self.ox + x * self.sc) * S, (self.oy + y * self.sc) * S)

    def _mask(self, pts):
        m = Image.new("L", (N, N), 0); ImageDraw.Draw(m).polygon([self._px(x, y) for x, y in pts], fill=255)
        return np.array(m, dtype=np.float32) / 255

    def _composite(self, rgba, mask):
        base = np.array(self.img, dtype=np.float32)
        a = (rgba[..., 3:4] / 255) * mask[..., None]
        base[..., :3] = base[..., :3] * (1 - a) + rgba[..., :3] * a
        self.img = Image.fromarray(base.astype(np.uint8))

    def fill(self, pts, color):
        rgba = np.zeros((N, N, 4), np.float32); rgba[:] = color
        self._composite(rgba, self._mask(pts))

    def _stops(self, t, stops):
        t = np.clip(t, 0, 1); out = np.zeros(t.shape + (4,), np.float32)
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            sel = (t >= t0) & (t <= t1); f = ((t - t0) / max(t1 - t0, 1e-6))[sel][:, None]
            out[sel] = np.array(c0) * (1 - f) + np.array(c1) * f
        return out

    def linear(self, pts, p0, p1, stops):
        dx, dy = p1[0]-p0[0], p1[1]-p0[1]; L = dx*dx + dy*dy
        t = ((self.xx - p0[0]) * dx + (self.yy - p0[1]) * dy) / L
        self._composite(self._stops(t, stops), self._mask(pts))

    def radial(self, pts, c, r, stops):
        t = np.sqrt((self.xx - c[0])**2 + (self.yy - c[1])**2) / r
        self._composite(self._stops(t, stops), self._mask(pts))

    def stroke(self, pts, color, width, closed=True):
        d = ImageDraw.Draw(self.img); seq = [self._px(x, y) for x, y in pts]
        if closed: seq = seq + [seq[0]]
        d.line(seq, fill=color, width=int(width * S * self.sc), joint="curve")
        r = width * S * self.sc / 2
        for x, y in (seq[:1] + seq[-1:]):
            d.ellipse([x - r, y - r, x + r, y + r], fill=color)

    def out(self): return self.img.resize((400, 400), Image.LANCZOS)

NAVY_HI, NAVY, NAVY_LO, OUT = hexc('3E5290'), hexc('1E2A4A'), hexc('121A33'), hexc('0B1124')
SUN, AMBER, ORANGE, CORAL, CORAL_D = hexc('FFF3C4'), hexc('FFC93C'), hexc('FF8A3D'), hexc('F25C4A'), hexc('C8392B')
SKY, SKY_D, FEET = hexc('6CC4FA'), hexc('2F7FCC'), hexc('5B7FA8')
WHITE, BROWN, BLUSH = hexc('FFFFFF'), hexc('6B4423'), hexc('FF8C96', 0.65)
LEATHER, LEATHER_D, KHAKI, KHAKI_D = hexc('B07A45'), hexc('7E5230'), hexc('E2C48A'), hexc('B8975A')

WING_PIVOT = (31, 48)
def wing(up=0):
    pts = path((30, 45), ('c', (38, 45), (41, 58), (38, 70)), ('c', (35, 78), (26, 80), (21, 73)), ('c', (17, 63), (21, 48), (30, 45)))
    return rot(pts, up, WING_PIVOT)

def draw(mood='idle', breathe=0.0, canvas=None, shadow=True):
    c = canvas or Canvas()
    happy = mood in ('cheer', 'proud'); sleepy = mood == 'sleepy'
    # ground shadow
    if shadow:
        c.fill(ellipse(43, 94, 42, 6), hexc('1E2A4A', 0.12))
    # feet
    for fx in (37, 49):
        for dx in (-3, 0, 3):
            c.stroke([(fx, 84), (fx + dx * 1.3, 91)], FEET, 2.4, closed=False)
    # tail
    tail = rot(path((14, 66), ('l', (26, 66)), ('l', (26, 86)), ('c', (26, 92), (14, 92), (14, 86)), ('l', (14, 66))), 38, (20, 70))
    c.linear(tail, (20, 66), (20, 92), [(0, NAVY), (1, NAVY_LO)]); c.stroke(tail, OUT, 2.2)
    # body
    body = path((40, 24), ('c', (56, 24), (64, 38), (64, 54)), ('c', (64, 72), (54, 88), (40, 88)),
                ('c', (26, 88), (16, 74), (16, 56)), ('c', (16, 38), (26, 24), (40, 24)))
    c.radial(body, (32, 38), 52, [(0, NAVY_HI), (0.45, NAVY), (1, NAVY_LO)])
    if mood == 'backpacker':
        pack = path((12, 50), ('c', (12, 44), (16, 42), (22, 42)), ('l', (26, 42)), ('c', (30, 42), (31, 46), (31, 50)), ('l', (31, 70)), ('c', (31, 74), (28, 76), (24, 76)), ('l', (16, 76)), ('c', (12, 76), (11, 73), (11, 70)), ('l', (12, 50)))
        c.linear(pack, (12, 44), (30, 76), [(0, LEATHER), (1, LEATHER_D)]); c.stroke(pack, OUT, 2.0)
        flap = path((11, 52), ('c', (16, 49), (26, 49), (31, 52)), ('l', (31, 58)), ('c', (26, 61), (16, 61), (11, 58)), ('l', (11, 52)))
        c.fill(flap, LEATHER_D); c.stroke(flap, OUT, 1.6)
        c.fill(ellipse(21, 59, 3, 3), AMBER); c.stroke(ellipse(21, 59, 3, 3), OUT, 1.0)
    # crest
    for pts in ([(34, 26), (30, 12), (39, 24)], [(38, 25), (37, 9), (44, 24)], [(42, 25), (46, 12), (48, 26)]):
        tuft = path(pts[0], ('c', (pts[0][0] - 2, 18), (pts[1][0] - 2, pts[1][1] + 2), pts[1]), ('c', (pts[1][0] + 3, pts[1][1] + 3), (pts[2][0], 18), pts[2]))
        if mood != 'backpacker':
            c.fill(tuft, NAVY); c.stroke(tuft, OUT, 1.8)
    c.stroke(body, OUT, 2.4)
    # chest bib with scalloped feathers
    bib = path((47, 29), ('c', (60, 31), (65, 45), (61, 58)), ('c', (57, 66), (46, 66), (41, 58)), ('c', (38, 48), (38, 34), (47, 29)))
    c.linear(bib, (50, 30), (50, 64), [(0, SUN), (1, AMBER)])
    for row, y in enumerate((44, 50, 56)):
        for i in range(3):
            x = 44 + i * 5 + (row % 2) * 2.5
            if 40 < x < 60:
                c.stroke(path((x - 2.2, y), ('c', (x - 2.2, y + 2.5), (x + 2.2, y + 2.5), (x + 2.2, y))), hexc('E0A82E'), 0.9, closed=False)
    # coral sash
    sash = path((39, 57), ('c', (46, 64), (56, 63), (61, 56)), ('c', (62, 60), (61, 64), (58, 66)), ('c', (51, 71), (43, 69), (38, 62)), ('l', (39, 57)))
    c.linear(sash, (40, 58), (60, 66), [(0, CORAL), (1, CORAL_D)])
    c.stroke(bib, hexc('C9922A'), 1.0)
    # body sheen
    c.fill(ellipse(27, 36, 10, 6), hexc('FFFFFF', 0.13))
    # wing with feather detail and sky-blue tips
    up = 100 if happy else 0
    w = wing(up)
    c.linear(w, (30, 44), (30, 80), [(0, hexc('2E3F72')), (1, NAVY_LO)])
    for a, b, ctl in [((25, 55), (32, 70), (31, 59)), ((22, 61), (28, 74), (25, 67)), ((29, 51), (36, 64), (35, 54))]:
        line = rot(path(a, ('c', ctl, ctl, b)), up, WING_PIVOT)
        c.stroke(line, hexc('4A5C94'), 1.0, closed=False)
    for tx, ty in [(22.5, 73), (27.5, 77), (33, 75.5)]:
        tip = rot(ellipse(tx, ty, 6, 4), up, WING_PIVOT)
        c.fill(tip, SKY); c.stroke(tip, OUT, 1.0)
    c.stroke(w, OUT, 2.2)
    # eye ring, eye, brow
    c.fill(ellipse(54, 36, 23, 23), SKY); c.stroke(ellipse(54, 36, 23, 23), OUT, 1.6)
    if sleepy:
        c.stroke(path((48, 36), ('c', (51, 41), (57, 41), (60, 36))), OUT, 2.2, closed=False)
    elif happy:
        c.stroke(path((48, 39), ('c', (51, 31), (57, 31), (60, 39))), OUT, 2.4, closed=False)
    else:
        c.fill(ellipse(55, 35.5, 15, 17), WHITE); c.stroke(ellipse(55, 35.5, 15, 17), OUT, 1.0)
        c.radial(ellipse(57.2, 36.5, 9.5, 11), (57, 35), 7, [(0, hexc('8A5A2E')), (1, BROWN)])
        c.fill(ellipse(58, 37, 5.2, 6.2), OUT)
        c.fill(ellipse(59.8, 33.4, 3.4, 3.4), WHITE); c.fill(ellipse(55.8, 40, 1.6, 1.6), WHITE)
    c.stroke(path((44, 23), ('c', (49, 20), (56, 19.5), (61, 22))), OUT, 2.6, closed=False)
    c.fill(ellipse(51, 49, 7, 3.8), BLUSH)
    if mood == 'backpacker':
        strap = path((40, 30), ('c', (46, 44), (46, 60), (40, 72)))
        c.stroke(strap, LEATHER_D, 3.2, closed=False); c.stroke(strap, OUT, 0.8, closed=False)
        brim = ellipse(40, 23, 40, 8); c.fill(brim, KHAKI_D); c.stroke(brim, OUT, 1.8)
        crown = path((28, 22), ('c', (28, 12), (34, 8), (40, 8)), ('c', (46, 8), (52, 12), (52, 22)), ('l', (28, 22)))
        c.linear(crown, (40, 8), (40, 22), [(0, KHAKI), (1, KHAKI_D)]); c.stroke(crown, OUT, 1.8)
        band = path((28, 17), ('l', (52, 17)), ('l', (52, 21)), ('l', (28, 21)), ('l', (28, 17)))
        c.fill(band, CORAL); c.stroke(band, OUT, 1.0)
    if mood == 'listening':
        c.stroke(path((32, 34), ('c', (28, 6), (58, 2), (62, 20))), OUT, 4.6, closed=False)
        c.stroke(path((32, 34), ('c', (28, 6), (58, 2), (62, 20))), CORAL, 2.6, closed=False)
        cup = path((27, 30), ('c', (27, 26), (30, 25), (33, 25)), ('l', (37, 25)), ('c', (40, 25), (41, 28), (41, 31)), ('l', (41, 39)), ('c', (41, 42), (39, 44), (36, 44)), ('l', (32, 44)), ('c', (29, 44), (27, 42), (27, 39)), ('l', (27, 30)))
        c.linear(cup, (34, 25), (34, 44), [(0, CORAL), (1, CORAL_D)]); c.stroke(cup, OUT, 1.8)
        for n, (nx, ny) in enumerate([(70, 14), (78, 8)]):
            note = ellipse(nx, ny, 4, 3); c.fill(note, SKY_D)
            c.stroke([(nx + 1.8, ny), (nx + 1.8, ny - 7)], SKY_D, 1.2, closed=False)
    # beak: big, sun to coral, with a sky lower mandible
    lower = path((61, 43), ('c', (76, 43), (90, 45), (98, 47)), ('c', (90, 52), (74, 53), (62, 50)), ('l', (61, 43)))
    upper = path((59, 29), ('c', (74, 21), (93, 29), (99, 46)), ('c', (92, 45), (78, 43), (61, 44)), ('l', (59, 29)))
    if happy:
        lower = rot(lower, 8, (61, 46))
    c.linear(lower, (62, 46), (98, 46), [(0, SKY), (1, SKY_D)]); c.stroke(lower, OUT, 2.0)
    c.linear(upper, (59, 36), (99, 40), [(0, AMBER), (0.5, ORANGE), (0.82, CORAL), (1, CORAL_D)])
    c.stroke(path((64, 28.5), ('c', (76, 24.5), (88, 29), (94, 37))), hexc('FFFFFF', 0.55), 2.0, closed=False)
    c.fill(ellipse(65, 32, 2.4, 1.4), OUT)
    c.stroke(upper, OUT, 2.2)
    if mood in ('cheer', 'proud'):
        for sx, sy, r in [(14, 22, 3), (86, 14, 3.5), (90, 70, 2.5), (8, 52, 2.5)]:
            star = path((sx, sy - r * 2), ('l', (sx + r * 0.6, sy)), ('l', (sx, sy + r * 2)), ('l', (sx - r * 0.6, sy)), ('l', (sx, sy - r * 2)))
            c.fill(star, AMBER)
    if sleepy:
        for i, (zx, zy, zs) in enumerate([(76, 16, 3), (84, 9, 4)]):
            c.stroke([(zx, zy), (zx + zs, zy), (zx, zy + zs), (zx + zs, zy + zs)], SKY_D, 1.4, closed=False)
    return c.out()

if __name__ != "__main__":
    pass
if __name__ == "__main__":
  row = Image.new("RGBA", (1200, 800))
  for i, m in enumerate(['idle', 'cheer', 'sleepy', 'backpacker', 'listening', 'proud']):
      row.paste(draw(m), ((i % 3) * 400, (i // 3) * 400))
  row.save('toucan.png')
