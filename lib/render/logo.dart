import 'dart:math';

import 'package:flutter/material.dart';

/// War of Kingdoms logosu: mavi/kırmızı ikiye bölünmüş zemin, çapraz kılıçlar,
/// iki tarafın renklerini taşıyan kalkan ve altın taç.
///
/// Tüm çizim 1024x1024 birimlik bir alanda yapılır; uygulama simgeleri de
/// (tool/generate_icons_test.dart) aynı çizimden üretilir.
class Logo {
  static const double unit = 1024;

  static const _gold = [Color(0xFFFFEDB0), Color(0xFFF2BE45), Color(0xFFB27A1A)];
  static const _goldDark = Color(0xFF6E4A0E);

  /// Tam kare zemin.
  static void paintBackground(Canvas c) {
    const rect = Rect.fromLTWH(0, 0, unit, unit);
    final blue = Path()
      ..moveTo(0, 0)
      ..lineTo(unit, 0)
      ..lineTo(0, unit)
      ..close();
    final red = Path()
      ..moveTo(unit, 0)
      ..lineTo(unit, unit)
      ..lineTo(0, unit)
      ..close();
    c.drawPath(
      blue,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.center,
          colors: [Color(0xFF3567CF), Color(0xFF12296A)],
        ).createShader(rect),
    );
    c.drawPath(
      red,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.center,
          colors: [Color(0xFFD03A2C), Color(0xFF5E100C)],
        ).createShader(rect),
    );
    // Ortadaki sıcak ışık
    const glow = Offset(512, 540);
    c.drawCircle(
      glow,
      470,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFFFD27A).withValues(alpha: 0.45), const Color(0x00FFD27A)],
        ).createShader(Rect.fromCircle(center: glow, radius: 470)),
    );
    // İki tarafın çarpıştığı çizgi
    c.drawLine(
      const Offset(unit, 0),
      const Offset(0, unit),
      Paint()
        ..color = const Color(0x66FFD54F)
        ..strokeWidth = 22
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    c.drawLine(
      const Offset(unit, 0),
      const Offset(0, unit),
      Paint()
        ..color = const Color(0xB3FFE9A8)
        ..strokeWidth = 4,
    );
    // Kenar karartması
    c.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x00000000), Color(0x59000000)],
          stops: [0.66, 1.0],
        ).createShader(rect),
    );
  }

  /// Kılıçlar, kalkan ve taç (arka plansız).
  static void paintEmblem(Canvas c) {
    _sword(c, const Offset(190, 885), const Offset(874, 146));
    _sword(c, const Offset(834, 885), const Offset(150, 146));
    _shield(c);
    _crown(c);
  }

  static Paint _goldPaint(Rect r) => Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: _gold,
      stops: [0, 0.45, 1],
    ).createShader(r);

  static Paint _stroke(Color col, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..color = col
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  static void _sword(Canvas c, Offset pommel, Offset tip) {
    final d = tip - pommel;
    final len = d.distance;
    c.save();
    c.translate(pommel.dx, pommel.dy);
    c.rotate(atan2(d.dy, d.dx) + pi / 2); // kılıç yukarı (-y) bakar
    // gölge
    c.drawRect(
      Rect.fromLTWH(-30, -len + 30, 70, len - 30),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    // Namlu
    final blade = Path()
      ..moveTo(-37, -160)
      ..lineTo(37, -160)
      ..lineTo(37, -len + 130)
      ..lineTo(0, -len)
      ..lineTo(-37, -len + 130)
      ..close();
    final bladeRect = Rect.fromLTWH(-37, -len, 74, len);
    c.drawPath(
      blade,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF8E9AA6), Color(0xFFF4F7FA), Color(0xFFB7C2CC), Color(0xFF6C7883)],
          stops: [0, 0.42, 0.58, 1],
        ).createShader(bladeRect),
    );
    c.drawLine(const Offset(0, -175), Offset(0, -len + 60), _stroke(const Color(0x99FFFFFF), 5));
    c.drawPath(blade, _stroke(const Color(0xFF3E4750), 5));
    // Kabza
    final grip = RRect.fromRectAndRadius(const Rect.fromLTWH(-19, -150, 38, 130), const Radius.circular(10));
    c.drawRRect(grip, Paint()..color = const Color(0xFF5B3518));
    for (var y = -140.0; y < -25; y += 18) {
      c.drawLine(Offset(-19, y), Offset(19, y + 12), _stroke(const Color(0xFF8A5A2B), 6));
    }
    c.drawRRect(grip, _stroke(const Color(0xFF2E1A0B), 4));
    // Balçak
    final guard = Path()
      ..moveTo(-118, -150)
      ..quadraticBezierTo(-60, -172, 0, -168)
      ..quadraticBezierTo(60, -172, 118, -150)
      ..quadraticBezierTo(126, -132, 112, -126)
      ..quadraticBezierTo(60, -146, 0, -142)
      ..quadraticBezierTo(-60, -146, -112, -126)
      ..quadraticBezierTo(-126, -132, -118, -150)
      ..close();
    c.drawPath(guard, _goldPaint(const Rect.fromLTWH(-126, -175, 252, 50)));
    c.drawPath(guard, _stroke(_goldDark, 5));
    c.drawCircle(const Offset(0, -156), 16, Paint()..color = const Color(0xFFC62828));
    c.drawCircle(const Offset(-5, -161), 5, Paint()..color = const Color(0xCCFFFFFF));
    // Topuz
    c.drawCircle(Offset.zero, 30, _goldPaint(Rect.fromCircle(center: Offset.zero, radius: 30)));
    c.drawCircle(Offset.zero, 30, _stroke(_goldDark, 5));
    c.drawCircle(const Offset(-9, -9), 9, Paint()..color = const Color(0xB3FFFFFF));
    c.restore();
  }

  static Path _shieldPath() => Path()
    ..moveTo(272, 345)
    ..quadraticBezierTo(512, 300, 752, 345)
    ..lineTo(752, 560)
    ..cubicTo(752, 728, 640, 830, 512, 892)
    ..cubicTo(384, 830, 272, 728, 272, 560)
    ..close();

  static void _shield(Canvas c) {
    final p = _shieldPath();
    c.drawPath(
      p.shift(const Offset(0, 18)),
      Paint()
        ..color = const Color(0x8C000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    const bounds = Rect.fromLTWH(272, 300, 480, 592);
    c.save();
    c.clipPath(p);
    c.drawRect(
      const Rect.fromLTWH(272, 300, 240, 600),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A82F0), Color(0xFF1C3F9A)],
        ).createShader(const Rect.fromLTWH(272, 300, 240, 600)),
    );
    c.drawRect(
      const Rect.fromLTWH(512, 300, 240, 600),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFF0574A), Color(0xFF8E1C15)],
        ).createShader(const Rect.fromLTWH(512, 300, 240, 600)),
    );
    // Parlama
    c.drawOval(
      const Rect.fromLTWH(250, 280, 330, 260),
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)],
        ).createShader(const Rect.fromLTWH(250, 280, 330, 260)),
    );
    // Orta ayrım
    c.drawLine(const Offset(512, 300), const Offset(512, 900), _stroke(const Color(0xFFE9B64A), 12));
    c.restore();
    _castle(c);
    // Altın çerçeve
    c.drawPath(p, _stroke(const Color(0xFF5A3A08), 34));
    c.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeJoin = StrokeJoin.round
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _gold,
        ).createShader(bounds),
    );
    c.drawPath(p, _stroke(const Color(0x66FFFFFF), 3));
  }

  /// Kalkanın ortasındaki kale (krallıklar).
  static void _castle(Canvas c) {
    const cx = 512.0, base = 735.0;
    final body = Path()
      ..moveTo(cx - 92, base)
      ..lineTo(cx - 92, 545)
      ..lineTo(cx - 92, 505)
      ..lineTo(cx - 58, 505)
      ..lineTo(cx - 58, 530)
      ..lineTo(cx - 17, 530)
      ..lineTo(cx - 17, 505)
      ..lineTo(cx + 17, 505)
      ..lineTo(cx + 17, 530)
      ..lineTo(cx + 58, 530)
      ..lineTo(cx + 58, 505)
      ..lineTo(cx + 92, 505)
      ..lineTo(cx + 92, base)
      ..close();
    c.drawPath(
      body.shift(const Offset(6, 8)),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    c.drawPath(body, _goldPaint(const Rect.fromLTWH(420, 505, 184, 230)));
    c.drawPath(body, _stroke(_goldDark, 6));
    // Kapı ve pencere
    final door = Path()
      ..moveTo(cx - 32, base)
      ..lineTo(cx - 32, 668)
      ..arcToPoint(const Offset(cx + 32, 668), radius: const Radius.circular(32))
      ..lineTo(cx + 32, base)
      ..close();
    c.drawPath(door, Paint()..color = const Color(0xFF3B2405));
    c.drawLine(const Offset(cx, 640), const Offset(cx, base), _stroke(const Color(0xFF6E4A0E), 4));
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(cx - 13, 568, 26, 40), const Radius.circular(13)),
      Paint()..color = const Color(0xFF3B2405),
    );
  }

  static void _crown(Canvas c) {
    final crown = Path()
      ..moveTo(352, 312)
      ..lineTo(330, 186)
      ..lineTo(384, 250)
      ..lineTo(426, 156)
      ..lineTo(470, 244)
      ..lineTo(512, 120)
      ..lineTo(554, 244)
      ..lineTo(598, 156)
      ..lineTo(640, 250)
      ..lineTo(694, 186)
      ..lineTo(672, 312)
      ..close();
    c.drawPath(
      crown.shift(const Offset(0, 14)),
      Paint()
        ..color = const Color(0x80000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    c.drawPath(crown, _goldPaint(const Rect.fromLTWH(330, 120, 364, 192)));
    c.drawPath(crown, _stroke(_goldDark, 7));
    for (final pt in const [Offset(330, 186), Offset(426, 156), Offset(512, 120), Offset(598, 156), Offset(694, 186)]) {
      c.drawCircle(pt, 17, _goldPaint(Rect.fromCircle(center: pt, radius: 17)));
      c.drawCircle(pt, 17, _stroke(_goldDark, 5));
      c.drawCircle(pt - const Offset(5, 5), 5, Paint()..color = const Color(0xCCFFFFFF));
    }
    // Taç bandı ve taşlar
    final band = RRect.fromRectAndRadius(const Rect.fromLTWH(340, 288, 344, 62), const Radius.circular(14));
    c.drawRRect(band, _goldPaint(band.outerRect));
    c.drawRRect(band, _stroke(_goldDark, 7));
    void gem(Offset o, double rx, double ry, Color col) {
      final r = Rect.fromCenter(center: o, width: rx * 2, height: ry * 2);
      c.drawOval(r, Paint()..color = col);
      c.drawOval(r, _stroke(_goldDark, 4));
      c.drawOval(
        Rect.fromCenter(center: o - Offset(rx * 0.35, ry * 0.35), width: rx * 0.7, height: ry * 0.6),
        Paint()..color = const Color(0xB3FFFFFF),
      );
    }

    gem(const Offset(512, 319), 26, 20, const Color(0xFFD32F2F));
    gem(const Offset(420, 319), 17, 14, const Color(0xFF1E5BD6));
    gem(const Offset(604, 319), 17, 14, const Color(0xFF1E5BD6));
    gem(const Offset(512, 210), 14, 18, const Color(0xFF2E9D52));
  }
}

/// Uygulama içinde logoyu çizer (ör. ana menü). [background] false ise yalnızca amblem.
class LogoPainter extends CustomPainter {
  const LogoPainter({this.background = false});
  final bool background;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / Logo.unit;
    canvas.save();
    canvas.translate((size.width - Logo.unit * s) / 2, (size.height - Logo.unit * s) / 2);
    canvas.scale(s);
    if (background) Logo.paintBackground(canvas);
    Logo.paintEmblem(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LogoPainter oldDelegate) => oldDelegate.background != background;
}
