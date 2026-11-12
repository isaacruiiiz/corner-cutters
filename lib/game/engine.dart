import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/rng.dart';
import 'city.dart';
import 'data.dart';
import 'economy.dart';
import 'era.dart';
import 'model.dart';
import 'texts.dart';

int nowMs() => DateTime.now().millisecondsSinceEpoch;

/// Avisos para la interfaz (diálogos, toasts, pantallas de resumen).
enum NoticeKind { toast, stage, renoDone, tenantNew, saleClosed, market, event, defects, achievement, eraEnd }

class Notice {
  final NoticeKind kind;
  final String text;
  final int? propId;
  final Map<String, dynamic> data;
  Notice(this.kind, this.text, {this.propId, this.data = const {}});
}

/// Resultado de un toque.
class TapResult {
  final bool ok;
  final double power;
  final bool crit;
  final bool phaseDone;
  final bool renoDone;
  final String? reason;
  TapResult({required this.ok, this.power = 0, this.crit = false, this.phaseDone = false, this.renoDone = false, this.reason});
}

/// Resumen del progreso sin conexión.
class OfflineReport {
  final Duration away;
  final Duration counted;
  final double rent;
  final double salaries;
  final double interest;
  final double crewWork;
  final int phasesDone;
  final int renosDone;
  final int sales;
  final double salesAmount;
  final int offers;
  final int tenants;
  final int events;
  OfflineReport({
    required this.away,
    required this.counted,
    required this.rent,
    required this.salaries,
    required this.interest,
    required this.crewWork,
    required this.phasesDone,
    required this.renosDone,
    required this.sales,
    required this.salesAmount,
    required this.offers,
    required this.tenants,
    this.events = 0,
  });
}

/// Algo que pasará con el juego cerrado (para las notificaciones del sistema).
class Forecast {
  /// Tipo de aviso: obra, inquilino, venta, mercado, eventos (los mismos de Ajustes → Notificaciones) o tope.
  final String kind;

  /// Tiempo real desde ahora.
  final Duration at;
  final String title;
  final String body;
  const Forecast(this.kind, this.at, this.title, this.body);

  @override
  String toString() => '$kind +${at.inMinutes} min · $title · $body';
}

class Achievement {
  final String id;
  final String name;
  final String desc;
  final String? reward; // cosmético desbloqueado
  const Achievement(this.id, this.name, this.desc, [this.reward]);
}

const achievementsList = [
  Achievement('primera_obra', 'Manos a la obra', 'Termina tu primera reforma'),
  Achievement('primera_venta', 'Vendido', 'Vende tu primera vivienda'),
  Achievement('primer_alquiler', 'Casero', 'Firma tu primer contrato de alquiler'),
  Achievement('ajustado', 'Ni un dólar de más', 'Termina una reforma con calidad 1,00 sin pasarte en ningún oficio', 'pastel'),
  Achievement('combo', 'Ritmo de obra', 'Llega a combo ×2,0'),
  Achievement('critico', 'Ojo de halcón', 'Acierta 25 críticos', 'ladrillo'),
  Achievement('crisis', 'Comprar en rojo', 'Compra una ruina durante una crisis', 'atardecer'),
  Achievement('burbuja', 'A tiempo', 'Vende una vivienda durante una burbuja'),
  Achievement('cuadrilla', 'Empresario', 'Contrata tu primera cuadrilla'),
  Achievement('diez', 'Cartera seria', 'Ten 10 viviendas a la vez'),
  Achievement('millon', 'Millonario sobre plano', 'Alcanza \$1.000.000 de patrimonio', 'modernista'),
  Achievement('nivel10', 'Oficio', 'Sube un oficio a nivel 10'),
  Achievement('ciudad', 'Fundador', 'Funda una nueva ciudad', 'noche'),
];

/// Estado y reglas de la partida.
class Game extends ChangeNotifier {
  // ---------- persistente ----------
  int seed = 1;
  late Rng rng;
  late CityMap city;
  double cash = 0;
  final List<Property> props = [];
  final List<Crew> crews = [];
  final Map<Trade, int> tradeLv = {for (final t in Trade.values) t: 1};
  final Map<Trade, int> toolLv = {for (final t in Trade.values) t: 1};
  final List<GameEvent> events = [];
  final List<Offer> offers = [];
  final List<Listing> listings = [];
  MarketPhase phase = MarketPhase.recup;
  int phaseStarted = 0;
  int phaseEnds = 0;
  final List<double> mHistory = [];
  int lastSample = 0;
  int renosDone = 0;
  double energy = 600;
  int clock = 0; // reloj de juego (ms), avanza según la velocidad
  double speed = 1; // ×1, ×2, ×4
  double gameSec = 0; // segundos de juego desde el inicio de la partida
  int lastTick = 0;
  Stage stage = Stage.manitas;
  Meta meta = Meta();
  Settings settings = Settings();
  Gestoria gestoria = Gestoria();
  final Map<int, List<Service>> services = {};
  int nextId = 1;
  final Map<String, double> stats = {};
  final List<Mission> missions = [];
  String missionDay = '';
  final List<Headline> news = [];
  double monthAcc = 0;
  int boostWorkUntil = 0;
  int boostRentUntil = 0;
  int created = 0;
  bool tutorialDone = false;
  int marketRefreshAt = 0;
  final Map<int, int> bankDeadline = {}; // propId → ms
  /// Cambio del público de cada barrio según lo que reformas allí (zona que cambia).
  final Map<int, Map<Sector, double>> districtShift = {};
  /// Inversores rivales que ya han aparecido.
  final List<Rival> rivals = [];
  /// Encargos de clientes disponibles en el mercado.
  final List<ClientJob> jobs = [];
  int jobsRefreshAt = 0;
  /// Impulso «Atraer compradores»: el doble de visitas.
  int boostSaleUntil = 0;
  /// Café para todos: con premium, gratis cada 30 min.
  int cafeReadyAt = 0;
  /// Último intento de un rival de llevarse un inquilino (como mucho uno cada 30 min).
  int lastPoach = 0;
  /// Momento en que apareció el último rival (salen poco a poco).
  int lastRivalAt = 0;
  final Map<int, List<Trait>> _traitCache = {};

  // ---------- DLC de épocas (null en el modo principal) ----------
  /// Época de esta partida. En el modo principal es null y ninguna regla de época se aplica.
  EraConfig? eraCfg;
  /// La época ha terminado: el reloj se detiene y se muestra el resultado.
  bool eraOver = false;
  /// Sucesos fijos de la época ya publicados (por mes).
  final Set<int> eraFired = {};

  /// Energía máxima: da para reformar unas tres viviendas.
  static const maxEnergy = 600.0;

  /// Recuperación: 1 punto cada 2 s de juego (≈20 min para llenarla).
  static const energyRegen = 0.5;

  // ---------- Calendario ----------
  static const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  int get monthIndex => gameSec ~/ Eco.monthSeconds;
  int get day => ((gameSec % Eco.monthSeconds) / (Eco.monthSeconds / 30)).floor() + 1;
  int get year => monthIndex ~/ 12 + 1;
  String get monthName => _meses[monthIndex % 12];
  String get dateLabel => eraCfg == null ? '$day $monthName · Año $year' : '$day $monthName $eraYear';

  /// Año del calendario real en una época.
  int get eraYear => (eraCfg?.startYear ?? 0) + monthIndex ~/ 12;
  /// Medalla actual de la época (0 a 3).
  int get eraMedal => eraCfg?.medalFor(eraScore) ?? 0;

  /// Lo que mide el objetivo de la época (patrimonio, viviendas, alquiladas o reformas).
  double get eraScore {
    final c = eraCfg;
    if (c == null) return netWorth;
    return switch (c.metric) {
      EraMetric.patrimonio => netWorth,
      EraMetric.viviendas => props.where((p) => !p.isClient).length.toDouble(),
      EraMetric.alquiladas => props.where((p) => p.tenant != null).length.toDouble(),
      EraMetric.reformas => stat('renos'),
    };
  }

  /// Interés mensual de las hipotecas (en 1980, el triple).
  double get mortgageRate => Eco.mortgageRate * (eraCfg?.rate ?? 1);

  /// Tiempo real hasta el próximo cobro de rentas.
  Duration get nextRentIn => Duration(milliseconds: ((Eco.monthSeconds - monthAcc) / speed * 1000).round());
  double get monthProgress => (monthAcc / Eco.monthSeconds).clamp(0.0, 1.0);

  void setSpeed(double v) {
    speed = v;
    notifyListeners();
  }

  // ---------- transitorio ----------
  bool loaded = false;
  double combo = 1;
  int lastTapMs = 0;
  int tapsToCrit = 25;
  final List<Notice> notices = [];
  /// Sonidos pendientes de reproducir (la interfaz los vacía).
  final List<String> sounds = [];
  void _sfx(String s) {
    if (sounds.length < 8) sounds.add(s);
  }

  OfflineReport? offlineReport;
  int _tickCount = 0;
  int? selectedLot;

  // ======================================================================
  // Partida nueva
  // ======================================================================
  void newGame(int s, {bool keepMeta = true}) {
    eraCfg = null;
    eraOver = false;
    eraFired.clear();
    seed = s;
    rng = Rng(s);
    city = CityGen.generate(s, version: 3);
    cash = 10000;
    props.clear();
    crews.clear();
    for (final t in Trade.values) {
      tradeLv[t] = 1;
      toolLv[t] = 1;
    }
    events.clear();
    offers.clear();
    listings.clear();
    services.clear();
    stats.clear();
    missions.clear();
    news.clear();
    mHistory.clear();
    bankDeadline.clear();
    districtShift.clear();
    rivals.clear();
    jobs.clear();
    _traitCache.clear();
    jobsRefreshAt = 0;
    boostSaleUntil = 0;
    cafeReadyAt = 0;
    lastPoach = 0;
    final now = nowMs();
    lastRivalAt = now;
    clock = now;
    gameSec = 0;
    speed = 1;
    phase = MarketPhase.values[rng.nextInt(5)];
    phaseStarted = now - rng.range(0, 40) * 60000;
    phaseEnds = now + rng.range(60, 180) * 60000;
    // Historial inicial suave.
    final prevM = mph(MarketPhase.values[(phase.index + 4) % 5]).m;
    final curM = mph(phase).m;
    final cut = rng.range(30, 60);
    for (var i = 0; i < 72; i++) {
      mHistory.add(i < cut ? prevM : curM);
    }
    lastSample = now;
    renosDone = 0;
    energy = maxEnergy;
    lastTick = now;
    stage = Stage.manitas;
    gestoria = Gestoria();
    nextId = 1;
    monthAcc = 0;
    boostWorkUntil = 0;
    boostRentUntil = 0;
    created = now;
    marketRefreshAt = 0;
    offlineReport = null;
    if (!keepMeta) meta = Meta();

    // Dos pisos de 50 m² en ruina, en zona universitaria, en la misma calle si se puede.
    final uni = city.lots.where((l) => l.zone == Zone.uni && l.w == 1 && l.d == 1 && l.landmark == null).toList();
    final pool = uni.isNotEmpty ? uni : city.lots.where((l) => l.landmark == null).toList();
    final first = pool[rng.nextInt(pool.length)];
    final same = pool.where((l) => l.street == first.street && l.id != first.id).toList();
    final second = same.isNotEmpty ? same[rng.nextInt(same.length)] : pool[(pool.indexOf(first) + 7) % pool.length];
    for (final l in [first, second]) {
      final p = _newProperty(l, kind: Kind.piso, levels: rollLevels(rng, Origin.ruina));
      p.paid = valueOf(p);
      props.add(p);
    }
    _refreshListings(force: true);
    _rollMissions();
    _pushHeadline();
    selectedLot = first.id;
    loaded = true;
    notifyListeners();
  }

  Property _newProperty(Lot l, {Kind? kind, int unit = 0, Map<Trade, int>? levels, Origin origin = Origin.ruina}) {
    final k = kind ?? l.kind;
    final lv = levels ?? const <Trade, int>{};
    return Property(
      id: nextId++,
      lotId: l.id,
      unit: unit,
      kind: k,
      m2: kindInfo[k]!.m2,
      levels: Map.of(lv),
      doneFrac: {for (final t in Trade.values) if ((lv[t] ?? 0) > 0) t: 1.0},
      origin: origin,
      // Los defectos ocultos afectan a lo que está en mal estado.
      humidity: (lv[Trade.alb] ?? 0) <= 3 && rng.chance(0.35),
      badWiring: (lv[Trade.ele] ?? 0) <= 3 && rng.chance(0.30),
      boughtAt: clock,
    );
  }

  /// Niveles de partida de una vivienda según de dónde sale.
  static Map<Trade, int> rollLevels(Rng r, Origin o) {
    switch (o) {
      case Origin.ruina:
      case Origin.edificio:
        final lv = {for (final t in Trade.values) t: r.range(0, 3)};
        // A veces una ruina esconde un oficio en buen estado.
        if (r.chance(0.15)) lv[Trade.values[r.nextInt(5)]] = r.range(6, 12);
        return lv;
      case Origin.usada:
        return {for (final t in Trade.values) t: r.range(2, 8)};
      case Origin.subasta:
      case Origin.embargo:
        final lv = {for (final t in Trade.values) t: r.range(0, 14)};
        // Habitable: la electricidad funciona.
        lv[Trade.ele] = math.max(4, lv[Trade.ele]!);
        return lv;
      case Origin.rival:
        return {for (final t in Trade.values) t: r.range(6, 18)};
      case Origin.encargo:
        return {for (final t in Trade.values) t: r.range(1, 5)};
    }
  }

  // ======================================================================
  // Consultas
  // ======================================================================
  double get m => eraCfg == null ? mph(phase).m : mph(phase).m * eraCfg!.priceMult(monthIndex);
  double get ma => eraCfg == null ? mph(phase).ma : mph(phase).ma * eraCfg!.rentMult(monthIndex);
  Lot lotOf(Property p) => city.lots[p.lotId];
  Zone zoneOf(Property p) => lotOf(p).zone;
  // ---------- Demanda por zona ----------
  /// Cuota de visitas de cada sector en una parcela: zona + rasgo de la ciudad + cambios del barrio.
  Map<Sector, double> sharesOf(Lot l) {
    final base = zoneShares[l.zone]!;
    final add = cityTraitInfo[city.trait]!.shareAdd;
    final sh = districtShift[l.district];
    final out = <Sector, double>{};
    var tot = 0.0;
    for (final s in Sector.values) {
      final v = math.max(0.02, base[s]! + (add[s] ?? 0) + (sh?[s] ?? 0));
      out[s] = v;
      tot += v;
    }
    return {for (final e in out.entries) e.key: e.value / tot};
  }

  /// Rasgos fijos de una parcela (ascensor, ruido, terraza, parking, vistas).
  List<Trait> traitsOf(Lot l) => _traitCache.putIfAbsent(l.id, () => city.traitsOf(l));
  double traitMult(Lot l, Sector s) => traitsOf(l).fold(1.0, (a, t) => a * traitInfo[t]!.mult[s]!);

  static Map<Trade, double> _full(Map<Trade, int> lv) => {for (final t in Trade.values) t: (lv[t] ?? 0) > 0 ? 1.0 : 0.0};

  /// Calidad de unos niveles para un sector en la zona de la vivienda.
  double qualityFor(Property p, Sector s, [Map<Trade, int>? levels]) {
    final lv = levels ?? p.effLevels;
    return Eco.quality(s, zoneOf(p), lv, _full(lv));
  }

  /// Dominas el barrio con más del 40 % de sus edificios: +5 % de renta y −5 % en obras.
  bool dominates(int district) {
    final lots = city.lots.where((l) => l.district == district).length;
    if (lots == 0) return false;
    final mine = props.where((p) => !p.isClient && lotOf(p).district == district).map((p) => p.lotId).toSet().length;
    return mine / lots > 0.40;
  }

  /// Lo que paga de media un comprador del sector [s]: precio de la zona hasta su techo,
  /// calidad para ese sector y rasgos de la vivienda.
  double payOf(Property p, Sector s, {Map<Trade, int>? levels, double? mOverride, bool? renovated}) {
    final l = lotOf(p);
    final q = qualityFor(p, s, levels);
    final ren = renovated ?? p.everRenovated;
    return p.m2 *
        Eco.payPerM2(refPrice(l), s) *
        (mOverride ?? m) *
        (0.5 + 0.5 * q) *
        traitMult(l, s) *
        (1 + p.bonus) *
        (1 + streetBonus(p)) *
        (city.nearLandmark(l) ? 1.05 : 1.0) *
        (ren ? 1 : Eco.unrenovated);
  }

  /// Sectores con una cuota mínima en la zona (los demás apenas visitan).
  Iterable<Sector> _present(Lot l) {
    final sh = sharesOf(l);
    return Sector.values.where((s) => sh[s]! >= 0.04);
  }

  /// Perfil que más pagaría por la vivienda con esos niveles.
  Sector bestSectorFor(Property p, [Map<Trade, int>? levels]) {
    Sector? best;
    var bv = -1.0;
    for (final s in _present(lotOf(p))) {
      final v = payOf(p, s, levels: levels, renovated: true);
      if (v > bv) {
        bv = v;
        best = s;
      }
    }
    return best ?? Sector.fam;
  }

  /// Valor de mercado: lo que pagaría el comprador que más la valora.
  double valueOf(Property p, {Map<Trade, int>? levels, double? mOverride, bool? renovated}) {
    if (p.isClient) return 0;
    var best = 0.0;
    for (final s in _present(lotOf(p))) {
      best = math.max(best, payOf(p, s, levels: levels, mOverride: mOverride, renovated: renovated));
    }
    return best;
  }

  /// Renta mensual que aceptaría de media un inquilino del sector [s].
  double rentFor(Property p, Sector s, {Map<Trade, int>? levels}) {
    final l = lotOf(p);
    final q = qualityFor(p, s, levels);
    final dom = dominates(l.district) ? 1.05 : 1.0;
    return 0.008 *
        p.m2 *
        Eco.payPerM2(refPrice(l), s) *
        ma *
        (0.5 + 0.5 * q) *
        traitMult(l, s) *
        sectorRentFactor[s]! *
        (1 + p.bonus) *
        (1 + streetBonus(p)) *
        meta.rentBonus *
        dom;
  }

  /// Renta de referencia: la del perfil que más pagaría.
  double rentRef(Property p, {Map<Trade, int>? levels}) {
    var best = 0.0;
    for (final s in _present(lotOf(p))) {
      best = math.max(best, rentFor(p, s, levels: levels));
    }
    return best;
  }

  /// Quién compraría: por sector, cuota de visitas, lo que paga y probabilidad de pagar [ask].
  List<BuyerRow> buyersOf(Property p, double ask, {Map<Trade, int>? levels, bool renovated = true}) {
    final sh = sharesOf(lotOf(p));
    return [
      for (final s in Sector.values)
        if (sh[s]! >= 0.04)
          () {
            final pay = payOf(p, s, levels: levels, renovated: renovated);
            return BuyerRow(s, sh[s]!, pay, Eco.payProb(ask, pay, si(s).sigma));
          }(),
    ];
  }

  /// Probabilidad por visita de que alguien pague el precio pedido y · valor.
  double saleProb(Property p, double y) {
    final ask = valueOf(p) * y;
    final sh = sharesOf(lotOf(p));
    var pr = 0.0;
    for (final s in Sector.values) {
      pr += sh[s]! * Eco.payProb(ask, payOf(p, s), si(s).sigma);
    }
    return pr;
  }

  /// Probabilidad por visita de recibir una oferta.
  double saleOfferProb(Property p, double y) {
    final ask = valueOf(p) * y;
    final sh = sharesOf(lotOf(p));
    var pr = 0.0;
    for (final s in Sector.values) {
      pr += sh[s]! * Eco.offerProbAt(ask, payOf(p, s), si(s).sigma);
    }
    return pr;
  }

  /// Visitas por minuto real (el impulso «Atraer compradores» las duplica).
  double get visitRate => saleBoost ? 2 : 1;

  /// Espera media hasta vender (minutos reales).
  double saleWaitMin(Property p, double y) {
    final pr = saleProb(p, y) * visitRate;
    if (pr < 1e-7) return double.infinity;
    return 1 / pr;
  }

  /// Quién alquilaría: por sector, cuota, renta que acepta y probabilidad de aceptar x · referencia.
  List<BuyerRow> rentersOf(Property p, double x) {
    final ask = rentRef(p) * x;
    final sh = sharesOf(lotOf(p));
    return [
      for (final s in Sector.values)
        if (sh[s]! >= 0.04) BuyerRow(s, sh[s]!, rentFor(p, s), Eco.payProb(ask, rentFor(p, s), si(s).sigma)),
    ];
  }

  /// Probabilidad de que un candidato acepte la renta x · referencia.
  double rentAcceptProb(Property p, double x) {
    final ask = rentRef(p) * x;
    final sh = sharesOf(lotOf(p));
    var pr = 0.0;
    for (final s in Sector.values) {
      pr += sh[s]! * Eco.payProb(ask, rentFor(p, s), si(s).sigma);
    }
    return pr;
  }

  District districtOf(Property p) => city.districts[lotOf(p).district];
  String addressOf(Property p) {
    final base = city.address(lotOf(p));
    if (p.unit <= 0) return base;
    final floor = (p.unit + 1) ~/ 2;
    final door = p.unit.isOdd ? '1ª' : '2ª';
    return '$base, $floorº $door';
  }

  String addressOfLot(Lot l) => city.address(l);
  String streetOf(Property p) => city.streets[lotOf(p).street].name;
  Property? prop(int id) {
    for (final p in props) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Property> propsOnLot(int lotId) => props.where((p) => p.lotId == lotId).toList();

  /// Precio de referencia $/m² con barrio y servicios.
  double refPrice(Lot l) {
    final d = city.districts[l.district];
    final sv = (services[d.id]?.length ?? 0).clamp(0, 3);
    return zi(l.zone).price * d.priceFactor * (1 + 0.05 * sv);
  }

  /// Efecto barrio (fase 4): +2 % por vivienda reformada propia en la misma calle, hasta 10 %.
  double streetBonus(Property p) {
    if (stage.index < Stage.promotor.index) return 0;
    final st = lotOf(p).street;
    final n = props.where((o) => o.id != p.id && o.everRenovated && lotOf(o).street == st).length;
    return math.min(0.10, 0.02 * n);
  }

  /// Valor reformada al óptimo del perfil principal de la zona, a precios normales (referencia).
  double refValue(Property p) {
    final s = bestSector(zoneOf(p));
    return valueOf(p, levels: Map.of(si(s).optimal), mOverride: 1, renovated: true);
  }

  double rentOf(Property p) => rentRef(p) * p.rentX * (boostRentUntil > nowMs() ? 1.5 : 1);

  double get monthlyRent =>
      props.where((p) => p.state == PState.alquilada && (p.tenant?.arrears ?? 0) == 0).fold(0.0, (a, p) => a + rentOf(p));

  double get monthlySalaries {
    var s = 0.0;
    for (final t in Trade.values) {
      final n = crews.where((c) => c.trade == t).length;
      for (var i = 1; i <= n; i++) {
        s += Eco.crewSalary(i);
      }
    }
    return s;
  }

  /// Sobrecoste de las horas extra acumuladas este mes.
  double get overtimeCost {
    var s = 0.0;
    for (final c in crews) {
      if (c.otSec <= 0) continue;
      final n = crews.where((o) => o.trade == c.trade).toList().indexOf(c) + 1;
      s += Eco.crewSalary(n) * (Eco.overtimeSalaryMult - 1) * c.otSec / Eco.monthSeconds;
    }
    return s;
  }

  /// Rentas de las ciudades anteriores que cobra la gestoría (15 %).
  double get legacyRent => meta.legacy.fold(0.0, (a, c) => a + c.rent) * 0.15;

  double get monthlyInterest => props.fold(0.0, (a, p) => a + p.debt * mortgageRate);
  double get monthlyNet => monthlyRent + legacyRent - monthlySalaries - monthlyInterest;
  double get totalDebt => props.fold(0.0, (a, p) => a + p.debt);
  double get assets => props.where((p) => !p.isClient).fold(0.0, (a, p) => a + valueOf(p));
  double get netWorth => cash + assets - totalDebt;
  int get activeRenos => props.where((p) => p.state == PState.obra).length;
  int get maxRenos => stage.index >= Stage.empresa.index ? 99 : 1;
  bool get canBuy => stage.index >= Stage.casero.index;
  bool get hasCrews => stage.index >= Stage.empresa.index;
  bool get hasMortgage => stage.index >= Stage.empresa.index && (eraCfg == null || eraCfg!.creditAt(monthIndex));
  /// Por qué no hay hipotecas ahora.
  String get mortgageLock => eraCfg != null && stage.index >= Stage.empresa.index
      ? 'Sin crédito hasta ${eraCfg!.creditYear ?? eraCfg!.endYear}'
      : 'Las hipotecas llegan con la Empresa de reformas';
  bool get isPromoter => stage.index >= Stage.promotor.index;
  bool get canPrestige => eraCfg == null && netWorth >= 5000000;
  int get levelCap => meta.levelCap;
  Duration get phaseLeft => Duration(milliseconds: (math.max(0, phaseEnds - clock) / speed).round());
  bool get workBoost => boostWorkUntil > nowMs();
  bool get rentBoost => boostRentUntil > nowMs();
  bool get saleBoost => boostSaleUntil > nowMs();
  bool get inCrisis => phase == MarketPhase.crisis;
  /// Cuadrillas agotadas (descansando) con obra pendiente.
  int get tiredCrews => crews.where((c) => c.resting && !c.overtime && c.propId != null).length;
  int get pendingCount => events.length + offers.length + missions.where((x) => x.done && !x.claimed).length;

  MarketPhase get nextPhase => MarketPhase.values[(phase.index + 1) % 5];

  double stat(String k) => stats[k] ?? 0;
  void _inc(String k, [double v = 1]) => stats[k] = (stats[k] ?? 0) + v;

  // ---------- Estimación del selector ----------
  /// Multiplicador de coste de obra hoy (crisis, barrio dominado).
  double renoCostMult(Property p) => Eco.renoCostMult(phase) * (dominates(lotOf(p).district) ? 0.95 : 1.0);

  /// Coste de una obra que lleva cada oficio de su nivel actual a [levels].
  double renoCost(Property p, Map<Trade, int> levels) {
    if (p.isClient) return 0;
    var cost = 0.0;
    for (final t in Trade.values) {
      cost += Eco.stepCost(t, p.m2, p.lv(t), levels[t] ?? 0);
    }
    return cost * renoCostMult(p);
  }

  /// Niveles objetivo válidos: nunca por debajo de lo que ya hay.
  Map<Trade, int> clampTargets(Property p, Map<Trade, int> levels) =>
      {for (final t in Trade.values) t: math.max(p.lv(t), levels[t] ?? 0)};

  /// Combinación sugerida para la zona: la que más beneficio deja entre los óptimos de cada perfil
  /// (con los niveles que tiene formados tu empresa).
  Map<Trade, int> suggestedLevels(Property p) {
    Map<Trade, int>? best;
    var bp = double.negativeInfinity;
    for (final s in _present(lotOf(p))) {
      final lv = clampTargets(p, {
        for (final t in Trade.values) t: math.max(t == Trade.ele ? 1 : 0, math.min(si(s).optimal[t]!, tradeLv[t]!)),
      });
      final profit = valueOf(p, levels: lv, renovated: true) - renoCost(p, lv);
      if (profit > bp) {
        bp = profit;
        best = lv;
      }
    }
    return best ?? clampTargets(p, {Trade.ele: 1});
  }

  RenoEstimate estimate(Property p, Map<Trade, int> levels) {
    final lv = clampTargets(p, levels);
    final s = bestSectorFor(p, lv);
    final q = qualityFor(p, s, lv);
    final v = valueOf(p, levels: lv, renovated: true);
    final cost = renoCost(p, lv);
    var work = 0.0;
    for (final t in Trade.values) {
      work += Eco.stepWork(t, p.m2, p.lv(t), lv[t]!);
    }
    final sug = suggestedLevels(p);
    final vOpt = valueOf(p, levels: sug, renovated: true);
    final buy = p.paid + p.spent;
    final profit = v - buy - cost;
    final profitOpt = vOpt - buy - renoCost(p, sug);
    final avgPower = (Trade.values.fold<int>(0, (a, t) => a + toolLv[t]!) / 5 + 1) * 1.4;
    final taps = work / avgPower;
    return RenoEstimate(
      sector: s,
      quality: q,
      value: v,
      cost: cost,
      work: work,
      taps: taps,
      profit: profit,
      profitOpt: profitOpt,
      rent: rentRef(p, levels: lv),
      optCost: renoCost(p, sug),
    );
  }

  // ======================================================================
  // Reloj
  // ======================================================================
  void tick() {
    if (!loaded) return;
    final real = nowMs();
    var dt = (real - lastTick) / 1000.0;
    if (dt <= 0) return;
    if (dt > 30) dt = 30; // saltos grandes los resuelve el progreso offline
    lastTick = real;
    _step(dt * speed, live: true);
    _tickCount++;
    notifyListeners();
  }

  void _step(double dt, {bool live = false, _Acc? acc}) {
    if (eraOver) return;
    clock += (dt * 1000).round();
    final now = clock;
    gameSec += dt;
    energy = math.min(maxEnergy, energy + dt * energyRegen);
    if (live && nowMs() - lastTapMs > 1500) combo = 1;

    // Cuadrillas: trabajan gastando su jornada y descansan para recuperarla.
    for (final c in crews) {
      final maxE = Eco.crewMaxEnergy(tradeLv[c.trade]!);
      void rest() {
        c.energy = math.min(maxE, c.energy + Eco.crewRegen * dt);
        if (c.energy >= maxE) c.resting = false;
      }

      var target = c.propId == null ? null : prop(c.propId!);
      if (target == null || target.reno == null || target.reno!.phaseDone(c.trade)) {
        if (c.auto) {
          target = _findWorkFor(c.trade);
          c.propId = target?.id;
        } else {
          c.propId = target?.reno == null ? null : c.propId;
          target = null;
        }
      }
      if (target == null || target.reno == null || !target.reno!.has(c.trade)) {
        rest();
        continue;
      }
      if (c.resting && !c.overtime) {
        rest();
        continue;
      }
      final r = target.reno!;
      final rate = Eco.crewRate(tradeLv[c.trade]!) * meta.speedBonus * (boostWorkUntil > now ? 2 : 1) * (eraCfg?.crewMult ?? 1);
      var work = rate * dt;
      var ot = 0.0;
      final need = work * Eco.crewEnergyPerWork;
      if (c.energy >= need) {
        c.energy -= need;
      } else if (c.overtime) {
        ot = work - c.energy / Eco.crewEnergyPerWork;
        c.energy = 0;
        c.otSec += dt * ot / work;
      } else {
        work = c.energy / Eco.crewEnergyPerWork;
        c.energy = 0;
        c.resting = true;
      }
      final before = r.frac(c.trade);
      r.done[c.trade] = math.min(r.work[c.trade] ?? 0, (r.done[c.trade] ?? 0) + work);
      r.lastActivity = now;
      acc?.crewWork += work;
      // Horas extra: cansancio y riesgo de que la fase quede un nivel por debajo.
      if (ot > 0 && r.frac(c.trade) < 1 && rng.chance(Eco.overtimeSlipPerMin * dt / 60 * ot / (rate * dt))) {
        final b = r.base[c.trade] ?? 0;
        final l = r.levels[c.trade] ?? 0;
        if (l - 1 > b) {
          r.levels[c.trade] = l - 1;
          r.work[c.trade] = math.max(r.done[c.trade] ?? 0, Eco.stepWork(c.trade, target.m2, b, l - 1));
          if (acc == null) {
            _push(Notice(NoticeKind.toast, 'Horas extra: la ${ti(c.trade).phase.toLowerCase()} de ${addressOf(target)} queda en nivel ${l - 1}',
                propId: target.id));
          }
        }
      }
      if (before < 1 && r.frac(c.trade) >= 1) {
        acc?.phases++;
        if (r.allDone) {
          finishReno(target, silent: acc != null);
          acc?.renos++;
        }
      }
    }

    // Mes de juego.
    monthAcc += dt;
    while (monthAcc >= Eco.monthSeconds) {
      monthAcc -= Eco.monthSeconds;
      _monthly(now, acc);
    }

    // Mercado (en una época lo marca su calendario).
    if (eraCfg != null) {
      _eraStep(now, live: live);
      if (eraOver) return;
    } else if (now >= phaseEnds) {
      _advancePhase(now, live: live);
    }
    if (now - lastSample >= 10 * 60000) {
      lastSample = now;
      mHistory.add(m);
      while (mHistory.length > 72) {
        mHistory.removeAt(0);
      }
    }

    // Ventas: ~1 visita por minuto real (2 con el impulso).
    for (final p in List<Property>.from(props)) {
      if (p.state == PState.venta) {
        if (rng.chance(dt / 60 * visitRate)) _visit(p, now, acc);
      } else if (p.state == PState.buscando) {
        p.vacancyLeft -= dt;
        if (p.vacancyLeft <= 0) {
          _newTenant(p, now, live: acc == null);
          acc?.tenants++;
        }
      }
    }

    // Ofertas caducadas.
    offers.removeWhere((o) => o.expires < now || prop(o.propId)?.state != PState.venta);

    // Banco: deuda superior al valor.
    if (hasMortgage) _checkBank(now);

    // Mercado de ruinas.
    if (now >= marketRefreshAt) _refreshListings();

    // Gestoría.
    if (gestoria.on && isPromoter) _gestoria(now);

    // Encargos de clientes.
    if (now >= jobsRefreshAt) _refreshJobs();
    _checkJobs(now, acc);

    // Inversores rivales.
    _rivalsStep(now, dt, live: acc == null);

    // Fases de progreso.
    _checkStage();
    if (live && _tickCount % 5 == 0) _checkAchievements();
  }

  Property? _findWorkFor(Trade t) {
    Property? best;
    for (final p in props) {
      final r = p.reno;
      if (r == null || r.phaseDone(t)) continue;
      final busy = crews.where((c) => c.trade == t && c.propId == p.id).length;
      if (best == null || busy == 0) {
        best = p;
        if (busy == 0) break;
      }
    }
    return best;
  }

  void _monthly(int now, _Acc? acc) {
    _inc('months');
    final monthOfYear = monthIndex % 12; // 0 = enero
    var paidCount = 0;
    // Rentas.
    for (final p in List<Property>.from(props)) {
      if (p.state != PState.alquilada || p.tenant == null) continue;
      final t = p.tenant!;
      t.months++;
      if (t.arrears > 0) {
        t.arrears--;
        t.sat -= 2;
        t.record(false);
      } else {
        t.record(true);
        final r = rentOf(p);
        paidCount++;
        cash += r;
        acc?.rent += r;
        _inc('rentTotal', r);
        if (r > stat('rentMax')) stats['rentMax'] = r;
        _missionProgress('renta', r.round());
      }
      // Satisfacción según el perfil: los ejecutivos exigen más, los mayores son los más fieles.
      final qs = qualityFor(p, t.sector);
      var target = 40 + 55 * qs - 45 * math.max(0, p.rentX - 1);
      if (p.breakdown) target -= 25;
      if (t.type == TenantType.ejemplar) target += 10;
      if (t.type == TenantType.problematico) target -= 10;
      if (t.sector == Sector.eje && qs < 0.9) target -= 10;
      if (t.sector == Sector.may) target += 8;
      final speed = t.sector == Sector.fam || t.sector == Sector.may ? 0.2 : 0.35;
      t.sat += (target - t.sat) * speed;
      t.sat = t.sat.clamp(0.0, 100.0);
      String? leave;
      if (t.sat < 30) {
        leave = 'satisfacción ${t.sat.round()}';
      } else if (t.sector == Sector.est && monthOfYear == 5 && t.months >= 6 && rng.chance(0.7)) {
        // Fin de curso: muchos estudiantes se van en junio y el piso queda vacío en verano.
        leave = 'fin de curso';
      } else if (t.sector == Sector.eje && rng.chance(0.04)) {
        leave = 'traslado de empresa';
      }
      if (leave != null) {
        if (acc == null) _push(Notice(NoticeKind.toast, '${t.name} deja ${addressOf(p)}: $leave', propId: p.id));
        p.tenant = null;
        p.state = PState.buscando;
        p.vacancyLeft = _vacancyTime(p) + (leave == 'fin de curso' ? 2.5 * Eco.monthSeconds : 0);
        continue;
      }
      // El inquilino despistado a veces se retrasa.
      if (t.type == TenantType.despistado && rng.chance(0.12)) t.arrears = 1;
      // Desgaste: cada 8 meses alquilada baja un nivel la decoración; cada 16, la carpintería.
      p.wear += 1;
      if (p.wear >= 8) {
        p.wear -= 8;
        p.worn++;
        final which = p.worn.isEven ? Trade.car : Trade.dec;
        final l = p.levels[which] ?? 0;
        if (l > 1) {
          p.levels[which] = l - 1;
          _recalc(p);
        }
      }
      // Un rival intenta llevarse al inquilino (solo con el juego abierto y con aviso).
      if (acc == null) _maybePoach(p, now);
    }
    if (acc == null && paidCount > 0) _sfx(paidCount >= 3 ? 'renta_multi' : 'renta');
    // Salarios, horas extra e intereses.
    final sal = monthlySalaries + overtimeCost;
    for (final c in crews) {
      c.otSec = 0;
    }
    final intr = monthlyInterest;
    cash -= sal + intr;
    acc?.salaries += sal;
    acc?.interest += intr;
    // Ciudades anteriores: la gestoría ingresa el 15 % de sus rentas.
    final lr = legacyRent;
    if (lr > 0) {
      cash += lr;
      acc?.rent += lr;
    }

    // Eventos: 3 % por vivienda y mes.
    for (final p in List<Property>.from(props)) {
      if (!p.isClient && rng.chance(0.03)) _rollEvent(p, now);
    }
    // Misiones del día.
    final day = _dayKey(nowMs());
    if (day != missionDay) _rollMissions();
  }

  // ---------- Mercado ----------
  void _advancePhase(int now, {bool live = false}) {
    final old = phase;
    phase = nextPhase;
    phaseStarted = now;
    phaseEnds = now + rng.range(60, 180) * 60000;
    _pushHeadline();
    _inc('phases');
    if (live) {
      _push(Notice(NoticeKind.market, '${mph(old).name} → ${mph(phase).name}',
          data: {'from': old.index, 'to': phase.index}));
      _sfx(switch (phase) {
        MarketPhase.crisis => 'crisis',
        MarketPhase.expan || MarketPhase.burbuja => 'auge',
        _ => 'fase_mercado',
      });
    }
    if (phase == MarketPhase.crisis) {
      // Llega la crisis: objetivo especial, embargos y rivales que necesitan liquidez.
      _addCrisisMission();
      _rivalsFireSale(now);
      _refreshListings(force: true);
      _refreshJobs();
    }
  }

  // ---------- DLC de épocas ----------
  /// Partida nueva en una época: Alba Nova, calendario real y reglas de la época.
  /// No toca la partida principal (se guarda aparte antes de llamar a esto).
  void newEraGame(EraConfig c, int s) {
    newGame(s, keepMeta: false);
    eraCfg = c;
    eraOver = false;
    eraFired.clear();
    city = CityGen.generate(s, name: 'Alba Nova', version: 3);
    cash = c.startCash;
    // Empiezas con oficio: la época no repite el tutorial.
    stage = Stage.empresa;
    tutorialDone = true;
    for (final t in Trade.values) {
      tradeLv[t] = 3;
    }
    meta.mapTheme = 'epoca_${c.id}';
    final now = clock;
    phase = c.phaseAt(0);
    phaseStarted = now;
    phaseEnds = now + c.nextChange(0) * Eco.monthSeconds * 1000;
    mHistory
      ..clear()
      ..addAll(List.filled(72, m));
    lastSample = now;
    for (final p in props) {
      p.paid = valueOf(p);
    }
    missions.clear();
    _rollMissions();
    news.clear();
    listings.clear();
    _eraStep(now);
    _refreshListings(force: true);
    notifyListeners();
  }

  /// Avanza el reloj de juego en saltos (solo para tests).
  @visibleForTesting
  void debugAdvance(double seconds, {double step = 10}) {
    var left = seconds;
    while (left > 0) {
      final d = math.min(step, left);
      _step(d, live: true);
      left -= d;
    }
  }

  /// Calendario de la época: fase del mercado por mes, sucesos fijos y final.
  void _eraStep(int now, {bool live = false}) {
    final c = eraCfg!;
    final mo = monthIndex;
    if (mo >= c.months) {
      if (!eraOver) {
        eraOver = true;
        _sfx('patrimonio');
        _push(Notice(NoticeKind.eraEnd, c.name, data: {'era': c.id}));
      }
      return;
    }
    final want = c.phaseAt(mo);
    if (want != phase) {
      final old = phase;
      phase = want;
      phaseStarted = now;
      _inc('phases');
      if (live) {
        _push(Notice(NoticeKind.market, '${mph(old).name} → ${mph(phase).name}',
            data: {'from': old.index, 'to': phase.index}));
        _sfx(switch (phase) {
          MarketPhase.crisis => 'crisis',
          MarketPhase.expan || MarketPhase.burbuja => 'auge',
          _ => 'fase_mercado',
        });
      }
      if (phase == MarketPhase.crisis) {
        _addCrisisMission();
        _rivalsFireSale(now);
        _refreshListings(force: true);
      }
      _pushHeadline();
    }
    // Cuenta atrás hasta el próximo cambio del calendario.
    phaseEnds = now + ((c.nextChange(mo) * Eco.monthSeconds - gameSec) * 1000).round();
    for (final e in c.events) {
      if (mo < e.month || eraFired.contains(e.month)) continue;
      eraFired.add(e.month);
      news.insert(0, Headline(e.title, e.body, clock));
      while (news.length > 12) {
        news.removeLast();
      }
      if (live) _push(Notice(NoticeKind.toast, e.title));
    }
  }

  /// Objetivo de crisis: cazar gangas mientras dura.
  void _addCrisisMission() {
    missions.removeWhere((x) => x.id.startsWith('crisis_'));
    final cap = (30000 * cityTraitInfo[city.trait]!.price / 1000).round() * 1000.0;
    final pool = [
      Mission(id: 'crisis_compra', text: 'Crisis: compra 2 viviendas por menos de ${_money(cap)}', target: 2, reward: 6000),
      Mission(id: 'crisis_reforma', text: 'Crisis: termina 2 reformas mientras dura', target: 2, reward: 5000),
      Mission(id: 'crisis_alquiler', text: 'Crisis: firma 2 alquileres', target: 2, reward: 4000),
      Mission(id: 'crisis_encargo', text: 'Crisis: termina un encargo de un cliente', target: 1, reward: 4500),
    ];
    missions.add(pool[rng.nextInt(pool.length)]);
  }

  /// Vivienda provisional para tasar un anuncio.
  Property _probe(Lot l, Map<Trade, int> levels, {bool renovated = false, Kind? kind}) {
    final k = kind ?? l.kind;
    return Property(
      id: -1,
      lotId: l.id,
      kind: k,
      m2: kindInfo[k]!.m2,
      levels: Map.of(levels),
      doneFrac: {for (final t in Trade.values) if ((levels[t] ?? 0) > 0) t: 1.0},
      everRenovated: renovated,
    );
  }

  /// Valor de lo que anuncia un anuncio (sin el descuento de subasta ni el ruido).
  double listingValue(Listing l) {
    final lot = city.lots[l.lotId];
    final hab = l.origin == Origin.subasta || l.origin == Origin.embargo || l.origin == Origin.rival;
    return valueOf(_probe(lot, l.levels, renovated: hab)) * l.units;
  }

  /// Rango de nivel que se ve de una subasta antes de comprarla.
  (int, int) levelRange(Listing l, Trade t) {
    final v = l.levels[t] ?? 0;
    if (!l.hidden) return (v, v);
    final off = hash2(l.lotId * 7 + t.index, l.expires) % 4;
    final lo = math.max(0, v - off);
    return (lo, math.min(20, lo + 4));
  }

  /// Rivales interesados en una parcela (según su zona preferida).
  List<Rival> rivalsInterested(Lot l) => rivals.where((r) => rivalStyleInfo[r.style]!.zones.contains(l.zone)).toList();

  /// Parcela de algún rival.
  Rival? rivalOwner(int lotId) {
    for (final r in rivals) {
      if (r.lots.contains(lotId)) return r;
    }
    return null;
  }

  void _pushHeadline() {
    final l = eraCfg?.newsFor(phase) ?? Tx.marketNews[phase]!;
    final t = l[rng.nextInt(l.length)];
    final body = 'Precios ×${mph(phase).m.toStringAsFixed(2).replaceAll('.', ',')} · '
        'Alquileres ×${mph(phase).ma.toStringAsFixed(2).replaceAll('.', ',')}';
    news.insert(0, Headline(t, body, clock));
    while (news.length > 12) {
      news.removeLast();
    }
  }

  void _refreshListings({bool force = false}) {
    final now = clock;
    listings.removeWhere((l) =>
        (l.expires < now && !l.reserved(now)) || props.any((p) => p.lotId == l.lotId) || (l.origin != Origin.rival && rivalOwner(l.lotId) != null));
    final ownedLots = props.map((p) => p.lotId).toSet();
    final want = (isPromoter ? 9 : 7) + (inCrisis ? 2 : 0);
    var guard = 0;
    while (listings.length < want && guard++ < 300) {
      final l = city.lots[rng.nextInt(city.lots.length)];
      if (l.landmark != null || ownedLots.contains(l.id) || listings.any((x) => x.lotId == l.id) || rivalOwner(l.id) != null) continue;
      // Al principio, viviendas asequibles.
      if (stage.index <= Stage.casero.index && l.zone != Zone.uni && l.zone != Zone.fam && rng.chance(0.7)) continue;
      final building = isPromoter && l.zone != Zone.res && l.height >= 18 && rng.chance(0.3);
      final units = building ? rng.range(4, 8) : 1;
      Origin origin;
      if (building) {
        origin = Origin.edificio;
      } else if (inCrisis && rng.chance(eraCfg?.embargoChance ?? 0.22)) {
        origin = Origin.embargo;
      } else if (rng.chance(0.15)) {
        origin = Origin.subasta;
      } else if (rng.chance(0.35)) {
        origin = Origin.usada;
      } else {
        origin = Origin.ruina;
      }
      final levels = rollLevels(rng, origin);
      final expires = now + rng.range(20, 90) * 60000;
      final hab = origin == Origin.subasta || origin == Origin.embargo;
      final worth = valueOf(_probe(l, levels, renovated: hab)) * units;
      final double price = switch (origin) {
        // Subasta: niveles ocultos (solo rangos) y descuento sobre lo que vale.
        Origin.subasta => worth * rng.rangeD(0.75, 0.95),
        // Embargo bancario (solo en crisis): habitable y muy por debajo de su valor.
        Origin.embargo => worth * rng.rangeD(0.60, 0.72),
        // Ruinas y sin reformar: lo que vale lo hecho, con ruido (hay gangas y trampas).
        _ => eraCfg == null
            ? worth * rng.rangeD(0.85, 1.15) * Eco.listingMult(phase)
            : worth * rng.rangeD(0.85, 1.15) * Eco.listingMult(phase) * eraCfg!.ruinMult(monthIndex),
      };
      // Algún rival le echará el ojo y la comprará si nadie se adelanta.
      final fans = rivalsInterested(l);
      final rival = fans.isEmpty || rng.chance(0.35) ? null : fans[rng.nextInt(fans.length)];
      listings.add(Listing(
        lotId: l.id,
        price: (price / 100).round() * 100.0,
        auction: origin == Origin.subasta,
        expires: expires,
        building: building,
        units: units,
        origin: origin,
        levels: levels,
        hidden: origin == Origin.subasta,
        rivalId: rival?.id,
        rivalBuysAt: rival == null ? 0 : now + rng.range(12, math.max(13, (expires - now) ~/ 60000 - 4)) * 60000,
        listedAt: now,
      ));
    }
    marketRefreshAt = now + (force ? 5 : 10) * 60000;
  }

  /// Paga una señal (3 %) y reserva el anuncio 10 minutos: ningún rival puede comprarlo.
  String? reserve(Listing l) {
    if (l.reserved(clock)) return 'Ya está reservada';
    final fee = (l.price * 0.03 / 10).round() * 10.0;
    if (cash < fee) return 'Necesitas ${_money(fee)} para la señal';
    cash -= fee;
    l.reservedUntil = clock + 10 * 60000;
    notifyListeners();
    return null;
  }

  double reserveFee(Listing l) => (l.price * 0.03 / 10).round() * 10.0;

  // ---------- Ventas ----------
  void _visit(Property p, int now, _Acc? acc) {
    // Cada visita es de un perfil según la cuota de la zona; paga lo que vale para él, con dispersión.
    final sh = sharesOf(lotOf(p));
    final s = rng.weighted(sh);
    final v = valueOf(p);
    final ask = v * p.askY;
    final val = payOf(p, s) * math.exp(si(s).sigma * rng.gauss());
    _inc('visits');
    if (val >= ask) {
      _completeSale(p, ask, now, live: acc == null);
      acc?.sales++;
      acc?.salesAmount += ask;
    } else if (val >= 0.8 * ask) {
      final amount = (val / 100).round() * 100.0;
      offers.add(Offer(id: nextId++, propId: p.id, amount: amount, at: now, expires: now + 24 * 3600 * 1000));
      acc?.offers++;
      if (acc == null) {
        _push(Notice(NoticeKind.toast, 'Oferta de \$${_fmt(amount)} por ${addressOf(p)}', propId: p.id));
      }
    }
  }

  void _completeSale(Property p, double amount, int now, {bool live = true}) {
    final debt = p.debt;
    final profit = amount - p.paid - p.spent;
    cash += amount - debt;
    props.remove(p);
    offers.removeWhere((o) => o.propId == p.id);
    for (final c in crews) {
      if (c.propId == p.id) c.propId = null;
    }
    if (live) _sfx('venta');
    _inc('sales');
    _inc('salesTotal', amount);
    _missionProgress('vender', 1);
    if (phase == MarketPhase.burbuja) _unlock('burbuja');
    _unlock('primera_venta');
    _push(Notice(NoticeKind.saleClosed, 'Venta cerrada', propId: p.id, data: {
      'amount': amount,
      'debt': debt,
      'paid': p.paid,
      'profit': profit,
      'address': addressOf(p),
      'm2': p.m2,
      'lot': p.lotId,
      'live': live,
    }));
  }

  // ---------- Alquiler ----------
  double _vacancyTime(Property p) => rng.expo(vacancyMean(p, p.rentX) - 5) + 5;

  /// Tiempo medio estimado hasta encontrar inquilino (segundos de juego): un candidato
  /// cada ~18 s que acepta si la renta no pasa de lo que paga su perfil.
  double vacancyMean(Property p, double x) => 18 / math.max(rentAcceptProb(p, x), 0.02) + 5;

  void _newTenant(Property p, int now, {bool live = true}) {
    final type = rng.weighted({
      TenantType.puntual: 50.0,
      TenantType.despistado: 20.0,
      TenantType.problematico: p.rentX < 0.9 ? 6.0 : 12.0,
      TenantType.ejemplar: p.rentX > 1.2 ? 26.0 : 18.0,
    });
    // Perfil del inquilino: cuota de la zona × probabilidad de aceptar la renta.
    final ask = rentOf(p);
    final sh = sharesOf(lotOf(p));
    final w = {for (final s in Sector.values) s: sh[s]! * math.max(0.001, Eco.payProb(ask, rentFor(p, s), si(s).sigma))};
    final sector = rng.weighted(w);
    final q = qualityFor(p, sector);
    final sat = (45 + 50 * q - 40 * math.max(0, p.rentX - 1) + (p.rentX < 1 ? 10 : 0)).clamp(30, 95).toDouble();
    p.tenant = Tenant(type: type, sector: sector, name: Tx.name(rng), since: now, sat: sat);
    _missionProgress('crisis_alquiler', 1);
    p.state = PState.alquilada;
    _inc('tenants');
    _unlock('primer_alquiler');
    if (live) _push(Notice(NoticeKind.tenantNew, 'Inquilino nuevo', propId: p.id));
  }

  // ---------- Eventos ----------
  void _rollEvent(Property p, int now) {
    // Con muchos eventos sin atender no se generan más (evita la avalancha al volver).
    if (events.length >= Eco.maxOpenEvents) return;
    final problem = rng.chance(0.55);
    final addr = addressOf(p);
    if (problem) {
      final kinds = <EvKind>[];
      if (p.state == PState.alquilada) kinds.addAll([EvKind.averia, EvKind.impago, EvKind.mejora]);
      if (p.everRenovated && p.state != PState.alquilada) kinds.add(EvKind.averia);
      if (p.everRenovated) kinds.add(EvKind.inspeccion);
      kinds.add(EvKind.temporal);
      final k = kinds[rng.nextInt(kinds.length)];
      switch (k) {
        case EvKind.averia:
          final which = rng.chance(0.5) ? Trade.fon : Trade.ele;
          final lv = p.levels[which] ?? 1;
          if (!rng.chance(1.0 - lv / 25)) return; // el nivel del oficio reduce la probabilidad
          final cost = (p.m2 * ti(which).costPerM2 * 0.25).roundToDouble();
          p.breakdown = true;
          _addEvent(GameEvent(
              id: nextId++,
              kind: k,
              propId: p.id,
              amount: cost,
              title: 'Avería de ${ti(which).phase.toLowerCase()}',
              text: '$addr · reparación ${_money(cost)}. Si no se atiende, baja la satisfacción.',
              at: now));
        case EvKind.impago:
          if (p.tenant == null) return;
          // El impago ya no es una notificación: se ve en la cartera y en la ficha (historial de pagos).
          final months = p.tenant!.type == TenantType.problematico ? rng.range(2, 3) : rng.range(1, 3);
          p.tenant!.arrears = months;
        case EvKind.mejora:
          final cost = (p.m2 * 40.0).roundToDouble();
          _addEvent(GameEvent(
              id: nextId++,
              kind: k,
              propId: p.id,
              amount: cost,
              title: 'Petición de mejora',
              text: '$addr · el inquilino pide una mejora de ${_money(cost)}. Aceptar sube la satisfacción.',
              at: now));
        case EvKind.inspeccion:
          final lv = p.levels[Trade.ele] ?? 1;
          final fine = lv <= 1 ? (p.m2 * 60.0).roundToDouble() : 0.0;
          _addEvent(GameEvent(
              id: nextId++,
              kind: k,
              propId: p.id,
              amount: fine,
              title: 'Inspección municipal',
              text: fine > 0
                  ? '$addr · instalación de nivel mínimo: multa de ${_money(fine)}'
                  : '$addr · instalación de nivel $lv: sin consecuencias',
              at: now));
        case EvKind.temporal:
          final d = lotOf(p).district;
          final affected = props.where((o) => lotOf(o).district == d).toList();
          final cost = affected.fold<double>(0, (a, o) => a + valueOf(o) * 0.02);
          _addEvent(GameEvent(
              id: nextId++,
              kind: k,
              propId: p.id,
              amount: cost.roundToDouble(),
              props: affected.map((e) => e.id).toList(),
              title: 'Temporal en ${city.districts[d].name}',
              text: '${affected.length} ${affected.length == 1 ? 'vivienda dañada' : 'viviendas dañadas'} · reparación ${_money(cost)}',
              at: now));
        default:
          return;
      }
    } else {
      final kinds = <EvKind>[EvKind.hallazgo];
      if (p.state == PState.venta || p.state == PState.lista) kinds.add(EvKind.ofertaInesperada);
      if ((p.levels[Trade.ele] ?? 0) >= 10) kinds.add(EvKind.subvencion);
      final k = kinds[rng.nextInt(kinds.length)];
      switch (k) {
        case EvKind.ofertaInesperada:
          final amount = (valueOf(p) * rng.rangeD(1.05, 1.22) / 100).round() * 100.0;
          _addEvent(GameEvent(
              id: nextId++,
              kind: k,
              propId: p.id,
              amount: amount,
              title: 'Oferta inesperada',
              text: '$addr · alguien ofrece ${_money(amount)}, más que su valor de mercado',
              at: now));
        case EvKind.inquilinoModelo:
          p.tenant?.type = TenantType.ejemplar;
          p.tenant?.sat = math.min(100.0, (p.tenant?.sat ?? 60) + 20);
          _addEvent(GameEvent(
              id: nextId++,
              kind: k,
              propId: p.id,
              title: 'Inquilino modelo',
              text: '$addr · paga puntual y cuida la vivienda. Satisfacción +20',
              at: now));
        case EvKind.subvencion:
          final amount = (p.m2 * 40.0 * (p.levels[Trade.ele] ?? 10) / 10).roundToDouble();
          _addEvent(GameEvent(
              id: nextId++,
              kind: k,
              propId: p.id,
              amount: amount,
              title: 'Subvención de eficiencia',
              text: '$addr · pago único de ${_money(amount)} por la instalación eléctrica',
              at: now));
        case EvKind.hallazgo:
          final pc = rng.rangeD(0.02, 0.05);
          p.bonus += pc;
          _addEvent(GameEvent(
              id: nextId++,
              kind: k,
              propId: p.id,
              amount: pc,
              title: 'Hallazgo en la obra',
              text: '$addr · un detalle original sube el valor un ${(pc * 100).toStringAsFixed(0)} %',
              at: now));
        default:
          return;
      }
    }
  }

  void _addEvent(GameEvent e) {
    events.add(e);
    _sfx('aviso');
    _inc('events');
    _push(Notice(NoticeKind.event, e.title, propId: e.propId, data: {'id': e.id}));
  }

  GameEvent? eventById(int id) {
    for (final e in events) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Respuestas a eventos. [action]: pagar, esperar, rescindir, aceptar, rechazar, cobrar, amortizar.
  String? resolveEvent(int id, String action) {
    final e = eventById(id);
    if (e == null) return null;
    final p = e.propId == null ? null : prop(e.propId!);
    switch (e.kind) {
      case EvKind.averia:
        if (action == 'pagar') {
          if (cash < e.amount) return 'Efectivo insuficiente';
          cash -= e.amount;
          p?.breakdown = false;
        } else {
          p?.tenant?.sat -= 10;
        }
      case EvKind.impago:
        if (action == 'rescindir' && p != null) {
          p.tenant = null;
          p.state = PState.buscando;
          p.vacancyLeft = _vacancyTime(p);
        }
      case EvKind.mejora:
        if (action == 'pagar') {
          if (cash < e.amount) return 'Efectivo insuficiente';
          cash -= e.amount;
          if (p != null) {
            p.tenant?.sat = math.min(100.0, (p.tenant?.sat ?? 50) + 18);
            p.bonus += 0.01;
          }
        } else {
          p?.tenant?.sat -= 8;
        }
      case EvKind.inspeccion:
        cash -= e.amount;
      case EvKind.temporal:
        if (action == 'pagar') {
          if (cash < e.amount) return 'Efectivo insuficiente';
          cash -= e.amount;
        } else {
          for (final id in e.props) {
            final o = prop(id);
            if (o != null) o.bonus -= 0.04;
          }
        }
      case EvKind.ofertaInesperada:
        if (action == 'aceptar' && p != null) {
          _completeSale(p, e.amount, clock);
        }
      case EvKind.subvencion:
        cash += e.amount;
      case EvKind.banco:
        if (action == 'amortizar' && p != null) {
          final need = math.max(0.0, p.debt - valueOf(p) * Eco.mortgageLtv);
          if (cash < need) return 'Necesitas ${_money(need)} para amortizar';
          cash -= need;
          p.debt -= need;
          bankDeadline.remove(p.id);
        } else {
          return null; // esperar: el aviso sigue
        }
      case EvKind.rival:
        // Un rival tienta a tu inquilino: bajar la renta, pagar una mejora o dejarle ir.
        if (p == null || p.tenant == null) break;
        if (action == 'bajar') {
          p.rentX = math.max(0.7, p.rentX - 0.10);
          p.tenant!.sat = math.min(100.0, p.tenant!.sat + 15);
        } else if (action == 'mejorar') {
          if (cash < e.amount) return 'Efectivo insuficiente';
          cash -= e.amount;
          p.tenant!.sat = math.min(100.0, p.tenant!.sat + 25);
          p.bonus += 0.01;
        } else {
          final rid = e.props.isEmpty ? -1 : e.props.first;
          final r = rivals.where((x) => x.id == rid).firstOrNull;
          p.tenant = null;
          p.state = PState.buscando;
          p.vacancyLeft = _vacancyTime(p);
          if (r != null) _pushNews('${r.name} se lleva a un inquilino de ${streetOf(p)}', 'La competencia aprieta en ${districtOf(p).name}');
        }
      default:
        break;
    }
    events.remove(e);
    notifyListeners();
    return null;
  }

  void _checkBank(int now) {
    for (final p in List<Property>.from(props)) {
      if (p.debt <= 0) continue;
      final v = valueOf(p);
      if (v < p.debt) {
        if (!bankDeadline.containsKey(p.id)) {
          bankDeadline[p.id] = now + 30 * 60000;
          _addEvent(GameEvent(
              id: nextId++,
              kind: EvKind.banco,
              propId: p.id,
              amount: p.debt - v,
              title: 'Aviso del banco',
              text: '${addressOf(p)} vale menos que su hipoteca. Amortiza o el banco ejecutará en 30 min.',
              at: now));
        } else if (now > bankDeadline[p.id]!) {
          bankDeadline.remove(p.id);
          events.removeWhere((e) => e.kind == EvKind.banco && e.propId == p.id);
          props.remove(p);
          for (final c in crews) {
            if (c.propId == p.id) c.propId = null;
          }
          _push(Notice(NoticeKind.toast, 'El banco ha ejecutado la hipoteca de ${addressOf(p)}'));
        }
      } else if (bankDeadline.containsKey(p.id)) {
        bankDeadline.remove(p.id);
        events.removeWhere((e) => e.kind == EvKind.banco && e.propId == p.id);
      }
    }
  }

  // ======================================================================
  // Acciones del jugador
  // ======================================================================
  String? buy(Listing l, {double loan = 0}) {
    if (!canBuy) return 'Disponible en la fase Casero';
    if (loan > 0 && !hasMortgage) return mortgageLock;
    final maxLoan = l.price * Eco.mortgageLtv;
    loan = loan.clamp(0.0, maxLoan);
    final need = l.price - loan;
    if (cash < need) return 'Efectivo insuficiente';
    final lot = city.lots[l.lotId];
    cash -= need;
    final habitable = l.origin == Origin.subasta || l.origin == Origin.embargo || l.origin == Origin.rival;
    for (var u = 0; u < l.units; u++) {
      final p = _newProperty(lot, unit: l.building ? u + 1 : 0, levels: l.levels, origin: l.origin);
      p.paid = l.price / l.units;
      p.debt = loan / l.units;
      if (habitable) {
        // Habitable: se puede vender o alquilar al momento, o reformar para subir el margen.
        p.everRenovated = true;
        p.humidity = false;
        p.badWiring = false;
        p.state = PState.lista;
      }
      _recalc(p);
      props.add(p);
    }
    listings.remove(l);
    _sfx('compra');
    // Si un rival la vendía, cobra él.
    if (l.origin == Origin.rival) {
      final r = rivals.where((x) => x.id == l.rivalId).firstOrNull;
      if (r != null) {
        r.cash += l.price;
        r.sold++;
        r.lots.remove(l.lotId);
      }
    }
    _inc('buys');
    if (l.price / l.units < 30000 * cityTraitInfo[city.trait]!.price) _missionProgress('crisis_compra', 1);
    if (phase == MarketPhase.crisis) _unlock('crisis');
    if (props.length >= 10) _unlock('diez');
    selectedLot = lot.id;
    notifyListeners();
    return null;
  }

  /// Comprueba si se puede lanzar la reforma; devuelve el motivo si no.
  String? canStartReno(Property p, Map<Trade, int> levels) {
    if (p.state == PState.obra) return 'Ya está en obra';
    if (activeRenos >= maxRenos) return 'Una obra a la vez hasta la fase Empresa de reformas';
    final lv = clampTargets(p, levels);
    if ((lv[Trade.ele] ?? 0) <= 0) return 'La electricidad es obligatoria';
    if (!Trade.values.any((t) => lv[t]! > p.lv(t))) return 'Sube al menos un oficio';
    for (final t in Trade.values) {
      if (lv[t]! > p.lv(t) && lv[t]! > tradeLv[t]!) return '${ti(t).name}: nivel ${lv[t]} no disponible';
    }
    final cost = renoCost(p, lv);
    if (cash < cost) return 'Te faltan ${_money(cost - cash)}';
    return null;
  }

  String? startReno(Property p, Map<Trade, int> levels) {
    final err = canStartReno(p, levels);
    if (err != null) return err;
    final lv = clampTargets(p, levels);
    // Reformar obliga a rescindir o retirar del mercado.
    p.tenant = null;
    offers.removeWhere((o) => o.propId == p.id);
    final cost = renoCost(p, lv);
    final work = <Trade, double>{};
    for (final t in Trade.values) {
      var w = Eco.stepWork(t, p.m2, p.lv(t), lv[t]!);
      if (w <= 0) continue;
      if (t == Trade.alb && p.humidity && !p.everRenovated) w *= 1.3;
      if (t == Trade.ele && p.badWiring && !p.everRenovated) w *= 1.25;
      work[t] = w.roundToDouble();
    }
    cash -= cost;
    final now = clock;
    p.reno = Reno(
      sector: bestSectorFor(p, lv),
      levels: lv,
      base: p.effLevels,
      work: work,
      done: {for (final t in work.keys) t: 0.0},
      cost: cost,
      startedAt: now,
      lastActivity: now,
      defectsRevealed: true,
    );
    p.state = PState.obra;
    _inc('renosStarted');
    if (!p.everRenovated && (p.humidity || p.badWiring)) {
      final parts = <String>[];
      if (p.humidity) parts.add('humedades (+30 % de toques en albañilería)');
      if (p.badWiring) parts.add('instalación peor de lo esperado (+25 % en electricidad)');
      _push(Notice(NoticeKind.defects, 'Defectos ocultos: ${parts.join(' y ')}', propId: p.id));
    }
    // Asigna cuadrillas automáticas libres.
    for (final c in crews) {
      if (c.auto && c.propId == null && p.reno!.has(c.trade)) c.propId = p.id;
    }
    notifyListeners();
    return null;
  }

  /// Toque manual en una fase. [crit] si se acertó un punto crítico.
  TapResult tap(Property p, Trade t, {bool crit = false, double scale = 1}) {
    final r = p.reno;
    if (r == null || !r.has(t)) return TapResult(ok: false, reason: 'Sin obra');
    if (r.phaseDone(t)) return TapResult(ok: false, reason: 'Fase terminada');
    if (energy < 1) return TapResult(ok: false, reason: 'energia');
    final now = nowMs();
    energy -= 1;
    if (now - lastTapMs < 1500) {
      combo = math.min(2.0, combo + 0.02);
    } else {
      combo = 1;
    }
    lastTapMs = now;
    if (combo >= 1.999) _unlock('combo');
    final power = (1 + toolLv[t]!) * combo * meta.speedBonus * (workBoost ? 2 : 1) * (crit ? 10 : 1) * scale * (eraCfg?.tapMult ?? 1);
    final before = r.frac(t);
    r.done[t] = math.min(r.work[t] ?? 0, (r.done[t] ?? 0) + power);
    r.lastActivity = clock;
    _inc('taps');
    _missionProgress('toques', 1);
    meta.passXp += 1;
    if (crit) {
      _inc('crits');
      if (stat('crits') >= 25) _unlock('critico');
    }
    tapsToCrit--;
    final phaseDone = before < 1 && r.frac(t) >= 1;
    if (phaseDone) _sfx('fase');
    var renoDone = false;
    if (phaseDone && r.allDone) {
      finishReno(p);
      renoDone = true;
    }
    notifyListeners();
    return TapResult(ok: true, power: power, crit: crit, phaseDone: phaseDone, renoDone: renoDone);
  }

  /// Decoración por capas: el tablero informa de la fracción de la fase ya pintada y se cobra
  /// la energía equivalente a los toques que habría costado ese trabajo (la herramienta abarata).
  TapResult paintTo(Property p, double frac) => workTo(p, Trade.dec, frac);

  /// Igual que [paintTo] para cualquier oficio cuyo tablero lleve su propio progreso
  /// (decoración por capas, fontanería por juntas).
  TapResult workTo(Property p, Trade t, double frac) {
    final r = p.reno;
    if (r == null || !r.has(t)) return TapResult(ok: false, reason: 'Sin obra');
    if (r.phaseDone(t)) return TapResult(ok: false, reason: 'Fase terminada');
    final work = r.work[t] ?? 0;
    // ≥ 99,9 % cuenta como la fase entera: que un redondeo no deje la pintura a medias.
    final target = frac >= 0.999 ? work : frac.clamp(0.0, 1.0) * work;
    final delta = target - (r.done[t] ?? 0);
    if (delta <= 0) return TapResult(ok: true);
    final now = nowMs();
    if (now - lastTapMs < 1500) {
      combo = math.min(2.0, combo + 0.02);
    } else {
      combo = 1;
    }
    lastTapMs = now;
    if (combo >= 1.999) _unlock('combo');
    final power = (1 + toolLv[t]!) * combo * meta.speedBonus * (workBoost ? 2 : 1) * (eraCfg?.tapMult ?? 1);
    final cost = delta / power;
    if (energy < math.min(1.0, cost)) return TapResult(ok: false, reason: 'energia');
    energy = math.max(0.0, energy - cost);
    final before = r.frac(t);
    r.done[t] = math.min(work, target);
    r.lastActivity = clock;
    final taps = math.max(1, cost.round());
    _inc('taps', taps.toDouble());
    _missionProgress('toques', taps);
    meta.passXp += taps;
    tapsToCrit -= taps;
    final phaseDone = before < 1 && r.frac(t) >= 1;
    if (phaseDone) _sfx('fase');
    var renoDone = false;
    if (phaseDone && r.allDone) {
      finishReno(p);
      renoDone = true;
    }
    notifyListeners();
    return TapResult(ok: true, power: delta, phaseDone: phaseDone, renoDone: renoDone);
  }

  /// Chispazo al conectar mal un cable: se pierde el combo y algo de energía.
  void shortCircuit() {
    combo = 1;
    energy = math.max(0.0, energy - 3);
    _sfx('chispazo');
    notifyListeners();
  }

  bool get critReady => tapsToCrit <= 0;
  void consumeCrit() => tapsToCrit = rng.range(20, 30);

  /// Recalcula calidad y perfil de la vivienda con sus niveles actuales.
  void _recalc(Property p) {
    final s = bestSectorFor(p);
    p.sector = s;
    p.quality = qualityFor(p, s);
  }

  /// Termina la reforma (todas las fases o cierre a medias).
  void finishReno(Property p, {bool partial = false, bool silent = false}) {
    final r = p.reno;
    if (r == null) return;
    // Reembolso de fases sin empezar al cerrar a medias.
    var refund = 0.0;
    if (partial) {
      for (final t in Trade.values) {
        if (r.has(t) && (r.done[t] ?? 0) <= 0) {
          refund += Eco.stepCost(t, p.m2, r.base[t] ?? 0, r.levels[t] ?? 0) * renoCostMult(p);
        }
      }
      refund = math.min(refund, r.cost);
      if (!p.isClient) cash += refund;
    }
    final lv = {for (final t in Trade.values) t: r.levelNow(t)};
    final before = p.quality;
    p.levels = lv;
    p.doneFrac = {for (final t in Trade.values) if (lv[t]! > 0) t: 1.0};
    p.state = PState.lista;
    p.everRenovated = true;
    p.breakdown = false;
    p.wear = 0;
    p.worn = 0;
    _recalc(p);
    final q = p.quality;
    final sector = p.sector!;
    final cost = r.cost - refund;
    p.spent += cost;
    p.reno = null;
    for (final c in crews) {
      if (c.propId == p.id) c.propId = null;
    }
    if (p.isClient) {
      _finishJob(p, partial: partial, silent: silent);
      notifyListeners();
      return;
    }
    renosDone++;
    _inc('renos');
    _inc('renoCost', cost);
    _missionProgress('reforma_${sector.name}', 1);
    _missionProgress('reformas', 1);
    _missionProgress('crisis_reforma', 1);
    if (!silent) _sfx('objetivo');
    meta.passXp += 40;
    _unlock('primera_obra');
    final opt = si(sector).optimal;
    if (q >= 0.999 && Trade.values.every((t) => (lv[t] ?? 0) <= math.max(opt[t]!, r.base[t] ?? 0))) _unlock('ajustado');
    // Zona que cambia: cada reforma atrae a su público al barrio.
    _shiftDistrict(lotOf(p).district, sector);
    _push(Notice(NoticeKind.renoDone, 'Obra terminada', propId: p.id, data: {
      'quality': q,
      'qualityBefore': before,
      'cost': cost,
      'value': valueOf(p),
      'paid': p.paid,
      'levels': {for (final t in Trade.values) t.name: lv[t] ?? 0},
      'sector': sector.index,
      'partial': partial,
      'silent': silent,
    }));
    _checkStage();
    notifyListeners();
  }

  /// El público de un barrio se desplaza hacia el perfil de lo que se reforma allí (máx. ±20 puntos).
  void _shiftDistrict(int district, Sector s) {
    final sh = districtShift.putIfAbsent(district, () => {for (final x in Sector.values) x: 0.0});
    const step = 0.015;
    if ((sh[s] ?? 0) >= 0.20) return;
    sh[s] = (sh[s] ?? 0) + step;
    for (final o in Sector.values) {
      if (o != s) sh[o] = math.max(-0.20, (sh[o] ?? 0) - step / 3);
    }
  }

  String? closePartial(Property p) {
    final r = p.reno;
    if (r == null) return 'Sin obra';
    if (r.has(Trade.ele) && r.frac(Trade.ele) < 1 && (r.base[Trade.ele] ?? 0) <= 0) return 'La electricidad no admite cierre parcial';
    finishReno(p, partial: true);
    return null;
  }

  /// Valor que se pierde al cerrar ahora.
  double partialLoss(Property p) {
    final r = p.reno;
    if (r == null) return 0;
    final now = {for (final t in Trade.values) t: r.levelNow(t)};
    return valueOf(p, levels: r.levels, renovated: true) - valueOf(p, levels: now, renovated: true);
  }

  String? listForRent(Property p, double x) {
    if (p.isClient) return 'Es un encargo: la vivienda es del cliente';
    if (p.state == PState.ruina) return 'Primero hay que reformarla';
    if (!p.electricOk) return 'Sin la fase eléctrica completa no se puede alquilar';
    if (p.state == PState.obra) return 'En obra';
    p.rentX = x.clamp(0.7, 1.5);
    if (p.state == PState.alquilada) {
      notifyListeners();
      return null;
    }
    offers.removeWhere((o) => o.propId == p.id);
    p.state = PState.buscando;
    p.vacancyLeft = _vacancyTime(p);
    p.listedAt = clock;
    notifyListeners();
    return null;
  }

  String? listForSale(Property p, double y) {
    if (p.isClient) return 'Es un encargo: la vivienda es del cliente';
    if (p.state == PState.ruina) return 'Primero hay que reformarla';
    if (!p.electricOk) return 'Sin la fase eléctrica completa no se puede vender';
    if (p.state == PState.obra) return 'En obra';
    p.askY = y.clamp(0.7, 2.0);
    p.tenant = null;
    p.state = PState.venta;
    p.listedAt = clock;
    notifyListeners();
    return null;
  }

  void withdraw(Property p) {
    offers.removeWhere((o) => o.propId == p.id);
    p.state = p.everRenovated ? PState.lista : PState.ruina;
    p.tenant = null;
    notifyListeners();
  }

  void rescind(Property p) {
    p.tenant = null;
    p.state = PState.lista;
    notifyListeners();
  }

  void acceptOffer(Offer o) {
    final p = prop(o.propId);
    if (p == null) return;
    _completeSale(p, o.amount, clock);
    notifyListeners();
  }

  void rejectOffer(Offer o) {
    offers.remove(o);
    notifyListeners();
  }

  // ---------- Empresa ----------
  /// Precios de empresa de hoy (a mitad en crisis).
  double trainCost(int toLevel) => Eco.trainCost(toLevel) * Eco.companyMult(phase);
  double crewCost(int n) => Eco.crewCost(n) * Eco.companyMult(phase);
  double toolCost(int n) => Eco.toolCost(n) * Eco.companyMult(phase);

  String? train(Trade t) {
    final next = tradeLv[t]! + 1;
    if (next > levelCap) return 'Nivel máximo ($levelCap)';
    final c = trainCost(next);
    if (cash < c) return 'Te faltan ${_money(c - cash)}';
    cash -= c;
    _sfx('pago');
    tradeLv[t] = next;
    _inc('trainings');
    _missionProgress('formar', 1);
    if (next >= 10) _unlock('nivel10');
    notifyListeners();
    return null;
  }

  int crewCount(Trade t) => crews.where((c) => c.trade == t).length;

  String? hireCrew(Trade t) {
    if (!hasCrews) return 'Las cuadrillas llegan con la Empresa de reformas';
    final n = crewCount(t) + 1;
    final c = crewCost(n);
    if (cash < c) return 'Te faltan ${_money(c - cash)}';
    cash -= c;
    final crew = Crew(id: nextId++, trade: t, energy: Eco.crewMaxEnergy(tradeLv[t]!));
    crew.propId = _findWorkFor(t)?.id;
    crews.add(crew);
    _unlock('cuadrilla');
    notifyListeners();
    return null;
  }

  void fireCrew(Trade t) {
    final l = crews.where((c) => c.trade == t).toList();
    if (l.isEmpty) return;
    crews.remove(l.last);
    notifyListeners();
  }

  void assignCrew(Crew c, int? propId) {
    c.propId = propId;
    c.auto = propId == null;
    notifyListeners();
  }

  /// Horas extra: la cuadrilla sigue trabajando sin energía (salario ×1,5, riesgo de fallos).
  void setOvertime(Crew c, bool on) {
    c.overtime = on;
    notifyListeners();
  }

  /// Energía máxima de una cuadrilla.
  double crewMax(Crew c) => Eco.crewMaxEnergy(tradeLv[c.trade]!);

  String? upgradeTool(Trade t) {
    final next = toolLv[t]! + 1;
    final c = toolCost(next);
    if (cash < c) return 'Te faltan ${_money(c - cash)}';
    cash -= c;
    toolLv[t] = next;
    notifyListeners();
    return null;
  }

  double crewRateTotal(Trade t) =>
      crews.where((c) => c.trade == t).length * Eco.crewRate(tradeLv[t]!) * meta.speedBonus * (eraCfg?.crewMult ?? 1);

  // ---------- Plantillas ----------
  int get templateSlots => 5 + (meta.passClaimed.contains(5) ? 3 : 0);
  String? saveTemplate(RenoTemplate t, {int? index}) {
    if (index != null && index < meta.templates.length) {
      meta.templates[index] = t;
    } else {
      if (meta.templates.length >= templateSlots) return 'Sin huecos libres ($templateSlots)';
      meta.templates.add(t);
    }
    notifyListeners();
    return null;
  }

  void deleteTemplate(int i) {
    meta.templates.removeAt(i);
    notifyListeners();
  }

  /// Aplica una plantilla a varias viviendas a la vez; devuelve cuántas obras se lanzaron.
  int applyTemplate(RenoTemplate t, List<Property> targets) {
    var n = 0;
    for (final p in targets) {
      final lv = {for (final k in Trade.values) k: math.max(p.lv(k), math.min(t.levels[k] ?? 0, tradeLv[k]!))};
      if (startReno(p, lv) == null) n++;
    }
    return n;
  }

  // ---------- Hipotecas ----------
  double maxLoan(Property p) => math.max(0.0, valueOf(p) * Eco.mortgageLtv - p.debt);
  String? borrow(Property p, double amount) {
    if (!hasMortgage) return mortgageLock;
    final a = amount.clamp(0, maxLoan(p)).toDouble();
    if (a <= 0) return 'Sin margen de financiación';
    p.debt += a;
    cash += a;
    notifyListeners();
    return null;
  }

  String? repay(Property p, double amount) {
    final a = math.min(amount, p.debt);
    if (cash < a) return 'Efectivo insuficiente';
    cash -= a;
    p.debt -= a;
    if (p.debt < 1) p.debt = 0;
    notifyListeners();
    return null;
  }

  // ---------- Barrio ----------
  String? buyService(int districtId, Service s) {
    if (!isPromoter) return 'Disponible con el Promotor';
    final l = services.putIfAbsent(districtId, () => []);
    if (l.contains(s)) return 'Ya existe';
    if (l.length >= 3) return 'Máximo tres servicios por barrio';
    final c = Eco.serviceCost(l.length);
    if (cash < c) return 'Te faltan ${_money(c - cash)}';
    cash -= c;
    l.add(s);
    notifyListeners();
    return null;
  }

  void _gestoria(int now) {
    for (final p in props) {
      if (p.state == PState.lista && p.electricOk && !p.isClient) {
        if (gestoria.autoRent) {
          listForRent(p, gestoria.rentX);
        } else {
          listForSale(p, gestoria.askY);
        }
      }
    }
    for (final o in List<Offer>.from(offers)) {
      final p = prop(o.propId);
      if (p != null && o.amount >= valueOf(p) * gestoria.minOffer) _completeSale(p, o.amount, now);
    }
  }

  // ---------- Impulsos (anuncio opcional) ----------
  void boostWork() {
    boostWorkUntil = nowMs() + 15 * 60000;
    notifyListeners();
  }

  void boostRent() {
    boostRentUntil = nowMs() + 30 * 60000;
    notifyListeners();
  }

  void refillEnergy() {
    energy = maxEnergy;
    notifyListeners();
  }

  /// Atraer compradores: el doble de visitas durante 20 min.
  void boostSale() {
    boostSaleUntil = nowMs() + 20 * 60000;
    notifyListeners();
  }

  /// Café para todos: todas las cuadrillas recuperan su jornada.
  void cafe({bool premium = false}) {
    for (final c in crews) {
      c.energy = crewMax(c);
      c.resting = false;
    }
    if (premium) cafeReadyAt = nowMs() + 30 * 60000;
    notifyListeners();
  }

  /// Con la versión premium el café es gratis cada 30 min.
  bool get cafeFree => meta.passPremium && nowMs() >= cafeReadyAt;

  // ---------- Prestigio ----------
  int get reputationGain => Eco.reputation(netWorth);

  void foundCity() {
    final gain = reputationGain;
    meta.reputation += gain;
    meta.cities += 1;
    _unlock('ciudad');
    _sfx('ciudad');
    // La ciudad actual pasa al legado: visitable y gestionada por la gestoría.
    meta.legacy.add(LegacyCity(
      seed: seed,
      name: city.name,
      version: city.version,
      founded: clock,
      netWorth: netWorth,
      props: [
        for (final p in props)
          if (!p.isClient && p.state != PState.obra)
            LegacyProp(p.lotId, addressOf(p), p.m2, valueOf(p), p.state == PState.alquilada ? rentOf(p) : rentRef(p) * 0.8,
                p.state == PState.alquilada || p.everRenovated),
      ],
      states: {
        for (final p in props)
          p.lotId: switch (p.state) {
            PState.ruina => 'ruina',
            PState.obra => 'obra',
            PState.alquilada => 'alquilada',
            _ => 'reformada',
          },
      },
    ));
    final keep = meta;
    final st = settings;
    final used = {city.name, for (final c in meta.legacy) c.name};
    var newSeed = DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;
    // Nombre nuevo: nunca repite el de una ciudad anterior.
    for (var i = 0; i < 40 && used.contains(CityGen.nameFor(newSeed)); i++) {
      newSeed = hash2(newSeed, i + 3);
    }
    newGame(newSeed);
    meta = keep;
    settings = st;
    tutorialDone = true;
    stage = Stage.manitas;
    notifyListeners();
  }

  /// Vende una vivienda de una ciudad anterior (la gestoría se queda un 10 %).
  void sellLegacy(LegacyCity c, LegacyProp p) {
    cash += p.value * 0.9;
    c.props.remove(p);
    c.states.remove(p.lotId);
    _sfx('venta');
    notifyListeners();
  }

  // ---------- Fases ----------
  void _checkStage() {
    var s = stage;
    if (s == Stage.manitas && renosDone >= 1) s = Stage.casero;
    if (s == Stage.casero && renosDone >= 3) s = Stage.empresa;
    if (s == Stage.empresa && netWorth >= 500000) s = Stage.promotor;
    if (s == Stage.promotor && netWorth >= 5000000) s = Stage.prestigio;
    if (s != stage) {
      stage = s;
      _push(Notice(NoticeKind.stage, stageInfo[s]!.name, data: {'stage': s.index}));
      if (s == Stage.promotor) _refreshListings(force: true);
    }
  }

  // ---------- Misiones ----------
  String _dayKey(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month}-${d.day}';
  }

  void _rollMissions() {
    missionDay = _dayKey(nowMs());
    final r = Rng(hash2(seed, missionDay.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7FFFFFFF)));
    final pool = <Mission>[
      Mission(id: 'toques', text: 'Da 400 toques de obra', target: 400, reward: 1500),
      Mission(id: 'reformas', text: 'Termina 2 reformas', target: 2, reward: 4000),
      Mission(id: 'reforma_est', text: 'Reforma una vivienda para Estudiantes', target: 1, reward: 2500),
      Mission(id: 'reforma_fam', text: 'Reforma una vivienda para Familias', target: 1, reward: 4000),
      Mission(id: 'reforma_may', text: 'Reforma una vivienda para Mayores', target: 1, reward: 4500),
      Mission(id: 'reforma_eje', text: 'Reforma una vivienda para Ejecutivos', target: 1, reward: 9000),
      Mission(id: 'vender', text: 'Vende una vivienda', target: 1, reward: 3000),
      Mission(id: 'renta', text: 'Cobra \$5.000 en rentas', target: 5000, reward: 2500),
      Mission(id: 'formar', text: 'Sube un oficio de nivel', target: 1, reward: 2000),
    ];
    final picked = <Mission>[];
    while (picked.length < 3) {
      final x = pool.removeAt(r.nextInt(pool.length));
      if (x.id == 'reforma_eje' && stage.index < Stage.empresa.index) continue;
      picked.add(x);
    }
    final crisis = missions.where((x) => x.id.startsWith('crisis_') && !x.claimed).toList();
    missions
      ..clear()
      ..addAll(picked)
      ..addAll(crisis);
  }

  void _missionProgress(String id, int v) {
    for (final x in missions) {
      if (x.id == id && !x.claimed) x.progress = math.min(x.target, x.progress + v);
    }
  }

  void claimMission(Mission x) {
    if (!x.done || x.claimed) return;
    x.claimed = true;
    _sfx('objetivo');
    cash += x.reward;
    meta.passXp += 120;
    notifyListeners();
  }

  // ---------- Logros ----------
  void _unlock(String id) {
    if (meta.achievements.contains(id)) return;
    meta.achievements.add(id);
    final a = achievementsList.firstWhere((e) => e.id == id, orElse: () => Achievement(id, id, ''));
    if (a.reward != null) meta.cosmetics.add(a.reward!);
    _push(Notice(NoticeKind.achievement, a.name, data: {'id': id}));
  }

  double _lastMilestone = 0;
  void _checkAchievements() {
    if (netWorth >= 1000000) _unlock('millon');
    // Cada cifra redonda de patrimonio (100 k, 250 k, 500 k, 1 M...) suena.
    const steps = [100000.0, 250000.0, 500000.0, 1e6, 2.5e6, 5e6, 1e7, 2.5e7, 5e7, 1e8];
    final reached = steps.where((x) => netWorth >= x).fold(0.0, (a, b) => b);
    if (reached > _lastMilestone) {
      if (_lastMilestone > 0) _sfx('patrimonio');
      _lastMilestone = reached;
    }
  }

  // ---------- Pase de temporada ----------
  static const passStep = 500;
  int get passTier => math.min(20, meta.passXp ~/ passStep);
  void claimPass(int tier) {
    if (tier > passTier || meta.passClaimed.contains(tier)) return;
    meta.passClaimed.add(tier);
    if (tier % 4 == 0) {
      cash += 2000.0 * tier;
    }
    const cos = {3: 'atardecer', 7: 'ladrillo', 11: 'pastel', 15: 'modernista', 19: 'noche'};
    if (cos.containsKey(tier)) meta.cosmetics.add(cos[tier]!);
    notifyListeners();
  }

  // ---------- Avisos ----------
  void _push(Notice n) => notices.add(n);
  Notice? takeNotice() => notices.isEmpty ? null : notices.removeAt(0);
  void toast(String t) {
    _push(Notice(NoticeKind.toast, t));
    notifyListeners();
  }

  void touch() => notifyListeners();

  // ======================================================================
  // Progreso sin conexión
  // ======================================================================
  void catchUp() {
    // Las épocas no avanzan sin conexión: se retoman donde se dejaron.
    if (eraCfg != null) {
      lastTick = nowMs();
      return;
    }
    final now = nowMs();
    final away = now - lastTick;
    if (away < 15000) {
      lastTick = now;
      return;
    }
    final crewCap = 8 * 3600 * 1000;
    final total = math.min(away, 24 * 3600 * 1000);
    final acc = _Acc();
    final cashBefore = cash;
    final eventsBefore = events.length;
    // Sin conexión el tiempo de juego va más despacio: 1 hora real = Eco.offlineMonthsPerHour meses.
    final rate = Eco.offlineRate;
    final gameTotal = (total * rate).round();
    final gameCrewCap = (crewCap * rate).round();
    var t = 0;
    const stepMs = 10000;
    final crewsBackup = <int, int?>{};
    while (t < gameTotal) {
      final dtMs = math.min(stepMs, gameTotal - t);
      t += dtMs;
      // Más allá de 8 h reales solo cuentan anuncios de venta y alquiler: se paran cuadrillas y rentas.
      if (t > gameCrewCap) {
        for (final c in crews) {
          crewsBackup.putIfAbsent(c.id, () => c.propId);
          c.propId = null;
          c.auto = false;
        }
        monthAcc = 0;
      }
      _step(dtMs / 1000, acc: acc);
    }
    for (final c in crews) {
      if (crewsBackup.containsKey(c.id)) {
        c.propId = crewsBackup[c.id];
        c.auto = true;
      }
    }
    lastTick = now;
    if (away > 5 * 60000) {
      offlineReport = OfflineReport(
        away: Duration(milliseconds: away),
        counted: Duration(milliseconds: math.min(away, crewCap)),
        rent: acc.rent,
        salaries: acc.salaries,
        interest: acc.interest,
        crewWork: acc.crewWork,
        phasesDone: acc.phases,
        renosDone: acc.renos,
        sales: acc.sales,
        salesAmount: acc.salesAmount,
        offers: acc.offers,
        tenants: acc.tenants,
        events: math.max(0, events.length - eventsBefore),
      );
    }
    // Los avisos de lo ocurrido fuera se resumen en el informe (sin avalancha de notificaciones).
    notices.removeWhere((n) =>
        n.kind == NoticeKind.renoDone ||
        n.kind == NoticeKind.saleClosed ||
        n.kind == NoticeKind.tenantNew ||
        n.kind == NoticeKind.event ||
        n.kind == NoticeKind.toast ||
        n.kind == NoticeKind.market ||
        n.kind == NoticeKind.defects);
    if (cash.isNaN) cash = cashBefore;
    notifyListeners();
  }

  /// Horas reales que cuentan las cuadrillas y las rentas con el juego cerrado.
  static const offlineCapHours = 8;

  /// Previsión de lo que ocurrirá con el juego cerrado. Repite sobre una copia el mismo cálculo
  /// que [catchUp] hará al volver y apunta cuándo cae cada cosa. No toca esta partida.
  List<Forecast> forecast() {
    if (!loaded || eraCfg != null) return const [];
    final Game g;
    try {
      g = Game()..loadJson(toJson());
    } catch (_) {
      return const [];
    }
    g.notices.clear();
    final out = <Forecast>[];
    final acc = _Acc();
    final rate = Eco.offlineRate;
    final gameCap = (offlineCapHours * 3600 * 1000 * rate).round();
    const stepMs = 10000;
    var t = 0;
    while (t < gameCap) {
      t += stepMs;
      final searching = [for (final p in g.props) if (p.state == PState.buscando) p.id];
      final offersBefore = acc.offers;
      final phaseBefore = g.phase;
      g._step(stepMs / 1000, acc: acc);
      final at = Duration(milliseconds: (t / rate).round());
      for (final n in g.notices) {
        switch (n.kind) {
          case NoticeKind.renoDone:
            final p = n.propId == null ? null : g.prop(n.propId!);
            if (p != null && !p.isClient) {
              out.add(Forecast('obra', at, 'Obra terminada', '${g.addressOf(p)} está lista para alquilar o vender.'));
            }
          case NoticeKind.saleClosed:
            out.add(Forecast('venta', at, 'Venta cerrada',
                '${n.data['address']} se ha vendido por ${_money((n.data['amount'] as num).toDouble())}.'));
          case NoticeKind.event:
            out.add(Forecast('eventos', at, 'Algo pendiente', n.text));
          default:
            break;
        }
      }
      g.notices.clear();
      for (final id in searching) {
        final p = g.prop(id);
        if (p != null && p.state == PState.alquilada) {
          out.add(Forecast('inquilino', at, 'Inquilino nuevo', 'Contrato firmado en ${g.addressOf(p)}.'));
        }
      }
      if (acc.offers > offersBefore && g.offers.isNotEmpty) {
        final p = g.prop(g.offers.last.propId);
        if (p != null) {
          out.add(Forecast('venta', at, 'Tienes una oferta', 'Alguien quiere ${g.addressOf(p)}. Caduca en 24 horas.'));
        }
      }
      if (g.phase != phaseBefore) {
        out.add(Forecast('mercado', at, 'El mercado se mueve', '${g.city.name} entra en ${mph(g.phase).name.toLowerCase()}.'));
      }
    }
    // A las 8 horas se paran cuadrillas y rentas: es el mejor momento para volver.
    final working = g.crews.any((c) => c.propId != null && g.prop(c.propId!)?.reno != null);
    final cap = Duration(hours: offlineCapHours);
    if (working) {
      out.add(Forecast('tope', cap, 'Las cuadrillas han parado',
          acc.rent >= 1 ? 'Llevan 8 horas sin ti. Rentas cobradas: ${_money(acc.rent)}.' : 'Llevan 8 horas sin ti. Sin jefe no hay obra.'));
    } else if (acc.rent >= 1) {
      out.add(Forecast('tope', cap, 'Rentas cobradas', 'Has ingresado ${_money(acc.rent)} mientras no estabas.'));
    }
    return out;
  }

  // ======================================================================
  // Guardado
  // ======================================================================
  Map<String, dynamic> toJson() => {
        'v': 1,
        'seed': seed,
        'rng': rng.state,
        'cityName': city.name,
        'cityV': city.version,
        'cash': cash,
        'props': props.map((e) => e.toJson()).toList(),
        'crews': crews.map((e) => e.toJson()).toList(),
        'tradeLv': {for (final e in tradeLv.entries) e.key.name: e.value},
        'toolLv': {for (final e in toolLv.entries) e.key.name: e.value},
        'events': events.map((e) => e.toJson()).toList(),
        'offers': offers.map((e) => e.toJson()).toList(),
        'listings': listings.map((e) => e.toJson()).toList(),
        'phase': phase.name,
        'phaseStarted': phaseStarted,
        'phaseEnds': phaseEnds,
        'mHistory': mHistory,
        'lastSample': lastSample,
        'renosDone': renosDone,
        'energy': energy,
        'clock': clock,
        'speed': speed,
        'gameSec': gameSec,
        'lastTick': lastTick,
        'stage': stage.name,
        'meta': meta.toJson(),
        'settings': settings.toJson(),
        'gestoria': gestoria.toJson(),
        'services': {for (final e in services.entries) '${e.key}': e.value.map((s) => s.name).toList()},
        'nextId': nextId,
        'stats': stats,
        'missions': missions.map((e) => e.toJson()).toList(),
        'missionDay': missionDay,
        'news': news.map((e) => e.toJson()).toList(),
        'monthAcc': monthAcc,
        'boostWorkUntil': boostWorkUntil,
        'boostRentUntil': boostRentUntil,
        'created': created,
        'tutorialDone': tutorialDone,
        'marketRefreshAt': marketRefreshAt,
        'bankDeadline': {for (final e in bankDeadline.entries) '${e.key}': e.value},
        'toolsCombo': combo,
        'districtShift': {
          for (final e in districtShift.entries) '${e.key}': {for (final s in e.value.entries) s.key.name: s.value},
        },
        'rivals': rivals.map((e) => e.toJson()).toList(),
        'jobs': jobs.map((e) => e.toJson()).toList(),
        'jobsRefreshAt': jobsRefreshAt,
        'boostSaleUntil': boostSaleUntil,
        'cafeReadyAt': cafeReadyAt,
        'lastPoach': lastPoach,
        'lastRivalAt': lastRivalAt,
        if (eraCfg != null) 'era': eraCfg!.id,
        if (eraCfg != null) 'eraOver': eraOver,
        if (eraCfg != null) 'eraFired': eraFired.toList(),
      };

  void loadJson(Map<String, dynamic> j) {
    seed = j['seed'] as int;
    rng = Rng.fromState(((j['rng'] as List).map((e) => (e as num).toInt())).toList());
    city = CityGen.generate(seed, name: currentCityName(j['cityName'] as String?), version: (j['cityV'] as num?)?.toInt() ?? 1);
    cash = (j['cash'] as num).toDouble();
    props
      ..clear()
      ..addAll((j['props'] as List).map((e) => Property.fromJson(Map<String, dynamic>.from(e as Map))));
    crews
      ..clear()
      ..addAll((j['crews'] as List).map((e) => Crew.fromJson(Map<String, dynamic>.from(e as Map))));
    final tl = j['tradeLv'] as Map;
    final tool = j['toolLv'] as Map;
    for (final t in Trade.values) {
      tradeLv[t] = (tl[t.name] as num?)?.toInt() ?? 1;
      toolLv[t] = (tool[t.name] as num?)?.toInt() ?? 1;
    }
    events
      ..clear()
      ..addAll((j['events'] as List).map((e) => GameEvent.fromJson(Map<String, dynamic>.from(e as Map))))
      // «Inquilino modelo» e «Impago» ya no son notificaciones (el impago se ve en cartera y ficha).
      ..removeWhere((e) => e.kind == EvKind.inquilinoModelo || e.kind == EvKind.impago);
    offers
      ..clear()
      ..addAll((j['offers'] as List).map((e) => Offer.fromJson(Map<String, dynamic>.from(e as Map))));
    listings
      ..clear()
      ..addAll((j['listings'] as List).map((e) => Map<String, dynamic>.from(e as Map)).where((e) => !Listing.legacy(e)).map(Listing.fromJson));
    // Anuncios de versiones anteriores (sin niveles de partida): se regeneran.
    if (listings.isEmpty) marketRefreshAt = 0;
    phase = MarketPhase.values.firstWhere((p) => p.name == j['phase'], orElse: () => MarketPhase.recup);
    phaseStarted = j['phaseStarted'] as int;
    phaseEnds = j['phaseEnds'] as int;
    mHistory
      ..clear()
      ..addAll((j['mHistory'] as List).map((e) => (e as num).toDouble()));
    lastSample = j['lastSample'] as int;
    renosDone = j['renosDone'] as int;
    energy = (j['energy'] as num).toDouble();
    clock = (j['clock'] as num?)?.toInt() ?? (j['lastTick'] as int);
    speed = (j['speed'] as num?)?.toDouble() ?? 1;
    gameSec = (j['gameSec'] as num?)?.toDouble() ??
        (((j['stats'] as Map)['months'] as num? ?? 0) * Eco.monthSeconds + ((j['monthAcc'] as num?) ?? 0)).toDouble();
    if (energy <= 100 && j['clock'] == null) energy = maxEnergy;
    lastTick = j['lastTick'] as int;
    stage = Stage.values.firstWhere((s) => s.name == j['stage'], orElse: () => Stage.manitas);
    meta = Meta.fromJson(Map<String, dynamic>.from(j['meta'] as Map));
    settings = Settings.fromJson(Map<String, dynamic>.from(j['settings'] as Map));
    gestoria = Gestoria.fromJson(Map<String, dynamic>.from(j['gestoria'] as Map));
    services.clear();
    (j['services'] as Map).forEach((k, v) {
      services[int.parse(k as String)] =
          (v as List).map((e) => Service.values.firstWhere((s) => s.name == e, orElse: () => Service.parque)).toList();
    });
    nextId = j['nextId'] as int;
    stats
      ..clear()
      ..addAll((j['stats'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())));
    missions
      ..clear()
      ..addAll((j['missions'] as List).map((e) => Mission.fromJson(Map<String, dynamic>.from(e as Map))));
    missionDay = j['missionDay'] as String;
    news
      ..clear()
      ..addAll((j['news'] as List).map((e) => Headline.fromJson(Map<String, dynamic>.from(e as Map))));
    monthAcc = (j['monthAcc'] as num).toDouble();
    boostWorkUntil = j['boostWorkUntil'] as int;
    boostRentUntil = j['boostRentUntil'] as int;
    created = j['created'] as int;
    tutorialDone = j['tutorialDone'] == true;
    marketRefreshAt = (j['marketRefreshAt'] as num?)?.toInt() ?? 0;
    bankDeadline.clear();
    ((j['bankDeadline'] as Map?) ?? {}).forEach((k, v) => bankDeadline[int.parse(k as String)] = (v as num).toInt());
    districtShift.clear();
    ((j['districtShift'] as Map?) ?? {}).forEach((k, v) {
      districtShift[int.parse(k as String)] = {
        for (final s in Sector.values)
          if ((v as Map)[s.name] != null) s: ((v)[s.name] as num).toDouble(),
      };
    });
    rivals
      ..clear()
      ..addAll(((j['rivals'] as List?) ?? const []).map((e) => Rival.fromJson(Map<String, dynamic>.from(e as Map))));
    jobs
      ..clear()
      ..addAll(((j['jobs'] as List?) ?? const []).map((e) => ClientJob.fromJson(Map<String, dynamic>.from(e as Map))));
    jobsRefreshAt = (j['jobsRefreshAt'] as num?)?.toInt() ?? 0;
    boostSaleUntil = (j['boostSaleUntil'] as num?)?.toInt() ?? 0;
    cafeReadyAt = (j['cafeReadyAt'] as num?)?.toInt() ?? 0;
    lastPoach = (j['lastPoach'] as num?)?.toInt() ?? 0;
    lastRivalAt = (j['lastRivalAt'] as num?)?.toInt() ?? clock;
    eraCfg = EraConfig.byId(j['era'] as String?);
    eraOver = eraCfg != null && j['eraOver'] == true;
    eraFired
      ..clear()
      ..addAll(((j['eraFired'] as List?) ?? const []).map((e) => (e as num).toInt()));
    _traitCache.clear();
    // Calidad y perfil se recalculan con el modelo de demanda por zona.
    for (final p in props) {
      if (p.reno == null) _recalc(p);
    }
    for (final c in crews) {
      if (c.energy > crewMax(c)) c.energy = crewMax(c);
    }
    loaded = true;
    selectedLot = props.isNotEmpty ? props.first.lotId : null;
    if (_dayKey(nowMs()) != missionDay) _rollMissions();
  }

  // ======================================================================
  // Encargos de clientes
  // ======================================================================
  static const _clients = [
    'Familia Ortega', 'Sra. Pons', 'Sr. Delgado', 'Comunidad del 3º', 'Familia Haddad', 'Sra. Lin',
    'Sr. Abril', 'Familia Vázquez', 'Sra. Moreau', 'Sr. Quintana', 'Familia Bauer', 'Sra. Iglesias',
  ];

  void _refreshJobs() {
    final now = clock;
    jobs.removeWhere((j) => j.expires < now);
    jobsRefreshAt = now + 15 * 60000;
    if (stage.index < Stage.casero.index) return;
    final want = inCrisis ? 4 : 2;
    var guard = 0;
    while (jobs.length < want && guard++ < 100) {
      final l = city.lots[rng.nextInt(city.lots.length)];
      if (l.landmark != null || props.any((p) => p.lotId == l.id) || listings.any((x) => x.lotId == l.id) || rivalOwner(l.id) != null) continue;
      if (jobs.any((j) => j.lotId == l.id)) continue;
      final base = rollLevels(rng, Origin.encargo);
      final target = Map<Trade, int>.of(base);
      // El cliente pide subir 2 o 3 oficios hasta donde tu empresa puede llegar.
      final ts = List<Trade>.of(Trade.values)..shuffle(math.Random(rng.nextInt(1 << 30)));
      var n = 0;
      for (final t in ts) {
        if (n >= rng.range(2, 3)) break;
        final cap = tradeLv[t]!;
        if (cap <= base[t]!) continue;
        target[t] = math.min(cap, base[t]! + rng.range(2, 5));
        n++;
      }
      if (n == 0) continue;
      final m2 = kindInfo[l.kind]!.m2;
      var cost = 0.0, work = 0.0;
      for (final t in Trade.values) {
        cost += Eco.stepCost(t, m2, base[t]!, target[t]!);
        work += Eco.stepWork(t, m2, base[t]!, target[t]!);
      }
      final fee = (cost * 0.45 * (inCrisis ? 1.2 : 1.0) / 100).round() * 100.0;
      jobs.add(ClientJob(
        id: nextId++,
        lotId: l.id,
        client: _clients[rng.nextInt(_clients.length)],
        m2: m2,
        base: base,
        target: target,
        fee: math.max(800, fee),
        minutes: (20 + work / 40).round(),
        expires: now + rng.range(30, 70) * 60000,
      ));
    }
  }

  /// Toques de trabajo de un encargo.
  double jobWork(ClientJob j) {
    var w = 0.0;
    for (final t in Trade.values) {
      w += Eco.stepWork(t, j.m2, j.base[t]!, j.target[t]!);
    }
    return w;
  }

  String? acceptJob(ClientJob j) {
    if (activeRenos >= maxRenos) return 'Una obra a la vez hasta la fase Empresa de reformas';
    final lot = city.lots[j.lotId];
    final p = Property(
      id: nextId++,
      lotId: lot.id,
      kind: lot.kind,
      m2: j.m2,
      levels: Map.of(j.base),
      doneFrac: {for (final t in Trade.values) if ((j.base[t] ?? 0) > 0) t: 1.0},
      origin: Origin.encargo,
      everRenovated: true,
      boughtAt: clock,
      clientFee: j.fee,
      clientDeadline: clock + j.minutes * 60000,
      clientName: j.client,
    );
    props.add(p);
    final err = startReno(p, j.target);
    if (err != null) {
      props.remove(p);
      return err;
    }
    jobs.remove(j);
    selectedLot = lot.id;
    notifyListeners();
    return null;
  }

  void _checkJobs(int now, _Acc? acc) {
    jobs.removeWhere((j) => j.expires < now);
    for (final p in List<Property>.from(props)) {
      if (!p.isClient || p.clientDeadline > now) continue;
      // Plazo vencido: el cliente se lleva la obra y no paga.
      props.remove(p);
      for (final c in crews) {
        if (c.propId == p.id) c.propId = null;
      }
      if (acc == null) _push(Notice(NoticeKind.toast, 'Encargo perdido: ${p.clientName} ha buscado otra empresa', propId: p.id));
    }
  }

  void _finishJob(Property p, {bool partial = false, bool silent = false}) {
    final fee = partial ? p.clientFee * 0.5 : p.clientFee;
    cash += fee;
    props.remove(p);
    _inc('jobs');
    _missionProgress('crisis_encargo', 1);
    meta.passXp += 25;
    _push(Notice(NoticeKind.toast, 'Encargo terminado para ${p.clientName}: +${_money(fee)}', propId: p.id));
  }

  // ======================================================================
  // Inversores rivales
  // ======================================================================
  static const _rivalNames = [
    'Mancini Capital', 'Hermanos Ruina', 'Grupo Ladrillo Feliz', 'Inversiones Gaviota', 'Vértice Patrimonial',
    'Nuria Soler Inversiones', 'Torres & Torres', 'Fondo Andamio',
  ];
  static const _rivalColors = [0xFFB98AD6, 0xFFE2675B, 0xFF5AA6D6, 0xFF78D9AB];

  /// Cuántos rivales tocan según tu progreso (salen de uno en uno, nunca de golpe).
  int get rivalCap {
    if (stage.index < Stage.casero.index) return 0;
    if (stage == Stage.casero) return 1;
    if (stage == Stage.empresa) return 2;
    if (netWorth < 2000000) return 3;
    return 4;
  }

  void _rivalsStep(int now, double dt, {bool live = true}) {
    // Aparición: como mucho uno cada 25 min de juego.
    if (rivals.length < rivalCap && now - lastRivalAt >= 25 * 60000) {
      final used = rivals.map((r) => r.style).toSet();
      final styles = RivalStyle.values.where((s) => !used.contains(s)).toList();
      final names = _rivalNames.where((n) => !rivals.any((r) => r.name == n)).toList();
      if (styles.isNotEmpty && names.isNotEmpty) {
        final r = Rival(
          id: nextId++,
          name: names[rng.nextInt(names.length)],
          style: styles[rng.nextInt(styles.length)],
          color: _rivalColors[rivals.length % _rivalColors.length],
          cash: math.max(60000, netWorth * 0.8),
        );
        rivals.add(r);
        lastRivalAt = now;
        _pushNews('${r.name} llega a ${city.name}', rivalStyleInfo[r.style]!.desc);
        if (live) _push(Notice(NoticeKind.toast, 'Nuevo inversor en la ciudad: ${r.name}'));
        // Empieza con un par de edificios.
        for (var i = 0; i < 2; i++) {
          final pool = city.lots.where((l) => rivalStyleInfo[r.style]!.zones.contains(l.zone) && !_taken(l.id)).toList();
          if (pool.isNotEmpty) r.lots.add(pool[rng.nextInt(pool.length)].id);
        }
      }
    }
    for (final r in rivals) {
      // Su caja crece con sus rentas.
      r.cash += r.lots.length * 40 * dt;
    }
    // Compras y pujas.
    for (final l in List<Listing>.from(listings)) {
      if (l.rivalId == null || l.origin == Origin.rival) continue;
      final r = rivals.where((x) => x.id == l.rivalId).firstOrNull;
      if (r == null) continue;
      // Subastas: el especulador sube la puja poco a poco.
      if (l.auction && rivalStyleInfo[r.style]!.auctions && rng.chance(dt / 90)) {
        l.price = (l.price * rng.rangeD(1.02, 1.05) / 100).round() * 100.0;
      }
      if (now < l.rivalBuysAt || l.reserved(now)) continue;
      if (r.cash < l.price) continue;
      r.cash -= l.price;
      r.lots.add(l.lotId);
      r.bought++;
      listings.remove(l);
      _pushNews('${r.name} compra en ${city.streets[city.lots[l.lotId].street].name}', Tx.rivalBuy[rng.nextInt(Tx.rivalBuy.length)]);
      if (live && selectedLot == l.lotId) {
        _push(Notice(NoticeKind.toast, '${r.name} se te ha adelantado'));
        _sfx('rival');
      }
    }
    // En burbuja venden algo de su cartera.
    if (phase == MarketPhase.burbuja && rng.chance(dt / 600)) _rivalSell(now, 1.0);
  }

  bool _taken(int lotId) =>
      city.lots[lotId].landmark != null ||
      props.any((p) => p.lotId == lotId) || listings.any((x) => x.lotId == lotId) || rivalOwner(lotId) != null;

  /// Un rival pone a la venta una de sus viviendas (reformada, con niveles visibles).
  void _rivalSell(int now, double mult) {
    final sellers = rivals.where((r) => r.lots.isNotEmpty).toList();
    if (sellers.isEmpty) return;
    final r = sellers[rng.nextInt(sellers.length)];
    final lotId = r.lots.elementAt(rng.nextInt(r.lots.length));
    if (listings.any((x) => x.lotId == lotId)) return;
    final lot = city.lots[lotId];
    final lv = rollLevels(rng, Origin.rival);
    final worth = valueOf(_probe(lot, lv, renovated: true));
    listings.add(Listing(
      lotId: lotId,
      price: (worth * mult * rng.rangeD(0.95, 1.05) / 100).round() * 100.0,
      auction: false,
      expires: now + rng.range(30, 80) * 60000,
      origin: Origin.rival,
      levels: lv,
      rivalId: r.id,
      listedAt: now,
    ));
  }

  /// Crisis: los rivales endeudados venden por debajo de mercado.
  void _rivalsFireSale(int now) {
    for (var i = 0; i < math.min(3, rivals.length); i++) {
      _rivalSell(now, 0.80);
    }
    if (rivals.isNotEmpty) _pushNews('Liquidaciones: inversores venden con descuento', 'Hay gangas para quien tenga liquidez');
  }

  /// Un rival con viviendas en el barrio intenta llevarse a tu inquilino (con aviso previo).
  void _maybePoach(Property p, int now) {
    if (nowMs() - lastPoach < 30 * 60000) return;
    if (events.any((e) => e.kind == EvKind.rival)) return;
    final d = lotOf(p).district;
    final near = rivals.where((r) => r.lots.any((id) => city.lots[id].district == d)).toList();
    if (near.isEmpty || !rng.chance(0.06)) return;
    final r = near[rng.nextInt(near.length)];
    lastPoach = nowMs();
    final cost = (p.m2 * 25.0 / 10).round() * 10.0;
    _addEvent(GameEvent(
      id: nextId++,
      kind: EvKind.rival,
      propId: p.id,
      amount: cost,
      props: [r.id],
      title: '${p.tenant!.name} ha visto un piso de ${r.name}',
      text: '${addressOf(p)} · baja la renta un 10 %, paga una mejora de ${_money(cost)} o déjale ir.',
      at: now,
    ));
  }

  void _pushNews(String title, String body) {
    news.insert(0, Headline(title, body, clock));
    while (news.length > 12) {
      news.removeLast();
    }
  }

  // ---------- utilidades ----------
  static String _fmt(double v) {
    final s = v.round().abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  static String _money(double v) => '\$${_fmt(v)}';
}

/// Fila de «Quién la compraría».
class BuyerRow {
  final Sector sector;
  final double share;
  final double pay;
  final double prob;
  BuyerRow(this.sector, this.share, this.pay, this.prob);
}

class RenoEstimate {
  /// Perfil al que mejor encaja la reforma.
  final Sector sector;
  final double quality, value, cost, work, taps, profit, profitOpt, rent, optCost;
  RenoEstimate({
    required this.sector,
    required this.quality,
    required this.value,
    required this.cost,
    required this.work,
    required this.taps,
    required this.profit,
    required this.profitOpt,
    required this.rent,
    required this.optCost,
  });
}

class _Acc {
  double rent = 0, salaries = 0, interest = 0, crewWork = 0, salesAmount = 0;
  int phases = 0, renos = 0, sales = 0, offers = 0, tenants = 0;
}
