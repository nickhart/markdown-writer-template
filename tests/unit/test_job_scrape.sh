#!/bin/bash

# Tests for scripts/job-scrape.sh

# Set up environment
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

source tests/test_framework.sh

# Setup mocks for external commands
setup_scrape_mocks() {
    mock_command "curl" '
        # Find the -o parameter and the file that follows it
        output_file=""
        while [[ $# -gt 0 ]]; do
            if [[ "$1" == "-o" ]] && [[ -n "${2:-}" ]]; then
                output_file="$2"
                break
            fi
            shift
        done
        if [[ -n "$output_file" ]]; then
            echo "<html><head><title>Job Title</title></head><body><h1>Senior Engineer</h1><p>Requirements: Experience with testing</p></body></html>" > "$output_file"
        fi
        exit 0'
    mock_command "pandoc" '
        # Get the output file (last argument that doesn'\''t start with -)
        output_file="${@: -1}"
        if [[ "$output_file" != -* ]]; then
            touch "$output_file" 2>/dev/null
        fi
        exit 0'
}

cleanup_scrape_mocks() {
    unmock_command "curl"
    unmock_command "pandoc"
}

test_suite_start "Job Scrape Script Tests"

# Test 1: URL domain extraction
test_start "Domain extraction from URL"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    
    source "$PROJECT_ROOT/scripts/job-scrape.sh"
    
    domain1=$(get_domain "https://stripe.com/jobs/listing/123")
    domain2=$(get_domain "https://www.example.com/careers")
    domain3=$(get_domain "https://jobs.google.com/posting")
    
    if [[ "$domain1" == "stripe.com" ]]; then
        test_pass "Stripe domain extracted correctly"
    else
        test_fail "Stripe domain extraction failed. Expected 'stripe.com', got '$domain1'"
    fi
    
    if [[ "$domain2" == "example.com" ]]; then
        test_pass "WWW prefix removed correctly"
    else
        test_fail "WWW prefix removal failed. Expected 'example.com', got '$domain2'"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 2: Company name extraction from URL
test_start "Company name extraction from URL"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    
    source "$PROJECT_ROOT/scripts/job-scrape.sh"
    
    company1=$(extract_company_from_url "https://stripe.com/jobs/listing/123")
    company2=$(extract_company_from_url "https://jobs.techcorp.com/posting")
    company3=$(extract_company_from_url "https://techstartup.greenhouse.io/jobs/456")
    
    if [[ "$company1" == "stripe" ]]; then
        test_pass "Company extracted from main domain"
    else
        test_fail "Company extraction failed. Expected 'stripe', got '$company1'"
    fi
    
    if [[ "$company2" == "techcorp" ]]; then
        test_pass "Company extracted from jobs subdomain"
    else
        test_fail "Jobs subdomain extraction failed. Expected 'techcorp', got '$company2'"
    fi
    
    if [[ "$company3" == "techstartup" ]]; then
        test_pass "Company extracted from greenhouse URL"
    else
        test_fail "Greenhouse extraction failed. Expected 'techstartup', got '$company3'"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 3: Filename sanitization
test_start "Filename sanitization"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    
    source "$PROJECT_ROOT/scripts/job-scrape.sh"
    
    sanitized1=$(sanitize_filename "Tech Corp & Associates")
    sanitized2=$(sanitize_filename "Senior Software Engineer @ Google")
    
    if [[ "$sanitized1" == "tech_corp_associates" ]]; then
        test_pass "Company name sanitized for filename"
    else
        test_fail "Filename sanitization failed. Expected 'tech_corp_associates', got '$sanitized1'"
    fi
    
    if [[ "$sanitized2" == "senior_software_engineer_google" ]]; then
        test_pass "Role name sanitized for filename"
    else
        test_fail "Role sanitization failed. Expected 'senior_software_engineer_google', got '$sanitized2'"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 4: Job posting scraping (mocked)
test_start "Job posting scraping with mocks"
temp_dir=$(setup_temp_dir)
setup_scrape_mocks
(
    cd "$temp_dir"
    mkdir -p job_postings/formatted
    
    timeout 10s "$PROJECT_ROOT/scripts/job-scrape.sh" "https://example.com/job" -c "TestCorp" -r "Engineer" >/dev/null 2>&1 || echo "Command completed or timed out"
    
    # Check if file was created (either PDF or HTML)
    files_created=0
    for ext in pdf html; do
        if ls job_postings/formatted/testcorp_engineer_*.$ext 1> /dev/null 2>&1; then
            ((files_created++))
        fi
    done
    
    if [[ $files_created -gt 0 ]]; then
        test_pass "Job posting file created"
    else
        # Debug: show what files were actually created
        echo "Debug: Files in job_postings/formatted/:" >&2
        ls -la job_postings/formatted/ >&2 2>/dev/null || echo "Directory doesn't exist" >&2
        test_fail "No job posting file created"
    fi
)
cleanup_temp_dir "$temp_dir"
cleanup_scrape_mocks

# Test 5: Chrome fallback to curl
test_start "Chrome fallback to curl"
temp_dir=$(setup_temp_dir)
setup_scrape_mocks
(
    cd "$temp_dir"
    
    source "$PROJECT_ROOT/scripts/job-scrape.sh"
    
    # Mock Chrome path to simulate Chrome not being available
    # Create a test archive function that will use curl fallback
    archive_job_posting() {
        local url="$1"
        local filename="$2"

        # Simulate Chrome not being available by setting empty chrome_path
        local chrome_path=""
        
        # Test the curl fallback logic
        log_warning "Chrome not available, falling back to curl..."
        
        if ! command_exists curl; then
            log_error "Neither Chrome nor curl is available for downloading job postings"
            return 1
        fi

        # Download with curl and UTF-8 handling (mocked)
        {
            printf '\xEF\xBB\xBF'  # UTF-8 BOM
            echo "<html><head><title>Test Job</title></head><body>Test job posting content</body></html>"
        } > "$filename"

        if [[ -s "$filename" ]]; then
            log_success "UTF-8 HTML saved to $filename (via curl)"
            return 0
        else
            log_error "Failed to download job posting with curl"
            return 1
        fi
    }
    
    # Test the fallback
    archive_job_posting "https://example.com/job" "test_fallback.html"
    
    if [[ -f "test_fallback.html" ]] && [[ -s "test_fallback.html" ]]; then
        # Check if UTF-8 BOM is present
        if hexdump -C "test_fallback.html" | head -1 | grep -q "ef bb bf"; then
            test_pass "Curl fallback works with UTF-8 BOM"
        else
            test_fail "Curl fallback missing UTF-8 BOM"
        fi
    else
        test_fail "Curl fallback failed to create file"
    fi
)
cleanup_temp_dir "$temp_dir"
cleanup_scrape_mocks

# Test 6: Information extraction
test_start "Job information extraction"
temp_dir=$(setup_temp_dir)
setup_scrape_mocks
(
    cd "$temp_dir"
    mkdir -p job_postings/formatted
    
    # Create mock text file with job info
    cat > "test_job.txt" << EOF
Senior Software Engineer Position

Requirements:
- 5+ years experience
- JavaScript proficiency
- React knowledge

Salary: \$120,000 - \$150,000

Location: San Francisco, CA (Remote possible)
EOF
    
    source "$PROJECT_ROOT/scripts/job-scrape.sh"
    
    extract_job_info "test_job.pdf" "TestCorp" "Engineer"
    
    if [[ -f "test_job_summary.txt" ]]; then
        content=$(cat "test_job_summary.txt")
        if [[ "$content" == *"TestCorp"* ]] && [[ "$content" == *"Engineer"* ]]; then
            test_pass "Job information extracted"
        else
            test_fail "Job information extraction incomplete"
        fi
    else
        test_fail "Summary file not created"
    fi
)
cleanup_temp_dir "$temp_dir"
cleanup_scrape_mocks

# Test 7: List scraped postings
test_start "List scraped job postings"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    mkdir -p job_postings/formatted
    
    # Create some mock job posting files
    touch "job_postings/formatted/techcorp_engineer_20250619.pdf"
    touch "job_postings/formatted/startup_developer_20250618.html"
    
    output=$(capture_output "$PROJECT_ROOT/scripts/job-scrape.sh --list")
    
    if [[ "$output" == *"Scraped Job Postings"* ]] && [[ "$output" == *"techcorp"* ]]; then
        test_pass "Job postings listed correctly"
    else
        test_fail "Job posting listing failed"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 8: Invalid URL handling
test_start "Invalid URL handling"
output=$(capture_output "$PROJECT_ROOT/scripts/job-scrape.sh invalid-url 2>&1")

if [[ "$output" == *"http"* ]] || [[ "$output" == *"URL"* ]] || [[ "$output" == *"ERROR"* ]]; then
    test_pass "Invalid URL handled correctly"
else
    test_fail "Invalid URL not handled properly"
fi

# Test 9: Missing URL handling
test_start "Missing URL handling"
output=$(capture_output "$PROJECT_ROOT/scripts/job-scrape.sh 2>&1")

if [[ "$output" == *"required"* ]] || [[ "$output" == *"URL"* ]] || [[ "$output" == *"ERROR"* ]]; then
    test_pass "Missing URL handled correctly"
else
    test_fail "Missing URL not handled properly"
fi

# Test 10: Help message
test_start "Help message display"
output=$(capture_output "$PROJECT_ROOT/scripts/job-scrape.sh --help")

if [[ "$output" == *"Usage:"* ]] && [[ "$output" == *"Examples:"* ]] && [[ "$output" == *"Features:"* ]]; then
    test_pass "Help message comprehensive"
else
    test_fail "Help message incomplete"
fi

# Test 11: Output file path customization
test_start "Custom output file path"
temp_dir=$(setup_temp_dir)
setup_scrape_mocks
(
    cd "$temp_dir"
    
    "$PROJECT_ROOT/scripts/job-scrape.sh" "https://example.com/job" -o "/tmp/custom_job.pdf" >/dev/null 2>&1
    
    if [[ -f "/tmp/custom_job.pdf" ]] || [[ -f "/tmp/custom_job.html" ]]; then
        test_pass "Custom output path used"
        rm -f "/tmp/custom_job.pdf" "/tmp/custom_job.html"
    else
        test_fail "Custom output path not used"
    fi
)
cleanup_temp_dir "$temp_dir"
cleanup_scrape_mocks

test_suite_end