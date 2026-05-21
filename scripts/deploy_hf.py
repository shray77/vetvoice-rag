#!/usr/bin/env python3
"""Deploy updated files to HuggingFace Spaces."""
import os
from huggingface_hub import HfApi

REPO_ID = "shrayyyy/vetderm-ai"
TOKEN = os.environ.get("HF_TOKEN", "")

if not TOKEN:
    print("ERROR: HF_TOKEN not set")
    exit(1)

api = HfApi()

# Map local files to their target paths in the HF Space repo
FILES = {
    "src/api/app.py": "app.py",
    "requirements.txt": "requirements.txt",
}

for local_path, remote_path in FILES.items():
    if os.path.exists(local_path):
        print(f"Uploading {local_path} -> {remote_path}")
        api.upload_file(
            path_or_fileobj=local_path,
            path_in_repo=remote_path,
            repo_id=REPO_ID,
            repo_type="space",
            token=TOKEN,
        )
    else:
        print(f"Skipping {local_path} (not found)")

print("Deploy complete!")
