import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/entities.dart';
import '../render/world_painter.dart';
import 'controller.dart';
import 'hud.dart';

/// Telefon ve tablet (yerel uygulama). Bu cihazlarda oyun yatay ve tam ekran açılır.
bool get isMobilePlatform =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

/// Dokunmatik (mobil) yerleşim kullanılsın mı: telefon/tablet ya da küçük pencere.
bool useTouchLayout(Size size) => isMobilePlatform || size.width < 1000 || size.height < 620;

/// Telefon (yatay) arayüzü ölçüleri.
const double kMobileTop = 32;
const double kMobileBtn = 44;
const double kMobileGap = 6;
const double kMobileMinimap = 104;
const double kMobileStrip = 78;
const double kMobileCardW = kMobileBtn * 4 + 3 * 3;

/// Telefonlar için ayrı yerleşim: dünya tüm ekranı kaplar, arayüz köşelere yerleşir.
class MobileHud extends StatelessWidget {
  const MobileHud({
    super.key,
    required this.c,
    required this.minimapBase,
    required this.fog,
    required this.minimapRepaint,
    required this.onChanged,
    required this.onMenu,
    required this.onPause,
    required this.safe,
  });

  final GameController c;
  final MinimapBase minimapBase;
  final FogImage fog;
  final Listenable minimapRepaint;
  final VoidCallback onChanged, onMenu, onPause;
  final EdgeInsets safe;

  @override
  Widget build(BuildContext context) {
    final left = safe.left + kMobileGap, right = safe.right + kMobileGap, bottom = safe.bottom + kMobileGap;
    final card = c.commandCard();
    // Komut yoksa boş ızgarayı gösterme; şerit sağa kadar uzar.
    final hasCard = card.any((x) => x != null);
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: _MobileTopBar(c: c, safe: safe, onMenu: onMenu, onPause: onPause),
        ),
        Positioned(
          left: left,
          top: kMobileTop + kMobileGap,
          child: _SideBar(c: c, onChanged: onChanged),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: kMobileTop + 6,
          child: MessageList(c: c, fontSize: 13),
        ),
        Positioned(
          left: left,
          bottom: bottom,
          width: kMobileMinimap,
          height: kMobileMinimap,
          child: MinimapView(c: c, base: minimapBase, fog: fog, repaint: minimapRepaint, onChanged: onChanged),
        ),
        if (hasCard) Positioned(right: right, bottom: bottom, child: _commandCard(card)),
        // Seçim yoksa şerit yalnızca ilk oyundaki kontrol ipucu için görünür.
        if (c.sel.isNotEmpty || c.showHint)
          Positioned(
            left: left + kMobileMinimap + kMobileGap,
            right: right + (hasCard ? kMobileCardW + kMobileGap : 0),
            bottom: bottom,
            height: kMobileStrip,
            child: MobileInfoStrip(c: c, onChanged: onChanged),
          ),
      ],
    );
  }

  Widget _commandCard(List<Cmd?> card) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xCC15100A),
        border: Border.all(color: kBorder, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < 3; r++)
            Padding(
              padding: EdgeInsets.only(bottom: r < 2 ? 3 : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var col = 0; col < 4; col++)
                    Padding(
                      padding: EdgeInsets.only(right: col < 3 ? 3 : 0),
                      child: CmdButton(
                        cmd: card[r * 4 + col],
                        onChanged: onChanged,
                        team: c.me.color,
                        size: kMobileBtn,
                        showHotkey: false,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({required this.c, required this.safe, required this.onMenu, required this.onPause});
  final GameController c;
  final EdgeInsets safe;
  final VoidCallback onMenu, onPause;

  Widget _btn(IconData icon, VoidCallback onTap) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: 40,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFF241A11),
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 18, color: kGold),
    ),
  );

  Widget _res(
    BuildContext context,
    IconData icon,
    Color col,
    String text,
    String template, {
    Color textColor = Colors.white,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: col, size: 16),
        const SizedBox(width: 4),
        fixedNum(
          context,
          text,
          kTextShadow.copyWith(color: textColor, fontSize: 14, fontWeight: FontWeight.w700),
          template,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final me = c.me;
    final g = c.game;
    final night = g.isNight;
    return Container(
      height: kMobileTop,
      padding: EdgeInsets.only(left: safe.left + 6, right: safe.right + 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xEE33261A), Color(0xEE15100A)],
        ),
        border: Border(bottom: BorderSide(color: kBorder, width: 1.5)),
      ),
      child: Row(
        children: [
          _btn(Icons.menu, onMenu),
          const SizedBox(width: 6),
          _btn(c.paused ? Icons.play_arrow : Icons.pause, onPause),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _res(context, Icons.monetization_on, const Color(0xFFFFC107), '${me.gold}', '88888'),
                  _res(context, Icons.forest, const Color(0xFF8BC34A), '${me.lumber}', '88888'),
                  _res(
                    context,
                    Icons.restaurant,
                    const Color(0xFFFFAB91),
                    '${me.foodUsed}/${me.foodCap}',
                    '888/888',
                    textColor: me.foodUsed >= me.foodCap ? const Color(0xFFFF6E6E) : Colors.white,
                  ),
                ],
              ),
            ),
          ),
          Icon(
            night ? Icons.nightlight_round : Icons.wb_sunny,
            color: night ? const Color(0xFF90CAF9) : const Color(0xFFFFD54F),
            size: 16,
          ),
          const SizedBox(width: 4),
          fixedNum(
            context,
            g.clockText,
            kTextShadow.copyWith(color: kGold, fontSize: 13, fontWeight: FontWeight.w700),
            '88:88',
          ),
          const SizedBox(width: 6),
          fixedNum(context, fmtClock(g.time), kTextShadow.copyWith(color: Colors.white70, fontSize: 12), '88:88'),
        ],
      ),
    );
  }
}

/// Sol sütun: kahramanlar, boştaki işçi ve tüm orduyu seçme.
class _SideBar extends StatelessWidget {
  const _SideBar({required this.c, required this.onChanged});
  final GameController c;
  final VoidCallback onChanged;

  Widget _tile({required Widget child, required VoidCallback onTap, VoidCallback? onDoubleTap, bool glow = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          onTap();
          onChanged();
        },
        onDoubleTap: onDoubleTap == null
            ? null
            : () {
                onDoubleTap();
                onChanged();
              },
        child: Container(
          width: 48,
          padding: const EdgeInsets.all(2),
          decoration: panelDeco(radius: 4, glow: glow),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heroes = c.myHeroes;
    final idle = c.idleWorkers.length;
    final g = c.game;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < heroes.length; i++)
          _tile(
            glow: heroes[i].skillPoints > 0 && !heroes[i].dead,
            onTap: () => c.selectHero(i),
            onDoubleTap: () => c.selectHero(i, center: true),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: iconBox(),
                      child: unitIcon(heroes[i].type, c.me.color, 40, grey: heroes[i].dead, time: g.time),
                    ),
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(3)),
                        child: Text(
                          '${heroes[i].level}',
                          style: const TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (heroes[i].dead)
                      const Positioned.fill(
                        child: Center(child: Icon(Icons.close, color: Color(0xCCFF5252), size: 26)),
                      ),
                    if (heroes[i].skillPoints > 0 && !heroes[i].dead)
                      const Positioned(
                        left: 1,
                        top: 1,
                        child: Icon(Icons.add_circle, color: Color(0xFFFFD54F), size: 13),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                hpBar(heroes[i].dead ? 0 : heroes[i].hp / heroes[i].maxHp, const Color(0xFF4CFF4C), height: 3),
                const SizedBox(height: 1),
                hpBar(
                  heroes[i].dead ? 0 : heroes[i].mana / max(1, heroes[i].maxMana),
                  const Color(0xFF42A5F5),
                  height: 3,
                ),
              ],
            ),
          ),
        if (idle > 0)
          _tile(
            onTap: c.selectIdleWorker,
            child: SizedBox(
              height: 40,
              child: Stack(
                children: [
                  Center(child: unitIcon(ut(c.me.faction!.worker), c.me.color, 38)),
                  Positioned(
                    right: 1,
                    bottom: 0,
                    child: Text(
                      '$idle',
                      style: kTextShadow.copyWith(color: kGold, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        _tile(
          onTap: c.selectArmy,
          child: const SizedBox(
            height: 40,
            child: FittedBox(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups, color: kGold, size: 22),
                  Text(
                    'Ordu',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Alt orta şerit: seçili birim(ler)in özeti.
class MobileInfoStrip extends StatelessWidget {
  const MobileInfoStrip({super.key, required this.c, required this.onChanged});
  final GameController c;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final sel = c.sel;
    Widget body;
    if (sel.isEmpty) {
      body = const Center(
        child: Text(
          'Dokun: seç / emir ver · Çift dokun: aynı türdekiler\n'
          'Basılı tut + sürükle: kutu seçimi · Kaydır: kamera · İki parmak: yakınlaştır',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFD7CCC8), fontSize: 11, height: 1.4),
        ),
      );
    } else if (sel.length == 1) {
      body = _single(sel.first);
    } else {
      body = _multi(sel);
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xDD15100A),
        border: Border.all(color: kBorder, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRect(
        child: Row(
          children: [
            Expanded(child: body),
            if (sel.isNotEmpty)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  c.select([]);
                  onChanged();
                },
                child: const SizedBox(
                  width: 30,
                  height: double.infinity,
                  child: Icon(Icons.close, color: Color(0xFFBCAAA4), size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData i, String v) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(i, size: 12, color: const Color(0xFFBCAAA4)),
        const SizedBox(width: 2),
        Text(
          v,
          style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _single(Unit u) {
    final own = u.owner == kPlayer;
    final title = u.isHero ? '${u.heroName} · Sv ${u.level}' : u.type.name;
    String sub;
    if (u.owner == kCreeps) {
      sub = 'Tarafsız · Sv ${u.type.level}';
    } else if (u.owner == kEnemy) {
      sub = 'Düşman';
    } else if (u.isMine) {
      sub = 'Kalan altın: ${u.goldLeft}';
    } else if (u.isBuilding && u.constructing) {
      sub = 'İnşa: %${(u.progress * 100).floor()}';
    } else {
      sub = orderText(u);
    }
    final stats = <Widget>[
      if (u.type.canAttack && !u.isMine) _stat(Icons.gps_fixed, '${u.dmgMin.round()}-${u.dmgMax.round()}'),
      if (!u.isMine) _stat(Icons.shield, fmtNum(double.parse(u.armor.toStringAsFixed(1)))),
      if (u.type.worker && (u.carryGold > 0 || u.carryWood > 0))
        _stat(u.carryGold > 0 ? Icons.monetization_on : Icons.forest, '${u.carryGold + u.carryWood}'),
      if (u.type.summon) _stat(Icons.timer, '${u.expire.ceil()} sn'),
    ];
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: kGold, fontSize: 13.5, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            ...stats,
            Flexible(
              child: Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: own || u.isMine ? const Color(0xFFD7CCC8) : const Color(0xFFFF8A80),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        if (!u.isMine)
          Row(
            children: [
              Expanded(
                child: hpBar(
                  u.constructing ? u.progress : u.hp / u.maxHp,
                  u.constructing ? const Color(0xFFFFA726) : const Color(0xFF4CFF4C),
                  height: 6,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${u.hp.ceil()}/${u.maxHp.round()}',
                style: const TextStyle(color: Color(0xFF7CFF6B), fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        if (u.maxMana > 0) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(child: hpBar(u.mana / u.maxMana, const Color(0xFF42A5F5), height: 4)),
              const SizedBox(width: 4),
              Text(
                '${u.mana.floor()}/${u.maxMana.round()}',
                style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ],
    );
    return Row(
      children: [
        Container(
          decoration: iconBox(),
          child: unitIcon(u.type, u.pl.color, 54, time: c.game.time),
        ),
        const SizedBox(width: 6),
        // Yazı tipine göre birkaç piksel taşabilir; taşma uyarısı yerine kırp.
        Expanded(
          child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: info),
        ),
        if (u.isHero && own) ...[const SizedBox(width: 6), _inventory(u)],
        if (u.isBuilding && own && u.queue.isNotEmpty) ...[const SizedBox(width: 6), _queue(u)],
      ],
    );
  }

  Widget _inventory(Unit h) {
    Widget slot(int i) {
      final it = h.inv[i];
      final box = Container(
        width: 27,
        height: 27,
        margin: const EdgeInsets.all(1),
        decoration: iconBox(),
        child: it == null ? null : Icon(it.icon, color: it.color, size: 18),
      );
      if (it == null) return box;
      return GestureDetector(
        onTap: () {
          c.game.cmdUseItem(h, i);
          onChanged();
        },
        onLongPress: it.consumable
            ? null
            : () {
                c.game.cmdDropItem(h, i);
                onChanged();
              },
        child: box,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < 2; r++)
          Row(mainAxisSize: MainAxisSize.min, children: [for (var k = 0; k < 3; k++) slot(r * 3 + k)]),
      ],
    );
  }

  Widget _queue(Unit b) {
    final q0 = b.queue.first;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < min(b.queue.length, 3); i++)
          GestureDetector(
            onTap: () {
              c.game.cmdCancelQueue(b, i);
              onChanged();
            },
            child: Container(
              width: 34,
              margin: const EdgeInsets.only(right: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: iconBox(),
                    child: Center(
                      child: b.queue[i].kind == 'research'
                          ? Icon(b.queue[i].upgrade!.icon, size: 20, color: const Color(0xFFB0BEC5))
                          : unitIcon(b.queue[i].unitType!, c.me.color, 30, grey: b.queue[i].kind == 'revive'),
                    ),
                  ),
                  if (i == 0) ...[
                    const SizedBox(height: 2),
                    hpBar(q0.progress / q0.time, const Color(0xFF80DEEA), height: 4),
                  ],
                ],
              ),
            ),
          ),
        if (b.queue.length > 3)
          Text('+${b.queue.length - 3}', style: const TextStyle(color: Color(0xFFB2EBF2), fontSize: 11)),
      ],
    );
  }

  Widget _multi(List<Unit> sel) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final u in sel)
          GestureDetector(
            onTap: () {
              c.select([u]);
              onChanged();
            },
            child: Container(
              width: 42,
              margin: const EdgeInsets.only(right: 3),
              padding: const EdgeInsets.all(1.5),
              decoration: iconBox(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  unitIcon(u.type, u.pl.color, 36),
                  hpBar(
                    u.hp / u.maxHp,
                    u.hp / u.maxHp > 0.5 ? const Color(0xFF4CFF4C) : const Color(0xFFFF5252),
                    height: 3,
                  ),
                  if (u.maxMana > 0) ...[
                    const SizedBox(height: 1),
                    hpBar(u.mana / u.maxMana, const Color(0xFF42A5F5), height: 2),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
