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

  factory CalcDrug.fromJson(Map<String, dynamic> json) {
    Map<String, AnimalSpecificDosage>? specific;
    if (json['animal_specific'] != null) {
      specific = {};
      (json['animal_specific'] as Map<String, dynamic>).forEach((key, value) {
        specific![key] = AnimalSpecificDosage.fromJson(value as Map<String, dynamic>);
      });
    }

    return CalcDrug(
      id: json['id'] as int,
      name: json['name'] as String,
      inn: json['inn'] as String? ?? '',
      form: json['form'] as String? ?? '',
      formType: json['form_type'] as String? ?? 'injection',
      concentration: (json['concentration'] as num?)?.toDouble() ?? 0,
      concentrationUnit: json['concentration_unit'] as String? ?? 'мг/мл',
      unit: json['unit'] as String? ?? 'мл',
      dosePerKg: (json['dose_per_kg'] as num?)?.toDouble() ?? 0,
      doseMin: (json['dose_min'] as num?)?.toDouble() ?? 0,
      doseMax: (json['dose_max'] as num?)?.toDouble() ?? 0,
      doseUnit: json['dose_unit'] as String? ?? 'мг/кг',
      animals: (json['animals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      method: json['method'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      courseDays: json['course_days'] as String? ?? '',
      withdrawalDays: json['withdrawal_days'] as int? ?? 0,
      fixedDose: json['fixed_dose'],
      calculatorApplicable: json['calculator_applicable'] as bool? ?? true,
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
      dosePerKg: (json['dose_per_kg'] as num?)?.toDouble() ?? 0,
      doseMin: (json['dose_min'] as num?)?.toDouble() ?? 0,
      doseMax: (json['dose_max'] as num?)?.toDouble() ?? 0,
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
      id: json['id'] as int,
      tradeName: json['trade_name'] as String,
      inn: json['inn'] as String,
      form: json['form'] as String,
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
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      minWeight: (json['min_weight'] as num?)?.toDouble() ?? 0.1,
      maxWeight: (json['max_weight'] as num?)?.toDouble() ?? 2000,
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

/// Болезнь
class Disease {
  final String name;
  final String category;
  final List<String> animals;
  final String dangerLevel;
  final String description;
  final String symptoms;

  const Disease({
    required this.name,
    required this.category,
    required this.animals,
    this.dangerLevel = '',
    this.description = '',
    this.symptoms = '',
  });

  factory Disease.fromJson(Map<String, dynamic> json) {
    return Disease(
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      animals: (json['animals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      dangerLevel: json['danger_level'] as String? ?? '',
      description: json['description'] as String? ?? '',
      symptoms: json['symptoms'] as String? ?? '',
    );
  }
}

/// Взаимодействие препаратов
class DrugInteraction {
  final String drug1;
  final String drug2;
  final String severity;
  final String description;
  final String recommendation;

  const DrugInteraction({
    required this.drug1,
    required this.drug2,
    this.severity = 'moderate',
    this.description = '',
    this.recommendation = '',
  });

  factory DrugInteraction.fromJson(Map<String, dynamic> json) {
    return DrugInteraction(
      drug1: json['drug1'] as String? ?? '',
      drug2: json['drug2'] as String? ?? '',
      severity: json['severity'] as String? ?? 'moderate',
      description: json['description'] as String? ?? '',
      recommendation: json['recommendation'] as String? ?? '',
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
