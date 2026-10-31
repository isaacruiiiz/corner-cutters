import 'dart:math' as math;

/// Generador determinista (xorshift128) cuyo estado se guarda con la partida:
/// recargar no permite repetir una tirada.
class Rng {
  int _a, _b, _c, _d;

  Rng(int seed)
      : _a = 0,
        _b = 0,
        _c = 0,
        _d = 0 {
    var s = seed & 0xFFFFFFFF;
    int next() {
      // splitmix32
      s = (s + 0x9E3779B9) & 0xFFFFFFFF;
      var z = s;
      z = ((z ^ (z >> 16)) * 0x85EBCA6B) & 0xFFFFFFFF;
      z = ((z ^ (z >> 13)) * 0xC2B2AE35) & 0xFFFFFFFF;
      return (z ^ (z >> 16)) & 0xFFFFFFFF;
    }

    _a = next();
    _b = next();
    _c = next();
    _d = next() | 1;
  }

  Rng.fromState(List<int> st)
      : _a = st[0],
        _b = st[1],
        _c = st[2],
        _d = st[3];

  List<int> get state => [_a, _b, _c, _d];

  int _u32() {
    var t = _d;
    final s = _a;
    _d = _c;
    _c = _b;
    _b = s;
    t ^= (t << 11) & 0xFFFFFFFF;
    t ^= t >> 8;
    _a = (t ^ s ^ (s >> 19)) & 0xFFFFFFFF;
    return _a;
  }

  /// [0, 1)
  double next() => _u32() / 4294967296.0;

  int nextInt(int max) => max <= 0 ? 0 : (next() * max).floor();
  int range(int min, int maxIncl) => min + nextInt(maxIncl - min + 1);
  double rangeD(double min, double max) => min + next() * (max - min);
  bool chance(double p) => next() < p;
  T pick<T>(List<T> l) => l[nextInt(l.length)];

  /// Normal estándar (Box-Muller).
  double gauss() {
    var u = next();
    if (u < 1e-12) u = 1e-12;
    final v = next();
    return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
  }

  /// Tiempo exponencial con media [mean].
  double expo(double mean) {
    var u = next();
    if (u < 1e-12) u = 1e-12;
    return -math.log(u) * mean;
  }

  T weighted<T>(Map<T, double> w) {
    final total = w.values.fold<double>(0, (a, b) => a + b);
    var r = next() * total;
    for (final e in w.entries) {
      r -= e.value;
      if (r <= 0) return e.key;
    }
    return w.keys.last;
  }
}

/// Función de distribución normal estándar Φ.
double normCdf(double x) {
  // Abramowitz-Stegun 7.1.26
  final t = 1 / (1 + 0.2316419 * x.abs());
  final d = 0.3989422804014327 * math.exp(-x * x / 2);
  final p = d * t * (0.3193815 + t * (-0.3565638 + t * (1.781478 + t * (-1.821256 + t * 1.330274))));
  return x >= 0 ? 1 - p : p;
}

/// Hash entero estable para derivar sub-semillas.
int hash2(int a, int b) {
  var h = (a * 374761393 + b * 668265263) & 0xFFFFFFFF;
  h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF;
  return (h ^ (h >> 16)) & 0x7FFFFFFF;
}
