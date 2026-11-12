// Capturas de los tableros nuevos (no forma parte de `flutter test`):
//   flutter test tool/capturas/tableros_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corner_cutters/ui/minigames/boards.dart';
import 'package:corner_cutters/ui/minigames/obras2.dart';

Future<void> _fonts() async {
  final j = FontLoader('Jersey')..addFont(rootBundle.load('assets/fonts/Jersey15-Regular.ttf'));
  final m = FontLoader('Manrope')
    ..addFont(rootBundle.load('assets/fonts/Manrope-800.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Manrope-700.ttf'));
  await j.load();
  await m.load();
}

Future<void> _shot(WidgetTester t, String name, Widget board) async {
  await t.binding.setSurfaceSize(const Size(366, 470));
  await t.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: RepaintBoundary(child: SizedBox(width: 366, height: 470, child: board))),
  ));
  await t.pump(const Duration(milliseconds: 300));
  await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('out/$name.png'));
}

bool _ok(Offset _) => true;

Future<void> _era(WidgetTester t, String name, String era, String trade, Widget board) async {
  await t.binding.setSurfaceSize(const Size(366, 440));
  await t.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: const Color(0xFF0E2221),
      body: RepaintBoundary(child: SizedBox(width: 366, height: 440, child: Padding(padding: const EdgeInsets.all(8), child: BoardFrame(height: 366, era: era, trade: trade, child: board)))),
    ),
  ));
  await t.pump(const Duration(milliseconds: 300));
  await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('out/epocas/$name.png'));
}

void main() {
  setUpAll(_fonts);
  Furniture f(String id) => kFurniture.firstWhere((x) => x.id == id);
  testWidgets('montar mesa', (t) => _shot(t, 'montar_mesa', AssembleBoard(progress: 0.47, onWork: _ok, item: f('mesa'))));
  testWidgets('montar aparador', (t) => _shot(t, 'montar_aparador', AssembleBoard(progress: 0.66, onWork: _ok, item: f('aparador'), era: '1929')));
  testWidgets('montar armario', (t) => _shot(t, 'montar_armario', AssembleBoard(progress: 1, onWork: _ok, item: f('armario'))));
  testWidgets('empapelar bajando', (t) => _shot(t, 'empapelar_1', WallpaperBoard(progress: 0.42, onWork: _ok, pattern: kPapers[1])));
  testWidgets('empapelar burbujas', (t) => _shot(t, 'empapelar_2', WallpaperBoard(progress: 0.62, onWork: _ok, pattern: kPapers[3])));
  testWidgets('pintar', (t) => _shot(t, 'pintar', RollerBoard(progress: 0.67, onWork: _ok, paint: kPaints[0])));

  for (final era in ['1980', '2005', '2020', '2050']) {
    final own = kEraFurniture[era]!.first;
    final paper = kPapers.firstWhere((p) => p.id == {'1980': 'circulos', '2005': 'gotele', '2020': 'tropical', '2050': 'fibra'}[era]);
    testWidgets('$era albañilería', (t) => _era(t, '${era}_1_alb', era, 'alb', BrickBoard(progress: 0.62, onWork: _ok, era: era)));
    testWidgets('$era fontanería', (t) => _era(t, '${era}_2_fon', era, 'fon', PipeBoard(progress: 0.3, onSeal: (_) => true, era: era)));
    testWidgets('$era electricidad', (t) => _era(t, '${era}_3_ele', era, 'ele', WireBoard(progress: 0.2, onWork: _ok, onMiss: () {}, pairs: 4, era: era)));
    testWidgets('$era carpintería', (t) => _era(t, '${era}_4_car', era, 'car', AssembleBoard(progress: 0.8, onWork: _ok, item: own, era: era)));
    testWidgets('$era decoración', (t) => _era(t, '${era}_5_dec', era, 'dec', WallpaperBoard(progress: 0.62, onWork: _ok, pattern: paper)));
  }
}
