#!/usr/bin/env python3.13
"""A/B: текущий TF-IDF ранг vs BM25-гибрид на gold-наборе (60 запросов).

Варианты:
  V0 baseline      — как продакшн: TF-IDF fetch50 + keyword boost ranking
  V1 bm25_only     — BM25Okapi + keyword boost ranking (BM25 вместо TF-IDF)
  V2 rrf           — RRF(ранг V0, ранг V1): финальный порядок
  V3 rrf_boost     — RRF + keyword boost как аддитив к RRF-скору
  V4 rrf_stem      — V2 на стеммированных токенах (обрубок до 6 символов)

BM25-документ = content + conditions + chunk_type + source (чтобы
"взаимодействие" находило drug_interaction-чанки, а не только текст).
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(ROOT))

import faiss
from rank_bm25 import BM25Okapi
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.preprocessing import normalize

from scripts.build_rag import collect_local_chunks
from src.rag.retriever import translate_ru_to_en_query

GOLD_PATH = Path(__file__).parent / "gold_queries.jsonl"
TOP_K = 5
RRF_K = 60

TOKEN_RE = re.compile(r"\w+", re.UNICODE)


def tokenize(text: str, stem: bool = False) -> list[str]:
    toks = [t.lower() for t in TOKEN_RE.findall(text)]
    if stem:
        out = []
        for t in toks:
            out.append(t)
            if len(t) > 6:
                out.append(t[:6])
        return out
    return toks


def bm25_doc_text(doc: dict) -> str:
    parts = [doc.get("content", "")]
    parts += [c for c in (doc.get("conditions") or [])]
    parts.append(doc.get("chunk_type", ""))
    parts.append(doc.get("source", ""))
    return " ".join(parts)


def build_tfidf(chunks):
    texts = [c["content"] for c in chunks]
    vec = TfidfVectorizer(max_features=8000, ngram_range=(1, 1), stop_words=None,
                          min_df=1, max_df=0.95, sublinear_tf=True, strip_accents=None)
    mat = vec.fit_transform(texts).toarray().astype("float32")
    mat = normalize(mat, norm="l2")
    index = faiss.IndexFlatIP(mat.shape[1])
    index.add(mat)
    return vec, index


def is_relevant(doc: dict, exp_type: str, exp_conds: list[str]) -> bool:
    if doc.get("chunk_type") != exp_type:
        return False
    if not exp_conds:
        return True
    doc_conds = [c.lower() for c in (doc.get("conditions") or [])]
    return any(any(ec.lower() in dc for dc in doc_conds) for ec in exp_conds)


def cond_boost(doc: dict, q_lower: str, en_query: str) -> tuple[float, int]:
    boost, matched = 0.0, 0
    for cond in (doc.get("conditions") or []):
        if cond and cond.lower() in q_lower or cond and cond.lower() in en_query:
            boost += 0.30
            matched += 1
    return min(boost, 0.90), matched


def rank_tfidf(vec, index, documents, query: str) -> list[dict]:
    """V0 — продакшн-логика (fetch 50, score = tfidf*mult + boost)."""
    q = translate_ru_to_en_query(query)
    qv = normalize(vec.transform([q]).toarray().astype("float32"), norm="l2")
    fetch_k = 50
    _, indices = index.search(qv, fetch_k)
    q_lower, en_query = query.lower(), q.lower()
    results = []
    for idx in indices[0]:
        if idx < 0 or idx >= len(documents):
            continue
        doc = documents[idx].copy()
        tfidf_score = float(vec.transform([q]).toarray()[0][0]) if False else None
        boost, matched = cond_boost(doc, q_lower, en_query)
        results.append(doc)
    # порядок из FAISS-ранга; boost переупорядочивает как аддитив к ранговому весу
    # (продакшн: score = tfidf*mult + boost — здесь приближаем рангом + boost)
    for rank, doc in enumerate(results, 1):
        boost, matched = cond_boost(doc, q_lower, en_query)
        doc["_v0"] = -rank + 3.0 * boost
    results.sort(key=lambda d: d["_v0"], reverse=True)
    return results


def main() -> int:
    print("Сборка корпуса...")
    chunks = collect_local_chunks()
    print(f"  {len(chunks)} чанков")
    vec, index = build_tfidf(chunks)

    # BM25 (обычный и стеммированный)
    corpus_plain = [tokenize(bm25_doc_text(c)) for c in chunks]
    corpus_stem = [tokenize(bm25_doc_text(c), stem=True) for c in chunks]
    bm25_plain = BM25Okapi(corpus_plain)
    bm25_stem = BM25Okapi(corpus_stem)
    print(f"  BM25 готов ({len(corpus_plain)} документов)\n")

    gold = [json.loads(l) for l in GOLD_PATH.read_text(encoding="utf-8").splitlines() if l.strip()]
    print(f"Gold: {len(gold)} запросов\n")

    variants = ["V0_tfidf", "V1_bm25", "V2_rrf", "V3_rrf_boost", "V4_rrf_stem"]
    hits = {v: 0 for v in variants}
    mrrs = {v: 0.0 for v in variants}
    per_type = {v: {} for v in variants}

    def record(variant, item, rank):
        et = item["expected_chunk_type"]
        if rank is not None:
            hits[variant] += 1
            mrrs[variant] += 1.0 / rank
            per_type[variant].setdefault(et, []).append(1.0 / rank)
        else:
            per_type[variant].setdefault(et, []).append(0.0)

    for i, item in enumerate(gold, 1):
        q, et, ec = item["query"], item["expected_chunk_type"], item.get("expected_conditions", [])
        en = translate_ru_to_en_query(q)
        ql, el = q.lower(), en.lower()

        # V0
        r0 = rank_tfidf(vec, index, chunks, q)[:TOP_K]
        # V1: BM25 full-corpus ranking + boost
        scores = bm25_plain.get_scores(tokenize(en))
        order = sorted(range(len(chunks)), key=lambda j: scores[j], reverse=True)[:50]
        cand = []
        for j in order:
            d = chunks[j].copy()
            boost, _ = cond_boost(d, ql, el)
            d["_v1"] = scores[j] * (1.5 if boost > 0 else 1.0) + boost
            cand.append(d)
        cand.sort(key=lambda d: d["_v1"], reverse=True)
        r1 = cand[:TOP_K]

        # V2/V4: RRF(V0-ранг, BM25-ранг) — чистый
        # V3: RRF + boost*0.05 аддитив
        bm25_stem_scores = bm25_stem.get_scores(tokenize(en, stem=True))
        stem_order = sorted(range(len(chunks)), key=lambda j: bm25_stem_scores[j], reverse=True)

        rrf = {}
        for rank, d in enumerate(r0 + [], 1):
            cid = d.get("chunk_id")
            rrf[cid] = rrf.get(cid, 0.0) + 1.0 / (RRF_K + rank)
        # BM25-ранг по всем корпусом (plain)
        for rank, j in enumerate(order, 1):
            cid = chunks[j].get("chunk_id")
            rrf[cid] = rrf.get(cid, 0.0) + 1.0 / (RRF_K + rank)
        fused = sorted(rrf.keys(), key=lambda c: rrf[c], reverse=True)

        by_cid = {c.get("chunk_id"): c for c in chunks}
        r2 = [by_cid[c] for c in fused[:TOP_K]]

        rrf_b = {}
        for rank, d in enumerate(r0, 1):
            cid = d.get("chunk_id")
            rrf_b[cid] = rrf_b.get(cid, 0.0) + 1.0 / (RRF_K + rank)
        for rank, j in enumerate(order, 1):
            cid = chunks[j].get("chunk_id")
            boost, _ = cond_boost(chunks[j], ql, el)
            rrf_b[cid] = rrf_b.get(cid, 0.0) + 1.0 / (RRF_K + rank) + 0.004 * boost
        fused_b = sorted(rrf_b.keys(), key=lambda c: rrf_b[c], reverse=True)
        r3 = [by_cid[c] for c in fused_b[:TOP_K]]

        rrf_s = {}
        for rank, d in enumerate(r0, 1):
            cid = d.get("chunk_id")
            rrf_s[cid] = rrf_s.get(cid, 0.0) + 1.0 / (RRF_K + rank)
        for rank, j in enumerate(stem_order[:50], 1):
            cid = chunks[j].get("chunk_id")
            rrf_s[cid] = rrf_s.get(cid, 0.0) + 1.0 / (RRF_K + rank)
        fused_s = sorted(rrf_s.keys(), key=lambda c: rrf_s[c], reverse=True)
        r4 = [by_cid[c] for c in fused_s[:TOP_K]]

        for v, res in zip(variants, [r0, r1, r2, r3, r4]):
            rank = None
            for rr, doc in enumerate(res, 1):
                if is_relevant(doc, et, ec):
                    rank = rr
                    break
            record(v, item, rank)

        marks = {v: ("✓" if any(is_relevant(d, et, ec) for d in r) else "✗") for v, r in zip(variants, [r0, r1, r2, r3, r4])}
        print(f"  [{i:>2}/{len(gold)}] {q[:44]:44} " + " ".join(f"{v.split('_')[0]}:{m}" for v, m in marks.items()))

    print("\n" + "=" * 64)
    print(f"{'Вариант':16} {'Recall@5':>9} {'MRR':>7}")
    for v in variants:
        print(f"{v:16} {hits[v]/len(gold):>9.3f} {mrrs[v]/len(gold):>7.3f}")
    print("=" * 64)
    print("\nPer-type MRR (лучший вариант по сумме):")
    best = max(variants, key=lambda v: mrrs[v])
    for t, sc in sorted(per_type[best].items(), key=lambda x: -sum(x[1])):
        vals = {v: sum(per_type[v].get(t, [0])) / max(1, len(per_type[v].get(t, [1]))) for v in variants}
        row = " ".join(f"{v.split('_')[1]}={vals[v]:.2f}" for v in variants)
        print(f"  {t:22} {row}  (n={len(sc)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
