#!/bin/bash

# Define the Downloads folder
DOWNLOADS_DIR="$HOME/Downloads"

# Check if the directory exists
if [ ! -d "$DOWNLOADS_DIR" ]; then
    echo "Downloads folder not found!"
    exit 1
fi

# Organize files by their types
for file in "$DOWNLOADS_DIR"/*; do
    if [ -f "$file" ]; then
        # Get the file extension
        extension=$(echo "${file##*.}" | tr '[:upper:]' '[:lower:]')
        # Create a folder for the file type if it doesn't exist
        folder="$DOWNLOADS_DIR/$extension"
        mkdir -p "$folder"
        # Move the file to the appropriate folder
        mv "$file" "$folder/"
    fi
done

echo "Files in the Downloads folder have been organized"
