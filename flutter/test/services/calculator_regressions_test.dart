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
}
