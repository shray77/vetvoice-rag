#!/usr/bin/env python3
"""Build RAG knowledge base from local veterinary JSON data.

Primary source: assets/data/*.json (139 diseases, drugs, protocols, interactions, etc.)
Fallback:      Hugging Face Hub repo `shrayyyy/vet-derm-rag` (only when --from-hf)
Upload:        optional, with --upload when HF_TOKEN is set.

Output: knowledge_base/
  - vet_derm_faiss.index            (FAISS IndexFlatIP, cosine)
  - vet_derm_vectorizer.pkl         (TfidfVectorizer, bi-grams)
  - vet_derm_retrieval_store.json   (chunk_id, source, conditions, content, chunk_type, ...)

Usage:
  python3 scripts/build_rag.py                 # build from local JSON
  python3 scripts/build_rag.py --harvest       # also pull academic papers
  python3 scripts/build_rag.py --from-hf       # load existing HF KB first, then merge local
  python3 scripts/build_rag.py --upload        # upload result to HF (needs HF_TOKEN)
  python3 scripts/build_rag.py --stats         # just print stats, no rebuild
"""

from __future__ import annotations

import json
import os
import pickle
import re
import sys
import hashlib
from pathlib import Path
from typing import Any, Dict, List, Optional


try:
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.preprocessing import normalize
    import faiss
except ImportError:
    print("Install: pip install scikit-learn faiss-cpu", file=sys.stderr)
    sys.exit(1)


# =====================================================================
# Paths & constants
# =====================================================================

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "assets" / "data"
OUTPUT_DIR = ROOT / "knowledge_base"

HF_REPO = os.environ.get("VETVOICE_RAG_REPO", "shrayyyy/vet-derm-rag")
HF_TOKEN = os.environ.get("HF_TOKEN", "")

CHUNK_SIZE = 600   # characters
CHUNK_OVERLAP = 150
MAX_FEATURES = 8000
NGRAM_RANGE = (1, 1)   # unigrams — bi-grams create too much sparsity on RU+EN mix

# =====================================================================
# Helpers
# =====================================================================

def _u(s: Any) -> str:
    """Safe stringification."""
    if s is None:
        return ""
    if isinstance(s, (list, tuple)):
        return ", ".join(_u(x) for x in s if x)
    if isinstance(s, dict):
        return "; ".join(f"{k}: {_u(v)}" for k, v in s.items() if v)
    return str(s).strip()


def _hash(text: str) -> str:
    return hashlib.sha1(text.encode("utf-8")).hexdigest()[:16]


def _chunk_text(text: str, chunk_size: int = CHUNK_SIZE, overlap: int = CHUNK_OVERLAP) -> List[str]:
    """Sentence-aware chunking with overlap."""
    text = re.sub(r"\s+", " ", text).strip()
    if not text:
        return []
    sentences = re.split(r"(?<=[.!?])\s+", text)
    chunks: List[str] = []
    current = ""
    for sent in sentences:
        if not sent:
            continue
        if len(current) + len(sent) > chunk_size and current:
            chunks.append(current.strip())
            tail = " ".join(current.split()[-(overlap // 5):])
            current = f"{tail} {sent}".strip()
        else:
            current = f"{current} {sent}".strip()
    if current.strip():
        chunks.append(current.strip())
    # If any chunk is still too long (no sentence break), hard-split
    final: List[str] = []
    for c in chunks:
        if len(c) <= chunk_size * 2:
            final.append(c)
            continue
        for i in range(0, len(c), chunk_size):
            final.append(c[i : i + chunk_size])
    return final


def _make_chunk(
    content: str,
    source: str,
    conditions: Optional[List[str]] = None,
    chunk_type: str = "general",
    extra: Optional[Dict[str, Any]] = None,
) -> Optional[Dict[str, Any]]:
    """Create a chunk dict with stable chunk_id."""
    content = content.strip()
    if not content or len(content) < 30:
        return None
    chunk_id = f"{source}:{_hash(content)}"
    chunk = {
        "chunk_id": chunk_id,
        "source": source,
        "conditions": conditions or [],
        "content": content,
        "chunk_type": chunk_type,
    }
    if extra:
        chunk.update(extra)
    return chunk


# =====================================================================
# Local JSON → chunks
# =====================================================================

def _load_json(rel_path: str) -> Optional[Any]:
    p = DATA_DIR / rel_path
    if not p.exists():
        return None
    try:
        with p.open("r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"  ! Cannot parse {rel_path}: {e}", file=sys.stderr)
        return None


def _diseases_chunks() -> List[Dict[str, Any]]:
    data = _load_json("diseases.json")
    if not data:
        return []
    chunks: List[Dict[str, Any]] = []
    for d in data.get("diseases", []):
        name = _u(d.get("name"))
        code = _u(d.get("code"))
        animals = d.get("animals", []) or []
        category = _u(d.get("category"))
        content = (
            f"Болезнь: {name} (код: {code}). "
            f"Категория: {category}. "
            f"Вид животных: {', '.join(animals)}. "
            f"Источник: {_u(data.get('source'))}."
        )
        c = _make_chunk(
            content=content,
            source="diseases.json",
            conditions=[name, code],
            chunk_type="disease",
            extra={"disease_name": name, "disease_code": code, "animals": animals},
        )
        if c:
            chunks.append(c)
    # Non-contagious
    nc = _load_json("non_contagious_diseases.json")
    if nc:
        for d in nc.get("diseases", []):
            name = _u(d.get("name"))
            animals = d.get("animals", []) or []
            desc = _u(d.get("description"))
            content = (
                f"Неконтагиозное заболевание: {name}. "
                f"Вид животных: {', '.join(animals)}. "
                f"Описание: {desc}."
            )
            c = _make_chunk(
                content=content,
                source="non_contagious_diseases.json",
                conditions=[name],
                chunk_type="disease",
                extra={"disease_name": name, "animals": animals},
            )
            if c:
                chunks.append(c)
    return chunks


def _drugs_chunks() -> List[Dict[str, Any]]:
    chunks: List[Dict[str, Any]] = []
    # drugs.json — main registry
    data = _load_json("drugs.json")
    if data:
        for d in data.get("drugs", []):
            name = _u(d.get("name"))
            inn = _u(d.get("active_ingredient"))
            dose = d.get("dose")
            unit = _u(d.get("unit"))
            method = _u(d.get("method"))
            method_short = _u(d.get("method_short"))
            animals = d.get("animals", []) or []
            withdrawal = d.get("withdrawal_days")
            desc = _u(d.get("description"))
            contra = d.get("contraindications", {}) or {}
            contra_lines: List[str] = []
            if contra.get("pregnancy"):
                contra_lines.append("противопоказан при беременности")
            if contra.get("lactation"):
                contra_lines.append("противопоказан при лактации")
            if contra.get("young"):
                contra_lines.append("противопоказан молодняку")
            if contra.get("old"):
                contra_lines.append("с осторожностью у пожилых животных")
            for w in contra.get("warnings", []) or []:
                contra_lines.append(_u(w))
            adj = d.get("dose_adjustment", {}) or {}
            adj_line = ""
            if adj:
                adj_line = "Коррекция дозы: " + _u(adj) + ". "
            content = (
                f"Препарат: {name}. Действующее вещество: {inn}. "
                f"Доза: {dose} {unit}. Способ введения: {method} ({method_short}). "
                f"Вид животных: {', '.join(animals)}. "
                f"Период ожидания: {withdrawal} сут. "
                f"Описание: {desc}. "
                f"{adj_line}"
                f"Противопоказания: {'; '.join(contra_lines) if contra_lines else 'нет особых'}."
            )
            c = _make_chunk(
                content=content,
                source="drugs.json",
                conditions=[name, inn],
                chunk_type="drug",
                extra={"drug_name": name, "inn": inn, "animals": animals},
            )
            if c:
                chunks.append(c)
    # drugs_calc.json — full calculators
    dc = _load_json("drugs_calc.json")
    if dc:
        for d in dc.get("drugs_calc", []):
            name = _u(d.get("name"))
            inn = _u(d.get("inn"))
            form = _u(d.get("form"))
            form_type = _u(d.get("form_type"))
            conc = d.get("concentration")
            conc_unit = _u(d.get("concentration_unit"))
            unit = _u(d.get("unit"))
            dose_per_kg = d.get("dose_per_kg")
            dose_min = d.get("dose_min")
            dose_max = d.get("dose_max")
            dose_unit = _u(d.get("dose_unit"))
            animals = d.get("animals", []) or []
            method = _u(d.get("method"))
            freq = _u(d.get("frequency"))
            course = _u(d.get("course_days"))
            withdrawal = d.get("withdrawal_days")
            category = _u(d.get("category"))
            indications = _u(d.get("indications"))
            contra = _u(d.get("contraindications"))
            side = d.get("side_effects", []) or []
            content = (
                f"Препарат-калькулятор: {name} (INN: {inn}). "
                f"Форма: {form} ({form_type}). "
                f"Концентрация: {conc} {conc_unit}. "
                f"Доза: {dose_per_kg} {dose_unit} (диапазон {dose_min}-{dose_max} {dose_unit}). "
                f"Способ: {method}, {freq}, курс {course}. "
                f"Период ожидания: {withdrawal} сут. "
                f"Категория: {category}. "
                f"Вид животных: {', '.join(animals)}. "
                f"Показания: {indications}. "
                f"Противопоказания: {contra}. "
                f"Побочные эффекты: {', '.join(side)}."
            )
            c = _make_chunk(
                content=content,
                source="drugs_calc.json",
                conditions=[name, inn],
                chunk_type="drug_calculator",
                extra={"drug_name": name, "inn": inn, "animals": animals, "category": category},
            )
            if c:
                chunks.append(c)
            # animal-specific overrides
            for animal, spec in (d.get("animal_specific") or {}).items():
                spec_content = (
                    f"Препарат {name} ({inn}) — специфика для животного «{animal}»: "
                    f"доза {spec.get('dose_per_kg')} {spec.get('dose_unit', dose_unit)}, "
                    f"способ {spec.get('method', method)}, "
                    f"частота {spec.get('frequency', freq)}, курс {spec.get('course_days', course)}."
                )
                c = _make_chunk(
                    content=spec_content,
                    source="drugs_calc.json",
                    conditions=[name, inn, animal],
                    chunk_type="drug_animal_specific",
                    extra={"drug_name": name, "inn": inn, "animal": animal},
                )
                if c:
                    chunks.append(c)
    # drugs_registry.json — additional registry
    reg = _load_json("drugs_registry.json")
    if reg:
        drugs_list = reg.get("drugs", []) or []
        if isinstance(drugs_list, dict):
            drugs_list = list(drugs_list.values())
        for d in drugs_list:
            if not isinstance(d, dict):
                continue
            name = _u(d.get("trade_name") or d.get("name"))
            inn = _u(d.get("inn") or d.get("active_ingredient"))
            form = _u(d.get("form") or d.get("release_form"))
            manufacturer = _u(d.get("manufacturer"))
            animals = d.get("animals", []) or []
            pharm_group = _u(d.get("pharmacological_group"))
            indications = _u(d.get("indications"))
            contra = _u(d.get("contraindications"))
            side = _u(d.get("side_effects"))
            reg_num = _u(d.get("registration_number"))
            reg_date = _u(d.get("registration_date"))
            content = (
                f"Препарат из реестра: {name} (INN: {inn}). "
                f"Форма выпуска: {form}. Фармгруппа: {pharm_group}. "
                f"Производитель: {manufacturer}. "
                f"Регистрационный номер: {reg_num} от {reg_date}. "
                f"Вид животных: {', '.join(animals) if animals else 'не указано'}. "
                f"Показания: {indications}. "
                f"Противопоказания: {contra}. "
                f"Побочные эффекты: {side}."
            )
            c = _make_chunk(
                content=content,
                source="drugs_registry.json",
                conditions=[name, inn],
                chunk_type="drug_registry",
                extra={"drug_name": name, "inn": inn, "animals": animals,
                       "reg_number": reg_num},
            )
            if c:
                chunks.append(c)
    return chunks


def _render_drug_entry(d: Any) -> str:
    """Robustly stringify a drug entry that may be dict, list, str, or number."""
    if d is None:
        return ""
    if isinstance(d, str):
        return d.strip()
    if isinstance(d, (int, float)):
        return str(d)
    if isinstance(d, dict):
        parts = []
        for k in ("name", "inn", "dose", "route", "frequency", "duration",
                  "pharm_group", "waiting_period", "notes", "warnings"):
            v = d.get(k)
            if v:
                parts.append(f"{k}={_u(v)}")
        return "; ".join(parts) if parts else _u(d)
    if isinstance(d, list):
        return " | ".join(_render_drug_entry(x) for x in d if x)
    return _u(d)


def _protocols_chunks() -> List[Dict[str, Any]]:
    chunks: List[Dict[str, Any]] = []
    # treatment_protocols.json — per-disease treatment plans
    tp = _load_json("advanced/treatment_protocols.json")
    if tp:
        protocols = tp.get("protocols", []) or []
        if isinstance(protocols, dict):
            protocols = list(protocols.values())
        for p in protocols:
            if not isinstance(p, dict):
                continue
            dx = _u(p.get("diagnosis"))
            code = _u(p.get("code"))
            cat_name = _u(p.get("category_name"))
            species = p.get("species", []) or []
            pathogen = _u(p.get("pathogen_type"))
            severity = _u(p.get("severity"))
            order_num = _u(p.get("order_number"))
            treatment = p.get("treatment", {}) or {}
            lines: List[str] = []
            if isinstance(treatment, dict):
                for tier_name in ("primary", "secondary", "supportive", "symptomatic"):
                    tier = treatment.get(tier_name)
                    if not tier:
                        continue
                    if isinstance(tier, dict):
                        tier_drugs = tier.get("drugs", []) or []
                    else:
                        tier_drugs = tier
                        tier = {"drugs": tier_drugs}
                    if tier_drugs:
                        if isinstance(tier_drugs, (str, int, float)):
                            drug_lines = [_render_drug_entry(tier_drugs)]
                        elif isinstance(tier_drugs, list):
                            drug_lines = [_render_drug_entry(x) for x in tier_drugs if x]
                        elif isinstance(tier_drugs, dict):
                            drug_lines = [_render_drug_entry(tier_drugs)]
                        else:
                            drug_lines = [_u(tier_drugs)]
                        drug_lines = [x for x in drug_lines if x]
                        if drug_lines:
                            lines.append(f"{tier_name.upper()}: " + " | ".join(drug_lines))
                    notes = tier.get("notes") if isinstance(tier, dict) else None
                    if notes:
                        lines.append(f"{tier_name} notes: {_u(notes)}")
            elif isinstance(treatment, list):
                lines.append("Лечение: " + _render_drug_entry(treatment))
            elif isinstance(treatment, str):
                lines.append(f"Лечение: {treatment}")
            # Protocol-level notes/warnings
            for extra_key in ("notes", "warnings"):
                extra_val = p.get(extra_key)
                if extra_val:
                    lines.append(f"{extra_key}: {_u(extra_val)}")
            content = (
                f"Протокол лечения №{order_num}. Диагноз: {dx} (код {code}). "
                f"Категория: {cat_name}. Вид животных: {', '.join(species)}. "
                f"Этиология: {pathogen}. Тяжесть: {severity}. "
                + " ".join(lines)
            )
            c = _make_chunk(
                content=content,
                source="treatment_protocols.json",
                conditions=[dx, code],
                chunk_type="treatment_protocol",
                extra={"disease_name": dx, "disease_code": code, "species": species},
            )
            if c:
                chunks.append(c)
    # non_contagious_protocols.json
    ncp = _load_json("advanced/non_contagious_protocols.json")
    if ncp:
        for p in ncp.get("protocols", []):
            dx = _u(p.get("diagnosis") or p.get("name"))
            animals = p.get("animals", []) or p.get("species", []) or []
            treatment = _u(p.get("treatment") or p.get("recommendations"))
            content = (
                f"Протокол неконтагиозного лечения: {dx}. "
                f"Вид животных: {', '.join(animals)}. "
                f"Рекомендации: {treatment}."
            )
            c = _make_chunk(
                content=content,
                source="non_contagious_protocols.json",
                conditions=[dx],
                chunk_type="treatment_protocol",
                extra={"disease_name": dx, "animals": animals},
            )
            if c:
                chunks.append(c)
    # emergency_protocols.json
    ep = _load_json("advanced/emergency_protocols.json")
    if ep:
        for p in ep.get("protocols", []):
            name = _u(p.get("name") or p.get("title"))
            scenario = _u(p.get("scenario") or p.get("indication"))
            steps = p.get("steps", []) or []
            steps_text = " | ".join(
                f"Шаг {i+1}: {_u(s.get('action') or s.get('description'))} "
                f"({ _u(s.get('drug')) }, доза {_u(s.get('dose'))})"
                for i, s in enumerate(steps)
            )
            content = (
                f"Экстренный протокол: {name}. Сценарий: {scenario}. "
                f"Шаги: {steps_text}."
            )
            c = _make_chunk(
                content=content,
                source="emergency_protocols.json",
                conditions=[name],
                chunk_type="emergency_protocol",
                extra={"protocol_name": name},
            )
            if c:
                chunks.append(c)
    # unofficial_protocols.json
    up = _load_json("unofficial_protocols.json")
    if up:
        for r in up.get("records", []):
            dx = _u(r.get("diagnosis") or r.get("disease"))
            drug = _u(r.get("drug") or r.get("treatment"))
            dose = _u(r.get("dose"))
            notes = _u(r.get("notes") or r.get("comment"))
            content = (
                f"Неофициальный протокол: диагноз {dx}. "
                f"Препарат: {drug}. Доза: {dose}. Комментарий: {notes}."
            )
            c = _make_chunk(
                content=content,
                source="unofficial_protocols.json",
                conditions=[dx, drug],
                chunk_type="unofficial_protocol",
            )
            if c:
                chunks.append(c)
    return chunks


def _interactions_chunks() -> List[Dict[str, Any]]:
    chunks: List[Dict[str, Any]] = []
    di = _load_json("advanced/drug_interactions.json")
    if di:
        for it in di.get("interactions", []):
            a = _u(it.get("drug_a") or it.get("drug_1"))
            b = _u(it.get("drug_b") or it.get("drug_2"))
            severity = _u(it.get("severity"))
            effect = _u(it.get("effect") or it.get("description"))
            action = _u(it.get("action") or it.get("recommendation"))
            content = (
                f"Взаимодействие: {a} + {b}. "
                f"Тяжесть: {severity}. Эффект: {effect}. "
                f"Рекомендация: {action}."
            )
            c = _make_chunk(
                content=content,
                source="drug_interactions.json",
                conditions=[a, b],
                chunk_type="drug_interaction",
                extra={"drug_a": a, "drug_b": b, "severity": severity},
            )
            if c:
                chunks.append(c)
    return chunks


def _side_effects_chunks() -> List[Dict[str, Any]]:
    chunks: List[Dict[str, Any]] = []
    se = _load_json("advanced/side_effects.json")
    if se:
        for d in se.get("drugs", []) or []:
            if not isinstance(d, dict):
                continue
            name = _u(d.get("drug") or d.get("name"))
            effects_raw = d.get("effects") or d.get("side_effects") or []
            monitoring = _u(d.get("monitoring"))
            # Effects may be list[str] or list[dict]
            effect_lines: List[str] = []
            for e in effects_raw:
                if isinstance(e, str):
                    effect_lines.append(e)
                elif isinstance(e, dict):
                    effect = _u(e.get("effect"))
                    age = _u(e.get("age"))
                    dose = _u(e.get("dose"))
                    cond = _u(e.get("condition"))
                    freq = _u(e.get("frequency"))
                    action = _u(e.get("action"))
                    parts = [effect]
                    if age:    parts.append(f"возраст: {age}")
                    if dose:   parts.append(f"доза: {dose}")
                    if cond:   parts.append(f"условие: {cond}")
                    if freq:   parts.append(f"частота: {freq}")
                    if action: parts.append(f"действие: {action}")
                    effect_lines.append(" — ".join(parts))
            content = (
                f"Побочные эффекты препарата {name}: "
                + ". ".join(effect_lines)
                + (f". Мониторинг: {monitoring}." if monitoring else ".")
            )
            c = _make_chunk(
                content=content,
                source="side_effects.json",
                conditions=[name],
                chunk_type="side_effect",
                extra={"drug_name": name},
            )
            if c:
                chunks.append(c)
        gp = se.get("general_principles")
        if gp:
            content = f"Общие принципы побочных эффектов: {_u(gp)}."
            c = _make_chunk(
                content=content,
                source="side_effects.json",
                conditions=[],
                chunk_type="general_principle",
            )
            if c:
                chunks.append(c)
    return chunks


def _antidotes_chunks() -> List[Dict[str, Any]]:
    chunks: List[Dict[str, Any]] = []
    an = _load_json("advanced/antidotes.json")
    if an:
        for p in an.get("poisonings", []):
            toxin = _u(p.get("toxin") or p.get("poison"))
            antidote = _u(p.get("antidote"))
            dose = _u(p.get("dose"))
            mechanism = _u(p.get("mechanism"))
            notes = _u(p.get("notes"))
            content = (
                f"Отравление: {toxin}. Антидот: {antidote}. "
                f"Доза: {dose}. Механизм: {mechanism}. Заметки: {notes}."
            )
            c = _make_chunk(
                content=content,
                source="antidotes.json",
                conditions=[toxin, antidote],
                chunk_type="antidote",
                extra={"toxin": toxin, "antidote": antidote},
            )
            if c:
                chunks.append(c)
    return chunks


def _dose_adjustments_chunks() -> List[Dict[str, Any]]:
    chunks: List[Dict[str, Any]] = []
    da = _load_json("advanced/dose_adjustments.json")
    if not da:
        return chunks
    for key in ("age_adjustments", "renal_adjustment", "hepatic_adjustment",
                "cardiac_adjustment", "pregnancy_lactation"):
        section = da.get(key)
        if not section:
            continue
        content = f"Коррекция дозы — {key}: {_u(section)}."
        c = _make_chunk(
            content=content,
            source="dose_adjustments.json",
            conditions=[],
            chunk_type="dose_adjustment",
            extra={"adjustment_type": key},
        )
        if c:
            chunks.append(c)
    return chunks


def _fluid_therapy_chunks() -> List[Dict[str, Any]]:
    chunks: List[Dict[str, Any]] = []
    ft = _load_json("advanced/fluid_therapy.json")
    if not ft:
        return chunks
    for key in ("formulas", "solutions", "additives", "special_protocols", "body_surface_area"):
        section = ft.get(key)
        if not section:
            continue
        if isinstance(section, list):
            content = f"Жидкостная терапия — {key}: " + " | ".join(_u(x) for x in section)
        elif isinstance(section, dict):
            content = f"Жидкостная терапия — {key}: " + _u(section)
        else:
            content = f"Жидкостная терапия — {key}: {_u(section)}"
        c = _make_chunk(
            content=content,
            source="fluid_therapy.json",
            conditions=[],
            chunk_type="fluid_therapy",
            extra={"section": key},
        )
        if c:
            chunks.append(c)
    return chunks


def _withdrawal_chunks() -> List[Dict[str, Any]]:
    chunks: List[Dict[str, Any]] = []
    w = _load_json("advanced/withdrawal_by_product.json")
    if not w:
        return chunks
    for d in w.get("drugs", []):
        name = _u(d.get("drug") or d.get("name"))
        animals = d.get("animals", []) or []
        if isinstance(animals, list):
            animals_lines = []
            for a in animals:
                if isinstance(a, dict):
                    animals_lines.append(
                        f"{_u(a.get('animal'))}: мясо {_u(a.get('meat'))}, "
                        f"молоко {_u(a.get('milk'))}, яйца {_u(a.get('eggs'))}"
                    )
                else:
                    animals_lines.append(_u(a))
            content = f"Период ожидания для {name}: " + " | ".join(animals_lines)
        else:
            content = f"Период ожидания для {name}: {_u(animals)}"
        c = _make_chunk(
            content=content,
            source="withdrawal_by_product.json",
            conditions=[name],
            chunk_type="withdrawal",
            extra={"drug_name": name},
        )
        if c:
            chunks.append(c)
    notes = w.get("special_notes") if w else None
    if notes:
        content = f"Особые заметки о периодах ожидания: {_u(notes)}."
        c = _make_chunk(
            content=content,
            source="withdrawal_by_product.json",
            conditions=[],
            chunk_type="withdrawal_note",
        )
        if c:
            chunks.append(c)
    return chunks


def _verified_dosages_chunks() -> List[Dict[str, Any]]:
    chunks: List[Dict[str, Any]] = []
    vd = _load_json("verified_dosages.json")
    if not vd:
        return chunks
    for drug_name, info in vd.items():
        if drug_name == "_meta":
            continue
        if not isinstance(info, dict):
            content = f"Проверенная дозировка — {drug_name}: {_u(info)}"
        else:
            parts = []
            for k, v in info.items():
                if k == "_meta":
                    continue
                parts.append(f"{k}: {_u(v)}")
            content = f"Проверенная дозировка — {drug_name}. " + ". ".join(parts)
        c = _make_chunk(
            content=content,
            source="verified_dosages.json",
            conditions=[drug_name],
            chunk_type="verified_dosage",
            extra={"drug_name": drug_name},
        )
        if c:
            chunks.append(c)
    return chunks


def _dosage_database_chunks() -> List[Dict[str, Any]]:
    """dosage_database.json: {dosages: {drug_name: {animal: {...}}}, meta: ...}"""
    chunks: List[Dict[str, Any]] = []
    dd = _load_json("dosage_database.json")
    if not dd:
        return chunks
    dosages = dd.get("dosages", {})
    if isinstance(dosages, list):
        # fallback: list of records
        for d in dosages:
            if not isinstance(d, dict):
                continue
            drug = _u(d.get("drug") or d.get("name"))
            animal = _u(d.get("animal"))
            dose = _u(d.get("dose") or d.get("dose_mg_kg"))
            freq = _u(d.get("frequency"))
            notes = _u(d.get("notes"))
            content = (
                f"Дозировка из базы: {drug}. Животное: {animal}. "
                f"Доза: {dose}. Кратность: {freq}. Заметки: {notes}."
            )
            c = _make_chunk(
                content=content, source="dosage_database.json",
                conditions=[drug, animal], chunk_type="dosage",
                extra={"drug_name": drug, "animal": animal},
            )
            if c: chunks.append(c)
        return chunks
    # main case: dict of {drug: {animal: {...}}}
    for drug, animals in dosages.items():
        if not isinstance(animals, dict):
            continue
        animal_lines = []
        for animal, info in animals.items():
            if isinstance(info, dict):
                dose = info.get("dose_mg_kg", info.get("dose"))
                freq = info.get("frequency")
                notes = info.get("notes")
                parts = [f"доза {_u(dose)}"]
                if freq:  parts.append(f"кратность {freq}")
                if notes: parts.append(f"заметки {notes}")
                animal_lines.append(f"{animal}: " + ", ".join(parts))
            else:
                animal_lines.append(f"{animal}: {_u(info)}")
        content = f"Дозировка из базы — {drug}. " + " | ".join(animal_lines) + "."
        c = _make_chunk(
            content=content, source="dosage_database.json",
            conditions=[drug], chunk_type="dosage",
            extra={"drug_name": drug, "animals": list(animals.keys())},
        )
        if c: chunks.append(c)
    return chunks


def _correct_dosages_chunks() -> List[Dict[str, Any]]:
    """correct_dosages_reference.json: {dosages: {drug: {animal: {...}}}}"""
    chunks: List[Dict[str, Any]] = []
    cd = _load_json("correct_dosages_reference.json")
    if not cd:
        return chunks
    dosages = cd.get("dosages", {})
    if isinstance(dosages, list):
        # list form
        for d in dosages:
            if not isinstance(d, dict):
                continue
            drug = _u(d.get("drug") or d.get("name"))
            animal = _u(d.get("animal"))
            dose = _u(d.get("dose") or d.get("correct_dose"))
            note = _u(d.get("note") or d.get("comment"))
            content = (
                f"Эталонная дозировка: {drug}. Животное: {animal}. "
                f"Корректная доза: {dose}. Комментарий: {note}."
            )
            c = _make_chunk(
                content=content, source="correct_dosages_reference.json",
                conditions=[drug, animal], chunk_type="verified_dosage",
                extra={"drug_name": drug, "animal": animal},
            )
            if c: chunks.append(c)
        return chunks
    # dict form: {drug: {animal: {...}}}
    for drug, animals in dosages.items():
        if not isinstance(animals, dict):
            continue
        animal_lines = []
        for animal, info in animals.items():
            if isinstance(info, dict):
                dose = info.get("dose_per_kg", info.get("dose"))
                dmin = info.get("dose_min")
                dmax = info.get("dose_max")
                freq = info.get("frequency")
                notes = info.get("notes")
                parts = []
                if dose: parts.append(f"доза {dose} мг/кг")
                if dmin and dmax: parts.append(f"диапазон {dmin}-{dmax}")
                if freq:  parts.append(f"кратность {freq}")
                if notes: parts.append(f"заметки {notes}")
                animal_lines.append(f"{animal}: " + ", ".join(parts))
            else:
                animal_lines.append(f"{animal}: {_u(info)}")
        content = f"Эталонная дозировка — {drug}. " + " | ".join(animal_lines) + "."
        c = _make_chunk(
            content=content, source="correct_dosages_reference.json",
            conditions=[drug], chunk_type="verified_dosage",
            extra={"drug_name": drug, "animals": list(animals.keys())},
        )
        if c: chunks.append(c)
    return chunks


def collect_local_chunks() -> List[Dict[str, Any]]:
    """Collect chunks from all local JSON data files."""
    chunks: List[Dict[str, Any]] = []
    collectors = [
        ("diseases", _diseases_chunks),
        ("drugs", _drugs_chunks),
        ("protocols", _protocols_chunks),
        ("interactions", _interactions_chunks),
        ("side_effects", _side_effects_chunks),
        ("antidotes", _antidotes_chunks),
        ("dose_adjustments", _dose_adjustments_chunks),
        ("fluid_therapy", _fluid_therapy_chunks),
        ("withdrawal", _withdrawal_chunks),
        ("verified_dosages", _verified_dosages_chunks),
        ("dosage_database", _dosage_database_chunks),
        ("correct_dosages", _correct_dosages_chunks),
    ]
    for name, fn in collectors:
        try:
            new_chunks = fn()
            chunks.extend(new_chunks)
            print(f"  + {name}: {len(new_chunks)} chunks")
        except Exception as e:
            print(f"  ! {name} failed: {e}", file=sys.stderr)
    return chunks


# =====================================================================
# HF Hub integration (optional)
# =====================================================================

def load_from_hf() -> List[Dict[str, Any]]:
    """Try to load existing chunks from HF Hub. Empty list on failure."""
    if not HF_TOKEN:
        print("  (no HF_TOKEN, skipping HF load)")
        return []
    try:
        from huggingface_hub import hf_hub_download
        path = hf_hub_download(
            repo_id=HF_REPO, filename="vet_derm_retrieval_store.json",
            token=HF_TOKEN, local_dir=str(OUTPUT_DIR),
        )
        with open(path, "r", encoding="utf-8") as f:
            chunks = json.load(f)
        print(f"  Loaded {len(chunks)} chunks from HF Hub")
        return chunks
    except Exception as e:
        print(f"  (HF load skipped: {e})")
        return []


def harvest_papers() -> List[Dict[str, Any]]:
    """Optional: harvest academic papers via paper_harvester.py."""
    try:
        from paper_harvester import harvest_papers as hp, process_papers_to_rag  # type: ignore
        queries = [
            "canine atopic dermatitis treatment",
            "veterinary dermatology diagnosis",
            "feline dermatophytosis",
            "canine pyoderma bacterial",
            "dog Malassezia dermatitis",
            "canine pemphigus foliaceus",
            "veterinary dermatology immunotherapy",
            "canine pruritus diagnostic algorithm",
        ]
        papers = hp("all", queries, max_per_query=5)
        print(f"  Harvested {len(papers)} papers")
        chunks = process_papers_to_rag(papers, OUTPUT_DIR)
        return chunks
    except Exception as e:
        print(f"  Paper harvest skipped: {e}")
        return []


def upload_to_hub() -> None:
    """Upload KB to HuggingFace Hub (requires HF_TOKEN)."""
    if not HF_TOKEN:
        print("No HF_TOKEN set, skipping upload")
        return
    try:
        from huggingface_hub import HfApi
        api = HfApi()
        for f in os.listdir(OUTPUT_DIR):
            if f.endswith(('.index', '.pkl', '.json')):
                api.upload_file(
                    path_or_fileobj=str(OUTPUT_DIR / f),
                    path_in_repo=f,
                    repo_id=HF_REPO,
                    repo_type="model",
                    token=HF_TOKEN,
                )
                print(f"  Uploaded: {f}")
    except Exception as e:
        print(f"Upload failed: {e}", file=sys.stderr)


# =====================================================================
# Build TF-IDF + FAISS index
# =====================================================================

def build_index(chunks: List[Dict[str, Any]]) -> None:
    """Build TF-IDF + FAISS index from chunks. Saves to OUTPUT_DIR."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    texts = [c["content"] for c in chunks]
    print(f"\nBuilding index from {len(texts)} chunks...")

    vectorizer = TfidfVectorizer(
        max_features=MAX_FEATURES,
        ngram_range=NGRAM_RANGE,
        stop_words=None,           # mixed RU/EN — don't drop Russian as stop words
        min_df=1,
        max_df=0.95,
        sublinear_tf=True,
        strip_accents=None,
    )
    tfidf = vectorizer.fit_transform(texts).toarray().astype("float32")
    tfidf = normalize(tfidf, norm="l2")

    index = faiss.IndexFlatIP(tfidf.shape[1])
    index.add(tfidf)

    faiss.write_index(index, str(OUTPUT_DIR / "vet_derm_faiss.index"))
    with open(OUTPUT_DIR / "vet_derm_vectorizer.pkl", "wb") as f:
        pickle.dump(vectorizer, f)

    # Save retrieval store (chunk metadata + content)
    store = [
        {
            "chunk_id": c["chunk_id"],
            "source": c["source"],
            "conditions": c.get("conditions", []),
            "content": c["content"],
            "chunk_type": c.get("chunk_type", "general"),
            **{k: v for k, v in c.items()
               if k not in ("chunk_id", "source", "conditions", "content", "chunk_type")},
        }
        for c in chunks
    ]
    with open(OUTPUT_DIR / "vet_derm_retrieval_store.json", "w", encoding="utf-8") as f:
        json.dump(store, f, ensure_ascii=False, indent=2)

    print(f"\n✓ Index: {index.ntotal} vectors, {tfidf.shape[1]} dims")
    print(f"✓ Files written to: {OUTPUT_DIR}/")
    for fname in ("vet_derm_faiss.index", "vet_derm_vectorizer.pkl", "vet_derm_retrieval_store.json"):
        size_kb = (OUTPUT_DIR / fname).stat().st_size / 1024
        print(f"    {fname}: {size_kb:.1f} KB")


def print_stats(chunks: List[Dict[str, Any]]) -> None:
    """Print chunk-type distribution and sample."""
    if not chunks:
        print("No chunks.")
        return
    by_type: Dict[str, int] = {}
    by_source: Dict[str, int] = {}
    for c in chunks:
        t = c.get("chunk_type", "general")
        s = c.get("source", "?")
        by_type[t] = by_type.get(t, 0) + 1
        by_source[s] = by_source.get(s, 0) + 1
    print(f"\n=== Stats: {len(chunks)} chunks ===")
    print("\nBy type:")
    for k, v in sorted(by_type.items(), key=lambda x: -x[1]):
        print(f"  {v:>5}  {k}")
    print("\nBy source:")
    for k, v in sorted(by_source.items(), key=lambda x: -x[1]):
        print(f"  {v:>5}  {k}")
    print("\nSample chunk:")
    s = chunks[0]
    print(f"  chunk_id: {s.get('chunk_id')}")
    print(f"  source:   {s.get('source')}")
    print(f"  type:     {s.get('chunk_type')}")
    print(f"  content:  {s.get('content', '')[:200]}...")


# =====================================================================
# Entry point
# =====================================================================

def main() -> int:
    print("=" * 60)
    print("VetVoice RAG Knowledge Base Builder")
    print("=" * 60)
    print(f"Data dir:   {DATA_DIR}")
    print(f"Output dir: {OUTPUT_DIR}")
    print(f"HF repo:    {HF_REPO}  (token: {'set' if HF_TOKEN else 'NOT set'})")
    print()

    # Step 1: collect chunks
    print("Collecting chunks from local JSON data...")
    chunks = collect_local_chunks()
    print(f"\nTotal local chunks: {len(chunks)}")

    # Optional: merge HF Hub data
    if "--from-hf" in sys.argv:
        print("\nLoading existing KB from HF Hub...")
        hf_chunks = load_from_hf()
        existing_ids = {c["chunk_id"] for c in chunks}
        for c in hf_chunks:
            if c.get("chunk_id") not in existing_ids:
                chunks.append(c)
                existing_ids.add(c.get("chunk_id"))
        print(f"After HF merge: {len(chunks)} chunks")

    # Optional: harvest academic papers
    if "--harvest" in sys.argv:
        print("\nHarvesting academic papers...")
        paper_chunks = harvest_papers()
        existing_ids = {c["chunk_id"] for c in chunks}
        for c in paper_chunks:
            if c.get("chunk_id") not in existing_ids:
                chunks.append(c)
                existing_ids.add(c.get("chunk_id"))
        print(f"After paper harvest: {len(chunks)} chunks")

    # Stats-only mode
    if "--stats" in sys.argv:
        print_stats(chunks)
        return 0

    if not chunks:
        print("No chunks collected, aborting.", file=sys.stderr)
        return 1

    # Deduplicate
    seen = set()
    deduped: List[Dict[str, Any]] = []
    for c in chunks:
        cid = c["chunk_id"]
        if cid in seen:
            continue
        seen.add(cid)
        deduped.append(c)
    if len(deduped) != len(chunks):
        print(f"\nDeduplicated: {len(chunks)} → {len(deduped)}")
    chunks = deduped

    # Step 2: print stats
    print_stats(chunks)

    # Step 3: build index
    build_index(chunks)

    # Step 4: upload (optional)
    if "--upload" in sys.argv:
        print("\nUploading to HF Hub...")
        upload_to_hub()

    print("\n✓ Done. RAG knowledge base is ready at:")
    print(f"  {OUTPUT_DIR}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
