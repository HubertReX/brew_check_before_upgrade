#!/bin/bash

# Funkcja do szybkiego przeglądania notatek z wydania dla pakietu Homebrew
brew-notes() {
  if [ -z "$1" ]; then
    echo "Użycie: $0 <nazwa_formuły>"
    return 1
  fi

  # Użyj jq do wyciągnięcia repozytorium w formacie "owner/repo"
  local repo_path=$(brew info --json=v2 --formula "$1" | jq -r '.formulae[0].urls.stable.url' | cut -d'/' -f4,5 2>/dev/null)

  if [ -z "$repo_path" ]; then
    echo "Nie udało się znaleźć repozytorium GitHub dla '$1'."
    # echo "Próbuję otworzyć stronę domową..."
    # brew home "$1"
    return 1
  fi

  echo "Pobieranie notatek dla: $repo_path..."
  gh release view --repo "$repo_path"
}

brew-notes $1
