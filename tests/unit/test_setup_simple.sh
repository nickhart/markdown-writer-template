#!/bin/bash

# Simple setup tests focused on basic functionality

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

source tests/test_framework.sh

test_suite_start "Setup Script Simple Tests"

# Test 1: Chrome detection function existence
test_start "Chrome detection function exists"
if grep -q "detect_chrome" setup.sh; then
    test_pass "detect_chrome function found in setup.sh"
else
    test_fail "detect_chrome function not found"
fi

# Test 2: Chrome mentioned in help
test_start "Chrome mentioned in help"
output=$(capture_output "$PROJECT_ROOT/setup.sh --help")
if [[ "$output" == *"Chrome"* ]]; then
    test_pass "Chrome mentioned in help text"
else
    test_fail "Chrome not mentioned in help text"
fi

# Test 3: Chrome path validation function exists
test_start "Chrome path validation function exists"
if grep -q "validate_chrome_path" setup.sh; then
    test_pass "validate_chrome_path function found in setup.sh"
else
    test_fail "validate_chrome_path function not found"
fi

# Test 4: Chrome detection supports multiple platforms
test_start "Chrome detection supports multiple platforms"
checks=0
grep -A 50 "detect_chrome" setup.sh | grep -q "macos" && ((checks++))
grep -A 50 "detect_chrome" setup.sh | grep -q "linux" && ((checks++))
grep -A 50 "detect_chrome" setup.sh | grep -q "windows" && ((checks++))

if [[ $checks -ge 3 ]]; then
    test_pass "Chrome detection supports multiple platforms ($checks found)"
else
    test_fail "Chrome detection supports insufficient platforms ($checks found)"
fi

# Test 5: Chrome prompt function handles graceful fallback
test_start "Chrome prompt function handles graceful fallback"
if grep -A 50 "prompt_chrome_path" setup.sh | grep -q "Skip Chrome setup"; then
    test_pass "Chrome setup can be skipped gracefully"
else
    test_fail "Chrome setup doesn't handle graceful fallback"
fi

# Test 6: LaTeX detection function exists
test_start "LaTeX detection function exists"
if grep -q "detect_latex" setup.sh; then
    test_pass "detect_latex function found in setup.sh"
else
    test_fail "detect_latex function not found"
fi

# Test 7: LaTeX validation function exists
test_start "LaTeX validation function exists"
if grep -q "validate_latex_for_pdf" setup.sh; then
    test_pass "validate_latex_for_pdf function found in setup.sh"
else
    test_fail "validate_latex_for_pdf function not found"
fi

# Test 8: LaTeX prompt function handles graceful fallback
test_start "LaTeX prompt function handles graceful fallback"
if grep -A 50 "prompt_latex_installation" setup.sh | grep -q "Skip LaTeX setup"; then
    test_pass "LaTeX setup can be skipped gracefully"
else
    test_fail "LaTeX setup doesn't handle graceful fallback"
fi

test_suite_end