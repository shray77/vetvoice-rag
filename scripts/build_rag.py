#!/usr/bin/env python3
"""Build RAG knowledge base — scrape Merck/MSD Vet Manuals and build FAISS index"""

import json
import os
import re
import sys
import pickle
import numpy as np
from typing import List, Dict

try:
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.preprocessing import normalize
    import faiss
    from huggingface_hub import HfApi, hf_hub_download
except ImportError:
    print("Install: pip install scikit-learn faiss-cpu huggingface_hub")
    sys.exit(1)


OUTPUT_DIR = "knowledge_base"
HF_REPO = "shrayyyy/vet-derm-rag"
HF_TOKEN = os.environ.get("HF_TOKEN", "")


def html_to_text(html: str) -> str:
    """Extract clean text from HTML"""
    text = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.DOTALL | re.IGNORECASE)
    text = re.sub(r'<style[^>]*>.*?</style>', '', text, flags=re.DOTALL | re.IGNORECASE)
    text = re.sub(r'<[^>]+>', ' ', text)
    text = text.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>')
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def chunk_text(text: str, chunk_size: int = 600, overlap: int = 150) -> List[str]:
    """Split text into overlapping chunks"""
    sentences = re.split(r'(?<=[.!?])\s+', text)
    chunks = []
    current = ""
    for sent in sentences:
        if len(current) + len(sent) > chunk_size and current:
            chunks.append(current.strip())
            words = current.split()
            current = " ".join(words[-overlap//5:]) + " " + sent
        else:
            current += " " + sent
    if current.strip():
        chunks.append(current.strip())
    return chunks


def build_index(chunks: List[Dict]) -> None:
    """Build TF-IDF + FAISS index from chunks"""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    texts = [c["content"] for c in chunks]

    vectorizer = TfidfVectorizer(
        max_features=10000, ngram_range=(1, 2),
        stop_words='english', min_df=1, max_df=0.95,
    )
    tfidf = vectorizer.fit_transform(texts).toarray().astype('float32')
    tfidf = normalize(tfidf, norm='l2')

    index = faiss.IndexFlatIP(tfidf.shape[1])
    index.add(tfidf)

    faiss.write_index(index, os.path.join(OUTPUT_DIR, "vet_derm_faiss.index"))
    with open(os.path.join(OUTPUT_DIR, "vet_derm_vectorizer.pkl"), 'wb') as f:
        pickle.dump(vectorizer, f)

    # Save retrieval store
    store = [{"chunk_id": c["chunk_id"], "source": c["source"],
              "conditions": c.get("conditions", []), "content": c["content"]}
             for c in chunks]
    with open(os.path.join(OUTPUT_DIR, "vet_derm_retrieval_store.json"), 'w') as f:
        json.dump(store, f, ensure_ascii=False, indent=2)

    print(f"Built index: {index.ntotal} vectors, {tfidf.shape[1]} dims")


def upload_to_hub() -> None:
    """Upload knowledge base to HuggingFace Hub"""
    api = HfApi()
    for f in os.listdir(OUTPUT_DIR):
        if f.endswith(('.index', '.pkl', '.json')):
            api.upload_file(
                path_or_fileobj=os.path.join(OUTPUT_DIR, f),
                path_in_repo=f,
                repo_id=HF_REPO,
                repo_type="model",
                token=HF_TOKEN,
            )
            print(f"Uploaded: {f}")


def main():
    print("Loading existing knowledge base from HF Hub...")
    try:
        doc_path = hf_hub_download(
            repo_id=HF_REPO, filename="vet_derm_retrieval_store.json",
            token=HF_TOKEN, local_dir=OUTPUT_DIR,
        )
        with open(doc_path) as f:
            chunks = json.load(f)
        print(f"Loaded {len(chunks)} existing chunks")
    except Exception as e:
        print(f"Could not load existing KB: {e}")
        chunks = []

    # TODO: Add new scraping here using z-ai-web-dev-sdk or requests
    # For now, rebuild index from existing data
    if chunks:
        build_index(chunks)

    if HF_TOKEN:
        upload_to_hub()
    else:
        print("No HF_TOKEN set, skipping upload")


if __name__ == "__main__":
    main()
