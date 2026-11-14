"""Draw the mod's preview image (1920x1080 JPG, the size other mods ship) from SVG with rsvg-convert and Lato.

A retrofitted station with its catchment radius drawn as rings (the stock radius dashed, the retrofitted one blue),
houses the wider ring brings into reach, a bus and a train around it, and the four level trees listed on the left.
The upper right corner is kept clear for a version number. Drawn in the style of Depot Retrofits' cover (its
tools/make_preview.py, MIT, same author), so the two mods' listings read as a pair.

Usage: python3 tools/make_preview.py [OUT_FILE] [--version 1.0] [--keep-svg SVG_FILE]
--keep-svg also writes the SVG the image is rendered from (for example to local/preview/cover.svg); keep it out of station_retrofits_1/.
OUT_FILE defaults to station_retrofits_1/_metadata/0.jpg, the cover (the uploader's Preview slot), and then also writes a copy to
1-cover.jpg, the first gallery image, so the cover opens the gallery too (as in Depot Retrofits' docs/publishing.md).
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

W, H = 1920, 1080

GREEN, AMBER = "#6cc04a", "#f2b33d"
BLUE, TEAL, VIOLET = "#4fa3e0", "#45c1a4", "#a58be6"
INK = "#152031"

# The background's gradient and glow, drawn by background(); the same as Depot Retrofits' cover.
BACKGROUND_DEFS = '''<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#22334b"/><stop offset="1" stop-color="#0e1521"/></linearGradient>
  <radialGradient id="glow" cx="0.62" cy="0.78" r="0.55"><stop offset="0" stop-color="#3a5a7e" stop-opacity=".45"/><stop offset="1" stop-color="#3a5a7e" stop-opacity="0"/></radialGradient>'''


def darker(color, k=0.55):
    r, g, b = (int(color[i:i + 2], 16) for i in (1, 3, 5))
    return f"#{int(r * k):02x}{int(g * k):02x}{int(b * k):02x}"


def text(x, y, s, size=42, anchor="start", weight=700, fill="#fff", opacity=.88):
    return (f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="Lato" font-weight="{weight}" font-size="{size}" '
            f'fill="{fill}" fill-opacity="{opacity}">{s}</text>')


def background():
    out = [f'<rect width="{W}" height="{H}" fill="url(#bg)"/>', f'<rect width="{W}" height="{H}" fill="url(#glow)"/>']
    for x in range(0, W + 1, 160):
        out.append(f'<line x1="{x}" y1="0" x2="{x}" y2="{H}" stroke="#fff" stroke-opacity="0.045" stroke-width="2"/>')
    for y in range(0, H + 1, 160):
        out.append(f'<line x1="0" y1="{y}" x2="{W}" y2="{y}" stroke="#fff" stroke-opacity="0.045" stroke-width="2"/>')
    return "\n".join(out)


# ---- tree icons, drawn on a 64 x 64 grid centred on (0, 0) ----

def glyph(key, ink):
    if key == "catchment":
        return (f'<circle r="27" fill="none" stroke="{ink}" stroke-width="5" stroke-dasharray="8 6"/>'
                f'<circle r="15" fill="none" stroke="{ink}" stroke-width="5"/><circle r="6" fill="{ink}"/>')
    if key == "pollution":
        return (f'<circle cx="-12" cy="2" r="12" fill="{ink}"/><circle cx="3" cy="-8" r="15" fill="{ink}"/>'
                f'<circle cx="17" cy="4" r="10" fill="{ink}"/><rect x="-12" y="2" width="29" height="12" fill="{ink}"/>'
                f'<path d="M -4 20 L 4 28 L 12 20" fill="none" stroke="{ink}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>')
    if key == "noise":
        return (f'<path d="M -26 -9 L -14 -9 L 0 -22 L 0 22 L -14 9 L -26 9 Z" fill="{ink}" stroke="{ink}" stroke-width="3" stroke-linejoin="round"/>'
                f'<path d="M 9 -10 Q 16 0 9 10" fill="none" stroke="{ink}" stroke-width="5" stroke-linecap="round"/>'
                f'<path d="M 16 -19 Q 29 0 16 19" fill="none" stroke="{ink}" stroke-width="5" stroke-linecap="round"/>')
    if key == "upkeep":
        return (f'<circle r="25" fill="none" stroke="{ink}" stroke-width="5"/>'
                f'<text y="12" text-anchor="middle" font-family="Lato" font-weight="900" font-size="34" fill="{ink}">$</text>')
    raise ValueError(key)


def badge(cx, cy, r, key, color):
    """A tree's icon on a coloured disc with a white rim, in the style of Best Before's faces."""
    k = r * 1.45 / 64
    return f'''<g filter="url(#shadow)">
  <circle cx="{cx}" cy="{cy}" r="{r}" fill="{color}" stroke="#fff" stroke-width="{max(4, r * .11):.1f}"/>
  <ellipse cx="{cx - r * .3:.1f}" cy="{cy - r * .5:.1f}" rx="{r * .35:.1f}" ry="{r * .18:.1f}" fill="#fff" opacity=".25"/>
  <g transform="translate({cx} {cy}) scale({k:.3f})">{glyph(key, INK)}</g>
</g>'''


# ---- the station, the vehicles and the houses, flat style: fill, darker same-hue outline, light highlight ----

def arch_window(x, y, w, h, fill, edge, sw=5):
    """An arched window, top left at (x, y): a half circle on a rectangle."""
    r = w / 2
    return (f'<path d="M {x} {y + h} L {x} {y + r} A {r} {r} 0 0 1 {x + w} {y + r} L {x + w} {y + h} Z" '
            f'fill="{fill}" stroke="{edge}" stroke-width="{sw}" stroke-linejoin="round"/>')


def station(cx, ground, s=1.0):
    """A retrofitted station seen from the front: stone hall with a clock in the gable and a tall arched window over
    the entrance, two lower wings, a platform canopy on the right with solar panels. Local units: about 760 wide, the
    origin at the middle of the ground line."""
    wall, edge, course = "#d8c4a0", "#6a5233", "#c2ab84"
    roof, roof_edge, glass, frame = "#5f6e7d", "#323d48", "#9fd6f2", "#4f6d88"
    out = ['<ellipse cx="60" cy="6" rx="420" ry="28" fill="#000" opacity=".35"/>']
    # platform canopy on the right: posts, a shallow roof with solar panels, the platform edge
    out.append(f'<rect x="250" y="-26" width="270" height="26" fill="#9aa4ad" stroke="#434c55" stroke-width="5"/>')
    out.append(f'<rect x="250" y="-26" width="270" height="7" fill="{AMBER}" opacity=".85"/>')
    out += [f'<rect x="{x}" y="-162" width="12" height="136" fill="#7c8894" stroke="#434c55" stroke-width="4"/>' for x in (330, 420, 500)]
    out.append(f'<path d="M 250 -168 L 530 -168 L 546 -150 L 250 -150 Z" fill="{roof}" stroke="{roof_edge}" stroke-width="6" stroke-linejoin="round"/>')
    for x in (282, 362, 442):
        out.append(f'<path d="M {x} -168 L {x + 70} -168 L {x + 62} -190 L {x + 8} -190 Z" fill="#2b4d86" stroke="#1a2f55" stroke-width="3" stroke-linejoin="round"/>')
        out.append(f'<line x1="{x + 35}" y1="-168" x2="{x + 35}" y2="-190" stroke="#7fb0ff" stroke-width="2"/>')
    # the wings
    for x0 in (-300, 120):
        out.append(f'<rect x="{x0}" y="-176" width="180" height="176" fill="{wall}" stroke="{edge}" stroke-width="6"/>')
        out += [f'<line x1="{x0 + 3}" y1="{y}" x2="{x0 + 177}" y2="{y}" stroke="{course}" stroke-width="3"/>' for y in range(-150, 0, 26)]
        out.append(f'<rect x="{x0 - 10}" y="-190" width="200" height="18" rx="3" fill="{roof}" stroke="{roof_edge}" stroke-width="6"/>')
        out += [arch_window(x0 + dx, -138, 50, 104, glass, frame) for dx in (28, 102)]
    # the hall, its gable and clock
    out.append(f'<rect x="-130" y="-270" width="260" height="270" fill="{wall}" stroke="{edge}" stroke-width="6"/>')
    out += [f'<line x1="-127" y1="{y}" x2="127" y2="{y}" stroke="{course}" stroke-width="3"/>' for y in range(-244, 0, 26)]
    out.append(f'<path d="M -150 -268 L 0 -372 L 150 -268 Z" fill="{roof}" stroke="{roof_edge}" stroke-width="6" stroke-linejoin="round"/>')
    out.append(f'<path d="M -112 -282 L 0 -358 L 112 -282 Z" fill="{wall}" stroke="{edge}" stroke-width="4" stroke-linejoin="round"/>')
    out.append(f'<circle cx="0" cy="-308" r="24" fill="#f4efe2" stroke="{edge}" stroke-width="5"/>')
    out.append(f'<path d="M 0 -308 L 0 -324 M 0 -308 L 11 -302" stroke="{INK}" stroke-width="4" stroke-linecap="round"/>')
    # sign
    out.append(f'<rect x="-118" y="-258" width="236" height="40" rx="6" fill="{GREEN}" stroke="{edge}" stroke-width="4"/>')
    out.append(f'<text x="0" y="-228" text-anchor="middle" font-family="Lato" font-weight="900" font-size="28" fill="{INK}" '
               f'letter-spacing="5">STATION</text>')
    # tall arched window over the entrance doors
    out.append(arch_window(-80, -204, 160, 204, glass, frame, 6))
    out.append(f'<line x1="0" y1="-204" x2="0" y2="-80" stroke="{frame}" stroke-width="5"/>')
    out.append(f'<line x1="-80" y1="-122" x2="80" y2="-122" stroke="{frame}" stroke-width="5"/>')
    out.append(f'<rect x="-58" y="-80" width="116" height="80" fill="#2b3c4e" stroke="{edge}" stroke-width="5"/>')
    out.append(f'<line x1="0" y1="-80" x2="0" y2="0" stroke="{edge}" stroke-width="4"/>')
    out.append('<rect x="-296" y="-172" width="14" height="168" fill="#fff" opacity=".12"/>')
    return f'<g transform="translate({cx} {ground}) scale({s})">{"".join(out)}</g>'


def bus(cx, ground, s=1.0, color=GREEN, facing=1):
    edge = darker(color)
    windows = "".join(f'<rect x="{x}" y="-90" width="34" height="32" rx="4" fill="#bfe3f5"/>' for x in range(-104, 60, 42))
    return f'''<g transform="translate({cx} {ground}) scale({s * facing} {s})">
  <ellipse cx="0" cy="2" rx="130" ry="10" fill="#000" opacity=".35"/>
  <rect x="-124" y="-104" width="248" height="88" rx="14" fill="{color}" stroke="{edge}" stroke-width="5"/>
  {windows}
  <path d="M 84 -90 L 112 -90 Q 118 -90 118 -82 L 118 -50 L 84 -50 Z" fill="#bfe3f5"/>
  <rect x="-120" y="-44" width="240" height="8" fill="#fff" opacity=".45"/>
  <circle cx="-74" cy="-14" r="18" fill="#1f262f"/><circle cx="-74" cy="-14" r="7" fill="#9aa7b4"/>
  <circle cx="74" cy="-14" r="18" fill="#1f262f"/><circle cx="74" cy="-14" r="7" fill="#9aa7b4"/>
  <circle cx="114" cy="-30" r="5" fill="#ffe7a3"/>
</g>'''


def train(cx, ground, s=1.0, color=BLUE, facing=1):
    """A two-car passenger train seen from the side, the cab with its sloped nose at the front (right when facing 1).
    Local units: 560 long, the origin at the middle of the rail."""
    edge = darker(color)
    out = ['<ellipse cx="0" cy="2" rx="290" ry="11" fill="#000" opacity=".35"/>',
           '<rect x="-290" y="-6" width="580" height="6" fill="#56606a"/>']
    for x0 in (-280, 4):  # the two cars, the front one ends in a nose
        if x0 == 4:
            out.append(f'<path d="M {x0} -112 L 226 -112 Q 262 -110 276 -60 L 276 -24 L {x0} -24 Z" fill="{color}" stroke="{edge}" '
                       f'stroke-width="5" stroke-linejoin="round"/>')
            out.append('<path d="M 228 -100 Q 252 -98 264 -64 L 228 -64 Z" fill="#bfe3f5"/>')
            out.append('<circle cx="268" cy="-38" r="5" fill="#ffe7a3"/>')
        else:
            out.append(f'<rect x="{x0}" y="-112" width="276" height="88" rx="10" fill="{color}" stroke="{edge}" stroke-width="5"/>')
        out += [f'<rect x="{x0 + dx}" y="-98" width="34" height="30" rx="4" fill="#bfe3f5"/>' for dx in (18, 62, 106, 150, 194)
                if x0 + dx + 34 < 224]
        out.append(f'<rect x="{x0 + 4}" y="-56" width="{268}" height="8" fill="#fff" opacity=".45"/>')
        for bx in (x0 + 50, x0 + 226):
            out.append(f'<rect x="{bx - 36}" y="-28" width="72" height="12" rx="4" fill="#2a323b"/>')
            out += [f'<circle cx="{bx + d}" cy="-12" r="12" fill="#1f262f"/><circle cx="{bx + d}" cy="-12" r="4.5" fill="#9aa7b4"/>' for d in (-20, 20)]
    out.append('<rect x="-6" y="-70" width="14" height="22" fill="#2a323b"/>')
    return f'<g transform="translate({cx} {ground}) scale({s * facing} {s})">{"".join(out)}</g>'


def house(cx, ground, s=1.0, wall="#c9b48f", roof="#a4553f"):
    """A small town house, its windows lit: the people the wider catchment brings into reach."""
    edge = darker(wall, .45)
    return f'''<g transform="translate({cx} {ground}) scale({s})">
  <ellipse cx="0" cy="2" rx="52" ry="7" fill="#000" opacity=".3"/>
  <rect x="-40" y="-56" width="80" height="56" fill="{wall}" stroke="{edge}" stroke-width="4"/>
  <path d="M -50 -54 L 0 -94 L 50 -54 Z" fill="{roof}" stroke="{darker(roof)}" stroke-width="4" stroke-linejoin="round"/>
  <rect x="-28" y="-44" width="18" height="18" fill="#ffd98a"/><rect x="10" y="-44" width="18" height="18" fill="#ffd98a"/>
  <rect x="-8" y="-24" width="16" height="24" fill="{darker(wall, .6)}"/>
</g>'''


def ring(cx, cy, rx, color="#fff", opacity=.4, width=5, dash=""):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    return (f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{rx * .3:.1f}" fill="none" stroke="{color}" '
            f'stroke-opacity="{opacity}" stroke-width="{width}"{d}/>')


def scene():
    """The station right of centre with both catchment rings: the stock one dashed, the retrofitted one wider and in
    the catchment tree's colour, with houses between the two that only the wider ring reaches."""
    cx, g = 1250, 840
    r = 620
    cy = g - 30
    return "\n".join([
        f'<ellipse cx="{cx}" cy="{cy}" rx="{r}" ry="{r * .3:.1f}" fill="{BLUE}" fill-opacity=".08"/>',
        ring(cx, cy, r, BLUE, .9, 8),
        ring(cx, cy, r, BLUE, .25, 26),
        ring(cx, cy, round(r / 1.75), "#fff", .45, 5, "18 14"),
        house(850, 712, .7, "#b9c4cf", "#5e7d99"), house(760, 792, .88),
        house(1808, 752, .8, "#b9c4cf", "#a4553f"),
        text(cx, g + 110, "stock catchment", 32, "middle", 700, "#fff", .6),
        station(cx - 40, g),
        train(cx + 450, g + 70, .58, BLUE, -1),
        bus(cx - 470, g + 130, .72, GREEN),
    ])


def trees():
    """Left column below the title: the four level trees, one row each (badge and what it does)."""
    rows = [("catchment", "Wider catchment area", BLUE), ("pollution", "Less pollution", TEAL),
            ("noise", "Less noise", VIOLET), ("upkeep", "Lower upkeep", AMBER)]
    out = []
    for i, (key, label, color) in enumerate(rows):
        y = 450 + i * 96
        out.append(badge(110, y, 36, key, color))
        out.append(text(170, y + 14, label, 40))
    return "\n".join(out)


def build(version=None):
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
        f'''<defs>
  {BACKGROUND_DEFS}
  <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="6" stdDeviation="7" flood-color="#000" flood-opacity=".45"/></filter>
</defs>''',
        background(),
        scene(),
        '<g filter="url(#shadow)"><text x="70" y="220" font-family="Lato" font-weight="900" font-size="150" fill="#fff" letter-spacing="2">STATION RETROFITS</text></g>',
        f'<text x="76" y="310" font-family="Lato" font-weight="800" font-size="62" fill="{AMBER}" letter-spacing="11">LEVEL UP YOUR STATIONS</text>',
        trees(),
    ]
    if version:  # upper right corner, kept clear for it
        parts.append(f'<text x="{W - 56}" y="72" text-anchor="end" font-family="Lato" font-weight="700" font-size="54" fill="#fff" fill-opacity=".85">v{version}</text>')
    parts.append("</svg>")
    return "\n".join(parts)


def main():
    args = sys.argv[1:]
    version = None
    if "--version" in args:
        i = args.index("--version")
        version = args[i + 1]
        del args[i:i + 2]
    keep_svg = None
    if "--keep-svg" in args:
        i = args.index("--keep-svg")
        keep_svg = Path(args[i + 1])
        del args[i:i + 2]
    metadata = Path(__file__).resolve().parent.parent / "station_retrofits_1/_metadata"
    out = Path(args[0]) if args else metadata / "0.jpg"
    out.parent.mkdir(parents=True, exist_ok=True)
    from PIL import Image
    with tempfile.TemporaryDirectory() as tmp:
        svg, png = Path(tmp) / "preview.svg", Path(tmp) / "preview.png"
        svg.write_text(build(version))
        if keep_svg:
            keep_svg.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(svg, keep_svg)
        subprocess.run(["rsvg-convert", "-w", str(W), "-h", str(H), "-o", str(png), str(svg)], check=True)
        Image.open(png).convert("RGB").save(out, quality=92, optimize=True, progressive=True)
    print(out)
    if not args:
        shutil.copyfile(out, metadata / "1-cover.jpg")
        print(metadata / "1-cover.jpg")


if __name__ == "__main__":
    main()
