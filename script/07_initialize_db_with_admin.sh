#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "@@@ Running script/hke/init_db_with_admin.rb"

bin/rails runner script/hke/init_db_with_admin.rb