#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Sanitize string for filename
sanitize_filename() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/_\+/_/g' | sed 's/^_\|_$//g'
}

# Extract domain from URL
get_domain() {
    echo "$1" | sed -n 's/.*\/\/\([^\/]*\).*/\1/p' | sed 's/^www\.//'
}

# Try to extract company name from URL or domain
extract_company_from_url() {
    local url="$1"
    local domain
    domain=$(get_domain "$url")
    
    # Extract company name from common patterns
    case "$domain" in
        *jobs.*)
            echo "$domain" | sed 's/jobs\.//' | sed 's/\.com$//' | sed 's/\..*$//'
            ;;
        *.greenhouse.io)
            echo "$domain" | sed 's/\.greenhouse\.io$//'
            ;;
        *.lever.co)
            echo "$domain" | sed 's/\.lever\.co$//'
            ;;
        *.workday.com)
            echo "workday_client"
            ;;
        *)
            echo "$domain" | sed 's/\.com$//' | sed 's/\..*$//'
            ;;
    esac
}

# Download and convert job posting
scrape_job_posting() {
    local url="$1"
    local company="${2:-}"
    local role="${3:-}"
    local output_file="${4:-}"
    
    # Auto-detect company if not provided
    if [[ -z "$company" ]]; then
        company=$(extract_company_from_url "$url")
    fi
    
    # Create default filename if not provided
    if [[ -z "$output_file" ]]; then
        local company_clean
        company_clean=$(sanitize_filename "$company")
        local role_clean=""
        if [[ -n "$role" ]]; then
            role_clean="_$(sanitize_filename "$role")"
        fi
        local date_str
        date_str=$(date +%Y%m%d)
        
        output_file="$PROJECT_ROOT/job_postings/formatted/${company_clean}${role_clean}_${date_str}.pdf"
    fi
    
    # Ensure output directory exists
    mkdir -p "$(dirname "$output_file")"
    
    log_info "Scraping job posting from: $url"
    log_info "Saving to: $output_file"
    
    # Download HTML content
    local temp_html="/tmp/job_posting_$$.html"
    local temp_text="/tmp/job_posting_$$.txt"
    
    if ! command_exists curl; then
        log_error "curl is required for downloading job postings"
        return 1
    fi
    
    # Download with user agent to avoid blocking
    if ! curl -L -s \
        -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
        "$url" -o "$temp_html"; then
        log_error "Failed to download job posting"
        return 1
    fi
    
    # Check if we got a valid HTML file
    if [[ ! -s "$temp_html" ]]; then
        log_error "Downloaded file is empty"
        rm -f "$temp_html"
        return 1
    fi
    
    # Convert to PDF using available tools
    local conversion_success=false
    
    # Try wkhtmltopdf first (best results)
    if command_exists wkhtmltopdf; then
        log_info "Converting to PDF using wkhtmltopdf..."
        if wkhtmltopdf \
            --page-size A4 \
            --margin-top 0.75in \
            --margin-right 0.75in \
            --margin-bottom 0.75in \
            --margin-left 0.75in \
            --disable-smart-shrinking \
            "$temp_html" "$output_file" 2>/dev/null; then
            conversion_success=true
        fi
    fi
    
    # Try pandoc as fallback
    if [[ "$conversion_success" == false ]] && command_exists pandoc; then
        log_info "Converting to PDF using pandoc..."
        if pandoc "$temp_html" -o "$output_file" 2>/dev/null; then
            conversion_success=true
        fi
    fi
    
    # If PDF conversion failed, save as HTML and create a text version
    if [[ "$conversion_success" == false ]]; then
        local html_output="${output_file%.pdf}.html"
        cp "$temp_html" "$html_output"
        log_warning "PDF conversion failed, saved as HTML: $html_output"
        
        # Try to create a readable text version
        if command_exists lynx; then
            lynx -dump "$temp_html" > "$temp_text" 2>/dev/null || true
        elif command_exists w3m; then
            w3m -dump "$temp_html" > "$temp_text" 2>/dev/null || true
        elif command_exists links; then
            links -dump "$temp_html" > "$temp_text" 2>/dev/null || true
        fi
        
        if [[ -s "$temp_text" ]]; then
            local text_output="${output_file%.pdf}.txt"
            mv "$temp_text" "$text_output"
            log_info "Also created text version: $text_output"
        fi
        
        output_file="$html_output"
    fi
    
    # Clean up temp files
    rm -f "$temp_html" "$temp_text"
    
    if [[ -f "$output_file" ]]; then
        log_success "Job posting saved: $output_file"
        
        # Try to extract key information
        extract_job_info "$output_file" "$company" "$role"
        
        return 0
    else
        log_error "Failed to save job posting"
        return 1
    fi
}

# Extract key information from job posting
extract_job_info() {
    local file="$1"
    local company="$2"
    local role="$3"
    
    log_info "Extracting job information..."
    
    # Create a summary file
    local summary_file="${file%.*}_summary.txt"
    
    cat > "$summary_file" << EOF
Job Posting Summary
==================

Company: $company
Role: $role
Scraped: $(date)
Source File: $(basename "$file")

Key Information Extracted:
EOF
    
    # If we have a text version, try to extract key details
    local text_file="${file%.*}.txt"
    if [[ -f "$text_file" ]]; then
        echo "" >> "$summary_file"
        
        # Look for common patterns (this is basic - could be enhanced)
        if grep -qi "requirements\|qualifications\|skills" "$text_file"; then
            echo "Requirements/Qualifications found:" >> "$summary_file"
            grep -i -A 10 "requirements\|qualifications\|skills" "$text_file" | head -15 >> "$summary_file" || true
            echo "" >> "$summary_file"
        fi
        
        if grep -qi "salary\|compensation\|pay" "$text_file"; then
            echo "Compensation mentioned:" >> "$summary_file"
            grep -i "salary\|compensation\|pay" "$text_file" | head -5 >> "$summary_file" || true
            echo "" >> "$summary_file"
        fi
        
        if grep -qi "remote\|location\|office" "$text_file"; then
            echo "Location/Remote info:" >> "$summary_file"
            grep -i "remote\|location\|office" "$text_file" | head -5 >> "$summary_file" || true
            echo "" >> "$summary_file"
        fi
    fi
    
    echo "Note: This is an automated extraction. Review the full job posting for complete details." >> "$summary_file"
    
    log_success "Created summary: $summary_file"
}

# List scraped job postings
list_job_postings() {
    local postings_dir="$PROJECT_ROOT/job_postings/formatted"
    
    if [[ ! -d "$postings_dir" ]]; then
        log_info "No job postings directory found"
        return
    fi
    
    echo "Scraped Job Postings:"
    echo "===================="
    
    local count=0
    for file in "$postings_dir"/*; do
        if [[ -f "$file" ]] && [[ ! "$file" == *"_summary.txt" ]]; then
            ((count++))
            local basename
            basename=$(basename "$file")
            local size
            size=$(ls -lh "$file" | awk '{print $5}')
            local date
            date=$(ls -l "$file" | awk '{print $6, $7, $8}')
            
            echo "$count. $basename ($size) - $date"
            
            # Show summary if it exists
            local summary_file="${file%.*}_summary.txt"
            if [[ -f "$summary_file" ]]; then
                echo "   Summary available: $(basename "$summary_file")"
            fi
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo "No job postings found"
    else
        echo
        echo "Total: $count job postings"
        echo "Directory: $postings_dir"
    fi
}

# Print usage information
print_usage() {
    cat << EOF
Job Posting Scraper

Download and convert job postings from URLs to PDF format.

Usage: $0 URL [OPTIONS]
       $0 --list

Arguments:
    URL                     Job posting URL to scrape

Options:
    -c, --company COMPANY   Company name (auto-detected if not provided)
    -r, --role ROLE         Role/position title (optional, for filename)
    -o, --output FILE       Output file path (auto-generated if not provided)
    -l, --list              List all scraped job postings
    -h, --help              Show this help message

Examples:
    $0 "https://stripe.com/jobs/listing/123"
    $0 "https://company.com/careers/senior-dev" --company "TechCorp" --role "Senior Developer"
    $0 "https://jobs.example.com/posting" --output "/path/to/job.pdf"
    $0 --list

Features:
    - Downloads HTML content with proper user agent
    - Converts to PDF using wkhtmltopdf or pandoc
    - Auto-detects company name from URL
    - Creates readable text version when possible
    - Extracts key information (requirements, salary, location)
    - Generates summary files
    - Saves to job_postings/formatted/ directory

Supported Conversion Tools:
    1. wkhtmltopdf (best results) - install with: brew install wkhtmltopdf
    2. pandoc (fallback) - install with: brew install pandoc
    3. HTML + text fallback if PDF conversion fails

Output Files:
    company_role_date.pdf     # Main PDF file
    company_role_date.html    # HTML fallback if PDF fails
    company_role_date.txt     # Text version for analysis
    company_role_date_summary.txt  # Extracted key information
EOF
}

# Main function
main() {
    local url=""
    local company=""
    local role=""
    local output_file=""
    local list_flag=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--company)
                if [[ -n "${2:-}" ]]; then
                    company="$2"
                    shift 2
                else
                    log_error "--company requires a value"
                    exit 1
                fi
                ;;
            -r|--role)
                if [[ -n "${2:-}" ]]; then
                    role="$2"
                    shift 2
                else
                    log_error "--role requires a value"
                    exit 1
                fi
                ;;
            -o|--output)
                if [[ -n "${2:-}" ]]; then
                    output_file="$2"
                    shift 2
                else
                    log_error "--output requires a value"
                    exit 1
                fi
                ;;
            -l|--list)
                list_flag=true
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
            *)
                if [[ -z "$url" ]]; then
                    url="$1"
                else
                    log_error "Multiple URLs specified"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Handle list flag
    if [[ "$list_flag" == true ]]; then
        list_job_postings
        exit 0
    fi
    
    # Validate URL
    if [[ -z "$url" ]]; then
        log_error "URL is required"
        print_usage
        exit 1
    fi
    
    # Validate URL format
    if [[ ! "$url" =~ ^https?:// ]]; then
        log_error "URL must start with http:// or https://"
        exit 1
    fi
    
    # Scrape the job posting
    scrape_job_posting "$url" "$company" "$role" "$output_file"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi