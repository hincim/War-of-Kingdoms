import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/data.dart';

final Paint _f = Paint()..isAntiAlias = true;
final Paint _s = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Paint fillP(Color c) => _f..color = c;
Paint strokeP(Color c, double w) => _s
  ..color = c
  ..strokeWidth = w;

Color shade(Color c, double f) {
  if (f >= 0) return Color.lerp(c, Colors.white, f)!;
  return Color.lerp(c, Colors.black, -f)!;
}

const _steel = Color(0xFFB8C4CC);
const _steelDark = Color(0xFF5E6E78);
const _skin = Color(0xFFF0C08A);
const _leather = Color(0xFF7B5236);
const _wood = Color(0xFF6D4C33);
const _goldC = Color(0xFFFFC52E);
const _orcSkin = Color(0xFF6E9A32);
const _trollSkin = Color(0xFF3FA3A0);
const _shadow = Color(0x55000000);

/// Prosedürel sprite çizimleri. Birimler (0,0) = yer konumu olacak şekilde çizilir.
class Sprites {
  // ------------------------------------------------------------ Birimler

  static void unit(
    Canvas c,
    UnitType t,
    Color team, {
    double facing = pi / 2,
    double walk = 0,
    double swing = 1,
    bool moving = false,
    double time = 0,
    int carry = 0, // 1 = altın, 2 = odun
  }) {
    final side = cos(facing) >= 0 ? 1 : -1;
    final back = sin(facing) < -0.55;
    final bob = moving ? sin(walk * 2) * 1.2 : 0.0;
    final legs = moving ? sin(walk * 2) : 0.0;
    final r = t.radius;
    switch (t.id) {
      case 'h_worker':
        _humanoid(c, r: r, body: const Color(0xFF9C7B4F), trim: _leather, skin: _skin, team: team,
            side: side, back: back, bob: bob, legs: legs, swing: swing, weapon: 'pick', head: 'hair',
            hair: const Color(0xFF6D4C2F), carry: carry);
      case 'o_worker':
        _humanoid(c, r: r, body: const Color(0xFF8A6A45), trim: _leather, skin: _orcSkin, team: team,
            side: side, back: back, bob: bob, legs: legs, swing: swing, weapon: 'pick', head: 'bald',
            tusks: true, ears: true, carry: carry);
      case 'h_footman':
        _humanoid(c, r: r, body: _steel, trim: _steelDark, skin: _skin, team: team, side: side,
            back: back, bob: bob, legs: legs, swing: swing, weapon: 'sword', head: 'helmet', shield: true);
      case 'h_rifleman':
        _humanoid(c, r: r, body: const Color(0xFF8D6E4A), trim: _leather, skin: _skin, team: team,
            side: side, back: back, bob: bob, legs: legs, swing: swing, weapon: 'gun', head: 'helmet',
            beard: true, hair: const Color(0xFFB5651D), bulk: 1.15, short: true);
      case 'h_knight':
        _mount(c, r: r, color: const Color(0xFFEEE6D8), side: side, legs: legs, team: team, armored: true);
        c.save();
        c.translate(-side * r * 0.1, -r * 0.55 + bob);
        _humanoid(c, r: r * 0.66, body: _steel, trim: _steelDark, skin: _skin, team: team, side: side,
            back: back, bob: 0, legs: 0, swing: swing, weapon: 'sword', head: 'helmet', shield: true,
            noLegs: true, noShadow: true, plume: team);
        c.restore();
      case 'o_grunt':
        _humanoid(c, r: r, body: const Color(0xFF5A4A3A), trim: const Color(0xFF3B2F25), skin: _orcSkin,
            team: team, side: side, back: back, bob: bob, legs: legs, swing: swing, weapon: 'axe',
            head: 'bald', tusks: true, ears: true, bulk: 1.2, pads: true);
      case 'o_headhunter':
        _humanoid(c, r: r, body: const Color(0xFF6B5B3E), trim: _leather, skin: _trollSkin, team: team,
            side: side, back: back, bob: bob, legs: legs, swing: swing, weapon: 'spear', head: 'mohawk',
            hair: const Color(0xFFD84315), tusks: true, ears: true, tall: true);
      case 'o_raider':
        _mount(c, r: r, color: const Color(0xFF6B5E55), side: side, legs: legs, team: team, wolf: true);
        c.save();
        c.translate(-side * r * 0.1, -r * 0.5 + bob);
        _humanoid(c, r: r * 0.66, body: const Color(0xFF5A4A3A), trim: _leather, skin: _orcSkin, team: team,
            side: side, back: back, bob: 0, legs: 0, swing: swing, weapon: 'axe', head: 'bald',
            tusks: true, ears: true, noLegs: true, noShadow: true);
        c.restore();
      case 'h_paladin':
        _heroGlow(c, r, const Color(0xFFFFE082), time);
        _humanoid(c, r: r, body: const Color(0xFFD7DEE3), trim: _goldC, skin: _skin, team: team, side: side,
            back: back, bob: bob, legs: legs, swing: swing, weapon: 'hammer', head: 'helmet', cape: true,
            shield: true, plume: _goldC, bulk: 1.1);
      case 'h_archmage':
        _heroGlow(c, r, const Color(0xFF81D4FA), time);
        _humanoid(c, r: r, body: shade(team, -0.15), trim: _goldC, skin: _skin, team: team, side: side,
            back: back, bob: bob, legs: legs, swing: swing, weapon: 'staff', head: 'hood', beard: true,
            hair: const Color(0xFFF5F5F5), robe: true, orb: const Color(0xFF4FC3F7), time: time);
      case 'o_chieftain':
        _heroGlow(c, r, const Color(0xFFFFB74D), time);
        _humanoid(c, r: r, body: const Color(0xFF7A5230), trim: const Color(0xFF4E342E),
            skin: const Color(0xFF8B5A2B), team: team, side: side, back: back, bob: bob, legs: legs,
            swing: swing, weapon: 'totem', head: 'horns', bulk: 1.35, pads: true, cape: true);
      case 'o_farseer':
        _heroGlow(c, r, const Color(0xFF80DEEA), time);
        _humanoid(c, r: r, body: shade(team, -0.25), trim: const Color(0xFFB0BEC5), skin: _orcSkin,
            team: team, side: side, back: back, bob: bob, legs: legs, swing: swing, weapon: 'staff',
            head: 'wolfhood', tusks: true, robe: true, orb: const Color(0xFF80DEEA), time: time);
      case 'h_waterel':
        _waterElemental(c, r, time);
      case 'o_wolf':
        _mount(c, r: r * 0.9, color: const Color(0xFF90A4C8), side: side, legs: legs, team: team,
            wolf: true, ghost: true);
      case 'c_gnoll':
        _humanoid(c, r: r, body: const Color(0xFF8D6E3C), trim: const Color(0xFF5D4037),
            skin: const Color(0xFFB08850), team: const Color(0xFF6D4C41), side: side, back: back, bob: bob,
            legs: legs, swing: swing, weapon: 'club', head: 'gnoll');
      case 'c_gnollArcher':
        _humanoid(c, r: r, body: const Color(0xFF7D6235), trim: const Color(0xFF5D4037),
            skin: const Color(0xFFB08850), team: const Color(0xFF558B2F), side: side, back: back, bob: bob,
            legs: legs, swing: swing, weapon: 'bow', head: 'gnoll');
      case 'c_murloc':
        _murloc(c, r, side, bob, swing, legs);
      case 'c_troll':
        _humanoid(c, r: r, body: const Color(0xFF5D6B3A), trim: _leather, skin: _trollSkin,
            team: const Color(0xFF33691E), side: side, back: back, bob: bob, legs: legs, swing: swing,
            weapon: 'spear', head: 'mohawk', hair: const Color(0xFF7B1FA2), tusks: true, ears: true, tall: true);
      case 'c_ogre':
        _humanoid(c, r: r, body: const Color(0xFF8D7B5A), trim: const Color(0xFF5D4037),
            skin: const Color(0xFF9EA48A), team: const Color(0xFF6D4C41), side: side, back: back, bob: bob,
            legs: legs, swing: swing, weapon: 'club', head: 'bald', tusks: true, bulk: 1.45);
      case 'c_golem':
        _golem(c, r, side, bob, swing);
      case 'c_dragon':
        _dragon(c, r, side, time, swing);
      default:
        c.drawCircle(Offset(0, -r * 0.4), r, fillP(team));
    }
  }

  static void _heroGlow(Canvas c, double r, Color col, double time) {
    final a = 0.25 + 0.1 * sin(time * 3);
    c.drawOval(Rect.fromCenter(center: Offset(0, r * 0.45), width: r * 2.8, height: r * 1.2),
        fillP(col.withValues(alpha: a)));
  }

  static void _humanoid(
    Canvas c, {
    required double r,
    required Color body,
    required Color trim,
    required Color skin,
    required Color team,
    required int side,
    required bool back,
    required double bob,
    required double legs,
    required double swing,
    String weapon = 'sword',
    String head = 'helmet',
    bool shield = false,
    bool cape = false,
    double bulk = 1,
    Color? hair,
    bool beard = false,
    bool tusks = false,
    bool ears = false,
    bool noLegs = false,
    bool noShadow = false,
    Color? plume,
    bool robe = false,
    Color? orb,
    double time = 0,
    bool pads = false,
    bool short = false,
    bool tall = false,
    int carry = 0,
  }) {
    final bw = r * 1.25 * bulk;
    final bh = r * (short ? 0.95 : (tall ? 1.25 : 1.1));
    final by = -r * 0.2 + bob; // gövde merkezi
    if (!noShadow) {
      c.drawOval(Rect.fromCenter(center: Offset(0, r * 0.5), width: r * 2.0 * bulk, height: r * 0.85),
          fillP(_shadow));
    }
    // Pelerin
    if (cape) {
      final p = Path()
        ..moveTo(-bw * 0.45, by - bh * 0.4)
        ..lineTo(bw * 0.45, by - bh * 0.4)
        ..lineTo(bw * 0.62 - side * 2, by + bh * 0.65)
        ..lineTo(-bw * 0.62 - side * 2, by + bh * 0.65)
        ..close();
      c.drawPath(p, fillP(shade(team, -0.2)));
    }
    // Bacaklar
    if (!noLegs && !robe) {
      final lc = shade(trim, -0.2);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(-r * 0.42, by + bh * 0.3 + legs * 1.5, r * 0.32, r * 0.55), Radius.circular(r * 0.12)),
          fillP(lc));
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(r * 0.1, by + bh * 0.3 - legs * 1.5, r * 0.32, r * 0.55), Radius.circular(r * 0.12)),
          fillP(lc));
    }
    // Arka elde kalkan (arkadan bakarken önde)
    void drawShield() {
      final sx = -side * bw * 0.52;
      final sp = Path()
        ..moveTo(sx - r * 0.38, by - bh * 0.25)
        ..lineTo(sx + r * 0.38, by - bh * 0.25)
        ..lineTo(sx + r * 0.38, by + bh * 0.12)
        ..quadraticBezierTo(sx + r * 0.3, by + bh * 0.45, sx, by + bh * 0.55)
        ..quadraticBezierTo(sx - r * 0.3, by + bh * 0.45, sx - r * 0.38, by + bh * 0.12)
        ..close();
      c.drawPath(sp, fillP(team));
      c.drawPath(sp, strokeP(shade(trim, -0.1), max(1, r * 0.1)));
      c.drawLine(Offset(sx, by - bh * 0.15), Offset(sx, by + bh * 0.4), strokeP(_goldC.withValues(alpha: 0.8), r * 0.08));
    }

    // Gövde
    final bodyRect = Rect.fromCenter(center: Offset(0, by), width: bw, height: bh);
    if (robe) {
      final p = Path()
        ..moveTo(-bw * 0.42, by - bh * 0.5)
        ..lineTo(bw * 0.42, by - bh * 0.5)
        ..lineTo(bw * 0.62, by + bh * 0.75)
        ..lineTo(-bw * 0.62, by + bh * 0.75)
        ..close();
      c.drawPath(p, fillP(body));
      c.drawLine(Offset(0, by - bh * 0.45), Offset(0, by + bh * 0.72), strokeP(trim, r * 0.12));
      c.drawPath(p, strokeP(shade(body, -0.35), max(1, r * 0.07)));
    } else {
      c.drawRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(r * 0.35)), fillP(body));
      // tabard
      c.drawRect(Rect.fromCenter(center: Offset(0, by + bh * 0.08), width: bw * 0.32, height: bh * 0.85),
          fillP(team));
      c.drawLine(Offset(-bw * 0.48, by + bh * 0.22), Offset(bw * 0.48, by + bh * 0.22), strokeP(trim, r * 0.13));
      c.drawRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(r * 0.35)),
          strokeP(shade(body, -0.4), max(1, r * 0.07)));
    }
    if (pads) {
      for (final sx in [-1, 1]) {
        c.drawOval(
            Rect.fromCenter(center: Offset(sx * bw * 0.48, by - bh * 0.38), width: r * 0.62, height: r * 0.42),
            fillP(team));
        c.drawLine(Offset(sx * bw * 0.48, by - bh * 0.62), Offset(sx * bw * 0.55, by - bh * 0.78),
            strokeP(const Color(0xFFEEEEDD), r * 0.1));
      }
    }
    if (shield && back) drawShield();

    // Yük
    if (carry == 1) {
      c.drawCircle(Offset(-side * bw * 0.35, by - bh * 0.1), r * 0.42, fillP(const Color(0xFFC8A15A)));
      c.drawCircle(Offset(-side * bw * 0.35, by - bh * 0.18), r * 0.18, fillP(_goldC));
    } else if (carry == 2) {
      for (var i = 0; i < 3; i++) {
        c.drawLine(Offset(-side * bw * 0.65, by - bh * 0.35 + i * r * 0.18),
            Offset(-side * bw * 0.05, by - bh * 0.5 + i * r * 0.18), strokeP(const Color(0xFF8D6E63), r * 0.2));
      }
    }

    // Kafa
    final hr = r * 0.42 * (bulk > 1.3 ? 1.1 : 1);
    final hy = by - bh * 0.5 - hr * 0.55;
    final hc = Offset(0, hy);
    if (head == 'horns') {
      for (final sx in [-1.0, 1.0]) {
        final hp = Path()
          ..moveTo(sx * hr * 0.6, hy - hr * 0.2)
          ..quadraticBezierTo(sx * hr * 1.9, hy - hr * 0.4, sx * hr * 1.5, hy - hr * 1.6);
        c.drawPath(hp, strokeP(const Color(0xFFF5EBD7), hr * 0.35));
      }
    }
    if (ears) {
      for (final sx in [-1.0, 1.0]) {
        final ep = Path()
          ..moveTo(sx * hr * 0.7, hy - hr * 0.1)
          ..lineTo(sx * hr * 1.55, hy - hr * 0.45)
          ..lineTo(sx * hr * 0.8, hy + hr * 0.3)
          ..close();
        c.drawPath(ep, fillP(skin));
      }
    }
    if (head == 'gnoll') {
      c.drawCircle(hc, hr, fillP(skin));
      c.drawOval(Rect.fromCenter(center: Offset(side * hr * 0.8, hy + hr * 0.25), width: hr * 1.3, height: hr * 0.75),
          fillP(shade(skin, -0.1)));
      c.drawCircle(Offset(side * hr * 1.4, hy + hr * 0.2), hr * 0.18, fillP(Colors.black87));
      for (final sx in [-0.55, 0.45]) {
        c.drawCircle(Offset(sx * hr, hy - hr * 0.9), hr * 0.3, fillP(shade(skin, -0.25)));
      }
      c.drawCircle(Offset(side * hr * 0.25, hy - hr * 0.1), hr * 0.14, fillP(Colors.black));
    } else {
      c.drawCircle(hc, hr, fillP(skin));
      c.drawCircle(hc, hr, strokeP(shade(skin, -0.35), max(0.8, r * 0.05)));
      if (!back) {
        final ex = side * hr * 0.28;
        c.drawCircle(Offset(ex - hr * 0.22, hy - hr * 0.05), hr * 0.12, fillP(Colors.black87));
        c.drawCircle(Offset(ex + hr * 0.22, hy - hr * 0.05), hr * 0.12, fillP(Colors.black87));
      }
    }
    if (beard) {
      final bp = Path()
        ..moveTo(-hr * 0.75, hy + hr * 0.15)
        ..lineTo(hr * 0.75, hy + hr * 0.15)
        ..lineTo(0, hy + hr * 1.5)
        ..close();
      c.drawPath(bp, fillP(hair ?? const Color(0xFF8D6E63)));
    }
    if (tusks && !back) {
      c.drawLine(Offset(-hr * 0.35, hy + hr * 0.45), Offset(-hr * 0.45, hy + hr * 0.05),
          strokeP(const Color(0xFFFFF8E1), hr * 0.18));
      c.drawLine(Offset(hr * 0.35, hy + hr * 0.45), Offset(hr * 0.45, hy + hr * 0.05),
          strokeP(const Color(0xFFFFF8E1), hr * 0.18));
    }
    switch (head) {
      case 'helmet':
        c.drawArc(Rect.fromCircle(center: hc, radius: hr * 1.05), pi, pi, true, fillP(_steel));
        c.drawArc(Rect.fromCircle(center: hc, radius: hr * 1.05), pi, pi, false, strokeP(_steelDark, hr * 0.12));
        if (!back) c.drawLine(Offset(side * hr * 0.25, hy - hr * 0.4), Offset(side * hr * 0.25, hy + hr * 0.25), strokeP(_steelDark, hr * 0.18));
        if (plume != null) {
          c.drawOval(Rect.fromCenter(center: Offset(-side * hr * 0.2, hy - hr * 1.2), width: hr * 1.2, height: hr * 0.55),
              fillP(plume));
        }
      case 'hair':
        c.drawArc(Rect.fromCircle(center: hc, radius: hr * 1.02), pi * 1.05, pi * 0.9, true,
            fillP(hair ?? const Color(0xFF5D4037)));
      case 'mohawk':
        c.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, hy - hr * 0.95), width: hr * 0.45, height: hr * 0.9),
                Radius.circular(hr * 0.2)),
            fillP(hair ?? Colors.red));
      case 'hood':
        final hp = Path()
          ..addArc(Rect.fromCircle(center: hc, radius: hr * 1.18), pi * 0.85, pi * 1.3)
          ..lineTo(0, hy - hr * 1.7)
          ..close();
        c.drawPath(hp, fillP(shade(body, 0.1)));
      case 'wolfhood':
        c.drawArc(Rect.fromCircle(center: hc, radius: hr * 1.15), pi, pi, true, fillP(const Color(0xFF9E9E9E)));
        c.drawCircle(Offset(-hr * 0.6, hy - hr * 1.0), hr * 0.3, fillP(const Color(0xFF8D8D8D)));
        c.drawCircle(Offset(hr * 0.6, hy - hr * 1.0), hr * 0.3, fillP(const Color(0xFF8D8D8D)));
      case 'horns':
        c.drawCircle(Offset(side * hr * 0.55, hy + hr * 0.35), hr * 0.45, fillP(shade(skin, -0.15)));
        c.drawCircle(Offset(side * hr * 0.55, hy + hr * 0.35), hr * 0.12, fillP(const Color(0xFFFFD54F)));
    }

    // Silah
    final hand = Offset(side * bw * 0.55, by - bh * 0.05);
    final sw = swing.clamp(0.0, 1.0);
    // 0 → kaldırılmış, 0.5 → vuruş, 1 → dinlenme
    double ang;
    if (sw < 0.5) {
      ang = -1.4 + sw / 0.5 * 1.85;
    } else {
      ang = 0.45 - (sw - 0.5) / 0.5 * 1.35;
    }
    if (side < 0) ang = pi - ang;
    final dir = Offset(cos(ang), sin(ang));
    final perp = Offset(-dir.dy, dir.dx);
    switch (weapon) {
      case 'sword':
        final tip = hand + dir * (r * 1.25);
        c.drawLine(hand, tip, strokeP(const Color(0xFFE0E6EA), r * 0.2));
        c.drawLine(hand + dir * (r * 0.18) + perp * (r * 0.25), hand + dir * (r * 0.18) - perp * (r * 0.25),
            strokeP(_goldC, r * 0.14));
      case 'axe':
        final tip = hand + dir * (r * 1.3);
        c.drawLine(hand - dir * (r * 0.2), tip, strokeP(_wood, r * 0.17));
        final ap = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo((tip + perp * (r * 0.6) - dir * (r * 0.25)).dx, (tip + perp * (r * 0.6) - dir * (r * 0.25)).dy)
          ..quadraticBezierTo((tip + perp * (r * 0.75) - dir * (r * 0.55)).dx, (tip + perp * (r * 0.75) - dir * (r * 0.55)).dy,
              (tip + perp * (r * 0.5) - dir * (r * 0.7)).dx, (tip + perp * (r * 0.5) - dir * (r * 0.7)).dy)
          ..lineTo((tip - dir * (r * 0.45)).dx, (tip - dir * (r * 0.45)).dy)
          ..close();
        c.drawPath(ap, fillP(const Color(0xFFB0BEC5)));
        c.drawPath(ap, strokeP(const Color(0xFF546E7A), r * 0.06));
      case 'hammer':
        final tip = hand + dir * (r * 1.25);
        c.drawLine(hand - dir * (r * 0.15), tip, strokeP(_wood, r * 0.16));
        c.save();
        c.translate(tip.dx, tip.dy);
        c.rotate(ang);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: r * 0.45, height: r * 0.8),
            Radius.circular(r * 0.1)), fillP(const Color(0xFFCFD8DC)));
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: r * 0.45, height: r * 0.8),
            Radius.circular(r * 0.1)), strokeP(_goldC, r * 0.08));
        c.restore();
      case 'totem':
        final tip = hand + dir * (r * 1.4);
        c.drawLine(hand - dir * (r * 0.3), tip, strokeP(const Color(0xFF5D4037), r * 0.22));
        c.drawCircle(tip, r * 0.38, fillP(const Color(0xFF8D6E63)));
        c.drawCircle(tip, r * 0.38, strokeP(const Color(0xFF3E2723), r * 0.08));
      case 'pick':
        final tip = hand + dir * (r * 1.0);
        c.drawLine(hand - dir * (r * 0.1), tip, strokeP(_wood, r * 0.15));
        final pp = Path()
          ..moveTo((tip + perp * (r * 0.55) - dir * (r * 0.25)).dx, (tip + perp * (r * 0.55) - dir * (r * 0.25)).dy)
          ..quadraticBezierTo(tip.dx + dir.dx * r * 0.15, tip.dy + dir.dy * r * 0.15,
              (tip - perp * (r * 0.55) - dir * (r * 0.25)).dx, (tip - perp * (r * 0.55) - dir * (r * 0.25)).dy);
        c.drawPath(pp, strokeP(const Color(0xFF90A4AE), r * 0.14));
      case 'club':
        final tip = hand + dir * (r * 1.15);
        c.drawLine(hand, tip, strokeP(const Color(0xFF8D6E63), r * 0.32));
        c.drawCircle(tip, r * 0.24, fillP(const Color(0xFF795548)));
      case 'spear':
        final a2 = side > 0 ? -0.9 + (1 - sw) * 0.6 : pi + 0.9 - (1 - sw) * 0.6;
        final d2 = Offset(cos(a2), sin(a2));
        final p2 = Offset(-d2.dy, d2.dx);
        final tip = hand + d2 * (r * 1.4);
        c.drawLine(hand - d2 * (r * 0.8), tip, strokeP(_wood, r * 0.12));
        final sp = Path()
          ..moveTo((tip + d2 * (r * 0.45)).dx, (tip + d2 * (r * 0.45)).dy)
          ..lineTo((tip + p2 * (r * 0.18)).dx, (tip + p2 * (r * 0.18)).dy)
          ..lineTo((tip - p2 * (r * 0.18)).dx, (tip - p2 * (r * 0.18)).dy)
          ..close();
        c.drawPath(sp, fillP(const Color(0xFFCFD8DC)));
      case 'bow':
        final bc = Offset(side * bw * 0.7, by - bh * 0.1);
        c.drawArc(Rect.fromCenter(center: bc, width: r * 0.9, height: r * 1.6), side > 0 ? -pi / 2 : pi / 2, pi, false,
            strokeP(const Color(0xFF8D6E63), r * 0.13));
        c.drawLine(bc + Offset(0, -r * 0.8), bc + Offset(0, r * 0.8), strokeP(Colors.white70, r * 0.05));
      case 'gun':
        final g0 = Offset(side * bw * 0.1, by);
        final g1 = g0 + Offset(side * r * 1.5, -r * 0.15 - (1 - sw) * r * 0.2);
        c.drawLine(g0, g1, strokeP(const Color(0xFF455A64), r * 0.22));
        c.drawLine(g0, g0 + Offset(side * r * 0.55, r * 0.05), strokeP(_wood, r * 0.3));
      case 'staff':
        final top = Offset(side * bw * 0.6, by - bh * 1.15);
        final bot = Offset(side * bw * 0.6, by + bh * 0.6);
        c.drawLine(bot, top, strokeP(const Color(0xFF6D4C41), r * 0.14));
        final o = orb ?? Colors.lightBlueAccent;
        c.drawCircle(top, r * 0.42 + sin(time * 4) * r * 0.05, fillP(o.withValues(alpha: 0.35)));
        c.drawCircle(top, r * 0.24, fillP(o));
    }
    // El
    c.drawCircle(hand, r * 0.17, fillP(skin));
    if (shield && !back) drawShield();
  }

  static void _mount(Canvas c,
      {required double r,
      required Color color,
      required int side,
      required double legs,
      required Color team,
      bool wolf = false,
      bool armored = false,
      bool ghost = false}) {
    final col = ghost ? color.withValues(alpha: 0.75) : color;
    c.drawOval(Rect.fromCenter(center: Offset(0, r * 0.5), width: r * 2.4, height: r * 0.9), fillP(_shadow));
    final dark = shade(col, -0.3);
    // Bacaklar
    for (var i = 0; i < 4; i++) {
      final lx = (i < 2 ? side * r * 0.62 : -side * r * 0.62) + (i.isEven ? 3 : -3);
      final sw = (i.isEven ? legs : -legs) * 3;
      c.drawLine(Offset(lx, r * 0.0), Offset(lx + sw, r * 0.5), strokeP(dark, r * 0.18));
    }
    // Kuyruk
    final tail = Path()
      ..moveTo(-side * r * 0.95, -r * 0.2)
      ..quadraticBezierTo(-side * r * 1.45, -r * 0.1, -side * r * 1.35, wolf ? -r * 0.55 : r * 0.35);
    c.drawPath(tail, strokeP(wolf ? col : const Color(0xFF5D4037), r * (wolf ? 0.28 : 0.18)));
    // Gövde
    final body = Rect.fromCenter(center: Offset(0, -r * 0.12), width: r * 2.1, height: r * 0.95);
    c.drawOval(body, fillP(col));
    c.drawOval(body, strokeP(dark, max(1, r * 0.07)));
    if (armored) {
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, -r * 0.08), width: r * 1.5, height: r * 0.8),
              Radius.circular(r * 0.2)),
          fillP(team));
      c.drawLine(Offset(-r * 0.75, r * 0.28), Offset(r * 0.75, r * 0.28), strokeP(_goldC, r * 0.1));
    }
    if (wolf && !ghost) {
      c.drawLine(Offset(-r * 0.4, -r * 0.5), Offset(r * 0.4, -r * 0.5), strokeP(team, r * 0.22));
    }
    // Boyun + kafa
    final neck = Offset(side * r * 0.85, -r * 0.35);
    final head = Offset(side * r * 1.2, -r * 0.7);
    c.drawLine(neck, head, strokeP(col, r * 0.45));
    if (wolf) {
      final hp = Path()
        ..moveTo(head.dx - side * r * 0.25, head.dy - r * 0.25)
        ..lineTo(head.dx + side * r * 0.6, head.dy + r * 0.05)
        ..lineTo(head.dx - side * r * 0.2, head.dy + r * 0.25)
        ..close();
      c.drawPath(hp, fillP(col));
      c.drawPath(
          Path()
            ..moveTo(head.dx - side * r * 0.2, head.dy - r * 0.2)
            ..lineTo(head.dx - side * r * 0.05, head.dy - r * 0.55)
            ..lineTo(head.dx + side * r * 0.08, head.dy - r * 0.15)
            ..close(),
          fillP(dark));
      c.drawCircle(head + Offset(side * r * 0.12, -r * 0.03), r * 0.07, fillP(ghost ? Colors.cyanAccent : Colors.amber));
    } else {
      c.drawOval(Rect.fromCenter(center: head + Offset(side * r * 0.2, 0), width: r * 0.8, height: r * 0.42), fillP(col));
      c.drawLine(head + Offset(-side * r * 0.15, -r * 0.2), head + Offset(-side * r * 0.25, r * 0.1),
          strokeP(const Color(0xFF5D4037), r * 0.14));
      if (armored) {
        c.drawOval(Rect.fromCenter(center: head + Offset(side * r * 0.1, 0), width: r * 0.5, height: r * 0.36),
            fillP(_steel));
      }
    }
  }

  static void _waterElemental(Canvas c, double r, double time) {
    c.drawOval(Rect.fromCenter(center: Offset(0, r * 0.5), width: r * 2.2, height: r * 0.8),
        fillP(const Color(0x553FA9F5)));
    for (var i = 0; i < 4; i++) {
      final rr = r * (1.0 - i * 0.18);
      final yy = -r * 0.2 - i * r * 0.32 + sin(time * 3 + i) * 1.5;
      final xx = sin(time * 2 + i * 1.3) * r * 0.15;
      c.drawCircle(Offset(xx, yy), rr, fillP(Color.lerp(const Color(0xCC1E88E5), const Color(0xDDB3E5FC), i / 4)!));
    }
    c.drawCircle(Offset(-r * 0.2, -r * 1.2), r * 0.1, fillP(Colors.white));
    c.drawCircle(Offset(r * 0.2, -r * 1.2), r * 0.1, fillP(Colors.white));
  }

  static void _murloc(Canvas c, double r, int side, double bob, double swing, double legs) {
    c.drawOval(Rect.fromCenter(center: Offset(0, r * 0.5), width: r * 1.9, height: r * 0.8), fillP(_shadow));
    const sk = Color(0xFF4CAF7A);
    c.drawLine(Offset(-r * 0.3, r * 0.1), Offset(-r * 0.35 + legs * 2, r * 0.5), strokeP(shade(sk, -0.3), r * 0.25));
    c.drawLine(Offset(r * 0.3, r * 0.1), Offset(r * 0.35 - legs * 2, r * 0.5), strokeP(shade(sk, -0.3), r * 0.25));
    c.drawOval(Rect.fromCenter(center: Offset(0, -r * 0.3 + bob), width: r * 1.6, height: r * 1.5), fillP(sk));
    c.drawOval(Rect.fromCenter(center: Offset(0, -r * 0.1 + bob), width: r * 0.9, height: r * 0.8),
        fillP(const Color(0xFFC5E1A5)));
    // yüzgeç
    final fp = Path()
      ..moveTo(-r * 0.2, -r * 1.0 + bob)
      ..lineTo(0, -r * 1.45 + bob)
      ..lineTo(r * 0.25, -r * 1.0 + bob)
      ..close();
    c.drawPath(fp, fillP(const Color(0xFFE57373)));
    c.drawCircle(Offset(side * r * 0.35, -r * 0.7 + bob), r * 0.2, fillP(Colors.white));
    c.drawCircle(Offset(side * r * 0.4, -r * 0.7 + bob), r * 0.1, fillP(Colors.black));
    final a = side > 0 ? -1.0 + swing * 0.8 : pi + 1.0 - swing * 0.8;
    final h = Offset(side * r * 0.75, -r * 0.3 + bob);
    c.drawLine(h - Offset(cos(a), sin(a)) * r * 0.5, h + Offset(cos(a), sin(a)) * r * 1.3, strokeP(_wood, r * 0.12));
    c.drawCircle(h + Offset(cos(a), sin(a)) * r * 1.35, r * 0.15, fillP(const Color(0xFFCFD8DC)));
  }

  static void _golem(Canvas c, double r, int side, double bob, double swing) {
    c.drawOval(Rect.fromCenter(center: Offset(0, r * 0.5), width: r * 2.2, height: r * 0.9), fillP(_shadow));
    const rock = Color(0xFF8D8A85);
    final dark = shade(rock, -0.35);
    final body = Path()
      ..moveTo(-r * 0.8, -r * 0.1 + bob)
      ..lineTo(-r * 0.6, -r * 1.0 + bob)
      ..lineTo(r * 0.1, -r * 1.25 + bob)
      ..lineTo(r * 0.75, -r * 0.85 + bob)
      ..lineTo(r * 0.85, -r * 0.05 + bob)
      ..lineTo(r * 0.3, r * 0.35 + bob)
      ..lineTo(-r * 0.4, r * 0.3 + bob)
      ..close();
    c.drawPath(body, fillP(rock));
    c.drawPath(body, strokeP(dark, r * 0.08));
    c.drawCircle(Offset(-r * 0.25, -r * 0.4 + bob), r * 0.18, fillP(const Color(0xFF7CB342)));
    final arm = side * r * (1.0 + (1 - swing) * 0.15);
    c.drawCircle(Offset(arm, -r * 0.35 + bob + (swing < 0.5 ? -r * 0.3 : 0)), r * 0.4, fillP(shade(rock, -0.1)));
    c.drawCircle(Offset(-side * r * 0.95, -r * 0.3 + bob), r * 0.35, fillP(shade(rock, -0.15)));
    c.drawCircle(Offset(side * r * 0.1, -r * 1.35 + bob), r * 0.32, fillP(shade(rock, 0.1)));
    c.drawCircle(Offset(side * r * 0.2, -r * 1.38 + bob), r * 0.08, fillP(const Color(0xFFFFEB3B)));
  }

  static void _dragon(Canvas c, double r, int side, double time, double swing) {
    c.drawOval(Rect.fromCenter(center: Offset(0, r * 0.6), width: r * 3.0, height: r * 1.1), fillP(_shadow));
    const red = Color(0xFFC62828);
    final dark = shade(red, -0.35);
    final flap = sin(time * 2.5) * r * 0.25;
    for (final sx in [-1.0, 1.0]) {
      final wp = Path()
        ..moveTo(sx * r * 0.2, -r * 0.6)
        ..lineTo(sx * r * 1.6, -r * 1.5 - flap)
        ..lineTo(sx * r * 1.3, -r * 0.4)
        ..lineTo(sx * r * 0.9, -r * 0.2)
        ..close();
      c.drawPath(wp, fillP(const Color(0xFF8E2424)));
      c.drawPath(wp, strokeP(dark, r * 0.05));
    }
    final tail = Path()
      ..moveTo(-side * r * 0.6, -r * 0.1)
      ..quadraticBezierTo(-side * r * 1.5, r * 0.3, -side * r * 1.6, -r * 0.4);
    c.drawPath(tail, strokeP(red, r * 0.22));
    c.drawOval(Rect.fromCenter(center: Offset(0, -r * 0.3), width: r * 1.7, height: r * 1.1), fillP(red));
    c.drawOval(Rect.fromCenter(center: Offset(side * r * 0.1, -r * 0.15), width: r * 0.9, height: r * 0.6),
        fillP(const Color(0xFFFFB74D)));
    final head = Offset(side * r * 1.15, -r * (swing < 0.5 ? 0.6 : 0.9));
    c.drawLine(Offset(side * r * 0.5, -r * 0.5), head, strokeP(red, r * 0.4));
    c.drawOval(Rect.fromCenter(center: head + Offset(side * r * 0.15, 0), width: r * 0.8, height: r * 0.45), fillP(red));
    c.drawLine(head + Offset(-side * r * 0.1, -r * 0.15), head + Offset(-side * r * 0.4, -r * 0.45),
        strokeP(const Color(0xFFFFF3E0), r * 0.1));
    c.drawCircle(head + Offset(side * r * 0.15, -r * 0.07), r * 0.07, fillP(Colors.yellow));
  }

  // ------------------------------------------------------------ Ölü beden

  static void corpse(Canvas c, UnitType t, Color team, double alpha) {
    final r = t.radius;
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2.2, height: r * 1.0),
        fillP(const Color(0xFF5D1F1A).withValues(alpha: 0.5 * alpha)));
    c.drawOval(Rect.fromCenter(center: const Offset(0, -2), width: r * 1.6, height: r * 0.7),
        fillP(Color.lerp(team, Colors.black, 0.45)!.withValues(alpha: alpha)));
    c.drawCircle(Offset(r * 0.8, -3), r * 0.32, fillP(const Color(0xFF9E9E9E).withValues(alpha: alpha)));
  }

  // ------------------------------------------------------------ Ağaçlar

  static final List<ui.Image> _trees = [];

  static void initTrees() {
    if (_trees.isNotEmpty) return;
    for (var v = 0; v < 4; v++) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.translate(26, 58);
      _drawTree(c, v);
      final pic = rec.endRecording();
      _trees.add(pic.toImageSync(52, 66));
      pic.dispose();
    }
  }

  static void _drawTree(Canvas c, int v) {
    final s = 0.9 + v * 0.06;
    c.drawOval(Rect.fromCenter(center: const Offset(3, 2), width: 34 * s, height: 13 * s), fillP(const Color(0x66000000)));
    c.drawRect(Rect.fromCenter(center: Offset(0, -4 * s), width: 5 * s, height: 10 * s), fillP(const Color(0xFF5D4037)));
    final greens = [
      const Color(0xFF1B5E20),
      const Color(0xFF2E7D32),
      const Color(0xFF388E3C),
    ];
    final base = v.isEven ? 0.0 : 0.05;
    for (var i = 0; i < 3; i++) {
      final w = (30 - i * 7) * s;
      final y0 = (-6 - i * 12) * s;
      final p = Path()
        ..moveTo(-w / 2, y0)
        ..quadraticBezierTo(0, y0 + 5 * s, w / 2, y0)
        ..lineTo(0, y0 - 20 * s)
        ..close();
      c.drawPath(p, fillP(shade(greens[i], base)));
      final hl = Path()
        ..moveTo(-w * 0.1, y0 - 1)
        ..lineTo(w * 0.35, y0 - 1)
        ..lineTo(0, y0 - 18 * s)
        ..close();
      c.drawPath(hl, fillP(Colors.white.withValues(alpha: 0.08)));
    }
    if (v == 3) {
      c.drawCircle(Offset(-5 * s, -18 * s), 1.8, fillP(const Color(0xFFE8F5E9).withValues(alpha: 0.4)));
    }
  }

  static void tree(Canvas c, double x, double y, int variant) {
    if (_trees.isEmpty) {
      c.save();
      c.translate(x, y);
      _drawTree(c, variant & 3);
      c.restore();
      return;
    }
    c.drawImage(_trees[variant & 3], Offset(x - 26, y - 58), _f..color = Colors.white);
  }

  // ------------------------------------------------------------ Altın madeni

  static void goldMine(Canvas c, double w, double h, double time) {
    c.drawOval(Rect.fromLTWH(-4, h * 0.45, w + 8, h * 0.6), fillP(_shadow));
    const rock = Color(0xFF8B7B6B);
    final p = Path()
      ..moveTo(0, h * 0.95)
      ..lineTo(w * 0.05, h * 0.35)
      ..lineTo(w * 0.3, h * 0.0)
      ..lineTo(w * 0.62, -h * 0.08)
      ..lineTo(w * 0.9, h * 0.22)
      ..lineTo(w, h * 0.95)
      ..close();
    c.drawPath(p, fillP(rock));
    c.drawPath(p, strokeP(shade(rock, -0.4), 2));
    c.drawPath(
        Path()
          ..moveTo(w * 0.3, h * 0.0)
          ..lineTo(w * 0.45, h * 0.4)
          ..lineTo(w * 0.62, -h * 0.08),
        strokeP(shade(rock, -0.25), 1.5));
    // giriş
    final door = Rect.fromLTWH(w * 0.3, h * 0.45, w * 0.4, h * 0.5);
    c.drawRRect(RRect.fromRectAndCorners(door, topLeft: Radius.circular(w * 0.2), topRight: Radius.circular(w * 0.2)),
        fillP(const Color(0xFF1A1410)));
    c.drawLine(Offset(w * 0.27, h * 0.95), Offset(w * 0.27, h * 0.45), strokeP(_wood, 4));
    c.drawLine(Offset(w * 0.73, h * 0.95), Offset(w * 0.73, h * 0.45), strokeP(_wood, 4));
    c.drawLine(Offset(w * 0.24, h * 0.45), Offset(w * 0.76, h * 0.45), strokeP(_wood, 5));
    // altın parçaları
    final rnd = Random(7);
    for (var i = 0; i < 9; i++) {
      final gx = w * (0.12 + rnd.nextDouble() * 0.76), gy = h * (0.1 + rnd.nextDouble() * 0.35);
      final tw = 0.6 + 0.4 * sin(time * 3 + i * 1.7);
      c.drawCircle(Offset(gx, gy), 2.6, fillP(_goldC));
      if (tw > 0.9) c.drawCircle(Offset(gx, gy), 4.5, fillP(Colors.white.withValues(alpha: 0.5)));
    }
    c.drawCircle(Offset(w * 0.15, h * 0.88), 5, fillP(_goldC));
    c.drawCircle(Offset(w * 0.85, h * 0.9), 4, fillP(_goldC));
  }

  // ------------------------------------------------------------ Binalar

  /// (0,0) = taban dikdörtgeninin sol üstü.
  static void building(Canvas c, UnitType t, Color team, double w, double h,
      {double progress = 1, double time = 0}) {
    if (t.isMine) {
      goldMine(c, w, h, time);
      return;
    }
    final orc = t.id.startsWith('o_');
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-3, 4, w + 6, h + 2), const Radius.circular(8)),
        fillP(const Color(0x44000000)));
    if (progress < 1) {
      // temel
      c.drawRect(Rect.fromLTWH(2, 2, w - 4, h - 4), fillP(const Color(0xFF7A6A55)));
      c.save();
      final top = -h * 0.6;
      final clipTop = h - (h - top) * progress;
      c.clipRect(Rect.fromLTRB(-20, clipTop, w + 20, h + 20));
      _drawBuilding(c, t, team, w, h, orc, time, progress);
      c.restore();
      final sc = strokeP(const Color(0xFFBCA27A), 2);
      for (var i = 0; i <= 4; i++) {
        final x = 4 + (w - 8) * i / 4;
        c.drawLine(Offset(x, h - 2), Offset(x, max(clipTop, top + 6)), sc);
      }
      for (var y = h - 8; y > max(clipTop, top + 6); y -= 14) {
        c.drawLine(Offset(4, y), Offset(w - 4, y), sc);
      }
      return;
    }
    _drawBuilding(c, t, team, w, h, orc, time, 1);
  }

  static void _drawBuilding(Canvas c, UnitType t, Color team, double w, double h, bool orc, double time, double prog) {
    final kind = t.id.substring(2);
    switch (kind) {
      case 'hall':
        orc ? _orcHall(c, team, w, h, time) : _humanHall(c, team, w, h, time);
      case 'farm':
      case 'burrow':
        orc ? _burrow(c, team, w, h) : _farm(c, team, w, h);
      case 'barracks':
        orc ? _orcBarracks(c, team, w, h, time) : _humanBarracks(c, team, w, h, time);
      case 'altar':
        _altar(c, team, w, h, time, orc);
      case 'smith':
      case 'mill':
        _smith(c, team, w, h, time, orc);
      case 'tower':
        _tower(c, team, w, h, time, orc);
    }
  }

  static void _walls(Canvas c, Rect r, bool orc) {
    if (orc) {
      c.drawRect(r, fillP(const Color(0xFF7B5435)));
      for (var x = r.left + 5; x < r.right; x += 7) {
        c.drawLine(Offset(x, r.top), Offset(x, r.bottom), strokeP(const Color(0xFF5D3A22), 1.2));
      }
      c.drawRect(r, strokeP(const Color(0xFF3E2716), 1.5));
    } else {
      c.drawRect(r, fillP(const Color(0xFFE9DFC8)));
      final tb = strokeP(const Color(0xFF6D4C33), 2);
      c.drawLine(Offset(r.left, r.top + r.height * 0.45), Offset(r.right, r.top + r.height * 0.45), tb);
      for (var x = r.left; x <= r.right + 0.1; x += r.width / 3) {
        c.drawLine(Offset(x, r.top), Offset(x, r.bottom), tb);
      }
      c.drawRect(r, strokeP(const Color(0xFF5D4037), 1.5));
      // taş temel
      c.drawRect(Rect.fromLTWH(r.left - 2, r.bottom - 6, r.width + 4, 6), fillP(const Color(0xFF9E9E9E)));
    }
  }

  static void _roof(Canvas c, Rect base, double peak, Color team, bool orc) {
    final p = Path()
      ..moveTo(base.left - 6, base.top)
      ..lineTo(base.left + base.width * 0.18, base.top - peak)
      ..lineTo(base.right - base.width * 0.18, base.top - peak)
      ..lineTo(base.right + 6, base.top)
      ..close();
    if (orc) {
      c.drawPath(p, fillP(const Color(0xFFC9A66B)));
      c.drawPath(p, strokeP(const Color(0xFF6D4C33), 2));
      for (var i = 1; i < 4; i++) {
        final y = base.top - peak * i / 4;
        c.drawLine(Offset(base.left + base.width * 0.05 * i, y), Offset(base.right - base.width * 0.05 * i, y),
            strokeP(team.withValues(alpha: 0.85), 2.5));
      }
      // kemik dikenler
      for (final x in [base.left - 4, base.right + 4]) {
        c.drawLine(Offset(x, base.top), Offset(x + (x < base.center.dx ? -8 : 8), base.top - peak * 0.7),
            strokeP(const Color(0xFFF5EBD7), 3.5));
      }
    } else {
      c.drawPath(p, fillP(team));
      final sh = Path()
        ..moveTo(base.left - 6, base.top)
        ..lineTo(base.left + base.width * 0.18, base.top - peak)
        ..lineTo(base.center.dx, base.top - peak)
        ..lineTo(base.center.dx, base.top)
        ..close();
      c.drawPath(sh, fillP(Colors.black.withValues(alpha: 0.12)));
      for (var i = 1; i < 4; i++) {
        final y = base.top - peak * i / 4;
        c.drawLine(Offset(base.left + base.width * 0.05 * i - 4, y), Offset(base.right - base.width * 0.05 * i + 4, y),
            strokeP(shade(team, -0.3), 1));
      }
      c.drawPath(p, strokeP(shade(team, -0.45), 2));
    }
  }

  static void _flag(Canvas c, Offset base, double hgt, Color team, double time) {
    c.drawLine(base, base - Offset(0, hgt), strokeP(const Color(0xFF5D4037), 2));
    final top = base - Offset(0, hgt);
    final wv = sin(time * 4) * 2;
    final p = Path()
      ..moveTo(top.dx, top.dy)
      ..quadraticBezierTo(top.dx + 8, top.dy + 2 + wv, top.dx + 16, top.dy + 1)
      ..lineTo(top.dx + 16, top.dy + 9)
      ..quadraticBezierTo(top.dx + 8, top.dy + 10 - wv, top.dx, top.dy + 9)
      ..close();
    c.drawPath(p, fillP(team));
  }

  static void _door(Canvas c, double cx, double bottom, double dw, double dh, bool orc) {
    final r = Rect.fromLTWH(cx - dw / 2, bottom - dh, dw, dh);
    c.drawRRect(RRect.fromRectAndCorners(r, topLeft: Radius.circular(dw / 2), topRight: Radius.circular(dw / 2)),
        fillP(orc ? const Color(0xFF2B1B10) : const Color(0xFF4E342E)));
  }

  static void _window(Canvas c, double x, double y, double s) {
    c.drawRect(Rect.fromCenter(center: Offset(x, y), width: s, height: s * 1.2), fillP(const Color(0xFF3E2F25)));
    c.drawRect(Rect.fromCenter(center: Offset(x, y), width: s * 0.7, height: s * 0.9), fillP(const Color(0xFFFFE08A)));
  }

  static void _humanHall(Canvas c, Color team, double w, double h, double time) {
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(2, h * 0.3, w - 4, h * 0.7 - 2), const Radius.circular(6)),
        fillP(const Color(0xFF9E9E9E)));
    final wall = Rect.fromLTWH(10, h * 0.42, w - 20, h * 0.5);
    _walls(c, wall, false);
    _roof(c, wall, h * 0.32, team, false);
    // kule
    final tw = w * 0.26;
    final tower = Rect.fromLTWH(w / 2 - tw / 2, h * 0.05, tw, h * 0.55);
    c.drawRect(tower, fillP(const Color(0xFFBDBDBD)));
    for (var y = tower.top + 6; y < tower.bottom; y += 8) {
      c.drawLine(Offset(tower.left, y), Offset(tower.right, y), strokeP(const Color(0xFF8D8D8D), 1));
    }
    c.drawRect(tower, strokeP(const Color(0xFF616161), 1.5));
    final cone = Path()
      ..moveTo(tower.left - 5, tower.top)
      ..lineTo(w / 2, tower.top - h * 0.3)
      ..lineTo(tower.right + 5, tower.top)
      ..close();
    c.drawPath(cone, fillP(team));
    c.drawPath(cone, strokeP(shade(team, -0.45), 1.5));
    _window(c, w / 2, tower.top + tower.height * 0.35, 8);
    _flag(c, Offset(w / 2, tower.top - h * 0.3), 18, team, time);
    _door(c, w / 2, wall.bottom, 20, 26, false);
    _window(c, wall.left + 14, wall.top + wall.height * 0.7, 9);
    _window(c, wall.right - 14, wall.top + wall.height * 0.7, 9);
  }

  static void _orcHall(Canvas c, Color team, double w, double h, double time) {
    c.drawOval(Rect.fromLTWH(2, h * 0.32, w - 4, h * 0.68), fillP(const Color(0xFF6B5A45)));
    final wall = Rect.fromLTWH(12, h * 0.45, w - 24, h * 0.47);
    _walls(c, wall, true);
    final dome = Path()
      ..moveTo(wall.left - 8, wall.top + 4)
      ..quadraticBezierTo(w / 2, -h * 0.35, wall.right + 8, wall.top + 4)
      ..close();
    c.drawPath(dome, fillP(const Color(0xFFC9A66B)));
    c.drawPath(dome, strokeP(const Color(0xFF6D4C33), 2));
    for (var i = 1; i <= 3; i++) {
      final yy = wall.top - h * 0.12 * i;
      c.drawLine(Offset(wall.left + 10 * i, yy), Offset(wall.right - 10 * i, yy), strokeP(team, 3));
    }
    // dişler
    for (final s in [-1.0, 1.0]) {
      final p = Path()
        ..moveTo(w / 2 + s * 22, wall.bottom - 6)
        ..quadraticBezierTo(w / 2 + s * 40, wall.top - 6, w / 2 + s * 18, wall.top - h * 0.25);
      c.drawPath(p, strokeP(const Color(0xFFF5EBD7), 6));
    }
    _door(c, w / 2, wall.bottom, 22, 28, true);
    c.drawCircle(Offset(w / 2, wall.top - h * 0.05), 7, fillP(const Color(0xFFF5EBD7)));
    c.drawCircle(Offset(w / 2 - 2.5, wall.top - h * 0.06), 1.6, fillP(Colors.black));
    c.drawCircle(Offset(w / 2 + 2.5, wall.top - h * 0.06), 1.6, fillP(Colors.black));
    _flag(c, Offset(wall.left + 4, wall.top), 30, team, time);
    _flag(c, Offset(wall.right - 4, wall.top), 30, team, time + 1);
  }

  static void _farm(Canvas c, Color team, double w, double h) {
    // tarla
    final field = Rect.fromLTWH(3, h * 0.55, w - 6, h * 0.42);
    c.drawRect(field, fillP(const Color(0xFF8D6E4A)));
    for (var y = field.top + 4; y < field.bottom; y += 5) {
      c.drawLine(Offset(field.left + 2, y), Offset(field.right - 2, y), strokeP(const Color(0xFF9CCC65), 1.6));
    }
    final wall = Rect.fromLTWH(8, h * 0.22, w * 0.62, h * 0.36);
    _walls(c, wall, false);
    _roof(c, wall, h * 0.26, team, false);
    _door(c, wall.left + wall.width * 0.35, wall.bottom, 8, 12, false);
    c.drawOval(Rect.fromLTWH(w * 0.72, h * 0.3, w * 0.22, h * 0.22), fillP(const Color(0xFFE6C35C)));
  }

  static void _burrow(Canvas c, Color team, double w, double h) {
    final mound = Path()
      ..moveTo(2, h - 2)
      ..quadraticBezierTo(w / 2, -h * 0.35, w - 2, h - 2)
      ..close();
    c.drawPath(mound, fillP(const Color(0xFF8A6A48)));
    c.drawPath(mound, strokeP(const Color(0xFF4E342E), 2));
    for (var i = 0; i < 5; i++) {
      final x = 8 + (w - 16) * i / 4;
      c.drawLine(Offset(x, h * 0.4 + (i - 2).abs() * 5), Offset(x + (i - 2) * 3, h * 0.05 + (i - 2).abs() * 6),
          strokeP(const Color(0xFFF5EBD7), 3));
    }
    c.drawLine(Offset(w * 0.2, h * 0.45), Offset(w * 0.8, h * 0.45), strokeP(team, 4));
    _door(c, w / 2, h - 2, 14, 16, true);
  }

  static void _humanBarracks(Canvas c, Color team, double w, double h, double time) {
    c.drawRect(Rect.fromLTWH(2, h * 0.3, w - 4, h * 0.68), fillP(const Color(0xFF9E9E9E)));
    final wall = Rect.fromLTWH(8, h * 0.38, w - 16, h * 0.55);
    c.drawRect(wall, fillP(const Color(0xFFB0A89A)));
    for (var y = wall.top + 7; y < wall.bottom; y += 8) {
      c.drawLine(Offset(wall.left, y), Offset(wall.right, y), strokeP(const Color(0xFF8D857A), 1));
    }
    c.drawRect(wall, strokeP(const Color(0xFF5D5D5D), 1.5));
    _roof(c, wall, h * 0.3, team, false);
    _door(c, w / 2, wall.bottom, 18, 22, false);
    // çapraz kılıçlar
    final cc = Offset(w / 2, wall.top + 10);
    c.drawCircle(cc, 9, fillP(team));
    c.drawLine(cc + const Offset(-7, -7), cc + const Offset(7, 7), strokeP(const Color(0xFFE0E0E0), 2.2));
    c.drawLine(cc + const Offset(7, -7), cc + const Offset(-7, 7), strokeP(const Color(0xFFE0E0E0), 2.2));
    _flag(c, Offset(wall.left + 4, wall.top - 2), 26, team, time);
  }

  static void _orcBarracks(Canvas c, Color team, double w, double h, double time) {
    c.drawRect(Rect.fromLTWH(2, h * 0.32, w - 4, h * 0.66), fillP(const Color(0xFF6B5A45)));
    final wall = Rect.fromLTWH(8, h * 0.4, w - 16, h * 0.52);
    _walls(c, wall, true);
    _roof(c, wall, h * 0.32, team, true);
    _door(c, w / 2, wall.bottom, 18, 22, true);
    for (var i = 0; i < 6; i++) {
      final x = wall.left + 4 + (wall.width - 8) * i / 5;
      c.drawLine(Offset(x, wall.bottom), Offset(x - 4, wall.bottom + 6), strokeP(const Color(0xFFF5EBD7), 2.5));
    }
    _flag(c, Offset(wall.right - 4, wall.top - 6), 26, team, time);
  }

  static void _altar(Canvas c, Color team, double w, double h, double time, bool orc) {
    final plat = Rect.fromLTWH(4, h * 0.25, w - 8, h * 0.7);
    c.drawOval(plat.inflate(2), fillP(orc ? const Color(0xFF4E4A47) : const Color(0xFF9E9E9E)));
    c.drawOval(plat.deflate(8), fillP(orc ? const Color(0xFF5E5753) : const Color(0xFFBDBDBD)));
    final glow = 0.5 + 0.3 * sin(time * 2.5);
    final col = orc ? const Color(0xFF80DEEA) : const Color(0xFFFFE082);
    c.drawOval(plat.deflate(18), fillP(col.withValues(alpha: glow * 0.6)));
    final pts = [
      Offset(w * 0.18, h * 0.45),
      Offset(w * 0.82, h * 0.45),
      Offset(w * 0.25, h * 0.85),
      Offset(w * 0.75, h * 0.85),
    ];
    for (final p in pts) {
      final ph = orc ? 34.0 : 26.0;
      c.drawRect(Rect.fromLTWH(p.dx - 4, p.dy - ph, 8, ph), fillP(orc ? const Color(0xFF3E3A37) : const Color(0xFFE0E0E0)));
      c.drawRect(Rect.fromLTWH(p.dx - 4, p.dy - ph, 8, ph), strokeP(const Color(0xFF424242), 1));
      c.drawRect(Rect.fromLTWH(p.dx - 6, p.dy - ph - 3, 12, 4), fillP(team));
    }
    // merkezdeki ışık sütunu
    final beam = Rect.fromLTWH(w / 2 - 5, h * 0.05, 10, h * 0.6);
    c.drawRect(beam, fillP(col.withValues(alpha: 0.25 + glow * 0.2)));
    c.drawCircle(Offset(w / 2, h * 0.62), 7, fillP(col));
    if (orc && sin(time * 7) > 0.7) {
      c.drawLine(Offset(w / 2, h * 0.1), Offset(w / 2 + 6, h * 0.3), strokeP(Colors.white, 1.5));
      c.drawLine(Offset(w / 2 + 6, h * 0.3), Offset(w / 2 - 3, h * 0.45), strokeP(Colors.white, 1.5));
    }
  }

  static void _smith(Canvas c, Color team, double w, double h, double time, bool orc) {
    c.drawRect(Rect.fromLTWH(2, h * 0.3, w - 4, h * 0.68), fillP(orc ? const Color(0xFF6B5A45) : const Color(0xFF9E9E9E)));
    final wall = Rect.fromLTWH(8, h * 0.42, w * 0.7, h * 0.5);
    _walls(c, wall, orc);
    // baca
    final ch = Rect.fromLTWH(wall.right - 18, h * 0.0, 12, h * 0.4);
    c.drawRect(ch, fillP(const Color(0xFF616161)));
    c.drawRect(ch, strokeP(const Color(0xFF424242), 1));
    _roof(c, wall, h * 0.28, team, orc);
    for (var i = 0; i < 3; i++) {
      final ph = ((time * 0.6 + i / 3) % 1.0);
      c.drawCircle(Offset(ch.center.dx + sin(ph * 6) * 3, ch.top - ph * 26), 4 + ph * 5,
          fillP(Colors.grey.withValues(alpha: 0.5 * (1 - ph))));
    }
    // ocak ışığı
    final glow = 0.6 + 0.3 * sin(time * 9);
    _door(c, wall.left + wall.width * 0.4, wall.bottom, 16, 18, orc);
    c.drawCircle(Offset(wall.left + wall.width * 0.4, wall.bottom - 6), 5, fillP(Colors.deepOrange.withValues(alpha: glow)));
    // örs / testere
    if (orc) {
      final cc = Offset(w * 0.86, h * 0.68);
      c.drawCircle(cc, 11, fillP(const Color(0xFFB0BEC5)));
      c.save();
      c.translate(cc.dx, cc.dy);
      c.rotate(time * 2);
      for (var i = 0; i < 8; i++) {
        c.rotate(pi / 4);
        c.drawLine(const Offset(9, 0), const Offset(13, 0), strokeP(const Color(0xFF78909C), 2));
      }
      c.restore();
      c.drawCircle(cc, 3, fillP(_wood));
    } else {
      final a = Offset(w * 0.85, h * 0.75);
      c.drawRect(Rect.fromCenter(center: a, width: 16, height: 6), fillP(const Color(0xFF37474F)));
      c.drawRect(Rect.fromCenter(center: a + const Offset(0, 6), width: 6, height: 8), fillP(const Color(0xFF37474F)));
    }
  }

  static void _tower(Canvas c, Color team, double w, double h, double time, bool orc) {
    if (orc) {
      final legs = strokeP(const Color(0xFF5D4037), 4);
      c.drawLine(Offset(w * 0.2, h - 4), Offset(w * 0.32, -h * 0.4), legs);
      c.drawLine(Offset(w * 0.8, h - 4), Offset(w * 0.68, -h * 0.4), legs);
      c.drawLine(Offset(w * 0.25, h * 0.4), Offset(w * 0.75, h * 0.0), strokeP(const Color(0xFF6D4C41), 2));
      c.drawLine(Offset(w * 0.75, h * 0.4), Offset(w * 0.25, h * 0.0), strokeP(const Color(0xFF6D4C41), 2));
      final hut = Rect.fromLTWH(w * 0.12, -h * 0.75, w * 0.76, h * 0.42);
      c.drawRect(hut, fillP(const Color(0xFF7B5435)));
      c.drawRect(hut, strokeP(const Color(0xFF3E2716), 1.5));
      final roof = Path()
        ..moveTo(hut.left - 5, hut.top)
        ..lineTo(w / 2, hut.top - h * 0.35)
        ..lineTo(hut.right + 5, hut.top)
        ..close();
      c.drawPath(roof, fillP(const Color(0xFFC9A66B)));
      c.drawLine(Offset(hut.left, hut.top + 8), Offset(hut.right, hut.top + 8), strokeP(team, 3));
      c.drawLine(Offset(hut.left - 6, hut.bottom), Offset(hut.left - 12, hut.bottom - 10), strokeP(const Color(0xFFF5EBD7), 3));
      c.drawLine(Offset(hut.right + 6, hut.bottom), Offset(hut.right + 12, hut.bottom - 10), strokeP(const Color(0xFFF5EBD7), 3));
      return;
    }
    c.drawOval(Rect.fromLTWH(4, h * 0.55, w - 8, h * 0.4), fillP(const Color(0xFF8D8D8D)));
    final shaft = Rect.fromLTWH(w * 0.22, -h * 0.55, w * 0.56, h * 1.35);
    c.drawRect(shaft, fillP(const Color(0xFFBDBDBD)));
    for (var y = shaft.top + 8; y < shaft.bottom; y += 9) {
      c.drawLine(Offset(shaft.left, y), Offset(shaft.right, y), strokeP(const Color(0xFF9E9E9E), 1));
    }
    c.drawRect(shaft, strokeP(const Color(0xFF616161), 1.5));
    final top = Rect.fromLTWH(w * 0.12, -h * 0.72, w * 0.76, h * 0.22);
    c.drawRect(top, fillP(const Color(0xFFD0D0D0)));
    for (var i = 0; i < 4; i++) {
      c.drawRect(Rect.fromLTWH(top.left + i * top.width / 4 + 1, top.top - 6, top.width / 8, 6), fillP(const Color(0xFFD0D0D0)));
    }
    c.drawRect(top, strokeP(const Color(0xFF616161), 1.5));
    c.drawRect(Rect.fromLTWH(w * 0.42, -h * 0.3, w * 0.16, h * 0.2), fillP(const Color(0xFF3E2F25)));
    _flag(c, Offset(w / 2, top.top - 4), 18, team, time);
  }

  // ------------------------------------------------------------ Yer eşyası

  static void groundItem(Canvas c, Color col, double time) {
    final bob = sin(time * 3) * 2;
    c.drawOval(Rect.fromCenter(center: const Offset(0, 6), width: 18, height: 6), fillP(_shadow));
    c.drawCircle(Offset(0, -2 + bob), 11, fillP(col.withValues(alpha: 0.25)));
    final p = Path()
      ..moveTo(-7, 2 + bob)
      ..quadraticBezierTo(-9, -8 + bob, 0, -9 + bob)
      ..quadraticBezierTo(9, -8 + bob, 7, 2 + bob)
      ..close();
    c.drawPath(p, fillP(const Color(0xFF8D6E4A)));
    c.drawCircle(Offset(0, -9 + bob), 2.5, fillP(col));
    c.drawCircle(Offset(0, -3 + bob), 3, fillP(col));
  }
}
