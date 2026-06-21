import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../models/drug_models.dart';
import '../services/glm_ai_service.dart';

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

      // 1) HF Space Gradio API — returns FINAL GLM answer (with RAG context).
      answer = await _askRagViaHfSpace(content);
      if (answer != null && answer.isNotEmpty) {
        source = 'hf_space';
        _saveToCache(content, answer);
      }

      // 2) Fallback: direct GLM without RAG context.
      if (answer == null || answer.isEmpty) {
        answer = await _aiService.askWithRag(
          question: content,
          ragContext: null,
        );
        source = 'direct_glm';
        if (answer.isNotEmpty) _saveToCache(content, answer);
      }

      // 3) Last resort: check offline cache.
      if (answer == null || answer.isEmpty) {
        final cached = _getFromCache(content);
        if (cached != null) {
          answer = '$cached\n\n⚠️ Ответ из офлайн-кэша (нет соединения с сервером).';
          source = 'cache';
        }
      }

      _lastSource = source;

      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: answer,
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

  /// Запрос к HF Space Gradio API.
  ///
  /// Space вызывает rag_search(query), который:
  ///   1. retrieve(query, top_k=5) → 5 чанков из векторной базы
  ///   2. format_context(results) → строка с metadata и content
  ///   3. GLM.generate_text(RAG_SYSTEM_PROMPT, user_msg_with_context) → финальный ответ
  ///   4. Возвращает этот финальный ответ.
  ///
  /// Поэтому НЕ нужно вызывать GLM ещё раз — просто возвращаем результат.
  Future<String?> _askRagViaHfSpace(String query) async {
    try {
      // Шаг 1: Отправить запрос
      final response = await http.post(
        Uri.parse('${ApiConfig.hfSpaceUrl}${ApiConfig.ragApiPath}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'data': [query]}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('RAG API POST failed: ${response.statusCode} ${response.body.substring(0, 200)}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final eventId = data['event_id'] as String?;
      if (eventId == null) {
        debugPrint('RAG API: no event_id in response');
        return null;
      }

      // Шаг 2: Получить результат (polling до 90 секунд)
      String? result;
      for (int attempt = 0; attempt < 6; attempt++) {
        await Future.delayed(const Duration(seconds: 5));
        final resultResponse = await http.get(
          Uri.parse('${ApiConfig.hfSpaceUrl}${ApiConfig.ragApiPath}/$eventId'),
        ).timeout(const Duration(seconds: 30));

        if (resultResponse.statusCode != 200) {
          debugPrint('RAG API GET failed (attempt $attempt): ${resultResponse.statusCode}');
          continue;
        }

        // Шаг 3: Парсим SSE
        final body = resultResponse.body;
        final dataMatch = RegExp(r'data:\s*(.+?)(?:\n|$)').firstMatch(body);
        if (dataMatch == null) {
          // SSE ещё не готов, ждём и пробуем снова
          continue;
        }

        final raw = dataMatch.group(1)!.trim();
        if (raw == '[true]') continue; // Gradio иногда шлёт heartbeat

        try {
          final resultData = jsonDecode(raw) as List<dynamic>;
          if (resultData.isNotEmpty) {
            result = resultData[0] as String?;
            if (result != null && result.isNotEmpty) break;
          }
        } catch (_) {
          continue;
        }
      }

      if (result == null || result.isEmpty) {
        debugPrint('RAG API: empty result after 6 attempts');
        return null;
      }

      // HF Space rag_search() возвращает ОДИН ИЗ ДВУХ вариантов:
      //
      // 1. Если GLM_API_KEY задан на Space: финальный ответ GLM (чистый текст)
      // 2. Если GLM_API_KEY НЕ задан: markdown-список найденных чанков с
      //    метаданными вида:
      //      ### [1] drugs_registry.json (релевантность: 0.28)
      //      **Заболевания:** энрофлоксацин
      //      <content text>
      //      ---
      //      ### [2] ...
      //
      // В случае (2) мы извлекаем только содержимое чанков (content),
      // отбрасывая метаданные и разделители. Затем отправляем этот
      // очищенный контекст в GLM для генерации финального ответа.
      result = _cleanRagResult(result);

      // Если результат — это markdown-список чанков (case 2), отправим
      // их в GLM как контекст для финального ответа.
      if (result.startsWith('=== RAG CHUNKS ===')) {
        final chunks = result.substring('=== RAG CHUNKS ==='.length).trim();
        if (chunks.isEmpty) return null;
        debugPrint('RAG: got raw chunks, sending to GLM as context');
        final glmAnswer = await _aiService.askWithRag(
          question: query,
          ragContext: chunks,
        );
        return glmAnswer;
      }

      return result;
    } catch (e) {
      debugPrint('RAG HF Space error: $e');
      return null;
    }
  }

  /// Очистить историю чата
  void clearChat() {
    _messages.clear();
    _error = '';
    _lastSource = '';
    notifyListeners();
  }

  /// Парсит результат HF Space rag_search().
  ///
  /// Если результат — markdown-список чанков (case 2, когда GLM не настроен
  /// на Space), извлекает только содержимое (content) каждого чанка,
  /// отбрасывая метаданные:
  ///   - `### [N] source.json (релевантность: X.XX)`
  ///   - `**Заболевания:** ...`
  ///   - `---` разделители
  ///
  /// Возвращает строку с префиксом `=== RAG CHUNKS ===` если это были
  /// сырые чанки, иначе возвращает исходную строку без изменений.
  String _cleanRagResult(String input) {
    final trimmed = input.trim();

    // Если начинается с "### [" — это markdown-список чанков
    if (!trimmed.startsWith('### [')) {
      return trimmed;
    }

    // Разбиваем по разделителю "---"
    final sections = trimmed.split(RegExp(r'\n---\n'));
    final chunks = <String>[];

    for (final section in sections) {
      final lines = section.trim().split('\n');
      final contentLines = <String>[];
      var skipMeta = true;

      for (final line in lines) {
        final t = line.trim();
        if (t.isEmpty) continue;

        // Пропускаем заголовки метаданных
        if (skipMeta) {
          if (t.startsWith('### [')) continue;       // ### [1] source.json (релевантность: ...)
          if (t.startsWith('**Заболевания:**')) continue;  // **Заболевания:** ...
          skipMeta = false; // следующие строки — content
        }
        contentLines.add(line);
      }

      if (contentLines.isNotEmpty) {
        chunks.add(contentLines.join('\n').trim());
      }
    }

    if (chunks.isEmpty) return trimmed;
    return '=== RAG CHUNKS ===\n${chunks.join('\n\n---\n\n')}';
  }
}
