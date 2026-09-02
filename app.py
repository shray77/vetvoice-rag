"""
VetVoice — Veterinary AI assistant (Gradio UI)
Tabs: VLM (GLM-4V) | RAG Search | Dictation → SOAP | Dose Calculator
"""

import logging

import gradio as gr
import json
from PIL import Image

logger = logging.getLogger("vetvoice.ui")


# ============================================================
# RAG COMPONENTS
# ============================================================
# Single source of truth: src/rag/retriever.py (shared with the FastAPI backend).
from src.rag.retriever import VetDermRAG  # noqa: E402

# ============================================================
# GLM API CLIENT

# ============================================================
from src.vlm.client import GLMClient  # noqa: E402

# ============================================================
# SYSTEM PROMPTS
# ============================================================

VLM_DIAGNOSIS_PROMPT = """You are VetVoice, an expert veterinary dermatologist AI. Analyze the image and provide:

### First Analysis
- **Patient:** species, breed (if identifiable)
- **Lesion type:** primary + secondary lesions
- **Localization:** body regions
- **Pruritus:** present/absent, severity

### Differential Diagnosis (by probability)
1. **[Diagnosis]** — probability [%] — reasoning
2. **[Diagnosis]** — probability [%] — reasoning
3. **[Diagnosis]** — probability [%] — reasoning

### Recommended Diagnostic Tests
1. [Test] — purpose

### Treatment Recommendations
**Systemic therapy:** drug, dosage, route, duration
**Topical therapy:** drug, frequency, duration
**Monitoring:** what to check

Respond in the SAME language the user writes in.
Always add: This is AI-assisted analysis, not a veterinary diagnosis. Consult a licensed veterinarian."""

RAG_SYSTEM_PROMPT = """Ты — ветеринарный AI-ассистент VetEcosystem с доступом к базе ветеринарных знаний.
Отвечай на русском языке, используя предоставленный RAG-контекст.

Правила:
1. Давай точные, научно обоснованные ответы
2. Указывай дозировки в мг/кг с путём введения
3. Предупреждай о противопоказаниях и взаимодействиях
4. Если не уверен — скажи об этом прямо
5. Ссылайся на источники из контекста
6. Структурируй ответ с заголовками"""

DICTATION_SYSTEM_PROMPT = """Ты — ветеринарный AI-ассистент, специализирующийся на структурировании клинических записей.
Твоя задача — разобрать текст диктовки ветеринарного врача и извлечь из него структурированные данные в формате JSON.

ВАЖНО: Ответь ТОЛЬКО валидным JSON, без Markdown-обёрток, без пояснений, без ```json блоков.
Просто чистый JSON объект.

Структура JSON:
{
  "animal_type": "вид животного",
  "animal_breed": "порода или null",
  "animal_weight": вес_число_или_null,
  "animal_age": возраст_число_или_null,
  "animal_age_unit": "лет/месяцев/недель",
  "animal_gender": "м/ж/кастрирован/null",
  "animal_id": "кличка/номер или null",
  "complaint": "жалоба владельца (Subjective)",
  "anamnesis": "анамнез заболевания (Subjective)",
  "temperature": температура_или_null,
  "heart_rate": пульс_или_null,
  "respiratory_rate": чдд_или_null,
  "physical_exam": "данные осмотра (Objective)",
  "mucous_membranes": "слизистые или null",
  "lymph_nodes": "лимфоузлы или null",
  "skin_coat": "кожа и шерсть или null",
  "diagnosis": "основной диагноз (Assessment)",
  "differential_dx": "дифф. диагноз или null",
  "disease_severity": "лёгкая/средняя/тяжёлая/null",
  "prescribed_drugs": [
    {
      "name": "название препарата",
      "inn": "МНН или null",
      "dose_per_kg": доза_мг_кг_или_null,
      "total_dose": общая_доза_или_null,
      "dose_unit": "мг/мл/таб",
      "route": "путь введения",
      "frequency": "кратность",
      "duration_days": дней_или_null,
      "notes": "заметки или null"
    }
  ],
  "procedures": "процедуры",
  "diet": "рекомендации по кормлению",
  "follow_up": "повторный приём/контроль",
  "notes": "дополнительные заметки"
}

Правила:
1. Если значение не упоминается — null
2. Дозировки извлекай точно (мг/кг, путь, кратность)
3. Температура в градусах Цельсия (число)
4. Диагноз формулируй кратко, профессионально
5. Если врач сказал "подозрение"/"вероятно" — укажи в diagnosis
6. Все текстовые поля на русском языке"""


# ============================================================
# DOSE CALCULATOR DATA
# ============================================================

COMMON_DRUGS = {
    "амоксициллин": {"dose_mg_kg": 10, "route": "внутрь", "frequency": "2 раза/день", "duration": 7, "unit": "мг/кг"},
    "амоксиклав": {"dose_mg_kg": 12.5, "route": "внутрь", "frequency": "2 раза/день", "duration": 7, "unit": "мг/кг"},
    "энрофлоксацин": {
        "dose_mg_kg": 5, "route": "внутрь/п/к", "frequency": "1 раз/день", "duration": 5, "unit": "мг/кг",
    },
    "марбофлоксацин": {"dose_mg_kg": 2, "route": "внутрь", "frequency": "1 раз/день", "duration": 5, "unit": "мг/кг"},
    "цефазолин": {"dose_mg_kg": 22, "route": "в/м/в/в", "frequency": "2-3 раза/день", "duration": 7, "unit": "мг/кг"},
    "цефовеицин": {"dose_mg_kg": 8, "route": "п/к", "frequency": "1 раз/14 дней", "duration": 14, "unit": "мг/кг"},
    "доксициклин": {"dose_mg_kg": 5, "route": "внутрь", "frequency": "2 раза/день", "duration": 14, "unit": "мг/кг"},
    "метронидазол": {"dose_mg_kg": 10, "route": "внутрь", "frequency": "2 раза/день", "duration": 7, "unit": "мг/кг"},
    "преднизолон": {
        "dose_mg_kg": 0.5, "route": "внутрь", "frequency": "1 раз/день", "duration": "схема", "unit": "мг/кг",
    },
    "метилпреднизолон": {
        "dose_mg_kg": 1, "route": "в/м", "frequency": "показания", "duration": "схема", "unit": "мг/кг",
    },
    "преднизон": {
        "dose_mg_kg": 0.5, "route": "внутрь", "frequency": "1-2 раза/день", "duration": "схема", "unit": "мг/кг",
    },
    "апоквел (оклацитиниб)": {
        "dose_mg_kg": 0.4, "route": "внутрь", "frequency": "2 раза/день→1 раз",
        "duration": "длительно", "unit": "мг/кг",
    },
    "циклоспорин": {
        "dose_mg_kg": 5, "route": "внутрь", "frequency": "1 раз/день", "duration": "длительно", "unit": "мг/кг",
    },
    "итраконазол": {"dose_mg_kg": 5, "route": "внутрь", "frequency": "1-2 раза/день", "duration": 21, "unit": "мг/кг"},
    "кетоконазол": {"dose_mg_kg": 5, "route": "внутрь", "frequency": "1 раз/день", "duration": 21, "unit": "мг/кг"},
    "флуконазол": {"dose_mg_kg": 5, "route": "внутрь", "frequency": "1 раз/день", "duration": 21, "unit": "мг/кг"},
    "селамектин": {"dose_mg_kg": 6, "route": "топически", "frequency": "1 раз/месяц", "duration": "1", "unit": "мг/кг"},
    "моксидектин": {
        "dose_mg_kg": 0.2, "route": "топически/внутрь", "frequency": "1 раз/месяц", "duration": "1", "unit": "мг/кг",
    },
    "ивермектин": {"dose_mg_kg": 0.3, "route": "п/к", "frequency": "1 раз/неделю", "duration": "4", "unit": "мг/кг"},
    "милбемицин": {
        "dose_mg_kg": 0.5, "route": "внутрь", "frequency": "1 раз/день", "duration": "длительно", "unit": "мг/кг",
    },
    "цетиризин": {
        "dose_mg_kg": 1, "route": "внутрь", "frequency": "1-2 раза/день",
        "duration": "симптоматически", "unit": "мг/кг",
    },
    "хлорфенирамин": {
        "dose_mg_kg": 0.5, "route": "внутрь", "frequency": "2 раза/день",
        "duration": "симптоматически", "unit": "мг/кг",
    },
    "омепразол": {"dose_mg_kg": 1, "route": "внутрь", "frequency": "1 раз/день", "duration": "14", "unit": "мг/кг"},
    "карпрофен": {"dose_mg_kg": 2.2, "route": "внутрь/п/к", "frequency": "1 раз/день", "duration": 5, "unit": "мг/кг"},
    "мелоксикам": {"dose_mg_kg": 0.1, "route": "внутрь", "frequency": "1 раз/день", "duration": 5, "unit": "мг/кг"},
    "травматин": {
        "dose_mg_kg": 0.1, "route": "п/к/в/м", "frequency": "1-2 раза/день", "duration": "5-7", "unit": "мл/кг",
    },
    "лидокаин": {
        "dose_mg_kg": 2, "route": "местно/инфильтрация", "frequency": "по показаниям", "duration": "1", "unit": "мг/кг",
    },
}

SPECIES_WEIGHT_DEFAULTS = {
    "Собака": 15, "Кошка": 4, "Кролик": 2, "Морская свинка": 0.8,
    "Хорёк": 1, "Попугай": 0.04, "Крыса": 0.3, "Хомяк": 0.04,
}


# ============================================================
# INIT
# ============================================================
print("Initializing VetEcosystem backend...")
rag = VetDermRAG()
glm = GLMClient()
print("VetEcosystem ready!")


# ============================================================
# TAB 1: VLM (Vision Language Model) — анализ изображений
# ============================================================
def vlm_analyze(image: Image.Image, mode: str) -> str:
    if image is None:
        return "Загрузите изображение"
    if not glm.configured:
        return "Ошибка: GLM_API_KEY не задан. Установите переменную окружения."

    image = image.convert("RGB")

    # ── Шаг 1: VLM описывает видимые поражения (без RAG) ──────────────
    lesion_prompt = (
        "Опиши ветеринарно-дерматологическими терминами, что видно на фото кожи животного: "
        "морфология первичных и вторичных элементов, локализация, распространённость, "
        "признаки зуда, предполагаемый вид/порода. Будь максимально конкретным — "
        "это пойдёт в поиск по базе знаний."
    )
    try:
        description = glm.analyze_image(image, lesion_prompt)
    except Exception as e:
        return f"Ошибка анализа изображения: {e}"

    # ── Шаг 2: ретрив из RAG ПО ОПИСАНИЮ фото, а не по хардкоду ──────
    rag_context = ""
    if rag.is_ready():
        # Ключевые слова режима уточняют, что именно искать в базе.
        mode_hint = {
            "Диагноз": "дифференциальный диагноз причины лечение",
            "Описание": "",
            "Тяжесть": "тяжесть прогноз",
            "Лечение": "терапия дозировка препараты",
        }.get(mode, "")
        query = f"{description}\n{mode_hint}".strip()
        results = rag.retrieve(query, top_k=5)
        if results:
            rag_context = rag.format_context(results, max_chars=3000)

    # ── Шаг 3: синтез финального ответа с RAG-контекстом ─────────────
    prompts = {
        "Диагноз": VLM_DIAGNOSIS_PROMPT,
        "Описание": (
            "Describe all visible skin lesions in detail: morphology, distribution, "
            "body regions. Use veterinary terminology."
        ),
        "Тяжесть": (
            "Assess the severity of the visible condition: mild, moderate, or severe. "
            "Explain your reasoning."
        ),
        "Лечение": (
            "Based on the visible skin condition, suggest a treatment approach with "
            "specific drug names, dosages (mg/kg), route, and duration."
        ),
    }
    prompt = prompts.get(mode, VLM_DIAGNOSIS_PROMPT)
    synthesis = (
        f"{prompt}\n\n"
        f"## Что видно на фото (описание VLM):\n{description}\n"
    )
    if rag_context:
        synthesis += (
            f"\n## Контекст из базы знаний (доказательная база):\n{rag_context}\n"
            f"Опирайся на контекст из базы знаний, где это уместно, и указывай источники.\n"
        )

    try:
        result = glm.generate_text(RAG_SYSTEM_PROMPT, synthesis, temperature=0.3)
        return result + "\n\n---\n*⚠️ AI-ассистированный анализ. Не заменяет консультацию ветеринара.*"
    except Exception as e:
        # Фолбэк: хотя бы вернём описание, если синтез не удался.
        return description + f"\n\n(⚠️ Не удалось сгенерировать ответ: {e})"


# ============================================================
# TAB 2: RAG Search — поиск по ветеринарной базе знаний
# ============================================================
def rag_search(query: str) -> str:
    if not query.strip():
        return "Введите поисковый запрос"
    if not rag.is_ready():
        return "RAG база знаний недоступна. Проверьте HF_TOKEN и доступ к shrayyyy/vet-derm-rag"

    results = rag.retrieve(query, top_k=5)
    if not results:
        return "Ничего не найдено. Попробуйте другой запрос."

    # Если есть GLM — генерируем ответ с контекстом
    if glm.configured:
        rag_context = rag.format_context(results)
        user_msg = (
            f"## Контекст из ветеринарной базы знаний:\n{rag_context}\n\n"
            f"## Вопрос:\n{query}\n\n"
            f"Ответь на вопрос, используя предоставленный контекст. Укажи источники."
        )
        try:
            answer = glm.generate_text(RAG_SYSTEM_PROMPT, user_msg, temperature=0.3)
            return answer
        except Exception as exc:  # noqa: BLE001
            logger.warning("RAG answer generation failed, showing raw results: %s", exc)
            # Fallback к простому выводу результатов

    # Fallback — просто показываем найденные чанки
    output_parts = []
    for i, r in enumerate(results):
        source = r.get("source", "Unknown")
        conditions = r.get("conditions", [])
        content = r.get("content", "")
        score = r.get("score", 0)
        output_parts.append(
            f"### [{i+1}] {source} (релевантность: {score:.2f})\n"
            f"**Заболевания:** {', '.join(conditions) if conditions else 'общее'}\n\n"
            f"{content}\n"
        )

    return "\n---\n".join(output_parts)


# ============================================================
# TAB 3: Диктовка → SOAP медкарта
# ============================================================
def dictation_parse(text: str) -> str:
    if not text.strip():
        return "Надиктуйте или введите текст записи"

    if not glm.configured:
        return "Ошибка: GLM_API_KEY не задан"

    try:
        raw_json = glm.generate_text(DICTATION_SYSTEM_PROMPT, text, temperature=0.2, max_tokens=2048)

        # Убираем markdown-обёртки
        raw_json = raw_json.strip()
        if raw_json.startswith("```json"):
            raw_json = raw_json[7:]
        elif raw_json.startswith("```"):
            raw_json = raw_json[3:]
        if raw_json.endswith("```"):
            raw_json = raw_json[:-3]
        raw_json = raw_json.strip()

        # Парсим JSON
        record = json.loads(raw_json)

        # Форматируем красивую медкарту
        lines = []
        lines.append("## Медицинская карта\n")

        # Пациент
        lines.append("### Пациент")
        lines.append(f"- **Вид:** {record.get('animal_type', '—')}")
        if record.get('animal_breed'):
            lines.append(f"- **Порода:** {record['animal_breed']}")
        if record.get('animal_weight'):
            lines.append(f"- **Вес:** {record['animal_weight']} кг")
        if record.get('animal_age'):
            unit = record.get('animal_age_unit', 'лет')
            lines.append(f"- **Возраст:** {record['animal_age']} {unit}")
        if record.get('animal_gender'):
            lines.append(f"- **Пол:** {record['animal_gender']}")
        if record.get('animal_id'):
            lines.append(f"- **Идентификация:** {record['animal_id']}")

        # S — Subjective
        lines.append("\n### S — Субъективно")
        if record.get('complaint'):
            lines.append(f"**Жалоба:** {record['complaint']}")
        if record.get('anamnesis'):
            lines.append(f"**Анамнез:** {record['anamnesis']}")

        # O — Objective
        lines.append("\n### O — Объективно")
        vitals = []
        if record.get('temperature'):
            vitals.append(f"Т: {record['temperature']}°C")
        if record.get('heart_rate'):
            vitals.append(f"ЧСС: {record['heart_rate']} уд/мин")
        if record.get('respiratory_rate'):
            vitals.append(f"ЧДД: {record['respiratory_rate']} /мин")
        if vitals:
            lines.append(f"**Витальные показатели:** {' | '.join(vitals)}")
        if record.get('physical_exam'):
            lines.append(f"**Клинический осмотр:** {record['physical_exam']}")
        if record.get('mucous_membranes'):
            lines.append(f"**Слизистые:** {record['mucous_membranes']}")
        if record.get('lymph_nodes'):
            lines.append(f"**Лимфоузлы:** {record['lymph_nodes']}")
        if record.get('skin_coat'):
            lines.append(f"**Кожа/шерсть:** {record['skin_coat']}")

        # A — Assessment
        lines.append("\n### A — Оценка")
        if record.get('diagnosis'):
            lines.append(f"**Диагноз:** {record['diagnosis']}")
        if record.get('differential_dx'):
            lines.append(f"**Дифф. диагноз:** {record['differential_dx']}")
        if record.get('disease_severity'):
            lines.append(f"**Тяжесть:** {record['disease_severity']}")

        # P — Plan
        lines.append("\n### P — План")
        drugs = record.get('prescribed_drugs', [])
        if drugs:
            lines.append("**Назначения:**")
            for d in drugs:
                drug_str = f"- **{d.get('name', '?')}**"
                if d.get('dose_per_kg'):
                    drug_str += f" {d['dose_per_kg']} мг/кг"
                if d.get('total_dose'):
                    drug_str += f" (всего {d['total_dose']} {d.get('dose_unit', 'мг')})"
                if d.get('route'):
                    drug_str += f", {d['route']}"
                if d.get('frequency'):
                    drug_str += f", {d['frequency']}"
                if d.get('duration_days'):
                    drug_str += f", {d['duration_days']} дн."
                lines.append(drug_str)
        if record.get('procedures'):
            lines.append(f"**Процедуры:** {record['procedures']}")
        if record.get('diet'):
            lines.append(f"**Диета/содержание:** {record['diet']}")
        if record.get('follow_up'):
            lines.append(f"**Контроль:** {record['follow_up']}")
        if record.get('notes'):
            lines.append(f"**Заметки:** {record['notes']}")

        # JSON для программного использования
        lines.append("\n---\n<details><summary>JSON (для API)</summary>\n")
        lines.append(f"```json\n{json.dumps(record, ensure_ascii=False, indent=2)}\n```")
        lines.append("\n</details>")

        return "\n".join(lines)

    except json.JSONDecodeError as e:
        return f"Ошибка парсинга JSON: {e}\n\nСырой ответ:\n{raw_json[:500]}"
    except Exception as e:
        return f"Ошибка: {e}"


# ============================================================
# TAB 4: Калькулятор дозировок
# ============================================================
def dose_calculate(drug_name: str, weight_kg: float, species: str) -> str:
    if not drug_name or not weight_kg:
        return "Выберите препарат и укажите вес"

    # Ищем препарат
    drug_key = drug_name.lower().strip()
    drug_info = COMMON_DRUGS.get(drug_key)

    # Частичное совпадение
    if not drug_info:
        for key, info in COMMON_DRUGS.items():
            if drug_key in key or key in drug_key:
                drug_info = info
                drug_key = key
                break

    if not drug_info:
        # Если не нашли в базе — спросим GLM
        if glm.configured:
            try:
                prompt = (
                    f"Рассчитай дозировку препарата '{drug_name}' для {species} "
                    f"весом {weight_kg} кг. Укажи: дозу мг/кг, общую дозу, путь "
                    f"введения, кратность, длительность. Формат: JSON с полями "
                    f"dose_mg_kg, total_dose_mg, route, frequency, duration_days, notes"
                )
                result = glm.generate_text(
                    "Ты ветеринарный фармацевт. Отвечай ТОЛЬКО JSON без markdown.",
                    prompt, temperature=0.2, max_tokens=300
                )
                result = result.strip()
                if result.startswith("```"):
                    result = result.split("\n", 1)[-1].rsplit("```", 1)[0].strip()
                parsed = json.loads(result)
                total_dose = parsed.get('total_dose_mg', weight_kg * parsed.get('dose_mg_kg', 0))
                return f"""## {drug_name}
**Вид:** {species} | **Вес:** {weight_kg} кг

| Параметр | Значение |
|---|---|
| Доза | {parsed.get('dose_mg_kg', '?')} мг/кг |
| **Общая доза** | **{total_dose:.1f} мг** |
| Путь введения | {parsed.get('route', '?')} |
| Кратность | {parsed.get('frequency', '?')} |
| Длительность | {parsed.get('duration_days', '?')} дн. |
{f"| Примечание | {parsed.get('notes', '')} |" if parsed.get('notes') else ''}

⚠️ Дозировка рассчитана AI. Подтвердите у ветеринара перед применением."""
            except Exception:
                return f"Препарат '{drug_name}' не найден в базе. Проверьте название."
        return f"Препарат '{drug_name}' не найден в базе. Проверьте название."

    dose_per_kg = drug_info['dose_mg_kg']
    total_dose = dose_per_kg * weight_kg

    # Предупреждения по видам
    warnings = []
    if "ивермектин" in drug_key and species.lower() in ["кошка", "cat"]:
        warnings.append("⚠️ **Ивермектин:** Осторожно кошкам! Может быть токсичен.")
    if "ивермектин" in drug_key and "колли" in drug_name.lower():
        warnings.append("⚠️ **MDR1 мутация:** Колли и родственные породы чувствительны к ивермектину!")
    if "энрофлоксацин" in drug_key and species.lower() in ["кошка", "cat"]:
        warnings.append("⚠️ **Энрофлоксацин:** У кошек может вызывать ретинальную дегенерацию в высоких дозах.")
    if "кетоконазол" in drug_key and species.lower() in ["кошка", "cat"]:
        warnings.append("⚠️ **Кетоконазол:** Кошки более чувствительны к гепатотоксичности.")
    if "карпрофен" in drug_key and species.lower() in ["кошка", "cat"]:
        warnings.append(
            "⚠️ **Карпрофен:** У кошек ограниченное применение. "
            "Разовая доза или мелоксикам предпочтительнее."
        )
    if "доксициклин" in drug_key:
        warnings.append("⚠️ **Доксициклин:** Давать с водой/едой. Риск эзофагита у кошек.")

    warn_text = "\n".join(warnings) if warnings else ""

    return f"""## {drug_key.title()}
**Вид:** {species} | **Вес:** {weight_kg} кг

| Параметр | Значение |
|---|---|
| Доза | {dose_per_kg} мг/кг |
| **Общая доза** | **{total_dose:.2f} мг** |
| Путь введения | {drug_info['route']} |
| Кратность | {drug_info['frequency']} |
| Длительность | {drug_info['duration']} дн. |

{warn_text}

⚠️ Дозировка ознакомительная. Подтвердите у ветеринара перед применением."""


# ============================================================
# GRADIO UI
# ============================================================
DISCLAIMER_HTML = """
<div style="background:#fff8e6;border-left:4px solid #f0a500;padding:12px 16px;
            border-radius:8px;margin:8px 0 16px;font-size:14px;color:#5b4a00;">
  <strong>⚠️ Важно:</strong> сервис даёт AI-ассистированный анализ и <b>не заменяет
  консультацию ветеринара</b>. Все дозировки — ознакомительные, подтверждайте у
  лицензированного специалиста.
</div>
"""

with gr.Blocks(
    title="VetVoice — Ветеринарный AI",
    theme=gr.themes.Soft(
        primary_hue="emerald",
        secondary_hue="blue",
        font=["Inter", "-apple-system", "BlinkMacSystemFont", "Segoe UI", "Roboto", "sans-serif"],
        text_size="md",
        radius="lg",
    ),
) as demo:

    gr.HTML("""
    <div style="text-align:center;padding:20px 0 4px;">
      <h1 style="margin:0;font-weight:700;letter-spacing:-0.5px;">VetVoice</h1>
      <p style="font-size:15px;color:#6b7280;margin:6px 0 0;">
        Ветеринарный AI-ассистент — анализ фото, база знаний, медкарты, дозировки
      </p>
    </div>
    """)

    gr.HTML(DISCLAIMER_HTML)

    with gr.Tabs():
        # === TAB 1: VLM ===
        with gr.Tab("📷 VLM Диагностика"):
            with gr.Row():
                with gr.Column(scale=1):
                    vlm_image = gr.Image(type="pil", label="Фото поражения", height=350)
                    vlm_mode = gr.Radio(
                        choices=["Диагноз", "Описание", "Тяжесть", "Лечение"],
                        value="Диагноз",
                        label="Режим анализа",
                    )
                    vlm_btn = gr.Button("🔍 Анализировать", variant="primary", size="lg")
                with gr.Column(scale=1):
                    vlm_output = gr.Markdown(
                        value="*Загрузите фото и нажмите «Анализировать»*",
                    )
            vlm_btn.click(
                fn=vlm_analyze,
                inputs=[vlm_image, vlm_mode],
                outputs=vlm_output,
                show_progress="full",
            ).then(fn=lambda: gr.update(interactive=True), inputs=None, outputs=vlm_btn)
            vlm_btn.click(fn=lambda: gr.update(interactive=False), inputs=None, outputs=vlm_btn)

        # === TAB 2: RAG Search ===
        with gr.Tab("📚 RAG База знаний"):
            with gr.Row():
                with gr.Column(scale=1):
                    rag_query = gr.Textbox(
                        label="Поисковый запрос",
                        placeholder=(
                            "напр. атопический дерматит у собак лечение\n"
                            "или: demodicosis puppy treatment\n"
                            "или: зуд у французского бульдога"
                        ),
                        lines=3,
                    )
                    rag_btn = gr.Button("🔎 Искать", variant="primary")
                    rag_status = gr.Markdown(
                        value=f"**RAG статус:** {'Загружен ✅' if rag.is_ready() else 'Недоступен ❌ (нужен HF_TOKEN)'}\n"
                              f"**Векторов:** {rag.index.ntotal if rag.is_ready() else 0}\n"
                              f"**Документов:** {len(rag.documents) if rag.is_ready() else 0}"
                    )
                with gr.Column(scale=2):
                    rag_output = gr.Markdown(value="*Введите запрос и нажмите «Искать»*")
            rag_btn.click(
                fn=rag_search,
                inputs=rag_query,
                outputs=rag_output,
                show_progress="full",
            ).then(fn=lambda: gr.update(interactive=True), inputs=None, outputs=rag_btn)
            rag_btn.click(fn=lambda: gr.update(interactive=False), inputs=None, outputs=rag_btn)

        # === TAB 3: Dictation → SOAP ===
        with gr.Tab("🎙️ Диктовка → Медкарта"):
            with gr.Row():
                with gr.Column(scale=1):
                    dict_text = gr.Textbox(
                        label="Текст диктовки / записи",
                        placeholder=(
                            "Надиктуйте или введите описание приёма.\n\n"
                            "Пример:\nСобака, французский бульдог, 3 года, 12 кг. "
                            "Жалоба: чешется 2 недели, покраснение на животе и подмышках. "
                            "На осмотре: эритема вентрально, папулы, экскориации. "
                            "Диагноз: атопический дерматит. Назначено: апоквел 0.4 мг/кг "
                            "2 раза в день 2 недели, затем 1 раз, хлоргексидин шампунь "
                            "2 раза в неделю."
                        ),
                        lines=10,
                    )
                    dict_btn = gr.Button("📋 Разобрать в SOAP", variant="primary", size="lg")
                with gr.Column(scale=1):
                    dict_output = gr.Markdown(value="*Надиктуйте или введите текст, затем нажмите «Разобрать в SOAP»*")
            dict_btn.click(
                fn=dictation_parse,
                inputs=dict_text,
                outputs=dict_output,
                show_progress="full",
            ).then(fn=lambda: gr.update(interactive=True), inputs=None, outputs=dict_btn)
            dict_btn.click(fn=lambda: gr.update(interactive=False), inputs=None, outputs=dict_btn)

        # === TAB 4: Dose Calculator ===
        with gr.Tab("💊 Калькулятор дозировок"):
            with gr.Row():
                with gr.Column(scale=1):
                    dose_drug = gr.Dropdown(
                        choices=sorted(COMMON_DRUGS.keys()),
                        label="Препарат",
                        allow_custom_value=True,
                        filterable=True,
                    )
                    dose_weight = gr.Number(
                        label="Вес (кг)",
                        value=15,
                        minimum=0.01,
                        maximum=2000,
                    )
                    dose_species = gr.Dropdown(
                        choices=list(SPECIES_WEIGHT_DEFAULTS.keys()),
                        label="Вид животного",
                        value="Собака",
                    )
                    dose_btn = gr.Button("💊 Рассчитать дозу", variant="primary", size="lg")
                with gr.Column(scale=1):
                    dose_output = gr.Markdown(value="*Выберите препарат, укажите вес и нажмите «Рассчитать дозу»*")
            dose_btn.click(
                fn=dose_calculate,
                inputs=[dose_drug, dose_weight, dose_species],
                outputs=dose_output,
                show_progress="full",
            ).then(fn=lambda: gr.update(interactive=True), inputs=None, outputs=dose_btn)
            dose_btn.click(fn=lambda: gr.update(interactive=False), inputs=None, outputs=dose_btn)

    # Footer
    gr.HTML("""
    <div style="text-align:center;color:#9ca3af;font-size:13px;padding:18px 0 6px;">
      VetVoice · AI-ассистированный инструмент · не является медицинской услугой
    </div>
    """)

demo.launch()
