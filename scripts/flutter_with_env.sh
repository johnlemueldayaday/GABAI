#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
FLUTTER_BIN="${ROOT_DIR}/flutter/bin/flutter"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "Missing GEMINI_API_KEY. Add it to ${ENV_FILE} or export it in your shell." >&2
  exit 1
fi

exec "${FLUTTER_BIN}" "$@" --dart-define=GEMINI_API_KEY="${GEMINI_API_KEY}"
