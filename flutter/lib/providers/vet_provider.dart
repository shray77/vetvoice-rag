import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/drug_models.dart';
import '../services/data_load_service.dart';

/// Главный провайдер состояния приложения
class VetProvider extends ChangeNotifier {
  final DataLoadService _dataService = DataLoadService();

  // Loading
  bool _isLoading = true;
  String _statusMessage = 'Загрузка баз...';
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;

  // Selected state
  Animal? _selectedAnimal;
  CalcDrug? _selectedCalcDrug;
  RegistryDrug? _selectedRegistryDrug;
  double _weight = 0;
  DoseResult _result = const DoseResult();
  String _searchQuery = '';

  // Task 194: состояние пациента — возраст + беременность/лактация.
  // Дозы в базах не дифференцированы по полу/возрасту, поэтому это НЕ
  // корректор расчёта, а усилитель предупреждений: релевантные
  // противопоказания препарата (структурированные contraindications)
  // поднимаются наверх с пометкой. Раньше «ни пол, ни возраст выбрать
  // нельзя» — теперь можно, и база на это отвечает.
  String _patientAge = ''; // '', 'young', 'adult', 'old'
  bool _patientPregnant = false;
  bool _patientLactating = false;

  Animal? get selectedAnimal => _selectedAnimal;
  CalcDrug? get selectedCalcDrug => _selectedCalcDrug;
  RegistryDrug? get selectedRegistryDrug => _selectedRegistryDrug;
  double get weight => _weight;
  DoseResult get result => _applyPatientWarnings(_result);
  String get searchQuery => _searchQuery;

  String get patientAge => _patientAge;
  bool get patientPregnant => _patientPregnant;
  bool get patientLactating => _patientLactating;

  /// Возрастная группа: '' (не указано) / young / adult / old.
  void setPatientAge(String age) {
    _patientAge = (_patientAge == age) ? '' : age;
    notifyListeners();
  }

  void togglePregnancy() {
    _patientPregnant = !_patientPregnant;
    if (_patientPregnant) _patientLactating = false;
    notifyListeners();
  }

  void toggleLactation() {
    _patientLactating = !_patientLactating;
    if (_patientLactating) _patientPregnant = false;
    notifyListeners();
  }

  // ─── History & Favorites ───────────────────────────────────────────
  final List<HistoryEntry> _history = [];
  final Set<String> _favorites = {}; // drug IDs (name-based)

  List<HistoryEntry> get history => List.unmodifiable(_history);
  List<HistoryEntry> get recentHistory => _history.take(10).toList();
  Set<String> get favorites => Set.unmodifiable(_favorites);

  bool isFavorite(String drugName) => _favorites.contains(drugName);

  void toggleFavorite(String drugName) {
    if (_favorites.contains(drugName)) {
      _favorites.remove(drugName);
    } else {
      _favorites.add(drugName);
    }
    _saveFavorites();
    notifyListeners();
  }

  void addHistory(HistoryEntry entry) {
    _history.insert(0, entry);
    if (_history.length > 50) _history.removeLast();
    _saveHistory();
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    _saveHistory();
    notifyListeners();
  }

  Future<void> _loadHistoryAndFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    // History
    final histJson = prefs.getString('dose_history');
    if (histJson != null) {
      try {
        final list = jsonDecode(histJson) as List<dynamic>;
        _history.addAll(list.map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    // Favorites
    final favJson = prefs.getString('dose_favorites');
    if (favJson != null) {
      try {
        final list = jsonDecode(favJson) as List<dynamic>;
        _favorites.addAll(list.map((e) => e.toString()));
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _history.map((e) => e.toJson()).toList();
    await prefs.setString('dose_history', jsonEncode(list));
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dose_favorites', jsonEncode(_favorites.toList()));
  }

  // Stats
  int get totalDrugs => _dataService.calcDrugs.length + _dataService.registryDrugs.length;
  int get totalDiseases => _dataService.diseases.length + _dataService.nonContagiousDiseases.length;
  int get totalProtocols => _dataService.treatmentProtocols.length + _dataService.nonContagiousProtocols.length;
  List<Animal> get animals => _dataService.animals;

  // New data accessors (delegating to DataLoadService)
  List<Disease> get diseases => _dataService.diseases;
  List<Disease> get nonContagiousDiseases => _dataService.nonContagiousDiseases;
  List<Disease> get allDiseases => _dataService.allDiseases;
  List<DrugInteraction> get interactions => _dataService.interactions;
  List<SideEffectEntry> get sideEffects => _dataService.sideEffects;
  List<Antidote> get antidotes => _dataService.antidotes;
  List<TreatmentProtocol> get treatmentProtocols => _dataService.treatmentProtocols;
  List<TreatmentProtocol> get nonContagiousProtocols => _dataService.nonContagiousProtocols;
  List<TreatmentProtocol> get allProtocols => _dataService.allProtocols;
  List<EmergencyProtocol> get emergencyProtocols => _dataService.emergencyProtocols;
  List<FluidFormula> get fluidFormulas => _dataService.fluidFormulas;
  List<WithdrawalInfo> get withdrawals => _dataService.withdrawals;
  Map<String, DoseAdjustment> get doseAdjustments => _dataService.doseAdjustments;
  Map<String, VerifiedDosage> get verifiedDosages => _dataService.verifiedDosages;
  Map<String, Map<String, dynamic>> get correctDosages => _dataService.correctDosages;

  /// Сводная статистика для экрана «Справочник»
  Map<String, int> get dbStats => _dataService.stats;

  // ─── Lookup helpers ────────────────────────────────────────────────

  /// Поиск болезней (contagious + non-contagious)
  List<Disease> searchDiseases(String query) => _dataService.searchDiseases(query);

  /// Найти протокол лечения по диагнозу или коду
  TreatmentProtocol? findProtocol(String query) => _dataService.findProtocol(query);

  /// Найти взаимодействия препарата
  List<DrugInteraction> findInteractions(String drugName) => _dataService.findInteractions(drugName);

  /// Найти побочные эффекты препарата
  SideEffectEntry? findSideEffects(String drugName) => _dataService.findSideEffects(drugName);

  /// Найти антидот по токсину
  Antidote? findAntidote(String toxin) => _dataService.findAntidote(toxin);

  /// Найти период ожидания по INN
  WithdrawalInfo? findWithdrawal(String inn) => _dataService.findWithdrawal(inn);

  /// Инициализация — загрузка данных
  Future<void> initialize() async {
    _isLoading = true;
    _statusMessage = 'Загрузка баз препаратов...';
    notifyListeners();

    await _dataService.loadAll();
    await _loadHistoryAndFavorites();

    _statusMessage = 'Загружено: ${_dataService.calcDrugs.length} препаратов для расчёта, '
        '${_dataService.registryDrugs.length} в реестре';
    _isLoading = false;
    notifyListeners();
  }

  /// Выбрать животное
  void selectAnimal(Animal animal) {
    _selectedAnimal = animal;
    _selectedCalcDrug = null;
    _selectedRegistryDrug = null;
    _result = const DoseResult();
    _searchQuery = '';
    // Task 194: смена вида = новый пациент — состояние сбрасывается.
    _patientAge = '';
    _patientPregnant = false;
    _patientLactating = false;
    notifyListeners();
  }

  /// Выбрать препарат
  void selectDrug(dynamic drug) {
    if (drug is CalcDrug) {
      _selectedCalcDrug = drug;
      _selectedRegistryDrug = null;
      if (_weight > 0) {
        _recalculate();
        _addCurrentToHistory(drug.name);
      } else {
        _result = DoseResult(
          drugName: drug.name,
          drugForm: drug.form,
          method: drug.method,
          frequency: drug.frequency,
          hasResult: true,
          note: drug.indications,
        );
      }
    } else if (drug is RegistryDrug) {
      _selectedRegistryDrug = drug;
      _selectedCalcDrug = null;
      _result = DoseResult(
        drugName: drug.tradeName,
        drugForm: drug.form,
        method: 'См. инструкцию',
        hasResult: true,
        note: drug.indications,
        contraindications: drug.contraindications.isNotEmpty ? [drug.contraindications] : [],
      );
    }
    _searchQuery = '';
    notifyListeners();
  }

  /// Установить вес.
  ///
  /// Task 179: гвард знака. Минус — случайное нажатие или правка «5»
  /// после забытого «-»; отрицательного веса физически не существует.
  /// Контракт единый с RU-запятой (Task 178): некорректный ввод =
  /// «вес не указан» (`_weight = 0`), а не «-250 мл» в расчёт и не
  /// висящая подсказка при заполненном поле. Все читатели уже
  /// проверяют `weight > 0` — отрицательное значение просто
  /// просачивалось в состояние и жило там.
  void setWeight(double w) {
    _weight = w > 0 ? w : 0;
    if (_selectedCalcDrug != null) {
      _recalculate();
    }
    notifyListeners();
  }

  /// Task 194: вес вне диапазона выбранного вида? «2 кг бык» —
  /// почти наверняка опечатка, но визард принимал любую цифру и
  /// сразу прыгал на следующий шаг. Границы — из min/max вида
  /// (Animal.minWeight/maxWeight, данные drugs.json), диапазон виден
  /// в подсказке рядом с полем. null = всё в порядке.
  String? get weightError {
    final a = _selectedAnimal;
    if (a == null || _weight <= 0) return null;
    if (_weight < a.minWeight || _weight > a.maxWeight) {
      final min = a.minWeight % 1 == 0
          ? a.minWeight.toStringAsFixed(0)
          : a.minWeight.toStringAsFixed(1);
      final max = a.maxWeight % 1 == 0
          ? a.maxWeight.toStringAsFixed(0)
          : a.maxWeight.toStringAsFixed(1);
      return 'Вне диапазона для ${a.name} ($min–$max кг) — проверьте вес или выберите другой вид';
    }
    return null;
  }

  /// Вес годен для расчёта: введён и в диапазоне вида.
  bool get isWeightValid => _weight > 0 && weightError == null;

  /// Установить поисковый запрос
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Результаты поиска
  List<dynamic> get searchResults {
    if (_searchQuery.isEmpty) return [];
    return _dataService.searchDrugs(
      _searchQuery,
      animalFilter: _selectedAnimal?.name,
    );
  }

  /// Препараты для выбранного животного
  List<dynamic> get availableDrugs {
    if (_selectedAnimal == null) return [];
    return _dataService.getDrugsForAnimal(_selectedAnimal!.name);
  }

  void _recalculate() {
    if (_selectedCalcDrug == null || _weight <= 0) return;
    _result = _dataService.calculateDose(
      _selectedCalcDrug!,
      _weight,
      animalName: _selectedAnimal?.name,
    );
  }

  /// Task 194: поднять релевантные состоянию пациента противопоказания.
  /// Геттер [result] применяет на лету — переключение чипов не требует
  /// пересчёта дозы. У CalcDrug — структурные флаги, у RegistryDrug —
  /// эвристика по тексту (реестр хранит противопоказания строкой).
  DoseResult _applyPatientWarnings(DoseResult r) {
    if (!_patientPregnant && !_patientLactating && _patientAge.isEmpty) {
      return r;
    }
    final alerts = <String>[];
    final calc = _selectedCalcDrug;
    if (calc != null) {
      if (_patientPregnant && calc.contraindicatedInPregnancy) {
        alerts.add('⛔ БЕРЕМЕННОСТЬ: препарат противопоказан беременным животным');
      }
      if (_patientLactating && calc.contraindicatedInLactation) {
        alerts.add('⛔ ЛАКТАЦИЯ: препарат противопоказан в период лактации');
      }
      if (_patientAge == 'young' && calc.contraindicatedYoung) {
        alerts.add('⛔ МОЛОДОЕ ЖИВОТНОЕ: противопоказан незрелым животным');
      }
      if (_patientAge == 'old' && calc.contraindicatedOld) {
        alerts.add('⛔ ПОЖИЛОЕ ЖИВОТНОЕ: соблюдать осторожность по инструкции');
      }
    } else {
      final reg = _selectedRegistryDrug;
      if (reg != null && reg.contraindications.isNotEmpty) {
        final t = reg.contraindications.toLowerCase();
        if (_patientPregnant && (t.contains('беремен') || t.contains('стельн'))) {
          alerts.add('⛔ БЕРЕМЕННОСТЬ: по инструкции противопоказан беременным');
        }
        if (_patientLactating && t.contains('лакт')) {
          alerts.add('⛔ ЛАКТАЦИЯ: по инструкции противопоказан в лактацию');
        }
      }
    }
    if (alerts.isEmpty) return r;
    return r.copyWithWarnings(
      contraindications: [...alerts, ...r.contraindications],
    );
  }

  /// Сохраняет текущий расчёт в историю.
  void _addCurrentToHistory(String drugName) {
    if (_result.volume <= 0 && !_result.hasResult) return;
    addHistory(HistoryEntry(
      drugName: drugName,
      animalName: _selectedAnimal?.name ?? '',
      weight: _weight,
      volume: _result.volume,
      unit: _result.unit,
      method: _result.method,
      timestamp: DateTime.now(),
    ));
  }

  /// Сбросить всё
  void reset() {
    _selectedAnimal = null;
    _selectedCalcDrug = null;
    _selectedRegistryDrug = null;
    _weight = 0;
    _result = const DoseResult();
    _searchQuery = '';
    _patientAge = '';
    _patientPregnant = false;
    _patientLactating = false;
    notifyListeners();
  }

  /// Найти препарат по названию (для голосового ввода)
  bool findDrugByName(String name) {
    final results = _dataService.searchDrugs(
      name,
      animalFilter: _selectedAnimal?.name,
    );
    if (results.isNotEmpty) {
      selectDrug(results.first);
      return true;
    }
    return false;
  }
}
