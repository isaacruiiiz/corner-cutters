import '../game/engine.dart';

/// Una notificación del sistema ya decidida: cuándo y con qué texto (en español; se traduce al programarla).
class Aviso {
  final int id;
  final Duration en;
  final String titulo;
  final String cuerpo;
  const Aviso(this.id, this.en, this.titulo, this.cuerpo);

  @override
  String toString() => '#$id +${en.inMinutes} min · $titulo · $cuerpo';
}

/// Decide qué notificaciones se programan al cerrar el juego.
///
/// - Respeta los interruptores de Ajustes → Notificaciones ([ajustes]).
/// - Como mucho una por tipo, separadas al menos 45 minutos y cuatro en total (más el recordatorio).
/// - Con «Silencio nocturno», lo que caería entre las 23:00 y las 8:00 se junta en un aviso a las 8:05.
/// - Un recordatorio a los tres días si el jugador no ha vuelto (va con el interruptor de mercado).
List<Aviso> planAvisos(List<Forecast> prevision, Map<String, bool> ajustes, DateTime ahora, {required String ciudad}) {
  bool on(String k) => ajustes[k] ?? true;
  final noche = ajustes['noche'] ?? false;
  bool permitido(Forecast f) => switch (f.kind) {
        'tope' => on('obra') || on('inquilino'),
        _ => on(f.kind),
      };

  // Lo que pasa en los primeros minutos no se avisa: el jugador acaba de salir.
  final lista = prevision.where((f) => permitido(f) && f.at >= const Duration(minutes: 10)).toList()
    ..sort((a, b) => a.at.compareTo(b.at));

  final elegidos = <Forecast>[];
  final tipos = <String>{};
  for (final f in lista) {
    if (!tipos.add('${f.kind}|${f.title}')) continue;
    final cerca = elegidos.isNotEmpty && f.at - elegidos.last.at < const Duration(minutes: 45);
    if (cerca && f.kind != 'tope') continue;
    if (cerca && f.kind == 'tope') elegidos.removeLast();
    elegidos.add(f);
    if (elegidos.length >= 4) break;
  }

  bool deNoche(DateTime t) => t.hour >= 23 || t.hour < 8;
  Duration hastaLaManana(DateTime t) {
    var m = DateTime(t.year, t.month, t.day, 8, 5);
    if (t.hour >= 23) m = m.add(const Duration(days: 1));
    return m.difference(ahora);
  }

  final out = <Aviso>[];
  final dormidos = <Forecast>[];
  var id = 1;
  for (final f in elegidos) {
    if (noche && deNoche(ahora.add(f.at))) {
      dormidos.add(f);
    } else {
      out.add(Aviso(id++, f.at, f.title, f.body));
    }
  }
  if (dormidos.isNotEmpty) {
    final en = hastaLaManana(ahora.add(dormidos.first.at));
    out.add(dormidos.length == 1
        ? Aviso(id++, en, dormidos.first.title, dormidos.first.body)
        : Aviso(id++, en, 'Mientras dormías', '${dormidos.length} novedades en $ciudad. La primera: ${dormidos.first.title}.'));
  }

  if (on('mercado')) {
    var en = const Duration(days: 3);
    final cuando = ahora.add(en);
    if (noche && deNoche(cuando)) en = hastaLaManana(cuando);
    out.add(Aviso(id++, en, '$ciudad sigue en pie', 'El mercado ha cambiado y tus rivales no han parado. Pásate cuando puedas.'));
  }
  out.sort((a, b) => a.en.compareTo(b.en));
  return out;
}
