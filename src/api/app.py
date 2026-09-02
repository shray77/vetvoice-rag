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

Конфигурация — только через src/settings.py (env VETVOICE_* / .env /
configs/config.yaml). Хардкода URL и моделей здесь нет.
"""

from __future__ import annotations

import json
import logging
import secrets
import threading
import time
from typing import Any, Dict, List, Optional

import httpx
from fastapi import Depends, FastAPI, HTTPException, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import APIKeyHeader
from pydantic import BaseModel, Field

from src.rag.retriever import ru_localize
from src.rag.search import retrieve, get_rag as _search_get_rag
from src.settings import Settings, get_settings

logger = logging.getLogger("vetvoice.api")

# ─── Z AI config: re-read on every request ─────────────────────────────
# Кэш защищён локом: FastAPI обслуживает запросы конкурентно, а словарь
# один на процесс.

_config_lock = threading.Lock()
_config_cache: Dict[str, Any] = {"data": None, "ts": 0.0}
_CONFIG_TTL_SEC = 30.0

UPSTREAM_TIMEOUT_SEC = 90
VISION_TIMEOUT_SEC = 120
MAX_RAG_TOP_K = 20


def _load_zai_config() -> Dict[str, str]:
    """Read Z AI config from /etc/.z-ai-config with 30s cache (thread-safe)."""
    cfg = get_settings()
    path = cfg.zai_config_path

    now = time.time()
    with _config_lock:
        if _config_cache["data"] and (now - _config_cache["ts"]) < _CONFIG_TTL_SEC:
            return dict(_config_cache["data"])

        fresh: Dict[str, str] = {
            "baseUrl": cfg.zai_base_url,
            "apiKey": cfg.glm_api_key or "Z.ai",
            "chatId": "",
            "token": "",
            "userId": "",
        }

        try:
            with open(path, "r", encoding="utf-8") as f:
                file_cfg = json.load(f)
            fresh.update({k: v for k, v in file_cfg.items() if isinstance(v, str)})
        except FileNotFoundError:
            logger.debug("Z AI config %s not found, using settings defaults", path)
        except Exception as e:  # noqa: BLE001
            logger.warning("Failed to parse %s: %s", path, e)

        _config_cache["data"] = fresh
        _config_cache["ts"] = now
        return dict(fresh)


def _zai_headers() -> Dict[str, str]:
    """Build Z AI request headers from current config."""
    cfg = _load_zai_config()
    h: Dict[str, str] = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {cfg.get('apiKey', 'Z.ai')}",
        "X-Z-AI-From": "Z",
    }
    for header, key in (
        ("X-Chat-Id", "chatId"),
        ("X-User-Id", "userId"),
        ("X-Token", "token"),
    ):
        value = cfg.get(key)
        if value:
            h[header] = value
    return h


def _zai_base_url() -> str:
    return _load_zai_config().get("baseUrl") or get_settings().zai_base_url


# ─── RAG: lazy-loaded singleton (delegates to src.rag.search) ──────────

def get_rag():
    """Lazy-load the RAG retriever. Delegates to the shared singleton in
    src.rag.search so the TF-IDF index is loaded only once per process."""
    return _search_get_rag()


# ─── System prompt for RAG-augmented chat ──────────────────────────────

SYSTEM_PROMPT_VET = (
    "Ты — ветеринарный ИИ-ассистент VetVoice. "
    "Отвечай на русском языке, профессионально, но понятно. "
    "Используй предоставленный контекст из базы знаний. "
    "Если в контексте нет точного ответа, скажи об этом и дай общую рекомендацию. "
    "Всегда указывай дозировки, способы введения, периоды ожидания и противопоказания. "
    "При подозрении на зооноз или особо опасное заболевание — рекомендуй обратиться к ветврачу. "
    "Отвечай СТРОГО на русском; латинские/английские названия препаратов и болезней из "
    "контекста переводи на русский (торговое название или русское МНН). "
    "Каждый ответ с дозировкой заканчивай дисклеймером: это ИИ-ассистированный расчёт, "
    "перед применением нужна консультация ветеринарного врача."
)


# ─── Pydantic schemas ──────────────────────────────────────────────────


class Message(BaseModel):
    role: str
    content: Any  # str or list (for vision)


class ChatRequest(BaseModel):
    model: Optional[str] = None
    messages: List[Message]
    temperature: float = 0.7
    max_tokens: int = 2048
    thinking: Optional[dict] = None
    use_rag: bool = True       # if True, prepend RAG context to last user message
    rag_top_k: int = 5


class RAGRequest(BaseModel):
    query: str = Field(min_length=1, max_length=2000)
    top_k: int = Field(default=5, ge=1, le=MAX_RAG_TOP_K)


# ─── Auth & rate limiting ──────────────────────────────────────────────

_api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


async def require_api_key(api_key: Optional[str] = Depends(_api_key_header)) -> None:
    """Если VETVOICE_API_KEYS задан — требуем совпадение. Иначе открытый режим."""
    cfg = get_settings()
    if not cfg.auth_enabled:
        return
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing X-API-Key header"
        )
    if not any(secrets.compare_digest(api_key, known) for known in cfg.api_keys):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid API key"
        )


def _rate_limit_value() -> str:
    return f"{get_settings().rate_limit_per_minute}/minute"


def _apply_guardrails(body: Dict[str, Any], is_vision: bool = False) -> None:
    """Whitelist моделей и потолок max_tokens — чтобы прокси не сжигал квоту.

    is_vision=True — это эндпоинт VLM: если model не задан, дефолтим в
    cfg.vlm_model (vision-модель), а не в текстовый cfg.llm_model.
    """
    cfg = get_settings()
    allowed = cfg.allowed_model_names()
    model = body.get("model")
    if model and model not in allowed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Model '{model}' is not allowed. Allowed: {sorted(allowed)}",
        )
    if not model:
        body["model"] = cfg.vlm_model if is_vision else cfg.llm_model

    try:
        max_tokens = int(body.get("max_tokens", cfg.max_tokens_limit))
    except (TypeError, ValueError):
        max_tokens = cfg.max_tokens_limit
    body["max_tokens"] = max(1, min(max_tokens, cfg.max_tokens_limit))


def _proxy_response(resp: httpx.Response) -> Response:
    """Пробрасывает статус upstream.

    Без этого upstream 401/429 возвращался клиенту с HTTP 200, и клиент
    показывал текст ошибки как ответ ассистента.
    """
    try:
        payload = resp.json()
    except ValueError:
        payload = {"error": "upstream returned non-JSON", "detail": resp.text[:500]}


def _localize_payload(payload: Any) -> Any:
    """Replace Latin/English drug & disease names in the upstream answer with
    Russian. Fixes the RAG leak where GLM echoed raw INN names from context."""
    if isinstance(payload, dict):
        for choice in payload.get("choices", []) or []:
            if not isinstance(choice, dict):
                continue
            msg = choice.get("message")
            if isinstance(msg, dict) and isinstance(msg.get("content"), str):
                msg["content"] = ru_localize(msg["content"])
            delta = choice.get("delta")
            if isinstance(delta, dict) and isinstance(delta.get("content"), str):
                delta["content"] = ru_localize(delta["content"])
    return payload

    if resp.status_code == 200:
        return _localize_payload(payload)

    if resp.status_code == 429:
        raise HTTPException(status_code=429, detail="Upstream rate limit exceeded")
    if 400 <= resp.status_code < 500:
        raise HTTPException(status_code=resp.status_code, detail=payload)
    raise HTTPException(status_code=502, detail=f"Upstream error {resp.status_code}")


# ─── App factory ───────────────────────────────────────────────────────


def create_app(settings: Optional[Settings] = None) -> FastAPI:
    cfg = settings or get_settings()

    app = FastAPI(title="VetVoice RAG API", version="2.1.0")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=cfg.cors_origins,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    if not cfg.auth_enabled:
        logger.warning(
            "VETVOICE_API_KEYS is empty — API работает в ОТКРЫТОМ режиме. "
            "Любой может дергать /v1/chat/completions и тратить квоту. "
            "Задайте VETVOICE_API_KEYS перед деплоем в интернет."
        )

    # ─── Routes ─────────────────────────────────────────────────────────

    @app.get("/health")
    async def health_root():
        """Алиас для docker-compose healthcheck и keep-alive."""
        return {"status": "ok"}

    @app.get("/v1/health")
    async def health():
        zai = _load_zai_config()
        return {
            "status": "ok",
            "version": "2.1.0",
            "auth_enabled": cfg.auth_enabled,
            "zai_configured": bool(zai.get("token")),
            "zai_base_url": zai.get("baseUrl"),
        }

    @app.get("/v1/rag/stats")
    async def rag_stats(_: None = Depends(require_api_key)):
        try:
            rag = get_rag()
            return {
                "loaded": True,
                "n_vectors": rag.index.ntotal if rag.index else 0,
                "n_documents": len(rag.documents),
            }
        except Exception:  # noqa: BLE001
            # Детали только в лог: путь до ФС клиенту знать не нужно.
            logger.exception("RAG stats failed")
            return {"loaded": False, "error": "knowledge base unavailable"}

    @app.post("/v1/rag/search")
    async def rag_search(
        req: RAGRequest, _: None = Depends(require_api_key)
    ):
        """Direct local RAG retrieval — no HF Space hop."""
        try:
            rag = get_rag()
            results = retrieve(req.query, top_k=req.top_k)
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
        except Exception as e:  # noqa: BLE001
            logger.exception("RAG search failed")
            raise HTTPException(
                status_code=500, detail="RAG error: knowledge base unavailable"
            ) from e

    def _augment_with_rag(body: Dict[str, Any], top_k: int) -> None:
        """Дополняет последнее user-сообщение RAG-контекстом (in-place)."""
        messages = body.get("messages", [])
        if not messages:
            return

        last_user_idx = None
        for i in range(len(messages) - 1, -1, -1):
            if messages[i].get("role") == "user":
                last_user_idx = i
                break
        if last_user_idx is None:
            return

        last_msg = messages[last_user_idx]
        user_text = (
            last_msg["content"]
            if isinstance(last_msg["content"], str)
            else json.dumps(last_msg["content"], ensure_ascii=False)
        )

        try:
            rag = get_rag()
            results = retrieve(user_text, top_k=top_k)
        except Exception as e:  # noqa: BLE001
            # RAG недоступен — отвечаем без контекста, но не роняем запрос.
            logger.warning("RAG augmentation failed: %s", e)
            return

        if not results:
            return

        context = rag.format_context(results)
        messages[last_user_idx] = {
            "role": "user",
            "content": (
                f"Контекст из базы знаний VetVoice:\n{context}\n\n"
                f"Вопрос пользователя: {user_text}\n\n"
                f"Ответь на вопрос, опираясь на контекст. "
                f"Если контекст не релевантен — отвечай по общим знаниям."
            ),
        }

        # Системный промпт — ролью system, а не assistant.
        if not any(m.get("role") == "system" for m in messages):
            messages.insert(0, {"role": "system", "content": SYSTEM_PROMPT_VET})

        body["messages"] = messages

    @app.post("/v1/chat/completions")
    async def chat_completions(
        req: ChatRequest,
        request: Request,
        _: None = Depends(require_api_key),
    ):
        """Text chat via Z AI, with optional RAG context prepended."""
        _check_rate_limit(request)
        body = req.model_dump(exclude_none=True)
        body.setdefault("thinking", {"type": "disabled"})

        if req.use_rag:
            _augment_with_rag(body, min(req.rag_top_k, MAX_RAG_TOP_K))

        _apply_guardrails(body)

        base = _zai_base_url().rstrip("/")
        headers = _zai_headers()

        try:
            async with httpx.AsyncClient(timeout=UPSTREAM_TIMEOUT_SEC) as client:
                resp = await client.post(
                    f"{base}/chat/completions", headers=headers, json=body
                )
                return _proxy_response(resp)
        except httpx.RequestError as e:
            raise HTTPException(
                status_code=502, detail="Z AI request failed"
            ) from e

    @app.post("/v1/chat/completions/vision")
    async def vision_completions(
        req: ChatRequest,
        request: Request,
        _: None = Depends(require_api_key),
    ):
        """Image analysis via Z AI VLM endpoint."""
        _check_rate_limit(request)
        body = req.model_dump(exclude_none=True)
        body.setdefault("thinking", {"type": "disabled"})
        _apply_guardrails(body, is_vision=True)

        base = _zai_base_url().rstrip("/")
        headers = _zai_headers()

        try:
            async with httpx.AsyncClient(timeout=VISION_TIMEOUT_SEC) as client:
                resp = await client.post(
                    f"{base}/chat/completions/vision", headers=headers, json=body
                )
                return _proxy_response(resp)
        except httpx.RequestError as e:
            raise HTTPException(
                status_code=502, detail="Z AI vision request failed"
            ) from e

    @app.get("/")
    async def root():
        return {
            "name": "VetVoice RAG API",
            "version": "2.1.0",
            "endpoints": [
                "GET  /health",
                "GET  /v1/health",
                "GET  /v1/rag/stats",
                "POST /v1/rag/search",
                "POST /v1/chat/completions",
                "POST /v1/chat/completions/vision",
            ],
        }

    return app


# ─── Rate limiting ─────────────────────────────────────────────────────
# Простой in-memory счётчик на процесс. Для одного инстанса (HF Space,
# docker-compose) этого достаточно; для нескольких реплик нужен Redis.

_rate_state: Dict[str, List[float]] = {}
_rate_lock = threading.Lock()


def _check_rate_limit(request: Request) -> None:
    cfg = get_settings()
    limit = cfg.rate_limit_per_minute
    if limit <= 0:
        return

    if cfg.auth_enabled:
        key = request.headers.get("X-API-Key", "")
    else:
        client = request.client
        key = client.host if client else "unknown"

    now = time.time()
    window = 60.0
    with _rate_lock:
        hits = [t for t in _rate_state.get(key, []) if now - t < window]
        if len(hits) >= limit:
            _rate_state[key] = hits
            raise HTTPException(
                status_code=429,
                detail=f"Rate limit exceeded: {limit} requests/minute",
            )
        hits.append(now)
        _rate_state[key] = hits


# For `uvicorn src.api.app:app` style invocation
app = create_app()
