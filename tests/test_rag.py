"""Tests for RAG retriever"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from src.rag.retriever import translate_ru_to_en_query, RU_EN_TERMS


def test_translation_basic():
    result = translate_ru_to_en_query("собака чешет лапы")
    assert "pruritus" in result.lower() or "itchy" in result.lower()
    assert "paws" in result.lower() or "interdigital" in result.lower()
    print("✅ Basic translation works")


def test_translation_breed():
    result = translate_ru_to_en_query("французский бульдог")
    assert "French Bulldog" in result
    print("✅ Breed translation works")


def test_translation_disease():
    result = translate_ru_to_en_query("демодекоз у щенка")
    assert "demodicosis" in result
    assert "puppy" in result.lower()
    print("✅ Disease translation works")


def test_translation_empty():
    result = translate_ru_to_en_query("")
    assert isinstance(result, str)
    print("✅ Empty string handled")


def test_translation_english_passthrough():
    result = translate_ru_to_en_query("dog has atopic dermatitis")
    assert "atopic dermatitis" in result
    print("✅ English text preserved")


def test_terms_dict_not_empty():
    assert len(RU_EN_TERMS) > 50
    print(f"✅ Terms dictionary has {len(RU_EN_TERMS)} entries")


if __name__ == "__main__":
    test_translation_basic()
    test_translation_breed()
    test_translation_disease()
    test_translation_empty()
    test_translation_english_passthrough()
    test_terms_dict_not_empty()
    print("\n🎉 All RAG tests passed!")
