#!/bin/bash
# Integration tests for auge CLI
# Run: bash Tests/integration/run.sh

set -euo pipefail

AUGE="${1:-auge}"
DIR="$(cd "$(dirname "$0")" && pwd)"
PASSED=0
FAILED=0

pass() { echo "  OK  $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL $1: $2"; FAILED=$((FAILED + 1)); }

echo ""
echo "Integration Tests"
echo "================================="

# --- Version ---
echo ""
echo "CLI basics"

out=$($AUGE --version 2>&1)
echo "$out" | grep -q "auge v" && pass "--version" || fail "--version" "expected 'auge v'"

out=$($AUGE --help 2>&1)
echo "$out" | grep -q "USAGE:" && pass "--help" || fail "--help" "expected 'USAGE:'"

out=$($AUGE --release 2>&1)
echo "$out" | grep -q "VERSION:" && pass "--release" || fail "--release" "expected 'VERSION:'"

# --- Exit codes ---
echo ""
echo "Exit codes"

$AUGE --ocr /nonexistent.png >/dev/null 2>&1 && fail "nonexistent file" "should exit 1" || {
    [ $? -eq 1 ] && pass "nonexistent file -> exit 1" || fail "nonexistent file" "expected exit 1, got $?"
}

$AUGE --bad-flag >/dev/null 2>&1 && fail "bad flag" "should exit 2" || {
    [ $? -eq 2 ] && pass "bad flag -> exit 2" || fail "bad flag" "expected exit 2, got $?"
}

$AUGE >/dev/null 2>&1 && fail "no args" "should exit 2" || {
    [ $? -eq 2 ] && pass "no args -> exit 2" || fail "no args" "expected exit 2, got $?"
}

# --- OCR ---
echo ""
echo "OCR"

TEST_IMG="$DIR/test_text.png"
if [ -f "$TEST_IMG" ]; then
    out=$($AUGE --ocr "$TEST_IMG" 2>&1)
    echo "$out" | grep -qi "hello" && pass "--ocr detects text" || fail "--ocr" "expected 'Hello' in output"

    out=$($AUGE --ocr "$TEST_IMG" -o json 2>&1)
    echo "$out" | grep -q '"mode" : "ocr"' && pass "--ocr json mode field" || fail "--ocr json" "expected mode:ocr"
    echo "$out" | grep -q '"on_device" : true' && pass "--ocr json on_device field" || fail "--ocr json" "expected on_device:true"
else
    fail "test image" "missing $TEST_IMG"
fi

# --- Classification ---
echo ""
echo "Classification"

if [ -f "$TEST_IMG" ]; then
    out=$($AUGE --classify "$TEST_IMG" 2>&1)
    echo "$out" | grep -q "%" && pass "--classify shows percentages" || fail "--classify" "expected percentages"

    out=$($AUGE --classify "$TEST_IMG" --top 2 2>&1)
    lines=$(echo "$out" | wc -l | tr -d ' ')
    [ "$lines" -le 2 ] && pass "--classify --top 2 limits output" || fail "--classify --top" "expected <=2 lines, got $lines"

    out=$($AUGE --classify "$TEST_IMG" -o json 2>&1)
    echo "$out" | grep -q '"mode" : "classify"' && pass "--classify json" || fail "--classify json" "expected mode:classify"
else
    fail "test image" "missing $TEST_IMG"
fi

# --- Face detection ---
echo ""
echo "Face detection"

if [ -f "$TEST_IMG" ]; then
    out=$($AUGE --faces "$TEST_IMG" 2>&1)
    echo "$out" | grep -q "faces detected" && pass "--faces output" || fail "--faces" "expected 'faces detected'"

    out=$($AUGE --faces "$TEST_IMG" -o json 2>&1)
    echo "$out" | grep -q '"count"' && pass "--faces json has count" || fail "--faces json" "expected count field"
else
    fail "test image" "missing $TEST_IMG"
fi

# --- Barcode detection ---
echo ""
echo "Barcode detection"

if [ -f "$TEST_IMG" ]; then
    $AUGE --barcode "$TEST_IMG" -q 2>/dev/null
    [ $? -eq 0 ] && pass "--barcode exits 0 (no barcodes)" || fail "--barcode" "expected exit 0"
fi

# --- Piping ---
echo ""
echo "Piping"

if [ -f "$TEST_IMG" ]; then
    out=$(echo "$TEST_IMG" | $AUGE --ocr 2>&1)
    echo "$out" | grep -qi "hello" && pass "stdin pipe" || fail "stdin pipe" "expected text output"
fi

# --- Quiet mode ---
echo ""
echo "Quiet mode"

if [ -f "$TEST_IMG" ]; then
    out=$($AUGE --barcode "$TEST_IMG" -q 2>&1)
    [ -z "$out" ] && pass "--quiet suppresses messages" || fail "--quiet" "expected no output"
fi

# --- Summary ---
echo ""
echo "================================="
if [ $FAILED -eq 0 ]; then
    echo "All $PASSED integration tests passed"
else
    echo "$FAILED failed, $PASSED passed"
    exit 1
fi
