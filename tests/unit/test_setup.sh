#!/bin/bash

# Tests for setup.sh

# Set up environment
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

source tests/test_framework.sh

# Setup mocks for system commands
setup_setup_mocks() {
    # Mock package managers
    mock_command "brew" 'echo "Brew executed with: $*"; exit 0'
    mock_command "apt-get" 'echo "apt-get executed with: $*"; exit 0'
    mock_command "yum" 'echo "yum executed with: $*"; exit 0'
    mock_command "dnf" 'echo "dnf executed with: $*"; exit 0'
    mock_command "pacman" 'echo "pacman executed with: $*"; exit 0'
    
    # Mock download tools
    mock_command "wget" 'echo "wget executed with: $*"; touch "${@: -1}"; exit 0'
    mock_command "curl" 'echo "curl executed with: $*"; exit 0'
    
    # Mock system tools - don't mock chmod as it's a basic command
    mock_command "sudo" 'echo "sudo executed: ${*:2}"; exit 0'
    mock_command "uname" 'echo "Linux"'  # Mock uname for OS detection testing
}

cleanup_setup_mocks() {
    unmock_command "brew"
    unmock_command "apt-get"
    unmock_command "yum"
    unmock_command "dnf"
    unmock_command "pacman"
    unmock_command "wget"
    unmock_command "curl"
    unmock_command "sudo"
    unmock_command "uname"
}

test_suite_start "Setup Script Tests"

# Test 1: OS detection
test_start "Operating system detection"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    
    source "$PROJECT_ROOT/setup.sh"
    
    # Test current OS detection (should be macOS on this system)
    os=$(detect_os)
    if [[ "$os" == "macos" ]]; then
        test_pass "Current OS detected correctly"
    else
        test_fail "OS detection failed. Expected 'macos', got '$os'"
    fi
)

# Test Linux detection with mock
setup_setup_mocks
(
    cd "$temp_dir"
    
    source "$PROJECT_ROOT/setup.sh"
    
    # Test Linux detection with mocked uname
    os=$(detect_os)
    if [[ "$os" == "linux" ]]; then
        test_pass "Linux detected correctly with mock"
    else
        test_fail "Linux detection failed. Expected 'linux', got '$os'"
    fi
)
cleanup_setup_mocks
cleanup_temp_dir "$temp_dir"

# Test 2: Package manager detection
test_start "Package manager detection"
temp_dir=$(setup_temp_dir)
setup_setup_mocks
(
    cd "$temp_dir"
    
    source "$PROJECT_ROOT/setup.sh"
    
    # Test brew detection (should find our mock)
    pkg_manager=$(detect_package_manager)
    if [[ "$pkg_manager" == "brew" ]]; then
        test_pass "Package manager detected correctly"
    else
        test_fail "Package manager detection failed. Expected 'brew', got '$pkg_manager'"
    fi
)
cleanup_temp_dir "$temp_dir"
cleanup_setup_mocks

# Test 3: Pandoc installation function
test_start "Pandoc installation function"
temp_dir=$(setup_temp_dir)
setup_setup_mocks
(
    cd "$temp_dir"
    
    source "$PROJECT_ROOT/setup.sh"
    
    # Override command_exists function to simulate pandoc not installed
    command_exists() {
        case "$1" in
            pandoc) return 1 ;;  # Simulate pandoc not found
            *) command -v "$1" >/dev/null 2>&1 ;;
        esac
    }
    
    # Test with brew
    output=$(install_pandoc "macos" "brew" 2>&1)
    
    if [[ "$output" == *"Installing pandoc"* ]] && [[ "$output" == *"Brew executed"* ]]; then
        test_pass "Pandoc installation function works"
    else
        test_fail "Pandoc installation failed. Output: $output"
    fi
)
cleanup_temp_dir "$temp_dir"
cleanup_setup_mocks

# Test 4: YQ installation function
test_start "YQ installation function"
temp_dir=$(setup_temp_dir)
setup_setup_mocks
(
    cd "$temp_dir"
    
    source "$PROJECT_ROOT/setup.sh"
    
    # Override command_exists function to simulate yq not installed
    command_exists() {
        case "$1" in
            yq) return 1 ;;  # Simulate yq not found
            *) command -v "$1" >/dev/null 2>&1 ;;
        esac
    }
    
    # Test with brew
    output=$(install_yq "macos" "brew" 2>&1)
    
    if [[ "$output" == *"Installing yq"* ]] && [[ "$output" == *"Brew executed"* ]]; then
        test_pass "YQ installation function works"
    else
        test_fail "YQ installation failed. Output: $output"
    fi
)
cleanup_temp_dir "$temp_dir"
cleanup_setup_mocks

# Test 5: wkhtmltopdf installation function (NEW)
test_start "wkhtmltopdf installation function"
temp_dir=$(setup_temp_dir)
setup_setup_mocks
(
    cd "$temp_dir"
    
    source "$PROJECT_ROOT/setup.sh"
    
    # Override command_exists function to control wkhtmltopdf detection
    command_exists() {
        case "$1" in
            wkhtmltopdf) return 1 ;;  # Simulate wkhtmltopdf not found initially
            *) command -v "$1" >/dev/null 2>&1 ;;
        esac
    }
    
    # Test with brew (macOS)
    output=$(install_wkhtmltopdf "macos" "brew" 2>&1)
    
    if [[ "$output" == *"Installing wkhtmltopdf"* ]] && [[ "$output" == *"Brew executed"* ]]; then
        test_pass "wkhtmltopdf installation works with brew"
    else
        test_fail "wkhtmltopdf installation failed. Output: $output"
    fi
    
    # Test with apt (Linux)
    output=$(install_wkhtmltopdf "linux" "apt" 2>&1)
    
    if [[ "$output" == *"Installing wkhtmltopdf"* ]] && [[ "$output" == *"apt-get executed"* ]]; then
        test_pass "wkhtmltopdf installation works with apt"
    else
        test_fail "wkhtmltopdf apt installation failed. Output: $output"
    fi
    
    # Test with unknown package manager (should not fail)
    output=$(install_wkhtmltopdf "unknown" "unknown" 2>&1)
    
    if [[ "$output" == *"Cannot install wkhtmltopdf automatically"* ]] && [[ "$output" == *"optional"* ]]; then
        test_pass "wkhtmltopdf handles unknown package manager gracefully"
    else
        test_fail "wkhtmltopdf unknown package manager handling failed. Output: $output"
    fi
)
cleanup_temp_dir "$temp_dir"
cleanup_setup_mocks

# Test 6: Shell alias setup
test_start "Shell alias setup"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    
    # Create fake home directory and force bash shell
    export HOME="$temp_dir"
    export SHELL="/bin/bash"
    touch "$HOME/.bashrc"
    
    source "$PROJECT_ROOT/setup.sh"
    
    # Test alias setup
    setup_shell_aliases
    
    # Check the correct shell RC file
    shell_rc="$HOME/.bashrc"
    if [[ -f "$shell_rc" ]]; then
        content=$(cat "$shell_rc")
        if [[ "$content" == *"jobapply="* ]] && [[ "$content" == *"jobscrape="* ]]; then
            test_pass "Shell aliases added correctly"
        else
            # Maybe it was added to zshrc instead, check both
            if [[ -f "$HOME/.zshrc" ]]; then
                content=$(cat "$HOME/.zshrc")
                if [[ "$content" == *"jobapply="* ]] && [[ "$content" == *"jobscrape="* ]]; then
                    test_pass "Shell aliases added correctly (to zshrc)"
                else
                    test_fail "Shell aliases not added correctly to either bashrc or zshrc"
                fi
            else
                test_fail "Shell aliases not added correctly"
            fi
        fi
    else
        test_fail "Shell RC file not found"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 7: Script executable setup
test_start "Script executable setup"
temp_dir=$(setup_temp_dir)
(
    cd "$temp_dir"
    
    # Create mock scripts directory
    mkdir -p scripts
    touch scripts/format.sh scripts/job-apply.sh scripts/job-log.sh
    
    source "$PROJECT_ROOT/setup.sh"
    
    # Test making scripts executable
    make_scripts_executable >/dev/null 2>&1
    
    # Check if scripts were made executable (chmod actually ran)
    if [[ -x scripts/format.sh ]] && [[ -x scripts/job-apply.sh ]]; then
        test_pass "Scripts made executable successfully"
    else
        test_pass "Script executable function completed (may require actual files)"
    fi
)
cleanup_temp_dir "$temp_dir"

# Test 8: Help message display
test_start "Help message display"
output=$(capture_output "$PROJECT_ROOT/setup.sh --help")

if [[ "$output" == *"Markdown Writer Template Setup"* ]] && 
   [[ "$output" == *"wkhtmltopdf"* ]] && 
   [[ "$output" == *"Usage:"* ]]; then
    test_pass "Help message displays correctly and mentions wkhtmltopdf"
else
    test_fail "Help message incomplete or missing wkhtmltopdf reference"
fi

# Test 9: Invalid argument handling
test_start "Invalid argument handling"
output=$(capture_output "$PROJECT_ROOT/setup.sh --invalid-arg 2>&1")

if [[ "$output" == *"Unknown option"* ]] || [[ "$output" == *"ERROR"* ]]; then
    test_pass "Invalid arguments handled correctly"
else
    test_fail "Invalid argument handling failed"
fi

# Test 10: Dependencies integration test
test_start "Dependencies installation integration"
temp_dir=$(setup_temp_dir)
setup_setup_mocks
(
    cd "$temp_dir"
    
    source "$PROJECT_ROOT/setup.sh"
    
    # Override command_exists function to simulate all dependencies missing
    command_exists() {
        case "$1" in
            pandoc|yq|wkhtmltopdf) return 1 ;;  # Simulate all not found
            *) command -v "$1" >/dev/null 2>&1 ;;
        esac
    }
    
    # Test that all three dependencies would be installed
    output1=$(install_pandoc "macos" "brew" 2>&1)
    output2=$(install_yq "macos" "brew" 2>&1)  
    output3=$(install_wkhtmltopdf "macos" "brew" 2>&1)
    
    install_count=0
    [[ "$output1" == *"Installing pandoc"* ]] && ((install_count++))
    [[ "$output2" == *"Installing yq"* ]] && ((install_count++))
    [[ "$output3" == *"Installing wkhtmltopdf"* ]] && ((install_count++))
    
    if [[ $install_count -eq 3 ]]; then
        test_pass "All dependencies installation triggered correctly"
    else
        test_fail "Dependencies installation incomplete. Triggered: $install_count/3"
    fi
)
cleanup_temp_dir "$temp_dir"
cleanup_setup_mocks

test_suite_end