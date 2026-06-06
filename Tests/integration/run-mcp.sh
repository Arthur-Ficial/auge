#!/bin/bash
# Integration tests for auge MCP stdio server
# Run: bash Tests/integration/run-mcp.sh .build/debug/auge-mcp

set -euo pipefail

SERVER="${1:-.build/debug/auge-mcp}"
DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_IMG="$DIR/test_text.png"
PASSED=0
FAILED=0

pass() { echo "  OK  $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL $1: $2"; FAILED=$((FAILED + 1)); }

run_mcp() {
    printf '%s\n' \
      '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"integration-test","version":"1.0.0"}}}' \
      '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
      "$1" | "$SERVER"
}

echo ""
echo "MCP Integration Tests"
echo "================================="

echo ""
echo "Lifecycle"

out=$(printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"integration-test","version":"1.0.0"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' | "$SERVER")
echo "$out" | grep -q '"protocolVersion":"2025-03-26"' && pass "initialize negotiates protocol" || fail "initialize" "expected negotiated protocol version"

echo ""
echo "Tool discovery"

out=$(run_mcp '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}')
echo "$out" | grep -q '"name":"auge_ocr"' && pass "tools/list exposes OCR tool" || fail "tools/list" "expected auge_ocr"
echo "$out" | grep -q '"name":"auge_release"' && pass "tools/list exposes release tool" || fail "tools/list" "expected auge_release"

echo ""
echo "Tool calls"

out=$(run_mcp "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"auge_ocr\",\"arguments\":{\"path\":\"$TEST_IMG\",\"output\":\"json\",\"compact\":true}}}")
echo "$out" | grep -q '"isError":false' && pass "auge_ocr succeeds" || fail "auge_ocr" "expected non-error result"
echo "$out" | grep -q '"mode":"ocr"' && pass "auge_ocr returns OCR mode" || fail "auge_ocr" "expected OCR structured content"

out=$(run_mcp '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"auge_release","arguments":{}}}')
echo "$out" | grep -q '"framework":"Vision' && pass "auge_release returns framework metadata" || fail "auge_release" "expected release metadata"

echo ""
echo "================================="
if [ $FAILED -eq 0 ]; then
    echo "All $PASSED MCP integration tests passed"
else
    echo "$FAILED failed, $PASSED passed"
    exit 1
fi
