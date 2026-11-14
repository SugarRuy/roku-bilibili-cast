"""Render the channel icons, splash and UI chrome into channel/images.

    tools/.venv/bin/python scripts/make-art.py
"""
from pathlib import Path
from PIL import Image, ImageDraw
from make_branding import render_branding

OUT = Path(__file__).resolve().parent.parent / "channel" / "images"
OUT.mkdir(parents=True, exist_ok=True)
BG = (15, 15, 20)
# accent colours, keyed like themes() in channel/components/common/utils.brs; the first is the default
THEMES = {
    "pink": (251, 114, 153),
    "yellow": (255, 201, 60),
    "blue": (61, 139, 253),
    "green": (52, 211, 153),
    "purple": (155, 123, 255),
}
render_branding()


# ---------- UI chrome ----------

def nine_patch(img: Image.Image, stretch_x: tuple[int, int], stretch_y: tuple[int, int], name: str):
    """Wrap img in the 1px guide border Roku's .9.png format wants."""
    w, h = img.size
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    out.paste(img, (1, 1))
    px = out.load()
    for x in range(stretch_x[0], stretch_x[1]):
        px[x + 1, 0] = (0, 0, 0, 255)
    for y in range(stretch_y[0], stretch_y[1]):
        px[0, y + 1] = (0, 0, 0, 255)
    out.save(OUT / name)


def rounded(size, radius, fill=None, outline=None, width=0, scale=4):
    """Antialiased rounded rect: draw large, shrink."""
    W, H = size[0] * scale, size[1] * scale
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle([0, 0, W - 1, H - 1], radius=radius * scale,
                                          fill=fill, outline=outline, width=width * scale)
    return img.resize(size, Image.LANCZOS)


for key, rgb in THEMES.items():
    nine_patch(rounded((48, 48), 14, outline=rgb + (255,), width=5), (20, 28), (20, 28), f"focus_{key}.9.png")
    nine_patch(rounded((56, 56), 28, fill=rgb + (255,)), (27, 29), (27, 29), f"pill_{key}.9.png")
    nine_patch(rounded((28, 28), 10, fill=rgb + (255,)), (12, 16), (12, 16), f"chip_{key}.9.png")
    spin = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    ImageDraw.Draw(spin).arc([16, 16, 240, 240], 0, 270, fill=rgb + (255,), width=20)
    spin.resize((64, 64), Image.LANCZOS).save(OUT / f"spinner_{key}.png")
nine_patch(rounded((56, 56), 28, fill=(255, 255, 255, 34)), (27, 29), (27, 29), "pill_dim.9.png")
nine_patch(rounded((32, 32), 8, fill=(0, 0, 0, 170)), (12, 20), (12, 20), "badge.9.png")
nine_patch(rounded((40, 40), 12, fill=(28, 28, 36, 255)), (16, 24), (16, 24), "card.9.png")

Image.new("RGBA", (4, 4), (0, 0, 0, 0)).save(OUT / "clear.png")

# left-to-right scrim for the detail page backdrop, top scrim for the player HUD
scrim = Image.new("RGBA", (480, 4), (0, 0, 0, 0))
for x in range(480):
    a = 255 if x < 200 else int(255 * max(0.0, 1 - (x - 200) / 280) ** 1.4)
    for y in range(4):
        scrim.putpixel((x, y), BG + (a,))
scrim.save(OUT / "scrim_left.png")
top = Image.new("RGBA", (4, 270), (0, 0, 0, 0))
for y in range(270):
    a = int(220 * (1 - y / 270) ** 1.6)
    for x in range(4):
        top.putpixel((x, y), (0, 0, 0, a))
top.save(OUT / "scrim_top.png")
bottom = top.transpose(Image.FLIP_TOP_BOTTOM)
bottom.save(OUT / "scrim_bottom.png")
print("ui chrome ->", OUT)


# rounds the avatar on the 我的 account card: card colour (see card.9.png) with a hole
S4 = 140 * 4
mask = Image.new("RGBA", (S4, S4), (28, 28, 36, 255))
ImageDraw.Draw(mask).ellipse([0, 0, S4 - 1, S4 - 1], fill=(0, 0, 0, 0))
mask.resize((140, 140), Image.LANCZOS).save(OUT / "avatar_mask.png")
print("avatar mask ->", OUT / "avatar_mask.png")
