import 'dart:math';
import 'dart:ui' show Offset, Rect;

import 'data.dart';
import 'entities.dart';
import 'game.dart';

class _PlanStep {
  const _PlanStep(this.type, this.count, this.minTime, this.minWorkers);
  final String type;
  final int count;
  final double minTime;
  final int minWorkers;
}

/// Bilgisayar rakibi: ekonomi, üretim, kahraman, yaratık avı ve saldırı dalgaları.
class EnemyAI {
  EnemyAI(this.g, this.pid, this.diff) {
    waveSize = switch (diff) {
      Difficulty.easy => 10,
      Difficulty.normal => 8,
      Difficulty.hard => 7,
    };
    firstAttack = switch (diff) {
      Difficulty.easy => 560.0,
      Difficulty.normal => 420.0,
      Difficulty.hard => 300.0,
    };
    targetWorkers = switch (diff) {
      Difficulty.easy => 10,
      Difficulty.normal => 12,
      Difficulty.hard => 14,
    };
    final heroes = f.heroes;
    heroPick = heroes[g.rng.nextInt(heroes.length)];
    _plan = [
      _PlanStep(f.barracks, 1, 0, 5),
      _PlanStep(f.altar, 1, 0, 6),
      _PlanStep(f.smith, 1, diff == Difficulty.hard ? 200 : 260, 8),
      _PlanStep(f.tower, 1, 240, 8),
      _PlanStep(f.barracks, 2, diff == Difficulty.hard ? 280 : 500, 10),
      _PlanStep(f.tower, 2, 480, 10),
    ];
  }

  final Game g;
  final int pid;
  final Difficulty diff;
  late int waveSize;
  late double firstAttack;
  late int targetWorkers;
  late String heroPick;
  late List<_PlanStep> _plan;

  double _t = 0.3;
  String mode = 'build';
  double modeSince = 0;
  int campTarget = -1;
  Unit? attackTarget;
  int attackStartSize = 0;

  Player get p => g.players[pid];
  Faction get f => p.faction!;
  int get foe => pid == kPlayer ? kEnemy : kPlayer;

  void update(double dt) {
    _t -= dt;
    if (_t > 0) return;
    _t = 0.5;
    _think();
  }

  void _setMode(String m) {
    if (mode != m) {
      mode = m;
      modeSince = g.time;
    }
  }

  void _think() {
    final mine = g.units.where((u) => u.owner == pid && !u.dead).toList();
    Unit? hall;
    for (final u in mine) {
      if (u.type.townHall && !u.constructing) {
        hall = u;
        break;
      }
    }
    final workers = mine.where((u) => u.type.worker).toList();
    final army = mine.where((u) => !u.isBuilding && !u.type.worker).toList();
    final heroes = army.where((u) => u.isHero).toList();

    if (hall != null) {
      _economy(mine, workers, hall);
      _production(mine, workers, hall);
    }
    _heroMicro(heroes);
    _military(mine, army, heroes, hall);
  }

  // ------------------------------------------------------------ Ekonomi

  Unit? _mainMine(Unit hall) {
    Unit? best;
    var bd = 700.0;
    for (final m in g.units) {
      if (!m.isMine || m.dead) continue;
      final d = Game.dist(m, hall);
      if (d < bd) {
        bd = d;
        best = m;
      }
    }
    return best;
  }

  int _reservedGold = 0, _reservedLumber = 0;

  int get freeGold => p.gold - _reservedGold;
  int get freeLumber => p.lumber - _reservedLumber;

  List<Unit> _myMines(List<Unit> mine) {
    final halls = mine.where((u) => u.type.townHall && !u.constructing).toList();
    return g.units.where((m) => m.isMine && !m.dead && halls.any((h) => Game.dist(h, m) < 650)).toList();
  }

  void _economy(List<Unit> mine, List<Unit> workers, Unit hall) {
    final mines = _myMines(mine);
    final perMine = <Unit, int>{for (final m in mines) m: 0};
    _reservedGold = 0;
    _reservedLumber = 0;
    for (final w in workers) {
      if (w.order == Order.gather && w.gatherKind == 'gold' && perMine.containsKey(w.mine)) {
        perMine[w.mine!] = perMine[w.mine!]! + 1;
      }
      if (w.order == Order.build && w.buildType != null) {
        _reservedGold += w.buildType!.gold;
        _reservedLumber += w.buildType!.lumber;
      }
    }
    Unit? leastMine() {
      Unit? best;
      var bc = 5;
      perMine.forEach((m, c) {
        if (c < bc) {
          bc = c;
          best = m;
        }
      });
      return best;
    }

    for (final w in workers) {
      if (w.order != Order.idle) continue;
      final m = leastMine();
      if (m != null) {
        g.cmdGatherGold(w, m);
        perMine[m] = perMine[m]! + 1;
      } else {
        final h = g.nearestHall(w) ?? hall;
        final t = g.map.nearestTree(h.x, h.y, 20);
        if (t != null) {
          g.cmdGatherWood(w, t.x, t.y);
        } else if (mines.isNotEmpty) {
          g.cmdGatherGold(w, mines.first);
        }
      }
    }
    // Fazla altın işçisini oduna kaydır.
    for (final m in mines) {
      if (perMine[m]! <= 6) continue;
      for (final w in workers) {
        if (w.order == Order.gather && w.gatherKind == 'gold' && w.mine == m && w.gatherPhase == 0 && !w.hidden) {
          final t = g.map.nearestTree(w.x, w.y, 20);
          if (t != null) g.cmdGatherWood(w, t.x, t.y);
          break;
        }
      }
    }
    var queuedWorkers = 0;
    for (final q in hall.queue) {
      if (q.kind == 'unit' && q.unitType!.worker) queuedWorkers++;
    }
    final want = min(targetWorkers + 5, targetWorkers + (mines.length - 1) * 5);
    if (workers.length + queuedWorkers < want && hall.queue.length < 2 && freeGold >= 75) {
      g.cmdTrain(hall, f.worker);
    }
  }

  /// Ana maden azalınca en yakın boş madene yeni ana bina kurar.
  bool _expand(List<Unit> mine, List<Unit> workers, Unit hall) {
    final mines = _myMines(mine);
    final left = mines.fold<int>(0, (s, m) => s + m.goldLeft);
    if (left > 4500 && g.time < 900) return false;
    if (_count(mine, workers, f.hall) >= 1 + mines.length.clamp(0, 1) && mines.isNotEmpty) return false;
    Unit? target;
    var bd = double.infinity;
    for (final m in g.units) {
      if (!m.isMine || m.dead || mines.contains(m) || m.goldLeft < 2000) continue;
      if (g.units.any((u) => u.type.townHall && Game.dist(u, m) < 650)) continue;
      if (g.units.any((u) => u.owner == kCreeps && Game.dist(u, m) < 450)) continue;
      final d = Game.dist(m, hall);
      if (d < bd) {
        bd = d;
        target = m;
      }
    }
    if (target == null) return false;
    final t = ut(f.hall);
    if (freeGold < t.gold || freeLumber < t.lumber) return true;
    final builder = _pickBuilder(workers);
    if (builder == null) return false;
    final spot = g.findBuildSpot(pid, t, target.x, target.y, minR: 4, maxR: 9);
    if (spot == null) return false;
    if (g.cmdBuild(builder, t, spot.x, spot.y)) {
      _reservedGold += t.gold;
      _reservedLumber += t.lumber;
    }
    return true;
  }

  int _count(List<Unit> mine, List<Unit> workers, String typeId) {
    var n = 0;
    for (final u in mine) {
      if (u.type.id == typeId) n++;
    }
    for (final w in workers) {
      if (w.order == Order.build && w.buildType?.id == typeId) n++;
    }
    return n;
  }

  Unit? _pickBuilder(List<Unit> workers) {
    Unit? best;
    for (final w in workers) {
      if (w.order == Order.build || w.order == Order.construct || w.hidden) continue;
      if (w.carryGold > 0) continue;
      if (w.order == Order.gather && w.gatherKind == 'wood') return w;
      best ??= w;
    }
    return best;
  }

  bool _tryBuild(String typeId, List<Unit> workers, Unit hall) {
    final t = ut(typeId);
    if (freeGold < t.gold || freeLumber < t.lumber) return false;
    final builder = _pickBuilder(workers);
    if (builder == null) return false;
    final gm = _mainMine(hall);
    Rect? avoid;
    if (gm != null) {
      avoid = Rect.fromPoints(Offset(hall.x, hall.y), Offset(gm.x, gm.y)).inflate(56);
    }
    final center = const Offset(kMapPx / 2, kMapPx / 2);
    final dir = (center - Offset(hall.x, hall.y));
    final dn = dir / dir.distance;
    final spot = typeId == f.tower
        ? g.findBuildSpot(pid, t, hall.x + dn.dx * 260, hall.y + dn.dy * 260, minR: 0, maxR: 7, avoid: avoid)
        : g.findBuildSpot(pid, t, hall.x, hall.y, minR: 4, maxR: 15, avoid: avoid);
    if (spot == null) return false;
    final ok = g.cmdBuild(builder, t, spot.x, spot.y);
    if (ok) {
      _reservedGold += t.gold;
      _reservedLumber += t.lumber;
    }
    return ok;
  }

  // ------------------------------------------------------------ Üretim

  void _production(List<Unit> mine, List<Unit> workers, Unit hall) {
    var saving = false;
    // Çiftlik
    final farmPending = mine.any((u) => u.type.id == f.farm && u.constructing) ||
        workers.any((w) => w.order == Order.build && w.buildType?.id == f.farm);
    final barracksN = _count(mine, workers, f.barracks);
    if (!farmPending && p.foodCap < 100 && p.foodCap - p.foodUsed <= 4 + barracksN * 2) {
      if (!_tryBuild(f.farm, workers, hall)) saving = true;
    }
    if (_expand(mine, workers, hall)) saving = true;
    // Yapı planı
    for (final s in _plan) {
      if (_count(mine, workers, s.type) >= s.count) continue;
      if (g.time < s.minTime || workers.length < s.minWorkers) break;
      if (!_tryBuild(s.type, workers, hall)) saving = true;
      break;
    }
    // Kahramanlar
    Unit? altar;
    for (final u in mine) {
      if (u.type.altar && !u.constructing) altar = u;
    }
    if (altar != null && altar.queue.isEmpty) {
      final hc = g.heroCount(pid);
      if (p.deadHeroes.isNotEmpty) {
        if (!g.cmdRevive(altar, p.deadHeroes.first)) saving = true;
      } else if (hc == 0) {
        if (!g.cmdTrain(altar, heroPick)) saving = true;
      } else if (hc < kMaxHeroes && diff != Difficulty.easy && g.time > 600 && freeGold > 700) {
        final other = f.heroes.firstWhere((h) => !g.hasHeroType(pid, h), orElse: () => heroPick);
        g.cmdTrain(altar, other);
      }
    }
    // Ordu
    final hasSmith = mine.any((u) => u.type.id == f.smith && !u.constructing);
    for (final b in mine) {
      if (b.type.id != f.barracks || b.constructing || b.queue.length >= 2) continue;
      if (saving && freeGold < 450) continue;
      final r = g.rng.nextDouble();
      String pick;
      if (hasSmith && r < 0.22) {
        pick = f.cavalry;
      } else if (r < 0.62) {
        pick = f.melee;
      } else {
        pick = f.ranged;
      }
      final t = ut(pick);
      if (freeGold >= t.gold && freeLumber >= t.lumber) g.cmdTrain(b, pick);
    }
    // Geliştirmeler
    for (final b in mine) {
      if (b.type.id != f.smith || b.constructing || b.queue.isNotEmpty) continue;
      if (freeGold < 350 || freeLumber < 200) continue;
      final w = p.upgrade('weapons'), a = p.upgrade('armor');
      if (w <= a && w < 2) {
        g.cmdResearch(b, 'weapons');
      } else if (a < 2) {
        g.cmdResearch(b, 'armor');
      }
    }
  }

  // ------------------------------------------------------------ Kahraman

  void _heroMicro(List<Unit> heroes) {
    for (final h in heroes) {
      while (h.skillPoints > 0) {
        String? best;
        var bestLvl = 99;
        for (final aid in h.type.abilities) {
          if (!g.canLearn(h, aid)) continue;
          final l = h.abilityLevel(aid);
          if (l < bestLvl) {
            bestLvl = l;
            best = aid;
          }
        }
        if (best == null) break;
        g.cmdLearn(h, best);
      }
      if (h.hp < h.maxHp * 0.35) {
        final s = h.inv.indexWhere((i) => i?.id == 'potionHeal');
        if (s >= 0) g.cmdUseItem(h, s);
      }
      if (h.mana < 60) {
        final s = h.inv.indexWhere((i) => i?.id == 'potionMana');
        if (s >= 0) g.cmdUseItem(h, s);
      }
      if (h.order == Order.cast || h.stun > 0) continue;
      _autoCast(h);
      if (h.order == Order.idle || (h.order == Order.attackMove && h.engaged == null)) {
        GroundItem? best;
        var bd = 450.0;
        final hasSlot = h.inv.any((i) => i == null);
        for (final it in g.items) {
          if (it.taken || (!hasSlot && !it.type.onPickup)) continue;
          final d = Game.distPt(h, it.x, it.y);
          if (d < bd) {
            bd = d;
            best = it;
          }
        }
        if (best != null && _enemiesNear(h.x, h.y, 350, pid).isEmpty) g.cmdPickup(h, best);
      }
    }
  }

  List<Unit> _enemiesNear(double x, double y, double r, int owner) {
    final out = <Unit>[];
    for (final e in g.units) {
      if (e.dead || e.hidden || e.isMine || !g.isEnemy(owner, e.owner)) continue;
      if ((e.x - x).abs() > r || (e.y - y).abs() > r) continue;
      if (sqrt((e.x - x) * (e.x - x) + (e.y - y) * (e.y - y)) - e.radius <= r) out.add(e);
    }
    return out;
  }

  void _autoCast(Unit h) {
    for (final aid in h.type.abilities) {
      final a = abilityTypes[aid]!;
      final lvl = h.abilityLevel(aid);
      if (lvl == 0 || a.passive) continue;
      if (h.cooldownLeft(aid) > 0 || h.mana < a.mana[lvl - 1]) continue;
      final v1 = a.v1[lvl - 1];
      switch (aid) {
        case 'holyLight':
        case 'healingWave':
          Unit? best;
          var worst = 0.55;
          for (final u in g.units) {
            if (u.owner != pid || u.dead || u.isBuilding || u.hidden) continue;
            if (Game.dist(u, h) > a.range + 120) continue;
            final ratio = u.hp / u.maxHp;
            if (ratio < worst && u.maxHp - u.hp > v1 * 0.5) {
              worst = ratio;
              best = u;
            }
          }
          if (best != null && g.cmdCast(h, aid, target: best)) return;
        case 'stormBolt':
        case 'chainLightning':
          final es = _enemiesNear(h.x, h.y, a.range + 60, pid).where((e) => !e.isBuilding).toList();
          if (es.isEmpty) continue;
          es.sort((x, y) {
            if (x.isHero != y.isHero) return x.isHero ? -1 : 1;
            return y.hp.compareTo(x.hp);
          });
          if (g.cmdCast(h, aid, target: es.first)) return;
        case 'warStomp':
          final es = _enemiesNear(h.x, h.y, a.radius - 10, pid).where((e) => !e.isBuilding).toList();
          if (es.length >= 2 || es.any((e) => e.isHero)) {
            if (g.cmdCast(h, aid)) return;
          }
        case 'blizzard':
          final es = _enemiesNear(h.x, h.y, a.range + 40, pid).where((e) => !e.isBuilding).toList();
          for (final e in es) {
            final n = es.where((o) => Game.dist(o, e) < a.radius).length;
            if (n >= 3) {
              if (g.cmdCast(h, aid, x: e.x, y: e.y)) return;
              break;
            }
          }
        case 'shockwave':
          final es = _enemiesNear(h.x, h.y, 260, pid).where((e) => !e.isBuilding).toList();
          if (es.length >= 2) {
            if (g.cmdCast(h, aid, x: es.first.x, y: es.first.y)) return;
          }
        case 'waterElemental':
        case 'feralSpirit':
          if (_enemiesNear(h.x, h.y, 420, pid).where((e) => !e.isBuilding).isNotEmpty) {
            if (g.cmdCast(h, aid)) return;
          }
      }
    }
  }

  // ------------------------------------------------------------ Askeri

  Offset _rally(Unit? hall) {
    if (hall == null) return const Offset(kMapPx / 2, kMapPx / 2);
    final center = const Offset(kMapPx / 2, kMapPx / 2);
    final dir = center - Offset(hall.x, hall.y);
    return Offset(hall.x, hall.y) + dir / dir.distance * 230;
  }

  double _power(List<Unit> army) {
    var s = 0.0;
    for (final u in army) {
      s += u.isHero ? 3 + u.level * 2 : (u.type.summon ? 2 : u.type.food.toDouble());
    }
    return s;
  }

  double _campPower(int c) {
    var s = 0.0;
    for (final u in g.units) {
      if (u.camp == c && !u.dead) s += u.type.level * 1.25 + (u.type.id == 'c_dragon' ? 6 : 0);
    }
    return s;
  }

  void _orderGroup(List<Unit> group, double x, double y) {
    final todo = <Unit>[];
    for (final a in group) {
      if (a.order == Order.cast || a.order == Order.pickup) continue;
      if (a.order == Order.attackMove && (a.tx - x).abs() < 200 && (a.ty - y).abs() < 200) continue;
      if (a.order == Order.attack && Game.valid(a.target)) continue;
      todo.add(a);
    }
    if (todo.isNotEmpty) g.cmdMove(todo, x, y, attack: true, pid: pid);
  }

  void _military(List<Unit> mine, List<Unit> army, List<Unit> heroes, Unit? hall) {
    if (army.isEmpty) return;
    final home = _rally(hall);

    // Düşük canlı kahramanı geri çek.
    final active = <Unit>[];
    for (final a in army) {
      if (a.isHero && a.hp < a.maxHp * 0.3 && !a.inv.any((i) => i?.id == 'potionHeal')) {
        if (a.order != Order.move && hall != null) g.cmdMove([a], home.dx, home.dy, pid: pid);
        continue;
      }
      if (a.isHero && a.order == Order.move && a.hp < a.maxHp * 0.75 && hall != null) continue;
      active.add(a);
    }

    // Savunma
    Unit? threat;
    for (final b in mine) {
      if (!b.isBuilding) continue;
      for (final e in _enemiesNear(b.x, b.y, 520, pid)) {
        if (e.owner == kCreeps || e.isBuilding) continue;
        threat = e;
        break;
      }
      if (threat != null) break;
    }
    if (threat != null) {
      _setMode('defend');
      _orderGroup(active, threat.x, threat.y);
      return;
    }
    if (mode == 'defend') _setMode('build');

    if (mode == 'attack') {
      if (active.length <= max(2, (attackStartSize * 0.3).round())) {
        _setMode('retreat');
        g.cmdMove(active, home.dx, home.dy, pid: pid);
        return;
      }
      if (!Game.valid(attackTarget)) attackTarget = _pickAttackTarget(active);
      final t = attackTarget;
      if (t == null) return;
      _orderGroup(active, t.x, t.y);
      return;
    }
    if (mode == 'retreat') {
      if (g.time - modeSince > 25 || active.every((a) => Game.distPt(a, home.dx, home.dy) < 400)) {
        _setMode('build');
      }
      return;
    }

    final soldiers = active.where((a) => !a.isHero && !a.type.summon).length;
    if (soldiers + (heroes.isNotEmpty ? 1 : 0) >= waveSize && g.time >= firstAttack) {
      _setMode('attack');
      attackStartSize = active.length;
      waveSize = min(waveSize + 3, 26);
      attackTarget = _pickAttackTarget(active);
      if (attackTarget != null) _orderGroup(active, attackTarget!.x, attackTarget!.y);
      return;
    }

    final hero = heroes.isNotEmpty ? heroes.first : null;
    if (hero != null && soldiers >= 2 && hero.hp > hero.maxHp * 0.55) {
      if (campTarget < 0 || !g.units.any((u) => u.camp == campTarget && !u.dead)) {
        campTarget = _pickCamp(active, hall);
      }
      if (campTarget >= 0) {
        _setMode('creep');
        final c = campDefs[campTarget];
        _orderGroup(active, c.x * kTile, c.y * kTile);
        return;
      }
    } else if (mode == 'creep' && hero != null && hero.hp < hero.maxHp * 0.35) {
      _setMode('retreat');
      g.cmdMove(active, home.dx, home.dy, pid: pid);
      return;
    }
    _setMode('build');
    // Boştaki orduyu toplanma noktasına götür.
    final idle = active.where((a) => a.order == Order.idle && Game.distPt(a, home.dx, home.dy) > 220).toList();
    if (idle.isNotEmpty) g.cmdMove(idle, home.dx, home.dy, attack: true, pid: pid);
  }

  int _pickCamp(List<Unit> army, Unit? hall) {
    final power = _power(army);
    var best = -1;
    var bd = double.infinity;
    final ox = hall?.x ?? army.first.x, oy = hall?.y ?? army.first.y;
    for (var c = 0; c < campDefs.length; c++) {
      final cp = _campPower(c);
      if (cp <= 0 || cp * 1.4 > power) continue;
      final d = sqrt(pow(campDefs[c].x * kTile - ox, 2) + pow(campDefs[c].y * kTile - oy, 2));
      // Rakip üssünün dibindeki kampları sona bırak.
      var penalty = 0.0;
      for (final b in g.units) {
        if (b.owner == foe && b.type.townHall) {
          final dd = sqrt(pow(campDefs[c].x * kTile - b.x, 2) + pow(campDefs[c].y * kTile - b.y, 2));
          if (dd < 700) penalty = 1500;
        }
      }
      if (d + penalty < bd) {
        bd = d + penalty;
        best = c;
      }
    }
    return best;
  }

  Unit? _pickAttackTarget(List<Unit> army) {
    if (army.isEmpty) return null;
    var cx = 0.0, cy = 0.0;
    for (final a in army) {
      cx += a.x;
      cy += a.y;
    }
    cx /= army.length;
    cy /= army.length;
    Unit? best;
    var bd = double.infinity;
    for (final b in g.units) {
      if (b.owner != foe || !b.isBuilding || b.dead) continue;
      final d = Game.distPt(b, cx, cy) - (b.type.townHall ? 300 : 0);
      if (d < bd) {
        bd = d;
        best = b;
      }
    }
    return best;
  }
}
