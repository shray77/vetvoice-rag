"""
VetVoice RAG — FastAPI application factory.

Creates a FastAPI app with:
  - /v1/chat/completions  (text chat via Z AI SDK)
  - /v1/chat/completions/vision  (image analysis via Z AI SDK)
  - /v1/rag/search  (RAG proxy to HF Space)
  - /v1/health  (health check)
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Any
import os
import httpx


def create_app() -> FastAPI:
    app = FastAPI(title="VetVoice RAG API", version="1.0.0")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Z AI config from environment or defaults
    ZAI_BASE_URL = os.environ.get("ZAI_BASE_URL", "https://internal-api.z.ai/v1")
    ZAI_API_KEY = os.environ.get("ZAI_API_KEY", "Z.ai")
    ZAI_TOKEN = os.environ.get("ZAI_TOKEN", "")
    ZAI_CHAT_ID = os.environ.get("ZAI_CHAT_ID", "")
    ZAI_USER_ID = os.environ.get("ZAI_USER_ID", "")

    HF_SPACE_URL = "https://shrayyyy-vetderm-ai.hf.space"
    RAG_API_PATH = "/gradio_api/call/rag_search"

    def get_headers():
        h = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {ZAI_API_KEY}",
            "X-Z-AI-From": "Z",
        }
        if ZAI_CHAT_ID:
            h["X-Chat-Id"] = ZAI_CHAT_ID
        if ZAI_USER_ID:
            h["X-User-Id"] = ZAI_USER_ID
        if ZAI_TOKEN:
            h["X-Token"] = ZAI_TOKEN
        return h

    # ─── Schemas ────────────────────────────────────────────────────────

    class Message(BaseModel):
        role: str
        content: Any  # str or list (for vision)

    class ChatRequest(BaseModel):
        model: str = "glm-4-flash"
        messages: List[Message]
        temperature: float = 0.7
        max_tokens: int = 2048
        thinking: Optional[dict] = None

    class RAGRequest(BaseModel):
        query: str

    # ─── Routes ─────────────────────────────────────────────────────────

    @app.get("/v1/health")
    async def health():
        return {"status": "ok", "version": "1.0.0"}

    @app.post("/v1/chat/completions")
    async def chat_completions(req: ChatRequest):
        body = req.model_dump()
        body.setdefault("thinking", {"type": "disabled"})

        async with httpx.AsyncClient(timeout=90) as client:
            resp = await client.post(
                f"{ZAI_BASE_URL}/chat/completions",
                headers=get_headers(),
                json=body,
            )
            return resp.json()

    @app.post("/v1/chat/completions/vision")
    async def vision_completions(req: ChatRequest):
        body = req.model_dump()
        body.setdefault("thinking", {"type": "disabled"})

        async with httpx.AsyncClient(timeout=90) as client:
            resp = await client.post(
                f"{ZAI_BASE_URL}/chat/completions/vision",
                headers=get_headers(),
                json=body,
            )
            return resp.json()

    @app.post("/v1/rag/search")
    async def rag_search(req: RAGRequest):
        async with httpx.AsyncClient(timeout=120) as client:
            # Step 1: Submit query to HF Space
            submit_resp = await client.post(
                f"{HF_SPACE_URL}{RAG_API_PATH}",
                headers={"Content-Type": "application/json"},
                json={"data": [req.query]},
            )
            if submit_resp.status_code != 200:
                return {"error": f"HF Space returned {submit_resp.status_code}"}

            event_id = submit_resp.json().get("event_id")
            if not event_id:
                return {"error": "No event_id from HF Space"}

            # Step 2: Get result
            result_resp = await client.get(f"{HF_SPACE_URL}{RAG_API_PATH}/{event_id}")
            result_text = result_resp.text

            # Parse SSE
            import re
            data_match = re.search(r"data:\s*(.+)", result_text)
            if not data_match:
                return {"error": "No data in SSE response"}

            import json
            result_data = json.loads(data_match.group(1))
            rag_text = result_data[0] if isinstance(result_data, list) else result_data

            return {"context": rag_text, "query": req.query}

    return app
