import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../models/drug_models.dart';
import '../services/glm_ai_service.dart';

/// Провайдер AI-ассистента с RAG.
///
/// Стратегия запроса (по убыванию приоритета):
///   1. Локальный FastAPI сервер (`/v1/rag/search`) — если запущен, использует
///      локальный KB (12 024 чанков) и автоматически обновляет chatId из /etc/.z-ai-config.
///   2. HF Space Gradio API (`shrayyyy-vetderm-ai.hf.space`) — удалённый RAG,
///      запасной вариант если FastAPI не запущен.
///   3. Прямой GLM без RAG — финальный fallback, отвечает на основе общих знаний.
class AiProvider extends ChangeNotifier {
  final GlmAiService _aiService = GlmAiService();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String _error = '';
  String _lastSource = '';   // 'local' | 'hf_space' | 'direct_glm'

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String get error => _error;
  String get lastSource => _lastSource;

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

      // 1) Try local FastAPI server first
      answer = await _askLocalFastApi(content);
      if (answer != null && answer.isNotEmpty) {
        source = 'local';
      }

      // 2) Fallback to HF Space Gradio API
      if (answer == null || answer.isEmpty) {
        answer = await _askRagViaHfSpace(content);
        if (answer != null && answer.isNotEmpty) {
          source = 'hf_space';
        }
      }

      // 3) Final fallback: direct GLM without RAG
      if (answer == null || answer.isEmpty) {
        answer = await _aiService.askWithRag(
          question: content,
          ragContext: null,
        );
        source = 'direct_glm';
      }

      _lastSource = source;

      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: answer,
        isUser: false,
        timestamp: DateTime.now(),
        sources: source == 'local' || source == 'hf_space'
            ? [SourceReference(title: 'Источник: $source', snippet: 'RAG context used')]
            : null,
      ));
    } catch (e) {
      _error = 'Ошибка: $e';
      debugPrint('AI Provider error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Запрос к локальному FastAPI серверу (`/v1/rag/search`).
  /// Сервер использует локальный KB (12 024 чанков) и сам ходит в Z AI с chatId из /etc/.z-ai-config.
  Future<String?> _askLocalFastApi(String query) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.localApiUrl}${ApiConfig.localApiPath}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query, 'top_k': 5}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('Local FastAPI returned ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final context = data['context'] as String?;
      if (context == null || context.isEmpty) {
        return null;
      }

      // Now use the local context to ask GLM directly
      final aiResponse = await _aiService.askWithRag(
        question: query,
        ragContext: context,
      );
      return aiResponse;
    } catch (e) {
      debugPrint('Local FastAPI error (likely not running): $e');
      return null;
    }
  }

  /// Запрос к RAG через HF Space Gradio API (текстовый — надёжный)
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

      // Шаг 2: Получить результат
      final resultResponse = await http.get(
        Uri.parse('${ApiConfig.hfSpaceUrl}${ApiConfig.ragApiPath}/$eventId'),
      ).timeout(const Duration(seconds: 90));

      if (resultResponse.statusCode != 200) {
        debugPrint('RAG API GET failed: ${resultResponse.statusCode}');
        return null;
      }

      // Шаг 3: Парсим SSE
      final body = resultResponse.body;
      final dataMatch = RegExp(r'data:\s*(.+)').firstMatch(body);
      if (dataMatch == null) {
        debugPrint('RAG API: no data in SSE');
        return null;
      }

      final resultData = jsonDecode(dataMatch.group(1)!) as List<dynamic>;
      if (resultData.isNotEmpty) {
        return resultData[0] as String;
      }
      return null;
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
}
