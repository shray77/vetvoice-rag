import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../models/drug_models.dart';
import '../services/glm_ai_service.dart';

/// Провайдер AI-ассистента с RAG
/// Стратегия: сначала RAG через HF Space (текстовый API, надёжный),
/// fallback на прямой GLM без RAG
class AiProvider extends ChangeNotifier {
  final GlmAiService _aiService = GlmAiService();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String _error = '';

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String get error => _error;

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
      // Сначала пробуем RAG через HF Space
      String? ragAnswer = await _askRagViaHfSpace(content);
      if (ragAnswer != null && ragAnswer.isNotEmpty) {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: ragAnswer,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      } else {
        // Fallback на прямой GLM
        final response = await _aiService.askWithRag(
          question: content,
          ragContext: null,
        );

        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      _error = 'Ошибка: $e';
      debugPrint('AI Provider error: $e');
    }

    _isLoading = false;
    notifyListeners();
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
    notifyListeners();
  }
}
