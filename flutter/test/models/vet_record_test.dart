import 'package:flutter_test/flutter_test.dart';
import 'package:veteco/models/vet_record_model.dart';

void main() {
  group('VetRecord', () {
    test('toText produces formatted output with all sections', () {
      final record = VetRecord(
        id: 'test-1',
        animalType: 'Собака',
        animalBreed: 'Ротвейлер',
        animalWeight: 35.0,
        animalAge: 5,
        animalGender: 'кобель',
        complaint: 'Хромота три дня',
        anamnesis: 'Аппетит снижен',
        temperature: 39.2,
        heartRate: 120,
        diagnosis: 'Травматический артрит',
        diseaseSeverity: 'средняя',
        prescribedDrugs: [
          PrescribedDrug(name: 'Мелоксикам', shortDescription: '0.1 мг/кг внутрь 7 дней'),
        ],
        procedures: 'Физиотерапия',
        followUp: 'Повторный осмотр через неделю',
        createdAt: DateTime(2026, 6, 21),
        status: VetRecordStatus.parsed,
        rawDictation: 'Собака ротвейлер 35 кг...',
      );

      final text = record.toText();

      expect(text, contains('VetEco — Ветеринарная запись'));
      expect(text, contains('Собака'));
      expect(text, contains('Ротвейлер'));
      expect(text, contains('35 кг'));
      expect(text, contains('S — СУБЪЕКТИВНО'));
      expect(text, contains('Хромота три дня'));
      expect(text, contains('O — ОБЪЕКТИВНО'));
      expect(text, contains('39.2 °C'));
      expect(text, contains('A — ОЦЕНКА'));
      expect(text, contains('Травматический артрит'));
      expect(text, contains('P — ПЛАН'));
      expect(text, contains('Мелоксикам'));
    });

    test('toText handles minimal record (only animal type)', () {
      final record = VetRecord(
        id: 'test-2',
        animalType: 'Корова',
        createdAt: DateTime(2026, 6, 21),
        status: VetRecordStatus.draft,
      );

      final text = record.toText();

      expect(text, contains('Корова'));
      expect(text, contains('ЖИВОТНОЕ'));
      // Should not contain SOAP sections if data is missing
      expect(text, isNot(contains('S — СУБЪЕКТИВНО')));
    });

    test('completeness calculates percentage correctly', () {
      final record = VetRecord(
        id: 'test-3',
        animalType: 'Собака',
        animalWeight: 10.0,
        diagnosis: 'Оtitis',
        prescribedDrugs: [PrescribedDrug(name: 'Капли', shortDescription: '2 капли')],
        createdAt: DateTime(2026, 6, 21),
        status: VetRecordStatus.parsed,
      );

      // 4 filled fields out of 15 → ~26.7%
      expect(record.completeness, greaterThan(0.2));
      expect(record.completeness, lessThan(0.35));
    });
  });

  group('PrescribedDrug', () {
    test('shortDescription is accessible', () {
      final drug = PrescribedDrug(
        name: 'Энрофлоксацин',
        shortDescription: '5 мг/кг в/м 5 дней',
      );
      expect(drug.name, 'Энрофлоксацин');
      expect(drug.shortDescription, '5 мг/кг в/м 5 дней');
    });
  });
}
