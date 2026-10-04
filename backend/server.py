"""Personal Deep-dive backend for the Say It Better iOS app.

Runs on a machine you control (your Mac) and answers with Claude through the Claude Agent SDK,
authenticated with your own Claude Code login, so calls draw on your Claude subscription rather
than separately billed API usage. Personal use on your own devices only.

    GET  /health                  -> {"ok": true}
    GET  /deepdive?word=cadence   -> deep-dive JSON (same shape as the app's bundled deepdive.json)
    GET  /lookup?word=anything    -> one word card: {word, pronunciation, partOfSpeech, definition, example, insteadOf, goesWith}
    POST /checkSentence           -> {"verdict", "feedback", "improved"}  body: {"word", "sentence"}

Run:  uvicorn server:app --host 0.0.0.0 --port 8765
"""

from __future__ import annotations

import json
import logging
import os
import re
import time
from typing import Any

from claude_agent_sdk import ClaudeAgentOptions, ResultMessage, query
from fastapi import FastAPI, HTTPException, Query, Request
from pydantic import BaseModel, Field

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("sayitbetter")

COACH = (
    "You are a vocabulary coach for a lead software engineer who wants to sound clear and "
    "confident when presenting and explaining technical work to teams and stakeholders."
)

SETTINGS = ["Standup", "Design review", "Incident call", "Stakeholder update", "1:1", "Email"]

DEEPDIVE_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "word": {"type": "string"},
        "pronunciation": {"type": "string"},
        "partOfSpeech": {"type": "string", "description": "One short label, e.g. noun, verb, adjective"},
        "meaning": {"type": "string"},
        "origin": {"type": "string"},
        "family": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {"word": {"type": "string"}, "meaning": {"type": "string"}},
                "required": ["word", "meaning"],
            },
        },
        "collocations": {"type": "array", "items": {"type": "string"}},
        "compare": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {"word": {"type": "string"}, "difference": {"type": "string"}},
                "required": ["word", "difference"],
            },
        },
        "mistake": {"type": "string"},
        "examples": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {"setting": {"type": "string"}, "sentence": {"type": "string"}},
                "required": ["setting", "sentence"],
            },
        },
        "tip": {"type": "string"},
    },
    "required": [
        "word", "pronunciation", "partOfSpeech", "meaning", "origin", "family",
        "collocations", "compare", "mistake", "examples", "tip",
    ],
}

LOOKUP_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "word": {"type": "string"},
        "pronunciation": {"type": "string"},
        "partOfSpeech": {"type": "string", "description": "One short label, e.g. noun, verb, adjective"},
        "definition": {"type": "string"},
        "example": {"type": "string"},
        "insteadOf": {"type": "string"},
        "goesWith": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["word", "pronunciation", "partOfSpeech", "definition", "example", "insteadOf", "goesWith"],
}

FEEDBACK_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "verdict": {"type": "string", "enum": ["good", "almost", "off"]},
        "feedback": {"type": "string"},
        "improved": {"type": "string"},
    },
    "required": ["verdict", "feedback", "improved"],
}

app = FastAPI(title="Say It Better backend")
_cache: dict[str, dict[str, Any]] = {}


@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log every request as: METHOD path?query -> status (ms), plus the client address."""
    start = time.perf_counter()
    response = await call_next(request)
    ms = (time.perf_counter() - start) * 1000
    client = request.client.host if request.client else "?"
    target = request.url.path + (f"?{request.url.query}" if request.url.query else "")
    log.info("%s %s from %s -> %d (%.0f ms)", request.method, target, client, response.status_code, ms)
    return response


async def ask_claude(prompt: str, schema: dict[str, Any]) -> dict[str, Any]:
    """One stateless Agent SDK call with no tools, returning parsed JSON."""
    options = ClaudeAgentOptions(
        tools=[],  # a pure writing task: no file, shell or web access
        max_turns=3,
        setting_sources=[],  # ignore any CLAUDE.md / settings in the directory it runs from
        output_format={"type": "json_schema", "schema": schema},
        model=os.environ.get("SAYITBETTER_MODEL") or None,
    )
    log.info("Claude request: %s", prompt[:200].replace("\n", " "))
    result: ResultMessage | None = None
    async for message in query(prompt=prompt, options=options):
        if isinstance(message, ResultMessage):
            result = message

    if result is None or result.is_error:
        detail = (result.errors or result.result) if result else "no result"
        log.error("Claude call failed: %s", detail)
        raise HTTPException(status_code=502, detail=f"Claude call failed: {detail}")
    data = result.structured_output if isinstance(result.structured_output, dict) else _parse_json(result.result or "")
    log.info("Claude response: %s", json.dumps(data, ensure_ascii=False)[:300])
    return data


def _parse_json(text: str) -> dict[str, Any]:
    """Fallback for a plain-text reply: take the outermost {...} block."""
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        raise HTTPException(status_code=502, detail="Claude did not return JSON")
    try:
        return json.loads(match.group(0))
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=502, detail=f"Claude returned malformed JSON: {exc}") from exc


@app.get("/health")
async def health() -> dict[str, bool]:
    return {"ok": True}


@app.get("/deepdive")
async def deepdive(word: str = Query(..., min_length=1, max_length=60)) -> dict[str, Any]:
    key = word.strip().lower()
    if key in _cache:
        return _cache[key]

    prompt = (
        f'{COACH} Explain the English word or phrase "{word.strip()}" in depth. '
        "Reply with only one JSON object: {word, pronunciation, partOfSpeech, meaning, origin, "
        "family: [{word, meaning}], collocations: [string], compare: [{word, difference}], "
        "mistake, examples: [{setting, sentence}], tip}. "
        f"Give exactly one example for each of these settings, in order: {', '.join(SETTINGS)}. "
        "Use a simple respelled pronunciation with the stressed syllable in capitals "
        "(e.g. rek-uhn-sil-ee-AY-shun) and a one-word partOfSpeech (noun, verb, adjective). Keep the etymology accurate; say so if it is uncertain."
    )
    data = await ask_claude(prompt, DEEPDIVE_SCHEMA)
    _cache[key] = data
    return data


@app.get("/lookup")
async def lookup(word: str = Query(..., min_length=1, max_length=60)) -> dict[str, Any]:
    key = "lookup:" + word.strip().lower()
    if key in _cache:
        return _cache[key]

    prompt = (
        f'{COACH} Someone heard or read the word or phrase "{word.strip()}" and wants a quick card for it. '
        "Reply with only one JSON object: {word, pronunciation, partOfSpeech, definition, example, "
        "insteadOf, goesWith}. "
        "definition: one plain sentence. "
        "example: one natural workplace sentence that uses the word, with the word wrapped in square brackets, "
        "e.g. We need to [prioritize] the migration. "
        "insteadOf: a plainer phrase a person would otherwise say. "
        "goesWith: exactly three short phrases the word is commonly used with. "
        "pronunciation: a simple respelling with the stressed syllable in capitals. "
        "partOfSpeech: one short label such as noun, verb or adjective."
    )
    data = await ask_claude(prompt, LOOKUP_SCHEMA)
    _cache[key] = data
    return data


class SentenceIn(BaseModel):
    word: str = Field(min_length=1, max_length=60)
    sentence: str = Field(min_length=1, max_length=600)


@app.post("/checkSentence")
async def check_sentence(body: SentenceIn) -> dict[str, Any]:
    prompt = (
        f'{COACH} They wrote this sentence to practise the word "{body.word}":\n\n'
        f"{body.sentence}\n\n"
        "Judge whether the word is used correctly and naturally for a workplace setting. "
        'Reply with only one JSON object: {verdict: "good" | "almost" | "off", '
        "feedback: one or two encouraging, specific sentences, "
        "improved: a polished version of their sentence that keeps their meaning}."
    )
    return await ask_claude(prompt, FEEDBACK_SCHEMA)
