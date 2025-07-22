# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Homebrew package management utility that helps users manage outdated formulae by:
1. Checking for outdated Homebrew formulae
2. Interactive management of ignored packages via `gum` CLI tool
3. Generating detailed Markdown reports with release notes from GitHub

## Key Files

- `brew-release_notes.sh` - Main script that orchestrates the entire process
- `get_release_notes_from_gh.sh` - Simple utility script for fetching GitHub release notes
- `ignored_formulae.txt` - List of formulae to skip during updates

## Dependencies

Required tools that must be installed:
- `brew` (Homebrew)
- `gh` (GitHub CLI) 
- `jq` (JSON processor)
- `gum` (interactive CLI tool from Charm)

## Script Architecture

The main script (`brew-release_notes.sh`) follows this workflow:
1. **Dependency Check** - Validates all required tools are installed
2. **Outdated Detection** - Uses `brew outdated --json` to find packages needing updates
3. **Interactive Filtering** - Uses `gum choose` for selecting packages to ignore
4. **Repository Discovery** - Extracts GitHub repo paths from brew formula metadata
5. **Release Notes Fetching** - Uses `gh release` commands to get version history
6. **Report Generation** - Creates timestamped Markdown reports in `raporty_YYYYMMDD_HHMMSS/` directories

## Key Functions

- `get_repo_path()` - Extracts GitHub repository path from brew formula info
- `generate_update_report()` - Creates detailed Markdown report for a single formula
- Version comparison uses `sort -V` for semantic versioning

## Development Notes

- All user-facing messages and output are in English
- Error handling with `set -uo pipefail` for robust execution
- Output files use sanitized names (`tr '/' '-'`) for filesystem compatibility
- Reports include version history sorted in reverse chronological order
- Output directories use English naming: `reports_YYYYMMDD_HHMMSS/` format