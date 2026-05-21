import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/drug_models.dart';

/// Сервис загрузки данных из JSON-ассетов
class DataLoadService {
  static final DataLoadService _instance = DataLoadService._internal();
  factory DataLoadService() => _instance;
  DataLoadService._internal();

  List<CalcDrug>? _calcDrugs;
  List<RegistryDrug>? _registryDrugs;
  List<Animal>? _animals;
  List<Disease>? _diseases;
  List<DrugInteraction>? _interactions;
  Map<String, dynamic>? _dosageDatabase;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  List<CalcDrug> get calcDrugs => _calcDrugs ?? [];
  List<RegistryDrug> get registryDrugs => _registryDrugs ?? [];
  List<Animal> get animals => _animals ?? [];
  List<Disease> get diseases => _diseases ?? [];
  List<DrugInteraction> get interactions => _interactions ?? [];
  Map<String, dynamic> get dosageDatabase => _dosageDatabase ?? {};

  /// Загрузить все базы данных
  Future<void> loadAll() async {
    if (_isLoaded) return;

    try {
      // Load calc drugs
      final calcData = await _loadJson('assets/data/drugs_calc.json');
      if (calcData != null) {
        final List<dynamic> drugsList = calcData['drugs_calc'] ?? [];
        _calcDrugs = drugsList.map((e) => CalcDrug.fromJson(e as Map<String, dynamic>)).toList();
      }

      // Load registry drugs
      final regData = await _loadJson('assets/data/drugs_registry.json');
      if (regData != null) {
        final List<dynamic> drugsList = regData['drugs'] ?? [];
        _registryDrugs = drugsList.map((e) => RegistryDrug.fromJson(e as Map<String, dynamic>)).toList();
      }

      // Load simple drugs (for animals list)
      final drugsData = await _loadJson('assets/data/drugs.json');
      if (drugsData != null) {
        final List<dynamic> animalsList = drugsData['animals'] ?? [];
        _animals = animalsList.map((e) => Animal.fromJson(e as Map<String, dynamic>)).toList();
      }

      // Load diseases
      final diseaseData = await _loadJson('assets/data/diseases.json');
      if (diseaseData != null) {
        final List<dynamic> diseasesList = diseaseData['diseases'] ?? [];
        _diseases = diseasesList.map((e) => Disease.fromJson(e as Map<String, dynamic>)).toList();
      }

      // Load drug interactions
      final interactionData = await _loadJson('assets/data/advanced/drug_interactions.json');
      if (interactionData != null) {
        final List<dynamic> interactionsList = interactionData['interactions'] ?? [];
        _interactions = interactionsList.map((e) => DrugInteraction.fromJson(e as Map<String, dynamic>)).toList();
      }

      // Load dosage database
      final dosageData = await _loadJson('assets/data/dosage_database.json');
      if (dosageData != null) {
        _dosageDatabase = dosageData['dosages'] as Map<String, dynamic>? ?? {};
      }

      _isLoaded = true;
    } catch (e) {
      print('Error loading data: $e');
      _isLoaded = false;
    }
  }

  Future<Map<String, dynamic>?> _loadJson(String path) async {
    try {
      final String jsonString = await rootBundle.loadString(path);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('Error loading $path: $e');
      return null;
    }
  }

  /// Поиск препаратов по названию/МНН
  List<dynamic> searchDrugs(String query, {String? animalFilter}) {
    if (query.isEmpty) return [];
    final lower = query.toLowerCase();
    final results = <dynamic>[];

    // Search in calc drugs first
    for (final drug in _calcDrugs ?? []) {
      if (!drug.calculatorApplicable) continue;
      if (animalFilter != null && !drug.isForAnimal(animalFilter)) continue;
      if (drug.name.toLowerCase().contains(lower) || drug.inn.toLowerCase().contains(lower)) {
        results.add(drug);
      }
    }

    // Then search in registry
    for (final drug in _registryDrugs ?? []) {
      if (animalFilter != null && !drug.isForAnimal(animalFilter)) continue;
      if (drug.tradeName.toLowerCase().contains(lower) || drug.inn.toLowerCase().contains(lower)) {
        results.add(drug);
      }
    }

    return results;
  }

  /// Получить препараты для животного
  List<dynamic> getDrugsForAnimal(String animalName) {
    final results = <dynamic>[];

    for (final drug in _calcDrugs ?? []) {
      if (drug.isForAnimal(animalName) && drug.calculatorApplicable) {
        results.add(drug);
      }
    }

    for (final drug in _registryDrugs ?? []) {
      if (drug.isForAnimal(animalName)) {
        results.add(drug);
      }
    }

    return results;
  }

  /// Рассчитать дозу для CalcDrug
  DoseResult calculateDose(CalcDrug drug, double weight, {String? animalName}) {
    if (weight <= 0) {
      return DoseResult(
        drugName: drug.name,
        drugForm: drug.form,
        error: 'Укажите вес животного',
      );
    }

    // Check for animal-specific dosage
    double dosePerKg = drug.dosePerKg;
    double doseMin = drug.doseMin;
    double doseMax = drug.doseMax;
    String doseUnit = drug.doseUnit;
    String method = drug.method;
    String frequency = drug.frequency;

    if (animalName != null && drug.animalSpecific != null) {
      // Try Russian animal names first
      final specific = drug.animalSpecific![animalName];
      if (specific != null) {
        dosePerKg = specific.dosePerKg > 0 ? specific.dosePerKg : dosePerKg;
        doseMin = specific.doseMin > 0 ? specific.doseMin : doseMin;
        doseMax = specific.doseMax > 0 ? specific.doseMax : doseMax;
        doseUnit = specific.doseUnit.isNotEmpty ? specific.doseUnit : doseUnit;
        method = specific.method.isNotEmpty ? specific.method : method;
        frequency = specific.frequency.isNotEmpty ? specific.frequency : frequency;
      }
    }

    // Fixed dose (vaccines etc.)
    if (drug.fixedDose != null && drug.fixedDose.toString().isNotEmpty) {
      return DoseResult(
        drugName: drug.name,
        drugForm: drug.form,
        method: method.isNotEmpty ? method : drug.method,
        frequency: frequency.isNotEmpty ? frequency : drug.frequency,
        courseDays: drug.courseDays,
        withdrawalDays: drug.withdrawalDays,
        hasDosage: true,
        hasResult: true,
        isFixedDose: true,
        fixedDoseText: drug.fixedDose.toString(),
        contraindications: drug.contraindications.isNotEmpty ? [drug.contraindications] : [],
        sideEffects: drug.sideEffects,
        note: drug.indications,
      );
    }

    // Calculate volume
    double volumeMl = 0;
    String note = '';

    if (drug.concentration > 0 && dosePerKg > 0) {
      // dose_mg = dose_per_kg * weight; volume_ml = dose_mg / concentration
      final doseMg = dosePerKg * weight;
      volumeMl = doseMg / drug.concentration;
      note = '$dosePerKg $doseUnit × ${weight.toStringAsFixed(1)} кг ÷ ${drug.concentration} ${drug.concentrationUnit}';
    } else if (dosePerKg > 0 && drug.unit == 'мл/кг') {
      volumeMl = dosePerKg * weight;
      note = '$dosePerKg мл/кг × ${weight.toStringAsFixed(1)} кг';
    }

    return DoseResult(
      volume: volumeMl,
      unit: drug.unit == 'г' ? 'г' : 'мл',
      drugName: drug.name,
      drugForm: drug.form,
      method: method.isNotEmpty ? method : drug.method,
      frequency: frequency.isNotEmpty ? frequency : drug.frequency,
      courseDays: drug.courseDays,
      withdrawalDays: drug.withdrawalDays,
      hasDosage: dosePerKg > 0,
      hasResult: true,
      contraindications: drug.contraindications.isNotEmpty ? [drug.contraindications] : [],
      sideEffects: drug.sideEffects,
      note: note,
      dosePerKg: dosePerKg,
      doseMin: doseMin,
      doseMax: doseMax,
      doseUnit: doseUnit,
      weight: weight,
      concentration: drug.concentration,
    );
  }
}
