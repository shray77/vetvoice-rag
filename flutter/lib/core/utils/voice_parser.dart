import 'package:flutter/services.dart';

/// Number words to digit mapping for Russian voice input
const Map<String, int> _numberWords = {
  'ноль': 0, 'нуль': 0,
  'один': 1, 'одна': 1, 'одно': 1,
  'два': 2, 'две': 2,
  'три': 3,
  'четыре': 4,
  'пять': 5,
  'шесть': 6,
  'семь': 7,
  'восемь': 8,
  'девять': 9,
  'десять': 10,
  'одиннадцать': 11,
  'двенадцать': 12,
  'тринадцать': 13,
  'четырнадцать': 14,
  'пятнадцать': 15,
  'шестнадцать': 16,
  'семнадцать': 17,
  'восемнадцать': 18,
  'девятнадцать': 19,
  'двадцать': 20,
  'тридцать': 30,
  'сорок': 40,
  'пятьдесят': 50,
  'шестьдесят': 60,
  'семьдесят': 70,
  'восемьдесят': 80,
  'девяносто': 90,
  'сто': 100,
  'двести': 200,
  'триста': 300,
  'четыреста': 400,
  'пятьсот': 500,
  'шестьсот': 600,
  'семьсот': 700,
  'восемьсот': 800,
  'девятьсот': 900,
  'тысяча': 1000,
};

/// Animal name aliases for voice recognition
const Map<String, String> animalAliases = {
  'крс': 'КРС', 'корова': 'КРС', 'коровы': 'КРС', 'бык': 'КРС',
  'коров': 'КРС', 'скот': 'КРС', 'крупный рогатый скот': 'КРС',
  'мрс': 'МРС', 'овца': 'МРС', 'овцы': 'МРС', 'баран': 'МРС',
  'овец': 'МРС', 'мелкий рогатый скот': 'МРС', 'коза': 'МРС', 'козы': 'МРС',
  'свинья': 'Свиньи', 'свиньи': 'Свиньи', 'хряк': 'Свиньи', 'свиней': 'Свиньи',
  'поросенок': 'Свиньи', 'поросёнок': 'Свиньи', 'свинину': 'Свиньи',
  'лошадь': 'Лошади', 'лошади': 'Лошади', 'конь': 'Лошади', 'жеребец': 'Лошади',
  'собака': 'Собаки', 'собаки': 'Собаки', 'пес': 'Собаки', 'щенок': 'Собаки',
  'кошка': 'Кошки', 'кошки': 'Кошки', 'кот': 'Кошки', 'котенок': 'Кошки', 'котёнок': 'Кошки',
  'курица': 'Птица', 'птица': 'Птица', 'птицы': 'Птица', 'куры': 'Птица',
  'петух': 'Птица', 'цыпленок': 'Птица', 'цыплёнок': 'Птица', 'бройлер': 'Птица',
  'кролик': 'Кролики', 'кролики': 'Кролики', 'кроликов': 'Кролики',
  'рыба': 'Рыбы', 'рыбы': 'Рыбы', 'карп': 'Рыбы', 'форель': 'Рыбы',
  'пчела': 'Пчелы', 'пчелы': 'Пчелы', 'пчёл': 'Пчелы', 'пчел': 'Пчелы',
  'улей': 'Пчелы',
};

/// Parse weight from voice text
double? parseWeight(String text) {
  // Try direct number extraction first
  final numberRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:кг|килограмм|килограммов|kg)?');
  final match = numberRegex.firstMatch(text.toLowerCase());
  if (match != null) {
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  // Try Russian number words
  int total = 0;
  int current = 0;
  final words = text.toLowerCase().split(RegExp(r'\s+'));

  for (final word in words) {
    if (_numberWords.containsKey(word)) {
      final value = _numberWords[word]!;
      if (value >= 100) {
        current += value;
      } else if (value == 1000) {
        current = (current == 0 ? 1 : current) * 1000;
      } else {
        current += value;
      }
    }
  }

  total = current;
  return total > 0 ? total.toDouble() : null;
}

/// Parse animal from voice text
String? parseAnimal(String text) {
  final lower = text.toLowerCase();
  for (final entry in animalAliases.entries) {
    if (lower.contains(entry.key)) {
      return entry.value;
    }
  }
  return null;
}

/// Haptic feedback helpers
class HapticHelper {
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();
  static void selection() => HapticFeedback.selectionClick();
}
