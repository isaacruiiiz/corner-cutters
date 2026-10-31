# Sprites v2 (generador)

Pixel art isométrico procedural (Python 3 + Pillow + numpy).

- `spr2.py`: motor (texturas, ventanas con marco, cornisas, cúpulas, agujas, rosetones…).
- `arch2.py`: ciudad actual (monumentos, equipamientos y edificios comunes).
- `arch_eras.py`: los 11 tipos de cada época.
- `export2.py`: escribe los PNG y los manifest en `assets/sprites/A` y `assets/eras/<año>/sprites`.

Uso, desde esta carpeta:

    python3 export2.py ../..

Regla: ningún sprite puede tener `anchor_y` > 124 (`SpriteAtlas.maxAbove`); el exportador lo comprueba.
