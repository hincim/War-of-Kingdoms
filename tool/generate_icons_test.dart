// Uygulama simgelerini lib/render/logo.dart çiziminden üretir.
//
//   flutter test tool/generate_icons_test.dart
//
// ICON_PREVIEW=<klasör> ortam değişkeni verilirse proje dosyalarına dokunmadan
// yalnızca önizleme PNG'lerini o klasöre yazar.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warcraft/render/logo.dart';

enum IconStyle {
  /// Tam kare, kenara kadar zemin (iOS; sistem köşeleri kendisi yuvarlar).
  full,

  /// macOS Big Sur tarzı: kenar boşluklu yuvarlak kare ve gölge.
  mac,

  /// Yuvarlak köşeli kare (web, Windows, eski Android simgeleri).
  rounded,

  /// Maskelenebilir web simgesi: amblem güvenli alan içinde.
  maskable,

  /// Android uyarlanabilir simge ön katmanı (şeffaf, yalnızca amblem).
  foreground,

  /// Android uyarlanabilir simge arka katmanı (yalnızca zemin).
  background,
}

Future<ui.Image> render(int px, IconStyle style) {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.scale(px / Logo.unit);
  void emblem(double scale) {
    c.save();
    c.translate(512, 512);
    c.scale(scale);
    c.translate(-512, -512);
    Logo.paintEmblem(c);
    c.restore();
  }

  switch (style) {
    case IconStyle.full:
      Logo.paintBackground(c);
      emblem(0.9);
    case IconStyle.maskable:
      Logo.paintBackground(c);
      emblem(0.78);
    case IconStyle.background:
      Logo.paintBackground(c);
    case IconStyle.foreground:
      emblem(0.64);
    case IconStyle.rounded:
      final r = RRect.fromRectAndRadius(const Rect.fromLTWH(20, 20, 984, 984), const Radius.circular(200));
      c.save();
      c.clipRRect(r);
      Logo.paintBackground(c);
      c.restore();
      emblem(0.86);
    case IconStyle.mac:
      final r = RRect.fromRectAndRadius(const Rect.fromLTWH(100, 100, 824, 824), const Radius.circular(185));
      c.drawRRect(
        r.shift(const Offset(0, 12)),
        Paint()
          ..color = const Color(0x66000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      c.save();
      c.clipRRect(r);
      c.translate(100, 100);
      c.scale(824 / 1024);
      Logo.paintBackground(c);
      c.restore();
      emblem(0.74);
  }
  return rec.endRecording().toImage(px, px);
}

Future<Uint8List> pngRgba(ui.Image img) async =>
    (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

/// Saydamlık kanalı olmayan (RGB) PNG; App Store simgeleri saydamlık kabul etmez.
Future<Uint8List> pngRgb(ui.Image img) async {
  final rgba = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  final w = img.width, h = img.height;
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0);
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      raw.add([rgba[i], rgba[i + 1], rgba[i + 2]]);
    }
  }
  final out = BytesBuilder()..add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    out
      ..add(_u32(data.length))
      ..add(body)
      ..add(_u32(_crc32(body)));
  }

  chunk('IHDR', [..._u32(w), ..._u32(h), 8, 2, 0, 0, 0]);
  chunk('IDAT', zlib.encode(raw.takeBytes()));
  chunk('IEND', const []);
  return out.takeBytes();
}

List<int> _u32(int v) => [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255];

final List<int> _crcTable = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 255] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// PNG başlığından genişlik.
int pngWidth(File f) {
  final b = f.readAsBytesSync();
  return (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
}

/// PNG kayıtlı çok boyutlu Windows .ico dosyası.
Future<Uint8List> ico(List<int> sizes) async {
  final images = <Uint8List>[for (final s in sizes) await pngRgba(await render(s, IconStyle.rounded))];
  final out = BytesBuilder();
  List<int> u16(int v) => [v & 255, (v >> 8) & 255];
  List<int> u32le(int v) => [v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255];
  out
    ..add(u16(0))
    ..add(u16(1))
    ..add(u16(sizes.length));
  var offset = 6 + 16 * sizes.length;
  for (var i = 0; i < sizes.length; i++) {
    final s = sizes[i] >= 256 ? 0 : sizes[i];
    out
      ..add([s, s, 0, 0])
      ..add(u16(1))
      ..add(u16(32))
      ..add(u32le(images[i].length))
      ..add(u32le(offset));
    offset += images[i].length;
  }
  for (final img in images) {
    out.add(img);
  }
  return out.takeBytes();
}

void main() {
  test('uygulama simgelerini üret', () async {
    final preview = Platform.environment['ICON_PREVIEW'];
    if (preview != null) {
      Directory(preview).createSync(recursive: true);
      for (final st in IconStyle.values) {
        File('$preview/${st.name}.png').writeAsBytesSync(await pngRgba(await render(512, st)));
      }
      return;
    }

    Future<void> write(String path, int size, IconStyle st, {bool opaque = false}) async {
      final img = await render(size, st);
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(opaque ? await pngRgb(img) : await pngRgba(img));
    }

    // iOS
    for (final f in Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset').listSync().whereType<File>()) {
      if (f.path.endsWith('.png')) await write(f.path, pngWidth(f), IconStyle.full, opaque: true);
    }
    // macOS
    for (final f in Directory('macos/Runner/Assets.xcassets/AppIcon.appiconset').listSync().whereType<File>()) {
      if (f.path.endsWith('.png')) await write(f.path, pngWidth(f), IconStyle.mac);
    }
    // Android: eski simgeler + uyarlanabilir simge katmanları
    const densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
    const res = 'android/app/src/main/res';
    for (final e in densities.entries) {
      final dir = '$res/mipmap-${e.key}';
      await write('$dir/ic_launcher.png', (48 * e.value).round(), IconStyle.rounded);
      await write('$dir/ic_launcher_foreground.png', (108 * e.value).round(), IconStyle.foreground);
      await write('$dir/ic_launcher_background.png', (108 * e.value).round(), IconStyle.background);
    }
    File('$res/mipmap-anydpi-v26/ic_launcher.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''');
    // Web
    await write('web/favicon.png', 32, IconStyle.rounded);
    await write('web/icons/Icon-192.png', 192, IconStyle.rounded);
    await write('web/icons/Icon-512.png', 512, IconStyle.rounded);
    await write('web/icons/Icon-maskable-192.png', 192, IconStyle.maskable);
    await write('web/icons/Icon-maskable-512.png', 512, IconStyle.maskable);
    // Windows
    File('windows/runner/resources/app_icon.ico').writeAsBytesSync(await ico([16, 24, 32, 48, 64, 128, 256]));
    // README
    await write('docs/logo.png', 256, IconStyle.rounded);
  });
}
