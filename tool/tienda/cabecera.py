#!/usr/bin/env python3
"""Gráfico de cabecera de Google Play (1024×500) a partir del título y la ciudad pixel art.

Uso:  python3 tool/tienda/cabecera.py            → tienda/cabecera_1024x500.png
Necesita Pillow (pip3 install pillow)."""
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
FONDO = (14, 34, 33)        # Hc.bg
W, H = 1024, 500

def main():
    lienzo = Image.new('RGB', (W, H), FONDO)
    # Título: ×5 exacto desde el original (pixel art nítido), a la izquierda.
    titulo = Image.open(RAIZ / 'assets/branding/logo/titulo_1x.png').convert('RGBA')
    titulo = titulo.resize((titulo.width * 5, titulo.height * 5), Image.NEAREST)
    margen = 52
    # Ciudad: ×2 sin suavizar, a la derecha del título y saliéndose por el borde, como en la portada.
    ciudad = Image.open(RAIZ / 'site/img/ciudad_b.png').convert('RGBA')
    ciudad = ciudad.crop(ciudad.getbbox())
    ciudad = ciudad.resize((ciudad.width * 2, ciudad.height * 2), Image.NEAREST)
    x_ciudad = margen + titulo.width + 36
    lienzo.paste(ciudad, (x_ciudad, (H - ciudad.height) // 2 + 30), ciudad)
    lienzo.paste(titulo, (margen, (H - titulo.height) // 2), titulo)
    salida = RAIZ / 'tienda/cabecera_1024x500.png'
    salida.parent.mkdir(exist_ok=True)
    lienzo.save(salida, optimize=True)
    print(salida)

if __name__ == '__main__':
    main()
