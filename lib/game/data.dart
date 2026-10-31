import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Oficios: uno por fase de obra.
enum Trade { alb, fon, ele, car, dec }

class TradeInfo {
  final String name; // Albañil
  final String phase; // Albañilería
  final String code; // ALB
  final String gesture;
  final String hint;
  final double tapsPerM2;
  final double costPerM2;
  final IconData icon;
  final Color color;
  const TradeInfo(this.name, this.phase, this.code, this.gesture, this.hint, this.tapsPerM2,
      this.costPerM2, this.icon, this.color);
}

const tradeInfo = <Trade, TradeInfo>{
  Trade.alb: TradeInfo('Albañil', 'Albañilería', 'ALB', 'Toque repetido',
      'Toca la pared para demoler y levantar', 3.0, 50, Icons.grid_view_rounded, Color(0xFFD9785B)),
  Trade.fon: TradeInfo('Fontanero', 'Fontanería', 'FON', 'Mantener pulsado',
      'Mantén pulsada cada junta hasta sellarla', 2.0, 35, Icons.water_drop_outlined, Hc.info),
  Trade.ele: TradeInfo('Electricista', 'Electricidad', 'ELE', 'Unir cables',
      'Conecta en orden (1, 2, 3…) cada cable con su borne', 2.0, 30, Icons.bolt_rounded, Hc.acc),
  Trade.car: TradeInfo('Carpintero', 'Carpintería', 'CAR', 'Alternar dos puntos',
      'Toca alternando los dos puntos, cada vez más deprisa', 1.5, 20, Icons.carpenter_outlined,
      Color(0xFFB98A5A)),
  Trade.dec: TradeInfo('Decorador', 'Decoración', 'DEC', 'Pintar por capas',
      'Imprimación, dos manos y recortes: cubre toda la pared', 1.5, 15, Icons.brush_outlined, Color(0xFFB98AD6)),
};

TradeInfo ti(Trade t) => tradeInfo[t]!;

/// Qué entrega cada oficio por tramos de nivel (1, 10, 20).
const tradeTiers = <Trade, List<String>>{
  Trade.ele: [
    'Instalación mínima y segura',
    'Luces de colores y persianas motorizadas',
    'Vivienda integrada y autoconsumo'
  ],
  Trade.fon: [
    'Tuberías sin fugas y un baño básico',
    'Radiadores y baño completo con ducha',
    'Suelo radiante, baños de diseño y cocina profesional'
  ],
  Trade.alb: [
    'Estructura sana y suelo de cemento pulido',
    'Aislamiento térmico y acústico, suelo cerámico',
    'Aislamiento pasivo y distribuciones a medida'
  ],
  Trade.car: [
    'Puertas y ventanas funcionales',
    'Armarios empotrados y doble acristalamiento',
    'Mobiliario y cocina a medida'
  ],
  Trade.dec: [
    'Pintura blanca y suelo neutro',
    'Paleta coherente e iluminación decorativa',
    'Interiorismo de revista'
  ],
};

/// Detalle del electricista por tramos (doc).
const eleDetail = [
  [1, 1, 'Mínimo de seguridad: protecciones básicas', 'Ninguna', 'Consumo alto'],
  [2, 4, 'Más enchufes y cableado en canaleta', 'Interruptores con temporizador', 'Iluminación LED'],
  [5, 8, 'Cuadro por zonas e iluminación regulable', 'Termostato programable', 'Consumo medio'],
  [9, 12, 'Luces con escenas y enchufes USB', 'Persianas y luces motorizadas', 'Consumo bajo'],
  [13, 16, 'Cableado oculto y cuadro etiquetado', 'Control completo desde el móvil', 'Consumo muy bajo'],
  [17, 20, 'Instalación empotrada y recarga de coche', 'Escenas, voz y gestión de energía', 'Autoconsumo solar'],
];

/// Sectores de clientes.
enum Sector { est, fam, may, eje }

class SectorInfo {
  final String name;
  final String values;
  final Map<Trade, int> optimal;
  final double elasticity;
  final double sigma;
  final IconData icon;
  const SectorInfo(this.name, this.values, this.optimal, this.elasticity, this.sigma, this.icon);
}

const sectorInfo = <Sector, SectorInfo>{
  Sector.est: SectorInfo('Estudiantes', 'Precio bajo y funcionalidad',
      {Trade.ele: 4, Trade.fon: 4, Trade.alb: 5, Trade.car: 3, Trade.dec: 3}, 2.0, 0.09,
      Icons.school_outlined),
  Sector.fam: SectorInfo('Familias', 'Baños, estructura y espacio',
      {Trade.ele: 8, Trade.fon: 12, Trade.alb: 12, Trade.car: 10, Trade.dec: 6}, 1.0, 0.13,
      Icons.family_restroom_outlined),
  Sector.may: SectorInfo('Mayores', 'Accesibilidad y seguridad',
      {Trade.ele: 10, Trade.fon: 10, Trade.alb: 12, Trade.car: 8, Trade.dec: 5}, 0.8, 0.15,
      Icons.elderly_outlined),
  Sector.eje: SectorInfo('Ejecutivos', 'Domótica y decoración',
      {Trade.ele: 20, Trade.fon: 14, Trade.alb: 12, Trade.car: 14, Trade.dec: 18}, 0.5, 0.22,
      Icons.work_outline),
};

SectorInfo si(Sector s) => sectorInfo[s]!;

/// Zonas de la ciudad.
enum Zone { uni, fam, cen, res }

class ZoneInfo {
  final String name;
  final double price; // $/m² de referencia
  final Map<Trade, double> weights;
  final Color tint;
  const ZoneInfo(this.name, this.price, this.weights, this.tint);
}

const zoneInfo = <Zone, ZoneInfo>{
  Zone.uni: ZoneInfo('Universitaria', 1200,
      {Trade.ele: .30, Trade.fon: .20, Trade.alb: .20, Trade.car: .15, Trade.dec: .15}, Hc.info),
  Zone.fam: ZoneInfo('Barrio familiar', 1600,
      {Trade.ele: .15, Trade.fon: .30, Trade.alb: .30, Trade.car: .15, Trade.dec: .10}, Hc.ok),
  Zone.cen: ZoneInfo('Centro', 2400,
      {Trade.ele: .20, Trade.fon: .15, Trade.alb: .15, Trade.car: .15, Trade.dec: .35}, Hc.acc),
  Zone.res: ZoneInfo('Residencial alto', 3000,
      {Trade.ele: .25, Trade.fon: .15, Trade.alb: .15, Trade.car: .20, Trade.dec: .25},
      Color(0xFFB98AD6)),
};

/// Cuota de visitas (compradores y candidatos a inquilino) de cada sector según la zona. Suma 1.
const zoneShares = <Zone, Map<Sector, double>>{
  Zone.uni: {Sector.est: 0.60, Sector.fam: 0.15, Sector.may: 0.15, Sector.eje: 0.10},
  Zone.fam: {Sector.est: 0.10, Sector.fam: 0.55, Sector.may: 0.25, Sector.eje: 0.10},
  Zone.cen: {Sector.est: 0.25, Sector.fam: 0.15, Sector.may: 0.20, Sector.eje: 0.40},
  Zone.res: {Sector.est: 0.05, Sector.fam: 0.35, Sector.may: 0.20, Sector.eje: 0.40},
};

/// Techo de pago de cada sector en $/m²: por buena que sea la reforma, no paga más.
const sectorCeiling = <Sector, double>{
  Sector.est: 1300,
  Sector.fam: 2200,
  Sector.may: 2400,
  Sector.eje: 4000,
};

/// Ajuste de la renta que acepta cada perfil (los mayores pagan algo menos; los ejecutivos, más).
const sectorRentFactor = <Sector, double>{
  Sector.est: 1.0,
  Sector.fam: 1.0,
  Sector.may: 0.92,
  Sector.eje: 1.10,
};

/// Perfil con más cuota en una zona (sin ajustes de barrio).
Sector bestSector(Zone z) => zoneShares[z]!.entries.reduce((a, b) => b.value > a.value ? b : a).key;

/// Rasgos fijos de una vivienda: no se reforman y cambian lo que paga cada perfil.
enum Trait { sinAscensor, ruido, terraza, parking, vistas }

class TraitInfo {
  final String name;
  final String desc;
  final IconData icon;
  final bool good;
  /// Multiplicador de lo que paga cada sector.
  final Map<Sector, double> mult;
  const TraitInfo(this.name, this.desc, this.icon, this.good, this.mult);
}

const traitInfo = <Trait, TraitInfo>{
  Trait.sinAscensor: TraitInfo('Sin ascensor', 'Los mayores la descartan casi siempre', Icons.stairs_outlined, false,
      {Sector.est: 1.0, Sector.fam: 0.95, Sector.may: 0.70, Sector.eje: 0.95}),
  Trait.ruido: TraitInfo('Calle con ruido', 'Bares y tráfico: a los estudiantes les da igual', Icons.volume_up_outlined, false,
      {Sector.est: 1.0, Sector.fam: 0.90, Sector.may: 0.80, Sector.eje: 0.95}),
  Trait.terraza: TraitInfo('Terraza', 'Familias y ejecutivos pagan más', Icons.deck_outlined, true,
      {Sector.est: 1.03, Sector.fam: 1.10, Sector.may: 1.05, Sector.eje: 1.10}),
  Trait.parking: TraitInfo('Plaza de parking', 'Suma para familias y ejecutivos', Icons.local_parking_outlined, true,
      {Sector.est: 1.0, Sector.fam: 1.05, Sector.may: 1.02, Sector.eje: 1.05}),
  Trait.vistas: TraitInfo('Vistas al agua', 'Mar, río o lago: todos pagan más; los ejecutivos, bastante más', Icons.landscape_outlined, true,
      {Sector.est: 1.05, Sector.fam: 1.08, Sector.may: 1.08, Sector.eje: 1.12}),
};

/// Rasgo de la ciudad: cambia el reparto de público y los precios.
enum CityTrait { equilibrada, universitaria, costera, industrial }

class CityTraitInfo {
  final String name;
  final String desc;
  final double price;
  final Map<Sector, double> shareAdd;
  const CityTraitInfo(this.name, this.desc, this.price, this.shareAdd);
}

const cityTraitInfo = <CityTrait, CityTraitInfo>{
  CityTrait.equilibrada: CityTraitInfo('Equilibrada', 'Un poco de todo', 1.0, {}),
  CityTrait.universitaria: CityTraitInfo('Universitaria', 'Más estudiantes en todos los barrios', 0.92,
      {Sector.est: 0.10, Sector.eje: -0.04}),
  CityTrait.costera: CityTraitInfo('Costera turística', 'Precios altos y ejecutivos de segunda residencia', 1.15,
      {Sector.eje: 0.08, Sector.est: -0.04}),
  CityTrait.industrial: CityTraitInfo('Industrial en declive', 'Ruinas baratas, familias y mayores', 0.80,
      {Sector.fam: 0.06, Sector.may: 0.05, Sector.eje: -0.06}),
};

ZoneInfo zi(Zone z) => zoneInfo[z]!;

/// Fases del ciclo de mercado.
enum MarketPhase { crisis, estanc, recup, expan, burbuja }

class PhaseInfo {
  final String name;
  final String short;
  final double m; // precios
  final double ma; // alquileres
  final String play;
  final Color color;
  const PhaseInfo(this.name, this.short, this.m, this.ma, this.play, this.color);
}

const phaseInfo = <MarketPhase, PhaseInfo>{
  MarketPhase.crisis: PhaseInfo('Crisis', 'CRISIS', .70, 1.12, 'Comprar barato, reformar barato y alquilar', Hc.bad),
  MarketPhase.estanc: PhaseInfo('Estancamiento', 'ESTANC.', .85, 1.02, 'Reformar sin prisa', Hc.mut),
  MarketPhase.recup: PhaseInfo('Recuperación', 'RECUP.', .95, .98, 'Rotar inventario', Hc.info),
  MarketPhase.expan: PhaseInfo('Expansión', 'EXPANS.', 1.10, 1.05, 'Crecer y apalancarse', Hc.ok),
  MarketPhase.burbuja: PhaseInfo('Burbuja', 'BURBUJA', 1.35, 1.18, 'Vender antes del pinchazo', Hc.acc),
};

PhaseInfo mph(MarketPhase p) => phaseInfo[p]!;

/// Tipologías de vivienda.
enum Kind { estudio, piso, familiar, atico }

class KindInfo {
  final String name;
  final int m2;
  const KindInfo(this.name, this.m2);
}

const kindInfo = <Kind, KindInfo>{
  Kind.estudio: KindInfo('Estudio', 30),
  Kind.piso: KindInfo('Piso pequeño', 50),
  Kind.familiar: KindInfo('Piso familiar', 80),
  Kind.atico: KindInfo('Ático', 120),
};

/// Tipos de inquilino.
enum TenantType { puntual, despistado, problematico, ejemplar }

const tenantNames = {
  TenantType.puntual: 'Puntual',
  TenantType.despistado: 'Despistado',
  TenantType.problematico: 'Problemático',
  TenantType.ejemplar: 'Ejemplar',
};

const tenantDesc = {
  TenantType.puntual: 'Paga el día 1. Sin sorpresas.',
  TenantType.despistado: 'Paga, pero con retraso. A veces mucho.',
  TenantType.problematico: 'Impagos y desperfectos frecuentes.',
  TenantType.ejemplar: 'Acepta rentas altas y cuida la vivienda.',
};

/// Fases de progreso del jugador.
enum Stage { manitas, casero, empresa, promotor, prestigio }

class StageInfo {
  final String name;
  final String unlock;
  final String adds;
  final List<String> novelties;
  const StageInfo(this.name, this.unlock, this.adds, this.novelties);
}

const stageInfo = <Stage, StageInfo>{
  Stage.manitas: StageInfo('Manitas', 'Inicio de la partida', 'Reforma manual por toques, una obra a la vez',
      ['Reformar tocando', 'Energía, combo y críticos']),
  Stage.casero: StageInfo('Casero', 'Primera reforma terminada',
      'Alquiler y venta, precio, ciclos de mercado, inquilinos y formación de oficios', [
    'Alquilar o vender cada vivienda',
    'El mercado y sus ciclos',
    'Formación de oficios',
    'Comprar más ruinas',
  ]),
  Stage.empresa: StageInfo('Empresa de reformas', 'Tres reformas terminadas',
      'Cuadrillas automáticas, hipotecas y progreso sin conexión', [
    'Cuadrillas que reforman solas',
    'Hipotecas hasta el 70 %',
    'Plantillas de reforma',
    'Progreso sin conexión (8 h)',
  ]),
  Stage.promotor: StageInfo('Promotor', 'Patrimonio de \$500.000',
      'Edificios, calles y barrios enteros, efecto barrio y nuevas ciudades', [
    'Edificios enteros por lotes',
    'Efecto barrio: +2 % por vivienda de la calle',
    'Servicios: parque, colegio, metro',
    'Gestoría automática',
  ]),
  Stage.prestigio: StageInfo('Prestigio', 'Patrimonio de \$5.000.000',
      'Nueva ciudad: reinicio con reputación y bonus permanentes', [
    'Fundar una nueva ciudad',
    'Reputación permanente',
    '+3 % de obra y alquiler por punto',
  ]),
};

/// Servicios de barrio (fase 4).
enum Service { parque, colegio, metro }

const serviceNames = {Service.parque: 'Parque', Service.colegio: 'Colegio', Service.metro: 'Metro'};
const serviceIcons = {
  Service.parque: Icons.park_outlined,
  Service.colegio: Icons.school_outlined,
  Service.metro: Icons.subway_outlined,
};
