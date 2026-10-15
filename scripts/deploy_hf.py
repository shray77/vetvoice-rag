#!/usr/bin/env python3
"""Deploy updated files to HuggingFace Spaces.

Шлёт в shrayyyy/vetderm-ai не только app.py / requirements.txt / Dockerfile,
но и src/ (единый GLMClient, retriever, settings) + configs/config.yaml —
иначе refactor не дойдёт до прод-инстанса и app.py упадёт на импорте src.*.
"""

import os
from pathlib import Path

from huggingface_hub import HfApi

REPO_ID = "shrayyyy/vetderm-ai"
TOKEN = os.environ.get("HF_TOKEN", "")

if not TOKEN:
    print("ERROR: HF_TOKEN not set")
    exit(1)

api = HfApi()

# Flat files + whole directories that the Gradio app imports at runtime.
INCLUDE = [
    "app.py",
    "requirements.txt",
    "Dockerfile",
    "configs/config.yaml",
]
INCLUDE_DIRS = ["src", "scripts"]

files = list(INCLUDE)
for d in INCLUDE_DIRS:
    root = Path(d)
    if root.is_dir():
        for p in sorted(root.rglob("*")):
            if p.is_file() and p.suffix == ".py":
                files.append(str(p))

for local_path in files:
    if os.path.exists(local_path):
        print(f"Uploading {local_path}")
        api.upload_file(
            path_or_fileobj=local_path,
            path_in_repo=local_path,
            repo_id=REPO_ID,
            repo_type="space",
            token=TOKEN,
        )
    else:
        print(f"Skipping {local_path} (not found)")

print("Deploy complete!")
