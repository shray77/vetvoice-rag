# VetVoice RAG (VetEcosystem)

Ветеринарный AI-ассистент: VLM-диагностика по фото кожи, RAG-поиск по базе
знаний, диктовка → SOAP-медкарта и калькулятор дозировок. Веб-интерфейс на
Gradio + FastAPI-бэкенд (прокси к Z.AI GLM) + Flutter-клиент.

## Архитектура

- `app.py` — Gradio UI (VLM + RAG + диктовка + дозы). Единый источник правды для
  RAG и GLM — `src/rag/retriever.py` и `src/vlm/client.py`.
- `src/api/app.py` — FastAPI: `/v1/chat/completions`, `/v1/chat/completions/vision`,
  `/v1/rag/search`, `/v1/health`, `/health`. Проксирует Z.AI (`glm-4.5-flash` /
  `glm-4.6v`) с RAG-аугментацией, API-ключом (`X-API-Key`), rate-limit и whitelist
  моделей.
- `src/rag/retriever.py` — FAISS + TF-IDF гибридный ретривер (RU↔EN словари,
  keyword boost по `conditions`). Грузит локально из `knowledge_base/` или с HF Hub
  (`shrayyyy/vet-derm-rag`, публично).
- `src/settings.py` — единая конфигурация (env `VETVOICE_*` → `.env` →
  `configs/config.yaml` → дефолты).
- `flutter/` — мобильный клиент (Dart). Данные из `assets/data/` копируются в
  `flutter/assets/data` на сборке (см. `Makefile` / `flutter-build.yml`).

## Быстрый старт

### Gradio UI (локально)
```bash
pip install -r requirements.txt
cp .env.example .env   # впиши GLM_API_KEY
python app.py          # http://localhost:7860
```

### API (FastAPI)
```bash
pip install -r requirements.txt
make run               # uvicorn src.main:app --reload  → http://localhost:7860
```

### Docker
```bash
docker compose up -d   # собирает образ и поднимает Gradio на :7860
```

### Flutter
```bash
make flutter-sync-assets     # cp assets/data -> flutter/assets/data
make flutter-build-apk       # релизный APK
```

## Конфигурация

Копия `.env.example` → `.env`. Все ключи с префиксом `VETVOICE_` перекрывают
`configs/config.yaml`.

| Переменная | Назначение | Дефолт |
|---|---|---|
| `GLM_API_KEY` | Ключ Z.AI (https://z.ai/manage-apikey/apikey-list) | — |
| `VETVOICE_ZAI_BASE_URL` | Публичный endpoint | `https://api.z.ai/api/paas/v4` |
| `VETVOICE_LLM_MODEL` | Текстовая модель | `glm-4.5-flash` |
| `VETVOICE_VLM_MODEL` | Визуальная модель | `glm-4.6v` |
| `VETVOICE_API_KEYS` | Через запятую; если пусто — открытый режим | — |
| `VETVOICE_RATE_LIMIT_PER_MINUTE` | Rate limit | `30` |
| `VETVOICE_RAG_TOP_K` | Число чанков | `5` |
| `VETVOICE_KB_DIR` | Локальная база знаний | `<repo>/knowledge_base` |
| `HF_TOKEN` | Только для приватных репо / загрузки | — |

> ⚠️ `internal-api.z.ai` и `open.bigmodel.cn` **не использовать** — приватный IP /
> недоступны снаружи. Только `api.z.ai/api/paas/v4`.

## API

| Метод | Путь | Назначение |
|---|---|---|
| GET | `/health`, `/v1/health` | Liveness / статус (`auth_enabled`, `zai_base_url`) |
| POST | `/v1/chat/completions` | Чат с RAG-контекстом (`use_rag`, `rag_top_k`) |
| POST | `/v1/chat/completions/vision` | VLM-анализ изображения |
| POST | `/v1/rag/search` | Прямой ретрив из локальной базы |
| GET | `/v1/rag/stats` | Статистика индекса |

## База знаний

Локально: `python scripts/build_rag.py` → `knowledge_base/`. В проде ретривер тянет
с HF Hub (`shrayyyy/vet-derm-rag`). Сборка/деплой в HF Space — через
`scripts/deploy_hf.py` (шлёт `app.py`, `requirements.txt`, `Dockerfile`, `src/`,
`configs/`).

## Тесты / CI

```bash
pytest tests/ -v --cov=src
```
- `tests/test_api.py` — FastAPI через `TestClient` (offline).
- `tests/test_rag.py` — RU↔EN перевод запросов.
- `tests/test_client.py` — единый `GLMClient` (мок httpx).

CI: lint (ruff/flake8) → test (cov ≥ 30%) → docker-build → deployHF.

## Безопасность

API открыт по умолчанию (dev). Перед публикацией задай `VETVOICE_API_KEYS` —
включится проверка `X-API-Key`, rate limit и whitelist моделей. ⚠️ Дозировки —
ознакомительные, не заменяют консультацию ветврача.

## Лицензия

MIT — см. `LICENSE`.
