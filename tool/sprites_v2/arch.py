"""Arquetipos por época. Cada uno: (clave, nombre, w, d, hmax, función)."""
from spr import Spr, sh

FH = 8

# ------------------------------------------------------------------ 1888
def casa_cos(s):
    s.ground('#4A3C2C')
    b = s.box(0.1, 0.1, 0.8, 0.8, 0, 2 * FH + 2, '#C9A36A')
    s.windows(b, 'L', 2, 2, 0, FH, 0.14, 5, kind='shutter', lit='#E8B860', dark='#3A2C1E')
    s.windows(b, 'R', 2, 2, 0, FH, 0.14, 5, kind='shutter', lit='#E8B860', dark='#3A2C1E')
    s.door(b, 'L', 0.38, 0.16, 7, '#5A3A22')
    s.parapet(b, '#B08C5A', 3)
    s.box(0.55, 0.25, 0.12, 0.12, b['h'], 8, '#8A5A3A')  # chimenea
    return b

def finca_ensanche(s):
    s.ground('#4A3C2C', 0, 0, 2, 2)
    b = s.box(0.1, 0.1, 1.8, 1.8, 0, 5 * FH + 4, '#D8C29A')
    s.quad(b, 'L', 0, 0, 1.8, FH, '#8A7458')
    s.quad(b, 'R', 0, 0, 1.8, FH, '#8A7458')
    for face in 'LR':
        for k in range(4):
            s.quad(b, face, 0.15 + k * 0.42, 1, 0.2, 6, '#2A2018')
    s.windows(b, 'L', 5, 5, 0, FH, 0.14, 5, lit='#E8B860', dark='#3A2C1E', frame='#F0E2C0', skip_ground=True)
    s.windows(b, 'R', 5, 5, 0, FH, 0.14, 5, lit='#E8B860', dark='#3A2C1E', frame='#F0E2C0', skip_ground=True)
    # tribuna (galería) en la cara izquierda
    t = s.box(0.7, 1.9, 0.4, 0.14, FH * 2, FH * 3, '#E8D8B8')
    s.windows(t, 'L', 3, 2, FH * 2, FH, 0.1, 5, lit='#F2D08A', dark='#4A3A2A')
    s.bands(b, 'L', 0, b['h'], FH, '#B8A27C')
    s.bands(b, 'R', 0, b['h'], FH, '#B8A27C')
    s.parapet(b, '#C8B08A', 3)
    return b

def fabrica_vapor(s):
    s.ground('#3E3428', 0, 0, 2, 2)
    b = s.box(0.1, 0.1, 1.8, 1.5, 0, 2 * FH + 4, '#9A4A32')
    s.windows(b, 'L', 2, 5, 0, FH + 2, 0.16, 8, lit='#E8B860', dark='#2A1E18', frame='#C8A070')
    s.windows(b, 'R', 2, 4, 0, FH + 2, 0.16, 8, lit='#E8B860', dark='#2A1E18', frame='#C8A070')
    s.gable(0.1, 0.1, 1.8, 1.5, b['h'], 8, '#5A4A44', '#9A4A32', axis='i')
    c = s.box(1.55, 1.65, 0.28, 0.28, 0, 64, '#8A3E2A')
    s.bands(c, 'L', 0, 64, 10, '#6E3020')
    if s.state != 'ruina':
        x, y = s.p(1.69, 1.79, 66)
        for k, col in enumerate(['#8F8578', '#7A7166', '#6A6258']):
            s.rect(x - 2 + k * 3, y - 4 - k * 4, 4, 3, col, raw=True)
    return b

def colmado(s):
    s.ground('#4A3C2C')
    b = s.box(0.1, 0.1, 0.8, 0.8, 0, 2 * FH + 2, '#B8925E')
    s.quad(b, 'L', 0.08, 1, 0.64, 7, '#2A1E16')
    s.windows(b, 'L', 2, 2, 0, FH, 0.14, 5, lit='#E8B860', dark='#3A2C1E', skip_ground=True)
    s.windows(b, 'R', 2, 2, 0, FH, 0.14, 5, lit='#E8B860', dark='#3A2C1E')
    for k in range(6):
        s.quad(b, 'L', k * 0.8 / 6, FH, 0.8 / 6, 3, '#C8553D' if k % 2 == 0 else '#ECE0C8')
    s.quad(b, 'L', 0.12, FH + 4, 0.56, 3, '#3E2A1A')
    s.parapet(b, '#A07E50', 2)
    return b

def mercado_hierro(s):
    s.ground('#3E3428', 0, 0, 2, 2)
    b = s.box(0.15, 0.15, 1.7, 1.7, 0, FH + 6, '#4E6E5A')
    s.vstripes(b, 'L', 8, 0, b['h'], '#2E4A3A', 0.06)
    s.vstripes(b, 'R', 8, 0, b['h'], '#2E4A3A', 0.06)
    for face in 'LR':
        s.quad(b, face, 0.1, 3, 1.5, 9, '#9CC4C8')
    s.vstripes(b, 'L', 8, 3, 9, '#2E4A3A', 0.05)
    s.vstripes(b, 'R', 8, 3, 9, '#2E4A3A', 0.05)
    s.gable(0.15, 0.15, 1.7, 1.7, b['h'], 14, '#7FA8A8', '#4E6E5A', axis='j')
    return b

# ------------------------------------------------------------------ 1929
def vecinos_deco(s):
    s.ground('#34372F')
    b = s.box(0.1, 0.1, 0.8, 0.8, 0, 5 * FH + 2, '#D9CDB0')
    s.windows(b, 'L', 5, 3, 0, FH, 0.13, 5, lit='#E5CD8A', dark='#3C3A34')
    s.windows(b, 'R', 5, 3, 0, FH, 0.13, 5, lit='#E5CD8A', dark='#3C3A34')
    s.bands(b, 'L', 0, b['h'], FH, '#B8AC90')
    s.vstripes(b, 'L', 1, 0, b['h'], '#C8A050', 0.06)
    s.box(0.25, 0.25, 0.5, 0.5, b['h'], 5, '#C8BC9E')
    s.door(b, 'L', 0.35, 0.14, 7, '#3A2E22')
    return b

def torre_deco(s):
    s.ground('#34372F')
    b = s.box(0.08, 0.08, 0.84, 0.84, 0, 6 * FH, '#B8B2A0')
    s.windows(b, 'L', 6, 3, 0, FH, 0.12, 5, lit='#E5CD8A', dark='#34322C')
    s.windows(b, 'R', 6, 3, 0, FH, 0.12, 5, lit='#E5CD8A', dark='#34322C')
    s.vstripes(b, 'L', 3, 0, b['h'], '#9A9480', 0.05)
    b2 = s.box(0.2, 0.2, 0.6, 0.6, b['h'], 3 * FH, '#C8C2B0')
    s.windows(b2, 'L', 3, 2, b['h'], FH, 0.12, 5, lit='#E5CD8A', dark='#34322C')
    s.windows(b2, 'R', 3, 2, b['h'], FH, 0.12, 5, lit='#E5CD8A', dark='#34322C')
    z = b['h'] + b2['h']
    b3 = s.box(0.32, 0.32, 0.36, 0.36, z, 2 * FH, '#D8D2C0')
    s.quad(b3, 'L', 0.05, z + 3, 0.26, 2, '#E3A93B')
    s.quad(b3, 'R', 0.05, z + 3, 0.26, 2, '#B8862E')
    s.box(0.46, 0.46, 0.08, 0.08, z + b3['h'], 14, '#E3A93B')
    return b

def cine(s):
    s.ground('#34372F', 0, 0, 2, 1)
    b = s.box(0.1, 0.1, 1.8, 0.8, 0, 3 * FH + 2, '#8E4A3E')
    s.windows(b, 'L', 3, 5, 0, FH, 0.14, 5, lit='#E5CD8A', dark='#2E2622', skip_ground=True)
    s.windows(b, 'R', 3, 2, 0, FH, 0.14, 5, lit='#E5CD8A', dark='#2E2622')
    s.quad(b, 'L', 0.2, 0, 1.4, 7, '#2A1E1A')
    m = s.box(0.15, 0.9, 1.7, 0.18, FH - 1, 4, '#E8D8B0')
    lit = s.state in ('normal', 'reformada', 'alquilada')
    for k in range(12):
        x, y = s.fp(m, 'L', 0.07 + k * 0.135, FH + 1)
        s.px(x, y, '#FFE28A' if lit and k % 2 == 0 else '#8A7A5A', raw=True)
    v = s.box(1.55, 0.95, 0.12, 0.1, FH + 4, 3 * FH, '#C8553D')
    for k in range(4):
        x, y = s.fp(v, 'L', 0.04, FH + 8 + k * 5)
        s.rect(x, y - 2, 2, 3, '#FFE28A' if lit else '#5A4A3A', raw=True)
    return b

def banco(s):
    s.ground('#34372F', 0, 0, 2, 2)
    b = s.box(0.1, 0.1, 1.8, 1.8, 0, 3 * FH + 6, '#B8B4A8')
    for face in 'LR':
        for k in range(6):
            s.quad(b, face, 0.15 + k * 0.28, 3, 0.1, 18, '#E0DCD0')
            s.quad(b, face, 0.27 + k * 0.28, 4, 0.12, 15, '#4A4640')
    s.quad(b, 'L', 0, b['h'] - 5, 1.8, 5, '#8E8A80')
    s.quad(b, 'R', 0, b['h'] - 5, 1.8, 5, '#7A766E')
    s.parapet(b, '#A8A498', 3)
    s.box(0.7, 0.7, 0.6, 0.6, b['h'], 6, '#9A968A')
    s.box(0.85, 0.85, 0.3, 0.3, b['h'] + 6, 6, '#6F8C80')
    return b

def fabrica_dientes(s):
    s.ground('#2E312C', 0, 0, 2, 2)
    b = s.box(0.1, 0.1, 1.8, 1.8, 0, FH + 6, '#8A4632')
    s.windows(b, 'L', 1, 6, 0, FH + 6, 0.16, 8, lit='#E5CD8A', dark='#2A221E', frame='#B89A70')
    s.windows(b, 'R', 1, 6, 0, FH + 6, 0.16, 8, lit='#E5CD8A', dark='#2A221E', frame='#B89A70')
    z = b['h']
    for k in range(4):
        i0 = 0.1 + k * 0.45
        s.poly([s.p(i0, 0.1, z), s.p(i0, 1.9, z), s.p(i0 + 0.1, 1.9, z + 9), s.p(i0 + 0.1, 0.1, z + 9)], '#9CB0B0')
        s.poly([s.p(i0 + 0.1, 0.1, z + 9), s.p(i0 + 0.1, 1.9, z + 9), s.p(i0 + 0.45, 1.9, z), s.p(i0 + 0.45, 0.1, z)], '#5A4A44')
        s.poly([s.p(i0, 1.9, z), s.p(i0 + 0.45, 1.9, z), s.p(i0 + 0.1, 1.9, z + 9)], '#6E3424')
    t = s.box(1.45, 0.3, 0.3, 0.3, z + 14, 9, '#6A5A4A')
    for (a, c) in [(1.47, 0.32), (1.72, 0.57)]:
        s.line(s.p(a, c, z), s.p(a, c, z + 14), '#4A4038')
    return b

# ------------------------------------------------------------------ 1980
def bloque_ladrillo(s):
    s.ground('#2E2626')
    b = s.box(0.1, 0.1, 0.8, 0.8, 0, 8 * FH, '#8A5A42')
    s.windows(b, 'L', 8, 2, 0, FH, 0.2, 4, lit='#F0A060', dark='#2A201C', frame='#C8B8A0')
    s.windows(b, 'R', 8, 2, 0, FH, 0.2, 4, lit='#F0A060', dark='#2A201C', frame='#C8B8A0')
    for f in range(1, 8):
        s.quad(b, 'L', 0.02, f * FH, 0.76, 1, '#B8B0A0')
    x, y = s.p(0.5, 0.5, b['h'])
    s.line((x, y), (x, y - 10), '#9A9A9A', raw=False)
    s.line((x - 4, y - 7), (x + 4, y - 7), '#9A9A9A')
    s.line((x - 3, y - 4), (x + 3, y - 4), '#9A9A9A')
    return b

def torre_brutalista(s):
    s.ground('#2E2626', 0, 0, 2, 2)
    b = s.box(0.25, 0.25, 1.5, 1.5, 0, 7 * FH, '#8C8880')
    for f in range(7):
        s.quad(b, 'L', 0.05, f * FH + 3, 1.4, 3, '#2A2624')
        s.quad(b, 'R', 0.05, f * FH + 3, 1.4, 3, '#24201E')
        for k in range(6):
            col = '#F0A060' if s.rnd.random() < (0.3 if s.state == 'normal' else 0.6 if s.state in ('reformada', 'alquilada') else 0) else '#2A2624'
            s.quad(b, 'L', 0.12 + k * 0.22, f * FH + 3, 0.12, 3, col)
    top = s.box(0.1, 0.1, 1.8, 1.8, b['h'], FH + 4, '#9A968E')
    s.quad(top, 'L', 0, b['h'] + 4, 1.8, 3, '#5A5650')
    s.quad(top, 'R', 0, b['h'] + 4, 1.8, 3, '#4E4A46')
    return b

def local_persiana(s):
    s.ground('#2E2626')
    b = s.box(0.1, 0.1, 0.8, 0.8, 0, 2 * FH + 2, '#C8A888')
    s.quad(b, 'L', 0.06, 0, 0.68, 7, '#8A8A86')
    for z in range(1, 7, 2):
        s.quad(b, 'L', 0.06, z, 0.68, 1, '#6A6A66')
    if s.state in ('normal', 'ruina', 'obra'):
        for (u, z, col) in [(0.12, 2, '#C84A8A'), (0.2, 3, '#4AA0C8'), (0.32, 2, '#E3A93B'), (0.45, 4, '#4FC08D'), (0.55, 2, '#C84A8A')]:
            s.quad(b, 'L', u, z, 0.08, 2, col, raw=True)
    s.windows(b, 'L', 2, 2, 0, FH, 0.16, 4, lit='#F0A060', dark='#2A201C', skip_ground=True)
    s.windows(b, 'R', 2, 2, 0, FH, 0.16, 4, lit='#F0A060', dark='#2A201C')
    s.quad(b, 'L', 0.15, FH - 1, 0.5, 3, '#C8553D')
    return b

def nave_abandonada(s):
    s.ground('#2E2626', 0, 0, 2, 2)
    b = s.box(0.1, 0.1, 1.8, 1.8, 0, FH + 8, '#7A7A74')
    s.vstripes(b, 'L', 18, 0, b['h'], '#5E5E5A', 0.03)
    s.vstripes(b, 'R', 18, 0, b['h'], '#545450', 0.03)
    s.quad(b, 'L', 0.6, 0, 0.6, 11, '#3E3E3A')
    for z in range(1, 11, 2):
        s.quad(b, 'L', 0.6, z, 0.6, 1, '#4E4E4A')
    s.gable(0.1, 0.1, 1.8, 1.8, b['h'], 9, '#6E5A4A', '#7A7A74', axis='j')
    return b

def oficinas_70(s):
    s.ground('#2E2626')
    b = s.box(0.1, 0.1, 0.8, 0.8, 0, 6 * FH, '#5A4434')
    for f in range(6):
        s.quad(b, 'L', 0, f * FH + 2, 0.8, 5, '#8A6A3E')
        s.quad(b, 'R', 0, f * FH + 2, 0.8, 5, '#6A5030')
        if s.state in ('reformada', 'alquilada'):
            s.quad(b, 'L', 0.1, f * FH + 3, 0.2, 3, '#F0C080')
    s.quad(b, 'L', 0, b['h'] - 1, 0.8, 1, '#C8A060')
    return b

# ------------------------------------------------------------------ 2005
def adosados(s):
    s.ground('#4F7A52', 0, 0, 2, 1)
    for k in range(2):
        b = s.box(0.1 + k * 0.95, 0.15, 0.85, 0.7, 0, 2 * FH, '#E8DCC0' if k == 0 else '#E0CCAA')
        s.windows(b, 'L', 2, 2, 0, FH, 0.16, 5, lit='#9CC8E0', dark='#4A5A62', frame='#FFFFFF')
        s.windows(b, 'R', 2, 1, 0, FH, 0.16, 5, lit='#9CC8E0', dark='#4A5A62', frame='#FFFFFF')
        s.gable(0.1 + k * 0.95, 0.15, 0.85, 0.7, b['h'], 7, '#B8503A', '#E8DCC0', axis='i')
        if k == 1:
            x, y = s.fp(b, 'R', 0.2, b['h'] - 2)
            s.rect(x, y - 3, 3, 3, '#E8E8E8')
    s.ground('#6FA05E', 0, 0.85, 2, 0.15)
    return b

def torre_cristal(s):
    s.ground('#3E5A48')
    b = s.box(0.12, 0.12, 0.76, 0.76, 0, 13 * FH, '#4E86A8', top='#9CC8E0', right='#3A6A88')
    for f in range(13):
        s.quad(b, 'L', 0, f * FH, 0.76, 1, '#6A9CBC')
        s.quad(b, 'R', 0, f * FH, 0.76, 1, '#4A7A98')
    lit = 0.35 if s.state == 'normal' else 0.7 if s.state in ('reformada', 'alquilada') else 0.0
    for f in range(13):
        for k in range(4):
            if s.rnd.random() < lit:
                s.quad(b, 'L', 0.04 + k * 0.18, f * FH + 2, 0.12, 4, '#F2E2A0', raw=True)
    # reflejo diagonal
    for k in range(20):
        s.quad(b, 'L', 0.05 + k * 0.03, 40 + k * 2.5, 0.05, 6, '#B8DCEC')
    s.quad(b, 'L', 0.18, b['h'] - 6, 0.4, 3, '#E3A93B')
    return b

def centro_comercial(s):
    s.ground('#2C3A3E', 0, 0, 2, 2)
    b = s.box(0.1, 0.1, 1.8, 1.8, 0, 2 * FH + 6, '#DCD8D0')
    s.quad(b, 'L', 0.5, 0, 0.8, 14, '#7FB0CC')
    s.vstripes(b, 'L', 1, 0, 14, '#FFFFFF', 0.05)
    s.quad(b, 'R', 0.1, 4, 1.6, 4, '#B8B4AC')
    s.quad(b, 'L', 0.35, 15, 1.1, 5, '#C8553D')
    s.quad(b, 'L', 0.45, 16, 0.9, 3, '#F2C25F')
    s.box(1.5, 0.3, 0.3, 0.3, b['h'], 4, '#B8B4AC')
    for k in range(4):
        x, y = s.p(0.15 + k * 0.4, 1.95, 0)
        s.rect(x, y - 1, 6, 1, '#ECE4D0')
    return b

def obra_nueva(s):
    s.ground('#3E5A48')
    b = s.box(0.1, 0.1, 0.8, 0.8, 0, 6 * FH, '#ECE6DA')
    s.windows(b, 'L', 6, 2, 0, FH, 0.2, 5, lit='#9CC8E0', dark='#4A5A62')
    s.windows(b, 'R', 6, 2, 0, FH, 0.2, 5, lit='#9CC8E0', dark='#4A5A62')
    for f in range(1, 6):
        s.quad(b, 'R', 0, f * FH, 0.8, 1, '#C8C2B8')
    if s.state in ('normal', 'obra'):
        s.quad(b, 'L', 0.06, FH * 2, 0.68, 22, '#E86A2E')
        s.quad(b, 'L', 0.12, FH * 2 + 14, 0.56, 4, '#FFFFFF')
        s.quad(b, 'L', 0.12, FH * 2 + 6, 0.4, 3, '#FFFFFF')
        s.quad(b, 'L', 0.12, FH * 2 + 2, 0.3, 2, '#1E4A8A')
    return b

def urbanizacion(s):
    s.ground('#4F7A52', 0, 0, 2, 2)
    s.poly([s.p(0.9, 0.9, 0), s.p(1.8, 0.9, 0), s.p(1.8, 1.8, 0), s.p(0.9, 1.8, 0)], '#E8E2D0')
    s.poly([s.p(1.0, 1.0, 0), s.p(1.7, 1.0, 0), s.p(1.7, 1.7, 0), s.p(1.0, 1.7, 0)], '#3AB8D8')
    s.poly([s.p(1.1, 1.1, 0), s.p(1.3, 1.1, 0), s.p(1.3, 1.3, 0), s.p(1.1, 1.3, 0)], '#8AE0F0')
    b = s.box(0.1, 0.1, 0.7, 1.8, 0, 3 * FH + 2, '#F0DCC0')
    s.windows(b, 'L', 3, 2, 0, FH, 0.18, 5, lit='#9CC8E0', dark='#4A5A62', frame='#FFFFFF')
    s.windows(b, 'R', 3, 5, 0, FH, 0.18, 5, lit='#9CC8E0', dark='#4A5A62', frame='#FFFFFF')
    b2 = s.box(0.8, 0.1, 1.1, 0.7, 0, 3 * FH + 2, '#E8D0B0')
    s.windows(b2, 'L', 3, 3, 0, FH, 0.18, 5, lit='#9CC8E0', dark='#4A5A62', frame='#FFFFFF')
    s.windows(b2, 'R', 3, 2, 0, FH, 0.18, 5, lit='#9CC8E0', dark='#4A5A62', frame='#FFFFFF')
    s.box(0.1, 0.1, 0.7, 1.8, b['h'], 1, '#B8503A')
    x, y = s.p(1.85, 1.85, 0)
    s.rect(x, y - 16, 1, 16, '#8A6A44')
    s.rect(x - 4, y - 18, 9, 2, '#4FA36B'); s.rect(x - 5, y - 16, 3, 2, '#4FA36B'); s.rect(x + 3, y - 16, 3, 2, '#4FA36B')
    return b

# ------------------------------------------------------------------ 2020
def bloque_terrazas(s):
    s.ground('#1F3B38')
    b = s.box(0.15, 0.15, 0.7, 0.7, 0, 6 * FH, '#E8E4DA')
    s.windows(b, 'L', 6, 2, 0, FH, 0.22, 5, lit='#E3A93B', dark='#3A524E')
    s.windows(b, 'R', 6, 2, 0, FH, 0.22, 5, lit='#E3A93B', dark='#3A524E')
    for f in range(1, 6):
        t = s.box(0.1, 0.85, 0.8, 0.1, f * FH - 1, 1, '#C8C4BA')
        if s.state != 'ruina' and s.rnd.random() < 0.7:
            x, y = s.fp(t, 'L', 0.1 + s.rnd.random() * 0.5, f * FH + 1)
            s.rect(x, y - 2, 3, 2, '#4FA36B')
    for k in range(3):
        s.poly([s.p(0.25 + k * 0.18, 0.3, b['h'] + 1), s.p(0.38 + k * 0.18, 0.3, b['h'] + 1), s.p(0.38 + k * 0.18, 0.7, b['h'] + 3), s.p(0.25 + k * 0.18, 0.7, b['h'] + 3)], '#2B3F66')
    return b

def piso_turistico(s):
    s.ground('#1F3B38')
    b = s.box(0.1, 0.1, 0.8, 0.8, 0, 4 * FH + 2, '#D8A878')
    s.windows(b, 'L', 4, 2, 0, FH, 0.16, 5, lit='#E3A93B', dark='#3A3028', frame='#F0E0C8')
    s.windows(b, 'R', 4, 2, 0, FH, 0.16, 5, lit='#E3A93B', dark='#3A3028', frame='#F0E0C8')
    for f in range(1, 4):
        s.quad(b, 'L', 0.08, f * FH, 0.64, 1, '#2A2622')
    s.door(b, 'L', 0.32, 0.16, 7, '#3E5A4A')
    x, y = s.fp(b, 'L', 0.55, 5)
    s.rect(x, y - 3, 3, 3, '#1A1A1A'); s.px(x + 1, y - 2, '#E3A93B', raw=True)
    x, y = s.fp(b, 'L', 0.62, 14)
    s.rect(x, y - 4, 8, 4, '#5AA6D6'); s.rect(x + 1, y - 3, 1, 1, '#FFFFFF')
    s.parapet(b, '#C89868', 2)
    return b

def coworking(s):
    s.ground('#1F3B38', 0, 0, 2, 2)
    b = s.box(0.1, 0.1, 1.8, 1.8, 0, FH + 8, '#9A5A40')
    s.windows(b, 'L', 1, 5, 0, FH + 8, 0.24, 11, lit='#F2D08A', dark='#2E3A3A', frame='#2A2A2A')
    s.windows(b, 'R', 1, 5, 0, FH + 8, 0.24, 11, lit='#F2D08A', dark='#2E3A3A', frame='#2A2A2A')
    z = b['h']
    for k in range(4):
        i0 = 0.1 + k * 0.45
        s.poly([s.p(i0, 0.1, z), s.p(i0, 1.9, z), s.p(i0 + 0.1, 1.9, z + 8), s.p(i0 + 0.1, 0.1, z + 8)], '#BCE0EC')
        s.poly([s.p(i0 + 0.1, 0.1, z + 8), s.p(i0 + 0.1, 1.9, z + 8), s.p(i0 + 0.45, 1.9, z), s.p(i0 + 0.45, 0.1, z)], '#3A3A3A')
        s.poly([s.p(i0, 1.9, z), s.p(i0 + 0.45, 1.9, z), s.p(i0 + 0.1, 1.9, z + 8)], '#7A4632')
    x, y = s.fp(b, 'L', 0.2, 13)
    s.rect(x, y - 3, 10, 3, '#E86AA0' if s.state != 'ruina' else '#5A4A4A')
    return b

def dark_kitchen(s):
    s.ground('#1F3B38')
    b = s.box(0.1, 0.1, 0.8, 0.8, 0, FH + 6, '#5A6E6A')
    for k in range(2):
        s.quad(b, 'L', 0.06 + k * 0.36, 0, 0.32, 9, '#8A9692')
        for z in range(1, 9, 2):
            s.quad(b, 'L', 0.06 + k * 0.36, z, 0.32, 1, '#6E7A76')
    s.quad(b, 'R', 0.2, 2, 0.4, 6, '#2E3A3A')
    s.box(0.5, 0.3, 0.25, 0.2, b['h'], 5, '#9AA6A2')
    if s.state not in ('ruina',):
        for k, col in enumerate(['#4FC08D', '#E86A2E', '#E3A93B']):
            x, y = s.p(0.25 + k * 0.25, 1.0, 0)
            s.rect(x, y - 5, 4, 4, col, raw=True)
            s.rect(x - 1, y - 1, 6, 1, '#1A1A1A', raw=True)
    return b

def rehabilitado(s):
    s.ground('#1F3B38', 0, 0, 2, 1)
    b = s.box(0.1, 0.1, 1.8, 0.8, 0, 5 * FH, '#C8D8C8')
    pal = ['#C8D8C8', '#E8C8A8', '#A8C8D8', '#E8E0B0']
    for k in range(6):
        s.quad(b, 'L', k * 0.3, 0, 0.3, b['h'], pal[k % 4])
    s.windows(b, 'L', 5, 6, 0, FH, 0.14, 5, lit='#E3A93B', dark='#3A524E', frame='#FFFFFF')
    s.windows(b, 'R', 5, 2, 0, FH, 0.14, 5, lit='#E3A93B', dark='#3A524E', frame='#FFFFFF')
    for k in range(5):
        s.poly([s.p(0.25 + k * 0.32, 0.25, b['h'] + 1), s.p(0.5 + k * 0.32, 0.25, b['h'] + 1), s.p(0.5 + k * 0.32, 0.7, b['h'] + 4), s.p(0.25 + k * 0.32, 0.7, b['h'] + 4)], '#2B3F66')
    x, y = s.p(1.9, 0.95, 0)
    s.rect(x, y - 8, 2, 8, '#ECE4D0'); s.rect(x, y - 7, 2, 2, '#4FC08D')
    return b

# ------------------------------------------------------------------ 2050
def torre_madera(s):
    s.ground('#1B2C33')
    b = s.box(0.12, 0.12, 0.76, 0.76, 0, 11 * FH, '#C8A070', top='#4FA36B')
    s.windows(b, 'L', 11, 2, 0, FH, 0.24, 5, lit='#7FE0D8', dark='#2E4A56')
    s.windows(b, 'R', 11, 2, 0, FH, 0.24, 5, lit='#7FE0D8', dark='#2E4A56')
    s.vstripes(b, 'L', 4, 0, b['h'], '#A07A4A', 0.03)
    for f in range(11):
        if s.state != 'ruina' or s.rnd.random() < 0.3:
            s.quad(b, 'L', 0.0, f * FH, 0.12, 6, '#4FA36B')
            s.quad(b, 'R', 0.64, f * FH + 2, 0.12, 5, '#3E8A58')
    x, y = s.p(0.5, 0.5, b['h'])
    s.line((x, y), (x, y - 14), '#ECE4D0')
    s.line((x - 5, y - 17), (x + 5, y - 11), '#ECE4D0')
    s.line((x - 5, y - 11), (x + 5, y - 17), '#ECE4D0')
    return b

def anfibio(s):
    s.poly([s.p(0, 0, 0), s.p(1, 0, 0), s.p(1, 1, 0), s.p(0, 1, 0)], '#2D6F8F')
    s.poly([s.p(0.1, 0.6, 0), s.p(0.5, 0.6, 0), s.p(0.5, 0.65, 0), s.p(0.1, 0.65, 0)], '#7FC3DA')
    for (a, c) in [(0.2, 0.2), (0.8, 0.2), (0.8, 0.8), (0.2, 0.8)]:
        s.line(s.p(a, c, 0), s.p(a, c, 9), '#9AA6AA')
    b = s.box(0.1, 0.1, 0.8, 0.8, 9, 4 * FH, '#E8EEF0', top='#4FA36B')
    s.windows(b, 'L', 4, 2, 9, FH, 0.28, 5, lit='#7FE0D8', dark='#3A5266')
    s.windows(b, 'R', 4, 2, 9, FH, 0.28, 5, lit='#7FE0D8', dark='#3A5266')
    s.quad(b, 'L', 0, 9 + FH * 2, 0.8, 1, '#B8C8D0')
    return b

def granja_vertical(s):
    s.ground('#1B2C33', 0, 0, 2, 2)
    b = s.box(0.2, 0.2, 1.6, 1.6, 0, 8 * FH, '#7FA2B8', top='#4FA36B', right='#5A7E96')
    on = s.state in ('normal', 'reformada', 'alquilada')
    for f in range(8):
        s.quad(b, 'L', 0.05, f * FH + 1, 1.5, 6, '#2E4A56')
        s.quad(b, 'R', 0.05, f * FH + 1, 1.5, 6, '#263E48')
        s.quad(b, 'L', 0.08, f * FH + 2, 1.44, 2, '#4FA36B' if s.state != 'ruina' else '#5A5A4A')
        s.quad(b, 'R', 0.08, f * FH + 2, 1.44, 2, '#3E8A58' if s.state != 'ruina' else '#4A4A3E')
        if on:
            s.quad(b, 'L', 0.08, f * FH + 6, 1.44, 1, '#E86AC8', raw=True)
            s.quad(b, 'R', 0.08, f * FH + 6, 1.44, 1, '#C858A8', raw=True)
    return b

def hub_drones(s):
    s.ground('#1B2C33')
    b = s.box(0.3, 0.3, 0.4, 0.4, 0, 10 * FH, '#C8D6DE')
    s.windows(b, 'L', 10, 1, 0, FH, 0.2, 5, lit='#7FE0D8', dark='#3A5266')
    s.windows(b, 'R', 10, 1, 0, FH, 0.2, 5, lit='#7FE0D8', dark='#3A5266')
    for z in (3 * FH, 6 * FH, 10 * FH):
        p = s.box(0.08, 0.08, 0.84, 0.84, z, 2, '#7FA2B8', top='#9FB8C8')
        x, y = s.p(0.5, 0.5, z + 2)
        s.rect(x - 3, y, 7, 1, '#E3A93B')
    if s.state in ('normal', 'reformada', 'alquilada'):
        for (dx, dy) in [(-12, -10), (10, -22), (-6, -40)]:
            x, y = s.p(0.5, 0.5, 10 * FH)
            s.rect(x + dx - 2, y + dy, 5, 1, '#ECE4D0', raw=True)
            s.rect(x + dx, y + dy + 1, 1, 1, '#E3A93B', raw=True)
    return b

def bloque_muro(s):
    s.ground('#1B2C33', 0, 0, 2, 1)
    s.poly([s.p(0, 0.95, 0), s.p(2, 0.95, 0), s.p(2, 1, 0), s.p(0, 1, 0)], '#2D6F8F')
    b = s.box(0.15, 0.15, 1.7, 0.65, 0, 5 * FH, '#B8A890')
    s.windows(b, 'L', 5, 5, 0, FH, 0.16, 5, lit='#7FE0D8', dark='#3A4A52')
    s.windows(b, 'R', 5, 2, 0, FH, 0.16, 5, lit='#7FE0D8', dark='#3A4A52')
    s.quad(b, 'L', 0, 0, 1.7, 4, '#5A6A6E')
    w = s.box(0.05, 0.85, 1.9, 0.08, 0, 7, '#8A9AA0')
    s.quad(w, 'L', 0, 5, 1.9, 1, '#E3A93B')
    for k in range(5):
        s.poly([s.p(0.25 + k * 0.32, 0.25, b['h'] + 1), s.p(0.5 + k * 0.32, 0.25, b['h'] + 1), s.p(0.5 + k * 0.32, 0.65, b['h'] + 4), s.p(0.25 + k * 0.32, 0.65, b['h'] + 4)], '#2B3F66')
    return b


def _variant(fn, swaps):
    """Variante de color de un arquetipo: cambia colores concretos al dibujar."""
    def f(s):
        s.swaps = {k.upper(): v for k, v in swaps.items()}
        return fn(s)
    return f

vecinos_deco_v1 = _variant(vecinos_deco, {'#D9CDB0': '#D8B49A', '#B8AC90': '#B89478', '#C8BC9E': '#C8A488'})
vecinos_deco_v2 = _variant(vecinos_deco, {'#D9CDB0': '#BDB8A6', '#B8AC90': '#9E9A8A', '#C8BC9E': '#ACA898'})
cine_v1 = _variant(cine, {'#8E4A3E': '#4E5A6E', '#C8553D': '#E3A93B'})
banco_v1 = _variant(banco, {'#B8B4A8': '#C8B898', '#E0DCD0': '#EDE2C8', '#8E8A80': '#9C8E70'})

ARCH = {
    '1888': [('casa_cos', 'Casa de cos', 1, 1, 40, casa_cos), ('finca_ensanche', 'Finca del Ensanche', 2, 2, 64, finca_ensanche),
             ('fabrica_vapor', 'Fábrica de vapor', 2, 2, 86, fabrica_vapor), ('colmado', 'Colmado', 1, 1, 36, colmado),
             ('mercado_hierro', 'Mercado de hierro', 2, 2, 40, mercado_hierro)],
    '1929': [('vecinos_deco', 'Casa de vecinos déco', 1, 1, 60, vecinos_deco), ('torre_deco', 'Torre déco', 1, 1, 112, torre_deco),
             ('cine', 'Cine de estreno', 2, 1, 50, cine), ('banco', 'Banco', 2, 2, 56, banco),
             ('fabrica_dientes', 'Fábrica de dientes de sierra', 2, 2, 60, fabrica_dientes),
             ('vecinos_deco_v1', 'Casa de vecinos déco (salmón)', 1, 1, 60, vecinos_deco_v1),
             ('vecinos_deco_v2', 'Casa de vecinos déco (piedra)', 1, 1, 60, vecinos_deco_v2),
             ('cine_v1', 'Cine de estreno (azul)', 2, 1, 50, cine_v1),
             ('banco_v1', 'Banco (piedra dorada)', 2, 2, 56, banco_v1)],
    '1980': [('bloque_ladrillo', 'Bloque de ladrillo', 1, 1, 84, bloque_ladrillo), ('torre_brutalista', 'Torre brutalista', 2, 2, 80, torre_brutalista),
             ('local_persiana', 'Local con persiana', 1, 1, 36, local_persiana), ('nave_abandonada', 'Nave industrial', 2, 2, 42, nave_abandonada),
             ('oficinas_70', 'Oficinas de cristal ahumado', 1, 1, 60, oficinas_70)],
    '2005': [('adosados', 'Adosados', 2, 1, 36, adosados), ('torre_cristal', 'Torre de cristal', 1, 1, 118, torre_cristal),
             ('centro_comercial', 'Centro comercial', 2, 2, 40, centro_comercial), ('obra_nueva', 'Obra nueva «a estrenar»', 1, 1, 60, obra_nueva),
             ('urbanizacion', 'Urbanización con piscina', 2, 2, 40, urbanizacion)],
    '2020': [('bloque_terrazas', 'Bloque con terrazas', 1, 1, 60, bloque_terrazas), ('piso_turistico', 'Piso turístico', 1, 1, 46, piso_turistico),
             ('coworking', 'Coworking en nave', 2, 2, 40, coworking), ('dark_kitchen', 'Cocina fantasma', 1, 1, 30, dark_kitchen),
             ('rehabilitado', 'Bloque rehabilitado', 2, 1, 50, rehabilitado)],
    '2050': [('torre_madera', 'Torre de madera', 1, 1, 112, torre_madera), ('anfibio', 'Casa anfibia', 1, 1, 52, anfibio),
             ('granja_vertical', 'Granja vertical', 2, 2, 72, granja_vertical), ('hub_drones', 'Hub de drones', 1, 1, 100, hub_drones),
             ('bloque_muro', 'Bloque con muro antiinundación', 2, 1, 50, bloque_muro)],
}
STATES = ['normal', 'ruina', 'obra', 'reformada', 'alquilada']


def render(era, key, state):
    for k, name, w, d, hmax, fn in ARCH[era]:
        if k == key:
            s = Spr(w, d, hmax, state=state, era=era, seed=sum(map(ord, era + key)) + 3)
            b = fn(s)
            return s.finish(b), (s.ox, s.oy)
    raise KeyError(key)
