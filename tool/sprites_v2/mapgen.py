"""Compone mapas isométricos por época con los sprites de cada época."""
import random, json
from PIL import Image, ImageDraw
from arch import ARCH, render

GROUND = {'1888': ('#3A3226', '#2A241C', '#4A4A2C', '#2C2A20'), '1929': ('#2E312C', '#222521', '#3A4234', '#1E201D'),
          '1980': ('#2C2424', '#1E1919', '#3A3228', '#1A1616'), '2005': ('#3E5A48', '#2C3A3E', '#4F7A52', '#3A4448'),
          '2020': ('#1F3B38', '#142826', '#2C5A44', '#2A3E3B'), '2050': ('#1B2C33', '#12202A', '#2E5A48', '#22343E')}
SKY = {'1888': '#4A3B2C', '1929': '#3A3F3B', '1980': '#3A2632', '2005': '#7FB2C8', '2020': '#12302E', '2050': '#102436'}
STATE_MIX = {'1888': [('normal', .7), ('ruina', .12), ('obra', .1), ('reformada', .04), ('alquilada', .04)],
             '1929': [('normal', .55), ('ruina', .2), ('obra', .08), ('reformada', .07), ('alquilada', .1)],
             '1980': [('normal', .4), ('ruina', .4), ('obra', .1), ('reformada', .05), ('alquilada', .05)],
             '2005': [('normal', .55), ('ruina', .03), ('obra', .27), ('reformada', .08), ('alquilada', .07)],
             '2020': [('normal', .55), ('ruina', .08), ('obra', .12), ('reformada', .1), ('alquilada', .15)],
             '2050': [('normal', .6), ('ruina', .14), ('obra', .1), ('reformada', .08), ('alquilada', .08)]}

WEIGHT = {'torre_deco': .35, 'torre_cristal': .6, 'torre_madera': .7, 'hub_drones': .5, 'torre_brutalista': .7, 'fabrica_vapor': .6}
_cache = {}


def spr(era, key, st):
    k = (era, key, st)
    if k not in _cache:
        _cache[k] = render(era, key, st)
    return _cache[k]


def hexrgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def build(era, n=12, seed=4, sel=None, top=160, sky=True):
    rnd = random.Random(seed * 31 + int(era))
    g, road, park, mark = GROUND[era]
    W = 2 * n * 20 + 8
    H = 2 * n * 10 + top + 8
    OX, OY = n * 20 + 4, top
    im = Image.new('RGBA', (W, H), hexrgb(SKY[era]) + (255 if sky else 0,))
    dr = ImageDraw.Draw(im)
    water = 2 if era == '2050' else 0

    def P(i, j):
        return (OX + (i - j) * 20, OY + (i + j) * 10)

    def dia(i, j, col):
        a, b, c, d = P(i, j), P(i + 1, j), P(i + 1, j + 1), P(i, j + 1)
        dr.polygon([a, b, c, d], fill=hexrgb(col) + (255,))

    occ = set()
    isroad = lambda i, j: i % 5 == 4 or j % 5 == 4
    for i in range(n):
        for j in range(n):
            if water and i >= n - water:
                dia(i, j, '#2D6F8F' if (i + j) % 2 else '#337C9C')
            elif isroad(i, j):
                dia(i, j, road)
                if i % 5 == 4 and j % 5 != 4 and j % 2 == 0:
                    x, y = P(i + .5, j + .5)
                    dr.rectangle([x - 3, y, x + 2, y], fill=hexrgb(mark) + (255,))
            else:
                dia(i, j, g)
    placements = []
    arch = ARCH[era]
    mix = STATE_MIX[era]
    for i in range(n):
        for j in range(n):
            if (i, j) in occ or isroad(i, j) or (water and i >= n - water):
                continue
            if rnd.random() < 0.1 and (i, j) != sel:
                placements.append(('tree', i, j))
                occ.add((i, j))
                continue
            opts = [a for a in arch if all(
                (i + di, j + dj) not in occ and not isroad(i + di, j + dj) and i + di < n - water and j + dj < n
                for di in range(a[2]) for dj in range(a[3]))]
            if sel == (i, j):
                opts = [a for a in opts if a[2] == 1 and a[3] == 1] or opts
            if not opts:
                continue
            wts = [WEIGHT.get(o[0], 1.0) for o in opts]
            a = rnd.choices(opts, weights=wts)[0]
            if era == '2050' and a[0] == 'anfibio':
                continue
            r = rnd.random()
            acc = 0
            st = 'normal'
            for s_, p_ in mix:
                acc += p_
                if r < acc:
                    st = s_
                    break
            if sel == (i, j):
                st = 'normal'
            for di in range(a[2]):
                for dj in range(a[3]):
                    occ.add((i + di, j + dj))
            placements.append((a[0], i, j, a[2], a[3], st))
    if era == '2050':
        for j in range(0, n, 3):
            placements.append(('anfibio', n - 2, j, 1, 1, 'normal'))
    pin = None

    def key(p):
        if p[0] == 'tree':
            return p[1] + p[2] + 1
        return p[1] + p[2] + (p[3] + p[4]) / 2

    for p in sorted(placements, key=key):
        if p[0] == 'tree':
            x, y = P(p[1] + .5, p[2] + .5)
            col = {'1888': '#5E6B38', '1929': '#55644A', '1980': '#4E5236', '2005': '#6FA05E', '2020': '#3E7A52', '2050': '#4FA36B'}[era]
            dr.rectangle([x, y - 4, x, y], fill=(74, 50, 34, 255))
            dr.rectangle([x - 4, y - 13, x + 4, y - 4], fill=hexrgb(col) + (255,))
            dr.rectangle([x - 3, y - 14, x + 3, y - 14], fill=hexrgb(col) + (255,))
            continue
        k, i, j, w, d, st = p
        im_s, (ax, ay) = spr(era, k, st)
        X, Y = P(i, j)
        im.alpha_composite(im_s, (X - ax, Y - ay))
        if sel == (i, j):
            pin = (X, Y - ay + 4)
    if pin:
        x, y = pin
        dr.rectangle([x - 1, y - 8, x + 1, y - 2], fill=(5, 11, 11, 255))
        dr.ellipse([x - 12, y - 34, x + 12, y - 10], fill=(90, 166, 214, 255), outline=(236, 228, 208, 255), width=2)
        dr.rectangle([x - 5, y - 26, x + 5, y - 19], fill=(10, 26, 25, 255))
        dr.rectangle([x - 3, y - 24, x - 1, y - 22], fill=(90, 166, 214, 255))
    return im


if __name__ == '__main__':
    import sys
    out = '/home/claude/epocas_out'
    for e in ARCH:
        m = build(e, n=12)
        m.save(f'{out}/map_{e}.png')
        print(e, m.size)
