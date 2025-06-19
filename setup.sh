#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

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

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux) echo "linux" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

# Detect package manager
detect_package_manager() {
    if command -v brew >/dev/null 2>&1; then
        echo "brew"
    elif command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install pandoc
install_pandoc() {
    local os="$1"
    local pkg_manager="$2"
    
    if command_exists pandoc; then
        log_success "pandoc is already installed"
        return 0
    fi
    
    log_info "Installing pandoc..."
    
    case "$pkg_manager" in
        brew)
            brew install pandoc
            ;;
        apt)
            sudo apt-get update && sudo apt-get install -y pandoc
            ;;
        yum)
            sudo yum install -y pandoc
            ;;
        dnf)
            sudo dnf install -y pandoc
            ;;
        pacman)
            sudo pacman -S --noconfirm pandoc
            ;;
        *)
            log_error "Cannot install pandoc automatically on this system"
            log_info "Please install pandoc manually from: https://pandoc.org/installing.html"
            return 1
            ;;
    esac
    
    if command_exists pandoc; then
        log_success "pandoc installed successfully"
    else
        log_error "pandoc installation failed"
        return 1
    fi
}

# Install yq
install_yq() {
    local os="$1"
    local pkg_manager="$2"
    
    if command_exists yq; then
        log_success "yq is already installed"
        return 0
    fi
    
    log_info "Installing yq..."
    
    case "$pkg_manager" in
        brew)
            brew install yq
            ;;
        apt)
            # Install yq via snap or download binary
            if command_exists snap; then
                sudo snap install yq
            else
                log_info "Installing yq binary directly..."
                sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
                sudo chmod +x /usr/local/bin/yq
            fi
            ;;
        yum|dnf)
            log_info "Installing yq binary directly..."
            sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
            sudo chmod +x /usr/local/bin/yq
            ;;
        pacman)
            # Try AUR helper or install manually
            if command_exists yay; then
                yay -S --noconfirm yq
            else
                log_info "Installing yq binary directly..."
                sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
                sudo chmod +x /usr/local/bin/yq
            fi
            ;;
        *)
            log_info "Installing yq binary directly..."
            if [[ "$os" == "macos" ]]; then
                sudo curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_darwin_amd64 -o /usr/local/bin/yq
            else
                sudo curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/local/bin/yq
            fi
            sudo chmod +x /usr/local/bin/yq
            ;;
    esac
    
    if command_exists yq; then
        log_success "yq installed successfully"
    else
        log_error "yq installation failed"
        return 1
    fi
}


# Setup shell aliases
setup_shell_aliases() {
    local shell_rc=""
    
    # Detect shell and set RC file
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == */bash ]]; then
        shell_rc="$HOME/.bashrc"
    else
        log_warning "Unknown shell, skipping alias setup"
        return 0
    fi
    
    if [[ ! -f "$shell_rc" ]]; then
        touch "$shell_rc"
    fi
    
    # Check if aliases already exist
    if grep -q "# Markdown Writer Template aliases" "$shell_rc"; then
        log_success "Shell aliases already configured"
        return 0
    fi
    
    log_info "Adding shell aliases to $shell_rc..."
    
    cat >> "$shell_rc" << 'EOF'

# Markdown Writer Template aliases
alias md2html='./scripts/format.sh --format html'
alias md2docx='./scripts/format.sh --format docx'
alias md2pdf='./scripts/format.sh --format pdf'
alias mdformat='./scripts/format.sh'
alias jobapply='./scripts/job-apply.sh'
alias jobscrape='./scripts/job-scrape.sh'
alias joblog='./scripts/job-log.sh'
alias jobstatus='./scripts/job-log.sh report'
alias newresume='cp templates/resumes/general.md resumes/$(date +%Y%m%d)_resume.md'
alias newcover='cp templates/default_cover_letter.md cover_letters/$(date +%Y%m%d)_cover.md'
EOF
    
    log_success "Shell aliases added. Restart your shell or run 'source $shell_rc' to use them."
}

# Setup git hooks
setup_git_hooks() {
    if [[ ! -d ".git" ]]; then
        log_warning "Not a git repository, skipping git hooks setup"
        return 0
    fi
    
    local hooks_dir=".git/hooks"
    local pre_commit_hook="$hooks_dir/pre-commit"
    
    if [[ -f "$pre_commit_hook" ]]; then
        log_success "Git pre-commit hook already exists"
        return 0
    fi
    
    log_info "Setting up git pre-commit hook..."
    
    cp "scripts/pre-commit" "$pre_commit_hook"
    chmod +x "$pre_commit_hook"
    
    log_success "Git pre-commit hook installed"
}

# Create initial config files
create_configs() {
    log_info "Creating initial configuration files..."
    
    # Global config
    if [[ ! -f ".writer-config.yml" ]]; then
        cp "config/.writer-config.yml" ".writer-config.yml"
        log_success "Global configuration created"
    fi
    
    # Directory-specific configs
    local dirs=("blog" "resumes" "cover_letters" "interviews")
    for dir in "${dirs[@]}"; do
        if [[ ! -f "$dir/.writer-config.yml" ]]; then
            cp "templates/.writer-config.yml" "$dir/.writer-config.yml"
        fi
    done
}

# Make scripts executable
make_scripts_executable() {
    log_info "Making scripts executable..."
    chmod +x scripts/*.sh
    log_success "Scripts are now executable"
}

# Print usage information
print_usage() {
    cat << EOF
Markdown Writer Template Setup

This script will:
1. Install required dependencies (pandoc, yq)
2. Install optional dependencies (wkhtmltopdf)
3. Set up shell aliases
4. Configure git hooks
5. Create initial configuration files
6. Make scripts executable

Usage: $0 [OPTIONS]

Options:
    -h, --help          Show this help message
    -q, --quiet         Suppress non-error output
    --skip-deps         Skip dependency installation
    --skip-aliases      Skip shell alias setup
    --skip-git          Skip git hooks setup

Example:
    $0                  # Full setup
    $0 --skip-deps      # Setup without installing dependencies
EOF
}

# Main setup function
main() {
    local skip_deps=false
    local skip_aliases=false
    local skip_git=false
    local quiet=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            --skip-deps)
                skip_deps=true
                shift
                ;;
            --skip-aliases)
                skip_aliases=true
                shift
                ;;
            --skip-git)
                skip_git=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
    
    if [[ "$quiet" == "false" ]]; then
        echo "================================================"
        echo "    Markdown Writer Template Setup"
        echo "================================================"
        echo
    fi
    
    # Detect system
    local os
    os=$(detect_os)
    local pkg_manager
    pkg_manager=$(detect_package_manager)
    
    if [[ "$quiet" == "false" ]]; then
        log_info "Detected OS: $os"
        log_info "Detected package manager: $pkg_manager"
        echo
    fi
    
    # Install dependencies
    if [[ "$skip_deps" == "false" ]]; then
        install_pandoc "$os" "$pkg_manager" || {
            log_error "Failed to install pandoc"
            exit 1
        }
        
        install_yq "$os" "$pkg_manager" || {
            log_error "Failed to install yq"
            exit 1
        }
        
        echo
    fi
    
    # Setup components
    make_scripts_executable
    create_configs
    
    if [[ "$skip_aliases" == "false" ]]; then
        setup_shell_aliases
    fi
    
    if [[ "$skip_git" == "false" ]]; then
        setup_git_hooks
    fi
    
    if [[ "$quiet" == "false" ]]; then
        echo
        echo "================================================"
        log_success "Setup completed successfully!"
        echo "================================================"
        echo
        echo "Next steps:"
        echo "1. Restart your shell or run: source ~/.bashrc (or ~/.zshrc)"
        echo "2. Try the aliases: mdformat, jobapply, joblog"
        echo "3. Edit templates in the templates/ directory"
        echo "4. Start writing markdown files!"
        echo
        echo "For help, see the README.md file."
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi