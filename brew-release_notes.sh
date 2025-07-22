#!/bin/bash

# Ustawia tryb "fail-fast", aby skrypt przerywał działanie w przypadku błędu,
# niezdefiniowanej zmiennej lub błędu w potoku poleceń.
# set -euo pipefail
set -uo pipefail

# --- Główne Funkcje ---

# Wyświetla instrukcję użycia skryptu.
usage() {
  cat << EOF
Użycie: $(basename "$0")

Ten skrypt sprawdza, które z zainstalowanych formuł Homebrew są nieaktualne,
a następnie dla każdej z nich generuje raport w formacie Markdown. Raport
zawiera notatki z wydań (release notes) dla wszystkich wersji pomiędzy
zainstalowaną a najnowszą dostępną.

Wymagania:
  - Homebrew (brew)
  - GitHub CLI (gh)
  - jq

Wyniki są zapisywane w nowym katalogu o nazwie 'raporty_YYYYMMDD_HHMMSS'.
EOF
}

# Sprawdza, czy wszystkie wymagane narzędzia (brew, gh, jq) są zainstalowane.
check_dependencies() {
  local missing_deps=0
  echo before
  for cmd in brew gh jq; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "⛔ BŁĄD: Wymagane narzędzie '$cmd' nie jest zainstalowane." 
      missing_deps=1
    fi
  done
  echo Test: $missing_deps
  [ "$missing_deps" -eq 1 ] && exit 1
}

# Pobiera ścieżkę do repozytorium GitHub na podstawie nazwy formuły.
# Zwraca ścieżkę w formacie 'wlasciciel/repozytorium'.
get_repo_path() {
  local formula="$1"
  local repo_url
  
  # Używamy `brew info` do znalezienia URL strony głównej, która jest najbardziej
  # wiarygodnym źródłem informacji o repozytorium.
  repo_url=$(brew info --json=v2 --formula "$formula" | jq -r '.formulae[0].homepage')

  # Weryfikujemy, czy URL pochodzi z GitHub i wyciągamy ścieżkę.
  if [[ "$repo_url" == "https://github.com/"* ]]; then
    # Usuwa prefix "https://github.com/" i ewentualne końcowe ukośniki.
    echo "$repo_url" | sed -e 's|https://github.com/||' -e 's|/$||'
  else
    echo "⚠️ OSTRZEŻENIE: Nie udało się automatycznie ustalić repozytorium GitHub dla '$formula' ze strony głównej: $repo_url" >&2
    return 1
  fi
}

# Generuje raport zmian w formacie Markdown dla pojedynczej formuły.
# Argumenty: 1: nazwa formuły, 2: zainstalowana wersja, 3: ścieżka do pliku wyjściowego.
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
  # Pobieramy do 200 ostatnich wydań, ignorując wersje pre-release.
  all_tags=$(gh release list --repo "$repo_path" --limit 200 --json tagName,isPrerelease --jq '.[] | select(.isPrerelease | not) | .tagName')

  if [ -z "$all_tags" ]; then
    echo "⚠️ OSTRZEŻENIE: Nie znaleziono żadnych wydań w repozytorium '$repo_path'."
    return
  fi

  # Logika do znalezienia nowszych wersji:
  # 1. Tworzymy listę łączącą wersję zainstalowaną i wszystkie tagi.
  # 2. Usuwamy prefiks 'v' z tagów dla spójnego sortowania.
  # 3. Sortujemy wersje za pomocą `sort -V` (sortowanie numerów wersji).
  # 4. Używamy `awk` do znalezienia linii z naszą wersją i wydrukowania wszystkich kolejnych.
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

  # Iterujemy po nowszych wersjach, od najnowszej do najstarszej.
  while IFS= read -r version; do
    # Znajdujemy oryginalny tag (z 'v' lub bez), który pasuje do numeru wersji.
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
      # Jeśli notatki są puste, dodajemy stosowny komunikat.
      if [ -z "$release_notes" ]; then
        echo "*Brak notatek z wydania dla tej wersji.*"
      else
        echo "$release_notes"
      fi
      echo ""
    } >> "$output_file"

  done < <(echo "$versions_to_fetch" | sort -Vr) # sort -Vr odwraca kolejność sortowania

  echo "✅ Gotowe! Raport został zapisany w pliku: $output_file"
}

# --- Główna Logika Skryptu ---

main() {
  # Jeśli podano argument -h lub --help, wyświetl pomoc.
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi
  
  check_dependencies
  
  echo "-i- Sprawdzanie nieaktualnych formuł Homebrew..."
  # Używamy `brew outdated` z wyjściem JSON, aby uzyskać listę przestarzałych formuł.
  local outdated_formulae
  outdated_formulae=$(brew outdated --formulae --json | jq -r '.formulae[] | "\(.name);\(.installed_versions[0])"')

  if [ -z "$outdated_formulae" ]; then
    echo "🎉 Wszystkie formuły Homebrew są aktualne. Gratulacje!"
    exit 0
  fi

  local out_dir="raporty_$(date +"%Y%m%d_%H%M%S")"
  mkdir -p "$out_dir"
  echo "-i- Raporty zostaną zapisane w katalogu: $out_dir"

  # Przetwarzamy każdą nieaktualną formułę.
  while IFS=';' read -r name installed_version; do
    # Zastępujemy ukośniki w nazwie formuły, aby uniknąć problemów z systemem plików.
    local sanitized_name
    sanitized_name=$(echo "$name" | tr '/' '-')
    local filename="$out_dir/${sanitized_name}_od_${installed_version}.md"
    
    generate_update_report "$name" "$installed_version" "$filename"

  done <<< "$outdated_formulae"

  echo "--------------------------------------------------"
  echo "🏁 Wszystkie operacje zakończone."
}

# Uruchomienie głównej funkcji skryptu z przekazaniem wszystkich argumentów.
main "$@"

