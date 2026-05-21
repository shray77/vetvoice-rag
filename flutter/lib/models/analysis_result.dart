class AnalysisResult {
  final String vlmAnalysis;
  final String diagnosis;
  final List<String> conditions;
  final String disclaimer;

  AnalysisResult({
    this.vlmAnalysis = '',
    this.diagnosis = '',
    this.conditions = const [],
    this.disclaimer = '',
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      vlmAnalysis: json['vlm_analysis'] ?? '',
      diagnosis: json['diagnosis'] ?? '',
      conditions: List<String>.from(json['conditions'] ?? []),
      disclaimer: json['disclaimer'] ?? '',
    );
  }

  String toShareText() {
    return '''VetVoice AI Analysis

$diagnosis

Conditions: ${conditions.join(', ')}

⚠️ $disclaimer''';
  }
}
