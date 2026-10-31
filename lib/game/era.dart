import 'data.dart';

/// DLC de épocas: partidas cerradas en Alba Nova con reglas propias.
/// El modo principal no tiene época (`Game.eraCfg == null`) y ninguna de estas reglas le afecta.

/// Regla visible de una época (ventaja, pega u ojo).
enum EraRuleKind { ventaja, pega, ojo }

class EraRule {
  final EraRuleKind kind;
  final String title;
  final String desc;
  const EraRule(this.kind, this.title, this.desc);
}

/// Suceso fijo del calendario de una época (sale en la prensa y como aviso).
class EraEvent {
  final int month; // meses desde el inicio de la época
  final String title;
  final String body;
  const EraEvent(this.month, this.title, this.body);
}

/// Tramo del calendario: desde [from] (mes), fase del mercado y multiplicadores de la época.
class EraSpan {
  final int from;
  final MarketPhase phase;
  /// Precios de compraventa sobre los de la fase.
  final double price;
  /// Alquileres sobre los de la fase.
  final double rent;
  /// Precio de las ruinas y viviendas sin reformar que salen al mercado.
  final double ruins;
  /// Se puede pedir hipoteca.
  final bool credit;
  const EraSpan(this.from, this.phase, {this.price = 1, this.rent = 1, this.ruins = 1, this.credit = true});
}

/// Qué cuenta para las medallas de una época.
enum EraMetric { patrimonio, viviendas, alquiladas, reformas }

/// Estilo de la portada de la hemeroteca.
enum PressStyle { gaceta, broadsheet, vespertino, correo, app, feed }

class EraConfig {
  final String id;
  final String name;
  final String sub;
  final int startYear;
  final int endYear; // incluido
  final double startCash;
  final bool free;
  /// Jugable en esta versión (las demás se ven en la hemeroteca como «próximamente»).
  final bool playable;
  final String goal;
  /// Patrimonio para bronce, plata y oro.
  final List<double> medals;
  final List<EraRule> rules;
  final List<EraSpan> spans;
  final List<EraEvent> events;
  final Map<MarketPhase, List<String>> news;
  /// Probabilidad de embargo en crisis al reponer anuncios.
  final double embargoChance;
  /// Año en que vuelve el crédito (para el aviso de hipotecas), o null si nunca se corta.
  final int? creditYear;
  /// Nivel de precios de la época respecto a hoy: lo que se muestra en pantalla (dólares de la época).
  final double priceLevel;
  /// Qué mide el objetivo (patrimonio, viviendas en cartera, alquiladas o reformas terminadas).
  final EraMetric metric;
  /// Interés de las hipotecas respecto al normal.
  final double rate;
  /// Potencia de los toques en obra (obras a mano en 1888: más lentas).
  final double tapMult;
  /// Ritmo de las cuadrillas (drones en 2050: más rápidas).
  final double crewMult;

  // Portada.
  final PressStyle press;
  final String masthead;
  final String issue;
  final String price;
  final String date;
  final String headline;
  final String deck;
  final String footer;

  // Fin de época.
  final String quoteGold, quoteSilver, quoteBronze, quoteNone;

  const EraConfig({
    required this.id,
    required this.name,
    required this.sub,
    required this.startYear,
    required this.endYear,
    required this.startCash,
    required this.free,
    required this.playable,
    required this.goal,
    required this.medals,
    required this.rules,
    required this.spans,
    this.events = const [],
    this.news = const {},
    this.embargoChance = 0.22,
    this.creditYear,
    this.priceLevel = 1,
    this.metric = EraMetric.patrimonio,
    this.rate = 1,
    this.tapMult = 1,
    this.crewMult = 1,
    required this.press,
    required this.masthead,
    required this.issue,
    required this.price,
    required this.date,
    required this.headline,
    required this.deck,
    this.footer = '',
    this.quoteGold = '',
    this.quoteSilver = '',
    this.quoteBronze = '',
    this.quoteNone = '',
  });

  int get months => (endYear - startYear + 1) * 12;
  int get years => endYear - startYear + 1;

  EraSpan spanAt(int month) {
    var s = spans.first;
    for (final x in spans) {
      if (month >= x.from) s = x;
    }
    return s;
  }

  MarketPhase phaseAt(int month) => spanAt(month).phase;
  double priceMult(int month) => spanAt(month).price;
  double rentMult(int month) => spanAt(month).rent;
  double ruinMult(int month) => spanAt(month).ruins;
  bool creditAt(int month) => spanAt(month).credit;

  /// Primer mes posterior a [month] en que cambia la fase del mercado (o el final de la época).
  int nextChange(int month) {
    final p = phaseAt(month);
    for (var m = month + 1; m < months; m++) {
      if (phaseAt(m) != p) return m;
    }
    return months;
  }

  List<String>? newsFor(MarketPhase p) => news[p];

  /// Medalla para un patrimonio: 3 oro, 2 plata, 1 bronce, 0 ninguna.
  int medalFor(double netWorth) {
    var m = 0;
    for (var i = 0; i < medals.length; i++) {
      if (netWorth >= medals[i]) m = i + 1;
    }
    return m;
  }

  String quoteFor(int medal) => switch (medal) {
        3 => quoteGold,
        2 => quoteSilver,
        1 => quoteBronze,
        _ => quoteNone,
      };

  static EraConfig? byId(String? id) {
    if (id == null) return null;
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  static const all = [era1888, era1929, era1980, era2005, era2020, era2050];
}

const medalNames = ['Sin medalla', 'Bronce', 'Plata', 'Oro'];

// ======================================================================
// 1929 · El crac (jugable)
// ======================================================================
const era1929 = EraConfig(
  id: '1929',
  name: 'El crac',
  sub: 'Euforia, art déco y caída',
  startYear: 1929,
  endYear: 1933,
  startCash: 40000,
  free: true,
  playable: true,
  goal: 'Patrimonio al cerrar 1933',
  medals: [250000, 500000, 1000000],
  rules: [
    EraRule(EraRuleKind.pega, 'Crac de octubre', 'En octubre de 1929 el mercado pasa a crisis y los precios se hunden.'),
    EraRule(EraRuleKind.ojo, 'Sin crédito', 'Los bancos cierran el grifo hasta 1933: solo efectivo.'),
    EraRule(EraRuleKind.ventaja, 'Ruinas en saldo', 'Tras el crac salen ruinas y embargos muy por debajo de su valor.'),
  ],
  spans: [
    EraSpan(0, MarketPhase.burbuja, credit: false),
    EraSpan(9, MarketPhase.crisis, price: 0.75, rent: 0.9, ruins: 0.8, credit: false),
    EraSpan(10, MarketPhase.crisis, price: 0.6, rent: 0.85, ruins: 0.65, credit: false),
    EraSpan(11, MarketPhase.crisis, price: 0.5, rent: 0.8, ruins: 0.6, credit: false),
    EraSpan(36, MarketPhase.estanc, price: 0.55, rent: 0.85, ruins: 0.7, credit: false),
    EraSpan(48, MarketPhase.recup, price: 0.6, rent: 0.9, ruins: 0.8, credit: true),
  ],
  events: [
    EraEvent(0, 'Alba Nova vive su mejor año', 'Los locos años veinte llegan a su cima. Todo el mundo compra; nadie pregunta.'),
    EraEvent(9, 'Jueves Negro: la bolsa se desploma', 'Los banqueros piden calma desde la cubierta de sus yates.'),
    EraEvent(14, 'Quiebra el Banco de Alba Nova', 'Las colas llegan hasta la esquina. Los ahorros, no.'),
    EraEvent(36, 'El mercado toca fondo', 'Los precios ya no bajan. Tampoco suben.'),
    EraEvent(48, 'Vuelve el crédito', 'Los bancos reabren la ventanilla. Con interés.'),
  ],
  news: {
    MarketPhase.burbuja: [
      'Los expertos aseguran que la bolsa nunca baja',
      'Récord de compraventas: hasta el limpiabotas tiene acciones',
      'Se levanta otra torre déco. Ya van tres este mes',
    ],
    MarketPhase.crisis: [
      'Colas en los bancos y ruinas en cada esquina',
      'Los especuladores se tiran de los pelos; tú, de la chequera',
      'Se alquila barato. Se vende más barato todavía',
    ],
    MarketPhase.estanc: [
      'Nada se mueve en Alba Nova, salvo los desahucios',
      'Los precios ya no bajan. Tampoco suben',
    ],
    MarketPhase.recup: [
      'Vuelve el crédito: los bancos olvidan rápido',
      'Brotes verdes en el Ensanche. Muy pequeños',
    ],
  },
  embargoChance: 0.35,
  creditYear: 1933,
  priceLevel: 0.1,
  press: PressStyle.broadsheet,
  masthead: 'El Correo de Alba Nova',
  issue: 'Año XLI · Nº 12.408',
  price: '3 centavos',
  date: 'Jueves 24 de octubre de 1929 · Tercera edición',
  headline: 'La bolsa se desploma',
  deck: 'Los banqueros piden calma desde la cubierta de sus yates.',
  footer: 'Quien vendió en septiembre hoy brinda. Quien no, compra ruinas a un tercio.',
  quoteGold: 'Vendiste en septiembre y compraste en diciembre. Ni los banqueros.',
  quoteSilver: 'Compraste barato y vendiste tarde. Muy de la época.',
  quoteBronze: 'Sobreviviste al crac. Que no es poco.',
  quoteNone: 'El crac te pilló con todo dentro. Como a casi todos.',
);

// ======================================================================
// Épocas del pack
// ======================================================================
const era1888 = EraConfig(
  id: '1888',
  name: 'La ciudad de gas',
  sub: 'Ensanche, vapor y farolas',
  startYear: 1888,
  endYear: 1893,
  startCash: 30000,
  free: false,
  playable: true,
  goal: 'Viviendas en cartera al cerrar 1893',
  metric: EraMetric.viviendas,
  medals: [6, 12, 20],
  priceLevel: 0.02,
  tapMult: 0.7,
  rules: [
    EraRule(EraRuleKind.ventaja, 'Solares baratos', 'Caen las murallas: ruinas y solares a precio de saldo hasta 1890.'),
    EraRule(EraRuleKind.pega, 'Obras a mano', 'Sin máquinas: cada toque en obra rinde un 30 % menos.'),
    EraRule(EraRuleKind.ojo, 'Llega el tranvía', 'En 1891 el Ensanche se revaloriza. Quien compró antes, gana.'),
  ],
  spans: [
    EraSpan(0, MarketPhase.recup, price: 0.9, ruins: 0.6),
    EraSpan(24, MarketPhase.expan, price: 1.0, ruins: 0.8),
    EraSpan(36, MarketPhase.expan, price: 1.2, rent: 1.1),
    EraSpan(54, MarketPhase.burbuja, price: 1.3, rent: 1.15),
    EraSpan(66, MarketPhase.estanc, price: 1.15, rent: 1.1),
  ],
  events: [
    EraEvent(0, 'Caen las murallas', 'Miles de solares a la venta. Se ruega no preguntar quién los vende.'),
    EraEvent(12, 'La fiebre de la piedra', 'Cada mes se levanta una manzana nueva en el Ensanche.'),
    EraEvent(36, 'Llega el tranvía al Ensanche', 'Los vecinos celebran. Los propietarios, más.'),
    EraEvent(54, 'Fiebre del oro… de ladrillo', 'Se especula con solares que aún son huertos.'),
    EraEvent(66, 'Se enfría el Ensanche', 'Ya no se vende todo antes de construirlo.'),
  ],
  news: {
    MarketPhase.recup: [
      'Se venden solares. Razón: notaría',
      'El gas llega a la calle Mayor; la luz, a nadie',
      'Los indianos vuelven con dinero y ganas de fachada',
    ],
    MarketPhase.expan: [
      'Otra manzana del Ensanche, otro chaflán',
      'El tranvía hace milagros: los pisos lejanos ya no lo son',
    ],
    MarketPhase.burbuja: [
      'Se especula con huertos: «serán solares», aseguran',
      'Hasta el sereno tiene una finca a medias',
    ],
    MarketPhase.estanc: [
      'Calma en el Ensanche. Demasiada',
      'Los compradores, de veraneo. Los vendedores, esperando',
    ],
  },
  embargoChance: 0.2,
  press: PressStyle.gaceta,
  masthead: 'La Gaceta del Ensanche',
  issue: 'Año I · Núm. 214',
  price: 'Dos céntimos',
  date: 'Alba Nova, martes 8 de mayo de 1888',
  headline: 'Caen las murallas',
  deck: 'Miles de solares a la venta. Se ruega no preguntar quién los vende.',
  footer: 'SE VENDEN SOLARES · Razón: Notaría Puig, calle Mayor 3',
  quoteGold: 'Media ciudad nueva lleva tu firma en la escritura.',
  quoteSilver: 'Compraste piedra antes que el tranvía. Bien visto.',
  quoteBronze: 'Algo de Ensanche te tocó. Que no es poco.',
  quoteNone: 'Las murallas cayeron y tú seguías mirando.',
);

const era1980 = EraConfig(
  id: '1980',
  name: 'Hipotecas al 17 %',
  sub: 'La ciudad quebrada',
  startYear: 1978,
  endYear: 1984,
  startCash: 25000,
  free: false,
  playable: true,
  goal: 'Reformas terminadas al cerrar 1984',
  metric: EraMetric.reformas,
  medals: [4, 8, 14],
  priceLevel: 0.3,
  rate: 3,
  rules: [
    EraRule(EraRuleKind.ventaja, 'Ruinas por todas partes', 'Medio barrio abandonado: ruinas y embargos a precio de saldo.'),
    EraRule(EraRuleKind.pega, 'Préstamos al 17 %', 'Las hipotecas pagan el triple de interés.'),
    EraRule(EraRuleKind.ojo, 'Crisis industrial', 'De 1979 a 1982 cierran las fábricas y el mercado se hunde.'),
  ],
  spans: [
    EraSpan(0, MarketPhase.estanc, ruins: 0.8),
    EraSpan(15, MarketPhase.crisis, price: 0.85, rent: 0.9, ruins: 0.55),
    EraSpan(51, MarketPhase.estanc, price: 0.9, ruins: 0.7),
    EraSpan(69, MarketPhase.recup, price: 1.0, rent: 1.05, ruins: 0.8),
  ],
  events: [
    EraEvent(0, 'La ciudad quebrada', 'Las naves del puerto llevan años cerradas. Los pisos de encima, también.'),
    EraEvent(15, 'Cierra la siderúrgica', 'Tres mil despidos y un barrio entero en venta.'),
    EraEvent(26, 'El interés llega al 17 %', '«El banco le recuerda que su sonrisa no es un aval».'),
    EraEvent(51, 'Toca fondo la crisis', 'Ya no cierra nada porque no queda nada que cerrar.'),
    EraEvent(69, 'Vuelven las grúas', 'Primeras rehabilitaciones en el casco. Con andamio y pancarta.'),
  ],
  news: {
    MarketPhase.estanc: [
      'Se traspasa local con persiana. Grafiti incluido',
      'Nadie compra, nadie vende, todos fuman',
    ],
    MarketPhase.crisis: [
      'Otra fábrica cerrada; otro bloque vacío',
      'El banco embarga y subasta: hoy, la calle entera',
      'Hipotecas al 17 %: pague ahora, llore después',
    ],
    MarketPhase.recup: [
      'Rehabilitar está de moda: el ayuntamiento pone la mitad',
      'Las naves del puerto se convierten en lofts. Nadie sabe qué es un loft',
    ],
  },
  embargoChance: 0.5,
  creditYear: 1978,
  press: PressStyle.vespertino,
  masthead: 'DIARIO VESPERTINO',
  issue: 'Edición de tarde',
  price: '25 ¢',
  date: 'Viernes, 14 de marzo de 1980',
  headline: 'El interés llega al 17 %',
  deck: '«El banco le recuerda que su sonrisa no es un aval», dicen en ventanilla.',
  footer: 'CLASIFICADOS · Se traspasa local con persiana. Grafiti incluido.',
  quoteGold: 'Rehabilitaste medio barrio cuando nadie daba un duro por él.',
  quoteSilver: 'Andamio, pancarta y renta. Lo hiciste.',
  quoteBronze: 'Algo levantaste entre tanto cierre.',
  quoteNone: 'La crisis se llevó tus ganas y tu crédito.',
);

const era2005 = EraConfig(
  id: '2005',
  name: 'La burbuja',
  sub: 'Grúas, pelotazos y 2008',
  startYear: 2005,
  endYear: 2009,
  startCash: 60000,
  free: false,
  playable: true,
  goal: 'Patrimonio neto al cerrar 2009',
  metric: EraMetric.patrimonio,
  medals: [400000, 900000, 2000000],
  priceLevel: 0.75,
  rate: 0.8,
  rules: [
    EraRule(EraRuleKind.ventaja, 'Todo sube', 'Cada año los precios suben otro 15 %.'),
    EraRule(EraRuleKind.ojo, 'Hipoteca fácil', 'El banco presta barato y no pregunta.'),
    EraRule(EraRuleKind.pega, 'Pinchazo en 2008', 'En septiembre de 2008 los precios caen y el crédito se cierra.'),
  ],
  spans: [
    EraSpan(0, MarketPhase.burbuja),
    EraSpan(12, MarketPhase.burbuja, price: 1.15),
    EraSpan(24, MarketPhase.burbuja, price: 1.3, rent: 1.1),
    EraSpan(36, MarketPhase.burbuja, price: 1.38, rent: 1.12),
    EraSpan(44, MarketPhase.crisis, price: 0.8, rent: 0.95, ruins: 0.6, credit: false),
    EraSpan(50, MarketPhase.crisis, price: 0.65, rent: 0.9, ruins: 0.5, credit: false),
  ],
  events: [
    EraEvent(0, 'El piso medio sube otro 17 %', 'Los expertos coinciden: el ladrillo nunca baja.'),
    EraEvent(20, 'Récord de grúas', 'Alba Nova tiene más grúas que árboles.'),
    EraEvent(36, 'Los bancos se miran raro', 'Nadie sabe qué es una hipoteca subprime, pero suena caro.'),
    EraEvent(44, 'Quiebra un gran banco americano', 'Aquí, de momento, nadie se da por aludido.'),
    EraEvent(50, 'El banco ya no presta', 'Las grúas se quedan quietas. Los pisos, vacíos.'),
  ],
  news: {
    MarketPhase.burbuja: [
      'Reserva con 6.000 \$ y vende antes de escriturar',
      'El ladrillo nunca baja, repiten en la tele',
      'Se vende piso sobre plano. El plano, también',
    ],
    MarketPhase.crisis: [
      'Pinchazo: las urbanizaciones se quedan a medio hacer',
      'El banco se queda los pisos. No sabe qué hacer con ellos',
      'Dación en pago: la palabra del año',
    ],
  },
  embargoChance: 0.4,
  creditYear: 2009,
  press: PressStyle.correo,
  masthead: 'AlbaMail',
  issue: 'Bandeja de entrada (1.204)',
  price: '',
  date: '06/06/2005',
  headline: 'El piso medio sube otro 17 %',
  deck: 'Los expertos coinciden: el ladrillo nunca baja. Reserva con 6.000 \$ y vende antes de escriturar.',
  quoteGold: 'Vendiste en 2007. Tú sí lo viste venir.',
  quoteSilver: 'Pillaste la ola y saltaste a tiempo. Casi.',
  quoteBronze: 'Saliste del pinchazo con algo en el bolsillo.',
  quoteNone: 'Compraste en 2008. Como todo el mundo.',
);

const era2020 = EraConfig(
  id: '2020',
  name: 'Todos en casa',
  sub: 'Teletrabajo y pisos turísticos',
  startYear: 2020,
  endYear: 2023,
  startCash: 80000,
  free: false,
  playable: true,
  goal: 'Viviendas alquiladas al cerrar 2023',
  metric: EraMetric.alquiladas,
  medals: [6, 12, 18],
  rules: [
    EraRule(EraRuleKind.pega, 'Confinamiento', 'De marzo de 2020 a junio de 2021 las rentas caen un 30 %.'),
    EraRule(EraRuleKind.ventaja, 'Todos buscan piso', 'Desde 2022 la demanda dispara los alquileres.'),
    EraRule(EraRuleKind.ojo, 'Inflación', 'En 2022 todo sube: precios, rentas y nervios.'),
  ],
  spans: [
    EraSpan(0, MarketPhase.expan),
    EraSpan(2, MarketPhase.crisis, price: 0.92, rent: 0.7, ruins: 0.8),
    EraSpan(18, MarketPhase.recup, price: 0.97, rent: 0.9),
    EraSpan(24, MarketPhase.expan, price: 1.05, rent: 1.15),
    EraSpan(36, MarketPhase.burbuja, price: 1.12, rent: 1.25),
  ],
  events: [
    EraEvent(0, 'La ciudad se queda en casa', 'Los pisos turísticos descubren que existen los vecinos.'),
    EraEvent(2, 'Confinamiento', 'Las terrazas se cotizan más que los áticos.'),
    EraEvent(18, 'Vuelven los turistas', 'Con mascarilla y maleta de ruedas.'),
    EraEvent(24, 'Todo el mundo busca piso', 'Cien visitas por anuncio. Ninguna con nómina.'),
    EraEvent(36, 'Alquiler récord', 'El ayuntamiento estudia topes. Los propietarios, abogados.'),
  ],
  news: {
    MarketPhase.expan: [
      'Teletrabajo: el estudio se llama ahora «despacho»',
      'Se buscan pisos con terraza. Y con wifi',
    ],
    MarketPhase.crisis: [
      'Calles vacías y pisos turísticos aún más vacíos',
      'Los inquilinos piden rebaja. Los bancos, paciencia',
    ],
    MarketPhase.recup: [
      'Vuelve el turismo. Vuelven las maletas',
      'Las cocinas fantasma ocupan los bajos',
    ],
    MarketPhase.burbuja: [
      'Récord de alquiler: un estudio, un riñón',
      'Coliving: compartir piso, pero con logo',
    ],
  },
  press: PressStyle.app,
  masthead: 'alba.news',
  issue: 'En directo',
  price: '',
  date: 'Vivienda · domingo 15 mar 2020',
  headline: 'La ciudad se queda en casa',
  deck: 'Los pisos turísticos descubren que existen los vecinos.',
  quoteGold: 'Llenaste la ciudad de inquilinos cuando nadie salía de casa.',
  quoteSilver: 'Rentas al día en plena tormenta. Nada mal.',
  quoteBronze: 'Algunos inquilinos aguantaron contigo.',
  quoteNone: 'Pisos vacíos y turistas en casa. Mal momento.',
);

const era2050 = EraConfig(
  id: '2050',
  name: 'Cota de inundación',
  sub: 'Clima, drones y azoteas verdes',
  startYear: 2050,
  endYear: 2055,
  startCash: 150000,
  free: false,
  playable: true,
  goal: 'Reformas terminadas al cerrar 2055',
  metric: EraMetric.reformas,
  medals: [5, 10, 16],
  priceLevel: 2.2,
  crewMult: 1.5,
  rules: [
    EraRule(EraRuleKind.pega, 'Riadas', 'En 2051 el río se desborda: precios a la baja y ruinas en la orilla.'),
    EraRule(EraRuleKind.ventaja, 'Drones', 'Las cuadrillas trabajan un 50 % más rápido.'),
    EraRule(EraRuleKind.ojo, 'Adaptar o perder', 'Desde 2054 las viviendas reformadas se alquilan más caras.'),
  ],
  spans: [
    EraSpan(0, MarketPhase.recup),
    EraSpan(18, MarketPhase.crisis, price: 0.85, rent: 0.9, ruins: 0.65),
    EraSpan(30, MarketPhase.recup, price: 0.95),
    EraSpan(48, MarketPhase.expan, price: 1.1, rent: 1.15),
  ],
  events: [
    EraEvent(0, 'El río sube otros 12 cm', 'Las plantas bajas pasan a anunciarse «con vistas al agua».'),
    EraEvent(18, 'Riada en Alba Nova', 'El agua llega a la segunda planta. Los drones, a todas.'),
    EraEvent(30, 'Plan de muros verdes', 'Subvención para quien aísle y plante en la azotea.'),
    EraEvent(48, 'Adaptar cotiza', 'Las viviendas reformadas se alquilan antes y más caras.'),
  ],
  news: {
    MarketPhase.recup: [
      'Las azoteas verdes ya dan tomates',
      'Los drones de reparto ocupan el cielo del Ensanche',
    ],
    MarketPhase.crisis: [
      'Plantas bajas en saldo. Con barca',
      'El seguro no cubre riadas. Ni lluvia',
    ],
    MarketPhase.expan: [
      'Torres de madera: la nueva moda',
      'Reformar con aislamiento sube el precio. Y la nota del clima',
    ],
  },
  embargoChance: 0.3,
  press: PressStyle.feed,
  masthead: 'FEED·AN',
  issue: 'Generado · 12 s de lectura',
  price: '',
  date: '2050-09-02 07:12 · resumen para ti',
  headline: 'El río sube otros 12 cm',
  deck: 'Las plantas bajas pasan a anunciarse «con vistas al agua».',
  quoteGold: 'Adaptaste media ciudad antes de la siguiente riada.',
  quoteSilver: 'Tus edificios aguantan el agua. Y el mercado.',
  quoteBronze: 'Algo reformaste entre riada y riada.',
  quoteNone: 'El agua llegó antes que tus andamios.',
);
