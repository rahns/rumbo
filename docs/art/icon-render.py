# App icon: Pico on a warm gradient with a soft sun disc. Uses the reference toucan geometry.
import importlib.util, pathlib, numpy as np
from PIL import Image

# Load the reference toucan from pico-render.py next to this script.
_spec = importlib.util.spec_from_file_location("pico_render", pathlib.Path(__file__).with_name("pico-render.py"))
T = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(T)

def background(top, bottom, sun):
    yy, xx = np.mgrid[0:T.N, 0:T.N] / T.S
    t = (yy / 100)[..., None]
    img = np.array(top, np.float32) * (1 - t) + np.array(bottom, np.float32) * t
    d = np.sqrt((xx - 66) ** 2 + (yy - 30) ** 2)
    glow = np.clip(1 - (d - 24) / 4, 0, 1)[..., None] * 0.35
    img = img * (1 - glow) + np.array(sun, np.float32) * glow
    rgba = np.concatenate([img, np.full(img.shape[:2] + (1,), 255, np.float32)], axis=2)
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")

def icon(top, bottom, sun, name):
    c = T.Canvas(background(top, bottom, sun), ox=10, oy=9, sc=0.84)
    T.draw('idle', canvas=c, shadow=False)
    c.img.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(name)

# Chosen: sunset. The others were jungle and sky.
icon((92, 200, 120), (32, 140, 90), (255, 236, 160), 'icon_jungle.png')
icon((255, 214, 120), (242, 110, 74), (255, 246, 210), 'icon_sunset.png')
icon((120, 205, 250), (40, 120, 200), (255, 240, 190), 'icon_sky.png')
row = Image.new("RGB", (1536, 512), (255, 255, 255))
for i, n in enumerate(['icon_jungle.png', 'icon_sunset.png', 'icon_sky.png']):
    row.paste(Image.open(n).resize((480, 480)), (16 + i * 512, 16))
row.save('icons.png')
