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

# Find config by walking up directories
find_config() {
    local dir="$1"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/.writer-config.yml" ]]; then
            echo "$dir/.writer-config.yml"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    
    # Fallback to global config
    if [[ -f "$PROJECT_ROOT/.writer-config.yml" ]]; then
        echo "$PROJECT_ROOT/.writer-config.yml"
        return 0
    fi
    
    return 1
}

# Get config value using yq
get_config() {
    local config_file="$1"
    local key="$2"
    local default="${3:-null}"
    
    if [[ ! -f "$config_file" ]]; then
        echo "$default"
        return
    fi
    
    if ! command_exists yq; then
        log_warning "yq not found, using default value for $key"
        echo "$default"
        return
    fi
    
    local value
    value=$(yq eval ".$key" "$config_file" 2>/dev/null | tr -d '\n' | tr -d '"' | xargs || echo "null")
    
    if [[ "$value" == "null" || -z "$value" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Get pandoc options for format
get_pandoc_options() {
    local config_file="$1"
    local format="$2"
    
    # Try format-specific options first (pandoc_options.format)
    local options
    options=$(get_config "$config_file" "pandoc_options.$format" "")
    
    # If that's empty or null, and we didn't find format-specific options,
    # check if pandoc_options is a string (not an object)
    if [[ "$options" == "" ]] || [[ "$options" == "null" ]]; then
        local pandoc_opts_type
        pandoc_opts_type=$(yq eval '.pandoc_options | type' "$config_file" 2>/dev/null || echo "null")
        
        if [[ "$pandoc_opts_type" == "string" ]]; then
            options=$(get_config "$config_file" "pandoc_options" "")
        fi
    fi
    
    # Ensure we never return "null" - always return empty string if nothing found
    if [[ "$options" == "null" ]]; then
        options=""
    fi
    
    echo "$options"
}

# Create formatted directory if it doesn't exist
ensure_formatted_dir() {
    local file_dir="$1"
    local formatted_dir="$file_dir/formatted"
    
    if [[ ! -d "$formatted_dir" ]]; then
        mkdir -p "$formatted_dir"
        log_info "Created formatted directory: $formatted_dir"
    fi
}

# Format a single markdown file
format_file() {
    local md_file="$1"
    local format_override="${2:-}"
    local output_override="${3:-}"
    
    if [[ ! -f "$md_file" ]]; then
        log_error "File not found: $md_file"
        return 1
    fi
    
    # Get absolute path and directory
    local md_file_abs
    md_file_abs=$(realpath "$md_file")
    local file_dir
    file_dir=$(dirname "$md_file_abs")
    local file_name
    file_name=$(basename "$md_file" .md)
    
    # Find configuration
    local config_file
    if ! config_file=$(find_config "$file_dir"); then
        log_warning "No configuration found, using defaults"
        config_file=""
    fi
    
    # Determine format
    local format="docx"  # default
    if [[ -n "$format_override" ]]; then
        format="$format_override"
    elif [[ -n "$config_file" ]]; then
        format=$(get_config "$config_file" "format" "docx")
    fi
    
    # Determine output file
    local output_file
    if [[ -n "$output_override" ]]; then
        output_file="$output_override"
    else
        ensure_formatted_dir "$file_dir"
        output_file="$file_dir/formatted/$file_name.$format"
    fi
    
    # Get pandoc options
    local pandoc_options=""
    if [[ -n "$config_file" ]]; then
        pandoc_options=$(get_pandoc_options "$config_file" "$format")
        
        # Handle reference document path
        if [[ "$pandoc_options" == *"--reference-doc="* ]]; then
            local ref_doc
            ref_doc=$(echo "$pandoc_options" | sed -n 's/.*--reference-doc=\([^ ]*\).*/\1/p')
            
            # If reference doc is relative, make it relative to config file location
            if [[ ! "$ref_doc" == /* ]]; then
                local config_dir
                config_dir=$(dirname "$config_file")
                local full_ref_path="$config_dir/$ref_doc"
                
                if [[ -f "$full_ref_path" ]]; then
                    pandoc_options=$(echo "$pandoc_options" | sed "s|--reference-doc=$ref_doc|--reference-doc=$full_ref_path|")
                else
                    log_warning "Reference document not found: $full_ref_path"
                fi
            fi
        fi
    fi
    
    # Check if pandoc is available
    if ! command_exists pandoc; then
        log_error "pandoc is not installed. Please run the setup script."
        return 1
    fi
    
    log_info "Formatting $md_file -> $output_file (format: $format)"
    
    # Build and execute pandoc command
    local pandoc_cmd="pandoc \"$md_file_abs\" -o \"$output_file\""
    
    if [[ -n "$pandoc_options" ]]; then
        pandoc_cmd="pandoc \"$md_file_abs\" $pandoc_options -o \"$output_file\""
    fi
    
    if eval "$pandoc_cmd"; then
        log_success "Successfully formatted: $(basename "$output_file")"
    else
        log_error "Failed to format: $md_file"
        return 1
    fi
}

# Format all markdown files in directory
format_all() {
    local target_dir="${1:-.}"
    local format_override="${2:-}"
    
    log_info "Formatting all markdown files in: $target_dir"
    
    local count=0
    while IFS= read -r -d '' file; do
        if format_file "$file" "$format_override"; then
            ((count++))
        fi
    done < <(find "$target_dir" -name "*.md" -not -path "*/formatted/*" -print0)
    
    log_success "Formatted $count files"
}

# Print usage information
print_usage() {
    cat << EOF
Markdown Format Manager

Convert markdown files to various formats using pandoc and directory-specific configuration.

Usage: $0 [FILE] [OPTIONS]
       $0 --all [OPTIONS]

Arguments:
    FILE                    Markdown file to format

Options:
    --all                   Format all markdown files in current directory
    --format FORMAT         Override output format (docx, html, pdf)
    --output FILE           Specify output file path
    --dir DIRECTORY         Target directory for --all (default: current)
    -h, --help              Show this help message
    -v, --verbose           Verbose output

Examples:
    $0 resume.md                           # Format using directory config
    $0 resume.md --format pdf              # Override format
    $0 resume.md --output /tmp/resume.pdf  # Specify output file
    $0 --all                               # Format all .md files in current dir
    $0 --all --dir ./resumes               # Format all .md files in ./resumes
    $0 --all --format html                 # Format all to HTML

Configuration:
    Place .writer-config.yml in any directory to configure formatting options.
    The script walks up the directory tree to find the nearest configuration.

Dependencies:
    - pandoc (required)
    - yq (required for configuration parsing)
EOF
}

# Main function
main() {
    local file=""
    local format_override=""
    local output_override=""
    local format_all_files=false
    local target_dir="."
    local verbose=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            --all)
                format_all_files=true
                shift
                ;;
            --format)
                if [[ -n "${2:-}" ]]; then
                    format_override="$2"
                    shift 2
                else
                    log_error "--format requires a value"
                    exit 1
                fi
                ;;
            --output)
                if [[ -n "${2:-}" ]]; then
                    output_override="$2"
                    shift 2
                else
                    log_error "--output requires a value"
                    exit 1
                fi
                ;;
            --dir)
                if [[ -n "${2:-}" ]]; then
                    target_dir="$2"
                    shift 2
                else
                    log_error "--dir requires a value"
                    exit 1
                fi
                ;;
            -*)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
            *)
                if [[ -z "$file" ]]; then
                    file="$1"
                else
                    log_error "Multiple files specified. Use --all to format multiple files."
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate arguments
    if [[ "$format_all_files" == true ]] && [[ -n "$file" ]]; then
        log_error "Cannot specify both a file and --all"
        exit 1
    fi
    
    if [[ "$format_all_files" == false ]] && [[ -z "$file" ]]; then
        log_error "Must specify either a file or --all"
        print_usage
        exit 1
    fi
    
    # Execute based on mode
    if [[ "$format_all_files" == true ]]; then
        format_all "$target_dir" "$format_override"
    else
        format_file "$file" "$format_override" "$output_override"
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi