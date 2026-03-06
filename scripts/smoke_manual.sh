#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADMIN_DIR="$ROOT_DIR/apps/admin"
BASE_URL="${BASE_URL:-http://localhost:3000}"
ADMIN_UI_TOKEN="${ADMIN_UI_TOKEN:-}"
ADMIN_ARTIFACTS_TOKEN="${ADMIN_ARTIFACTS_TOKEN:-}"

if [[ -z "$ADMIN_UI_TOKEN" ]]; then
	echo "ERROR: ADMIN_UI_TOKEN is required for protected /dashboard/* smoke checks" >&2
	exit 1
fi

if [[ -z "$ADMIN_ARTIFACTS_TOKEN" ]]; then
	echo "ERROR: ADMIN_ARTIFACTS_TOKEN is required for artifact mechanism checks" >&2
	exit 1
fi

echo "== Smoke manual: Financial Core Simulator =="
echo "BASE_URL=$BASE_URL"

echo
echo "1) Verificando healthcheck del admin..."
curl -fsS "$BASE_URL/up" >/dev/null && echo "OK /up"

echo
echo "1.1) Verificando guard de auth en dashboard/admin (sin auth debe rechazar)..."
DASHBOARD_GUARD_STATUS="$(curl -sS -o /dev/null -w "%{http_code}" "$BASE_URL/dashboard/overview")"
ADMIN_GUARD_STATUS="$(curl -sS -o /dev/null -w "%{http_code}" "$BASE_URL/admin/overview")"
if [[ "$DASHBOARD_GUARD_STATUS" != "401" && "$DASHBOARD_GUARD_STATUS" != "403" ]]; then
	echo "ERROR: expected 401/403 for unauthenticated dashboard overview, got $DASHBOARD_GUARD_STATUS" >&2
	exit 1
fi
if [[ "$ADMIN_GUARD_STATUS" != "401" && "$ADMIN_GUARD_STATUS" != "403" ]]; then
	echo "ERROR: expected 401/403 for unauthenticated admin overview, got $ADMIN_GUARD_STATUS" >&2
	exit 1
fi
echo "OK unauth dashboard guard ($DASHBOARD_GUARD_STATUS)"
echo "OK unauth admin guard ($ADMIN_GUARD_STATUS)"

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
echo "4) Verificando endpoints protegidos de dashboard..."
curl -fsS -H "Authorization: Bearer $ADMIN_UI_TOKEN" "$BASE_URL/dashboard/overview" >/dev/null && echo "OK dashboard overview"
curl -fsS -H "Authorization: Bearer $ADMIN_UI_TOKEN" "$BASE_URL/dashboard/top-accounts" >/dev/null && echo "OK dashboard top-accounts"
curl -fsS -H "Authorization: Bearer $ADMIN_UI_TOKEN" "$BASE_URL/dashboard/ingestion-validation-errors" >/dev/null && echo "OK dashboard ingestion-validation-errors"

echo
echo "4.1) Verificando /admin/* via identidad de operador..."
curl -fsS -H "X-Admin-User: ops" -H "X-Admin-Role: operator" "$BASE_URL/admin/overview" >/dev/null && echo "OK admin overview"
curl -fsS -H "X-Admin-User: ops" -H "X-Admin-Role: operator" "$BASE_URL/admin/overview/top-accounts" >/dev/null && echo "OK admin top-accounts"

echo
echo "5) Verificando endpoints de artifacts..."
ARTIFACT_WRONG_MECH_STATUS="$(curl -sS -o /dev/null -w "%{http_code}" -H "X-Admin-Token: $ADMIN_UI_TOKEN" "$BASE_URL/runs/$RUN_ID/result")"
if [[ "$ARTIFACT_WRONG_MECH_STATUS" != "401" && "$ARTIFACT_WRONG_MECH_STATUS" != "403" ]]; then
	echo "ERROR: expected 401/403 for artifact access with unsupported X-Admin-Token, got $ARTIFACT_WRONG_MECH_STATUS" >&2
	exit 1
fi
echo "OK artifact rejects unsupported X-Admin-Token ($ARTIFACT_WRONG_MECH_STATUS)"

curl -fsS -H "Authorization: Bearer $ADMIN_ARTIFACTS_TOKEN" "$BASE_URL/runs/$RUN_ID/result" >/dev/null && echo "OK result.json via artifact token"
curl -fsS -H "Authorization: Bearer $ADMIN_ARTIFACTS_TOKEN" "$BASE_URL/runs/$RUN_ID/positions" >/dev/null && echo "OK positions.csv via artifact token"
curl -fsS -H "Authorization: Bearer $ADMIN_ARTIFACTS_TOKEN" "$BASE_URL/runs/$RUN_ID/pnl" >/dev/null && echo "OK pnl.csv via artifact token"

echo
echo "6) Verificando redirects de compatibilidad..."
curl -fsSI "$BASE_URL/admin/resources/runs/$RUN_ID/result" | rg -n "302|301|Location" || true
curl -fsSI "$BASE_URL/avo/resources/runs/$RUN_ID/result" | rg -n "302|301|Location" || true
curl -fsSI "$BASE_URL/avo" | rg -n "302|301|Location" || true

echo
echo "Smoke manual finalizado."
echo "Abrir UI Runs: $BASE_URL/admin/resources/runs/$RUN_ID"
echo "Abrir UI Overview: $BASE_URL/admin/overview"
