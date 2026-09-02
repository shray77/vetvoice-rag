import 'package:shared_preferences/shared_preferences.dart';

/// Z AI API configuration
/// Публичный endpoint api.z.ai доступен с любого устройства.
/// internal-api.z.ai резолвится в private IP (172.25.x.x) —
/// работает только изнутри сети Z.ai, недоступен с телефона.
///
/// Для прямых API вызовов нужен API key с https://z.ai/manage-apikey/apikey-list
/// Если ключ не задан — fallback на HF Space (Gradio RAG).
class ApiConfig {
  // Публичный Z AI API (доступен с телефона)
  static const String baseUrl = 'https://api.z.ai/api/paas/v4';
  static const String chatPath = '/chat/completions';
  static const String visionPath = '/chat/completions';

  // Models (OpenAI-compatible naming)
  // ⚠️ Устарело: используйте AppModels.selectedChatModel() / selectedVlmModel().
  // Константы оставлены как дефолтные id для обратной совместимости.
  static const String glmModel = 'glm-4.5-flash';
  static const String glmVlmModel = 'glm-4.6v';

  // HF Space (RAG backend — всегда доступен)
  static const String hfSpaceUrl = 'https://shrayyyy-vetderm-ai.hf.space';
  static const String ragApiPath = '/gradio_api/call/rag_search';

  // ─── VetEco FastAPI backend (primary RAG source) ──────────────────
  // Публичный URL задаётся в Settings (см. backendBaseUrlPrefsKey).
  // Если пусто — используем публичный HF Space Gradio API как fallback.
  static const String backendBaseUrlPrefsKey = 'veteco_backend_base_url';
  // Для обратной совместимости: старый ключ (было 'vetvoice_backend_base_url').
  static const String legacyBackendBaseUrlPrefsKey = 'vetvoice_backend_base_url';
  static const String backendChatPath = '/v1/chat/completions';
  static const String backendVisionPath = '/v1/chat/completions/vision';
  static const String backendRagSearchPath = '/v1/rag/search';
  // Дефолтный публичный бэкенд (переопределяется в Settings).
  static const String defaultBackendBaseUrl = 'https://shrayyyy-vetderm-ai.hf.space';

  // VetLearn URL
  static const String vetlearnUrl = 'https://t107t4hs5wm0-d.space-z.ai';

  // API key — вводится пользователем в Settings.
  // Получить: https://z.ai/manage-apikey/apikey-list
  // Сохраняется в SharedPreferences ('zai_api_key').
  // Если пустой — все AI запросы идут через HF Space fallback.
  static const String apiKeyPrefsKey = 'zai_api_key';

  // Legacy (не используется, но оставлено для совместимости)
  @Deprecated('Use baseUrl instead')
  static const String glmBaseUrl = baseUrl;
}

/// Описание одной выбираемой модели Z AI (GLM) для UI и запросов.
class ModelOption {
  final String id;
  final String label;
  final String modality; // 'chat' | 'vision'
  final String tier; // 'free' | 'plan' | 'paid'
  final String contextWindow;
  final String description;

  const ModelOption({
    required this.id,
    required this.label,
    required this.modality,
    required this.tier,
    required this.contextWindow,
    required this.description,
  });
}

/// Реестр выбираемых моделей. Единый источник правды для UI-пикеров и
/// для model, который шлётся в запросах. ids совпадают с тем, что разрешены
/// на бэкенде (src/settings.py → allowed_models), иначе бэкенд вернёт 400.
///
/// Набор «Рекомендованный» (бесплатные чат-модели + актуальные VLM):
///   чат:  glm-4.5-flash (free), glm-4.7-flash (free, 203K)
///   VLM:  glm-4.6v (plan),       glm-5v-turbo (plan, новая)
class AppModels {
  static const String selectedChatModelPrefsKey = 'veteco_selected_chat_model';
  static const String selectedVlmModelPrefsKey = 'veteco_selected_vlm_model';

  // Дефолты = прежние «соло» модели (обратная совместимость).
  static const String defaultChatModel = 'glm-4.5-flash';
  static const String defaultVlmModel = 'glm-4.6v';

  static const List<ModelOption> chatModels = [
    ModelOption(
      id: 'glm-4.5-flash',
      label: 'GLM-4.5-Flash',
      modality: 'chat',
      tier: 'free',
      contextWindow: '128K',
      description: 'Бесплатно. Текущая модель чата/RAG.',
    ),
    ModelOption(
      id: 'glm-4.7-flash',
      label: 'GLM-4.7-Flash',
      modality: 'chat',
      tier: 'free',
      contextWindow: '203K',
      description: 'Бесплатно. Новее, больше контекста.',
    ),
  ];

  static const List<ModelOption> visionModels = [
    ModelOption(
      id: 'glm-4.6v',
      label: 'GLM-4.6V',
      modality: 'vision',
      tier: 'plan',
      contextWindow: '—',
      description: 'Текущая VLM-модель (зрение).',
    ),
    ModelOption(
      id: 'glm-5v-turbo',
      label: 'GLM-5V-Turbo',
      modality: 'vision',
      tier: 'plan',
      contextWindow: '—',
      description: 'Новая VLM: анализ фото, OCR, визуальный QA.',
    ),
  ];

  /// id выбранной чат-модели (из SharedPreferences, иначе дефолт).
  static Future<String> selectedChatModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(selectedChatModelPrefsKey) ?? defaultChatModel;
  }

  /// id выбранной VLM-модели (из SharedPreferences, иначе дефолт).
  static Future<String> selectedVlmModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(selectedVlmModelPrefsKey) ?? defaultVlmModel;
  }

  static ModelOption chatModelById(String id) =>
      chatModels.firstWhere((m) => m.id == id, orElse: () => chatModels.first);

  static ModelOption vlmModelById(String id) =>
      visionModels.firstWhere((m) => m.id == id, orElse: () => visionModels.first);
}

/// App-wide constants
class AppConstants {
  static const String appName = 'VetEco';
  static const String appVersion = '1.3.0';
  // Total counts reflect actual JSON data (audited 2026-06-21 via scripts/audit_data.py):
  //   - drugs_calc.json:           2401 drugs
  //   - drugs_registry.json:       2449 drugs
  //   - diseases.json:              139 contagious diseases
  //   - non_contagious_diseases:     30 non-contagious diseases
  //   - treatment_protocols.json:   124 protocols
  //   - non_contagious_protocols:    30 protocols
  //   - drug_interactions.json:      73 interactions
  //   - antidotes.json:              17 antidotes
  //   - emergency_protocols.json:    16 emergency protocols
  //   - side_effects.json:           19 drug entries
  //   - fluid_therapy.json:           4 formulas
  //   - withdrawal_by_product.json:  83 entries
  //   - dose_adjustments.json:        5 sections
  //   - verified_dosages.json:       7 entries
  //   - correct_dosages_reference:  27 entries
  //   - dosage_database.json:      684 entries
  //   - unofficial_protocols.json:1116 records
  static const int totalRegistryDrugs = 2449;
  static const int totalContagiousDiseases = 139;
  static const int totalNonContagiousDiseases = 30;
  static const int totalDiseases = totalContagiousDiseases + totalNonContagiousDiseases; // 169
  static const int totalTreatmentProtocols = 124;
  static const int totalNonContagiousProtocols = 30;
  static const int totalProtocols = totalTreatmentProtocols + totalNonContagiousProtocols; // 154
  static const int totalCalcDrugs = 2401;
  static const int totalInteractions = 73;
  static const int totalAntidotes = 17;
  static const int totalEmergencyProtocols = 16;
  static const int totalSideEffectEntries = 19;
  static const int totalFluidFormulas = 4;
  static const int totalWithdrawals = 83;
  static const int totalDoseAdjustments = 5;
  static const int totalVerifiedDosages = 7;
  static const int totalCorrectDosages = 27;
  static const int totalDosageDatabase = 684;
  static const int totalUnofficialProtocols = 1116;
  static const String vlmModelName = 'GLM-4.6V + RAG';
}

/// Animal IDs matching JSON data
class AnimalIds {
  static const String cattle = 'cattle';
  static const String sheep = 'sheep';
  static const String pigs = 'pigs';
  static const String horses = 'horses';
  static const String dogs = 'dogs';
  static const String cats = 'cats';
  static const String poultry = 'poultry';
  static const String rabbits = 'rabbits';
  static const String fish = 'fish';
  static const String bees = 'bees';
}

/// Navigation tab indices (4 tabs)
class NavIndex {
  static const int notes = 0;       // Записи (SOAP)
  static const int doseCalc = 1;    // Калькулятор
  static const int aiHub = 2;       // AI (Чат + VLM)
  static const int more = 3;        // Ещё (Настройки, VetLearn)
}
