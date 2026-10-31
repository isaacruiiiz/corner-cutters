import sys
import arch2, arch_eras, mapgen2
HS = sys.argv[1]
for era, lst in arch_eras.ERAS2.items():
    items = []
    for key, name, w, d, fn, tag in lst:
        wt = -0.8 if tag == 'monumento' else (0.45 if key in ('torre_deco', 'hotel_deco', 'torre_cristal', 'torre_madera', 'hub_drones', 'torre_jardines', 'torre_eolica', 'grua_obra') else 1.0)
        items.append((key, w, d, wt, (lambda st, fn=fn, w=w, d=d, key=key, era=era: arch2.render2(fn, w, d, era=era, state=st, key=key))))
    m = mapgen2.build(era, items, n=12, seed=4, top=160)
    m.save(f'{HS}/assets/eras/portadas/{era}.png')
    print(era, m.size)
