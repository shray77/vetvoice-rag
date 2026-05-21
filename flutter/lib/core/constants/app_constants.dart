/// GLM API configuration
class ApiConfig {
  // GLM API
  static const String glmBaseUrl = 'https://open.bigmodel.cn/api/paas/v4';
  static const String glmApiKey = '278570cc58fc4f36b9e1b73275c3f946.2Lfl9yCjMWBBs1tL';
  static const String glmModel = 'glm-4-flash';

  // VetEcosystem HF Space (VLM + RAG + Dictation + Dose Calc)
  static const String hfSpaceUrl = 'https://shrayyyy-vetderm-ai.hf.space';

  // Gradio API endpoints
  static const String vlmEndpoint = '$hfSpaceUrl/api/vlm_analyze';
  static const String ragEndpoint = '$hfSpaceUrl/api/rag_search';
  static const String dictationEndpoint = '$hfSpaceUrl/api/dictation_parse';
  static const String doseCalcEndpoint = '$hfSpaceUrl/api/dose_calculate';

  // VetLearn URL
  static const String vetlearnUrl = 'https://t107t4hs5wm0-d.space-z.ai';

  // PaliGemma HF Hub (legacy)
  static const String paligemmaBaseModel = 'google/paligemma2-3b-mix-224';
  static const String paligemmaLoraRepo = 'shrayyyy/paligemma2-vet-derm';
}

/// App-wide constants
class AppConstants {
  static const String appName = 'VetEco';
  static const String appVersion = '1.0.0';
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

/// Navigation tab indices (6 tabs)
class NavIndex {
  static const int notes = 0;       // Записи (SOAP)
  static const int doseCalc = 1;    // Калькулятор
  static const int aiAssistant = 2; // AI-ассистент
  static const int vetlearn = 3;    // VetLearn WebView
  static const int vlm = 4;         // VLM диагностика
  static const int settings = 5;    // Настройки
}
