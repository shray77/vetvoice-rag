"""Tests for RAG retriever"""

from src.rag.retriever import translate_ru_to_en_query, RU_EN_TERMS


def test_translation_basic():
    result = translate_ru_to_en_query("собака чешет лапы")
    assert "pruritus" in result.lower() or "itchy" in result.lower()
    assert "paws" in result.lower() or "interdigital" in result.lower()


def test_translation_breed():
    result = translate_ru_to_en_query("французский бульдог")
    assert "French Bulldog" in result


def test_translation_disease():
    result = translate_ru_to_en_query("демодекоз")
    assert "demodicosis" in result
    # "щенок" exact match should translate
    result2 = translate_ru_to_en_query("щенок")
    assert "puppy" in result2.lower() or "young" in result2.lower()


def test_translation_empty():
    result = translate_ru_to_en_query("")
    assert isinstance(result, str)


def test_translation_english_passthrough():
    result = translate_ru_to_en_query("dog has atopic dermatitis")
    assert "atopic dermatitis" in result


def test_terms_dict_not_empty():
    assert len(RU_EN_TERMS) > 50


# ============================================================
# BM25 lexical channel (дефолтный ранкер с 1.1.3)
# ============================================================

def _mini_chunks():
    """Мини-корпус: типы и условия, на которых TF-IDF тонет, BM25 выезжает."""
    return [
        {"chunk_id": "d1", "chunk_type": "drug_interaction",
         "conditions": ["кетопрофен", "энрофлоксацин"],
         "content": "Кетопрофен нельзя сочетать с другими НПВС: риск язвы ЖКТ и нефротоксичности.",
         "source": "test"},
        {"chunk_id": "d2", "chunk_type": "drug_interaction",
         "conditions": ["метронидазол"],
         "content": "Метронидазол + варфарин: усиление антикоагуляции, контроль МНО.",
         "source": "test"},
        {"chunk_id": "s1", "chunk_type": "side_effect",
         "conditions": ["преднизолон"],
         "content": "Преднизолон: полиурия, полидипсия, синдром Кушинга при длительном применении.",
         "source": "test"},
        {"chunk_id": "z1", "chunk_type": "drug_calculator",
         "conditions": ["амоксициллин"],
         "content": "Калькулятор дозы амоксициллина: 10-15 мг/кг каждые 12 часов.",
         "source": "test"},
    ]


def _build_rag(chunks):
    from src.rag.retriever import VetDermRAG
    return VetDermRAG(chunks=chunks)


def test_bm25_index_built():
    rag = _build_rag(_mini_chunks())
    assert rag.has_bm25 is True


def test_bm25_finds_interaction_by_type_word():
    # Слово «взаимодействие/сочетать» должно вытащить drug_interaction-чанк,
    # даже если его нет в content дословно (BM25 видит chunk_type).
    rag = _build_rag(_mini_chunks())
    res = rag.retrieve_bm25("взаимодействие кетопрофена с другими препаратами", top_k=3)
    assert res, "пустой результат"
    assert res[0]["chunk_type"] == "drug_interaction"
    assert res[0]["chunk_id"] == "d1"


def test_bm25_handles_russian_morphology():
    # «преднизолона» (род. падеж) должно матчиться через стем-токены.
    rag = _build_rag(_mini_chunks())
    res = rag.retrieve_bm25("побочные эффекты преднизолона у собак", top_k=3)
    assert res and res[0]["chunk_id"] == "s1"


def test_bm25_fallback_without_index():
    rag = _build_rag(_mini_chunks())
    rag._bm25 = None  # имитация отсутствия rank_bm25
    # Запрос с точными токенами корпуса: TF-IDF-фолбэк обязан вернуть результат.
    # (Заодно видно, ПОЧЕМУ BM25 — дефолт: «преднизолона» в род. падеже фолбэк
    # возвращает пусто, BM25 находит через стем-токены.)
    res = rag.retrieve_bm25("варфарин контроль МНО", top_k=2)
    assert res and res[0]["chunk_id"] == "d2"


def test_bm25_beats_tfidf_on_morphology():
    rag = _build_rag(_mini_chunks())
    assert rag.retrieve_bm25("побочки преднизолона у кошки", top_k=1)[0]["chunk_id"] == "s1"
    # TF-IDF-фолбэк на том же запросе: матча нет (преднизолон vs преднизолона)
    rag._bm25 = None
    assert rag.retrieve("побочки преднизолона у кошки", top_k=1) == []


def test_search_route_bm25_mode():
    from src.rag import search
    assert "bm25" in search._VALID_MODES
