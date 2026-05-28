#!/usr/bin/env python3
"""
Generate architecture diagrams via GPUGeek image generation API.

Uses ACE_LLM_API_KEY for authentication. Saves base64-encoded image
responses to a file.
"""

import argparse
import base64
import json
import os
import sys
from pathlib import Path

import requests

API_URL = "https://api.gpugeek.com/v1/images/generations"
DEFAULT_MODEL = "Vendor2/GPT-image-2"
DEFAULT_SIZE = "1024x1024"
HD_SIZE = "4096x4096"
DEFAULT_TIMEOUT = 300  # image generation can be slow


def generate_diagram(
    prompt: str,
    output_path: str,
    size: str = DEFAULT_SIZE,
    api_key: str | None = None,
    timeout: int = DEFAULT_TIMEOUT,
) -> str:
    """Call image generation API and save the resulting image.

    Args:
        prompt: Image generation prompt (should describe the architecture).
        output_path: Path where the image will be saved.
        size: Image size, e.g. "1024x1024" or "4096x4096".
        api_key: GPUGeek API key. Falls back to ACE_LLM_API_KEY env var.
        timeout: HTTP request timeout in seconds.

    Returns:
        Absolute path to the saved image.

    Raises:
        RuntimeError: If no API key is available.
        requests.HTTPError: If the API returns an error status.
        KeyError: If the response JSON does not contain the expected fields.
    """
    api_key = api_key or os.getenv("ACE_LLM_API_KEY")
    if not api_key:
        raise RuntimeError(
            "API key not found. Set ACE_LLM_API_KEY environment variable."
        )

    payload = {
        "model": DEFAULT_MODEL,
        "prompt": prompt,
        "size": size,
        "response_format": "b64_json",
    }

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    resp = requests.post(API_URL, headers=headers, json=payload, timeout=timeout)
    resp.raise_for_status()
    data = resp.json()

    b64_image = data["data"][0]["b64_json"]
    image_bytes = base64.b64decode(b64_image)

    out = Path(output_path)
    out.write_bytes(image_bytes)
    return str(out.resolve())


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate architecture diagrams via GPUGeek image API."
    )
    parser.add_argument("prompt", help="Image generation prompt.")
    parser.add_argument(
        "-o", "--output", required=True, help="Output file path (e.g. diagram.png)."
    )
    parser.add_argument(
        "--size",
        default=DEFAULT_SIZE,
        choices=[DEFAULT_SIZE, HD_SIZE],
        help=f"Image size. Default: {DEFAULT_SIZE}. HD: {HD_SIZE}.",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=DEFAULT_TIMEOUT,
        help=f"Request timeout in seconds. Default: {DEFAULT_TIMEOUT}.",
    )
    parser.add_argument(
        "--api-key",
        default=os.getenv("ACE_LLM_API_KEY"),
        help="GPUGeek API key. Defaults to ACE_LLM_API_KEY env var.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output the saved file path as JSON.",
    )

    args = parser.parse_args()

    try:
        path = generate_diagram(
            prompt=args.prompt,
            output_path=args.output,
            size=args.size,
            api_key=args.api_key,
            timeout=args.timeout,
        )
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    except requests.HTTPError as e:
        print(f"API request failed: {e}", file=sys.stderr)
        return 1
    except KeyError as e:
        print(f"Unexpected API response format: missing key {e}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps({"path": path, "size": args.size}, ensure_ascii=False))
    else:
        print(f"Image saved: {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
