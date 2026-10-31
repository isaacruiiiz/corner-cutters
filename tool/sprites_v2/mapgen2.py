"""Mapas de muestra con los sprites v2."""
import random, json
from PIL import Image, ImageDraw
from mapgen import GROUND, SKY, hexrgb
GROUND = dict(GROUND); GROUND['presente'] = ('#2C4A40', '#1E2E2C', '#3A6A4A', '#3A4A46')
SKY = dict(SKY); SKY['presente'] = '#12302E'
TREE = {'1888': '#5E6B38', '1929': '#55644A', '1980': '#4E5236', '2005': '#6FA05E', '2020': '#3E7A52', '2050': '#4FA36B', 'presente': '#3E7A52'}


def build(era, items, n=12, seed=4, mix=None, top=150):
    """items: lista de (key, w, d, peso, fn(state)->(img,(ax,ay)))"""
    rnd = random.Random(seed * 31 + len(era))
    g, road, park, mark = GROUND[era]
    W = 2 * n * 20 + 8
    H = 2 * n * 10 + top + 8
    OX, OY = n * 20 + 4, top
    im = Image.new('RGBA', (W, H), hexrgb(SKY[era]) + (255,))
    dr = ImageDraw.Draw(im)
    water = 2 if era == '2050' else 0
    P = lambda i, j: (OX + (i - j) * 20, OY + (i + j) * 10)

    def dia(i, j, col):
        dr.polygon([P(i, j), P(i + 1, j), P(i + 1, j + 1), P(i, j + 1)], fill=hexrgb(col) + (255,))
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
    occ = set(); pl = []
    used = {}
    mix = mix or [('normal', .62), ('ruina', .1), ('obra', .1), ('reformada', .08), ('alquilada', .1)]
    for i in range(n):
        for j in range(n):
            if (i, j) in occ or isroad(i, j) or (water and i >= n - water):
                continue
            if rnd.random() < 0.07:
                pl.append(('tree', i, j)); occ.add((i, j)); continue
            opts = [a for a in items if all((i + di, j + dj) not in occ and not isroad(i + di, j + dj) and i + di < n - water and j + dj < n
                                            for di in range(a[1]) for dj in range(a[2]))]
            if not opts:
                continue
            wts = [(0.0 if (o[3] < 0 and used.get(o[0], 0)) else abs(o[3])) / (1 + 2.5 * used.get(o[0], 0)) for o in opts]
            if sum(wts) <= 0:
                continue
            a = rnd.choices(opts, weights=wts)[0]
            used[a[0]] = used.get(a[0], 0) + 1
            r = rnd.random(); acc = 0; st = 'normal'
            for s_, p_ in mix:
                acc += p_
                if r < acc:
                    st = s_; break
            for di in range(a[1]):
                for dj in range(a[2]):
                    occ.add((i + di, j + dj))
            pl.append((a, i, j, st))

    def key(p):
        if p[0] == 'tree':
            return p[1] + p[2] + 1
        a = p[0]
        return p[1] + p[2] + (a[1] + a[2]) / 2
    for p in sorted(pl, key=key):
        if p[0] == 'tree':
            x, y = P(p[1] + .5, p[2] + .5)
            col = hexrgb(TREE[era])
            dr.rectangle([x, y - 4, x, y], fill=(74, 50, 34, 255))
            dr.ellipse([x - 5, y - 15, x + 5, y - 4], fill=tuple(int(c * .85) for c in col) + (255,))
            dr.ellipse([x - 5, y - 15, x + 3, y - 6], fill=col + (255,))
            continue
        a, i, j, st = p
        try:
            spr, (ax, ay) = a[4](st)
        except Exception:
            spr, (ax, ay) = a[4]('normal')
        X, Y = P(i, j)
        im.alpha_composite(spr, (X - ax, Y - ay))
    return im
