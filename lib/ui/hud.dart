import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/data.dart';
import '../game/entities.dart';
import '../game/game.dart';
import '../game/map.dart';
import '../render/sprites.dart';
import '../render/world_painter.dart';
import 'controller.dart';

const Color kGold = Color(0xFFFFD98A);
const Color kBorder = Color(0xFF9C7A45);
const Color kPanelTop = Color(0xFF33261A);
const Color kPanelBottom = Color(0xFF15100A);

BoxDecoration panelDeco({double radius = 6, bool glow = false}) => BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [kPanelTop, kPanelBottom],
      ),
      border: Border.all(color: glow ? const Color(0xFFFFD54F) : kBorder, width: 2),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
    );

const TextStyle kTextShadow = TextStyle(
  color: Colors.white,
  shadows: [Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, 1))],
);

// ---------------------------------------------------------------- Simgeler

class UnitIconPainter extends CustomPainter {
  UnitIconPainter(this.type, this.color, {this.time = 0});
  final UnitType type;
  final Color color;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (type.building) {
      final s = type.size * kTile;
      final scale = min(size.width, size.height) / (s * 1.5);
      canvas.translate(size.width / 2 - s * scale / 2, size.height * 0.6 - s * scale / 2);
      canvas.scale(scale);
      Sprites.building(canvas, type, color, s, s, time: time);
    } else {
      final r = type.radius;
      final big = type.id == 'c_dragon' || type.id == 'h_knight' || type.id == 'o_raider' || type.id == 'o_wolf';
      final scale = min(size.width, size.height) / (r * (big ? 4.6 : 3.4));
      canvas.translate(size.width / 2, size.height * 0.74);
      canvas.scale(scale);
      Sprites.unit(canvas, type, color, facing: pi / 2 - 0.4, time: time);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant UnitIconPainter old) => old.type != type || old.color != color || old.time != time;
}

Widget unitIcon(UnitType t, Color color, double size, {bool grey = false, double time = 0}) {
  Widget w = CustomPaint(size: Size(size, size), painter: UnitIconPainter(t, color, time: time));
  if (grey) {
    w = ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.33, 0.33, 0.33, 0, 0, //
        0.33, 0.33, 0.33, 0, 0, //
        0.33, 0.33, 0.33, 0, 0, //
        0, 0, 0, 1, 0,
      ]),
      child: w,
    );
  }
  return w;
}

BoxDecoration iconBox({bool highlight = false}) => BoxDecoration(
      gradient: const RadialGradient(colors: [Color(0xFF3A4A3A), Color(0xFF101410)]),
      border: Border.all(color: highlight ? const Color(0xFFFFD54F) : const Color(0xFF6B5534), width: highlight ? 2 : 1.5),
      borderRadius: BorderRadius.circular(4),
      boxShadow: highlight ? const [BoxShadow(color: Color(0x88FFD54F), blurRadius: 8)] : null,
    );

// ---------------------------------------------------------------- Üst çubuk

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.c, required this.onMenu, required this.onPause});
  final GameController c;
  final VoidCallback onMenu;
  final VoidCallback onPause;

  Widget _res(IconData icon, Color col, String text, {Color textColor = Colors.white, String tip = ''}) {
    return Tooltip(
      message: tip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: col, size: 18),
          const SizedBox(width: 5),
          Text(text, style: kTextShadow.copyWith(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(4),
            color: const Color(0xFF241A11),
          ),
          child: Text(label, style: const TextStyle(color: kGold, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final me = c.me;
    final g = c.game;
    final night = g.isNight;
    final full = me.foodUsed >= me.foodCap;
    return Container(
      height: kTopBar,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kPanelTop, kPanelBottom]),
        border: Border(bottom: BorderSide(color: kBorder, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        _btn('Menü (F10)', onMenu),
        const SizedBox(width: 8),
        _btn(c.paused ? 'Devam' : 'Duraklat', onPause),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _res(Icons.monetization_on, const Color(0xFFFFC107), '${me.gold}', tip: 'Altın'),
              _res(Icons.forest, const Color(0xFF8BC34A), '${me.lumber}', tip: 'Odun'),
              _res(Icons.restaurant, const Color(0xFFFFAB91), '${me.foodUsed}/${me.foodCap}',
                  textColor: full ? const Color(0xFFFF6E6E) : Colors.white, tip: 'Yiyecek (kullanılan / sınır)'),
            ]),
          ),
        ),
        Icon(night ? Icons.nightlight_round : Icons.wb_sunny,
            color: night ? const Color(0xFF90CAF9) : const Color(0xFFFFD54F), size: 18),
        const SizedBox(width: 6),
        Text(g.clockText, style: kTextShadow.copyWith(color: kGold, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(width: 14),
        Text(fmtClock(g.time), style: kTextShadow.copyWith(color: Colors.white70, fontSize: 13)),
        const SizedBox(width: 8),
      ]),
    );
  }
}

String fmtClock(double t) {
  final m = t ~/ 60, s = (t % 60).floor();
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------- Kahraman çubuğu

class HeroBar extends StatelessWidget {
  const HeroBar({super.key, required this.c, required this.onChanged});
  final GameController c;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final heroes = c.myHeroes;
    final idle = c.idleWorkers.length;
    final g = c.game;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < heroes.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Tooltip(
            message: '${heroes[i].heroName} - ${heroes[i].type.name} (F${i + 1})',
            child: GestureDetector(
              onTap: () {
                c.selectHero(i);
                onChanged();
              },
              onDoubleTap: () {
                c.selectHero(i, center: true);
                onChanged();
              },
              child: Container(
                width: 58,
                decoration: panelDeco(radius: 4, glow: heroes[i].skillPoints > 0 && !heroes[i].dead),
                padding: const EdgeInsets.all(2),
                child: Column(children: [
                  Stack(children: [
                    Container(
                      decoration: iconBox(),
                      child: unitIcon(heroes[i].type, c.me.color, 50, grey: heroes[i].dead, time: g.time),
                    ),
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(3)),
                        child: Text('${heroes[i].level}', style: const TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (heroes[i].dead)
                      const Positioned.fill(child: Center(child: Icon(Icons.close, color: Color(0xCCFF5252), size: 30))),
                    if (heroes[i].skillPoints > 0 && !heroes[i].dead)
                      const Positioned(left: 1, top: 1, child: Icon(Icons.add_circle, color: Color(0xFFFFD54F), size: 14)),
                  ]),
                  const SizedBox(height: 2),
                  _bar(heroes[i].dead ? 0 : heroes[i].hp / heroes[i].maxHp, const Color(0xFF4CFF4C)),
                  const SizedBox(height: 1),
                  _bar(heroes[i].dead ? 0 : heroes[i].mana / max(1, heroes[i].maxMana), const Color(0xFF42A5F5)),
                ]),
              ),
            ),
          ),
        ),
      if (idle > 0)
        Tooltip(
          message: 'Boştaki işçiler (F8)',
          child: GestureDetector(
            onTap: () {
              c.selectIdleWorker();
              onChanged();
            },
            child: Container(
              width: 58,
              height: 58,
              decoration: panelDeco(radius: 4),
              child: Stack(children: [
                Center(child: unitIcon(ut(c.me.faction!.worker), c.me.color, 46)),
                Positioned(
                  right: 3,
                  bottom: 2,
                  child: Text('$idle', style: kTextShadow.copyWith(color: kGold, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ]),
            ),
          ),
        ),
    ]);
  }
}

Widget _bar(double ratio, Color col, {double height = 4}) => Container(
      height: height,
      decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.black, width: 0.5)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: ratio.clamp(0.0, 1.0),
        child: Container(color: col),
      ),
    );

// ---------------------------------------------------------------- Mesajlar

class MessageList extends StatelessWidget {
  const MessageList({super.key, required this.c});
  final GameController c;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final hint = switch (c.view.targeting) {
      'move' => 'Hedef noktayı seçin (sağ tık: iptal)',
      'attack' => 'Saldırılacak hedefi ya da noktayı seçin (sağ tık: iptal)',
      'gather' => 'Altın madeni ya da ağaç seçin (sağ tık: iptal)',
      'rally' => 'Toplanma noktasını seçin (sağ tık: iptal)',
      'ability' => '${abilityTypes[c.targetAbility]?.name ?? ''}: hedef seçin (sağ tık: iptal)',
      _ => c.view.placing != null ? '${c.view.placing!.name}: yer seçin (Shift ile birden fazla, sağ tık: iptal)' : null,
    };
    return IgnorePointer(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final m in g.messages)
          Text(
            m.text,
            textAlign: TextAlign.center,
            style: kTextShadow.copyWith(
              color: m.color.withValues(alpha: (1 - max(0.0, g.time - m.time - 4) / 2).clamp(0.0, 1.0)),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(hint, style: kTextShadow.copyWith(color: const Color(0xFFB3E5FC), fontSize: 14)),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Mini harita

class MinimapBase {
  ui.Image? image;
  int _ver = -1;
  bool _busy = false;
  double _last = -10;

  void update(Game g) {
    if (_busy || g.map.treeVersion == _ver) return;
    if (image != null && g.time - _last < 2) return;
    _busy = true;
    _last = g.time;
    final v = g.map.treeVersion;
    final m = g.map;
    final px = Uint8List(kMapW * kMapH * 4);
    for (var i = 0; i < kMapW * kMapH; i++) {
      Color c;
      if (m.wood[i] > 0) {
        c = const Color(0xFF1C4413);
      } else if (m.terrain[i] == tWater) {
        c = const Color(0xFF2B6E96);
      } else if (m.terrain[i] == tDirt) {
        c = const Color(0xFF7E6038);
      } else {
        c = const Color(0xFF4B7A2C);
      }
      px[i * 4] = (c.r * 255).round();
      px[i * 4 + 1] = (c.g * 255).round();
      px[i * 4 + 2] = (c.b * 255).round();
      px[i * 4 + 3] = 255;
    }
    ui.decodeImageFromPixels(px, kMapW, kMapH, ui.PixelFormat.rgba8888, (img) {
      image?.dispose();
      image = img;
      _ver = v;
      _busy = false;
    });
  }

  void reset() {
    _ver = -1;
    _last = -10;
  }

  void dispose() => image?.dispose();
}

class MinimapPainter extends CustomPainter {
  MinimapPainter(this.c, this.base, this.fog, {super.repaint});
  final GameController c;
  final MinimapBase base;
  final FogImage fog;

  @override
  void paint(Canvas canvas, Size size) {
    final g = c.game;
    final s = size.width / kMapPx;
    canvas.drawRect(Offset.zero & size, fillP(Colors.black));
    final img = base.image;
    final dst = Offset.zero & size;
    final p = Paint()..filterQuality = FilterQuality.low;
    if (img != null) {
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, kMapW.toDouble(), kMapH.toDouble()), dst, p);
    }
    for (final u in g.units) {
      if (u.dead || u.hidden || !c.isVisible(u)) continue;
      Color col;
      if (u.isMine) {
        col = const Color(0xFFFFD54F);
      } else if (u.owner == kCreeps) {
        col = const Color(0xFFE6B800);
      } else {
        col = u.pl.color;
        if (u.owner == kPlayer) col = shade(col, 0.15);
      }
      if (u.isBuilding) {
        final r = u.footprint;
        canvas.drawRect(Rect.fromLTWH(r.left * s, r.top * s, max(3, r.width * s), max(3, r.height * s)), fillP(col));
      } else {
        final sz = u.isHero ? 4.5 : 3.0;
        canvas.drawRect(Rect.fromCenter(center: Offset(u.x * s, u.y * s), width: sz, height: sz), fillP(col));
      }
    }
    final fi = fog.image;
    if (fi != null && !g.fog.revealAll) {
      canvas.drawImageRect(fi, Rect.fromLTWH(0, 0, kMapW.toDouble(), kMapH.toDouble()), dst, p);
    }
    for (final pg in g.pings) {
      final ph = (g.time - pg.time) % 1.0;
      canvas.drawCircle(Offset(pg.x * s, pg.y * s), 4 + ph * 12, strokeP(pg.color.withValues(alpha: 1 - ph), 2));
    }
    final v = c.view;
    final vr = Rect.fromLTWH(v.camX * s, v.camY * s, c.screen.width / v.zoom * s, (c.screen.height - kBottomHud + kTopBar) / v.zoom * s);
    canvas.drawRect(vr, strokeP(Colors.white, 1.2));
  }

  @override
  bool shouldRepaint(covariant MinimapPainter oldDelegate) => true;
}

class MinimapView extends StatelessWidget {
  const MinimapView({super.key, required this.c, required this.base, required this.fog, required this.repaint, required this.onChanged});
  final GameController c;
  final MinimapBase base;
  final FogImage fog;
  final Listenable repaint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      final size = min(cons.maxWidth, cons.maxHeight);
      Offset toWorld(Offset p) => Offset(p.dx / size * kMapPx, p.dy / size * kMapPx);
      void handle(PointerEvent e, int buttons) {
        final w = toWorld(e.localPosition);
        if (buttons & kSecondaryMouseButton != 0) {
          c.rightClickWorld(w);
        } else if (c.view.targeting != null && buttons & kPrimaryMouseButton != 0) {
          c.leftClickWorld(w);
        } else {
          c.centerOn(w.dx, w.dy);
        }
        onChanged();
      }

      return Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(border: Border.all(color: kBorder, width: 2)),
          child: Listener(
            onPointerDown: (e) => handle(e, e.buttons),
            onPointerMove: (e) {
              if (e.buttons & kPrimaryMouseButton != 0 && c.view.targeting == null) {
                final w = toWorld(e.localPosition);
                c.centerOn(w.dx, w.dy);
              }
            },
            child: CustomPaint(size: Size(size, size), painter: MinimapPainter(c, base, fog, repaint: repaint)),
          ),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------- Komut kartı

class CmdButton extends StatefulWidget {
  const CmdButton({super.key, required this.cmd, required this.onChanged, required this.team, this.size = 50});
  final Cmd? cmd;
  final Color team;
  final VoidCallback onChanged;
  final double size;

  @override
  State<CmdButton> createState() => _CmdButtonState();
}

class _CmdButtonState extends State<CmdButton> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final cmd = widget.cmd;
    final s = widget.size;
    if (cmd == null) {
      return Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: const Color(0xFF0E0B08),
          border: Border.all(color: const Color(0xFF3B2E1E)),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }
    final costs = <InlineSpan>[];
    void cost(IconData i, Color col, int v) {
      if (v <= 0) return;
      costs.add(WidgetSpan(child: Icon(i, size: 13, color: col)));
      costs.add(TextSpan(text: ' $v   ', style: const TextStyle(color: Colors.white)));
    }

    cost(Icons.monetization_on, const Color(0xFFFFC107), cmd.gold);
    cost(Icons.forest, const Color(0xFF8BC34A), cmd.lumber);
    cost(Icons.restaurant, const Color(0xFFFFAB91), cmd.food);
    cost(Icons.water_drop, const Color(0xFF64B5F6), cmd.mana);
    final tip = TextSpan(children: [
      TextSpan(text: cmd.name, style: const TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 14)),
      TextSpan(text: '  (${cmd.hotkey})', style: const TextStyle(color: Color(0xFFFFEB3B), fontSize: 12)),
      if (costs.isNotEmpty) const TextSpan(text: '\n'),
      ...costs,
      if (cmd.desc.isNotEmpty) TextSpan(text: '\n${cmd.desc}', style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 12.5)),
    ]);
    Widget icon;
    if (cmd.unitIcon != null) {
      icon = unitIcon(cmd.unitIcon!, cmd.iconColor == Colors.grey ? Colors.grey : widget.team, s - 6,
          grey: cmd.iconColor == Colors.grey);
    } else {
      icon = Icon(cmd.icon, size: s * 0.56, color: cmd.iconColor ?? const Color(0xFFE8DCC0));
    }
    return Tooltip(
      richMessage: tip,
      waitDuration: const Duration(milliseconds: 250),
      preferBelow: false,
      verticalOffset: s * 0.7,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xF0120D08),
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: GestureDetector(
          onTap: () {
            cmd.onTap();
            widget.onChanged();
          },
          child: Container(
            width: s,
            height: s,
            decoration: iconBox(highlight: cmd.highlight || hover),
            child: Stack(children: [
              Center(child: icon),
              if (!cmd.enabled) Positioned.fill(child: Container(color: const Color(0x99000000))),
              if (cmd.cooldown > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: (s - 4) * cmd.cooldown,
                  child: Container(color: const Color(0xAA000000)),
                ),
              Positioned(
                left: 3,
                top: 1,
                child: Text(cmd.hotkey == 'Esc' ? '' : cmd.hotkey,
                    style: kTextShadow.copyWith(color: const Color(0xFFFFEB3B), fontSize: 11, fontWeight: FontWeight.w900)),
              ),
              if (cmd.maxLevel > 0)
                Positioned(
                  bottom: 2,
                  left: 0,
                  right: 0,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 0; i < cmd.maxLevel; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < cmd.level ? const Color(0xFFFFD54F) : const Color(0xFF3B3B3B),
                          border: Border.all(color: Colors.black, width: 0.5),
                        ),
                      ),
                  ]),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class CommandCardView extends StatelessWidget {
  const CommandCardView({super.key, required this.c, required this.onChanged});
  final GameController c;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final card = c.commandCard();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (var r = 0; r < 3; r++)
        Padding(
          padding: EdgeInsets.only(bottom: r < 2 ? 4 : 0),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var col = 0; col < 4; col++)
              Padding(
                padding: EdgeInsets.only(right: col < 3 ? 4 : 0),
                child: CmdButton(cmd: card[r * 4 + col], onChanged: onChanged, team: c.me.color),
              ),
          ]),
        ),
    ]);
  }
}

// ---------------------------------------------------------------- Bilgi paneli

String orderText(Unit u) {
  if (u.isBuilding) {
    if (u.constructing) return 'İnşa ediliyor';
    if (u.queue.isNotEmpty) return 'Üretiyor';
    return '';
  }
  if (u.stun > 0) return 'Sersemledi';
  return switch (u.order) {
    Order.idle => u.engaged != null ? 'Savaşıyor' : 'Bekliyor',
    Order.move => 'Hareket ediyor',
    Order.attackMove => u.engaged != null ? 'Savaşıyor' : 'Saldırarak ilerliyor',
    Order.attack => 'Saldırıyor',
    Order.hold => 'Pozisyonu koruyor',
    Order.gather => u.gatherKind == 'gold'
        ? (u.gatherPhase == 2 ? 'Altın taşıyor' : 'Altın topluyor')
        : (u.gatherPhase == 2 ? 'Odun taşıyor' : 'Odun kesiyor'),
    Order.build => 'İnşaat alanına gidiyor',
    Order.construct => 'İnşa ediyor',
    Order.cast => 'Büyü yapıyor',
    Order.pickup => 'Eşya alıyor',
    Order.leash => 'Kampına dönüyor',
  };
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({super.key, required this.c, required this.onChanged});
  final GameController c;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      // Çok dar alanda içerik sığmaz; taşma yerine boş bırak.
      if (cons.maxWidth < 320 || cons.maxHeight < 110) return const SizedBox.shrink();
      final sel = c.sel;
      if (sel.isEmpty) return _empty();
      if (sel.length == 1) return _single(sel.first);
      return _multi(sel);
    });
  }

  Widget _empty() {
    final f = c.me.faction!;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(f.name, style: const TextStyle(color: kGold, fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          'Sol tık: seç · Sürükle: kutu seçimi · Sağ tık: akıllı emir\n'
          'Ok tuşları / ekran kenarı / orta tuş: kamerayı kaydır · Tekerlek: yakınlaştır\n'
          'Ctrl+1-9: grup ata · 1-9: grubu seç · F1/F2: kahraman · F8: boştaki işçi\n'
          'Boşluk: son uyarıya git · Alt: tüm can çubukları · Esc: iptal',
          style: TextStyle(color: Color(0xFFD7CCC8), fontSize: 12.5, height: 1.45),
        ),
      ]),
    );
  }

  Widget _stat(IconData i, String v, {Color col = const Color(0xFFE0E0E0), String tip = ''}) => Tooltip(
        message: tip,
        child: Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(i, size: 15, color: const Color(0xFFBCAAA4)),
            const SizedBox(width: 4),
            Text(v, style: TextStyle(color: col, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _single(Unit u) {
    final g = c.game;
    final own = u.owner == kPlayer;
    final title = u.isHero ? u.heroName : u.type.name;
    String sub;
    if (u.isHero) {
      sub = 'Seviye ${u.level} ${u.type.name}';
    } else if (u.owner == kCreeps) {
      sub = 'Tarafsız düşman · Seviye ${u.type.level}';
    } else if (u.owner == kEnemy) {
      sub = 'Düşman · ${u.pl.faction!.name}';
    } else if (u.isMine) {
      sub = 'Kalan altın: ${u.goldLeft}';
    } else {
      sub = orderText(u);
    }
    final children = <Widget>[
      Text(title, style: const TextStyle(color: kGold, fontSize: 17, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
      Text(sub, style: TextStyle(color: u.owner == kPlayer || u.isMine ? const Color(0xFFD7CCC8) : const Color(0xFFFF8A80), fontSize: 12.5)),
      const SizedBox(height: 6),
    ];
    if (u.isBuilding && u.constructing) {
      children.add(Text('İnşa ediliyor: %${(u.progress * 100).floor()}', style: const TextStyle(color: Color(0xFFFFCC80), fontSize: 13)));
      children.add(const SizedBox(height: 4));
      children.add(SizedBox(width: 220, child: _bar(u.progress, const Color(0xFFFFA726), height: 8)));
    } else if (u.isBuilding && !u.isMine) {
      final stats = <Widget>[_stat(Icons.shield, fmtNum(u.armor), tip: 'Zırh')];
      if (u.type.canAttack) stats.insert(0, _stat(Icons.gps_fixed, '${u.dmgMin.round()}-${u.dmgMax.round()}', tip: 'Hasar'));
      if (u.type.foodProvided > 0) stats.add(_stat(Icons.restaurant, '+${u.type.foodProvided}', tip: 'Yiyecek'));
      children.add(Row(children: stats));
      if (own && u.queue.isNotEmpty) {
        children.add(const SizedBox(height: 8));
        children.add(_queue(u));
      }
    } else if (!u.isBuilding) {
      final bonus = u.dmgBonus;
      children.add(Wrap(children: [
        if (u.type.canAttack)
          _stat(Icons.gps_fixed, '${u.dmgMin.round()}-${u.dmgMax.round()}',
              col: bonus > 0 ? const Color(0xFF9CFF57) : const Color(0xFFE0E0E0), tip: 'Saldırı hasarı'),
        _stat(Icons.shield, fmtNum(double.parse(u.armor.toStringAsFixed(1))),
            col: u.armor > u.type.armor ? const Color(0xFF9CFF57) : const Color(0xFFE0E0E0), tip: 'Zırh'),
        _stat(Icons.directions_run, '${u.speed.round()}', tip: 'Hareket hızı'),
        if (u.type.ranged) _stat(Icons.track_changes, '${u.range.round()}', tip: 'Menzil'),
      ]));
      if (u.isHero) {
        final need = u.level >= kMaxHeroLevel ? 1 : xpForLevel[u.level];
        final prev = xpForLevel[u.level - 1];
        final ratio = u.level >= kMaxHeroLevel ? 1.0 : (u.xp - prev) / (need - prev);
        children.add(const SizedBox(height: 6));
        children.add(Text(u.level >= kMaxHeroLevel ? 'En yüksek seviye' : 'Deneyim: ${u.xp} / $need',
            style: const TextStyle(color: Color(0xFFCE93D8), fontSize: 12)));
        children.add(const SizedBox(height: 2));
        children.add(SizedBox(width: 200, child: _bar(ratio, const Color(0xFFAB47BC), height: 6)));
      }
      if (u.type.worker && (u.carryGold > 0 || u.carryWood > 0)) {
        children.add(Text('Taşıyor: ${u.carryGold > 0 ? '${u.carryGold} altın' : '${u.carryWood} odun'}',
            style: const TextStyle(color: Color(0xFFFFE082), fontSize: 12.5)));
      }
      if (u.type.summon) {
        children.add(Text('Kalan süre: ${u.expire.ceil()} sn', style: const TextStyle(color: Color(0xFF80DEEA), fontSize: 12.5)));
      }
      if (u.isHero && own) children.add(Text(orderText(u), style: const TextStyle(color: Color(0xFFBCAAA4), fontSize: 12)));
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(decoration: iconBox(), child: unitIcon(u.type, u.pl.color, 82, time: g.time)),
          const SizedBox(height: 4),
          if (!u.isMine)
            Text('${u.hp.ceil()} / ${u.maxHp.round()}',
                style: const TextStyle(color: Color(0xFF7CFF6B), fontSize: 12.5, fontWeight: FontWeight.w700)),
          if (u.maxMana > 0)
            Text('${u.mana.floor()} / ${u.maxMana.round()}',
                style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
        if (u.isHero && own) _inventory(u),
      ]),
    );
  }

  Widget _queue(Unit b) {
    final q0 = b.queue.first;
    Widget qIcon(QueueItem q, double size) {
      if (q.kind == 'research') {
        return Icon(q.upgrade!.icon, size: size * 0.6, color: const Color(0xFFB0BEC5));
      }
      return unitIcon(q.unitType!, c.me.color, size - 4, grey: q.kind == 'revive');
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < b.queue.length; i++)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Tooltip(
            message: 'İptal etmek için tıklayın',
            child: GestureDetector(
              onTap: () {
                c.game.cmdCancelQueue(b, i);
                onChanged();
              },
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: i == 0 ? 46 : 34,
                  height: i == 0 ? 46 : 34,
                  decoration: iconBox(),
                  child: Center(child: qIcon(b.queue[i], i == 0 ? 46 : 34)),
                ),
                if (i == 0) ...[
                  const SizedBox(height: 3),
                  SizedBox(width: 46, child: _bar(q0.progress / q0.time, const Color(0xFF80DEEA), height: 5)),
                ],
              ]),
            ),
          ),
        ),
      const SizedBox(width: 6),
      Text('${max(0, q0.time - q0.progress).ceil()} sn', style: const TextStyle(color: Color(0xFFB2EBF2), fontSize: 12)),
    ]);
  }

  Widget _inventory(Unit h) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFF5D4630)), borderRadius: BorderRadius.circular(4)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Envanter', style: TextStyle(color: kGold, fontSize: 11)),
        const SizedBox(height: 3),
        for (var r = 0; r < 2; r++)
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (var col = 0; col < 3; col++) _slot(h, r * 3 + col),
          ]),
      ]),
    );
  }

  Widget _slot(Unit h, int i) {
    final it = h.inv[i];
    final box = Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.all(2),
      decoration: iconBox(),
      child: it == null ? null : Icon(it.icon, color: it.color, size: 24),
    );
    if (it == null) return box;
    return Tooltip(
      richMessage: TextSpan(children: [
        TextSpan(text: it.name, style: const TextStyle(color: kGold, fontWeight: FontWeight.bold)),
        TextSpan(text: '\n${it.desc}'),
        TextSpan(
            text: it.consumable ? '\nKullanmak için tıklayın.' : '\nPasif etki. Sağ tık: yere bırak.',
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 11)),
      ]),
      child: GestureDetector(
        onTap: () {
          c.game.cmdUseItem(h, i);
          onChanged();
        },
        onSecondaryTap: () {
          c.game.cmdDropItem(h, i);
          onChanged();
        },
        child: box,
      ),
    );
  }

  Widget _multi(List<Unit> sel) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(spacing: 4, runSpacing: 4, children: [
        for (final u in sel)
          GestureDetector(
            onTap: () {
              if (HardwareKeyboard.instance.isShiftPressed) {
                c.select(sel.where((o) => o != u).toList());
              } else {
                c.select([u]);
              }
              onChanged();
            },
            child: Container(
              width: 50,
              decoration: iconBox(),
              padding: const EdgeInsets.all(2),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                unitIcon(u.type, u.pl.color, 42),
                _bar(u.hp / u.maxHp, u.hp / u.maxHp > 0.5 ? const Color(0xFF4CFF4C) : const Color(0xFFFF5252)),
                if (u.maxMana > 0) ...[
                  const SizedBox(height: 1),
                  _bar(u.mana / u.maxMana, const Color(0xFF42A5F5), height: 3),
                ],
              ]),
            ),
          ),
      ]),
    );
  }
}

class BottomPanel extends StatelessWidget {
  const BottomPanel({
    super.key,
    required this.c,
    required this.minimapBase,
    required this.fog,
    required this.minimapRepaint,
    required this.onChanged,
  });
  final GameController c;
  final MinimapBase minimapBase;
  final FogImage fog;
  final Listenable minimapRepaint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kBottomHud,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kPanelTop, kPanelBottom]),
        border: Border(top: BorderSide(color: kBorder, width: 2)),
        boxShadow: [BoxShadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, -2))],
      ),
      padding: const EdgeInsets.all(6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: kBottomHud - 12,
          child: MinimapView(c: c, base: minimapBase, fog: fog, repaint: minimapRepaint, onChanged: onChanged),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x55000000),
              border: Border.all(color: const Color(0xFF5D4630)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRect(child: InfoPanel(c: c, onChanged: onChanged)),
          ),
        ),
        const SizedBox(width: 8),
        Center(child: CommandCardView(c: c, onChanged: onChanged)),
      ]),
    );
  }
}
