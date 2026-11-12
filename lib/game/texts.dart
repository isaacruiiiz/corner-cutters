import '../core/rng.dart';
import 'data.dart';

/// Textos de ambientación. Sarcasmo sutil dirigido al mercado y al sistema,
/// nunca a un sector de clientes. La información crítica va siempre sin ironía.
class Tx {
  static const ruinAds = [
    'Luminoso piso con mucho potencial',
    'Ideal inversores. Y valientes',
    'Para entrar a vivir después de entrar a reformar',
    'Encanto original, incluida la instalación',
    'A reformar. Entero',
    'Excelente ubicación. El resto, negociable',
    'Muchas posibilidades, pocas paredes rectas',
  ];

  static const firstNames = [
    'Marta', 'Jordi', 'Lucía', 'Ahmed', 'Elena', 'Pau', 'Sofía', 'Daniel', 'Aisha', 'Carlos', 'Nuria',
    'Tomás', 'Irene', 'Kevin', 'Laia', 'Rosa', 'Emma', 'Hugo', 'Valeria', 'Oriol', 'Yuki', 'Bruno',
  ];
  static const lastNames = [
    'García', 'Puig', 'Martín', 'Okafor', 'Soler', 'Rossi', 'Navarro', 'Chen', 'Ferrer', 'Molina',
    'Vidal', 'Kowalski', 'Romero', 'Serra', 'Blanco', 'Costa',
  ];

  static String name(Rng r) => '${r.pick(firstNames)} ${r.pick(lastNames)}';

  static String finishedQuote(double q, Map<Trade, int> levels, Sector s) {
    final over = Trade.values.where((t) => (levels[t] ?? 0) > si(s).optimal[t]!).toList();
    final skipped = Trade.values.where((t) => (levels[t] ?? 0) == 0).toList();
    if (skipped.isNotEmpty) return '«Cocina lista. El baño es un concepto»';
    if (over.contains(Trade.ele) && (levels[Trade.ele] ?? 0) >= 15) {
      return '«Domótica de nivel ${levels[Trade.ele]} para este público. Admirable. Nadie la va a notar»';
    }
    if (over.isNotEmpty) return '«Calidad por encima de lo que se paga. Generoso. Poco rentable»';
    if ((levels[Trade.ele] ?? 0) == 1) return '«Instalación en regla: no arde. Es el listón mínimo y lo cumple»';
    if (q >= 0.99) return '«Ajustado al público. Ni un dólar de más, ni uno de menos»';
    if (levels.values.every((l) => l <= 1)) return '«Reformado con mimo»';
    return '«Reformado con mimo. Y con presupuesto»';
  }

  static String selectorQuote(Map<Trade, int> levels, Sector s) {
    for (final t in Trade.values) {
      final l = levels[t] ?? 0;
      final o = si(s).optimal[t]!;
      if (l > o + 3) {
        if (t == Trade.dec) return '«Interiorismo de revista para este público. Admirable. Nadie lo va a notar»';
        if (t == Trade.ele) return '«Domótica de nivel $l para este público. Admirable. Nadie la va a notar»';
        return '«${ti(t).name} de nivel $l. El comprador no lo valora, la factura sí»';
      }
    }
    if ((levels[Trade.ele] ?? 0) == 1) return '«Instalación en regla: no arde. Es el listón mínimo y lo cumple»';
    if (levels.values.any((l) => l == 0)) return '«Cocina lista. El baño es un concepto»';
    return '«Ajustado al sector. El beneficio lo agradece»';
  }

  static const marketNews = {
    MarketPhase.crisis: [
      'El mercado se ha corregido. Como siempre, por sorpresa',
      'Los expertos recomiendan prudencia. Los mismos que recomendaban comprar',
      'Las ruinas vuelven a estar de oferta. Las de verdad y las otras',
    ],
    MarketPhase.estanc: [
      'Los precios no se mueven. Los anuncios, tampoco',
      'Estabilidad, dicen. Aburrimiento, piensa el mercado',
    ],
    MarketPhase.recup: [
      'Brotes verdes en el sector. Alguien los ha regado con crédito',
      'Los compradores vuelven, con cautela y con calculadora',
    ],
    MarketPhase.expan: [
      'Los precios suben. Los expertos, que lo vieron venir, también',
      'Récord de visitas. Algunas incluso para comprar',
    ],
    MarketPhase.burbuja: [
      'Nunca ha sido tan buen momento para vender. Ni tan malo para comprar',
      'Los pisos se venden en horas. Los sensatos, en silencio',
      'Analistas confirman que esta vez es diferente',
    ],
  };

  static const rivalBuy = [
    'Otro piso con mucho potencial. Para otro',
    'La competencia también sabe leer anuncios',
    'Comprado a primera vista. Y a primera oferta',
    'Alguien ha sido más rápido. Esta vez',
  ];

  static const rival = '«La competencia ofrece lo mismo. Más barato, dice»';
  static const impago = '«El inquilino atraviesa un periodo de liquidez creativa»';
  static const crisis = '«El mercado se ha corregido. Como siempre, por sorpresa»';
  static const averia = '«La instalación ha decidido tomarse un descanso»';
  static const inspeccion = '«El ayuntamiento se interesa por tu obra. Mucho»';
  static const temporal = '«La lluvia ha encontrado todas las grietas. Todas»';
  static const ofertaInesperada = '«Alguien ha visto el anuncio y se ha enamorado. Del precio no»';
  static const inquilinoModelo = '«Paga puntual, riega las plantas. Sospechoso»';
  static const subvencion = '«La administración premia la eficiencia. Con cierta eficiencia»';
  static const hallazgo = '«Bajo tres capas de gotelé apareció un hidráulico original»';
  static const banco = '«El banco quiere hablar contigo. No es para felicitarte»';
  static const subasta = '«Subasta judicial. Alguien perdió, alguien puede ganar»';
  static const mejora = '«El inquilino propone mejoras. Las propone, no las paga»';
  static const sinEnergia = '«Hasta los manitas descansan. Brevemente»';
  static const offline = '«Mientras dormías, tu empresa no»';
  static const ventaCerrada = '«Vendido. El comprador está encantado; tú, más»';
}
