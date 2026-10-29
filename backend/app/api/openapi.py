"""The exported OpenAPI documents (the contract), shared by both apps.

FastAPI generates each document; two things are then corrected so the documents say what the
API actually sends:

- Errors: every 4xx/5xx JSON response is ``ErrorEnvelope``. FastAPI declares its own
  ``HTTPValidationError`` for 422, but ``errors.register_exception_handlers`` answers every
  validation error with the envelope (research R8).
- Examples: FastAPI encodes the document with ``exclude_none``, which drops ``"data": null`` and
  ``"error": null`` from envelope examples. They are put back, so each example still validates
  against its schema (Prism serves them as the admin mock; the generated clients parse them).
"""

from __future__ import annotations

from collections.abc import Callable, Iterator
from typing import Any

from fastapi import FastAPI

from app.api.envelope import ErrorEnvelope

_REF_TEMPLATE = "#/components/schemas/{model}"
_FASTAPI_VALIDATION_SCHEMAS = ("HTTPValidationError", "ValidationError")


def _json_responses(document: dict[str, Any]) -> Iterator[tuple[str, dict[str, Any]]]:
    for operations in document.get("paths", {}).values():
        for operation in operations.values():
            for status, response in operation.get("responses", {}).items():
                content = response.get("content", {}).get("application/json")
                if content is not None:
                    yield status, content


def contract_document(document: dict[str, Any]) -> dict[str, Any]:
    """Apply the two corrections above to a FastAPI-generated document, in place."""
    schemas = document.setdefault("components", {}).setdefault("schemas", {})
    error_envelope = ErrorEnvelope.model_json_schema(ref_template=_REF_TEMPLATE)
    schemas.update(error_envelope.pop("$defs", {}))
    schemas["ErrorEnvelope"] = error_envelope

    for status, content in _json_responses(document):
        if status[:1] in {"4", "5"}:
            content["schema"] = {"$ref": _REF_TEMPLATE.format(model="ErrorEnvelope")}
        for example in content.get("examples", {}).values():
            value = example.get("value")
            if isinstance(value, dict) and "success" in value:
                value.setdefault("data", None)
                value.setdefault("error", None)

    for name in _FASTAPI_VALIDATION_SCHEMAS:
        schemas.pop(name, None)
    return document


def install(app: FastAPI) -> None:
    """Make ``app.openapi()`` (served at /openapi.json and exported by the CLI) the corrected document."""
    generate: Callable[[], dict[str, Any]] = app.openapi

    def openapi() -> dict[str, Any]:
        if app.openapi_schema is None:
            app.openapi_schema = contract_document(generate())
        return app.openapi_schema

    app.openapi = openapi  # type: ignore[method-assign]
