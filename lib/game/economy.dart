import 'dart:math' as math;

import '../core/rng.dart';
import 'data.dart';

/// Fórmulas del documento de diseño ("Economía en números").
class Eco {
  /// Mes de juego: 2 minutos reales.
  static const monthSeconds = 120;

  /// Tiempo sin conexión: cada hora real cuenta como este número de meses de juego.
  static const offlineMonthsPerHour = 1.0;
  static double get offlineRate => monthSeconds * offlineMonthsPerHour / 3600;

  /// Eventos pendientes como máximo (si hay más, no se generan nuevos hasta atenderlos).
  static const maxOpenEvents = 8;

  /// Multiplicador de coste por nivel: k(L) = 1 + 0,03 · (L − 1)².
  static double k(int level) => 1 + 0.03 * math.pow(level - 1, 2);

  /// Coste de una fase: C = S · c · k(L).
  static double phaseCost(Trade t, int m2, int level) => m2 * ti(t).costPerM2 * k(level);

  /// Toques de una fase: W = S · τ · (1 + 0,10 · (L − 1)).
  static double phaseWork(Trade t, int m2, int level) => m2 * ti(t).tapsPerM2 * (1 + 0.10 * (level - 1));

  /// Calidad que aporta un oficio al nivel L para un óptimo O.
  static double tradeQuality(int level, int optimal) {
    if (level <= 0) return 0;
    if (level >= optimal) return 1;
    if (optimal <= 1) return 1;
    return 0.5 + 0.5 * (level - 1) / (optimal - 1);
  }

  /// Q = Σ a_oficio · peso_zona · fracción_completada.
  static double quality(Sector s, Zone z, Map<Trade, int> levels, Map<Trade, double> done) {
    var q = 0.0;
    for (final t in Trade.values) {
      final l = levels[t] ?? 0;
      final f = (done[t] ?? 0.0).clamp(0.0, 1.0);
      q += tradeQuality(l, si(s).optimal[t]!) * zi(z).weights[t]! * f;
    }
    return q.clamp(0.0, 1.0);
  }

  /// Valor de mercado: V = S · P · M · (0,5 + 0,5 · Q).
  static double value(int m2, double p, double m, double q) => m2 * p * m * (0.5 + 0.5 * q);

  /// Renta de referencia mensual: R = 0,008 · S · P · Ma · (0,5 + 0,5 · Q).
  static double rent(int m2, double p, double ma, double q) => 0.008 * m2 * p * ma * (0.5 + 0.5 * q);

  /// Ocupación O(x).
  static double occupancy(double x, Sector s) {
    if (x <= 1) return 1;
    return (1 - si(s).elasticity * (x - 1)).clamp(0.0, 1.0);
  }

  /// Una vivienda sin reformar (ruina o de segunda mano) vale menos que lo que tiene hecho:
  /// el comprador descuenta el trabajo que queda.
  static const unrenovated = 0.62;

  /// Precio $/m² que paga un sector: el de la zona, sin pasar de su techo.
  static double payPerM2(double zonePrice, Sector s) => math.min(zonePrice, sectorCeiling[s]!);

  /// Coste de subir una fase del nivel [from] al [to]. Lo ya hecho se descuenta, con un mínimo del 25 %.
  static double stepCost(Trade t, int m2, int from, int to) {
    if (to <= from || to <= 0) return 0;
    final full = phaseCost(t, m2, to);
    final have = from <= 0 ? 0.0 : phaseCost(t, m2, from);
    return math.max(full - have, full * 0.25);
  }

  /// Toques para subir una fase del nivel [from] al [to] (mismo criterio que el coste).
  static double stepWork(Trade t, int m2, int from, int to) {
    if (to <= from || to <= 0) return 0;
    final full = phaseWork(t, m2, to);
    final have = from <= 0 ? 0.0 : phaseWork(t, m2, from);
    return math.max(full - have, full * 0.25);
  }

  /// Probabilidad de que alguien que valora la vivienda en [worth] (con dispersión [sigma]) pague [ask].
  static double payProb(double ask, double worth, double sigma) {
    if (worth <= 0) return 0;
    return 1 - normCdf(math.log(ask / worth) / sigma);
  }

  /// Probabilidad de que lance una oferta (valora entre 0,8 · ask y ask).
  static double offerProbAt(double ask, double worth, double sigma) {
    if (worth <= 0) return 0;
    return normCdf(math.log(ask / worth) / sigma) - normCdf(math.log(0.8 * ask / worth) / sigma);
  }

  /// Obra: multiplicador de coste según la fase del mercado (en crisis la mano de obra sale barata).
  static double renoCostMult(MarketPhase p) => switch (p) {
        MarketPhase.crisis => 0.75,
        MarketPhase.estanc => 0.90,
        MarketPhase.burbuja => 1.10,
        _ => 1.0,
      };

  /// Anuncios del mercado: rebaja extra en crisis.
  static double listingMult(MarketPhase p) => switch (p) {
        MarketPhase.crisis => 0.85,
        MarketPhase.estanc => 0.95,
        _ => 1.0,
      };

  /// Formación, cuadrillas y herramientas: a mitad de precio en crisis.
  static double companyMult(MarketPhase p) => p == MarketPhase.crisis ? 0.5 : 1.0;

  // ---------- Cuadrillas ----------
  /// Energía de una cuadrilla: 100 + 20 por nivel del oficio por encima del 1.
  static double crewMaxEnergy(int tradeLevel) => 100 + 20.0 * (tradeLevel - 1);

  /// Energía por toque de trabajo de una cuadrilla (≈ 80 % de lo que gasta el jugador).
  static const crewEnergyPerWork = 0.2;

  /// Recuperación de una cuadrilla en descanso (por segundo de juego).
  static const crewRegen = 1.2;

  /// Las horas extra cuestan el salario ×1,5 mientras duran.
  static const overtimeSalaryMult = 1.5;

  /// Probabilidad de un fallo en la fase por cada minuto de juego en horas extra.
  static const overtimeSlipPerMin = 0.02;

  /// Probabilidad de que un comprador pague el precio pedido y · valor.
  static double buyProb(double y, Sector s) => 1 - normCdf(math.log(y) / si(s).sigma);

  /// Probabilidad de que un comprador lance oferta (valora entre 0,8·y y y).
  static double offerProb(double y, Sector s) {
    final sg = si(s).sigma;
    return normCdf(math.log(y) / sg) - normCdf(math.log(0.8 * y) / sg);
  }


  /// Formación: subir al nivel N cuesta 2.000 × 1,35^(N − 2).
  static double trainCost(int toLevel) => 2000 * math.pow(1.35, toLevel - 2).toDouble();

  /// Cuadrilla n: 4.000 × 1,5^(n − 1).
  static double crewCost(int n) => 4000 * math.pow(1.5, n - 1).toDouble();

  /// Salario mensual de la cuadrilla n: 4 % de su coste.
  static double crewSalary(int n) => crewCost(n) * 0.04;

  /// Herramienta n: 300 × 1,6^(n − 1).
  static double toolCost(int n) => 300 * math.pow(1.6, n - 1).toDouble();

  /// Toques por segundo de una cuadrilla.
  static double crewRate(int tradeLevel) => 2 * (1 + 0.05 * (tradeLevel - 1));

  /// Reputación = ⌊√(patrimonio / 250.000)⌋.
  static int reputation(double netWorth) => netWorth <= 0 ? 0 : math.sqrt(netWorth / 250000).floor();

  /// Interés hipotecario mensual.
  static const mortgageRate = 0.005;
  static const mortgageLtv = 0.70;

  /// Servicio de barrio: coste por unidad.
  static double serviceCost(int already) => 60000 * math.pow(1.8, already).toDouble();
}
