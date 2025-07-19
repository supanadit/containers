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
    # Get top-level entries in the zip
    top_dirs=$(unzip -l "$plugin_name.zip" | awk '{print $4}' | grep -v '^$' | grep -v '/$' | awk -F/ '{print $1}' | sort | uniq)
    if [ "$(echo "$top_dirs" | wc -l)" -eq 1 ]; then
      # All files are in one top-level directory, extract as usual
      unzip "$plugin_name.zip"
    else
      # Files are not wrapped, create a directory and extract there
      mkdir "$plugin_name"
      unzip "$plugin_name.zip" -d "$plugin_name"
    fi
    rm "$plugin_name.zip"
    echo "Extracted plugin zip: $(basename "$item")"
    cd - > /dev/null
  fi
done