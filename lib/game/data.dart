import 'package:flutter/material.dart';

/// Dünya ölçüleri.
const double kTile = 32;
const int kMapW = 80;
const int kMapH = 80;
const double kMapPx = kMapW * kTile;

/// Gün/gece döngüsü (saniye). 0 = 06:00.
const double kDayLength = 360;

/// Oyuncu kimlikleri.
const int kPlayer = 0;
const int kEnemy = 1;
const int kCreeps = 2;
const int kPassive = 3;

enum Difficulty { easy, normal, hard }

extension DifficultyName on Difficulty {
  String get label => switch (this) {
        Difficulty.easy => 'Kolay',
        Difficulty.normal => 'Normal',
        Difficulty.hard => 'Zor',
      };
}

enum TargetKind { none, unit, point, passive }

String fmtNum(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(((v * 10).roundToDouble() == v * 10) ? 1 : 2);
}

class AbilityType {
  const AbilityType({
    required this.id,
    required this.name,
    required this.hotkey,
    required this.desc,
    required this.icon,
    required this.color,
    required this.target,
    this.targetAlly = false,
    this.mana = const [0, 0, 0],
    this.cooldown = const [0, 0, 0],
    this.range = 0,
    this.radius = 0,
    this.v1 = const [0, 0, 0],
    this.v2 = const [0, 0, 0],
  });

  final String id;
  final String name;
  final String hotkey;
  final String desc;
  final IconData icon;
  final Color color;
  final TargetKind target;
  final bool targetAlly;
  final List<double> mana;
  final List<double> cooldown;
  final double range;
  final double radius;
  final List<double> v1;
  final List<double> v2;

  bool get passive => target == TargetKind.passive;

  String describe(int lvl) {
    final i = (lvl - 1).clamp(0, 2);
    return desc
        .replaceAll('{v1}', fmtNum(v1[i]))
        .replaceAll('{v2}', fmtNum(v2[i]));
  }
}

const Map<String, AbilityType> abilityTypes = {
  'holyLight': AbilityType(
    id: 'holyLight',
    name: 'Kutsal Işık',
    hotkey: 'Q',
    desc: 'Dost bir birimi {v1} can iyileştirir.',
    icon: Icons.wb_sunny,
    color: Color(0xFFFFE082),
    target: TargetKind.unit,
    targetAlly: true,
    mana: [65, 65, 65],
    cooldown: [5, 5, 5],
    range: 220,
    v1: [200, 400, 600],
  ),
  'stormBolt': AbilityType(
    id: 'stormBolt',
    name: 'Fırtına Çekici',
    hotkey: 'W',
    desc: 'Düşmana büyülü bir çekiç fırlatır: {v1} hasar ve {v2} sn sersemletme.',
    icon: Icons.bolt,
    color: Color(0xFF90CAF9),
    target: TargetKind.unit,
    mana: [75, 75, 75],
    cooldown: [9, 9, 9],
    range: 250,
    v1: [100, 225, 350],
    v2: [2, 2.5, 3],
  ),
  'devotion': AbilityType(
    id: 'devotion',
    name: 'Bağlılık Aurası',
    hotkey: 'E',
    desc: 'Yakındaki dost birimlere +{v1} zırh verir.',
    icon: Icons.shield,
    color: Color(0xFFFFD54F),
    target: TargetKind.passive,
    radius: 300,
    v1: [1.5, 3, 4.5],
  ),
  'blizzard': AbilityType(
    id: 'blizzard',
    name: 'Kar Fırtınası',
    hotkey: 'Q',
    desc: 'Hedef bölgeye {v2} dalga buz yağdırır; her dalga {v1} hasar verir.',
    icon: Icons.ac_unit,
    color: Color(0xFF81D4FA),
    target: TargetKind.point,
    mana: [75, 75, 75],
    cooldown: [8, 8, 8],
    range: 280,
    radius: 110,
    v1: [30, 40, 50],
    v2: [4, 5, 6],
  ),
  'waterElemental': AbilityType(
    id: 'waterElemental',
    name: 'Su Elementali',
    hotkey: 'W',
    desc: '{v1} canlı, {v2} hasarlı bir su elementali çağırır (60 sn).',
    icon: Icons.water_drop,
    color: Color(0xFF4FC3F7),
    target: TargetKind.none,
    mana: [125, 125, 125],
    cooldown: [20, 20, 20],
    v1: [525, 675, 900],
    v2: [22, 32, 42],
  ),
  'brilliance': AbilityType(
    id: 'brilliance',
    name: 'Parlaklık Aurası',
    hotkey: 'E',
    desc: 'Yakındaki dostlara saniyede +{v1} mana yenilenmesi verir.',
    icon: Icons.auto_awesome,
    color: Color(0xFFB39DDB),
    target: TargetKind.passive,
    radius: 400,
    v1: [0.75, 1.5, 2.25],
  ),
  'warStomp': AbilityType(
    id: 'warStomp',
    name: 'Savaş Kükremesi',
    hotkey: 'Q',
    desc: 'Yere vurur: yakındaki düşmanlara {v1} hasar ve {v2} sn sersemletme.',
    icon: Icons.landslide,
    color: Color(0xFFBCAAA4),
    target: TargetKind.none,
    mana: [90, 90, 90],
    cooldown: [7, 7, 7],
    radius: 140,
    v1: [25, 50, 75],
    v2: [2, 3, 4],
  ),
  'shockwave': AbilityType(
    id: 'shockwave',
    name: 'Şok Dalgası',
    hotkey: 'W',
    desc: 'Bir hat boyunca ilerleyen ve tüm düşmanlara {v1} hasar veren dalga.',
    icon: Icons.waves,
    color: Color(0xFFFFB74D),
    target: TargetKind.point,
    mana: [100, 100, 100],
    cooldown: [8, 8, 8],
    range: 400,
    radius: 50,
    v1: [75, 130, 200],
  ),
  'endurance': AbilityType(
    id: 'endurance',
    name: 'Dayanıklılık Aurası',
    hotkey: 'E',
    desc: 'Dostlara +%{v1} hareket ve +%{v2} saldırı hızı verir.',
    icon: Icons.speed,
    color: Color(0xFFFF8A65),
    target: TargetKind.passive,
    radius: 300,
    v1: [10, 20, 30],
    v2: [5, 10, 15],
  ),
  'chainLightning': AbilityType(
    id: 'chainLightning',
    name: 'Zincir Şimşek',
    hotkey: 'Q',
    desc: '{v1} hasar veren ve {v2} hedefe sıçrayan bir şimşek.',
    icon: Icons.flash_on,
    color: Color(0xFF80DEEA),
    target: TargetKind.unit,
    mana: [110, 110, 110],
    cooldown: [9, 9, 9],
    range: 260,
    v1: [85, 125, 180],
    v2: [4, 5, 6],
  ),
  'feralSpirit': AbilityType(
    id: 'feralSpirit',
    name: 'Ruh Kurtları',
    hotkey: 'W',
    desc: '{v1} canlı iki ruh kurdu çağırır (60 sn).',
    icon: Icons.pets,
    color: Color(0xFF90A4AE),
    target: TargetKind.none,
    mana: [75, 75, 75],
    cooldown: [18, 18, 18],
    v1: [250, 350, 450],
    v2: [12, 17, 22],
  ),
  'healingWave': AbilityType(
    id: 'healingWave',
    name: 'Şifa Dalgası',
    hotkey: 'E',
    desc: 'Dostu {v1} can iyileştirir ve {v2} kez başka dostlara sıçrar.',
    icon: Icons.healing,
    color: Color(0xFF81C784),
    target: TargetKind.unit,
    targetAlly: true,
    mana: [90, 90, 90],
    cooldown: [9, 9, 9],
    range: 250,
    v1: [130, 215, 300],
    v2: [3, 4, 5],
  ),
};

class UnitType {
  const UnitType(
    this.id,
    this.name, {
    this.desc = '',
    this.hotkey = '',
    this.building = false,
    this.hero = false,
    this.worker = false,
    this.summon = false,
    this.creep = false,
    this.townHall = false,
    this.altar = false,
    this.gold = 0,
    this.lumber = 0,
    this.food = 0,
    this.foodProvided = 0,
    this.buildTime = 0,
    this.hp = 100,
    this.mana = 0,
    this.armor = 0,
    this.dmgMin = 0,
    this.dmgMax = 0,
    this.cooldown = 1.5,
    this.range = 12,
    this.projSpeed = 0,
    this.projectile = '',
    this.speed = 0,
    this.sight = 260,
    this.radius = 10,
    this.size = 0,
    this.trains = const [],
    this.researches = const [],
    this.requires = const [],
    this.level = 1,
    this.bounty = 0,
    this.abilities = const [],
    this.hpPerLvl = 0,
    this.manaPerLvl = 0,
    this.dmgPerLvl = 0,
    this.armorPerLvl = 0,
    this.hpRegen = 0.25,
    this.manaRegen = 0.5,
  });

  final String id;
  final String name;
  final String desc;
  final String hotkey;
  final bool building, hero, worker, summon, creep, townHall, altar;
  final int gold, lumber, food, foodProvided;
  final double buildTime;
  final double hp, mana, armor;
  final double dmgMin, dmgMax, cooldown, range, projSpeed;
  final String projectile;
  final double speed, sight, radius;
  final int size;
  final List<String> trains, researches, requires;
  final int level, bounty;
  final List<String> abilities;
  final double hpPerLvl, manaPerLvl, dmgPerLvl, armorPerLvl;
  final double hpRegen, manaRegen;

  bool get canAttack => dmgMax > 0;
  bool get ranged => range > 40;
  bool get isMine => id == 'goldmine';
  double get acquire => building ? range + 10 : (range + 80 > 260 ? range + 80 : 260);

  /// Öldürüldüğünde kahramanlara verilen deneyim.
  int get xpValue {
    if (building) return 0;
    if (hero) return const [100, 120, 160, 220, 300, 400, 500, 600, 700, 800][(level - 1).clamp(0, 9)];
    return const [0, 25, 40, 60, 85, 115, 150, 190, 235, 285][level.clamp(0, 9)];
  }
}

const Map<String, UnitType> unitTypes = {
  // ---------------------------------------------------------------- İnsanlar
  'h_worker': UnitType('h_worker', 'İşçi',
      desc: 'Altın kazar, odun keser ve bina inşa eder.',
      hotkey: 'P', worker: true, gold: 75, food: 1, buildTime: 15,
      hp: 220, dmgMin: 5, dmgMax: 6, cooldown: 2, speed: 75, radius: 9),
  'h_footman': UnitType('h_footman', 'Piyade',
      desc: 'Kılıç ve kalkanla donanmış dayanıklı yakın dövüş askeri.',
      hotkey: 'F', gold: 135, food: 2, buildTime: 20,
      hp: 420, armor: 2, dmgMin: 12, dmgMax: 13, cooldown: 1.35, speed: 80, radius: 11),
  'h_rifleman': UnitType('h_rifleman', 'Tüfekçi',
      desc: 'Uzaktan yüksek hasar veren cüce nişancı.',
      hotkey: 'R', gold: 205, lumber: 30, food: 3, buildTime: 24,
      hp: 300, dmgMin: 19, dmgMax: 23, cooldown: 1.5, range: 165, projSpeed: 900,
      projectile: 'bullet', speed: 80, radius: 10),
  'h_knight': UnitType('h_knight', 'Şövalye',
      desc: 'Ağır zırhlı, hızlı süvari. Demirci gerektirir.',
      hotkey: 'K', gold: 245, lumber: 60, food: 4, buildTime: 35,
      hp: 800, armor: 5, dmgMin: 25, dmgMax: 31, cooldown: 1.4, speed: 105,
      radius: 14, requires: ['h_smith']),
  'h_paladin': UnitType('h_paladin', 'Paladin',
      desc: 'Kutsal savaşçı kahraman. Dostlarını iyileştirir ve korur.',
      hotkey: 'P', hero: true, gold: 425, lumber: 100, food: 5, buildTime: 35,
      hp: 650, mana: 255, armor: 4, dmgMin: 24, dmgMax: 34, cooldown: 2.1, speed: 85,
      sight: 320, radius: 13, abilities: ['holyLight', 'stormBolt', 'devotion'],
      hpPerLvl: 50, manaPerLvl: 15, dmgPerLvl: 2.5, armorPerLvl: 0.4, hpRegen: 1, manaRegen: 0.6),
  'h_archmage': UnitType('h_archmage', 'Başbüyücü',
      desc: 'Buz ve su büyülerinde usta, uzaktan saldıran büyücü kahraman.',
      hotkey: 'A', hero: true, gold: 425, lumber: 100, food: 5, buildTime: 35,
      hp: 450, mana: 285, armor: 2, dmgMin: 20, dmgMax: 26, cooldown: 2.1, range: 170,
      projSpeed: 700, projectile: 'magic', speed: 80, sight: 320, radius: 12,
      abilities: ['blizzard', 'waterElemental', 'brilliance'],
      hpPerLvl: 30, manaPerLvl: 25, dmgPerLvl: 2, armorPerLvl: 0.3, hpRegen: 0.8, manaRegen: 0.9),
  'h_waterel': UnitType('h_waterel', 'Su Elementali',
      desc: 'Çağrılmış geçici bir yaratık.',
      summon: true, hp: 525, dmgMin: 20, dmgMax: 24, cooldown: 1.5, range: 150,
      projSpeed: 600, projectile: 'water', speed: 75, radius: 12, level: 3, hpRegen: 0),
  'h_hall': UnitType('h_hall', 'Ana Bina',
      desc: 'Ana yapı. İşçi üretir, kaynaklar buraya taşınır. +12 yiyecek.',
      hotkey: 'H', building: true, townHall: true, gold: 385, lumber: 185, buildTime: 60,
      foodProvided: 12, hp: 1500, armor: 5, size: 4, sight: 360, trains: ['h_worker']),
  'h_farm': UnitType('h_farm', 'Çiftlik',
      desc: '+6 yiyecek sağlar.',
      hotkey: 'F', building: true, gold: 80, lumber: 20, buildTime: 20,
      foodProvided: 6, hp: 500, armor: 1, size: 2),
  'h_barracks': UnitType('h_barracks', 'Kışla',
      desc: 'Piyade, Tüfekçi ve Şövalye yetiştirir.',
      hotkey: 'B', building: true, gold: 160, lumber: 60, buildTime: 35,
      hp: 1200, armor: 5, size: 3, trains: ['h_footman', 'h_rifleman', 'h_knight']),
  'h_altar': UnitType('h_altar', 'Krallar Sunağı',
      desc: 'Kahraman çağırır ve ölen kahramanları diriltir.',
      hotkey: 'A', building: true, altar: true, gold: 180, lumber: 50, buildTime: 30,
      hp: 900, armor: 5, size: 3, trains: ['h_paladin', 'h_archmage']),
  'h_smith': UnitType('h_smith', 'Demirci',
      desc: 'Silah ve zırh geliştirmeleri yapar. Şövalye için gerekli.',
      hotkey: 'S', building: true, gold: 140, lumber: 60, buildTime: 30,
      hp: 1000, armor: 5, size: 3, researches: ['weapons', 'armor']),
  'h_tower': UnitType('h_tower', 'Gözcü Kulesi',
      desc: 'Yaklaşan düşmanlara ok atan savunma kulesi.',
      hotkey: 'T', building: true, gold: 110, lumber: 80, buildTime: 25,
      hp: 550, armor: 5, size: 2, dmgMin: 18, dmgMax: 22, cooldown: 1.0, range: 230,
      projSpeed: 800, projectile: 'arrow', sight: 360),

  // -------------------------------------------------------------- Orklar
  'o_worker': UnitType('o_worker', 'Köle',
      desc: 'Altın kazar, odun keser ve bina inşa eder.',
      hotkey: 'P', worker: true, gold: 75, food: 1, buildTime: 15,
      hp: 250, dmgMin: 7, dmgMax: 8, cooldown: 2, speed: 75, radius: 9),
  'o_grunt': UnitType('o_grunt', 'Savaşçı',
      desc: 'Güçlü ve dayanıklı ork piyadesi.',
      hotkey: 'G', gold: 200, food: 3, buildTime: 27,
      hp: 700, armor: 1, dmgMin: 19, dmgMax: 21, cooldown: 1.6, speed: 80, radius: 12),
  'o_headhunter': UnitType('o_headhunter', 'Mızrakçı',
      desc: 'Uzaktan mızrak fırlatan trol avcı.',
      hotkey: 'H', gold: 135, lumber: 20, food: 2, buildTime: 20,
      hp: 350, dmgMin: 23, dmgMax: 27, cooldown: 2, range: 165, projSpeed: 700,
      projectile: 'spear', speed: 80, radius: 10),
  'o_raider': UnitType('o_raider', 'Kurt Binici',
      desc: 'Kurt sırtında hızlı ork akıncısı. Savaş Değirmeni gerektirir.',
      hotkey: 'R', gold: 180, lumber: 40, food: 3, buildTime: 28,
      hp: 610, armor: 1, dmgMin: 24, dmgMax: 30, cooldown: 1.85, speed: 110,
      radius: 14, requires: ['o_mill']),
  'o_chieftain': UnitType('o_chieftain', 'Boğa Şef',
      desc: 'Yeri sarsan devasa savaşçı kahraman.',
      hotkey: 'T', hero: true, gold: 425, lumber: 100, food: 5, buildTime: 35,
      hp: 725, mana: 225, armor: 1.5, dmgMin: 26, dmgMax: 36, cooldown: 2.2, speed: 80,
      sight: 320, radius: 15, abilities: ['warStomp', 'shockwave', 'endurance'],
      hpPerLvl: 55, manaPerLvl: 13, dmgPerLvl: 2.6, armorPerLvl: 0.4, hpRegen: 1.1, manaRegen: 0.5),
  'o_farseer': UnitType('o_farseer', 'Kahin',
      desc: 'Şimşek ve ruhlara hükmeden, uzaktan saldıran büyücü kahraman.',
      hotkey: 'F', hero: true, gold: 425, lumber: 100, food: 5, buildTime: 35,
      hp: 475, mana: 270, armor: 2, dmgMin: 22, dmgMax: 28, cooldown: 2.1, range: 170,
      projSpeed: 800, projectile: 'lightning', speed: 85, sight: 320, radius: 12,
      abilities: ['chainLightning', 'feralSpirit', 'healingWave'],
      hpPerLvl: 30, manaPerLvl: 22, dmgPerLvl: 2.2, armorPerLvl: 0.3, hpRegen: 0.8, manaRegen: 0.85),
  'o_wolf': UnitType('o_wolf', 'Ruh Kurdu',
      desc: 'Çağrılmış geçici bir yaratık.',
      summon: true, hp: 250, dmgMin: 11, dmgMax: 13, cooldown: 1.3, speed: 92,
      radius: 10, level: 2, hpRegen: 0),
  'o_hall': UnitType('o_hall', 'Büyük Salon',
      desc: 'Ana yapı. Köle üretir, kaynaklar buraya taşınır. +12 yiyecek.',
      hotkey: 'H', building: true, townHall: true, gold: 385, lumber: 185, buildTime: 60,
      foodProvided: 12, hp: 1500, armor: 5, size: 4, sight: 360, trains: ['o_worker']),
  'o_burrow': UnitType('o_burrow', 'Ork Barınağı',
      desc: '+8 yiyecek sağlar.',
      hotkey: 'O', building: true, gold: 110, lumber: 30, buildTime: 22,
      foodProvided: 8, hp: 600, armor: 2, size: 2),
  'o_barracks': UnitType('o_barracks', 'Ork Kışlası',
      desc: 'Savaşçı, Mızrakçı ve Kurt Binici yetiştirir.',
      hotkey: 'B', building: true, gold: 180, lumber: 50, buildTime: 35,
      hp: 1200, armor: 5, size: 3, trains: ['o_grunt', 'o_headhunter', 'o_raider']),
  'o_altar': UnitType('o_altar', 'Fırtına Sunağı',
      desc: 'Kahraman çağırır ve ölen kahramanları diriltir.',
      hotkey: 'A', building: true, altar: true, gold: 180, lumber: 50, buildTime: 30,
      hp: 900, armor: 5, size: 3, trains: ['o_chieftain', 'o_farseer']),
  'o_mill': UnitType('o_mill', 'Savaş Değirmeni',
      desc: 'Silah ve zırh geliştirmeleri yapar. Kurt Binici için gerekli.',
      hotkey: 'W', building: true, gold: 140, lumber: 60, buildTime: 30,
      hp: 1000, armor: 5, size: 3, researches: ['weapons', 'armor']),
  'o_tower': UnitType('o_tower', 'Ork Kulesi',
      desc: 'Yaklaşan düşmanlara mızrak atan savunma kulesi.',
      hotkey: 'T', building: true, gold: 110, lumber: 80, buildTime: 25,
      hp: 500, armor: 5, size: 2, dmgMin: 17, dmgMax: 21, cooldown: 1.0, range: 230,
      projSpeed: 700, projectile: 'spear', sight: 360),

  // ----------------------------------------------------------- Tarafsızlar
  'goldmine': UnitType('goldmine', 'Altın Madeni',
      desc: 'İşçiler buradan altın çıkarır.', building: true, hp: 99999, armor: 99, size: 3, sight: 0),
  'c_gnoll': UnitType('c_gnoll', 'Gnoll Yağmacı',
      creep: true, hp: 240, armor: 1, dmgMin: 8, dmgMax: 9, cooldown: 1.6, speed: 70,
      radius: 10, level: 1, bounty: 9),
  'c_gnollArcher': UnitType('c_gnollArcher', 'Gnoll Okçu',
      creep: true, hp: 200, dmgMin: 10, dmgMax: 12, cooldown: 1.8, range: 150, projSpeed: 700,
      projectile: 'arrow', speed: 70, radius: 10, level: 1, bounty: 9),
  'c_murloc': UnitType('c_murloc', 'Balıkadam',
      creep: true, hp: 330, armor: 1, dmgMin: 12, dmgMax: 14, cooldown: 1.5, speed: 75,
      radius: 10, level: 2, bounty: 12),
  'c_troll': UnitType('c_troll', 'Orman Trolü',
      creep: true, hp: 420, armor: 1, dmgMin: 16, dmgMax: 19, cooldown: 1.8, range: 150,
      projSpeed: 700, projectile: 'spear', speed: 75, radius: 11, level: 3, bounty: 18),
  'c_ogre': UnitType('c_ogre', 'Ogre',
      creep: true, hp: 850, armor: 2, dmgMin: 26, dmgMax: 31, cooldown: 1.8, speed: 72,
      radius: 15, level: 4, bounty: 25),
  'c_golem': UnitType('c_golem', 'Kaya Golemi',
      creep: true, hp: 1100, armor: 4, dmgMin: 30, dmgMax: 36, cooldown: 2, speed: 65,
      radius: 15, level: 5, bounty: 30),
  'c_dragon': UnitType('c_dragon', 'Kızıl Ejderha',
      creep: true, hp: 1700, armor: 3, dmgMin: 48, dmgMax: 58, cooldown: 2, range: 160,
      projSpeed: 600, projectile: 'fire', speed: 80, radius: 20, level: 7, bounty: 60),
};

UnitType ut(String id) => unitTypes[id]!;

class Faction {
  const Faction({
    required this.id,
    required this.name,
    required this.hall,
    required this.farm,
    required this.barracks,
    required this.altar,
    required this.smith,
    required this.tower,
    required this.worker,
    required this.heroes,
    required this.melee,
    required this.ranged,
    required this.cavalry,
    required this.heroNames,
  });

  final String id, name;
  final String hall, farm, barracks, altar, smith, tower, worker;
  final List<String> heroes;
  final String melee, ranged, cavalry;
  final Map<String, List<String>> heroNames;

  List<String> get buildings => [hall, farm, barracks, altar, smith, tower];
}

const Faction humanFaction = Faction(
  id: 'human',
  name: 'İnsan İttifakı',
  hall: 'h_hall',
  farm: 'h_farm',
  barracks: 'h_barracks',
  altar: 'h_altar',
  smith: 'h_smith',
  tower: 'h_tower',
  worker: 'h_worker',
  heroes: ['h_paladin', 'h_archmage'],
  melee: 'h_footman',
  ranged: 'h_rifleman',
  cavalry: 'h_knight',
  heroNames: {
    'h_paladin': ['Sir Kaan', 'Sir Alparslan', 'Sir Toprak', 'Sir Aybars'],
    'h_archmage': ['Bilge Ozan', 'Akbaş Demir', 'Yıldız Hakan'],
  },
);

const Faction orcFaction = Faction(
  id: 'orc',
  name: 'Ork Ordusu',
  hall: 'o_hall',
  farm: 'o_burrow',
  barracks: 'o_barracks',
  altar: 'o_altar',
  smith: 'o_mill',
  tower: 'o_tower',
  worker: 'o_worker',
  heroes: ['o_chieftain', 'o_farseer'],
  melee: 'o_grunt',
  ranged: 'o_headhunter',
  cavalry: 'o_raider',
  heroNames: {
    'o_chieftain': ['Kara Boğa', 'Tunç Boynuz', 'Gök Toynak'],
    'o_farseer': ['Bozkurt Kam', 'Göksel Kurt', 'Ulu Tengri'],
  },
);

class UpgradeType {
  const UpgradeType({
    required this.id,
    required this.name,
    required this.desc,
    required this.icon,
    required this.hotkey,
    required this.gold,
    required this.lumber,
    required this.time,
  });

  final String id, name, desc, hotkey;
  final IconData icon;
  final List<int> gold, lumber;
  final List<double> time;
  int get maxLevel => gold.length;
}

const Map<String, UpgradeType> upgradeTypes = {
  'weapons': UpgradeType(
    id: 'weapons',
    name: 'Silah Geliştirme',
    desc: 'Askeri birimlerin saldırısına seviye başına +2 hasar.',
    icon: Icons.gavel,
    hotkey: 'S',
    gold: [100, 175],
    lumber: [50, 125],
    time: [40, 55],
  ),
  'armor': UpgradeType(
    id: 'armor',
    name: 'Zırh Geliştirme',
    desc: 'Askeri birimlerin zırhına seviye başına +2.',
    icon: Icons.security,
    hotkey: 'Z',
    gold: [100, 175],
    lumber: [75, 150],
    time: [40, 55],
  ),
};

class ItemType {
  const ItemType({
    required this.id,
    required this.name,
    required this.desc,
    required this.icon,
    required this.color,
    this.consumable = false,
    this.onPickup = false,
    this.dmg = 0,
    this.armor = 0,
    this.hp = 0,
    this.speed = 0,
    this.healHp = 0,
    this.healMana = 0,
    this.xp = 0,
  });

  final String id, name, desc;
  final IconData icon;
  final Color color;
  final bool consumable, onPickup;
  final double dmg, armor, hp, speed, healHp, healMana;
  final int xp;
}

const Map<String, ItemType> itemTypes = {
  'potionHeal': ItemType(
      id: 'potionHeal', name: 'Şifa İksiri', desc: 'Kullanınca 250 can yeniler.',
      icon: Icons.local_drink, color: Color(0xFFE53935), consumable: true, healHp: 250),
  'potionMana': ItemType(
      id: 'potionMana', name: 'Mana İksiri', desc: 'Kullanınca 150 mana yeniler.',
      icon: Icons.local_drink, color: Color(0xFF1E88E5), consumable: true, healMana: 150),
  'claws': ItemType(
      id: 'claws', name: 'Saldırı Pençeleri', desc: '+6 saldırı hasarı.',
      icon: Icons.content_cut, color: Color(0xFFFF9800), dmg: 6),
  'ring': ItemType(
      id: 'ring', name: 'Koruma Yüzüğü', desc: '+3 zırh.',
      icon: Icons.radio_button_checked, color: Color(0xFFB0BEC5), armor: 3),
  'boots': ItemType(
      id: 'boots', name: 'Hız Çizmeleri', desc: '+40 hareket hızı.',
      icon: Icons.hiking, color: Color(0xFF8D6E63), speed: 40),
  'periapt': ItemType(
      id: 'periapt', name: 'Sağlık Muskası', desc: '+200 maksimum can.',
      icon: Icons.favorite, color: Color(0xFFEC407A), hp: 200),
  'tome': ItemType(
      id: 'tome', name: 'Bilgi Kitabı', desc: 'Alındığında +300 deneyim kazandırır.',
      icon: Icons.menu_book, color: Color(0xFFAB47BC), onPickup: true, xp: 300),
};

/// Deneyim eşikleri: [L] = L+1. seviyeye ulaşmak için toplam deneyim.
const List<int> xpForLevel = [0, 200, 500, 900, 1400, 2000, 2700, 3500, 4400, 5400];
const int kMaxHeroLevel = 10;
const int kMaxHeroes = 2;

// --------------------------------------------------------------- Harita düzeni

class StartLoc {
  const StartLoc(this.hallX, this.hallY, this.mineX, this.mineY);
  final int hallX, hallY, mineX, mineY;
}

const List<StartLoc> startLocs = [
  StartLoc(12, 64, 5, 66),
  StartLoc(64, 12, 72, 11),
];

/// Genişleme madenleri (sol üst köşe karoları).
const List<List<int>> expansionMines = [
  [8, 8],
  [69, 69],
];

class CampDef {
  const CampDef(this.x, this.y, this.creeps, this.drops);
  final double x, y; // karo koordinatı (merkez)
  final List<String> creeps;
  final List<String> drops;
}

const List<CampDef> campDefs = [
  CampDef(25, 57, ['c_gnoll', 'c_gnoll', 'c_gnollArcher'], ['potionHeal']),
  CampDef(54, 22, ['c_gnoll', 'c_gnoll', 'c_gnollArcher'], ['potionHeal']),
  CampDef(31, 33, ['c_murloc', 'c_murloc', 'c_murloc'], ['potionMana']),
  CampDef(48, 46, ['c_murloc', 'c_murloc', 'c_murloc'], ['potionMana']),
  CampDef(14.5, 14.5, ['c_troll', 'c_troll', 'c_ogre'], ['claws']),
  CampDef(64.5, 64.5, ['c_troll', 'c_troll', 'c_ogre'], ['ring']),
  CampDef(12, 40, ['c_golem', 'c_troll'], ['boots']),
  CampDef(67, 39, ['c_golem', 'c_troll'], ['boots']),
  CampDef(39.5, 39.5, ['c_dragon', 'c_ogre', 'c_ogre'], ['periapt', 'tome']),
];

const List<Color> playerColors = [
  Color(0xFF2F6FE8), // mavi
  Color(0xFFD9322B), // kırmızı
  Color(0xFF9E9E5A), // tarafsız
  Color(0xFFFFD54F), // pasif
];
