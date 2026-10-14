#!/usr/bin/env bash
# Runs every automated check: formatting, lint, strict type-check against
# the Roblox API definitions, unit tests and a place-file build.
# Usage: scripts/check.sh            (from the repository root)
#        DEFS=path/to/globalTypes.d.luau scripts/check.sh
set -euo pipefail
cd "$(dirname "$0")/.."

DEFS="${DEFS:-.tools/globalTypes.d.luau}"
if [ ! -f "$DEFS" ]; then
	mkdir -p "$(dirname "$DEFS")"
	echo "Downloading Roblox type definitions..."
	curl -sSfL -o "$DEFS" \
		https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.38.0/scripts/globalTypes.d.luau
fi

status=0
step() { echo; echo "== $1"; }

step "stylua (format check)"
stylua --check src tests || status=1

step "selene (lint)"
selene src || status=1

step "luau-lsp analyze (strict types)"
rojo sourcemap default.project.json --output sourcemap.json
luau-lsp analyze --definitions="$DEFS" --sourcemap=sourcemap.json \
	--base-luaurc=.luaurc --flag:LuauSolverV2=false src || status=1

step "lune unit tests"
lune run tests/run.luau || status=1

step "rojo build"
mkdir -p build
rojo build default.project.json --output build/SlimeGarden.rbxlx || status=1

step "place validation"
lune run tests/validate_place.luau build/SlimeGarden.rbxlx || status=1

echo
if [ "$status" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; fi
exit $status
