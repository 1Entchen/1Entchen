#!/usr/bin/env bash
# Builds the place file and refreshes the committed snapshot in release/.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build release
rojo build default.project.json --output build/SlimeGarden.rbxlx
cp build/SlimeGarden.rbxlx release/SlimeGarden.rbxlx
echo "Built release/SlimeGarden.rbxlx — open it in Roblox Studio."
