import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/drug_models.dart';
import '../services/glm_ai_service.dart';
import '../services/backend_rag_service.dart';

/// Провайдер AI-ассистента с RAG.
///
/// Стратегия запроса:
///   1. HF Space Gradio API (`shrayyyy-vetderm-ai.hf.space`) — Space сам
///      вызывает GLM с RAG-контекстом и возвращает финальный ответ.
///      ВАЖНО: НЕ отправлять этот ответ повторно в GLM!
///   2. Прямой GLM без RAG (glm_ai_service.dart) — финальный fallback.
///
/// Локальный FastAPI убран: на реальном телефоне `http://10.0.2.2:7860`
/// не резолвится (это IP для эмулятора). Когда задеплоим FastAPI на
/// публичный URL — добавим обратно как primary.
class AiProvider extends ChangeNotifier {
  final GlmAiService _aiService = GlmAiService();
  final BackendRagService _backend = BackendRagService();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String _error = '';
  String _lastSource = '';   // 'hf_space' | 'direct_glm' | 'cache'

  // ─── Offline cache ────────────────────────────────────────────────
  // Last 20 Q&A pairs saved in SharedPreferences for offline access.
  static const _cacheKey = 'rag_cache';
  static const _maxCache = 20;
  final Map<String, String> _cache = {}; // query → answer

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String get error => _error;
  String get lastSource => _lastSource;

  static const String _ragSystemPrompt = '''Ты — ветеринарный AI-ассистент VetEco. Отвечай на русском языке, профессионально, но понятно.

Правила:
1. Давай точные, научно обоснованные ответы.
2. Указывай дозировки в мг/кг с путём введения.
3. Предупреждай о противопоказаниях и взаимодействиях.
4. Если не уверен — говори прямо.
5. Опирайся на предоставленный RAG-контекст и указывай источники.
6. Каждый ответ с дозировкой завершай дисклеймером: это AI-ассистированный расчёт, подтвердите у ветеринара.''';

  AiProvider() {
    _loadCache();
  }

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_cacheKey);
    if (json != null) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        _cache.addAll(map.cast<String, String>());
      } catch (_) {}
    }
  }

  Future<void> _saveToCache(String query, String answer) async {
    _cache[query.toLowerCase().trim()] = answer;
    // Trim to max entries
    if (_cache.length > _maxCache) {
      final keys = _cache.keys.toList();
      for (final k in keys.sublist(0, _cache.length - _maxCache)) {
        _cache.remove(k);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(_cache));
  }

  String? _getFromCache(String query) {
    return _cache[query.toLowerCase().trim()];
  }

  /// Отправить вопрос AI-ассистенту
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    _messages.add(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    ));
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      String? answer;
      String source = '';

      // 0) Primary: VetEco FastAPI backend (RAG-контекст на стороне сервера).
      if (await _aiService.hasApiKey()) {
        final apiKey = await _aiService._getApiKey();
        answer = await _backend.chatWithRag(
          message: content,
          systemPrompt: _ragSystemPrompt,
          apiKey: apiKey,
        );
        if (answer != null && answer.isNotEmpty) {
          source = 'backend_rag';
          _saveToCache(content, answer);
        }
      }

      // 1) Fallback: прямой GLM через Z.AI (без RAG-контекста).
      if (answer == null || answer.isEmpty) {
        answer = await _aiService.askWithRag(question: content, ragContext: null);
        if (answer != null && answer.isNotEmpty) {
          source = 'direct_glm';
          _saveToCache(content, answer);
        }
      }

      // 2) Last resort: offline cache.
      if (answer == null || answer.isEmpty) {
        final cached = _getFromCache(content);
        if (cached != null) {
          answer = '$cached\n\n⚠️ Ответ из офлайн-кэша.';
          source = 'cache';
        }
      }

      _lastSource = source;

      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: answer ?? 'Не удалось получить ответ.',
        isUser: false,
        timestamp: DateTime.now(),
        sources: source == 'hf_space'
            ? [SourceReference(title: 'Источник: RAG + GLM', snippet: 'Ветеринарная база знаний')]
            : null,
      ));
    } catch (e) {
      _error = 'Ошибка: $e';
      debugPrint('AI Provider error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Запрос к RAG через VetEco FastAPI backend.
  ///
  /// DEPRECATED: ранее использовался хрупкий Gradio HF Space API
  /// (event_id + SSE-поллинг). Теперь RAG-поиск идёт через
  /// [BackendRagService] (см. sendMessage). Этот метод оставлен пустым
  /// для обратной совместимости и будет удалён в следующем рефакторе.
  @Deprecated('Use BackendRagService instead')
  Future<String?> _askRagViaHfSpace(String query) async => null;

  /// Очистить историю чата
  void clearChat() {
    _messages.clear();
    _error = '';
    _lastSource = '';
    notifyListeners();
  }
}
