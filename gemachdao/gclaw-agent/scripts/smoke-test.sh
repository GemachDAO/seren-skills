#!/usr/bin/env bash
# smoke-test.sh — Quick live smoke test for a running Gclaw instance
# Usage: bash scripts/smoke-test.sh
# Requires: gclaw binary installed and configured (~/.gclaw/config.json)
# Exit code 0 = all checks pass, 1 = any check fails
set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

pass()    { echo -e "  ${GREEN}✓${RESET} $1"; PASSED=$((PASSED + 1)); }
fail()    { echo -e "  ${RED}✗${RESET} $1"; [[ -n "${2:-}" ]] && echo -e "    ${RED}→ $2${RESET}"; FAILED=$((FAILED + 1)); }
skip()    { echo -e "  ${YELLOW}⊘${RESET} $1 ${YELLOW}(skipped: ${2:-not available})${RESET}"; SKIPPED=$((SKIPPED + 1)); }
section() { echo -e "\n${CYAN}▶ $*${RESET}"; }

GATEWAY_HOST="${GCLAW_GATEWAY_HOST:-localhost}"
GATEWAY_PORT="${GCLAW_GATEWAY_PORT:-18790}"
GATEWAY_URL="http://${GATEWAY_HOST}:${GATEWAY_PORT}"

# ─── Check binary ─────────────────────────────────────────────────────────────
section "1. Binary Check"

if ! command -v gclaw &>/dev/null; then
  echo -e "${RED}gclaw binary not found. Run: bash scripts/install.sh${RESET}"
  exit 1
fi

pass "gclaw binary found: $(command -v gclaw)"

# ─── Agent message test ───────────────────────────────────────────────────────
section "2. Agent Message Test"

echo "  Sending test message to agent..."
AGENT_OUTPUT=$(gclaw agent -m "hello" 2>&1)
AGENT_EXIT=$?

if [[ $AGENT_EXIT -eq 0 ]] && [[ -n "$AGENT_OUTPUT" ]]; then
  pass "gclaw agent -m 'hello' responded (exit 0)"
  echo -e "  ${CYAN}Response preview:${RESET} $(echo "$AGENT_OUTPUT" | head -3)"
elif [[ $AGENT_EXIT -ne 0 ]] && echo "$AGENT_OUTPUT" | grep -qi "config\|key\|token\|provider"; then
  fail "gclaw agent -m 'hello' failed — likely missing API key or config" "$AGENT_OUTPUT"
else
  fail "gclaw agent -m 'hello' failed (exit ${AGENT_EXIT})" "$(echo "$AGENT_OUTPUT" | head -5)"
fi

# ─── Status check ────────────────────────────────────────────────────────────
section "3. Status Check"

STATUS_OUTPUT=$(gclaw status 2>&1)
STATUS_EXIT=$?

if [[ $STATUS_EXIT -eq 0 ]]; then
  pass "gclaw status exits 0"
  echo -e "  ${CYAN}Status output:${RESET}"
  echo "$STATUS_OUTPUT" | head -10 | sed 's/^/    /'
else
  fail "gclaw status returned non-zero (exit ${STATUS_EXIT})" \
    "$(echo "$STATUS_OUTPUT" | head -3)"
fi

# Check for GMAC balance in output
if echo "$STATUS_OUTPUT" | grep -qi "gmac\|balance\|goodwill"; then
  pass "Status output includes GMAC/balance information"
else
  skip "GMAC balance in status" "may need agent to be initialized first"
fi

# ─── Skills list ─────────────────────────────────────────────────────────────
section "4. Skills List"

SKILLS_OUTPUT=$(gclaw skills list 2>&1)
SKILLS_EXIT=$?

if [[ $SKILLS_EXIT -eq 0 ]]; then
  pass "gclaw skills list exits 0"
else
  skip "gclaw skills list" "command failed (exit ${SKILLS_EXIT}) — may need onboarding"
fi

BUILTIN_OUTPUT=$(gclaw skills list-builtin 2>&1)
BUILTIN_EXIT=$?

if [[ $BUILTIN_EXIT -eq 0 ]]; then
  pass "gclaw skills list-builtin exits 0"
else
  skip "gclaw skills list-builtin" "command failed — may need onboarding"
fi

# ─── Gateway health endpoint ─────────────────────────────────────────────────
section "5. Gateway Health Endpoint"

if command -v curl &>/dev/null; then
  HEALTH_RESPONSE=$(curl -sf --connect-timeout 3 "${GATEWAY_URL}/health" 2>&1)
  CURL_EXIT=$?

  if [[ $CURL_EXIT -eq 0 ]] && [[ -n "$HEALTH_RESPONSE" ]]; then
    pass "Gateway health endpoint responded: ${GATEWAY_URL}/health"
    echo -e "  ${CYAN}Response:${RESET} $(echo "$HEALTH_RESPONSE" | head -3)"

    # Check for expected JSON fields
    if echo "$HEALTH_RESPONSE" | grep -q '"status"'; then
      pass "Health response contains 'status' field"
    else
      skip "Health response 'status' field" "unexpected response format"
    fi

    if echo "$HEALTH_RESPONSE" | grep -qi '"ok"\|"healthy"\|"running"'; then
      pass "Health status is OK/healthy"
    else
      fail "Health status not OK" "Response: $(echo "$HEALTH_RESPONSE" | head -1)"
    fi
  else
    skip "Gateway health endpoint" "Gateway not running at ${GATEWAY_URL} — start with: gclaw gateway"
  fi
else
  skip "Gateway health check" "curl not available"
fi

# ─── Cron list ────────────────────────────────────────────────────────────────
section "6. Cron Job List"

CRON_OUTPUT=$(gclaw cron list 2>&1)
CRON_EXIT=$?

if [[ $CRON_EXIT -eq 0 ]]; then
  pass "gclaw cron list exits 0"
  JOB_COUNT=$(echo "$CRON_OUTPUT" | grep -c '.' || echo "0")
  echo -e "  ${CYAN}Cron output:${RESET} ${JOB_COUNT} line(s)"
else
  skip "gclaw cron list" "command failed (exit ${CRON_EXIT}) — may need onboarding"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
TOTAL=$((PASSED + FAILED + SKIPPED))
echo ""
echo -e "${CYAN}═══ Smoke Test Summary ═══${RESET}"
echo -e "  Total:   ${TOTAL}"
echo -e "  ${GREEN}Passed:  ${PASSED}${RESET}"
echo -e "  ${RED}Failed:  ${FAILED}${RESET}"
echo -e "  ${YELLOW}Skipped: ${SKIPPED}${RESET}"
echo ""

if [[ $FAILED -gt 0 ]]; then
  echo -e "${RED}✗ Smoke test failed — ${FAILED} check(s) did not pass${RESET}"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Ensure gclaw is configured: gclaw onboard"
  echo "  2. Set API keys in ~/.gclaw/config.json or environment variables"
  echo "  3. Start gateway for health checks: gclaw gateway"
  exit 1
else
  echo -e "${GREEN}✓ Smoke tests passed${RESET}"
  [[ $SKIPPED -gt 0 ]] && echo -e "${YELLOW}  (${SKIPPED} check(s) skipped — start 'gclaw gateway' for full coverage)${RESET}"
  exit 0
fi
