import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/data.dart';
import 'render/sprites.dart';
import 'ui/game_screen.dart';
import 'ui/hud.dart';
import 'ui/mobile_hud.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) BrowserContextMenu.disableContextMenu();
  if (isMobilePlatform) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  runApp(const KingdomsApp());
}

const bool _autoStart = bool.fromEnvironment('AUTOSTART');

class KingdomsApp extends StatelessWidget {
  const KingdomsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Krallıklar Savaşı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9C7A45), brightness: Brightness.dark),
        tooltipTheme: const TooltipThemeData(textStyle: TextStyle(color: Colors.white, fontSize: 12.5)),
      ),
      home: _autoStart
          ? const GameScreen(faction: humanFaction, difficulty: Difficulty.normal, seed: 3)
          : const MenuScreen(),
    );
  }
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  Faction faction = humanFaction;
  Difficulty difficulty = Difficulty.normal;

  void _start() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(faction: faction, difficulty: difficulty),
    ));
  }

  Widget _factionCard(Faction f, String desc) {
    final selected = identical(f, faction);
    final color = playerColors[0];
    return GestureDetector(
      onTap: () => setState(() => faction = f),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 300,
          padding: const EdgeInsets.all(14),
          decoration: panelDeco(radius: 10, glow: selected),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final h in f.heroes)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: iconBox(highlight: selected),
                  child: unitIcon(ut(h), color, 76),
                ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: iconBox(highlight: selected),
                child: unitIcon(ut(f.hall), color, 76),
              ),
            ]),
            const SizedBox(height: 10),
            Text(f.name, style: const TextStyle(color: kGold, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(desc, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFD7CCC8), fontSize: 13, height: 1.4)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Sprites.initTrees();
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: CustomPaint(painter: _MenuBackground())),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('KRALLIKLAR SAVAŞI',
                  textAlign: TextAlign.center,
                  style: kTextShadow.copyWith(color: kGold, fontSize: 46, fontWeight: FontWeight.w900, letterSpacing: 5)),
              const SizedBox(height: 4),
              Text('Kahramanlar · Ordular · Gerçek Zamanlı Strateji',
                  style: kTextShadow.copyWith(color: const Color(0xFFD7CCC8), fontSize: 16, letterSpacing: 1.5)),
              const SizedBox(height: 30),
              Text('Tarafını seç', style: kTextShadow.copyWith(color: kGold, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(spacing: 20, runSpacing: 20, alignment: WrapAlignment.center, children: [
                _factionCard(humanFaction,
                    'Paladin ve Başbüyücü komutasında piyadeler, tüfekçiler ve şövalyeler. Dengeli ve dayanıklı.'),
                _factionCard(orcFaction,
                    'Boğa Şef ve Kahin önderliğinde savaşçılar, mızrakçılar ve kurt biniciler. Güçlü ve hızlı.'),
              ]),
              const SizedBox(height: 26),
              Text('Zorluk', style: kTextShadow.copyWith(color: kGold, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(spacing: 10, children: [
                for (final d in Difficulty.values)
                  ChoiceChip(
                    label: Text(d.label, style: const TextStyle(fontSize: 15)),
                    selected: d == difficulty,
                    selectedColor: const Color(0xFF6B4A1E),
                    backgroundColor: const Color(0xFF241A11),
                    side: const BorderSide(color: kBorder),
                    onSelected: (_) => setState(() => difficulty = d),
                  ),
              ]),
              const SizedBox(height: 30),
              SizedBox(
                width: 280,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7A5420),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFFFD54F), width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 2),
                  ),
                  onPressed: _start,
                  child: const Text('SAVAŞA BAŞLA'),
                ),
              ),
              const SizedBox(height: 26),
              Container(
                width: 620,
                padding: const EdgeInsets.all(14),
                decoration: panelDeco(radius: 8),
                child: const Text(
                  'Amaç: Düşmanın tüm yapılarını yık.\n'
                  'İşçilerle altın ve odun topla, çiftlik kurarak yiyecek sınırını artır. Kışlada ordu, '
                  'sunakta kahraman yetiştir. Kahramanlar tarafsız yaratık kamplarını temizleyerek seviye '
                  'atlar, yetenek öğrenir ve eşya toplar. Gece görüş mesafesi azalır.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFD7CCC8), fontSize: 13.5, height: 1.5),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _MenuBackground extends CustomPainter {
  const _MenuBackground();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1426), Color(0xFF1B2A1A), Color(0xFF223A17)],
        ).createShader(rect),
    );
    final rnd = Random(4);
    for (var i = 0; i < 90; i++) {
      canvas.drawCircle(Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height * 0.45),
          rnd.nextDouble() * 1.4 + 0.3, Paint()..color = Colors.white.withValues(alpha: rnd.nextDouble() * 0.7));
    }
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.16), 46, Paint()..color = const Color(0x33FFF8E1));
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.16), 34, Paint()..color = const Color(0xFFFFF3C4));
    // dağlar
    final hills = Path()..moveTo(0, size.height * 0.75);
    for (var x = 0.0; x <= size.width; x += size.width / 12) {
      hills.lineTo(x, size.height * (0.62 + rnd.nextDouble() * 0.12));
    }
    hills
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hills, Paint()..color = const Color(0xFF14240F));
    // orman silueti
    for (var x = -20.0; x < size.width + 40; x += 26) {
      final y = size.height * 0.88 + rnd.nextDouble() * size.height * 0.08;
      Sprites.tree(canvas, x, y, rnd.nextInt(4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
