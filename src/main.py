"""VetVoice RAG — Entry point (FastAPI).

Gradio-интерфейс лежит в ./app.py и запускается отдельно:
    python app.py
"""

import os

import uvicorn

from src.api.app import create_app
from src.settings import get_settings

app = create_app()


if __name__ == "__main__":
    cfg = get_settings()
    uvicorn.run(
        "src.main:app",
        host=cfg.api_host,
        port=int(os.environ.get("PORT", cfg.api_port)),
        reload=False,
    )
