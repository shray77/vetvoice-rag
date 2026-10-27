import 'package:flutter_test/flutter_test.dart';
import 'package:veteco/providers/vet_provider.dart';
import 'package:veteco/utils/decimal_input.dart';

/// Гейт-кейсы Task 179: «мусор в семантических полях».
///
/// Регрессия: «-5» кг (минус — случайное нажатие или правка после
/// забытого знака) уходил в провайдер и жил в состоянии: все читатели
/// проверяют `weight > 0`, поэтому шаги блокировались, подсказка
/// «укажите вес» висела при заполненном поле — тихая ерунда без краша.
///
/// Контракт (единый с RU-запятой Task 178): парсер не судит — судит
/// гвард. `parseDecimal('-5')` честно возвращает -5.0, а `setWeight`
/// маппит некорректное в «не указано» (= 0).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('setWeight — гвард знака', () {
    test('положительный вес проходит как есть', () {
      final p = VetProvider();
      p.setWeight(12.5);
      expect(p.weight, 12.5);
    });

    test('отрицательный вес → «не указано» (регрессия Task 179)', () {
      final p = VetProvider();
      p.setWeight(-5);
      expect(p.weight, 0);
    });

    test('ноль → «не указано» (не изменение)', () {
      final p = VetProvider();
      p.setWeight(12.5);
      p.setWeight(0);
      expect(p.weight, 0);
    });

    test('восстановление: минус, затем корректный ввод', () {
      final p = VetProvider();
      p.setWeight(-5);
      p.setWeight(12.5);
      expect(p.weight, 12.5);
    });

    test('полная цепочка: parseDecimal не судит, гвард судит', () {
      final p = VetProvider();
      // parseDecimal пропускает минус намеренно (Task 178)…
      expect(parseDecimal('-5'), -5.0);
      // …значит, именно сеттер обязан держать инвариант:
      p.setWeight(parseDecimal('-5')!);
      expect(p.weight, 0);
      p.setWeight(parseDecimal('12,5')!);
      expect(p.weight, 12.5);
    });

    test('reset возвращает вес в «не указано»', () {
      final p = VetProvider();
      p.setWeight(30);
      p.reset();
      expect(p.weight, 0);
    });
  });
}
