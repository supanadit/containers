#!/bin/bash

PLUGIN_SRC_DIR="$1"
PLUGIN_DEST="/var/www/html/wp-content/plugins"

if [ -z "$PLUGIN_SRC_DIR" ]; then
  echo "Usage: $0 <source_plugins_directory>"
  exit 1
fi

if [ ! -d "$PLUGIN_SRC_DIR" ]; then
  echo "Error: $PLUGIN_SRC_DIR is not a directory."
  exit 2
fi

for item in "$PLUGIN_SRC_DIR"/*; do
  if [ -d "$item" ]; then
    cp -r "$item" "$PLUGIN_DEST"
    echo "Copied plugin directory: $(basename "$item")"
  elif [ -f "$item" ] && [[ "$item" == *.zip ]]; then
    plugin_name="$(basename "$item" .zip)"
    cp "$item" "$PLUGIN_DEST"
    cd "$PLUGIN_DEST"

    # Get top-level entries (files and dirs) in the zip
    top_entries=$(unzip -l "$plugin_name.zip" | awk '{print $4}' | grep -v '^$' | awk -F/ '{print $1}' | sort | uniq)
    top_entry_count=$(echo "$top_entries" | wc -l)

    # If only one top-level entry and it's a directory, extract as usual
    if [ "$top_entry_count" -eq 1 ]; then
      if unzip -l "$plugin_name.zip" | grep -q "^ *[0-9]\+ *[0-9-]\+ *[0-9:]\+ *$top_entries/"; then
        unzip "$plugin_name.zip"
        # Check for double directory after extraction
        if [ -d "$plugin_name/$plugin_name" ]; then
          mv "$plugin_name/$plugin_name/"* "$plugin_name/"
          rm -rf "$plugin_name/$plugin_name"
        fi
      else
        mkdir "$plugin_name"
        unzip "$plugin_name.zip" -d "$plugin_name"
      fi
    else
      mkdir "$plugin_name"
      unzip "$plugin_name.zip" -d "$plugin_name"
      # Check for double directory after extraction
      if [ -d "$plugin_name/$plugin_name" ]; then
        mv "$plugin_name/$plugin_name/"* "$plugin_name/"
        rm -rf "$plugin_name/$plugin_name"
      fi
    fi

    rm "$plugin_name.zip"
    echo "Extracted plugin zip: $(basename "$item")"
    cd - > /dev/null
  fi
done