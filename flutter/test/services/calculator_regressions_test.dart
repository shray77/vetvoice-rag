// Task 194: регрессии полевого репорта по калькулятору ветэко.
//
// 1) «Окситоцин в базе не найден»: жёсткий фильтр
//    calculator_applicable=false прятал ~1034 препарата с реальными
//    дозами (вакцины, МЕ-препараты). Теперь прячутся только записи
//    без фиксированной дозы И без мг/кг.
// 2) «2 кг бык»: вес без диапазона, визард прыгал дальше на любой
//    цифре. Теперь weightError + isWeightValid гейтят шаг.
// 3) «Ни пол, ни возраст»: состояние пациента поднимает релевантные
//    противопоказания наверх (структурные флаги contraindications).
// 4) RegistryDrug с animals:[] = «вид не указан», не «ни для кого».
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:veteco/models/drug_models.dart';
import 'package:veteco/providers/vet_provider.dart';
import 'package:veteco/services/data_load_service.dart';

CalcDrug _oxytocinLike() => CalcDrug.fromJson(const {
      'id': 323,
      'name': 'Окситоцин',
      'inn': 'окситоцин',
      'form': 'Раствор для инъекций',
      'concentration': '5 МЕ, 10 МЕ',
      'concentration_unit': 'МЕ/мл',
      'dose_per_kg': 0,
      'dose_unit': 'fixed',
      'animals': ['Собаки', 'Кошки', 'КРС'],
      'fixed_dose': {
        'Собаки': '5-10 МЕ (0,5-1 мл) на животное в/м',
        'Кошки': '3-5 МЕ (0,3-0,5 мл) на животное в/м',
        'КРС': '30-50 МЕ (3-5 мл) на животное в/м',
      },
      'calculator_applicable': false,
      'contraindications': {
        'pregnancy': true,
        'lactation': true,
        'young': false,
        'warnings': ['Противопоказан беременным животным.'],
      },
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // VetProvider асинхронно ходит в shared_preferences (история/избранное:
  // _loadHistoryAndFavorites в конструкторе, _saveHistory при selectDrug
  // с весом). Без мока канал плагина рвётся MissingPluginException, причём
  // ошибка прилетает ПОСЛЕ завершения теста («failed after completed»)
  // и валит прогоны regen/CI. Паттерн golden_all_screens_test.
  SharedPreferences.setMockInitialValues({});

  group('searchDrugs — фиксированные дозы не прячутся', () {
    test('окситоцин (calculator_applicable=false + fixed_dose) находится', () {
      final svc = DataLoadService();
      svc.debugSetDrugs(calcDrugs: [_oxytocinLike()]);
      final found = svc.searchDrugs('окситоцин');
      expect(found, isNotEmpty);
      expect((found.first as CalcDrug).name, 'Окситоцин');
    });

    test('запись без доз вовсе — по-прежнему скрыта', () {
      final useless = CalcDrug.fromJson(const {
        'id': 999,
        'name': 'Ошейник Больфо',
        'inn': 'фипронил',
        'dose_per_kg': 0,
        'fixed_dose': {},
        'calculator_applicable': false,
      });
      final svc = DataLoadService();
      svc.debugSetDrugs(calcDrugs: [useless]);
      expect(svc.searchDrugs('ольфо'), isEmpty);
    });

    test('животный фильтр не роняет поиск по виду из animals[]', () {
      final svc = DataLoadService();
      svc.debugSetDrugs(calcDrugs: [_oxytocinLike()]);
      final found = svc.searchDrugs('окситоцин', animalFilter: 'КРС');
      expect(found, hasLength(1));
    });
  });

  group('RegistryDrug.isForAnimal — пустой animals = вид не указан', () {
    test('animals:[] находится для любого вида', () {
      final reg = RegistryDrug.fromJson(const {
        'id': 1418,
        'trade_name': 'Окситоцин',
        'inn': 'окситоцин',
        'animals': [],
      });
      expect(reg.isForAnimal('КРС'), isTrue);
      expect(reg.isForAnimal('Собаки'), isTrue);
    });

    test('животный фильтр с реестровой записью без вида', () {
      final reg = RegistryDrug.fromJson(const {
        'id': 1418,
        'trade_name': 'Окситоцин',
        'inn': 'окситоцин',
        'animals': [],
      });
      final svc = DataLoadService();
      svc.debugSetDrugs(registryDrugs: [reg]);
      expect(svc.searchDrugs('окситоцин', animalFilter: 'Лошади'), isNotEmpty);
    });
  });

  group('weightError — «2 кг бык» ловится', () {
    late VetProvider p;
    late Animal cattle;
    setUp(() {
      p = VetProvider();
      cattle = Animal.fromJson(const {
        'id': 'cattle',
        'name': 'КРС',
        'icon': 'cattle',
        'min_weight': 30,
        'max_weight': 1500,
      });
    });

    test('вес в диапазоне — ошибки нет, шаг открыт', () {
      p.selectAnimal(cattle);
      p.setWeight(500);
      expect(p.weightError, isNull);
      expect(p.isWeightValid, isTrue);
    });

    test('2 кг для КРС — ошибка, шаг закрыт (регрессия репорта)', () {
      p.selectAnimal(cattle);
      p.setWeight(2);
      expect(p.weightError, contains('Вне диапазона'));
      expect(p.isWeightValid, isFalse);
    });

    test('вес выше максимума тоже ловится', () {
      p.selectAnimal(cattle);
      p.setWeight(9000);
      expect(p.isWeightValid, isFalse);
    });

    test('вес без вида не валидируется (нет диапазона)', () {
      p.setWeight(2);
      expect(p.weightError, isNull);
    });
  });

  group('состояние пациента — противопоказания поднимаются', () {
    VetProvider readyProvider() {
      final p = VetProvider();
      p.selectAnimal(Animal.fromJson(const {
        'id': 'cattle',
        'name': 'КРС',
        'icon': 'cattle',
        'min_weight': 30,
        'max_weight': 1500,
      }));
      p.setWeight(500);
      p.selectDrug(_oxytocinLike());
      return p;
    }

    test('беременность + препарат с pregnancy:true → алерт наверху', () {
      final p = readyProvider();
      p.togglePregnancy();
      final result = p.result;
      expect(result.contraindications, isNotEmpty);
      expect(result.contraindications.first, contains('БЕРЕМЕННОСТЬ'));
    });

    test('без состояния — текст противопоказаний как был', () {
      final p = readyProvider();
      final result = p.result;
      expect(result.contraindications, isNotEmpty);
      expect(result.contraindications.first, isNot(contains('БЕРЕМЕННОСТЬ')));
    });

    test('молодое животное у окситоцина (young:false) — тишина', () {
      final p = readyProvider();
      p.setPatientAge('young');
      expect(p.result.contraindications.first, isNot(contains('МОЛОДОЕ')));
    });

    test('смена вида сбрасывает состояние пациента', () {
      final p = VetProvider();
      p.selectDrug(_oxytocinLike());
      p.togglePregnancy();
      expect(p.patientPregnant, isTrue);
      p.selectAnimal(Animal.fromJson(const {
        'id': 'dog',
        'name': 'Собаки',
        'icon': 'dog',
        'min_weight': 1,
        'max_weight': 100,
      }));
      expect(p.patientPregnant, isFalse);
    });
  });

  // Task 224 (вариант А): мультиконцентрационные препараты — расчёт
  // по выбранной фасовке. Синтетический «Флексопрофен 2,5/5/10%»:
  // conc-дефолт 50 (5%), фасовки 25/50/100 мг/мл, доза 3 мг/кг, КРС 500 кг.
  // Объём = 3 × 500 ÷ conc: 30 мл (5%), 15 мл (10%), 60 мл (2,5%).
  group('Task 224 — выбор фасовки флакона', () {
    CalcDrug flexoprofen() => CalcDrug.fromJson(const {
          'id': 1618,
          'name': 'Флексопрофен® 2,5%, 5% и 10%',
          'inn': 'кетопрофен',
          'form': 'Раствор для инъекций',
          'concentration': 50.0,
          'concentration_unit': 'мг/мл',
          'dose_per_kg': 3,
          'dose_unit': 'мг/кг',
          'animals': ['КРС'],
          'concentration_variants': [
            {'label': '2,5%', 'concentration': 25.0},
            {'label': '5%', 'concentration': 50.0},
            {'label': '10%', 'concentration': 100.0},
          ],
        });

    VetProvider readyProvider() {
      final p = VetProvider();
      p.selectAnimal(Animal.fromJson(const {
        'id': 'cattle',
        'name': 'КРС',
        'icon': 'cattle',
        'min_weight': 30,
        'max_weight': 1500,
      }));
      p.setWeight(500);
      p.selectDrug(flexoprofen());
      return p;
    }

    test('варианты парсятся из concentration_variants', () {
      final d = flexoprofen();
      expect(d.concentrationVariants, hasLength(3));
      expect(d.concentrationVariants[0].label, '2,5%');
      expect(d.concentrationVariants[2].concentration, 100.0);
    });

    test('без выбора — дефолтная фасовка (30 мл на 5%)', () {
      final p = readyProvider();
      expect(p.selectedConcentration, isNull); // дефолт: 5% = conc записи
      expect(p.result.volume, closeTo(30.0, 0.001));
      expect(p.result.concentration, 50.0);
    });

    test('выбор фасовки 10% пересчитывает объём вдвое меньше', () {
      final p = readyProvider();
      p.selectConcentration(2); // 10% = 100 мг/мл
      expect(p.selectedConcentration, 100.0);
      expect(p.result.volume, closeTo(15.0, 0.001));
      expect(p.result.concentration, 100.0);
      expect(p.result.note, contains('100'));
    });

    test('выбор фасовки 2,5% — объём вчетверо больше дефолта', () {
      final p = readyProvider();
      p.selectConcentration(0); // 2,5% = 25 мг/мл
      expect(p.result.volume, closeTo(60.0, 0.001));
    });

    test('смена препарата сбрасывает выбор фасовки', () {
      final p = readyProvider();
      p.selectConcentration(2);
      expect(p.selectedConcentrationIndex, 2);
      p.selectDrug(flexoprofen());
      expect(p.selectedConcentrationIndex, 0);
      expect(p.result.volume, closeTo(30.0, 0.001));
    });

    test('одноконцентрационный препарат — селектора нет, override нет', () {
      final p = VetProvider();
      p.selectAnimal(Animal.fromJson(const {
        'id': 'cattle',
        'name': 'КРС',
        'icon': 'cattle',
        'min_weight': 30,
        'max_weight': 1500,
      }));
      p.setWeight(500);
      p.selectDrug(CalcDrug.fromJson(const {
        'id': 1978,
        'name': 'Фуросемид 5%',
        'inn': 'фуросемид',
        'concentration': 50.0,
        'concentration_unit': 'мг/мл',
        'dose_per_kg': 2,
        'dose_unit': 'мг/кг',
        'animals': ['Собаки'],
      }));
      expect(p.concentrationVariants, isEmpty);
      expect(p.selectedConcentration, isNull);
      // 2 мг/кг × 500 кг — животное не из списка, но расчёт по общим полям
      expect(p.result.volume, closeTo(20.0, 0.001));
    });
  });
}
