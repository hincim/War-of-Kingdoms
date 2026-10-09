# Krallıklar Savaşı

Kahramanların ve orduların çarpıştığı, Flutter ile yazılmış gerçek zamanlı strateji oyunu. Tüm grafikler
kodla (prosedürel olarak) çizilir; harici görsel ya da paket gerekmez.

## Çalıştırma

```bash
flutter run -d macos     # masaüstü (önerilen)
flutter run -d chrome    # tarayıcı
```

Oyun fare ve klavye için tasarlanmıştır. Dokunmatik ekranda temel kontroller çalışır
(dokun: seç / emir ver, sürükle: kamerayı kaydır).

## Oyun

- **İki taraf:** İnsan İttifakı ve Ork Ordusu. Rakip bilgisayar diğer tarafı oynar.
- **Kaynaklar:** İşçiler altın madeninden altın, ağaçlardan odun toplar. Çiftlik / Barınak yiyecek sınırını artırır.
- **Yapılar:** Ana Bina, Çiftlik, Kışla, Sunak, Demirci / Savaş Değirmeni, Gözcü Kulesi.
- **Birimler:** Piyade, Tüfekçi, Şövalye / Savaşçı, Mızrakçı, Kurt Binici.
- **Kahramanlar:** Paladin, Başbüyücü / Boğa Şef, Kahin. Seviye atlar (en fazla 10), üçer yetenek
  öğrenir, 6 yuvalı envanter taşır. Ölen kahraman sunakta diriltilir.
- **Tarafsız yaratıklar:** Haritadaki kamplar deneyim, altın ve eşya (iksir, yüzük, çizme, kitap…) verir.
- **Sis ve gece:** Görülmemiş alanlar karanlıktır; gece görüş mesafesi azalır.
- **Yapay zekâ:** Ekonomi kurar, kamp temizler, genişler ve dalgalar halinde saldırır (Kolay / Normal / Zor).
- **Amaç:** Düşmanın tüm yapılarını yıkmak.

## Kontroller

| Girdi | İşlev |
| --- | --- |
| Sol tık / sürükle | Seç / kutu seçimi (Shift: ekle, çift tık: aynı türdekiler) |
| Sağ tık | Akıllı emir: hareket, saldırı, toplama, eşya alma, toplanma noktası |
| A, S, H, M | Saldır, dur, pozisyonu koru, hareket |
| B, G | İnşa menüsü, topla (işçi) |
| Q, W, E / O | Kahraman yetenekleri / yetenek öğren |
| Ctrl+1–9, 1–9 | Kontrol grubu ata / seç (iki kez: kamerayı götür) |
| F1, F2, F8 | Kahramanlar, boştaki işçi |
| Ok tuşları, ekran kenarı, orta tuş, iki parmak | Kamera |
| Tekerlek | Yakınlaştır |
| Boşluk | Son saldırı uyarısına git |
| Alt | Tüm can çubukları |
| Esc / F10 | İptal / menü |

## Kod yapısı

```
lib/
  main.dart               ana menü
  game/data.dart          birim, yapı, yetenek, eşya ve harita tanımları
  game/map.dart           harita üretimi ve A* yol bulma
  game/entities.dart      birim, oyuncu, mermi ve efekt sınıfları
  game/game.dart          simülasyon: emirler, savaş, toplama, inşa, yetenekler, sis
  game/ai.dart            bilgisayar rakibi
  render/sprites.dart     prosedürel çizimler
  render/world_painter.dart  dünya çizimi (arazi önbelleği, sis, efektler)
  ui/controller.dart      seçim, komut kartı, kısayollar
  ui/hud.dart             üst çubuk, mini harita, bilgi paneli, komut kartı
  ui/game_screen.dart     oyun döngüsü ve girdi
test/
  sim_test.dart           YZ–YZ maçları (harita simetrisi, ekonomi, kazanan)
  controls_test.dart      fare/klavye ile oynanış
  ui_fuzz_test.dart       komut kartı bulanık testi
```

```bash
flutter test
```
