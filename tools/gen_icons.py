"""Draws the window's rail icons and the timeline's diamond as 32x32 white TGA textures in Media/.

The game tints them with SetVertexColor. Run: python3 tools/gen_icons.py"""
import os
import sys

from PIL import Image, ImageDraw

SIZE, SCALE = 32, 8
BIG = SIZE * SCALE
media = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'Media')


def p(x, y):
    # 24 unit view box, like the mockups' SVG icons, centred in 32 pixels
    return ((x + 4) * SCALE, (y + 4) * SCALE)


def save(name, draw_fn):
    image = Image.new('RGBA', (BIG, BIG), (255, 255, 255, 0))
    draw = ImageDraw.Draw(image)
    draw_fn(draw)
    image = image.resize((SIZE, SIZE), Image.LANCZOS)
    image.save(os.path.join(media, name + '.tga'))


W = int(1.9 * SCALE)


def line(draw, *points):
    draw.line([p(*point) for point in points], fill='white', width=W, joint='curve')
    for point in (points[0], points[-1]):
        x, y = p(*point)
        draw.ellipse([x - W / 2, y - W / 2, x + W / 2, y + W / 2], fill='white')


def plans(draw):
    line(draw, (4, 6), (20, 6))
    line(draw, (4, 12), (14, 12))
    line(draw, (4, 18), (11, 18))


def timeline(draw):
    line(draw, (3, 12), (21, 12))
    line(draw, (7, 8), (7, 16))
    line(draw, (12, 6), (12, 18))
    line(draw, (17, 9), (17, 15))


def ramps(draw):
    line(draw, (3, 20), (21, 4), (21, 20), (3, 20))


def display(draw):
    line(draw, (4, 5), (20, 5), (20, 17), (4, 17), (4, 5))
    line(draw, (9, 21), (15, 21))
    line(draw, (12, 17), (12, 21))


def general(draw):
    x, y = p(12, 12)
    r = 3.5 * SCALE
    draw.ellipse([x - r, y - r, x + r, y + r], outline='white', width=W)
    line(draw, (12, 3), (12, 6))
    line(draw, (12, 18), (12, 21))
    line(draw, (3, 12), (6, 12))
    line(draw, (18, 12), (21, 12))


def diamond(draw):
    c, r = BIG / 2, BIG / 2 - SCALE
    draw.polygon([(c, c - r), (c + r, c), (c, c + r), (c - r, c)], fill='white')


def hatch():
    """Diagonal stripes that tile: the intermission band on the Timeline."""
    size, scale = 16, 8
    big = Image.new('RGBA', (size * scale, size * scale), (255, 255, 255, 0))
    pixels = big.load()
    for x in range(size * scale):
        for y in range(size * scale):
            if ((x + y) // scale) % 16 < 6:
                pixels[x, y] = (255, 255, 255, 255)
    big.resize((size, size), Image.LANCZOS).save(os.path.join(media, 'hatch.tga'))


hatch()
for name, fn in [('rail-plans', plans), ('rail-timeline', timeline), ('rail-ramps', ramps), ('rail-display', display),
                 ('rail-general', general), ('diamond', diamond)]:
    save(name, fn)
print('icons written to', os.path.abspath(media))
