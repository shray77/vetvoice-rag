"""Unified RAG retrieval with a pluggable mode (tfidf / hybrid / embedding).

Single entry point for both the Gradio UI (`app.py`) and the FastAPI backend
(`src/api/app.py`). Mode is driven by `settings.rag_mode`; TF-IDF is always the
safety net, so the app never breaks if the embedding index/model is unavailable.

- tfidf     : pure TF-IDF + keyword boost (original behaviour)
- hybrid    : Reciprocal Rank Fusion of TF-IDF + dense embeddings (RECOMMENDED default)
- embedding : dense embeddings only (no TF-IDF) — risky, used only for A/B

Instances are cached (singletons) so the FAISS indices load once per process.
"""
from __future__ import annotations

import sys
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from src.rag.retriever import VetDermRAG
from src.settings import get_settings

_VALID_MODES = ("tfidf", "hybrid", "embedding")

_RAG: VetDermRAG | None = None
_EMBED = None
_LOCK = threading.Lock()


def get_rag() -> VetDermRAG:
    """Cached TF-IDF retriever singleton (loads the FAISS index once)."""
    global _RAG
    if _RAG is None:
        with _LOCK:
            if _RAG is None:
                _RAG = VetDermRAG()
    return _RAG


def _get_embed_retriever(tfidf: VetDermRAG):
    """Cached dense retriever singleton. Returns None if it can't be built."""
    global _EMBED
    if _EMBED is not None:
        return _EMBED
    with _LOCK:
        if _EMBED is not None:
            return _EMBED
        try:
            from src.rag.embed_retriever import EmbedRetriever

            _EMBED = EmbedRetriever(tfidf_retriever=tfidf)
        except Exception as e:  # noqa: BLE001
            print(f"[search] embedding retriever unavailable ({e}); using TF-IDF fallback")
            _EMBED = None
    return _EMBED


def retrieve(
    query: str,
    top_k: int | None = None,
    mode: str | None = None,
) -> list[dict]:
    """Retrieve relevant chunks using the active RAG mode.

    Always falls back to TF-IDF if embeddings are unavailable, so callers can
    rely on this returning results whenever the KB is loaded.
    """
    cfg = get_settings()
    rag = get_rag()
    if not rag.is_ready():
        return []
    k = top_k or cfg.rag_top_k
    m = (mode or cfg.rag_mode or "hybrid").lower()
    if m not in _VALID_MODES:
        m = "hybrid"

    if m == "tfidf":
        return rag.retrieve(query, top_k=k)

    er = _get_embed_retriever(rag)
    if er is None or er.index is None:
        # Graceful fallback — embeddings unavailable, use TF-IDF.
        return rag.retrieve(query, top_k=k)

    if m == "embedding":
        return er.search(query, top_k=k)

    # hybrid (RRF)
    return er.hybrid_search(query, top_k=k, alpha=cfg.rag_hybrid_alpha)
