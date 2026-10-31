# Corner Cutters · Property idle game

Juego móvil incremental de propiedades (Flutter + Riverpod + Supabase). Compra ruinas, reforma tocando la pantalla, alquila o vende, monta tu empresa de reformas y llega a tener barrios enteros.

## Arrancar

```bash
cd ~/Proyectos/corner-cutters
flutter pub get
flutter run
```

## Supabase

1. Crea un proyecto en Supabase y activa **Authentication → Providers → Anonymous sign-ins**.
2. Ejecuta `supabase/schema.sql` en el SQL Editor (tablas `partidas`, `ranking`, `titulares` con RLS).
3. Pon la URL y la clave publicable en `assets/config.json` (`supabaseUrl`, `supabaseKey`).

Sin claves, el juego funciona entero en local (guardado en el móvil). Con claves: cuenta anónima, guardado en la nube, vincular email y ranking.

4. Ejecuta después `supabase/cuentas.sql` (tipos de usuario, pack regalado, compras, panel admin y borrar cuenta).

## Web (Cloudflare Pages)

Proyecto `corner-cutters` → https://corner-cutters.pages.dev. Sirve el juego en web, el panel admin (`/admin/`), la política de privacidad (`/privacidad/`) y la página para borrar la cuenta (`/borrar-cuenta/`).

- Framework preset: *None*
- Build command: `git clone https://github.com/flutter/flutter.git -b stable --depth 1 /tmp/flutter && /tmp/flutter/bin/flutter build web --release`
- Build output directory: `build/web`

## Google Play

- Paquete: `com.isaacruiiiz.cornercutters`.
- Firma de subida: `tool/crear_firma.command` (una vez). Crea `android/key.properties`, que nunca se sube al repo.
- `.aab`: `tool/play.command` → `build/app/outputs/bundle/release/app-release.aab`.

## Estructura

- `lib/game/` — reglas: `economy.dart` (fórmulas del documento), `engine.dart` (reloj, mercado, obras, cuadrillas, inquilinos, ventas, eventos, offline, guardado), `city.dart` (ciudad procedural por semilla), `model.dart`, `data.dart`, `texts.dart`.
- `lib/ui/map/` — mapa isométrico pixel art (`city_render.dart`) e interacción (`map_view.dart`, `map_screen.dart`).
- `lib/ui/minigames/` — los cinco gestos de obra (albañilería, fontanería, electricidad, carpintería, decoración).
- `lib/ui/screens/` — ficha, selector de reforma, obra, alquilar/vender, comprar, empresa, mercado, hipotecas, eventos, cartera, barrio, prestigio, tienda, pase, ajustes…
- `lib/ui/widgets/atoms.dart` — sistema de diseño Refinado (Jersey 15 + Manrope, teal y dorado, sombras duras).

## Script de apoyo

`tool/flutter.command` ejecuta el paso escrito en `tool/paso` (`analyze`, `web`, `apk`…) y deja el log en `tool/ultimo.log`.
