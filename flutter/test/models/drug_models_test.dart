import 'package:flutter_test/flutter_test.dart';
import 'package:veteco/models/drug_models.dart';

void main() {
  group('CalcDrug', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 1,
        'name': 'Энрофлоксацин',
        'inn': 'энрофлоксацин',
        'form': 'Раствор для инъекций',
        'form_type': 'injection',
        'concentration': 100.0,
        'concentration_unit': 'мг/мл',
        'unit': 'мл',
        'dose_per_kg': 5.0,
        'dose_min': 4.0,
        'dose_max': 6.0,
        'dose_unit': 'мг/кг',
        'animals': ['Собаки', 'Кошки'],
        'method': 'Внутримышечно',
        'frequency': '1 раз в день',
        'course_days': '5-7 дней',
        'withdrawal_days': 14,
        'calculator_applicable': true,
        'contraindications': 'Не применять щенкам',
        'side_effects': ['Тошнота', 'Диарея'],
        'category': 'Антибактериальные',
        'indications': 'Бактериальные инфекции',
      };

      final drug = CalcDrug.fromJson(json);

      expect(drug.id, 1);
      expect(drug.name, 'Энрофлоксацин');
      expect(drug.inn, 'энрофлоксацин');
      expect(drug.concentration, 100.0);
      expect(drug.dosePerKg, 5.0);
      expect(drug.animals, ['Собаки', 'Кошки']);
      expect(drug.withdrawalDays, 14);
      expect(drug.calculatorApplicable, true);
      expect(drug.sideEffects, ['Тошнота', 'Диарея']);
    });

    test('isForAnimal matches case-insensitive', () {
      final drug = CalcDrug(
        id: 1, name: 'Test', inn: '', form: '',
        animals: ['Собаки', 'Кошки'],
      );
      expect(drug.isForAnimal('собаки'), true);
      expect(drug.isForAnimal('СОБАКИ'), true);
      expect(drug.isForAnimal('Коровы'), false);
    });

    test('displayName removes ® symbol', () {
      final drug = CalcDrug(id: 1, name: 'Мариния®', inn: '', form: '', animals: []);
      expect(drug.displayName, 'Мариния');
    });

    test('_parseDouble handles string numbers with units', () {
      final json = {
        'id': 1, 'name': 'Test', 'inn': '', 'form': '',
        'animals': [],
        'concentration': '100 мг/мл',
        'dose_per_kg': '5.5',
      };
      final drug = CalcDrug.fromJson(json);
      expect(drug.concentration, 100.0);
      expect(drug.dosePerKg, 5.5);
    });
  });

  group('Disease', () {
    test('fromJson parses contagious disease', () {
      final json = {
        'id': 1,
        'name': 'Ящур',
        'code': 'FMD',
        'category': 'particularly_dangerous',
        'animals': ['КРС', 'МРС', 'Свиньи'],
      };
      final d = Disease.fromJson(json, isContagious: true);
      expect(d.id, 1);
      expect(d.name, 'Ящур');
      expect(d.code, 'FMD');
      expect(d.isContagious, true);
      expect(d.categoryRu, 'Особо опасные');
    });

    test('fromJson parses non-contagious disease', () {
      final json = {
        'id': 201,
        'name': 'Кетоз',
        'code': 'KET',
        'category': 'non_contagious',
        'animals': ['КРС'],
      };
      final d = Disease.fromJson(json, isContagious: false);
      expect(d.isContagious, false);
      expect(d.categoryRu, 'Незаразные');
    });
  });

  group('DrugInteraction', () {
    test('fromJson parses all fields including consequence', () {
      final json = {
        'drug1': 'энрофлоксацин',
        'drug2': 'теофиллин',
        'severity': 'critical',
        'effect': 'Повышение уровня теофиллина',
        'consequence': 'Судороги, тахикардия',
        'recommendation': 'Снизить дозу теофиллина',
      };
      final it = DrugInteraction.fromJson(json);
      expect(it.drug1, 'энрофлоксацин');
      expect(it.drug2, 'теофиллин');
      expect(it.severity, 'critical');
      expect(it.effect, 'Повышение уровня теофиллина');
      expect(it.consequence, 'Судороги, тахикардия');
      expect(it.severityRu, 'Критично');
    });
  });

  group('DoseResult', () {
    test('formattedVolume formats correctly for different ranges', () {
      expect(
        const DoseResult(volume: 0.5, unit: 'мл').formattedVolume,
        '0.500 мл',
      );
      expect(
        const DoseResult(volume: 5.0, unit: 'мл').formattedVolume,
        '5.00 мл',
      );
      expect(
        const DoseResult(volume: 50.0, unit: 'мл').formattedVolume,
        '50.0 мл',
      );
      expect(
        const DoseResult(volume: 500.0, unit: 'мл').formattedVolume,
        '500 мл',
      );
    });

    test('hasDoseRange detects valid range', () {
      expect(
        const DoseResult(doseMin: 4.0, doseMax: 6.0).hasDoseRange,
        true,
      );
      expect(
        const DoseResult(doseMin: 0, doseMax: 0).hasDoseRange,
        false,
      );
    });
  });

  group('HistoryEntry', () {
    test('toJson / fromJson roundtrip', () {
      final entry = HistoryEntry(
        drugName: 'Энрофлоксацин',
        animalName: 'Собаки',
        weight: 25.0,
        volume: 12.5,
        unit: 'мл',
        method: 'в/м',
        timestamp: DateTime(2026, 6, 21, 14, 30),
      );
      final json = entry.toJson();
      final restored = HistoryEntry.fromJson(json);

      expect(restored.drugName, 'Энрофлоксацин');
      expect(restored.animalName, 'Собаки');
      expect(restored.weight, 25.0);
      expect(restored.volume, 12.5);
      expect(restored.unit, 'мл');
      expect(restored.method, 'в/м');
      expect(restored.timestamp, DateTime(2026, 6, 21, 14, 30));
    });
  });

  group('Antidote', () {
    test('fromJson parses all fields', () {
      final json = {
        'toxin': 'ивермектин',
        'common_names': ['ивомек', 'баймек'],
        'symptoms': ['атаксия', 'тремор'],
        'antidote': 'физостигмин',
        'antidote_dose': '0.02 мг/кг в/в медленно',
        'alternative': 'Поддерживающая терапия',
        'notes': 'У колли летальная доза в 10 раз ниже',
        'prognosis': 'Выздоровление за 24-72 часа',
      };
      final a = Antidote.fromJson(json);
      expect(a.toxin, 'ивермектин');
      expect(a.commonNames, ['ивомек', 'баймек']);
      expect(a.symptoms, ['атаксия', 'тремор']);
      expect(a.antidote, 'физостигмин');
      expect(a.antidoteDose, '0.02 мг/кг в/в медленно');
      expect(a.prognosis, 'Выздоровление за 24-72 часа');
    });
  });

  group('WithdrawalProduct', () {
    test('labels format int and string values', () {
      expect(
        const WithdrawalProduct(meat: 14, milk: 5).meatLabel,
        '14 сут',
      );
      expect(
        const WithdrawalProduct(meat: 14, milk: 5).milkLabel,
        '5 сут',
      );
      expect(
        const WithdrawalProduct(eggs: 'НЕ ПРИМЕНЯТЬ').eggsLabel,
        'НЕ ПРИМЕНЯТЬ',
      );
      expect(
        const WithdrawalProduct().meatLabel,
        '—',
      );
    });
  });
}
