"""A/B comparison: TF-IDF vs Embeddings vs Hybrid (RRF) on the gold query set.

Usage:
  python -m src.rag.eval.compare            # all three, requires embeddings built
  python -m src.rag.eval.compare --tfidf-only  # just baseline, no model needed

Outputs eval_results.json with Recall@5 / MRR per mode and a per-type breakdown.
Hybrid must BEAT tfidf (Recall@5 not lower, MRR >= +5%) before any prod flip.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(ROOT))

GOLD_PATH = Path(__file__).parent / "gold_queries.jsonl"
TOP_K = 5

# Reuse the same relevance + tfidf logic as baseline.py
from src.rag.eval.baseline import (
    build_tfidf,
    collect_local_chunks,
    is_relevant,
    retrieve,
)


def emb_relevant(doc, exp_type, exp_conds):
    return is_relevant(doc, exp_type, exp_conds)


def main() -> int:
    tfidf_only = "--tfidf-only" in sys.argv

    print("Collecting chunks...")
    chunks = collect_local_chunks()
    vec, index = build_tfidf(chunks)
    print(f"  TF-IDF: {index.ntotal} vectors, {len(chunks)} docs")

    gold = [json.loads(line) for line in GOLD_PATH.read_text(encoding="utf-8").splitlines() if line.strip()]

    # ── TF-IDF ──
    tfidf_ranks = []
    for item in gold:
        res = retrieve(vec, index, chunks, item["query"], TOP_K)
        rank = next((r for r, d in enumerate(res, 1) if is_relevant(d, item["expected_chunk_type"], item["expected_conditions"])), None)
        tfidf_ranks.append(rank)

    results = {"tfidf": _summarize(tfidf_ranks, gold)}
    print(f"  TF-IDF  Recall@{TOP_K}={results['tfidf']['recall']:.3f}  MRR={results['tfidf']['mrr']:.3f}")

    if tfidf_only:
        _dump(results)
        return 0

    # ── Embeddings + Hybrid ──
    try:
        from src.rag.embed_retriever import EmbedRetriever
    except Exception as e:  # noqa: BLE001 — eval должен мягко деградировать без эмбеддингов
        print(f"Embeddings unavailable ({e}); skipping. Run without --tfidf-only after build_index().")
        _dump(results)
        return 0

    er = EmbedRetriever(tfidf_retriever=_TfidfShim(vec, index, chunks))
    if er.index is None:
        print("[Embed] index not built. Run: python -m src.rag.embed_retriever")
        _dump(results)
        return 0

    emb_ranks, hyb_ranks = [], []
    for item in gold:
        eres = er.search(item["query"], TOP_K)
        erank = next((r for r, d in enumerate(eres, 1) if is_relevant(d, item["expected_chunk_type"], item["expected_conditions"])), None)
        emb_ranks.append(erank)

        hres = er.hybrid_search(item["query"], TOP_K)
        hrank = next((r for r, d in enumerate(hres, 1) if is_relevant(d, item["expected_chunk_type"], item["expected_conditions"])), None)
        hyb_ranks.append(hrank)

    results["embedding"] = _summarize(emb_ranks, gold)
    results["hybrid"] = _summarize(hyb_ranks, gold)
    print(f"  Embed    Recall@{TOP_K}={results['embedding']['recall']:.3f}  MRR={results['embedding']['mrr']:.3f}")
    print(f"  Hybrid   Recall@{TOP_K}={results['hybrid']['recall']:.3f}  MRR={results['hybrid']['mrr']:.3f}")

    _dump(results)
    return 0


def _summarize(ranks: list[int | None], gold: list[dict]) -> dict:
    n = len(ranks)
    hits = sum(1 for r in ranks if r is not None)
    mrr = sum(1.0 / r for r in ranks if r) / n
    # per-type
    per_type: dict[str, list[float]] = {}
    for r, item in zip(ranks, gold):
        t = item["expected_chunk_type"]
        per_type.setdefault(t, []).append(1.0 / r if r else 0.0)
    per_type_avg = {t: sum(v) / len(v) for t, v in per_type.items()}
    return {
        "recall": hits / n,
        "mrr": mrr,
        "hits": hits,
        "total": n,
        "per_type_mrr": {t: round(v, 3) for t, v in sorted(per_type_avg.items(), key=lambda x: -x[1])},
    }


class _TfidfShim:
    """Minimal shim exposing .retrieve() so EmbedRetriever.hybrid_search can call it."""
    def __init__(self, vec, index, chunks):
        self._vec, self._index, self._chunks = vec, index, chunks

    def retrieve(self, query, top_k):
        from src.rag.eval.baseline import retrieve as _ret
        return _ret(self._vec, self._index, self._chunks, query, top_k)


def _dump(results: dict) -> None:
    out = Path(__file__).parent / "eval_results.json"
    out.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n✓ Saved -> {out}")


if __name__ == "__main__":
    sys.exit(main())
