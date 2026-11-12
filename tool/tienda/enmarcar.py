#!/usr/bin/env python3
"""Enmarca las capturas del juego para la ficha de la tienda (1080×1920) con su rótulo en cada idioma.

Uso:
  1. Deja las capturas del móvil en tienda/capturas/<idioma>/ numeradas en este orden:
     1 mapa · 2 obra (minijuego) · 3 venta o alquiler · 4 empresa · 5 épocas
     (por ejemplo tienda/capturas/es/1.png … 5.png). Si un idioma no tiene capturas propias, usa las de «es».
  2. python3 tool/tienda/enmarcar.py
  3. Salen en tienda/ficha/<idioma>/1.png … listas para subir a Play Console y App Store Connect.

Los rótulos están en tool/tienda/textos.json. Necesita Pillow (pip3 install pillow).
El chino usa una fuente del sistema (PingFang en macOS); el resto, Jersey 15 del juego."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parents[2]
W, H = 1080, 1920
FONDO, TINTA, ACENTO, LINEA = (14, 34, 33), (236, 228, 208), (227, 169, 59), (5, 11, 11)
JERSEY = RAIZ / 'assets/fonts/Jersey15-Regular.ttf'
CJK = ['/System/Library/Fonts/PingFang.ttc', '/System/Library/Fonts/STHeiti Medium.ttc',
       '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc', '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc']


def fuente(idioma, cuerpo):
    if idioma == 'zh':
        for f in CJK:
            if Path(f).exists():
                return ImageFont.truetype(f, int(cuerpo * 0.72))
        print('  aviso: no encuentro una fuente china; el rótulo saldrá con cuadros', file=sys.stderr)
    return ImageFont.truetype(str(JERSEY), cuerpo)


def partir(d, texto, f, ancho, chino):
    """Parte el rótulo en líneas que quepan (por palabras; el chino, por caracteres)."""
    trozos = list(texto) if chino else texto.split(' ')
    union = '' if chino else ' '
    lineas, actual = [], ''
    for t in trozos:
        prueba = t if not actual else actual + union + t
        if d.textlength(prueba, font=f) <= ancho:
            actual = prueba
        else:
            lineas.append(actual)
            actual = t
    if actual:
        lineas.append(actual)
    return lineas


def enmarcar(captura, rotulo, idioma, salida):
    lienzo = Image.new('RGB', (W, H), FONDO)
    d = ImageDraw.Draw(lienzo)
    f = fuente(idioma, 92)
    lineas = partir(d, rotulo, f, W - 150, idioma == 'zh')
    alto_linea = int(f.size * 1.02)
    y = 96
    for i, l in enumerate(lineas):
        x = (W - d.textlength(l, font=f)) / 2
        # Sombra dura del juego bajo el texto; la última línea, en dorado.
        d.text((x, y + 5), l, font=f, fill=LINEA)
        d.text((x, y), l, font=f, fill=ACENTO if i == len(lineas) - 1 and len(lineas) > 1 else TINTA)
        y += alto_linea
    arriba = y + 56
    # La captura, tan grande como quepa, con borde de 4 px, esquinas redondas y sombra dura.
    im = Image.open(captura).convert('RGB')
    escala = min((W - 140) / im.width, (H - arriba + 60) / im.height)
    escala = max(escala, (W - 140) / im.width)  # siempre a lo ancho; lo que sobre se sale por abajo
    im = im.resize((round(im.width * escala), round(im.height * escala)), Image.LANCZOS)
    x0 = (W - im.width) // 2
    radio = 44
    mascara = Image.new('L', im.size, 0)
    ImageDraw.Draw(mascara).rounded_rectangle((0, 0, im.width - 1, im.height - 1), radio, fill=255)
    d.rounded_rectangle((x0 - 6, arriba + 8, x0 + im.width + 5, arriba + im.height + 22), radio + 6, fill=LINEA)
    d.rounded_rectangle((x0 - 6, arriba - 6, x0 + im.width + 5, arriba + im.height + 5), radio + 6, fill=LINEA)
    lienzo.paste(im, (x0, arriba), mascara)
    salida.parent.mkdir(parents=True, exist_ok=True)
    lienzo.save(salida, optimize=True)


def main():
    textos = json.loads((Path(__file__).parent / 'textos.json').read_text(encoding='utf-8'))
    origen = RAIZ / 'tienda/capturas'
    hechas = 0
    for idioma, rotulos in textos.items():
        if idioma.startswith('_'):
            continue
        for n, rotulo in enumerate(rotulos, start=1):
            cand = [p for carpeta in (idioma, 'es') for ext in ('png', 'jpg', 'jpeg') for p in [origen / carpeta / f'{n}.{ext}'] if p.exists()]
            if not cand:
                continue
            enmarcar(cand[0], rotulo, idioma, RAIZ / f'tienda/ficha/{idioma}/{n}.png')
            hechas += 1
    print(f'{hechas} capturas enmarcadas en tienda/ficha/' if hechas else 'No hay capturas en tienda/capturas/es/ (1.png … 5.png)')


if __name__ == '__main__':
    main()
