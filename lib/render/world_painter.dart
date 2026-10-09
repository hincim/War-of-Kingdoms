import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/entities.dart';
import '../game/game.dart';
import '../game/map.dart';
import 'sprites.dart';

/// Birim sprite'larının çarpışma yarıçapına göre görsel büyütmesi.
const double kUnitScale = 1.4;

/// Ekran durumu: kamera, seçim ve imleç bilgileri (UI ile ressam arasında paylaşılır).
class GameView {
  double camX = 0, camY = 0, zoom = 1.15;
  final List<Unit> selection = [];
  Offset? mouse;
  Offset? dragStart, dragEnd;
  UnitType? placing;
  String? targeting;
  final List<ClickMarker> markers = [];

  Offset toWorld(Offset s) => Offset(s.dx / zoom + camX, s.dy / zoom + camY);
  Offset toScreen(double x, double y) => Offset((x - camX) * zoom, (y - camY) * zoom);

  /// Yerleştirme hayaletinin sol üst karosu.
  TilePos placeTile(Offset world, UnitType t) =>
      TilePos((world.dx / kTile - t.size / 2 + 0.5).floor(), (world.dy / kTile - t.size / 2 + 0.5).floor());
}

/// Araziyi 8x8 karoluk parçalar halinde önbelleğe alır.
class TerrainCache {
  TerrainCache(this.map);
  final GameMap map;
  static const int chunk = 8;
  final Map<int, ui.Image> _chunks = {};

  ui.Image get(int cx, int cy) {
    final key = cy * 100 + cx;
    final cached = _chunks[key];
    if (cached != null) return cached;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const px = chunk * kTile;
    c.clipRect(const Rect.fromLTWH(0, 0, px, px));
    c.translate(-cx * px, -cy * px);
    _paintTiles(c, cx * chunk - 1, cy * chunk - 1, cx * chunk + chunk, cy * chunk + chunk);
    final pic = rec.endRecording();
    final img = pic.toImageSync(px.toInt(), px.toInt());
    pic.dispose();
    _chunks[key] = img;
    return img;
  }

  void _paintTiles(Canvas c, int x0, int y0, int x1, int y1) {
    final m = map;
    bool ok(int x, int y) => m.inside(x, y);
    final soft = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    // 1. Çim zemin: düz renk + yumuşak lekeler
    c.drawRect(Rect.fromLTWH(x0 * kTile, y0 * kTile, (x1 - x0 + 1) * kTile, (y1 - y0 + 1) * kTile),
        fillP(const Color(0xFF4C7E2A)));
    for (var y = y0 - 1; y <= y1 + 1; y++) {
      for (var x = x0 - 1; x <= x1 + 1; x++) {
        if (!ok(x, y)) continue;
        final v = m.variant[m.idx(x, y)] / 255.0;
        final t = ((sin(x * 0.37) + sin(y * 0.29 + x * 0.11)) * 0.25 + 0.5) * 0.65 + v * 0.35;
        soft.color = Color.lerp(const Color(0xFF3E6E22), const Color(0xFF649433), t)!;
        c.drawCircle(GameMap.tileCenter(x, y), 22, soft);
      }
    }
    // 2. Orman tabanı
    soft.color = const Color(0xFF2C5220);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (!ok(x, y) || m.wood[m.idx(x, y)] == 0) continue;
        c.drawCircle(GameMap.tileCenter(x, y), 24, soft);
      }
    }
    // 3. Toprak
    final dirt = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (!ok(x, y) || m.terrain[m.idx(x, y)] != tDirt) continue;
        final v = m.variant[m.idx(x, y)] / 255.0;
        dirt.color = Color.lerp(const Color(0xFF86663D), const Color(0xFF957447), v)!;
        c.drawCircle(GameMap.tileCenter(x, y), 24, dirt);
      }
    }
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (!ok(x, y) || m.terrain[m.idx(x, y)] != tDirt) continue;
        final v = m.variant[m.idx(x, y)];
        final cc = GameMap.tileCenter(x, y);
        if (v % 5 == 0) c.drawCircle(cc + Offset(-6.0 + v % 11, 5), 2, fillP(const Color(0xFF7D7468)));
        if (v % 7 == 0) c.drawCircle(cc + Offset(4.0 - v % 9, -6), 1.5, fillP(const Color(0xFFA89A84)));
      }
    }
    // 4. Su ve kıyı
    bool water(int x, int y) => ok(x, y) && m.terrain[m.idx(x, y)] == tWater;
    final shore = Paint()
      ..color = const Color(0xFFBFAE7E)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (water(x, y)) c.drawCircle(GameMap.tileCenter(x, y), 28, shore);
      }
    }
    final body = Path();
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (water(x, y)) body.addOval(Rect.fromCircle(center: GameMap.tileCenter(x, y), radius: 23));
      }
    }
    c.drawPath(body, fillP(const Color(0xFF2E7299)));
    final deep = Paint()
      ..color = const Color(0xFF1F5A80)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (water(x, y) && water(x - 1, y) && water(x + 1, y) && water(x, y - 1) && water(x, y + 1)) {
          c.drawCircle(GameMap.tileCenter(x, y), 24, deep);
        }
      }
    }
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (!water(x, y)) continue;
        final v = m.variant[m.idx(x, y)];
        if (v % 4 != 0) continue;
        final cc = GameMap.tileCenter(x, y);
        c.drawArc(Rect.fromCenter(center: cc + Offset(v % 9 - 4.0, v % 7 - 3.0), width: 14, height: 5), pi, pi, false,
            strokeP(const Color(0x77B3E5FC), 1.2));
      }
    }
    // 5. Süsler
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (!ok(x, y)) continue;
        final i = m.idx(x, y);
        if (m.terrain[i] != tGrass || m.wood[i] > 0) continue;
        final v = m.variant[i];
        final bx = x * kTile, by = y * kTile;
        if (v < 70) {
          for (var k = 0; k < 3; k++) {
            final gx = bx + ((v * (k + 3)) % 28) + 2.0, gy = by + ((v * (k + 7)) % 26) + 4.0;
            c.drawLine(Offset(gx, gy), Offset(gx - 1.5, gy - 4), strokeP(const Color(0xFF6FA040), 1));
            c.drawLine(Offset(gx + 2, gy), Offset(gx + 3, gy - 3.5), strokeP(const Color(0xFF34601E), 1));
          }
        } else if (v < 80) {
          final cols = [const Color(0xFFFFF176), const Color(0xFFF8BBD0), const Color(0xFFFFFFFF), const Color(0xFFCE93D8)];
          for (var k = 0; k < 3; k++) {
            c.drawCircle(Offset(bx + ((v * (k + 5)) % 26) + 3.0, by + ((v * (k + 2)) % 26) + 3.0), 1.6,
                fillP(cols[(v + k) % 4]));
          }
        } else if (v < 84) {
          final rc = Offset(bx + 10.0 + v % 12, by + 12.0 + v % 9);
          c.drawOval(Rect.fromCenter(center: rc + const Offset(1, 2), width: 11, height: 6), fillP(const Color(0x33000000)));
          c.drawOval(Rect.fromCenter(center: rc, width: 10, height: 7), fillP(const Color(0xFF9E9A92)));
          c.drawOval(Rect.fromCenter(center: rc - const Offset(1.5, 1.5), width: 4, height: 2.5), fillP(const Color(0xFFC9C5BC)));
        }
      }
    }
  }

  void dispose() {
    for (final i in _chunks.values) {
      i.dispose();
    }
    _chunks.clear();
  }
}

/// Sis görüntüsünü (karo başına 1 piksel) eşzamansız günceller.
class FogImage {
  ui.Image? image;
  int _version = -1;
  bool _busy = false;
  final Uint8List _px = Uint8List(kMapW * kMapH * 4);

  void update(Fog fog) {
    if (_busy || fog.version == _version) return;
    _busy = true;
    final v = fog.version;
    for (var i = 0; i < kMapW * kMapH; i++) {
      final a = fog.visible[i] == 1 ? 0 : (fog.explored[i] == 1 ? 125 : 255);
      _px[i * 4] = 0;
      _px[i * 4 + 1] = 0;
      _px[i * 4 + 2] = 0;
      _px[i * 4 + 3] = a;
    }
    ui.decodeImageFromPixels(_px, kMapW, kMapH, ui.PixelFormat.rgba8888, (img) {
      image?.dispose();
      image = img;
      _version = v;
      _busy = false;
    });
  }

  void reset() {
    _version = -1;
  }

  void dispose() {
    image?.dispose();
    image = null;
  }
}

class _Drawable {
  _Drawable(this.y, this.kind, this.unit, this.tx, this.ty);
  final double y;
  final int kind; // 0 = birim/bina, 1 = ağaç
  final Unit? unit;
  final int tx, ty;
}

final Map<String, TextPainter> _textCache = {};

TextPainter textPainter(String text, Color color, double size, {bool bold = true}) {
  final key = '$text|${color.toARGB32()}|$size|$bold';
  final cached = _textCache[key];
  if (cached != null) return cached;
  if (_textCache.length > 300) _textCache.clear();
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        shadows: const [Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, 1))],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  _textCache[key] = tp;
  return tp;
}

class WorldPainter extends CustomPainter {
  WorldPainter({
    required this.g,
    required this.view,
    required this.terrain,
    required this.fog,
    required this.showAllBars,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final Game g;
  final GameView view;
  final TerrainCache terrain;
  final FogImage fog;
  final bool Function() showAllBars;

  bool _visible(Unit u) {
    if (u.owner == kPlayer) return true;
    if (u.isBuilding) {
      if (u.isMine) {
        return g.fog.exploredTile(u.tileX + 1, u.tileY + 1);
      }
      return u.seen;
    }
    return g.fog.visibleAt(u.x, u.y);
  }

  static Color relColor(Unit u) {
    if (u.owner == kPlayer) return const Color(0xFF4CFF4C);
    if (u.owner == kEnemy || u.owner == kCreeps) return const Color(0xFFFF4040);
    return const Color(0xFFFFEB3B);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final z = view.zoom;
    canvas.drawRect(Offset.zero & size, fillP(Colors.black));
    canvas.save();
    canvas.scale(z);
    canvas.translate(-view.camX, -view.camY);
    final vr = Rect.fromLTWH(view.camX, view.camY, size.width / z, size.height / z);
    final t = g.time;

    // Arazi
    const cpx = TerrainCache.chunk * kTile;
    final cx0 = max(0, (vr.left / cpx).floor()), cx1 = min(kMapW ~/ TerrainCache.chunk - 1, (vr.right / cpx).floor());
    final cy0 = max(0, (vr.top / cpx).floor()), cy1 = min(kMapH ~/ TerrainCache.chunk - 1, (vr.bottom / cpx).floor());
    final imgPaint = Paint()..filterQuality = FilterQuality.low;
    for (var cy = cy0; cy <= cy1; cy++) {
      for (var cx = cx0; cx <= cx1; cx++) {
        // 1 piksellik bindirme, yakınlaştırmada parça sınırlarındaki çizgileri gizler.
        canvas.drawImageRect(terrain.get(cx, cy), const Rect.fromLTWH(0, 0, cpx, cpx),
            Rect.fromLTWH(cx * cpx, cy * cpx, cpx + 1, cpx + 1), imgPaint);
      }
    }

    final cull = vr.inflate(80);

    // Yerdeki efektler (enkaz)
    for (final f in g.effects) {
      if (f.kind != 'rubble' || !cull.contains(Offset(f.x, f.y))) continue;
      final a = f.p > 0.8 ? (1 - f.p) / 0.2 : 1.0;
      final rnd = Random(f.x.toInt() * 31 + f.y.toInt());
      for (var i = 0; i < 12; i++) {
        final dx = (rnd.nextDouble() - 0.5) * f.radius * 1.8, dy = (rnd.nextDouble() - 0.5) * f.radius * 1.6;
        canvas.drawCircle(Offset(f.x + dx, f.y + dy), 3 + rnd.nextDouble() * 6,
            fillP(Color.lerp(const Color(0xFF5D4037), const Color(0xFF9E9E9E), rnd.nextDouble())!.withValues(alpha: a * 0.85)));
      }
    }

    // Cesetler
    for (final c in g.corpses) {
      if (!cull.contains(Offset(c.x, c.y)) || !g.fog.visibleAt(c.x, c.y)) continue;
      final a = c.t > 10 ? max(0.0, 1 - (c.t - 10) / 4) : 1.0;
      canvas.save();
      canvas.translate(c.x, c.y);
      canvas.scale(kUnitScale);
      Sprites.corpse(canvas, c.type, c.color, a);
      canvas.restore();
    }

    // Yerdeki eşyalar
    for (final it in g.items) {
      if (!cull.contains(Offset(it.x, it.y)) || !g.fog.visibleAt(it.x, it.y)) continue;
      canvas.save();
      canvas.translate(it.x, it.y);
      Sprites.groundItem(canvas, it.type.color, t);
      canvas.restore();
    }

    // Seçim halkaları
    final selected = view.selection.toSet();
    final hovered = view.mouse != null && view.dragStart == null ? g.pick(view.toWorld(view.mouse!).dx, view.toWorld(view.mouse!).dy) : null;
    for (final u in g.units) {
      if (u.hidden || !cull.contains(Offset(u.x, u.y))) continue;
      final sel = selected.contains(u);
      if (!sel && u != hovered) continue;
      if (!_visible(u)) continue;
      final col = relColor(u);
      final p = strokeP(sel ? col : col.withValues(alpha: 0.5), sel ? 2 : 1.2);
      if (u.isBuilding) {
        canvas.drawOval(u.footprint.inflate(4).translate(0, 4), p);
      } else {
        final r = u.radius * kUnitScale;
        canvas.drawOval(Rect.fromCenter(center: Offset(u.x, u.y + r * 0.45), width: r * 2.6, height: r * 1.3), p);
      }
    }
    // Aura halkaları
    for (final h in g.units) {
      if (!h.isHero || !cull.contains(Offset(h.x, h.y)) || !_visible(h)) continue;
      for (final aid in h.type.abilities) {
        final a = abilityTypes[aid]!;
        if (!a.passive || h.abilityLevel(aid) == 0) continue;
        canvas.drawOval(Rect.fromCenter(center: Offset(h.x, h.y + 6), width: 70, height: 30),
            strokeP(a.color.withValues(alpha: 0.35 + 0.15 * sin(t * 3)), 1.5));
      }
    }

    // Sıralı çizim
    final ds = <_Drawable>[];
    for (final u in g.units) {
      if (u.hidden) continue;
      final r = u.isBuilding ? u.footprint.inflate(60) : Rect.fromCircle(center: Offset(u.x, u.y), radius: 60);
      if (!cull.overlaps(r)) continue;
      if (!_visible(u)) continue;
      ds.add(_Drawable(u.isBuilding ? u.footprint.bottom - 2 : u.y, 0, u, 0, 0));
    }
    final m = g.map;
    final tx0 = max(0, (vr.left / kTile).floor() - 1), tx1 = min(kMapW - 1, (vr.right / kTile).ceil() + 1);
    final ty0 = max(0, (vr.top / kTile).floor() - 1), ty1 = min(kMapH - 1, (vr.bottom / kTile).ceil() + 2);
    for (var y = ty0; y <= ty1; y++) {
      for (var x = tx0; x <= tx1; x++) {
        final i = m.idx(x, y);
        if (m.wood[i] == 0 || !g.fog.exploredTile(x, y)) continue;
        ds.add(_Drawable(y * kTile + kTile * 0.75, 1, null, x, y));
      }
    }
    ds.sort((a, b) => a.y.compareTo(b.y));
    for (final d in ds) {
      if (d.kind == 1) {
        final v = m.variant[m.idx(d.tx, d.ty)];
        Sprites.tree(canvas, d.tx * kTile + 16 + (v % 7) - 3, d.ty * kTile + 26 + (v % 5) - 2, v);
        continue;
      }
      final u = d.unit!;
      _drawUnit(canvas, u, t);
    }

    // Kar fırtınası alanları
    for (final a in g.areas) {
      if (!cull.contains(Offset(a.x, a.y))) continue;
      canvas.drawCircle(Offset(a.x, a.y), a.radius, fillP(const Color(0x2290CAF9)));
      canvas.drawCircle(Offset(a.x, a.y), a.radius, strokeP(const Color(0x6690CAF9), 1.5));
      final rnd = Random(a.hashCode);
      for (var i = 0; i < 26; i++) {
        final ang = rnd.nextDouble() * 2 * pi, rr = sqrt(rnd.nextDouble()) * a.radius;
        final ph = (a.age * 1.6 + rnd.nextDouble()) % 1.0;
        final gx = a.x + cos(ang) * rr, gy = a.y + sin(ang) * rr * 0.8;
        final fy = gy - (1 - ph) * 90;
        canvas.drawLine(Offset(gx - 6 * (1 - ph), fy - 10), Offset(gx, fy), strokeP(const Color(0xCCE1F5FE), 2));
        if (ph > 0.85) canvas.drawCircle(Offset(gx, gy), 4, fillP(const Color(0x88FFFFFF)));
      }
    }

    // Mermiler
    for (final p in g.projectiles) {
      if (!cull.contains(Offset(p.x, p.y))) continue;
      _drawProjectile(canvas, p, t);
    }

    // Efektler
    for (final f in g.effects) {
      if (f.kind == 'rubble') continue;
      _drawFx(canvas, f, t);
    }

    // Can çubukları
    final allBars = showAllBars();
    for (final u in g.units) {
      if (u.hidden || u.isMine || !cull.contains(Offset(u.x, u.y)) || !_visible(u)) continue;
      final sel = selected.contains(u);
      final hurt = u.hp < u.maxHp - 0.5;
      if (!(allBars || sel || u == hovered || (hurt && !u.isBuilding) || u.isHero || u.constructing ||
          (u.isBuilding && (hurt || u.queue.isNotEmpty)))) {
        continue;
      }
      _drawBars(canvas, u);
    }

    // Gece karartması (sisten önce)
    final night = g.nightness;
    if (night > 0) {
      canvas.drawRect(vr, Paint()
        ..blendMode = BlendMode.multiply
        ..color = Color.lerp(Colors.white, const Color(0xFF6070B0), night)!);
    }

    // Sis
    final fi = fog.image;
    if (fi != null && !g.fog.revealAll) {
      canvas.drawImageRect(fi, Rect.fromLTWH(0, 0, kMapW.toDouble(), kMapH.toDouble()),
          const Rect.fromLTWH(0, 0, kMapPx, kMapPx), Paint()..filterQuality = FilterQuality.low);
    }

    // Toplanma noktası
    if (view.selection.length == 1) {
      final b = view.selection.first;
      if (b.isBuilding && b.owner == kPlayer && b.rallyX != null) {
        final rp = Offset(b.rallyX!, b.rallyY!);
        _dashed(canvas, Offset(b.x, b.y), rp, const Color(0xAA4CFF4C));
        canvas.drawLine(rp, rp - const Offset(0, 22), strokeP(const Color(0xFF5D4037), 2));
        canvas.drawPath(
            Path()
              ..moveTo(rp.dx, rp.dy - 22)
              ..lineTo(rp.dx + 13, rp.dy - 17)
              ..lineTo(rp.dx, rp.dy - 12)
              ..close(),
            fillP(g.me.color));
      }
    }

    // Tıklama işaretleri ve uyarı pingleri
    for (final mk in view.markers) {
      final p = mk.t / 0.6;
      final r = 14 * (1 - p) + 3;
      canvas.drawOval(Rect.fromCenter(center: Offset(mk.x, mk.y), width: r * 2, height: r), strokeP(mk.color.withValues(alpha: 1 - p), 2));
    }
    for (final pg in g.pings) {
      final age = g.time - pg.time;
      final p = (age % 1.0);
      canvas.drawCircle(Offset(pg.x, pg.y), 20 + p * 60, strokeP(pg.color.withValues(alpha: (1 - p) * 0.8), 3));
    }

    // Yüzen yazılar
    for (final ft in g.texts) {
      if (!cull.contains(Offset(ft.x, ft.y))) continue;
      if (!g.fog.visibleAt(ft.x, ft.y + 30)) continue;
      final a = (1 - ft.t / ft.dur).clamp(0.0, 1.0);
      final tp = textPainter(ft.text, ft.color, ft.size);
      canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: a));
      tp.paint(canvas, Offset(ft.x - tp.width / 2, ft.y - ft.t * 22 - tp.height / 2));
      canvas.restore();
    }

    // Bina yerleştirme hayaleti
    final pl = view.placing;
    if (pl != null && view.mouse != null) {
      final w = view.toWorld(view.mouse!);
      final tp = view.placeTile(w, pl);
      final ok = g.canPlace(pl, tp.x, tp.y, kPlayer);
      for (var y = tp.y; y < tp.y + pl.size; y++) {
        for (var x = tp.x; x < tp.x + pl.size; x++) {
          final good = m.buildable(x, y) && g.fog.exploredTile(x, y);
          canvas.drawRect(Rect.fromLTWH(x * kTile + 1, y * kTile + 1, kTile - 2, kTile - 2),
              fillP(good ? const Color(0x5534FF34) : const Color(0x66FF3030)));
        }
      }
      canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: 0.55));
      canvas.translate(tp.x * kTile, tp.y * kTile);
      Sprites.building(canvas, pl, g.me.color, pl.size * kTile, pl.size * kTile, time: t);
      canvas.restore();
      if (!ok) {
        canvas.drawRect(Rect.fromLTWH(tp.x * kTile, tp.y * kTile, pl.size * kTile, pl.size * kTile),
            strokeP(const Color(0xFFFF3030), 2));
      }
    }

    canvas.restore();

    // Seçim kutusu
    if (view.dragStart != null && view.dragEnd != null) {
      final r = Rect.fromPoints(view.dragStart!, view.dragEnd!);
      canvas.drawRect(r, fillP(const Color(0x1A4CFF4C)));
      canvas.drawRect(r, strokeP(const Color(0xFF4CFF4C), 1.2));
    }
    // Hedef imleci
    if (view.targeting != null && view.mouse != null) {
      final mp = view.mouse!;
      final col = view.targeting == 'move' ? const Color(0xFF4CFF4C) : const Color(0xFFFF5252);
      canvas.drawCircle(mp, 12, strokeP(col, 2));
      canvas.drawLine(mp - const Offset(18, 0), mp - const Offset(6, 0), strokeP(col, 2));
      canvas.drawLine(mp + const Offset(18, 0), mp + const Offset(6, 0), strokeP(col, 2));
      canvas.drawLine(mp - const Offset(0, 18), mp - const Offset(0, 6), strokeP(col, 2));
      canvas.drawLine(mp + const Offset(0, 18), mp + const Offset(0, 6), strokeP(col, 2));
    }
  }

  void _dashed(Canvas c, Offset a, Offset b, Color col) {
    final d = b - a;
    final len = d.distance;
    if (len < 1) return;
    final dir = d / len;
    for (var s = 0.0; s < len; s += 12) {
      c.drawLine(a + dir * s, a + dir * min(s + 6, len), strokeP(col, 1.5));
    }
  }

  void _drawUnit(Canvas canvas, Unit u, double t) {
    final team = u.pl.color;
    if (u.isBuilding) {
      canvas.save();
      canvas.translate(u.tileX * kTile, u.tileY * kTile);
      Sprites.building(canvas, u.type, team, u.size * kTile, u.size * kTile,
          progress: u.constructing ? u.progress.clamp(0.05, 1.0) : 1, time: t);
      canvas.restore();
      // yanan bina
      if (!u.isMine && u.hp < u.maxHp * 0.5 && !u.constructing) {
        final rnd = Random(u.id);
        final n = u.hp < u.maxHp * 0.25 ? 3 : 1;
        for (var i = 0; i < n; i++) {
          final fx = u.x + (rnd.nextDouble() - 0.5) * u.radius * 1.2, fy = u.y - u.radius * 0.3 + (rnd.nextDouble() - 0.5) * u.radius;
          final fl = 6 + 3 * sin(t * 12 + i);
          canvas.drawCircle(Offset(fx, fy), fl, fillP(const Color(0xCCFF6F00)));
          canvas.drawCircle(Offset(fx, fy - 3), fl * 0.55, fillP(const Color(0xDDFFD54F)));
          final ph = (t * 0.7 + i * 0.3) % 1.0;
          canvas.drawCircle(Offset(fx + sin(ph * 5) * 4, fy - 10 - ph * 30), 5 + ph * 6, fillP(Colors.black.withValues(alpha: 0.35 * (1 - ph))));
        }
      }
      return;
    }
    final since = t - u.attackAt;
    final swing = (since / 0.45).clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(u.x, u.y);
    canvas.scale(kUnitScale);
    var carry = 0;
    if (u.type.worker) carry = u.carryGold > 0 ? 1 : (u.carryWood > 0 ? 2 : 0);
    if (u.type.summon && u.expire < 5) {
      canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: 0.4 + 0.4 * (sin(t * 10) * 0.5 + 0.5)));
      Sprites.unit(canvas, u.type, team, facing: u.facing, walk: u.walkAnim, swing: swing, moving: u.moving, time: t, carry: carry);
      canvas.restore();
    } else {
      Sprites.unit(canvas, u.type, team, facing: u.facing, walk: u.walkAnim, swing: swing, moving: u.moving, time: t, carry: carry);
    }
    if (u.stun > 0) {
      final hy = -u.radius * 2.1;
      for (var i = 0; i < 3; i++) {
        final a = t * 5 + i * 2 * pi / 3;
        canvas.drawCircle(Offset(cos(a) * u.radius * 0.7, hy + sin(a) * 3), 2.2, fillP(const Color(0xFFFFEB3B)));
      }
    }
    canvas.restore();
  }

  void _drawBars(Canvas c, Unit u) {
    double w, y, x;
    if (u.isBuilding) {
      w = u.size * kTile * 0.6;
      x = u.x;
      y = u.footprint.top - (u.type.id.endsWith('tower') ? u.size * kTile * 1.05 : u.size * kTile * 0.4);
    } else {
      w = max(26.0, u.radius * 2.8);
      x = u.x;
      y = u.y - u.radius * kUnitScale * 2.4 - (u.isHero ? 8 : 0);
    }
    final ratio = (u.hp / u.maxHp).clamp(0.0, 1.0);
    final r = Rect.fromLTWH(x - w / 2, y, w, 4);
    c.drawRect(r.inflate(1), fillP(Colors.black.withValues(alpha: 0.75)));
    final col = ratio > 0.6 ? Color.lerp(const Color(0xFFFFEB3B), const Color(0xFF4CFF4C), (ratio - 0.6) / 0.4)! : Color.lerp(const Color(0xFFFF3030), const Color(0xFFFFEB3B), ratio / 0.6)!;
    c.drawRect(Rect.fromLTWH(r.left, r.top, w * ratio, 4), fillP(col));
    var ny = r.bottom + 1;
    if (u.maxMana > 0) {
      final mr = (u.mana / u.maxMana).clamp(0.0, 1.0);
      final mrect = Rect.fromLTWH(x - w / 2, ny, w, 3);
      c.drawRect(mrect.inflate(1), fillP(Colors.black.withValues(alpha: 0.75)));
      c.drawRect(Rect.fromLTWH(mrect.left, mrect.top, w * mr, 3), fillP(const Color(0xFF42A5F5)));
      ny = mrect.bottom + 1;
    }
    if (u.constructing) {
      final pr = Rect.fromLTWH(x - w / 2, ny + 1, w, 3);
      c.drawRect(pr.inflate(1), fillP(Colors.black.withValues(alpha: 0.75)));
      c.drawRect(Rect.fromLTWH(pr.left, pr.top, w * u.progress, 3), fillP(const Color(0xFFFFA726)));
    } else if (u.isBuilding && u.queue.isNotEmpty && u.owner == kPlayer) {
      final q = u.queue.first;
      final pr = Rect.fromLTWH(x - w / 2, ny + 1, w, 3);
      c.drawRect(pr.inflate(1), fillP(Colors.black.withValues(alpha: 0.75)));
      c.drawRect(Rect.fromLTWH(pr.left, pr.top, w * (q.progress / q.time).clamp(0.0, 1.0), 3), fillP(const Color(0xFF80DEEA)));
    }
    if (u.isHero) {
      final tp = textPainter('${u.level}', const Color(0xFFFFE082), 10);
      final bc = Offset(x - w / 2 - 8, y + 2);
      c.drawCircle(bc, 7, fillP(const Color(0xFF3E2723)));
      c.drawCircle(bc, 7, strokeP(const Color(0xFFFFC107), 1.2));
      tp.paint(c, bc - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _drawProjectile(Canvas c, Projectile p, double t) {
    final dx = p.tx - p.x, dy = p.ty - p.y;
    final d = sqrt(dx * dx + dy * dy);
    final dir = d < 0.01 ? const Offset(1, 0) : Offset(dx / d, dy / d);
    final pos = Offset(p.x, p.y);
    switch (p.kind) {
      case 'arrow':
        c.drawLine(pos - dir * 12, pos, strokeP(const Color(0xFF6D4C41), 2));
        c.drawLine(pos - dir * 3, pos + dir * 2, strokeP(const Color(0xFFCFD8DC), 2.5));
      case 'spear':
        c.drawLine(pos - dir * 16, pos, strokeP(const Color(0xFF795548), 2.2));
        c.drawLine(pos - dir * 3, pos + dir * 3, strokeP(const Color(0xFFCFD8DC), 3));
      case 'bullet':
        c.drawLine(pos - dir * 10, pos, strokeP(const Color(0x88FFF59D), 2));
        c.drawCircle(pos, 2.2, fillP(const Color(0xFFFFF176)));
      case 'magic':
        c.drawCircle(pos, 8, fillP(const Color(0x557E57C2)));
        c.drawCircle(pos, 4, fillP(const Color(0xFFB39DDB)));
      case 'water':
        c.drawCircle(pos, 7, fillP(const Color(0x5529B6F6)));
        c.drawCircle(pos, 4, fillP(const Color(0xFF81D4FA)));
      case 'lightning':
        c.drawCircle(pos, 9, fillP(const Color(0x4480DEEA)));
        c.drawCircle(pos, 4, fillP(const Color(0xFFE0F7FA)));
      case 'fire':
        c.drawCircle(pos - dir * 8, 6, fillP(const Color(0x66FF6F00)));
        c.drawCircle(pos, 9, fillP(const Color(0x88FF5722)));
        c.drawCircle(pos, 5, fillP(const Color(0xFFFFCA28)));
      case 'hammer':
        c.drawCircle(pos, 11, fillP(const Color(0x5590CAF9)));
        c.save();
        c.translate(pos.dx, pos.dy);
        c.rotate(t * 18);
        c.drawRect(const Rect.fromLTWH(-5, -7, 10, 14), fillP(const Color(0xFFCFD8DC)));
        c.drawLine(const Offset(0, 7), const Offset(0, 14), strokeP(const Color(0xFF6D4C41), 2.5));
        c.restore();
      default:
        c.drawCircle(pos, 3, fillP(Colors.white));
    }
  }

  void _drawFx(Canvas c, Fx f, double t) {
    final p = f.p;
    switch (f.kind) {
      case 'holy':
        final col = f.color ?? const Color(0xFFFFE082);
        c.drawOval(Rect.fromCenter(center: Offset(f.x, f.y + 4), width: f.radius * 2.4, height: f.radius * 1.1),
            fillP(col.withValues(alpha: 0.5 * (1 - p))));
        c.drawRect(Rect.fromCenter(center: Offset(f.x, f.y - 30), width: 14 * (1 - p) + 4, height: 70),
            fillP(col.withValues(alpha: 0.35 * (1 - p))));
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3 + t * 2;
          c.drawCircle(Offset(f.x + cos(a) * f.radius * 0.8, f.y - p * 40 - i * 3), 2.5, fillP(col.withValues(alpha: 1 - p)));
        }
      case 'spark':
        c.drawCircle(Offset(f.x, f.y - 8), f.radius * (0.5 + p), fillP((f.color ?? Colors.white).withValues(alpha: 0.7 * (1 - p))));
      case 'stomp':
        final r = f.radius * (0.3 + p * 0.8);
        c.drawOval(Rect.fromCenter(center: Offset(f.x, f.y), width: r * 2, height: r * 1.1),
            strokeP(const Color(0xFFD7CCC8).withValues(alpha: 1 - p), 6 * (1 - p) + 1));
        c.drawOval(Rect.fromCenter(center: Offset(f.x, f.y), width: r * 1.7, height: r * 0.9),
            fillP(const Color(0xFF8D6E63).withValues(alpha: 0.35 * (1 - p))));
      case 'shockwave':
        final a = Offset(f.x, f.y), b = Offset(f.x2, f.y2);
        final head = Offset.lerp(a, b, min(1.0, p * 1.6))!;
        final rnd = Random(f.x.toInt());
        for (var i = 0; i < 16; i++) {
          final s = i / 16;
          if (s > p * 1.6) break;
          final pt = Offset.lerp(a, b, s)!;
          c.drawCircle(pt + Offset(rnd.nextDouble() * 12 - 6, rnd.nextDouble() * 12 - 6), f.radius * 0.5 * (1 - p) + 4,
              fillP(const Color(0xFFBCAAA4).withValues(alpha: 0.6 * (1 - p))));
        }
        c.drawCircle(head, 14, fillP(const Color(0xFFFFB74D).withValues(alpha: 0.6 * (1 - p))));
      case 'lightning':
      case 'healwave':
        final pts = f.pts!;
        final col = f.color ?? Colors.cyanAccent;
        final rnd = Random((t * 20).floor());
        for (var i = 0; i + 1 < pts.length; i++) {
          final path = Path()..moveTo(pts[i].dx, pts[i].dy);
          const segs = 6;
          for (var s = 1; s <= segs; s++) {
            final q = Offset.lerp(pts[i], pts[i + 1], s / segs)!;
            final j = s == segs ? Offset.zero : Offset(rnd.nextDouble() * 14 - 7, rnd.nextDouble() * 14 - 7);
            path.lineTo(q.dx + j.dx, q.dy + j.dy);
          }
          c.drawPath(path, strokeP(col.withValues(alpha: 0.4 * (1 - p)), 7));
          c.drawPath(path, strokeP(Colors.white.withValues(alpha: 1 - p), 2));
        }
      case 'levelup':
        final r = f.radius * (0.4 + p);
        c.drawOval(Rect.fromCenter(center: Offset(f.x, f.y + 4), width: r * 2, height: r),
            strokeP(const Color(0xFFFFD54F).withValues(alpha: 1 - p), 3));
        for (var i = 0; i < 8; i++) {
          final a = i * pi / 4;
          c.drawCircle(Offset(f.x + cos(a) * r * 0.7, f.y - p * 50 + sin(a) * 6), 2.5,
              fillP(const Color(0xFFFFF59D).withValues(alpha: 1 - p)));
        }
      case 'poof':
        c.drawCircle(Offset(f.x, f.y - 6), f.radius * (0.4 + p * 0.8), fillP(const Color(0xFFB0BEC5).withValues(alpha: 0.6 * (1 - p))));
      case 'explosion':
        c.drawCircle(Offset(f.x, f.y), f.radius * (0.3 + p), fillP(const Color(0xFFFF7043).withValues(alpha: 0.7 * (1 - p))));
        c.drawCircle(Offset(f.x, f.y - p * 30), f.radius * (0.2 + p * 0.8), fillP(Colors.black.withValues(alpha: 0.4 * (1 - p))));
    }
  }

  @override
  bool shouldRepaint(covariant WorldPainter oldDelegate) => true;
}
