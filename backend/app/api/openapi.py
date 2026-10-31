"""The exported OpenAPI documents (the contract), shared by both apps.

FastAPI generates each document; two things are then corrected so the documents say what the
API actually sends:

- Errors: every 4xx/5xx JSON response is ``ErrorEnvelope``. FastAPI declares its own
  ``HTTPValidationError`` for 422, but ``errors.register_exception_handlers`` answers every
  validation error with the envelope (research R8).
- Examples: FastAPI encodes the document with ``exclude_none``, which drops every ``null`` from the
  examples (``"data": null``, ``"error": null`` and nested ones such as ``"logo": null``). Each
  example is put back exactly as the route declared it, so it still validates against its schema
  (Prism serves them as the admin mock; the generated clients parse them).
"""

from __future__ import annotations

import copy
from collections.abc import Callable, Iterator
from typing import Any

from fastapi import FastAPI
from fastapi.routing import APIRoute, iter_route_contexts

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


def restore_example_values(app: FastAPI, document: dict[str, Any]) -> None:
    """Put every JSON example back exactly as its route declared it (nulls included), in place."""
    # FastAPI keeps each included router as one wrapper; iter_route_contexts flattens them with the
    # prefix and responses of their include.
    for route in iter_route_contexts(app.routes):
        if not isinstance(route.original_route, APIRoute):
            continue
        operations = document.get("paths", {}).get(route.path_format, {})
        for method in route.methods or ():
            operation = operations.get(method.lower())
            if operation is None:
                continue
            for status, declared in route.responses.items():
                declared_examples = declared.get("content", {}).get("application/json", {}).get("examples")
                if not declared_examples:
                    continue
                generated = (
                    operation["responses"].get(str(status), {}).get("content", {}).get("application/json", {})
                ).get("examples", {})
                for name, example in declared_examples.items():
                    if name in generated:
                        generated[name]["value"] = copy.deepcopy(example["value"])


def install(app: FastAPI) -> None:
    """Make ``app.openapi()`` (served at /openapi.json and exported by the CLI) the corrected document."""
    generate: Callable[[], dict[str, Any]] = app.openapi

    def openapi() -> dict[str, Any]:
        if app.openapi_schema is None:
            document = generate()
            restore_example_values(app, document)
            app.openapi_schema = contract_document(document)
        return app.openapi_schema

    app.openapi = openapi  # type: ignore[method-assign]
