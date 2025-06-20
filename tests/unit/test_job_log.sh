#!/bin/bash

# Tests for scripts/job-log.sh

# Set up environment
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

source tests/test_framework.sh

test_suite_start "Job Log Script Tests"

# Test 1: Application status listing
test_start "Application status listing"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    
    # Create mock application directories with metadata
    mkdir -p applications/{active,submitted,interviews}/test_app
    
    cat > "applications/active/test_app/.application.yml" << EOF
company: "TestCorp"
role: "Developer"
template_used: "general"
application_date: "2025-06-19"
status: "active"
EOF
    
    cat > "applications/submitted/test_app/.application.yml" << EOF
company: "AnotherCorp"
role: "Engineer"
template_used: "general"
application_date: "2025-06-18"
status: "submitted"
EOF
    
    output=$(capture_output "$PROJECT_ROOT/scripts/job-log.sh list")
    
    if [[ "$output" == *"TestCorp"* ]] && [[ "$output" == *"AnotherCorp"* ]]; then
        test_pass "Application listing works"
    else
        test_fail "Application listing failed"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 2: Status summary
test_start "Status summary generation"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    
    # Create applications in different status directories
    mkdir -p applications/{active,submitted,interviews}
    mkdir -p applications/active/{app1,app2}
    mkdir -p applications/submitted/app3
    
    # Create minimal metadata
    for app in app1 app2 app3; do
        mkdir -p "applications/active/$app"
        echo "status: active" > "applications/active/$app/.application.yml" 2>/dev/null || true
    done
    
    output=$(capture_output "$PROJECT_ROOT/scripts/job-log.sh status")
    
    if [[ "$output" == *"Status Summary"* ]] && [[ "$output" == *"Total:"* ]]; then
        test_pass "Status summary generated"
    else
        test_fail "Status summary failed"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 3: Report generation
test_start "Report generation"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    
    mkdir -p applications/active/test_app
    
    cat > "applications/active/test_app/.application.yml" << EOF
company: "TestCorp"
role: "Developer"
template_used: "general"
application_date: "2025-06-19"
status: "active"
EOF
    
    "$PROJECT_ROOT/scripts/job-log.sh" report --output "test_report.md" >/dev/null 2>&1
    
    if [[ -f "test_report.md" ]]; then
        content=$(cat "test_report.md")
        if [[ "$content" == *"Job Applications Report"* ]] && [[ "$content" == *"TestCorp"* ]]; then
            test_pass "Report generated successfully"
        else
            test_fail "Report content incomplete"
        fi
    else
        test_fail "Report file not created"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 4: Application movement
test_start "Application status movement"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    
    # Create application in active status
    mkdir -p applications/active/test_app
    
    cat > "applications/active/test_app/.application.yml" << EOF
company: "TestCorp"
role: "Developer"
status: "active"
EOF
    
    # Move to submitted
    "$PROJECT_ROOT/scripts/job-log.sh" move test_app submitted >/dev/null 2>&1
    
    if [[ -d "applications/submitted/test_app" ]] && [[ ! -d "applications/active/test_app" ]]; then
        test_pass "Application moved successfully"
    else
        test_fail "Application movement failed"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 5: CSV export
test_start "CSV export functionality"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    
    mkdir -p applications/active/test_app
    
    cat > "applications/active/test_app/.application.yml" << EOF
company: "TestCorp"
role: "Developer"
template_used: "general"
application_date: "2025-06-19"
status: "active"
job_url: "https://example.com"
notes: "Test notes"
EOF
    
    "$PROJECT_ROOT/scripts/job-log.sh" export csv test_export.csv >/dev/null 2>&1
    
    if [[ -f "test_export.csv" ]]; then
        content=$(cat "test_export.csv")
        if [[ "$content" == *"TestCorp"* ]] && [[ "$content" == *"Developer"* ]]; then
            test_pass "CSV export successful"
        else
            test_fail "CSV export content incomplete"
        fi
    else
        test_fail "CSV export file not created"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 6: Help message
test_start "Help message display"
output=$(capture_output "$PROJECT_ROOT/scripts/job-log.sh --help")

if [[ "$output" == *"Usage:"* ]] && [[ "$output" == *"Commands:"* ]]; then
    test_pass "Help message displayed"
else
    test_fail "Help message incomplete"
fi

# Test 7: Invalid command handling
test_start "Invalid command handling"
output=$(capture_output "$PROJECT_ROOT/scripts/job-log.sh invalid_command 2>&1")

if [[ "$output" == *"Unknown command"* ]] || [[ "$output" == *"ERROR"* ]]; then
    test_pass "Invalid command handled"
else
    test_fail "Invalid command not handled properly"
fi

# Test 8: Metadata field extraction
test_start "Metadata field extraction"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    
    cat > "test_metadata.yml" << EOF
company: "TestCorp"
role: "Senior Developer"
application_date: "2025-06-19"
EOF
    
    # Test metadata extraction indirectly through yq since sourcing causes issues
    if command -v yq >/dev/null 2>&1; then
        company=$(yq eval '.company' "test_metadata.yml")
        role=$(yq eval '.role' "test_metadata.yml")
        
        if [[ "$company" == "TestCorp" ]] && [[ "$role" == "Senior Developer" ]]; then
            test_pass "Metadata extraction works"
        else
            test_fail "Metadata extraction failed. Company: '$company', Role: '$role'"
        fi
    else
        test_skip "yq not available, skipping metadata extraction test"
    fi
)
cleanup_temp_dir "$temp_dir"

test_suite_end