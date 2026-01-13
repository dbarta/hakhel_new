#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bin/rails runner 'load Rails.root.join("script","hke","import_from_csv.rb")' "$@"
