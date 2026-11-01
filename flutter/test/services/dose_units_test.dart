// Task 223: регрессии порядка веток calculateDose (аудит SW-19 §4.1).
//
// До фикса ветка «мг/кг × вес ÷ мг/мл» срабатывала БЕЗ проверки
// dose_unit — даже для «мл/кг» и «МЕ/кг»:
//  - кальция борглюконат 0.75 мл/кг в/в (корова 400 кг, conc 100 мг/мл)
//    давал 3 мл вместо 300 мл (в 100× меньше);
//  - Гельминтал С 0.1 мл/кг (собака 4 кг, conc 25 мг/мл) давал
//    0.016 мл вместо пипетки 0.4 мл (в 25× меньше);
//  - «МЕ/кг ÷ мг/мл» (КОЛИСТИМ К, свинья 20 кг) давало бессмысленные
//    20 000 мл.
//
// Новая схема веток — по СОВМЕСТИМОСТИ единиц:
//  1) «мл/кг»  → объём = мл/кг × вес (концентрация не участвует);
//  2) «МЕ/кг»  → делится только на conc в МЕ/мл; иначе доза без объёма;
//  3) «мкг/кг» → делится на мг/мл через точный пересчёт 1 мг = 1000 мкг;
//  4) «мг/кг»  → как раньше (÷ мг/мл).
import 'package:flutter_test/flutter_test.dart';
import 'package:veteco/models/drug_models.dart';
import 'package:veteco/services/data_load_service.dart';

CalcDrug _drug(Map<String, dynamic> json) => CalcDrug.fromJson({
      'id': 1,
      'name': 'Тест',
      'inn': 'тест',
      'form': 'Раствор',
      'animals': <String>[],
      ...json,
    });

void main() {
  group('calculateDose: мг/кг — как раньше (якорь A фикса не ломает)', () {
    test('5 мг/кг × 10 кг ÷ 100 мг/мл = 0,5 мл', () {
      final drug = _drug(const {
        'concentration': 100.0,
        'dose_per_kg': 5.0,
        'dose_unit': 'мг/кг',
      });
      final result = DataLoadService().calculateDose(drug, 10.0);
      expect(result.volume, closeTo(0.5, 1e-9));
      expect(result.hasDosage, isTrue);
      expect(result.isFixedDose, isFalse);
    });

    test('мг/кг без концентрации — доза без объёма, как раньше', () {
      final drug = _drug(const {
        'concentration': 0,
        'dose_per_kg': 5.0,
        'dose_unit': 'мг/кг',
      });
      final result = DataLoadService().calculateDose(drug, 10.0);
      expect(result.volume, 0);
      expect(result.hasDosage, isTrue);
      expect(result.note, contains('= 50.0 мг'));
    });
  });

  group('calculateDose: мл/кг не делится на концентрацию', () {
    test('борглюконат: 0.75 мл/кг × 400 кг = 300 мл (было 3.0)', () {
      final drug = _drug(const {
        'concentration': 100.0,
        'concentration_unit': 'мг/мл',
        'dose_per_kg': 0.75,
        'dose_unit': 'мл/кг',
      });
      final result = DataLoadService().calculateDose(drug, 400.0);
      expect(result.volume, closeTo(300.0, 1e-9));
      expect(result.note, contains('0.75 мл/кг × 400.0 кг'));
    });

    test('Гельминтал С: 0.1 мл/кг × 4 кг = 0.4 мл пипетки (было 0.016)', () {
      final drug = _drug(const {
        'concentration': 25.0,
        'concentration_unit': 'мг/мл',
        'dose_per_kg': 0.1,
        'dose_unit': 'мл/кг',
      });
      final result = DataLoadService().calculateDose(drug, 4.0);
      expect(result.volume, closeTo(0.4, 1e-9));
    });

    test('мл/кг с conc=0 — прежняя ветка 2, объём тот же', () {
      final drug = _drug(const {
        'concentration': 0,
        'dose_per_kg': 0.1,
        'dose_unit': 'мл/кг',
      });
      final result = DataLoadService().calculateDose(drug, 4.0);
      expect(result.volume, closeTo(0.4, 1e-9));
    });

    test('видовая доза в мл/кг перекрывает мг/кг уровня препарата', () {
      final drug = _drug(const {
        'concentration': 25.0,
        'dose_per_kg': 2.5,
        'dose_unit': 'мг/кг',
        'animal_specific': {
          'Собаки': {
            'dose_per_kg': 0.1,
            'dose_unit': 'мл/кг',
          },
        },
      });
      final result =
          DataLoadService().calculateDose(drug, 4.0, animalName: 'Собаки');
      expect(result.volume, closeTo(0.4, 1e-9));
    });
  });

  group('calculateDose: МЕ/кг не делится на мг/мл', () {
    test('КОЛИСТИМ К: свинья 20 кг — доза без объёма (было 20 000 мл)', () {
      final drug = _drug(const {
        'concentration': 50.0,
        'concentration_unit': 'мг/мл',
        'dose_per_kg': 50000,
        'dose_unit': 'МЕ/кг',
      });
      final result = DataLoadService().calculateDose(drug, 20.0);
      expect(result.volume, 0);
      expect(result.hasDosage, isTrue);
      expect(result.note, contains('1000000 МЕ'));
      expect(result.note, contains('объём не рассчитан'));
    });

    test('МЕ/кг с концентрацией в МЕ/мл — объём считается', () {
      // Канинсулин-подобный случай: 0.5 МЕ/кг × 10 кг ÷ 40 МЕ/мл = 0.125 мл
      final drug = _drug(const {
        'concentration': 40.0,
        'concentration_unit': 'МЕ/мл',
        'dose_per_kg': 0.5,
        'dose_unit': 'МЕ/кг',
      });
      final result = DataLoadService().calculateDose(drug, 10.0);
      expect(result.volume, closeTo(0.125, 1e-9));
      expect(result.note, contains('МЕ/мл'));
    });

    test('МЕ/кг без концентрации — доза без объёма', () {
      final drug = _drug(const {
        'concentration': 0,
        'dose_per_kg': 75000,
        'dose_unit': 'МЕ/кг',
      });
      final result = DataLoadService().calculateDose(drug, 2.0);
      expect(result.volume, 0);
      expect(result.note, contains('150000 МЕ'));
    });
  });

  group('calculateDose: мкг/кг — точный пересчёт в мг (не в 1000× больше)', () {
    test('Регостенол: 0.96 мкг/кг × 500 кг ÷ 0.25 мг/мл = 1.92 мл', () {
      final drug = _drug(const {
        'concentration': 0.25,
        'concentration_unit': 'мг/мл',
        'dose_per_kg': 0.96,
        'dose_unit': 'мкг/кг',
      });
      final result = DataLoadService().calculateDose(drug, 500.0);
      expect(result.volume, closeTo(1.92, 1e-9));
      expect(result.note, contains('мкг→мг'));
    });

    test('мкг/кг без концентрации — доза в мкг без объёма', () {
      final drug = _drug(const {
        'concentration': 0,
        'dose_per_kg': 0.96,
        'dose_unit': 'мкг/кг',
      });
      final result = DataLoadService().calculateDose(drug, 500.0);
      expect(result.volume, 0);
      expect(result.note, contains('480 мкг'));
    });
  });
}
