import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vet_record_model.dart';
import '../services/glm_ai_service.dart';

/// Провайдер для управления ветеринарными записями
/// Voice → AI Parse → Structured Record → Save
class NotesProvider extends ChangeNotifier {
  final GlmAiService _aiService = GlmAiService();

  // === Список записей ===
  List<VetRecord> _records = [];
  List<VetRecord> get records => _records;

  // === Текущая запись (в работе) ===
  VetRecord? _currentRecord;
  VetRecord? get currentRecord => _currentRecord;

  // === Голосовой ввод ===
  String _dictationText = '';
  String get dictationText => _dictationText;
  bool _isListening = false;
  bool get isListening => _isListening;

  // === AI парсинг ===
  bool _isParsing = false;
  bool get isParsing => _isParsing;
  String _parseError = '';
  String get parseError => _parseError;

  // === Поиск/фильтр ===
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  List<VetRecord> get filteredRecords {
    if (_searchQuery.isEmpty) return _records;
    final q = _searchQuery.toLowerCase();
    return _records.where((r) {
      return r.animalType.toLowerCase().contains(q) ||
          (r.animalId ?? '').toLowerCase().contains(q) ||
          (r.diagnosis ?? '').toLowerCase().contains(q) ||
          (r.complaint ?? '').toLowerCase().contains(q) ||
          (r.rawDictation ?? '').toLowerCase().contains(q);
    }).toList();
  }

  /// Инициализация — загрузить сохранённые записи
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('vet_records');
      if (saved != null) {
        final List<dynamic> jsonList = jsonDecode(saved) as List<dynamic>;
        _records = jsonList
            .map((j) => VetRecord.fromJson(j as Map<String, dynamic>))
            .toList();
        // Сортировка по дате (новые сверху)
        _records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      debugPrint('NotesProvider: Error loading records: $e');
    }
    notifyListeners();
  }

  /// Сохранить записи в локальное хранилище
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _records.map((r) => r.toJson()).toList();
      await prefs.setString('vet_records', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('NotesProvider: Error saving records: $e');
    }
  }

  // === Голосовой ввод ===

  /// Обновить текст диктовки (из speech recognition)
  void updateDictationText(String text) {
    _dictationText = text;
    notifyListeners();
  }

  /// Установить статус прослушивания
  void setListening(bool listening) {
    _isListening = listening;
    notifyListeners();
  }

  /// Начать новую диктовку
  void startNewDictation() {
    _dictationText = '';
    _currentRecord = null;
    _parseError = '';
    notifyListeners();
  }

  // === AI парсинг диктовки ===

  /// Отправить диктовку на парсинг в GLM
  Future<void> parseDictation() async {
    if (_dictationText.trim().isEmpty) return;

    _isParsing = true;
    _parseError = '';
    notifyListeners();

    try {
      final record = await _aiService.parseVetRecord(_dictationText);
      _currentRecord = record;
      _isParsing = false;
      notifyListeners();
    } catch (e) {
      _parseError = 'Ошибка парсинга: $e';
      _isParsing = false;
      notifyListeners();
    }
  }

  // === Ручное редактирование записи ===

  /// Обновить поле текущей записи
  void updateCurrentRecord(VetRecord updated) {
    _currentRecord = updated.copyWith(status: VetRecordStatus.edited);
    notifyListeners();
  }

  /// Сохранить текущую запись в список
  Future<void> saveCurrentRecord() async {
    if (_currentRecord == null) return;

    final record = _currentRecord!.copyWith(status: VetRecordStatus.saved);

    // Обновить существующую или добавить новую
    final idx = _records.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      _records[idx] = record;
    } else {
      _records.insert(0, record);
    }

    _records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _currentRecord = null;
    _dictationText = '';
    _parseError = '';

    notifyListeners();
    await _saveToStorage();
  }

  /// Открыть существующую запись для просмотра/редактирования
  void openRecord(VetRecord record) {
    _currentRecord = record;
    _dictationText = record.rawDictation ?? '';
    notifyListeners();
  }

  /// Удалить запись
  Future<void> deleteRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
    if (_currentRecord?.id == id) {
      _currentRecord = null;
    }
    notifyListeners();
    await _saveToStorage();
  }

  /// Сбросить текущую запись
  void discardCurrentRecord() {
    _currentRecord = null;
    _dictationText = '';
    _parseError = '';
    notifyListeners();
  }

  /// Установить поисковый запрос
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Получить запись по ID
  VetRecord? getRecordById(String id) {
    try {
      return _records.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Количество записей
  int get totalRecords => _records.length;

  /// Записи по типу животного
  Map<String, List<VetRecord>> get recordsByAnimal {
    final map = <String, List<VetRecord>>{};
    for (final r in _records) {
      final key = r.animalType.isEmpty ? 'Не указано' : r.animalType;
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }
}
