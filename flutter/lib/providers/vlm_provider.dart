import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../services/glm_ai_service.dart';

/// Провайдер VLM (Vision Language Model) диагностики
/// Стратегия: GLM-4V напрямую + опциональный RAG контекст из HF Space
/// Это надёжнее чем Gradio API с файлами (который даёт 400 на изображениях)
class VlmProvider extends ChangeNotifier {
  final GlmAiService _aiService = GlmAiService();

  // Изображение
  String? _imageBase64;
  String? _imagePath;

  // Результат
  String _analysisResult = '';
  bool _isAnalyzing = false;
  String _error = '';

  // Режим анализа
  VlmAnalysisMode _mode = VlmAnalysisMode.diagnose;
  String _modelUsed = '';

  // Авто-анализ
  bool _autoAnalyze = true;

  String? get imageBase64 => _imageBase64;
  String? get imagePath => _imagePath;
  String get analysisResult => _analysisResult;
  bool get isAnalyzing => _isAnalyzing;
  String get error => _error;
  bool get hasImage => _imageBase64 != null;
  bool get hasResult => _analysisResult.isNotEmpty;
  VlmAnalysisMode get mode => _mode;
  String get modelUsed => _modelUsed;
  bool get autoAnalyze => _autoAnalyze;

  /// Установить изображение для анализа
  void setImage(String base64, {String? path}) {
    _imageBase64 = base64;
    _imagePath = path;
    _analysisResult = '';
    _error = '';
    _modelUsed = '';
    notifyListeners();

    if (_autoAnalyze) {
      analyzeImage();
    }
  }

  /// Включить/выключить авто-анализ
  void setAutoAnalyze(bool value) {
    _autoAnalyze = value;
    notifyListeners();
  }

  /// Выбрать режим анализа
  void setMode(VlmAnalysisMode newMode) {
    _mode = newMode;
    notifyListeners();

    if (_autoAnalyze && _imageBase64 != null && _analysisResult.isNotEmpty) {
      analyzeImage();
    }
  }

  /// Проанализировать изображение
  Future<void> analyzeImage() async {
    if (_imageBase64 == null) return;

    _isAnalyzing = true;
    _error = '';
    notifyListeners();

    try {
      // 1. Получаем RAG контекст (текстовый запрос, надёжный)
      String? ragContext = await _fetchRagContext();

      // 2. Вызываем GLM-4V напрямую с изображением + RAG контекст
      final prompt = _buildPrompt(ragContext: ragContext);
      final result = await _aiService.analyzeImage(
        imageBase64: _imageBase64!,
        prompt: prompt,
      );

      _analysisResult = result;
      _modelUsed = ragContext != null
          ? 'GLM-4V + RAG'
          : 'GLM-4V Flash';
    } catch (e) {
      _error = 'Ошибка анализа: $e';
      debugPrint('VLM error: $e');
    }

    _isAnalyzing = false;
    notifyListeners();
  }

  /// Получить RAG контекст из HF Space (текстовый запрос — надёжный)
  Future<String?> _fetchRagContext() async {
    try {
      // Шаг 1: Отправить запрос к RAG
      final response = await http.post(
        Uri.parse('${ApiConfig.hfSpaceUrl}${ApiConfig.ragApiPath}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': ['dermatology skin condition diagnosis'],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('RAG API step 1 failed: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final eventId = data['event_id'] as String?;
      if (eventId == null) {
        debugPrint('RAG API: no event_id');
        return null;
      }

      // Шаг 2: Получить результат по event_id
      final resultResponse = await http.get(
        Uri.parse('${ApiConfig.hfSpaceUrl}${ApiConfig.ragApiPath}/$eventId'),
      ).timeout(const Duration(seconds: 60));

      if (resultResponse.statusCode != 200) {
        debugPrint('RAG API step 2 failed: ${resultResponse.statusCode}');
        return null;
      }

      // Шаг 3: Парсим SSE ответ
      final body = resultResponse.body;
      final dataMatch = RegExp(r'data:\s*(.+)').firstMatch(body);
      if (dataMatch == null) {
        debugPrint('RAG API: no data in SSE response');
        return null;
      }

      final resultData = jsonDecode(dataMatch.group(1)!) as List<dynamic>;
      if (resultData.isEmpty) return null;

      final ragText = resultData[0] as String;
      if (ragText.isNotEmpty && ragText.length > 20) {
        // Обрезаем контекст чтобы не превысить лимит токенов
        return ragText.length > 3000 ? ragText.substring(0, 3000) : ragText;
      }
      return null;
    } catch (e) {
      debugPrint('RAG context fetch error: $e');
      return null;
    }
  }

  /// Построить промпт с учётом режима и RAG контекста
  String _buildPrompt({String? ragContext}) {
    final basePrompt = _modeToPrompt();
    if (ragContext != null && ragContext.isNotEmpty) {
      return '$basePrompt\n\n## Контекст из ветеринарной базы знаний:\n$ragContext\n\nИспользуй этот контекст для более точного анализа.';
    }
    return basePrompt;
  }

  /// Маппинг режима в промпт
  String _modeToPrompt() {
    return switch (_mode) {
      VlmAnalysisMode.diagnose =>
        '''You are a veterinary dermatologist examining a photo of an animal's skin condition. Provide analysis in Russian.

### First Analysis
- **Patient:** species, breed (if identifiable)
- **Lesion type:** primary + secondary lesions
- **Localization:** body regions
- **Pruritus:** present/absent, severity

### Differential Diagnosis (by probability)
1. **[Diagnosis]** — probability [%] — reasoning
2. **[Diagnosis]** — probability [%] — reasoning
3. **[Diagnosis]** — probability [%] — reasoning

### Recommended Diagnostic Tests
1. [Test] — purpose

### Treatment Recommendations
**Systemic therapy:** drug, dosage (мг/кг), route, duration
**Topical therapy:** drug, frequency, duration
**Monitoring:** what to check

Respond in Russian.
Add: Это AI-ассистированный анализ, не ветеринарный диагноз. Обратитесь к лицензированному ветеринару.''',
      VlmAnalysisMode.describe =>
        'Детально опиши видимые поражения на изображении: морфология, распределение, локализация. Используй ветеринарную терминологию. Отвечай на русском языке.',
      VlmAnalysisMode.severity =>
        'Оцени тяжесть видимого состояния: лёгкая, средняя или тяжёлая. Объясни почему. Укажи прогноз. Отвечай на русском языке.',
      VlmAnalysisMode.treatment =>
        'На основе видимого поражения, предложи подход к лечению. Укажи препараты, дозировки (мг/кг), путь введения, кратность, длительность. Отвечай на русском языке.',
      VlmAnalysisMode.skin =>
        'Определи ветеринарное дерматологическое заболевание на изображении. Укажи диагноз, характеристики, дифференциальный диагноз и лечение. Отвечай на русском языке.',
    };
  }

  /// Сброс
  void reset() {
    _imageBase64 = null;
    _imagePath = null;
    _analysisResult = '';
    _error = '';
    _modelUsed = '';
    notifyListeners();
  }
}

/// Режимы анализа VLM
enum VlmAnalysisMode {
  diagnose,   // Диагноз
  describe,   // Описание поражений
  severity,   // Оценка тяжести
  treatment,  // Рекомендации по лечению
  skin,       // Дерматология
}
