/// Formato de cifras en español: $48.250 · ×1,10 · 23 % · 4,3 min.
String _group(int v) {
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// DLC de épocas: nivel de precios de la época que se está jugando. Todas las cifras internas
/// del motor siguen iguales; solo cambia lo que se muestra (en 1929 un piso vale una décima parte).
/// En el modo principal es 1.
class Money {
  static double scale = 1;
}

/// Dinero: $48.250. Con [sign] antepone + o −.
String money(num v, {bool sign = false, bool compact = false}) {
  v = v * Money.scale;
  final neg = v < 0;
  final a = v.abs();
  String body;
  if (compact && a >= 1e6) {
    body = '${dec(a / 1e6, a >= 1e7 ? 1 : 2)} M';
  } else if (compact && a >= 1e5) {
    body = '${dec(a / 1e3, 0)} k';
  } else {
    body = _group(a.round());
  }
  final pre = neg ? '−' : (sign ? '+' : '');
  return '$pre\$$body';
}

/// Número con [d] decimales y coma decimal.
String dec(num v, int d) {
  final s = v.toStringAsFixed(d);
  if (d == 0) return _group(v.round());
  final parts = s.split('.');
  final ip = int.parse(parts[0].replaceAll('-', ''));
  final neg = v < 0 && (ip != 0 || parts[1].replaceAll('0', '').isNotEmpty);
  return '${neg ? '−' : ''}${_group(ip)},${parts[1]}';
}

String mult(num v) => '×${dec(v, 2)}';
String pct(num v, {int d = 0}) => '${dec(v * 100, d)} %';
String intg(num v) => _group(v.round());

/// Duración legible: 45 s · 4,3 min · 1 h 12 min · 2 d.
String dur(Duration d) {
  final s = d.inSeconds;
  if (s < 60) return '$s s';
  if (s < 600) return '${dec(s / 60, 1)} min';
  if (s < 3600) return '${(s / 60).round()} min';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h < 48) return m == 0 ? '$h h' : '$h h $m min';
  return '${d.inDays} d';
}

String durMin(double minutes) {
  if (minutes.isInfinite || minutes > 60 * 24 * 30) return 'Nunca';
  return dur(Duration(milliseconds: (minutes * 60000).round()));
}
