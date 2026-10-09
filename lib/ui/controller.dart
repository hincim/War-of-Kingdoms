import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart' show Colors, IconData, Icons;

import '../game/data.dart';
import '../game/entities.dart';
import '../game/game.dart';
import '../game/map.dart';
import '../render/world_painter.dart';

const double kTopBar = 36;
const double kBottomHud = 176;

/// Komut kartındaki tek bir düğme.
class Cmd {
  Cmd({
    required this.name,
    required this.hotkey,
    required this.onTap,
    this.icon,
    this.unitIcon,
    this.iconColor,
    this.desc = '',
    this.enabled = true,
    this.gold = 0,
    this.lumber = 0,
    this.food = 0,
    this.mana = 0,
    this.cooldown = 0,
    this.level = -1,
    this.maxLevel = 0,
    this.highlight = false,
  });

  final String name;
  final String hotkey;
  final void Function() onTap;
  final IconData? icon;
  final UnitType? unitIcon;
  final Color? iconColor;
  final String desc;
  final bool enabled;
  final int gold, lumber, food, mana;
  final double cooldown; // 0..1
  final int level, maxLevel;
  final bool highlight;
}

class GameController {
  GameController(this.game) {
    final hall = game.units.firstWhere((u) => u.owner == kPlayer && u.type.townHall);
    centerOn(hall.x, hall.y);
  }

  final Game game;
  final GameView view = GameView();
  String cardMode = 'main';
  String? targetAbility;
  final Map<int, List<Unit>> groups = {};
  bool paused = false;
  bool menuOpen = false;
  Size screen = const Size(1280, 800);

  /// Arayüzün üstte ve altta kapladığı alan (kamera sınırları için).
  double hudTop = kTopBar, hudBottom = kBottomHud;

  /// Dokunmatik mod: daha toleranslı seçim, yerleştirme onayı, daha büyük seçim sınırı.
  bool touch = false;
  int get maxSelection => touch ? 24 : 12;
  double _lastTapTime = -10;
  Unit? _lastTapUnit;
  int _lastGroup = -1;
  double _lastGroupTime = -10;
  int _idleIdx = 0;

  Player get me => game.me;
  List<Unit> get sel => view.selection;
  Unit? get primary => sel.isEmpty ? null : sel.first;
  bool get ownSelection => sel.isNotEmpty && sel.first.owner == kPlayer;

  // ------------------------------------------------------------ Kamera

  void centerOn(double x, double y) {
    view.camX = x - screen.width / (2 * view.zoom);
    view.camY = y - (screen.height - hudBottom + hudTop) / (2 * view.zoom);
    clampCamera();
  }

  void clampCamera() {
    final z = view.zoom;
    final maxX = kMapPx - screen.width / z;
    final maxY = kMapPx - (screen.height - hudBottom) / z;
    view.camX = view.camX.clamp(min(0.0, maxX), max(0.0, maxX));
    view.camY = view.camY.clamp(min(-hudTop / z, maxY), max(-hudTop / z, maxY));
  }

  void zoomAt(Offset screenPos, double factor) {
    final before = view.toWorld(screenPos);
    view.zoom = (view.zoom * factor).clamp(touch ? 0.5 : 0.55, touch ? 1.8 : 1.6);
    view.camX = before.dx - screenPos.dx / view.zoom;
    view.camY = before.dy - screenPos.dy / view.zoom;
    clampCamera();
  }

  // ------------------------------------------------------------ Seçim

  bool isVisible(Unit u) {
    if (u.owner == kPlayer) return true;
    if (u.isBuilding) return u.isMine ? game.fog.exploredTile(u.tileX + 1, u.tileY + 1) : u.seen;
    return game.fog.visibleAt(u.x, u.y);
  }

  Unit? pickVisible(Offset w) {
    final u = game.pick(w.dx, w.dy);
    if (u != null && isVisible(u)) return u;
    if (!touch) return null;
    // Parmakla dokunuş: yakındaki en yakın birimi kabul et.
    final tol = 26 / view.zoom;
    Unit? best;
    var bd = double.infinity;
    for (final o in game.units) {
      if (o.dead || o.hidden || !isVisible(o)) continue;
      double d;
      if (o.isBuilding) {
        final r = o.footprint.inflate(tol * 0.6);
        if (!r.contains(w)) continue;
        d = 1000 + (Offset(o.x, o.y) - w).distance;
      } else {
        d = (Offset(o.x, o.y - o.radius * 0.5) - w).distance - o.radius * 1.5;
        if (d > tol) continue;
      }
      if (d < bd) {
        bd = d;
        best = o;
      }
    }
    return best;
  }

  static int _rank(Unit u) {
    if (u.isHero) return 0;
    if (u.isBuilding) return 3;
    if (u.type.worker) return 2;
    return 1;
  }

  void select(List<Unit> us) {
    final list = us.where((u) => !u.dead).toList();
    list.sort((a, b) {
      final r = _rank(a).compareTo(_rank(b));
      if (r != 0) return r;
      return a.type.id.compareTo(b.type.id);
    });
    sel
      ..clear()
      ..addAll(list.take(maxSelection));
    cardMode = 'main';
    cancelModes();
  }

  void pruneSelection() {
    final before = sel.length;
    sel.removeWhere((u) => u.dead);
    if (sel.length != before && sel.isEmpty) cardMode = 'main';
    for (final g in groups.values) {
      g.removeWhere((u) => u.dead && !u.isHero);
    }
  }

  void cancelModes() {
    view.placing = null;
    view.targeting = null;
    targetAbility = null;
  }

  void boxSelect(Rect worldRect, {bool shift = false}) {
    final units = game.units
        .where(
          (u) =>
              u.owner == kPlayer &&
              !u.isBuilding &&
              !u.hidden &&
              worldRect.inflate(u.radius * 0.6).contains(Offset(u.x, u.y)),
        )
        .toList();
    if (units.isEmpty) {
      final bs = game.units
          .where((u) => u.owner == kPlayer && u.isBuilding && worldRect.overlaps(u.footprint))
          .toList();
      if (bs.isNotEmpty) {
        final t = bs.first.type;
        select(bs.where((b) => b.type == t).toList());
      } else if (!shift) {
        // boş kutu: seçimi koru
      }
      return;
    }
    if (shift && ownSelection) {
      final all = {...sel.where((u) => !u.isBuilding), ...units}.toList();
      select(all);
    } else {
      select(units);
    }
  }

  void selectSameTypeOnScreen(Unit u) {
    final vr = Rect.fromLTWH(view.camX, view.camY, screen.width / view.zoom, (screen.height - hudBottom) / view.zoom);
    select(
      game.units
          .where((o) => o.owner == kPlayer && o.type == u.type && !o.hidden && vr.contains(Offset(o.x, o.y)))
          .toList(),
    );
  }

  /// Tüm askeri birimleri (işçiler hariç) seçer.
  void selectArmy() {
    final army = game.units.where((u) => u.owner == kPlayer && !u.isBuilding && !u.type.worker && !u.hidden).toList();
    if (army.isEmpty) {
      game.msg(kPlayer, 'Henüz askeri biriminiz yok.');
      return;
    }
    select(army);
  }

  /// Dokunmatik ekranda tek dokunuş: seçim ya da bağlama göre emir.
  void tapWorld(Offset w, double now) {
    if (view.placing != null || view.targeting != null) {
      leftClickWorld(w);
      return;
    }
    final u = pickVisible(w);
    final dbl = u != null && u == _lastTapUnit && now - _lastTapTime < 0.4;
    _lastTapTime = now;
    _lastTapUnit = u;
    final commanding = ownSelection && sel.any((o) => !o.isBuilding);
    if (u != null && u.owner == kPlayer) {
      // İşçiler seçiliyken yarım kalmış binaya dokunmak inşaata yardım ettirir.
      if (commanding && u.isBuilding && u.constructing && sel.every((o) => o.type.worker)) {
        rightClickWorld(w);
        return;
      }
      if (dbl) {
        selectSameTypeOnScreen(u);
      } else {
        select([u]);
      }
      return;
    }
    if (commanding) {
      rightClickWorld(w);
      return;
    }
    select(u == null ? [] : [u]);
  }

  /// Dokunmatik yerleştirme: hayaletin bulunduğu yere inşa et.
  void confirmPlacement() {
    final m = view.mouse;
    if (view.placing == null || m == null) return;
    _placeBuilding(view.toWorld(m), false);
  }

  void leftClickWorld(Offset w, {bool shift = false, bool dbl = false, bool ctrl = false}) {
    if (view.placing != null) {
      _placeBuilding(w, shift);
      return;
    }
    if (view.targeting != null) {
      _executeTarget(w);
      return;
    }
    final u = pickVisible(w);
    if (u == null) {
      if (!shift) select([]);
      return;
    }
    if ((dbl || ctrl) && u.owner == kPlayer) {
      selectSameTypeOnScreen(u);
      return;
    }
    if (shift && u.owner == kPlayer && ownSelection && !u.isBuilding && !primary!.isBuilding) {
      if (sel.contains(u)) {
        final rest = sel.where((o) => o != u).toList();
        select(rest);
      } else {
        select([...sel, u]);
      }
      return;
    }
    select([u]);
  }

  void rightClickWorld(Offset w) {
    if (view.placing != null || view.targeting != null) {
      cancelModes();
      return;
    }
    if (!ownSelection) return;
    final clicked = pickVisible(w);
    GroundItem? item = game.itemAt(w.dx, w.dy);
    if (item != null && !game.fog.visibleAt(item.x, item.y)) item = null;
    final tx = (w.dx / kTile).floor(), ty = (w.dy / kTile).floor();
    final tree = game.map.isTree(tx, ty) && game.fog.exploredTile(tx, ty) ? TilePos(tx, ty) : null;
    game.cmdSmart(List.of(sel), w.dx, w.dy, clicked: clicked, item: item, tree: tree);
    final enemy = clicked != null && game.isEnemy(kPlayer, clicked.owner);
    view.markers.add(ClickMarker(w.dx, w.dy, enemy ? const Color(0xFFFF4040) : const Color(0xFF4CFF4C)));
  }

  void _placeBuilding(Offset w, bool shift) {
    final t = view.placing!;
    final builder = sel.firstWhere((u) => u.type.worker && u.owner == kPlayer && !u.dead, orElse: () => sel.first);
    final tp = view.placeTile(w, t);
    if (game.cmdBuild(builder, t, tp.x, tp.y)) {
      view.markers.add(ClickMarker(w.dx, w.dy, const Color(0xFF4CFF4C)));
      if (!shift) {
        view.placing = null;
        cardMode = 'main';
      }
    }
  }

  void _executeTarget(Offset w) {
    final mode = view.targeting!;
    final clicked = pickVisible(w);
    final units = sel.where((u) => u.owner == kPlayer && !u.dead).toList();
    switch (mode) {
      case 'move':
        game.cmdMove(units, w.dx, w.dy);
        view.markers.add(ClickMarker(w.dx, w.dy, const Color(0xFF4CFF4C)));
      case 'attack':
        if (clicked != null && clicked.owner != kPlayer && !clicked.isMine) {
          game.cmdAttack(units, clicked);
        } else {
          game.cmdMove(units, w.dx, w.dy, attack: true);
        }
        view.markers.add(ClickMarker(w.dx, w.dy, const Color(0xFFFF4040)));
      case 'gather':
        final tx = (w.dx / kTile).floor(), ty = (w.dy / kTile).floor();
        for (final u in units.where((u) => u.type.worker)) {
          if (clicked != null && clicked.isMine) {
            game.cmdGatherGold(u, clicked);
          } else if (game.map.isTree(tx, ty)) {
            game.cmdGatherWood(u, tx, ty);
          } else {
            final t = game.map.nearestTree(w.dx, w.dy, 3);
            if (t != null) {
              game.cmdGatherWood(u, t.x, t.y);
            } else {
              game.msg(kPlayer, 'Bir altın madeni ya da ağaç seçin.');
            }
          }
        }
        view.markers.add(ClickMarker(w.dx, w.dy, const Color(0xFFFFEB3B)));
      case 'rally':
        final tx = (w.dx / kTile).floor(), ty = (w.dy / kTile).floor();
        final tree = game.map.isTree(tx, ty) ? TilePos(tx, ty) : null;
        game.cmdSmart(sel.where((u) => u.isBuilding).toList(), w.dx, w.dy, clicked: clicked, tree: tree);
      case 'ability':
        final h = units.firstWhere((u) => u.isHero, orElse: () => units.first);
        final a = abilityTypes[targetAbility]!;
        if (a.target == TargetKind.unit) {
          if (clicked == null) {
            game.msg(kPlayer, 'Bir birim hedeflenmeli.');
            return;
          }
          game.cmdCast(h, a.id, target: clicked);
        } else {
          game.cmdCast(h, a.id, x: w.dx, y: w.dy, target: clicked != null && !clicked.isBuilding ? clicked : null);
        }
        view.markers.add(ClickMarker(w.dx, w.dy, a.color));
      case 'item':
        break;
    }
    cancelModes();
  }

  // ------------------------------------------------------------ Kontrol grupları

  void setGroup(int n) {
    if (!ownSelection) return;
    groups[n] = List.of(sel);
    game.msg(kPlayer, 'Grup $n atandı.', color: const Color(0xFFB3E5FC));
  }

  void recallGroup(int n) {
    final g = groups[n];
    if (g == null) return;
    final alive = g.where((u) => !u.dead).toList();
    if (alive.isEmpty) return;
    if (_lastGroup == n && game.time - _lastGroupTime < 0.5 && game.time >= _lastGroupTime) {
      centerOn(alive.first.x, alive.first.y);
    }
    _lastGroup = n;
    _lastGroupTime = game.time;
    select(alive);
  }

  List<Unit> get myHeroes {
    final list = game.units.where((u) => u.owner == kPlayer && u.isHero).toList();
    list.addAll(me.deadHeroes);
    return list;
  }

  void selectHero(int i, {bool center = false}) {
    final hs = myHeroes;
    if (i >= hs.length) return;
    final h = hs[i];
    if (h.dead) {
      game.msg(kPlayer, '${h.heroName} ölü. Sunakta diriltebilirsiniz.');
      return;
    }
    if (center || (sel.length == 1 && sel.first == h)) centerOn(h.x, h.y);
    select([h]);
  }

  List<Unit> get idleWorkers =>
      game.units.where((u) => u.owner == kPlayer && u.type.worker && u.order == Order.idle && !u.dead).toList();

  void selectIdleWorker() {
    final ws = idleWorkers;
    if (ws.isEmpty) return;
    _idleIdx = (_idleIdx + 1) % ws.length;
    final w = ws[_idleIdx];
    select([w]);
    centerOn(w.x, w.y);
  }

  // ------------------------------------------------------------ Komut kartı

  List<Cmd?> commandCard() {
    final card = List<Cmd?>.filled(12, null);
    if (!ownSelection) return card;
    final p = primary!;
    final cancel = Cmd(
      name: 'İptal',
      hotkey: 'Esc',
      icon: Icons.close,
      iconColor: const Color(0xFFFF8A80),
      desc: 'Geçerli işlemi iptal eder.',
      onTap: () {
        cancelModes();
        cardMode = 'main';
      },
    );
    if (view.targeting != null || view.placing != null) {
      final pl = view.placing;
      if (touch && pl != null && view.mouse != null) {
        final tp = view.placeTile(view.toWorld(view.mouse!), pl);
        card[10] = Cmd(
          name: 'Buraya Yerleştir',
          hotkey: 'Y',
          icon: Icons.check_circle,
          iconColor: const Color(0xFF8BC34A),
          desc: 'Yapıyı gösterilen yere kurar. Yeri değiştirmek için parmağınızı sürükleyin ya da istediğiniz yere dokunun.',
          enabled: game.canPlace(pl, tp.x, tp.y, kPlayer),
          highlight: true,
          onTap: confirmPlacement,
        );
      }
      card[11] = cancel;
      return card;
    }
    if (p.isBuilding) {
      _buildingCard(p, card);
      return card;
    }
    final units = sel.where((u) => !u.isBuilding).toList();
    if (cardMode == 'build' && p.type.worker) {
      final f = me.faction!;
      final slots = [0, 1, 2, 3, 4, 5];
      final list = f.buildings;
      for (var i = 0; i < list.length; i++) {
        final t = ut(list[i]);
        final ok = me.gold >= t.gold && me.lumber >= t.lumber;
        card[slots[i]] = Cmd(
          name: t.name,
          hotkey: t.hotkey,
          unitIcon: t,
          desc: t.desc,
          gold: t.gold,
          lumber: t.lumber,
          enabled: ok,
          onTap: () {
            if (!game.canAfford(me, t.gold, t.lumber)) return;
            view.placing = t;
            if (touch) view.mouse = Offset(screen.width / 2, (screen.height - hudBottom + hudTop) / 2);
          },
        );
      }
      card[11] = cancel;
      return card;
    }
    if (cardMode == 'learn' && p.isHero) {
      for (var i = 0; i < p.type.abilities.length; i++) {
        final aid = p.type.abilities[i];
        final a = abilityTypes[aid]!;
        final cur = p.abilityLevel(aid);
        final can = game.canLearn(p, aid);
        card[8 + i] = Cmd(
          name: '${a.name} öğren (Seviye ${cur + 1})',
          hotkey: a.hotkey,
          icon: a.icon,
          iconColor: a.color,
          desc: cur >= 3
              ? 'En yüksek seviyede.'
              : '${a.describe(cur + 1)}${p.level < 1 + cur * 2 ? '\nGereken kahraman seviyesi: ${1 + cur * 2}' : ''}',
          enabled: can,
          level: cur,
          maxLevel: 3,
          highlight: can,
          onTap: () {
            if (!game.cmdLearn(p, aid)) return;
            if (p.skillPoints == 0) cardMode = 'main';
          },
        );
      }
      card[11] = cancel;
      return card;
    }
    card[0] = Cmd(
      name: 'Hareket Et',
      hotkey: 'M',
      icon: Icons.directions_walk,
      desc: 'Seçili birimleri hedef noktaya yürütür.',
      onTap: () => view.targeting = 'move',
    );
    card[1] = Cmd(
      name: 'Dur',
      hotkey: 'S',
      icon: Icons.pan_tool,
      desc: 'Birimlerin mevcut emirlerini iptal eder.',
      onTap: () => game.cmdStop(units),
    );
    card[2] = Cmd(
      name: 'Pozisyonu Koru',
      hotkey: 'H',
      icon: Icons.shield_outlined,
      desc: 'Birimler yerinden ayrılmadan menzildeki düşmanlara saldırır.',
      onTap: () => game.cmdHold(units),
    );
    if (units.any((u) => u.type.canAttack)) {
      card[3] = Cmd(
        name: 'Saldır',
        hotkey: 'A',
        icon: Icons.gps_fixed,
        iconColor: const Color(0xFFFF8A80),
        desc: 'Bir hedefe saldırır ya da yol boyunca karşılaşılan düşmanlarla savaşarak ilerler.',
        onTap: () => view.targeting = 'attack',
      );
    }
    if (p.type.worker) {
      card[4] = Cmd(
        name: 'Topla',
        hotkey: 'G',
        icon: Icons.agriculture,
        iconColor: const Color(0xFFFFD54F),
        desc: 'Altın madeninden altın ya da ağaçlardan odun toplar.',
        onTap: () => view.targeting = 'gather',
      );
      card[5] = Cmd(
        name: 'İnşa Et',
        hotkey: 'B',
        icon: Icons.construction,
        iconColor: const Color(0xFFFFB74D),
        desc: 'Yapı inşa etme menüsünü açar.',
        onTap: () => cardMode = 'build',
      );
      if (p.carryGold > 0 || p.carryWood > 0) {
        card[6] = Cmd(
          name: 'Kaynağı Teslim Et',
          hotkey: 'R',
          icon: Icons.home,
          desc: 'Taşınan kaynakları en yakın ana binaya götürür.',
          onTap: () {
            for (final u in units) {
              game.cmdReturnCargo(u);
            }
          },
        );
      }
    }
    if (p.isHero) {
      if (p.skillPoints > 0) {
        card[7] = Cmd(
          name: 'Yetenek Öğren (${p.skillPoints} puan)',
          hotkey: 'O',
          icon: Icons.add_circle,
          iconColor: const Color(0xFFFFE082),
          desc: 'Kahraman yeteneği öğrenmek için yetenek puanı harcayın.',
          highlight: true,
          onTap: () => cardMode = 'learn',
        );
      }
      for (var i = 0; i < p.type.abilities.length; i++) {
        final aid = p.type.abilities[i];
        final a = abilityTypes[aid]!;
        final lvl = p.abilityLevel(aid);
        final cd = p.cooldownLeft(aid);
        final maxCd = lvl > 0 ? a.cooldown[lvl - 1] : 1;
        card[8 + i] = Cmd(
          name: a.passive ? '${a.name} (pasif)' : a.name,
          hotkey: a.hotkey,
          icon: a.icon,
          iconColor: a.color,
          desc: lvl == 0 ? '${a.describe(1)}\nHenüz öğrenilmedi.' : a.describe(lvl),
          mana: lvl > 0 && !a.passive ? a.mana[lvl - 1].round() : 0,
          enabled: lvl > 0 && !a.passive && p.mana >= (lvl > 0 ? a.mana[lvl - 1] : 0),
          cooldown: cd > 0 && maxCd > 0 ? cd / maxCd : 0,
          level: lvl,
          maxLevel: 3,
          onTap: () {
            if (lvl == 0 || a.passive) return;
            if (a.target == TargetKind.none) {
              game.cmdCast(p, aid);
            } else {
              if (cd > 0) {
                game.msg(kPlayer, 'Yetenek henüz hazır değil.');
                return;
              }
              if (p.mana < a.mana[lvl - 1]) {
                game.msg(kPlayer, 'Yeterli mana yok.');
                return;
              }
              view.targeting = 'ability';
              targetAbility = aid;
            }
          },
        );
      }
    }
    return card;
  }

  void _buildingCard(Unit b, List<Cmd?> card) {
    if (b.isMine) return;
    if (b.constructing) {
      card[11] = Cmd(
        name: 'İnşaatı İptal Et',
        hotkey: 'Esc',
        icon: Icons.close,
        iconColor: const Color(0xFFFF8A80),
        desc: 'Harcanan kaynakların %75\'ini geri verir.',
        onTap: () => game.cmdCancelConstruction(b),
      );
      return;
    }
    final same = sel.where((o) => o.type == b.type && !o.constructing).toList();
    Unit best() {
      same.sort((a, c) => a.queue.length.compareTo(c.queue.length));
      return same.first;
    }

    var slot = 0;
    for (final id in b.type.trains) {
      final t = ut(id);
      final req = game.meetsReq(me, t);
      final heroBlocked = t.hero && (game.hasHeroType(kPlayer, id) || game.heroCount(kPlayer) >= kMaxHeroes);
      var desc = t.desc;
      if (!req) desc += '\nGereksinim: ${t.requires.map((r) => ut(r).name).join(', ')}';
      if (t.hero) {
        desc += '\nYetenekler: ${t.abilities.map((a) => abilityTypes[a]!.name).join(', ')}';
        if (heroBlocked) desc += '\n(Zaten sahipsiniz ya da kahraman sınırına ulaştınız)';
      }
      if (t.canAttack) {
        desc += '\nCan ${t.hp.round()} · Hasar ${t.dmgMin.round()}-${t.dmgMax.round()} · Zırh ${fmtNum(t.armor)}';
      }
      card[slot++] = Cmd(
        name: t.name,
        hotkey: t.hotkey,
        unitIcon: t,
        desc: desc,
        gold: t.gold,
        lumber: t.lumber,
        food: t.food,
        enabled: req && !heroBlocked && me.gold >= t.gold && me.lumber >= t.lumber,
        onTap: () => game.cmdTrain(best(), id),
      );
    }
    for (final id in b.type.researches) {
      final up = upgradeTypes[id]!;
      var lvl = me.upgrade(id);
      for (final u in game.units) {
        if (u.owner != kPlayer) continue;
        for (final q in u.queue) {
          if (q.kind == 'research' && q.upgrade!.id == id) lvl++;
        }
      }
      final maxed = lvl >= up.maxLevel;
      card[slot++] = Cmd(
        name: maxed ? '${up.name} (tamamlandı)' : '${up.name} (Seviye ${lvl + 1})',
        hotkey: up.hotkey,
        icon: up.icon,
        iconColor: const Color(0xFFB0BEC5),
        desc: up.desc,
        gold: maxed ? 0 : up.gold[lvl],
        lumber: maxed ? 0 : up.lumber[lvl],
        enabled: !maxed && me.gold >= up.gold[min(lvl, up.maxLevel - 1)],
        level: me.upgrade(id),
        maxLevel: up.maxLevel,
        onTap: () => game.cmdResearch(b, id),
      );
    }
    if (b.type.altar) {
      var s = 4;
      for (final h in me.deadHeroes) {
        if (s > 6) break;
        final cost = game.reviveCost(h);
        card[s++] = Cmd(
          name: '${h.heroName} dirilt (Seviye ${h.level})',
          hotkey: s == 5 ? 'D' : 'E',
          unitIcon: h.type,
          iconColor: Colors.grey,
          desc: 'Ölen kahramanı tüm canı ve manasıyla geri getirir.',
          gold: cost,
          food: h.type.food,
          enabled: me.gold >= cost,
          onTap: () => game.cmdRevive(b, h),
        );
      }
    }
    if (b.type.trains.isNotEmpty) {
      card[8] = Cmd(
        name: 'Toplanma Noktası',
        hotkey: 'Y',
        icon: Icons.flag,
        iconColor: const Color(0xFF8BC34A),
        desc: 'Yeni birimlerin gideceği noktayı belirler. (Sağ tık ile de ayarlanır; işçiler için maden/ağaç seçilebilir.)',
        onTap: () => view.targeting = 'rally',
      );
    }
  }

  /// Klavye kısayolu. İşlendiyse true.
  bool hotkey(String key) {
    for (final c in commandCard()) {
      if (c != null && c.hotkey.toUpperCase() == key.toUpperCase()) {
        c.onTap();
        return true;
      }
    }
    return false;
  }

  bool escape() {
    if (view.placing != null || view.targeting != null) {
      cancelModes();
      return true;
    }
    if (cardMode != 'main') {
      cardMode = 'main';
      return true;
    }
    final p = primary;
    if (p != null && p.isBuilding && p.owner == kPlayer && p.constructing) {
      game.cmdCancelConstruction(p);
      return true;
    }
    if (p != null && p.isBuilding && p.owner == kPlayer && p.queue.isNotEmpty) {
      game.cmdCancelQueue(p, p.queue.length - 1);
      return true;
    }
    return false;
  }
}
