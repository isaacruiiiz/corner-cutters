"""Arquetipos v2 por época: mejoras de los existentes + nuevos."""
import math
from spr import sh, mix
from arch2 import block, chaflan_gen, gtower, lancets, stained, FH, LIT

G = {'1888': '#4A3C2C', '1929': '#34372F', '1980': '#2E2626', '2005': '#3E5A48', '2020': '#1F3B38', '2050': '#1B2C33'}
COB = {'1888': '#6E5E48', '1929': '#5A5C54', '1980': '#5A5250', '2005': '#8A8E86', '2020': '#5E6E6A', '2050': '#4E626A'}


def gr(s, w=1, d=1, pave=True):
    s.ground(G[s.era], 0, 0, w, d)
    if pave:
        s.plaza(0.04, 0.04, w - 0.08, d - 0.08, COB[s.era], tiles=False)


# ================================================================== 1888
GAS = '#E8B860'
W88 = dict(glass='#3A2C1E', lit=GAS, frame='#F0E2C0')


def casa_cos(s):
    gr(s)
    b = block(s, 0.12, 0.12, 0.76, 0.76, 3, '#C9A36A', win='shutter', tex='stone', per=(2, 2), wu=0.13, wh=5, plinth='#8A7458', gf=4, roof='gable', roofc='#A8553A', **W88)
    s.win(b, 'L', 0.31, 2, 0.14, 7, 'arch', frame='#E8D8B0', glass='#5A3A22', lit='#5A3A22', sill=False)
    s.balcony(b, 'L', 0.1, FH * 1 + 1, 0.56)
    s.chimney(0.62, 0.3, b['top'] + 4, 7)
    for k in range(3):
        x, y = s.fp(b, 'L', 0.18 + k * 0.2, FH + 3)
        s.px(x, y - 1, '#C8402E', raw=True); s.px(x + 1, y - 2, '#4F7A3A', raw=True)
    s.lamp(0.92, 0.92, light=GAS)
    return b


def finca_ensanche(s):
    gr(s, 2, 2)
    b = chaflan_gen(s, 0.1, 0.1, 1.8, 1.8, 6, '#D8C29A', 0.5, roofc=None, awn=('#7A3A2A', '#E8D8B8'), glass='#3A2C1E', lit=GAS, frame='#F0E2C0', tex='stone')
    s.parapet(dict(b, i0=0.1, j0=0.1, w=1.8, d=1.8, z0=0, h=b['top']), '#C8B08A', 2)
    s.box(0.2, 0.2, 1.2, 0.5, b['top'], 7, '#5A5048')
    for k in range(4):
        s.chimney(0.3 + k * 0.3, 0.75, b['top'], 6)
    s.tank(1.4, 0.3, b['top'] + 1, '#6A4A32')
    for k in range(3):
        s.lamp(1.95, 0.3 + k * 0.6, light=GAS)
    return b


def fabrica_vapor(s):
    gr(s, 2, 2)
    # depósito de agua
    s.tank(0.25, 0.25, 26, '#6A4A32')
    b = block(s, 0.12, 0.12, 1.7, 1.2, 2, '#9A4A32', win='arch', tex='brick', per=(6, 4), wu=0.14, wh=8, fh=11, frame='#C8A070', roof='gable', roofc='#5A4A44', plinth='#6E3424', gf=3, **{k: v for k, v in W88.items() if k != 'frame'})
    # nave anexa
    a = block(s, 0.6, 1.32, 1.2, 0.55, 1, '#8A4430', win='arch', tex='brick', per=(4, 2), wu=0.14, wh=7, fh=10, frame='#C8A070', roof='gable', roofc='#4A3E3A', glass='#3A2C1E', lit=GAS)
    s.fq(a, 'L', 0.15, 0, 0.22, 9, '#3A2A20')
    # chimenea con anillos
    s.revolve(1.85, 1.75, 0, 70, lambda t: 0.1 - 0.035 * t, '#8A3E2A', bands=[(0.0, 0.1, '#6E3020'), (0.45, 0.48, '#E8D8B8'), (0.94, 1, '#2A1E18')])
    if s.state != 'ruina':
        x, y = s.p(1.85, 1.75, 72)
        for k, col in enumerate(['#8F8578', '#7A7166', '#6A6258', '#5A544C']):
            s.dr.ellipse([x - 3 + k * 4, y - 6 - k * 6, x + 3 + k * 5, y - 1 - k * 6], fill=s.c(col) + (255,))
    # vagoneta
    s.box(0.2, 1.7, 0.2, 0.12, 1, 3, '#4A3E36'); x, y = s.p(0.25, 1.82, 2); s.px(x, y, '#2A2622')
    return b


def colmado(s):
    gr(s)
    b = block(s, 0.12, 0.12, 0.76, 0.76, 2, '#B8925E', win='shutter', tex='stone', per=(2, 2), wu=0.13, wh=5, roof='gable', roofc='#A8553A', **W88)
    s.fq(b, 'L', 0.0, 0, 0.76, FH, '#4A3222')
    s.shopfront(b, 'L', 0.06, 0.64, FH - 1, glass='#5A4A3A', frame='#3E2A1A', awn=('#C8553D', '#ECE0C8'))
    s.sign(b, 'L', 0.12, FH + 0.5, 0.52, 2, '#3E2A1A', '#E8B860')
    for k, col in enumerate(['#8A6440', '#7A5A38']):
        x, y = s.p(0.25 + k * 0.16, 0.98, 0)
        s.rect(x - 2, y - 4, 4, 4, col); s.rect(x - 2, y - 3, 4, 1, '#3A2A1A')
    x, y = s.p(0.7, 0.98, 0); s.rect(x - 2, y - 3, 5, 3, '#A07A4A'); s.px(x - 1, y - 4, '#7FB848', raw=True); s.px(x + 1, y - 4, '#E2675B', raw=True)
    return b


def mercado_hierro(s):
    gr(s, 2, 2)
    iron = '#3E5E52'
    b = s.box(0.15, 0.15, 1.7, 1.7, 0, 12, '#4E6E5A')
    for f in 'LR':
        L = s.flen(b, f)
        for k in range(7):
            s.win(b, f, 0.07 + k * L / 7, 2, L / 7 * 0.6, 9, 'arch', frame='#2E4A3A', glass='#9CC4C8', lit='#F2D08A', sill=False)
    s.cornice(b, iron, 0.03, 2)
    s.barrel(0.15, 1.85, 1.0, 0.85, 14, '#9CC4C8', end='#2E4A3A', ribs=0.14, rise=20)
    s.revolve(1.0, 1.0, 30, 10, lambda t: 0.22 * (1 - t ** 2) ** 0.5 + 0.02, '#7FA8A8', ribs=8)
    s.revolve(1.0, 1.0, 39, 4, lambda t: 0.04, iron)
    for k in range(4):
        x, y = s.p(0.3 + k * 0.42, 1.95, 0)
        s.rect(x - 2, y - 3, 4, 3, '#8A6440'); s.px(x - 1, y - 4, '#E2675B', raw=True); s.px(x + 1, y - 4, '#F2C25F', raw=True)
    s.lamp(1.95, 1.95, light=GAS)
    return b


def estacion_hierro(s):
    gr(s, 2, 2)
    stone = '#D8C29A'
    for k in range(3):
        j = 0.15 + k * 0.3
        s.poly([s.p(0.0, j, 0), s.p(2, j, 0), s.p(2, j + 0.05, 0), s.p(0, j + 0.05, 0)], '#3A2E24')
    s.barrel(0.1, 1.55, 0.55, 0.5, 14, '#9CB8B8', end='#3E4A44', ribs=0.12, rise=30)
    # locomotora
    s.box(1.58, 0.42, 0.34, 0.2, 0, 9, '#2A2622')
    s.revolve(1.85, 0.52, 9, 6, lambda t: 0.04, '#2A2622')
    s.box(1.6, 0.44, 0.1, 0.16, 9, 5, '#2A2622')
    x, y = s.p(1.85, 0.52, 16); s.dr.ellipse([x - 2, y - 7, x + 4, y - 2], fill=s.c('#C8C0B0') + (255,))
    # edificio de viajeros
    h = s.box(0.1, 1.1, 1.8, 0.7, 0, 24, stone)
    s.texture(h, 'L', 'stone'); s.texture(h, 'R', 'stone')
    s.plinth(h, 5, sh(stone, 0.8))
    for k in range(6):
        s.win(h, 'L', 0.1 + k * 0.28, 6, 0.14, 13, 'arch', frame='#F0E2C0', glass='#3A2C1E', lit=GAS)
    s.cornice(h, '#F0E2C0', 0.04, 2, dentil=True)
    s.hip(0.1, 1.1, 1.8, 0.7, 26, 6, '#5A5048')
    for (a, c) in [(0.08, 1.62), (1.62, 1.62)]:
        t = s.box(a, c, 0.3, 0.26, 0, 46, stone)
        s.texture(t, 'L', 'stone')
        s.win(t, 'L', 0.09, 30, 0.12, 8, 'arch', frame='#F0E2C0', **{k: v for k, v in W88.items() if k != 'frame'})
        s.cornice(t, '#F0E2C0', 0.03, 2)
        s.revolve(a + 0.15, c + 0.13, 48, 12, lambda t_: 0.16 * (1 - t_ ** 2) ** 0.5 + 0.01, '#5E7A6E', ribs=6)
        x, y = s.p(a + 0.15, c + 0.13, 60); s.rect(x, y - 4, 1, 4, '#C8A050')
    s.clock(h, 'L', 0.9, 18, 0.12)
    s.lamp(0.5, 1.95, light=GAS); s.lamp(1.4, 1.95, light=GAS)
    x, y = s.p(0.9, 1.95, 0); s.rect(x - 4, y - 4, 7, 3, '#2A2622'); s.rect(x + 3, y - 4, 2, 3, '#5A3A22')
    return h


def teatro(s):
    gr(s, 2, 2)
    stone = '#E2D2AE'
    s.plaza(0.1, 1.3, 1.8, 0.6, '#8A7A60')
    b = s.box(0.2, 0.2, 1.6, 1.15, 0, 30, stone)
    s.texture(b, 'L', 'courses'); s.texture(b, 'R', 'courses')
    s.plinth(b, 8, sh(stone, 0.86))
    s.grid(b, 'R', 3, 4, 0, 10, 0.12, 6, 'arch', frame='#F4EAD0', glass='#3A2C1E', lit=GAS)
    # pórtico de columnas pareadas
    s.fq(b, 'L', 0.2, 8, 1.2, 18, '#5A4636')
    for k in range(9):
        u = 0.2 + k * 0.145
        s.fq(b, 'L', u, 8, 0.05, 18, '#F6EEDA')
        s.fline(b, 'L', u + 0.05, 8, u + 0.05, 26, '#B8A880')
    for k in range(8):
        s.win(b, 'L', 0.26 + k * 0.145, 10, 0.07, 12, 'arch', frame=None, glass='#4A3020', lit=GAS, sill=False)
    s.cornice(b, '#F4EAD0', 0.04, 3, dentil=True)
    s.fpoly(b, 'L', [(0.3, 33), (1.3, 33), (0.8, 42)], '#F4EAD0')
    s.fpoly(b, 'L', [(0.4, 34), (1.2, 34), (0.8, 40)], '#D8C8A4')
    # cúpula sobre la sala
    s.box(0.55, 0.3, 0.8, 0.8, 33, 6, stone)
    s.revolve(0.95, 0.7, 39, 18, lambda t: 0.4 * (1 - t ** 2) ** 0.5 + 0.02, '#5E8A7E', ribs=12)
    s.revolve(0.95, 0.7, 56, 5, lambda t: 0.06, stone)
    s.statue(0.95, 0.7, '#C8A050', stone) if False else None
    x, y = s.p(0.95, 0.7, 61); s.rect(x - 1, y - 5, 3, 5, '#C8A050')
    for k in range(2):
        x, y = s.fp(b, 'L', 0.25 + k * 1.1, 36)
        s.rect(x - 1, y - 6, 3, 6, '#C8A050'); s.px(x, y - 7, '#C8A050')
    # carteles y farolas
    for k in range(3):
        x, y = s.p(0.3 + k * 0.6, 1.88, 0)
        s.rect(x, y - 10, 2, 10, '#2A2622'); s.rect(x - 2, y - 9, 6, 5, s.rnd.choice(['#C8553D', '#E3A93B', '#ECE0C8']))
    s.lamp(0.2, 1.95, light=GAS); s.lamp(1.8, 1.95, light=GAS)
    return b


def palacete(s):
    gr(s, 2, 2, pave=False)
    s.poly([s.p(0.05, 0.05, 0), s.p(1.95, 0.05, 0), s.p(1.95, 1.95, 0), s.p(0.05, 1.95, 0)], '#4A5A34')
    s.poly([s.p(0.85, 1.2, 0), s.p(1.15, 1.2, 0), s.p(1.15, 1.95, 0), s.p(0.85, 1.95, 0)], '#B8A880')
    b = block(s, 0.35, 0.3, 1.3, 0.9, 3, '#E8D8BC', win='shutter', tex='courses', per=(4, 3), wu=0.12, wh=6, fh=9, plinth='#B8A07C', gf=4, cornice='#F4EAD0', roof='mansard', roofc='#4A4A58', **W88)
    s.box(0.8, 1.2, 0.4, 0.14, 0, 9, '#F4EAD0')
    s.balcony(dict(i0=0.8, j0=1.2, w=0.4, d=0.14, z0=0, h=9, wall='#F4EAD0'), 'L', 0, 9, 0.4)
    s.chimney(0.5, 0.45, b['top'] + 7, 6); s.chimney(1.45, 0.45, b['top'] + 7, 6)
    s.fountain(1.0, 1.6, 0.16)
    for (i, j) in [(0.2, 1.4), (0.3, 1.8), (1.7, 1.4), (1.8, 1.8), (0.15, 0.4), (1.85, 0.6)]:
        s.tree2(i, j, 'cone' if j < 1 else 'round', h=12)
    # verja
    for k in range(20):
        x, y = s.p(0.05 + k * 0.095, 1.95, 0)
        s.rect(x, y - 3, 1, 3, '#2A2622')
    return b


def iglesia_neogotica(s):
    gr(s, 2, 1)
    stone = '#B8A890'
    n = s.box(0.15, 0.2, 1.3, 0.6, 0, 26, stone)
    s.texture(n, 'L', 'stone')
    for k in range(4):
        s.box(0.22 + k * 0.32, 0.78, 0.05, 0.07, 0, 22, sh(stone, 0.95))
        s.spire(0.245 + k * 0.32, 0.815, 0.03, 22, 5, sh(stone, 0.95), octo=False)
    lancets(s, n, 'L', 4, 7, 14, 0.08, frame='#E0D4BC')
    s.gable(0.15, 0.2, 1.3, 0.6, 26, 14, '#4A4A58', stone, axis='i')
    gtower(s, 1.45, 0.25, 0.42, 50, stone, 36, '#4A4A58', levels=3)
    s.lamp(1.95, 0.95, light=GAS)
    return n


def cuadras(s):
    gr(s, 2, 1)
    s.poly([s.p(1.3, 0.1, 0), s.p(1.95, 0.1, 0), s.p(1.95, 0.9, 0), s.p(1.3, 0.9, 0)], '#8A7A4A')
    b = s.box(0.1, 0.15, 1.15, 0.7, 0, 14, '#8A6440')
    s.texture(b, 'L', 'wood'); s.texture(b, 'R', 'wood')
    for k in range(3):
        s.fpoly(b, 'L', [(0.08 + k * 0.37, 0), (0.36 + k * 0.37, 0), (0.36 + k * 0.37, 8), (0.22 + k * 0.37, 11), (0.08 + k * 0.37, 8)], '#3A2A1E')
        s.fline(b, 'L', 0.08 + k * 0.37, 0, 0.36 + k * 0.37, 8, '#A07A4A')
    s.gable(0.1, 0.15, 1.15, 0.7, 14, 12, '#7A5A3A', '#8A6440', axis='i')
    s.win(b, 'R', 0.28, 15, 0.14, 6, 'sash', frame='#A07A4A', glass='#2A1E16', lit='#2A1E16', sill=False)
    # balas de heno y carruaje
    for k in range(3):
        s.box(1.4 + k * 0.15, 0.2, 0.12, 0.1, 0, 4, '#D8B860')
    s.box(1.45, 0.55, 0.3, 0.16, 3, 5, '#3A2A20')
    for (a, c) in [(1.5, 0.71), (1.7, 0.71)]:
        x, y = s.p(a, c, 2); s.dr.ellipse([x - 2, y - 2, x + 2, y + 2], outline=s.c('#8A6440') + (255,))
    x, y = s.p(1.9, 0.62, 0); s.rect(x - 3, y - 7, 7, 4, '#6A4A32'); s.rect(x + 3, y - 9, 2, 3, '#6A4A32'); s.rect(x - 3, y - 3, 1, 3, '#4A3222'); s.rect(x + 2, y - 3, 1, 3, '#4A3222')
    return b


def kiosco_musica(s):
    gr(s, pave=False)
    s.plaza(0.05, 0.05, 0.9, 0.9, '#8A7A60')
    s.revolve(0.5, 0.5, 0, 3, lambda t: 0.3, '#D8C8A4', top=True)
    for k in range(8):
        a = 2 * math.pi * k / 8
        x, y = s.p(0.5 + 0.25 * math.cos(a), 0.5 + 0.25 * math.sin(a), 3)
        if math.sin(a + math.pi / 4) > -0.5:
            s.rect(x, y - 13, 1, 13, '#2E4A3A')
    s.revolve(0.5, 0.5, 16, 8, lambda t: 0.34 * (1 - t) + 0.02, '#4E7A6A', ribs=8)
    x, y = s.p(0.5, 0.5, 25); s.rect(x, y - 4, 1, 4, '#C8A050')
    for (i, j) in [(0.1, 0.1), (0.9, 0.1), (0.1, 0.9)]:
        s.tree2(i, j, h=12)
    s.lamp(0.9, 0.9, light=GAS)
    return dict(i0=0.2, j0=0.2, w=0.6, d=0.6, z0=0, h=16, wall='#D8C8A4')


# ================================================================== 1929
W29 = dict(glass='#2E2C28', lit='#D9B85C', frame='#8E8878')


def vecinos_deco(s):
    gr(s)
    var = s.swaps.get('#D9CDB0')
    fl = 4 if var is None else (3 if var == '#D8B49A' else 4)
    roof = 'mansard' if var == '#D8B49A' else 'flat'
    b = block(s, 0.1, 0.1, 0.8, 0.8, fl, '#D9CDB0', win='sash', per=(2, 2), wu=0.13, wh=5, plinth='#8E846F', gf=FH,
              shops=[('#2E5A4A', '#ECE6D2')], courses='#B8AC90', cornice='#ECE6D2', roof=roof, roofc='#5A5650', **W29)
    if var is None:
        # pilastra déco central con remate escalonado
        s.fq(b, 'L', 0.36, FH, 0.08, b['h'] - FH, '#C8A050')
        s.box(0.42, 0.85, 0.16, 0.06, b['top'], 4, '#ECE6D2')
    elif roof == 'flat':
        # azotea con tendedero y depósito
        s.tank(0.25, 0.25, b['top'] + 1, '#6A5A4A')
        x, y = s.p(0.55, 0.6, b['top'] + 4)
        s.line((x - 6, y), (x + 6, y - 3), '#ECE6D2')
        for k, col in enumerate(['#ECE4D0', '#5AA6D6', '#E2675B']):
            s.px(x - 4 + k * 4, y - k + 1, col, raw=True)
    else:
        s.chimney(0.3, 0.3, b['top'] + 7, 5)
    return b


def torre_deco(s):
    gr(s)
    b = block(s, 0.08, 0.08, 0.84, 0.84, 6, '#B8B2A0', win='strip', per=(3, 3), wu=0.12, wh=5, plinth='#6E6A5E', gf=FH, **W29)
    s.vstripes(b, 'L', 3, FH, b['h'] - FH, '#9A9480', 0.04); s.vstripes(b, 'R', 3, FH, b['h'] - FH, '#8A8470', 0.04)
    s.fq(b, 'L', 0.3, 0, 0.24, 7, '#2A2622'); s.fpoly(b, 'L', [(0.26, 7), (0.58, 7), (0.42, 10)], '#C8A050')
    b2 = block(s, 0.2, 0.2, 0.6, 0.6, 3, '#C8C2B0', win='strip', per=(2, 2), wu=0.12, wh=5, z0=b['h'], **W29)
    s.vstripes(b2, 'L', 2, b2['z0'], b2['h'], '#A8A290', 0.04)
    z = b2['z0'] + b2['h']
    b3 = s.box(0.32, 0.32, 0.36, 0.36, z, 14, '#D8D2C0')
    # abanicos déco
    for f in 'LR':
        for k in range(3):
            s.fpoly(b3, f, [(0.04 + k * 0.1, z + 6), (0.12 + k * 0.1, z + 6), (0.08 + k * 0.1, z + 12)], '#E3A93B')
    s.revolve(0.5, 0.5, z + 14, 18, lambda t: 0.08 * (1 - t), '#C8C2B0', bands=[(0, 0.3, '#E3A93B')])
    x, y = s.p(0.5, 0.5, z + 32); s.rect(x, y - 6, 1, 6, '#E3A93B')
    return b


def cine(s):
    gr(s, 2, 1)
    b = block(s, 0.1, 0.1, 1.8, 0.8, 3, '#8E4A3E', win='strip', per=(6, 2), wu=0.14, wh=4, shops=None, courses='#6E3428', cornice='#E8D8B0', **W29)
    s.fq(b, 'L', 0.2, 0, 1.4, 7, '#2A1E1A')
    for k in range(3):
        s.fq(b, 'L', 0.35 + k * 0.4, 0, 0.25, 6, '#F2D08A' if s.state in LIT else '#4A3A30')
    m = s.box(0.15, 0.9, 1.7, 0.18, FH - 1, 4, '#E8D8B0')
    lit = s.state in LIT
    for k in range(24):
        x, y = s.fp(m, 'L', 0.04 + k * 0.07, FH + 1)
        s.px(x, y, '#FFE28A' if lit and k % 2 == 0 else '#8A7A5A', raw=True)
    s.fq(m, 'L', 0.3, FH + 3, 1.1, 1, '#2A2622')
    v = s.box(1.55, 0.95, 0.1, 0.1, FH + 4, 4 * FH, '#C8553D')
    for k in range(6):
        x, y = s.fp(v, 'L', 0.03, FH + 8 + k * 5)
        s.rect(x - 1, y - 2, 3, 3, '#FFE28A' if lit else '#5A4A3A', raw=True)
    s.revolve(1.6, 1.0, FH + 4 + 4 * FH, 4, lambda t: 0.08 * (1 - t), '#E3A93B')
    for k in range(3):
        x, y = s.fp(b, 'L', 0.25 + k * 0.5, 1)
        s.rect(x, y - 7, 4, 6, s.rnd.choice(['#E3A93B', '#5AA6D6', '#E2675B']))
    return b


def banco(s):
    gr(s, 2, 2)
    stone = '#C8C2B0'
    s.plaza(0.1, 1.5, 1.8, 0.45, '#8E8A80')
    b = s.box(0.15, 0.15, 1.7, 1.4, 0, 34, stone)
    s.texture(b, 'L', 'stone'); s.texture(b, 'R', 'stone')
    s.plinth(b, 6, '#8E8A80')
    s.fq(b, 'L', 0.2, 6, 1.3, 22, '#3A3A36')
    for k in range(8):
        u = 0.2 + k * 0.185
        s.fq(b, 'L', u, 6, 0.06, 22, '#ECE6D2')
        s.fq(b, 'L', u - 0.01, 6, 0.08, 2, '#F6F2E6'); s.fq(b, 'L', u - 0.01, 26, 0.08, 2, '#F6F2E6')
    for k in range(7):
        s.win(b, 'L', 0.29 + k * 0.185, 8, 0.08, 14, 'sash', frame=None, glass='#2A3A3A', lit='#E5CD8A', sill=False)
    s.grid(b, 'R', 3, 4, 6, 9, 0.12, 6, 'sash', **W29)
    s.fq(b, 'L', 0, 28, 1.7, 6, '#ECE6D2'); s.fq(b, 'R', 0, 28, 1.4, 6, '#ECE6D2')
    s.sign(b, 'L', 0.55, 30, 0.6, 2, '#C8A050', '#2A2622')
    s.parapet(dict(b, h=34), '#B8B2A0', 3)
    s.box(0.55, 0.45, 0.9, 0.7, 34, 8, '#B8B2A0')
    s.revolve(1.0, 0.8, 42, 10, lambda t: 0.3 * (1 - t ** 2) ** 0.5 + 0.02, '#6F8C80', ribs=10)
    x, y = s.p(1.0, 0.8, 52); s.rect(x, y - 4, 1, 4, '#E3A93B')
    s.box(0.7, 1.55, 0.6, 0.1, 0, 2, '#ECE6D2'); s.box(0.75, 1.65, 0.5, 0.1, 0, 1, '#ECE6D2')
    s.lamp(0.3, 1.9); s.lamp(1.7, 1.9)
    s.car(1.2, 1.78, '#2A2622')
    return b


def fabrica_dientes(s):
    gr(s, 2, 2)
    b = s.box(0.1, 0.1, 1.8, 1.8, 0, FH + 8, '#8A4632')
    s.texture(b, 'L', 'brick'); s.texture(b, 'R', 'brick')
    s.grid(b, 'L', 1, 6, 0, FH + 8, 0.18, 10, 'sash', frame='#B89A70', glass='#2A221E', lit='#E5CD8A')
    s.grid(b, 'R', 1, 6, 0, FH + 8, 0.18, 10, 'sash', frame='#B89A70', glass='#2A221E', lit='#E5CD8A')
    z = b['h']
    for k in range(5):
        i0 = 0.1 + k * 0.36
        s.poly([s.p(i0, 0.1, z), s.p(i0, 1.9, z), s.p(i0 + 0.08, 1.9, z + 10), s.p(i0 + 0.08, 0.1, z + 10)], '#9CB0B0')
        s.poly([s.p(i0 + 0.08, 0.1, z + 10), s.p(i0 + 0.08, 1.9, z + 10), s.p(i0 + 0.36, 1.9, z), s.p(i0 + 0.36, 0.1, z)], '#5A4A44')
        s.poly([s.p(i0, 1.9, z), s.p(i0 + 0.36, 1.9, z), s.p(i0 + 0.08, 1.9, z + 10)], '#6E3424')
    s.sign(b, 'L', 0.3, z - 5, 1.2, 3, '#ECE6D2', '#2A2622')
    s.revolve(1.75, 0.3, z, 50, lambda t: 0.09 - 0.03 * t, '#7A3A28', bands=[(0.9, 1, '#2A1E18')])
    s.tank(0.3, 0.3, z + 10, '#5A5048')
    s.box(1.0, 1.92, 0.3, 0.06, 0, 1, '#3A3A36')
    s.car(0.3, 1.92, '#3A4A3A')
    return b


def rascacielos_deco(s):
    gr(s, 2, 2)
    st = '#C8C2B0'
    b1 = block(s, 0.3, 0.3, 1.4, 1.4, 4, st, win='strip', per=(5, 5), wu=0.14, wh=5, plinth='#6E6A5E', gf=FH, **W29)
    s.vstripes(b1, 'L', 5, FH, b1['h'] - FH, '#A8A290', 0.04); s.vstripes(b1, 'R', 5, FH, b1['h'] - FH, '#989280', 0.04)
    s.fq(b1, 'L', 0.55, 0, 0.3, 9, '#2A2622'); s.fpoly(b1, 'L', [(0.5, 9), (0.9, 9), (0.7, 14)], '#C8A050')
    z = b1['h']
    b2 = block(s, 0.5, 0.5, 1.0, 1.0, 4, '#D2CCBA', win='strip', per=(4, 4), wu=0.12, wh=5, z0=z, **W29)
    s.vstripes(b2, 'L', 4, z, b2['h'], '#B0AA98', 0.04)
    z += b2['h']
    b3 = block(s, 0.68, 0.68, 0.64, 0.64, 3, '#DCD6C4', win='strip', per=(3, 3), wu=0.1, wh=5, z0=z, **W29)
    z += b3['h']
    # corona de arcos solares
    cr = s.box(0.78, 0.78, 0.44, 0.44, z, 18, '#E8E2D0')
    for f in 'LR':
        for r_, col in ((0.2, '#C8A050'), (0.15, '#2A2622'), (0.1, '#C8A050'), (0.05, '#2A2622')):
            pts = [(0.22 + r_ * math.cos(a), z + 2 + r_ * 26 * math.sin(a)) for a in [math.pi * k / 10 for k in range(11)]]
            s.fpoly(cr, f, pts, col)
        for k in range(5):
            x, y = s.fp(cr, f, 0.06 + k * 0.08, z + 3 + 4 * math.sin(math.pi * (k + 1) / 6))
            s.px(x, y, '#FFE28A' if s.state in LIT else '#6A5A3A', raw=True)
    s.revolve(1.0, 1.0, z + 18, 16, lambda t: 0.16 * (1 - t) ** 1.3, '#D8D2C0', bands=[(0, 0.12, '#C8A050'), (0.4, 0.46, '#C8A050')])
    x, y = s.p(1.0, 1.0, z + 34); s.rect(x, y - 6, 1, 6, '#ECE6D2'); s.px(x, y - 7, '#E2675B', raw=True)
    s.lamp(0.15, 1.85); s.lamp(1.85, 1.85); s.car(0.9, 1.8, '#2A2622')
    return b1


def gasolinera_deco(s):
    gr(s)
    b = s.box(0.1, 0.1, 0.45, 0.45, 0, 12, '#ECE6D2')
    s.shopfront(b, 'L', 0.05, 0.35, 8, glass='#9CB8B8'); s.course(b, 9, '#C8402E')
    s.revolve(0.55, 0.32, 0, 12, lambda t: 0.2, '#ECE6D2', bands=[(0.7, 0.78, '#C8402E')])
    s.box(0.3, 0.3, 0.12, 0.12, 12, 12, '#ECE6D2'); s.sign(dict(i0=0.3, j0=0.3, w=0.12, d=0.12, z0=12, h=12, wall='#ECE6D2'), 'L', 0.01, 14, 0.1, 8, '#C8402E', '#ECE6D2')
    for k in range(2):
        s.box(0.65 + k * 0.18, 0.72, 0.06, 0.06, 0, 7, '#C8402E')
        s.revolve(0.68 + k * 0.18, 0.75, 7, 3, lambda t: 0.04, '#ECE6D2')
    s.car(0.62, 0.9, '#2A3A5A')
    return b


def hotel_deco(s):
    gr(s)
    b = block(s, 0.12, 0.12, 0.76, 0.76, 9, '#D8C8A8', win='sash', per=(3, 3), wu=0.12, wh=5, plinth='#6E5E48', gf=FH, shops=[None], courses='#C0B090', cornice='#ECE6D2', **W29)
    s.box(0.25, 0.86, 0.5, 0.14, FH, 1, '#2A2622')
    v = s.box(0.82, 0.86, 0.06, 0.06, FH + 6, 5 * FH, '#2A2622')
    lit = s.state in LIT
    for k in range(5):
        x, y = s.fp(v, 'L', 0.0, FH + 9 + k * 7)
        s.rect(x, y - 4, 2, 4, '#E2675B' if lit else '#5A3A30', raw=True)
    s.box(0.3, 0.3, 0.4, 0.4, b['top'], 6, '#ECE6D2'); s.box(0.42, 0.42, 0.16, 0.16, b['top'] + 6, 5, '#C8A050')
    return b


def palacio_exposiciones(s):
    gr(s, 2, 2)
    st = '#E8DCC0'
    s.plaza(0.05, 1.4, 1.9, 0.55, '#8E8A80')
    s.fountain(1.0, 1.72, 0.18)
    for (a, c) in [(0.15, 0.2), (1.25, 0.2)]:
        w = block(s, a, c, 0.6, 1.15, 2, st, win='arch', per=(2, 4), wu=0.14, wh=9, fh=12, cornice='#F4EEDC', roof='flat', **W29)
    m = s.box(0.6, 0.35, 0.8, 0.9, 0, 30, st)
    s.texture(m, 'L', 'courses')
    s.win(m, 'L', 0.2, 4, 0.4, 20, 'arch', frame='#F4EEDC', glass='#34322C', lit='#E5CD8A', sill=False)
    s.cornice(m, '#F4EEDC', 0.04, 2)
    s.revolve(1.0, 0.8, 32, 6, lambda t: 0.38, st)
    s.revolve(1.0, 0.8, 38, 20, lambda t: 0.38 * (1 - t ** 2) ** 0.5 + 0.02, '#A88A44', ribs=14)
    s.revolve(1.0, 0.8, 61, 6, lambda t: 0.05, st)
    for (a, c) in [(0.2, 1.2), (1.8, 1.2)]:
        s.revolve(a, c, 0, 46, lambda t: 0.05, '#ECE6D2', bands=[(0.9, 1, '#C8A050')])
    return m


def cochera_tranvias(s):
    gr(s, 2, 1)
    b = s.box(0.1, 0.12, 1.8, 0.76, 0, 18, '#A85A3C')
    s.texture(b, 'L', 'brick'); s.texture(b, 'R', 'brick')
    for k in range(3):
        s.fpoly(b, 'R', [(0.06 + k * 0.24, 0), (0.24 + k * 0.24, 0), (0.24 + k * 0.24, 10), (0.15 + k * 0.24, 13), (0.06 + k * 0.24, 10)], '#2A2622')
    s.grid(b, 'L', 1, 6, 4, 12, 0.14, 7, 'arch', frame='#E8DCC0', glass='#34322C', lit='#E5CD8A')
    s.gable(0.1, 0.12, 1.8, 0.76, 18, 10, '#5A5048', '#A85A3C', axis='i')
    s.sign(b, 'R', 0.12, 15, 0.5, 2, '#E8DCC0', '#2A2622')
    s.box(1.9, 0.42, 0.08, 0.2, 0, 1, '#4A4A44')
    s.box(1.88, 0.4, 0.1, 0.24, 1, 0, '#4A4A44')
    t = s.box(1.92, 0.4, 0.06, 0.22, 1, 9, '#C8A050')
    return b


def tienda_deco(s):
    gr(s)
    b = block(s, 0.1, 0.1, 0.8, 0.8, 2, '#C8B89A', win='sash', per=(2, 2), wu=0.14, wh=5, shops=None, courses='#A89A7C', **W29)
    s.shopfront(b, 'L', 0.05, 0.7, FH - 1, glass='#9CB8B8', frame='#2E2C28', awn=('#2E5A4A', '#ECE6D2'))
    s.shopfront(b, 'R', 0.08, 0.64, FH - 1, glass='#9CB8B8', frame='#2E2C28', awn=None, door=False)
    s.sign(b, 'R', 0.08, FH + 0.5, 0.64, 2, '#2E2C28', '#D9B85C')
    # remate escalonado déco
    z = b['h']
    s.box(0.1, 0.84, 0.8, 0.06, z, 2, '#ECE6D2')
    s.box(0.3, 0.86, 0.4, 0.05, z + 2, 3, '#ECE6D2')
    s.box(0.44, 0.87, 0.12, 0.04, z + 5, 3, '#C8A050')
    return b


def chaflan_deco(s):
    gr(s)
    b = chaflan_gen(s, 0.08, 0.08, 0.84, 0.84, 6, '#D0C8B0', 0.3, roofc=None, dome=False, awn=('#2E5A4A', '#ECE6D2'), style='strip', tex=None, **W29)
    s.parapet(dict(b, h=6 * FH + 2), '#ECE6D2', 3)
    s.box(0.62, 0.62, 0.22, 0.22, 6 * FH + 4, 10, '#ECE6D2')
    s.revolve(0.73, 0.73, 6 * FH + 14, 8, lambda t: 0.06 * (1 - t), '#C8A050')
    return b


ERAS2 = {
    '1888': [
        ('casa_cos', 'Casa de cos', 1, 1, casa_cos, 'mejora'), ('finca_ensanche', 'Finca del Ensanche', 2, 2, finca_ensanche, 'mejora'),
        ('fabrica_vapor', 'Fábrica de vapor', 2, 2, fabrica_vapor, 'mejora'), ('colmado', 'Colmado', 1, 1, colmado, 'mejora'),
        ('mercado_hierro', 'Mercado de hierro', 2, 2, mercado_hierro, 'mejora'),
        ('estacion_hierro', 'Estación del Norte', 2, 2, estacion_hierro, 'monumento'), ('teatro', 'Gran Teatro', 2, 2, teatro, 'nuevo'),
        ('palacete', 'Palacete con jardín', 2, 2, palacete, 'nuevo'), ('iglesia_neogotica', 'Parroquia neogótica', 2, 1, iglesia_neogotica, 'nuevo'),
        ('cuadras', 'Cuadras y cocheras', 2, 1, cuadras, 'nuevo'), ('kiosco_musica', 'Kiosco de música', 1, 1, kiosco_musica, 'nuevo')],
    '1929': [
        ('vecinos_deco', 'Casa de vecinos déco', 1, 1, vecinos_deco, 'mejora'), ('torre_deco', 'Torre déco', 1, 1, torre_deco, 'mejora'),
        ('cine', 'Cine de estreno', 2, 1, cine, 'mejora'), ('banco', 'Banco', 2, 2, banco, 'mejora'),
        ('fabrica_dientes', 'Fábrica de dientes de sierra', 2, 2, fabrica_dientes, 'mejora'),
        ('rascacielos_deco', 'Rascacielos del Progreso', 2, 2, rascacielos_deco, 'monumento'), ('palacio_exposiciones', 'Palacio de Exposiciones', 2, 2, palacio_exposiciones, 'nuevo'),
        ('hotel_deco', 'Hotel con rótulo', 1, 1, hotel_deco, 'nuevo'), ('gasolinera_deco', 'Surtidor aerodinámico', 1, 1, gasolinera_deco, 'nuevo'),
        ('cochera_tranvias', 'Cochera de tranvías', 2, 1, cochera_tranvias, 'nuevo'), ('chaflan_deco', 'Esquina déco', 1, 1, chaflan_deco, 'nuevo'),
        ('tienda_deco', 'Tienda déco', 1, 1, tienda_deco, 'nuevo')],
}


# ================================================================== 1980
W80 = dict(glass='#2A201C', lit='#F0A060', frame='#C8B8A0')


def bloque_ladrillo(s):
    gr(s)
    b = block(s, 0.1, 0.1, 0.8, 0.8, 9, '#8A5A42', win='sash', tex='brick', per=(2, 2), wu=0.2, wh=4, courses='#B8B0A0', shops=[None], **W80)
    for f in range(2, 9, 2):
        s.balcony(b, 'R', 0.08, f * FH + 1, 0.3, '#C8C0B0')
    # tendederos y antenas
    for f in (3, 5, 7):
        x, y = s.fp(b, 'L', 0.55, f * FH + 4)
        for k, col in enumerate(['#ECE4D0', '#5AA6D6', '#E2675B']):
            s.px(x + k * 2, y + 1, col, raw=True)
    s.antenna(0.3, 0.3, b['top'] + 2, 10); s.antenna(0.65, 0.55, b['top'] + 2, 7)
    s.box(0.55, 0.2, 0.25, 0.25, b['top'], 6, '#7A4A36')
    s.fq(b, 'L', 0.3, 0, 0.2, 6, '#3A2E28')
    return b


def torre_brutalista(s):
    gr(s, 2, 2)
    con = '#8C8880'
    s.box(0.1, 0.1, 1.8, 1.8, 0, 6, '#6E6A64')
    b = s.box(0.3, 0.3, 1.4, 1.4, 6, 60, con)
    s.texture(b, 'L', 'panels'); s.texture(b, 'R', 'panels')
    for f in range(7):
        z = 6 + f * FH + 2
        for face in 'LR':
            s.fq(b, face, 0.04, z, 1.32, 4, '#2A2624')
            for k in range(7):
                if s.rnd.random() < (0.3 if s.state == 'normal' else 0.6 if s.state in ('reformada', 'alquilada') else 0):
                    s.fq(b, face, 0.08 + k * 0.18, z + 1, 0.1, 3, '#F0A060')
            s.fq(b, face, 0.0, z - 2, 1.4, 2, '#A8A49C')
    top = s.box(0.1, 0.1, 1.8, 1.8, 66, 12, '#9A968E')
    s.texture(top, 'L', 'panels'); s.texture(top, 'R', 'panels')
    s.fq(top, 'L', 0.1, 70, 1.6, 3, '#2A2624'); s.fq(top, 'R', 0.1, 70, 1.6, 3, '#2A2624')
    s.box(0.7, 0.7, 0.3, 0.3, 78, 10, '#7A766E')
    s.antenna(0.85, 0.85, 88, 12)
    s.car(0.2, 1.75, '#C8A050'); s.car(1.5, 1.8, '#5A6A8A')
    return b


def local_persiana(s):
    gr(s)
    b = block(s, 0.1, 0.1, 0.8, 0.8, 3, '#C8A888', win='sash', per=(2, 2), wu=0.16, wh=4, shops=None, **W80)
    s.fq(b, 'L', 0.06, 0, 0.68, 7, '#8A8A86')
    for z in range(1, 7, 2):
        s.fq(b, 'L', 0.06, z, 0.68, 1, '#6A6A66')
    if s.state in ('normal', 'ruina', 'obra'):
        for (u, z, col) in [(0.12, 2, '#C84A8A'), (0.2, 3, '#4AA0C8'), (0.32, 2, '#E3A93B'), (0.45, 4, '#4FC08D'), (0.55, 2, '#C84A8A'), (0.6, 4, '#ECE4D0')]:
            s.fq(b, 'L', u, z, 0.08, 2, col, raw=True)
    s.sign(b, 'L', 0.12, FH - 1, 0.56, 3, '#C8553D', '#ECE4D0')
    s.shopfront(b, 'R', 0.1, 0.6, 7, glass='#4A5A5A', awn=('#E3A93B', '#2A2622'))
    s.antenna(0.5, 0.5, b['h'] + 2, 8)
    return b


def nave_abandonada(s):
    gr(s, 2, 2)
    b = s.box(0.1, 0.1, 1.8, 1.8, 0, FH + 8, '#7A7A74')
    s.texture(b, 'L', 'metal'); s.texture(b, 'R', 'metal')
    s.fq(b, 'L', 0.6, 0, 0.6, 12, '#3E3E3A')
    for z in range(1, 12, 2):
        s.fq(b, 'L', 0.6, z, 0.6, 1, '#4E4E4A')
    s.fq(b, 'R', 0.2, 10, 1.4, 4, '#9CB0B0')
    s.vstripes(b, 'R', 10, 10, 4, '#5E5E5A', 0.02)
    s.barrel(0.1, 1.9, 1.0, 0.9, 16, '#6E5A4A', end='#7A7A74', ribs=0.2, rise=12, glass=False)
    for (u, z, col) in [(0.1, 2, '#C84A8A'), (0.25, 3, '#4AA0C8'), (1.3, 2, '#E3A93B'), (1.45, 4, '#4FC08D')]:
        s.fq(b, 'L', u, z, 0.12, 3, col)
    s.box(1.6, 1.85, 0.25, 0.1, 0, 3, '#4A3E36')
    return b


def oficinas_70(s):
    gr(s)
    b = s.box(0.1, 0.1, 0.8, 0.8, 0, 7 * FH, '#5A4434')
    s.box(0.14, 0.14, 0.72, 0.72, 0, 6, '#3A2E24')
    for f in range(1, 7):
        for face in 'LR':
            s.fq(b, face, 0, f * FH + 1, 0.8, 5, '#8A6A3E')
            s.vstripes(dict(b, z0=f * FH + 1, h=5), face, 5, f * FH + 1, 5, '#3A2E24', 0.02)
            if s.state in LIT and s.rnd.random() < 0.6:
                s.fq(b, face, 0.1 + s.rnd.random() * 0.5, f * FH + 2, 0.15, 3, '#F0C080')
    s.cornice(b, '#C8A060', 0.02, 2)
    s.box(0.3, 0.3, 0.4, 0.4, 7 * FH + 2, 6, '#4A3A2C')
    s.sign(b, 'L', 0.1, 7 * FH - 4, 0.6, 3, '#C8A060', '#2A2622')
    return b


def torre_telefonica(s):
    gr(s)
    s.box(0.2, 0.2, 0.6, 0.6, 0, 8, '#9A968E')
    s.revolve(0.5, 0.5, 8, 64, lambda t: 0.14 - 0.05 * t, '#B8B4AC', ribs=4)
    for z in (40, 56):
        s.revolve(0.5, 0.5, z, 3, lambda t: 0.22, '#8A867E')
        for k in range(3):
            a = 2 * math.pi * k / 3 + 0.5
            x, y = s.p(0.5 + 0.2 * math.cos(a), 0.5 + 0.2 * math.sin(a), z + 5)
            s.dr.ellipse([x - 3, y - 3, x + 3, y + 3], fill=s.c('#ECE8E0') + (255,))
            s.px(x, y, '#9A968E')
    s.revolve(0.5, 0.5, 72, 8, lambda t: 0.2, '#6E6A64', bands=[(0.3, 0.6, '#2A2624')])
    x, y = s.p(0.5, 0.5, 80)
    for k in range(0, 30, 3):
        s.rect(x, y - k - 3, 1, 3, '#C8402E' if (k // 3) % 2 == 0 else '#ECE4D0', raw=True)
    s.px(x, y - 32, '#FF6A5A', raw=True)
    return dict(i0=0.36, j0=0.36, w=0.28, d=0.28, z0=0, h=72, wall='#B8B4AC')


def polideportivo(s):
    gr(s, 2, 2)
    s.poly([s.p(1.3, 0.1, 0), s.p(1.95, 0.1, 0), s.p(1.95, 1.9, 0), s.p(1.3, 1.9, 0)], '#3A3434')
    for k in range(5):
        s.line(s.p(1.32, 0.3 + k * 0.35, 0), s.p(1.92, 0.3 + k * 0.35, 0), '#ECE4D0')
    b = s.box(0.1, 0.15, 1.15, 1.7, 0, 14, '#C8C0B0')
    s.texture(b, 'L', 'panels'); s.texture(b, 'R', 'panels')
    s.fq(b, 'R', 0.1, 6, 1.5, 5, '#3E6A8A'); s.vstripes(dict(b, z0=6, h=5), 'R', 12, 6, 5, '#ECE4D0', 0.02)
    s.course(b, 3, '#C8553D')
    s.barrel(0.1, 1.25, 1.0, 0.85, 14, '#9A9EA4', end='#C8C0B0', ribs=0.2, rise=12, glass=False)
    s.sign(b, 'L', 0.2, 8, 0.7, 3, '#C8553D', '#ECE4D0')
    s.car(1.4, 0.35, '#C8553D', 'j'); s.car(1.6, 1.1, '#E3A93B', 'j'); s.car(1.8, 0.7, '#4A6A8A', 'j')
    return b


def recreativos(s):
    gr(s)
    b = block(s, 0.1, 0.1, 0.8, 0.8, 2, '#4A3A4A', win='sash', per=(2, 2), wu=0.16, wh=4, shops=None, **W80)
    lit = s.state in LIT or s.state == 'normal'
    s.fq(b, 'L', 0.06, 0, 0.68, 7, '#1A1420')
    for k in range(4):
        s.fq(b, 'L', 0.1 + k * 0.16, 1, 0.1, 5, s.rnd.choice(['#E86AC8', '#5AE0E8', '#F2C25F']) if lit else '#3A2E3A')
    s.sign(b, 'L', 0.06, FH + 1, 0.68, 4, '#1A1420', '#E86AC8' if lit else '#5A3A5A')
    s.sign(b, 'R', 0.1, 4, 0.6, 3, '#1A1420', '#5AE0E8' if lit else '#3A4A5A')
    for (u, z, col) in [(0.05, 2, '#4FC08D'), (0.2, 3, '#E3A93B'), (0.45, 2, '#C84A8A')]:
        s.fq(b, 'R', u, z, 0.1, 2, col, raw=True)
    return b


def colmena(s):
    gr(s, 2, 1)
    b = block(s, 0.1, 0.15, 1.8, 0.7, 10, '#B8A890', win='balcony', per=(7, 3), wu=0.14, wh=4, courses='#9A8C78', **W80)
    s.texture(b, 'L', 'panels')
    for k in range(6):
        x, y = s.fp(b, 'L', 0.2 + k * 0.28, (2 + k % 7) * FH + 4)
        for m, col in enumerate(['#ECE4D0', '#5AA6D6', '#E2675B', '#F2C25F']):
            s.px(x + m * 2, y + 1, col, raw=True)
    for k in range(4):
        s.antenna(0.3 + k * 0.4, 0.4, b['top'] + 2, 8)
    s.box(0.8, 0.3, 0.3, 0.3, b['top'], 8, '#9A8C78')
    return b


def gasolinera_80(s):
    gr(s)
    b = s.box(0.08, 0.1, 0.4, 0.4, 0, 10, '#E8E4DA')
    s.shopfront(b, 'L', 0.04, 0.32, 8, glass='#4A5A5A'); s.course(b, 9, '#E3A93B')
    for (i, j) in [(0.6, 0.5), (0.9, 0.5), (0.6, 0.9), (0.9, 0.9)]:
        x, y = s.p(i, j, 0); s.rect(x, y - 14, 1, 14, '#ECE8E0')
    s.box(0.55, 0.62, 0.06, 0.08, 0, 5, '#E3A93B'); s.box(0.8, 0.62, 0.06, 0.08, 0, 5, '#E3A93B')
    cb = s.box(0.52, 0.42, 0.46, 0.54, 14, 4, '#E3A93B', top='#F2C25F')
    s.fq(cb, 'L', 0, 15, 0.46, 1, '#C8402E'); s.fq(cb, 'R', 0, 15, 0.54, 1, '#C8402E')
    x, y = s.p(0.15, 0.85, 0); s.rect(x, y - 22, 2, 22, '#5A5A5A'); s.rect(x - 4, y - 30, 10, 9, '#E3A93B'); s.rect(x - 3, y - 27, 8, 1, '#C8402E'); s.rect(x - 3, y - 25, 8, 1, '#2A2622')
    s.car(0.68, 0.7, '#8A2A2A', 'j')
    return b


def mercado_barrio(s):
    gr(s, 2, 1)
    b = s.box(0.1, 0.12, 1.8, 0.76, 0, 14, '#B8B0A0')
    s.texture(b, 'L', 'panels')
    for k in range(4):
        s.shopfront(b, 'L', 0.06 + k * 0.44, 0.38, 7, glass='#4A5A5A', awn=(('#C8553D', '#ECE4D0'), ('#4FA36B', '#ECE4D0'), ('#E3A93B', '#ECE4D0'), ('#5AA6D6', '#ECE4D0'))[k])
    s.fq(b, 'L', 0.0, 9, 1.8, 4, '#9CB0B0'); s.vstripes(dict(b, z0=9, h=4), 'L', 18, 9, 4, '#6E6A64', 0.02)
    s.sign(b, 'R', 0.1, 9, 0.56, 3, '#3E6A8A', '#ECE4D0')
    s.gable(0.1, 0.12, 1.8, 0.76, 14, 7, '#9A9EA4', '#B8B0A0', axis='i')
    return b


# ================================================================== 2005
W05 = dict(glass='#4A5A62', lit='#9CC8E0', frame='#FFFFFF')


def adosados(s):
    gr(s, 2, 1, pave=False)
    s.poly([s.p(0.05, 0.05, 0), s.p(1.95, 0.05, 0), s.p(1.95, 0.95, 0), s.p(0.05, 0.95, 0)], '#5E9A50')
    for k in range(3):
        a = 0.1 + k * 0.6
        b = s.box(a, 0.15, 0.56, 0.55, 0, 2 * FH, ('#E8DCC0', '#E0CCAA', '#ECE0CC')[k])
        s.grid(b, 'L', 2, 2, 0, FH, 0.14, 5, 'sash', **W05)
        s.grid(b, 'R', 2, 1, 0, FH, 0.14, 5, 'sash', **W05)
        s.fq(b, 'L', 0.38, 0, 0.1, 6, '#6A4A32')
        s.gable(a, 0.15, 0.56, 0.55, b['h'], 8, '#B8503A', b['wall'], axis='i')
        s.poly([s.p(a, 0.72, 0), s.p(a + 0.56, 0.72, 0), s.p(a + 0.56, 0.95, 0), s.p(a, 0.95, 0)], '#B8B0A0')
        x, y = s.p(a + 0.15, 0.8, 0); s.box(a + 0.08, 0.76, 0.26, 0.12, 1, 3, ('#5AA6D6', '#C8C8C8', '#2A2A2A')[k], rim=False, ao=False)
        x, y = s.fp(b, 'R', 0.15, b['h'] - 3); s.rect(x, y - 3, 3, 3, '#E8E8E8'); s.px(x + 1, y - 2, '#9A9A9A')
    return b


def torre_cristal(s):
    gr(s)
    b = s.box(0.12, 0.12, 0.76, 0.76, 0, 13 * FH, '#4E86A8', top='#9CC8E0', right='#3A6A88')
    for f in range(13):
        s.fq(b, 'L', 0, f * FH, 0.76, 1, '#6A9CBC'); s.fq(b, 'R', 0, f * FH, 0.76, 1, '#4A7A98')
    s.vstripes(b, 'L', 6, 0, b['h'], '#3E6E8E', 0.015)
    lit = 0.35 if s.state == 'normal' else 0.7 if s.state in ('reformada', 'alquilada') else 0.0
    for f in range(13):
        for k in range(4):
            if s.rnd.random() < lit:
                s.fq(b, 'L', 0.04 + k * 0.18, f * FH + 2, 0.12, 4, '#F2E2A0', raw=True)
    for k in range(20):
        s.fq(b, 'L', 0.05 + k * 0.03, 40 + k * 2.5, 0.05, 6, '#B8DCEC')
    s.box(0.3, 0.3, 0.4, 0.4, b['h'], 6, '#9CC8E0')
    s.sign(b, 'L', 0.18, b['h'] - 6, 0.4, 3, '#E3A93B', '#2A2622')
    s.box(0.15, 0.85, 0.7, 0.12, 8, 1, '#ECE8E0')
    return b


def centro_comercial(s):
    gr(s, 2, 2)
    for k in range(6):
        s.car(1.3 + (k % 2) * 0.3, 0.2 + (k // 2) * 0.45, s.rnd.choice(['#C8553D', '#ECE4D0', '#2A2A2A', '#5AA6D6']), 'j')
    b = s.box(0.1, 0.1, 1.15, 1.8, 0, 2 * FH + 6, '#DCD8D0')
    s.texture(b, 'L', 'panels'); s.texture(b, 'R', 'panels')
    s.fq(b, 'L', 0.3, 0, 0.55, 15, '#7FB0CC'); s.vstripes(dict(b, z0=0, h=15), 'L', 5, 0, 15, '#FFFFFF', 0.02)
    s.fq(b, 'R', 0.1, 4, 1.6, 4, '#B8B4AC')
    s.sign(b, 'L', 0.2, 16, 0.75, 5, '#C8553D', '#F2C25F')
    s.revolve(0.95, 1.6, 0, 26, lambda t: 0.14, '#7FB0CC', bands=[(0.9, 1, '#DCD8D0')])
    s.box(0.3, 0.3, 0.3, 0.3, b['h'], 4, '#B8B4AC'); s.ac(0.8, 0.5, b['h'] + 1); s.ac(0.8, 1.0, b['h'] + 1)
    x, y = s.p(1.2, 1.95, 0); s.rect(x, y - 24, 2, 24, '#9A9A9A'); s.rect(x - 5, y - 32, 12, 9, '#C8553D'); s.rect(x - 4, y - 29, 10, 2, '#F2C25F')
    return b


def obra_nueva(s):
    gr(s)
    b = block(s, 0.1, 0.1, 0.8, 0.8, 6, '#ECE6DA', win='balcony', per=(2, 2), wu=0.2, wh=5, courses='#C8C2B8', **W05)
    if s.state in ('normal', 'obra'):
        s.fq(b, 'L', 0.06, FH * 2, 0.68, 22, '#E86A2E')
        s.fq(b, 'L', 0.12, FH * 2 + 14, 0.56, 4, '#FFFFFF')
        s.fq(b, 'L', 0.12, FH * 2 + 6, 0.4, 3, '#FFFFFF')
        s.fq(b, 'L', 0.12, FH * 2 + 2, 0.3, 2, '#1E4A8A')
    s.box(0.5, 0.2, 0.3, 0.3, b['top'], 4, '#C8C2B8')
    return b


def urbanizacion(s):
    gr(s, 2, 2, pave=False)
    s.poly([s.p(0.05, 0.05, 0), s.p(1.95, 0.05, 0), s.p(1.95, 1.95, 0), s.p(0.05, 1.95, 0)], '#5E9A50')
    s.poly([s.p(0.9, 0.9, 0), s.p(1.85, 0.9, 0), s.p(1.85, 1.85, 0), s.p(0.9, 1.85, 0)], '#E8E2D0')
    s.poly([s.p(1.0, 1.0, 0), s.p(1.75, 1.0, 0), s.p(1.75, 1.75, 0), s.p(1.0, 1.75, 0)], '#3AB8D8')
    s.poly([s.p(1.1, 1.1, 0), s.p(1.3, 1.1, 0), s.p(1.3, 1.3, 0), s.p(1.1, 1.3, 0)], '#8AE0F0')
    b = block(s, 0.1, 0.1, 0.7, 1.8, 3, '#F0DCC0', win='balcony', per=(2, 5), wu=0.18, wh=5, roof='hip', roofc='#B8503A', **W05)
    b2 = block(s, 0.8, 0.1, 1.1, 0.7, 3, '#E8D0B0', win='balcony', per=(3, 2), wu=0.18, wh=5, roof='hip', roofc='#B8503A', **W05)
    for (i, j) in [(1.88, 1.88), (0.95, 1.9)]:
        s.tree2(i, j, 'palm', '#4FA36B', 16)
    for k in range(3):
        x, y = s.p(1.1 + k * 0.25, 0.95, 0); s.rect(x - 2, y - 1, 5, 1, '#ECE4D0'); s.rect(x - 2, y - 2, 1, 1, '#ECE4D0')
    return b


def torre_bala(s):
    gr(s)
    lit = s.state in LIT
    rf = lambda t: 0.36 * (1 - t ** 3) ** 0.5 + 0.01
    s.revolve(0.5, 0.5, 0, 108, rf, '#3E5FA8', ribs=10, bands=[(0, 0.2, '#C8402E'), (0.2, 0.4, '#E86A2E'), (0.4, 0.6, '#3E8AC8'), (0.6, 0.85, '#5AA6D6'), (0.85, 1, '#BCE0EC')])
    for k in range(60):
        z = s.rnd.random() * 100
        r = rf(z / 108)
        a = s.rnd.uniform(-0.3, 1.6)
        x, y = s.p(0.5 + r * 0.96 * math.cos(a), 0.5 + r * 0.96 * math.sin(a), z)
        s.px(x, y, '#FFFFFF' if (lit and s.rnd.random() < 0.5) else '#1E2A4A')
    return dict(i0=0.15, j0=0.15, w=0.7, d=0.7, z0=0, h=100, wall='#3E5FA8')


def museo_titanio(s):
    gr(s, 2, 2)
    s.poly([s.p(0.05, 1.4, 0), s.p(1.95, 1.4, 0), s.p(1.95, 1.95, 0), s.p(0.05, 1.95, 0)], '#3A8AB0')
    s.box(0.2, 0.2, 1.0, 1.0, 0, 20, '#D8C8A0')
    s.texture(dict(i0=0.2, j0=0.2, w=1.0, d=1.0, z0=0, h=20, wall='#D8C8A0'), 'L', 'stone')
    for (i, j, r, z, h, c) in [(0.6, 0.6, 0.45, 16, 16, '#B8C0C8'), (1.25, 0.55, 0.34, 10, 14, '#C8CED4'), (0.9, 1.1, 0.4, 4, 14, '#D4D8DC'), (1.45, 1.15, 0.28, 0, 22, '#B0B8C0'), (0.5, 1.25, 0.24, 6, 10, '#C8CED4')]:
        s.revolve(i, j, z, h, lambda t, r=r: r * (1 - 0.75 * t ** 1.5) * (0.9 + 0.1 * math.sin(t * 7)), c, ribs=3)
    s.box(1.2, 0.2, 0.6, 0.4, 0, 18, '#7FB0CC', top='#BCE0EC')
    s.vstripes(dict(i0=1.2, j0=0.2, w=0.6, d=0.4, z0=0, h=18, wall='#7FB0CC'), 'R', 4, 0, 18, '#ECE4D0', 0.02)
    s.statue(1.7, 1.7, '#C84A8A', '#ECE4D0')
    return dict(i0=0.2, j0=0.2, w=1.6, d=1.6, z0=0, h=40, wall='#C8CCD0')


def multicines(s):
    gr(s, 2, 2)
    for k in range(5):
        s.car(0.15 + k * 0.3, 1.75, s.rnd.choice(['#C8553D', '#ECE4D0', '#2A2A2A', '#5AA6D6', '#C8C8C8']))
    b = s.box(0.15, 0.15, 1.7, 1.35, 0, 26, '#2A2A3A')
    s.texture(b, 'L', 'panels', '#3A3A4A'); s.texture(b, 'R', 'panels', '#3A3A4A')
    lit = s.state in LIT or s.state == 'normal'
    s.fq(b, 'L', 0.4, 0, 0.9, 10, '#7FB0CC'); s.vstripes(dict(b, z0=0, h=10), 'L', 6, 0, 10, '#ECE4D0', 0.02)
    for k in range(4):
        s.fq(b, 'L', 0.1 + k * 0.42, 13, 0.3, 9, s.rnd.choice(['#C8553D', '#3E5FA8', '#E3A93B', '#4FA36B', '#C84A8A']))
        s.fq(b, 'L', 0.12 + k * 0.42, 14, 0.26, 2, '#ECE4D0')
    s.sign(b, 'R', 0.15, 16, 1.0, 5, '#C8402E', '#F2C25F' if lit else '#6A4A3A')
    s.course(b, 24, '#E3A93B' if lit else '#6A5A3A')
    s.box(1.3, 1.3, 0.3, 0.3, 26, 8, '#2A2A3A'); s.sign(dict(i0=1.3, j0=1.3, w=0.3, d=0.3, z0=26, h=8, wall='#2A2A3A'), 'L', 0.02, 28, 0.26, 4, '#E3A93B', '#2A2622')
    return b


def chalet_piscina(s):
    gr(s, pave=False)
    s.poly([s.p(0.03, 0.03, 0), s.p(0.97, 0.03, 0), s.p(0.97, 0.97, 0), s.p(0.03, 0.97, 0)], '#5E9A50')
    s.poly([s.p(0.55, 0.5, 0), s.p(0.92, 0.5, 0), s.p(0.92, 0.92, 0), s.p(0.55, 0.92, 0)], '#E8E2D0')
    s.poly([s.p(0.6, 0.55, 0), s.p(0.87, 0.55, 0), s.p(0.87, 0.87, 0), s.p(0.6, 0.87, 0)], '#3AB8D8')
    b = block(s, 0.1, 0.1, 0.55, 0.42, 2, '#F4EAD8', win='sash', per=(2, 1), wu=0.14, wh=5, roof='hip', roofc='#C8603A', **W05)
    s.tree2(0.15, 0.85, 'palm', '#4FA36B', 15)
    for k in range(2):
        x, y = s.p(0.62, 0.6 + k * 0.12, 0); s.rect(x - 4, y - 1, 4, 1, '#ECE4D0')
    return b


def grua_obra(s):
    gr(s, pave=False)
    s.poly([s.p(0.03, 0.03, 0), s.p(0.97, 0.03, 0), s.p(0.97, 0.97, 0), s.p(0.03, 0.97, 0)], '#8A7458')
    b = s.box(0.15, 0.15, 0.6, 0.6, 0, 4 * FH, '#B8B4AC')
    for f in range(1, 5):
        s.box(0.12, 0.12, 0.66, 0.66, f * FH - 1, 1, '#9A968E', rim=False)
    for f in range(4):
        for k in range(3):
            x, y = s.fp(b, 'L', 0.05 + k * 0.22, f * FH + 1); s.rect(x, y - 5, 1, 5, '#7A766E')
    # grúa torre
    x, y = s.p(0.85, 0.85, 0)
    for k in range(0, 96, 4):
        s.line((x - 1, y - k), (x + 1, y - k - 4), '#E3A93B'); s.line((x - 1, y - k - 4), (x + 1, y - k), '#E3A93B')
    s.rect(x - 2, y - 96, 1, 96, '#E3A93B'); s.rect(x + 1, y - 96, 1, 96, '#E3A93B')
    s.rect(x - 3, y - 102, 7, 6, '#ECE4D0'); s.rect(x - 2, y - 100, 2, 2, '#4A5A62', raw=True)
    s.line((x - 34, y - 98), (x + 14, y - 98), '#E3A93B'); s.line((x - 34, y - 96), (x + 14, y - 96), '#E3A93B')
    for k in range(-34, 14, 4):
        s.line((x + k, y - 96), (x + k + 2, y - 98), '#E3A93B')
    s.rect(x + 10, y - 97, 4, 4, '#6A6A6A')
    s.line((x, y - 110), (x - 34, y - 98), '#9A9A9A'); s.line((x, y - 110), (x + 14, y - 98), '#9A9A9A'); s.rect(x, y - 110, 1, 8, '#E3A93B')
    s.line((x - 22, y - 96), (x - 22, y - 60), '#2A2622'); s.rect(x - 24, y - 60, 5, 2, '#7A766E')
    return b


def rotonda(s):
    gr(s, pave=False)
    s.ground('#5A5C58')
    s.revolve(0.5, 0.5, 0, 2, lambda t: 0.4, '#ECE4D0', top=False)
    s.revolve(0.5, 0.5, 2, 0.5, lambda t: 0.36, '#5E9A50')
    for k in range(5):
        a = 2 * math.pi * k / 5
        x, y = s.p(0.5 + 0.25 * math.cos(a), 0.5 + 0.25 * math.sin(a), 3); s.px(x, y, '#E2675B', raw=True); s.px(x + 1, y, '#F2C25F', raw=True)
    s.box(0.42, 0.42, 0.16, 0.16, 2, 4, '#B8B4AC')
    x, y = s.p(0.5, 0.5, 6)
    s.poly([(x - 1, y), (x + 1, y), (x + 8, y - 26), (x + 5, y - 27)], '#C8CCD0')
    s.poly([(x - 1, y), (x - 9, y - 18), (x - 6, y - 20), (x + 1, y - 2)], '#E86A2E')
    return dict(i0=0.1, j0=0.1, w=0.8, d=0.8, z0=0, h=4, wall='#B8B4AC')


ERAS2['1980'] = [
    ('bloque_ladrillo', 'Bloque de ladrillo', 1, 1, bloque_ladrillo, 'mejora'), ('torre_brutalista', 'Torre brutalista', 2, 2, torre_brutalista, 'mejora'),
    ('local_persiana', 'Local con persiana', 1, 1, local_persiana, 'mejora'), ('nave_abandonada', 'Nave industrial', 2, 2, nave_abandonada, 'mejora'),
    ('oficinas_70', 'Oficinas de cristal ahumado', 1, 1, oficinas_70, 'mejora'),
    ('torre_telefonica', 'Torre de comunicaciones', 1, 1, torre_telefonica, 'monumento'), ('polideportivo', 'Polideportivo', 2, 2, polideportivo, 'nuevo'),
    ('colmena', 'Bloque colmena', 2, 1, colmena, 'nuevo'), ('mercado_barrio', 'Mercado de barrio', 2, 1, mercado_barrio, 'nuevo'),
    ('recreativos', 'Salón recreativo', 1, 1, recreativos, 'nuevo'), ('gasolinera_80', 'Gasolinera', 1, 1, gasolinera_80, 'nuevo')]
ERAS2['2005'] = [
    ('adosados', 'Adosados', 2, 1, adosados, 'mejora'), ('torre_cristal', 'Torre de cristal', 1, 1, torre_cristal, 'mejora'),
    ('centro_comercial', 'Centro comercial', 2, 2, centro_comercial, 'mejora'), ('obra_nueva', 'Obra nueva «a estrenar»', 1, 1, obra_nueva, 'mejora'),
    ('urbanizacion', 'Urbanización con piscina', 2, 2, urbanizacion, 'mejora'),
    ('torre_bala', 'Torre bala', 1, 1, torre_bala, 'monumento'), ('museo_titanio', 'Museo de titanio', 2, 2, museo_titanio, 'nuevo'),
    ('multicines', 'Multicines', 2, 2, multicines, 'nuevo'), ('chalet_piscina', 'Chalet con piscina', 1, 1, chalet_piscina, 'nuevo'),
    ('grua_obra', 'Solar con grúa', 1, 1, grua_obra, 'nuevo'), ('rotonda', 'Rotonda con escultura', 1, 1, rotonda, 'nuevo')]


# ================================================================== 2020
W20 = dict(glass='#3A524E', lit='#E3A93B', frame='#2A2A2A')


def bloque_terrazas(s):
    gr(s)
    b = block(s, 0.15, 0.15, 0.7, 0.7, 7, '#E8E4DA', win='strip', per=(2, 2), wu=0.24, wh=5, shops=[('#3E5A4A', '#E8E4DA')], **W20)
    for f in range(1, 7):
        t = s.box(0.1, 0.85, 0.8, 0.1, f * FH - 1, 1, '#C8C4BA', rim=False)
        s.line(s.p(0.1, 0.95, f * FH + 2), s.p(0.9, 0.95, f * FH + 2), '#9CB8B4')
        if s.state != 'ruina' and s.rnd.random() < 0.8:
            x, y = s.fp(t, 'L', 0.1 + s.rnd.random() * 0.5, f * FH + 1)
            s.rect(x, y - 2, 3, 2, '#4FA36B'); s.px(x + 1, y - 3, '#6FC08B')
    s.solar(0.25, 0.3, 0.5, 0.4, b['top'], 3)
    return b


def piso_turistico(s):
    gr(s)
    b = block(s, 0.1, 0.1, 0.8, 0.8, 4, '#D8A878', win='balcony', per=(2, 2), wu=0.16, wh=5, frame='#F0E0C8', glass='#3A3028', lit='#E3A93B', shops=[None])
    s.fq(b, 'L', 0.32, 0, 0.16, 7, '#3E5A4A')
    x, y = s.fp(b, 'L', 0.55, 5); s.rect(x, y - 3, 3, 3, '#1A1A1A'); s.px(x + 1, y - 2, '#E3A93B', raw=True)
    for k in range(3):
        x, y = s.p(0.3 + k * 0.15, 0.98, 0); s.rect(x - 1, y - 4, 3, 4, s.rnd.choice(['#C8553D', '#3E5FA8', '#2A2A2A'])); s.px(x, y - 5, '#9A9A9A')
    s.parapet(dict(b, h=b['h']), '#C89868', 2)
    x, y = s.p(0.5, 0.5, b['h'] + 2); s.rect(x - 4, y - 6, 8, 1, '#ECE4D0'); s.rect(x, y - 5, 1, 5, '#9A9A9A')
    return b


def coworking(s):
    gr(s, 2, 2)
    b = s.box(0.1, 0.1, 1.8, 1.8, 0, FH + 8, '#9A5A40')
    s.texture(b, 'L', 'brick'); s.texture(b, 'R', 'brick')
    s.grid(b, 'L', 1, 5, 0, FH + 8, 0.26, 12, 'sash', frame='#2A2A2A', glass='#2E3A3A', lit='#F2D08A')
    s.grid(b, 'R', 1, 5, 0, FH + 8, 0.26, 12, 'sash', frame='#2A2A2A', glass='#2E3A3A', lit='#F2D08A')
    z = b['h']
    for k in range(5):
        i0 = 0.1 + k * 0.36
        s.poly([s.p(i0, 0.1, z), s.p(i0, 1.9, z), s.p(i0 + 0.08, 1.9, z + 9), s.p(i0 + 0.08, 0.1, z + 9)], '#BCE0EC')
        s.poly([s.p(i0 + 0.08, 0.1, z + 9), s.p(i0 + 0.08, 1.9, z + 9), s.p(i0 + 0.36, 1.9, z), s.p(i0 + 0.36, 0.1, z)], '#3A3A3A')
        s.poly([s.p(i0, 1.9, z), s.p(i0 + 0.36, 1.9, z), s.p(i0 + 0.08, 1.9, z + 9)], '#7A4632')
    s.sign(b, 'L', 0.2, 13, 0.5, 3, '#E86AA0' if s.state != 'ruina' else '#5A4A4A', '#FFFFFF')
    for k in range(4):
        x, y = s.p(0.3 + k * 0.12, 1.96, 0); s.rect(x - 1, y - 3, 3, 1, '#2A2A2A'); s.px(x - 1, y - 2, '#2A2A2A'); s.px(x + 1, y - 2, '#2A2A2A')
    s.tree2(1.95, 0.4, h=10); s.tree2(1.95, 1.2, h=10)
    return b


def dark_kitchen(s):
    gr(s)
    b = s.box(0.1, 0.1, 0.8, 0.8, 0, FH + 6, '#5A6E6A')
    s.texture(b, 'L', 'metal'); s.texture(b, 'R', 'metal')
    for k in range(2):
        s.fq(b, 'L', 0.06 + k * 0.36, 0, 0.32, 9, '#8A9692')
        for z in range(1, 9, 2):
            s.fq(b, 'L', 0.06 + k * 0.36, z, 0.32, 1, '#6E7A76')
    s.fq(b, 'R', 0.2, 2, 0.4, 6, '#2E3A3A')
    s.box(0.5, 0.3, 0.25, 0.2, b['h'], 5, '#9AA6A2'); s.ac(0.2, 0.3, b['h'] + 1); s.ac(0.2, 0.55, b['h'] + 1)
    if s.state != 'ruina':
        for k, col in enumerate(['#4FC08D', '#E86A2E', '#E3A93B']):
            x, y = s.p(0.25 + k * 0.25, 1.0, 0)
            s.rect(x, y - 5, 4, 4, col, raw=True); s.rect(x - 1, y - 1, 6, 1, '#1A1A1A', raw=True); s.px(x - 1, y, '#1A1A1A'); s.px(x + 4, y, '#1A1A1A')
    return b


def rehabilitado(s):
    gr(s, 2, 1)
    b = s.box(0.1, 0.1, 1.8, 0.8, 0, 5 * FH, '#C8D8C8')
    pal = ['#C8D8C8', '#E8C8A8', '#A8C8D8', '#E8E0B0']
    for k in range(6):
        s.fq(b, 'L', k * 0.3, 0, 0.3, b['h'], pal[k % 4])
    s.grid(b, 'L', 5, 6, 0, FH, 0.14, 5, 'balcony', frame='#FFFFFF', glass='#3A524E', lit='#E3A93B')
    s.grid(b, 'R', 5, 2, 0, FH, 0.14, 5, 'balcony', frame='#FFFFFF', glass='#3A524E', lit='#E3A93B')
    s.solar(0.25, 0.25, 1.5, 0.45, b['h'], 5)
    x, y = s.p(1.9, 0.95, 0); s.rect(x, y - 8, 2, 8, '#ECE4D0'); s.rect(x, y - 7, 2, 2, '#4FC08D')
    return b


def torre_jardines(s):
    gr(s)
    b = s.box(0.2, 0.2, 0.6, 0.6, 0, 13 * FH, '#E8E4DA')
    s.texture(b, 'L', 'panels'); s.texture(b, 'R', 'panels')
    for f in range(13):
        z = f * FH
        for face in 'LR':
            s.fq(b, face, 0.06, z + 2, 0.48, 5, '#3A524E')
            if s.state in LIT and s.rnd.random() < 0.4:
                s.fq(b, face, 0.1 + s.rnd.random() * 0.3, z + 3, 0.1, 3, '#E3A93B')
        if f:
            t = s.box(0.12, 0.12, 0.76, 0.76, z, 1, '#C8C4BA', rim=False, ao=False)
            for k in range(5):
                if s.state != 'ruina' or s.rnd.random() < 0.3:
                    i, j = (0.12 + s.rnd.random() * 0.76, 0.88) if k % 2 else (0.88, 0.12 + s.rnd.random() * 0.76)
                    x, y = s.p(i, j, z + 1)
                    col = s.rnd.choice(['#4FA36B', '#3E8A58', '#6FC08B'])
                    s.dr.ellipse([x - 2, y - 4, x + 2, y], fill=s.c(col) + (255,))
    s.box(0.12, 0.12, 0.76, 0.76, 13 * FH, 1, '#C8C4BA')
    for k in range(4):
        s.tree2(0.25 + k * 0.15, 0.3 + (k % 2) * 0.3, h=8) if False else None
    x, y = s.p(0.5, 0.5, 13 * FH + 1); s.dr.ellipse([x - 7, y - 10, x + 7, y - 1], fill=s.c('#4FA36B') + (255,)); s.dr.ellipse([x - 5, y - 10, x + 2, y - 5], fill=s.c('#6FC08B') + (255,))
    return b


def coliving(s):
    gr(s, 2, 1)
    b = block(s, 0.1, 0.12, 1.8, 0.76, 5, '#D8C8B0', win='strip', per=(6, 2), wu=0.2, wh=5, shops=[('#2A2A2A', '#D8C8B0')], **W20)
    s.texture(b, 'L', 'wood', '#B89A78')
    for f in range(1, 5):
        s.balcony(b, 'L', 0.1, f * FH + 1, 1.6, '#2A2A2A')
    s.box(0.2, 0.25, 0.6, 0.5, b['top'], 6, '#8A6A4A')
    for k in range(3):
        x, y = s.p(1.1 + k * 0.25, 0.5, b['top'] + 1); s.rect(x - 3, y - 6, 7, 1, s.rnd.choice(['#E2675B', '#ECE4D0', '#F2C25F'])); s.rect(x, y - 5, 1, 5, '#9A9A9A')
    return b


def electrolinera(s):
    gr(s)
    for k in range(3):
        x, y = s.p(0.25 + k * 0.25, 0.85, 0); s.rect(x - 4, y - 1, 9, 1, '#ECE4D0')
    for k in range(3):
        s.box(0.2 + k * 0.25, 0.3, 0.06, 0.06, 0, 7, '#ECE8E0'); x, y = s.fp(dict(i0=0.2 + k * 0.25, j0=0.3, w=0.06, d=0.06, z0=0, h=7, wall='#ECE8E0'), 'L', 0.0, 5); s.px(x + 1, y, '#4FC08D', raw=True)
    for (i, j) in [(0.12, 0.2), (0.88, 0.2), (0.12, 0.75), (0.88, 0.75)]:
        x, y = s.p(i, j, 0); s.rect(x, y - 15, 1, 15, '#9A9A9A')
    s.solar(0.08, 0.15, 0.84, 0.66, 15, 4)
    s.car(0.25, 0.48, '#ECE4D0', 'j'); s.car(0.75, 0.48, '#3E5FA8', 'j')
    return dict(i0=0.1, j0=0.1, w=0.8, d=0.8, z0=0, h=15, wall='#ECE8E0')


def mercado_gourmet(s):
    gr(s, 2, 1)
    b = s.box(0.1, 0.12, 1.8, 0.76, 0, 16, '#A85A3C')
    s.texture(b, 'L', 'brick'); s.texture(b, 'R', 'brick')
    for k in range(4):
        s.win(b, 'L', 0.12 + k * 0.43, 2, 0.3, 11, 'arch', frame='#2A2A2A', glass='#2E3A3A', lit='#F2D08A', sill=False)
    s.win(b, 'R', 0.2, 2, 0.36, 11, 'arch', frame='#2A2A2A', glass='#2E3A3A', lit='#F2D08A', sill=False)
    s.barrel(0.1, 1.9, 0.5, 0.38, 16, '#BCE0EC', end='#2A2A2A', ribs=0.12, rise=11)
    lit = s.state in LIT or s.state == 'normal'
    for k in range(18):
        x, y = s.p(0.15 + k * 0.1, 1.0, 9 + 2 * math.sin(k * 0.9))
        s.px(x, y, '#FFE28A' if lit else '#6A5A3A', raw=True)
    for k in range(3):
        x, y = s.p(0.4 + k * 0.5, 1.0, 0); s.rect(x - 1, y - 4, 4, 1, '#2A2A2A'); s.rect(x, y - 3, 1, 3, '#2A2A2A')
    s.sign(b, 'R', 0.12, 13, 0.5, 2, '#2A2A2A', '#F2C25F')
    return b


def fachada_verde(s):
    gr(s)
    b = block(s, 0.12, 0.12, 0.76, 0.76, 8, '#5A6A62', win='strip', per=(2, 2), wu=0.16, wh=5, shops=[None], **W20)
    for face in 'LR':
        for k in range(160):
            u, z = s.rnd.random() * 0.76, FH + s.rnd.random() * (b['h'] - FH)
            x, y = s.fp(b, face, u, z)
            col = s.rnd.choice(['#4FA36B', '#3E8A58', '#6FC08B', '#2E6E48'])
            if s.state == 'ruina':
                col = s.rnd.choice(['#6A5A3A', '#5A4A32'])
            s.px(x, y, col); s.px(x + 1, y, col)
    s.green = None
    g = s.box(0.14, 0.14, 0.72, 0.72, b['top'], 1, '#4F8A4A', top='#5FA35A')
    s.tree2(0.4, 0.4, h=9); s.tree2(0.65, 0.6, h=8)
    return b


def hotel_boutique(s):
    gr(s)
    b = block(s, 0.12, 0.12, 0.76, 0.76, 6, '#B85A3C', win='sash', tex='brick', per=(2, 2), wu=0.16, wh=5, frame='#2A2A2A', glass='#2E3A3A', lit='#F2D08A', shops=[('#2A2A2A', '#B85A3C')], courses='#9A4A30')
    s.box(0.2, 0.2, 0.25, 0.25, b['top'], 6, '#2A2A2A')
    for k in range(3):
        x, y = s.p(0.5 + k * 0.12, 0.55 + (k % 2) * 0.2, b['top'] + 1)
        s.rect(x - 3, y - 7, 7, 2, s.rnd.choice(['#ECE4D0', '#E3A93B'])); s.rect(x, y - 5, 1, 5, '#9A9A9A')
    lit = s.state in LIT
    for k in range(12):
        x, y = s.p(0.15 + k * 0.06, 0.86, b['top'] + 4)
        s.px(x, y, '#FFE28A' if lit else '#6A5A3A', raw=True)
    return b


ERAS2['2020'] = [
    ('bloque_terrazas', 'Bloque con terrazas', 1, 1, bloque_terrazas, 'mejora'), ('piso_turistico', 'Piso turístico', 1, 1, piso_turistico, 'mejora'),
    ('coworking', 'Coworking en nave', 2, 2, coworking, 'mejora'), ('dark_kitchen', 'Cocina fantasma', 1, 1, dark_kitchen, 'mejora'),
    ('rehabilitado', 'Bloque rehabilitado', 2, 1, rehabilitado, 'mejora'),
    ('torre_jardines', 'Torre de jardines', 1, 1, torre_jardines, 'monumento'), ('coliving', 'Coliving', 2, 1, coliving, 'nuevo'),
    ('mercado_gourmet', 'Mercado gourmet', 2, 1, mercado_gourmet, 'nuevo'), ('hotel_boutique', 'Hotel boutique', 1, 1, hotel_boutique, 'nuevo'),
    ('fachada_verde', 'Fachada vegetal', 1, 1, fachada_verde, 'nuevo'), ('electrolinera', 'Electrolinera', 1, 1, electrolinera, 'nuevo')]


# ================================================================== 2050
W50 = dict(glass='#2E4A56', lit='#7FE0D8', frame='#ECE4D0')


def torre_madera(s):
    gr(s)
    b = s.box(0.12, 0.12, 0.76, 0.76, 0, 12 * FH, '#C8A070', top='#4FA36B')
    s.texture(b, 'L', 'wood'); s.texture(b, 'R', 'wood')
    s.grid(b, 'L', 12, 2, 0, FH, 0.24, 5, 'strip', frame=None, glass='#2E4A56', lit='#7FE0D8')
    s.grid(b, 'R', 12, 2, 0, FH, 0.24, 5, 'strip', frame=None, glass='#2E4A56', lit='#7FE0D8')
    for f in range(12):
        s.fq(b, 'L', 0, f * FH, 0.76, 1, '#8A6A44'); s.fq(b, 'R', 0, f * FH, 0.76, 1, '#8A6A44')
        if s.state != 'ruina' or s.rnd.random() < 0.3:
            for face in 'LR':
                u = s.rnd.choice([0.0, 0.62])
                x, y = s.fp(b, face, u + 0.07, f * FH + 1)
                s.dr.ellipse([x - 3, y - 3, x + 3, y + 1], fill=s.c(s.rnd.choice(['#4FA36B', '#3E8A58'])) + (255,))
    x, y = s.p(0.5, 0.5, b['h'])
    for k in range(3):
        xx = x - 8 + k * 8
        s.rect(xx, y - 10, 1, 10, '#ECE4D0'); s.line((xx - 3, y - 13), (xx + 3, y - 7), '#ECE4D0'); s.line((xx - 3, y - 7), (xx + 3, y - 13), '#ECE4D0')
    return b


def anfibio(s):
    s.poly([s.p(0, 0, 0), s.p(1, 0, 0), s.p(1, 1, 0), s.p(0, 1, 0)], '#2D6F8F')
    for k in range(5):
        x, y = s.p(0.1 + k * 0.2, 0.9, 0); s.rect(x - 3, y, 6, 1, '#7FC3DA')
    s.box(0.08, 0.08, 0.84, 0.84, 0, 5, '#9AA6AA')
    for (a, c) in [(0.15, 0.15), (0.85, 0.15), (0.85, 0.85), (0.15, 0.85)]:
        s.line(s.p(a, c, 5), s.p(a, c, 30), '#5A6A6E')
    b = block(s, 0.12, 0.12, 0.76, 0.76, 3, '#E8EEF0', win='strip', per=(2, 2), wu=0.26, wh=5, z0=6, roof='green', **W50)
    s.box(0.1, 0.9, 0.5, 0.25, 0, 1, '#C8A070')
    x, y = s.p(0.7, 1.0, 0); s.rect(x - 4, y - 2, 8, 2, '#ECE4D0'); s.rect(x - 1, y - 6, 1, 4, '#ECE4D0'); s.rect(x, y - 6, 3, 3, '#ECE4D0')
    return b


def granja_vertical(s):
    gr(s, 2, 2)
    b = s.box(0.2, 0.2, 1.6, 1.6, 0, 9 * FH, '#7FA2B8', top='#4FA36B', right='#5A7E96')
    on = s.state in LIT or s.state == 'normal'
    for f in range(9):
        for face in 'LR':
            s.fq(b, face, 0.05, f * FH + 1, 1.5, 6, '#2E4A56')
            for k in range(14):
                x, y = s.fp(b, face, 0.08 + k * 0.105, f * FH + 2)
                s.px(x, y - 1, '#4FA36B' if s.state != 'ruina' else '#5A5A4A'); s.px(x, y - 2, '#6FC08B' if s.state != 'ruina' else '#4A4A3E')
            if on:
                s.fq(b, face, 0.08, f * FH + 6, 1.44, 1, '#E86AC8', raw=True)
    s.revolve(1.0, 1.0, 9 * FH, 14, lambda t: 0.5 * (1 - t ** 2) ** 0.5 + 0.02, '#BCE0EC', ribs=10)
    s.revolve(0.25, 1.75, 0, 20, lambda t: 0.15, '#9AA6AA', bands=[(0.9, 1, '#7FA2B8')])
    return b


def hub_drones(s):
    gr(s)
    b = s.box(0.32, 0.32, 0.36, 0.36, 0, 10 * FH, '#C8D6DE')
    s.grid(b, 'L', 10, 1, 0, FH, 0.2, 5, 'strip', frame=None, **{k: v for k, v in W50.items() if k != 'frame'})
    s.grid(b, 'R', 10, 1, 0, FH, 0.2, 5, 'strip', frame=None, **{k: v for k, v in W50.items() if k != 'frame'})
    for z in (3 * FH, 6 * FH, 10 * FH):
        s.revolve(0.5, 0.5, z, 2, lambda t: 0.44, '#7FA2B8')
        x, y = s.p(0.5, 0.5, z + 2)
        s.dr.ellipse([x - 6, y - 3, x + 6, y + 3], outline=s.c('#E3A93B') + (255,))
    if s.state in LIT or s.state == 'normal':
        for (dx, dy) in [(-14, -6), (13, -14), (-12, -26), (12, -34)]:
            x, y = s.p(0.5, 0.5, 10 * FH)
            s.rect(x + dx - 2, y + dy, 5, 1, '#ECE4D0', raw=True); s.px(x + dx - 2, y + dy - 1, '#ECE4D0', raw=True); s.px(x + dx + 2, y + dy - 1, '#ECE4D0', raw=True)
            s.rect(x + dx, y + dy + 1, 1, 1, '#E3A93B', raw=True)
    return b


def bloque_muro(s):
    gr(s, 2, 1)
    s.poly([s.p(0, 0.92, 0), s.p(2, 0.92, 0), s.p(2, 1, 0), s.p(0, 1, 0)], '#2D6F8F')
    b = block(s, 0.15, 0.12, 1.7, 0.62, 5, '#B8A890', win='strip', per=(6, 2), wu=0.16, wh=5, roof='flat', **W50)
    s.fq(b, 'L', 0, 0, 1.7, 4, '#5A6A6E')
    w = s.box(0.05, 0.8, 1.9, 0.1, 0, 9, '#8A9AA0')
    s.texture(w, 'L', 'panels'); s.fq(w, 'L', 0, 6, 1.9, 1, '#E3A93B')
    s.solar(0.25, 0.2, 1.5, 0.45, b['top'], 5)
    return b


def arcologia(s):
    gr(s, 2, 2)
    z = 0
    lv = [(0.08, 1.84, 16), (0.24, 1.52, 16), (0.4, 1.2, 16), (0.56, 0.88, 16), (0.72, 0.56, 14), (0.86, 0.28, 12)]
    for k, (o, w, h) in enumerate(lv):
        b = s.box(o, o, w, w, z, h, '#E0E6E8', top='#5FA35A')
        for face in 'LR':
            s.fq(b, face, 0.04, z + 3, w - 0.08, h - 6, '#2E4A56')
            s.vstripes(dict(b, z0=z + 3, h=h - 6), face, max(2, int(w / 0.12)), z + 3, h - 6, '#ECE4D0', 0.015)
            for m in range(int(w * 6)):
                if s.state in LIT and s.rnd.random() < 0.4:
                    x, y = s.fp(b, face, 0.06 + s.rnd.random() * (w - 0.12), z + 4 + s.rnd.random() * (h - 9))
                    s.px(x, y, '#7FE0D8', raw=True)
        for m in range(int(w * 5)):
            i = o + 0.05 + s.rnd.random() * 0.08
            j = o + 0.1 + s.rnd.random() * (w - 0.2)
            for (ii, jj) in [(i + w - 0.13, j), (j, i + w - 0.13)]:
                x, y = s.p(ii, jj, z + h)
                s.dr.ellipse([x - 2, y - 3, x + 2, y], fill=s.c(s.rnd.choice(['#4FA36B', '#3E8A58', '#6FC08B'])) + (255,))
        z += h
    x, y = s.p(1.0, 1.0, z)
    s.rect(x, y - 16, 1, 16, '#ECE4D0'); s.px(x, y - 17, '#7FE0D8', raw=True)
    return dict(i0=0.08, j0=0.08, w=1.84, d=1.84, z0=0, h=40, wall='#E0E6E8')


def biodomo(s):
    gr(s, 2, 2)
    s.revolve(1.0, 1.0, 0, 3, lambda t: 0.92, '#9AA6AA')
    s.revolve(1.0, 1.0, 3, 40, lambda t: 0.9 * (1 - t ** 2) ** 0.5 + 0.02, '#9CD0D8', ribs=16, light=1.0)
    for k in range(40):
        a = s.rnd.uniform(0, 2 * math.pi); r = s.rnd.uniform(0, 0.7)
        x, y = s.p(1.0 + r * math.cos(a), 1.0 + r * math.sin(a), 3 + 30 * (1 - (r / 0.9) ** 2) ** 0.5)
        s.px(x, y, s.rnd.choice(['#4FA36B', '#6FC08B', '#ECE4D0']))
    for k in range(6):
        a = 2 * math.pi * k / 6
        for t in range(0, 20, 2):
            pass
    return dict(i0=0.1, j0=0.1, w=1.8, d=1.8, z0=0, h=40, wall='#9CD0D8')


def hyperloop(s):
    gr(s, 2, 1)
    for k in range(4):
        s.box(0.2 + k * 0.5, 0.42, 0.08, 0.16, 0, 14, '#9AA6AA')
    s.barrel(0.0, 2.0, 0.5, 0.18, 14, '#ECE8E0', end='#C8D6DE', ribs=0.25, rise=6, glass=False)
    s.revolve(1.0, 0.5, 14, 1, lambda t: 0.1, '#7FE0D8')
    st = s.box(0.6, 0.62, 0.8, 0.3, 0, 12, '#C8D6DE', top='#4FA36B')
    s.fq(st, 'L', 0.05, 1, 0.7, 9, '#2E4A56'); s.vstripes(dict(st, z0=1, h=9), 'L', 6, 1, 9, '#ECE4D0', 0.015)
    s.sign(st, 'L', 0.2, 10, 0.4, 2, '#7FE0D8', '#1B2C33')
    return st


def torre_eolica(s):
    gr(s)
    b = s.box(0.25, 0.25, 0.5, 0.5, 0, 9 * FH, '#E0E6E8')
    s.grid(b, 'L', 9, 2, 0, FH, 0.18, 5, 'strip', frame=None, **{k: v for k, v in W50.items() if k != 'frame'})
    s.grid(b, 'R', 9, 2, 0, FH, 0.18, 5, 'strip', frame=None, **{k: v for k, v in W50.items() if k != 'frame'})
    for z in (3 * FH, 6 * FH):
        s.box(0.22, 0.22, 0.56, 0.56, z, 1, '#9AA6AA')
    for k in range(3):
        z = 9 * FH + k * 10
        s.revolve(0.5, 0.5, z, 9, lambda t: 0.14 + 0.06 * math.sin(t * math.pi), '#ECE8E0', ribs=3)
    x, y = s.p(0.5, 0.5, 9 * FH + 30); s.rect(x, y - 5, 1, 5, '#ECE4D0'); s.px(x, y - 6, '#7FE0D8', raw=True)
    return b


def escuela_solar(s):
    gr(s, 2, 1)
    s.poly([s.p(1.3, 0.1, 0), s.p(1.95, 0.1, 0), s.p(1.95, 0.9, 0), s.p(1.3, 0.9, 0)], '#4FA36B')
    b = s.box(0.1, 0.12, 1.15, 0.76, 0, 2 * FH + 2, '#C8A070')
    s.texture(b, 'L', 'wood'); s.texture(b, 'R', 'wood')
    s.grid(b, 'L', 2, 4, 0, FH, 0.2, 6, 'sash', frame='#ECE4D0', glass='#2E4A56', lit='#7FE0D8')
    s.grid(b, 'R', 2, 2, 0, FH, 0.2, 6, 'sash', frame='#ECE4D0', glass='#2E4A56', lit='#7FE0D8')
    s.poly([s.p(0.08, 0.1, b['h']), s.p(1.27, 0.1, b['h']), s.p(1.27, 0.9, b['h'] + 8), s.p(0.08, 0.9, b['h'] + 8)], '#2B3F66')
    for k in range(10):
        s.line(s.p(0.08 + k * 0.12, 0.1, b['h']), s.p(0.08 + k * 0.12, 0.9, b['h'] + 8), '#5A7AB8')
    s.tree2(1.5, 0.3, h=11); s.tree2(1.8, 0.65, h=10)
    x, y = s.p(1.6, 0.75, 0); s.rect(x - 4, y - 3, 8, 3, '#E3A93B')
    return b


def plaza_flotante(s):
    s.poly([s.p(0, 0, 0), s.p(1, 0, 0), s.p(1, 1, 0), s.p(0, 1, 0)], '#2D6F8F')
    for k in range(6):
        x, y = s.p(0.1 + k * 0.15, 0.95, 0); s.rect(x - 2, y, 4, 1, '#7FC3DA')
    s.revolve(0.5, 0.5, 0, 3, lambda t: 0.36, '#C8A070', top=True)
    s.revolve(0.5, 0.5, 3, 1, lambda t: 0.32, '#4FA36B')
    s.tree2(0.45, 0.45, h=13)
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.4
        s.bush(0.5 + 0.22 * math.cos(a), 0.5 + 0.22 * math.sin(a), '#6FC08B')
    s.box(0.78, 0.78, 0.12, 0.3, 0, 1, '#C8A070')
    return dict(i0=0.2, j0=0.2, w=0.6, d=0.6, z0=0, h=4, wall='#C8A070')


ERAS2['2050'] = [
    ('torre_madera', 'Torre de madera', 1, 1, torre_madera, 'mejora'), ('anfibio', 'Casa anfibia', 1, 1, anfibio, 'mejora'),
    ('granja_vertical', 'Granja vertical', 2, 2, granja_vertical, 'mejora'), ('hub_drones', 'Hub de drones', 1, 1, hub_drones, 'mejora'),
    ('bloque_muro', 'Bloque con muro antiinundación', 2, 1, bloque_muro, 'mejora'),
    ('arcologia', 'Arcología', 2, 2, arcologia, 'monumento'), ('biodomo', 'Biodomo', 2, 2, biodomo, 'nuevo'),
    ('hyperloop', 'Estación de cápsulas', 2, 1, hyperloop, 'nuevo'), ('escuela_solar', 'Escuela solar', 2, 1, escuela_solar, 'nuevo'),
    ('torre_eolica', 'Torre eólica', 1, 1, torre_eolica, 'nuevo'), ('plaza_flotante', 'Plaza flotante', 1, 1, plaza_flotante, 'nuevo')]
