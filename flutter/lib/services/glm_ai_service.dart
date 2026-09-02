import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../models/vet_record_model.dart';

/// Z AI Service — работает через публичный endpoint api.z.ai.
///
/// Нужен API key с https://z.ai/manage-apikey/apikey-list
/// Сохраняется в SharedPreferences, вводится в Settings.
///
/// Если API key не задан — методы возвращают пустую строку,
/// и AiProvider fallback на HF Space.
class GlmAiService {
  static final GlmAiService _instance = GlmAiService._internal();
  factory GlmAiService() => _instance;
  GlmAiService._internal();

  String? _apiKey;
  String? get apiKey => _apiKey;

  Future<String?> _getApiKey() async {
    if (_apiKey != null) return _apiKey;
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(ApiConfig.apiKeyPrefsKey);
    return _apiKey;
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConfig.apiKeyPrefsKey, key);
  }

  Future<bool> hasApiKey() async {
    final key = await _getApiKey();
    return key != null && key.isNotEmpty;
  }

  Map<String, String> _headers(String apiKey) => {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };

  /// Отправить чат-запрос через Z AI
  Future<String> chat({
    required String message,
    required String systemPrompt,
    List<Map<String, String>>? history,
  }) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) return '';

    try {
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': systemPrompt},
        if (history != null) ...history,
        {'role': 'user', 'content': message},
      ];

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.chatPath}'),
        headers: _headers(apiKey),
        body: jsonEncode({
          'model': await AppModels.selectedChatModel(),
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 2048,
          'thinking': {'type': 'disabled'},
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          return choices[0]['message']['content'] as String? ?? '';
        }
      }

      return 'Ошибка API: ${response.statusCode}';
    } on TimeoutException {
      return 'Ошибка: сервер не ответил за 30 сек.';
    } on SocketException catch (e) {
      return 'Ошибка сети: ${e.message}';
    } on HandshakeException {
      return 'Ошибка SSL.';
    } catch (e) {
      return 'Ошибка: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}';
    }
  }

  /// RAG-запрос с контекстом
  Future<String> askWithRag({
    required String question,
    String? ragContext,
  }) async {
    final systemPrompt = '''Ты — ветеринарный AI-ассистент VetEco. Отвечай на русском языке.

Правила:
1. Точные, научно обоснованные ответы
2. Дозировки в мг/кг с путём введения
3. Предупреждай о противопоказаниях
4. Если не уверен — скажи прямо

${ragContext != null ? 'Контекст из базы знаний:\n$ragContext' : ''}''';

    return chat(message: question, systemPrompt: systemPrompt);
  }

  /// Анализ изображения через Z AI Vision
  Future<String> analyzeImage({
    required String imageBase64,
    String? prompt,
  }) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) return 'Нет API key. Введите в настройках.';

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.chatPath}'),
        headers: _headers(apiKey),
        body: jsonEncode({
          'model': await AppModels.selectedVlmModel(),
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'}},
                {'type': 'text', 'text': prompt ?? 'Опиши изображение с ветеринарной точки зрения.'},
              ],
            },
          ],
          'temperature': 0.5,
          'max_tokens': 1024,
          'thinking': {'type': 'disabled'},
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          return choices[0]['message']['content'] as String? ?? '';
        }
      }

      return 'VLM ошибка: ${response.statusCode}';
    } on TimeoutException {
      return 'Ошибка: сервер не ответил за 60 сек.';
    } on SocketException catch (e) {
      return 'Ошибка сети: ${e.message}';
    } on HandshakeException {
      return 'Ошибка SSL.';
    } catch (e) {
      return 'Ошибка: $e';
    }
  }

  /// Парсинг ветеринарной диктовки в SOAP JSON
  Future<VetRecord> parseVetRecord(String dictationText) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Нет API key. Введите в настройках.');
    }

    const systemPrompt = '''Ты — ветеринарный AI, структурирующий клинические записи.
Ответь ТОЛЬКО валидным JSON (без markdown, без ```json).

Структура:
{
  "animal_type": "вид",
  "animal_breed": null,
  "animal_weight": null,
  "animal_age": null,
  "animal_age_unit": "лет",
  "animal_gender": null,
  "animal_id": null,
  "complaint": "жалоба",
  "anamnesis": "анамнез",
  "temperature": null,
  "heart_rate": null,
  "respiratory_rate": null,
  "physical_exam": "осмотр",
  "mucous_membranes": null,
  "lymph_nodes": null,
  "skin_coat": null,
  "diagnosis": "диагноз",
  "differential_dx": null,
  "disease_severity": null,
  "prescribed_drugs": [],
  "procedures": null,
  "diet": null,
  "follow_up": null,
  "notes": null
}

Правила:
1. null если не упомянуто
2. Дозировки точно как сказал врач
3. Температура в °C (число)
4. Диагноз кратко
5. Препараты в массив prescribed_drugs
6. Текст на русском''';

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.chatPath}'),
        headers: _headers(apiKey),
        body: jsonEncode({
          'model': await AppModels.selectedChatModel(),
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': dictationText},
          ],
          'temperature': 0.2,
          'max_tokens': 2048,
          'thinking': {'type': 'disabled'},
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          var content = choices[0]['message']['content'] as String? ?? '';

          content = content.trim();
          if (content.startsWith('```json')) content = content.substring(7);
          else if (content.startsWith('```')) content = content.substring(3);
          if (content.endsWith('```')) content = content.substring(0, content.length - 3);
          content = content.trim();

          final jsonResult = jsonDecode(content) as Map<String, dynamic>;
          return VetRecord.fromAiJson(jsonResult, rawText: dictationText);
        }
      }

      throw Exception('Z AI вернул статус ${response.statusCode}');
    } on TimeoutException {
      throw Exception('Сервер не ответил за 45 сек.');
    } on SocketException catch (e) {
      throw Exception('Ошибка сети: ${e.message}');
    } on HandshakeException {
      throw Exception('Ошибка SSL.');
    } on FormatException catch (e) {
      throw Exception('Ошибка парсинга JSON: $e');
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }
}
