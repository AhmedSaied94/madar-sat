#!/usr/bin/env python3
"""Print `sw.js` as one classic script, with `sw_core.mjs` inlined (D4 M-R1-1).

`flutter_bootstrap.js` registers `/sw.js` as a classic service worker: Firefox has no module
service workers to rely on, and a classic worker that starts with `import` throws a
SyntaxError, so it never installs. `web/sw.js` keeps its `import` so `node --test app/test_web/`
can test the core as a module; `tool/stage_web_release.sh` runs this on the staged copy.

Usage: python3 tool/classic_sw.py <sw.js> <sw_core.mjs>   (the classic script on stdout)

A `sw.js` without the import is already classic and is printed unchanged. Anything left that
a classic script cannot parse (an `import` or `export` statement) is an error.
"""

import re
import sys

IMPORT = re.compile(r"^import \{([^}]*)\} from '\./sw_core\.mjs(?:\?[^']*)?';\n", re.M)
EXPORT = re.compile(r"^export (?=(?:async\s+)?function\b|const\b|let\b|class\b)", re.M)
MODULE_SYNTAX = re.compile(r"^\s*(?:import|export)\b", re.M)


def classic(worker: str, core: str) -> str:
    found = IMPORT.search(worker)
    if found is None:
        if MODULE_SYNTAX.search(worker):
            raise ValueError("sw.js has an import or export this script does not know how to inline")
        return worker
    names = [name.strip() for name in found.group(1).split(",") if name.strip()]
    if not names or not all(re.fullmatch(r"[A-Za-z_$][\w$]*", name) for name in names):
        raise ValueError(f"sw.js imports names this script cannot read: {found.group(1)!r}")
    body = EXPORT.sub("", core)
    rest = worker[: found.start()] + worker[found.end() :]
    for label, text in (("sw_core.mjs", body), ("sw.js", rest)):
        if MODULE_SYNTAX.search(text):
            raise ValueError(f"{label} still has an import or export after inlining")
    listed = ", ".join(names)
    # An IIFE, so the core's private names (SHELL_FILES, RELEASE_PATH, ...) can't collide with
    # the worker's own top-level names.
    block = (
        "// sw_core.mjs, inlined by tool/classic_sw.py: a classic service worker cannot `import`.\n"
        f"const {{ {listed} }} = (() => {{\n{body.rstrip()}\n\nreturn {{ {listed} }};\n}})();\n"
    )
    return rest[: found.start()] + block + rest[found.start() :]


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    with open(sys.argv[1], encoding="utf-8") as handle:
        worker = handle.read()
    with open(sys.argv[2], encoding="utf-8") as handle:
        core = handle.read()
    try:
        sys.stdout.write(classic(worker, core))
    except ValueError as error:
        print(f"classic_sw.py: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
