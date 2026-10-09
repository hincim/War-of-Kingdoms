import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Color, Offset, Rect;

import 'ai.dart';
import 'data.dart';
import 'entities.dart';
import 'map.dart';

const Color kGoldColor = Color(0xFFFFD54F);
const Color kLumberColor = Color(0xFF8BC34A);

/// Oyuncunun (0) görüş alanı.
class Fog {
  final Uint8List visible = Uint8List(kMapW * kMapH);
  final Uint8List explored = Uint8List(kMapW * kMapH);
  int version = 0;
  bool revealAll = false;

  void update(Game g) {
    visible.fillRange(0, visible.length, 0);
    final night = g.isNight;
    for (final u in g.units) {
      if (u.owner != kPlayer || u.dead) continue;
      var r = u.type.sight;
      if (u.isBuilding && u.constructing) r = 160;
      if (night && !u.isBuilding) r *= 0.75;
      final rt = r / kTile;
      final cx = u.x / kTile, cy = u.y / kTile;
      final r2 = rt * rt;
      final y0 = max(0, (cy - rt).floor()), y1 = min(kMapH - 1, (cy + rt).ceil());
      final x0 = max(0, (cx - rt).floor()), x1 = min(kMapW - 1, (cx + rt).ceil());
      for (var ty = y0; ty <= y1; ty++) {
        final dy = ty + 0.5 - cy;
        for (var tx = x0; tx <= x1; tx++) {
          final dx = tx + 0.5 - cx;
          if (dx * dx + dy * dy <= r2) {
            final i = ty * kMapW + tx;
            visible[i] = 1;
            explored[i] = 1;
          }
        }
      }
    }
    if (revealAll) {
      visible.fillRange(0, visible.length, 1);
      explored.fillRange(0, explored.length, 1);
    }
    for (final u in g.units) {
      if (u.isBuilding && u.owner != kPlayer && !u.seen) {
        final r = u.footprint;
        if (visibleAt(r.left + 4, r.top + 4) ||
            visibleAt(r.right - 4, r.bottom - 4) ||
            visibleAt(r.left + 4, r.bottom - 4) ||
            visibleAt(r.right - 4, r.top + 4)) {
          u.seen = true;
        }
      }
    }
    version++;
  }

  bool visibleAt(double x, double y) {
    final tx = (x / kTile).floor(), ty = (y / kTile).floor();
    if (tx < 0 || ty < 0 || tx >= kMapW || ty >= kMapH) return false;
    return visible[ty * kMapW + tx] == 1;
  }

  bool exploredTile(int tx, int ty) {
    if (tx < 0 || ty < 0 || tx >= kMapW || ty >= kMapH) return false;
    return explored[ty * kMapW + tx] == 1;
  }
}

class Game {
  Game({
    required Faction playerFaction,
    this.difficulty = Difficulty.normal,
    int? seed,
    bool autoPlayer = false,
  }) {
    final s = seed ?? DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    rng = Random(s);
    map = GameMap(s);
    final enemyFaction = identical(playerFaction, humanFaction) ? orcFaction : humanFaction;
    players.add(Player(kPlayer, playerFaction, name: 'Siz', isAI: autoPlayer));
    players.add(Player(kEnemy, enemyFaction, name: 'Bilgisayar', isAI: true));
    players.add(Player(kCreeps, null, name: 'Tarafsız Yaratıklar'));
    players.add(Player(kPassive, null, name: 'Tarafsız'));
    players[kEnemy].gatherMult = switch (difficulty) {
      Difficulty.easy => 0.8,
      Difficulty.normal => 1.0,
      Difficulty.hard => 1.3,
    };

    for (var i = 0; i < 2; i++) {
      _setupBase(players[i], startLocs[i]);
    }
    for (final m in expansionMines) {
      _spawnMine(m[0], m[1], 10000);
    }
    for (var c = 0; c < campDefs.length; c++) {
      final def = campDefs[c];
      final n = def.creeps.length;
      for (var k = 0; k < n; k++) {
        final a = k / n * 2 * pi + 0.4;
        final rr = n == 1 ? 0.0 : 30.0;
        final u = spawnUnit(def.creeps[k], kCreeps, def.x * kTile + cos(a) * rr, def.y * kTile + sin(a) * rr);
        u.camp = c;
        u.facing = rng.nextDouble() * 2 * pi;
      }
    }
    for (var i = 0; i < 2; i++) {
      if (players[i].isAI) ais.add(EnemyAI(this, i, difficulty));
    }
    _recomputeFood();
    fog.update(this);
  }

  late final Random rng;
  late final GameMap map;
  final Difficulty difficulty;
  final List<Player> players = [];
  final List<Unit> units = [];
  final List<Projectile> projectiles = [];
  final List<Fx> effects = [];
  final List<AreaEffect> areas = [];
  final List<FloatText> texts = [];
  final List<GroundItem> items = [];
  final List<Corpse> corpses = [];
  final List<GameMessage> messages = [];
  final List<Ping> pings = [];
  final List<EnemyAI> ais = [];
  final Fog fog = Fog();

  double time = 0;
  double dayClock = 30; // 08:00
  int? winner;
  double _auraT = 0, _fogT = 0, _winT = 1;
  double _lastAlert = -100;
  Offset? lastAlertPos;

  Player get me => players[kPlayer];

  // ------------------------------------------------------------- Zaman

  double get hours => (dayClock / kDayLength * 24 + 6) % 24;
  bool get isNight => hours >= 18 || hours < 6;

  /// 0 = gündüz, 1 = tam gece (geçişler yumuşak).
  double get nightness {
    final h = hours;
    if (h >= 6.5 && h < 17.5) return 0;
    if (h >= 18.5 || h < 5.5) return 1;
    if (h >= 17.5 && h < 18.5) return h - 17.5;
    return 1 - (h - 5.5);
  }

  String get clockText {
    final h = hours.floor();
    final m = ((hours - h) * 60).floor();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  // ------------------------------------------------------------- Kurulum

  void _setupBase(Player p, StartLoc loc) {
    p.gold = 500;
    p.lumber = 150;
    final hall = spawnBuilding(p.faction!.hall, p.id, loc.hallX, loc.hallY, complete: true);
    final mine = _spawnMine(loc.mineX, loc.mineY, 15000);
    for (var i = 0; i < 5; i++) {
      final a = atan2(mine.y - hall.y, mine.x - hall.x) + (i - 2) * 0.45;
      final w = spawnUnit(p.faction!.worker, p.id, hall.x + cos(a) * 80, hall.y + sin(a) * 80);
      cmdGatherGold(w, mine);
    }
  }

  Unit _spawnMine(int tx, int ty, int gold) {
    final m = spawnBuilding('goldmine', kPassive, tx, ty, complete: true);
    m.goldLeft = gold;
    return m;
  }

  Unit spawnBuilding(String typeId, int owner, int tx, int ty, {bool complete = true}) {
    final t = ut(typeId);
    final b = Unit(t, owner, players[owner], (tx + t.size / 2) * kTile, (ty + t.size / 2) * kTile);
    b.tileX = tx;
    b.tileY = ty;
    b.constructing = !complete;
    b.progress = complete ? 1 : 0;
    b.hp = complete ? t.hp : t.hp * 0.1;
    if (!complete || owner == kPlayer) b.seen = owner == kPlayer;
    map.setOccupied(tx, ty, t.size, true);
    units.add(b);
    return b;
  }

  Unit spawnUnit(String typeId, int owner, double x, double y) {
    final t = ut(typeId);
    final u = Unit(t, owner, players[owner], x, y);
    if (!map.walkablePx(x, y)) {
      final n = map.nearestWalkable((x / kTile).floor(), (y / kTile).floor(), x, y);
      if (n != null) {
        final c = GameMap.tileCenter(n.x, n.y);
        u.x = c.dx;
        u.y = c.dy;
      }
    }
    if (t.hero) {
      final names = players[owner].faction?.heroNames[t.id] ?? const ['Kahraman'];
      u.heroName = names[rng.nextInt(names.length)];
      u.skillPoints = 1;
      u.mana = u.maxMana;
    }
    u.homeX = u.x;
    u.homeY = u.y;
    units.add(u);
    return u;
  }

  // ------------------------------------------------------------- Yardımcılar

  static double dist(Unit a, Unit b) {
    final dx = a.x - b.x, dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  static double distPt(Unit a, double x, double y) {
    final dx = a.x - x, dy = a.y - y;
    return sqrt(dx * dx + dy * dy);
  }

  /// Kenardan kenara mesafe.
  static double edgeDist(Unit a, Unit b) {
    if (b.isBuilding) {
      final half = b.size * kTile / 2;
      final dx = max((a.x - b.x).abs() - half, 0.0), dy = max((a.y - b.y).abs() - half, 0.0);
      return sqrt(dx * dx + dy * dy) - (a.isBuilding ? a.radius * 0.7 : a.radius);
    }
    if (a.isBuilding) return dist(a, b) - b.radius - a.radius * 0.7;
    return dist(a, b) - a.radius - b.radius;
  }

  /// Binanın, birime en yakın kenarının hemen dışındaki nokta.
  static Offset approachPoint(Unit u, Unit b, [double pad = 12]) {
    final r = b.footprint.inflate(pad);
    return Offset(u.x.clamp(r.left, r.right), u.y.clamp(r.top, r.bottom));
  }

  bool isEnemy(int a, int b) {
    if (a == b) return false;
    if (a == kPassive || b == kPassive) return false;
    return true;
  }

  static bool valid(Unit? t) => t != null && !t.dead && !t.hidden;

  void msg(int pid, String text, {Color color = const Color(0xFFFFD54F)}) {
    if (pid != kPlayer) return;
    messages.removeWhere((m) => m.text == text);
    messages.add(GameMessage(text, time, color: color));
    if (messages.length > 5) messages.removeAt(0);
  }

  bool meetsReq(Player p, UnitType t) {
    for (final r in t.requires) {
      if (!units.any((u) => u.owner == p.id && u.type.id == r && !u.constructing)) return false;
    }
    return true;
  }

  Unit? nearestHall(Unit u) {
    Unit? best;
    var bd = double.infinity;
    for (final b in units) {
      if (b.owner != u.owner || !b.type.townHall || b.constructing || b.dead) continue;
      final d = dist(u, b);
      if (d < bd) {
        bd = d;
        best = b;
      }
    }
    return best;
  }

  int heroCount(int pid) {
    var n = players[pid].deadHeroes.length;
    for (final u in units) {
      if (u.owner != pid) continue;
      if (u.isHero) n++;
      for (final q in u.queue) {
        if (q.kind == 'unit' && q.unitType!.hero) n++;
      }
    }
    return n;
  }

  bool hasHeroType(int pid, String typeId) {
    if (players[pid].deadHeroes.any((h) => h.type.id == typeId)) return true;
    for (final u in units) {
      if (u.owner != pid) continue;
      if (u.type.id == typeId) return true;
      for (final q in u.queue) {
        if (q.kind == 'unit' && q.unitType!.id == typeId) return true;
      }
    }
    return false;
  }

  int xpOf(Unit v) {
    if (v.isHero) return const [100, 120, 160, 220, 300, 400, 500, 600, 700, 800][(v.level - 1).clamp(0, 9)];
    return v.type.xpValue;
  }

  Unit? pick(double x, double y) {
    Unit? best;
    var bd = double.infinity;
    for (final u in units) {
      if (u.dead || u.hidden) continue;
      double d;
      if (u.isBuilding) {
        final r = u.footprint;
        final r2 = Rect.fromLTRB(r.left, r.top - 18, r.right, r.bottom);
        if (!r2.contains(Offset(x, y))) continue;
        d = 1000 + distPt(u, x, y);
      } else {
        d = distPt(u, x, y - u.radius * 0.5);
        if (d > u.radius * 1.5 + 6) continue;
      }
      if (d < bd) {
        bd = d;
        best = u;
      }
    }
    return best;
  }

  GroundItem? itemAt(double x, double y) {
    for (final it in items) {
      if (!it.taken && (it.x - x).abs() < 14 && (it.y - y).abs() < 14) return it;
    }
    return null;
  }

  // ------------------------------------------------------------- Ana döngü

  void update(double dt) {
    if (winner != null) return;
    time += dt;
    dayClock = (dayClock + dt) % kDayLength;
    _auraT -= dt;
    if (_auraT <= 0) {
      _auraT = 0.5;
      _computeAuras();
    }
    final list = List<Unit>.of(units);
    for (final u in list) {
      if (!u.dead) _updateUnit(u, dt);
    }
    _separate();
    _updateProjectiles(dt);
    _updateAreas(dt);
    for (final f in effects) {
      f.t += dt;
    }
    effects.removeWhere((f) => f.t >= f.dur);
    for (final t in texts) {
      t.t += dt;
    }
    texts.removeWhere((t) => t.t >= t.dur);
    for (final c in corpses) {
      c.t += dt;
    }
    corpses.removeWhere((c) => c.t > 14);
    items.removeWhere((i) => i.taken);
    units.removeWhere((u) => u.dead);
    _recomputeFood();
    for (final ai in ais) {
      ai.update(dt);
    }
    _fogT -= dt;
    if (_fogT <= 0) {
      _fogT = 0.2;
      fog.update(this);
    }
    _winT -= dt;
    if (_winT <= 0) {
      _winT = 1;
      _checkWin();
    }
    messages.removeWhere((m) => time - m.time > 6);
    pings.removeWhere((p) => time - p.time > 4);
  }

  void _checkWin() {
    for (final pid in const [kPlayer, kEnemy]) {
      final has = units.any((u) => u.owner == pid && u.isBuilding && !u.dead);
      if (!has) {
        players[pid].defeated = true;
        winner = pid == kPlayer ? kEnemy : kPlayer;
        return;
      }
    }
  }

  void _recomputeFood() {
    for (var i = 0; i < 2; i++) {
      players[i].foodUsed = 0;
      players[i].foodCap = 0;
    }
    for (final u in units) {
      if (u.owner > 1 || u.dead) continue;
      final p = players[u.owner];
      if (u.isBuilding) {
        if (!u.constructing) p.foodCap += u.type.foodProvided;
        for (final q in u.queue) {
          p.foodUsed += q.food;
        }
      } else if (!u.type.summon) {
        p.foodUsed += u.type.food;
      }
    }
    for (var i = 0; i < 2; i++) {
      players[i].foodCap = min(players[i].foodCap, 100);
    }
  }

  void _computeAuras() {
    for (final u in units) {
      u.auraArmor = 0;
      u.auraMana = 0;
      u.auraSpeed = 0;
      u.auraAtk = 0;
    }
    for (final h in units) {
      if (!h.isHero || h.dead) continue;
      for (final aid in h.type.abilities) {
        final a = abilityTypes[aid]!;
        if (!a.passive) continue;
        final lvl = h.abilityLevel(aid);
        if (lvl == 0) continue;
        final v1 = a.v1[lvl - 1], v2 = a.v2[lvl - 1];
        for (final u in units) {
          if (u.owner != h.owner || u.isBuilding || u.dead) continue;
          if (dist(u, h) > a.radius) continue;
          switch (aid) {
            case 'devotion':
              u.auraArmor = max(u.auraArmor, v1);
            case 'brilliance':
              u.auraMana = max(u.auraMana, v1);
            case 'endurance':
              u.auraSpeed = max(u.auraSpeed, v1);
              u.auraAtk = max(u.auraAtk, v2);
          }
        }
      }
    }
  }

  void _updateUnit(Unit u, double dt) {
    if (u.atkCd > 0) u.atkCd -= dt;
    if (u.cds.isNotEmpty) {
      for (final k in u.cds.keys.toList()) {
        u.cds[k] = max(0, u.cds[k]! - dt);
      }
    }
    if (u.isBuilding) {
      _updateBuilding(u, dt);
      return;
    }
    if (u.type.summon) {
      u.expire -= dt;
      if (u.expire <= 0) {
        _kill(u, null, -1, silent: true);
        return;
      }
    }
    if (u.hp < u.maxHp) {
      u.hp = min(u.maxHp, u.hp + u.type.hpRegen * dt * (u.order == Order.leash ? 40 : 1));
    }
    if (u.hp > u.maxHp) u.hp = u.maxHp;
    final mm = u.maxMana;
    if (mm > 0 && u.mana < mm) u.mana = min(mm, u.mana + u.manaRegen * dt);
    u.moving = false;
    if (u.stun > 0) {
      u.stun -= dt;
      u.swing = 0;
      u.swingTarget = null;
      return;
    }
    if (u.swing > 0) {
      u.swing -= dt;
      if (u.swing <= 0) _finishSwing(u);
      return;
    }
    switch (u.order) {
      case Order.idle:
        _idle(u, dt, hold: false);
      case Order.hold:
        _idle(u, dt, hold: true);
      case Order.move:
        if (u.path == null) _setPath(u, u.tx, u.ty);
        if (_stepPath(u, dt)) u.order = Order.idle;
      case Order.attackMove:
        _attackMove(u, dt);
      case Order.attack:
        final t = u.target;
        if (!valid(t) || t!.isMine) {
          u.order = Order.idle;
          u.target = null;
        } else {
          _engage(u, t, dt);
        }
      case Order.gather:
        _gather(u, dt);
      case Order.build:
        _build(u, dt);
      case Order.construct:
        _construct(u, dt);
      case Order.cast:
        _cast(u, dt);
      case Order.pickup:
        _pickupOrder(u, dt);
      case Order.leash:
        if (u.path == null) _setPath(u, u.homeX, u.homeY);
        if (_stepPath(u, dt) || distPt(u, u.homeX, u.homeY) < 12) {
          u.order = Order.idle;
          u.engaged = null;
        }
    }
  }

  void _idle(Unit u, double dt, {required bool hold}) {
    if (!u.type.canAttack) return;
    if (u.type.creep) {
      final home = distPt(u, u.homeX, u.homeY);
      if (u.engaged != null && home > 520) {
        _leash(u);
        return;
      }
      if (u.engaged == null && home > 40) {
        _leash(u);
        return;
      }
    }
    final e = u.engaged;
    if (e != null) {
      if (!valid(e) || !isEnemy(u.owner, e.owner) || (!hold && edgeDist(u, e) > u.type.acquire * 1.8)) {
        u.engaged = null;
      } else if (hold && edgeDist(u, e) > u.range + 4) {
        u.engaged = null;
      } else {
        _engage(u, e, dt, hold: hold);
        return;
      }
    }
    if (u.type.worker) return;
    u.acquireTimer -= dt;
    if (u.acquireTimer <= 0) {
      u.acquireTimer = 0.3 + rng.nextDouble() * 0.2;
      final t = _acquire(u, hold ? u.range + 4 : u.type.acquire);
      if (t != null) {
        u.engaged = t;
        if (u.camp >= 0) _alertCamp(u.camp, t);
      }
    }
  }

  void _leash(Unit u) {
    for (final c in units) {
      if (c.camp == u.camp && c.camp >= 0 && !c.dead && c.order != Order.leash) {
        c.order = Order.leash;
        c.engaged = null;
        c.path = null;
      }
    }
  }

  void _alertCamp(int camp, Unit attacker) {
    for (final c in units) {
      if (c.camp == camp && !c.dead && c.order == Order.idle && c.engaged == null) {
        c.engaged = attacker;
      }
    }
  }

  void _attackMove(Unit u, double dt) {
    final e = u.engaged;
    if (e != null) {
      if (!valid(e) || edgeDist(u, e) > u.type.acquire * 1.8) {
        u.engaged = null;
        u.path = null;
      } else {
        _engage(u, e, dt);
        return;
      }
    }
    if (u.type.canAttack) {
      u.acquireTimer -= dt;
      if (u.acquireTimer <= 0) {
        u.acquireTimer = 0.25 + rng.nextDouble() * 0.1;
        final t = _acquire(u, u.type.acquire);
        if (t != null) {
          u.engaged = t;
          u.path = null;
          if (t.camp >= 0) _alertCamp(t.camp, u);
          _engage(u, t, dt);
          return;
        }
      }
    }
    if (u.path == null) _setPath(u, u.tx, u.ty);
    if (_stepPath(u, dt)) u.order = Order.idle;
  }

  Unit? _acquire(Unit u, double range) {
    Unit? best;
    var bs = double.infinity;
    for (final v in units) {
      if (v.dead || v.hidden || v.isMine) continue;
      if (!isEnemy(u.owner, v.owner)) continue;
      if (u.type.creep && v.isBuilding) continue;
      if ((v.x - u.x).abs() > range + 80 || (v.y - u.y).abs() > range + 80) continue;
      final d = edgeDist(u, v);
      if (d > range) continue;
      final s = d + (v.isBuilding ? 400 : 0) + (v.type.worker ? 40 : 0);
      if (s < bs) {
        bs = s;
        best = v;
      }
    }
    return best;
  }

  void _engage(Unit u, Unit t, double dt, {bool hold = false}) {
    final d = edgeDist(u, t);
    if (d <= u.range + (t.isBuilding ? 10 : 2)) {
      u.path = null;
      u.facing = atan2(t.y - u.y, t.x - u.x);
      if (u.atkCd <= 0) _startSwing(u, t);
      return;
    }
    if (hold || u.order == Order.hold) return;
    u.repath -= dt;
    if (u.path == null || u.repath <= 0) {
      u.repath = d > 300 ? 1.0 : 0.4;
      if (t.isBuilding) {
        final ap = approachPoint(u, t, 4);
        _setPath(u, ap.dx, ap.dy);
      } else {
        _setPath(u, t.x, t.y);
      }
    }
    _stepPath(u, dt);
  }

  void _startSwing(Unit u, Unit t) {
    u.swingDur = u.isBuilding ? 0.1 : (u.isHero ? 0.35 : 0.3);
    u.swing = u.swingDur;
    u.swingTarget = t;
    u.atkCd = u.cooldown;
    u.attackAt = time;
  }

  void _finishSwing(Unit u) {
    final t = u.swingTarget;
    u.swingTarget = null;
    if (!valid(t)) return;
    if (edgeDist(u, t!) > u.range + 40) return;
    final dmg = u.dmgMin + rng.nextDouble() * (u.dmgMax - u.dmgMin);
    if (u.type.projSpeed > 0) {
      final p = Projectile(
        kind: u.type.projectile,
        x: u.x,
        y: u.y - (u.isBuilding ? 30 : 10),
        target: t,
        speed: u.type.projSpeed,
        owner: u.owner,
        onHit: () => damage(u, u.owner, t, dmg),
      );
      p.tx = t.x;
      p.ty = t.y;
      projectiles.add(p);
    } else {
      damage(u, u.owner, t, dmg);
    }
  }

  void damage(Unit? src, int srcOwner, Unit t, double amount, {bool spell = false}) {
    if (t.dead || t.isMine) return;
    if (!spell) {
      final a = t.armor;
      final f = a >= 0 ? 1 - (0.06 * a) / (1 + 0.06 * a) : 2 - pow(0.94, -a).toDouble();
      amount *= f;
    }
    t.hp -= amount;
    t.lastHurt = time;
    if (src != null && !src.dead && isEnemy(t.owner, srcOwner)) {
      t.lastAttacker = src;
      _onAttacked(t, src);
    }
    if (t.hp <= 0) _kill(t, src, srcOwner);
  }

  void _onAttacked(Unit t, Unit src) {
    if (!t.isBuilding && t.type.canAttack && !t.type.worker && t.engaged == null) {
      if (t.order == Order.idle || t.order == Order.attackMove) {
        if (t.camp < 0 || distPt(t, t.homeX, t.homeY) < 500) t.engaged = src;
      }
    }
    if (t.camp >= 0) _alertCamp(t.camp, src);
    if (t.owner == kPlayer && time - _lastAlert > 12) {
      _lastAlert = time;
      lastAlertPos = Offset(t.x, t.y);
      msg(kPlayer, t.isBuilding ? 'Üssünüz saldırı altında!' : 'Birimleriniz saldırı altında!',
          color: const Color(0xFFFF6E6E));
      pings.add(Ping(t.x, t.y, time, const Color(0xFFFF3B30)));
    }
  }

  void _kill(Unit t, Unit? killer, int killerOwner, {bool silent = false}) {
    if (t.dead) return;
    t.dead = true;
    t.hp = 0;
    t.swingTarget = null;
    t.engaged = null;
    final p = t.pl;
    if (t.isBuilding) {
      map.setOccupied(t.tileX, t.tileY, t.size, false);
      effects.add(Fx('rubble', t.x, t.y, 18, radius: t.radius));
      effects.add(Fx('explosion', t.x, t.y, 0.9, radius: t.radius * 1.2));
      for (final w in units) {
        if (w.target == t && (w.order == Order.construct || w.order == Order.gather)) {
          w.order = Order.idle;
          w.target = null;
        }
      }
      if (t.isMine) {
        for (final w in units) {
          if (w.mine == t && w.owner == kPlayer) {
            msg(kPlayer, 'Altın madeni tükendi.');
            break;
          }
        }
      }
    } else if (t.type.summon || silent) {
      effects.add(Fx('poof', t.x, t.y, 0.6, radius: t.radius * 1.6));
    } else {
      corpses.add(Corpse(t.type, p.color, t.x, t.y, t.facing));
    }
    if (t.owner == kCreeps && (killerOwner == kPlayer || killerOwner == kEnemy)) {
      players[killerOwner].gold += t.type.bounty;
      if (killerOwner == kPlayer) {
        texts.add(FloatText('+${t.type.bounty}', t.x, t.y - 24, kGoldColor));
      }
    }
    if ((killerOwner == kPlayer || killerOwner == kEnemy) && t.owner != killerOwner && !silent) {
      _giveKillXp(killerOwner, t);
      players[killerOwner].kills++;
    }
    if (t.owner <= 1 && !t.isBuilding && !t.type.summon) players[t.owner].unitsLost++;
    if (t.isHero) {
      p.deadHeroes.add(t);
      if (t.owner == kPlayer) {
        msg(kPlayer, 'Kahramanınız ${t.heroName} öldü! Sunakta diriltebilirsiniz.', color: const Color(0xFFFF6E6E));
      } else if (t.owner == kEnemy) {
        msg(kPlayer, 'Düşman kahramanı ${t.heroName} öldürüldü!', color: const Color(0xFF8BC34A));
      }
    }
    if (t.camp >= 0 && !units.any((c) => c.camp == t.camp && !c.dead)) {
      final drops = campDefs[t.camp].drops;
      for (var i = 0; i < drops.length; i++) {
        items.add(GroundItem(itemTypes[drops[i]]!, t.x + i * 22 - (drops.length - 1) * 11, t.y));
      }
    }
  }

  void _giveKillXp(int owner, Unit victim) {
    final heroes = units.where((h) => h.owner == owner && h.isHero && !h.dead && dist(h, victim) < 1000).toList();
    if (heroes.isEmpty) return;
    final share = xpOf(victim) / heroes.length;
    for (final h in heroes) {
      var s = share;
      if (victim.owner == kCreeps) {
        s *= const [1.0, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.25, 0.2, 0.2][(h.level - 1).clamp(0, 9)];
      }
      gainXp(h, s.round());
    }
  }

  void gainXp(Unit h, int amount) {
    if (h.level >= kMaxHeroLevel || amount <= 0) return;
    h.xp += amount;
    while (h.level < kMaxHeroLevel && h.xp >= xpForLevel[h.level]) {
      final oldMax = h.maxHp, oldMana = h.maxMana;
      h.level++;
      h.skillPoints++;
      h.hp += h.maxHp - oldMax;
      h.mana += h.maxMana - oldMana;
      effects.add(Fx('levelup', h.x, h.y, 1.4, radius: 40));
      texts.add(FloatText('Seviye ${h.level}!', h.x, h.y - 34, const Color(0xFFFFE082), dur: 2.2, size: 15));
      if (h.owner == kPlayer) msg(kPlayer, '${h.heroName} seviye ${h.level} oldu!', color: const Color(0xFFFFE082));
    }
    if (h.level >= kMaxHeroLevel) h.xp = xpForLevel[kMaxHeroLevel - 1];
  }

  // ------------------------------------------------------------- Hareket

  void _setPath(Unit u, double gx, double gy) {
    u.pathI = 0;
    u.stuck = 0;
    final a = Offset(u.x, u.y), b = Offset(gx, gy);
    if (map.walkablePx(gx, gy) && map.lineClear(a, b)) {
      u.path = [b];
      return;
    }
    u.path = map.findPath(u.x, u.y, gx, gy);
  }

  bool _tryMove(Unit u, double nx, double ny) {
    if (map.walkablePx(nx, ny)) {
      u.x = nx;
      u.y = ny;
      return true;
    }
    if (map.walkablePx(nx, u.y)) {
      u.x = nx;
      return true;
    }
    if (map.walkablePx(u.x, ny)) {
      u.y = ny;
      return true;
    }
    return false;
  }

  void _unstick(Unit u) {
    if (map.walkablePx(u.x, u.y)) return;
    final n = map.nearestWalkable((u.x / kTile).floor(), (u.y / kTile).floor(), u.x, u.y);
    if (n != null) {
      final c = GameMap.tileCenter(n.x, n.y);
      u.x = c.dx;
      u.y = c.dy;
    }
  }

  /// Yolda ilerler; hedefe ulaşınca true döner.
  bool _stepPath(Unit u, double dt) {
    final p = u.path;
    if (p == null || u.pathI >= p.length) {
      u.path = null;
      return true;
    }
    _unstick(u);
    final wp = p[u.pathI];
    final dx = wp.dx - u.x, dy = wp.dy - u.y;
    final d = sqrt(dx * dx + dy * dy);
    final step = u.speed * dt;
    u.moving = true;
    u.walkAnim += dt * u.speed / 18;
    if (d <= max(step, 1.5)) {
      _tryMove(u, wp.dx, wp.dy);
      u.pathI++;
      if (u.pathI >= p.length) {
        u.path = null;
        u.stuckTotal = 0;
        return true;
      }
      return false;
    }
    u.facing = atan2(dy, dx);
    _tryMove(u, u.x + dx / d * step, u.y + dy / d * step);
    final nd = sqrt((wp.dx - u.x) * (wp.dx - u.x) + (wp.dy - u.y) * (wp.dy - u.y));
    if (nd > d - step * 0.3) {
      u.stuck += dt;
      u.stuckTotal += dt;
      if (u.stuckTotal > 4) {
        u.path = null;
        u.stuckTotal = 0;
        return true;
      }
      if (u.stuck > 0.6) {
        u.stuck = 0;
        final goal = p.last;
        _setPath(u, goal.dx, goal.dy);
      }
    } else {
      u.stuck = max(0, u.stuck - dt);
      u.stuckTotal = max(0, u.stuckTotal - dt * 0.5);
    }
    return false;
  }

  void _separate() {
    final cells = <int, List<Unit>>{};
    for (final u in units) {
      if (u.isBuilding || u.hidden || u.dead) continue;
      final k = (u.x ~/ 48) + (u.y ~/ 48) * 1000;
      (cells[k] ??= []).add(u);
    }
    for (final u in units) {
      if (u.isBuilding || u.hidden || u.dead) continue;
      final cx = u.x ~/ 48, cy = u.y ~/ 48;
      for (var oy = -1; oy <= 1; oy++) {
        for (var ox = -1; ox <= 1; ox++) {
          final list = cells[(cx + ox) + (cy + oy) * 1000];
          if (list == null) continue;
          for (final v in list) {
            if (v.id <= u.id) continue;
            if (u.gathering && v.gathering) continue;
            final dx = v.x - u.x, dy = v.y - u.y;
            final rr = (u.radius + v.radius) * 0.85;
            final d2 = dx * dx + dy * dy;
            if (d2 >= rr * rr) continue;
            var d = sqrt(d2);
            var nx = 1.0, ny = 0.0;
            if (d < 0.01) {
              final a = (u.id * 1.7 + v.id) % (2 * pi);
              nx = cos(a);
              ny = sin(a);
              d = 0.01;
            } else {
              nx = dx / d;
              ny = dy / d;
            }
            final overlap = min(rr - d, 4.0);
            final wu = _pushWeight(u), wv = _pushWeight(v);
            final tot = wu + wv;
            if (tot <= 0) continue;
            final pu = overlap * wu / tot, pv = overlap * wv / tot;
            final ux = u.x - nx * pu, uy = u.y - ny * pu;
            if (map.walkablePx(ux, uy)) {
              u.x = ux;
              u.y = uy;
            }
            final vx = v.x + nx * pv, vy = v.y + ny * pv;
            if (map.walkablePx(vx, vy)) {
              v.x = vx;
              v.y = vy;
            }
          }
        }
      }
    }
  }

  double _pushWeight(Unit u) {
    if (u.order == Order.hold) return 0.05;
    if (u.moving) return 0.3;
    if (u.swing > 0 || u.order == Order.construct) return 0.2;
    return 0.7;
  }

  // ------------------------------------------------------------- Binalar

  void _updateBuilding(Unit b, double dt) {
    if (b.isMine || b.constructing) return;
    if (b.type.canAttack) {
      if (b.swing > 0) {
        b.swing -= dt;
        if (b.swing <= 0) _finishSwing(b);
      } else {
        var t = b.engaged;
        if (!valid(t) || edgeDist(b, t!) > b.range) {
          b.acquireTimer -= dt;
          if (b.acquireTimer <= 0) {
            b.acquireTimer = 0.3;
            t = _acquire(b, b.range);
            b.engaged = t;
          } else {
            t = null;
          }
        }
        if (t != null && b.atkCd <= 0) _startSwing(b, t);
      }
    }
    if (b.queue.isNotEmpty) {
      final q = b.queue.first;
      q.progress += dt;
      if (q.progress >= q.time) {
        b.queue.removeAt(0);
        _completeQueue(b, q);
      }
    }
  }

  Offset _spawnPoint(Unit b) {
    final fx = b.rallyX ?? b.x, fy = b.rallyY ?? (b.y + 400);
    final n = map.nearestWalkable(b.tileX + b.size ~/ 2, b.tileY + b.size ~/ 2, fx, fy);
    if (n == null) return Offset(b.x, b.y + b.radius + 12);
    return GameMap.tileCenter(n.x, n.y);
  }

  void _completeQueue(Unit b, QueueItem q) {
    final p = b.pl;
    switch (q.kind) {
      case 'unit':
        final sp = _spawnPoint(b);
        final u = spawnUnit(q.unitType!.id, b.owner, sp.dx + rng.nextDouble() * 4 - 2, sp.dy);
        p.unitsTrained++;
        if (u.isHero) {
          effects.add(Fx('levelup', u.x, u.y, 1.2, radius: 36));
          msg(b.owner, '${u.heroName} (${u.type.name}) savaşa hazır!', color: const Color(0xFFFFE082));
        }
        _applyRally(b, u);
      case 'research':
        final up = q.upgrade!;
        p.upgrades[up.id] = p.upgrade(up.id) + 1;
        msg(b.owner, '${up.name} (Seviye ${p.upgrade(up.id)}) tamamlandı.', color: const Color(0xFF8BC34A));
      case 'revive':
        final h = q.hero!;
        p.deadHeroes.remove(h);
        final sp = _spawnPoint(b);
        h.dead = false;
        h.hp = h.maxHp;
        h.mana = h.maxMana;
        h.x = sp.dx;
        h.y = sp.dy;
        h.order = Order.idle;
        h.path = null;
        h.stun = 0;
        h.target = null;
        h.engaged = null;
        h.cds.clear();
        units.add(h);
        effects.add(Fx('levelup', h.x, h.y, 1.2, radius: 36));
        msg(b.owner, '${h.heroName} yeniden doğdu!', color: const Color(0xFFFFE082));
        _applyRally(b, h);
    }
  }

  void _applyRally(Unit b, Unit u) {
    final ru = b.rallyUnit;
    if (u.type.worker && ru != null && ru.isMine && !ru.dead) {
      cmdGatherGold(u, ru);
      return;
    }
    if (u.type.worker && b.rallyTreeX >= 0) {
      cmdGatherWood(u, b.rallyTreeX, b.rallyTreeY);
      return;
    }
    if (b.rallyX != null) {
      _setOrder(u, Order.move);
      u.tx = b.rallyX!;
      u.ty = b.rallyY!;
    }
  }

  // ------------------------------------------------------------- İşçiler

  void _gather(Unit u, double dt) {
    if (u.gatherKind == 'gold') {
      _gatherGold(u, dt);
    } else {
      _gatherWood(u, dt);
    }
  }

  void _returnCargo(Unit u, double dt) {
    final hall = nearestHall(u);
    if (hall == null) {
      u.order = Order.idle;
      return;
    }
    if (edgeDist(u, hall) <= 18) {
      final p = u.pl;
      if (u.carryGold > 0) {
        final amt = (u.carryGold * p.gatherMult).round();
        p.gold += amt;
        p.goldMined += amt;
        if (u.owner == kPlayer) texts.add(FloatText('+$amt', hall.x, hall.y - 50, kGoldColor, dur: 1.0, size: 11));
      }
      if (u.carryWood > 0) {
        final amt = (u.carryWood * p.gatherMult).round();
        p.lumber += amt;
        p.lumberMined += amt;
        if (u.owner == kPlayer) texts.add(FloatText('+$amt', hall.x, hall.y - 50, kLumberColor, dur: 1.0, size: 11));
      }
      u.carryGold = 0;
      u.carryWood = 0;
      u.gatherPhase = 0;
      u.path = null;
      return;
    }
    u.repath -= dt;
    if (u.path == null || u.repath <= 0) {
      u.repath = 3;
      final ap = approachPoint(u, hall);
      _setPath(u, ap.dx, ap.dy);
    }
    if (_stepPath(u, dt) && edgeDist(u, hall) > 18) {
      u.path = null;
      u.stuckTotal += 0.5;
      if (u.stuckTotal > 8) {
        u.stuckTotal = 0;
        u.order = Order.idle;
      }
    }
  }

  void _gatherGold(Unit u, double dt) {
    final m = u.mine;
    if (u.gatherPhase == 2 || (u.gatherPhase == 0 && (u.carryGold > 0 || u.carryWood > 0))) {
      u.gatherPhase = 2;
      _returnCargo(u, dt);
      return;
    }
    if (m == null || m.dead) {
      u.hidden = false;
      u.order = Order.idle;
      return;
    }
    if (u.gatherPhase == 1) {
      u.gatherTimer -= dt;
      if (u.gatherTimer <= 0) {
        final take = min(10, m.goldLeft);
        m.goldLeft -= take;
        u.carryGold = take;
        u.hidden = false;
        _exitMine(u, m);
        u.gatherPhase = 2;
        if (m.goldLeft <= 0) _kill(m, null, -1);
      }
      return;
    }
    if (edgeDist(u, m) <= 16) {
      u.hidden = true;
      u.path = null;
      u.gatherPhase = 1;
      u.gatherTimer = 1.0;
      return;
    }
    u.repath -= dt;
    if (u.path == null || u.repath <= 0) {
      u.repath = 3;
      final hall = nearestHall(u);
      // Madenin ana binaya bakan kenarına git.
      var gx = m.x, gy = m.y;
      if (hall != null) {
        final a = atan2(hall.y - m.y, hall.x - m.x);
        gx = m.x + cos(a) * (m.radius + 10);
        gy = m.y + sin(a) * (m.radius + 10);
        if (!map.walkablePx(gx, gy)) {
          final ap = approachPoint(u, m);
          gx = ap.dx;
          gy = ap.dy;
        }
      }
      _setPath(u, gx, gy);
    }
    if (_stepPath(u, dt) && edgeDist(u, m) > 16) {
      u.path = null;
      u.stuckTotal += 0.5;
      if (u.stuckTotal > 6) {
        u.stuckTotal = 0;
        u.order = Order.idle;
      }
    }
  }

  void _exitMine(Unit u, Unit m) {
    final hall = nearestHall(u);
    final a = hall != null ? atan2(hall.y - m.y, hall.x - m.x) : pi / 2;
    final ex = m.x + cos(a) * (m.radius + u.radius + 2), ey = m.y + sin(a) * (m.radius + u.radius + 2);
    u.x = ex;
    u.y = ey;
    _unstick(u);
    u.path = null;
  }

  void _gatherWood(Unit u, double dt) {
    if (u.gatherPhase == 2 || (u.gatherPhase == 0 && (u.carryWood >= 10 || u.carryGold > 0))) {
      u.gatherPhase = 2;
      _returnCargo(u, dt);
      return;
    }
    if (!map.isTree(u.treeX, u.treeY)) {
      final t = map.nearestTree(u.x, u.y, 8);
      if (t == null) {
        if (u.carryWood > 0) {
          u.gatherPhase = 2;
        } else {
          u.order = Order.idle;
        }
        return;
      }
      u.treeX = t.x;
      u.treeY = t.y;
      u.path = null;
      u.gatherPhase = 0;
    }
    final c = GameMap.tileCenter(u.treeX, u.treeY);
    final d = distPt(u, c.dx, c.dy);
    if (u.gatherPhase == 1) {
      if (d > kTile * 1.5 + 14) {
        u.gatherPhase = 0;
        return;
      }
      u.facing = atan2(c.dy - u.y, c.dx - u.x);
      u.gatherTimer -= dt;
      if (u.gatherTimer <= 0) {
        u.gatherTimer = 0.75;
        u.attackAt = time;
        u.carryWood++;
        final gone = map.chop(u.treeX, u.treeY, 1);
        if (u.carryWood >= 10) {
          u.gatherPhase = 2;
          u.path = null;
        } else if (gone) {
          u.gatherPhase = 0;
        }
      }
      return;
    }
    if (d <= kTile * 1.5 + 4) {
      u.gatherPhase = 1;
      u.gatherTimer = 0.75;
      u.path = null;
      return;
    }
    u.repath -= dt;
    if (u.path == null || u.repath <= 0) {
      u.repath = 3;
      _setPath(u, c.dx, c.dy);
    }
    if (_stepPath(u, dt) && distPt(u, c.dx, c.dy) > kTile * 1.5 + 4) {
      // Bu ağaca ulaşılamıyor; başka birini dene.
      u.stuckTotal += 1;
      if (u.stuckTotal > 3) {
        u.stuckTotal = 0;
        u.order = Order.idle;
        return;
      }
      final t = map.nearestTree(u.x, u.y, 4);
      if (t != null) {
        u.treeX = t.x;
        u.treeY = t.y;
      }
      u.path = null;
    }
  }

  void _resumeGather(Unit u) {
    if (!u.type.worker) return;
    if (u.lastGatherKind == 'gold' && u.mine != null && !u.mine!.dead) {
      cmdGatherGold(u, u.mine!);
    } else if (u.lastGatherKind == 'wood') {
      final t = map.nearestTree(u.x, u.y, 10);
      if (t != null) cmdGatherWood(u, t.x, t.y);
    }
  }

  bool canPlace(UnitType t, int tx, int ty, int owner) {
    for (var y = ty; y < ty + t.size; y++) {
      for (var x = tx; x < tx + t.size; x++) {
        if (!map.buildable(x, y)) return false;
        if (owner == kPlayer && !fog.exploredTile(x, y)) return false;
      }
    }
    final r = Rect.fromLTWH(tx * kTile, ty * kTile, t.size * kTile, t.size * kTile);
    for (final u in units) {
      if (u.isBuilding || u.hidden || u.dead || u.owner == owner) continue;
      if (r.inflate(u.radius * 0.5).contains(Offset(u.x, u.y))) return false;
    }
    if (t.townHall) {
      for (final m in units) {
        if (!m.isMine) continue;
        final f = m.footprint;
        final gapX = max(f.left - r.right, r.left - f.right);
        final gapY = max(f.top - r.bottom, r.top - f.bottom);
        if (max(gapX, gapY) < 3 * kTile) return false;
      }
    }
    return true;
  }

  void _build(Unit u, double dt) {
    final t = u.buildType!;
    final r = Rect.fromLTWH(u.buildTx * kTile, u.buildTy * kTile, t.size * kTile, t.size * kTile);
    final dx = max(max(r.left - u.x, u.x - r.right), 0.0);
    final dy = max(max(r.top - u.y, u.y - r.bottom), 0.0);
    final d = sqrt(dx * dx + dy * dy);
    if (d > 20) {
      if (u.path == null) _setPath(u, r.center.dx, r.center.dy);
      if (_stepPath(u, dt)) {
        final dx2 = max(max(r.left - u.x, u.x - r.right), 0.0);
        final dy2 = max(max(r.top - u.y, u.y - r.bottom), 0.0);
        if (sqrt(dx2 * dx2 + dy2 * dy2) > 40) {
          msg(u.owner, 'İşçi inşaat alanına ulaşamıyor.');
          u.order = Order.idle;
        }
      }
      return;
    }
    final p = u.pl;
    if (!canPlace(t, u.buildTx, u.buildTy, u.owner)) {
      msg(u.owner, 'Buraya inşa edilemez.');
      u.order = Order.idle;
      _resumeGather(u);
      return;
    }
    if (p.gold < t.gold || p.lumber < t.lumber) {
      msg(u.owner, p.gold < t.gold ? 'Yeterli altın yok.' : 'Yeterli odun yok.');
      u.order = Order.idle;
      _resumeGather(u);
      return;
    }
    p.gold -= t.gold;
    p.lumber -= t.lumber;
    final b = spawnBuilding(t.id, u.owner, u.buildTx, u.buildTy, complete: false);
    for (final o in units) {
      if (o.isBuilding || o.hidden || o.dead) continue;
      if (b.footprint.inflate(o.radius * 0.8).contains(Offset(o.x, o.y))) {
        final n = map.nearestWalkable((o.x / kTile).floor(), (o.y / kTile).floor(), u.x, u.y);
        if (n != null) {
          final c = GameMap.tileCenter(n.x, n.y);
          o.x = c.dx;
          o.y = c.dy;
          o.path = null;
        }
      }
    }
    u.order = Order.construct;
    u.target = b;
    b.target = u;
    u.path = null;
  }

  void _construct(Unit u, double dt) {
    final b = u.target;
    if (b == null || b.dead || !b.constructing) {
      u.order = Order.idle;
      u.target = null;
      _resumeGather(u);
      return;
    }
    if (edgeDist(u, b) > 18) {
      if (u.path == null) {
        final ap = approachPoint(u, b);
        _setPath(u, ap.dx, ap.dy);
      }
      if (_stepPath(u, dt) && edgeDist(u, b) > 18) {
        u.order = Order.idle;
      }
      return;
    }
    u.path = null;
    u.facing = atan2(b.y - u.y, b.x - u.x);
    if (time - u.attackAt > 0.7) u.attackAt = time;
    final mb = b.target;
    if (mb == null || mb.dead || mb.order != Order.construct || mb.target != b) b.target = u;
    final factor = b.target == u ? 1.0 : 0.5;
    final rate = dt / b.type.buildTime * factor;
    b.progress += rate;
    b.hp = min(b.maxHp, b.hp + rate * b.maxHp * 0.9);
    if (b.progress >= 1) {
      b.progress = 1;
      b.constructing = false;
      msg(b.owner, '${b.type.name} tamamlandı.', color: const Color(0xFF8BC34A));
      for (final w in units) {
        if (w.order == Order.construct && w.target == b) {
          w.order = Order.idle;
          w.target = null;
          _resumeGather(w);
        }
      }
    }
  }

  // ------------------------------------------------------------- Yetenekler

  void _cast(Unit u, double dt) {
    final a = u.castAbility;
    if (a == null) {
      u.order = Order.idle;
      return;
    }
    final lvl = u.abilityLevel(a.id);
    if (lvl == 0 || u.mana < a.mana[lvl - 1] || u.cooldownLeft(a.id) > 0) {
      _afterCast(u);
      return;
    }
    double px = u.x, py = u.y;
    Unit? t;
    if (a.target == TargetKind.unit) {
      t = u.target;
      if (!valid(t)) {
        _afterCast(u);
        return;
      }
      px = t!.x;
      py = t.y;
    } else if (a.target == TargetKind.point) {
      px = u.tx;
      py = u.ty;
    }
    if (a.target != TargetKind.none) {
      final d = sqrt((px - u.x) * (px - u.x) + (py - u.y) * (py - u.y)) - (t?.radius ?? 0);
      if (d > a.range) {
        u.repath -= dt;
        if (u.path == null || u.repath <= 0) {
          u.repath = 0.5;
          _setPath(u, px, py);
        }
        _stepPath(u, dt);
        return;
      }
      u.facing = atan2(py - u.y, px - u.x);
    }
    u.path = null;
    _execute(u, a, lvl, t, px, py);
    u.attackAt = time;
    _afterCast(u);
  }

  void _afterCast(Unit u) {
    u.castAbility = null;
    u.target = null;
    if (u.resumeAttackMove) {
      u.resumeAttackMove = false;
      u.order = Order.attackMove;
      u.tx = u.resumeX;
      u.ty = u.resumeY;
      u.path = null;
    } else {
      u.order = Order.idle;
    }
  }

  void _execute(Unit h, AbilityType a, int lvl, Unit? t, double px, double py) {
    final i = lvl - 1;
    h.mana -= a.mana[i];
    h.cds[a.id] = a.cooldown[i];
    final v1 = a.v1[i], v2 = a.v2[i];
    switch (a.id) {
      case 'holyLight':
        _heal(t!, v1);
        effects.add(Fx('holy', t.x, t.y, 1.0, radius: 30, color: a.color));
      case 'stormBolt':
        final target = t!;
        final p = Projectile(
          kind: 'hammer',
          x: h.x,
          y: h.y - 12,
          target: target,
          speed: 520,
          owner: h.owner,
          onHit: () {
            damage(h, h.owner, target, v1, spell: true);
            if (!target.dead) target.stun = max(target.stun, v2);
            effects.add(Fx('spark', target.x, target.y, 0.4, radius: 22, color: a.color));
          },
        );
        p.tx = target.x;
        p.ty = target.y;
        projectiles.add(p);
      case 'blizzard':
        areas.add(AreaEffect('blizzard', px, py, a.radius, v2.round(), v1, h.owner, h));
      case 'waterElemental':
        _summon(h, 'h_waterel', 1, v1, v2);
      case 'feralSpirit':
        _summon(h, 'o_wolf', 2, v1, v2);
      case 'warStomp':
        effects.add(Fx('stomp', h.x, h.y, 0.7, radius: a.radius));
        for (final e in List<Unit>.of(units)) {
          if (e.dead || e.hidden || e.isBuilding || !isEnemy(h.owner, e.owner)) continue;
          if (dist(e, h) - e.radius > a.radius) continue;
          damage(h, h.owner, e, v1, spell: true);
          if (!e.dead) e.stun = max(e.stun, e.isHero ? v2 * 0.6 : v2);
        }
      case 'shockwave':
        final ang = atan2(py - h.y, px - h.x);
        final ex = h.x + cos(ang) * a.range, ey = h.y + sin(ang) * a.range;
        effects.add(Fx('shockwave', h.x, h.y, 0.8, x2: ex, y2: ey, radius: a.radius));
        for (final e in List<Unit>.of(units)) {
          if (e.dead || e.hidden || !isEnemy(h.owner, e.owner) || e.isMine) continue;
          final sx = ex - h.x, sy = ey - h.y;
          final l2 = sx * sx + sy * sy;
          var tt = ((e.x - h.x) * sx + (e.y - h.y) * sy) / l2;
          tt = tt.clamp(0.0, 1.0);
          final cx = h.x + sx * tt, cy = h.y + sy * tt;
          final dd = sqrt((e.x - cx) * (e.x - cx) + (e.y - cy) * (e.y - cy));
          if (dd <= a.radius + e.radius) damage(h, h.owner, e, e.isBuilding ? v1 * 0.5 : v1, spell: true);
        }
      case 'chainLightning':
        _chain(h, t!, v1, v2.round(), enemy: true, color: a.color);
      case 'healingWave':
        _chain(h, t!, v1, v2.round(), enemy: false, color: a.color);
    }
  }

  void _heal(Unit t, double amount) {
    final before = t.hp;
    t.hp = min(t.maxHp, t.hp + amount);
    final healed = (t.hp - before).round();
    if (healed > 0 && (t.owner == kPlayer || fog.visibleAt(t.x, t.y))) {
      texts.add(FloatText('+$healed', t.x, t.y - 26, const Color(0xFF9CFF57)));
    }
  }

  void _summon(Unit h, String typeId, int count, double hp, double dmg) {
    final base = ut(typeId);
    for (var k = 0; k < count; k++) {
      final a = h.facing + (k - (count - 1) / 2) * 0.9;
      final s = spawnUnit(typeId, h.owner, h.x + cos(a) * 40, h.y + sin(a) * 40);
      s.extraHp = hp - base.hp;
      s.hp = s.maxHp;
      s.extraDmg = dmg - (base.dmgMin + base.dmgMax) / 2;
      s.expire = 60;
      s.facing = h.facing;
      effects.add(Fx('poof', s.x, s.y, 0.6, radius: 24));
      if (h.order == Order.attackMove || h.resumeAttackMove) {
        s.order = Order.attackMove;
        s.tx = h.resumeAttackMove ? h.resumeX : h.tx;
        s.ty = h.resumeAttackMove ? h.resumeY : h.ty;
      }
    }
  }

  void _chain(Unit h, Unit first, double amount, int jumps, {required bool enemy, required Color color}) {
    final hit = <Unit>{};
    final pts = <Offset>[Offset(h.x, h.y - 12)];
    var cur = first;
    var amt = amount;
    for (var j = 0; j <= jumps; j++) {
      hit.add(cur);
      pts.add(Offset(cur.x, cur.y - 6));
      if (enemy) {
        damage(h, h.owner, cur, amt, spell: true);
      } else {
        _heal(cur, amt);
      }
      amt *= enemy ? 0.85 : 0.75;
      Unit? next;
      var bd = double.infinity;
      for (final v in units) {
        if (v.dead || v.hidden || v.isBuilding || hit.contains(v)) continue;
        if (enemy ? !isEnemy(h.owner, v.owner) : v.owner != h.owner) continue;
        if (!enemy && v.hp >= v.maxHp) continue;
        final d = dist(v, cur);
        if (d < 220 && d < bd) {
          bd = d;
          next = v;
        }
      }
      if (next == null) break;
      cur = next;
    }
    effects.add(Fx(enemy ? 'lightning' : 'healwave', 0, 0, 0.45, pts: pts, color: color));
  }

  void _updateAreas(double dt) {
    for (final a in areas) {
      a.age += dt;
      a.timer -= dt;
      if (a.timer <= 0 && a.waves > 0) {
        a.timer = 1.0;
        a.waves--;
        for (final e in List<Unit>.of(units)) {
          if (e.dead || e.hidden || !isEnemy(a.owner, e.owner) || e.isMine) continue;
          if (distPt(e, a.x, a.y) - e.radius > a.radius) continue;
          damage(a.source, a.owner, e, e.isBuilding ? a.dmg * 0.5 : a.dmg, spell: true);
        }
      }
    }
    areas.removeWhere((a) => a.waves <= 0 && a.timer <= 0.2);
  }

  void _updateProjectiles(double dt) {
    for (final p in projectiles) {
      p.age += dt;
      final t = p.target;
      if (!t.dead && !t.hidden) {
        p.tx = t.x;
        p.ty = t.y - (t.isBuilding ? 10 : 6);
      }
      final dx = p.tx - p.x, dy = p.ty - p.y;
      final d = sqrt(dx * dx + dy * dy);
      final step = p.speed * dt;
      if (d <= step + 2) {
        p.done = true;
        if (!t.dead && !t.hidden) p.onHit();
      } else {
        p.x += dx / d * step;
        p.y += dy / d * step;
      }
      if (p.age > 5) p.done = true;
    }
    projectiles.removeWhere((p) => p.done);
  }

  void _pickupOrder(Unit u, double dt) {
    final it = u.targetItem;
    if (it == null || it.taken) {
      u.order = Order.idle;
      return;
    }
    if (distPt(u, it.x, it.y) > 30) {
      if (u.path == null) _setPath(u, it.x, it.y);
      if (_stepPath(u, dt) && distPt(u, it.x, it.y) > 30) u.order = Order.idle;
      return;
    }
    u.order = Order.idle;
    if (it.type.onPickup) {
      it.taken = true;
      gainXp(u, it.type.xp);
      texts.add(FloatText('+${it.type.xp} XP', u.x, u.y - 30, const Color(0xFFCE93D8)));
      return;
    }
    final slot = u.inv.indexWhere((s) => s == null);
    if (slot < 0) {
      msg(u.owner, 'Envanter dolu.');
      return;
    }
    u.inv[slot] = it.type;
    it.taken = true;
    if (u.owner == kPlayer) msg(kPlayer, '${it.type.name} alındı.', color: const Color(0xFFB3E5FC));
  }

  // ------------------------------------------------------------- Komutlar

  void _setOrder(Unit u, Order o) {
    if (u.hidden) {
      u.hidden = false;
      final m = u.mine;
      if (m != null) _exitMine(u, m);
    }
    if (u.order == Order.gather) u.lastGatherKind = u.gatherKind;
    u.order = o;
    u.engaged = null;
    u.target = null;
    u.path = null;
    u.castAbility = null;
    u.swing = 0;
    u.swingTarget = null;
    u.resumeAttackMove = false;
    u.stuckTotal = 0;
  }

  bool _controllable(Unit u, int pid) => u.owner == pid && !u.dead && !u.isBuilding;

  static List<Offset> formation(int n, double spacing) {
    final out = <Offset>[Offset.zero];
    var ring = 1;
    while (out.length < n) {
      final count = ring * 6;
      for (var i = 0; i < count && out.length < n; i++) {
        final a = i / count * 2 * pi;
        out.add(Offset(cos(a), sin(a)) * spacing * ring.toDouble());
      }
      ring++;
    }
    return out;
  }

  void cmdMove(List<Unit> us, double x, double y, {bool attack = false, int pid = kPlayer}) {
    final list = us.where((u) => _controllable(u, pid)).toList();
    if (list.isEmpty) return;
    final f = formation(list.length, 28);
    for (var i = 0; i < list.length; i++) {
      final u = list[i];
      var gx = x + f[i].dx, gy = y + f[i].dy;
      if (!map.walkablePx(gx, gy)) {
        gx = x;
        gy = y;
      }
      _setOrder(u, attack ? Order.attackMove : Order.move);
      u.tx = gx;
      u.ty = gy;
    }
  }

  void cmdStop(List<Unit> us, {int pid = kPlayer}) {
    for (final u in us) {
      if (_controllable(u, pid)) _setOrder(u, Order.idle);
    }
  }

  void cmdHold(List<Unit> us, {int pid = kPlayer}) {
    for (final u in us) {
      if (_controllable(u, pid)) _setOrder(u, Order.hold);
    }
  }

  void cmdAttack(List<Unit> us, Unit t, {int pid = kPlayer}) {
    if (t.isMine) return;
    for (final u in us) {
      if (u.owner != pid || u.dead) continue;
      if (u.isBuilding) {
        if (u.type.canAttack) u.engaged = t;
        continue;
      }
      if (!u.type.canAttack) continue;
      _setOrder(u, Order.attack);
      u.target = t;
    }
  }

  void cmdGatherGold(Unit u, Unit mine) {
    if (!u.type.worker || mine.dead) return;
    final carrying = u.carryGold > 0 || u.carryWood > 0;
    _setOrder(u, Order.gather);
    u.gatherKind = 'gold';
    u.lastGatherKind = 'gold';
    u.mine = mine;
    u.gatherPhase = carrying ? 2 : 0;
  }

  void cmdGatherWood(Unit u, int tx, int ty) {
    if (!u.type.worker) return;
    final carrying = u.carryGold > 0 || u.carryWood >= 10;
    _setOrder(u, Order.gather);
    u.gatherKind = 'wood';
    u.lastGatherKind = 'wood';
    u.treeX = tx;
    u.treeY = ty;
    u.gatherPhase = carrying ? 2 : 0;
  }

  void cmdReturnCargo(Unit u) {
    if (!u.type.worker || (u.carryGold == 0 && u.carryWood == 0)) return;
    final kind = u.carryGold > 0 ? 'gold' : 'wood';
    _setOrder(u, Order.gather);
    u.gatherKind = kind;
    u.gatherPhase = 2;
  }

  /// Sağ tık: bağlama göre uygun emir.
  void cmdSmart(List<Unit> us, double x, double y, {Unit? clicked, GroundItem? item, TilePos? tree, int pid = kPlayer}) {
    final movers = <Unit>[];
    for (final u in us) {
      if (u.owner != pid || u.dead) continue;
      if (u.isBuilding) {
        if (u.type.trains.isNotEmpty) {
          u.rallyX = x;
          u.rallyY = y;
          u.rallyUnit = (clicked != null && clicked.isMine) ? clicked : null;
          u.rallyTreeX = tree?.x ?? -1;
          u.rallyTreeY = tree?.y ?? -1;
        }
        if (clicked != null && isEnemy(pid, clicked.owner) && u.type.canAttack) u.engaged = clicked;
        continue;
      }
      if (clicked != null && clicked != u) {
        if (isEnemy(pid, clicked.owner) && !clicked.isMine) {
          if (u.type.canAttack) {
            _setOrder(u, Order.attack);
            u.target = clicked;
          }
          continue;
        }
        if (u.type.worker && clicked.isMine) {
          cmdGatherGold(u, clicked);
          continue;
        }
        if (u.type.worker && clicked.owner == pid && clicked.isBuilding) {
          if (clicked.constructing) {
            _setOrder(u, Order.construct);
            u.target = clicked;
            continue;
          }
          if (clicked.type.townHall && (u.carryGold > 0 || u.carryWood > 0)) {
            cmdReturnCargo(u);
            continue;
          }
        }
      }
      if (item != null && u.isHero) {
        _setOrder(u, Order.pickup);
        u.targetItem = item;
        continue;
      }
      if (tree != null && u.type.worker) {
        cmdGatherWood(u, tree.x, tree.y);
        continue;
      }
      movers.add(u);
    }
    if (movers.isNotEmpty) cmdMove(movers, x, y, pid: pid);
  }

  bool canAfford(Player p, int gold, int lumber, {bool notify = true}) {
    if (p.gold < gold) {
      if (notify) msg(p.id, 'Yeterli altın yok.');
      return false;
    }
    if (p.lumber < lumber) {
      if (notify) msg(p.id, 'Yeterli odun yok.');
      return false;
    }
    return true;
  }

  bool cmdBuild(Unit u, UnitType t, int tx, int ty) {
    if (!u.type.worker || u.dead) return false;
    final p = u.pl;
    if (!canAfford(p, t.gold, t.lumber)) return false;
    if (!canPlace(t, tx, ty, u.owner)) {
      msg(u.owner, 'Buraya inşa edilemez.');
      return false;
    }
    _setOrder(u, Order.build);
    u.buildType = t;
    u.buildTx = tx;
    u.buildTy = ty;
    return true;
  }

  bool cmdTrain(Unit b, String typeId) {
    if (b.dead || b.constructing) return false;
    final t = ut(typeId);
    final p = b.pl;
    if (b.queue.length >= 5) {
      msg(b.owner, 'Üretim sırası dolu.');
      return false;
    }
    if (!meetsReq(p, t)) {
      msg(b.owner, 'Gereksinim: ${t.requires.map((r) => ut(r).name).join(', ')}.');
      return false;
    }
    if (t.hero) {
      if (heroCount(b.owner) >= kMaxHeroes) {
        msg(b.owner, 'En fazla $kMaxHeroes kahramanınız olabilir.');
        return false;
      }
      if (hasHeroType(b.owner, typeId)) {
        msg(b.owner, 'Bu kahramana zaten sahipsiniz.');
        return false;
      }
    }
    if (p.foodUsed + t.food > p.foodCap) {
      msg(b.owner, 'Yetersiz yiyecek. Daha fazla ${ut(p.faction!.farm).name} inşa edin.');
      return false;
    }
    if (!canAfford(p, t.gold, t.lumber)) return false;
    p.gold -= t.gold;
    p.lumber -= t.lumber;
    b.queue.add(QueueItem.unit(t));
    _recomputeFood();
    return true;
  }

  bool cmdResearch(Unit b, String upId) {
    if (b.dead || b.constructing) return false;
    final up = upgradeTypes[upId]!;
    final p = b.pl;
    var lvl = p.upgrade(upId);
    for (final u in units) {
      if (u.owner != b.owner) continue;
      for (final q in u.queue) {
        if (q.kind == 'research' && q.upgrade!.id == upId) lvl++;
      }
    }
    if (lvl >= up.maxLevel) {
      msg(b.owner, 'Bu geliştirme tamamlandı.');
      return false;
    }
    if (b.queue.length >= 5) return false;
    if (!canAfford(p, up.gold[lvl], up.lumber[lvl])) return false;
    p.gold -= up.gold[lvl];
    p.lumber -= up.lumber[lvl];
    b.queue.add(QueueItem.research(up, lvl));
    return true;
  }

  int reviveCost(Unit h) => 120 + 45 * h.level;
  double reviveTime(Unit h) => 20.0 + 3 * h.level;

  bool cmdRevive(Unit b, Unit hero) {
    if (b.dead || b.constructing || !b.type.altar) return false;
    final p = b.pl;
    if (!p.deadHeroes.contains(hero)) return false;
    for (final u in units) {
      for (final q in u.queue) {
        if (q.hero == hero) return false;
      }
    }
    if (p.foodUsed + hero.type.food > p.foodCap) {
      msg(b.owner, 'Yetersiz yiyecek.');
      return false;
    }
    final cost = reviveCost(hero);
    if (!canAfford(p, cost, 0)) return false;
    p.gold -= cost;
    b.queue.add(QueueItem.revive(hero, cost, reviveTime(hero)));
    return true;
  }

  void cmdCancelQueue(Unit b, int index) {
    if (index < 0 || index >= b.queue.length) return;
    final q = b.queue.removeAt(index);
    b.pl.gold += q.gold;
    b.pl.lumber += q.lumber;
  }

  void cmdCancelConstruction(Unit b) {
    if (!b.constructing || b.dead) return;
    b.pl.gold += (b.type.gold * 0.75).round();
    b.pl.lumber += (b.type.lumber * 0.75).round();
    _kill(b, null, -1, silent: true);
  }

  bool cmdCast(Unit h, String abilityId, {Unit? target, double? x, double? y}) {
    final a = abilityTypes[abilityId]!;
    final lvl = h.abilityLevel(abilityId);
    if (lvl == 0 || a.passive || h.dead) return false;
    if (h.cooldownLeft(abilityId) > 0) {
      msg(h.owner, 'Yetenek henüz hazır değil.');
      return false;
    }
    if (h.mana < a.mana[lvl - 1]) {
      msg(h.owner, 'Yeterli mana yok.');
      return false;
    }
    if (a.target == TargetKind.unit) {
      if (target == null || target.dead || target.isBuilding) return false;
      if (a.targetAlly && target.owner != h.owner) {
        msg(h.owner, 'Dost bir birim hedeflenmeli.');
        return false;
      }
      if (!a.targetAlly && !isEnemy(h.owner, target.owner)) {
        msg(h.owner, 'Düşman bir birim hedeflenmeli.');
        return false;
      }
    }
    final wasAttackMove = h.order == Order.attackMove;
    final rx = h.tx, ry = h.ty;
    _setOrder(h, Order.cast);
    if (wasAttackMove) {
      h.resumeAttackMove = true;
      h.resumeX = rx;
      h.resumeY = ry;
    }
    h.castAbility = a;
    h.target = target;
    if (x != null && y != null) {
      h.tx = x;
      h.ty = y;
    }
    if (target != null && a.target == TargetKind.point) {
      h.tx = target.x;
      h.ty = target.y;
    }
    return true;
  }

  bool canLearn(Unit h, String abilityId) {
    final cur = h.abilityLevel(abilityId);
    return h.skillPoints > 0 && cur < 3 && h.level >= 1 + cur * 2;
  }

  bool cmdLearn(Unit h, String abilityId) {
    if (!canLearn(h, abilityId)) return false;
    h.abil[abilityId] = h.abilityLevel(abilityId) + 1;
    h.skillPoints--;
    _computeAuras();
    return true;
  }

  void cmdUseItem(Unit h, int slot) {
    final it = h.inv[slot];
    if (it == null || h.dead) return;
    if (!it.consumable) {
      msg(h.owner, '${it.name} pasif bir eşyadır.');
      return;
    }
    if (it.healHp > 0) {
      _heal(h, it.healHp);
      effects.add(Fx('holy', h.x, h.y, 0.8, radius: 26, color: const Color(0xFFFF8A80)));
    }
    if (it.healMana > 0) {
      h.mana = min(h.maxMana, h.mana + it.healMana);
      effects.add(Fx('holy', h.x, h.y, 0.8, radius: 26, color: const Color(0xFF82B1FF)));
    }
    h.inv[slot] = null;
  }

  void cmdDropItem(Unit h, int slot) {
    final it = h.inv[slot];
    if (it == null) return;
    h.inv[slot] = null;
    items.add(GroundItem(it, h.x + 18, h.y + 8));
  }

  void cmdPickup(Unit h, GroundItem it) {
    if (!h.isHero) return;
    _setOrder(h, Order.pickup);
    h.targetItem = it;
  }

  /// Bir oyuncu için yapı yeri bulur (YZ için).
  TilePos? findBuildSpot(int pid, UnitType t, double nearX, double nearY, {int minR = 4, int maxR = 16, Rect? avoid}) {
    final cx = (nearX / kTile).floor(), cy = (nearY / kTile).floor();
    for (var r = minR; r <= maxR; r++) {
      final cands = <TilePos>[];
      for (var y = cy - r; y <= cy + r; y++) {
        for (var x = cx - r; x <= cx + r; x++) {
          if (max((x - cx).abs(), (y - cy).abs()) != r) continue;
          cands.add(TilePos(x - t.size ~/ 2, y - t.size ~/ 2));
        }
      }
      cands.shuffle(rng);
      for (final c in cands) {
        if (!canPlace(t, c.x, c.y, pid)) continue;
        // Kenarlarda 1 karo boşluk bırak.
        var ok = true;
        for (var y = c.y - 1; y <= c.y + t.size && ok; y++) {
          for (var x = c.x - 1; x <= c.x + t.size; x++) {
            if (!map.inside(x, y) || map.occ[map.idx(x, y)] > 0) {
              ok = false;
              break;
            }
          }
        }
        if (!ok) continue;
        if (avoid != null &&
            avoid.overlaps(Rect.fromLTWH(c.x * kTile, c.y * kTile, t.size * kTile, t.size * kTile))) {
          continue;
        }
        return c;
      }
    }
    return null;
  }
}
