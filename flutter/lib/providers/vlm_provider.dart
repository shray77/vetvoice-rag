import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../services/glm_ai_service.dart';

/// Провайдер VLM (Vision Language Model) диагностики
/// Поддерживает два режима:
/// 1. HF Spaces Gradio API — основной (VLM + RAG)
/// 2. GLM-4V (fallback) — если HF Spaces недоступен
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

    // Авто-анализ при загрузке изображения
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

    // Авто-анализ при смене режима если есть изображение
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
      // Пробуем HF Spaces Gradio API первым
      final result = await _analyzeWithGradioApi();
      if (result != null) {
        _analysisResult = result;
        _modelUsed = 'GLM-4V + RAG (HF Space)';
        _isAnalyzing = false;
        notifyListeners();
        return;
      }

      // Fallback на GLM-4V напрямую
      final prompt = _modeToPrompt();
      final glmResult = await _aiService.analyzeImage(
        imageBase64: _imageBase64!,
        prompt: prompt,
      );
      _analysisResult = glmResult;
      _modelUsed = 'GLM-4V Flash';
    } catch (e) {
      _error = 'Ошибка анализа: $e';
    }

    _isAnalyzing = false;
    notifyListeners();
  }

  /// Запрос к HF Spaces Gradio API
  Future<String?> _analyzeWithGradioApi() async {
    try {
      // Gradio client API: POST /api/vlm_analyze
      // Using the Gradio queue-based API format
      final response = await http.post(
        Uri.parse('${ApiConfig.hfSpaceUrl}/call/vlm_analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': [
            'data:image/jpeg;base64,$_imageBase64',
            _modeToTask(),
          ],
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final eventId = data['event_id'] as String?;

        if (eventId != null) {
          // Poll for result
          final resultResponse = await http.get(
            Uri.parse('${ApiConfig.hfSpaceUrl}/call/vlm_analyze/$eventId'),
          ).timeout(const Duration(seconds: 120));

          if (resultResponse.statusCode == 200) {
            // SSE format: event: complete\ndata: [...]
            final body = resultResponse.body;
            final dataMatch = RegExp(r'data:\s*(.+)').firstMatch(body);
            if (dataMatch != null) {
              final resultData = jsonDecode(dataMatch.group(1)!) as List<dynamic>;
              if (resultData.isNotEmpty) {
                return resultData[0] as String;
              }
            }
          }
        }
      }

      debugPrint('Gradio API HTTP ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Gradio API error: $e');
      return null;
    }
  }

  /// Маппинг режима в промпт (для GLM-4V fallback)
  String _modeToPrompt() {
    return switch (_mode) {
      VlmAnalysisMode.diagnose =>
        'Опиши что ты видишь на этом изображении с ветеринарной точки зрения. Какой диагноз?',
      VlmAnalysisMode.describe =>
        'Детально опиши видимые поражения на изображении: характер, локализация, распространённость.',
      VlmAnalysisMode.severity =>
        'Оцени тяжесть видимого состояния: лёгкая, средняя или тяжёлая. Объясни почему.',
      VlmAnalysisMode.treatment =>
        'На основе видимого поражения, предложи подход к лечению. Укажи препараты и дозировки.',
      VlmAnalysisMode.skin =>
        'en What veterinary dermatological condition is visible? Provide the diagnosis and characteristics.',
    };
  }

  /// Маппинг режима в задачу для HF Space Gradio
  String _modeToTask() {
    return switch (_mode) {
      VlmAnalysisMode.diagnose => 'Диагноз',
      VlmAnalysisMode.describe => 'Описание',
      VlmAnalysisMode.severity => 'Тяжесть',
      VlmAnalysisMode.treatment => 'Лечение',
      VlmAnalysisMode.skin => 'Диагноз',
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
