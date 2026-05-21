/// Структурированная ветеринарная запись (SOAP-формат)
/// Надиктовал → AI разобрал → заполнил поля автоматически
class VetRecord {
  final String id;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // === Идентификация животного ===
  final String animalType;       // корова, собака, кошка...
  final String? animalBreed;     // порода
  final double? animalWeight;    // вес в кг
  final int? animalAge;          // возраст в месяцах
  final String? animalAgeUnit;   // месяцев / лет
  final String? animalGender;    // пол: м/ж/кастрирован
  final String? animalId;        // бирка/чип/кличка

  // === S — Subjective (Субъективно) ===
  final String? complaint;       // жалоба владельца
  final String? anamnesis;       // анамнез

  // === O — Objective (Объективно) ===
  final double? temperature;     // температура °C
  final int? heartRate;          // ЧСС
  final int? respiratoryRate;    // ЧДД
  final String? physicalExam;    // клинический осмотр
  final String? mucousMembranes; // слизистые
  final String? lymphNodes;      // лимфоузлы
  final String? skinCoat;        // кожа/шерсть

  // === A — Assessment (Оценка) ===
  final String? diagnosis;       // диагноз
  final String? differentialDx;  // дифф. диагноз
  final String? diseaseSeverity; // тяжесть: лёгкая/средняя/тяжёлая

  // === P — Plan (План) ===
  final List<PrescribedDrug> prescribedDrugs; // назначенные препараты
  final String? procedures;      // процедуры
  final String? diet;            // диета/содержание
  final String? followUp;        // повторный приём
  final String? notes;           // доп. заметки

  // === Сырой текст (оригинал диктовки) ===
  final String? rawDictation;

  // === Статус ===
  final VetRecordStatus status;

  const VetRecord({
    required this.id,
    required this.createdAt,
    this.updatedAt,
    this.animalType = '',
    this.animalBreed,
    this.animalWeight,
    this.animalAge,
    this.animalAgeUnit,
    this.animalGender,
    this.animalId,
    this.complaint,
    this.anamnesis,
    this.temperature,
    this.heartRate,
    this.respiratoryRate,
    this.physicalExam,
    this.mucousMembranes,
    this.lymphNodes,
    this.skinCoat,
    this.diagnosis,
    this.differentialDx,
    this.diseaseSeverity,
    this.prescribedDrugs = const [],
    this.procedures,
    this.diet,
    this.followUp,
    this.notes,
    this.rawDictation,
    this.status = VetRecordStatus.draft,
  });

  /// Создать из JSON, который вернул GLM AI
  factory VetRecord.fromAiJson(Map<String, dynamic> json, {String? rawText}) {
    final drugs = <PrescribedDrug>[];
    if (json['prescribed_drugs'] != null) {
      for (final d in (json['prescribed_drugs'] as List<dynamic>)) {
        drugs.add(PrescribedDrug.fromJson(d as Map<String, dynamic>));
      }
    }

    return VetRecord(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      animalType: json['animal_type'] as String? ?? '',
      animalBreed: json['animal_breed'] as String?,
      animalWeight: (json['animal_weight'] as num?)?.toDouble(),
      animalAge: json['animal_age'] as int?,
      animalAgeUnit: json['animal_age_unit'] as String?,
      animalGender: json['animal_gender'] as String?,
      animalId: json['animal_id'] as String?,
      complaint: json['complaint'] as String?,
      anamnesis: json['anamnesis'] as String?,
      temperature: (json['temperature'] as num?)?.toDouble(),
      heartRate: json['heart_rate'] as int?,
      respiratoryRate: json['respiratory_rate'] as int?,
      physicalExam: json['physical_exam'] as String?,
      mucousMembranes: json['mucous_membranes'] as String?,
      lymphNodes: json['lymph_nodes'] as String?,
      skinCoat: json['skin_coat'] as String?,
      diagnosis: json['diagnosis'] as String?,
      differentialDx: json['differential_dx'] as String?,
      diseaseSeverity: json['disease_severity'] as String?,
      prescribedDrugs: drugs,
      procedures: json['procedures'] as String?,
      diet: json['diet'] as String?,
      followUp: json['follow_up'] as String?,
      notes: json['notes'] as String?,
      rawDictation: rawText,
      status: VetRecordStatus.parsed,
    );
  }

  /// Полная сериализация для локального хранения
  Map<String, dynamic> toJson() => {
    'id': id,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'animal_type': animalType,
    'animal_breed': animalBreed,
    'animal_weight': animalWeight,
    'animal_age': animalAge,
    'animal_age_unit': animalAgeUnit,
    'animal_gender': animalGender,
    'animal_id': animalId,
    'complaint': complaint,
    'anamnesis': anamnesis,
    'temperature': temperature,
    'heart_rate': heartRate,
    'respiratory_rate': respiratoryRate,
    'physical_exam': physicalExam,
    'mucous_membranes': mucousMembranes,
    'lymph_nodes': lymphNodes,
    'skin_coat': skinCoat,
    'diagnosis': diagnosis,
    'differential_dx': differentialDx,
    'disease_severity': diseaseSeverity,
    'prescribed_drugs': prescribedDrugs.map((d) => d.toJson()).toList(),
    'procedures': procedures,
    'diet': diet,
    'follow_up': followUp,
    'notes': notes,
    'raw_dictation': rawDictation,
    'status': status.name,
  };

  factory VetRecord.fromJson(Map<String, dynamic> json) {
    final drugs = <PrescribedDrug>[];
    if (json['prescribed_drugs'] != null) {
      for (final d in (json['prescribed_drugs'] as List<dynamic>)) {
        drugs.add(PrescribedDrug.fromJson(d as Map<String, dynamic>));
      }
    }

    return VetRecord(
      id: json['id'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      animalType: json['animal_type'] as String? ?? '',
      animalBreed: json['animal_breed'] as String?,
      animalWeight: (json['animal_weight'] as num?)?.toDouble(),
      animalAge: json['animal_age'] as int?,
      animalAgeUnit: json['animal_age_unit'] as String?,
      animalGender: json['animal_gender'] as String?,
      animalId: json['animal_id'] as String?,
      complaint: json['complaint'] as String?,
      anamnesis: json['anamnesis'] as String?,
      temperature: (json['temperature'] as num?)?.toDouble(),
      heartRate: json['heart_rate'] as int?,
      respiratoryRate: json['respiratory_rate'] as int?,
      physicalExam: json['physical_exam'] as String?,
      mucousMembranes: json['mucous_membranes'] as String?,
      lymphNodes: json['lymph_nodes'] as String?,
      skinCoat: json['skin_coat'] as String?,
      diagnosis: json['diagnosis'] as String?,
      differentialDx: json['differential_dx'] as String?,
      diseaseSeverity: json['disease_severity'] as String?,
      prescribedDrugs: drugs,
      procedures: json['procedures'] as String?,
      diet: json['diet'] as String?,
      followUp: json['follow_up'] as String?,
      notes: json['notes'] as String?,
      rawDictation: json['raw_dictation'] as String?,
      status: VetRecordStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => VetRecordStatus.draft,
      ),
    );
  }

  VetRecord copyWith({
    String? animalType,
    String? animalBreed,
    double? animalWeight,
    int? animalAge,
    String? animalAgeUnit,
    String? animalGender,
    String? animalId,
    String? complaint,
    String? anamnesis,
    double? temperature,
    int? heartRate,
    int? respiratoryRate,
    String? physicalExam,
    String? mucousMembranes,
    String? lymphNodes,
    String? skinCoat,
    String? diagnosis,
    String? differentialDx,
    String? diseaseSeverity,
    List<PrescribedDrug>? prescribedDrugs,
    String? procedures,
    String? diet,
    String? followUp,
    String? notes,
    String? rawDictation,
    VetRecordStatus? status,
  }) {
    return VetRecord(
      id: id,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      animalType: animalType ?? this.animalType,
      animalBreed: animalBreed ?? this.animalBreed,
      animalWeight: animalWeight ?? this.animalWeight,
      animalAge: animalAge ?? this.animalAge,
      animalAgeUnit: animalAgeUnit ?? this.animalAgeUnit,
      animalGender: animalGender ?? this.animalGender,
      animalId: animalId ?? this.animalId,
      complaint: complaint ?? this.complaint,
      anamnesis: anamnesis ?? this.anamnesis,
      temperature: temperature ?? this.temperature,
      heartRate: heartRate ?? this.heartRate,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      physicalExam: physicalExam ?? this.physicalExam,
      mucousMembranes: mucousMembranes ?? this.mucousMembranes,
      lymphNodes: lymphNodes ?? this.lymphNodes,
      skinCoat: skinCoat ?? this.skinCoat,
      diagnosis: diagnosis ?? this.diagnosis,
      differentialDx: differentialDx ?? this.differentialDx,
      diseaseSeverity: diseaseSeverity ?? this.diseaseSeverity,
      prescribedDrugs: prescribedDrugs ?? this.prescribedDrugs,
      procedures: procedures ?? this.procedures,
      diet: diet ?? this.diet,
      followUp: followUp ?? this.followUp,
      notes: notes ?? this.notes,
      rawDictation: rawDictation ?? this.rawDictation,
      status: status ?? this.status,
    );
  }

  /// Краткое описание для списка записей
  String get summary {
    final parts = <String>[];
    if (animalType.isNotEmpty) parts.add(animalType);
    if (animalId != null) parts.add(animalId!);
    if (diagnosis != null) parts.add('— $diagnosis');
    return parts.isEmpty ? 'Запись от ${_fmtDate(createdAt)}' : parts.join(' ');
  }

  /// Сколько полей заполнено (для индикатора полноты)
  int get filledFieldsCount {
    int count = 0;
    if (animalType.isNotEmpty) count++;
    if (animalBreed != null) count++;
    if (animalWeight != null) count++;
    if (animalAge != null) count++;
    if (complaint != null) count++;
    if (anamnesis != null) count++;
    if (temperature != null) count++;
    if (heartRate != null) count++;
    if (respiratoryRate != null) count++;
    if (physicalExam != null) count++;
    if (diagnosis != null) count++;
    if (differentialDx != null) count++;
    if (prescribedDrugs.isNotEmpty) count++;
    if (procedures != null) count++;
    if (followUp != null) count++;
    return count;
  }

  /// Всего заполняемых полей
  static const int totalFields = 15;

  /// Процент заполненности
  double get completeness => filledFieldsCount / totalFields;

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

/// Назначенный препарат в записи
class PrescribedDrug {
  final String name;           // название
  final String? inn;           // МНН
  final double? dosePerKg;     // мг/кг
  final double? totalDose;     // общая доза
  final String? doseUnit;      // единица
  final String? route;         // путь введения
  final String? frequency;     // кратность
  final int? durationDays;     // длительность курса
  final String? notes;         // заметки

  const PrescribedDrug({
    required this.name,
    this.inn,
    this.dosePerKg,
    this.totalDose,
    this.doseUnit,
    this.route,
    this.frequency,
    this.durationDays,
    this.notes,
  });

  factory PrescribedDrug.fromJson(Map<String, dynamic> json) => PrescribedDrug(
    name: json['name'] as String? ?? '',
    inn: json['inn'] as String?,
    dosePerKg: (json['dose_per_kg'] as num?)?.toDouble(),
    totalDose: (json['total_dose'] as num?)?.toDouble(),
    doseUnit: json['dose_unit'] as String?,
    route: json['route'] as String?,
    frequency: json['frequency'] as String?,
    durationDays: json['duration_days'] as int?,
    notes: json['notes'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'inn': inn,
    'dose_per_kg': dosePerKg,
    'total_dose': totalDose,
    'dose_unit': doseUnit,
    'route': route,
    'frequency': frequency,
    'duration_days': durationDays,
    'notes': notes,
  };

  /// Краткая строка назначения
  String get shortDescription {
    final parts = <String>[name];
    if (dosePerKg != null) parts.add('${dosePerKg} мг/кг');
    if (route != null) parts.add(route!);
    if (frequency != null) parts.add(frequency!);
    if (durationDays != null) parts.add('$durationDays дн.');
    return parts.join(', ');
  }
}

/// Статус записи
enum VetRecordStatus {
  draft,    // черновик (сырой текст, не разобран)
  parsed,   // разобран AI (поля заполнены)
  edited,   // отредактировано вручную
  saved,    // сохранено в локальную базу
}
