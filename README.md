# Homebrew Release Notes Generator

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Language-Bash-blue.svg)](https://www.gnu.org/software/bash/)
[![Homebrew](https://img.shields.io/badge/Platform-Homebrew-orange.svg)](https://brew.sh)

A powerful shell script that helps you manage outdated Homebrew formulae by generating detailed Markdown reports with release notes from GitHub.

## ✨ Features

- **Smart Formula Detection**: Automatically identifies outdated Homebrew formulae
- **Interactive Management**: Use `gum` for beautiful CLI interactions to manage ignored packages
- **GitHub Integration**: Fetches release notes directly from GitHub repositories
- **Markdown Reports**: Generates professional release notes in Markdown format
- **Batch Processing**: Handles multiple formulae efficiently
- **Timestamped Output**: Organized reports with readable timestamps
- **Error Handling**: Robust error handling and informative warnings

## 🚀 Quick Start

### Prerequisites

Before running the script, ensure you have the following tools installed:

```bash
# Install required dependencies
brew install gh jq gum

# Authenticate GitHub CLI (required for fetching release notes)
gh auth login
```

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/HubertReX/brew_check_before_upgrade.git
   cd brew_check_before_upgrade
   ```

2. **Make the script executable:**
   ```bash
   chmod +x brew-release_notes.sh
   ```

### Usage

#### Normal Execution

Run the script to check for outdated formulae and generate reports:

```bash
./brew-release_notes.sh
```

The script will:
1. Check for outdated Homebrew formulae
2. Allow you to interactively select which formulae to ignore
3. Generate detailed Markdown reports for the remaining formulae
4. Save reports in a timestamped directory (e.g., `reports_2025-01-22_14:30:45/`)

#### Testing and Debugging

For development and testing individual functions, you can source the script without triggering the full execution:

```bash
# Source the script for testing (prevents automatic execution)
BREW_RELEASE_NOTES_SOURCED=true source brew-release_notes.sh

# Now you can test individual functions:
get_repo_path "git"                    # Test repository path extraction
check_dependencies                     # Test dependency validation
log_message "Test message"             # Test logging functionality

# Example: Test repository detection for a specific package
get_repo_path "node"
# Output: github.com/nodejs/node

# Example: Generate a report for a single package
generate_update_report "git" "2.43.0" "2.44.0" "test_report.md"
```

This approach is particularly useful for:
- **Quick function testing** without waiting for the full 2+ minute execution
- **Debugging specific functionality** like repository path extraction
- **Development workflows** when modifying individual functions

## 📖 How It Works

### Workflow

1. **Dependency Check**: Verifies all required tools are installed
2. **Outdated Detection**: Uses `brew outdated --json` to find packages needing updates
3. **Interactive Filtering**: Uses `gum choose` for selecting packages to ignore
4. **Repository Discovery**: Extracts GitHub repository paths from brew formula metadata
5. **Release Notes Fetching**: Uses `gh release` commands to get version history
6. **Report Generation**: Creates timestamped Markdown reports in organized directories

### File Structure

```
brew_check_upgrade/
├── brew-release_notes.sh      # Main script
├── get_release_notes_from_gh.sh # Utility script for GitHub release notes
├── ignored_formulae.txt       # List of formulae to skip (auto-generated)
├── reports_YYYY-MM-DD_HH:MM:SS/ # Generated reports directory
│   ├── formula1_from_1.0.0.md
│   ├── formula2_from_2.1.0.md
│   └── ...
├── CLAUDE.md                  # Development guidelines
└── README.md                  # This file
```

## 🔧 Configuration

### Ignored Formulae

The script maintains an `ignored_formulae.txt` file to track packages you want to skip. You can:

- **Interactive Selection**: Choose formulae to ignore during script execution
- **Manual Editing**: Edit `ignored_formulae.txt` directly to add/remove formulae
- **Automatic Sorting**: The file is automatically sorted and deduplicated

### GitHub API Limits

The script fetches the **last 50 releases** for each repository to balance between comprehensive coverage and performance. This limit can be adjusted in the script if needed.

## 📝 Example Output

### Sample Report Structure

```markdown
# Update Report for: `example-formula`

**Generated:** 2025-01-22 14:30:45

Report covers changes from your installed version **1.0.0**.

---
## 🏷️ Version: v1.1.0

## New Features
- Added support for new configuration options
- Improved error handling and logging

## Bug Fixes
- Fixed memory leak in core module
- Resolved compatibility issues with macOS Sequoia

---
## 🏷️ Version: v1.0.1

## Bug Fixes
- Critical security patch for authentication
- Fixed crash on startup with empty config
```

## 🛠️ Troubleshooting

### Common Issues

**GitHub CLI Authentication:**
```bash
# If you get authentication errors:
gh auth login --web
```

**Missing Dependencies:**
```bash
# Install missing tools:
brew install gh jq gum
```

**Permission Issues:**
```bash
# Make script executable:
chmod +x brew-release_notes.sh
```

**No Repository Found:**
- Some formulae don't have GitHub repositories
- These are automatically skipped with informative warnings

## 🤝 Contributing

Contributions are welcome! Here are some ways you can help:

1. **Report Issues**: Found a bug? Please open an issue
2. **Feature Requests**: Have an idea? Let's discuss it
3. **Pull Requests**: Code improvements and new features are welcome
4. **Documentation**: Help improve this README or add examples

### Development Setup

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes and test thoroughly
4. Commit with clear messages: `git commit -m "feat: add new feature"`
5. Push and create a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Homebrew](https://brew.sh) - The missing package manager for macOS
- [GitHub CLI](https://cli.github.com) - Official GitHub command line tool
- [jq](https://jqlang.github.io/jq/) - Command-line JSON processor
- [gum](https://github.com/charmbracelet/gum) - Beautiful CLI interactions

## 📊 Project Status

This project is actively maintained. Feel free to star ⭐ this repository if you find it useful!

---

**Made with ❤️ for the Homebrew community**