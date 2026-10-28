from .terms import translate_ru_to_en_query  # noqa: F401

# VetDermRAG не импортируем на уровне пакета: он тянет faiss/sklearn,
# а лёгкий terms (Task 184) должен быть доступен без ML-зависимостей.
# Тяжёлый ретривер — явно: from src.rag.retriever import VetDermRAG.
