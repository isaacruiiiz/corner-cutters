"""Exporta los sprites v2 al proyecto: ciudad actual (assets/sprites/A) y épocas (assets/eras/<id>/sprites)."""
import json, os, sys
import arch2, arch_eras
HS = sys.argv[1] if len(sys.argv) > 1 else '/home/claude/hs'
STATES = ['normal', 'ruina', 'obra', 'reformada', 'alquilada']
LANDMARKS = {'catedral', 'ayuntamiento', 'mercado', 'estadio', 'faro', 'torre_tv', 'estacion', 'hospital', 'museo', 'colegio', 'plaza_fuente'}
VAR_MAIN = {
    'casa': [{'#E8D2B0': '#D8B49A', '#B8503A': '#8A5A44'}, {'#E8D2B0': '#C8D4D8', '#B8503A': '#5A6A7A'}],
    'bloque': [{'#E2CDA8': '#D8B49A', '#C8B490': '#B89A80'}, {'#E2CDA8': '#C8C2B8', '#C8B490': '#A8A298'}],
    'ensanche': [{'#D8C29A': '#D8B49A'}, {'#D8C29A': '#C8C8C0'}],
    'modernista': [{'#E8DCC0': '#E8C8B8'}, {'#E8DCC0': '#D0D8D0'}],
    'iglesia': [{'#D8C4A0': '#C8B8A8', '#A8553A': '#7A5A4A'}, {'#D8C4A0': '#B8B0A0', '#A8553A': '#5A6070'}],
    'chaflan': [{'#D8B48C': '#E2CDA8'}, {'#D8B48C': '#C8C8C0'}],
    'hotel': [{'#E8E0D0': '#D8C0A8'}, {'#E8E0D0': '#B8C8D0'}],
    'gasolinera': [{'#2E8A4A': '#C8402E'}, {'#2E8A4A': '#3E5FA8'}],
}
VAR_ERA = {'1929': {'vecinos_deco': [{'#D9CDB0': '#D8B49A', '#B8AC90': '#B89478'}, {'#D9CDB0': '#BDB8A6', '#B8AC90': '#9E9A8A'}],
                    'cine': [{'#8E4A3E': '#4E5A6E', '#C8553D': '#E3A93B'}],
                    'banco': [{'#C8C2B0': '#D0BC98', '#ECE6D2': '#F0E2C0', '#B8B2A0': '#C0A880'}]}}
MAXA = 124


def put(dirp, man, name, im, a, fp):
    assert a[1] <= MAXA, (name, a)
    im.save(os.path.join(dirp, name))
    man[name] = dict(w=im.size[0], h=im.size[1], anchor_x=a[0], anchor_y=a[1], footprint=list(fp))


def main_set():
    d = f'{HS}/assets/sprites/A'
    mp = json.load(open(f'{d}/manifest.json'))
    man = mp['sprites']
    n = 0
    for key, name, w, dd, fn, tag in arch2.PRESENTE:
        sts = ['normal'] if key in LANDMARKS else STATES
        for st in sts:
            im, a = arch2.render2(fn, w, dd, era='presente', state=st, key=key)
            put(d, man, f'{key}_{st}.png', im, a, (w, dd)); n += 1
        for k, sw in enumerate(VAR_MAIN.get(key, []), 1):
            for st in ('normal', 'reformada', 'alquilada'):
                im, a = arch2.render2(fn, w, dd, era='presente', state=st, key=key, swaps=sw)
                put(d, man, f'{key}_v{k}_{st}.png', im, a, (w, dd)); n += 1
    json.dump(mp, open(f'{d}/manifest.json', 'w'), ensure_ascii=False, indent=1)
    return n


def era_set(era):
    d = f'{HS}/assets/eras/{era}/sprites'
    os.makedirs(d, exist_ok=True)
    man = {}
    for key, name, w, dd, fn, tag in arch_eras.ERAS2[era]:
        for st in STATES:
            im, a = arch2.render2(fn, w, dd, era=era, state=st, key=key)
            put(d, man, f'{key}_{st}.png', im, a, (w, dd))
        for k, sw in enumerate(VAR_ERA.get(era, {}).get(key, []), 1):
            for st in STATES:
                im, a = arch2.render2(fn, w, dd, era=era, state=st, key=key, swaps=sw)
                put(d, man, f'{key}_v{k}_{st}.png', im, a, (w, dd))
    json.dump({'tile': {'w': 40, 'h': 20}, 'era': era,
               'note': 'Sprites v2 de la época ' + era + '. anchor = píxel del vértice superior de la casilla (0,0) de la huella.',
               'sprites': man}, open(f'{d}/manifest.json', 'w'), ensure_ascii=False, indent=1)
    return len(man)


if __name__ == '__main__':
    print('A', main_set())
    for e in arch_eras.ERAS2:
        print(e, era_set(e))
