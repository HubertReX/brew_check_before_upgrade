2#!/bin/bash

# Ustawia tryb "fail-fast" dla niezdefiniowanych zmiennych i błędów w potoku.
set -uo pipefail

# --- Główne Funkcje ---

# Wyświetla instrukcję użycia skryptu.
usage() {
  cat << EOF
Użycie: $(basename "$0")

Ten skrypt sprawdza, które z zainstalowanych formuł Homebrew są nieaktualne,
pozwala interaktywnie zarządzać listą ignorowanych formuł, a następnie
dla pozostałych generuje raport w formacie Markdown. Raport zawiera notatki
z wydań (release notes).

Wymagania:
  - Homebrew (brew)
  - GitHub CLI (gh)
  - jq
  - gum (https://github.com/charmbracelet/gum)

Plik z ignorowanymi formułami: 'ignored_formulae.txt'.
Wyniki są zapisywane w nowym katalogu o nazwie 'raporty_YYYYMMDD_HHMMSS'.
EOF
}

# Sprawdza, czy wszystkie wymagane narzędzia (brew, gh, jq, gum) są zainstalowane.
check_dependencies() {
  local missing_deps=0
  for cmd in brew gh jq gum; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "⛔ BŁĄD: Wymagane narzędzie '$cmd' nie jest zainstalowane." >&2
      missing_deps=1
    fi
  done
  [ "$missing_deps" -eq 1 ] && exit 1
}

# Pobiera ścieżkę do repozytorium GitHub na podstawie nazwy formuły.
get_repo_path() {
  local formula="$1"
  local formula_info
  formula_info=$(brew info --json=v2 --formula "$formula")
  local homepage_url
  homepage_url=$(echo "$formula_info" | jq -r '.formulae[0].homepage')
  local stable_url
  stable_url=$(echo "$formula_info" | jq -r '.formulae[0].urls.stable.url')
  local repo_path=""

  if [[ "$homepage_url" == "https://github.com/"* ]]; then
    repo_path=$(echo "$homepage_url" | sed -e 's|https://github.com/||' | cut -d'/' -f1,2)
  elif [[ "$stable_url" == "https://github.com/"* ]]; then
    repo_path=$(echo "$stable_url" | sed -e 's|https://github.com/||' | cut -d'/' -f1,2)
  fi

  if [ -n "$repo_path" ]; then
    echo "$repo_path"
    return 0
  else
    echo "⚠️ OSTRZEŻENIE: Nie udało się automatycznie ustalić repozytorium GitHub dla '$formula'." >&2
    echo "   - Sprawdzony homepage: $homepage_url" >&2
    echo "   - Sprawdzony stable URL: $stable_url" >&2
    return 1
  fi
}

# Generuje raport zmian w formacie Markdown dla pojedynczej formuły.
generate_update_report() {
  local formula="$1"
  local installed_version="$2"
  local output_file="$3"

  echo "--------------------------------------------------"
  echo "🔎 Przetwarzanie formuły: $formula (wersja: $installed_version)"

  local repo_path
  if ! repo_path=$(get_repo_path "$formula"); then
    echo "↪️  Pominięto generowanie raportu dla '$formula'."
    return
  fi
  echo "📦 Repozytorium GitHub: $repo_path"

  echo "📡 Pobieranie listy wersji z GitHub..."
  local all_tags
  all_tags=$(gh release list --repo "$repo_path" --limit 200 --json tagName,isPrerelease --jq '.[] | select(.isPrerelease | not) | .tagName')

  if [ -z "$all_tags" ]; then
    echo "⚠️ OSTRZEŻENIE: Nie znaleziono żadnych wydań w repozytorium '$repo_path'."
    return
  fi

  local versions_to_fetch
  versions_to_fetch=$(printf "%s\n%s" "$installed_version" "$all_tags" | sed 's/^v//' | sort -V | uniq | awk -v ver="$installed_version" '$0 == ver {p=1; next} p')

  if [ -z "$versions_to_fetch" ]; then
    echo "🎉 Formuła '$formula' jest aktualna. Nie ma potrzeby generowania raportu."
    return
  fi
  
  local versions_count
  versions_count=$(echo "$versions_to_fetch" | wc -l | xargs)
  echo "✨ Znaleziono $versions_count nowszych wersji. Generowanie raportu..."

  # --- Generowanie pliku Markdown ---
  {
    echo "# Raport aktualizacji dla: \`$formula\`"
    echo ""
    echo "**Wygenerowano:** $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "Raport obejmuje zmiany od Twojej zainstalowanej wersji **$installed_version**."
    echo ""
  } > "$output_file"

  while IFS= read -r version; do
    local original_tag
    original_tag=$(echo "$all_tags" | grep -E "^v?${version}$" | head -n 1)

    if [ -z "$original_tag" ]; then
      echo "⚠️ Nie można znaleźć oryginalnego tagu dla wersji '$version'."
      continue
    fi
    
    echo "    - Pobieranie notatek dla wersji $original_tag..."
    local release_notes
    release_notes=$(gh release view "$original_tag" --repo "$repo_path" --json body --jq '.body')

    {
      echo "---"
      echo "## 🏷️ Wersja: $original_tag"
      echo ""
      if [ -z "$release_notes" ]; then
        echo "*Brak notatek z wydania dla tej wersji.*"
      else
        echo "$release_notes"
      fi
      echo ""
    } >> "$output_file"
  done < <(echo "$versions_to_fetch" | sort -Vr)

  echo "✅ Gotowe! Raport został zapisany w pliku: $output_file"
}

# --- Główna Logika Skryptu ---
main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi
  
  check_dependencies
  
  local ignored_file="ignored_formulae.txt"
  touch "$ignored_file"

  echo "-i- Sprawdzanie nieaktualnych formuł Homebrew..."
  local outdated_formulae
  outdated_formulae=$(brew outdated --formulae --json | jq -r '.formulae[] | "\(.name);\(.installed_versions[0])"')

  if [ -z "$outdated_formulae" ]; then
    echo "🎉 Wszystkie formuły Homebrew są aktualne. Gratulacje!"
    exit 0
  fi

  # Wyodrębniamy same nazwy formuł, aby porównać je z listą ignorowanych
  local outdated_names
  outdated_names=$(echo "$outdated_formulae" | cut -d';' -f1)

  # Filtrujemy, aby znaleźć formuły, które nie są jeszcze ignorowane
  local candidates_to_ignore
  candidates_to_ignore=$(grep -v -x -f "$ignored_file" <(echo "$outdated_names"))

  if [ -n "$candidates_to_ignore" ]; then
    echo "-i- Znaleziono nieaktualne formuły, których nie ma na liście ignorowanych."
    local newly_ignored
    # Używamy gum do interaktywnego wyboru
    newly_ignored=$(gum choose --no-limit --header "Wybierz formuły, które chcesz dodać do listy ignorowanych:" <<< "$candidates_to_ignore")
    
    if [ -n "$newly_ignored" ]; then
      echo "$newly_ignored" >> "$ignored_file"
      # Sortujemy i usuwamy duplikaty, aby utrzymać porządek w pliku
      sort -u -o "$ignored_file" "$ignored_file"
      echo "✅ Zaktualizowano plik '$ignored_file'."
    fi
  fi
  
  # Filtrujemy ostateczną listę formuł do przetworzenia
  local formulae_to_process
  # Używamy `grep` z opcją -v (odwrócenie), -x (całe linie), -f (plik ze wzorcami)
  formulae_to_process=$(grep -v -x -f "$ignored_file" <(echo "$outdated_names") | while read -r name; do
    # Przywracamy pełne informacje (nazwa;wersja) dla pasujących formuł
    echo "$outdated_formulae" | grep "^${name};"
  done)

  if [ -z "$formulae_to_process" ]; then
    echo "✅ Wszystkie nieaktualne formuły znajdują się na liście ignorowanych. Brak raportów do wygenerowania."
    exit 0
  fi

  local out_dir="raporty_$(date +"%Y%m%d_%H%M%S")"
  mkdir -p "$out_dir"
  echo "-i- Raporty zostaną zapisane w katalogu: $out_dir"

  while IFS=';' read -r name installed_version; do
    local sanitized_name
    sanitized_name=$(echo "$name" | tr '/' '-')
    local filename="$out_dir/${sanitized_name}_od_${installed_version}.md"
    
    generate_update_report "$name" "$installed_version" "$filename"
  done <<< "$formulae_to_process"

  echo "--------------------------------------------------"
  echo "🏁 Wszystkie operacje zakończone."
}

# Uruchomienie głównej funkcji skryptu z przekazaniem wszystkich argumentów.
main "$@"

