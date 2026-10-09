import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/data.dart';
import '../game/entities.dart';
import '../game/game.dart';
import '../render/sprites.dart';
import '../render/world_painter.dart';
import 'controller.dart';
import 'hud.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.faction, required this.difficulty, this.seed, this.onReady});
  final Faction faction;
  final Difficulty difficulty;
  final int? seed;

  /// Testler için: oyun kurulduğunda denetleyiciyi verir.
  @visibleForTesting
  final void Function(GameController c)? onReady;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late Game game;
  late GameController c;
  late TerrainCache terrain;
  final FogImage fogImg = FogImage();
  final MinimapBase minimapBase = MinimapBase();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  final ValueNotifier<int> _hud = ValueNotifier(0);
  final ValueNotifier<int> _minimap = ValueNotifier(0);
  double _hudAcc = 0, _mmAcc = 0;
  final FocusNode _focus = FocusNode();

  Offset? _screenMouse;
  Offset? _downPos;
  bool _dragging = false;
  bool _middlePan = false;
  Offset? _panLast;
  double _lastClickTime = -10;
  Unit? _lastClickUnit;
  Offset? _touchStart;
  bool _touchMoved = false;
  final Stopwatch _clock = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    Sprites.initTrees();
    _newGame();
    _ticker = createTicker(_tick)..start();
  }

  void _newGame() {
    game = Game(playerFaction: widget.faction, difficulty: widget.difficulty, seed: widget.seed);
    c = GameController(game);
    terrain = TerrainCache(game.map);
    game.msg(kPlayer, 'Savaş başladı! İşçilerinle kaynak topla, ordunu kur ve düşman üssünü yık.',
        color: const Color(0xFFFFE082));
    widget.onReady?.call(c);
  }

  @override
  void dispose() {
    _ticker.dispose();
    terrain.dispose();
    fogImg.dispose();
    minimapBase.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    dt = min(dt, 0.05);
    final running = !c.paused && !c.menuOpen && game.winner == null;
    if (running) game.update(dt);
    _scrollCamera(dt);
    c.pruneSelection();
    for (final m in c.view.markers) {
      m.t += dt;
    }
    c.view.markers.removeWhere((m) => m.t > 0.6);
    fogImg.update(game.fog);
    minimapBase.update(game);
    _frame.value++;
    _hudAcc += dt;
    if (_hudAcc > 0.1) {
      _hudAcc = 0;
      _hud.value++;
    }
    _mmAcc += dt;
    if (_mmAcc > 0.15) {
      _mmAcc = 0;
      _minimap.value++;
    }
    if (game.winner != null && !_shownEnd) {
      _shownEnd = true;
      setState(() {});
    }
  }

  bool _shownEnd = false;
  bool _centered = false;

  void _scrollCamera(double dt) {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    var dx = 0.0, dy = 0.0;
    if (keys.contains(LogicalKeyboardKey.arrowLeft)) dx -= 1;
    if (keys.contains(LogicalKeyboardKey.arrowRight)) dx += 1;
    if (keys.contains(LogicalKeyboardKey.arrowUp)) dy -= 1;
    if (keys.contains(LogicalKeyboardKey.arrowDown)) dy += 1;
    final m = _screenMouse;
    if (m != null && !_middlePan && _downPos == null) {
      const edge = 6.0;
      final s = c.screen;
      if (m.dx <= edge) dx -= 1;
      if (m.dx >= s.width - edge) dx += 1;
      if (m.dy <= edge) dy -= 1;
      if (m.dy >= s.height - edge) dy += 1;
    }
    if (dx != 0 || dy != 0) {
      final speed = 900 / c.view.zoom;
      c.view.camX += dx * speed * dt;
      c.view.camY += dy * speed * dt;
      c.clampCamera();
    }
  }

  void _changed() => _hud.value++;

  // ------------------------------------------------------------ Klavye

  static final _digits = [
    LogicalKeyboardKey.digit0,
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.handled;
    }
    if (e is KeyRepeatEvent) return KeyEventResult.handled;
    final hk = HardwareKeyboard.instance;
    final ctrl = hk.isControlPressed || hk.isMetaPressed;
    if (game.winner != null) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.f10) {
      setState(() => c.menuOpen = !c.menuOpen);
      return KeyEventResult.handled;
    }
    if (c.menuOpen) {
      if (k == LogicalKeyboardKey.escape) setState(() => c.menuOpen = false);
      return KeyEventResult.handled;
    }
    final di = _digits.indexOf(k);
    if (di >= 0) {
      if (ctrl) {
        c.setGroup(di);
      } else {
        c.recallGroup(di);
      }
    } else if (k == LogicalKeyboardKey.escape) {
      if (!c.escape()) setState(() => c.menuOpen = true);
    } else if (k == LogicalKeyboardKey.f1) {
      c.selectHero(0);
    } else if (k == LogicalKeyboardKey.f2) {
      c.selectHero(1);
    } else if (k == LogicalKeyboardKey.f8) {
      c.selectIdleWorker();
    } else if (k == LogicalKeyboardKey.pause) {
      setState(() => c.paused = !c.paused);
    } else if (k == LogicalKeyboardKey.space) {
      final p = game.lastAlertPos;
      if (p != null) c.centerOn(p.dx, p.dy);
    } else {
      final label = k.keyLabel;
      if (label.length == 1 && !ctrl) {
        if (!c.hotkey(label)) return KeyEventResult.ignored;
      } else {
        return KeyEventResult.ignored;
      }
    }
    _changed();
    return KeyEventResult.handled;
  }

  // ------------------------------------------------------------ Fare

  bool get _shift => HardwareKeyboard.instance.isShiftPressed;
  bool get _ctrl => HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;

  void _onDown(PointerDownEvent e) {
    _focus.requestFocus();
    c.view.mouse = e.localPosition;
    final w = c.view.toWorld(e.localPosition);
    if (e.kind == PointerDeviceKind.touch) {
      _touchStart = e.localPosition;
      _panLast = e.localPosition;
      _touchMoved = false;
      return;
    }
    if (e.buttons & kSecondaryMouseButton != 0) {
      c.rightClickWorld(w);
      _changed();
      return;
    }
    if (e.buttons & kMiddleMouseButton != 0) {
      _middlePan = true;
      _panLast = e.localPosition;
      return;
    }
    if (e.buttons & kPrimaryMouseButton != 0) {
      if (c.view.placing != null || c.view.targeting != null) {
        c.leftClickWorld(w, shift: _shift);
        _changed();
        return;
      }
      _downPos = e.localPosition;
      _dragging = false;
    }
  }

  void _onMove(PointerMoveEvent e) {
    c.view.mouse = e.localPosition;
    if (e.kind == PointerDeviceKind.touch && _touchStart != null) {
      if ((e.localPosition - _touchStart!).distance > 10) _touchMoved = true;
      if (_touchMoved) {
        final d = e.localPosition - _panLast!;
        c.view.camX -= d.dx / c.view.zoom;
        c.view.camY -= d.dy / c.view.zoom;
        c.clampCamera();
      }
      _panLast = e.localPosition;
      return;
    }
    if (_middlePan) {
      final d = e.localPosition - _panLast!;
      c.view.camX -= d.dx / c.view.zoom;
      c.view.camY -= d.dy / c.view.zoom;
      c.clampCamera();
      _panLast = e.localPosition;
      return;
    }
    final dp = _downPos;
    if (dp != null && (_dragging || (e.localPosition - dp).distance > 6)) {
      _dragging = true;
      c.view.dragStart = dp;
      c.view.dragEnd = e.localPosition;
    }
  }

  void _onUp(PointerUpEvent e) {
    final w = c.view.toWorld(e.localPosition);
    if (e.kind == PointerDeviceKind.touch && _touchStart != null) {
      if (!_touchMoved) _tap(w);
      _touchStart = null;
      _changed();
      return;
    }
    if (_middlePan) {
      _middlePan = false;
      return;
    }
    final dp = _downPos;
    if (dp != null) {
      if (_dragging) {
        final a = c.view.toWorld(dp), b = c.view.toWorld(e.localPosition);
        c.boxSelect(Rect.fromPoints(a, b), shift: _shift);
      } else {
        final now = _clock.elapsedMilliseconds / 1000.0;
        final u = c.pickVisible(w);
        final dbl = u != null && u == _lastClickUnit && now - _lastClickTime < 0.35;
        c.leftClickWorld(w, shift: _shift, ctrl: _ctrl, dbl: dbl);
        _lastClickTime = now;
        _lastClickUnit = u;
      }
    }
    _downPos = null;
    _dragging = false;
    c.view.dragStart = null;
    c.view.dragEnd = null;
    _changed();
  }

  void _tap(Offset w) {
    if (c.view.placing != null || c.view.targeting != null) {
      c.leftClickWorld(w);
      return;
    }
    final u = c.pickVisible(w);
    if (u != null && u.owner == kPlayer) {
      final now = _clock.elapsedMilliseconds / 1000.0;
      final dbl = u == _lastClickUnit && now - _lastClickTime < 0.35;
      c.leftClickWorld(w, dbl: dbl);
      _lastClickTime = now;
      _lastClickUnit = u;
    } else if (c.ownSelection) {
      c.rightClickWorld(w);
    } else {
      c.leftClickWorld(w);
    }
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      c.zoomAt(e.localPosition, e.scrollDelta.dy > 0 ? 0.9 : 1.1);
    }
  }

  void _onPanZoom(PointerPanZoomUpdateEvent e) {
    if ((e.scale - 1).abs() > 0.01) {
      c.zoomAt(e.localPosition, 1 + (e.scale - 1) * 0.08);
    }
    c.view.camX -= e.localPanDelta.dx / c.view.zoom;
    c.view.camY -= e.localPanDelta.dy / c.view.zoom;
    c.clampCamera();
  }

  // ------------------------------------------------------------ Arayüz

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: MouseRegion(
          onExit: (_) {
            _screenMouse = null;
          },
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerHover: (e) => _screenMouse = e.position,
            onPointerMove: (e) => _screenMouse = e.position,
            onPointerDown: (e) => _screenMouse = e.position,
            child: LayoutBuilder(builder: (context, cons) {
              c.screen = cons.biggest;
              if (!_centered) {
                _centered = true;
                final hall = game.units.firstWhere((u) => u.owner == kPlayer && u.type.townHall);
                c.centerOn(hall.x, hall.y);
              }
              return Stack(children: [
                Positioned.fill(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _hud,
                    builder: (context, _, child) => MouseRegion(
                      cursor: c.view.targeting != null ? SystemMouseCursors.precise : SystemMouseCursors.basic,
                      onHover: (e) => c.view.mouse = e.localPosition,
                      child: child,
                    ),
                    child: Listener(
                      onPointerDown: _onDown,
                      onPointerMove: _onMove,
                      onPointerUp: _onUp,
                      onPointerSignal: _onSignal,
                      onPointerPanZoomUpdate: _onPanZoom,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: WorldPainter(
                            g: game,
                            view: c.view,
                            terrain: terrain,
                            fog: fogImg,
                            showAllBars: () => HardwareKeyboard.instance.isAltPressed,
                            repaint: _frame,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _hud,
                    builder: (context, _, _) => TopBar(
                      c: c,
                      onMenu: () => setState(() => c.menuOpen = true),
                      onPause: () => setState(() => c.paused = !c.paused),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: kTopBar + 8,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _hud,
                    builder: (context, _, _) => HeroBar(c: c, onChanged: _changed),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: kBottomHud + 14,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _hud,
                    builder: (context, _, _) => MessageList(c: c),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _hud,
                    builder: (context, _, _) => BottomPanel(
                      c: c,
                      minimapBase: minimapBase,
                      fog: fogImg,
                      minimapRepaint: _minimap,
                      onChanged: _changed,
                    ),
                  ),
                ),
                if (c.paused && !c.menuOpen)
                  Positioned(
                    top: kTopBar + 40,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Text('DURAKLATILDI',
                            style: kTextShadow.copyWith(color: kGold, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 4)),
                      ),
                    ),
                  ),
                if (c.menuOpen && game.winner == null) _menuOverlay(),
                if (game.winner != null) _endOverlay(),
              ]);
            }),
          ),
        ),
      ),
    );
  }

  Widget _menuButton(String label, VoidCallback onTap, {bool primary = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SizedBox(
          width: 260,
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary ? const Color(0xFF6B4A1E) : const Color(0xFF2A1F14),
              foregroundColor: kGold,
              side: const BorderSide(color: kBorder, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            onPressed: () {
              onTap();
              _focus.requestFocus();
            },
            child: Text(label),
          ),
        ),
      );

  Widget _menuOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xAA000000),
        child: Center(
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(24),
            decoration: panelDeco(radius: 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('OYUN MENÜSÜ', style: TextStyle(color: kGold, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 18),
              _menuButton('Oyuna Dön', () => setState(() => c.menuOpen = false), primary: true),
              _menuButton('Yeniden Başlat', () => setState(_restart)),
              _menuButton('Ana Menüye Dön', () => Navigator.of(context).pop()),
              const SizedBox(height: 8),
              const Divider(color: kBorder),
              const SizedBox(height: 6),
              const Text(
                'Sol tık: seç · Sürükle: kutu seçimi · Çift tık: aynı türdekiler\n'
                'Sağ tık: hareket / saldırı / toplama / eşya alma / toplanma noktası\n'
                'A: saldır · S: dur · H: pozisyonu koru · M: hareket · B: inşa · G: topla\n'
                'Q W E: kahraman yetenekleri · O: yetenek öğren\n'
                'Ctrl+1-9: grup ata · 1-9: grup seç (iki kez: kamera)\n'
                'F1/F2: kahramanlar · F8: boştaki işçi · Boşluk: son uyarı\n'
                'Ok tuşları / ekran kenarı / orta tuş / iki parmak: kamera · Tekerlek: yakınlaştır\n'
                'Alt: tüm can çubukları · Pause: duraklat',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD7CCC8), fontSize: 12.5, height: 1.5),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _restart() {
    terrain.dispose();
    fogImg.reset();
    minimapBase.reset();
    _newGame();
    _shownEnd = false;
    _centered = false;
  }

  Widget _endOverlay() {
    final won = game.winner == kPlayer;
    final me = game.players[kPlayer], ai = game.players[kEnemy];
    Widget row(String label, String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(color: Color(0xFFD7CCC8), fontSize: 14))),
            SizedBox(width: 90, child: Text(a, textAlign: TextAlign.right, style: TextStyle(color: me.color, fontSize: 14, fontWeight: FontWeight.bold))),
            SizedBox(width: 90, child: Text(b, textAlign: TextAlign.right, style: TextStyle(color: ai.color, fontSize: 14, fontWeight: FontWeight.bold))),
          ]),
        );
    return Positioned.fill(
      child: Container(
        color: const Color(0xBB000000),
        child: Center(
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            decoration: panelDeco(radius: 10, glow: won),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(won ? 'ZAFER!' : 'YENİLGİ',
                  style: TextStyle(
                      color: won ? const Color(0xFFFFD54F) : const Color(0xFFFF5252),
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6)),
              const SizedBox(height: 6),
              Text(won ? 'Düşman üssü yerle bir edildi.' : 'Tüm yapılarınız yıkıldı.',
                  style: const TextStyle(color: Color(0xFFD7CCC8), fontSize: 15)),
              const SizedBox(height: 16),
              row('', 'Siz', 'Rakip'),
              const Divider(color: kBorder),
              row('Toplanan altın', '${me.goldMined}', '${ai.goldMined}'),
              row('Toplanan odun', '${me.lumberMined}', '${ai.lumberMined}'),
              row('Üretilen birim', '${me.unitsTrained}', '${ai.unitsTrained}'),
              row('Öldürülen', '${me.kills}', '${ai.kills}'),
              row('Kaybedilen birim', '${me.unitsLost}', '${ai.unitsLost}'),
              const SizedBox(height: 6),
              Text('Süre: ${(game.time ~/ 60)} dk ${(game.time % 60).floor()} sn',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 18),
              _menuButton('Tekrar Oyna', () => setState(_restart), primary: true),
              _menuButton('Ana Menüye Dön', () => Navigator.of(context).pop()),
            ]),
          ),
        ),
      ),
    );
  }
}
