import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

/// VetEco FastAPI backend client.
///
/// Единый источник правды для RAG: наш FastAPI (src/api/app.py) отдаёт
/// чистые JSON-эндпоинты, в отличие от хрупкого Gradio HF Space API
/// (event_id + SSE-поллинг). Сюда идут запросы RAG-поиска и чата с RAG.
///
/// Base URL хранится в SharedPreferences (Settings). Если не задан —
/// берётся [ApiConfig.defaultBackendBaseUrl].
class BackendRagService {
  static final BackendRagService _instance = BackendRagService._internal();
  factory BackendRagService() => _instance;
  BackendRagService._internal();

  Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    // Читаем новый ключ, при отсутствии — старый (для обратной совместимости).
    final saved = prefs.getString(ApiConfig.backendBaseUrlPrefsKey) ??
        prefs.getString(ApiConfig.legacyBackendBaseUrlPrefsKey);
    return (saved != null && saved.trim().isNotEmpty)
        ? saved.trim().replaceAll(RegExp(r'/$'), '')
        : ApiConfig.defaultBackendBaseUrl;
  }

  Map<String, String> _headers(String? apiKey) => {
    'Content-Type': 'application/json',
    if (apiKey != null && apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
  };

  /// Прямой RAG-поиск по базе знаний. Возвращает отформатированный
  /// контекст (или null при ошибке/недоступности).
  Future<String?> fetchRagContext(String query, {String? apiKey}) async {
    try {
      final base = await _getBaseUrl();
      final response = await http
          .post(
            Uri.parse('$base${ApiConfig.backendRagSearchPath}'),
            headers: _headers(apiKey),
            body: jsonEncode({'query': query, 'top_k': 5}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugLog('Backend RAG search failed: ${response.statusCode}');
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data case {'context': final String ctx}) {
        return ctx.isNotEmpty ? ctx : null;
      }
      // Fallback: соберём контекст из results, если поле context отсутствует.
      final results = data['results'] as List<dynamic>?;
      if (results != null && results.isNotEmpty) {
        return results
            .map((r) => (r as Map<String, dynamic>)['content'] as String? ?? '')
            .where((c) => c.isNotEmpty)
            .join('\n\n');
      }
      return null;
    } on TimeoutException {
      debugLog('Backend RAG search timeout');
      return null;
    } catch (e) {
      debugLog('Backend RAG search error: $e');
      return null;
    }
  }

  /// Чат с RAG-контекстом. Бэкенд сам дополняет последнее сообщение
  /// контекстом из базы (use_rag=true). Возвращает текст ответа.
  Future<String?> chatWithRag({
    required String message,
    required String systemPrompt,
    String? apiKey,
    List<Map<String, String>>? history,
  }) async {
    try {
      final base = await _getBaseUrl();
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': systemPrompt},
        if (history != null) ...history,
        {'role': 'user', 'content': message},
      ];
      final response = await http
          .post(
            Uri.parse('$base${ApiConfig.backendChatPath}'),
            headers: _headers(apiKey),
            body: jsonEncode({
              'model': ApiConfig.glmModel,
              'messages': messages,
              'temperature': 0.3,
              'max_tokens': 2048,
              'thinking': {'type': 'disabled'},
              'use_rag': true,
              'rag_top_k': 5,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        debugLog('Backend chat failed: ${response.statusCode}');
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        return choices[0]['message']['content'] as String? ?? '';
      }
      return null;
    } on TimeoutException {
      debugLog('Backend chat timeout');
      return null;
    } catch (e) {
      debugLog('Backend chat error: $e');
      return null;
    }
  }
}

void debugLog(String msg) {
  // Лёгкое логирование без шума — можно заменить на debugPrint при необходимости.
  // ignore: avoid_print
  print('[BackendRagService] $msg');
}
