"""VetVoice Embedding Retriever — local, free, offline-first dense retrieval.

PROTOTYPE for the TF-IDF -> embeddings migration (see docs/rag_embeddings_migration_plan.md).
NOT wired into production yet. The plan:
  1. Keep TF-IDF (src/rag/retriever.py) as the always-available fallback.
  2. Add this dense retriever on top, merge with Reciprocal Rank Fusion (RRF).
  3. A/B against the gold set BEFORE flipping any flag.

Implementation: pure onnxruntime + tokenizers (NO torch, NO fastembed).
  - Model: sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
    (multilingual ~50 langs incl. RU+EN, 384-dim, ~241 MB, mean-pooled)
  - All files are expected LOCALLY under MODEL_DIR (set VETVOICE_EMBED_MODEL_DIR
    or use the default D:/vetvoice-models/fastembed/... snapshot path).
  - Zero network at build/query time. $0, offline.

No API key, no network. Only cost: the one-time model download (already done).
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Dict, List, Optional

import faiss
import numpy as np
from tokenizers import Tokenizer  # type: ignore
import onnxruntime as ort  # type: ignore

# Local KB dir for the embedding index — mirrors retriever.py layout.
_DEFAULT_LOCAL_DIR = str(Path(__file__).resolve().parent.parent.parent / "knowledge_base")

# Where the ONNX model + tokenizer live.
# Priority:
#   1. VETVOICE_EMBED_MODEL_DIR env (local path)
#   2. D: copy already downloaded
#   3. TEMP copy (fastembed default)
#   4. Download from HF Hub repo (shrayyyy/vet-derm-rag, path embed_model/)
HF_REPO = "shrayyyy/vet-derm-rag"
HF_MODEL_PATH = "embed_model"
MODEL_DIR = os.environ.get("VETVOICE_EMBED_MODEL_DIR") or (
    "D:/vetvoice-models/fastembed/"
    "models--qdrant--paraphrase-multilingual-MiniLM-L12-v2-onnx-Q/"
    "snapshots/faf4aa4225822f3bc6376869cb1164e8e3feedd0"
)
_TEMP_DIR = (
    "C:/Users/Администратор/AppData/Local/Temp/fastembed_cache/"
    "models--qdrant--paraphrase-multilingual-MiniLM-L12-v2-onnx-Q/"
    "snapshots/faf4aa4225822f3bc6376869cb1164e8e3feedd0"
)

MAX_LENGTH = 128


def _resolve_model_dir() -> str:
    for d in (MODEL_DIR, _TEMP_DIR):
        if Path(d, "model_optimized.onnx").exists():
            return d
    # Fall back to HF Hub download into a local cache dir.
    try:
        from huggingface_hub import snapshot_download
    except ImportError as e:
        raise FileNotFoundError("huggingface_hub not installed for model download") from e
    print(f"[Embed] Downloading model from HF Hub {HF_REPO}:{HF_MODEL_PATH} ...")
    local = snapshot_download(
        repo_id=HF_REPO,
        repo_type="model",
        allow_patterns=f"{HF_MODEL_PATH}/*",
    )
    model_dir = Path(local) / HF_MODEL_PATH
    if (model_dir / "model_optimized.onnx").exists():
        return str(model_dir)
    # snapshot_download keeps repo layout; search for the onnx file
    found = list(Path(local).rglob("model_optimized.onnx"))
    if found:
        return str(found[0].parent)
    raise FileNotFoundError(f"model_optimized.onnx not found after download in {local}")


class EmbedRetriever:
    """Dense (embedding) retriever with optional RRF fusion to a TF-IDF retriever."""

    def __init__(
        self,
        local_dir: Optional[str] = None,
        tfidf_retriever=None,
    ):
        self.local_dir = Path(local_dir or _DEFAULT_LOCAL_DIR)
        self.tfidf = tfidf_retriever  # optional VetDermRAG instance for hybrid
        self._model = None
        self._tokenizer = None
        self.index = None
        self.documents: List[Dict] = []
        self._load()

    # ─── lazy model/tokenizer load ──────────────────────────────────────
    def _get_model(self):
        if self._model is not None:
            return self._model, self._tokenizer
        model_dir = _resolve_model_dir()
        print(f"[Embed] Loading ONNX model from {model_dir} ...")
        self._tokenizer = Tokenizer.from_file(str(Path(model_dir) / "tokenizer.json"))
        so = ort.SessionOptions()
        so.intra_op_num_threads = 0  # use all cores
        so.inter_op_num_threads = 0
        self._model = ort.InferenceSession(
            str(Path(model_dir) / "model_optimized.onnx"),
            sess_options=so,
            providers=["CPUExecutionProvider"],
        )
        return self._model, self._tokenizer

    def _embed(self, texts: List[str], batch_size: int = 256) -> np.ndarray:
        model, tok = self._get_model()
        all_pooled: List[np.ndarray] = []
        for start in range(0, len(texts), batch_size):
            batch = texts[start : start + batch_size]
            # Tokenize (no special tokens; match fastembed/ST preprocessing)
            enc = tok.encode_batch(
                [t if t else " " for t in batch],
                add_special_tokens=False,
            )
            input_ids = []
            attn = []
            for e in enc:
                ids = list(e.ids)[:MAX_LENGTH]
                if not ids:
                    ids = [0]
                mask = [1] * len(ids)
                input_ids.append(ids)
                attn.append(mask)
            # pad
            max_len = max(len(x) for x in input_ids)
            for i in range(len(input_ids)):
                pad = max_len - len(input_ids[i])
                input_ids[i] = input_ids[i] + [0] * pad
                attn[i] = attn[i] + [0] * pad
            input_ids = np.array(input_ids, dtype=np.int64)
            attn = np.array(attn, dtype=np.int64)
            token_type = np.zeros_like(input_ids)

            outputs = model.run(
                None,
                {
                    "input_ids": input_ids,
                    "attention_mask": attn,
                    "token_type_ids": token_type,
                },
            )
            # last_hidden_state: (batch, seq, dim)
            hidden = outputs[0]
            mask_f = attn[:, :, None].astype(np.float32)
            pooled = (hidden * mask_f).sum(1) / mask_f.sum(1).clip(min=1e-9)
            all_pooled.append(pooled)
        pooled = np.vstack(all_pooled)
        # L2 normalize for cosine (FAISS IndexFlatIP)
        norms = np.linalg.norm(pooled, axis=1, keepdims=True).clip(min=1e-9)
        return (pooled / norms).astype("float32")

    # ─── load or build index ───────────────────────────────────────────
    def _load(self):
        idx_path = self.local_dir / "vet_derm_embed.faiss"
        meta_path = self.local_dir / "vet_derm_embed_meta.json"
        if idx_path.exists() and meta_path.exists():
            print(f"[Embed] Loading cached index from {self.local_dir}")
            # faiss (swig) on Windows cannot open paths with non-ASCII chars
            # (e.g. Cyrillic 'Администратор'). Copy to an ASCII temp path first.
            read_path = idx_path
            tmp = None
            if os.name == "nt":
                try:
                    import tempfile, shutil
                    tmp = Path("D:/tmp_embed_index.faiss")
                    tmp.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(idx_path, tmp)
                    read_path = tmp
                except Exception as e:
                    print(f"[Embed] warn: could not copy to ASCII tmp ({e}), trying direct")
            self.index = faiss.read_index(str(read_path))
            self.documents = json.loads(meta_path.read_text(encoding="utf-8"))
            print(f"[Embed] Loaded: {self.index.ntotal} vectors")
            return
        print("[Embed] No cached embedding index — call build_index() first.")

    def build_index(self, chunks: List[Dict]) -> None:
        """Embed all chunk contents and store a FAISS index + metadata."""
        self.local_dir.mkdir(parents=True, exist_ok=True)
        texts = [c["content"] for c in chunks]
        print(f"[Embed] Embedding {len(texts)} chunks ...")
        embeddings = self._embed(texts)
        dim = embeddings.shape[1]
        index = faiss.IndexFlatIP(dim)
        index.add(embeddings)
        faiss.write_index(index, str(self.local_dir / "vet_derm_embed.faiss"))

        meta = [
            {
                "chunk_id": c.get("chunk_id"),
                "source": c.get("source"),
                "conditions": c.get("conditions", []),
                "content": c.get("content", ""),
                "chunk_type": c.get("chunk_type", "general"),
            }
            for c in chunks
        ]
        (self.local_dir / "vet_derm_embed_meta.json").write_text(
            json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        self.index = index
        self.documents = meta
        print(f"[Embed] ✓ Index built: {index.ntotal} vectors, {dim} dims")

    # ─── search ───────────────────────────────────────────────────────
    def search(self, query: str, top_k: int = 5) -> List[Dict]:
        if self.index is None:
            return []
        q = self._embed([query])
        distances, indices = self.index.search(q, top_k)
        results: List[Dict] = []
        for dist, idx in zip(distances[0], indices[0]):
            if idx < 0 or idx >= len(self.documents):
                continue
            doc = self.documents[idx].copy()
            doc["score"] = float(dist)
            doc["embed_score"] = float(dist)
            results.append(doc)
        return results

    # ─── hybrid (RRF) ──────────────────────────────────────────────────
    def hybrid_search(
        self, query: str, top_k: int = 5, alpha: float = 0.5, rrf_k: int = 60
    ) -> List[Dict]:
        """Reciprocal Rank Fusion of embedding + TF-IDF results.

        alpha weights the combined RRF score (0.5 = equal). TF-IDF is the
        safety net: if embeddings are unavailable, it still returns results.
        """
        emb = self.search(query, top_k * 3)
        tfidf = self.tfidf.retrieve(query, top_k * 3) if self.tfidf else []

        emb_rank = {d.get("chunk_id"): i + 1 for i, d in enumerate(emb)}
        tfidf_rank = {d.get("chunk_id"): i + 1 for i, d in enumerate(tfidf)}

        all_ids = set(emb_rank) | set(tfidf_rank)
        fused: Dict[str, Dict] = {}
        for cid in all_ids:
            r_emb = emb_rank.get(cid, len(emb) + rrf_k)
            r_tf = tfidf_rank.get(cid, len(tfidf) + rrf_k)
            score = alpha / (rrf_k + r_emb) + (1 - alpha) / (rrf_k + r_tf)
            doc = next((d for d in emb if d.get("chunk_id") == cid), None)
            if doc is None:
                doc = next((d for d in tfidf if d.get("chunk_id") == cid), None)
            doc = dict(doc) if doc else {"chunk_id": cid}
            doc["score"] = score
            doc["rrf_emb_rank"] = r_emb
            doc["rrf_tfidf_rank"] = r_tf
            fused[cid] = doc

        ranked = sorted(fused.values(), key=lambda x: x["score"], reverse=True)
        return ranked[:top_k]


if __name__ == "__main__":
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent.parent))
    from scripts.build_rag import collect_local_chunks

    # Build mode:
    #   BUILD_FULL=1  -> full 13k index (CI / fast machine)
    #   otherwise     -> balanced SAMPLE (~1.5k) for local A/B (slow CPU ~230s/1k)
    all_chunks = collect_local_chunks()
    if os.environ.get("BUILD_FULL") == "1":
        print(f"\nBuilding FULL index on {len(all_chunks)} chunks")
        sampled = all_chunks
    else:
        CAPS = {
            "drugs.json": 200,
            "drugs_calc.json": 200,
            "drugs_registry.json": 200,
            "treatment_protocols.json": 200,
            "non_contagious_protocols.json": 100,
            "diseases.json": 200,
            "non_contagious_diseases.json": 100,
        }
        DROP_SOURCES = {"dosage_database.json"}
        sampled = []
        from collections import defaultdict
        counts = defaultdict(int)
        for c in all_chunks:
            src = c.get("source", "")
            if src in DROP_SOURCES:
                continue
            cap = CAPS.get(src, 0)
            if cap and counts[src] >= cap:
                continue
            sampled.append(c)
            counts[src] += 1
        print(f"\nSampled {len(sampled)} chunks for A/B (from {len(all_chunks)} total)")

    er = EmbedRetriever()
    er.build_index(sampled)
