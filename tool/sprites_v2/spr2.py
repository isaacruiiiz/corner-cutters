"""Motor de sprites v2: más detalle por píxel.

Añade sobre Spr: texturas (ladrillo, sillería, chapa), ventanas con marco/alféizar/arco,
cornisas, tejados a cuatro aguas, agujas, sólidos de revolución (cúpulas, conos,
cilindros), rosetones, pináculos, toldos, balcones, rótulos, objetos de azotea y
mobiliario urbano. Recorta al contenido y devuelve el ancla corregida.
"""
import math
import numpy as np
from PIL import Image, ImageDraw
from spr import Spr, sh, mix, hexrgb, CW, CH


class Spr2(Spr):
    def __init__(self, w, d, state='normal', era='2020', seed=1, head=170, ground=True):
        super().__init__(w, d, head, state=state, era=era, seed=seed)
        self.has_ground = ground

    # ------------------------------------------------------------ básicos
    def box(self, i0, j0, w, d, z0, h, wall, top=None, right=None, rim=True, ao=True):
        b = super().box(i0, j0, w, d, z0, h, wall, top, right)
        wall = self.sw(wall)
        topc = self.sw(top) or sh(wall, 1.18)
        if rim and h > 0:
            z1 = z0 + h
            self.line(self.p(i0, j0 + d, z1), self.p(i0 + w, j0 + d, z1), sh(topc, 1.12))
            self.line(self.p(i0 + w, j0 + d, z1), self.p(i0 + w, j0, z1), sh(topc, 1.05))
        if ao and z0 == 0 and h > 3:
            self.line(self.p(i0, j0 + d, 0), self.p(i0 + w, j0 + d, 0), sh(wall, 0.62))
            self.line(self.p(i0 + w, j0 + d, 0), self.p(i0 + w, j0, 0), sh(self.sw(right) or sh(wall, 0.74), 0.62))
        return b

    def fpoly(self, b, face, uz, col, raw=False):
        shade = 1.0 if face == 'L' else 0.8
        c = self.sw(col)
        c = hexrgb(c) if isinstance(c, str) else c
        self.poly([self.fp(b, face, u, z) for u, z in uz], sh(c, shade) if not raw else sh(c, shade), raw=raw)

    def fq(self, b, face, u, z, du, dz, col, raw=False):
        """quad en cara con sombreado automático de la cara derecha"""
        shade = 1.0 if face == 'L' else 0.8
        c = self.sw(col)
        c = hexrgb(c) if isinstance(c, str) else c
        self.quad(b, face, u, z, du, dz, sh(c, shade), raw)

    def fline(self, b, face, u0, z0, u1, z1, col, raw=False):
        shade = 1.0 if face == 'L' else 0.8
        c = self.sw(col)
        c = hexrgb(c) if isinstance(c, str) else c
        self.line(self.fp(b, face, u0, z0), self.fp(b, face, u1, z1), sh(c, shade), raw)

    # ------------------------------------------------------------ texturas
    def texture(self, b, face, kind, col=None, z0=None, z1=None):
        L = self.flen(b, face)
        z0 = b['z0'] if z0 is None else z0
        z1 = b['z0'] + b['h'] if z1 is None else z1
        wall = b['wall']
        if kind == 'brick':
            col = col or sh(wall, 0.84)
            z, row = z0 + 2, 0
            while z < z1 - 1:
                self.fline(b, face, 0, z, L, z, col)
                off = 0.06 if row % 2 else 0.0
                u = off
                while u < L - 0.02:
                    if self.rnd.random() < 0.55:
                        self.fline(b, face, u, z + 1, u, z + 2, col)
                    u += 0.12
                z += 3
                row += 1
        elif kind == 'stone':
            col = col or sh(wall, 0.88)
            z, row = z0 + 3, 0
            while z < z1 - 1:
                self.fline(b, face, 0, z, L, z, col)
                u = 0.1 if row % 2 else 0.2
                while u < L - 0.05:
                    self.fline(b, face, u, z + 1, u, z + 3, col)
                    u += 0.24
                z += 4
                row += 1
        elif kind == 'courses':  # hiladas horizontales finas
            col = col or sh(wall, 0.9)
            z = z0 + 2
            while z < z1 - 1:
                self.fline(b, face, 0, z, L, z, col)
                z += 2
        elif kind == 'panels':  # paneles prefabricados
            col = col or sh(wall, 0.86)
            z = z0
            while z < z1:
                self.fline(b, face, 0, z, L, z, col)
                z += 8
            for k in range(1, int(L / 0.25)):
                self.fline(b, face, k * 0.25, z0, k * 0.25, z1, col)
        elif kind == 'metal':  # chapa ondulada
            col = col or sh(wall, 0.82)
            u = 0.03
            while u < L:
                self.fline(b, face, u, z0, u, z1, col)
                u += 0.07
        elif kind == 'wood':
            col = col or sh(wall, 0.85)
            u = 0.04
            while u < L:
                self.fline(b, face, u, z0, u, z1, col)
                u += 0.1

    def plinth(self, b, h, col, faces='LR'):
        for f in faces:
            self.fq(b, f, 0, b['z0'], self.flen(b, f), h, col)
            self.fline(b, f, 0, b['z0'] + h, self.flen(b, f), b['z0'] + h, sh(col, 1.25))

    def course(self, b, z, col, faces='LR', th=1):
        for f in faces:
            self.fq(b, f, 0, z, self.flen(b, f), th, col)

    def pilasters(self, b, face, n, col, wu=0.06, z0=None, z1=None):
        L = self.flen(b, face)
        z0 = b['z0'] if z0 is None else z0
        z1 = b['z0'] + b['h'] if z1 is None else z1
        for k in range(n + 1):
            u = k * (L - wu) / n
            self.fq(b, face, u, z0, wu, z1 - z0, col)
            self.fline(b, face, u, z0, u, z1, sh(col, 1.15))

    # ------------------------------------------------------------ ventanas
    def win(self, b, face, u, z, wu, wh, style='sash', frame='#ECE4D0', glass=None, lit=None, sill=True):
        glass = glass or '#2A3A40'
        lit = lit or '#E8C070'
        col = self.win_color(glass, lit)
        if style == 'arch':
            r = wu / 2
            pts = [(u, z), (u + wu, z), (u + wu, z + wh - r * 16)]
            for k in range(7):
                a = math.pi * k / 6
                pts.append((u + r + r * math.cos(a), z + wh - r * 10 + math.sin(a) * r * 16))
            pts.append((u, z + wh - r * 16))
            fr = [(x + (0.02 if x < u + r else -0.02) * 0, zz) for x, zz in pts]
            if frame:
                self.fpoly(b, face, [(x, zz + (1 if zz > z + 1 else -1)) for x, zz in pts], frame)
            self.fpoly(b, face, pts, col, raw=False)
        elif style == 'gothic':
            r = wu / 2
            pts = [(u, z), (u + wu, z), (u + wu, z + wh * 0.7), (u + r, z + wh), (u, z + wh * 0.7)]
            if frame:
                self.fpoly(b, face, [(u - 0.02, z - 1), (u + wu + 0.02, z - 1), (u + wu + 0.02, z + wh * 0.7), (u + r, z + wh + 2), (u - 0.02, z + wh * 0.7)], frame)
            self.fpoly(b, face, pts, col)
        else:
            if frame:
                self.fq(b, face, u - 0.025, z - 1, wu + 0.05, wh + 2, frame)
            self.fq(b, face, u, z, wu, wh, col, raw=False)
        # brillo y parteluz
        if style in ('sash', 'arch', 'balcony', 'shutter'):
            if wh >= 5 and wu >= 0.1:
                self.fline(b, face, u + wu / 2, z, u + wu / 2, z + wh - 1, sh(frame, 0.92) if frame else '#1A1A1A')
            if wh >= 6:
                self.fline(b, face, u, z + wh * 0.55, u + wu, z + wh * 0.55, sh(frame, 0.92) if frame else '#1A1A1A')
        if style == 'gothic' and frame:
            self.fline(b, face, u + wu / 2, z, u + wu / 2, z + wh - 1, frame)
        if sill and frame and style != 'strip':
            self.fq(b, face, u - 0.04, z - 2, wu + 0.08, 1, sh(frame, 0.85))
        if style == 'shutter' and self.state != 'ruina':
            sc = '#3E6B4A' if self.era in ('1888', '1929', 'presente') else '#6A5A4A'
            self.fq(b, face, u - wu * 0.5, z, wu * 0.45, wh, sc)
            self.fq(b, face, u + wu * 1.05, z, wu * 0.45, wh, sc)
        if style == 'balcony':
            self.balcony(b, face, u - 0.05, z, wu + 0.1)
        # cortinas al alquilar
        if self.state == 'alquilada' and self.rnd.random() < 0.5:
            cur = self.rnd.choice(['#C8553D', '#E3A93B', '#5AA6D6', '#4FC08D', '#ECE4D0'])
            self.fq(b, face, u, z + 1, wu * 0.3, wh - 2, cur, raw=False)

    def grid(self, b, face, floors, per, z0, fh, wu, wh, style='sash', skip=(), **kw):
        L = self.flen(b, face)
        step = L / per
        for f in range(floors):
            if f in skip:
                continue
            for k in range(per):
                u = k * step + (step - wu) / 2
                z = z0 + f * fh + (fh - wh) / 2 + 1
                self.win(b, face, u, z, wu, wh, style, **kw)

    def balcony(self, b, face, u, z, du, col='#2A2622'):
        # losa que sobresale + barandilla
        if face == 'L':
            j = b['j0'] + b['d']
            a, c = b['i0'] + u, b['i0'] + u + du
            self.poly([self.p(a, j, z), self.p(c, j, z), self.p(c, j + 0.07, z), self.p(a, j + 0.07, z)], sh(b['wall'], 1.1))
            self.line(self.p(a, j + 0.07, z), self.p(c, j + 0.07, z), sh(b['wall'], 0.7))
            self.line(self.p(a, j + 0.07, z + 3), self.p(c, j + 0.07, z + 3), col)
            n = max(2, int(du / 0.05))
            for k in range(n + 1):
                x = a + du * k / n
                self.line(self.p(x, j + 0.07, z), self.p(x, j + 0.07, z + 3), col)
        else:
            i = b['i0'] + b['w']
            a, c = b['j0'] + b['d'] - u, b['j0'] + b['d'] - u - du
            self.poly([self.p(i, a, z), self.p(i, c, z), self.p(i + 0.07, c, z), self.p(i + 0.07, a, z)], sh(b['wall'], 1.0))
            self.line(self.p(i + 0.07, a, z), self.p(i + 0.07, c, z), sh(b['wall'], 0.6))
            self.line(self.p(i + 0.07, a, z + 3), self.p(i + 0.07, c, z + 3), sh(col, 0.8))
            n = max(2, int(du / 0.05))
            for k in range(n + 1):
                y = a - du * k / n
                self.line(self.p(i + 0.07, y, z), self.p(i + 0.07, y, z + 3), sh(col, 0.8))

    def awning(self, b, face, u, z, du, cols=('#C8553D', '#ECE4D0'), depth=0.14, drop=3):
        n = max(2, int(du / 0.08))
        for k in range(n):
            a, c = u + du * k / n, u + du * (k + 1) / n
            col = cols[k % len(cols)]
            if face == 'L':
                j = b['j0'] + b['d']
                pts = [self.p(b['i0'] + a, j, z), self.p(b['i0'] + c, j, z), self.p(b['i0'] + c, j + depth, z - drop), self.p(b['i0'] + a, j + depth, z - drop)]
                self.poly(pts, col)
                x0, y0 = self.p(b['i0'] + a, j + depth, z - drop)
                x1, y1 = self.p(b['i0'] + c, j + depth, z - drop)
                self.line((x0, y0 + 1), (x1, y1 + 1), sh(col, 0.75))
            else:
                i = b['i0'] + b['w']
                ja, jc = b['j0'] + b['d'] - a, b['j0'] + b['d'] - c
                pts = [self.p(i, ja, z), self.p(i, jc, z), self.p(i + depth, jc, z - drop), self.p(i + depth, ja, z - drop)]
                self.poly(pts, sh(col, 0.85))
                x0, y0 = self.p(i + depth, ja, z - drop)
                x1, y1 = self.p(i + depth, jc, z - drop)
                self.line((x0, y0 + 1), (x1, y1 + 1), sh(col, 0.6))

    def shopfront(self, b, face, u, du, h=7, glass='#9CC8E0', frame='#2A2622', awn=None, door=True):
        self.fq(b, face, u, b['z0'], du, h, frame)
        lit = self.state in ('normal', 'reformada', 'alquilada')
        g = '#F2D08A' if lit and self.rnd.random() < 0.5 else glass
        if self.state == 'ruina':
            g = '#141110'
        self.fq(b, face, u + 0.03, b['z0'] + 1, du - 0.06, h - 2, g)
        if door:
            self.fq(b, face, u + du * 0.62, b['z0'], du * 0.18, h - 1, sh(frame, 1.4))
        # brillo
        self.fline(b, face, u + 0.05, b['z0'] + h - 2, u + 0.12, b['z0'] + 2, '#FFFFFF')
        if awn and self.state != 'ruina':
            self.awning(b, face, u - 0.02, b['z0'] + h + 2, du + 0.04, awn)

    def sign(self, b, face, u, z, du, dz, col, txt='#ECE4D0', dots=True):
        self.fq(b, face, u, z, du, dz, col)
        if dots and dz >= 3:
            n = int(du / 0.06)
            for k in range(1, n):
                if self.rnd.random() < 0.7:
                    x, y = self.fp(b, face, u + k * du / n, z + dz / 2)
                    self.px(x, y, txt)

    # ------------------------------------------------------------ cubiertas
    def cornice(self, b, col, over=0.05, h=2, dentil=False):
        z = b['z0'] + b['h']
        self.box(b['i0'] - over, b['j0'] - over, b['w'] + 2 * over, b['d'] + 2 * over, z, h, col, rim=True, ao=False)
        if dentil:
            nb = dict(b, i0=b['i0'] - over, j0=b['j0'] - over, w=b['w'] + 2 * over, d=b['d'] + 2 * over)
            for f in 'LR':
                L = self.flen(nb, f)
                u = 0.02
                while u < L:
                    x, y = self.fp(nb, f, u, z)
                    self.px(x, y, sh(col, 0.6))
                    u += 0.06

    def hip(self, i0, j0, w, d, z, h, col, axis='auto'):
        """tejado a cuatro aguas (si w==d, pirámide)"""
        if axis == 'auto':
            axis = 'i' if w >= d else 'j'
        if axis == 'i':
            r = min(d / 2, w / 2)
            a, bb = (i0 + r, j0 + d / 2), (i0 + w - r, j0 + d / 2)
        else:
            r = min(d / 2, w / 2)
            a, bb = (i0 + w / 2, j0 + r), (i0 + w / 2, j0 + d - r)
        A, B, C, D = (i0, j0), (i0 + w, j0), (i0 + w, j0 + d), (i0, j0 + d)
        P = lambda q, zz: self.p(q[0], q[1], zz)
        if axis == 'i':
            # caras visibles: frente (D-C), derecha (C-B)
            self.poly([P(A, z), P(B, z), P(bb, z + h), P(a, z + h)], sh(col, 1.2))
            self.poly([P(D, z), P(C, z), P(bb, z + h), P(a, z + h)], col)
            self.poly([P(C, z), P(B, z), P(bb, z + h)], sh(col, 0.76))
        else:
            self.poly([P(A, z), P(D, z), P(bb, z + h), P(a, z + h)], sh(col, 1.2))
            self.poly([P(D, z), P(C, z), P(bb, z + h)], col)
            self.poly([P(C, z), P(B, z), P(a, z + h), P(bb, z + h)], sh(col, 0.76))
        self.line(P(a, z + h), P(bb, z + h), sh(col, 1.3))
        self.line(P(C, z), P(bb, z + h), sh(col, 0.9))

    def spire(self, ci, cj, r, z, h, col, cross=None, octo=True):
        """aguja: pirámide fina, con aristas vivas; cross: color de la cruz/remate"""
        A, B, C, D = (ci - r, cj - r), (ci + r, cj - r), (ci + r, cj + r), (ci - r, cj + r)
        top = self.p(ci, cj, z + h)
        P = lambda q: self.p(q[0], q[1], z)
        self.poly([P(D), P(C), top], col)
        self.poly([P(C), P(B), top], sh(col, 0.72))
        if octo:  # arista central luminosa
            self.line(P(C), top, sh(col, 1.25))
        x, y = top
        if cross:
            self.rect(x, y - 5, 1, 5, cross, raw=True)
            self.rect(x - 1, y - 4, 3, 1, cross, raw=True)

    def pinnacles(self, pts, z, h, col):
        for (i, j) in pts:
            x, y = self.p(i, j, z)
            self.rect(x, y - h, 1, h, col)
            self.px(x, y - h - 1, sh(col, 1.3))

    def crenels(self, b, col, every=0.12):
        z = b['z0'] + b['h']
        for f in 'LR':
            L = self.flen(b, f)
            u = 0.0
            while u < L - 0.04:
                self.fq(b, f, u, z, 0.06, 2, col)
                u += every

    def revolve(self, ci, cj, z0, H, rfn, col, light=1.0, bands=None, ribs=0, top=True):
        """sólido de revolución por rodajas (cúpulas, conos, cilindros, bulbos).
        rfn(t) -> radio en celdas, t en [0,1]. bands: lista (t0,t1,color)."""
        col = self.sw(col)
        cx, cy = self.p(ci, cj, 0)
        steps = max(2, int(H))
        W, Hh = self.img.size
        arr = np.array(self.img)
        for k in range(steps + 1):
            t = k / steps
            r = rfn(t)
            if r <= 0.005:
                continue
            c = col
            if bands:
                for (t0, t1, bc) in bands:
                    if t0 <= t <= t1:
                        c = self.sw(bc)
            base = np.array(self.c(c), dtype=float)
            ax, ay = r * CW * math.sqrt(2), r * CH * math.sqrt(2)
            yc = cy - (z0 + t * H)
            x0, x1 = int(cx - ax - 1), int(cx + ax + 2)
            y0, y1 = int(yc - ay - 1), int(yc + ay + 2)
            for y in range(max(0, y0), min(Hh, y1)):
                for x in range(max(0, x0), min(W, x1)):
                    dx, dy = (x + 0.5 - cx) / ax, (y + 0.5 - yc) / ay
                    if dx * dx + dy * dy <= 1.0:
                        # tono por posición horizontal (luz desde la izquierda)
                        if k == steps and top:
                            f = 1.18
                        elif dx < -0.45:
                            f = 1.06 * light
                        elif dx < 0.15:
                            f = 0.92 * light
                        elif dx < 0.6:
                            f = 0.8 * light
                        else:
                            f = 0.7 * light
                        if ribs and k < steps:
                            ang = math.atan2(dy, dx)
                            if abs(math.sin(ang * ribs / 2)) < 0.12:
                                f *= 0.82
                        v = np.clip(base * f, 0, 255)
                        arr[y, x, :3] = v
                        arr[y, x, 3] = 255
        self.img = Image.fromarray(arr)
        self.dr = ImageDraw.Draw(self.img)

    def rose(self, b, face, uc, zc, r, frame='#E8DCC0', glass=('#3E5FA8', '#B8432F', '#E3A93B')):
        pts = []
        for k in range(16):
            a = 2 * math.pi * k / 16
            pts.append((uc + r * math.cos(a), zc + r * 16 * math.sin(a)))
        self.fpoly(b, face, [(u + (u - uc) * 0.25, zc + (z - zc) * 1.25) for u, z in pts], frame)
        self.fpoly(b, face, pts, glass[0], raw=False)
        lit = self.state in ('normal', 'reformada', 'alquilada')
        for k in range(8):
            a = 2 * math.pi * k / 8
            u2, z2 = uc + r * 0.65 * math.cos(a), zc + r * 10.4 * math.sin(a)
            x, y = self.fp(b, face, u2, z2)
            self.px(x, y, glass[1 + k % 2] if lit else '#3A3030')
            self.fline(b, face, uc, zc, uc + r * math.cos(a), zc + r * 16 * math.sin(a), frame)
        x, y = self.fp(b, face, uc, zc)
        self.px(x, y, glass[2])

    def barrel(self, i0, i1, jc, R, z0, col, end=None, ribs=0.15, rise=None, glass=True):
        """bóveda de cañón a lo largo de i (testero visible en la cara derecha)"""
        rise = rise or R * 14
        n = 14
        prof = [(jc - R + 2 * R * k / n, z0 + rise * math.sqrt(max(0.0, 1 - ((2 * k / n) - 1) ** 2))) for k in range(n + 1)]
        i = i0
        col = self.sw(col)
        while i <= i1 + 1e-6:
            rib = ribs and (abs(((i - i0) / ribs) - round((i - i0) / ribs)) < 0.08)
            for k in range(n):
                (ja, za), (jb, zb) = prof[k], prof[k + 1]
                jm = (ja + jb) / 2
                f = 1.0 if jm > jc + R * 0.35 else (1.16 if jm > jc - R * 0.35 else 0.84)
                c = sh(col, f * (0.72 if rib else 1.0))
                self.poly([self.p(i, ja, za), self.p(i, jb, zb), self.p(i, jb, z0), self.p(i, ja, z0)], c)
            i += 0.02
        if end:
            pts = [self.p(i1, j, z) for j, z in prof]
            self.poly(pts, sh(end, 0.85))
            inner = [self.p(i1, jc + (j - jc) * 0.85, z0 + (z - z0) * 0.85) for j, z in prof]
            lit = self.state in ('normal', 'reformada', 'alquilada')
            self.poly(inner, '#F2D08A' if lit and glass else ('#9CC4C8' if glass else sh(end, 0.6)))
            for k in range(0, n + 1, 2):
                j, z = prof[k]
                self.line(self.p(i1, jc, z0), self.p(i1, jc + (j - jc) * 0.85, z0 + (z - z0) * 0.85), sh(end, 0.7))
            self.line(self.p(i1, jc - R * 0.85, z0 + rise * 0.3), self.p(i1, jc + R * 0.85, z0 + rise * 0.3), sh(end, 0.7))

    # ------------------------------------------------------------ azotea y calle
    def ac(self, i, j, z):
        self.box(i, j, 0.12, 0.1, z, 3, '#B8BCBC', rim=False, ao=False)
        x, y = self.p(i + 0.06, j + 0.1, z + 1)
        self.px(x, y, '#5A6060')

    def tank(self, i, j, z, col='#8A6A4A'):
        for (a, c) in [(i, j), (i + 0.12, j), (i, j + 0.12), (i + 0.12, j + 0.12)]:
            self.line(self.p(a, c, z), self.p(a, c, z + 4), '#3A3430')
        self.revolve(i + 0.06, j + 0.06, z + 4, 6, lambda t: 0.09 if t < 0.8 else 0.09 - (t - 0.8) * 0.4, col)

    def antenna(self, i, j, z, h=10, col='#9A9A9A'):
        x, y = self.p(i, j, z)
        self.line((x, y), (x, y - h), col)
        self.line((x - 3, y - h + 3), (x + 3, y - h + 3), col)
        self.px(x, y - h - 1, '#E2675B', raw=True)

    def solar(self, i0, j0, w, d, z, n=3):
        for k in range(n):
            a = i0 + k * w / n
            self.poly([self.p(a + 0.02, j0, z + 1), self.p(a + w / n - 0.02, j0, z + 1), self.p(a + w / n - 0.02, j0 + d, z + 3), self.p(a + 0.02, j0 + d, z + 3)], '#2B3F66')
            x, y = self.p(a + w / n / 2, j0 + d / 2, z + 2)
            self.px(x, y, '#5A7AB8')

    def chimney(self, i, j, z, h=6, col='#8A5A3A'):
        self.box(i, j, 0.1, 0.1, z, h, col, rim=False, ao=False)
        self.box(i - 0.015, j - 0.015, 0.13, 0.13, z + h, 1, sh(col, 0.8), rim=False, ao=False)

    def tree2(self, i, j, kind='round', col=None, h=12):
        x, y = self.p(i, j, 0)
        col = col or {'1888': '#5E6B38', '1929': '#55644A', '1980': '#4E5A36', '2005': '#5E9A50', '2020': '#3E7A52', '2050': '#4FA36B'}.get(self.era, '#4F7A3A')
        if self.state == 'ruina':
            col = mix(col, '#6A5A3A', 0.5)
        self.rect(x, y - 4, 1, 5, '#4A3222')
        if kind == 'round':
            self.dr.ellipse([x - 5, y - h - 2, x + 5, y - 3], fill=sh(col, 0.85) + (255,))
            self.dr.ellipse([x - 5, y - h - 2, x + 3, y - 5], fill=self.c(col) + (255,))
            self.dr.ellipse([x - 3, y - h - 1, x, y - h + 3], fill=sh(col, 1.25) + (255,))
        elif kind == 'cone':
            self.poly([(x, y - h - 4), (x - 4, y - 3), (x + 4, y - 3)], col)
            self.poly([(x, y - h - 4), (x, y - 3), (x + 4, y - 3)], sh(col, 0.75))
        elif kind == 'palm':
            self.rect(x, y - h, 1, h, '#8A6A44')
            for dx, dy in [(-4, 1), (4, 1), (-3, -1), (3, -1), (0, -2)]:
                self.line((x, y - h), (x + dx, y - h + dy + 2), col)

    def bush(self, i, j, col='#4F7A3A'):
        x, y = self.p(i, j, 0)
        self.dr.ellipse([x - 3, y - 4, x + 3, y], fill=self.c(col) + (255,))
        self.px(x - 1, y - 3, sh(col, 1.3))

    def lamp(self, i, j, col='#2A2622', light='#FFE28A'):
        x, y = self.p(i, j, 0)
        self.rect(x, y - 9, 1, 9, col)
        self.rect(x - 1, y - 11, 3, 2, light if self.state in ('normal', 'reformada', 'alquilada') else '#5A5040', raw=True)

    def car(self, i, j, col='#C8553D', axis='i'):
        if axis == 'i':
            self.box(i, j, 0.3, 0.14, 1, 3, col, rim=False, ao=False)
            self.box(i + 0.07, j + 0.01, 0.15, 0.12, 4, 2, '#9CC8E0', rim=False, ao=False)
        else:
            self.box(i, j, 0.14, 0.3, 1, 3, col, rim=False, ao=False)
            self.box(i + 0.01, j + 0.07, 0.12, 0.15, 4, 2, '#9CC8E0', rim=False, ao=False)

    def plaza(self, i0, j0, w, d, col='#B8AE98', tiles=True):
        self.poly([self.p(i0, j0, 0), self.p(i0 + w, j0, 0), self.p(i0 + w, j0 + d, 0), self.p(i0, j0 + d, 0)], col)
        if tiles:
            k = 0.25
            u = i0 + k
            while u < i0 + w - 0.01:
                self.line(self.p(u, j0, 0), self.p(u, j0 + d, 0), sh(col, 0.9))
                u += k
            v = j0 + k
            while v < j0 + d - 0.01:
                self.line(self.p(i0, v, 0), self.p(i0 + w, v, 0), sh(col, 0.9))
                v += k

    def clock(self, b, face, uc, zc, r=0.09, col='#ECE4D0'):
        pts = [(uc + r * math.cos(2 * math.pi * k / 12), zc + r * 16 * math.sin(2 * math.pi * k / 12)) for k in range(12)]
        self.fpoly(b, face, pts, '#2A2622')
        self.fpoly(b, face, [(uc + (u - uc) * 0.75, zc + (z - zc) * 0.75) for u, z in pts], col)
        x, y = self.fp(b, face, uc, zc)
        self.px(x, y, '#2A2622'); self.px(x, y - 1, '#2A2622')

    def statue(self, i, j, col='#7FA8A0', base='#B8AE98'):
        self.box(i - 0.06, j - 0.06, 0.12, 0.12, 0, 4, base, rim=False)
        x, y = self.p(i, j, 4)
        self.rect(x - 1, y - 7, 3, 7, col)
        self.px(x, y - 8, col)
        self.px(x + 2, y - 6, col)

    def fountain(self, i, j, r=0.25):
        self.revolve(i, j, 0, 2, lambda t: r, '#B8AE98', top=False)
        self.revolve(i, j, 2, 0.5, lambda t: r * 0.8, '#5AA6D6')
        self.revolve(i, j, 2, 5, lambda t: 0.05, '#B8AE98')
        x, y = self.p(i, j, 7)
        for dx in (-2, 0, 2):
            self.px(x + dx, y - 1, '#BCE0EC')
        self.px(x, y - 2, '#FFFFFF')

    def works(self, b):
        e = self.era
        if e == 'presente':
            self.era = '2020'
        super().works(b)
        self.era = e

    def flag(self, b, col=None):
        super().flag(b, col or '#4FC08D')

    # ------------------------------------------------------------ cierre
    def done(self, main):
        img = self.finish(main)
        bb = img.getbbox()
        ax, ay = self.ox, self.oy
        if bb:
            l, t, r, btm = bb
            l, t = max(0, l - 1), max(0, t - 1)
            img = img.crop((l, t, min(img.size[0], r + 1), min(img.size[1], btm + 1)))
            ax, ay = ax - l, ay - t
        return img, (ax, ay)
