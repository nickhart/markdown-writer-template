#!/bin/bash

# Simple test framework for markdown-writer-template
# Usage: source tests/test_framework.sh

set -euo pipefail

# Test framework variables
TEST_COUNT=0
TEST_PASSED=0
TEST_FAILED=0
CURRENT_TEST=""
TEST_OUTPUT=""
ORIGINAL_PATH="$PATH"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test framework functions
test_start() {
    local test_name="$1"
    CURRENT_TEST="$test_name"
    ((TEST_COUNT++))
    echo -e "${BLUE}[TEST]${NC} Starting: $test_name"
}

test_pass() {
    local message="${1:-$CURRENT_TEST}"
    ((TEST_PASSED++))
    echo -e "${GREEN}[PASS]${NC} $message"
}

test_fail() {
    local message="${1:-$CURRENT_TEST}"
    ((TEST_FAILED++))
    echo -e "${RED}[FAIL]${NC} $message"
    if [[ -n "${TEST_OUTPUT:-}" ]]; then
        echo "  Output: $TEST_OUTPUT"
    fi
}

test_skip() {
    local message="${1:-$CURRENT_TEST}"
    echo -e "${YELLOW}[SKIP]${NC} $message"
}

# Assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Expected '$expected', got '$actual'}"
    
    if [[ "$expected" == "$actual" ]]; then
        test_pass "$message"
    else
        test_fail "$message"
    fi
}

assert_not_equals() {
    local not_expected="$1"
    local actual="$2"
    local message="${3:-Expected not '$not_expected', but got '$actual'}"
    
    if [[ "$not_expected" != "$actual" ]]; then
        test_pass "$message"
    else
        test_fail "$message"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Expected '$haystack' to contain '$needle'}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        test_pass "$message"
    else
        test_fail "$message"
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-Expected file '$file' to exist}"
    
    if [[ -f "$file" ]]; then
        test_pass "$message"
    else
        test_fail "$message"
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-Expected file '$file' to not exist}"
    
    if [[ ! -f "$file" ]]; then
        test_pass "$message"
    else
        test_fail "$message"
    fi
}

assert_dir_exists() {
    local dir="$1"
    local message="${2:-Expected directory '$dir' to exist}"
    
    if [[ -d "$dir" ]]; then
        test_pass "$message"
    else
        test_fail "$message"
    fi
}

assert_command_success() {
    local command="$1"
    local message="${2:-Expected command '$command' to succeed}"
    
    if eval "$command" >/dev/null 2>&1; then
        test_pass "$message"
    else
        test_fail "$message"
    fi
}

assert_command_fails() {
    local command="$1"
    local message="${2:-Expected command '$command' to fail}"
    
    if eval "$command" >/dev/null 2>&1; then
        test_fail "$message"
    else
        test_pass "$message"
    fi
}

# Utility functions
setup_temp_dir() {
    local temp_dir
    temp_dir=$(mktemp -d)
    echo "$temp_dir"
}

cleanup_temp_dir() {
    local temp_dir="$1"
    if [[ -n "$temp_dir" ]] && [[ -d "$temp_dir" ]]; then
        rm -rf "$temp_dir"
    fi
}

run_in_temp_dir() {
    local command="$1"
    local temp_dir
    temp_dir=$(setup_temp_dir)
    
    (
        cd "$temp_dir"
        eval "$command"
    )
    
    cleanup_temp_dir "$temp_dir"
}

capture_output() {
    local command="$1"
    TEST_OUTPUT=$(eval "$command" 2>&1 || true)
    echo "$TEST_OUTPUT"
}

# Test suite functions
test_suite_start() {
    local suite_name="$1"
    echo
    echo "========================================"
    echo "  Test Suite: $suite_name"
    echo "========================================"
    TEST_COUNT=0
    TEST_PASSED=0
    TEST_FAILED=0
}

test_suite_end() {
    echo
    echo "========================================"
    echo "  Test Results"
    echo "========================================"
    echo "Total tests: $TEST_COUNT"
    echo -e "${GREEN}Passed: $TEST_PASSED${NC}"
    if [[ $TEST_FAILED -gt 0 ]]; then
        echo -e "${RED}Failed: $TEST_FAILED${NC}"
        echo
        return 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        echo
        return 0
    fi
}

# Command existence check
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Project-specific helpers
source_script() {
    local script_path="$1"
    local project_root="${PROJECT_ROOT:-$(pwd)}"
    
    if [[ -f "$project_root/$script_path" ]]; then
        source "$project_root/$script_path"
    else
        echo "Error: Cannot find script $script_path" >&2
        return 1
    fi
}

create_test_markdown() {
    local file="$1"
    local content="${2:-# Test Document\n\nThis is a test document.}"
    
    printf "$content" > "$file"
}

create_test_config() {
    local file="$1"
    local format="${2:-docx}"
    local options="${3:-}"
    
    cat > "$file" << EOF
format: $format
pandoc_options: "$options"
auto_format: true
EOF
}

# Mock functions for testing
mock_command() {
    local command="$1"
    local mock_script="$2"
    
    # Only mock specific external tools, not basic shell commands
    case "$command" in
        "cp"|"mkdir"|"cat"|"rm"|"mv"|"ls"|"chmod"|"chown"|"ln"|"touch"|"echo"|"printf")
            echo "Warning: Refusing to mock basic shell command: $command" >&2
            return 1
            ;;
    esac
    
    # Create a temporary mock
    local mock_dir="/tmp/markdown-writer-mocks"
    mkdir -p "$mock_dir"
    
    cat > "$mock_dir/$command" << EOF
#!/bin/bash
$mock_script
EOF
    
    chmod +x "$mock_dir/$command"
    export PATH="$mock_dir:$PATH"
}

unmock_command() {
    local command="$1"
    local mock_dir="/tmp/markdown-writer-mocks"
    
    if [[ -f "$mock_dir/$command" ]]; then
        rm -f "$mock_dir/$command"
    fi
}

cleanup_mocks() {
    rm -rf "/tmp/markdown-writer-mocks"
    # Restore original PATH
    export PATH="$ORIGINAL_PATH"
}