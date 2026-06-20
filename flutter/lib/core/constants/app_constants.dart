/// Z AI API configuration
/// Используем Z AI gateway напрямую (НЕ локальный IP)
class ApiConfig {
  // Z AI Gateway — проксирует запросы к GLM-4-Flash / GLM-4V
  static const String baseUrl = 'https://internal-api.z.ai/v1';
  static const String apiKey = 'Z.ai';
  static const String token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiMDA3MzE0M2QtYTUwYS00MGY5LTljMzItYjk4NDYyY2Q2OWJmIiwiY2hhdF9pZCI6ImNoYXQtNzkzN2VhNTQtMGQ2My00ZjIxLWI0YWEtYzJlMzYxODc1YzQyIiwicGxhdGZvcm0iOiJ6YWkifQ.Rmtru5GZmsbYNW2hEeZNdgxrVeBQzrbp7xp5A0KbUE4';
  static const String chatId = 'chat-7937ea54-0d63-4f21-b4aa-c2e361875c42';
  static const String userId = '0073143d-a50a-40f9-9c32-b98462cd69bf';

  // Chat completions endpoint (Z AI)
  static const String chatPath = '/chat/completions';
  // Vision endpoint (Z AI — отдельный роут!)
  static const String visionPath = '/chat/completions/vision';

  // Models
  static const String glmModel = 'glm-4-flash';
  static const String glmVlmModel = 'glm-4.6v';

  // VetEcosystem HF Space (RAG only — текстовый API, надёжный)
  static const String hfSpaceUrl = 'https://shrayyyy-vetderm-ai.hf.space';

  // Gradio API path for RAG search (text-only, works reliably)
  // Gradio 6.x uses /gradio_api/ prefix!
  static const String ragApiPath = '/gradio_api/call/rag_search';

  // Local FastAPI server (preferred over HF Space when available).
  // Run: `uvicorn src.api.app:app --host 0.0.0.0 --port 7860`
  // Falls back to HF Space automatically if local server is unreachable.
  static const String localApiUrl = 'http://10.0.2.2:7860';  // Android emulator → host
  static const String localApiPath = '/v1/rag/search';

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
