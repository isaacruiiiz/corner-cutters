# Corner Cutters · ficha de la tienda (12-11-2026)

Todo lo de aquí está listo para copiar en Play Console (y sirve casi igual para App Store Connect). Los límites de Play están comprobados: título ≤ 30, descripción breve ≤ 80, completa ≤ 4000.

## Material gráfico
| Pieza | Dónde está | Estado |
|---|---|---|
| Icono 512×512 | `site/img/icono.png` | Ya existía |
| Gráfico de cabecera 1024×500 | `tienda/cabecera_1024x500.png` (se regenera con `python3 tool/tienda/cabecera.py`) | Hecho |
| Capturas 1080×1920 con rótulo, en los 5 idiomas | `python3 tool/tienda/enmarcar.py` | Falta hacer las 5 capturas en el móvil |

Capturas: deja en `tienda/capturas/es/` cinco capturas numeradas (`1.png` mapa, `2.png` obra, `3.png` venta o alquiler, `4.png` empresa, `5.png` épocas) y ejecuta el script. Salen en `tienda/ficha/<idioma>/`. Si quieres capturas con la interfaz en cada idioma, ponlas en `tienda/capturas/<idioma>/`; si no, se usan las de `es` con el rótulo traducido. Los rótulos están en `tool/tienda/textos.json`.

## Datos generales
- Tipo: Juego · Categoría: Simulación · Etiquetas: Idle, Tycoon, Gestión.
- Gratis, con anuncios y compras en la app.
- Correo de contacto: el de la cuenta de desarrollador.
- Política de privacidad: https://corner-cutters.pages.dev/privacidad/
- Borrar cuenta: https://corner-cutters.pages.dev/borrar-cuenta/
- Acceso a la app: «Todas las funciones están disponibles sin acceso especial» (se juega como invitado).
- Público objetivo: 16-17 y 18 o más (la política de privacidad dice que no va dirigido a menores de 16; no marcar franjas inferiores para no entrar en el programa Familias).
- Anuncios: Sí, contiene anuncios.
- Productos de la app (no consumibles): `cc_epocas` (Pack de épocas) y `cc_pro` (Pro, sin anuncios).

## Textos por idioma

### Español (España) · es-ES

**Título** (30/30)

```
Corner Cutters: ruinas y pisos
```

**Descripción breve** (76/80)

```
Compra ruinas, refórmalas a toques y alquila o vende. El mercado ya opinará.
```

**Descripción completa** (1921/4000)

```
Empiezas con 10.000 dólares, dos pisos en ruinas y mucho optimismo. Lo normal en el sector.

Corner Cutters es un juego incremental de propiedades: compras viviendas en ruinas, las reformas tú mismo tocando la pantalla y decides si alquilarlas o venderlas. Con lo que ganes, compras la siguiente. Y luego el edificio. Y luego el barrio.

REFORMA CON TUS MANOS
• Cinco oficios, cinco minijuegos: albañilería, fontanería, electricidad, carpintería y decoración.
• Cada oficio sube de nivel por separado y tú eliges hasta dónde reformar cada casa.
• Pasarte de calidad también cuesta dinero. Ajustar al público es el verdadero oficio.

ALQUILA O VENDE
• Pon el precio: pedir menos atrae compradores; pedir más, ofertas mejores (o ninguna).
• Inquilinos con carácter: ejemplares, despistados y de los otros.
• Un mercado con cinco fases, de la crisis a la burbuja. Comprar en rojo tiene premio.

DE MANITAS A EMPRESA
• Contrata cuadrillas que reforman solas mientras tú miras el móvil. O no lo miras.
• Hipotecas, encargos de clientes, inversores rivales y un banco con poca paciencia.
• Sucesos: averías, inspecciones, temporales y alguna oferta inesperada.

UNA CIUDAD DISTINTA CADA VEZ
• Mapa isométrico en pixel art generado por semilla: no hay dos ciudades iguales.
• Funda ciudades nuevas y conserva tu reputación.
• Ranking mundial por reputación y patrimonio.

PACK DE ÉPOCAS
• 1929, el crac, es gratis. El pack añade 1888, 1980, 2005, 2020 y 2050.
• Cada época tiene sus reglas, sus edificios, sus reformas de entonces y su medalla de bronce, plata y oro.

JUEGA A TU RITMO
• El juego sigue hasta 8 horas con la app cerrada y te avisa cuando acaba una obra.
• Partida en la nube con cuenta opcional. También se juega sin conexión.
• En español, catalán, inglés, alemán y chino.

SIN TRAMPA
Nunca se vende dinero del juego. Los anuncios son opcionales (a cambio de impulsos) más algún intermedio; con Pro desaparecen.
```

### Català · ca

**Título** (30/30)

```
Corner Cutters: ruïnes i pisos
```

**Descripción breve** (78/80)

```
Compra ruïnes, reforma-les a tocs i lloga o ven. El mercat ja hi dirà la seva.
```

**Descripción completa** (1889/4000)

```
Comences amb 10.000 dòlars, dos pisos en ruïnes i molt d’optimisme. El normal al sector.

Corner Cutters és un joc incremental de propietats: compres habitatges en ruïnes, els reformes tu mateix tocant la pantalla i decideixes si llogar-los o vendre’ls. Amb el que guanyis, compres el següent. I després l’edifici. I després el barri.

REFORMA AMB LES TEVES MANS
• Cinc oficis, cinc minijocs: paleta, lampisteria, electricitat, fusteria i decoració.
• Cada ofici puja de nivell per separat i tu tries fins on reformar cada casa.
• Passar-se de qualitat també costa diners. Ajustar-se al públic és l’ofici de debò.

LLOGA O VEN
• Posa el preu: demanar menys atrau compradors; demanar més, ofertes millors (o cap).
• Llogaters amb caràcter: exemplars, despistats i dels altres.
• Un mercat amb cinc fases, de la crisi a la bombolla. Comprar en vermell té premi.

DE MANETES A EMPRESA
• Contracta colles que reformen soles mentre tu mires el mòbil. O no el mires.
• Hipoteques, encàrrecs de clients, inversors rivals i un banc amb poca paciència.
• Successos: avaries, inspeccions, temporals i alguna oferta inesperada.

UNA CIUTAT DIFERENT CADA VEGADA
• Mapa isomètric en pixel art generat per llavor: no hi ha dues ciutats iguals.
• Funda ciutats noves i conserva la teva reputació.
• Rànquing mundial per reputació i patrimoni.

PACK D’ÈPOQUES
• 1929, el crac, és gratis. El pack afegeix 1888, 1980, 2005, 2020 i 2050.
• Cada època té les seves regles, els seus edificis, les reformes d’aleshores i la seva medalla de bronze, plata i or.

JUGA AL TEU RITME
• El joc continua fins a 8 hores amb l’app tancada i t’avisa quan acaba una obra.
• Partida al núvol amb compte opcional. També es juga sense connexió.
• En català, castellà, anglès, alemany i xinès.

SENSE TRAMPA
Mai es venen diners del joc. Els anuncis són opcionals (a canvi d’impulsos) més algun intermedi; amb Pro desapareixen.
```

### English (United States) · en-US

**Título** (29/30)

```
Corner Cutters: Property Idle
```

**Descripción breve** (78/80)

```
Buy ruins, renovate them tap by tap, then rent or sell. The market will judge.
```

**Descripción completa** (1913/4000)

```
You start with $10,000, two run-down flats and a lot of optimism. Standard for the industry.

Corner Cutters is an incremental property game: buy run-down homes, renovate them yourself by tapping, then decide whether to rent them out or sell. Use the profit to buy the next one. Then the building. Then the neighborhood.

RENOVATE WITH YOUR OWN HANDS
• Five trades, five minigames: masonry, plumbing, electrics, carpentry and decorating.
• Each trade levels up on its own, and you choose how far to take every renovation.
• Overbuilding costs money too. Matching the home to its market is the real trade.

RENT OR SELL
• Set the price: ask less and buyers show up; ask more and the offers get better (or stop coming).
• Tenants with personality: model ones, forgetful ones, and the other kind.
• A market with five phases, from crisis to bubble. Buying in the red pays off.

FROM HANDYMAN TO COMPANY
• Hire crews that renovate on their own while you check your phone. Or don’t.
• Mortgages, client commissions, rival investors and a bank with very little patience.
• Events: breakdowns, inspections, storms and the occasional surprise offer.

A DIFFERENT CITY EVERY TIME
• Isometric pixel-art map generated from a seed: no two cities are the same.
• Found new cities and keep your reputation.
• Global leaderboard by reputation and net worth.

ERAS PACK
• 1929, the crash, is free. The pack adds 1888, 1980, 2005, 2020 and 2050.
• Every era has its own rules, buildings, period-correct renovations and bronze, silver and gold medals.

PLAY AT YOUR OWN PACE
• The game keeps going for up to 8 hours while the app is closed and tells you when a job is done.
• Cloud save with an optional account. Works offline too.
• Available in English, Spanish, Catalan, German and Chinese.

NO TRICKS
In-game money is never for sale. Ads are optional (in exchange for boosts) plus the occasional interstitial; Pro removes them.
```

### Deutsch · de-DE

**Título** (26/30)

```
Corner Cutters: Immobilien
```

**Descripción breve** (79/80)

```
Kauf Ruinen, saniere per Fingertipp, vermiete oder verkaufe. Der Markt urteilt.
```

**Descripción completa** (2080/4000)

```
Du startest mit 10.000 Dollar, zwei Bruchbuden und viel Optimismus. Branchenüblich.

Corner Cutters ist ein Immobilien-Idle-Spiel: Du kaufst heruntergekommene Wohnungen, sanierst sie selbst per Fingertipp und entscheidest, ob du vermietest oder verkaufst. Vom Gewinn kaufst du die nächste. Dann das Haus. Dann das Viertel.

SANIERE MIT EIGENEN HÄNDEN
• Fünf Gewerke, fünf Minispiele: Maurerarbeiten, Sanitär, Elektrik, Tischlerei und Dekoration.
• Jedes Gewerk steigt einzeln auf, und du entscheidest, wie weit du jede Wohnung sanierst.
• Zu viel Qualität kostet auch Geld. Die Wohnung auf ihr Publikum abzustimmen ist das eigentliche Handwerk.

VERMIETEN ODER VERKAUFEN
• Lege den Preis fest: Wer weniger verlangt, lockt Käufer an; wer mehr verlangt, bekommt bessere Angebote (oder keine).
• Mieter mit Charakter: vorbildliche, vergessliche und die anderen.
• Ein Markt mit fünf Phasen, von der Krise bis zur Blase. Wer in der Krise kauft, wird belohnt.

VOM HEIMWERKER ZUR FIRMA
• Stelle Trupps ein, die allein sanieren, während du aufs Handy schaust. Oder auch nicht.
• Hypotheken, Kundenaufträge, rivalisierende Investoren und eine Bank mit wenig Geduld.
• Ereignisse: Pannen, Inspektionen, Unwetter und ab und zu ein unerwartetes Angebot.

JEDES MAL EINE ANDERE STADT
• Isometrische Pixel-Art-Karte aus einem Seed: Keine Stadt gleicht der anderen.
• Gründe neue Städte und behalte deinen Ruf.
• Weltweite Rangliste nach Ruf und Vermögen.

EPOCHEN-PAKET
• 1929, der Börsenkrach, ist kostenlos. Das Paket bringt 1888, 1980, 2005, 2020 und 2050.
• Jede Epoche hat eigene Regeln, Gebäude, zeitgemäße Sanierungen und Medaillen in Bronze, Silber und Gold.

SPIEL IN DEINEM TEMPO
• Das Spiel läuft bis zu 8 Stunden weiter, wenn die App geschlossen ist, und meldet sich, wenn eine Baustelle fertig ist.
• Cloud-Speicherstand mit optionalem Konto. Funktioniert auch offline.
• Auf Deutsch, Englisch, Spanisch, Katalanisch und Chinesisch.

OHNE TRICKS
Spielgeld wird nie verkauft. Werbung ist freiwillig (gegen Boosts), dazu gelegentlich eine Zwischenanzeige; mit Pro verschwindet sie.
```

### 中文（简体）· zh-CN

**Título** (21/30)

```
Corner Cutters：危房翻新大亨
```

**Descripción breve** (28/80)

```
买下危房，点击屏幕亲手翻新，再出租或出售。市场自有评价。
```

**Descripción completa** (684/4000)

```
开局只有 10,000 美元、两套危房和满满的乐观。这在业内很正常。

Corner Cutters 是一款房产放置游戏：买下破旧的房子，点击屏幕亲手翻新，再决定出租还是出售。赚到的钱拿去买下一间，然后是整栋楼，然后是整个街区。

亲手翻新
• 五个工种，五种小游戏：泥瓦、水管、电工、木工和装饰。
• 每个工种单独升级，每套房翻新到什么程度由你决定。
• 装修过头同样费钱。贴合目标人群，才是真功夫。

出租还是出售
• 自己定价：要价低，买家多；要价高，报价更好（或者没有报价）。
• 性格各异的租客：模范的、健忘的，还有另一种。
• 市场有五个阶段，从危机到泡沫。逆势买入自有回报。

从小工到公司
• 雇佣施工队，你看手机的时候他们自己干活。不看也行。
• 抵押贷款、客户委托、竞争对手，还有一家没什么耐心的银行。
• 突发事件：故障、检查、暴风雨，偶尔还有意外报价。

每次都是不同的城市
• 由种子生成的等距像素风地图：没有两座相同的城市。
• 建立新城市，并保留你的声望。
• 按声望和资产排名的全球排行榜。

年代包
• 1929 年大崩盘免费游玩。年代包另含 1888、1980、2005、2020 和 2050。
• 每个年代都有自己的规则、建筑、符合时代的装修，以及铜、银、金牌。

按自己的节奏玩
• 关闭应用后游戏最多继续运行 8 小时，工程完工时会通知你。
• 可选账号云存档，离线也能玩。
• 支持中文、英语、西班牙语、加泰罗尼亚语和德语。

不玩套路
游戏币永不出售。广告自愿观看（换取加速），偶尔有插屏广告；购买 Pro 后全部移除。
```

## Novedades de la versión 1.0.0
```
Primera versión. Compra ruinas, reforma, alquila o vende. Suerte.
```

## Seguridad de los datos (formulario de Play)
Respuestas según lo que hace la app en la versión 1.0.0. Revísalas si cambias de SDK.

- ¿Recoge o comparte datos? **Sí.**
- ¿Cifrados en tránsito? **Sí.**
- ¿Se puede pedir el borrado? **Sí**, con la URL de borrar cuenta de arriba.

| Tipo de dato | ¿Recogido? | ¿Compartido? | ¿Obligatorio? | Finalidad |
|---|---|---|---|---|
| Correo electrónico | Sí | No | Opcional (solo con cuenta) | Gestión de la cuenta |
| ID de usuario (identificador de jugador) | Sí | No | Obligatorio | Funciones de la app, analíticas |
| Historial de compras | Sí | No | Opcional | Funciones de la app |
| Interacciones con la app (pasos del juego, duración de la sesión) | Sí | No | Opcional (Ajustes → Datos de uso) | Analíticas |
| Otro contenido generado por el usuario (alias del ranking) | Sí | No | Opcional | Funciones de la app |
| Registros de fallos y diagnóstico | Sí | No | Opcional | Analíticas |
| ID de dispositivo u otros (ID de publicidad) | Sí | Sí (Google AdMob) | Obligatorio para quien ve anuncios | Publicidad, analíticas, prevención de fraude |
| Ubicación aproximada (deducida de la IP por AdMob) | Sí | Sí (Google AdMob) | Obligatorio para quien ve anuncios | Publicidad |

Las dos últimas filas vienen del SDK de anuncios, no del juego: contrástalas con la guía de AdMob para esta sección al rellenar el formulario, porque Google la actualiza.

## Clasificación de contenido (cuestionario IARC)
- Categoría: Juego.
- Violencia, sangre, miedo: No.
- Sexualidad o desnudez: No.
- Lenguaje soez: No. Humor crudo: No.
- Drogas, alcohol o tabaco: No.
- Juegos de azar reales o simulados: No (se especula con pisos, no hay apuestas ni casino).
- ¿Los usuarios pueden interactuar o intercambiar contenido? Sí, mínimamente: un alias visible en el ranking. El servidor lo filtra y los invitados salen como «Promotor anónimo». No hay chat.
- ¿Comparte la ubicación con otros usuarios? No.
- ¿Permite comprar productos digitales? Sí.

## App Store (cuando toque)
Sirven los mismos textos: nombre (30), subtítulo (30, usa una versión corta de la descripción breve), descripción y palabras clave. En «Privacidad de la app» declara lo mismo que en la tabla de arriba; el seguimiento (ATT) solo lo provoca AdMob.

## Lo que sigue siendo manual
1. Capturas en el móvil (5) y ejecutar `enmarcar.py`.
2. Subir textos, gráficos y cuestionarios a Play Console.
3. Crear los productos `cc_epocas` y `cc_pro` y poner precio.
4. Prueba cerrada (12 testers, 14 días seguidos) si la cuenta de Play es personal y posterior al 13-11-2023.
