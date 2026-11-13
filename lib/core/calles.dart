/// Nombres de calle adaptados a cada idioma, con el formato de dirección de cada uno.
///
/// Las calles se inventan en español en `city.dart` («C/ del Columpio», «Av. del Andamio») y se
/// guardan así en la partida. Aquí se traducen al pintarlas:
///   ca  C/ del Gronxador, 19, 2n 1a   ·  Av. del Gronxador
///   en  19 Swing St., Apt 2A          ·  Swing Ave.
///   de  Schaukelstraße 19, 2. OG links ·  Schaukelallee
///   zh  秋千街19号2楼1室               ·  秋千大道
library;

/// Clave: el nombre en español sin «C/ » ni «Av. ».
/// Valores: [catalán con su preposición, inglés, alemán para componer, chino].
/// En alemán, si acaba en guion se añade «Straße»/«Allee»; si no, «straße»/«allee» pegado.
const callesTraducidas = <String, List<String>>{
  'del Gato Sereno': ['del Gat Serè', 'Serene Cat', 'Katzenruh', '静猫'],
  'del Ladrillo': ['del Maó', 'Brick', 'Ziegel', '红砖'],
  'Tres Cerillas': ['dels Tres Llumins', 'Three Matches', 'Drei-Streichhölzer-', '三火柴'],
  'del Reloj Parado': ['del Rellotge Aturat', 'Stopped Clock', 'Stehende-Uhr-', '停钟'],
  'Siete Ventanas': ['de les Set Finestres', 'Seven Windows', 'Siebenfenster', '七窗'],
  'de la Nube Baja': ['del Núvol Baix', 'Low Cloud', 'Tiefwolken', '低云'],
  'de las Grúas': ['de les Grues', 'Crane', 'Kran', '吊车'],
  'del Ancla Torcida': ["de l'Àncora Torta", 'Crooked Anchor', 'Krummanker', '歪锚'],
  'Papel Mojado': ['del Paper Mullat', 'Wet Paper', 'Nasspapier', '湿纸'],
  'del Farol Tuerto': ['del Fanal Borni', 'One-Eyed Lamp', 'Funzel', '独眼灯'],
  'Vinagrera': ['del Setrill', 'Cruet', 'Essigflaschen', '醋瓶'],
  'del Botón': ['del Botó', 'Button', 'Knopf', '纽扣'],
  'Media Luna Verde': ['de la Mitja Lluna Verda', 'Green Crescent', 'Grüner-Halbmond-', '绿月牙'],
  'del Tejado Azul': ['de la Teulada Blava', 'Blue Roof', 'Blaudach', '蓝瓦'],
  'Limonar Viejo': ['del Llimonar Vell', 'Old Lemon Grove', 'Zitronenhain', '老柠檬园'],
  'del Caracol': ['del Cargol', 'Snail', 'Schnecken', '蜗牛'],
  'Pluma Larga': ['de la Ploma Llarga', 'Long Feather', 'Langfeder', '长羽'],
  'del Silbato': ['del Xiulet', 'Whistle', 'Pfeifen', '哨子'],
  'Cometa Roja': ["de l'Estel Vermell", 'Red Kite', 'Rotdrachen', '红风筝'],
  'del Peine': ['de la Pinta', 'Comb', 'Kamm', '木梳'],
  'Almohada': ['del Coixí', 'Pillow', 'Kissen', '枕头'],
  'del Ladrillo Feliz': ['del Maó Feliç', 'Happy Brick', 'Glücksziegel', '欢砖'],
  'Gaviota Coja': ['de la Gavina Coixa', 'Limping Gull', 'Hinkemöwen', '跛鸥'],
  'del Escalón': ["de l'Esglaó", 'Step', 'Stufen', '台阶'],
  'del Andamio': ['de la Bastida', 'Scaffold', 'Gerüst', '脚手架'],
  'del Rastrillo': ['del Rascle', 'Rake', 'Rechen', '耙子'],
  'Hojalata': ['de la Llauna', 'Tin Can', 'Blech', '铁皮'],
  'del Candado': ['del Cadenat', 'Padlock', 'Riegel', '挂锁'],
  'Persiana': ['de la Persiana', 'Shutter', 'Rollladen', '百叶'],
  'del Desván': ['de les Golfes', 'Loft', 'Dachboden', '阁楼'],
  'Teja Suelta': ['de la Teula Solta', 'Loose Tile', 'Wackelziegel', '松瓦'],
  'del Azulejo': ['de la Rajola', 'Tile', 'Kachel', '瓷砖'],
  'Baldosa': ['de la Llamborda', 'Flagstone', 'Fliesen', '地砖'],
  'del Tabique': ["de l'Envà", 'Partition', 'Trennwand', '隔墙'],
  'Cemento Fresco': ['del Ciment Fresc', 'Wet Cement', 'Frischzement', '湿水泥'],
  'Viga Maestra': ['de la Biga Mestra', 'Main Beam', 'Hauptbalken', '主梁'],
  'del Ático': ["de l'Àtic", 'Penthouse', 'Mansarden', '顶楼'],
  'Mortero': ['del Morter', 'Mortar', 'Mörtel', '砂浆'],
  'de la Plomada': ['de la Plomada', 'Plumb Line', 'Senklot', '铅锤'],
  'del Capataz': ["de l'Encarregat", 'Foreman', 'Polier', '工头'],
  'Escuadra': ["de l'Escaire", 'Set Square', 'Winkel', '角尺'],
  'del Ovillo': ['del Cabdell', 'Yarn Ball', 'Knäuel', '毛线团'],
  'del Vaivén': ['del Vaivé', 'Seesaw', 'Schwingen', '摇摆'],
  'Trébol Rojo': ['del Trèvol Vermell', 'Red Clover', 'Rotklee', '红三叶'],
  'del Columpio': ['del Gronxador', 'Swing', 'Schaukel', '秋千'],
  'Mandarina': ['de la Mandarina', 'Tangerine', 'Mandarinen', '橘子'],
  'del Gorrión Listo': ['del Pardal Llest', 'Clever Sparrow', 'Schlauspatz', '灵雀'],
  'Tintero': ['del Tinter', 'Inkwell', 'Tintenfass', '墨水瓶'],
};

const _idx = {'ca': 0, 'en': 1, 'de': 2, 'zh': 3};

final _direccion = RegExp(r'^(C/|Av\.) (.+?)(?: (\d+))?(?:, (\d+)º ([12])ª)?$');

/// Dirección o nombre de calle en el idioma [lang]. Devuelve null si [s] no es una calle conocida.
String? traducirCalle(String s, String lang) {
  final i = _idx[lang];
  if (i == null) return null;
  final m = _direccion.firstMatch(s);
  if (m == null) return null;
  final nombre = callesTraducidas[m.group(2)!];
  if (nombre == null) return null;
  final avenida = m.group(1) == 'Av.';
  final numero = m.group(3);
  final planta = m.group(4);
  final puerta = m.group(5);
  final n = nombre[i];
  switch (lang) {
    case 'ca':
      final calle = '${avenida ? 'Av.' : 'C/'} $n';
      final pis = planta == null ? '' : ', ${_ordinalCa(int.parse(planta))} ${puerta}a';
      return numero == null ? calle : '$calle, $numero$pis';
    case 'en':
      final calle = '$n ${avenida ? 'Ave.' : 'St.'}';
      final pis = planta == null ? '' : ', Apt $planta${puerta == '1' ? 'A' : 'B'}';
      return numero == null ? calle : '$numero $calle$pis';
    case 'de':
      final tipo = avenida ? 'allee' : 'straße';
      final calle = n.endsWith('-') ? '$n${tipo[0].toUpperCase()}${tipo.substring(1)}' : '$n$tipo';
      final pis = planta == null ? '' : ', $planta. OG ${puerta == '1' ? 'links' : 'rechts'}';
      return numero == null ? calle : '$calle $numero$pis';
    case 'zh':
      final calle = '$n${avenida ? '大道' : '街'}';
      final pis = planta == null ? '' : '$planta楼$puerta室';
      return numero == null ? calle : '$calle$numero号$pis';
  }
  return null;
}

String _ordinalCa(int n) => switch (n) {
      1 => '1r',
      2 => '2n',
      3 => '3r',
      4 => '4t',
      _ => '$nè',
    };
