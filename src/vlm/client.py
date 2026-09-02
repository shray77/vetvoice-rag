"""VetVoice GLM Client — единый HTTP-клиент к Z AI / GLM.

Отсюда работают и VLM (анализ фото кожи), и текстовый LLM (RAG-ответ,
разбор диктовки в SOAP). Раньше было две копии: тут и в app.py.
Все параметры берутся из src/settings.py — хардкода URL и моделей нет.
"""

from __future__ import annotations

import base64
import io
import os
from typing import Any, Dict, Optional

import requests
from PIL import Image

from src.settings import get_settings

VLM_PROMPT = """You are a veterinary dermatologist examining a photo of an animal's skin condition.
Provide a detailed, structured description:

1. **Species & Breed** (if identifiable from the image)
2. **Primary Lesions**: papules, pustules, nodules, macules, plaques, wheals, vesicles, bullae, tumors
3. **Secondary Lesions**: scales, crusts, excoriations, erosions, ulcers,
   lichenification, hyperpigmentation, alopecia, comedones
4. **Distribution**: focal / multifocal / generalized / symmetric / asymmetric
5. **Body Regions**: face, ears, ventrum, axillae, inguinal, paws, dorsum, tail, perianal
6. **Pruritus Signs**: excoriations, self-trauma, lichenification, salivary staining
7. **Severity**: mild / moderate / severe
8. **Additional Observations**: discoloration, odor signs, discharge, swelling

Use precise veterinary dermatological terminology. Be specific about lesion morphology."""


class GLMClient:
    """Клиент GLM: vision + text. Одна реализация на всё приложение."""

    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        model: Optional[str] = None,
        vlm_model: Optional[str] = None,
    ):
        cfg = get_settings()
        self.api_key = api_key or cfg.glm_api_key or os.environ.get("GLM_API_KEY", "")
        self.base_url = (base_url or cfg.zai_base_url).rstrip("/")
        self.model = model or cfg.llm_model
        self.vlm_model = vlm_model or cfg.vlm_model

    # ─── Низкоуровневое ────────────────────────────────────────────────────

    @staticmethod
    def _image_to_base64(image: Image.Image) -> str:
        buffered = io.BytesIO()
        image.convert("RGB").save(buffered, format="JPEG", quality=85)
        return base64.b64encode(buffered.getvalue()).decode("utf-8")

    def _headers(self) -> Dict[str, str]:
        return {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

    def _call_api(self, payload: Dict[str, Any], timeout: int = 90) -> Dict[str, Any]:
        resp = requests.post(
            f"{self.base_url}/chat/completions",
            json=payload,
            headers=self._headers(),
            timeout=timeout,
        )
        if resp.status_code != 200:
            raise RuntimeError(f"API error {resp.status_code}: {resp.text[:300]}")
        return resp.json()

    @staticmethod
    def _content_of(result: Dict[str, Any]) -> str:
        return result["choices"][0]["message"]["content"]

    # ─── Публичные методы ──────────────────────────────────────────────────

    @property
    def configured(self) -> bool:
        return bool(self.api_key)

    def analyze_image(
        self,
        image: Image.Image,
        prompt: Optional[str] = None,
        max_tokens: int = 800,
        temperature: float = 0.3,
    ) -> str:
        """VLM-анализ фото. Возвращает описание поражений."""
        if not self.api_key:
            raise RuntimeError("GLM_API_KEY не задан")
        b64 = self._image_to_base64(image)
        payload = {
            "model": self.vlm_model,
            "messages": [{
                "role": "user",
                "content": [
                    {"type": "image_url",
                     "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
                    {"type": "text", "text": prompt or VLM_PROMPT},
                ],
            }],
            "max_tokens": max_tokens,
            "temperature": temperature,
        }
        return self._content_of(self._call_api(payload, timeout=60))

    def generate_text(
        self,
        system_prompt: str,
        user_message: str,
        max_tokens: int = 2000,
        temperature: float = 0.4,
    ) -> str:
        """Текстовая генерация (RAG-ответ, SOAP-разбор)."""
        if not self.api_key:
            raise RuntimeError("GLM_API_KEY не задан")
        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_message},
            ],
            "max_tokens": max_tokens,
            "temperature": temperature,
        }
        return self._content_of(self._call_api(payload, timeout=90))


# Обратная совместимость: старое имя класса и метод.
class GLMVisionClient(GLMClient):
    """Deprecated. Используй GLMClient."""

    def analyze_skin_image(self, image: Image.Image) -> str:
        if not self.api_key:
            return "[VLM: No API key configured. Set GLM_API_KEY environment variable.]"
        try:
            return self.analyze_image(image)
        except Exception as e:  # noqa: BLE001 - UI не должен падать
            return f"[VLM Error: {e}]"
