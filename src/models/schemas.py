"""VetVoice data models — Pydantic schemas"""

from pydantic import BaseModel, Field
from typing import List


class AnalysisRequest(BaseModel):
    """Request for veterinary case analysis"""
    description: str = Field(default="", description="Text description of symptoms")
    breed: str = Field(default="", description="Animal breed")
    age: str = Field(default="", description="Animal age")


class AnalysisResponse(BaseModel):
    """Response from veterinary case analysis"""
    vlm_analysis: str = Field(default="", description="VLM image analysis results")
    diagnosis: str = Field(default="", description="LLM-generated differential diagnosis")
    conditions: List[str] = Field(default_factory=list, description="Detected conditions")
    disclaimer: str = Field(
        default="This is AI-assisted analysis, not a veterinary diagnosis. "
                "Consult a licensed veterinarian for definitive diagnosis and treatment."
    )


class HealthResponse(BaseModel):
    """Health check response"""
    status: str = "ok"
    rag_loaded: bool = False
    version: str = "1.0.0"
