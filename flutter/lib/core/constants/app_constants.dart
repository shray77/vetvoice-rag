/// Z AI API configuration
/// Используем Z AI gateway, НЕ bigmodel.cn напрямую
class ApiConfig {
  // Z AI Gateway — проксирует запросы к GLM-4-Flash / GLM-4V
  static const String baseUrl = 'http://172.25.136.193:8080/v1';
  static const String apiKey = 'Z.ai';
  static const String token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiMDA3MzE0M2QtYTUwYS00MGY5LTljMzItYjk4NDYyY2Q2OWJmIiwiY2hhdF9pZCI6ImNoYXQtNTRkMTEzZGEtNjIyMi00ZmY2LWJkYjktY2Y1MTM2ODRmMmY4IiwicGxhdGZvcm0iOiIifQ.BbbRJVrKzzkb66hJaartykfInf2Ju6zYKdCjdu1ejxM';
  static const String chatId = 'chat-54d113da-6222-4ff6-bdb9-cf513684f2f8';
  static const String userId = '0073143d-a50a-40f9-9c32-b98462cd69bf';

  // Chat completions endpoint (Z AI)
  static const String chatPath = '/chat/completions';
  // Vision endpoint (Z AI — отдельный роут!)
  static const String visionPath = '/chat/completions/vision';

  // Models
  static const String glmModel = 'glm-4-flash';
  static const String glmVlmModel = 'glm-4v-flash';

  // VetEcosystem HF Space (RAG only — текстовый API, надёжный)
  static const String hfSpaceUrl = 'https://shrayyyy-vetderm-ai.hf.space';

  // Gradio API path for RAG search (text-only, works reliably)
  // Gradio 6.x uses /gradio_api/ prefix!
  static const String ragApiPath = '/gradio_api/call/rag_search';

  // VetLearn URL
  static const String vetlearnUrl = 'https://t107t4hs5wm0-d.space-z.ai';

  // PaliGemma HF Hub (legacy)
  static const String paligemmaBaseModel = 'google/paligemma2-3b-mix-224';
  static const String paligemmaLoraRepo = 'shrayyyy/paligemma2-vet-derm';

  // Легаси-алиасы для обратной совместимости
  @Deprecated('Use baseUrl instead')
  static const String glmBaseUrl = baseUrl;
  @Deprecated('Use apiKey instead')
  static const String glmApiKey = apiKey;
}

/// App-wide constants
class AppConstants {
  static const String appName = 'VetEco';
  static const String appVersion = '1.2.0';
  static const int totalRegistryDrugs = 2449;
  static const int totalDiseases = 109;
  static const int totalCalcDrugs = 2401;
  static const String vlmModelName = 'GLM-4V Flash + RAG';
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
