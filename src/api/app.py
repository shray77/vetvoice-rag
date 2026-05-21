"""VetVoice FastAPI Application — VLM + RAG + LLM pipeline"""

import os
import io
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
import requests as req_lib

from ..rag.retriever import VetDermRAG
from ..vlm.client import GLMVisionClient
from ..models.schemas import AnalysisResponse, HealthResponse


# ============================================================
# SYSTEM PROMPT
# ============================================================
SYSTEM_PROMPT = """You are VetVoice, an expert veterinary dermatologist AI assistant with 20+ years of clinical experience in canine and feline dermatology. You specialize in diagnosing skin conditions from photographs and clinical descriptions, providing differential diagnoses, and recommending evidence-based treatment plans.

## CORE IDENTITY
- You are a board-certified veterinary dermatologist (DACVD-level expertise)
- You follow current veterinary dermatology guidelines (ESVD, AAVD, WSAVA)
- You think systematically using dermatological diagnostic algorithms
- You communicate in a clear, professional, yet compassionate tone

## DIAGNOSTIC FRAMEWORK

When analyzing a case, ALWAYS follow this structured approach:

### Step 1: Signalment Analysis
- Species, breed, age, sex — certain conditions have breed predispositions
- Example: Atopic dermatitis — Westies, French Bulldogs, Labradors; Demodicosis — young dogs or immunocompromised

### Step 2: Lesion Description (Morphological)
Identify PRIMARY lesions: papules, pustules, vesicles, bullae, nodules, tumors, macules, patches, plaques, wheals
Identify SECONDARY lesions: scales, crusts, excoriations, erosions, ulcers, lichenification, hyperpigmentation, alopecia, comedones
Distribution pattern: focal / multifocal / generalized / symmetric / asymmetric
Body regions affected: face, ears, ventrum, axillae, inguinal, paws, dorsum, tail, perianal

### Step 3: Pattern Recognition — Differential Diagnosis
**Pruritic (itchy) patterns:**
- Facial/ear pruritus -> atopic dermatitis, food allergy, Malassezia, otitis externa
- Ventral/axillary pruritus -> atopic dermatitis, contact allergy, Malassezia dermatitis
- Generalized pruritus -> scabies, atopic dermatitis, food adverse reaction, flea allergy
- Paw pruritus -> atopic dermatitis, food allergy, contact, Malassezia

**Non-pruritic / minimally pruritic patterns:**
- Alopecia without inflammation -> endocrine (hypothyroidism, hyperadrenocorticism), follicular dysplasia
- Scaling/crusting -> seborrhea, zinc-responsive dermatosis, pemphigus
- Nodules/tumors -> histiocytoma, lipoma, mast cell tumor
- Ulcerative/erosive -> pemphigus complex, vasculitis

### Step 4: Diagnostic Recommendations
Suggest step-by-step diagnostics in order of clinical utility

### Step 5: Treatment Plan
Provide FIRST-LINE and ALTERNATIVE treatments with specific drug names, dosages, duration

## CRITICAL RULES
1. NEVER provide a single definitive diagnosis from a photo alone - always provide a ranked differential list
2. ALWAYS state confidence level: High (>80%), Moderate (50-80%), Low (<50%)
3. ALWAYS add disclaimer about AI nature of analysis
4. ALWAYS consider zoonotic potential (scabies, dermatophytosis)
5. ALWAYS ask follow-up questions if critical information is missing
6. NEVER recommend prescription medications without noting they require veterinary prescription
7. ALWAYS prioritize ruling out parasites and infections before diagnosing allergic/autoimmune conditions
8. Use the RAG context provided to support your analysis with evidence-based information

## RESPONSE FORMAT

### Primary Analysis
- **Patient:** [breed, age, sex]
- **Lesion type:** [primary + secondary]
- **Location:** [body regions]
- **Pruritus:** [present/absent, severity]

### Differential Diagnosis (by probability)
1. **[Diagnosis]** - probability [%] - rationale: [...]
2. **[Diagnosis]** - probability [%] - rationale: [...]
3. **[Diagnosis]** - probability [%] - rationale: [...]

### Recommended Diagnostic Tests
1. [Test] - purpose: [...]

### Recommended Treatment
**Systemic therapy:** [drug, dosage, route, duration]
**Topical therapy:** [product, frequency, duration]
**Monitoring:** [what to check]

### Important Notes
- [Zoonotic potential, red flags]

### Follow-up Questions
- [What to clarify with the owner]

## LANGUAGE
Respond in the SAME language the user writes in."""


# ============================================================
# APP STATE
# ============================================================
class AppState:
    """Shared application state"""
    rag: Optional[VetDermRAG] = None
    vlm: Optional[GLMVisionClient] = None


state = AppState()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan: startup and shutdown"""
    # Startup
    try:
        state.rag = VetDermRAG()
    except Exception as e:
        print(f"RAG load warning: {e}")
        state.rag = None
    state.vlm = GLMVisionClient()
    yield
    # Shutdown (cleanup if needed)


# ============================================================
# APP FACTORY
# ============================================================
def create_app() -> FastAPI:
    """Create and configure the FastAPI application"""
    app = FastAPI(
        title="VetVoice RAG API",
        description="AI Veterinary Dermatology Assistant with RAG",
        version="1.0.0",
        lifespan=lifespan,
    )

    # CORS — allow Flutter app and any client
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/health", response_model=HealthResponse)
    async def health():
        return HealthResponse(
            status="ok",
            rag_loaded=state.rag is not None,
            version="1.0.0",
        )

    @app.post("/analyze", response_model=AnalysisResponse)
    async def analyze(
        image: UploadFile = File(default=None),
        description: str = Form(default=""),
        breed: str = Form(default=""),
        age: str = Form(default=""),
    ):
        """Analyze a veterinary dermatology case: image + text -> diagnosis"""
        if not description.strip() and image is None:
            raise HTTPException(400, "Provide either an image or a description")

        # Step 1: VLM image analysis
        vlm_analysis = ""
        if image is not None:
            try:
                contents = await image.read()
                pil_image = Image.open(io.BytesIO(contents)).convert("RGB")
                vlm_analysis = state.vlm.analyze_skin_image(pil_image)
            except Exception as e:
                vlm_analysis = f"[Image processing error: {e}]"

        # Step 2: Build query for RAG
        query_parts = []
        if breed:
            query_parts.append(f"Breed: {breed}")
        if age:
            query_parts.append(f"Age: {age}")
        if description:
            query_parts.append(f"Symptoms: {description}")
        if vlm_analysis and not vlm_analysis.startswith("["):
            query_parts.append(f"Image findings: {vlm_analysis}")
        user_query = " | ".join(query_parts)

        # Step 3: RAG retrieval
        rag_context = ""
        conditions = []
        if state.rag:
            results = state.rag.retrieve(user_query, top_k=5)
            rag_context = state.rag.format_context(results)
            conditions = list(set(
                c
                for r in results
                for c in r.get("conditions", [])
            ))

        # Step 4: LLM diagnosis
        user_message = f"""## RETRIEVED VETERINARY KNOWLEDGE (evidence-based reference):
{rag_context}

## CASE TO ANALYZE:
{user_query}

Analyze this case following the diagnostic framework in your system prompt. Provide a structured differential diagnosis with probabilities, recommended diagnostic tests, and treatment plan."""

        api_key = os.environ.get("GLM_API_KEY", os.environ.get("OPENAI_API_KEY", ""))
        base_url = os.environ.get("GLM_BASE_URL", "https://open.bigmodel.cn/api/paas/v4")
        llm_model = os.environ.get("LLM_MODEL", "glm-4")

        diagnosis = ""
        if api_key:
            try:
                payload = {
                    "model": llm_model,
                    "messages": [
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": user_message},
                    ],
                    "max_tokens": 2000,
                    "temperature": 0.4,
                }
                headers = {
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                }
                resp = req_lib.post(
                    f"{base_url}/chat/completions",
                    json=payload,
                    headers=headers,
                    timeout=90,
                )
                resp.raise_for_status()
                result = resp.json()
                diagnosis = result["choices"][0]["message"]["content"]
            except Exception as e:
                diagnosis = f"[LLM Error: {e}]\n\nRAG Context provided but LLM unavailable. The RAG context above contains relevant veterinary information."
        else:
            diagnosis = (
                "**[No API key configured]**\n\n"
                "Set `GLM_API_KEY` environment variable to enable LLM diagnosis.\n\n"
                f"**RAG Context (retrieved evidence):**\n{rag_context}"
            )

        return AnalysisResponse(
            vlm_analysis=vlm_analysis,
            diagnosis=diagnosis,
            conditions=conditions,
        )

    return app
