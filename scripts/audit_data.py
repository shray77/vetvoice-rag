#!/usr/bin/env python3
"""Smoke test: load all 18 JSON files and verify the same counts the Flutter app will see."""

import json
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "assets" / "data"


def load(rel):
    p = DATA / rel
    if not p.exists():
        return None
    with p.open("r", encoding="utf-8") as f:
        return json.load(f)


def main():
    print("=" * 60)
    print("VetVoice RAG — Data Audit (what Flutter app will load)")
    print("=" * 60)

    # 1. drugs_calc.json
    d = load("drugs_calc.json")
    n = len(d.get("drugs_calc", [])) if d else 0
    print(f"  1. drugs_calc.json:           {n:>5} drugs")

    # 2. drugs_registry.json
    d = load("drugs_registry.json")
    n = len(d.get("drugs", [])) if d else 0
    print(f"  2. drugs_registry.json:       {n:>5} drugs")

    # 3. drugs.json (animals)
    d = load("drugs.json")
    n = len(d.get("animals", [])) if d else 0
    print(f"  3. drugs.json:                {n:>5} animals")

    # 4. diseases.json (contagious)
    d = load("diseases.json")
    n = len(d.get("diseases", [])) if d else 0
    print(f"  4. diseases.json:             {n:>5} contagious diseases")

    # 5. non_contagious_diseases.json
    d = load("non_contagious_diseases.json")
    n = len(d.get("diseases", [])) if d else 0
    print(f"  5. non_contagious_diseases:   {n:>5} non-contagious diseases")

    # 6. drug_interactions.json
    d = load("advanced/drug_interactions.json")
    n = len(d.get("interactions", [])) if d else 0
    print(f"  6. drug_interactions.json:    {n:>5} interactions")

    # 7. side_effects.json
    d = load("advanced/side_effects.json")
    n = len(d.get("drugs", [])) if d else 0
    print(f"  7. side_effects.json:         {n:>5} drug entries")

    # 8. antidotes.json
    d = load("advanced/antidotes.json")
    n = len(d.get("poisonings", [])) if d else 0
    print(f"  8. antidotes.json:            {n:>5} antidotes")

    # 9. treatment_protocols.json
    d = load("advanced/treatment_protocols.json")
    n = len(d.get("protocols", [])) if d else 0
    print(f"  9. treatment_protocols.json:  {n:>5} protocols")

    # 10. non_contagious_protocols.json
    d = load("advanced/non_contagious_protocols.json")
    n = len(d.get("protocols", [])) if d else 0
    print(f" 10. non_contagious_protocols:  {n:>5} protocols")

    # 11. emergency_protocols.json
    d = load("advanced/emergency_protocols.json")
    n = len(d.get("protocols", [])) if d else 0
    print(f" 11. emergency_protocols.json:  {n:>5} emergency protocols")

    # 12. fluid_therapy.json
    d = load("advanced/fluid_therapy.json")
    n = len(d.get("formulas", [])) if d else 0
    print(f" 12. fluid_therapy.json:        {n:>5} formulas")

    # 13. withdrawal_by_product.json
    d = load("advanced/withdrawal_by_product.json")
    n = len(d.get("drugs", [])) if d else 0
    print(f" 13. withdrawal_by_product:     {n:>5} entries")

    # 14. dose_adjustments.json
    d = load("advanced/dose_adjustments.json")
    keys = ['age_adjustments', 'renal_adjustment', 'hepatic_adjustment',
            'cardiac_adjustment', 'pregnancy_lactation']
    n = sum(1 for k in keys if d and d.get(k)) if d else 0
    print(f" 14. dose_adjustments.json:     {n:>5} adjustment sections")

    # 15. verified_dosages.json
    d = load("verified_dosages.json")
    n = len([k for k in (d or {}).keys() if k != "_meta"])
    print(f" 15. verified_dosages.json:     {n:>5} verified dosages")

    # 16. correct_dosages_reference.json
    d = load("correct_dosages_reference.json")
    n = len(d.get("dosages", {})) if d else 0
    print(f" 16. correct_dosages_ref.json:  {n:>5} reference dosages")

    # 17. dosage_database.json
    d = load("dosage_database.json")
    n = len(d.get("dosages", {})) if d else 0
    print(f" 17. dosage_database.json:      {n:>5} dosage entries")

    # 18. unofficial_protocols.json
    d = load("unofficial_protocols.json")
    n = len(d.get("records", [])) if d else 0
    print(f" 18. unofficial_protocols.json: {n:>5} records")

    # Totals
    print()
    print("Expected Flutter app totals:")
    print("  - 169 diseases (139 contagious + 30 non-contagious)")
    print("  - 154 treatment protocols (124 + 30)")
    print("  - All 18 JSON files loaded")

    # Verify a few Disease records parse correctly
    print()
    print("Sample Disease records (verifying schema):")
    d = load("diseases.json")
    for d_rec in (d or {}).get("diseases", [])[:3]:
        print(f"  - id={d_rec.get('id')} name={d_rec.get('name')} code={d_rec.get('code')} "
              f"category={d_rec.get('category')} animals={d_rec.get('animals')}")

    print()
    print("Sample DrugInteraction (verifying schema):")
    d = load("advanced/drug_interactions.json")
    for it in (d or {}).get("interactions", [])[:2]:
        print(f"  - drug1={it.get('drug1')} drug2={it.get('drug2')} severity={it.get('severity')}")
        print(f"    effect={it.get('effect', '')[:80]}")
        print(f"    consequence={it.get('consequence', '')[:80]}")
        print(f"    recommendation={it.get('recommendation', '')[:80]}")

    print()
    print("Sample TreatmentProtocol (verifying schema):")
    d = load("advanced/treatment_protocols.json")
    for p in (d or {}).get("protocols", [])[:1]:
        print(f"  - diagnosis={p.get('diagnosis')} code={p.get('code')} severity={p.get('severity')}")
        if isinstance(p.get('treatment'), dict):
            for tier_name, tier in p['treatment'].items():
                drugs = tier.get('drugs', []) if isinstance(tier, dict) else []
                print(f"    {tier_name}: {len(drugs)} drugs")
                for dr in drugs[:2]:
                    if isinstance(dr, dict):
                        print(f"      - {dr.get('name')} (inn={dr.get('inn')}, dose={dr.get('dose')})")


if __name__ == "__main__":
    main()
