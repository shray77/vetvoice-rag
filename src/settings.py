"""VetVoice RAG — единый источник конфигурации.

Приоритет (от высшего к низшему):
  1. аргументы конструктора
  2. переменные окружения с префиксом `VETVOICE_`
  3. `.env`
  4. `configs/config.yaml`
  5. значения по умолчанию в классе

Так выглядит «одна правда»: и `app.py`, и `src/api/app.py`, и `src/rag/retriever.py`
читают одни и те же поля отсюда, а не из собственных дефолтов.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any, ClassVar

import yaml
from pydantic import Field
from pydantic_settings import (
    BaseSettings,
    PydanticBaseSettingsSource,
    SettingsConfigDict,
)

ROOT = Path(__file__).resolve().parent.parent


def _config_path() -> Path:
    env_path = os.environ.get("VETVOICE_CONFIG")
    if env_path:
        return Path(env_path)
    return ROOT / "configs" / "config.yaml"


class YamlSettingsSource(PydanticBaseSettingsSource):
    """Читает configs/config.yaml и приводит его к плоским именам полей."""

    # yaml key -> settings field
    _MAP: ClassVar[dict[tuple[str, str], str]] = {
        ("api", "host"): "api_host",
        ("api", "port"): "api_port",
        ("api", "cors_origins"): "cors_origins",
        ("rag", "local_dir"): "rag_local_dir",
        ("rag", "hf_dir"): "rag_hf_dir",
        ("rag", "repo_id"): "rag_repo_id",
        ("rag", "top_k"): "rag_top_k",
        ("rag", "mode"): "rag_mode",
        ("rag", "hybrid_alpha"): "rag_hybrid_alpha",
        ("rag", "max_context_chars"): "rag_max_context_chars",
        ("rag", "min_score"): "rag_min_score",
        ("zai", "config_path"): "zai_config_path",
        ("zai", "base_url"): "zai_base_url",
        ("zai", "models"): "_zai_models",
        ("logging", "level"): "log_level",
    }

    def __init__(self, settings_cls, path: Path):
        super().__init__(settings_cls)
        self._data = self._flatten(path)

    @classmethod
    def _flatten(cls, path: Path) -> dict[str, Any]:
        try:
            with open(path, "r", encoding="utf-8") as f:
                raw = yaml.safe_load(f) or {}
        except FileNotFoundError:
            return {}
        except Exception as e:  # noqa: BLE001 - конфиг не должен ронять приложение
            print(f"[warn] cannot parse {path}: {e}")
            return {}

        flat: dict[str, Any] = {}
        for (section, key), field in cls._MAP.items():
            value = (raw.get(section) or {}).get(key)
            if value in (None, ""):
                continue
            if field == "_zai_models":
                if isinstance(value, dict):
                    if value.get("vlm"):
                        flat["vlm_model"] = value["vlm"]
                    if value.get("llm"):
                        flat["llm_model"] = value["llm"]
                continue
            flat[field] = value
        return flat

    def get_field_value(self, field: Any, field_name: str):
        return self._data.get(field_name), field_name, False

    def __call__(self) -> dict[str, Any]:
        return dict(self._data)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="VETVOICE_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # ─── API ────────────────────────────────────────────────────────────────
    api_host: str = "0.0.0.0"
    api_port: int = 7860
    cors_origins: list[str] = Field(default_factory=lambda: ["*"])

    # ─── RAG ────────────────────────────────────────────────────────────────
    # Пустой local_dir в config.yaml означает «использовать <repo>/knowledge_base».
    rag_local_dir: str | None = None
    rag_hf_dir: str = "/tmp/vet_rag"
    rag_repo_id: str = "shrayyyy/vet-derm-rag"
    rag_top_k: int = 5
    # Режим ретривера: "tfidf" (только TF-IDF), "hybrid" (TF-IDF + embeddings через
    # RRF, рекомендуемый дефолт), "embedding" (только dense). TF-IDF всегда —
    # фолбэк, если эмбеддинг-индекс/модель недоступны.
    rag_mode: str = "hybrid"
    # Вес TF-IDF в RRF-гибриде (alpha): score = alpha*rrf(tfidf) + (1-alpha)*rrf(emb).
    rag_hybrid_alpha: float = 0.5
    rag_max_context_chars: int = 5000
    rag_min_score: float = 0.01
    # Репозиторий базы знаний публичный — токен нужен только для приватных.
    hf_token: str | None = None

    # ─── Z AI / GLM ─────────────────────────────────────────────────────────
    # Публичный endpoint. internal-api.z.ai резолвится в приватный IP и
    # недоступен ни с телефона, ни с HF Spaces, ни из Docker.
    zai_base_url: str = "https://api.z.ai/api/paas/v4"
    zai_config_path: str = "/etc/.z-ai-config"
    llm_model: str = "glm-4.5-flash"
    vlm_model: str = "glm-4.6v"
    glm_api_key: str | None = None

    # ─── Безопасность ───────────────────────────────────────────────────────
    # Если список пуст — API работает в открытом режиме (для локальной разработки),
    # но громко предупреждает в логе и отдаёт auth_enabled=false в /v1/health.
    api_keys: list[str] = Field(default_factory=list)
    rate_limit_per_minute: int = 30
    # Whitelist разрешённых моделей (соответствует AppModels в Flutter-клиенте).
    # По умолчанию — курируемый «рекомендованный» набор:
    #   чат:  glm-4.5-flash (free), glm-4.7-flash (free, 203K)
    #   VLM:  glm-4.6v (plan),       glm-5v-turbo (plan, новая)
    # Если переопределить через env (ZAI_ALLOWED_MODELS, через запятую) —
    # разрешены будут только перечисленные. Пустой список (default_factory=list)
    # означал бы «только llm_model/vlm_model» — здесь сразу заполнен актуальным набором.
    allowed_models: list[str] = Field(
        default_factory=lambda: [
            "glm-4.5-flash",
            "glm-4.7-flash",
            "glm-4.6v",
            "glm-5v-turbo",
        ]
    )
    max_tokens_limit: int = 2048

    # ─── Прочее ─────────────────────────────────────────────────────────────
    log_level: str = "INFO"

    @property
    def auth_enabled(self) -> bool:
        return bool(self.api_keys)

    @property
    def effective_local_dir(self) -> str:
        return self.rag_local_dir or str(ROOT / "knowledge_base")

    def allowed_model_names(self) -> set:
        """Множество разрешённых моделей. По умолчанию — только сконфигурированные."""
        if self.allowed_models:
            return set(self.allowed_models)
        return {self.llm_model, self.vlm_model}

    @classmethod
    def settings_customise_sources(
        cls,
        settings_cls,
        init_settings: PydanticBaseSettingsSource,
        env_settings: PydanticBaseSettingsSource,
        dotenv_settings: PydanticBaseSettingsSource,
        file_secret_settings: PydanticBaseSettingsSource,
    ):
        return (
            init_settings,
            env_settings,
            dotenv_settings,
            YamlSettingsSource(settings_cls, _config_path()),
            file_secret_settings,
        )


_settings: Settings | None = None


def get_settings() -> Settings:
    global _settings
    if _settings is None:
        _settings = Settings()
    return _settings


def reload_settings() -> Settings:
    """Перечитать конфиг (используется в тестах)."""
    global _settings
    _settings = Settings()
    return _settings
