#!/bin/bash

THEME_SRC_DIR="$1"
THEME_DEST="/var/www/html/wp-content/themes"

if [ -z "$THEME_SRC_DIR" ]; then
  echo "Usage: $0 <source_themes_directory>"
  exit 1
fi

if [ ! -d "$THEME_SRC_DIR" ]; then
  echo "Error: $THEME_SRC_DIR is not a directory."
  exit 2
fi

for item in "$THEME_SRC_DIR"/*; do
  if [ -d "$item" ]; then
    cp -r "$item" "$THEME_DEST"
    echo "Copied theme directory: $(basename "$item")"
  elif [ -f "$item" ] && [[ "$item" == *.zip ]]; then
    theme_name="$(basename "$item" .zip)"
    cp "$item" "$THEME_DEST"
    cd "$THEME_DEST"

    top_entries=$(unzip -l "$theme_name.zip" | awk '{print $4}' | grep -v '^$' | awk -F/ '{print $1}' | sort | uniq)
    top_entry_count=$(echo "$top_entries" | wc -l)

    if [ "$top_entry_count" -eq 1 ]; then
      if unzip -l "$theme_name.zip" | grep -q "^ *[0-9]\+ *[0-9-]\+ *[0-9:]\+ *$top_entries/"; then
        unzip "$theme_name.zip"
        if [ -d "$theme_name/$theme_name" ]; then
          mv "$theme_name/$theme_name/"* "$theme_name/"
          rm -rf "$theme_name/$theme_name"
        fi
      else
        mkdir "$theme_name"
        unzip "$theme_name.zip" -d "$theme_name"
      fi
    else
      mkdir "$theme_name"
      unzip "$theme_name.zip" -d "$theme_name"
      if [ -d "$theme_name/$theme_name" ]; then
        mv "$theme_name/$theme_name/"* "$theme_name/"
        rm -rf "$theme_name/$theme_name"
      fi
    fi

    rm "$theme_name.zip"
    echo "Extracted theme zip: $(basename "$item")"
    cd - > /dev/null
  fi
done