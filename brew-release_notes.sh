#!/bin/bash

# Sets "fail-fast" mode for undefined variables and pipeline errors.
set -uo pipefail

# --- Main Functions ---

# Displays the script usage instructions.
usage() {
  cat << EOF
Usage: $(basename "$0")

This script checks which explicitly installed Homebrew formulae and casks are outdated,
allows interactive management of the ignored packages list, and then
generates Markdown reports for the remaining ones. The report contains
release notes.

Requirements:
  - Homebrew (brew)
  - GitHub CLI (gh)
  - jq
  - gum (https://github.com/charmbracelet/gum)

Ignored packages file: 'ignored_formulae.txt'.
Results are saved in a new directory named 'reports_YYYY-MM-DD_HH:MM:SS'.
EOF
}

# Checks if all required tools (brew, gh, jq, gum) are installed.
check_dependencies() {
  local missing_deps=0
  for cmd in brew gh jq gum; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "⛔ ERROR: Required tool '$cmd' is not installed." >&2
      missing_deps=1
    fi
  done
  [ "$missing_deps" -eq 1 ] && exit 1
}

# Gets the GitHub repository path based on the package name (formula or cask).
get_repo_path() {
  local package="$1"
  local package_info
  local homepage_url
  local stable_url
  local repo_path=""
  
  # Try as formula first
  if package_info=$(brew info --json=v2 --formula "$package" 2>/dev/null) && [ "$(echo "$package_info" | jq -r '.formulae | length')" -gt 0 ]; then
    homepage_url=$(echo "$package_info" | jq -r '.formulae[0].homepage')
    stable_url=$(echo "$package_info" | jq -r '.formulae[0].urls.stable.url')
  # Try as cask if formula failed
  elif package_info=$(brew info --json=v2 --cask "$package" 2>/dev/null) && [ "$(echo "$package_info" | jq -r '.casks | length')" -gt 0 ]; then
    homepage_url=$(echo "$package_info" | jq -r '.casks[0].homepage')
    stable_url=""  # Casks don't have stable URLs in the same way
  else
    echo "⚠️ WARNING: Could not get info for package '$package'." >&2
    return 1
  fi

  if [[ "$homepage_url" == "https://github.com/"* ]]; then
    repo_path=$(echo "$homepage_url" | sed -e 's|https://github.com/||' | cut -d'/' -f1,2)
  elif [[ "$stable_url" == "https://github.com/"* ]]; then
    repo_path=$(echo "$stable_url" | sed -e 's|https://github.com/||' | cut -d'/' -f1,2)
  fi

  if [ -n "$repo_path" ]; then
    echo "$repo_path"
    return 0
  else
    echo "⚠️ WARNING: Could not automatically determine GitHub repository for '$package'." >&2
    echo "   - Checked homepage: $homepage_url" >&2
    if [ -n "$stable_url" ]; then
      echo "   - Checked stable URL: $stable_url" >&2
    fi
    return 1
  fi
}

# Generates a Markdown changelog report for a single package (formula or cask).
generate_update_report() {
  local package="$1"
  local installed_version="$2"
  local latest_version="$3"
  local output_file="$4"

  echo "--------------------------------------------------"
  echo "🔎 Processing package: $package (version: $installed_version)"

  local repo_path
  if ! repo_path=$(get_repo_path "$package"); then
    echo "↪️  Skipped report generation for '$package'."
    return
  fi
  echo "📦 GitHub repository: $repo_path"

  echo "📡 Fetching version list from GitHub..."
  local all_tags
  all_tags=$(gh release list --repo "$repo_path" --json tagName,isPrerelease --jq '.[] | select(.isPrerelease | not) | .tagName')

  if [ -z "$all_tags" ]; then
    echo "⚠️ WARNING: No releases found in repository '$repo_path'."
    return
  fi

  local versions_to_fetch
  versions_to_fetch=$(printf "%s\n%s" "$installed_version" "$all_tags" | sed 's/^v//' | sort -V | uniq | awk -v ver="$installed_version" '$0 == ver {p=1; next} p')

  if [ -z "$versions_to_fetch" ]; then
    echo "🎉 Package '$package' is up to date. No need to generate a report."
    return
  fi
  
  local versions_count
  versions_count=$(echo "$versions_to_fetch" | wc -l | xargs)
  echo "✨ Found $versions_count newer versions. Generating report..."

  # --- Generating Markdown file ---
  {
    echo "# Update Report for: \`$package\`"
    echo ""
    echo "**Generated:** $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "Report covers changes from your installed version **$installed_version**."
    echo ""
  } > "$output_file"

  while IFS= read -r version; do
    local original_tag
    original_tag=$(echo "$all_tags" | grep -E "^v?${version}$" | head -n 1)

    if [ -z "$original_tag" ]; then
      echo "⚠️ Cannot find original tag for version '$version'."
      continue
    fi
    
    echo "    - Fetching notes for version $original_tag..."
    local release_notes
    release_notes=$(gh release view "$original_tag" --repo "$repo_path" --json body --jq '.body')

    {
      echo "---"
      echo "## 🏷️ Version: $original_tag"
      echo ""
      if [ -z "$release_notes" ]; then
        echo "*No release notes available for this version.*"
      else
        echo "$release_notes"
      fi
      echo ""
    } >> "$output_file"
  done < <(echo "$versions_to_fetch" | sort -Vr)

  echo "✅ Done! Report saved to file: $output_file"
}

# --- Main Script Logic ---
main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi
  
  check_dependencies
  
  local ignored_file="ignored_formulae.txt"
  touch "$ignored_file"

  echo "🔍 Checking outdated Homebrew formulae..."
  local outdated_formulae
  outdated_formulae=$(brew outdated --formulae --json | jq -r '.formulae[] | "\(.name);\(.installed_versions[0])"')
  
  echo "🎯 Filtering for explicitly installed formulae only..."
  local explicitly_installed
  explicitly_installed=$(brew list --formulae --installed-on-request)
  
  # Filter outdated formulae to include only those explicitly installed
  local filtered_outdated=""
  while IFS=';' read -r name version; do
    if echo "$explicitly_installed" | grep -q "^${name}$"; then
      if [ -n "$filtered_outdated" ]; then
        filtered_outdated="${filtered_outdated}\n${name};${version}"
      else
        filtered_outdated="${name};${version}"
      fi
    fi
  done <<< "$outdated_formulae"
  
  outdated_formulae="$filtered_outdated"

  echo "📦 Checking outdated Homebrew casks..."
  local outdated_casks
  outdated_casks=$(brew outdated --cask --json | jq -r '.casks[] | "\(.name);\(.installed_versions[0])"')
  
  if [ -n "$outdated_casks" ]; then
    echo "✨ All casks are treated as explicitly installed (no dependency filtering needed)..."
    # Combine formulae and casks
    if [ -n "$outdated_formulae" ]; then
      outdated_formulae="${outdated_formulae}\n${outdated_casks}"
    else
      outdated_formulae="$outdated_casks"
    fi
  fi

  if [ -z "$outdated_formulae" ]; then
    echo "🎉 All explicitly installed Homebrew formulae and casks are up to date. Congratulations!"
    exit 0
  fi

  # Extract package names only to compare with ignored list
  local outdated_names
  outdated_names=$(echo -e "$outdated_formulae" | cut -d';' -f1)

  # Filter to find packages that are not yet ignored
  local candidates_to_ignore
  candidates_to_ignore=$(grep -v -x -f "$ignored_file" <(echo -e "$outdated_names"))

  if [ -n "$candidates_to_ignore" ]; then
    echo "🔔 Found outdated packages not on the ignore list."
    local newly_ignored
    # Use gum for interactive selection
    newly_ignored=$(gum choose --no-limit --header "Select packages to add to the ignore list:" <<< "$candidates_to_ignore")
    
    if [ -n "$newly_ignored" ]; then
      echo "$newly_ignored" >> "$ignored_file"
      # Sort and remove duplicates to maintain file order
      sort -u -o "$ignored_file" "$ignored_file"
      echo "✅ Updated file '$ignored_file'."
    fi
  fi
  
  # Filter final list of packages to process
  local packages_to_process
  # Use `grep` with -v (invert), -x (whole lines), -f (pattern file)
  packages_to_process=$(grep -v -x -f "$ignored_file" <(echo -e "$outdated_names") | while read -r name; do
    # Restore full information (name;version) for matching packages
    echo -e "$outdated_formulae" | grep "^${name};"
  done)

  if [ -z "$packages_to_process" ]; then
    echo "✅ All outdated packages are on the ignore list. No reports to generate."
    exit 0
  fi

  local out_dir="reports_$(date +"%Y-%m-%d_%H:%M:%S")"
  mkdir -p "$out_dir"
  echo "📂 Reports will be saved in directory: $out_dir"

  while IFS=';' read -r name installed_version; do
    echo "🔍 Getting latest version for $name..."
    local latest_version
    latest_version=$(brew info --json=v2 --formula "$name" 2>/dev/null | jq -r '.formulae[0].versions.stable' || \
                    brew info --json=v2 --cask "$name" 2>/dev/null | jq -r '.casks[0].version')
    
    if [ -z "$latest_version" ] || [ "$latest_version" = "null" ]; then
      echo "⚠️ Could not determine latest version for $name, using 'latest'"
      latest_version="latest"
    fi
    
    local sanitized_name
    sanitized_name=$(echo "$name" | tr '/' '-')
    local filename="$out_dir/${sanitized_name}_from_${installed_version}_to_${latest_version}.md"
    
    generate_update_report "$name" "$installed_version" "$latest_version" "$filename"
  done <<< "$packages_to_process"

  echo "--------------------------------------------------"
  echo "🏁 All operations completed."
}

# Run the main script function with all arguments passed through.
main "$@"

