"""Draw a gallery image for the mod's listing (1920x1080 JPG): screenshots of the station window laid as a loose pile of cards
on the preview image's background (tools/make_preview.py), each a little off upright.

Copied from Depot Retrofits (tools/make_gallery.py there, MIT, same author), unchanged apart from this docstring.

Each screenshot is a hand-cropped shot of one whole window, cut tight to the window's light outline: the cut follows that
outline with the window's own rounded corners, so map left below or beside the window shows as a strip under the card. The
close button stands out of the window's top-right corner: there the cut follows the window's outline row by row and adds the
button, so the map between them goes too. Each card is rotated at full size and scaled down last, and the cut is drawn larger
and scaled down, so its edges stay smooth. Cards keep their slant and position from the arguments, so a new set of
screenshots can be laid out the same way.

Usage: python3 tools/make_gallery.py [--spacing N] [--card-height N] OUT_FILE CARD.png[:angle[:dy[:slot]]] ...
Cards are listed from the bottom of the pile to the top. angle is in degrees (positive tilts left), dy moves the card down in
pixels, slot is its place from the left (default: its place in the list). --spacing (pixels between card centres, default
560) and --card-height (default 880) fit more than three cards. Needs rsvg-convert, for the background.

Depot Retrofits drew its listing's 2-retrofit-tabs.jpg (four windows) with --spacing 465 --card-height 760. Record here the
command that draws this mod's gallery image once its crops are chosen (docs/publishing.md, "Gallery").
"""
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_preview  # noqa: E402

W, H = make_preview.W, make_preview.H
CARD_H = 880
SPACING = 560  # between card centres; a card is about 550 wide, so neighbours just overlap once tilted
RADIUS = 34  # the window's rounded corners, in screenshot pixels (its outline meets the edge about 33 pixels from a corner)
CLOSE_CORNER = 120  # the top-right square that holds the window's close button, in screenshot pixels
BUTTON_RADIUS = 15  # the close button's rounded corners
SUPERSAMPLE = 4  # cut masks are drawn this many times larger and scaled down, for smooth edges


def near_outline(p):
    """The light outline around the game's windows (about #545858)."""
    r, g, b = p[:3]
    return 0x4c <= r <= 0x5e and 0x50 <= g <= 0x60 and 0x52 <= b <= 0x62


def window_box(im):
    """The window's outline on each side, found along the middle row and column; the image edge where no outline shows."""
    w, h = im.size
    px = im.load()

    def scan(coords):
        for i, (x, y) in enumerate(coords):
            if near_outline(px[x, y]):
                return i
        return 0

    left = scan([(x, h // 2) for x in range(0, 40)])
    right = scan([(x, h // 2) for x in range(w - 1, w - 41, -1)])
    top = scan([(w // 2, y) for y in range(0, 40)])
    bottom = scan([(w // 2, y) for y in range(h - 1, h - 41, -1)])
    return (left, top, w - right, h - bottom)


def smooth(size, draw):
    """A cut mask of the given size, drawn SUPERSAMPLE times larger by draw(ImageDraw, scale) and scaled down."""
    big = Image.new("L", (size[0] * SUPERSAMPLE, size[1] * SUPERSAMPLE), 0)
    draw(ImageDraw.Draw(big), SUPERSAMPLE)
    return big.resize(size, Image.LANCZOS)


def close_corner(im):
    """The cut in the top-right square: the window up to its outline on each row, and the close button.

    The window's outline bends in around the button, and the map shows in the gap. Each row keeps the window from the
    square's left edge to the end of the first run of outline. The button is the flat blue region around a point above its
    cross, taken as a rounded square a pixel inside that region's bounds.
    """
    w = im.width
    s = CLOSE_CORNER
    px = im.load()
    ends = []
    for y in range(s):
        x = next((x for x in range(w - s, w) if near_outline(px[x, y])), w - 1)
        while x + 1 < w and near_outline(px[x + 1, y]):
            x += 1
        ends.append(x - (w - s) + 1)
    flood = im.crop((w - s, 0, w, s)).convert("RGB")
    ImageDraw.floodfill(flood, (s - 34, 8), (255, 0, 255), thresh=40)
    button = Image.eval(flood, lambda v: 0).convert("L")
    fpx, bpx = flood.load(), button.load()
    for y in range(s):
        for x in range(s):
            if fpx[x, y] == (255, 0, 255):
                bpx[x, y] = 255
    left, top, right, bottom = button.getbbox()
    left, top, right, bottom = left + 1, top + 1, right - 1, bottom - 1  # the flat blue stops short of the map's light rim

    def draw(d, k):
        d.polygon([(0, 0)] + [p for y, e in enumerate(ends) for p in ((e * k, y * k), (e * k, (y + 1) * k))] + [(0, s * k)], fill=255)
        d.rounded_rectangle((left * k, top * k, right * k - 1, bottom * k - 1), BUTTON_RADIUS * k, fill=255)

    return smooth((s, s), draw)


def card(path, angle):
    """The window cut out, rotated by angle and scaled to CARD_H high (before the rotation)."""
    im = Image.open(path).convert("RGBA")
    im = im.crop(window_box(im))
    mask = smooth(im.size, lambda d, k: d.rounded_rectangle((0, 0, im.width * k - 1, im.height * k - 1), RADIUS * k, fill=255))
    mask.paste(close_corner(im), (im.width - CLOSE_CORNER, 0))
    im.putalpha(mask)
    scale = CARD_H / im.height
    im = im.rotate(angle, resample=Image.BICUBIC, expand=True)
    return im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)


def background():
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
           f'<defs>{make_preview.BACKGROUND_DEFS}</defs>{make_preview.background()}</svg>')
    with tempfile.TemporaryDirectory() as tmp:
        src, png = Path(tmp) / "background.svg", Path(tmp) / "background.png"
        src.write_text(svg)
        subprocess.run(["rsvg-convert", "-w", str(W), "-h", str(H), "-o", str(png), str(src)], check=True)
        return Image.open(png).convert("RGBA")


def main():
    global SPACING, CARD_H
    args = sys.argv[1:]
    while args and args[0] in ("--spacing", "--card-height") and len(args) > 1:
        if args[0] == "--spacing":
            SPACING = int(args[1])
        else:
            CARD_H = int(args[1])
        args = args[2:]
    if len(args) < 2:
        sys.exit(__doc__)
    out, specs = Path(args[0]), args[1:]
    image = background()
    for i, spec in enumerate(specs):
        path, *rest = spec.split(":")
        angle = float(rest[0]) if len(rest) > 0 else 0.0
        dy = int(rest[1]) if len(rest) > 1 else 0
        slot = int(rest[2]) if len(rest) > 2 else i
        c = card(path, angle)
        x = round(W / 2 + (slot - (len(specs) - 1) / 2) * SPACING) - c.width // 2
        y = (H - c.height) // 2 + dy
        # The preview's drop shadow (its "shadow" filter): 6 pixels down, blur 7, black at 45%.
        shadow = Image.new("RGBA", c.size, (0, 0, 0, 0))
        shadow.putalpha(c.getchannel("A").point(lambda a: a * 0.45))
        image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(7)), (x, y + 6))
        image.alpha_composite(c, (x, y))
    out.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(out, quality=92, optimize=True, progressive=True)
    print(out)


if __name__ == "__main__":
    main()
