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
5. Ejecuta por último `supabase/seguridad.sql`: el ranking pasa a escribirlo el servidor (topes, filtro de alias, invitados como «Promotor anónimo»), tope de tamaño de la partida, compras acotadas, partidas y medallas de época en la nube y telemetría propia (eventos de uso y errores, visibles en el panel admin → Uso y Errores). Se puede volver a ejecutar. La app funciona también sin él: usa el camino antiguo hasta que exista `guardar_partida`.

En Supabase → Authentication conviene tener activados «Confirm email», la protección de contraseñas filtradas y el captcha para las altas anónimas.

## Web (Cloudflare Pages)

Proyecto `corner-cutters` → https://corner-cutters.pages.dev. La web NO sirve el juego: es la página de descarga (`site/index.html`), el panel admin (`/admin/`), la política de privacidad (`/privacidad/`) y la página para borrar la cuenta (`/borrar-cuenta/`).

- Framework preset: *None*
- Build command: *(vacío)*
- Build output directory: `site`

`site/config.json` es una copia de `assets/config.json` (lo leen el panel admin y la página de borrar cuenta): si cambias las claves, cambia los dos.
Enlaces de las tiendas: constante `TIENDAS` al final de `site/index.html` (el de App Store vacío sale como «Próximamente»).

## Google Play

- Paquete: `com.isaacruiiiz.cornercutters`.
- Firma de subida: `tool/crear_firma.command` (una vez). Crea `android/key.properties`, que nunca se sube al repo.
- `.aab`: `tool/play.command` → `build/app/outputs/bundle/release/app-release.aab`.

## Comprobación automática (GitHub Actions)

`.github/workflows/ci.yml` analiza, pasa los tests y compila el APK en cada subida a `main` o `prelanzamiento` y en cada pull request. El APK queda como artefacto de la ejecución (firmado con la clave de depuración).

## Notificaciones, datos de uso y valoración

- `lib/services/avisos*.dart`: notificaciones locales. Al cerrar el juego, `Game.forecast()` repite sobre una copia lo que hará `catchUp` y `planAvisos` decide cuáles se programan (interruptores de Ajustes → Notificaciones, silencio nocturno, una por tipo). Se cancelan al volver. El permiso se ofrece tras la primera obra.
- `lib/services/telemetria.dart`: eventos de uso y errores a Supabase (`registrar_eventos`, `registrar_error`). Interruptor en Ajustes → Datos de uso.
- `lib/services/social.dart`: valoración en la tienda (tras una venta con beneficio o una medalla; nunca el primer día) y compartir.

## Estructura

- `lib/game/` — reglas: `economy.dart` (fórmulas del documento), `engine.dart` (reloj, mercado, obras, cuadrillas, inquilinos, ventas, eventos, offline, guardado), `city.dart` (ciudad procedural por semilla), `model.dart`, `data.dart`, `texts.dart`.
- `lib/ui/map/` — mapa isométrico pixel art (`city_render.dart`) e interacción (`map_view.dart`, `map_screen.dart`).
- `lib/ui/minigames/` — los cinco gestos de obra (albañilería, fontanería, electricidad, carpintería, decoración).
- `lib/ui/screens/` — ficha, selector de reforma, obra, alquilar/vender, comprar, empresa, mercado, hipotecas, eventos, cartera, barrio, prestigio, tienda, pase, ajustes…
- `lib/ui/widgets/atoms.dart` — sistema de diseño Refinado (Jersey 15 + Manrope, teal y dorado, sombras duras).

## Script de apoyo

`tool/flutter.command` ejecuta el paso escrito en `tool/paso` (`analyze`, `web`, `apk`…) y deja el log en `tool/ultimo.log`.
