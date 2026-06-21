/// Модель препарата для расчёта дозировок
class CalcDrug {
  final int id;
  final String name;
  final String inn;
  final String form;
  final String formType;
  final double concentration;
  final String concentrationUnit;
  final String unit;
  final double dosePerKg;
  final double doseMin;
  final double doseMax;
  final String doseUnit;
  final List<String> animals;
  final String method;
  final String frequency;
  final String courseDays;
  final int withdrawalDays;
  final dynamic fixedDose;
  final bool calculatorApplicable;
  final String contraindications;
  final List<String> sideEffects;
  final String category;
  final String indications;
  final Map<String, AnimalSpecificDosage>? animalSpecific;

  const CalcDrug({
    required this.id,
    required this.name,
    required this.inn,
    required this.form,
    this.formType = 'injection',
    this.concentration = 0,
    this.concentrationUnit = 'мг/мл',
    this.unit = 'мл',
    this.dosePerKg = 0,
    this.doseMin = 0,
    this.doseMax = 0,
    this.doseUnit = 'мг/кг',
    required this.animals,
    this.method = '',
    this.frequency = '',
    this.courseDays = '',
    this.withdrawalDays = 0,
    this.fixedDose,
    this.calculatorApplicable = true,
    this.contraindications = '',
    this.sideEffects = const [],
    this.category = '',
    this.indications = '',
    this.animalSpecific,
  });

  /// Безопасное извлечение числа из JSON (может быть String, int, double, null)
  static double _parseDouble(dynamic value, [double defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      // Убираем пробелы, неразрывные пробелы, МЕ/мг суффиксы
      final cleaned = value
          .replaceAll(RegExp(r'[\s\u00A0]'), '')
          .replaceAll(RegExp(r'[Мм][Ее]|мг|мл|г'), '')
          .replaceAll(',', '.')
          .replaceAll(RegExp(r'[^\d.]'), '')
          .trim();
      if (cleaned.isEmpty) return defaultValue;
      return double.tryParse(cleaned) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Безопасное извлечение целого числа из JSON
  static int _parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d]'), '').trim();
      if (cleaned.isEmpty) return defaultValue;
      return int.tryParse(cleaned) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Безопасное извлечение bool из JSON
  static bool _parseBool(dynamic value, [bool defaultValue = true]) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is int) return value != 0;
    return defaultValue;
  }

  factory CalcDrug.fromJson(Map<String, dynamic> json) {
    Map<String, AnimalSpecificDosage>? specific;
    if (json['animal_specific'] != null) {
      specific = {};
      (json['animal_specific'] as Map<String, dynamic>).forEach((key, value) {
        try {
          specific![key] = AnimalSpecificDosage.fromJson(value as Map<String, dynamic>);
        } catch (_) {
          // Пропускаем некорректные записи animal_specific
        }
      });
    }

    return CalcDrug(
      id: _parseInt(json['id'], 0),
      name: json['name'] as String? ?? '',
      inn: json['inn'] as String? ?? '',
      form: json['form'] as String? ?? '',
      formType: json['form_type'] as String? ?? 'injection',
      concentration: _parseDouble(json['concentration'], 0),
      concentrationUnit: json['concentration_unit'] as String? ?? 'мг/мл',
      unit: json['unit'] as String? ?? 'мл',
      dosePerKg: _parseDouble(json['dose_per_kg'], 0),
      doseMin: _parseDouble(json['dose_min'], 0),
      doseMax: _parseDouble(json['dose_max'], 0),
      doseUnit: json['dose_unit'] as String? ?? 'мг/кг',
      animals: (json['animals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      method: json['method'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      courseDays: json['course_days']?.toString() ?? '',
      withdrawalDays: _parseInt(json['withdrawal_days'], 0),
      fixedDose: json['fixed_dose'],
      calculatorApplicable: _parseBool(json['calculator_applicable'], true),
      contraindications: json['contraindications'] as String? ?? '',
      sideEffects: (json['side_effects'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      category: json['category'] as String? ?? '',
      indications: json['indications'] as String? ?? '',
      animalSpecific: specific,
    );
  }

  bool isForAnimal(String animalName) {
    return animals.any((a) => a.toLowerCase() == animalName.toLowerCase());
  }

  String get displayName => name.replaceAll('®', '').trim();
}

/// Видо-специфичная дозировка
class AnimalSpecificDosage {
  final double dosePerKg;
  final double doseMin;
  final double doseMax;
  final String doseUnit;
  final String method;
  final String frequency;
  final String notes;

  const AnimalSpecificDosage({
    this.dosePerKg = 0,
    this.doseMin = 0,
    this.doseMax = 0,
    this.doseUnit = 'мг/кг',
    this.method = '',
    this.frequency = '',
    this.notes = '',
  });

  factory AnimalSpecificDosage.fromJson(Map<String, dynamic> json) {
    return AnimalSpecificDosage(
      dosePerKg: CalcDrug._parseDouble(json['dose_per_kg'], 0),
      doseMin: CalcDrug._parseDouble(json['dose_min'], 0),
      doseMax: CalcDrug._parseDouble(json['dose_max'], 0),
      doseUnit: json['dose_unit'] as String? ?? 'мг/кг',
      method: json['method'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }
}

/// Препарат из реестра
class RegistryDrug {
  final int id;
  final String tradeName;
  final String inn;
  final String form;
  final String dosage;
  final List<String> animals;
  final String pharmacologicalGroup;
  final String indications;
  final String contraindications;
  final String sideEffects;
  final String manufacturer;
  final String registrationNumber;
  final String composition;
  final String packaging;

  const RegistryDrug({
    required this.id,
    required this.tradeName,
    required this.inn,
    required this.form,
    this.dosage = '',
    required this.animals,
    this.pharmacologicalGroup = '',
    this.indications = '',
    this.contraindications = '',
    this.sideEffects = '',
    this.manufacturer = '',
    this.registrationNumber = '',
    this.composition = '',
    this.packaging = '',
  });

  factory RegistryDrug.fromJson(Map<String, dynamic> json) {
    return RegistryDrug(
      id: CalcDrug._parseInt(json['id'], 0),
      tradeName: json['trade_name'] as String? ?? '',
      inn: json['inn'] as String? ?? '',
      form: json['form'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      animals: (json['animals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      pharmacologicalGroup: json['pharmacological_group'] as String? ?? '',
      indications: json['indications'] as String? ?? '',
      contraindications: json['contraindications'] as String? ?? '',
      sideEffects: json['side_effects'] as String? ?? '',
      manufacturer: json['manufacturer'] as String? ?? '',
      registrationNumber: json['registration_number'] as String? ?? '',
      composition: json['composition'] as String? ?? '',
      packaging: json['packaging'] as String? ?? '',
    );
  }

  bool isForAnimal(String animalName) {
    return animals.any((a) => a.toLowerCase() == animalName.toLowerCase());
  }

  String get displayName => tradeName.replaceAll('®', '').trim();
  bool get isVaccine => pharmacologicalGroup.toLowerCase().contains('вакцин');
}

/// Животное
class Animal {
  final String id;
  final String name;
  final String icon;
  final double minWeight;
  final double maxWeight;
  final String weightHint;
  final String pregnancyTerm;

  const Animal({
    required this.id,
    required this.name,
    required this.icon,
    this.minWeight = 0.1,
    this.maxWeight = 2000,
    this.weightHint = '',
    this.pregnancyTerm = 'Беременность',
  });

  factory Animal.fromJson(Map<String, dynamic> json) {
    return Animal(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '🐾',
      minWeight: CalcDrug._parseDouble(json['min_weight'], 0.1),
      maxWeight: CalcDrug._parseDouble(json['max_weight'], 2000),
      weightHint: json['weight_hint'] as String? ?? '',
      pregnancyTerm: json['pregnancy_term'] as String? ?? 'Беременность',
    );
  }
}

/// Результат расчёта дозы
class DoseResult {
  final double volume;
  final String unit;
  final String drugName;
  final String drugForm;
  final String method;
  final String frequency;
  final String courseDays;
  final int withdrawalDays;
  final String error;
  final String warning;
  final List<String> contraindications;
  final List<String> sideEffects;
  final bool hasDosage;
  final bool hasResult;
  final bool isFixedDose;
  final String fixedDoseText;
  final String note;
  final double dosePerKg;
  final double doseMin;
  final double doseMax;
  final String doseUnit;
  final double weight;
  final double concentration;

  const DoseResult({
    this.volume = 0,
    this.unit = 'мл',
    this.drugName = '',
    this.drugForm = '',
    this.method = '',
    this.frequency = '',
    this.courseDays = '',
    this.withdrawalDays = 0,
    this.error = '',
    this.warning = '',
    this.contraindications = const [],
    this.sideEffects = const [],
    this.hasDosage = false,
    this.hasResult = false,
    this.isFixedDose = false,
    this.fixedDoseText = '',
    this.note = '',
    this.dosePerKg = 0,
    this.doseMin = 0,
    this.doseMax = 0,
    this.doseUnit = 'мг/кг',
    this.weight = 0,
    this.concentration = 0,
  });

  bool get hasError => error.isNotEmpty;
  bool get hasContraindications => contraindications.isNotEmpty;
  bool get hasSideEffects => sideEffects.isNotEmpty;
  bool get hasDoseRange => doseMin > 0 && doseMax > 0 && doseMin < doseMax;

  String get formattedVolume {
    if (volume >= 100) return '${volume.toStringAsFixed(0)} $unit';
    if (volume >= 10) return '${volume.toStringAsFixed(1)} $unit';
    if (volume >= 1) return '${volume.toStringAsFixed(2)} $unit';
    return '${volume.toStringAsFixed(3)} $unit';
  }

  String get speechText {
    final buffer = StringBuffer();
    if (hasDosage && volume > 0) {
      buffer.write('$drugName: $formattedVolume $method. ');
      if (frequency.isNotEmpty) buffer.write('$frequency. ');
      if (courseDays.isNotEmpty) buffer.write('Курс: $courseDays. ');
    } else if (hasDosage && isFixedDose) {
      buffer.write('$drugName. Доза: $fixedDoseText. ');
    } else {
      buffer.write('$drugName. Дозировка по инструкции. ');
    }
    if (hasContraindications) {
      buffer.write('Внимание! ${contraindications.first} ');
    }
    if (withdrawalDays > 0) {
      buffer.write('Срок ожидания $withdrawalDays дней. ');
    }
    return buffer.toString();
  }

  DoseResult copyWith({
    double? volume,
    String? unit,
    String? drugName,
    String? drugForm,
    String? method,
    String? frequency,
    String? courseDays,
    int? withdrawalDays,
    String? error,
    String? warning,
    List<String>? contraindications,
    List<String>? sideEffects,
    bool? hasDosage,
    bool? hasResult,
    bool? isFixedDose,
    String? fixedDoseText,
    String? note,
    double? dosePerKg,
    double? doseMin,
    double? doseMax,
    String? doseUnit,
    double? weight,
    double? concentration,
  }) {
    return DoseResult(
      volume: volume ?? this.volume,
      unit: unit ?? this.unit,
      drugName: drugName ?? this.drugName,
      drugForm: drugForm ?? this.drugForm,
      method: method ?? this.method,
      frequency: frequency ?? this.frequency,
      courseDays: courseDays ?? this.courseDays,
      withdrawalDays: withdrawalDays ?? this.withdrawalDays,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      contraindications: contraindications ?? this.contraindications,
      sideEffects: sideEffects ?? this.sideEffects,
      hasDosage: hasDosage ?? this.hasDosage,
      hasResult: hasResult ?? this.hasResult,
      isFixedDose: isFixedDose ?? this.isFixedDose,
      fixedDoseText: fixedDoseText ?? this.fixedDoseText,
      note: note ?? this.note,
      dosePerKg: dosePerKg ?? this.dosePerKg,
      doseMin: doseMin ?? this.doseMin,
      doseMax: doseMax ?? this.doseMax,
      doseUnit: doseUnit ?? this.doseUnit,
      weight: weight ?? this.weight,
      concentration: concentration ?? this.concentration,
    );
  }
}

/// Болезнь (contagious + non-contagious)
class Disease {
  final int id;
  final String name;
  final String code;
  final String category;
  final List<String> animals;
  final String description;
  final String symptoms;
  final bool isContagious;

  const Disease({
    required this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.animals,
    this.description = '',
    this.symptoms = '',
    this.isContagious = true,
  });

  /// Русское название категории
  String get categoryRu {
    switch (category) {
      case 'particularly_dangerous':
        return 'Особо опасные';
      case 'infectious':
        return 'Инфекционные';
      case 'non_contagious':
        return 'Незаразные';
      case 'parasitic':
        return 'Паразитарные';
      default:
        return category;
    }
  }

  factory Disease.fromJson(Map<String, dynamic> json, {bool isContagious = true}) {
    return Disease(
      id: CalcDrug._parseInt(json['id'], 0),
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      category: json['category'] as String? ?? '',
      animals: (json['animals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      description: json['description'] as String? ?? '',
      symptoms: json['symptoms'] as String? ?? '',
      isContagious: isContagious,
    );
  }
}

/// Взаимодействие препаратов
/// Schema: { drug1, drug2, severity, effect, consequence, recommendation }
class DrugInteraction {
  final String drug1;
  final String drug2;
  final String severity;        // critical | warning | moderate | info
  final String effect;
  final String consequence;
  final String recommendation;

  const DrugInteraction({
    required this.drug1,
    required this.drug2,
    this.severity = 'moderate',
    this.effect = '',
    this.consequence = '',
    this.recommendation = '',
  });

  /// Человекочитаемое название тяжести
  String get severityRu {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'Критично';
      case 'warning':
        return 'Предупреждение';
      case 'moderate':
        return 'Умеренное';
      case 'info':
        return 'Информация';
      default:
        return severity;
    }
  }

  /// Цвет для UI (название цвета в Material)
  String get severityColor {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'red';
      case 'warning':
        return 'orange';
      case 'moderate':
        return 'amber';
      case 'info':
        return 'blue';
      default:
        return 'grey';
    }
  }

  factory DrugInteraction.fromJson(Map<String, dynamic> json) {
    return DrugInteraction(
      drug1: json['drug1'] as String? ?? '',
      drug2: json['drug2'] as String? ?? '',
      severity: json['severity'] as String? ?? 'moderate',
      effect: json['effect'] as String? ?? '',
      consequence: json['consequence'] as String? ?? '',
      recommendation: json['recommendation'] as String? ?? '',
    );
  }
}

/// Антидот при отравлении
/// Schema: { toxin, common_names, symptoms, antidote, antidote_dose, alternative, notes, prognosis }
class Antidote {
  final String toxin;
  final List<String> commonNames;
  final List<String> symptoms;
  final String antidote;
  final String antidoteDose;
  final String alternative;
  final String notes;
  final String prognosis;

  const Antidote({
    required this.toxin,
    this.commonNames = const [],
    this.symptoms = const [],
    required this.antidote,
    this.antidoteDose = '',
    this.alternative = '',
    this.notes = '',
    this.prognosis = '',
  });

  factory Antidote.fromJson(Map<String, dynamic> json) {
    return Antidote(
      toxin: json['toxin'] as String? ?? '',
      commonNames: (json['common_names'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      symptoms: (json['symptoms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      antidote: json['antidote'] as String? ?? '',
      antidoteDose: json['antidote_dose'] as String? ?? '',
      alternative: json['alternative'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      prognosis: json['prognosis'] as String? ?? '',
    );
  }
}

/// Препарат в протоколе лечения
class ProtocolDrug {
  final String name;
  final String inn;
  final String dose;
  final String route;
  final String frequency;
  final String duration;
  final String pharmGroup;
  final String waitingPeriod;

  const ProtocolDrug({
    this.name = '',
    this.inn = '',
    this.dose = '',
    this.route = '',
    this.frequency = '',
    this.duration = '',
    this.pharmGroup = '',
    this.waitingPeriod = '',
  });

  factory ProtocolDrug.fromJson(Map<String, dynamic> json) {
    return ProtocolDrug(
      name: json['name'] as String? ?? '',
      inn: json['inn'] as String? ?? '',
      dose: json['dose']?.toString() ?? '',
      route: json['route'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      duration: json['duration']?.toString() ?? '',
      pharmGroup: json['pharm_group'] as String? ?? '',
      waitingPeriod: json['waiting_period'] as String? ?? '',
    );
  }
}

/// Ярус лечения (primary / secondary / supportive / symptomatic)
class TreatmentTier {
  final List<ProtocolDrug> drugs;
  final String notes;

  const TreatmentTier({
    this.drugs = const [],
    this.notes = '',
  });

  factory TreatmentTier.fromJson(Map<String, dynamic> json) {
    final drugsRaw = json['drugs'];
    List<ProtocolDrug> drugs = [];
    if (drugsRaw is List) {
      drugs = drugsRaw
          .whereType<Map<String, dynamic>>()
          .map((d) => ProtocolDrug.fromJson(d))
          .where((d) => d.name.isNotEmpty)
          .toList();
    }
    return TreatmentTier(
      drugs: drugs,
      notes: json['notes']?.toString() ?? '',
    );
  }
}

/// Протокол лечения болезни
/// Schema (treatment_protocols.json): { disease_id, diagnosis, code, category,
///   category_name, species, pathogen_type, severity, order_number,
///   treatment: { primary, secondary, supportive, symptomatic }, notes, warnings }
class TreatmentProtocol {
  final int diseaseId;
  final String diagnosis;
  final String code;
  final String category;
  final String categoryName;
  final List<String> species;
  final String pathogenType;
  final String severity;
  final String orderNumber;
  final Map<String, TreatmentTier> treatment; // 'primary', 'supportive', etc.
  final String notes;
  final String warnings;

  const TreatmentProtocol({
    this.diseaseId = 0,
    required this.diagnosis,
    required this.code,
    this.category = '',
    this.categoryName = '',
    this.species = const [],
    this.pathogenType = '',
    this.severity = '',
    this.orderNumber = '',
    this.treatment = const {},
    this.notes = '',
    this.warnings = '',
  });

  /// Все препараты из всех ярусов одним списком
  List<ProtocolDrug> get allDrugs {
    final all = <ProtocolDrug>[];
    for (final tier in treatment.values) {
      all.addAll(tier.drugs);
    }
    return all;
  }

  /// Список ярусов с названиями (primary, supportive, ...)
  List<MapEntry<String, TreatmentTier>> get sortedTiers {
    const order = ['primary', 'secondary', 'supportive', 'symptomatic'];
    final sorted = <MapEntry<String, TreatmentTier>>[];
    for (final name in order) {
      final t = treatment[name];
      if (t != null && (t.drugs.isNotEmpty || t.notes.isNotEmpty)) {
        sorted.add(MapEntry(name, t));
      }
    }
    // Add any other tiers not in the standard order
    for (final entry in treatment.entries) {
      if (!order.contains(entry.key) &&
          (entry.value.drugs.isNotEmpty || entry.value.notes.isNotEmpty)) {
        sorted.add(entry);
      }
    }
    return sorted;
  }

  factory TreatmentProtocol.fromJson(Map<String, dynamic> json) {
    final treatmentRaw = json['treatment'];
    final treatment = <String, TreatmentTier>{};
    if (treatmentRaw is Map<String, dynamic>) {
      treatmentRaw.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          final tier = TreatmentTier.fromJson(value);
          if (tier.drugs.isNotEmpty || tier.notes.isNotEmpty) {
            treatment[key] = tier;
          }
        }
      });
    }
    return TreatmentProtocol(
      diseaseId: CalcDrug._parseInt(json['disease_id'], 0),
      diagnosis: json['diagnosis'] as String? ?? '',
      code: json['code'] as String? ?? '',
      category: json['category'] as String? ?? '',
      categoryName: json['category_name'] as String? ?? '',
      species: (json['species'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      pathogenType: json['pathogen_type'] as String? ?? '',
      severity: json['severity'] as String? ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      treatment: treatment,
      notes: json['notes']?.toString() ?? '',
      warnings: json['warnings']?.toString() ?? '',
    );
  }
}

/// Экстренный протокол
/// Schema (emergency_protocols.json): { name, code, indication, algorithm, drugs, monitoring, termination }
class EmergencyProtocol {
  final String name;
  final String code;
  final String indication;
  final List<EmergencyStep> algorithm;
  final List<EmergencyDrug> drugs;
  final List<String> monitoring;
  final String termination;

  const EmergencyProtocol({
    required this.name,
    this.code = '',
    this.indication = '',
    this.algorithm = const [],
    this.drugs = const [],
    this.monitoring = const [],
    this.termination = '',
  });

  factory EmergencyProtocol.fromJson(Map<String, dynamic> json) {
    return EmergencyProtocol(
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      indication: json['indication'] as String? ?? '',
      algorithm: (json['algorithm'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(EmergencyStep.fromJson)
              .toList() ?? [],
      drugs: (json['drugs'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(EmergencyDrug.fromJson)
              .toList() ?? [],
      monitoring: (json['monitoring'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      termination: json['termination'] as String? ?? '',
    );
  }
}

class EmergencyStep {
  final int step;
  final String action;
  final String detail;

  const EmergencyStep({
    this.step = 0,
    this.action = '',
    this.detail = '',
  });

  factory EmergencyStep.fromJson(Map<String, dynamic> json) {
    return EmergencyStep(
      step: CalcDrug._parseInt(json['step'], 0),
      action: json['action'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }
}

class EmergencyDrug {
  final String drug;
  final String dose;
  final String route;
  final String frequency;

  const EmergencyDrug({
    this.drug = '',
    this.dose = '',
    this.route = '',
    this.frequency = '',
  });

  factory EmergencyDrug.fromJson(Map<String, dynamic> json) {
    return EmergencyDrug(
      drug: json['drug'] as String? ?? '',
      dose: json['dose'] as String? ?? '',
      route: json['route'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
    );
  }
}

/// Побочный эффект препарата
/// Schema (side_effects.json): { drug, side_effects: [{ effect, age?, dose?, condition?, frequency?, action }], monitoring }
class SideEffectEntry {
  final String drugName;
  final List<SideEffectItem> effects;
  final String monitoring;

  const SideEffectEntry({
    required this.drugName,
    this.effects = const [],
    this.monitoring = '',
  });

  factory SideEffectEntry.fromJson(Map<String, dynamic> json) {
    return SideEffectEntry(
      drugName: json['drug'] as String? ?? '',
      effects: (json['side_effects'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(SideEffectItem.fromJson)
              .toList() ?? [],
      monitoring: json['monitoring'] as String? ?? '',
    );
  }
}

class SideEffectItem {
  final String effect;
  final String age;
  final String dose;
  final String condition;
  final String frequency;
  final String action;

  const SideEffectItem({
    this.effect = '',
    this.age = '',
    this.dose = '',
    this.condition = '',
    this.frequency = '',
    this.action = '',
  });

  factory SideEffectItem.fromJson(Map<String, dynamic> json) {
    return SideEffectItem(
      effect: json['effect'] as String? ?? '',
      age: json['age'] as String? ?? '',
      dose: json['dose'] as String? ?? '',
      condition: json['condition'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      action: json['action'] as String? ?? '',
    );
  }
}

/// Жидкостная терапия — формула
/// Schema (fluid_therapy.json): { formulas: [{ name, formula, dehydration_levels, example }] }
class FluidFormula {
  final String name;
  final String formula;
  final Map<String, DehydrationLevel> dehydrationLevels;
  final String example;

  const FluidFormula({
    this.name = '',
    this.formula = '',
    this.dehydrationLevels = const {},
    this.example = '',
  });

  factory FluidFormula.fromJson(Map<String, dynamic> json) {
    final dh = <String, DehydrationLevel>{};
    final dhRaw = json['dehydration_levels'];
    if (dhRaw is Map<String, dynamic>) {
      dhRaw.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          dh[k] = DehydrationLevel.fromJson(v);
        }
      });
    }
    return FluidFormula(
      name: json['name'] as String? ?? '',
      formula: json['formula'] as String? ?? '',
      dehydrationLevels: dh,
      example: json['example'] as String? ?? '',
    );
  }
}

class DehydrationLevel {
  final int percent;
  final String signs;

  const DehydrationLevel({
    this.percent = 0,
    this.signs = '',
  });

  factory DehydrationLevel.fromJson(Map<String, dynamic> json) {
    return DehydrationLevel(
      percent: CalcDrug._parseInt(json['percent'], 0),
      signs: json['signs'] as String? ?? '',
    );
  }
}

/// Период ожидания для препарата
/// Schema (withdrawal_by_product.json): { inn, products: { animal: { meat, milk, eggs } }, notes }
class WithdrawalInfo {
  final String inn;
  final Map<String, WithdrawalProduct> products;
  final String notes;

  const WithdrawalInfo({
    required this.inn,
    this.products = const {},
    this.notes = '',
  });

  factory WithdrawalInfo.fromJson(Map<String, dynamic> json) {
    final products = <String, WithdrawalProduct>{};
    final pRaw = json['products'];
    if (pRaw is Map<String, dynamic>) {
      pRaw.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          products[k] = WithdrawalProduct.fromJson(v);
        }
      });
    }
    return WithdrawalInfo(
      inn: json['inn'] as String? ?? '',
      products: products,
      notes: json['notes'] as String? ?? '',
    );
  }
}

class WithdrawalProduct {
  /// meat — int (days) or string (e.g. "НЕ ПРИМЕНЯТЬ")
  final dynamic meat;
  final dynamic milk;
  final dynamic eggs;

  const WithdrawalProduct({
    this.meat,
    this.milk,
    this.eggs,
  });

  factory WithdrawalProduct.fromJson(Map<String, dynamic> json) {
    return WithdrawalProduct(
      meat: json['meat'],
      milk: json['milk'],
      eggs: json['eggs'],
    );
  }

  String get meatLabel {
    if (meat == null) return '—';
    if (meat is int) return '$meat сут';
    return meat.toString();
  }

  String get milkLabel {
    if (milk == null) return '—';
    if (milk is int) return '$milk сут';
    return milk.toString();
  }

  String get eggsLabel {
    if (eggs == null) return '—';
    if (eggs is int) return '$eggs сут';
    return eggs.toString();
  }
}

/// Коррекция дозы
/// Schema (dose_adjustments.json): { age_adjustments, renal_adjustment, hepatic_adjustment,
///   cardiac_adjustment, pregnancy_lactation }
class DoseAdjustment {
  final String description;
  final List<String> issues;
  final String generalRule;
  final List<String> drugsCareful;
  final List<String> monitoring;
  final Map<String, dynamic> raw;

  const DoseAdjustment({
    this.description = '',
    this.issues = const [],
    this.generalRule = '',
    this.drugsCareful = const [],
    this.monitoring = const [],
    this.raw = const {},
  });

  factory DoseAdjustment.fromJson(Map<String, dynamic> json) {
    return DoseAdjustment(
      description: json['description'] as String? ?? '',
      issues: (json['issues'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      generalRule: json['general_rule'] as String? ?? '',
      drugsCareful: (json['drugs_careful'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      monitoring: (json['monitoring'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      raw: json,
    );
  }
}

/// Эталонная дозировка из verified_dosages.json
class VerifiedDosage {
  final String drugName;
  final String inn;
  final dynamic concentration;
  final String concentrationUnit;
  final String form;
  final List<String> animals;
  final Map<String, AnimalSpecificDosage> animalSpecific;
  final String source;
  final String url;
  final List<String> warnings;
  final Map<String, dynamic> contraindications;

  const VerifiedDosage({
    required this.drugName,
    this.inn = '',
    this.concentration,
    this.concentrationUnit = 'мг/мл',
    this.form = '',
    this.animals = const [],
    this.animalSpecific = const {},
    this.source = '',
    this.url = '',
    this.warnings = const [],
    this.contraindications = const {},
  });

  factory VerifiedDosage.fromJson(String name, Map<String, dynamic> json) {
    final specific = <String, AnimalSpecificDosage>{};
    final spRaw = json['animal_specific'];
    if (spRaw is Map<String, dynamic>) {
      spRaw.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          specific[k] = AnimalSpecificDosage.fromJson(v);
        }
      });
    }
    final contra = json['contraindications'];
    final warnings = <String>[];
    if (contra is Map<String, dynamic>) {
      final w = contra['warnings'];
      if (w is List) {
        warnings.addAll(w.map((e) => e.toString()));
      }
    }
    final ws = json['_warnings'];
    if (ws is List) {
      warnings.addAll(ws.map((e) => e.toString()));
    }
    return VerifiedDosage(
      drugName: name,
      inn: json['inn'] as String? ?? '',
      concentration: json['concentration'],
      concentrationUnit: json['concentration_unit'] as String? ?? 'мг/мл',
      form: json['form'] as String? ?? '',
      animals: (json['animals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      animalSpecific: specific,
      source: json['_source'] as String? ?? '',
      url: json['_url'] as String? ?? '',
      warnings: warnings,
      contraindications: contra is Map<String, dynamic> ? contra : {},
    );
  }
}

/// Чат-сообщение для AI-ассистента
class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final List<SourceReference>? sources;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.sources,
  });
}

/// Ссылка на источник в RAG
class SourceReference {
  final String title;
  final String url;
  final String snippet;

  const SourceReference({
    required this.title,
    this.url = '',
    this.snippet = '',
  });
}

/// Запись истории расчёта дозы.
/// Сохраняется в SharedPreferences (до 50 записей).
class HistoryEntry {
  final String drugName;
  final String animalName;
  final double weight;
  final double volume;
  final String unit;
  final String method;
  final DateTime timestamp;

  const HistoryEntry({
    required this.drugName,
    required this.animalName,
    required this.weight,
    required this.volume,
    required this.unit,
    required this.method,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'drugName': drugName,
    'animalName': animalName,
    'weight': weight,
    'volume': volume,
    'unit': unit,
    'method': method,
    'timestamp': timestamp.toIso8601String(),
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    drugName: json['drugName'] as String? ?? '',
    animalName: json['animalName'] as String? ?? '',
    weight: (json['weight'] as num?)?.toDouble() ?? 0,
    volume: (json['volume'] as num?)?.toDouble() ?? 0,
    unit: json['unit'] as String? ?? 'мл',
    method: json['method'] as String? ?? '',
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
  );
}
