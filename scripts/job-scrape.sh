#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Sanitize string for filename
sanitize_filename() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/__*/_/g' | sed 's/^_\|_$//g'
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

archive_job_posting() {
    local url="$1"
    local filename="$2"

    log_info "Archiving job posting with proper UTF-8..."

    # Get Chrome path from config
    local chrome_path=""
    local config_file="$PROJECT_ROOT/.writer-config.yml"

    if [[ -f "$config_file" ]] && command_exists yq; then
        chrome_path=$(yq eval '.chrome_path' "$config_file" 2>/dev/null)
        if [[ "$chrome_path" == "null" || -z "$chrome_path" ]]; then
            chrome_path=""
        fi
    fi

    # Fallback to common Chrome locations if not in config
    if [[ -z "$chrome_path" ]]; then
        local chrome_paths=(
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
            "/usr/bin/google-chrome"
            "/usr/bin/google-chrome-stable"
            "/usr/bin/chromium"
            "/usr/bin/chromium-browser"
        )

        for path in "${chrome_paths[@]}"; do
            if [[ -x "$path" ]]; then
                chrome_path="$path"
                break
            fi
        done
    fi

    if [[ -z "$chrome_path" ]]; then
        log_error "Chrome not found. Please install Chrome or update the chrome_path in .writer-config.yml"
        return 1
    fi

    if [[ ! -x "$chrome_path" ]]; then
        log_error "Chrome executable not found at: $chrome_path"
        return 1
    fi

    # UTF-8 BOM + Chrome dump = perfect encoding
    {
        printf '\xEF\xBB\xBF'  # UTF-8 BOM
        "$chrome_path" \
            --headless \
            --disable-gpu \
            --dump-dom \
            --virtual-time-budget=5000 \
            "$url"
    } > "$filename"

    log_success "Clean UTF-8 HTML saved to $filename"
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

        # Use relative path if directory exists, otherwise absolute
        if [[ -d "job_postings/formatted" ]]; then
            output_file="job_postings/formatted/${company_clean}${role_clean}_${date_str}.html"
        else
            mkdir -p "$PROJECT_ROOT/job_postings/formatted"
            output_file="$PROJECT_ROOT/job_postings/formatted/${company_clean}${role_clean}_${date_str}.html"
        fi
    fi

    # Ensure output directory exists
    mkdir -p "$(dirname "$output_file")"

    log_info "Scraping job posting from: $url"
    log_info "Saving to: $output_file"

    # Use new Chrome archiving function
    archive_job_posting "$url" "$output_file"

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
    # Use relative path if it exists, otherwise absolute
    if [[ -d "job_postings/formatted" ]]; then
        local postings_dir="job_postings/formatted"
    else
        local postings_dir="$PROJECT_ROOT/job_postings/formatted"
    fi

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
    1. wkhtmltopdf (best for HTML-to-PDF) - install with: brew install wkhtmltopdf
    2. pandoc (backup option) - install with: brew install pandoc
    3. HTML + text fallback if PDF conversion fails

Note: For best results, install wkhtmltopdf which handles modern HTML/CSS better than pandoc.

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