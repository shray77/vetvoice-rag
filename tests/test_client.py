"""Tests for the unified GLMClient (offline — HTTP mocked)."""

from unittest import mock
import os

from src.vlm.client import GLMClient


def _fake_response(payload_json):
    class _R:
        status_code = 200

        def json(self):
            return payload_json

    return _R()


def test_configured_flag_without_key():
    # GLMClient falls back to the GLM_API_KEY env var when no key is passed
    # (see src/vlm/client.py). Neutralize it here so the assertion checks the
    # *code* path, not whatever GLM_API_KEY happens to be set in the runner
    # (e.g. CI exports GLM_API_KEY=test, which would make this fail).
    with mock.patch.dict(os.environ, {"GLM_API_KEY": ""}):
        assert GLMClient(api_key="").configured is False
        assert GLMClient().configured is False  # no env -> empty key


def test_configured_flag_with_key():
    c = GLMClient(api_key="k", base_url="https://example.test/api/paas/v4")
    assert c.configured is True
    assert c.base_url == "https://example.test/api/paas/v4"
    assert c.model == "glm-4.5-flash"


def test_generate_text_uses_system_role_and_model():
    c = GLMClient(api_key="k", base_url="https://example.test/api/paas/v4", model="glm-4.5-flash")
    captured = {}

    def fake_post(url, json=None, headers=None, timeout=None):
        captured.update(json)
        return _fake_response({"choices": [{"message": {"content": "ok"}}]})

    with mock.patch("src.vlm.client.requests.post", side_effect=fake_post):
        out = c.generate_text("SYS-PROMPT", "USER-MSG", max_tokens=512)

    assert out == "ok"
    assert captured["model"] == "glm-4.5-flash"
    assert captured["messages"][0] == {"role": "system", "content": "SYS-PROMPT"}
    assert captured["messages"][1] == {"role": "user", "content": "USER-MSG"}
    assert captured["max_tokens"] == 512


def test_analyze_image_uses_vlm_model():
    from PIL import Image

    c = GLMClient(api_key="k", base_url="https://example.test/api/paas/v4", vlm_model="glm-4.6v")
    captured = {}

    def fake_post(url, json=None, headers=None, timeout=None):
        captured.update(json)
        return _fake_response({"choices": [{"message": {"content": "desc"}}]})

    with mock.patch("src.vlm.client.requests.post", side_effect=fake_post):
        out = c.analyze_image(Image.new("RGB", (4, 4)), prompt="P")

    assert out == "desc"
    assert captured["model"] == "glm-4.6v"
