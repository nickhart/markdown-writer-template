#!/bin/bash

# Tests for scripts/job-apply.sh

# Set up environment
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

source tests/test_framework.sh

# Setup mock commands
setup_mocks() {
    mock_command "curl" 'echo "<html><body>Mock job posting</body></html>" > "$4"; exit 0'
    mock_command "pandoc" 'touch "$4" 2>/dev/null || touch "${@: -1}" 2>/dev/null; exit 0'
}

cleanup_mocks() {
    unmock_command "curl"
    unmock_command "pandoc"
}

test_suite_start "Job Apply Script Tests"

# Test 1: Directory name sanitization
test_start "Company and role name sanitization"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    
    # Create necessary directory structure
    mkdir -p templates/resumes applications/active scripts
    cp "$PROJECT_ROOT/templates/resumes/general.md" "templates/resumes/"
    cp "$PROJECT_ROOT/templates/default_cover_letter.md" "templates/"
    cp "$PROJECT_ROOT/scripts/format.sh" "scripts/"
    chmod +x scripts/format.sh
    
    source "$PROJECT_ROOT/scripts/job-apply.sh"
    
    # Test sanitization function
    result1=$(sanitize_dirname "Tech Corp & Associates")
    result2=$(sanitize_dirname "Senior Software Engineer @ Google")
    
    if [[ "$result1" == "tech_corp_associates" ]]; then
        test_pass "Company name sanitized correctly"
    else
        test_fail "Company sanitization failed. Expected 'tech_corp_associates', got '$result1'"
    fi
    
    if [[ "$result2" == "senior_software_engineer_google" ]]; then
        test_pass "Role name sanitized correctly"
    else
        test_fail "Role sanitization failed. Expected 'senior_software_engineer_google', got '$result2'"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 2: Template variable replacement
test_start "Template variable replacement"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    
    # Create test template
    cat > "test_template.md" << 'EOF'
# Cover Letter for {{ROLE_TITLE}} at {{COMPANY_NAME}}

Date: {{APPLICATION_DATE}}
Month/Year: {{MONTH_YEAR}}
EOF
    
    source "$PROJECT_ROOT/scripts/job-apply.sh"
    
    replace_template_variables "test_template.md" "TechCorp" "Senior Engineer" "June 19, 2025" "June 2025"
    
    content=$(cat "test_template.md")
    
    if [[ "$content" == *"TechCorp"* ]] && [[ "$content" == *"Senior Engineer"* ]]; then
        test_pass "Template variables replaced correctly"
    else
        test_fail "Template variable replacement failed"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 3: Application directory creation
test_start "Application directory structure creation"
temp_dir=$(setup_temp_dir)
setup_mocks
(
    cd "$temp_dir"
    
    # Create necessary templates and config
    mkdir -p templates/resumes templates applications/active scripts
    cp "$PROJECT_ROOT/templates/resumes/general.md" "templates/resumes/"
    cp "$PROJECT_ROOT/templates/default_cover_letter.md" "templates/"
    cp "$PROJECT_ROOT/scripts/format.sh" "scripts/"
    chmod +x scripts/format.sh
    
    # Create basic config
    cat > ".writer-config.yml" << EOF
format: docx
auto_format: true
EOF
    
    # Run job application creation
    "$PROJECT_ROOT/scripts/job-apply.sh" -c "TestCorp" -r "Developer" -t "general" >/dev/null 2>&1
    
    # Check if directory was created
    app_dirs=(applications/active/testcorp_developer_*)
    if [[ -d "${app_dirs[0]}" ]]; then
        test_pass "Application directory created"
    else
        test_fail "Application directory not created"
    fi
    
    # Check required files
    app_dir="${app_dirs[0]}"
    files_created=0
    
    [[ -f "$app_dir/resume.md" ]] && ((files_created++))
    [[ -f "$app_dir/cover_letter.md" ]] && ((files_created++))
    [[ -f "$app_dir/.application.yml" ]] && ((files_created++))
    [[ -f "$app_dir/.writer-config.yml" ]] && ((files_created++))
    
    if [[ $files_created -eq 4 ]]; then
        test_pass "All required files created"
    else
        test_fail "Missing files. Created $files_created/4 expected files"
    fi
)
cleanup_temp_dir "$temp_dir"
cleanup_mocks

# Test 4: Template selection
test_start "Resume template selection"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    
    mkdir -p templates/resumes applications/active scripts
    
    # Create multiple templates
    echo "# General Resume" > "templates/resumes/general.md"
    echo "# Mobile Resume" > "templates/resumes/mobile.md"
    echo "# Frontend Resume" > "templates/resumes/frontend.md"
    
    cp "$PROJECT_ROOT/templates/default_cover_letter.md" "templates/"
    cp "$PROJECT_ROOT/scripts/format.sh" "scripts/"
    chmod +x scripts/format.sh
    
    # Create basic config
    cat > ".writer-config.yml" << EOF
format: docx
auto_format: true
EOF
    
    # Test template selection
    "$PROJECT_ROOT/scripts/job-apply.sh" -c "TestCorp" -r "Developer" -t "mobile" >/dev/null 2>&1
    
    app_dirs=(applications/active/testcorp_developer_*)
    if [[ -f "${app_dirs[0]}/resume.md" ]]; then
        content=$(cat "${app_dirs[0]}/resume.md")
        if [[ "$content" == *"Mobile Resume"* ]]; then
            test_pass "Correct template selected"
        else
            test_fail "Wrong template content. Expected 'Mobile Resume', got: $content"
        fi
    else
        test_fail "Resume file not created"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 5: Metadata generation
test_start "Application metadata generation"
temp_dir=$(setup_temp_dir)
setup_mocks
(
    cd "$temp_dir"
    
    mkdir -p templates/resumes applications/active scripts
    cp "$PROJECT_ROOT/templates/resumes/general.md" "templates/resumes/"
    cp "$PROJECT_ROOT/templates/default_cover_letter.md" "templates/"
    cp "$PROJECT_ROOT/scripts/format.sh" "scripts/"
    chmod +x scripts/format.sh
    
    # Create basic config
    cat > ".writer-config.yml" << EOF
format: docx
auto_format: true
EOF
    
    "$PROJECT_ROOT/scripts/job-apply.sh" -c "TestCorp" -r "Senior Dev" -t "general" -u "https://example.com/job" >/dev/null 2>&1
    
    app_dirs=(applications/active/testcorp_senior_dev_*)
    metadata_file="${app_dirs[0]}/.application.yml"
    
    if [[ -f "$metadata_file" ]]; then
        content=$(cat "$metadata_file")
        
        checks=0
        [[ "$content" == *"TestCorp"* ]] && ((checks++))
        [[ "$content" == *"Senior Dev"* ]] && ((checks++))
        [[ "$content" == *"general"* ]] && ((checks++))
        [[ "$content" == *"https://example.com/job"* ]] && ((checks++))
        [[ "$content" == *"active"* ]] && ((checks++))
        
        if [[ $checks -eq 5 ]]; then
            test_pass "Metadata generated correctly"
        else
            test_fail "Metadata incomplete. Found $checks/5 expected fields. Content: $content"
        fi
    else
        test_fail "Metadata file not created"
    fi
)
cleanup_temp_dir "$temp_dir"
cleanup_mocks

# Test 6: Interactive mode (simulated)
test_start "List templates functionality"
output=$(capture_output "$PROJECT_ROOT/scripts/job-apply.sh --list-templates")

if [[ "$output" == *"Available resume templates"* ]]; then
    test_pass "Template listing works"
else
    test_fail "Template listing failed"
fi

# Test 7: Invalid template handling
test_start "Invalid template handling"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    
    mkdir -p templates/resumes applications/active scripts
    cp "$PROJECT_ROOT/templates/resumes/general.md" "templates/resumes/"
    cp "$PROJECT_ROOT/templates/default_cover_letter.md" "templates/"
    cp "$PROJECT_ROOT/scripts/format.sh" "scripts/"
    chmod +x scripts/format.sh
    
    output=$(capture_output "$PROJECT_ROOT/scripts/job-apply.sh -c TestCorp -r Developer -t nonexistent 2>&1")
    
    if [[ "$output" == *"not found"* ]] || [[ "$output" == *"ERROR"* ]]; then
        test_pass "Invalid template handled correctly"
    else
        test_fail "Invalid template not handled properly"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 8: Missing required arguments
test_start "Missing required arguments handling"
output=$(capture_output "$PROJECT_ROOT/scripts/job-apply.sh -c TestCorp 2>&1")

if [[ "$output" == *"required"* ]] || [[ "$output" == *"ERROR"* ]]; then
    test_pass "Missing arguments handled correctly"
else
    test_fail "Missing arguments not handled properly"
fi

# Test 9: Help message
test_start "Help message display"
output=$(capture_output "$PROJECT_ROOT/scripts/job-apply.sh --help")

if [[ "$output" == *"Usage:"* ]] && [[ "$output" == *"Examples:"* ]] && [[ "$output" == *"Features:"* ]]; then
    test_pass "Help message comprehensive"
else
    test_fail "Help message incomplete"
fi

# Test 10: Job posting download (mocked)
test_start "Job posting download"
temp_dir=$(setup_temp_dir)
setup_mocks
(
    cd "$temp_dir"
    
    mkdir -p templates/resumes applications/active scripts
    cp "$PROJECT_ROOT/templates/resumes/general.md" "templates/resumes/"
    cp "$PROJECT_ROOT/templates/default_cover_letter.md" "templates/"
    cp "$PROJECT_ROOT/scripts/format.sh" "scripts/"
    chmod +x scripts/format.sh
    
    "$PROJECT_ROOT/scripts/job-apply.sh" -c "TestCorp" -r "Developer" -t "general" -u "https://example.com/job" >/dev/null 2>&1
    
    app_dirs=(applications/active/testcorp_developer_*)
    
    # Check for job posting file (HTML or PDF)
    if [[ -f "${app_dirs[0]}/job_description.html" ]] || [[ -f "${app_dirs[0]}/job_description.pdf" ]]; then
        test_pass "Job posting downloaded"
    else
        test_fail "Job posting not downloaded"
    fi
)
cleanup_temp_dir "$temp_dir"
cleanup_mocks

test_suite_end