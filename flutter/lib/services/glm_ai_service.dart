import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../models/vet_record_model.dart';

/// Z AI Service — работает через Z AI gateway
/// Chat: POST /chat/completions
/// Vision: POST /chat/completions/vision
/// Все запросы требуют заголовки: Authorization, X-Z-AI-From, X-Token, X-Chat-Id, X-User-Id
class GlmAiService {
  static final GlmAiService _instance = GlmAiService._internal();
  factory GlmAiService() => _instance;
  GlmAiService._internal();

  /// Общие заголовки для Z AI
  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${ApiConfig.apiKey}',
    'Content-Type': 'application/json',
    'X-Z-AI-From': 'Z',
    'X-Token': ApiConfig.token,
    'X-Chat-Id': ApiConfig.chatId,
    'X-User-Id': ApiConfig.userId,
  };

  /// Отправить чат-запрос через Z AI gateway
  Future<String> chat({
    required String message,
    required String systemPrompt,
    List<Map<String, String>>? history,
  }) async {
    try {
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': systemPrompt},
        if (history != null) ...history,
        {'role': 'user', 'content': message},
      ];

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.chatPath}'),
        headers: _headers,
        body: jsonEncode({
          'model': ApiConfig.glmModel,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 2048,
          'thinking': {'type': 'disabled'},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          return choices[0]['message']['content'] as String? ?? '';
        }
      }

      return 'Ошибка: ${response.statusCode} — ${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}';
    } on SocketException {
      return 'Ошибка: нет подключения к интернету';
    } catch (e) {
      return 'Ошибка: $e';
    }
  }

  /// RAG-запрос с контекстом из ветеринарных статей
  Future<String> askWithRag({
    required String question,
    String? ragContext,
  }) async {
    final systemPrompt = '''Ты — ветеринарный AI-ассистент VetEcosystem. Отвечай на вопросы ветеринарных врачей на русском языке.

Правила:
1. Давай точные, научно обоснованные ответы
2. Указывай дозировки в мг/кг с указанием пути введения
3. Предупреждай о противопоказаниях и взаимодействиях
4. Если не уверен — скажи об этом прямо
5. Ссылайся на источники если есть контекст

${ragContext != null ? 'Контекст из ветеринарных статей:\n$ragContext' : ''}''';

    return chat(message: question, systemPrompt: systemPrompt);
  }

  /// Анализ изображения через Z AI Vision endpoint
  /// Использует /chat/completions/vision (отдельный роут Z AI)
  Future<String> analyzeImage({
    required String imageBase64,
    String? prompt,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.visionPath}'),
        headers: _headers,
        body: jsonEncode({
          'model': ApiConfig.glmVlmModel,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
                },
                {
                  'type': 'text',
                  'text': prompt ?? 'Опиши что ты видишь на этом изображении с ветеринарной точки зрения. Какие патологии или состояния ты можешь определить?',
                },
              ],
            },
          ],
          'temperature': 0.5,
          'max_tokens': 1024,
          'thinking': {'type': 'disabled'},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          return choices[0]['message']['content'] as String? ?? '';
        }
      }

      return 'VLM ошибка: ${response.statusCode} — ${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}';
    } catch (e) {
      return 'VLM ошибка: $e';
    }
  }

  /// Парсинг ветеринарной диктовки в структурированную SOAP-запись
  /// Надиктовал → AI разобрал → вернул JSON → VetRecord
  Future<VetRecord> parseVetRecord(String dictationText) async {
    const systemPrompt = '''Ты — ветеринарный AI-ассистент, специализирующийся на структурировании клинических записей.
Твоя задача — разобрать текст диктовки ветеринарного врача и извлечь из него структурированные данные в формате JSON.

ВАЖНО: Ответь ТОЛЬКО валидным JSON, без Markdown-обёрток, без пояснений, без ```json блоков.
Просто чистый JSON объект.

Структура JSON для ответа:
{
  "animal_type": "вид животного (корова/собака/кошка/лошадь/овца/свинья/курица/кролик и т.д.)",
  "animal_breed": "порода если указана, иначе null",
  "animal_weight": вес_число_или_null,
  "animal_age": возраст_число_или_null,
  "animal_age_unit": "лет/месяцев/недель",
  "animal_gender": "м/ж/кастрирован/null",
  "animal_id": "кличка/номер/бирка или null",
  "complaint": "жалоба владельца (Subjective)",
  "anamnesis": "анамнез заболевания (Subjective)",
  "temperature": температура_число_или_null,
  "heart_rate": пульс_число_или_null,
  "respiratory_rate": чдд_число_или_null,
  "physical_exam": "данные объективного осмотра (Objective)",
  "mucous_membranes": "состояние слизистых или null",
  "lymph_nodes": "лимфоузлы или null",
  "skin_coat": "кожа и шерсть или null",
  "diagnosis": "основной диагноз (Assessment)",
  "differential_dx": "дифференциальный диагноз или null",
  "disease_severity": "лёгкая/средняя/тяжёлая/null",
  "prescribed_drugs": [
    {
      "name": "название препарата",
      "inn": "МНН или null",
      "dose_per_kg": доза_мг_кг_или_null,
      "total_dose": общая_доза_или_null,
      "dose_unit": "мг/мл/таб",
      "route": "путь введения (в/м/в/в/внутрь/п/к и т.д.)",
      "frequency": "кратность (2 раза в день/сут и т.д.)",
      "duration_days": дней_или_null,
      "notes": "заметки по препарату или null"
    }
  ],
  "procedures": "проведённые/планируемые процедуры",
  "diet": "рекомендации по кормлению/содержанию",
  "follow_up": "повторный приём/контроль",
  "notes": "дополнительные заметки врача"
}

Правила извлечения:
1. Если значение не упоминается в тексте — ставь null
2. Дозировки извлекай точно, как сказал врач (мг/кг, путь, кратность)
3. Температуру указывай в градусах Цельсия (число)
4. Пульс и ЧДД — числа (уд/мин, дыханий/мин)
5. Диагноз формулируй кратко, профессионально
6. Если врач сказал "подозрение" или "вероятно" — укажи это в diagnosis
7. Выделяй назначенные препараты в массив prescribed_drugs
8. Все текстовые поля на русском языке''';

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.chatPath}'),
        headers: _headers,
        body: jsonEncode({
          'model': ApiConfig.glmModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': dictationText},
          ],
          'temperature': 0.2,
          'max_tokens': 2048,
          'thinking': {'type': 'disabled'},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          var content = choices[0]['message']['content'] as String? ?? '';

          // Убрать Markdown-обёртки если AI их добавил
          content = content.trim();
          if (content.startsWith('```json')) {
            content = content.substring(7);
          } else if (content.startsWith('```')) {
            content = content.substring(3);
          }
          if (content.endsWith('```')) {
            content = content.substring(0, content.length - 3);
          }
          content = content.trim();

          final jsonResult = jsonDecode(content) as Map<String, dynamic>;
          return VetRecord.fromAiJson(jsonResult, rawText: dictationText);
        }
      }

      throw Exception('Z AI вернул статус ${response.statusCode}');
    } on SocketException {
      throw Exception('Нет подключения к интернету');
    } on FormatException catch (e) {
      throw Exception('Ошибка парсинга JSON ответа: $e');
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }
}
