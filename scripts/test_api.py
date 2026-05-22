#!/usr/bin/env python3
"""Test VetVoice API endpoint"""

import sys
import requests
import json

BASE_URL = "http://localhost:7860"


def test_health():
    r = requests.get(f"{BASE_URL}/health", timeout=10)
    assert r.status_code == 200, f"Health failed: {r.status_code}"
    data = r.json()
    print(f"Health: {data}")
    assert data["status"] == "ok"
    print("✅ Health check passed")


def test_analyze_text():
    r = requests.post(
        f"{BASE_URL}/analyze",
        data={"description": "French Bulldog scratching paws and face, red inflamed skin", "breed": "French Bulldog", "age": "3 years"},
        timeout=120,
    )
    assert r.status_code == 200, f"Analyze failed: {r.status_code}"
    data = r.json()
    print(f"Diagnosis length: {len(data['diagnosis'])} chars")
    print(f"Conditions: {data['conditions']}")
    assert data["diagnosis"], "Empty diagnosis"
    print("✅ Text analysis passed")


def test_analyze_russian():
    r = requests.post(
        f"{BASE_URL}/analyze",
        data={"description": "Мой французский бульдог чешет лапы, кожа красная", "breed": "Французский бульдог", "age": "2 года"},
        timeout=120,
    )
    assert r.status_code == 200, f"Russian analyze failed: {r.status_code}"
    data = r.json()
    print(f"Russian diagnosis: {data['diagnosis'][:200]}...")
    print("✅ Russian analysis passed")


if __name__ == "__main__":
    test_health()
    test_analyze_text()
    test_analyze_russian()
    print("\n🎉 All API tests passed!")
