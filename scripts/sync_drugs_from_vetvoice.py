#!/usr/bin/env python3
"""Синхронизация баз препаратов из канонического источника — репозитория vetvoice.

Экосистема держит лекарственные базы (препараты, дозировки, болезни, протоколы)
в ДВУХ репозиториях: vetvoice (голосовой справочник, канонический источник)
и vetvoice-rag (ВетЭко). Исторически копии разъезжались: в vetvoice-rag
verified_dosages был огрызком на 7 записей против 2 376 в vetvoice, а
противопоказания в drugs_calc оставались в старом строковом формате.

Правило (см. README, раздел «Источник препаратов»):
  источник = vetvoice. Этот скрипт приводит копию ВетЭко в соответствие.

Файлы:
  - SYNC (байт-в-байт): verified_dosages, drugs_calc, diseases, drugs,
    advanced/treatment_protocols
  - MERGE (объединение): dosage_database — локальная копия исторически
    надмножество (13 локальных записей), поэтому общие записи берутся из
    vetvoice, локальные дополнения сохраняются.

Запуск:
  python3 scripts/sync_drugs_from_vetvoice.py            # синк из GitHub (raw)
  python3 scripts/sync_drugs_from_vetvoice.py --from ../vetvoice   # из локального клона
  python3 scripts/sync_drugs_from_vetvoice.py --check    # только проверить (для CI)

Код выхода при --check: 0 — синхронно, 1 — есть рассинхрон, 2 — ошибка сети/чтения.
Только стандартная библиотека.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DATA = REPO / "assets" / "data"

RAW_BASE = "https://raw.githubusercontent.com/shray77/vetvoice/main/assets/data"

# Байт-в-байт из vetvoice.
SYNC_FILES = [
    "verified_dosages.json",
    "drugs_calc.json",
    "diseases.json",
    "drugs.json",
    "advanced/treatment_protocols.json",
]

# Объединение: записи vetvoice каноничны, локальные дополнения сохраняются.
MERGE_FILES = ["dosage_database.json"]


def read_remote(rel: str, base: str) -> bytes:
    url = f"{base}/{rel}"
    with urllib.request.urlopen(url, timeout=60) as r:
        return r.read()


def read_local(rel: str, base: str) -> bytes:
    return (Path(base) / rel).read_bytes()


def md5(data: bytes) -> str:
    return hashlib.md5(data).hexdigest()


def merge_dosage_database(remote: bytes, local_path: Path) -> bytes | None:
    """Общие записи — из vetvoice, локальные дополнения — сохраняются.

    Возвращает новые байты, либо None, если семантически ничего не меняется
    (не трогаем файл впустую — иначе каждая выдача скрипта будет шуметь в git).
    """
    remote_json = json.loads(remote)
    local_json = json.loads(local_path.read_text(encoding="utf-8"))
    r_doses = remote_json.get("dosages", {})
    l_doses = local_json.get("dosages", {})
    merged = dict(r_doses)
    for k in l_doses:
        if k not in r_doses:
            merged[k] = l_doses[k]
    if merged == l_doses and remote_json.get("meta") == local_json.get("meta"):
        return None  # локальная копия уже супермножество канона — не трогаем
    remote_json["dosages"] = merged
    out = json.dumps(remote_json, ensure_ascii=False, indent=2)
    return out.encode("utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--from", dest="source", default=RAW_BASE,
                    help="URL-префикс raw.githubusercontent или путь к локальному клону vetvoice")
    ap.add_argument("--check", action="store_true",
                    help="только проверить синхронность, ничего не менять")
    args = ap.parse_args()

    is_url = args.source.startswith("http://") or args.source.startswith("https://")
    read = read_remote if is_url else read_local
    base = args.source.rstrip("/")

    if not is_url:
        # Передали корень клона vetvoice — дополним до каталога с данными.
        root = Path(base)
        if (root / "assets" / "data" / "verified_dosages.json").exists():
            base = str(root / "assets" / "data")

    drift = []
    try:
        for rel in SYNC_FILES:
            remote = read(rel, base)
            local_path = DATA / rel
            if not local_path.exists():
                drift.append((rel, "отсутствует локально"))
                if not args.check:
                    local_path.parent.mkdir(parents=True, exist_ok=True)
                    local_path.write_bytes(remote)
                print(f"  {'+СКРИПТ' if not args.check else '  DRIFT'} {rel}: отсутствует -> {'записан' if not args.check else 'нужна запись'}")
                continue
            local = local_path.read_bytes()
            if md5(local) != md5(remote):
                n_remote = count_entries(remote, rel)
                n_local = count_entries(local, rel)
                drift.append((rel, f"дрейф (локально {n_local} записей, в vetvoice {n_remote})"))
                if not args.check:
                    local_path.write_bytes(remote)
                print(f"  {'UPD' if not args.check else 'DRIFT'} {rel}: {n_local} -> {n_remote} записей"
                      + ("" if not args.check else " (нужен синк)"))
            else:
                print(f"  OK  {rel}")

        for rel in MERGE_FILES:
            remote = read(rel, base)
            local_path = DATA / rel
            if not local_path.exists():
                drift.append((rel, "отсутствует локально"))
                if not args.check:
                    local_path.write_bytes(remote)
                print(f"  {'NEW' if not args.check else 'DRIFT'} {rel}: записан из vetvoice")
                continue
            merged = merge_dosage_database(remote, local_path)
            if merged is None:
                print(f"  OK  {rel} (локальное супермножество канона)")
            else:
                drift.append((rel, "merge-расхождение"))
                if not args.check:
                    local_path.write_bytes(merged)
                print(f"  {'MRG' if not args.check else 'DRIFT'} {rel}: смёржено с vetvoice")
    except Exception as e:  # noqa: BLE001
        print(f"ОШИБКА чтения источника: {e}", file=sys.stderr)
        return 2

    print()
    if drift:
        for rel, why in drift:
            print(f"  ! {rel}: {why}")
        mode = "Рассинхрон обнаружен" if args.check else "Синхронизировано"
        print(f"{mode}: {len(drift)} файл(ов). Источник: vetvoice ({'GitHub' if is_url else 'локально'}).")
        return 1 if args.check else 0
    print(f"Все базы синхронны с vetvoice ({'GitHub' if is_url else 'локально'}).")
    return 0


def count_entries(data: bytes, rel: str) -> str:
    """Короткая человекочитаемая метрика для отчёта."""
    try:
        d = json.loads(data)
    except Exception:  # noqa: BLE001
        return "?"
    if rel == "verified_dosages.json":
        return len([k for k in d if k != "_meta"])
    if rel == "drugs_calc.json":
        return len(d.get("drugs_calc", []))
    if rel == "diseases.json":
        return len(d.get("diseases", []))
    if rel == "drugs.json":
        return len(d.get("drugs", []))
    if rel.endswith("treatment_protocols.json"):
        return len(d.get("protocols", d if isinstance(d, list) else []))
    return len(d)


if __name__ == "__main__":
    sys.exit(main())
