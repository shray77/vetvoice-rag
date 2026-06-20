import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/drug_models.dart';

/// Сервис загрузки данных из JSON-ассетов.
///
/// Грузит ВСЕ 18 JSON-файлов из assets/data/ и assets/data/advanced/:
///  - drugs_calc, drugs_registry, drugs (animals), diseases, non_contagious_diseases
///  - drug_interactions, side_effects, antidotes, dose_adjustments
///  - treatment_protocols, non_contagious_protocols, emergency_protocols
///  - fluid_therapy, withdrawal_by_product, verified_dosages, correct_dosages_reference
///  - dosage_database, unofficial_protocols
class DataLoadService {
  static final DataLoadService _instance = DataLoadService._internal();
  factory DataLoadService() => _instance;
  DataLoadService._internal();

  // ─── Loaded data ───────────────────────────────────────────────────
  List<CalcDrug>? _calcDrugs;
  List<RegistryDrug>? _registryDrugs;
  List<Animal>? _animals;
  List<Disease>? _diseases;             // contagious + non-contagious merged
  List<Disease>? _nonContagiousDiseases;
  List<DrugInteraction>? _interactions;
  List<SideEffectEntry>? _sideEffects;
  List<Antidote>? _antidotes;
  List<TreatmentProtocol>? _treatmentProtocols;
  List<TreatmentProtocol>? _nonContagiousProtocols;
  List<EmergencyProtocol>? _emergencyProtocols;
  List<FluidFormula>? _fluidFormulas;
  List<WithdrawalInfo>? _withdrawals;
  Map<String, DoseAdjustment>? _doseAdjustments;
  Map<String, VerifiedDosage>? _verifiedDosages;       // verified_dosages.json
  Map<String, Map<String, dynamic>>? _correctDosages;  // correct_dosages_reference.json
  Map<String, dynamic>? _dosageDatabase;                // dosage_database.json (raw)
  List<Map<String, dynamic>>? _unofficialProtocols;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  // ─── Getters ───────────────────────────────────────────────────────
  List<CalcDrug> get calcDrugs => _calcDrugs ?? [];
  List<RegistryDrug> get registryDrugs => _registryDrugs ?? [];
  List<Animal> get animals => _animals ?? [];
  List<Disease> get diseases => _diseases ?? [];
  List<Disease> get nonContagiousDiseases => _nonContagiousDiseases ?? [];
  List<DrugInteraction> get interactions => _interactions ?? [];
  List<SideEffectEntry> get sideEffects => _sideEffects ?? [];
  List<Antidote> get antidotes => _antidotes ?? [];
  List<TreatmentProtocol> get treatmentProtocols => _treatmentProtocols ?? [];
  List<TreatmentProtocol> get nonContagiousProtocols => _nonContagiousProtocols ?? [];
  List<EmergencyProtocol> get emergencyProtocols => _emergencyProtocols ?? [];
  List<FluidFormula> get fluidFormulas => _fluidFormulas ?? [];
  List<WithdrawalInfo> get withdrawals => _withdrawals ?? [];
  Map<String, DoseAdjustment> get doseAdjustments => _doseAdjustments ?? {};
  Map<String, VerifiedDosage> get verifiedDosages => _verifiedDosages ?? {};
  Map<String, Map<String, dynamic>> get correctDosages => _correctDosages ?? {};
  Map<String, dynamic> get dosageDatabase => _dosageDatabase ?? {};
  List<Map<String, dynamic>> get unofficialProtocols => _unofficialProtocols ?? [];

  /// Все болезни (contagious + non-contagious)
  List<Disease> get allDiseases => [...diseases, ...nonContagiousDiseases];

  /// Все протоколы (contagious + non-contagious)
  List<TreatmentProtocol> get allProtocols => [...treatmentProtocols, ...nonContagiousProtocols];

  /// Сводная статистика для UI
  Map<String, int> get stats => {
    'calcDrugs': calcDrugs.length,
    'registryDrugs': registryDrugs.length,
    'diseases': diseases.length,
    'nonContagiousDiseases': nonContagiousDiseases.length,
    'interactions': interactions.length,
    'sideEffects': sideEffects.length,
    'antidotes': antidotes.length,
    'treatmentProtocols': treatmentProtocols.length,
    'nonContagiousProtocols': nonContagiousProtocols.length,
    'emergencyProtocols': emergencyProtocols.length,
    'fluidFormulas': fluidFormulas.length,
    'withdrawals': withdrawals.length,
    'doseAdjustments': doseAdjustments.length,
    'verifiedDosages': verifiedDosages.length,
    'correctDosages': correctDosages.length,
    'unofficialProtocols': unofficialProtocols.length,
  };

  /// Загрузить все базы данных
  Future<void> loadAll() async {
    if (_isLoaded) return;

    int errorsCount = 0;
    final sw = Stopwatch()..start();

    try {
      // 1. Calc drugs (drugs_calc.json) — 2401 drugs
      final calcData = await _loadJson('assets/data/drugs_calc.json');
      if (calcData != null) {
        final List<dynamic> drugsList = calcData['drugs_calc'] ?? [];
        final drugs = <CalcDrug>[];
        for (int i = 0; i < drugsList.length; i++) {
          try {
            drugs.add(CalcDrug.fromJson(drugsList[i] as Map<String, dynamic>));
          } catch (e) {
            errorsCount++;
            if (errorsCount <= 3) {
              debugPrint('CalcDrug parse error #$i: $e');
            }
          }
        }
        _calcDrugs = drugs;
        debugPrint('Loaded ${drugs.length} calc drugs '
            '(${drugsList.length - drugs.length} parse errors)');
      }

      // 2. Registry drugs (drugs_registry.json) — 2449 entries
      final regData = await _loadJson('assets/data/drugs_registry.json');
      if (regData != null) {
        final List<dynamic> drugsList = regData['drugs'] ?? [];
        final drugs = <RegistryDrug>[];
        for (int i = 0; i < drugsList.length; i++) {
          try {
            drugs.add(RegistryDrug.fromJson(drugsList[i] as Map<String, dynamic>));
          } catch (e) {
            errorsCount++;
            if (errorsCount <= 6) {
              debugPrint('RegistryDrug parse error #$i: $e');
            }
          }
        }
        _registryDrugs = drugs;
        debugPrint('Loaded ${drugs.length} registry drugs');
      }

      // 3. Simple drugs (drugs.json) — for animals list
      final drugsData = await _loadJson('assets/data/drugs.json');
      if (drugsData != null) {
        final List<dynamic> animalsList = drugsData['animals'] ?? [];
        final animals = <Animal>[];
        for (final a in animalsList) {
          try {
            animals.add(Animal.fromJson(a as Map<String, dynamic>));
          } catch (e) {
            debugPrint('Animal parse error: $e');
          }
        }
        _animals = animals;
      }

      // 4. Contagious diseases (diseases.json) — 139 entries
      final diseaseData = await _loadJson('assets/data/diseases.json');
      if (diseaseData != null) {
        final List<dynamic> diseasesList = diseaseData['diseases'] ?? [];
        _diseases = diseasesList
            .whereType<Map<String, dynamic>>()
            .map((e) => Disease.fromJson(e, isContagious: true))
            .toList();
        debugPrint('Loaded ${_diseases!.length} contagious diseases');
      }

      // 5. Non-contagious diseases (non_contagious_diseases.json) — 30 entries
      final ncData = await _loadJson('assets/data/non_contagious_diseases.json');
      if (ncData != null) {
        final List<dynamic> list = ncData['diseases'] ?? [];
        _nonContagiousDiseases = list
            .whereType<Map<String, dynamic>>()
            .map((e) => Disease.fromJson(e, isContagious: false))
            .toList();
        debugPrint('Loaded ${_nonContagiousDiseases!.length} non-contagious diseases');
      }

      // 6. Drug interactions (advanced/drug_interactions.json) — 73 entries
      final interactionData = await _loadJson('assets/data/advanced/drug_interactions.json');
      if (interactionData != null) {
        final List<dynamic> list = interactionData['interactions'] ?? [];
        _interactions = list
            .whereType<Map<String, dynamic>>()
            .map((e) => DrugInteraction.fromJson(e))
            .toList();
        debugPrint('Loaded ${_interactions!.length} drug interactions');
      }

      // 7. Side effects (advanced/side_effects.json) — 20 entries
      final seData = await _loadJson('assets/data/advanced/side_effects.json');
      if (seData != null) {
        final List<dynamic> list = seData['drugs'] ?? [];
        _sideEffects = list
            .whereType<Map<String, dynamic>>()
            .map((e) => SideEffectEntry.fromJson(e))
            .where((e) => e.drugName.isNotEmpty)
            .toList();
        debugPrint('Loaded ${_sideEffects!.length} side-effect entries');
      }

      // 8. Antidotes (advanced/antidotes.json) — 17 entries
      final anData = await _loadJson('assets/data/advanced/antidotes.json');
      if (anData != null) {
        final List<dynamic> list = anData['poisonings'] ?? [];
        _antidotes = list
            .whereType<Map<String, dynamic>>()
            .map((e) => Antidote.fromJson(e))
            .where((e) => e.toxin.isNotEmpty)
            .toList();
        debugPrint('Loaded ${_antidotes!.length} antidotes');
      }

      // 9. Treatment protocols (advanced/treatment_protocols.json) — 124 entries
      final tpData = await _loadJson('assets/data/advanced/treatment_protocols.json');
      if (tpData != null) {
        final List<dynamic> list = tpData['protocols'] ?? [];
        _treatmentProtocols = list
            .whereType<Map<String, dynamic>>()
            .map((e) => TreatmentProtocol.fromJson(e))
            .where((e) => e.diagnosis.isNotEmpty)
            .toList();
        debugPrint('Loaded ${_treatmentProtocols!.length} treatment protocols');
      }

      // 10. Non-contagious protocols (advanced/non_contagious_protocols.json) — 30 entries
      final ncpData = await _loadJson('assets/data/advanced/non_contagious_protocols.json');
      if (ncpData != null) {
        final List<dynamic> list = ncpData['protocols'] ?? [];
        _nonContagiousProtocols = list
            .whereType<Map<String, dynamic>>()
            .map((e) => TreatmentProtocol.fromJson(e))
            .where((e) => e.diagnosis.isNotEmpty)
            .toList();
        debugPrint('Loaded ${_nonContagiousProtocols!.length} non-contagious protocols');
      }

      // 11. Emergency protocols (advanced/emergency_protocols.json) — 16 entries
      final epData = await _loadJson('assets/data/advanced/emergency_protocols.json');
      if (epData != null) {
        final List<dynamic> list = epData['protocols'] ?? [];
        _emergencyProtocols = list
            .whereType<Map<String, dynamic>>()
            .map((e) => EmergencyProtocol.fromJson(e))
            .where((e) => e.name.isNotEmpty)
            .toList();
        debugPrint('Loaded ${_emergencyProtocols!.length} emergency protocols');
      }

      // 12. Fluid therapy (advanced/fluid_therapy.json) — formulas
      final ftData = await _loadJson('assets/data/advanced/fluid_therapy.json');
      if (ftData != null) {
        final List<dynamic> list = ftData['formulas'] ?? [];
        _fluidFormulas = list
            .whereType<Map<String, dynamic>>()
            .map((e) => FluidFormula.fromJson(e))
            .where((e) => e.name.isNotEmpty)
            .toList();
        debugPrint('Loaded ${_fluidFormulas!.length} fluid therapy formulas');
      }

      // 13. Withdrawal periods (advanced/withdrawal_by_product.json)
      final wData = await _loadJson('assets/data/advanced/withdrawal_by_product.json');
      if (wData != null) {
        final List<dynamic> list = wData['drugs'] ?? [];
        _withdrawals = list
            .whereType<Map<String, dynamic>>()
            .map((e) => WithdrawalInfo.fromJson(e))
            .where((e) => e.inn.isNotEmpty)
            .toList();
        debugPrint('Loaded ${_withdrawals!.length} withdrawal entries');
      }

      // 14. Dose adjustments (advanced/dose_adjustments.json) — 5 sections
      final daData = await _loadJson('assets/data/advanced/dose_adjustments.json');
      if (daData != null) {
        _doseAdjustments = {};
        for (final key in ['age_adjustments', 'renal_adjustment',
                           'hepatic_adjustment', 'cardiac_adjustment',
                           'pregnancy_lactation']) {
          final v = daData[key];
          if (v is Map<String, dynamic>) {
            _doseAdjustments![key] = DoseAdjustment.fromJson(v);
          }
        }
        debugPrint('Loaded ${_doseAdjustments!.length} dose-adjustment sections');
      }

      // 15. Verified dosages (verified_dosages.json) — 7 named entries
      final vdData = await _loadJson('assets/data/verified_dosages.json');
      if (vdData != null) {
        _verifiedDosages = {};
        vdData.forEach((key, value) {
          if (key == '_meta') return;
          if (value is Map<String, dynamic>) {
            try {
              _verifiedDosages![key] = VerifiedDosage.fromJson(key, value);
            } catch (e) {
              debugPrint('VerifiedDosage parse error for $key: $e');
            }
          }
        });
        debugPrint('Loaded ${_verifiedDosages!.length} verified dosages');
      }

      // 16. Correct dosages reference (correct_dosages_reference.json) — 27 drugs
      final cdData = await _loadJson('assets/data/correct_dosages_reference.json');
      if (cdData != null) {
        _correctDosages = {};
        final dosages = cdData['dosages'];
        if (dosages is Map<String, dynamic>) {
          dosages.forEach((drug, animals) {
            if (animals is Map<String, dynamic>) {
              _correctDosages![drug] = animals;
            }
          });
        }
        debugPrint('Loaded ${_correctDosages!.length} correct-dosage entries');
      }

      // 17. Dosage database (dosage_database.json) — raw map {drug: {animal: {...}}}
      final ddData = await _loadJson('assets/data/dosage_database.json');
      if (ddData != null) {
        _dosageDatabase = ddData['dosages'] as Map<String, dynamic>? ?? {};
        debugPrint('Loaded ${_dosageDatabase!.length} dosage-database entries');
      }

      // 18. Unofficial protocols (unofficial_protocols.json) — raw list of records
      final upData = await _loadJson('assets/data/unofficial_protocols.json');
      if (upData != null) {
        final List<dynamic> list = upData['records'] ?? [];
        _unofficialProtocols = list
            .whereType<Map<String, dynamic>>()
            .toList();
        debugPrint('Loaded ${_unofficialProtocols!.length} unofficial protocols');
      }

      _isLoaded = true;
      sw.stop();
      debugPrint('DataLoadService: loaded all 18 data sources in ${sw.elapsedMilliseconds}ms '
          '($errorsCount parse errors total)');
      if (errorsCount > 0) {
        debugPrint('DataLoadService: $errorsCount total parse errors');
      }
    } catch (e, st) {
      debugPrint('Error loading data: $e\n$st');
      _isLoaded = false;
    }
  }

  Future<Map<String, dynamic>?> _loadJson(String path) async {
    try {
      final String jsonString = await rootBundle.loadString(path);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading $path: $e');
      return null;
    }
  }

  /// Поиск препаратов по названию/МНН
  List<dynamic> searchDrugs(String query, {String? animalFilter}) {
    if (query.isEmpty) return [];
    final lower = query.toLowerCase();
    final results = <dynamic>[];

    for (final drug in _calcDrugs ?? []) {
      if (!drug.calculatorApplicable) continue;
      if (animalFilter != null && !drug.isForAnimal(animalFilter)) continue;
      if (drug.name.toLowerCase().contains(lower) ||
          drug.inn.toLowerCase().contains(lower)) {
        results.add(drug);
      }
    }

    for (final drug in _registryDrugs ?? []) {
      if (animalFilter != null && !drug.isForAnimal(animalFilter)) continue;
      if (drug.tradeName.toLowerCase().contains(lower) ||
          drug.inn.toLowerCase().contains(lower)) {
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

  /// Поиск болезней по названию или коду (contagious + non-contagious)
  List<Disease> searchDiseases(String query) {
    if (query.isEmpty) return allDiseases;
    final lower = query.toLowerCase();
    return allDiseases.where((d) =>
      d.name.toLowerCase().contains(lower) ||
      d.code.toLowerCase().contains(lower) ||
      d.categoryRu.toLowerCase().contains(lower)
    ).toList();
  }

  /// Найти протокол лечения по диагнозу или коду
  TreatmentProtocol? findProtocol(String query) {
    if (query.isEmpty) return null;
    final lower = query.toLowerCase();
    try {
      return allProtocols.firstWhere((p) =>
        p.diagnosis.toLowerCase().contains(lower) ||
        p.code.toLowerCase().contains(lower)
      );
    } catch (_) {
      return null;
    }
  }

  /// Найти взаимодействие по препарату
  List<DrugInteraction> findInteractions(String drugName) {
    if (drugName.isEmpty) return [];
    final lower = drugName.toLowerCase();
    return interactions.where((i) =>
      i.drug1.toLowerCase().contains(lower) ||
      i.drug2.toLowerCase().contains(lower)
    ).toList();
  }

  /// Найти побочные эффекты по препарату
  SideEffectEntry? findSideEffects(String drugName) {
    if (drugName.isEmpty) return null;
    final lower = drugName.toLowerCase();
    try {
      return sideEffects.firstWhere((e) =>
        e.drugName.toLowerCase() == lower ||
        e.drugName.toLowerCase().contains(lower)
      );
    } catch (_) {
      return null;
    }
  }

  /// Найти антидот по токсину
  Antidote? findAntidote(String toxin) {
    if (toxin.isEmpty) return null;
    final lower = toxin.toLowerCase();
    try {
      return antidotes.firstWhere((a) =>
        a.toxin.toLowerCase().contains(lower) ||
        a.commonNames.any((n) => n.toLowerCase().contains(lower))
      );
    } catch (_) {
      return null;
    }
  }

  /// Найти период ожидания по INN препарата
  WithdrawalInfo? findWithdrawal(String inn) {
    if (inn.isEmpty) return null;
    final lower = inn.toLowerCase();
    try {
      return withdrawals.firstWhere((w) =>
        w.inn.toLowerCase() == lower ||
        w.inn.toLowerCase().contains(lower)
      );
    } catch (_) {
      return null;
    }
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
      final doseMg = dosePerKg * weight;
      volumeMl = doseMg / drug.concentration;
      note = '$dosePerKg $doseUnit × ${weight.toStringAsFixed(1)} кг ÷ ${drug.concentration} ${drug.concentrationUnit}';
    } else if (dosePerKg > 0 && drug.unit == 'мл/кг') {
      volumeMl = dosePerKg * weight;
      note = '$dosePerKg мл/кг × ${weight.toStringAsFixed(1)} кг';
    } else if (dosePerKg > 0) {
      final doseMg = dosePerKg * weight;
      note = '$dosePerKg $doseUnit × ${weight.toStringAsFixed(1)} кг = ${doseMg.toStringAsFixed(1)} мг';
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
