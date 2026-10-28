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
  v1.2.0 — на vet-ds v2.3.2 «Научная периодика» (голос A + бирюза Vet Teal
  #0F766E/#2DD4BF, зеркально vet-insilico): токены `flutter/lib/theme/ds.dart`,
  гейт контраста `scripts/ds_gate.py` (70 пар AA), Prata-дисплей,
  радиусы ≤ 10, движение 160 мс, эмодзи в UI запрещены.

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
| `VETVOICE_RAG_REPO_REVISION` | Пин ревизии HF-репо базы (supply-chain) | — |
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

## Источник препаратов

Лекарственные базы (`drugs_calc`, `verified_dosages`, `diseases`, `drugs`,
`advanced/treatment_protocols`) — **канонический источник: репозиторий [vetvoice](https://github.com/shray77/vetvoice)**.
ВетЭко не ведёт свою копию, а синхронизируется:

```bash
make sync-drugs                                # из GitHub (raw.githubusercontent.com)
python3 scripts/sync_drugs_from_vetvoice.py --from ../vetvoice   # из локального клона
python3 scripts/sync_drugs_from_vetvoice.py --check             # проверка без записи (CI-ready)
```

Правила синка:
- 5 файлов — байт-в-байт из vetvoice;
- `dosage_database.json` — merge: общие записи из vetvoice, локальные
  дополнения сохраняются (исторически здесь их 13);
- правки препаратов делать **в vetvoice**, затем прогонять синк здесь.

Пуш в `assets/data/**` автоматически запускает CI-ворклоф `Build Embedding Index`
(перестройка плотного FAISS-индекса → HF Hub). После синка крупного объёма
(как 2026-10-20: verified_dosages 7 → 2 376 записей) HF Space стоит
передеплоить (`scripts/deploy_hf.py`), чтобы ретривер поднял свежий индекс.

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
- `tests/test_terms.py` — словари RU↔EN: уникальность ключей, кириллица
  значений, стоп-лист опечаток МНН. Лёгкий — запускается без ML-зависимостей
  (`python3 -m pytest tests/test_terms.py`).

CI: lint (ruff/flake8) → test (cov ≥ 30%) → docker-build → deployHF.

## Безопасность

API открыт по умолчанию (dev). Перед публикацией задай `VETVOICE_API_KEYS` —
включится проверка `X-API-Key`, rate limit и whitelist моделей. ⚠️ Дозировки —
ознакомительные, не заменяют консультацию ветврача.

### Supply-chain: pickle-артефакты из публичного HF-репо

Если локальной `knowledge_base/` нет, ретривер (`src/rag/retriever.py::_load`)
скачивает артефакты из публичного HF-репо `shrayyyy/vet-derm-rag` и делает
`pickle.load` векторизатора (`vet_derm_vectorizer.pkl`). Артефакты пересобирает
CI этого репозитория (воркфлоу «Build Embedding Index» из `assets/data/**`),
но ветка по умолчанию «плавающая»: скомпрометированный HF-аккаунт может
подменить pickle вредоносным. Митигации:

- пин ревизии: `VETVOICE_RAG_REPO_REVISION=<commit-хэш/тег>` — загрузка идёт
  строго из указанного снапшота; фактическая ревизия логируется строкой
  `[RAG] HF artifacts revision: ...`;
- локальная база `python3 scripts/build_rag.py` → `knowledge_base/` минует
  HF Hub вовсе;
- мониторинг лога ревизии на HF Space при непинованных деплоях.

Полный переход на JSON-конфиг векторизатора (vocabulary_ + idf_ — плоские
структуры, восстановление `TfidfVectorizer` вручную) — в бэклоге: объёмный
рефакторинг вне волны 184.

## Лицензия

MIT — см. `LICENSE`.

## Дисклеймер

ВетЭко (VetEco) — AI-ассистент, предоставляется «как есть», без гарантий. VLM-анализ фото, RAG-ответы и сгенерированные медкарты могут быть ошибочными и не являются диагнозом или назначением: решение принимает ветеринарный врач — даже если вы сами ветеринарный врач. Дисклеймер интегрирован в приложение: обязательный слайд согласия в онбординге, экран «Условия и дисклеймер» (офлайн, раздел «Юридическое» в настройках), системный промпт AI завершает ответы с дозировками напоминанием подтвердить у врача. В интерфейсе Space отображается постоянный дисклеймер.

Общие условия экосистемы: https://shray77.github.io/terms.html
