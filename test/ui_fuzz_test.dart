import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:warcraft/game/data.dart';
import 'package:warcraft/game/game.dart';
import 'package:warcraft/ui/controller.dart';

void main() {
  for (final f in [humanFaction, orcFaction]) {
    test('komut kartı bulanık testi (${f.id})', () {
      final g = Game(playerFaction: f, seed: 11, autoPlayer: true, difficulty: Difficulty.normal);
      final c = GameController(g);
      c.screen = const Size(1440, 900);
      final rnd = Random(5);
      var pressed = 0;
      var t = 0.0;
      while (t < 900 && g.winner == null) {
        g.update(0.05);
        t += 0.05;
        c.pruneSelection();
        if ((t * 20).round() % 60 != 0) continue;
        final mine = g.units.where((u) => u.owner == kPlayer).toList();
        if (mine.isEmpty) break;
        // Rastgele seçim: tek birim, aynı tür, ya da karışık grup
        final pick = mine[rnd.nextInt(mine.length)];
        switch (rnd.nextInt(3)) {
          case 0:
            c.select([pick]);
          case 1:
            c.select(mine.where((u) => u.type == pick.type).toList());
          default:
            c.select(mine.where((u) => !u.isBuilding).take(8).toList());
        }
        if (pick.isHero && pick.skillPoints > 0) c.cardMode = 'learn';
        for (var round = 0; round < 2; round++) {
          final card = c.commandCard();
          final cmds = card.whereType<Cmd>().toList();
          if (cmds.isEmpty) break;
          final cmd = cmds[rnd.nextInt(cmds.length)];
          cmd.onTap();
          pressed++;
          final w = Offset(rnd.nextDouble() * kMapPx, rnd.nextDouble() * kMapPx);
          if (c.view.placing != null || c.view.targeting != null) {
            c.leftClickWorld(w, shift: rnd.nextBool());
          }
        }
        c.view.mouse = Offset(rnd.nextDouble() * 1440, rnd.nextDouble() * 700);
        if (rnd.nextInt(4) == 0) c.rightClickWorld(Offset(rnd.nextDouble() * kMapPx, rnd.nextDouble() * kMapPx));
        if (rnd.nextInt(6) == 0) c.escape();
        if (rnd.nextInt(5) == 0) c.boxSelect(Rect.fromCenter(center: Offset(pick.x, pick.y), width: 300, height: 300));
        if (rnd.nextInt(8) == 0) c.setGroup(rnd.nextInt(10));
        if (rnd.nextInt(8) == 0) c.recallGroup(rnd.nextInt(10));
        if (rnd.nextInt(10) == 0) c.selectIdleWorker();
        if (rnd.nextInt(10) == 0) c.selectHero(rnd.nextInt(2));
        for (final key in ['Q', 'W', 'E', 'A', 'S', 'B', 'P', 'O', 'G']) {
          if (rnd.nextInt(12) == 0) c.hotkey(key);
        }
        c.zoomAt(const Offset(700, 400), rnd.nextBool() ? 1.1 : 0.9);
        final h = mine.where((u) => u.isHero).toList();
        if (h.isNotEmpty) {
          final hero = h.first;
          for (var s = 0; s < 6; s++) {
            if (hero.inv[s] != null && rnd.nextInt(6) == 0) g.cmdUseItem(hero, s);
          }
        }
      }
      // ignore: avoid_print
      print('${f.id}: t=${t.round()} winner=${g.winner} pressed=$pressed units=${g.units.length}');
      expect(pressed, greaterThan(100));
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
