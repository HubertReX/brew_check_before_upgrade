#!/bin/bash

# Sprawdza aktualizacje dla formuły Homebrew i generuje raport ze zmianami.
# Użycie: brew-check-updates <nazwa_formuły>
brew-check-updates() {
  echo "-------------------------------------"
  echo "$1"
  echo "-------------------------------------"
  # --- Krok 1: Walidacja i sprawdzenie zależności ---
  local formula="$1"
  local file_name="$2"
  if [ -z "$formula" ] || [ -z "$file_name" ]; then
    echo "⛔ BŁĄD: Podaj nazwę formuły i nazwę pliku."
    echo "Użycie: $0 <nazwa_formuły> <nazwa_pliku>"
    return 1
  fi

  for cmd in brew gh jq; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "⛔ BŁĄD: Wymagane narzędzie '$cmd' nie jest zainstalowane."
      return 1
    fi
  done

  echo "🔍 Sprawdzanie formuły: $formula..."

  # --- Krok 2: Pobranie informacji o wersji i repozytorium ---
  local installed_info
  installed_info=$(brew list --versions "$formula")
  if [ -z "$installed_info" ]; then
    echo "INFO: Formuła '$formula' nie jest zainstalowana. Nie ma czego porównywać."
    return 0
  fi

  # Wyciąga ostatnie słowo (numer wersji)
  local current_version
  current_version=$(echo "$installed_info" | awk '{print $NF}')
  echo "✅ Zainstalowana wersja: $current_version"

  local repo_path
  repo_url=$(brew info --json=v2 --formula "$formula" | jq -r '.formulae[0].urls.stable.url')
  full_repo_path=$(brew info --json=v2 --formula "$formula" | jq -r '.formulae[0].homepage')
  repo_path=$(brew info --json=v2 --formula "$formula" | jq -r '.formulae[0].homepage' | cut -d'/' -f4,5 2>/dev/null)
  # repo_url=$(brew info --json=v2 --formula "$formula" | jq -r '.formulae[0].urls.stable.url' | cut -d'/' -f4,5 2>/dev/null)
  if [ -z "$repo_path" ]; then
    echo "⛔ BŁĄD: Nie udało się odnaleźć repozytorium GitHub dla '$formula'."
    return 1
  fi
  echo "📦 Repozytorium GitHub: $repo_url"
  echo "📦 Repozytorium GitHub: $full_repo_path"
  echo "📦 Repozytorium GitHub: $repo_path"

  # --- Krok 3: Pobranie i filtrowanie releasów z GitHub ---
  echo "📡 Pobieranie listy wszystkich wersji z GitHub..."
  # Używamy --limit 100 aby pobrać więcej niż domyślne 30
  local all_tags
  all_tags=$(gh release list --repo "$repo_path" --limit 100 --json tagName,isPrerelease --jq '.[] | select(.isPrerelease | not).tagName')
  if [ -z "$all_tags" ]; then
    echo "⛔ BŁĄD: Nie znaleziono żadnych wydań (releases) w repozytorium '$repo_path'."
    return 1
  fi
  
  # Logika do znalezienia nowszych wersji
  # 1. Usuwamy 'v' z prefixu dla poprawnego sortowania
  # 2. Łączymy zainstalowaną wersję z listą wszystkich tagów
  # 3. Sortujemy je numerycznie za pomocą `sort -V`
  # 4. `awk` znajduje naszą wersję i drukuje wszystkie, które są po niej
  local versions_to_fetch
  versions_to_fetch=$(printf "%s\n%s" "$current_version" "$all_tags" | sed 's/^v//' | sort -V | uniq | awk -v ver="$current_version" '$0 == ver {found=1; next} found')

  if [ -z "$versions_to_fetch" ]; then
    echo "🎉 Jesteś na bieżąco! Brak nowszych wersji '$formula'."
    return 0
  fi

  local versions_count
  versions_count=$(echo "$versions_to_fetch" | wc -l | xargs)
  echo "✨ Znaleziono $versions_count nowszych wersji. Generowanie raportu..."

  # --- Krok 4: Generowanie pliku Markdown ---
  # local output_file="updates_${formula}_${current_version}.md"
  local output_file="${file_name}"
  echo "# Raport aktualizacji dla: $formula" > "$output_file"
  echo "Wygenerowano: $(date)" >> "$output_file"
  echo "Porównanie od wersji **$current_version**." >> "$output_file"

  # Iterujemy po posortowanych wersjach w odwrotnej kolejności (od najnowszej)
  while IFS= read -r version; do
    # Musimy znaleźć oryginalny tag (z 'v' lub bez), który pasuje do numeru wersji
    local original_tag
    original_tag=$(echo "$all_tags" | grep -E "^v?${version}$")
    
    echo "-------------------------------------"
    echo "Pobieram notatki dla wersji $original_tag..."

    # Dodajemy separator i nagłówek do pliku Markdown
    echo "" >> "$output_file"
    echo "---" >> "$output_file"
    echo "" >> "$output_file"
    echo "## 🏷️ Wersja: $original_tag" >> "$output_file"
    echo "" >> "$output_file"

    # Pobieramy treść notatek i dodajemy do pliku
    gh release view "$original_tag" --repo "$repo_path" --json body --jq '.body' >> "$output_file"
  done < <(echo "$versions_to_fetch" | sort -Vr) # sort -Vr odwraca kolejność

  echo "-------------------------------------"
  echo "✅ Gotowe! Raport został zapisany w pliku: $output_file"
}


# Get the list of outdated formulae with their versions
# The output is formatted as "name;installed_version;current_version"
outdated_formulae=$(brew outdated --formulae --json | jq -r '.formulae[] | "\(.name);\(.installed_versions[0]);\(.current_version)"')

# Check if there are any outdated formulae
if [ -z "$outdated_formulae" ]; then
  echo "✅ All Homebrew formulae are up to date. No files will be created."
else
  out_dir=$(date +"%Y%m%d_%H%M%S")
  mkdir "$out_dir"
  # Loop through each line of the output
  echo "$outdated_formulae" | while IFS=';' read -r name installed_version current_version; do
    # Replace '/' with '-' in the formula name
    sanitized_name=$(echo "$name" | sed 's/\//-/g')
    # Create the filename
    filename="$out_dir/${sanitized_name}_${installed_version}_${current_version}.md"

    # Create an empty file with the generated filename
    #touch "$filename"
    # echo "Created file: $filename" 
    brew-check-updates "$name" "$filename"
  done
fi
