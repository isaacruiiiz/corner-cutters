// Capturas de los tableros nuevos (no forma parte de `flutter test`):
//   flutter test tool/capturas/tableros_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  setUpAll(_fonts);
  Furniture f(String id) => kFurniture.firstWhere((x) => x.id == id);
  testWidgets('montar mesa', (t) => _shot(t, 'montar_mesa', AssembleBoard(progress: 0.47, onWork: _ok, item: f('mesa'))));
  testWidgets('montar aparador', (t) => _shot(t, 'montar_aparador', AssembleBoard(progress: 0.66, onWork: _ok, item: f('aparador'), era: '1929')));
  testWidgets('montar armario', (t) => _shot(t, 'montar_armario', AssembleBoard(progress: 1, onWork: _ok, item: f('armario'))));
  testWidgets('empapelar bajando', (t) => _shot(t, 'empapelar_1', WallpaperBoard(progress: 0.42, onWork: _ok, pattern: kPapers[1])));
  testWidgets('empapelar burbujas', (t) => _shot(t, 'empapelar_2', WallpaperBoard(progress: 0.62, onWork: _ok, pattern: kPapers[3])));
  testWidgets('pintar', (t) => _shot(t, 'pintar', RollerBoard(progress: 0.67, onWork: _ok, paint: kPaints[0])));
}
