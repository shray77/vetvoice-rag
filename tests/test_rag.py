"""Tests for RAG retriever"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

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
