"""Tests for FastAPI endpoints (offline — no network, no RAG download)."""

from fastapi.testclient import TestClient

from src.api.app import create_app


def test_root_endpoint():
    client = TestClient(create_app())
    r = client.get("/")
    assert r.status_code == 200
    assert r.json()["name"] == "VetVoice RAG API"


def test_health_root():
    client = TestClient(create_app())
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_health_v1_open_mode():
    # No VETVOICE_API_KEYS -> open mode, auth_enabled False
    client = TestClient(create_app())
    r = client.get("/v1/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["auth_enabled"] is False


def test_guardrail_rejects_unknown_model():
    client = TestClient(create_app())
    r = client.post(
        "/v1/chat/completions",
        json={"model": "gpt-4", "messages": [{"role": "user", "content": "hi"}]},
    )
    assert r.status_code == 400
    assert "not allowed" in r.json()["detail"]
