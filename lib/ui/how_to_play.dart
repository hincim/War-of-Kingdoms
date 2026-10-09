import 'package:flutter/material.dart';

import 'hud.dart';

/// "Nasıl Oynanır" penceresini açar. [touch] dokunmatik ya da fare/klavye kontrollerini seçer.
Future<void> showHowToPlay(BuildContext context, {required bool touch}) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xAA000000),
    builder: (context) => HowToPlayDialog(touch: touch),
  );
}

class HowToPlayDialog extends StatelessWidget {
  const HowToPlayDialog({super.key, required this.touch});
  final bool touch;

  static const _touchControls = [
    ('Birime dokun', 'Seç'),
    ('Seçiliyken yere dokun', 'Hareket et'),
    ('Seçiliyken düşmana dokun', 'Saldır'),
    ('İşçi seçiliyken madene / ağaca dokun', 'Altın / odun topla'),
    ('Çift dokun ya da basılı tut', 'Ekrandaki aynı türden birimleri seç'),
    ('Basılı tut + sürükle', 'Kutu seçimi'),
    ('Tek parmakla kaydır', 'Kamerayı gezdir'),
    ('İki parmakla aç / kapat', 'Yakınlaştır / uzaklaştır'),
    ('Mini haritaya dokun', 'O bölgeye git'),
    ('Sol sütun', 'Kahramanlar, boştaki işçi, Ordu (tüm askerler)'),
    ('Alt şeritteki çarpı düğmesi', 'Seçimi kaldır'),
    ('İnşa', 'İşçi → İnşa Et → yapı → yere dokun ya da sürükleyip onay düğmesine bas'),
    ('Komut düğmesine basılı tut', 'Açıklamasını gör'),
  ];

  static const _mouseControls = [
    ('Sol tık / sürükle', 'Seç / kutu seçimi (Shift: ekle, çift tık: aynı türdekiler)'),
    ('Sağ tık', 'Hareket, saldırı, toplama, eşya alma, toplanma noktası'),
    ('A · S · H · M', 'Saldır · dur · pozisyonu koru · hareket'),
    ('B · G', 'İnşa menüsü · topla (işçi)'),
    ('Q · W · E / O', 'Kahraman yetenekleri / yetenek öğren'),
    ('Ctrl+1–9 · 1–9', 'Grup ata · grubu seç (iki kez: kamera)'),
    ('F1 · F2 · F8', 'Kahramanlar · boştaki işçi'),
    ('Ok tuşları, ekran kenarı, orta tuş', 'Kamerayı gezdir'),
    ('Tekerlek', 'Yakınlaştır / uzaklaştır'),
    ('Boşluk · Alt', 'Son uyarıya git · tüm can çubukları'),
    ('Esc · F10', 'İptal · menü'),
  ];

  static const _sections = [
    (Icons.flag, 'Amaç', 'Düşmanın tüm yapılarını yık. Senin tüm yapıların yıkılırsa kaybedersin.'),
    (
      Icons.monetization_on,
      'Ekonomi',
      'İşçiler altın madeninden altın, ağaçlardan odun toplar; yeni işçileri Ana Binada üret. '
          'Her birim yiyecek kullanır, sınır dolunca Çiftlik (Ork: Barınak) kur.',
    ),
    (
      Icons.shield,
      'Ordu',
      'Kışlada asker yetiştir. Demirci (Ork: Savaş Değirmeni) silah ve zırhı güçlendirir ve '
          'süvariyi açar. Kuleler üssünü savunur.',
    ),
    (
      Icons.star,
      'Kahramanlar',
      'Sunakta kahraman çağır (en fazla 2). Düşmanları ve tarafsız yaratıkları öldürdükçe seviye atlar; '
          'yeni yetenek puanını Yetenek Öğren düğmesiyle harca. Yaratık kamplarından düşen eşyaları kahramanla al. '
          'Ölen kahramanını sunakta dirilt.',
    ),
    (
      Icons.lightbulb,
      'İpuçları',
      'Rakip ilk saldırısını Normal zorlukta yaklaşık 7. dakikada yapar; öncesinde birkaç asker ve bir '
          'kahraman hazırla. Gece görüş mesafesi azalır. Saldırıya uğrayınca uyarı çıkar ve mini haritada '
          'işaret belirir. Madenin tükenince haritadaki diğer madenlerin yanına Ana Bina kur.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final controls = touch ? _touchControls : _mouseControls;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          decoration: panelDeco(radius: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 6, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'NASIL OYNANIR',
                        style: TextStyle(color: kGold, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: kGold),
                    ),
                  ],
                ),
              ),
              const Divider(color: kBorder, height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (icon, title, text) in _sections) _section(icon, title, text),
                      const SizedBox(height: 4),
                      Text(
                        touch ? 'Dokunmatik kontroller' : 'Fare ve klavye',
                        style: const TextStyle(color: kGold, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      for (final (input, action) in controls) _control(input, action),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(IconData icon, String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: kGold, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$title  ',
                  style: const TextStyle(color: kGold, fontWeight: FontWeight.w800),
                ),
                TextSpan(text: text),
              ],
            ),
            style: const TextStyle(color: Color(0xFFD7CCC8), fontSize: 13.5, height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _control(String input, String action) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 230,
          child: Text(
            input,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Text(action, style: const TextStyle(color: Color(0xFFD7CCC8), fontSize: 13)),
        ),
      ],
    ),
  );
}
