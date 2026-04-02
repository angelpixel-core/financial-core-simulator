#!/usr/bin/env bash
set -euo pipefail

mkdir -p docs

bundle exec erd \
  --filename docs/erd \
  --filetype png
