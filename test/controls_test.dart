import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warcraft/game/data.dart';
import 'package:warcraft/game/entities.dart';
import 'package:warcraft/ui/controller.dart';
import 'package:warcraft/ui/game_screen.dart';

Future<void> run(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> leftDrag(WidgetTester tester, Offset a, Offset b) async {
  final g = await tester.startGesture(a, kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
  await g.moveTo((a + b) / 2);
  await g.moveTo(b);
  await g.up();
  await tester.pump();
}

Future<void> click(WidgetTester tester, Offset p, {int buttons = kPrimaryMouseButton}) async {
  final g = await tester.startGesture(p, kind: PointerDeviceKind.mouse, buttons: buttons);
  await g.up();
  await tester.pump();
}

void main() {
  testWidgets('fare ve klavye ile temel oynanış', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    late GameController c;
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(faction: humanFaction, difficulty: Difficulty.normal, seed: 3, onReady: (x) => c = x),
    ));
    await run(tester, 20);
    final g = c.game;

    // Tüm işçileri kutu seçimiyle seç
    final workers = g.units.where((u) => u.owner == kPlayer && u.type.worker).toList();
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final w in workers) {
      final s = c.view.toScreen(w.x, w.y);
      minX = s.dx < minX ? s.dx : minX;
      minY = s.dy < minY ? s.dy : minY;
      maxX = s.dx > maxX ? s.dx : maxX;
      maxY = s.dy > maxY ? s.dy : maxY;
    }
    await leftDrag(tester, Offset(minX - 30, minY - 30), Offset(maxX + 30, maxY + 30));
    expect(c.sel.length, workers.length, reason: 'kutu seçimi tüm işçileri seçmeli');

    // B → F: çiftlik yerleştirme modu
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    expect(c.cardMode, 'build');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    expect(c.view.placing?.id, 'h_farm');
    // Ana binanın güneyine yerleştir
    final hall = g.units.firstWhere((u) => u.owner == kPlayer && u.type.townHall);
    final spot = c.view.toScreen(hall.x + 32, hall.y + 150);
    await click(tester, spot);
    expect(c.view.placing, isNull);
    expect(c.sel.first.order, Order.build);
    await run(tester, 200);
    expect(g.units.any((u) => u.type.id == 'h_farm'), isTrue, reason: 'çiftlik inşaatı başlamalı');

    // Ana binayı tıkla, P ile işçi üret
    await click(tester, c.view.toScreen(hall.x, hall.y));
    expect(c.sel.single, hall);
    final goldBefore = g.me.gold;
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    expect(hall.queue.length, 1);
    expect(g.me.gold, goldBefore - 75);

    // Sağ tık ile toplanma noktası
    await click(tester, c.view.toScreen(hall.x + 200, hall.y + 60), buttons: kSecondaryMouseButton);
    expect(hall.rallyX, isNotNull);

    // Ctrl+1 grup atama ve geri çağırma
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await click(tester, c.view.toScreen(hall.x + 300, hall.y + 120));
    expect(c.sel, isEmpty, reason: 'seçili: ${c.sel.map((u) => '${u.type.id}@${u.x.round()},${u.y.round()} ekran=${c.view.toScreen(u.x, u.y)}').join(';')} tık=${c.view.toScreen(hall.x + 300, hall.y + 120)}');
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    expect(c.sel.single, hall);

    // Bir işçiyle sağ tık → hareket
    final w = workers.last;
    c.select([w]);
    final target = c.view.toScreen(hall.x + 120, hall.y + 220);
    await click(tester, target, buttons: kSecondaryMouseButton);
    expect(w.order, Order.move);
    await run(tester, 80);
    final tw = c.view.toWorld(target);
    expect((Offset(w.x, w.y) - tw).distance, lessThan(40));

    // Esc: menü
    c.select([]);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(c.menuOpen, isTrue);
    expect(find.text('OYUN MENÜSÜ'), findsOneWidget);
    await tester.tap(find.text('Oyuna Dön'));
    await tester.pump();
    expect(c.menuOpen, isFalse);
  });
}
