import 'dart:math';
import 'dart:ui' show Color, Offset, Rect;

import 'data.dart';

enum Order { idle, move, attackMove, attack, hold, gather, build, construct, cast, pickup, leash }

class Player {
  Player(this.id, this.faction, {this.isAI = false, required this.name})
      : color = playerColors[id];

  final int id;
  final Faction? faction;
  final bool isAI;
  final String name;
  final Color color;
  int gold = 0;
  int lumber = 0;
  int foodUsed = 0;
  int foodCap = 0;
  final Map<String, int> upgrades = {};
  final List<Unit> deadHeroes = [];
  double gatherMult = 1;
  bool defeated = false;

  // İstatistikler
  int unitsTrained = 0;
  int kills = 0;
  int unitsLost = 0;
  int goldMined = 0;
  int lumberMined = 0;

  int upgrade(String id) => upgrades[id] ?? 0;
}

class QueueItem {
  QueueItem.unit(UnitType this.unitType)
      : kind = 'unit',
        upgrade = null,
        hero = null,
        time = unitType.buildTime,
        gold = unitType.gold,
        lumber = unitType.lumber;
  QueueItem.research(UpgradeType this.upgrade, int level)
      : kind = 'research',
        unitType = null,
        hero = null,
        time = upgrade.time[level],
        gold = upgrade.gold[level],
        lumber = upgrade.lumber[level];
  QueueItem.revive(Unit this.hero, this.gold, this.time)
      : kind = 'revive',
        unitType = hero.type,
        upgrade = null,
        lumber = 0;

  final String kind;
  final UnitType? unitType;
  final UpgradeType? upgrade;
  final Unit? hero;
  final double time;
  final int gold, lumber;
  double progress = 0;

  int get food => kind == 'research' ? 0 : unitType!.food;
}

class Unit {
  Unit(this.type, this.owner, this.pl, this.x, this.y)
      : id = _nextId++,
        hp = type.hp,
        mana = type.mana,
        homeX = x,
        homeY = y {
    if (type.hero) mana = type.mana;
  }

  static int _nextId = 1;

  final int id;
  UnitType type;
  int owner;
  Player pl;
  double x, y;
  double hp;
  double mana;
  double facing = pi / 2;
  bool dead = false;
  bool hidden = false;
  bool seen = false; // oyuncu tarafından görüldü mü (binalar için)

  // Emir
  Order order = Order.idle;
  Unit? target;
  double tx = 0, ty = 0;
  UnitType? buildType;
  int buildTx = 0, buildTy = 0;
  AbilityType? castAbility;
  GroundItem? targetItem;
  bool queuedAttackMove = false;

  // Hareket
  List<Offset>? path;
  int pathI = 0;
  double repath = 0;
  double stuck = 0;
  bool moving = false;
  double walkAnim = 0;

  // Savaş
  double atkCd = 0;
  double attackAt = -10;
  double swing = 0;
  double swingDur = 0.3;
  Unit? swingTarget;
  Unit? engaged; // saldırı-hareket veya boşta iken seçilen hedef
  double acquireTimer = 0;
  bool resumeAttackMove = false;
  double resumeX = 0, resumeY = 0;
  double stuckTotal = 0;
  Unit? lastAttacker;
  double lastHurt = -100;

  // Durumlar
  double stun = 0;
  double expire = 0;
  double extraHp = 0, extraDmg = 0;
  double auraArmor = 0, auraMana = 0, auraSpeed = 0, auraAtk = 0;

  // İşçi
  int carryGold = 0, carryWood = 0;
  Unit? mine;
  int treeX = -1, treeY = -1;
  String gatherKind = '';
  int gatherPhase = 0;
  double gatherTimer = 0;
  String lastGatherKind = '';

  // Bina
  bool constructing = false;
  double progress = 0;
  int tileX = 0, tileY = 0;
  final List<QueueItem> queue = [];
  double? rallyX, rallyY;
  Unit? rallyUnit;
  int rallyTreeX = -1, rallyTreeY = -1;
  int goldLeft = 0;
  int builders = 0;

  // Kahraman
  String heroName = '';
  int level = 1;
  int xp = 0;
  int skillPoints = 0;
  final Map<String, int> abil = {};
  final Map<String, double> cds = {};
  final List<ItemType?> inv = List.filled(6, null);

  // Tarafsız
  int camp = -1;
  double homeX, homeY;

  int get size => type.size;
  double get radius => type.building ? type.size * kTile / 2 : type.radius;
  bool get isBuilding => type.building;
  bool get isHero => type.hero;
  bool get isMine => type.isMine;
  bool get alive => !dead;
  bool get completed => !constructing;

  Rect get footprint => Rect.fromLTWH(tileX * kTile, tileY * kTile, size * kTile, size * kTile);

  bool get _upg => !type.building && !type.hero && !type.worker && !type.summon && !type.creep;

  double _itemSum(double Function(ItemType) f) {
    var s = 0.0;
    for (final i in inv) {
      if (i != null) s += f(i);
    }
    return s;
  }

  double get maxHp =>
      type.hp + extraHp + (type.hero ? (level - 1) * type.hpPerLvl + _itemSum((i) => i.hp) : 0);
  double get maxMana => type.mana + (type.hero ? (level - 1) * type.manaPerLvl : 0);
  double get armor =>
      type.armor +
      (type.hero ? (level - 1) * type.armorPerLvl + _itemSum((i) => i.armor) : 0) +
      (_upg ? pl.upgrade('armor') * 2 : 0) +
      auraArmor;
  double get dmgBonus =>
      extraDmg +
      (type.hero ? (level - 1) * type.dmgPerLvl + _itemSum((i) => i.dmg) : 0) +
      (_upg ? pl.upgrade('weapons') * 2 : 0);
  double get dmgMin => type.dmgMin + dmgBonus;
  double get dmgMax => type.dmgMax + dmgBonus;
  double get speed =>
      (type.speed + (type.hero ? _itemSum((i) => i.speed) : 0)) * (1 + auraSpeed / 100);
  double get cooldown => type.cooldown / (1 + auraAtk / 100);
  double get range => type.range;
  double get manaRegen => type.manaRegen + auraMana;

  int abilityLevel(String id) => abil[id] ?? 0;
  double cooldownLeft(String id) => cds[id] ?? 0;

  bool get gathering => order == Order.gather;
}

class Projectile {
  Projectile({
    required this.kind,
    required this.x,
    required this.y,
    required this.target,
    required this.speed,
    required this.onHit,
    required this.owner,
  })  : sx = x,
        sy = y;

  final String kind;
  double x, y;
  final double sx, sy;
  final Unit target;
  final double speed;
  final int owner;
  final void Function() onHit;
  double tx = 0, ty = 0;
  bool done = false;
  double age = 0;
}

/// Görsel efekt.
class Fx {
  Fx(this.kind, this.x, this.y, this.dur, {this.radius = 20, this.color, this.pts, this.x2 = 0, this.y2 = 0});

  final String kind;
  final double x, y, x2, y2;
  final double dur;
  final double radius;
  final Color? color;
  final List<Offset>? pts;
  double t = 0;
  double get p => (t / dur).clamp(0.0, 1.0);
}

/// Süreli alan etkisi (ör. Kar Fırtınası).
class AreaEffect {
  AreaEffect(this.kind, this.x, this.y, this.radius, this.waves, this.dmg, this.owner, this.source);

  final String kind;
  final double x, y, radius;
  int waves;
  final double dmg;
  final int owner;
  final Unit? source;
  double timer = 0.4;
  double age = 0;
}

class FloatText {
  FloatText(this.text, this.x, this.y, this.color, {this.dur = 1.6, this.size = 13});
  final String text;
  final double x, y;
  final Color color;
  final double dur;
  final double size;
  double t = 0;
}

class GroundItem {
  GroundItem(this.type, this.x, this.y);
  final ItemType type;
  final double x, y;
  bool taken = false;
}

class Corpse {
  Corpse(this.type, this.color, this.x, this.y, this.facing);
  final UnitType type;
  final Color color;
  final double x, y, facing;
  double t = 0;
}

class GameMessage {
  GameMessage(this.text, this.time, {this.color = const Color(0xFFFFD54F)});
  final String text;
  final double time;
  final Color color;
}

class Ping {
  Ping(this.x, this.y, this.time, this.color);
  final double x, y, time;
  final Color color;
}

class ClickMarker {
  ClickMarker(this.x, this.y, this.color);
  final double x, y;
  final Color color;
  double t = 0;
}
