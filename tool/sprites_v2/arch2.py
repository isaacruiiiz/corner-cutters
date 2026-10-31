"""Arquetipos v2 (más detalle). Ciudad actual ('presente') + épocas."""
from spr2 import Spr2
from spr import sh, mix

FH = 8
LIT = ('normal', 'reformada', 'alquilada')


def stained(s):
    return '#E3A93B' if s.state in LIT and s.rnd.random() < 0.5 else ('#3E5FA8' if s.rnd.random() < 0.6 else '#B8432F')


def lancets(s, b, face, n, z, wh, wu=0.07, frame='#EDE3C8', margin=0.08):
    L = s.flen(b, face)
    step = (L - 2 * margin) / n
    for k in range(n):
        u = margin + k * step + (step - wu) / 2
        g = stained(s) if s.state != 'ruina' else '#141110'
        s.win(b, face, u, z, wu, wh, 'gothic', frame=frame, glass=g, lit=g, sill=False)


def gtower(s, i0, j0, w, h, stone, spire_h, spire_col, levels=4, cross='#E3A93B', belfry='#1E1A18'):
    """torre gótica: etapas, contrafuertes en esquinas, campanario, antepecho con pináculos y aguja"""
    t = s.box(i0, j0, w, w, 0, h, stone)
    s.texture(t, 'L', 'stone'); s.texture(t, 'R', 'stone')
    lh = h / levels
    for k in range(1, levels):
        s.course(t, k * lh, sh(stone, 0.78))
    for f in 'LR':
        for k in range(levels - 1):
            z = k * lh + 4
            n = 1 if k == 0 else 2
            for m in range(n):
                u = w / 2 - 0.04 if n == 1 else w * (0.28 + 0.38 * m) - 0.035
                g = (stained(s) if s.rnd.random() < 0.35 else '#2A2A30') if s.state != 'ruina' else '#141110'
                s.win(t, f, u, z, 0.07 if n == 2 else 0.08, lh - 8, 'gothic', frame=sh(stone, 1.12), glass=g, lit=g, sill=False)
        # campanario
        z = (levels - 1) * lh + 3
        for m in range(2):
            u = w * (0.25 + 0.38 * m) - 0.04
            s.win(t, f, u, z, 0.09, lh - 6, 'gothic', frame=sh(stone, 1.12), glass=belfry, lit=belfry, sill=False)
            s.fline(t, f, u, z + 3, u + 0.09, z + 3, sh(stone, 0.6))
    # contrafuertes en las esquinas frontales
    for (a, c, ww, dd) in [(i0 - 0.04, j0 + w - 0.06, 0.1, 0.1), (i0 + w - 0.06, j0 + w - 0.06, 0.1, 0.1), (i0 + w - 0.06, j0 - 0.04, 0.1, 0.1)]:
        s.box(a, c, ww, dd, 0, h * 0.82, sh(stone, 0.95))
        s.spire(a + ww / 2, c + dd / 2, 0.05, h * 0.82, 6, sh(stone, 0.95), octo=False)
    s.cornice(t, sh(stone, 1.05), 0.03, 2)
    s.crenels(dict(t, h=h + 2), sh(stone, 1.05), 0.09)
    s.pinnacles([(i0 + 0.02, j0 + w - 0.02), (i0 + w - 0.02, j0 + w - 0.02), (i0 + w - 0.02, j0 + 0.02), (i0 + 0.02, j0 + 0.02)], h + 2, 9, sh(stone, 1.05))
    ci, cj = i0 + w / 2, j0 + w / 2
    s.spire(ci, cj, w * 0.36, h + 2, spire_h, spire_col, cross=cross)
    # crochets en la arista
    for k in range(1, 6):
        x, y = s.p(ci + w * 0.36 * (1 - k / 6), cj + w * 0.36 * (1 - k / 6), h + 2 + spire_h * k / 6)
        s.px(x + 1, y, sh(spire_col, 1.35))
    # lucarna en la aguja
    x, y = s.p(ci + w * 0.2, cj + w * 0.2, h + 2 + spire_h * 0.25)
    s.rect(x - 1, y - 3, 2, 3, '#1E1A18')
    return t


# ================================================================== CIUDAD ACTUAL
def catedral(s):
    stone, roof, cu = '#D0BC94', '#454A5E', '#6FA890'
    s.plaza(0, 0, 2, 2, '#A89E88')
    s.plaza(0.05, 0.05, 1.9, 1.9, '#B8AE98')
    # ábside (detrás)
    s.revolve(0.36, 1.0, 0, 30, lambda t: 0.3, stone, top=False)
    s.revolve(0.36, 1.0, 30, 14, lambda t: 0.32 * (1 - t), roof)
    # torre trasera
    gtower(s, 1.42, 0.22, 0.42, 66, stone, 40, sh(stone, 0.92))
    # brazo trasero del crucero
    tb = s.box(0.72, 0.32, 0.32, 0.4, 0, 36, stone)
    # nave
    n = s.box(0.3, 0.62, 1.15, 0.76, 0, 38, stone)
    s.texture(n, 'L', 'stone')
    lancets(s, n, 'L', 5, 24, 11, 0.07)
    s.gable(0.3, 0.62, 1.15, 0.76, 38, 20, roof, stone, axis='i')
    # crestería del caballete
    for k in range(10):
        x, y = s.p(0.32 + k * 0.12, 1.0, 58)
        s.px(x, y - 1, '#2A2E3A')
    # crucero (brazo delantero, hastial con rosetón)
    tr = s.box(0.72, 1.38, 0.32, 0.36, 0, 40, stone)
    s.texture(tr, 'L', 'stone')
    s.gable(0.72, 0.32, 0.32, 1.42, 40, 16, roof, stone, axis='j')
    s.rose(tr, 'L', 0.16, 29, 0.12)
    lancets(s, tr, 'L', 2, 6, 14, 0.07, margin=0.05)
    # flecha del crucero (cobre)
    s.box(0.82, 0.92, 0.14, 0.14, 50, 10, cu)
    s.pinnacles([(0.82, 1.06), (0.96, 1.06), (0.96, 0.92)], 60, 4, cu)
    s.spire(0.89, 0.99, 0.07, 60, 34, cu, cross='#E3A93B')
    # nave lateral delantera con arbotantes, a ambos lados del crucero
    for (a, c) in [(0.32, 0.4), (1.04, 0.38)]:
        ai = s.box(a, 1.38, c, 0.3, 0, 20, stone)
        s.texture(ai, 'L', 'stone')
        lancets(s, ai, 'L', 2, 4, 12, 0.07, margin=0.06)
        s.poly([s.p(a, 1.38, 26), s.p(a + c, 1.38, 26), s.p(a + c, 1.68, 20), s.p(a, 1.68, 20)], roof)
        for k in range(2):
            pi = a + 0.04 + k * (c - 0.1)
            s.box(pi, 1.66, 0.06, 0.08, 0, 30, sh(stone, 0.96))
            s.spire(pi + 0.03, 1.7, 0.04, 30, 7, sh(stone, 0.96), octo=False)
            s.line(s.p(pi + 0.03, 1.66, 28), s.p(pi + 0.03, 1.38, 35), sh(stone, 0.8))
            s.line(s.p(pi + 0.03, 1.66, 27), s.p(pi + 0.03, 1.38, 34), sh(stone, 1.1))
    # fachada principal (cara derecha)
    f = s.box(1.45, 0.66, 0.4, 0.68, 0, 50, stone)
    s.texture(f, 'R', 'stone')
    s.gable(1.45, 0.66, 0.4, 0.68, 50, 18, roof, stone, axis='i')
    # hastial calado + pináculos
    s.pinnacles([(1.85, 0.66), (1.85, 1.34), (1.85, 1.0)], 50, 8, stone)
    s.rose(f, 'R', 0.34, 37, 0.17)
    # galería de reyes
    for k in range(9):
        u = 0.06 + k * 0.064
        s.win(f, 'R', u, 22, 0.035, 5, 'gothic', frame=sh(stone, 1.1), glass='#3A3230', lit='#3A3230', sill=False)
    s.course(f, 21, sh(stone, 0.75), 'R'); s.course(f, 28, sh(stone, 0.75), 'R')
    # tres portadas abocinadas
    for (u, wu, hh) in [(0.05, 0.14, 14), (0.25, 0.18, 18), (0.49, 0.14, 14)]:
        s.fpoly(f, 'R', [(u - 0.03, 0), (u + wu + 0.03, 0), (u + wu + 0.03, hh * 0.65), (u + wu / 2, hh + 3), (u - 0.03, hh * 0.65)], sh(stone, 1.12))
        s.fpoly(f, 'R', [(u, 0), (u + wu, 0), (u + wu, hh * 0.6), (u + wu / 2, hh), (u, hh * 0.6)], '#3A2A20')
        s.fline(f, 'R', u + wu / 2, 0, u + wu / 2, hh * 0.55, '#C8A060')
    # torre delantera
    gtower(s, 1.42, 1.34, 0.42, 66, stone, 40, sh(stone, 0.92))
    # plaza: farolas y árboles
    s.lamp(1.95, 0.4); s.lamp(1.95, 1.6)
    s.tree2(0.15, 1.88, 'cone', h=10); s.tree2(0.55, 1.92, 'cone', h=9)
    return n


# ================================================================== kit genérico
def block(s, i0, j0, w, d, fl, wall, win='sash', tex=None, shops=None, roof='flat', roofc='#6A5A4A',
          per=None, wu=0.12, wh=5, frame='#ECE4D0', glass=None, lit=None, fh=FH, z0=0, cornice=None,
          clutter=(), plinth=None, gf=None, courses=None, extra_h=2):
    h = fl * fh + extra_h
    b = s.box(i0, j0, w, d, z0, h, wall)
    if tex:
        s.texture(b, 'L', tex); s.texture(b, 'R', tex)
    if plinth:
        s.plinth(b, fh if gf is None else gf, plinth)
    if courses:
        for f in range(1, fl):
            s.course(b, z0 + f * fh, courses)
    pl = per or (max(1, round(w / 0.27)), max(1, round(d / 0.27)))
    skip = (0,) if shops else ()
    for face, n in zip('LR', pl):
        s.grid(b, face, fl, n, z0, fh, wu, wh, win, skip=skip, frame=frame, glass=glass, lit=lit)
    if shops:
        for face in 'LR':
            L = s.flen(b, face)
            k = max(1, round(L / 0.45))
            for m in range(k):
                u = m * L / k + 0.04
                s.shopfront(b, face, u, L / k - 0.08, fh - 1, awn=shops[m % len(shops)] if shops and shops[0] else None)
    top = z0 + h
    if cornice:
        s.cornice(b, cornice, 0.04, 2)
        top += 2
    if roof == 'gable':
        s.gable(i0, j0, w, d, top, 7 + 4 * min(w, d), roofc, wall, axis='i' if w >= d else 'j')
    elif roof == 'gablej':
        s.gable(i0, j0, w, d, top, 7 + 4 * min(w, d), roofc, wall, axis='j')
    elif roof == 'hip':
        s.hip(i0, j0, w, d, top, 6 + 6 * min(w, d), roofc)
    elif roof == 'mansard':
        m = s.box(i0 + 0.05, j0 + 0.05, w - 0.1, d - 0.1, top, 7, roofc)
        for face in 'LR':
            L = s.flen(m, face)
            n = max(1, round(L / 0.3))
            for k in range(n):
                u = (k + 0.5) * L / n - 0.05
                s.win(m, face, u, top + 1, 0.1, 4, 'sash', frame='#ECE4D0', glass=glass, lit=lit, sill=False)
        s.cornice(m, sh(roofc, 0.8), 0.0, 1)
    elif roof == 'green':
        g = s.box(i0 + 0.04, j0 + 0.04, w - 0.08, d - 0.08, top, 1, '#4F8A4A', top='#5FA35A')
        for k in range(int(4 * w * d) + 2):
            s.bush(i0 + 0.1 + s.rnd.random() * (w - 0.2), j0 + 0.1 + s.rnd.random() * (d - 0.2) , '#4FA36B')
    elif roof == 'flat':
        s.parapet(dict(b, h=h + (2 if cornice else 0)), sh(wall, 0.9), 2)
    for c in clutter:
        kind = c[0]
        if kind == 'ac':
            s.ac(c[1], c[2], top + 1)
        elif kind == 'tank':
            s.tank(c[1], c[2], top + 1)
        elif kind == 'ant':
            s.antenna(c[1], c[2], top + 1, c[3] if len(c) > 3 else 10)
        elif kind == 'solar':
            s.solar(c[1], c[2], c[3], c[4], top + 1)
        elif kind == 'chim':
            s.chimney(c[1], c[2], top + 1 if roof == 'flat' else top, 9)
    b['top'] = top
    return b


# ================================================================== CIUDAD ACTUAL · mejoras
def ayuntamiento(s):
    stone, slate = '#E2D6BC', '#4E5468'
    s.plaza(0, 0, 2, 2, '#A89E88'); s.plaza(0.05, 0.05, 1.9, 1.9, '#BCB29C')
    # torre del reloj (detrás del pabellón)
    t = s.box(0.82, 0.55, 0.36, 0.36, 0, 62, stone)
    s.texture(t, 'L', 'courses'); s.texture(t, 'R', 'courses')
    s.clock(t, 'L', 0.18, 52, 0.11); s.clock(t, 'R', 0.18, 52, 0.11)
    s.cornice(t, sh(stone, 1.05), 0.03, 2)
    s.box(0.87, 0.6, 0.26, 0.26, 64, 8, stone)
    for f in 'LR':
        b8 = dict(t, i0=0.87, j0=0.6, w=0.26, d=0.26, z0=64, h=8)
        s.win(b8, f, 0.08, 65, 0.1, 6, 'arch', frame='#ECE4D0', glass='#2A2622', lit='#2A2622', sill=False)
    s.revolve(1.0, 0.73, 72, 12, lambda t_: 0.17 * (1 - t_ ** 2) ** 0.5 + 0.01, '#5E9A86', ribs=8)
    s.revolve(1.0, 0.73, 83, 6, lambda t_: 0.04, '#E8DCC0')
    x, y = s.p(1.0, 0.73, 89); s.rect(x, y - 12, 1, 12, '#ECE4D0', raw=True); s.rect(x + 1, y - 12, 7, 4, '#C8553D', raw=True); s.rect(x + 1, y - 10, 7, 1, '#E3A93B', raw=True)
    # alas
    for (a, c) in [(0.15, 0.6), (1.25, 0.6)]:
        wb = block(s, a, 0.3, c, 1.15, 3, stone, win='sash', plinth=sh(stone, 0.85), gf=FH, courses=sh(stone, 0.86), cornice='#F0E6CE', roof='mansard', roofc=slate, glass='#2E3A44', lit='#F2D08A', frame='#F4EEDC')
        s.texture(wb, 'L', 'courses', z0=0, z1=FH)
    # pabellón central con pórtico y frontón
    pv = s.box(0.75, 0.3, 0.5, 1.32, 0, 30, stone)
    s.plinth(pv, FH, sh(stone, 0.85))
    s.grid(pv, 'R', 3, 3, 0, FH, 0.1, 5, 'arch', frame='#F4EEDC', glass='#2E3A44', lit='#F2D08A')
    # pórtico: sombra, columnas, entablamento y frontón
    s.fq(pv, 'L', 0.02, 2, 0.46, 24, '#5A4C40')
    for k in range(4):
        s.win(pv, 'L', 0.075 + k * 0.105, 3, 0.05, 8, 'arch', frame=None, glass='#2A2018', lit='#2A2018', sill=False)
        s.win(pv, 'L', 0.075 + k * 0.105, 15, 0.05, 7, 'sash', frame=None, glass='#2E3A44', lit='#F2D08A', sill=False)
    for k in range(5):
        u = 0.03 + k * 0.105
        s.fq(pv, 'L', u, 2, 0.04, 24, '#F6F0E0')
        s.fline(pv, 'L', u + 0.04, 2, u + 0.04, 26, '#B8AC94')
        s.fq(pv, 'L', u - 0.01, 25, 0.06, 1, '#FFFFFF')
    s.fq(pv, 'L', 0, 0, 0.5, 2, sh(stone, 0.8))
    s.fq(pv, 'L', 0.0, 26, 0.5, 4, '#F0E6CE')
    s.balcony(pv, 'L', 0.02, 14, 0.46)
    s.cornice(pv, '#F0E6CE', 0.04, 2)
    s.hip(0.71, 0.26, 0.58, 1.4, 32, 8, slate)
    s.fpoly(pv, 'L', [(-0.04, 32), (0.54, 32), (0.25, 41)], '#F0E6CE')
    s.fpoly(pv, 'L', [(0.04, 33), (0.46, 33), (0.25, 39)], '#D8CCB0')
    x, y = s.fp(pv, 'L', 0.25, 35); s.rect(x - 2, y - 1, 5, 3, '#C8A050')
    # banderas en el balcón
    for k, cols in enumerate([('#C8553D', '#E3A93B'), ('#3E5FA8', '#ECE4D0'), ('#4FC08D', '#ECE4D0')]):
        x, y = s.fp(pv, 'L', 0.12 + k * 0.13, 20)
        s.line((x, y), (x + 4, y - 6), '#2A2622')
        s.rect(x + 3, y - 9, 4, 2, cols[0], raw=True); s.rect(x + 3, y - 7, 4, 1, cols[1], raw=True)
    # escalinata y farolas
    s.box(0.72, 1.62, 0.56, 0.12, 0, 2, sh(stone, 0.9), ao=False)
    s.box(0.76, 1.74, 0.48, 0.1, 0, 1, sh(stone, 0.85), ao=False)
    s.lamp(0.55, 1.88); s.lamp(1.45, 1.88)
    s.bush(0.25, 1.75); s.bush(1.75, 1.75); s.bush(1.85, 1.2)
    return pv


def mercado(s):
    brick, iron, glass = '#A85A3C', '#3E5E52', '#9CC4C8'
    s.plaza(0, 0, 2, 1, '#A89E88')
    b = s.box(0.08, 0.12, 1.84, 0.76, 0, 18, brick)
    s.texture(b, 'L', 'brick'); s.texture(b, 'R', 'brick')
    s.plinth(b, 3, '#C8B89A')
    for face, n in (('L', 6), ('R', 2)):
        L = s.flen(b, face)
        for k in range(n):
            u = k * L / n + L / n * 0.2
            s.win(b, face, u, 4, L / n * 0.6, 12, 'arch', frame='#E8DCC0', glass='#3A4A48', lit='#F2D08A', sill=False)
    s.course(b, 17, '#E8DCC0')
    s.barrel(0.08, 1.92, 0.5, 0.38, 18, glass, end=iron, ribs=0.12, rise=13)
    s.box(0.5, 0.44, 1.0, 0.12, 30, 3, iron)
    s.barrel(0.5, 1.5, 0.5, 0.08, 33, glass, ribs=0.1, rise=3)
    # puestos fuera
    for k in range(4):
        i = 0.2 + k * 0.42
        s.awning(dict(i0=i, j0=0.75, w=0.3, d=0.12, z0=0, h=8, wall=brick), 'L', 0, 7, 0.3, (('#C8553D', '#ECE4D0'), ('#4FC08D', '#ECE4D0'), ('#E3A93B', '#ECE4D0'), ('#5AA6D6', '#ECE4D0'))[k], 0.1, 2)
        for m in range(5):
            x, y = s.p(i + 0.05 + m * 0.05, 0.95, 2)
            s.px(x, y, s.rnd.choice(['#E2675B', '#F2C25F', '#7FB848', '#E8892E']), raw=True)
    s.sign(b, 'R', 0.2, 13, 0.36, 3, '#2A2622', '#F2C25F')
    return b


def estadio(s):
    import math as _m
    s.plaza(0, 0, 2, 2, '#8E9A8C')
    ci, cj, R = 1.0, 1.0, 0.97
    # torres de focos
    for (i, j) in [(0.12, 0.12), (1.88, 0.12), (0.12, 1.88)]:
        x, y = s.p(i, j, 0)
        s.line((x, y), (x, y - 46), '#9A9A9A')
        s.rect(x - 3, y - 50, 7, 4, '#ECE4D0')
        if s.state in LIT:
            s.rect(x - 2, y - 49, 5, 2, '#FFF4C8', raw=True)
    s.revolve(ci, cj, 0, 22, lambda t: R, '#D8D4CC', ribs=34, top=True, bands=[(0.0, 0.12, '#9A968E'), (0.4, 0.5, '#C8553D')])
    # cuenco: gradas + césped
    import numpy as np
    from PIL import Image, ImageDraw
    arr = np.array(s.img)
    cx, cy = s.p(ci, cj, 0)
    zt, zf = 22, 12
    ax, ay = 0.86 * 28.28, 0.86 * 14.14
    fx, fy = 0.68 * 28.28, 0.66 * 14.14
    seats = [s.c(c) for c in ('#3E5FA8', '#4A6AB8', '#C8553D', '#E3A93B')]
    for y in range(arr.shape[0]):
        for x in range(arr.shape[1]):
            dx, dy = (x + .5 - cx) / ax, (y + .5 - (cy - zt)) / ay
            if dx * dx + dy * dy <= 1:
                ex, ey = (x + .5 - cx) / fx, (y + .5 - (cy - zf)) / fy
                if ex * ex + ey * ey <= 1:
                    stripe = int((x - cx + 2 * (y - cy)) / 5) % 2
                    c = s.c('#5FA84E' if stripe else '#4F9842')
                    if abs(ex) < 0.03 or abs(ex * ex + ey * ey - 0.08) < 0.03:
                        c = (236, 236, 226)
                else:
                    row = int((y - (cy - zt) + ay) / 2)
                    c = seats[(row + (1 if x % 7 == 0 else 0)) % 2] if dy < 0.2 else s.c('#2A3A6A')
                    if (x * 7 + y * 3) % 11 == 0 and s.state in LIT:
                        c = s.c('#ECE4D0')
                arr[y, x, :3] = c
                arr[y, x, 3] = 255
    s.img = Image.fromarray(arr); s.dr = ImageDraw.Draw(s.img)
    # marquesina: anillo superior
    for k in range(60):
        a_ = 2 * _m.pi * k / 60
        for rr in (0.97, 0.93, 0.89):
            i, j = ci + rr * _m.cos(a_), cj + rr * _m.sin(a_)
            x, y = s.p(i, j, 23)
            s.px(x, y, '#F4F2EC' if rr > 0.9 else '#B8B4AC')
    return dict(i0=0.1, j0=0.1, w=1.8, d=1.8, z0=0, h=18, wall='#D8D4CC')


def faro(s):
    s.ground('#6A6A62')
    for k in range(7):
        x, y = s.p(0.15 + s.rnd.random() * 0.7, 0.6 + s.rnd.random() * 0.35, 0)
        s.dr.ellipse([x - 3, y - 3, x + 3, y + 1], fill=s.c(s.rnd.choice(['#7A7A72', '#8A8A80', '#5E5E58'])) + (255,))
    # casa del farero
    hb = s.box(0.08, 0.5, 0.42, 0.42, 0, 10, '#ECE6D8')
    s.win(hb, 'L', 0.12, 3, 0.1, 4); s.win(hb, 'R', 0.2, 3, 0.1, 4)
    s.gable(0.08, 0.5, 0.42, 0.42, 10, 6, '#B8503A', '#ECE6D8', axis='i')
    rf = lambda t: 0.21 - 0.07 * t
    s.revolve(0.62, 0.38, 0, 70, rf, '#F2EEE6', bands=[(0.0, 0.08, '#8A8A80'), (0.2, 0.34, '#C8402E'), (0.5, 0.64, '#C8402E'), (0.8, 0.94, '#C8402E')], ribs=0)
    for z in (20, 40, 58):
        b = dict(i0=0.45, j0=0.21, w=0.34, d=0.34, z0=0, h=80, wall='#F2EEE6')
        x, y = s.p(0.62 + 0.12, 0.38 + 0.12, z)
        s.rect(x - 1, y - 2, 2, 3, '#2A3A40')
    s.revolve(0.62, 0.38, 70, 2, lambda t: 0.22, '#2A2622')
    x0, y0 = s.p(0.62, 0.38, 72)
    for dx in range(-6, 7, 3):
        s.line((x0 + dx, y0 + 2), (x0 + dx, y0 - 2), '#2A2622')
    lit = s.state in LIT
    s.revolve(0.62, 0.38, 72, 8, lambda t: 0.12, '#FFE28A' if lit else '#9CC4C8')
    s.revolve(0.62, 0.38, 80, 6, lambda t: 0.14 * (1 - t), '#C8402E')
    x, y = s.p(0.62, 0.38, 86); s.rect(x, y - 3, 1, 3, '#2A2622')
    if False:
        ov_pts = [(x0 + 1, y0 - 12), (x0 + 30, y0 - 22), (x0 + 30, y0 - 4)]
        from PIL import Image, ImageDraw
        ov = Image.new('RGBA', s.img.size, (0, 0, 0, 0)); ImageDraw.Draw(ov).polygon(ov_pts, fill=(255, 236, 160, 70)); s.img.alpha_composite(ov); s.dr = ImageDraw.Draw(s.img)
    return dict(i0=0.45, j0=0.21, w=0.34, d=0.34, z0=0, h=70, wall='#F2EEE6')


def torre_tv(s):
    s.ground('#8E9A8C')
    s.box(0.25, 0.25, 0.5, 0.5, 0, 5, '#B8B4AC')
    s.revolve(0.5, 0.5, 5, 70, lambda t: 0.1 - 0.04 * t, '#D8D4CC', ribs=6)
    s.revolve(0.5, 0.5, 72, 4, lambda t: 0.08 + 0.18 * t, '#B8B4AC')
    s.revolve(0.5, 0.5, 76, 6, lambda t: 0.26, '#3E5E74', bands=[(0.3, 0.7, '#9CC8E0')])
    s.revolve(0.5, 0.5, 82, 4, lambda t: 0.26 - 0.16 * t, '#ECE8E0')
    s.revolve(0.5, 0.5, 86, 6, lambda t: 0.06, '#C8402E', bands=[(0.5, 1, '#F2EEE6')])
    x, y = s.p(0.5, 0.5, 92)
    s.line((x, y), (x, y - 22), '#C8C8C0')
    for k in range(0, 22, 5):
        s.px(x + 1, y - k, '#C8402E', raw=True)
    s.px(x, y - 23, '#FF6A5A', raw=True)
    lit = s.state in LIT
    for k in range(6):
        xx, yy = s.p(0.5 + 0.18, 0.5 + 0.18, 78)
        if lit:
            s.px(xx - 12 + k * 4, yy - 1, '#F2D08A', raw=True)
    return dict(i0=0.4, j0=0.4, w=0.2, d=0.2, z0=0, h=70, wall='#D8D4CC')


def iglesia(s):
    stone, roof = '#D8C4A0', '#A8553A'
    s.plaza(0, 0, 2, 1, '#A89E88')
    s.revolve(0.32, 0.5, 0, 18, lambda t: 0.24, stone, top=False)
    s.revolve(0.32, 0.5, 18, 8, lambda t: 0.26 * (1 - t), roof)
    n = s.box(0.35, 0.22, 1.15, 0.56, 0, 22, stone)
    s.texture(n, 'L', 'stone'); s.texture(n, 'R', 'stone')
    for k in range(4):
        s.box(0.42 + k * 0.28, 0.76, 0.05, 0.06, 0, 18, sh(stone, 0.95))
        s.win(n, 'L', 0.16 + k * 0.28, 8, 0.07, 9, 'arch', frame='#ECE4D0', glass=stained(s), lit=stained(s), sill=False)
    s.gable(0.35, 0.22, 1.15, 0.56, 22, 11, roof, stone, axis='i')
    for k in range(9):
        x, y = s.p(0.4 + k * 0.12, 0.5, 33)
        s.px(x, y, sh(roof, 0.7))
    # campanario
    t = s.box(1.5, 0.2, 0.38, 0.38, 0, 56, stone)
    s.texture(t, 'L', 'stone'); s.texture(t, 'R', 'stone')
    for z in (18, 34):
        s.course(t, z, sh(stone, 0.8))
    for f in 'LR':
        s.win(t, f, 0.14, 22, 0.08, 8, 'arch', frame='#ECE4D0', glass='#2A3A44', lit='#F2D08A')
        for m in range(2):
            s.win(t, f, 0.07 + m * 0.16, 40, 0.08, 10, 'arch', frame='#ECE4D0', glass='#1E1A18', lit='#1E1A18', sill=False)
    s.clock(t, 'L', 0.19, 31, 0.07)
    s.cornice(t, sh(stone, 1.05), 0.03, 2)
    s.hip(1.47, 0.17, 0.44, 0.44, 58, 14, roof)
    x, y = s.p(1.69, 0.39, 72); s.rect(x, y - 6, 1, 6, '#2A2622'); s.rect(x - 1, y - 5, 3, 1, '#2A2622')
    # fachada a la derecha con portada y óculo
    f = s.box(1.5, 0.58, 0.02, 0.2, 0, 1, stone)
    s.fpoly(n, 'R', [(0.18, 0), (0.38, 0), (0.38, 8), (0.28, 13), (0.18, 8)], '#ECE4D0')
    s.fpoly(n, 'R', [(0.21, 0), (0.35, 0), (0.35, 7), (0.28, 11), (0.21, 7)], '#3A2A20')
    s.rose(n, 'R', 0.28, 22, 0.07)
    s.lamp(1.95, 0.85); s.tree2(0.15, 0.9, 'cone', h=9)
    return n


# ================================================================== CIUDAD ACTUAL · nuevos
def estacion(s):
    stone = '#D8C8A8'
    s.plaza(0, 0, 2, 2, '#9A9488')
    # andenes y vías detrás
    for k in range(3):
        j = 0.12 + k * 0.22
        s.poly([s.p(0.05, j, 0), s.p(1.95, j, 0), s.p(1.95, j + 0.04, 0), s.p(0.05, j + 0.04, 0)], '#5A4A3E')
    s.barrel(0.15, 1.75, 0.42, 0.36, 12, '#9CC4C8', end='#4A5A5E', ribs=0.13, rise=18)
    # tren asomando
    for k in range(2):
        s.box(1.76 + k * 0.0, 0.3, 0.2, 0.12, 0, 7, '#C8553D' if k == 0 else '#ECE4D0')
    hall = s.box(0.15, 0.82, 1.6, 0.6, 0, 22, stone)
    s.texture(hall, 'L', 'courses'); s.texture(hall, 'R', 'courses')
    s.plinth(hall, 4, sh(stone, 0.82))
    for k in range(5):
        s.win(hall, 'L', 0.12 + k * 0.3, 5, 0.14, 13, 'arch', frame='#F4EEDC', glass='#2E3A44', lit='#F2D08A')
    s.win(hall, 'R', 0.22, 5, 0.16, 13, 'arch', frame='#F4EEDC', glass='#2E3A44', lit='#F2D08A')
    s.cornice(hall, '#F0E6CE', 0.04, 2, dentil=True)
    s.hip(0.15, 0.82, 1.6, 0.6, 24, 7, '#4E5468')
    # torre del reloj
    t = s.box(0.82, 1.3, 0.26, 0.26, 0, 44, stone)
    s.clock(t, 'L', 0.13, 36, 0.09); s.clock(t, 'R', 0.13, 36, 0.09)
    s.cornice(t, '#F0E6CE', 0.03, 2)
    s.hip(0.8, 1.28, 0.3, 0.3, 46, 10, '#4E5468')
    x, y = s.p(0.95, 1.43, 56); s.rect(x, y - 5, 1, 5, '#2A2622')
    # marquesina de entrada
    s.box(0.6, 1.42, 0.7, 0.18, 12, 1, '#2A3A40')
    for k in range(4):
        x, y = s.p(0.62 + k * 0.22, 1.6, 0); s.rect(x, y - 12, 1, 12, '#2A3A40')
    s.sign(hall, 'L', 0.55, 17, 0.5, 3, '#2A3A40', '#F2C25F')
    # taxis y farolas
    s.car(0.3, 1.72, '#F2C25F'); s.car(1.3, 1.75, '#ECE4D0')
    s.lamp(0.15, 1.9); s.lamp(1.85, 1.9)
    return hall


def hospital(s):
    s.plaza(0, 0, 2, 2, '#A8AEA8')
    b = block(s, 0.15, 0.15, 1.1, 1.1, 7, '#F0F0EC', win='strip', per=(5, 5), wu=0.16, wh=4, frame='#B8C8D0', glass='#5A7A8A', lit='#E8F0F0', courses='#C8D0D4')
    s.course(b, 4, '#4FA3A0')
    z = b['top']
    # helipuerto
    s.revolve(0.7, 0.7, z, 1, lambda t: 0.38, '#5A6468')
    x, y = s.p(0.7, 0.7, z + 1)
    s.rect(x - 3, y - 2, 1, 5, '#ECE4D0', raw=True); s.rect(x + 3, y - 2, 1, 5, '#ECE4D0', raw=True); s.rect(x - 2, y, 5, 1, '#ECE4D0', raw=True)
    # ala baja con urgencias
    w2 = block(s, 1.25, 0.6, 0.6, 1.25, 2, '#E8ECEC', win='strip', per=(3, 5), wu=0.14, wh=4, frame='#B8C8D0', glass='#5A7A8A', lit='#E8F0F0')
    s.box(1.3, 1.85, 0.5, 0.12, 9, 1, '#C8402E')
    s.sign(w2, 'L', 0.1, 10, 0.4, 3, '#C8402E', '#ECE4D0')
    # cruz roja en la torre
    x, y = s.fp(b, 'L', 0.55, 46)
    s.rect(x - 1, y - 4, 3, 9, '#E2402E', raw=True); s.rect(x - 4, y - 1, 9, 3, '#E2402E', raw=True)
    s.box(1.45, 1.86, 0.3, 0.12, 0, 4, '#ECE4D0')
    x, y = s.p(1.6, 1.98, 3); s.rect(x - 1, y - 2, 3, 1, '#E2402E', raw=True)
    s.tree2(0.2, 1.7); s.tree2(0.6, 1.8); s.bush(1.0, 1.85)
    return b


def colegio(s):
    s.plaza(0, 0, 2, 1, '#9AA090')
    # patio con pista
    s.poly([s.p(1.15, 0.1, 0), s.p(1.95, 0.1, 0), s.p(1.95, 0.9, 0), s.p(1.15, 0.9, 0)], '#C86A4A')
    s.line(s.p(1.55, 0.1, 0), s.p(1.55, 0.9, 0), '#ECE4D0')
    x, y = s.p(1.92, 0.5, 0); s.rect(x, y - 12, 1, 12, '#2A2622'); s.rect(x - 3, y - 14, 5, 3, '#ECE4D0'); s.rect(x - 2, y - 11, 3, 1, '#E3A93B')
    b = block(s, 0.1, 0.12, 1.0, 0.78, 3, '#B85A3C', win='sash', tex='brick', per=(4, 3), wu=0.1, wh=5, frame='#E8DCC0', glass='#3A4A54', lit='#F2D08A', courses='#E8DCC0', cornice='#E8DCC0', roof='flat')
    s.box(0.45, 0.82, 0.3, 0.12, 0, 9, '#E8DCC0')
    s.clock(b, 'L', 0.5, 21, 0.07)
    x, y = s.p(0.95, 0.85, b['top']); s.rect(x, y - 16, 1, 16, '#ECE4D0', raw=True); s.rect(x + 1, y - 16, 7, 4, '#3E5FA8', raw=True)
    s.tree2(1.2, 0.95, h=11)
    return b


def hotel(s):
    s.ground('#8E9A8C')
    b = block(s, 0.12, 0.12, 0.76, 0.76, 12, '#E8E0D0', win='balcony', per=(3, 3), wu=0.13, wh=5, frame='#ECE4D0', glass='#3E5A6A', lit='#F2D08A', shops=[None], fh=FH)
    s.box(0.2, 0.86, 0.6, 0.14, 8, 1, '#2A2622')
    s.sign(b, 'L', 0.18, 6, 0.4, 2, '#C8A050', '#2A2622')
    z = b['top']
    s.box(0.25, 0.25, 0.5, 0.2, z, 7, '#2A2622')
    s.sign(dict(i0=0.25, j0=0.25, w=0.5, d=0.2, z0=z, h=7, wall='#2A2622'), 'L', 0.03, z + 1, 0.44, 5, '#C8402E', '#FFE28A')
    s.ac(0.6, 0.6, z + 1); s.tank(0.2, 0.6, z + 1)
    return b


def museo(s):
    s.plaza(0, 0, 2, 2, '#C8C0B0')
    s.poly([s.p(1.3, 1.3, 0), s.p(1.9, 1.3, 0), s.p(1.9, 1.9, 0), s.p(1.3, 1.9, 0)], '#3A8AB0')
    a = s.box(0.15, 0.15, 1.0, 1.3, 0, 16, '#F2F0EA')
    s.texture(a, 'L', 'panels'); s.texture(a, 'R', 'panels')
    g = s.box(0.6, 1.0, 0.7, 0.3, 0, 14, '#7FB0CC', top='#BCE0EC', right='#5A8AA8')
    s.vstripes(g, 'L', 7, 0, 14, '#ECE4D0', 0.02)
    c = s.box(0.25, 0.55, 1.4, 0.6, 16, 12, '#ECE8E0')
    s.texture(c, 'L', 'panels'); s.texture(c, 'R', 'panels')
    s.fq(c, 'L', 0.1, 19, 1.2, 3, '#2E3A44'); s.fq(c, 'R', 0.05, 19, 0.5, 3, '#2E3A44')
    d = s.box(1.05, 0.2, 0.5, 0.5, 28, 10, '#C8553D')
    s.texture(d, 'L', 'metal'); s.texture(d, 'R', 'metal')
    s.statue(1.6, 1.6, '#E3A93B', '#ECE4D0')
    s.tree2(0.2, 1.8); s.tree2(0.6, 1.85)
    return c


def gasolinera(s):
    s.ground('#6E706A')
    sh_ = s.box(0.08, 0.1, 0.4, 0.4, 0, 10, '#ECE8E0')
    s.shopfront(sh_, 'L', 0.04, 0.32, 8); s.shopfront(sh_, 'R', 0.04, 0.32, 8, door=False)
    for (i, j) in [(0.55, 0.45), (0.85, 0.45), (0.55, 0.85), (0.85, 0.85)]:
        x, y = s.p(i, j, 0); s.rect(x, y - 14, 1, 14, '#ECE8E0')
    for (i, j) in [(0.6, 0.6), (0.82, 0.68)]:
        s.box(i, j, 0.06, 0.08, 0, 5, '#C8402E')
    s.box(0.48, 0.38, 0.5, 0.56, 14, 3, '#ECE8E0', top='#F4F2EC')
    s.fq(dict(i0=0.48, j0=0.38, w=0.5, d=0.56, z0=14, h=3, wall='#ECE8E0'), 'L', 0, 14, 0.5, 2, '#2E8A4A')
    s.fq(dict(i0=0.48, j0=0.38, w=0.5, d=0.56, z0=14, h=3, wall='#ECE8E0'), 'R', 0, 14, 0.56, 2, '#2E8A4A')
    x, y = s.p(0.15, 0.85, 0); s.rect(x, y - 20, 2, 20, '#5A5A5A'); s.rect(x - 4, y - 28, 10, 9, '#2E8A4A'); s.rect(x - 3, y - 25, 8, 1, '#F2C25F'); s.rect(x - 3, y - 23, 8, 1, '#ECE4D0')
    s.car(0.68, 0.7, '#5AA6D6', 'j')
    return sh_


def plaza_fuente(s):
    s.plaza(0, 0, 1, 1, '#C8BEA8')
    s.fountain(0.5, 0.5, 0.26)
    for (i, j) in [(0.12, 0.12), (0.88, 0.12), (0.12, 0.88)]:
        s.tree2(i, j, h=11)
    s.lamp(0.88, 0.88)
    for (i, j) in [(0.5, 0.92), (0.92, 0.5)]:
        x, y = s.p(i, j, 0); s.rect(x - 3, y - 3, 6, 1, '#7A5A3A'); s.rect(x - 3, y - 2, 1, 2, '#2A2622'); s.rect(x + 2, y - 2, 1, 2, '#2A2622')
    return dict(i0=0.25, j0=0.25, w=0.5, d=0.5, z0=0, h=6, wall='#C8BEA8')


def chaflan(s):
    s.ground('#8E9A8C')
    return chaflan_gen(s, 0.08, 0.08, 0.84, 0.84, 6, '#D8B48C', 0.28)


def chaflan_gen(s, i0, j0, w, d, fl, wall, c, roofc='#4E5468', awn=('#2E6B4A', '#ECE4D0'), dome=True, glass='#3E4A50', lit='#F2D08A', frame='#F4EEDC', tex='courses', style='balcony'):
    """finca de esquina con chaflán, tribuna y mansarda"""
    h = fl * FH + 2
    A = s.box(i0, j0, w - c, d, 0, h, wall)
    B = s.box(i0 + w - c, j0, c, d - c, 0, h, wall)
    # cara del chaflán
    pa, pb = (i0 + w - c, j0 + d), (i0 + w, j0 + d - c)
    s.poly([s.p(*pa, 0), s.p(*pb, 0), s.p(*pb, h), s.p(*pa, h)], sh(wall, 0.9))
    s.poly([s.p(i0, j0, h), s.p(i0 + w, j0, h), s.p(*pb, h), s.p(*pa, h), s.p(i0, j0 + d, h)], sh(wall, 1.18))
    for f, bb in (('L', A), ('R', B)):
        n = max(1, round(s.flen(bb, f) / 0.28))
        if tex:
            s.texture(bb, f, tex)
        s.grid(bb, f, fl, n, 0, FH, 0.12, 5, style, skip=(0,), frame=frame, glass=glass, lit=lit)
        s.shopfront(bb, f, 0.06, s.flen(bb, f) - 0.12, FH - 1, awn=awn)
    # tribuna acristalada en el chaflán
    for f in range(1, min(fl, 5)):
        z = f * FH + 1
        mid = ((pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2)
        q = [s.p(pa[0] + 0.03, pa[1] + 0.02, z), s.p(pb[0] + 0.02, pb[1] + 0.03, z), s.p(pb[0] + 0.02, pb[1] + 0.03, z + 6), s.p(pa[0] + 0.03, pa[1] + 0.02, z + 6)]
        s.poly(q, '#F4EEDC')
        q2 = [s.p(pa[0] + 0.07, pa[1] - 0.0, z + 1), s.p(pb[0] - 0.0, pb[1] + 0.07, z + 1), s.p(pb[0], pb[1] + 0.07, z + 5), s.p(pa[0] + 0.07, pa[1], z + 5)]
        s.poly(q2, lit if s.state in LIT and s.rnd.random() < 0.6 else glass)
    s.poly([s.p(i0 - 0.03, j0 + d + 0.03, h), s.p(*pa, h), s.p(*pb, h), s.p(i0 + w + 0.03, j0 - 0.03, h), s.p(i0 + w + 0.03, j0 - 0.03, h + 2), s.p(*pb, h + 2), s.p(*pa, h + 2), s.p(i0 - 0.03, j0 + d + 0.03, h + 2)], '#F0E6CE')
    # mansarda y cúpula en la esquina
    if roofc:
        s.hip(i0 + 0.06, j0 + 0.06, w - 0.12, d - 0.12, h + 2, 8, roofc)
    if dome:
        s.revolve(i0 + w - 0.16, j0 + d - 0.16, h + 2, 10, lambda t: 0.12 * (1 - t ** 1.6) + 0.01, roofc or '#4E5468', ribs=6)
        x, y = s.p(i0 + w - 0.16, j0 + d - 0.16, h + 12); s.rect(x, y - 4, 1, 4, '#C8A050')
    A['top'] = h + 2
    return A


# ================================================================== CIUDAD ACTUAL · edificios comunes
WP = dict(glass='#2E3A44', lit='#F2D08A', frame='#F4EEDC')


def casa(s):
    s.plaza(0.05, 0.05, 0.9, 0.9, '#7A8A6A', tiles=False)
    b = block(s, 0.15, 0.12, 0.62, 0.6, 2, '#E8D2B0', win='shutter', per=(2, 1), wu=0.13, wh=5, plinth='#B89A78', gf=3, roof='gable', roofc='#B8503A', **WP)
    s.fq(b, 'L', 0.26, 0, 0.12, 7, '#6A4A32')
    s.chimney(0.55, 0.3, b['top'] + 5, 6)
    for k in range(2):
        x, y = s.fp(b, 'L', 0.12 + k * 0.32, FH + 2); s.rect(x, y, 3, 1, '#C8553D'); s.px(x + 1, y - 1, '#4F7A3A')
    for k in range(6):
        x, y = s.p(0.12 + k * 0.14, 0.92, 0); s.rect(x, y - 3, 1, 3, '#ECE4D0')
    s.bush(0.85, 0.85); s.tree2(0.88, 0.25, h=10)
    return b


def bloque(s):
    s.plaza(0.04, 0.04, 0.92, 0.92, '#8E9A8C', tiles=False)
    b = block(s, 0.1, 0.1, 0.8, 0.8, 6, '#E2CDA8', win='balcony', per=(3, 3), wu=0.12, wh=5, shops=[('#3E6B5A', '#ECE4D0'), ('#C8553D', '#ECE4D0')], courses='#C8B490', **WP)
    s.tank(0.2, 0.2, b['top'] + 2, '#8A8A84'); s.ac(0.6, 0.3, b['top'] + 2); s.antenna(0.7, 0.65, b['top'] + 2, 9)
    for f in (2, 4):
        x, y = s.fp(b, 'R', 0.6, f * FH + 3); s.ac(0.9, 0.3, f * FH + 1) if False else s.rect(x, y - 2, 3, 2, '#B8BCBC')
    return b


def ensanche(s):
    s.plaza(0.04, 0.04, 0.92, 0.92, '#8E9A8C', tiles=False)
    b = block(s, 0.1, 0.1, 0.8, 0.8, 6, '#D8C29A', win='balcony', tex='courses', per=(3, 3), wu=0.11, wh=6, shops=[('#2E5A4A', '#ECE4D0')], cornice='#F0E2C0', roof='mansard', roofc='#4E5468', **WP)
    s.pilasters(b, 'L', 3, '#E8D8B4', 0.03, FH, b['h']); s.pilasters(b, 'R', 3, '#E8D8B4', 0.03, FH, b['h'])
    s.chimney(0.3, 0.3, b['top'] + 7, 5); s.chimney(0.65, 0.3, b['top'] + 7, 5)
    return b


def modernista(s):
    import math as _m
    s.plaza(0.04, 0.04, 0.92, 0.92, '#8E9A8C', tiles=False)
    b = block(s, 0.1, 0.1, 0.8, 0.8, 7, '#E8DCC0', win='arch', per=(3, 3), wu=0.12, wh=6, shops=[None], **WP)
    # balcones ondulados de forja
    for f in range(1, 7):
        for face in 'LR':
            for k in range(3):
                u = 0.06 + k * 0.27
                for m in range(8):
                    x, y = s.fp(b, face, u + m * 0.024, f * FH + 2 + _m.sin(m * 0.8) * 1.2)
                    s.px(x, y, '#3E5A52')
    # cubierta ondulada con trencadís
    top = b['h']
    for k in range(5):
        for face, (i, j) in (('L', (0.14 + k * 0.16, 0.9)), ('R', (0.9, 0.14 + k * 0.16))):
            s.revolve(i, j, top, 6, lambda t: 0.08 * (1 - t ** 2) ** 0.5 + 0.01, ['#5AA6D6', '#4FA36B', '#E3A93B', '#C8553D', '#ECE4D0'][k], ribs=0)
    for (i, j, c) in [(0.3, 0.3, '#C8553D'), (0.6, 0.45, '#5AA6D6'), (0.4, 0.62, '#4FA36B')]:
        s.revolve(i, j, top, 10, lambda t: 0.05 + 0.03 * _m.sin(t * _m.pi), c, bands=[(0.0, 0.2, '#ECE4D0'), (0.5, 0.6, '#ECE4D0')])
    s.revolve(0.75, 0.75, top, 16, lambda t: 0.1 * (1 - t) + 0.01, '#C8A050', bands=[(0.2, 0.3, '#3E5A52'), (0.6, 0.7, '#3E5A52')])
    x, y = s.p(0.75, 0.75, top + 16); s.rect(x - 1, y - 3, 3, 1, '#C8A050'); s.rect(x, y - 4, 1, 3, '#C8A050')
    return b


# ================================================================== registro
PRESENTE = [
    ('catedral', 'Catedral', 2, 2, catedral, 'mejora'),
    ('ayuntamiento', 'Ayuntamiento', 2, 2, ayuntamiento, 'mejora'),
    ('mercado', 'Mercado', 2, 1, mercado, 'mejora'),
    ('estadio', 'Estadio', 2, 2, estadio, 'mejora'),
    ('faro', 'Faro', 1, 1, faro, 'mejora'),
    ('torre_tv', 'Torre de TV', 1, 1, torre_tv, 'mejora'),
    ('iglesia', 'Iglesia', 2, 1, iglesia, 'mejora'),
    ('casa', 'Casa', 1, 1, casa, 'mejora'),
    ('bloque', 'Bloque', 1, 1, bloque, 'mejora'),
    ('ensanche', 'Ensanche', 1, 1, ensanche, 'mejora'),
    ('modernista', 'Modernista', 1, 1, modernista, 'mejora'),
    ('estacion', 'Estación de tren', 2, 2, estacion, 'nuevo'),
    ('hospital', 'Hospital', 2, 2, hospital, 'nuevo'),
    ('museo', 'Museo', 2, 2, museo, 'nuevo'),
    ('colegio', 'Colegio', 2, 1, colegio, 'nuevo'),
    ('hotel', 'Hotel', 1, 1, hotel, 'nuevo'),
    ('chaflan', 'Finca en chaflán', 1, 1, chaflan, 'nuevo'),
    ('gasolinera', 'Gasolinera', 1, 1, gasolinera, 'nuevo'),
    ('plaza_fuente', 'Plaza con fuente', 1, 1, plaza_fuente, 'nuevo'),
]


def render2(fn, w, d, era='presente', state='normal', key='x', ground=True, swaps=None):
    s = Spr2(w, d, state=state, era=era, seed=sum(map(ord, era + key)) + 7, ground=ground)
    if swaps:
        s.swaps = {k.upper(): v for k, v in swaps.items()}
    b = fn(s)
    return s.done(b)
