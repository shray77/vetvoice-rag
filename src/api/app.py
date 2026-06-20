"""
VetVoice RAG — FastAPI application factory.

Routes:
  - POST /v1/chat/completions        Text chat via Z AI SDK (with local RAG context)
  - POST /v1/chat/completions/vision Image analysis via Z AI SDK
  - POST /v1/rag/search              Direct local RAG retrieval (no HF Space hop)
  - GET  /v1/health                  Health check
  - GET  /v1/rag/stats               Knowledge base stats

Z AI credentials are re-read from /etc/.z-ai-config on every request —
this solves the chatId TTL problem (credentials refresh automatically
when the IM session rotates them).
"""

from __future__ import annotations

import json
import os
import time
from typing import Any, Dict, List, Optional

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel


# ─── Z AI config: re-read on every request ─────────────────────────────

ZAI_CONFIG_PATH = os.environ.get("ZAI_CONFIG_PATH", "/etc/.z-ai-config")
ZAI_BASE_URL_FALLBACK = os.environ.get("ZAI_BASE_URL", "https://internal-api.z.ai/v1")

# Cache config for 30s — avoids re-reading file on every single request,
# but still picks up TTL-rotated credentials quickly.
_config_cache: Dict[str, Any] = {"data": None, "ts": 0.0}
_CONFIG_TTL_SEC = 30.0


def _load_zai_config() -> Dict[str, str]:
    """Read Z AI config from /etc/.z-ai-config with 30s cache."""
    now = time.time()
    if _config_cache["data"] and (now - _config_cache["ts"]) < _CONFIG_TTL_SEC:
        return _config_cache["data"]

    cfg: Dict[str, str] = {
        "baseUrl": ZAI_BASE_URL_FALLBACK,
        "apiKey": "Z.ai",
        "chatId": os.environ.get("ZAI_CHAT_ID", ""),
        "token": os.environ.get("ZAI_TOKEN", ""),
        "userId": os.environ.get("ZAI_USER_ID", ""),
    }

    try:
        with open(ZAI_CONFIG_PATH, "r", encoding="utf-8") as f:
            file_cfg = json.load(f)
        cfg.update({k: v for k, v in file_cfg.items() if isinstance(v, str)})
    except FileNotFoundError:
        print(f"[warn] {ZAI_CONFIG_PATH} not found, using env defaults")
    except Exception as e:
        print(f"[warn] Failed to parse {ZAI_CONFIG_PATH}: {e}")

    _config_cache["data"] = cfg
    _config_cache["ts"] = now
    return cfg


def _zai_headers() -> Dict[str, str]:
    """Build Z AI request headers from current config."""
    cfg = _load_zai_config()
    h: Dict[str, str] = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {cfg.get('apiKey', 'Z.ai')}",
        "X-Z-AI-From": "Z",
    }
    if cfg.get("chatId"):
        h["X-Chat-Id"] = cfg["chatId"]
    if cfg.get("userId"):
        h["X-User-Id"] = cfg["userId"]
    if cfg.get("token"):
        h["X-Token"] = cfg["token"]
    return h


def _zai_base_url() -> str:
    return _load_zai_config().get("baseUrl", ZAI_BASE_URL_FALLBACK)


# ─── RAG: lazy-loaded singleton ────────────────────────────────────────

_rag_instance = None


def _get_rag():
    """Lazy-load the RAG retriever. Singleton — first call loads the index."""
    global _rag_instance
    if _rag_instance is None:
        from src.rag.retriever import VetDermRAG
        _rag_instance = VetDermRAG()
    return _rag_instance


# ─── System prompt for RAG-augmented chat ──────────────────────────────

SYSTEM_PROMPT_VET = (
    "Ты — ветеринарный ИИ-ассистент VetVoice. "
    "Отвечай на русском языке, профессионально, но понятно. "
    "Используй предоставленный контекст из базы знаний. "
    "Если в контексте нет точного ответа, скажи об этом и дай общую рекомендацию. "
    "Всегда указывай дозировки, способы введения, периоды ожидания и противопоказания. "
    "При подозрении на зооноз или особо опасное заболевание — рекомендуй обратиться к ветврачу."
)


# ─── Pydantic schemas ──────────────────────────────────────────────────

class Message(BaseModel):
    role: str
    content: Any  # str or list (for vision)


class ChatRequest(BaseModel):
    model: str = "glm-4-flash"
    messages: List[Message]
    temperature: float = 0.7
    max_tokens: int = 2048
    thinking: Optional[dict] = None
    use_rag: bool = True       # if True, prepend RAG context to last user message
    rag_top_k: int = 5


class RAGRequest(BaseModel):
    query: str
    top_k: int = 5


# ─── App factory ───────────────────────────────────────────────────────

def create_app() -> FastAPI:
    app = FastAPI(title="VetVoice RAG API", version="2.0.0")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ─── Routes ─────────────────────────────────────────────────────────

    @app.get("/v1/health")
    async def health():
        cfg = _load_zai_config()
        return {
            "status": "ok",
            "version": "2.0.0",
            "zai_configured": bool(cfg.get("chatId") and cfg.get("token")),
            "zai_base_url": cfg.get("baseUrl"),
            "zai_chat_id_prefix": cfg.get("chatId", "")[:20] + "..." if cfg.get("chatId") else None,
            "config_path": ZAI_CONFIG_PATH,
        }

    @app.get("/v1/rag/stats")
    async def rag_stats():
        try:
            rag = _get_rag()
            return {
                "loaded": True,
                "n_vectors": rag.index.ntotal if rag.index else 0,
                "n_documents": len(rag.documents),
                "local_dir": rag.local_dir,
            }
        except Exception as e:
            return {"loaded": False, "error": str(e)}

    @app.post("/v1/rag/search")
    async def rag_search(req: RAGRequest):
        """Direct local RAG retrieval — no HF Space hop."""
        try:
            rag = _get_rag()
            results = rag.retrieve(req.query, top_k=req.top_k)
            context = rag.format_context(results)
            return {
                "query": req.query,
                "n_results": len(results),
                "results": [
                    {
                        "score": r.get("score", 0),
                        "tfidf_score": r.get("tfidf_score", 0),
                        "keyword_boost": r.get("keyword_boost", 0),
                        "source": r.get("source"),
                        "chunk_type": r.get("chunk_type"),
                        "conditions": r.get("conditions", []),
                        "content": r.get("content", "")[:500],
                    }
                    for r in results
                ],
                "context": context,
            }
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"RAG error: {e}")

    @app.post("/v1/chat/completions")
    async def chat_completions(req: ChatRequest):
        """Text chat via Z AI, with optional RAG context prepended."""
        body = req.model_dump()
        body.setdefault("thinking", {"type": "disabled"})

        messages = body.get("messages", [])

        # If RAG enabled and there's at least one user message, augment the last user msg
        if req.use_rag and messages:
            last_user_idx = None
            for i in range(len(messages) - 1, -1, -1):
                if messages[i].get("role") == "user":
                    last_user_idx = i
                    break
            if last_user_idx is not None:
                last_msg = messages[last_user_idx]
                user_text = (
                    last_msg["content"]
                    if isinstance(last_msg["content"], str)
                    else json.dumps(last_msg["content"], ensure_ascii=False)
                )
                try:
                    rag = _get_rag()
                    results = rag.retrieve(user_text, top_k=req.rag_top_k)
                    if results:
                        context = rag.format_context(results)
                        augmented = (
                            f"Контекст из базы знаний VetVoice:\n{context}\n\n"
                            f"Вопрос пользователя: {user_text}\n\n"
                            f"Ответь на вопрос, опираясь на контекст. "
                            f"Если контекст не релевантен — отвечай по общим знаниям."
                        )
                        # Replace last user message with augmented version
                        messages[last_user_idx] = {
                            "role": "user",
                            "content": augmented,
                        }
                        # Prepend system prompt if no system message
                        if not any(m.get("role") in ("system", "assistant")
                                   for m in messages[:1]):
                            messages.insert(0, {
                                "role": "assistant",
                                "content": SYSTEM_PROMPT_VET,
                            })
                        body["messages"] = messages
                except Exception as e:
                    print(f"[warn] RAG augmentation failed: {e}")

        base = _zai_base_url()
        headers = _zai_headers()

        try:
            async with httpx.AsyncClient(timeout=90) as client:
                resp = await client.post(
                    f"{base}/chat/completions",
                    headers=headers,
                    json=body,
                )
                return resp.json()
        except httpx.RequestError as e:
            raise HTTPException(status_code=502, detail=f"Z AI request failed: {e}")

    @app.post("/v1/chat/completions/vision")
    async def vision_completions(req: ChatRequest):
        """Image analysis via Z AI VLM endpoint."""
        body = req.model_dump()
        body.setdefault("thinking", {"type": "disabled"})

        base = _zai_base_url()
        headers = _zai_headers()

        try:
            async with httpx.AsyncClient(timeout=120) as client:
                resp = await client.post(
                    f"{base}/chat/completions/vision",
                    headers=headers,
                    json=body,
                )
                return resp.json()
        except httpx.RequestError as e:
            raise HTTPException(status_code=502, detail=f"Z AI vision request failed: {e}")

    @app.get("/")
    async def root():
        return {
            "name": "VetVoice RAG API",
            "version": "2.0.0",
            "endpoints": [
                "GET  /v1/health",
                "GET  /v1/rag/stats",
                "POST /v1/rag/search",
                "POST /v1/chat/completions",
                "POST /v1/chat/completions/vision",
            ],
        }

    return app


# For `uvicorn src.api.app:app` style invocation
app = create_app()
