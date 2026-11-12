import 'dart:math' as math;

import 'data.dart';

Map<String, dynamic> _tmap<V>(Map<Trade, V> m) => {for (final e in m.entries) e.key.name: e.value};
Map<Trade, int> _tint(dynamic j) => {
      for (final t in Trade.values)
        if (j is Map && j[t.name] != null) t: (j[t.name] as num).toInt()
    };
Map<Trade, double> _tdbl(dynamic j) => {
      for (final t in Trade.values)
        if (j is Map && j[t.name] != null) t: (j[t.name] as num).toDouble()
    };
T _enum<T extends Enum>(List<T> values, dynamic name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// Reforma en curso. Cada oficio sube de su nivel actual ([base]) al objetivo ([levels]);
/// los oficios que no suben no tienen fase.
class Reno {
  /// Perfil al que mejor encaja la reforma (se calcula; ya no se elige).
  Sector sector;
  Map<Trade, int> levels; // nivel objetivo
  Map<Trade, int> base; // nivel antes de la obra
  Map<Trade, double> work; // toques necesarios (solo oficios con fase)
  Map<Trade, double> done; // toques hechos
  double cost;
  int startedAt;
  int lastActivity;
  bool defectsRevealed;
  Reno({
    required this.sector,
    required this.levels,
    Map<Trade, int>? base,
    required this.work,
    required this.done,
    required this.cost,
    required this.startedAt,
    required this.lastActivity,
    this.defectsRevealed = false,
  }) : base = base ?? {};

  /// El oficio tiene trabajo en esta obra.
  bool has(Trade t) => (work[t] ?? 0) > 0;

  double frac(Trade t) {
    final w = work[t] ?? 0;
    if (w <= 0) return 1;
    return ((done[t] ?? 0) / w).clamp(0.0, 1.0);
  }

  /// Nivel que queda en el oficio si la obra se cierra ahora (las fases cuentan en proporción).
  int levelNow(Trade t) {
    final b = base[t] ?? 0;
    final l = levels[t] ?? 0;
    if (!has(t)) return math.max(b, l);
    final f = frac(t);
    if (f >= 1) return l;
    return (b + (l - b) * f).floor();
  }

  bool phaseDone(Trade t) => !has(t) || frac(t) >= 1;
  bool get allDone => Trade.values.every(phaseDone);
  int get phasesDone => Trade.values.where((t) => has(t) && frac(t) >= 1).length;
  int get phasesTotal => Trade.values.where(has).length;
  double get totalFrac {
    var w = 0.0, d = 0.0;
    for (final t in Trade.values) {
      w += work[t] ?? 0;
      d += (done[t] ?? 0.0).clamp(0.0, work[t] ?? 0.0);
    }
    return w <= 0 ? 1 : d / w;
  }

  Trade? get current {
    for (final t in Trade.values) {
      if (has(t) && frac(t) < 1) return t;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'sector': sector.name,
        'levels': _tmap(levels),
        'base': _tmap(base),
        'work': _tmap(work),
        'done': _tmap(done),
        'cost': cost,
        'startedAt': startedAt,
        'lastActivity': lastActivity,
        'defectsRevealed': defectsRevealed,
      };
  factory Reno.fromJson(Map<String, dynamic> j) => Reno(
        sector: _enum(Sector.values, j['sector'], Sector.est),
        levels: _tint(j['levels']),
        base: _tint(j['base']),
        work: _tdbl(j['work']),
        done: _tdbl(j['done']),
        cost: (j['cost'] as num).toDouble(),
        startedAt: j['startedAt'] as int,
        lastActivity: j['lastActivity'] as int,
        defectsRevealed: j['defectsRevealed'] == true,
      );
}

class Tenant {
  TenantType type;
  /// Perfil del inquilino (estudiante, familia, mayor o ejecutivo).
  Sector sector;
  String name;
  int since;
  double sat;
  int arrears; // meses de impago pendientes
  int months; // meses que lleva en la vivienda
  /// Pagos de los últimos 12 meses (true = pagó), del más antiguo al más reciente.
  List<bool> history;
  Tenant({
    required this.type,
    this.sector = Sector.fam,
    required this.name,
    required this.since,
    required this.sat,
    this.arrears = 0,
    this.months = 0,
    List<bool>? history,
  }) : history = history ?? [];

  void record(bool paid) {
    history.add(paid);
    while (history.length > 12) {
      history.removeAt(0);
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'sector': sector.name,
        'name': name,
        'since': since,
        'sat': sat,
        'arrears': arrears,
        'months': months,
        'hist': history.map((b) => b ? '1' : '0').join()
      };
  factory Tenant.fromJson(Map<String, dynamic> j) => Tenant(
        type: _enum(TenantType.values, j['type'], TenantType.puntual),
        sector: _enum(Sector.values, j['sector'], Sector.fam),
        name: j['name'] as String,
        since: j['since'] as int,
        sat: (j['sat'] as num).toDouble(),
        arrears: (j['arrears'] as num?)?.toInt() ?? 0,
        months: (j['months'] as num?)?.toInt() ?? 0,
        history: [for (final c in ((j['hist'] as String?) ?? '').split('')) if (c.isNotEmpty) c == '1'],
      );
}

/// De dónde salió la vivienda (cambia la etiqueta y lo que se sabe de ella).
enum Origin { ruina, usada, subasta, edificio, embargo, rival, encargo }

const originLabel = {
  Origin.ruina: 'Ruina',
  Origin.usada: 'Sin reformar',
  Origin.subasta: 'Subasta',
  Origin.edificio: 'Edificio',
  Origin.embargo: 'Embargo',
  Origin.rival: 'De un inversor',
  Origin.encargo: 'Encargo',
};

enum PState { ruina, obra, lista, buscando, alquilada, venta }

const pstateLabel = {
  PState.ruina: 'RUINA',
  PState.obra: 'OBRA',
  PState.lista: 'LISTA',
  PState.buscando: 'SE ALQUILA',
  PState.alquilada: 'ALQUILADA',
  PState.venta: 'EN VENTA',
};

class Property {
  final int id;
  final int lotId;
  final int unit; // planta/puerta dentro del edificio (0 = edificio propio)
  Kind kind;
  int m2;
  PState state;
  Sector? sector;
  Map<Trade, int> levels; // niveles de la última reforma
  Map<Trade, double> doneFrac; // fracción ejecutada de cada fase
  double quality;
  Reno? reno;
  double rentX;
  double askY;
  Tenant? tenant;
  double vacancyLeft; // segundos hasta el próximo inquilino
  bool humidity; // defectos ocultos
  bool badWiring;
  double paid;
  double spent; // coste de obras
  int boughtAt;
  double debt;
  double bonus; // hallazgos: +% de valor
  bool breakdown;
  int listedAt;
  bool everRenovated;
  Origin origin;
  /// Meses alquilada desde el último retoque: la vivienda se desgasta con el uso.
  double wear;
  /// Niveles perdidos por desgaste desde la última reforma.
  int worn;
  /// Encargo para un cliente: cobro al terminar, fecha límite (reloj de juego) y nombre.
  double clientFee;
  int clientDeadline;
  String clientName;
  Property({
    required this.id,
    required this.lotId,
    this.unit = 0,
    required this.kind,
    required this.m2,
    this.state = PState.ruina,
    this.sector,
    Map<Trade, int>? levels,
    Map<Trade, double>? doneFrac,
    this.quality = 0,
    this.reno,
    this.rentX = 1,
    this.askY = 1,
    this.tenant,
    this.vacancyLeft = 0,
    this.humidity = false,
    this.badWiring = false,
    this.paid = 0,
    this.spent = 0,
    this.boughtAt = 0,
    this.debt = 0,
    this.bonus = 0,
    this.breakdown = false,
    this.listedAt = 0,
    this.everRenovated = false,
    this.origin = Origin.ruina,
    this.wear = 0,
    this.worn = 0,
    this.clientFee = 0,
    this.clientDeadline = 0,
    this.clientName = '',
  })  : levels = levels ?? {},
        doneFrac = doneFrac ?? {};

  bool get electricOk => (levels[Trade.ele] ?? 0) >= 1 && (doneFrac[Trade.ele] ?? 0) >= 1;

  /// Encargo de un cliente: no es tuya, no cuenta en el patrimonio y no se alquila ni vende.
  bool get isClient => origin == Origin.encargo;

  /// Nivel efectivo de un oficio (las fases a medias de versiones anteriores cuentan en proporción).
  int lv(Trade t) {
    final l = levels[t] ?? 0;
    final f = doneFrac[t] ?? (l > 0 ? 1.0 : 0.0);
    if (f >= 1) return l;
    return (l * f).floor();
  }

  Map<Trade, int> get effLevels => {for (final t in Trade.values) t: lv(t)};

  Map<String, dynamic> toJson() => {
        'id': id,
        'lotId': lotId,
        'unit': unit,
        'kind': kind.name,
        'm2': m2,
        'state': state.name,
        'sector': sector?.name,
        'levels': _tmap(levels),
        'doneFrac': _tmap(doneFrac),
        'quality': quality,
        'reno': reno?.toJson(),
        'rentX': rentX,
        'askY': askY,
        'tenant': tenant?.toJson(),
        'vacancyLeft': vacancyLeft,
        'humidity': humidity,
        'badWiring': badWiring,
        'paid': paid,
        'spent': spent,
        'boughtAt': boughtAt,
        'debt': debt,
        'bonus': bonus,
        'breakdown': breakdown,
        'listedAt': listedAt,
        'everRenovated': everRenovated,
        'origin': origin.name,
        'wear': wear,
        'worn': worn,
        if (isClient) 'clientFee': clientFee,
        if (isClient) 'clientDeadline': clientDeadline,
        if (isClient) 'clientName': clientName,
      };
  factory Property.fromJson(Map<String, dynamic> j) => Property(
        id: j['id'] as int,
        lotId: j['lotId'] as int,
        unit: (j['unit'] as num?)?.toInt() ?? 0,
        kind: _enum(Kind.values, j['kind'], Kind.piso),
        m2: j['m2'] as int,
        state: _enum(PState.values, j['state'], PState.ruina),
        sector: j['sector'] == null ? null : _enum(Sector.values, j['sector'], Sector.est),
        levels: _tint(j['levels']),
        doneFrac: _tdbl(j['doneFrac']),
        quality: (j['quality'] as num).toDouble(),
        reno: j['reno'] == null ? null : Reno.fromJson(Map<String, dynamic>.from(j['reno'] as Map)),
        rentX: (j['rentX'] as num).toDouble(),
        askY: (j['askY'] as num).toDouble(),
        tenant: j['tenant'] == null ? null : Tenant.fromJson(Map<String, dynamic>.from(j['tenant'] as Map)),
        vacancyLeft: (j['vacancyLeft'] as num).toDouble(),
        humidity: j['humidity'] == true,
        badWiring: j['badWiring'] == true,
        paid: (j['paid'] as num).toDouble(),
        spent: (j['spent'] as num?)?.toDouble() ?? 0,
        boughtAt: j['boughtAt'] as int,
        debt: (j['debt'] as num).toDouble(),
        bonus: (j['bonus'] as num).toDouble(),
        breakdown: j['breakdown'] == true,
        listedAt: (j['listedAt'] as num?)?.toInt() ?? 0,
        everRenovated: j['everRenovated'] == true,
        origin: _enum(Origin.values, j['origin'], Origin.ruina),
        wear: (j['wear'] as num?)?.toDouble() ?? 0,
        worn: (j['worn'] as num?)?.toInt() ?? 0,
        clientFee: (j['clientFee'] as num?)?.toDouble() ?? 0,
        clientDeadline: (j['clientDeadline'] as num?)?.toInt() ?? 0,
        clientName: j['clientName'] as String? ?? '',
      );
}

class Crew {
  final int id;
  final Trade trade;
  int? propId;
  bool auto;
  /// Jornada: se gasta trabajando y se recupera descansando.
  double energy;
  /// Descansando hasta llenar la barra.
  bool resting;
  /// Horas extra: sigue trabajando sin energía, con salario ×1,5 y riesgo de fallos.
  bool overtime;
  /// Segundos de juego en horas extra este mes (se pagan en el cobro mensual).
  double otSec;
  Crew({
    required this.id,
    required this.trade,
    this.propId,
    this.auto = true,
    this.energy = 100,
    this.resting = false,
    this.overtime = false,
    this.otSec = 0,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'trade': trade.name,
        'propId': propId,
        'auto': auto,
        'energy': energy,
        'resting': resting,
        'overtime': overtime,
        'otSec': otSec,
      };
  factory Crew.fromJson(Map<String, dynamic> j) => Crew(
        id: j['id'] as int,
        trade: _enum(Trade.values, j['trade'], Trade.alb),
        propId: j['propId'] as int?,
        auto: j['auto'] != false,
        energy: (j['energy'] as num?)?.toDouble() ?? 100,
        resting: j['resting'] == true,
        overtime: j['overtime'] == true,
        otSec: (j['otSec'] as num?)?.toDouble() ?? 0,
      );
}

class RenoTemplate {
  String name;
  Sector sector;
  Map<Trade, int> levels;
  RenoTemplate({required this.name, required this.sector, required this.levels});
  Map<String, dynamic> toJson() => {'name': name, 'sector': sector.name, 'levels': _tmap(levels)};
  factory RenoTemplate.fromJson(Map<String, dynamic> j) => RenoTemplate(
        name: j['name'] as String,
        sector: _enum(Sector.values, j['sector'], Sector.est),
        levels: _tint(j['levels']),
      );
}

class Offer {
  final int id;
  final int propId;
  final double amount;
  final int at;
  final int expires;
  Offer({required this.id, required this.propId, required this.amount, required this.at, required this.expires});
  Map<String, dynamic> toJson() => {'id': id, 'propId': propId, 'amount': amount, 'at': at, 'expires': expires};
  factory Offer.fromJson(Map<String, dynamic> j) => Offer(
        id: j['id'] as int,
        propId: j['propId'] as int,
        amount: (j['amount'] as num).toDouble(),
        at: j['at'] as int,
        expires: j['expires'] as int,
      );
}

/// Tipos de evento.
enum EvKind {
  averia,
  impago,
  inspeccion,
  temporal,
  ofertaInesperada,
  inquilinoModelo,
  subvencion,
  hallazgo,
  banco,
  subasta,
  mejora,
  /// Un inversor rival intenta llevarse a tu inquilino.
  rival,
}

class GameEvent {
  final int id;
  final EvKind kind;
  final int? propId;
  final double amount;
  final String title;
  final String text;
  final int at;
  final List<int> props; // temporal: varias viviendas
  GameEvent({
    required this.id,
    required this.kind,
    this.propId,
    this.amount = 0,
    required this.title,
    required this.text,
    required this.at,
    this.props = const [],
  });
  bool get isProblem => const {
        EvKind.averia,
        EvKind.impago,
        EvKind.inspeccion,
        EvKind.temporal,
        EvKind.banco,
        EvKind.mejora,
        EvKind.rival,
      }.contains(kind);
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'propId': propId,
        'amount': amount,
        'title': title,
        'text': text,
        'at': at,
        'props': props,
      };
  factory GameEvent.fromJson(Map<String, dynamic> j) => GameEvent(
        id: j['id'] as int,
        kind: _enum(EvKind.values, j['kind'], EvKind.averia),
        propId: j['propId'] as int?,
        amount: (j['amount'] as num).toDouble(),
        title: j['title'] as String,
        text: j['text'] as String,
        at: j['at'] as int,
        props: ((j['props'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
      );
}

/// Vivienda en venta en el mercado: ruina, sin reformar, subasta, edificio, embargo o de un rival.
class Listing {
  final int lotId;
  /// Precio actual (en subasta sube con las pujas de los rivales).
  double price;
  final bool auction;
  final int expires;
  final bool building; // lote completo (fase 4)
  final int units;
  final Origin origin;
  /// Nivel de cada oficio que ya tiene la vivienda.
  final Map<Trade, int> levels;
  /// Subasta: hasta comprarla solo se ven rangos de nivel.
  final bool hidden;
  /// Señal pagada: reservada para ti hasta este reloj de juego.
  int reservedUntil;
  /// Rival que puja o que la vende (id) y cuándo la comprará si nadie se adelanta.
  int? rivalId;
  int rivalBuysAt;
  final int listedAt;
  Listing({
    required this.lotId,
    required this.price,
    required this.auction,
    required this.expires,
    this.building = false,
    this.units = 1,
    this.origin = Origin.ruina,
    Map<Trade, int>? levels,
    this.hidden = false,
    this.reservedUntil = 0,
    this.rivalId,
    this.rivalBuysAt = 0,
    this.listedAt = 0,
  }) : levels = levels ?? {};
  bool reserved(int now) => reservedUntil > now;
  Map<String, dynamic> toJson() => {
        'lotId': lotId,
        'price': price,
        'auction': auction,
        'expires': expires,
        'building': building,
        'units': units,
        'origin': origin.name,
        'levels': _tmap(levels),
        'hidden': hidden,
        'reservedUntil': reservedUntil,
        'rivalId': rivalId,
        'rivalBuysAt': rivalBuysAt,
        'listedAt': listedAt,
        'v': 3,
      };
  /// Anuncio guardado por una versión anterior (sin niveles de partida): se descarta al cargar.
  static bool legacy(Map<String, dynamic> j) => j['v'] != 3;
  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
        lotId: j['lotId'] as int,
        price: (j['price'] as num).toDouble(),
        auction: j['auction'] == true,
        expires: j['expires'] as int,
        building: j['building'] == true,
        units: (j['units'] as num?)?.toInt() ?? 1,
        origin: _enum(Origin.values, j['origin'], Origin.ruina),
        levels: _tint(j['levels']),
        hidden: j['hidden'] == true,
        reservedUntil: (j['reservedUntil'] as num?)?.toInt() ?? 0,
        rivalId: (j['rivalId'] as num?)?.toInt(),
        rivalBuysAt: (j['rivalBuysAt'] as num?)?.toInt() ?? 0,
        listedAt: (j['listedAt'] as num?)?.toInt() ?? 0,
      );
}

/// Encargo de un cliente: reformas su casa por un precio cerrado.
class ClientJob {
  final int id;
  final int lotId;
  final String client;
  final int m2;
  final Map<Trade, int> base;
  final Map<Trade, int> target;
  final double fee;
  /// Minutos de juego para terminarla una vez aceptada.
  final int minutes;
  final int expires;
  ClientJob({
    required this.id,
    required this.lotId,
    required this.client,
    required this.m2,
    required this.base,
    required this.target,
    required this.fee,
    required this.minutes,
    required this.expires,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'lotId': lotId,
        'client': client,
        'm2': m2,
        'base': _tmap(base),
        'target': _tmap(target),
        'fee': fee,
        'minutes': minutes,
        'expires': expires,
      };
  factory ClientJob.fromJson(Map<String, dynamic> j) => ClientJob(
        id: j['id'] as int,
        lotId: j['lotId'] as int,
        client: j['client'] as String,
        m2: j['m2'] as int,
        base: _tint(j['base']),
        target: _tint(j['target']),
        fee: (j['fee'] as num).toDouble(),
        minutes: j['minutes'] as int,
        expires: j['expires'] as int,
      );
}

/// Perfiles de inversor rival.
enum RivalStyle { barato, familiar, lujo, especulador }

class RivalStyleInfo {
  final String desc;
  final List<Zone> zones;
  final bool auctions;
  const RivalStyleInfo(this.desc, this.zones, this.auctions);
}

const rivalStyleInfo = {
  RivalStyle.barato: RivalStyleInfo('Barato y rápido: ruinas de la zona universitaria', [Zone.uni, Zone.fam], false),
  RivalStyle.familiar: RivalStyleInfo('Familiar y paciente: barrios familiares', [Zone.fam, Zone.res], false),
  RivalStyle.lujo: RivalStyleInfo('Lujo: centro y residencial alto', [Zone.cen, Zone.res], false),
  RivalStyle.especulador: RivalStyleInfo('Especulador de subastas', [Zone.cen, Zone.uni, Zone.fam, Zone.res], true),
};

/// Inversor controlado por el juego que compite por las mismas viviendas e inquilinos.
class Rival {
  final int id;
  final String name;
  final RivalStyle style;
  final int color;
  double cash;
  /// Parcelas que posee en esta ciudad.
  final Set<int> lots;
  int bought;
  int sold;
  Rival({
    required this.id,
    required this.name,
    required this.style,
    required this.color,
    required this.cash,
    Set<int>? lots,
    this.bought = 0,
    this.sold = 0,
  }) : lots = lots ?? {};
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'style': style.name,
        'color': color,
        'cash': cash,
        'lots': lots.toList(),
        'bought': bought,
        'sold': sold,
      };
  factory Rival.fromJson(Map<String, dynamic> j) => Rival(
        id: j['id'] as int,
        name: j['name'] as String,
        style: _enum(RivalStyle.values, j['style'], RivalStyle.barato),
        color: (j['color'] as num).toInt(),
        cash: (j['cash'] as num).toDouble(),
        lots: ((j['lots'] as List?) ?? const []).map((e) => (e as num).toInt()).toSet(),
        bought: (j['bought'] as num?)?.toInt() ?? 0,
        sold: (j['sold'] as num?)?.toInt() ?? 0,
      );
}

/// Ciudad anterior: queda en la cartera, gestionada por la gestoría.
class LegacyProp {
  final int lotId;
  final String address;
  final int m2;
  final double value;
  final double rent;
  final bool rented;
  LegacyProp(this.lotId, this.address, this.m2, this.value, this.rent, this.rented);
  Map<String, dynamic> toJson() => {'lotId': lotId, 'address': address, 'm2': m2, 'value': value, 'rent': rent, 'rented': rented};
  factory LegacyProp.fromJson(Map<String, dynamic> j) => LegacyProp(
        (j['lotId'] as num).toInt(),
        j['address'] as String,
        (j['m2'] as num).toInt(),
        (j['value'] as num).toDouble(),
        (j['rent'] as num).toDouble(),
        j['rented'] == true,
      );
}

class LegacyCity {
  final int seed;
  final String name;
  final int founded;
  final double netWorth;
  final List<LegacyProp> props;
  /// Estado del sprite por parcela (para dibujar el mapa tal como quedó).
  final Map<int, String> states;
  /// Versión del generador con la que se creó el mapa.
  final int version;
  LegacyCity({required this.seed, required this.name, required this.founded, required this.netWorth, required this.props, required this.states, this.version = 2});
  double get rent => props.where((p) => p.rented).fold(0.0, (a, p) => a + p.rent);
  double get value => props.fold(0.0, (a, p) => a + p.value);
  Map<String, dynamic> toJson() => {
        'seed': seed,
        'name': name,
        'founded': founded,
        'netWorth': netWorth,
        'props': props.map((e) => e.toJson()).toList(),
        'states': {for (final e in states.entries) '${e.key}': e.value},
        'v': version,
      };
  factory LegacyCity.fromJson(Map<String, dynamic> j) => LegacyCity(
        seed: (j['seed'] as num).toInt(),
        name: j['name'] as String,
        founded: (j['founded'] as num?)?.toInt() ?? 0,
        netWorth: (j['netWorth'] as num?)?.toDouble() ?? 0,
        props: ((j['props'] as List?) ?? const []).map((e) => LegacyProp.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        states: ((j['states'] as Map?) ?? const {}).map((k, v) => MapEntry(int.parse(k as String), v as String)),
        version: (j['v'] as num?)?.toInt() ?? 1,
      );
}

class Mission {
  final String id;
  final String text;
  final int target;
  int progress;
  final double reward;
  bool claimed;
  Mission({
    required this.id,
    required this.text,
    required this.target,
    this.progress = 0,
    required this.reward,
    this.claimed = false,
  });
  bool get done => progress >= target;
  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'target': target, 'progress': progress, 'reward': reward, 'claimed': claimed};
  factory Mission.fromJson(Map<String, dynamic> j) => Mission(
        id: j['id'] as String,
        text: j['text'] as String,
        target: j['target'] as int,
        progress: j['progress'] as int,
        reward: (j['reward'] as num).toDouble(),
        claimed: j['claimed'] == true,
      );
}

class Headline {
  final String title;
  final String body;
  final int at;
  Headline(this.title, this.body, this.at);
  Map<String, dynamic> toJson() => {'title': title, 'body': body, 'at': at};
  factory Headline.fromJson(Map<String, dynamic> j) =>
      Headline(j['title'] as String, j['body'] as String, j['at'] as int);
}

/// Reglas de la gestoría (fase 4).
class Gestoria {
  bool on;
  bool autoRent; // alquilar lo reformado (si no, vender)
  double rentX;
  double askY;
  double minOffer; // aceptar ofertas ≥ este múltiplo del valor
  Gestoria({this.on = false, this.autoRent = true, this.rentX = 1.0, this.askY = 1.1, this.minOffer = 1.0});
  Map<String, dynamic> toJson() =>
      {'on': on, 'autoRent': autoRent, 'rentX': rentX, 'askY': askY, 'minOffer': minOffer};
  factory Gestoria.fromJson(Map<String, dynamic> j) => Gestoria(
        on: j['on'] == true,
        autoRent: j['autoRent'] != false,
        rentX: (j['rentX'] as num?)?.toDouble() ?? 1,
        askY: (j['askY'] as num?)?.toDouble() ?? 1.1,
        minOffer: (j['minOffer'] as num?)?.toDouble() ?? 1,
      );
}

class Settings {
  bool sound;
  bool haptics;
  bool reduceMotion;
  /// Nubes, pájaros y hojas en el mapa (solo decorativo).
  bool ambient;
  Map<String, bool> notif;
  /// Calidad gráfica: auto, alta, media o baja.
  String quality;
  /// Música y efectos (0..1).
  double music;
  double sfx;
  /// Enviar datos de uso y errores (propios, sin terceros) para mejorar el juego.
  bool telemetry;
  Settings({
    this.sound = true,
    this.haptics = true,
    this.reduceMotion = false,
    this.ambient = true,
    Map<String, bool>? notif,
    this.quality = 'auto',
    this.music = 0.6,
    this.sfx = 0.8,
    this.telemetry = true,
  }) : notif = notif ?? {'obra': true, 'inquilino': true, 'venta': true, 'mercado': true, 'eventos': true, 'noche': false};
  Map<String, dynamic> toJson() => {
        'sound': sound,
        'haptics': haptics,
        'reduceMotion': reduceMotion,
        'ambient': ambient,
        'notif': notif,
        'quality': quality,
        'music': music,
        'sfx': sfx,
        'telemetry': telemetry,
      };
  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        sound: j['sound'] != false,
        haptics: j['haptics'] != false,
        reduceMotion: j['reduceMotion'] == true,
        ambient: j['ambient'] != false,
        notif: (j['notif'] as Map?)?.map((k, v) => MapEntry(k as String, v == true)),
        quality: j['quality'] as String? ?? 'auto',
        music: (j['music'] as num?)?.toDouble() ?? 0.6,
        sfx: (j['sfx'] as num?)?.toDouble() ?? 0.8,
        telemetry: j['telemetry'] != false,
      );
}

/// Lo que se conserva entre ciudades (prestigio).
class Meta {
  int reputation;
  int cities;
  Set<String> achievements;
  Set<String> cosmetics;
  String mapTheme;
  String facade;
  List<RenoTemplate> templates;
  int passXp;
  bool passPremium;
  Set<int> passClaimed;
  /// Ciudades anteriores (legado).
  List<LegacyCity> legacy;
  /// La guía del capataz ya se ha terminado o saltado.
  bool guideDone;
  Meta({
    this.reputation = 0,
    this.cities = 0,
    Set<String>? achievements,
    Set<String>? cosmetics,
    this.mapTheme = 'dia',
    this.facade = 'clasica',
    List<RenoTemplate>? templates,
    this.passXp = 0,
    this.passPremium = false,
    Set<int>? passClaimed,
    List<LegacyCity>? legacy,
    this.guideDone = false,
  })  : achievements = achievements ?? {},
        cosmetics = cosmetics ?? {'dia', 'clasica'},
        templates = templates ?? [],
        passClaimed = passClaimed ?? {},
        legacy = legacy ?? [];

  /// Tope de nivel de oficio: 20 + 5 por cada 10 puntos.
  int get levelCap => 20 + 5 * (reputation ~/ 10);
  double get speedBonus => 1 + 0.03 * reputation;
  double get rentBonus => 1 + 0.03 * reputation;

  Map<String, dynamic> toJson() => {
        'reputation': reputation,
        'cities': cities,
        'achievements': achievements.toList(),
        'cosmetics': cosmetics.toList(),
        'mapTheme': mapTheme,
        'facade': facade,
        'templates': templates.map((e) => e.toJson()).toList(),
        'passXp': passXp,
        'passPremium': passPremium,
        'passClaimed': passClaimed.toList(),
        'legacy': legacy.map((e) => e.toJson()).toList(),
        'guide': guideDone,
      };
  factory Meta.fromJson(Map<String, dynamic> j) => Meta(
        reputation: (j['reputation'] as num?)?.toInt() ?? 0,
        cities: (j['cities'] as num?)?.toInt() ?? 0,
        achievements: ((j['achievements'] as List?) ?? const []).map((e) => e as String).toSet(),
        cosmetics: ((j['cosmetics'] as List?) ?? const ['dia', 'clasica']).map((e) => e as String).toSet(),
        mapTheme: j['mapTheme'] as String? ?? 'dia',
        facade: j['facade'] as String? ?? 'clasica',
        templates: ((j['templates'] as List?) ?? const [])
            .map((e) => RenoTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        passXp: (j['passXp'] as num?)?.toInt() ?? 0,
        passPremium: j['passPremium'] == true,
        passClaimed: ((j['passClaimed'] as List?) ?? const []).map((e) => (e as num).toInt()).toSet(),
        legacy: ((j['legacy'] as List?) ?? const []).map((e) => LegacyCity.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        guideDone: j['guide'] == true,
      );
}
