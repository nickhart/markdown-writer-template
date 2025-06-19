# Markdown Writer Template

> A complete, production-ready template for markdown-first writing workflows with automated job application management.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Template](https://img.shields.io/badge/Template-Use%20This-brightgreen.svg)](https://github.com/yourusername/markdown-writer-template/generate)

## ✨ Features

### 📝 Markdown-First Writing
- Write everything in Markdown with automatic conversion to DOCX, PDF, and HTML
- Directory-specific formatting configurations
- Professional templates for resumes, cover letters, and more
- Git hooks for automatic formatting on commit

### 🎯 Job Application Workflow
- **One-command application setup** - Create complete application packages instantly
- **Resume templates** - Multiple professional resume formats (general, mobile, frontend, backend)
- **Smart cover letter generation** - Template-based with automatic customization
- **Job posting archival** - Download and convert job postings to PDF
- **Application tracking** - Organize applications by status with metadata

### 🔧 Developer Experience
- **Cross-platform setup** - Works on macOS and Linux with automatic dependency installation
- **Shell integration** - Convenient aliases for common operations
- **VSCode integration** - Optimized settings and recommended extensions
- **Production-ready** - Comprehensive error handling and logging

## 🚀 Quick Start

### Option 1: Use GitHub Template
1. Click the "Use this template" button above
2. Clone your new repository
3. Run the setup script

### Option 2: Clone and Setup
```bash
git clone https://github.com/yourusername/markdown-writer-template.git my-writing-project
cd my-writing-project
./setup.sh
```

### Option 3: Direct Installation
```bash
curl -sSL https://raw.githubusercontent.com/yourusername/markdown-writer-template/main/setup.sh | bash
```

## 📁 Directory Structure

```
markdown-writer-template/
├── 📄 setup.sh                     # One-command setup script
├── 📁 scripts/                     # All automation scripts
│   ├── format.sh                   # Markdown → DOCX/PDF/HTML converter
│   ├── job-apply.sh               # Complete job application workflow
│   ├── job-scrape.sh              # Job posting scraper
│   ├── job-log.sh                 # Application tracker
│   └── pre-commit                 # Git hook for auto-formatting
├── 📁 templates/                   # Document templates
│   ├── default_cover_letter.md    # Cover letter template
│   ├── reference.docx             # DOCX formatting template
│   └── resumes/                   # Resume templates
│       ├── general.md             # General purpose resume
│       ├── mobile.md              # Mobile developer resume
│       ├── frontend.md            # Frontend developer resume
│       └── backend.md             # Backend developer resume
├── 📁 applications/                # Job applications by status
│   ├── active/                    # Applications in progress
│   │   └── company_role_date/     # Individual application folders
│   │       ├── resume.md          # Customized resume
│   │       ├── cover_letter.md    # Customized cover letter
│   │       ├── job_description.pdf # Job posting
│   │       ├── .application.yml   # Application metadata
│   │       └── formatted/         # Generated documents
│   ├── submitted/                 # Awaiting response
│   ├── interviews/                # Interview stage
│   ├── offers/                    # Job offers received
│   ├── rejected/                  # Rejected applications
│   └── archive/                   # Completed applications
├── 📁 resumes/                     # General resume storage
├── 📁 cover_letters/               # General cover letter storage
├── 📁 blog/                        # Blog posts (HTML output)
├── 📁 interviews/                  # Interview preparation
└── 📁 job_postings/                # Scraped job postings
```

## 🎯 Job Application Workflow

### Create a New Application
```bash
# Interactive mode (recommended for first use)
./scripts/job-apply.sh --interactive

# Command line mode
./scripts/job-apply.sh -c "Stripe" -r "Engineering Manager" -t "general" -u "https://stripe.com/jobs/123"

# Using aliases (after setup)
jobapply -c "Acme Corp" -r "Senior Developer" -t "mobile"
```

**What this does:**
1. 📁 Creates organized directory: `applications/active/stripe_engineering_manager_june_2025/`
2. 📄 Copies and customizes resume from template
3. ✉️ Generates personalized cover letter
4. 📥 Downloads job posting as PDF (if URL provided)
5. 📊 Creates application metadata for tracking
6. 🔄 Auto-formats all documents to DOCX and PDF

### Track Your Applications
```bash
# Show status summary
./scripts/job-log.sh status

# List applications by status
./scripts/job-log.sh list active
./scripts/job-log.sh list submitted

# Generate comprehensive report
./scripts/job-log.sh report --output applications_report.md

# Move application to new status
./scripts/job-log.sh move stripe_engineering_manager_june_2025 submitted

# Export data for analysis
./scripts/job-log.sh export csv applications_2025.csv
```

### Scrape Job Postings
```bash
# Scrape and convert job posting to PDF
./scripts/job-scrape.sh "https://company.com/jobs/senior-engineer"

# With custom details
./scripts/job-scrape.sh "https://jobs.example.com/posting" -c "TechCorp" -r "Senior Developer"

# List all scraped postings
./scripts/job-scrape.sh --list
```

## 📝 Document Formatting

### Format Individual Files
```bash
# Format using directory configuration
./scripts/format.sh resume.md

# Override output format
./scripts/format.sh resume.md --format pdf

# Specify output location
./scripts/format.sh resume.md --output /path/to/resume.pdf
```

### Format Multiple Files
```bash
# Format all markdown files in current directory
./scripts/format.sh --all

# Format all files in specific directory
./scripts/format.sh --all --dir ./resumes

# Force specific format for all files
./scripts/format.sh --all --format html
```

### Shell Aliases (available after setup)
```bash
# Document formatting
mdformat resume.md              # Format using config
md2docx resume.md              # Force DOCX output
md2pdf resume.md               # Force PDF output
md2html blog_post.md           # Force HTML output

# Job application workflow
jobapply                       # Interactive application setup
jobscrape [URL]               # Scrape job posting
joblog status                 # Show application status
jobstatus                     # Alias for job status

# Quick file creation
newresume                     # Create new resume from template
newcover                      # Create new cover letter
```

## ⚙️ Configuration

### Global Configuration (`.writer-config.yml`)
```yaml
# Default output format
default_format: docx

# Pandoc options for each format
pandoc_options:
  docx: "--reference-doc=reference.docx"
  html: "--no-highlight --wrap=none -t html"
  pdf: "--pdf-engine=xelatex"

# Shell integration
shell_aliases: true
auto_format: true

# Job application settings
job_log_path: "job_applications.md"
templates:
  resume_default: "templates/resumes/general.md"
  cover_letter_default: "templates/default_cover_letter.md"
```

### Directory-Specific Configuration
Place `.writer-config.yml` in any directory to override global settings:

```yaml
# Example: Blog configuration for HTML output
format: html
pandoc_options: "--no-highlight --wrap=none -t html"
auto_format: true
```

```yaml
# Example: Resume configuration for DOCX output
format: docx
reference_doc: reference.docx
pandoc_options: "--reference-doc=reference.docx"
auto_format: true
```

## 🔧 Template Variables

The following variables are automatically replaced in templates:

- `{{COMPANY_NAME}}` → Company name
- `{{ROLE_TITLE}}` → Job role/position
- `{{APPLICATION_DATE}}` → Full date (e.g., "June 19, 2025")
- `{{MONTH_YEAR}}` → Month and year (e.g., "June 2025")

### Example Template Usage
```markdown
# Cover Letter for {{ROLE_TITLE}} at {{COMPANY_NAME}}

Dear Hiring Manager,

I am writing to express my interest in the {{ROLE_TITLE}} position at {{COMPANY_NAME}}. 

With my experience in software development, I believe I would be a great fit for your team.

Sincerely,
[Your Name]

*Application submitted: {{APPLICATION_DATE}}*
```

## 📦 Dependencies

### Required
- **pandoc** - Document conversion engine
- **yq** - YAML processing (for configuration)
- **librsvg** - SVG image conversion support (for PDF generation)

### Optional (for enhanced features)
- **curl** - Job posting downloads
- **git** - Version control and hooks

### Installation
The setup script automatically installs dependencies:

```bash
# macOS (via Homebrew)
brew install pandoc yq librsvg

# Ubuntu/Debian
sudo apt install pandoc librsvg2-bin
sudo snap install yq

# Arch Linux
sudo pacman -S pandoc librsvg
yay -S yq
```

## 🔄 Git Integration

### Automatic Formatting
Git hooks automatically format markdown files on commit:

```bash
# Files are formatted automatically
git add resume.md
git commit -m "Update resume"

# Skip auto-formatting if needed
git commit --no-verify -m "Skip formatting"
```

### Pre-commit Hook Features
- ✅ Detects changed `.md` files
- 🔄 Runs format script automatically
- 📁 Stages newly formatted files
- ⚠️ Continues even if formatting fails (non-blocking)

## 🎨 Customization

### Adding New Resume Templates
1. Create new template in `templates/resumes/`
2. Use template variables for personalization
3. Test with job-apply.sh script

### Custom Reference Documents
1. Create Word document with your preferred formatting
2. Save as `reference.docx` in appropriate directory
3. Update configuration to reference your template

### VSCode Integration
The template includes optimized VSCode settings:

```json
{
  "markdown.preview.breaks": true,
  "markdown.preview.linkify": true,
  "files.associations": {
    "*.md": "markdown"
  }
}
```

## 📊 Application Tracking

### Status Workflow
```
active → submitted → interviews → offers
   ↓         ↓           ↓
rejected  rejected   rejected
   ↓         ↓           ↓
archive   archive    archive
```

### Metadata Fields
Each application includes structured metadata:

```yaml
company: "Stripe"
role: "Engineering Manager"
template_used: "general"
job_url: "https://stripe.com/jobs/123"
application_date: "2025-06-19"
status: "active"
files:
  resume: "resume.md"
  cover_letter: "cover_letter.md"
  job_posting: "job_description.pdf"
notes: ""
```

## 🤝 Contributing

This is a template repository designed to be forked and customized. However, if you have improvements that would benefit everyone:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Related Projects

- [Pandoc](https://pandoc.org/) - Universal document converter
- [yq](https://github.com/mikefarah/yq) - YAML processor

## ❓ FAQ

**Q: Can I use this without the job application features?**  
A: Yes! The formatting system works independently. Just use the `format.sh` script for document conversion.

**Q: How do I customize the resume templates?**  
A: Edit the files in `templates/resumes/` or create new ones. Use template variables for personalization.

**Q: What if pandoc isn't available on my system?**  
A: The setup script will attempt to install it automatically. If that fails, install manually from [pandoc.org](https://pandoc.org/installing.html).

**Q: Can I add my own document formats?**  
A: Yes! Pandoc supports many formats. Update the configuration and format script as needed.

**Q: How do I backup my applications?**  
A: The entire `applications/` directory can be backed up. Consider using git for version control.

**Q: I'm getting "rsvg-convert not found" errors when downloading job postings**  
A: Install librsvg for SVG support: `brew install librsvg` (macOS) or `sudo apt install librsvg2-bin` (Linux).

**Q: PDF conversion fails with "pdflatex not found"**  
A: This is normal for web pages with complex formatting. The system automatically falls back to HTML format.

**Q: Job posting downloads are saved as HTML instead of PDF**  
A: This happens when the web page contains SVG images or complex formatting that pandoc can't convert. HTML format preserves all content.

## 🆘 Support

- 📖 Check this README for comprehensive documentation
- 🐛 Report issues on GitHub
- 💡 Request features via GitHub issues
- 📧 Contact: [your-email@example.com]

---

**Made with ❤️ for productive writing workflows**

*Last updated: June 19, 2025*