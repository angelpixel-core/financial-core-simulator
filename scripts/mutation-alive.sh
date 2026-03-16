#!/usr/bin/env bash
set -e

LOG=${1:-tmp/mutant/run.log}

grep -E '^evil:.*:[^:]+:[0-9]+:[a-f0-9]+$' "$LOG" |
  sed 's/:[^:]*$//' |
  sort -u
