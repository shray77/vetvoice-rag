"""Лёгкие тесты RU↔EN словарей (src/rag/terms.py).

Task 184: словари вынесены из retriever.py в модуль без faiss/sklearn —
эти тесты запускаются в любом окружении (pytest не требует ML-зависимостей).
"""

import re

from src.rag.terms import (
    EN_RU_DRUG_TERMS,
    RU_EN_TERMS,
    ru_localize,
    translate_ru_to_en_query,
)

# Стоп-лист известных опечаток МНН: в значениях словаря их быть не должно
# (прецедент аудита 183: «enalapril → энапалил»).
_MISSPELLED_INN = {"энапалил", "эналоприл", "энолаприл", "энаприл"}


def test_ru_en_keys_unique_lowercase():
    # Дубли в dict-литерале молча съедаются (последний выигрывает) — поэтому
    # уникальность проверяем после lower() и требуем нижний регистр ключей.
    keys = [k.lower() for k in RU_EN_TERMS]
    assert len(keys) == len(set(keys))
    assert all(v.strip() for v in RU_EN_TERMS.values()), "пустые значения"


def test_en_ru_keys_unique_case_insensitive():
    keys = [k.lower() for k in EN_RU_DRUG_TERMS]
    assert len(keys) == len(set(keys))
    assert all(v.strip() for v in EN_RU_DRUG_TERMS.values()), "пустые значения"


def test_en_ru_values_no_latin():
    # Русские значения EN_RU_DRUG_TERMS не должны содержать латиницу:
    # латиница в значении — почти всегда опечатка (класс «энапалил»).
    for en, ru in EN_RU_DRUG_TERMS.items():
        assert not re.search(r"[A-Za-z]", ru), f"латиница в значении {en!r}: {ru!r}"


def test_enalapril_spelled_correctly():
    assert EN_RU_DRUG_TERMS.get("enalapril") == "эналаприл"
    for ru in EN_RU_DRUG_TERMS.values():
        for bad in _MISSPELLED_INN:
            assert bad not in ru.lower(), f"опечатка {bad!r} в значении {ru!r}"


def test_translate_ru_to_en_basic():
    result = translate_ru_to_en_query("собака чешет лапы")
    assert "pruritus" in result.lower() or "itchy" in result.lower()
    assert "paws" in result.lower() or "interdigital" in result.lower()


def test_translate_en_drug_to_ru():
    result = translate_ru_to_en_query("enalapril dosage for dog")
    assert "эналаприл" in result


def test_ru_localize_replaces_latin_inn():
    assert ru_localize("Назначен enalapril 0.5 mg/kg") == "Назначен эналаприл 0.5 mg/kg"


def test_ru_localize_keeps_russian_text():
    assert ru_localize("эналаприл и преднизолон") == "эналаприл и преднизолон"
    assert ru_localize("") == ""
