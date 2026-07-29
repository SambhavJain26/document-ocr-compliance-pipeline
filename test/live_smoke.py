"""Run the Stage 4 text and PDF-vision smoke tests against the Responses API.

Synthetic fixtures only. The script reads OPENAI_API_KEY from the ignored root
.env file, prints no secret or raw response, and leaves uploaded test files in
the OpenAI project for the normal API retention period.
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[1]
API = "https://api.openai.com/v1"
MODEL = "gpt-5.4-mini-2026-03-17"


def load_env() -> None:
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, value = line.split("=", 1)
            if key and key not in os.environ:
                os.environ[key] = value


def request_json(path: str, payload: dict) -> tuple[dict, int]:
    started = time.perf_counter()
    request = urllib.request.Request(
        API + path,
        data=json.dumps(payload).encode(),
        headers={
            "Authorization": "Bearer " + os.environ["OPENAI_API_KEY"],
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        result = json.loads(response.read())
    return result, round((time.perf_counter() - started) * 1000)


def upload_pdf(path: Path) -> str:
    boundary = "----coi-smoke-" + uuid.uuid4().hex
    body = bytearray()
    for name, value in (("purpose", "user_data"),):
        body.extend(("--" + boundary + "\r\n").encode())
        body.extend(('Content-Disposition: form-data; name="' + name + '"\r\n\r\n').encode())
        body.extend(value.encode() + b"\r\n")
    body.extend(("--" + boundary + "\r\n").encode())
    body.extend(
        ('Content-Disposition: form-data; name="file"; filename="' + path.name +
         '"\r\nContent-Type: application/pdf\r\n\r\n').encode()
    )
    body.extend(path.read_bytes())
    body.extend(b"\r\n--" + boundary.encode() + b"--\r\n")
    request = urllib.request.Request(
        API + "/files",
        data=bytes(body),
        headers={
            "Authorization": "Bearer " + os.environ["OPENAI_API_KEY"],
            "Content-Type": "multipart/form-data; boundary=" + boundary,
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        return json.loads(response.read())["id"]


def delete_file(file_id: str) -> None:
    request = urllib.request.Request(
        API + "/files/" + file_id,
        headers={"Authorization": "Bearer " + os.environ["OPENAI_API_KEY"]},
        method="DELETE",
    )
    with urllib.request.urlopen(request, timeout=30):
        pass


def response_text(result: dict) -> dict:
    text = result.get("output_text")
    if not text:
        for item in result.get("output", []):
            for content in item.get("content", []):
                if content.get("type") == "output_text":
                    text = content.get("text")
                    break
    if not text:
        raise AssertionError("Responses API returned no output text")
    return json.loads(text)


def payload(schema: dict, prompt: str, content: list[dict], effort: str) -> dict:
    return {
        "model": MODEL,
        "instructions": prompt,
        "input": [{"role": "user", "content": content}],
        "text": {"format": {"type": "json_schema", "name": "coi_extraction", "strict": True, "schema": schema}},
        "reasoning": {"effort": effort},
        "max_output_tokens": 3000,
        "store": False,
    }


def metric(label: str, result: dict, latency_ms: int) -> None:
    usage = result.get("usage", {})
    print(
        label + ": input=" + str(usage.get("input_tokens", "?")) +
        " output=" + str(usage.get("output_tokens", "?")) +
        " latency_ms=" + str(latency_ms)
    )


def main() -> int:
    load_env()
    if not os.environ.get("OPENAI_API_KEY"):
        raise RuntimeError("OPENAI_API_KEY is required in .env")

    schema = json.loads((ROOT / "extraction/schema/coi_extraction.schema.json").read_text(encoding="utf-8"))
    prompt = (ROOT / "extraction/prompts/extract.system.md").read_text(encoding="utf-8")
    manifest = json.loads((ROOT / "fixtures/out/manifest.json").read_text(encoding="utf-8"))
    expected_expiration = next(item["expiration_date"] for item in manifest["fixtures"] if item["id"] == "f01-clean-current")

    text = PdfReader(ROOT / "fixtures/out/f01-clean-current.pdf").pages[0].extract_text()
    text_result, text_latency = request_json(
        "/responses",
        payload(schema, prompt, [{"type": "input_text", "text": "Extract the certificate data from the following document text.\n\n" + text}], "low"),
    )
    text_extraction = response_text(text_result)
    assert text_extraction["vendor_legal_name"] == "Vaughn Electric Co", "text vendor mismatch"
    assert any(item["expiration_date"] == expected_expiration for item in text_extraction["coverages"]), "text expiration mismatch"
    assert text_extraction["extraction_confidence"] == "HIGH", "text confidence is not HIGH"
    metric("text", text_result, text_latency)

    file_id = upload_pdf(ROOT / "fixtures/out/f04-scanned.pdf")
    try:
        vision_result, vision_latency = request_json(
            "/responses",
            payload(schema, prompt, [{"type": "input_file", "file_id": file_id}], "medium"),
        )
        vision_extraction = response_text(vision_result)
        assert vision_extraction["vendor_legal_name"] == "Vaughn Electric Co", "vision vendor mismatch"
        assert vision_extraction["extraction_confidence"] == "MEDIUM", "vision confidence is " + str(vision_extraction["extraction_confidence"])
        reason = vision_extraction["confidence_reason"] or ""
        assert any(word in reason.lower() for word in ("vendor", "expiration", "date")), "vision confidence reason names no field"
        metric("vision", vision_result, vision_latency)
    finally:
        delete_file(file_id)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (urllib.error.HTTPError, urllib.error.URLError, AssertionError, KeyError, ValueError) as error:
        print("Stage 4 live smoke failed: " + type(error).__name__ + ": " + str(error), file=sys.stderr)
        raise SystemExit(1)
