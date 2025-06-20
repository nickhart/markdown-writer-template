#!/bin/bash

# Main test runner for markdown-writer-template

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# Test configuration
UNIT_TESTS_DIR="tests/unit"
INTEGRATION_TESTS_DIR="tests/integration"
TEST_FRAMEWORK="tests/test_framework.sh"

# Test results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    log_info "Checking test dependencies..."
    
    local missing_deps=()
    
    # Check for required commands
    if ! command -v yq >/dev/null 2>&1; then
        missing_deps+=("yq")
    fi
    
    # Check for test framework
    if [[ ! -f "$TEST_FRAMEWORK" ]]; then
        log_error "Test framework not found: $TEST_FRAMEWORK"
        return 1
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warning "Missing optional dependencies: ${missing_deps[*]}"
        log_info "Some tests may be skipped. Run ./setup.sh to install dependencies."
    fi
    
    log_success "Dependencies check completed"
}

# Run a single test suite
run_test_suite() {
    local test_file="$1"
    local suite_name
    suite_name=$(basename "$test_file" .sh)
    
    ((TOTAL_SUITES++))
    
    log_info "Running test suite: $suite_name"
    
    if bash "$test_file"; then
        ((PASSED_SUITES++))
        log_success "Test suite passed: $suite_name"
        return 0
    else
        ((FAILED_SUITES++))
        log_error "Test suite failed: $suite_name"
        return 1
    fi
}

# Run all tests in a directory
run_test_directory() {
    local test_dir="$1"
    local dir_name
    dir_name=$(basename "$test_dir")
    
    if [[ ! -d "$test_dir" ]]; then
        log_warning "Test directory not found: $test_dir"
        return 0
    fi
    
    echo
    echo "========================================"
    echo "  Running $dir_name Tests"
    echo "========================================"
    
    local dir_failed=0
    
    for test_file in "$test_dir"/test_*.sh; do
        if [[ -f "$test_file" ]]; then
            if ! run_test_suite "$test_file"; then
                dir_failed=1
            fi
            echo
        fi
    done
    
    return $dir_failed
}

# Run specific test
run_specific_test() {
    local test_name="$1"
    local test_file=""
    
    # Look for the test in both directories
    if [[ -f "$UNIT_TESTS_DIR/test_$test_name.sh" ]]; then
        test_file="$UNIT_TESTS_DIR/test_$test_name.sh"
    elif [[ -f "$INTEGRATION_TESTS_DIR/test_$test_name.sh" ]]; then
        test_file="$INTEGRATION_TESTS_DIR/test_$test_name.sh"
    elif [[ -f "$test_name" ]]; then
        test_file="$test_name"
    else
        log_error "Test not found: $test_name"
        echo "Available tests:"
        list_available_tests
        return 1
    fi
    
    run_test_suite "$test_file"
}

# List available tests
list_available_tests() {
    echo "Unit Tests:"
    for test_file in "$UNIT_TESTS_DIR"/test_*.sh; do
        if [[ -f "$test_file" ]]; then
            local test_name
            test_name=$(basename "$test_file" .sh | sed 's/^test_//')
            echo "  - $test_name"
        fi
    done
    
    echo
    echo "Integration Tests:"
    for test_file in "$INTEGRATION_TESTS_DIR"/test_*.sh; do
        if [[ -f "$test_file" ]]; then
            local test_name
            test_name=$(basename "$test_file" .sh | sed 's/^test_//')
            echo "  - $test_name"
        fi
    done
}

# Clean up test artifacts
cleanup_test_artifacts() {
    log_info "Cleaning up test artifacts..."
    
    # Remove temporary test files
    rm -rf /tmp/markdown-writer-mocks
    rm -f /tmp/pandoc_calls.log
    
    # Clean up any test directories in project
    find . -name "test_*" -type d -path "*/tmp/*" -exec rm -rf {} + 2>/dev/null || true
    
    log_success "Cleanup completed"
}

# Generate test report
generate_test_report() {
    echo
    echo "========================================"
    echo "  Test Results Summary"
    echo "========================================"
    echo "Total test suites: $TOTAL_SUITES"
    echo -e "${GREEN}Passed: $PASSED_SUITES${NC}"
    
    if [[ $FAILED_SUITES -gt 0 ]]; then
        echo -e "${RED}Failed: $FAILED_SUITES${NC}"
        echo
        echo "Some tests failed. Please review the output above."
        return 1
    else
        echo -e "${GREEN}All test suites passed!${NC}"
        echo
        return 0
    fi
}

# Print usage information
print_usage() {
    cat << EOF
Test Runner for Markdown Writer Template

Usage: $0 [OPTIONS] [TEST_NAME]

Options:
    -h, --help          Show this help message
    -l, --list          List available tests
    -u, --unit          Run only unit tests
    -i, --integration   Run only integration tests
    -c, --clean         Clean up test artifacts and exit
    -v, --verbose       Verbose output (show all test details)

Arguments:
    TEST_NAME           Run specific test (without 'test_' prefix)

Examples:
    $0                  # Run all tests
    $0 --unit          # Run only unit tests
    $0 format          # Run format.sh tests
    $0 --list          # List available tests
    $0 --clean         # Clean up test artifacts

Test Structure:
    tests/unit/         Unit tests for individual scripts
    tests/integration/  Integration tests for complete workflows
    tests/fixtures/     Test data and configuration files
EOF
}

# Main function
main() {
    local run_unit=true
    local run_integration=true
    local specific_test=""
    local list_tests=false
    local clean_only=false
    local verbose=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -l|--list)
                list_tests=true
                shift
                ;;
            -u|--unit)
                run_integration=false
                shift
                ;;
            -i|--integration)
                run_unit=false
                shift
                ;;
            -c|--clean)
                clean_only=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
            *)
                if [[ -z "$specific_test" ]]; then
                    specific_test="$1"
                else
                    log_error "Multiple test names specified"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Handle special modes
    if [[ "$clean_only" == true ]]; then
        cleanup_test_artifacts
        exit 0
    fi
    
    if [[ "$list_tests" == true ]]; then
        list_available_tests
        exit 0
    fi
    
    # Set verbose mode
    if [[ "$verbose" == true ]]; then
        set -x
    fi
    
    echo "========================================"
    echo "  Markdown Writer Template Test Suite"
    echo "========================================"
    echo
    
    # Check dependencies
    check_dependencies
    
    # Handle specific test
    if [[ -n "$specific_test" ]]; then
        run_specific_test "$specific_test"
        cleanup_test_artifacts
        exit $?
    fi
    
    # Run test suites
    local overall_result=0
    
    if [[ "$run_unit" == true ]]; then
        if ! run_test_directory "$UNIT_TESTS_DIR"; then
            overall_result=1
        fi
    fi
    
    if [[ "$run_integration" == true ]]; then
        if ! run_test_directory "$INTEGRATION_TESTS_DIR"; then
            overall_result=1
        fi
    fi
    
    # Generate final report
    if ! generate_test_report; then
        overall_result=1
    fi
    
    # Cleanup
    cleanup_test_artifacts
    
    exit $overall_result
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi