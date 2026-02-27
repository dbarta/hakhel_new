#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MAX_IMPORT_ROWS="${1:-}" bin/rails runner 'load Rails.root.join("script","hke","import_from_csv.rb")'
