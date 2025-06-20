#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Sanitize string for directory name
sanitize_dirname() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/__*/_/g' | sed 's/^_\|_$//g'
}

# Get current date in various formats
get_date() {
    local format="$1"
    case "$format" in
        "short")
            date +%Y%m%d
            ;;
        "month_year")
            date +"%B %Y"
            ;;
        "full")
            date +"%B %d, %Y"
            ;;
        "iso")
            date +%Y-%m-%d
            ;;
        *)
            date
            ;;
    esac
}

# Check if PDF generation is available
is_pdf_generation_available() {
    local config_file="$PROJECT_ROOT/.writer-config.yml"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    if command_exists yq; then
        local pdf_enabled
        pdf_enabled=$(yq eval '.pdf_generation' "$config_file" 2>/dev/null)
        if [[ "$pdf_enabled" == "true" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Prompt for input with default
prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local var_name="$3"

    if [[ -n "$default" ]]; then
        read -p "$prompt [$default]: " input
        if [[ -z "$input" ]]; then
            input="$default"
        fi
    else
        read -p "$prompt: " input
        while [[ -z "$input" ]]; do
            echo "This field is required."
            read -p "$prompt: " input
        done
    fi

    eval "$var_name=\"\$input\""
}

# List available resume templates
list_resume_templates() {
    local templates_dir="templates/resumes"
    if [[ -d "$templates_dir" ]]; then
        echo "Available resume templates:"
        for template in "$templates_dir"/*.md; do
            if [[ -f "$template" ]]; then
                echo "  - $(basename "$template" .md)"
            fi
        done
    else
        echo "No resume templates found in $templates_dir"
    fi
}

# Replace template variables in file
replace_template_variables() {
    local file="$1"
    local company="$2"
    local role="$3"
    local date_full="$4"
    local date_month_year="$5"

    if [[ ! -f "$file" ]]; then
        log_error "Template file not found: $file"
        return 1
    fi

    # Use sed to replace template variables
    sed -i.bak \
        -e "s/{{COMPANY_NAME}}/$company/g" \
        -e "s/{{ROLE_TITLE}}/$role/g" \
        -e "s/{{APPLICATION_DATE}}/$date_full/g" \
        -e "s/{{MONTH_YEAR}}/$date_month_year/g" \
        "$file"

    # Remove backup file
    rm -f "$file.bak"
}

# Download job posting from URL
download_job_posting() {
    local url="$1"
    local output_file="$2"

    log_info "Downloading job posting from: $url"

    # Try to download with curl
    if command_exists curl; then
        local temp_html="/tmp/job_posting_$$.html"

        if curl -s -L "$url" -o "$temp_html"; then
            # Convert HTML to PDF using pandoc
            if command_exists pandoc; then
                if pandoc "$temp_html" -o "$output_file" 2>/dev/null; then
                    log_success "Job posting downloaded as PDF: $output_file"
                    rm -f "$temp_html"
                    return 0
                else
                    log_warning "PDF conversion failed, saving as HTML instead"
                    cp "$temp_html" "${output_file%.pdf}.html"
                    log_success "Job posting saved as HTML: ${output_file%.pdf}.html"
                    rm -f "$temp_html"
                    return 0
                fi
            else
                log_warning "pandoc not available for PDF conversion"
                cp "$temp_html" "${output_file%.pdf}.html"
                log_success "Job posting saved as HTML: ${output_file%.pdf}.html"
                rm -f "$temp_html"
                return 0
            fi
        fi
    fi

    log_warning "Failed to download job posting automatically"
    log_info "Please download the job posting manually and save it as: $output_file"
    return 1
}

# Create application metadata file
create_application_metadata() {
    local app_dir="$1"
    local company="$2"
    local role="$3"
    local template="$4"
    local url="${5:-}"
    local date_iso="$6"
    local dir_name="$7"

    local metadata_file="$app_dir/.application.yml"

    cat > "$metadata_file" << EOF
# Application metadata - auto-generated by job-apply.sh
company: "$company"
role: "$role"
template_used: "$template"
job_url: "$url"
application_date: "$date_iso"
status: "active"
directory: "$dir_name"
files:
  resume: "resume.md"
  cover_letter: "cover_letter.md"
  job_posting: "job_description.pdf"
notes: ""
EOF

    log_success "Created application metadata: $metadata_file"
}

# Interactive mode - prompt for all inputs
interactive_mode() {
    echo "=== Interactive Job Application Setup ==="
    echo

    list_resume_templates
    echo

    local company role template url

    prompt_input "Company name" "" company
    prompt_input "Role/Position title" "" role
    prompt_input "Resume template" "general" template
    prompt_input "Job posting URL (optional)" "" url

    create_application "$company" "$role" "$template" "$url"
}

# Create complete job application package
create_application() {
    local company="$1"
    local role="$2"
    local template="$3"
    local url="${4:-}"

    # Sanitize inputs for directory name
    local company_clean
    company_clean=$(sanitize_dirname "$company")
    local role_clean
    role_clean=$(sanitize_dirname "$role")
    local date_short
    date_short=$(get_date "short")

    # Create directory name
    local dir_name="${company_clean}_${role_clean}_$(get_date 'month_year' | tr '[:upper:]' '[:lower:]' | tr ' ' '_')_${date_short}"
    local app_dir="applications/active/$dir_name"

    log_info "Creating application package: $dir_name"

    # Create application directory
    if [[ -d "$app_dir" ]]; then
        log_warning "Application directory already exists: $app_dir"
        # In non-interactive mode (testing), auto-continue
        if [[ ! -t 0 ]]; then
            log_info "Non-interactive mode: continuing anyway"
        else
            read -p "Continue anyway? (y/N): " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                log_info "Cancelled"
                return 1
            fi
        fi
    else
        mkdir -p "$app_dir"
        mkdir -p "$app_dir/formatted"
    fi

    # Get date strings
    local date_full
    date_full=$(get_date "full")
    local date_month_year
    date_month_year=$(get_date "month_year")
    local date_iso
    date_iso=$(get_date "iso")

    # Copy resume template
    local resume_template="templates/resumes/$template.md"
    local resume_file="$app_dir/resume.md"

    if [[ ! -f "$resume_template" ]]; then
        log_error "Resume template not found: $resume_template"
        list_resume_templates
        return 1
    fi

    cp "$resume_template" "$resume_file"
    replace_template_variables "$resume_file" "$company" "$role" "$date_full" "$date_month_year"
    log_success "Created resume: $resume_file"

    # Copy cover letter template
    local cover_template="templates/default_cover_letter.md"
    local cover_file="$app_dir/cover_letter.md"

    if [[ -f "$cover_template" ]]; then
        cp "$cover_template" "$cover_file"
        replace_template_variables "$cover_file" "$company" "$role" "$date_full" "$date_month_year"
        log_success "Created cover letter: $cover_file"
    else
        log_warning "Cover letter template not found: $cover_template"
    fi

    # Download job posting if URL provided
    if [[ -n "$url" ]]; then
        local job_file="$app_dir/job_description.pdf"
        download_job_posting "$url" "$job_file"
    fi

    # Create application metadata
    create_application_metadata "$app_dir" "$company" "$role" "$template" "$url" "$date_iso" "$dir_name"

    # Copy config for DOCX formatting
    local config_file="$app_dir/.writer-config.yml"
    cat > "$config_file" << EOF
# Application-specific configuration
format: docx
pandoc_options: ""
auto_format: true
EOF

    # Format the markdown files
    log_info "Formatting documents..."
    # Try relative path first, then absolute
    local format_script="scripts/format.sh"
    if [[ ! -x "$format_script" ]]; then
        format_script="$PROJECT_ROOT/scripts/format.sh"
    fi

    if [[ -x "$format_script" ]]; then
        "$format_script" "$app_dir/resume.md" || log_warning "Failed to format resume"
        "$format_script" "$app_dir/cover_letter.md" || log_warning "Failed to format cover letter"

        # Create PDF versions if LaTeX is available
        if is_pdf_generation_available; then
            "$format_script" "$app_dir/resume.md" --format pdf || log_warning "Failed to create PDF resume"
            "$format_script" "$app_dir/cover_letter.md" --format pdf || log_warning "Failed to create PDF cover letter"
            log_success "PDF versions created"
        else
            log_warning "PDF generation not available (LaTeX not installed)"
            log_info "Install LaTeX and re-run setup to enable PDF generation"
        fi
    else
        log_warning "Format script not found or not executable"
    fi

    echo
    log_success "Job application package created successfully!"
    echo
    echo "Application directory: $app_dir"
    echo "Files created:"
    if is_pdf_generation_available; then
        echo "  - resume.md (+ DOCX and PDF versions)"
        echo "  - cover_letter.md (+ DOCX and PDF versions)"
    else
        echo "  - resume.md (+ DOCX version)"
        echo "  - cover_letter.md (+ DOCX version)"
    fi
    if [[ -n "$url" ]]; then
        echo "  - job_description.pdf"
    fi
    echo "  - .application.yml (metadata)"
    echo
    echo "Next steps:"
    echo "1. Edit the resume and cover letter files"
    echo "2. Run './scripts/format.sh --all --dir \"$app_dir\"' to regenerate formatted versions"
    echo "3. Use './scripts/job-log.sh' to track application status"
}

# Print usage information
print_usage() {
    cat << EOF
Job Application Workflow Manager

Create complete job application packages with resume, cover letter, and job posting.

Usage: $0 [OPTIONS]

Options:
    -c, --company COMPANY       Company name (required)
    -r, --role ROLE            Role/position title (required)
    -t, --template TEMPLATE    Resume template to use (default: general)
    -u, --url URL              Job posting URL (optional)
    -i, --interactive          Interactive mode (prompts for all inputs)
    -l, --list-templates       List available resume templates
    -h, --help                 Show this help message

Examples:
    $0 -c "Stripe" -r "Engineering Manager" -t "general"
    $0 --company "Acme Corp" --role "Senior Developer" --template "mobile" --url "https://acme.com/jobs/123"
    $0 --interactive
    $0 --list-templates

Features:
    - Creates organized directory structure under applications/active/
    - Copies and customizes resume from templates
    - Creates cover letter with template variables
    - Downloads job posting as PDF (if URL provided)
    - Generates application metadata
    - Auto-formats documents to DOCX (and PDF if LaTeX is available)
    - Template variable replacement:
      {{COMPANY_NAME}} → Company name
      {{ROLE_TITLE}} → Role title
      {{APPLICATION_DATE}} → Full date
      {{MONTH_YEAR}} → Month and year

Directory Structure:
    applications/active/company_role_month_year_date/
    ├── resume.md
    ├── cover_letter.md
    ├── job_description.pdf
    ├── .application.yml
    ├── .writer-config.yml
    └── formatted/
        ├── resume.docx
        ├── resume.pdf
        └── cover_letter.docx
EOF
}

# Main function
main() {
    local company=""
    local role=""
    local template="general"
    local url=""
    local interactive_mode_flag=false
    local list_templates_flag=false

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
            -t|--template)
                if [[ -n "${2:-}" ]]; then
                    template="$2"
                    shift 2
                else
                    log_error "--template requires a value"
                    exit 1
                fi
                ;;
            -u|--url)
                if [[ -n "${2:-}" ]]; then
                    url="$2"
                    shift 2
                else
                    log_error "--url requires a value"
                    exit 1
                fi
                ;;
            -i|--interactive)
                interactive_mode_flag=true
                shift
                ;;
            -l|--list-templates)
                list_templates_flag=true
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    # Handle special flags
    if [[ "$list_templates_flag" == true ]]; then
        list_resume_templates
        exit 0
    fi

    if [[ "$interactive_mode_flag" == true ]]; then
        interactive_mode
        exit 0
    fi

    # Validate required arguments
    if [[ -z "$company" ]] || [[ -z "$role" ]]; then
        log_error "Company and role are required. Use --interactive for guided setup."
        print_usage
        exit 1
    fi

    # Create the application
    create_application "$company" "$role" "$template" "$url"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi