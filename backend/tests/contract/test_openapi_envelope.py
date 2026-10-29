"""Both OpenAPI documents describe errors with the envelope and keep their examples whole.

- Every error response (and every 422) is ``ErrorEnvelope``, never FastAPI's default
  ``HTTPValidationError``: the error handlers answer with the envelope (research R8).
- Every named example validates against its own response schema. FastAPI's OpenAPI encoder
  drops ``None`` values, which used to strip ``"error": null`` and ``"data": null`` from the
  examples, so Prism served bodies that broke the schema and the generated clients rejected them.
"""

from __future__ import annotations

import json
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import jsonschema_rs
import pytest

BACKEND = Path(__file__).resolve().parents[2]
DOCS = {
    name: json.loads((BACKEND / "openapi" / f"{name}.json").read_text(encoding="utf-8")) for name in ("public", "admin")
}
ERROR_ENVELOPE = {"$ref": "#/components/schemas/ErrorEnvelope"}


def _json_responses(doc: dict[str, Any]) -> Iterator[tuple[str, dict[str, Any]]]:
    for path, operations in doc["paths"].items():
        for method, operation in operations.items():
            for status, response in operation["responses"].items():
                content = response.get("content", {}).get("application/json")
                if content is not None:
                    yield f"{method.upper()} {path} {status}", content


def _validator(doc: dict[str, Any], schema: dict[str, Any]) -> Any:
    # The response schema's "#/components/..." refs resolve against this root.
    return jsonschema_rs.validator_for({**schema, "components": doc["components"]})


@pytest.mark.parametrize("name", sorted(DOCS))
def test_no_document_uses_fastapis_default_validation_error(name):
    text = json.dumps(DOCS[name])
    assert "HTTPValidationError" not in text
    assert "ValidationError" not in DOCS[name]["components"]["schemas"]


@pytest.mark.parametrize("name", sorted(DOCS))
def test_every_error_response_is_the_error_envelope(name):
    errors = {
        where: content.get("schema")
        for where, content in _json_responses(DOCS[name])
        if where.rsplit(" ", 1)[1][0] in "45"
    }
    assert errors, "expected declared error responses"
    assert {where: schema for where, schema in errors.items() if schema != ERROR_ENVELOPE} == {}


@pytest.mark.parametrize("name", sorted(DOCS))
def test_error_envelope_schema(name):
    envelope = DOCS[name]["components"]["schemas"]["ErrorEnvelope"]
    assert set(envelope["required"]) == {"success", "data", "error", "meta"}
    assert envelope["properties"]["success"]["const"] is False
    assert envelope["properties"]["data"]["type"] == "null"
    assert envelope["properties"]["error"]["$ref"] == "#/components/schemas/ErrorBody"


@pytest.mark.parametrize("name", sorted(DOCS))
def test_every_example_validates_against_its_response_schema(name):
    doc = DOCS[name]
    invalid = {}
    for where, content in _json_responses(doc):
        for key, example in content.get("examples", {}).items():
            errors = [error.message for error in _validator(doc, content["schema"]).iter_errors(example["value"])]
            if errors:
                invalid[f"{where} {key}"] = errors
    assert invalid == {}


def test_admin_examples_keep_their_nulls():
    login = DOCS["admin"]["paths"]["/admin/api/auth/login"]["post"]["responses"]
    ok = login["200"]["content"]["application/json"]["examples"]["login_ok"]["value"]
    locked = login["429"]["content"]["application/json"]["examples"]["account_locked"]["value"]
    assert ok["error"] is None
    assert locked["data"] is None
