#!/usr/bin/env python3
"""Baseline evaluation of the CURRENT TF-IDF retriever on the gold query set.

Builds the TF-IDF index in-memory from local assets/data (no HF needed),
runs every query from gold_queries.jsonl, and reports:
  - Recall@5 : fraction of queries where a relevant chunk is in top-5
  - MRR      : Mean Reciprocal Rank of the first relevant hit
  - Per-type breakdown

Relevance = chunk matches expected_chunk_type AND (no expected_conditions
OR at least one expected condition substring-matches the chunk's conditions).

This is the "shelf" the hybrid/embedding approach must beat.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Dict, List

# Allow running as a script: make `src` importable
ROOT = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(ROOT))

from sklearn.feature_extraction.text import TfidfVectorizer  # noqa: E402
from sklearn.preprocessing import normalize  # noqa: E402
import faiss  # noqa: E402

from scripts.build_rag import collect_local_chunks, CHUNK_SIZE, CHUNK_OVERLAP  # noqa: E402

GOLD_PATH = Path(__file__).parent / "gold_queries.jsonl"
TOP_K = 5
MIN_SCORE = 0.04  # mirrors retriever.py default-ish threshold


def build_tfidf(chunks):
    texts = [c["content"] for c in chunks]
    vec = TfidfVectorizer(
        max_features=8000, ngram_range=(1, 1),
        stop_words=None, min_df=1, max_df=0.95,
        sublinear_tf=True, strip_accents=None,
    )
    mat = vec.fit_transform(texts).toarray().astype("float32")
    mat = normalize(mat, norm="l2")
    index = faiss.IndexFlatIP(mat.shape[1])
    index.add(mat)
    return vec, index


def translate_query(q: str) -> str:
    """Minimal RU->EN + EN->RU mirror of retriever.translate_ru_to_en_query
    using the same dictionaries so the baseline is faithful to production."""
    from src.rag.retriever import translate_ru_to_en_query
    return translate_ru_to_en_query(q)


def is_relevant(doc: Dict, exp_type: str, exp_conds: List[str]) -> bool:
    if doc.get("chunk_type") != exp_type:
        return False
    if not exp_conds:
        return True
    doc_conds = [c.lower() for c in (doc.get("conditions") or [])]
    return any(any(ec.lower() in dc for dc in doc_conds) for ec in exp_conds)


def retrieve(vec, index, documents, query: str, top_k: int = TOP_K):
    from src.rag.retriever import translate_ru_to_en_query
    q = translate_ru_to_en_query(query)
    qv = vec.transform([q]).toarray().astype("float32")
    qv = normalize(qv, norm="l2")
    fetch_k = min(top_k * 10, 50)
    _, indices = index.search(qv, fetch_k)
    q_lower = query.lower()
    en_query = translate_ru_to_en_query(query).lower()
    results = []
    for idx in indices[0]:
        if idx < 0 or idx >= len(documents):
            continue
        doc = documents[idx].copy()
        conditions = [c.lower() for c in (doc.get("conditions") or [])]
        boost = 0.0
        matched = 0
        for cond in conditions:
            if cond in q_lower or cond in en_query:
                boost += 0.30
                matched += 1
        boost = min(boost, 0.90)
        multiplier = 1.5 if matched > 0 else 1.0
        doc["score"] = boost * multiplier  # relevance proxy: keyword boost drives rank
        results.append(doc)
    results.sort(key=lambda x: x["score"], reverse=True)
    return results[:top_k]


def main() -> int:
    print("=" * 60)
    print("TF-IDF Baseline Evaluation")
    print("=" * 60)

    print("Collecting local chunks...")
    chunks = collect_local_chunks()
    print(f"  {len(chunks)} chunks")

    vec, index = build_tfidf(chunks)
    print(f"  TF-IDF index: {index.ntotal} vectors\n")

    gold = [json.loads(line) for line in GOLD_PATH.read_text(encoding="utf-8").splitlines() if line.strip()]
    print(f"Gold queries: {len(gold)}\n")

    recall_hits = 0
    mrr_sum = 0.0
    per_type: Dict[str, List[float]] = {}

    for i, item in enumerate(gold, 1):
        query = item["query"]
        exp_type = item["expected_chunk_type"]
        exp_conds = item.get("expected_conditions", [])
        results = retrieve(vec, index, chunks, query, TOP_K)

        rank = None
        for r, doc in enumerate(results, 1):
            if is_relevant(doc, exp_type, exp_conds):
                rank = r
                break
        if rank is not None:
            recall_hits += 1
            mrr_sum += 1.0 / rank
            per_type.setdefault(exp_type, []).append(1.0 / rank)
        else:
            per_type.setdefault(exp_type, []).append(0.0)

        ok = "✓" if rank else "✗"
        rr = f"rank={rank}" if rank else "MISS"
        print(f"  {ok} [{i:>2}/{len(gold)}] {query[:48]:48} -> {rr}")

    n = len(gold)
    recall = recall_hits / n
    mrr = mrr_sum / n
    print("\n" + "=" * 60)
    print(f"RECALL@{TOP_K}: {recall:.3f}  ({recall_hits}/{n})")
    print(f"MRR       : {mrr:.3f}")
    print("\nPer chunk_type MRR:")
    for t, scores in sorted(per_type.items(), key=lambda x: -sum(x[1])):
        avg = sum(scores) / len(scores)
        print(f"  {avg:.3f}  {t}  (n={len(scores)})")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    sys.exit(main())
