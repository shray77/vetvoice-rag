// Task 192: отображение фиксированных доз (МЕ-препараты).
//
// До фикса: fixed_dose-Map печатался в карточку через toString() —
// «{Собаки: 5-10 МЕ (0,5-1 мл)…, Кошки: 3-5 МЕ…}» (дамп всех видов,
// фигурные скобки), пустой Map {} показывался как «Фиксированная
// доза: {}» и блокировал расчёт по мг/кг.
import 'package:flutter_test/flutter_test.dart';
import 'package:veteco/models/drug_models.dart';
import 'package:veteco/services/data_load_service.dart';

void main() {
  group('DataLoadService.fixedDoseTextFor', () {
    test('Map: выбирает дозу выбранного вида (окситоцин, МЕ)', () {
      const fd = {
        'Собаки': '5-10 МЕ (0,5-1 мл) на животное в/м',
        'Кошки': '3-5 МЕ (0,3-0,5 мл) на животное в/м',
      };
      expect(
        DataLoadService.fixedDoseTextFor(fd, 'Кошки'),
        '3-5 МЕ (0,3-0,5 мл) на животное в/м',
      );
    });

    test('Map: вид без учёта регистра', () {
      const fd = {'Собаки': '5-10 МЕ', 'Кошки': '3-5 МЕ'};
      expect(DataLoadService.fixedDoseTextFor(fd, 'КОШКИ'), '3-5 МЕ');
    });

    test('Map: без вида — построчный список, без map-дампа', () {
      const fd = {'Собаки': '5-10 МЕ', 'Кошки': '3-5 МЕ'};
      final text = DataLoadService.fixedDoseTextFor(fd, null);
      expect(text, 'Собаки: 5-10 МЕ\nКошки: 3-5 МЕ');
      expect(text!.contains('{'), isFalse);
      expect(text.contains('}'), isFalse);
    });

    test('Map: вид не найден — построчный список всех', () {
      const fd = {'КРС': '30-50 МЕ (3-5 мл) на животное в/м'};
      expect(
        DataLoadService.fixedDoseTextFor(fd, 'Кошки'),
        'КРС: 30-50 МЕ (3-5 мл) на животное в/м',
      );
    });

    test('Пустой Map {} — фиксированной дозы нет (null)', () {
      expect(DataLoadService.fixedDoseTextFor({}, 'Собаки'), isNull);
      expect(DataLoadService.fixedDoseTextFor({}, null), isNull);
    });

    test('Map с пустыми значениями — null, не мусор', () {
      expect(DataLoadService.fixedDoseTextFor({'Собаки': '  '}, null), isNull);
    });

    test('null и пустая строка — null', () {
      expect(DataLoadService.fixedDoseTextFor(null, 'Собаки'), isNull);
      expect(DataLoadService.fixedDoseTextFor('', null), isNull);
      expect(DataLoadService.fixedDoseTextFor('  ', null), isNull);
    });

    test('Строка — как есть', () {
      expect(
        DataLoadService.fixedDoseTextFor('1 доза (0,5 мл) подкожно', null),
        '1 доза (0,5 мл) подкожно',
      );
    });
  });

  group('calculateDose: fixed_dose', () {
    test('окситоцин для кошки — МЕ-текст вида, не map-дамп', () {
      final drug = CalcDrug.fromJson(const {
        'id': 323,
        'name': 'Окситоцин',
        'inn': 'окситоцин',
        'form': 'Раствор для инъекций',
        'concentration': '5 МЕ, 10 МЕ',
        'concentration_unit': 'МЕ/мл',
        'unit': 'мл',
        'dose_per_kg': 0,
        'dose_unit': 'fixed',
        'animals': ['Собаки', 'Кошки'],
        'calculator_applicable': false,
        'fixed_dose': {
          'Собаки': '5-10 МЕ (0,5-1 мл) на животное в/м',
          'Кошки': '3-5 МЕ (0,3-0,5 мл) на животное в/м',
          'КРС': '30-50 МЕ (3-5 мл) на животное в/м',
        },
      });
      final result =
          DataLoadService().calculateDose(drug, 4.0, animalName: 'Кошки');
      expect(result.isFixedDose, isTrue);
      expect(result.fixedDoseText, '3-5 МЕ (0,3-0,5 мл) на животное в/м');
      expect(result.fixedDoseText.contains('{'), isFalse);
      expect(result.fixedDoseText.contains('Собаки'), isFalse);
    });

    test('пустой fixed_dose {} — расчёт по мг/кг, не «{}»', () {
      final drug = CalcDrug.fromJson(const {
        'id': 1,
        'name': 'Тест',
        'inn': 'тест',
        'form': 'Раствор',
        'concentration': 100.0,
        'dose_per_kg': 5.0,
        'dose_min': 3.0,
        'dose_max': 7.0,
        'animals': ['Собаки'],
        'fixed_dose': {},
      });
      final result = DataLoadService().calculateDose(drug, 10.0);
      expect(result.isFixedDose, isFalse);
      expect(result.fixedDoseText, '');
      // 5 мг/кг × 10 кг ÷ 100 мг/мл = 0,5 мл
      expect(result.volume, closeTo(0.5, 1e-9));
      expect(result.hasDosage, isTrue);
    });
  });
}
