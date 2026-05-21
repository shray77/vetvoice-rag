"""VetVoice VLM Client — GLM-4V vision model for skin image analysis"""

import os
import base64
import io
import requests
from PIL import Image
from typing import Optional


VLM_PROMPT = """You are a veterinary dermatologist examining a photo of an animal's skin condition.
Provide a detailed, structured description:

1. **Species & Breed** (if identifiable from the image)
2. **Primary Lesions**: papules, pustules, nodules, macules, plaques, wheals, vesicles, bullae, tumors
3. **Secondary Lesions**: scales, crusts, excoriations, erosions, ulcers, lichenification, hyperpigmentation, alopecia, comedones
4. **Distribution**: focal / multifocal / generalized / symmetric / asymmetric
5. **Body Regions**: face, ears, ventrum, axillae, inguinal, paws, dorsum, tail, perianal
6. **Pruritus Signs**: excoriations, self-trauma, lichenification, salivary staining
7. **Severity**: mild / moderate / severe
8. **Additional Observations**: discoloration, odor signs, discharge, swelling

Use precise veterinary dermatological terminology. Be specific about lesion morphology."""


class GLMVisionClient:
    """Client for Vision Language Model API (GLM-4V or compatible)"""

    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        model: Optional[str] = None,
    ):
        self.api_key = api_key or os.environ.get("GLM_API_KEY", os.environ.get("OPENAI_API_KEY", ""))
        self.base_url = base_url or os.environ.get("GLM_BASE_URL", "https://open.bigmodel.cn/api/paas/v4")
        self.model = model or os.environ.get("VLM_MODEL", "glm-4v")

    def _image_to_base64(self, image: Image.Image) -> str:
        """Convert PIL Image to base64 string"""
        buffered = io.BytesIO()
        image.save(buffered, format="JPEG", quality=85)
        return base64.b64encode(buffered.getvalue()).decode("utf-8")

    def analyze_skin_image(self, image: Image.Image) -> str:
        """Analyze a skin image using VLM and return structured description"""
        if not self.api_key:
            return "[VLM: No API key configured. Set GLM_API_KEY environment variable.]"

        b64 = self._image_to_base64(image)
        payload = {
            "model": self.model,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/jpeg;base64,{b64}"}
                        },
                        {
                            "type": "text",
                            "text": VLM_PROMPT
                        }
                    ]
                }
            ],
            "max_tokens": 800,
            "temperature": 0.3,
        }
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        try:
            response = requests.post(
                f"{self.base_url}/chat/completions",
                json=payload,
                headers=headers,
                timeout=60,
            )
            response.raise_for_status()
            result = response.json()
            return result["choices"][0]["message"]["content"]
        except requests.exceptions.Timeout:
            return "[VLM Error: Request timed out after 60s]"
        except requests.exceptions.ConnectionError:
            return "[VLM Error: Cannot connect to API server]"
        except KeyError:
            return f"[VLM Error: Unexpected API response format]"
        except Exception as e:
            return f"[VLM Error: {str(e)}]"
