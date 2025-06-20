#!/bin/bash

# Tests for scripts/format.sh

# Set up environment
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

source tests/test_framework.sh

# Mock external commands for testing
setup_format_mocks() {
    mock_command "pandoc" 'echo "Mock pandoc: $*" > /tmp/pandoc_calls.log; touch "$4" 2>/dev/null || touch "${@: -1}" 2>/dev/null'
}

cleanup_format_mocks() {
    unmock_command "pandoc"
    rm -f /tmp/pandoc_calls.log
}

test_suite_start "Format Script Tests"

# Test 1: Configuration Loading
test_start "Config file discovery"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    mkdir -p subdir/deep
    cp "$PROJECT_ROOT/tests/fixtures/test_config.yml" ".writer-config.yml"
    
    cd subdir/deep
    
    # Source the format script to access its functions
    source "$PROJECT_ROOT/scripts/format.sh"
    
    config_file=$(find_config "$(pwd)")
    if [[ "$config_file" == "$temp_dir/.writer-config.yml" ]]; then
        test_pass "Found config file in parent directory"
    else
        test_fail "Config discovery failed. Expected $temp_dir/.writer-config.yml, got $config_file"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 2: Configuration parsing
test_start "YAML configuration parsing"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    create_test_config ".writer-config.yml" "docx"
    
    source "$PROJECT_ROOT/scripts/format.sh"
    
    # Test with real yq if available, otherwise skip
    if command_exists yq; then
        format_val=$(get_config ".writer-config.yml" "format" "")
        options_val=$(get_config ".writer-config.yml" "pandoc_options" "")
        
        if [[ "$format_val" == "docx" ]]; then
            test_pass "Parsed format value correctly"
        else
            test_fail "Failed to parse format. Expected 'docx', got '$format_val'"
        fi
        
        if [[ "$options_val" == "" ]] || [[ "$options_val" == "null" ]]; then
            test_pass "Parsed empty pandoc_options correctly"
        else
            test_fail "Failed to parse pandoc_options. Expected empty or null, got '$options_val'"
        fi
    else
        test_skip "yq not available, skipping YAML parsing tests"
        test_skip "yq not available, skipping YAML parsing tests"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 3: Hierarchical configuration
test_start "Hierarchical pandoc options"
if command_exists yq; then
    temp_dir=$(setup_temp_dir)
    (
        cd "$temp_dir"
        # Create hierarchical config
        cat > ".writer-config.yml" << EOF
pandoc_options:
  docx: ""
  html: "--no-highlight --wrap=none"
default_format: docx
EOF
        
        source "$PROJECT_ROOT/scripts/format.sh"
        
        docx_opts=$(get_pandoc_options ".writer-config.yml" "docx")
        html_opts=$(get_pandoc_options ".writer-config.yml" "html")
        
        if [[ "$docx_opts" == "" ]]; then
            test_pass "Empty DOCX options parsed correctly"
        else
            test_fail "DOCX options failed. Expected empty, got '$docx_opts'"
        fi
        
        if [[ "$html_opts" == "--no-highlight --wrap=none" ]]; then
            test_pass "HTML options parsed correctly"
        else
            test_fail "HTML options failed. Expected '--no-highlight --wrap=none', got '$html_opts'"
        fi
    )
    cleanup_temp_dir "$temp_dir"
else
    test_skip "yq not available, skipping hierarchical config tests"
    test_skip "yq not available, skipping hierarchical config tests"
fi

# Test 4: File formatting with mocked pandoc
test_start "Basic file formatting"
temp_dir=$(setup_temp_dir)
setup_format_mocks
(
    cd "$temp_dir"
    cp "$PROJECT_ROOT/tests/fixtures/sample_resume.md" "test.md"
    cp "$PROJECT_ROOT/tests/fixtures/test_config.yml" ".writer-config.yml"
    mkdir -p formatted
    
    # Test the format script
    "$PROJECT_ROOT/scripts/format.sh" "test.md" --format docx >/dev/null 2>&1
    
    if [[ -f "formatted/test.docx" ]]; then
        test_pass "Output file created"
    else
        test_fail "Output file not created"
    fi
    
    if [[ -f "/tmp/pandoc_calls.log" ]]; then
        test_pass "Pandoc was called"
    else
        test_fail "Pandoc was not called"
    fi
)
cleanup_temp_dir "$temp_dir"
cleanup_format_mocks

# Test 5: Batch processing
test_start "Batch file processing"
temp_dir=$(setup_temp_dir)
setup_format_mocks
(
    cd "$temp_dir"
    
    # Create multiple markdown files
    create_test_markdown "file1.md" "# File 1\nContent 1"
    create_test_markdown "file2.md" "# File 2\nContent 2"
    create_test_markdown "file3.md" "# File 3\nContent 3"
    
    create_test_config ".writer-config.yml" "html"
    mkdir -p formatted
    
    # Test batch processing
    "$PROJECT_ROOT/scripts/format.sh" --all >/dev/null 2>&1
    
    files_created=0
    for file in formatted/*.html; do
        if [[ -f "$file" ]]; then
            ((files_created++))
        fi
    done
    
    if [[ $files_created -eq 3 ]]; then
        test_pass "All files processed in batch"
    else
        test_fail "Expected 3 files, got $files_created"
    fi
)
cleanup_temp_dir "$temp_dir"
cleanup_format_mocks

# Test 6: Error handling - missing file
test_start "Error handling for missing file"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    
    output=$(capture_output "$PROJECT_ROOT/scripts/format.sh nonexistent.md 2>&1")
    
    if [[ "$output" == *"File not found"* ]] || [[ "$output" == *"ERROR"* ]]; then
        test_pass "Error reported for missing file"
    else
        test_fail "No error reported for missing file"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 7: Format override
test_start "Format override functionality"
temp_dir=$(setup_temp_dir)
setup_format_mocks
(
    cd "$temp_dir"
    
    create_test_markdown "test.md"
    create_test_config ".writer-config.yml" "docx"  # Default to DOCX
    mkdir -p formatted
    
    # Override to HTML
    "$PROJECT_ROOT/scripts/format.sh" "test.md" --format html >/dev/null 2>&1
    
    if [[ -f "formatted/test.html" ]]; then
        test_pass "Format override worked"
    else
        test_fail "Format override failed"
    fi
)
cleanup_temp_dir "$temp_dir"
cleanup_format_mocks

# Test 8: Directory creation
test_start "Formatted directory creation"
temp_dir=$(setup_temp_dir)
setup_format_mocks
(
    cd "$temp_dir"
    
    create_test_markdown "test.md"
    create_test_config ".writer-config.yml" "docx"
    
    # Don't create formatted directory beforehand
    "$PROJECT_ROOT/scripts/format.sh" "test.md" >/dev/null 2>&1
    
    if [[ -d "formatted" ]]; then
        test_pass "Formatted directory created automatically"
    else
        test_fail "Formatted directory not created"
    fi
)
cleanup_temp_dir "$temp_dir"
cleanup_format_mocks

# Test 9: Help/usage display
test_start "Help message display"
output=$(capture_output "$PROJECT_ROOT/scripts/format.sh --help")

if [[ "$output" == *"Usage:"* ]] && [[ "$output" == *"Examples:"* ]]; then
    test_pass "Help message displayed correctly"
else
    test_fail "Help message incomplete or missing"
fi

# Test 10: Invalid arguments handling
test_start "Invalid arguments handling"
output=$(capture_output "$PROJECT_ROOT/scripts/format.sh --invalid-option 2>&1")

if [[ "$output" == *"Unknown option"* ]] || [[ "$output" == *"ERROR"* ]]; then
    test_pass "Invalid arguments handled correctly"
else
    test_fail "Invalid arguments not handled properly"
fi

test_suite_end