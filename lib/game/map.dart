import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'data.dart';

/// Arazi türleri.
const int tGrass = 0;
const int tDirt = 1;
const int tWater = 2;

const int kTreeWood = 50;

class _Zone {
  const _Zone(this.x, this.y, this.r);
  final double x, y, r;
}

class _Seg {
  const _Seg(this.x1, this.y1, this.x2, this.y2, this.r);
  final double x1, y1, x2, y2, r;

  double dist(double px, double py) {
    final dx = x2 - x1, dy = y2 - y1;
    final l2 = dx * dx + dy * dy;
    var t = l2 == 0 ? 0.0 : ((px - x1) * dx + (py - y1) * dy) / l2;
    t = t.clamp(0.0, 1.0);
    final cx = x1 + dx * t, cy = y1 + dy * t;
    return sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
  }
}

class TilePos {
  const TilePos(this.x, this.y);
  final int x, y;
}

class GameMap {
  GameMap(int seed) {
    _generate(seed);
  }

  final int w = kMapW;
  final int h = kMapH;
  final Uint8List terrain = Uint8List(kMapW * kMapH);
  final Int16List wood = Int16List(kMapW * kMapH);
  final Uint8List occ = Uint8List(kMapW * kMapH);
  final Uint8List variant = Uint8List(kMapW * kMapH);

  /// Ağaçlar değiştiğinde artar (mini harita yeniden çizimi için).
  int treeVersion = 0;

  int idx(int x, int y) => y * w + x;
  bool inside(int x, int y) => x >= 0 && y >= 0 && x < w && y < h;

  bool walkable(int x, int y) {
    if (!inside(x, y)) return false;
    final i = y * w + x;
    return terrain[i] != tWater && wood[i] == 0 && occ[i] == 0;
  }

  bool walkablePx(double x, double y) => walkable((x / kTile).floor(), (y / kTile).floor());

  bool isTree(int x, int y) => inside(x, y) && wood[y * w + x] > 0;

  bool buildable(int x, int y) {
    if (!inside(x, y)) return false;
    final i = y * w + x;
    return terrain[i] != tWater && wood[i] == 0 && occ[i] == 0;
  }

  static Offset tileCenter(int x, int y) => Offset((x + 0.5) * kTile, (y + 0.5) * kTile);

  void setOccupied(int tx, int ty, int size, bool on) {
    for (var y = ty; y < ty + size; y++) {
      for (var x = tx; x < tx + size; x++) {
        if (!inside(x, y)) continue;
        final i = idx(x, y);
        occ[i] = on ? occ[i] + 1 : max(0, occ[i] - 1);
      }
    }
  }

  /// Bir ağaçtan odun keser. Ağaç biterse true döner.
  bool chop(int x, int y, int amount) {
    if (!isTree(x, y)) return true;
    final i = idx(x, y);
    wood[i] = max(0, wood[i] - amount);
    if (wood[i] == 0) {
      treeVersion++;
      return true;
    }
    return false;
  }

  bool hasWalkableNeighbor(int x, int y) {
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if ((dx != 0 || dy != 0) && walkable(x + dx, y + dy)) return true;
      }
    }
    return false;
  }

  /// En yakın, erişilebilir kenarı olan ağacı bulur.
  TilePos? nearestTree(double px, double py, int maxR) {
    final cx = (px / kTile).floor(), cy = (py / kTile).floor();
    TilePos? best;
    var bestD = double.infinity;
    for (var r = 0; r <= maxR; r++) {
      for (var y = cy - r; y <= cy + r; y++) {
        for (var x = cx - r; x <= cx + r; x++) {
          if (max((x - cx).abs(), (y - cy).abs()) != r) continue;
          if (!isTree(x, y) || !hasWalkableNeighbor(x, y)) continue;
          final c = tileCenter(x, y);
          final d = (c.dx - px) * (c.dx - px) + (c.dy - py) * (c.dy - py);
          if (d < bestD) {
            bestD = d;
            best = TilePos(x, y);
          }
        }
      }
      if (best != null && r >= 2) return best;
    }
    return best;
  }

  /// (tx,ty) etrafındaki halkalarda, (fx,fy)'ye en yakın yürünebilir karo.
  TilePos? nearestWalkable(int tx, int ty, double fx, double fy, {int maxR = 14}) {
    if (walkable(tx, ty)) return TilePos(tx, ty);
    for (var r = 1; r <= maxR; r++) {
      TilePos? best;
      var bestD = double.infinity;
      for (var y = ty - r; y <= ty + r; y++) {
        for (var x = tx - r; x <= tx + r; x++) {
          if (max((x - tx).abs(), (y - ty).abs()) != r) continue;
          if (!walkable(x, y)) continue;
          final c = tileCenter(x, y);
          final d = (c.dx - fx) * (c.dx - fx) + (c.dy - fy) * (c.dy - fy);
          if (d < bestD) {
            bestD = d;
            best = TilePos(x, y);
          }
        }
      }
      if (best != null) return best;
    }
    return null;
  }

  // ------------------------------------------------------------ Yol bulma (A*)

  final Float64List _g = Float64List(kMapW * kMapH);
  final Int32List _par = Int32List(kMapW * kMapH);
  final Int32List _open = Int32List(kMapW * kMapH);
  final Int32List _closed = Int32List(kMapW * kMapH);
  int _stamp = 0;
  final List<int> _heap = [];
  final List<double> _heapF = [];

  void _push(int n, double f) {
    _heap.add(n);
    _heapF.add(f);
    var i = _heap.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_heapF[p] <= _heapF[i]) break;
      final tn = _heap[p], tf = _heapF[p];
      _heap[p] = _heap[i];
      _heapF[p] = _heapF[i];
      _heap[i] = tn;
      _heapF[i] = tf;
      i = p;
    }
  }

  int _pop() {
    final top = _heap[0];
    final lastN = _heap.removeLast();
    final lastF = _heapF.removeLast();
    if (_heap.isNotEmpty) {
      _heap[0] = lastN;
      _heapF[0] = lastF;
      var i = 0;
      final n = _heap.length;
      while (true) {
        final l = i * 2 + 1, r = l + 1;
        var m = i;
        if (l < n && _heapF[l] < _heapF[m]) m = l;
        if (r < n && _heapF[r] < _heapF[m]) m = r;
        if (m == i) break;
        final tn = _heap[m], tf = _heapF[m];
        _heap[m] = _heap[i];
        _heapF[m] = _heapF[i];
        _heap[i] = tn;
        _heapF[i] = tf;
        i = m;
      }
    }
    return top;
  }

  static const List<int> _dxs = [1, -1, 0, 0, 1, 1, -1, -1];
  static const List<int> _dys = [0, 0, 1, -1, 1, -1, 1, -1];
  static const List<double> _cost = [1, 1, 1, 1, 1.4142, 1.4142, 1.4142, 1.4142];

  /// (sx,sy)'den (gx,gy)'ye dünya koordinatlarında yol. Hedefe ulaşılamazsa
  /// mümkün olan en yakın noktaya giden yolu döndürür.
  List<Offset> findPath(double sx, double sy, double gx, double gy) {
    var stx = (sx / kTile).floor().clamp(0, w - 1);
    var sty = (sy / kTile).floor().clamp(0, h - 1);
    var gtx = (gx / kTile).floor().clamp(0, w - 1);
    var gty = (gy / kTile).floor().clamp(0, h - 1);

    if (!walkable(stx, sty)) {
      final n = nearestWalkable(stx, sty, sx, sy, maxR: 4);
      if (n == null) return [Offset(gx, gy)];
      stx = n.x;
      sty = n.y;
    }
    final exactGoal = walkable(gtx, gty);
    if (!exactGoal) {
      final n = nearestWalkable(gtx, gty, sx, sy);
      if (n == null) return const [];
      gtx = n.x;
      gty = n.y;
    }
    final goalPoint = exactGoal ? Offset(gx, gy) : tileCenter(gtx, gty);
    if (stx == gtx && sty == gty) return [goalPoint];

    _stamp++;
    _heap.clear();
    _heapF.clear();
    final start = idx(stx, sty), goal = idx(gtx, gty);
    _g[start] = 0;
    _par[start] = -1;
    _open[start] = _stamp;
    double heur(int x, int y) {
      final dx = (x - gtx).abs(), dy = (y - gty).abs();
      return (dx + dy) + (1.4142 - 2) * min(dx, dy);
    }

    _push(start, heur(stx, sty));
    var best = start;
    var bestH = heur(stx, sty);
    var found = false;
    var iter = 0;
    while (_heap.isNotEmpty && iter++ < 9000) {
      final cur = _pop();
      if (_closed[cur] == _stamp) continue;
      _closed[cur] = _stamp;
      if (cur == goal) {
        found = true;
        break;
      }
      final cx = cur % w, cy = cur ~/ w;
      final hc = heur(cx, cy);
      if (hc < bestH) {
        bestH = hc;
        best = cur;
      }
      for (var k = 0; k < 8; k++) {
        final dx = _dxs[k], dy = _dys[k];
        final nx = cx + dx, ny = cy + dy;
        if (!walkable(nx, ny)) continue;
        if (dx != 0 && dy != 0 && (!walkable(cx + dx, cy) || !walkable(cx, cy + dy))) continue;
        final ni = ny * w + nx;
        if (_closed[ni] == _stamp) continue;
        final ng = _g[cur] + _cost[k];
        if (_open[ni] == _stamp && ng >= _g[ni]) continue;
        _open[ni] = _stamp;
        _g[ni] = ng;
        _par[ni] = cur;
        _push(ni, ng + heur(nx, ny));
      }
    }
    final end = found ? goal : best;
    final tiles = <int>[];
    var n = end;
    while (n != -1 && n != start) {
      tiles.add(n);
      n = _par[n];
    }
    final pts = <Offset>[
      for (var i = tiles.length - 1; i >= 0; i--) tileCenter(tiles[i] % w, tiles[i] ~/ w),
    ];
    if (found) {
      if (pts.isNotEmpty) pts[pts.length - 1] = goalPoint;
    }
    if (pts.isEmpty) return const [];
    return _smooth(sx, sy, pts);
  }

  List<Offset> _smooth(double sx, double sy, List<Offset> pts) {
    final out = <Offset>[];
    var cur = Offset(sx, sy);
    var i = 0;
    while (i < pts.length) {
      var j = i;
      while (j + 1 < pts.length && lineClear(cur, pts[j + 1])) {
        j++;
      }
      out.add(pts[j]);
      cur = pts[j];
      i = j + 1;
    }
    return out;
  }

  /// İki nokta arasındaki düz çizginin engelsiz olup olmadığı (küçük bir pay ile).
  bool lineClear(Offset a, Offset b) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1) return true;
    final nx = -dy / len * 6, ny = dx / len * 6;
    final steps = (len / 8).ceil();
    for (var s = 1; s <= steps; s++) {
      final t = s / steps;
      final x = a.dx + dx * t, y = a.dy + dy * t;
      if (!walkablePx(x, y) || !walkablePx(x + nx, y + ny) || !walkablePx(x - nx, y - ny)) {
        return false;
      }
    }
    return true;
  }

  // ------------------------------------------------------------ Harita üretimi

  void _generate(int seed) {
    final rng = Random(seed);
    const gs = 12;
    final grid = List.generate((gs + 2) * (gs + 2), (_) => rng.nextDouble());
    final grid2 = List.generate((gs * 2 + 2) * (gs * 2 + 2), (_) => rng.nextDouble());

    double smooth(double t) => t * t * (3 - 2 * t);
    double vnoise(List<double> g, int gw, double x, double y) {
      final x0 = x.floor(), y0 = y.floor();
      final fx = smooth(x - x0), fy = smooth(y - y0);
      double at(int a, int b) => g[(b.clamp(0, gw - 1)) * gw + a.clamp(0, gw - 1)];
      final a = at(x0, y0), b = at(x0 + 1, y0), c = at(x0, y0 + 1), d = at(x0 + 1, y0 + 1);
      return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy;
    }

    double fbm(int x, int y) {
      // Simetri için kanonik koordinat.
      var cx = x, cy = y;
      if (x + y > w - 1 || (x + y == w - 1 && x > (w - 1) ~/ 2)) {
        cx = w - 1 - x;
        cy = h - 1 - y;
      }
      final n1 = vnoise(grid, gs + 2, cx / 7.0, cy / 7.0);
      final n2 = vnoise(grid2, gs * 2 + 2, cx / 3.2, cy / 3.2);
      return n1 * 0.72 + n2 * 0.28;
    }

    // Açık alanlar (tümü noktasal simetrik olarak aynalanır).
    final clears = <_Zone>[];
    final waters = <_Zone>[];
    final dirts = <_Zone>[];
    final lanes = <_Seg>[];
    void zone(List<_Zone> list, double x, double y, double r) {
      list.add(_Zone(x, y, r));
      list.add(_Zone(w - 1 - x, h - 1 - y, r));
    }

    void lane(List<List<double>> pts, double r) {
      for (var i = 0; i + 1 < pts.length; i++) {
        final a = pts[i], b = pts[i + 1];
        lanes.add(_Seg(a[0], a[1], b[0], b[1], r));
        lanes.add(_Seg(w - 1 - a[0], h - 1 - a[1], w - 1 - b[0], h - 1 - b[1], r));
      }
    }

    final s0 = startLocs[0];
    zone(clears, s0.hallX + 2.0, s0.hallY + 2.0, 11.5);
    zone(dirts, s0.hallX + 1.5, s0.hallY + 1.5, 4.2);
    zone(dirts, s0.mineX + 1.0, s0.mineY + 1.0, 2.6);
    final e0 = expansionMines[0];
    zone(clears, e0[0] + 4.0, e0[1] + 4.0, 7.5);
    zone(dirts, e0[0] + 1.0, e0[1] + 1.0, 2.6);
    zone(clears, 39.5, 39.5, 6.5);
    zone(dirts, 39.5, 39.5, 3.0);
    for (final c in campDefs) {
      clears.add(_Zone(c.x, c.y, 4.5));
    }
    zone(waters, 27, 29, 3.2);
    zone(clears, 28.5, 31, 7.5);

    lane([
      [16, 62], [27, 52], [39.5, 39.5],
    ], 2.4);
    lane([
      [13, 58], [12, 40], [13, 18], [20, 12], [40, 11], [52, 12],
    ], 2.3);
    lane([
      [31, 33], [37, 41],
    ], 1.8);
    lane([
      [31, 33], [19, 27],
    ], 1.8);
    lane([
      [22, 61], [25, 57], [30, 50],
    ], 1.8);

    bool inZones(List<_Zone> zs, int x, int y) {
      for (final z in zs) {
        final dx = x - z.x, dy = y - z.y;
        if (dx * dx + dy * dy <= z.r * z.r) return true;
      }
      return false;
    }

    double laneDist(int x, int y) {
      var d = double.infinity;
      for (final s in lanes) {
        final dd = s.dist(x.toDouble(), y.toDouble()) - s.r;
        if (dd < d) d = dd;
      }
      return d;
    }

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = idx(x, y);
        variant[i] = rng.nextInt(256);
        final border = x < 2 || y < 2 || x >= w - 2 || y >= h - 2;
        final n = fbm(x, y);
        final ld = laneDist(x, y);
        final clear = inZones(clears, x, y) || ld <= 0;
        if (inZones(waters, x, y)) {
          terrain[i] = tWater;
          continue;
        }
        var forest = border || (!clear && n > 0.5);
        // Kenar yakınında daha sık orman.
        final edge = min(min(x, y), min(w - 1 - x, h - 1 - y));
        if (!clear && edge < 5 && n > 0.36) forest = true;
        if (forest) {
          wood[i] = kTreeWood;
        }
        if (inZones(dirts, x, y) || ld < -1.1 + (n - 0.5) * 1.6) {
          terrain[i] = tDirt;
        }
      }
    }
    // Simetriyi kesinleştir (ağaçlar ve su).
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final mx = w - 1 - x, my = h - 1 - y;
        if (x + y > w - 1 || (x + y == w - 1 && x > mx)) {
          wood[idx(x, y)] = wood[idx(mx, my)];
          terrain[idx(x, y)] = terrain[idx(mx, my)];
        }
      }
    }
    _ensureConnected();
  }

  void _ensureConnected() {
    final a = startLocs[0], b = startLocs[1];
    final sx = a.hallX + 2, sy = a.hallY + 5;
    final seen = Uint8List(w * h);
    final q = <int>[idx(sx, sy)];
    seen[q.first] = 1;
    var qi = 0;
    while (qi < q.length) {
      final c = q[qi++];
      final cx = c % w, cy = c ~/ w;
      for (var k = 0; k < 4; k++) {
        final nx = cx + _dxs[k], ny = cy + _dys[k];
        if (!walkable(nx, ny)) continue;
        final ni = idx(nx, ny);
        if (seen[ni] == 1) continue;
        seen[ni] = 1;
        q.add(ni);
      }
    }
    if (seen[idx(b.hallX + 2, b.hallY - 2)] == 1) return;
    // Güvenlik: düz bir koridor aç.
    final steps = 200;
    for (var s = 0; s <= steps; s++) {
      final t = s / steps;
      final x = (sx + (b.hallX + 2 - sx) * t).round();
      final y = (sy + (b.hallY - 2 - sy) * t).round();
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (inside(x + dx, y + dy)) {
            wood[idx(x + dx, y + dy)] = 0;
            wood[idx(w - 1 - x - dx, h - 1 - y - dy)] = 0;
          }
        }
      }
    }
  }
}
