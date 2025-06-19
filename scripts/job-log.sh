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
APPLICATIONS_DIR="$PROJECT_ROOT/applications"

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

# Get application metadata
get_application_metadata() {
    local app_dir="$1"
    local metadata_file="$app_dir/.application.yml"
    
    if [[ ! -f "$metadata_file" ]]; then
        return 1
    fi
    
    if command_exists yq; then
        # Use yq to parse YAML
        yq eval "$metadata_file" 2>/dev/null || return 1
    else
        # Fallback to grep/sed parsing
        cat "$metadata_file" 2>/dev/null || return 1
    fi
}

# Get specific metadata field
get_metadata_field() {
    local app_dir="$1"
    local field="$2"
    local metadata_file="$app_dir/.application.yml"
    
    if [[ ! -f "$metadata_file" ]]; then
        echo ""
        return 1
    fi
    
    if command_exists yq; then
        yq eval ".$field" "$metadata_file" 2>/dev/null | sed 's/^null$//' || echo ""
    else
        # Fallback to grep/sed
        grep "^$field:" "$metadata_file" 2>/dev/null | sed 's/^[^:]*: *"\?\([^"]*\)"\?$/\1/' || echo ""
    fi
}

# Update metadata field
update_metadata_field() {
    local app_dir="$1"
    local field="$2"
    local value="$3"
    local metadata_file="$app_dir/.application.yml"
    
    if [[ ! -f "$metadata_file" ]]; then
        log_error "Metadata file not found: $metadata_file"
        return 1
    fi
    
    if command_exists yq; then
        yq eval ".$field = \"$value\"" -i "$metadata_file"
    else
        # Fallback to sed
        sed -i.bak "s/^$field: .*$/$field: \"$value\"/" "$metadata_file"
        rm -f "$metadata_file.bak"
    fi
}

# List applications by status
list_applications() {
    local status="${1:-all}"
    local format="${2:-table}"
    
    if [[ "$status" == "all" ]]; then
        local statuses=("active" "submitted" "interviews" "offers" "rejected" "archive")
    else
        local statuses=("$status")
    fi
    
    local total_count=0
    
    for status_dir in "${statuses[@]}"; do
        local status_path="$APPLICATIONS_DIR/$status_dir"
        
        if [[ ! -d "$status_path" ]]; then
            continue
        fi
        
        local count=0
        local applications=()
        
        for app_dir in "$status_path"/*; do
            if [[ -d "$app_dir" ]]; then
                local app_name
                app_name=$(basename "$app_dir")
                applications+=("$app_name")
                ((count++))
                ((total_count++))
            fi
        done
        
        if [[ $count -gt 0 ]]; then
            if [[ "$format" == "table" ]]; then
                echo
                echo "=== $status_dir ($count) ==="
                printf "%-50s %-20s %-25s %-12s %-15s\n" "Application" "Company" "Role" "Date" "Template"
                echo "$(printf '=%.0s' {1..122})"
                
                for app_name in "${applications[@]}"; do
                    local app_path="$status_path/$app_name"
                    local company
                    company=$(get_metadata_field "$app_path" "company")
                    local role
                    role=$(get_metadata_field "$app_path" "role")
                    local date
                    date=$(get_metadata_field "$app_path" "application_date")
                    local template
                    template=$(get_metadata_field "$app_path" "template_used")
                    
                    # Truncate long strings
                    app_name=$(echo "$app_name" | cut -c1-49)
                    company=$(echo "$company" | cut -c1-19)
                    role=$(echo "$role" | cut -c1-24)
                    template=$(echo "$template" | cut -c1-14)
                    
                    printf "%-50s %-20s %-25s %-12s %-15s\n" "$app_name" "$company" "$role" "$date" "$template"
                done
            else
                echo "$status_dir: $count applications"
                for app_name in "${applications[@]}"; do
                    echo "  - $app_name"
                done
            fi
        fi
    done
    
    if [[ "$format" == "table" ]]; then
        echo
        echo "Total: $total_count applications"
    fi
}

# Generate comprehensive report
generate_report() {
    local output_file="${1:-}"
    local format="${2:-markdown}"
    
    local report_content=""
    local date_str
    date_str=$(date +"%Y-%m-%d")
    
    # Header
    if [[ "$format" == "markdown" ]]; then
        report_content="# Job Applications Report - Generated $date_str

"
    else
        report_content="Job Applications Report - Generated $date_str

"
    fi
    
    # Summary by status
    if [[ "$format" == "markdown" ]]; then
        report_content+="## Summary by Status

"
    else
        report_content+="Summary by Status:
"
    fi
    
    local statuses=("active" "submitted" "interviews" "offers" "rejected" "archive")
    local total_count=0
    
    for status in "${statuses[@]}"; do
        local status_path="$APPLICATIONS_DIR/$status"
        local count=0
        
        if [[ -d "$status_path" ]]; then
            for app_dir in "$status_path"/*; do
                if [[ -d "$app_dir" ]]; then
                    ((count++))
                    ((total_count++))
                fi
            done
        fi
        
        if [[ "$format" == "markdown" ]]; then
            report_content+="- **$(echo "$status" | tr '[:lower:]' '[:upper:]')**: $count applications
"
        else
            report_content+="  $status: $count applications
"
        fi
    done
    
    report_content+="
Total: $total_count applications

"
    
    # Detailed breakdown
    for status in "${statuses[@]}"; do
        local status_path="$APPLICATIONS_DIR/$status"
        
        if [[ ! -d "$status_path" ]]; then
            continue
        fi
        
        local applications=()
        for app_dir in "$status_path"/*; do
            if [[ -d "$app_dir" ]]; then
                applications+=("$app_dir")
            fi
        done
        
        if [[ ${#applications[@]} -eq 0 ]]; then
            continue
        fi
        
        if [[ "$format" == "markdown" ]]; then
            report_content+="## $(echo "$status" | tr '[:lower:]' '[:upper:]') (${#applications[@]})

| Application | Company | Role | Date | Template |
|-------------|---------|------|------|----------|
"
        else
            report_content+="$(echo "$status" | tr '[:lower:]' '[:upper:]') (${#applications[@]}):
"
        fi
        
        for app_path in "${applications[@]}"; do
            local app_name
            app_name=$(basename "$app_path")
            local company
            company=$(get_metadata_field "$app_path" "company")
            local role
            role=$(get_metadata_field "$app_path" "role")
            local date
            date=$(get_metadata_field "$app_path" "application_date")
            local template
            template=$(get_metadata_field "$app_path" "template_used")
            
            if [[ "$format" == "markdown" ]]; then
                report_content+="| $app_name | $company | $role | $date | $template |
"
            else
                report_content+="  - $app_name ($company - $role, $date, template: $template)
"
            fi
        done
        
        report_content+="
"
    done
    
    # Output report
    if [[ -n "$output_file" ]]; then
        echo "$report_content" > "$output_file"
        log_success "Report saved to: $output_file"
    else
        echo "$report_content"
    fi
}

# Move application to different status
move_application() {
    local app_name="$1"
    local new_status="$2"
    
    # Find current location
    local current_path=""
    local current_status=""
    
    for status in "active" "submitted" "interviews" "offers" "rejected" "archive"; do
        local status_path="$APPLICATIONS_DIR/$status/$app_name"
        if [[ -d "$status_path" ]]; then
            current_path="$status_path"
            current_status="$status"
            break
        fi
    done
    
    if [[ -z "$current_path" ]]; then
        log_error "Application not found: $app_name"
        return 1
    fi
    
    if [[ "$current_status" == "$new_status" ]]; then
        log_warning "Application is already in $new_status status"
        return 0
    fi
    
    # Create new status directory if it doesn't exist
    local new_status_dir="$APPLICATIONS_DIR/$new_status"
    mkdir -p "$new_status_dir"
    
    # Move application
    local new_path="$new_status_dir/$app_name"
    
    log_info "Moving $app_name from $current_status to $new_status"
    
    if mv "$current_path" "$new_path"; then
        # Update metadata
        update_metadata_field "$new_path" "status" "$new_status"
        log_success "Application moved successfully"
    else
        log_error "Failed to move application"
        return 1
    fi
}

# Export applications data
export_applications() {
    local format="${1:-csv}"
    local output_file="${2:-}"
    
    if [[ -z "$output_file" ]]; then
        output_file="job_applications_$(date +%Y%m%d).$format"
    fi
    
    local content=""
    
    if [[ "$format" == "csv" ]]; then
        content="Application,Company,Role,Status,Date,Template,URL,Notes
"
        
        for status in "active" "submitted" "interviews" "offers" "rejected" "archive"; do
            local status_path="$APPLICATIONS_DIR/$status"
            
            if [[ ! -d "$status_path" ]]; then
                continue
            fi
            
            for app_dir in "$status_path"/*; do
                if [[ -d "$app_dir" ]]; then
                    local app_name
                    app_name=$(basename "$app_dir")
                    local company
                    company=$(get_metadata_field "$app_dir" "company")
                    local role
                    role=$(get_metadata_field "$app_dir" "role")
                    local date
                    date=$(get_metadata_field "$app_dir" "application_date")
                    local template
                    template=$(get_metadata_field "$app_dir" "template_used")
                    local url
                    url=$(get_metadata_field "$app_dir" "job_url")
                    local notes
                    notes=$(get_metadata_field "$app_dir" "notes")
                    
                    # Escape commas and quotes for CSV
                    company=$(echo "$company" | sed 's/"/\\"/g')
                    role=$(echo "$role" | sed 's/"/\\"/g')
                    notes=$(echo "$notes" | sed 's/"/\\"/g')
                    
                    content+="\"$app_name\",\"$company\",\"$role\",\"$status\",\"$date\",\"$template\",\"$url\",\"$notes\"
"
                fi
            done
        done
    fi
    
    echo "$content" > "$output_file"
    log_success "Data exported to: $output_file"
}

# Show application status summary
show_status_summary() {
    echo "Job Application Status Summary"
    echo "=============================="
    echo
    
    local statuses=("active" "submitted" "interviews" "offers" "rejected" "archive")
    local total=0
    
    for status in "${statuses[@]}"; do
        local status_path="$APPLICATIONS_DIR/$status"
        local count=0
        
        if [[ -d "$status_path" ]]; then
            for app_dir in "$status_path"/*; do
                if [[ -d "$app_dir" ]]; then
                    ((count++))
                    ((total++))
                fi
            done
        fi
        
        printf "%-12s: %d applications\n" "$status" "$count"
    done
    
    echo
    echo "Total: $total applications"
    
    # Show recent activity
    echo
    echo "Recent Applications (last 7 days):"
    echo "--------------------------------"
    
    local recent_count=0
    local cutoff_date
    cutoff_date=$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d 2>/dev/null || echo "")
    
    for status in "${statuses[@]}"; do
        local status_path="$APPLICATIONS_DIR/$status"
        
        if [[ ! -d "$status_path" ]]; then
            continue
        fi
        
        for app_dir in "$status_path"/*; do
            if [[ -d "$app_dir" ]]; then
                local app_date
                app_date=$(get_metadata_field "$app_dir" "application_date")
                
                if [[ -n "$cutoff_date" ]] && [[ "$app_date" > "$cutoff_date" ]]; then
                    local app_name
                    app_name=$(basename "$app_dir")
                    local company
                    company=$(get_metadata_field "$app_dir" "company")
                    echo "  - $app_name ($company) - $app_date"
                    ((recent_count++))
                fi
            fi
        done
    done
    
    if [[ $recent_count -eq 0 ]]; then
        echo "  No recent applications"
    fi
}

# Print usage information
print_usage() {
    cat << EOF
Job Application Logger and Tracker

Track and manage job applications across different stages.

Usage: $0 COMMAND [OPTIONS]

Commands:
    list [STATUS]               List applications by status (default: all)
    report [--output FILE]      Generate comprehensive report
    move APP_NAME STATUS        Move application to new status
    status                      Show status summary
    export [FORMAT] [FILE]      Export data (csv format)

Status Options:
    active, submitted, interviews, offers, rejected, archive

Examples:
    $0 list                                    # List all applications
    $0 list active                             # List active applications
    $0 report                                  # Generate markdown report
    $0 report --output report.md               # Save report to file
    $0 move stripe_eng_mgr_june_2025 submitted # Move to submitted status
    $0 status                                  # Show status summary
    $0 export csv applications.csv             # Export to CSV

Application Statuses:
    active      - Applications being prepared or in progress
    submitted   - Applications submitted, awaiting response
    interviews  - Applications in interview process
    offers      - Applications with job offers received
    rejected    - Applications that were rejected
    archive     - Completed/old applications

Features:
    - Tracks applications across status directories
    - Maintains metadata in .application.yml files
    - Generates reports in markdown and text formats
    - Exports data to CSV for analysis
    - Shows recent activity and summaries
    - Integrates with job-apply.sh workflow

Directory Structure:
    applications/
    ├── active/
    ├── submitted/
    ├── interviews/
    ├── offers/
    ├── rejected/
    └── archive/
EOF
}

# Main function
main() {
    local command="${1:-}"
    
    if [[ -z "$command" ]]; then
        log_error "Command is required"
        print_usage
        exit 1
    fi
    
    case "$command" in
        list)
            local status="${2:-all}"
            local format="${3:-table}"
            list_applications "$status" "$format"
            ;;
        report)
            local output_file=""
            local format="markdown"
            
            shift
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --output)
                        if [[ -n "${2:-}" ]]; then
                            output_file="$2"
                            shift 2
                        else
                            log_error "--output requires a value"
                            exit 1
                        fi
                        ;;
                    --format)
                        if [[ -n "${2:-}" ]]; then
                            format="$2"
                            shift 2
                        else
                            log_error "--format requires a value"
                            exit 1
                        fi
                        ;;
                    *)
                        log_error "Unknown option: $1"
                        exit 1
                        ;;
                esac
            done
            
            generate_report "$output_file" "$format"
            ;;
        move)
            if [[ $# -lt 3 ]]; then
                log_error "move requires application name and new status"
                exit 1
            fi
            move_application "$2" "$3"
            ;;
        status)
            show_status_summary
            ;;
        export)
            local format="${2:-csv}"
            local output_file="${3:-}"
            export_applications "$format" "$output_file"
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            log_error "Unknown command: $command"
            print_usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi