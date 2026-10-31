"""Motor de sprites isométricos pixel art por época (PIL, sin suavizado).

Celda: rombo 40x20. Ancla: vértice superior de la celda de origen.
Cada arquetipo se dibuja con primitivas (cajas, tejados, ventanas, rayas) y luego
se aplica el estado (normal, ruina, obra, reformada, alquilada).
"""
import random
from PIL import Image, ImageDraw

CW, CH = 20, 10  # media celda


def hexrgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def sh(c, f):
    if isinstance(c, str):
        c = hexrgb(c)
    return tuple(max(0, min(255, int(v * f))) for v in c[:3])


def mix(a, b, t):
    a = hexrgb(a) if isinstance(a, str) else a
    b = hexrgb(b) if isinstance(b, str) else b
    return tuple(int(a[k] * (1 - t) + b[k] * t) for k in range(3))


def desat(c, t):
    c = hexrgb(c) if isinstance(c, str) else c
    g = int(0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2])
    return mix(c, (g, g, g), t)


class Spr:
    def __init__(self, w, d, hmax, state='normal', era='2020', seed=1):
        self.w, self.d = w, d
        self.m = 6
        self.W = (w + d) * CW + 2 * self.m
        self.H = (w + d) * CH + hmax + 2 * self.m
        self.ox = d * CW + self.m
        self.oy = hmax + self.m
        self.img = Image.new('RGBA', (self.W, self.H), (0, 0, 0, 0))
        self.dr = ImageDraw.Draw(self.img)
        self.state = state
        self.era = era
        self.rnd = random.Random(seed)
        self.swaps = {}
        # transformación de color por estado
        self.tone = {'normal': 1.0, 'ruina': 0.62, 'obra': 0.9, 'reformada': 1.08, 'alquilada': 1.08}[state]
        self.gray = {'normal': 0.0, 'ruina': 0.45, 'obra': 0.15, 'reformada': 0.0, 'alquilada': 0.0}[state]

    # --- color por estado
    def sw(self, col):
        if isinstance(col, str) and col.upper() in self.swaps:
            return self.swaps[col.upper()]
        return col

    def c(self, col):
        col = self.sw(col)
        col = hexrgb(col) if isinstance(col, str) else col
        col = desat(col, self.gray)
        return sh(col, self.tone)

    def rc(self, col):
        return hexrgb(col) if isinstance(col, str) else tuple(col[:3])

    def p(self, i, j, z):
        return (round(self.ox + (i - j) * CW), round(self.oy + (i + j) * CH - z))

    def poly(self, pts, col, raw=False):
        self.dr.polygon(pts, fill=(self.rc(col) if raw else self.c(col)) + (255,))

    def line(self, a, b, col, raw=False, width=1):
        self.dr.line([a, b], fill=(self.rc(col) if raw else self.c(col)) + (255,), width=width)

    def px(self, x, y, col, raw=False):
        if 0 <= x < self.W and 0 <= y < self.H:
            self.img.putpixel((int(x), int(y)), (self.rc(col) if raw else self.c(col)) + (255,))

    def rect(self, x, y, w, h, col, raw=False):
        self.dr.rectangle([x, y, x + w - 1, y + h - 1], fill=(self.rc(col) if raw else self.c(col)) + (255,))

    # --- primitivas
    def box(self, i0, j0, w, d, z0, h, wall, top=None, right=None):
        wall, top, right = self.sw(wall), self.sw(top), self.sw(right)
        top = top or sh(wall, 1.18)
        right = right or sh(wall, 0.74)
        A, B, C, D = (i0, j0), (i0 + w, j0), (i0 + w, j0 + d), (i0, j0 + d)
        z1 = z0 + h
        self.poly([self.p(*D, z0), self.p(*C, z0), self.p(*C, z1), self.p(*D, z1)], wall)
        self.poly([self.p(*C, z0), self.p(*B, z0), self.p(*B, z1), self.p(*C, z1)], right)
        self.poly([self.p(*A, z1), self.p(*B, z1), self.p(*C, z1), self.p(*D, z1)], top)
        return dict(i0=i0, j0=j0, w=w, d=d, z0=z0, h=h, wall=wall)

    def fp(self, b, face, u, z):
        """punto en cara: 'L' (frente izq, u en [0,w]) o 'R' (frente der, u en [0,d])"""
        if face == 'L':
            return self.p(b['i0'] + u, b['j0'] + b['d'], z)
        return self.p(b['i0'] + b['w'], b['j0'] + b['d'] - u, z)

    def quad(self, b, face, u, z, du, dz, col, raw=False):
        pts = [self.fp(b, face, u, z), self.fp(b, face, u + du, z), self.fp(b, face, u + du, z + dz), self.fp(b, face, u, z + dz)]
        self.poly(pts, col, raw)

    def flen(self, b, face):
        return b['w'] if face == 'L' else b['d']

    def windows(self, b, face, floors, per, z0, fh, wu, wh, kind='std', dark=None, lit=None, frame=None, skip_ground=False):
        """rejilla de ventanas en una cara con estados aplicados"""
        L = self.flen(b, face)
        step = L / per
        dark = dark or '#2A2622'
        lit = lit or '#E3A93B'
        shade = 1.0 if face == 'L' else 0.82
        for f in range(floors):
            if skip_ground and f == 0:
                continue
            for k in range(per):
                u = k * step + (step - wu) / 2
                z = z0 + f * fh + (fh - wh) / 2 + 1
                col = self.win_color(dark, lit)
                if frame:
                    self.quad(b, face, u - 0.03, z - 1, wu + 0.06, wh + 2, sh(frame, shade))
                self.quad(b, face, u, z, wu, wh, sh(col, shade), raw=True)
                if self.state == 'alquilada' and self.rnd.random() < 0.7:
                    cur = self.rnd.choice(['#C8553D', '#E3A93B', '#5AA6D6', '#4FC08D', '#ECE4D0'])
                    self.quad(b, face, u, z + wh * 0.35, wu * 0.35, wh * 0.65, sh(cur, shade), raw=True)
                    self.quad(b, face, u + wu * 0.65, z + wh * 0.35, wu * 0.35, wh * 0.65, sh(cur, shade), raw=True)
                if self.state == 'ruina' and self.rnd.random() < 0.3:
                    # tablones
                    self.quad(b, face, u - 0.02, z + wh * 0.4, wu + 0.04, 1.5, '#6B4A2E')
                if kind == 'shutter' and self.state != 'ruina':
                    self.quad(b, face, u - wu * 0.45, z, wu * 0.4, wh, sh('#3E6B4A', shade))
                    self.quad(b, face, u + wu * 1.05, z, wu * 0.4, wh, sh('#3E6B4A', shade))

    def win_color(self, dark, lit):
        r = self.rnd.random()
        st = self.state
        if st == 'ruina':
            return sh('#0E0C0B', 1) if r < 0.6 else sh(dark, 0.6)
        if st == 'obra':
            return sh(dark, 0.9)
        if st in ('reformada', 'alquilada'):
            return hexrgb(lit) if r < 0.65 else sh(lit, 0.75)
        return hexrgb(lit) if r < 0.4 else hexrgb(dark)

    def bands(self, b, face, z0, h, every, col, thick=1):
        z = z0 + every
        L = self.flen(b, face)
        while z < z0 + h - 1:
            self.quad(b, face, 0, z, L, thick, col)
            z += every

    def vstripes(self, b, face, n, z0, h, col, wu=0.08):
        L = self.flen(b, face)
        for k in range(n + 1):
            u = k * (L - wu) / n
            self.quad(b, face, u, z0, wu, h, col)

    def door(self, b, face, u, wu, hz, col='#3A2A1E'):
        self.quad(b, face, u, b['z0'], wu, hz, col)

    def gable(self, i0, j0, w, d, zt, rh, roof, wallR, axis='i'):
        if axis == 'i':  # cumbrera paralela a i
            m = j0 + d / 2
            self.poly([self.p(i0, j0, zt), self.p(i0 + w, j0, zt), self.p(i0 + w, m, zt + rh), self.p(i0, m, zt + rh)], sh(roof, 1.15))
            self.poly([self.p(i0 + w, j0 + d, zt), self.p(i0 + w, j0, zt), self.p(i0 + w, m, zt + rh)], sh(wallR, 0.74))
            self.poly([self.p(i0, j0 + d, zt), self.p(i0 + w, j0 + d, zt), self.p(i0 + w, m, zt + rh), self.p(i0, m, zt + rh)], roof)
        else:  # cumbrera paralela a j
            m = i0 + w / 2
            self.poly([self.p(i0, j0, zt), self.p(i0, j0 + d, zt), self.p(m, j0 + d, zt + rh), self.p(m, j0, zt + rh)], sh(roof, 1.15))
            self.poly([self.p(i0, j0 + d, zt), self.p(i0 + w, j0 + d, zt), self.p(m, j0 + d, zt + rh)], wallR)
            self.poly([self.p(i0 + w, j0, zt), self.p(i0 + w, j0 + d, zt), self.p(m, j0 + d, zt + rh), self.p(m, j0, zt + rh)], sh(roof, 0.8))

    def parapet(self, b, col, hh=2):
        i0, j0, w, d, z = b['i0'], b['j0'], b['w'], b['d'], b['z0'] + b['h']
        t = 0.08
        self.box(i0, j0, w, t, z, hh, col)
        self.box(i0, j0, t, d, z, hh, col)
        self.box(i0, j0 + d - t, w, t, z, hh, col)
        self.box(i0 + w - t, j0, t, d, z, hh, col)

    def ground(self, col, i0=0, j0=0, w=None, d=None):
        w = w or self.w
        d = d or self.d
        self.poly([self.p(i0, j0, 0), self.p(i0 + w, j0, 0), self.p(i0 + w, j0 + d, 0), self.p(i0, j0 + d, 0)], col)

    def tree(self, i, j, col='#4F7A3A', h=10):
        x, y = self.p(i, j, 0)
        self.rect(x, y - 4, 1, 4, '#4A3222')
        self.rect(x - 3, y - h, 7, h - 3, col)
        self.rect(x - 2, y - h - 1, 5, 1, sh(col, 1.2))
        self.rect(x + 1, y - h + 1, 3, h - 5, sh(col, 0.8))

    def flag(self, b, col=None):
        col = col or ('#4FC08D' if self.era != '2050' else '#7FF0B8')
        x, y = self.p(b['i0'] + b['w'] * 0.5, b['j0'] + b['d'] * 0.5, b['z0'] + b['h'])
        self.rect(x, y - 14, 1, 14, '#ECE4D0', raw=True)
        self.rect(x + 1, y - 14, 6, 4, hexrgb(col), raw=True)
        self.rect(x + 1, y - 13, 5, 1, sh(col, 1.25), raw=True)

    # --- estados
    def finish(self, main, extras=None):
        st = self.state
        if st == 'ruina':
            self.ruin(main)
        elif st == 'obra':
            self.works(main)
        elif st == 'alquilada':
            self.flag(main)
        elif st == 'reformada':
            self.sparkle(main)
        self.outline()
        return self.img

    def ruin(self, b):
        # mordisco en la cubierta y escombros
        i0, j0, w, d, z = b['i0'], b['j0'], b['w'], b['d'], b['z0'] + b['h']
        r = self.rnd
        cx, cy = self.p(i0 + w * 0.7, j0 + d * 0.35, z)
        pts = [(cx - 7, cy - 1), (cx + 2, cy - 5), (cx + 9, cy - 1), (cx + 4, cy + 6), (cx - 3, cy + 3)]
        self.dr.polygon(pts, fill=(26, 20, 16, 255))
        self.dr.line([pts[0], pts[1], pts[2]], fill=(70, 56, 44, 255))
        for k in range(14):
            x, y = self.p(i0 + w * r.random(), j0 + d + 0.1 + r.random() * 0.15, 0)
            self.px(x, y - r.randint(0, 2), r.choice(['#5A4A3C', '#6E5E4E', '#4A3C30']), raw=True)
        # hiedra o algas
        vine = '#3F5A2C' if self.era != '2050' else '#2F6B5A'
        for k in range(int(10 + w * 8)):
            u = r.random() * w
            zz = r.random() * min(b['h'], 22)
            x, y = self.fp(b, 'L', u, b['z0'] + zz)
            self.px(x, y, vine, raw=True)
            self.px(x, y + 1, sh(vine, 0.8), raw=True)
        if self.era == '2050':
            self.quad(b, 'L', 0, 0, w, 5, (40, 110, 140), raw=True)
            self.quad(b, 'R', 0, 0, d, 5, (34, 95, 122), raw=True)

    def works(self, b):
        era = self.era
        if era == '2050':
            # brazo robótico y drones, marco holográfico
            col = (127, 224, 216)
            for face in ('L', 'R'):
                L = self.flen(b, face)
                self.line(self.fp(b, face, 0, b['z0']), self.fp(b, face, 0, b['z0'] + b['h'] + 4), col, raw=True)
                self.line(self.fp(b, face, L, b['z0']), self.fp(b, face, L, b['z0'] + b['h'] + 4), col, raw=True)
                self.line(self.fp(b, face, 0, b['z0'] + b['h'] + 4), self.fp(b, face, L, b['z0'] + b['h'] + 4), col, raw=True)
            for k in range(4):
                x, y = self.fp(b, 'L', b['w'] * (0.2 + 0.25 * k), b['z0'] + b['h'] * (0.4 + 0.15 * (k % 2)) + 8)
                self.rect(x - 2, y, 5, 1, '#ECE4D0', raw=True)
                self.rect(x, y + 1, 1, 1, '#E3A93B', raw=True)
            x, y = self.fp(b, 'R', b['d'] * 0.5, b['z0'])
            self.line((x + 6, y + 4), (x + 6, y - 12), (230, 120, 60), raw=True, width=2)
            self.line((x + 6, y - 12), (x - 2, y - 20), (230, 120, 60), raw=True, width=2)
            return
        pole = {'1888': '#8A6440', '1929': '#9A9A92', '1980': '#B0A090', '2005': '#C8C8C0', '2020': '#C8C8C0'}[era]
        plank = {'1888': '#A07A4A', '1929': '#8A6A44', '1980': '#8A6A44', '2005': '#6A6A66', '2020': '#6A6A66'}[era]
        for face in ('L', 'R'):
            L = self.flen(b, face)
            n = max(2, int(L * 3))
            top = b['z0'] + b['h'] + 3
            for k in range(n + 1):
                u = L * k / n
                self.line(self.fp(b, face, u, b['z0']), self.fp(b, face, u, top), hexrgb(pole), raw=True)
            z = b['z0'] + 8
            while z < top:
                self.line(self.fp(b, face, 0, z), self.fp(b, face, L, z), hexrgb(plank), raw=True)
                z += 8
            if era in ('2005', '2020'):
                # malla / lona
                mesh = (79, 160, 110) if era == '2020' else (90, 140, 200)
                for k in range(0, n, 2):
                    u = L * k / n
                    pts = [self.fp(b, face, u, b['z0'] + 9), self.fp(b, face, u + L / n, b['z0'] + 9),
                           self.fp(b, face, u + L / n, top - 2), self.fp(b, face, u, top - 2)]
                    ov = Image.new('RGBA', self.img.size, (0, 0, 0, 0))
                    ImageDraw.Draw(ov).polygon(pts, fill=mesh + (120,))
                    self.img.alpha_composite(ov)
        # cartel de obra
        x, y = self.fp(b, 'L', 0.15, 3)
        self.rect(x, y - 8, 9, 6, '#E3A93B', raw=True)
        self.rect(x + 1, y - 7, 7, 1, '#1A1304', raw=True)
        self.rect(x + 1, y - 5, 5, 1, '#1A1304', raw=True)
        self.rect(x + 2, y - 2, 1, 3, '#4A3A2A', raw=True)

    def sparkle(self, b):
        for k in range(3):
            x, y = self.fp(b, 'L', b['w'] * (0.2 + 0.3 * k), b['z0'] + b['h'] * (0.3 + 0.2 * k))
            col = (255, 236, 170)
            self.px(x, y - 1, col, raw=True); self.px(x, y + 1, col, raw=True)
            self.px(x - 1, y, col, raw=True); self.px(x + 1, y, col, raw=True)

    def outline(self, col=(10, 12, 12)):
        im = self.img
        W, H = im.size
        src = im.load()
        alpha = [[src[x, y][3] > 0 for y in range(H)] for x in range(W)]
        out = im.copy()
        o = out.load()
        for x in range(W):
            for y in range(H):
                if not alpha[x][y]:
                    if ((x > 0 and alpha[x - 1][y]) or (x < W - 1 and alpha[x + 1][y]) or
                            (y > 0 and alpha[x][y - 1]) or (y < H - 1 and alpha[x][y + 1])):
                        o[x, y] = col + (255,)
        self.img = out
