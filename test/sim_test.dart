import 'package:flutter_test/flutter_test.dart';
import 'package:warcraft/game/data.dart';
import 'package:warcraft/game/entities.dart';
import 'package:warcraft/game/game.dart';

void main() {
  test('harita simetrik ve üsler birbirine ulaşabiliyor', () {
    final g = Game(playerFaction: humanFaction, seed: 42);
    final m = g.map;
    for (var y = 0; y < kMapH; y++) {
      for (var x = 0; x < kMapW; x++) {
        expect(m.wood[m.idx(x, y)] > 0, m.wood[m.idx(kMapW - 1 - x, kMapH - 1 - y)] > 0);
      }
    }
    final a = startLocs[0], b = startLocs[1];
    final path = m.findPath((a.hallX + 2) * kTile, (a.hallY + 5) * kTile, (b.hallX + 2) * kTile, (b.hallY - 2) * kTile);
    expect(path, isNotEmpty);
    final end = path.last;
    expect((end.dx - (b.hallX + 2) * kTile).abs() < 64, isTrue);
  });

  for (final seed in [1, 7, 123]) {
    test('YZ - YZ simülasyonu çalışıyor (tohum $seed)', () {
      final g = Game(playerFaction: seed.isOdd ? humanFaction : orcFaction, seed: seed, autoPlayer: true, difficulty: Difficulty.hard);
      g.players[0].gatherMult = g.players[1].gatherMult;
      var maxArmy = [0, 0];
      var heroLevels = [0, 0];
      var t = 0.0;
      while (t < 1500 && g.winner == null) {
        g.update(0.05);
        t += 0.05;
        for (var p = 0; p < 2; p++) {
          final army = g.units.where((u) => u.owner == p && !u.isBuilding && !u.type.worker).length;
          if (army > maxArmy[p]) maxArmy[p] = army;
          for (final u in g.units) {
            if (u.owner == p && u.isHero && u.level > heroLevels[p]) heroLevels[p] = u.level;
          }
        }
      }
      final p0 = g.players[0], p1 = g.players[1];
      // ignore: avoid_print
      print('seed=$seed t=${t.toStringAsFixed(0)} winner=${g.winner} '
          'gold=${p0.goldMined}/${p1.goldMined} wood=${p0.lumberMined}/${p1.lumberMined} '
          'trained=${p0.unitsTrained}/${p1.unitsTrained} kills=${p0.kills}/${p1.kills} '
          'maxArmy=$maxArmy heroLv=$heroLevels units=${g.units.length} '
          'creeps=${g.units.where((u) => u.owner == kCreeps).length} '
          'buildings0=${g.units.where((u) => u.owner == 0 && u.isBuilding).map((u) => u.type.id).toList()} '
          'buildings1=${g.units.where((u) => u.owner == 1 && u.isBuilding).map((u) => u.type.id).toList()}');
      expect(p0.goldMined, greaterThan(2000));
      expect(p1.goldMined, greaterThan(2000));
      expect(p0.lumberMined, greaterThan(300));
      expect(maxArmy[0], greaterThan(4));
      expect(maxArmy[1], greaterThan(4));
      expect(heroLevels[0] + heroLevels[1], greaterThan(3));
      final stuckWorkers = g.units.where((u) => u.type.worker && u.order == Order.idle).length;
      expect(stuckWorkers, lessThan(6));
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
