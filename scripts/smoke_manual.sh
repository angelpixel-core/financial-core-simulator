#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADMIN_DIR="$ROOT_DIR/apps/admin"
BASE_URL="${BASE_URL:-http://localhost:3000}"

echo "== Smoke manual: Financial Core Simulator =="
echo "BASE_URL=$BASE_URL"

echo
echo "1) Verificando healthcheck del admin..."
curl -fsS "$BASE_URL/up" >/dev/null && echo "OK /up"

echo
echo "2) Ejecutando run demo para poblar artifacts..."
BUNDLE_GEMFILE="$ADMIN_DIR/Gemfile" bundle exec rails runner "$ADMIN_DIR/script/run_demo.rb"

echo
echo "3) Obteniendo ultimo run id..."
RUN_ID="$(BUNDLE_GEMFILE="$ADMIN_DIR/Gemfile" bundle exec rails runner 'puts Run.order(id: :desc).limit(1).pick(:id)' | tail -n 1)"
if [[ -z "$RUN_ID" ]]; then
	echo "ERROR: no se encontro Run" >&2
	exit 1
fi
echo "RUN_ID=$RUN_ID"

echo
echo "4) Verificando endpoints de artifacts..."
curl -fsS "$BASE_URL/runs/$RUN_ID/result" >/dev/null && echo "OK result.json"
curl -fsS "$BASE_URL/runs/$RUN_ID/positions" >/dev/null && echo "OK positions.csv"
curl -fsS "$BASE_URL/runs/$RUN_ID/pnl" >/dev/null && echo "OK pnl.csv"

echo
echo "5) Verificando redirects de compatibilidad..."
curl -fsSI "$BASE_URL/admin/resources/runs/$RUN_ID/result" | rg -n "302|301|Location" || true
curl -fsSI "$BASE_URL/avo/resources/runs/$RUN_ID/result" | rg -n "302|301|Location" || true
curl -fsSI "$BASE_URL/avo" | rg -n "302|301|Location" || true

echo
echo "Smoke manual finalizado."
echo "Abrir UI Runs: $BASE_URL/admin/resources/runs/$RUN_ID"
echo "Abrir UI Overview: $BASE_URL/admin/overview"
