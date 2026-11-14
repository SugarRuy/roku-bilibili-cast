"""Render Roku小电视 branding with Pillow and the font bundled with the app.

Run `python scripts/make_branding.py` from any directory. The approved FHD tile
is preserved; the transparent TV mark is traced from the supplied icon so it
can be rendered at the size needed by the header, splash and placeholder.
"""
from pathlib import Path
import shutil

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art" / "roku-tv"
OUT = ROOT / "channel" / "images"
FONT = ROOT / "channel" / "fonts" / "hei.ttf"
NAME = "Roku小电视"
BG = (15, 15, 20)
PINK = (244, 91, 137, 255)
LIGHT_PINK = (255, 134, 168, 255)
SCREEN = (35, 44, 58, 255)
WHITE = (255, 249, 247, 255)


def tv_mark(size: tuple[int, int], grey: bool = False) -> Image.Image:
    """Transparent mark in the reference's 512px coordinate system."""
    scale = 4
    image = Image.new("RGBA", (512 * scale, 512 * scale))
    draw = ImageDraw.Draw(image)

    def box(coords):
        return tuple(round(n * scale) for n in coords)

    def rounded(coords, radius, fill):
        draw.rounded_rectangle(box(coords), radius=radius * scale, fill=fill)

    for start, end in [((176, 130), (208, 168)), ((336, 130), (304, 168))]:
        draw.line(box((*start, *end)), fill=LIGHT_PINK, width=13 * scale)
        x, y = start
        draw.ellipse(box((x - 9, y - 9, x + 9, y + 9)), fill=LIGHT_PINK)
    rounded((117, 169, 395, 361), 50, PINK)
    rounded((142, 191, 339, 338), 32, SCREEN)
    draw.polygon([box(p) for p in [(213, 221), (289, 264), (213, 307)]], fill=WHITE)
    for y in (250, 290):
        draw.ellipse(box((356, y - 11, 378, y + 11)), fill=WHITE)
    for left in (168, 292):
        rounded((left, 362, left + 52, 378), 8, LIGHT_PINK)

    image = image.crop(image.getbbox())
    if grey:
        alpha = image.getchannel("A")
        image = ImageOps.grayscale(image).point(lambda v: 40 + v * 48 // 255).convert("RGBA")
        image.putalpha(alpha)
    image = ImageOps.contain(image, size, Image.Resampling.LANCZOS)
    result = Image.new("RGBA", size)
    result.alpha_composite(image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2))
    return result


def centered_image(canvas, image, center):
    canvas.paste(image, (center[0] - image.width // 2, center[1] - image.height // 2), image)


def centered_text(draw, text, top, font_size, fill):
    font = ImageFont.truetype(str(FONT), font_size)
    width = draw.textlength(text, font=font)
    draw.text(((1920 - width) / 2, top), text, font=font, fill=fill)


def render_branding():
    OUT.mkdir(parents=True, exist_ok=True)
    # This is the user's approved 540 × 405 artwork, without recompression.
    shutil.copyfile(ART / "tile-reference.png", OUT / "icon_focus_fhd.png")
    with Image.open(ART / "tile-reference.png") as tile:
        ImageOps.fit(tile, (290, 218), Image.Resampling.LANCZOS).save(OUT / "icon_focus_hd.png")
    tv_mark((96, 80)).save(OUT / "logo.png")

    splash = Image.new("RGB", (1920, 1080), BG)
    centered_image(splash, tv_mark((440, 410)), (960, 440))
    draw = ImageDraw.Draw(splash)
    centered_text(draw, NAME, 692, 72, WHITE[:3])
    centered_text(draw, "手机投屏 · B站播放", 802, 32, (177, 188, 204))
    splash.save(OUT / "splash_fhd.jpg", quality=95)

    placeholder = Image.new("RGB", (480, 270), (28, 28, 36))
    centered_image(placeholder, tv_mark((180, 170), grey=True), (240, 135))
    placeholder.save(OUT / "placeholder.png")
    print("branding ->", OUT)


if __name__ == "__main__":
    render_branding()
