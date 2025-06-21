#!/bin/bash

# Simple setup tests focused on wkhtmltopdf

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

source tests/test_framework.sh

test_suite_start "Setup Script Simple Tests"

# Test 1: wkhtmltopdf function existence
test_start "wkhtmltopdf function exists"
if grep -q "install_wkhtmltopdf" setup.sh; then
    test_pass "install_wkhtmltopdf function found in setup.sh"
else
    test_fail "install_wkhtmltopdf function not found"
fi

# Test 2: wkhtmltopdf mentioned in help
test_start "wkhtmltopdf mentioned in help"
output=$(capture_output "$PROJECT_ROOT/setup.sh --help")
if [[ "$output" == *"wkhtmltopdf"* ]]; then
    test_pass "wkhtmltopdf mentioned in help text"
else
    test_fail "wkhtmltopdf not mentioned in help text"
fi

# Test 3: main function calls wkhtmltopdf installation
test_start "main function includes wkhtmltopdf installation"
if grep -A 20 "Install dependencies" setup.sh | grep -q "install_wkhtmltopdf"; then
    test_pass "main function calls install_wkhtmltopdf"
else
    test_fail "main function doesn't call install_wkhtmltopdf"
fi

# Test 4: wkhtmltopdf supports multiple package managers
test_start "wkhtmltopdf supports multiple package managers"
checks=0
grep -A 30 "install_wkhtmltopdf" setup.sh | grep -q "brew" && ((checks++))
grep -A 30 "install_wkhtmltopdf" setup.sh | grep -q "apt" && ((checks++))
grep -A 30 "install_wkhtmltopdf" setup.sh | grep -q "yum" && ((checks++))

if [[ $checks -ge 3 ]]; then
    test_pass "wkhtmltopdf supports multiple package managers ($checks found)"
else
    test_fail "wkhtmltopdf supports insufficient package managers ($checks found)"
fi

# Test 5: wkhtmltopdf handles unknown package manager gracefully
test_start "wkhtmltopdf handles unknown package manager gracefully"
if grep -A 50 "install_wkhtmltopdf" setup.sh | grep -q "optional"; then
    test_pass "wkhtmltopdf installation is marked as optional for unknown systems"
else
    test_fail "wkhtmltopdf doesn't handle unknown systems gracefully"
fi

test_suite_end