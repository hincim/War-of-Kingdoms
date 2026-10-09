import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warcraft/game/data.dart';
import 'package:warcraft/game/entities.dart';
import 'package:warcraft/main.dart';
import 'package:warcraft/ui/controller.dart';
import 'package:warcraft/ui/game_screen.dart';
import 'package:warcraft/ui/mobile_hud.dart';

Future<void> run(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<GameController> startPhone(WidgetTester tester, {Faction faction = humanFaction}) async {
  // iPhone yatay: 852x393 mantıksal piksel, çentik ve ana sayfa çubuğu güvenli alanları.
  tester.view.physicalSize = const Size(852 * 3, 393 * 3);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(left: 59 * 3, right: 59 * 3, bottom: 21 * 3);
  addTearDown(tester.view.reset);
  late GameController c;
  await tester.pumpWidget(MaterialApp(
    home: GameScreen(faction: faction, difficulty: Difficulty.normal, seed: 3, onReady: (x) => c = x),
  ));
  await run(tester, 10);
  return c;
}

void main() {
  testWidgets('telefonda dokunmatik oynanış', (tester) async {
    GameController.hintShownThisSession = false;
    final c = await startPhone(tester);
    final g = c.game;
    expect(c.touch, isTrue, reason: 'telefon boyutunda mobil arayüz açılmalı');
    expect(find.text('Ordu'), findsOneWidget);
    // İlk oyunda kontrol ipucu bir kez görünür
    expect(c.showHint, isTrue);
    expect(find.textContaining('Basılı tut + sürükle'), findsOneWidget);

    // Tek dokunuşla bir işçi seç
    final workers = g.units.where((u) => u.owner == kPlayer && u.type.worker).toList();
    final w0 = workers.first;
    await tester.tapAt(c.view.toScreen(w0.x, w0.y - 4));
    await tester.pump();
    expect(c.sel.length, 1);
    expect(c.sel.first.type.worker, isTrue);
    expect(c.showHint, isFalse, reason: 'ilk seçimden sonra ipucu kaybolmalı');

    // Basılı tut + sürükle: kutu seçimi
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final w in workers) {
      final s = c.view.toScreen(w.x, w.y);
      if (s.dx < minX) minX = s.dx;
      if (s.dy < minY) minY = s.dy;
      if (s.dx > maxX) maxX = s.dx;
      if (s.dy > maxY) maxY = s.dy;
    }
    final gesture = await tester.startGesture(Offset(minX - 25, minY - 25));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(Offset((minX + maxX) / 2, (minY + maxY) / 2));
    await tester.pump();
    await gesture.moveTo(Offset(maxX + 25, maxY + 25));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(c.sel.length, workers.length, reason: 'kutu seçimi tüm işçileri seçmeli');

    // Seçiliyken boş yere dokun → hareket
    final hall = g.units.firstWhere((u) => u.owner == kPlayer && u.type.townHall);
    final target = c.view.toScreen(hall.x + 140, hall.y - 40);
    await tester.tapAt(target);
    await tester.pump();
    expect(c.sel.every((u) => u.order == Order.move), isTrue);

    // ✕ ile seçimi kaldır
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pump();
    expect(c.sel, isEmpty);
    await run(tester, 3);
    expect(find.textContaining('Basılı tut + sürükle'), findsNothing, reason: 'ipucu bir daha gösterilmemeli');
    expect(find.byType(MobileInfoStrip), findsNothing, reason: 'seçim yokken alt şerit gizli olmalı');

    // Tek parmakla kaydırma kamerayı hareket ettirir
    final camX = c.view.camX, camY = c.view.camY;
    await tester.dragFrom(const Offset(420, 160), const Offset(-150, -60));
    await tester.pump();
    expect(c.view.camX, greaterThan(camX));
    expect(c.view.camY, greaterThan(camY));

    // İki parmakla yakınlaştırma
    final z0 = c.view.zoom;
    final f1 = await tester.startGesture(const Offset(380, 170));
    final f2 = await tester.startGesture(const Offset(460, 170), pointer: 7);
    await tester.pump();
    for (var i = 1; i <= 5; i++) {
      await f1.moveTo(Offset(380 - i * 12.0, 170));
      await f2.moveTo(Offset(460 + i * 12.0, 170));
      await tester.pump();
    }
    await f1.up();
    await f2.up();
    await tester.pump();
    expect(c.view.zoom, greaterThan(z0));

    // İnşa: işçi seç, B menüsü, çiftlik, ✓ ile onayla
    c.centerOn(hall.x, hall.y);
    c.select([workers.last]);
    await run(tester, 4);
    await tester.tap(find.byIcon(Icons.construction));
    await tester.pump();
    expect(c.cardMode, 'build');
    c.view.placing = ut('h_farm');
    c.view.mouse = c.view.toScreen(hall.x + 32, hall.y + 150);
    await run(tester, 4);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tester.tap(find.byIcon(Icons.check_circle));
    await tester.pump();
    expect(c.view.placing, isNull);
    expect(workers.last.order, Order.build);

    // Ordu düğmesi: henüz ordu yok → mesaj
    await tester.tap(find.text('Ordu'));
    await tester.pump();
    expect(g.messages.any((m) => m.text.contains('askeri')), isTrue);

    // Menü açılır ve kısa ekrana sığar
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    expect(find.text('OYUN MENÜSÜ'), findsOneWidget);
    await tester.tap(find.text('Nasıl Oynanır'));
    await run(tester, 8);
    expect(find.text('NASIL OYNANIR'), findsOneWidget);
    expect(find.text('Dokunmatik kontroller'), findsOneWidget);
    await tester.tap(find.byTooltip('Kapat'));
    await run(tester, 8);
    expect(find.text('NASIL OYNANIR'), findsNothing);
    await tester.tap(find.text('Oyuna Dön'));
    await tester.pump();
    expect(c.menuOpen, isFalse);
    await run(tester, 40);
  });

  testWidgets('telefonda kahraman ve bina seçimi taşmadan çiziliyor', (tester) async {
    final c = await startPhone(tester, faction: orcFaction);
    final g = c.game;
    final hero = g.spawnUnit('o_farseer', kPlayer, 400, 2000);
    hero.inv[0] = itemTypes['potionHeal'];
    hero.inv[2] = itemTypes['ring'];
    hero.level = 3;
    hero.skillPoints = 2;
    c.select([hero]);
    await run(tester, 4);
    c.cardMode = 'learn';
    await run(tester, 4);
    final hall = g.units.firstWhere((u) => u.owner == kPlayer && u.type.townHall);
    g.cmdTrain(hall, 'o_worker');
    g.cmdTrain(hall, 'o_worker');
    c.select([hall]);
    await run(tester, 4);
    c.select(g.units.where((u) => u.owner == kPlayer && !u.isBuilding).toList());
    await run(tester, 4);
    final mine = g.units.firstWhere((u) => u.isMine);
    c.select([mine]);
    await run(tester, 4);
  });

  testWidgets('ana menü telefonda tek ekrana sığıyor, Nasıl Oynanır açılıyor', (tester) async {
    tester.view.physicalSize = const Size(852 * 3, 393 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(left: 59 * 3, right: 59 * 3, bottom: 21 * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const KingdomsApp());
    await tester.pump();
    final start = tester.getRect(find.text('SAVAŞA BAŞLA'));
    expect(start.bottom, lessThan(393), reason: 'başlat düğmesi kaydırmadan görünmeli');
    await tester.ensureVisible(find.text('Nasıl Oynanır'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nasıl Oynanır'));
    await tester.pumpAndSettle();
    expect(find.text('NASIL OYNANIR'), findsOneWidget);
    expect(find.text('Dokunmatik kontroller'), findsOneWidget);
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
  });
}
