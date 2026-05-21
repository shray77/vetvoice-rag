import 'package:flutter/foundation.dart';
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

  Animal? get selectedAnimal => _selectedAnimal;
  CalcDrug? get selectedCalcDrug => _selectedCalcDrug;
  RegistryDrug? get selectedRegistryDrug => _selectedRegistryDrug;
  double get weight => _weight;
  DoseResult get result => _result;
  String get searchQuery => _searchQuery;

  // Stats
  int get totalDrugs => _dataService.calcDrugs.length + _dataService.registryDrugs.length;
  int get totalDiseases => _dataService.diseases.length;
  List<Animal> get animals => _dataService.animals;

  /// Инициализация — загрузка данных
  Future<void> initialize() async {
    _isLoading = true;
    _statusMessage = 'Загрузка баз препаратов...';
    notifyListeners();

    await _dataService.loadAll();

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
    notifyListeners();
  }

  /// Выбрать препарат
  void selectDrug(dynamic drug) {
    if (drug is CalcDrug) {
      _selectedCalcDrug = drug;
      _selectedRegistryDrug = null;
      if (_weight > 0) {
        _recalculate();
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

  /// Установить вес
  void setWeight(double w) {
    _weight = w;
    if (_selectedCalcDrug != null) {
      _recalculate();
    }
    notifyListeners();
  }

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

  /// Сбросить всё
  void reset() {
    _selectedAnimal = null;
    _selectedCalcDrug = null;
    _selectedRegistryDrug = null;
    _weight = 0;
    _result = const DoseResult();
    _searchQuery = '';
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
