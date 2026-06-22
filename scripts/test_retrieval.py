#!/usr/bin/env python3
"""Quick smoke test: load local RAG KB, run 3 queries, print results."""

import sys
from pathlib import Path

# Make src/ importable
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from src.rag.retriever import VetDermRAG


QUERIES = [
    # Russian — disease + treatment
    "Чем лечить ящур у КРС?",
    # Russian — drug + dosage
    "Доза энрофлоксацина для собак",
    # English — drug + side effects (tests EN→RU translation)
    "enrofloxacin side effects in cats",
    # Russian — drug interactions
    "взаимодействие энрофлоксацина с другими препаратами",
    # Russian — antidote for poisoning
    "антидот при отравлении изониазидом у собак",
]


def main():
    print("Loading RAG (local first)...")
    rag = VetDermRAG()
    print()

    for q in QUERIES:
        print("=" * 70)
        print(f"QUERY: {q}")
        print("=" * 70)
        results = rag.retrieve(q, top_k=3)
        if not results:
            print("  (no results)")
            continue
        for i, r in enumerate(results, 1):
            score = r.get("score", 0)
            source = r.get("source", "?")
            ctype = r.get("chunk_type", "?")
            content = r.get("content", "")
            print(f"\n[{i}] score={score:.3f} | {source} | {ctype}")
            print(f"    {content[:300]}{'...' if len(content) > 300 else ''}")
        print()

    print("✓ All queries succeeded.")


if __name__ == "__main__":
    sys.exit(main())
