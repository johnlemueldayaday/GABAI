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

AI_PROVIDER="${AI_PROVIDER:-local}"
LOCAL_AI_BASE_URL="${LOCAL_AI_BASE_URL:-http://localhost:11434/v1}"
LOCAL_AI_MODEL="${LOCAL_AI_MODEL:-llama3.2:3b}"
LOCAL_AI_API_KEY="${LOCAL_AI_API_KEY:-local-ai}"

exec "${FLUTTER_BIN}" "$@" \
  --dart-define=AI_PROVIDER="${AI_PROVIDER}" \
  --dart-define=LOCAL_AI_BASE_URL="${LOCAL_AI_BASE_URL}" \
  --dart-define=LOCAL_AI_MODEL="${LOCAL_AI_MODEL}" \
  --dart-define=LOCAL_AI_API_KEY="${LOCAL_AI_API_KEY}" \
  --dart-define=GEMINI_API_KEY="${GEMINI_API_KEY:-}"
