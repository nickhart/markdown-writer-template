#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

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


# Detect Chrome installation
detect_chrome() {
    local os="$1"

    case "$os" in
        macos)
            # Check common macOS Chrome locations
            local chrome_paths=(
                "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
                "/Applications/Google Chrome Beta.app/Contents/MacOS/Google Chrome Beta"
                "/Applications/Google Chrome Dev.app/Contents/MacOS/Google Chrome Dev"
                "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary"
            )

            for path in "${chrome_paths[@]}"; do
                if [[ -x "$path" ]]; then
                    echo "$path"
                    return 0
                fi
            done
            ;;
        linux)
            # Check common Linux Chrome locations
            local chrome_paths=(
                "/usr/bin/google-chrome"
                "/usr/bin/google-chrome-stable"
                "/usr/bin/google-chrome-beta"
                "/usr/bin/google-chrome-unstable"
                "/usr/bin/chromium"
                "/usr/bin/chromium-browser"
                "/snap/bin/chromium"
            )

            for path in "${chrome_paths[@]}"; do
                if [[ -x "$path" ]]; then
                    echo "$path"
                    return 0
                fi
            done
            ;;
        windows)
            # Check common Windows Chrome locations
            local chrome_paths=(
                "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
                "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe"
                "$HOME\\AppData\\Local\\Google\\Chrome\\Application\\chrome.exe"
            )

            for path in "${chrome_paths[@]}"; do
                if [[ -x "$path" ]]; then
                    echo "$path"
                    return 0
                fi
            done
            ;;
    esac

    return 1
}

# Validate Chrome path
validate_chrome_path() {
    local chrome_path="$1"

    if [[ -z "$chrome_path" ]]; then
        return 1
    fi

    if [[ ! -f "$chrome_path" ]]; then
        log_error "File not found: $chrome_path"
        return 1
    fi

    if [[ ! -x "$chrome_path" ]]; then
        log_error "File is not executable: $chrome_path"
        return 1
    fi

    # Test if it's actually Chrome by running --version
    if "$chrome_path" --version >/dev/null 2>&1; then
        return 0
    else
        log_error "File does not appear to be a valid Chrome executable: $chrome_path"
        return 1
    fi
}

# Prompt user for Chrome path
prompt_chrome_path() {
    local os="$1"

    echo
    log_warning "Chrome was not detected automatically."
    echo
    echo "Chrome is required for job posting archiving functionality."
    echo "You have the following options:"
    echo

    case "$os" in
        macos)
            echo "1. Install Chrome:"
            echo "   • Download from: https://www.google.com/chrome/"
            echo "   • Or install via Homebrew: brew install --cask google-chrome"
            ;;
        linux)
            echo "1. Install Chrome:"
            echo "   • Ubuntu/Debian: wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -"
            echo "                    sudo sh -c 'echo \"deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main\" >> /etc/apt/sources.list.d/google-chrome.list'"
            echo "                    sudo apt update && sudo apt install google-chrome-stable"
            echo "   • Fedora/RHEL:   sudo dnf install google-chrome-stable"
            echo "   • Or install Chromium: sudo apt install chromium-browser (Ubuntu/Debian)"
            ;;
        windows)
            echo "1. Install Chrome:"
            echo "   • Download from: https://www.google.com/chrome/"
            echo "   • Or use Chocolatey: choco install googlechrome"
            ;;
    esac

    echo "2. Provide a custom Chrome path (if you have Chrome installed elsewhere)"
    echo "3. Skip Chrome setup (job posting archiving will not work)"
    echo

    local choice
    read -p "Choose an option (1-3): " choice

    case "$choice" in
        1)
            echo
            log_info "Please install Chrome using the instructions above, then re-run this setup script."
            echo "Setup will continue without Chrome for now."
            return 1
            ;;
        2)
            echo
            local custom_path
            read -p "Enter the full path to your Chrome executable: " custom_path

            if validate_chrome_path "$custom_path"; then
                echo "$custom_path"
                return 0
            else
                log_error "Invalid Chrome path. Setup will continue without Chrome."
                return 1
            fi
            ;;
        3)
            log_info "Skipping Chrome setup. Job posting archiving will not be available."
            return 1
            ;;
        *)
            log_warning "Invalid choice. Skipping Chrome setup."
            return 1
            ;;
    esac
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
            brew install pandoc librsvg
            ;;
        apt)
            sudo apt-get update && sudo apt-get install -y pandoc librsvg2-bin
            ;;
        yum)
            sudo yum install -y pandoc librsvg2-tools
            ;;
        dnf)
            sudo dnf install -y pandoc librsvg2-tools
            ;;
        pacman)
            sudo pacman -S --noconfirm pandoc librsvg
            ;;
        *)
            log_error "Cannot install pandoc automatically on this system"
            log_info "Please install pandoc manually from: https://pandoc.org/installing.html"
            log_info "Also install librsvg for SVG support"
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

    # Detect and configure Chrome path
    local os
    os=$(detect_os)
    local chrome_path

    if chrome_path=$(detect_chrome "$os"); then
        log_success "Chrome detected at: $chrome_path"
    else
        # Prompt user for Chrome installation or path
        if chrome_path=$(prompt_chrome_path "$os"); then
            log_success "Using Chrome at: $chrome_path"
        else
            log_info "Continuing setup without Chrome"
            log_info "Note: Job posting archiving will not be available"
            chrome_path=""
        fi
    fi

    # Save Chrome path to config if we have one
    if [[ -n "$chrome_path" ]] && command_exists yq; then
        yq eval ".chrome_path = \"$chrome_path\"" -i ".writer-config.yml"
        log_success "Chrome path added to global configuration"
    elif [[ -n "$chrome_path" ]]; then
        log_warning "yq not available, Chrome path not saved to config"
        log_info "You can manually add 'chrome_path: \"$chrome_path\"' to .writer-config.yml"
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
2. Configure optional dependencies (Google Chrome for better HTML archiving)
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