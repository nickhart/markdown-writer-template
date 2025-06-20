# Test Suite Documentation

This directory contains comprehensive tests for the markdown-writer-template project.

## 🏗️ Test Structure

```
tests/
├── README.md                    # This documentation
├── test_framework.sh           # Custom test framework
├── unit/                       # Unit tests for individual scripts
│   ├── test_format.sh          # Tests for format.sh
│   ├── test_job_apply.sh       # Tests for job-apply.sh
│   ├── test_job_log.sh         # Tests for job-log.sh
│   └── test_job_scrape.sh      # Tests for job-scrape.sh
├── integration/                # Integration tests for workflows
│   └── test_full_workflow.sh   # End-to-end workflow tests
└── fixtures/                   # Test data and configuration files
    ├── sample_resume.md        # Sample resume for testing
    ├── test_config.yml         # Basic test configuration
    └── hierarchical_config.yml # Complex configuration for testing
```

## 🚀 Running Tests

### Run All Tests
```bash
./test.sh
```

### Run Specific Test Categories
```bash
./test.sh --unit           # Unit tests only
./test.sh --integration    # Integration tests only
```

### Run Specific Tests
```bash
./test.sh format           # Test format.sh script
./test.sh job_apply        # Test job-apply.sh script
./test.sh job_log          # Test job-log.sh script
./test.sh job_scrape       # Test job-scrape.sh script
./test.sh full_workflow    # Test complete workflows
```

### List Available Tests
```bash
./test.sh --list
```

### Clean Up Test Artifacts
```bash
./test.sh --clean
```

## 🧪 Test Framework

The project uses a custom bash-based test framework (`test_framework.sh`) that provides:

### Assertion Functions
- `assert_equals expected actual [message]`
- `assert_not_equals not_expected actual [message]`
- `assert_contains haystack needle [message]`
- `assert_file_exists file [message]`
- `assert_file_not_exists file [message]`
- `assert_dir_exists dir [message]`
- `assert_command_success command [message]`
- `assert_command_fails command [message]`

### Test Organization
- `test_suite_start "Suite Name"`
- `test_start "Test Name"`
- `test_pass [message]`
- `test_fail [message]`
- `test_skip [message]`
- `test_suite_end`

### Utilities
- `setup_temp_dir` - Create temporary directory
- `cleanup_temp_dir dir` - Remove temporary directory
- `run_in_temp_dir command` - Execute command in temp directory
- `capture_output command` - Capture command output for testing
- `mock_command command script` - Mock external commands
- `unmock_command command` - Remove command mock

### Example Test
```bash
#!/bin/bash
source tests/test_framework.sh

test_suite_start "My Test Suite"

test_start "Simple assertion test"
result=$(echo "hello world")
assert_contains "$result" "world" "Should contain 'world'"

test_start "File creation test"
temp_dir=$(setup_temp_dir)
echo "test content" > "$temp_dir/test.txt"
assert_file_exists "$temp_dir/test.txt"
cleanup_temp_dir "$temp_dir"

test_suite_end
```

## 📋 Test Coverage

### Unit Tests

#### `test_format.sh` - Format Script Tests
- ✅ Configuration file discovery
- ✅ YAML configuration parsing
- ✅ Hierarchical pandoc options
- ✅ Basic file formatting
- ✅ Batch file processing
- ✅ Error handling for missing files
- ✅ Format override functionality
- ✅ Directory creation
- ✅ Help message display
- ✅ Invalid arguments handling

#### `test_job_apply.sh` - Job Application Tests
- ✅ Directory name sanitization
- ✅ Template variable replacement
- ✅ Application directory structure creation
- ✅ Resume template selection
- ✅ Metadata generation
- ✅ List templates functionality
- ✅ Invalid template handling
- ✅ Missing required arguments
- ✅ Help message display
- ✅ Job posting download (mocked)

#### `test_job_log.sh` - Job Logging Tests
- ✅ Application status listing
- ✅ Status summary generation
- ✅ Report generation
- ✅ Application status movement
- ✅ CSV export functionality
- ✅ Help message display
- ✅ Invalid command handling
- ✅ Metadata field extraction

#### `test_job_scrape.sh` - Job Scraping Tests
- ✅ URL domain extraction
- ✅ Company name extraction from URL
- ✅ Filename sanitization
- ✅ Job posting scraping (mocked)
- ✅ Information extraction
- ✅ List scraped postings
- ✅ Invalid URL handling
- ✅ Missing URL handling
- ✅ Help message display
- ✅ Custom output file path

### Integration Tests

#### `test_full_workflow.sh` - Complete Workflow Tests
- ✅ Complete job application workflow
- ✅ Application status management workflow
- ✅ Document formatting workflow
- ✅ Configuration hierarchy workflow
- ✅ End-to-end job search workflow

## 🔧 Mocking System

The test framework includes a sophisticated mocking system for external dependencies:

### Available Mocks
- `pandoc` - Document conversion (creates dummy output files)
- `curl` - HTTP requests (returns mock HTML content)
- `yq` - YAML processing (returns configurable values)

### Mock Usage
```bash
# Setup mocks
mock_command "pandoc" 'touch "$4"; exit 0'
mock_command "curl" 'echo "<html>Mock content</html>" > "$4"; exit 0'

# Your test code here

# Cleanup mocks
unmock_command "pandoc"
unmock_command "curl"
```

## 🔄 Continuous Integration

Tests are automatically run in GitHub Actions with multiple jobs:

### `test-setup` Job
- Tests setup script functionality
- Validates directory structure
- Checks script permissions
- Verifies configuration files

### `test-with-dependencies` Job
- Installs pandoc and dependencies
- Tests actual document formatting
- Validates job application workflow

### `run-tests` Job
- Runs complete test suite
- Tests individual components
- Validates all functionality

## ⚠️ Test Dependencies

### Required
- `bash` 4.0+ (for associative arrays and modern features)
- `yq` (for YAML parsing in tests)

### Optional (for enhanced testing)
- `pandoc` (for actual document conversion testing)
- `curl` (for real HTTP request testing)
- `librsvg2-bin` (for SVG conversion testing)

### Installing Dependencies
```bash
# Run setup script to install all dependencies
./setup.sh

# Or install manually
brew install pandoc yq librsvg     # macOS
sudo apt install pandoc librsvg2-bin && sudo snap install yq  # Ubuntu
```

## 🐛 Debugging Tests

### Verbose Mode
```bash
./test.sh --verbose    # Enable bash debug mode
```

### Individual Test Debugging
```bash
# Run specific test with debug output
bash -x tests/unit/test_format.sh
```

### Test Artifacts
Test artifacts are automatically cleaned up, but you can inspect them:
- Temporary directories: `/tmp/tmp.*`
- Mock command logs: `/tmp/pandoc_calls.log`
- Mock commands: `/tmp/markdown-writer-mocks/`

### Common Issues
1. **Permission errors**: Ensure all scripts are executable (`chmod +x`)
2. **Missing dependencies**: Run `./setup.sh` or install manually
3. **Path issues**: Tests expect to run from project root directory
4. **Mock conflicts**: Run `./test.sh --clean` to reset

## 📈 Adding New Tests

### 1. Create Test File
```bash
# For unit tests
cp tests/unit/test_format.sh tests/unit/test_newscript.sh

# For integration tests
cp tests/integration/test_full_workflow.sh tests/integration/test_new_workflow.sh
```

### 2. Implement Tests
```bash
#!/bin/bash
source tests/test_framework.sh

test_suite_start "New Script Tests"

test_start "Basic functionality"
# Your test implementation
assert_equals "expected" "actual"

test_suite_end
```

### 3. Make Executable
```bash
chmod +x tests/unit/test_newscript.sh
```

### 4. Run New Tests
```bash
./test.sh newscript
```

## 🎯 Best Practices

### Test Organization
- **One test file per script** for unit tests
- **One test file per workflow** for integration tests
- **Group related assertions** in logical test cases
- **Use descriptive test names** that explain what's being tested

### Assertion Guidelines
- **Test one thing at a time** - don't combine multiple assertions unnecessarily
- **Provide meaningful messages** for failed assertions
- **Test both success and failure cases**
- **Use appropriate assertion types** (file_exists vs equals)

### Resource Management
- **Always clean up temporary files** and directories
- **Use the provided utilities** (`setup_temp_dir`, `cleanup_temp_dir`)
- **Mock external dependencies** to avoid side effects
- **Don't rely on external services** in tests

### Error Handling
- **Test error conditions** as thoroughly as success conditions
- **Verify error messages** are helpful and accurate
- **Test edge cases** and boundary conditions
- **Handle missing dependencies gracefully**

This comprehensive test suite ensures the reliability and maintainability of the markdown-writer-template project!