"""Tests for FastAPI endpoints"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from src.models.schemas import AnalysisRequest, AnalysisResponse, HealthResponse


def test_analysis_request():
    req = AnalysisRequest(description="itchy dog", breed="Labrador", age="5 years")
    assert req.description == "itchy dog"
    assert req.breed == "Labrador"
    print("✅ AnalysisRequest works")


def test_analysis_request_defaults():
    req = AnalysisRequest()
    assert req.description == ""
    assert req.breed == ""
    assert req.age == ""
    print("✅ AnalysisRequest defaults work")


def test_analysis_response():
    resp = AnalysisResponse(
        vlm_analysis="Papules on ventrum",
        diagnosis="Atopic dermatitis - 75%",
        conditions=["atopic dermatitis", "pyoderma"],
    )
    assert len(resp.conditions) == 2
    assert "disclaimer" in resp.disclaimer.lower() or "veterinar" in resp.disclaimer.lower()
    print("✅ AnalysisResponse works")


def test_health_response():
    health = HealthResponse(rag_loaded=True)
    assert health.status == "ok"
    assert health.rag_loaded is True
    assert health.version == "1.0.0"
    print("✅ HealthResponse works")


if __name__ == "__main__":
    test_analysis_request()
    test_analysis_request_defaults()
    test_analysis_response()
    test_health_response()
    print("\n🎉 All API model tests passed!")
