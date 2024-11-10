#!/bin/bash

# Load configuration from the .env file in the .jrnl directory
source "$HOME/.jrnl/.env"

# Helper function to open and edit an existing journal file
open_journal_file() {
  local encrypted_file="$1"

  # Check if the encrypted file exists
  if [[ ! -f "$encrypted_file" ]]; then
    echo "Error: File '$encrypted_file' not found in the journal directory."
    exit 1
  fi

  # Decrypt the file to a temporary location
  TEMP_FILE=$(mktemp)
  echo "$GPG_PASSWORD" | gpg --batch --yes --passphrase-fd 0 --decrypt "$encrypted_file" > "$TEMP_FILE" 2>/dev/null
  
  if [[ $? -ne 0 ]]; then
    echo "Error decrypting the file. Check your password or file integrity."
    rm "$TEMP_FILE"
    exit 1
  fi

  # Record the initial checksum to detect changes
  INITIAL_CHECKSUM=$(md5sum "$TEMP_FILE" | awk '{ print $1 }')

  # Open the decrypted file in Vim
  vim "$TEMP_FILE"

  # Check for changes by comparing checksums
  FINAL_CHECKSUM=$(md5sum "$TEMP_FILE" | awk '{ print $1 }')
  if [[ "$INITIAL_CHECKSUM" != "$FINAL_CHECKSUM" ]]; then
    # Re-encrypt the file if changes were made
    echo "$GPG_PASSWORD" | gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo AES256 "$TEMP_FILE"
    mv "$TEMP_FILE.gpg" "$encrypted_file"
    echo "File re-encrypted and saved as '$encrypted_file'"
  else
    echo "No changes made. File was not modified."
  fi

  # Clean up the temporary file
  rm "$TEMP_FILE"
}

# Check if --open or -o flag is used
if [[ "$1" == "--open" || "$1" == "-o" ]]; then
  # Ensure the journal directory exists and list available files
  if [[ ! -d "$FILES_DIRECTORY" ]]; then
    echo "Journal directory '$FILES_DIRECTORY' does not exist."
    exit 1
  fi

  # List .gpg files in the journal directory and prompt for selection
  mapfile -t files < <(find "$FILES_DIRECTORY" -type f -name "*.gpg" | sort)
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No encrypted journal files found in $FILES_DIRECTORY."
    exit 1
  fi

  echo "Available journal files:"
  for i in "${!files[@]}"; do
    echo "$((i + 1)). ${files[$i]##*/}"
  done

  read -p "Enter the number of the file you wish to open: " file_choice
  if ! [[ "$file_choice" =~ ^[0-9]+$ ]] || (( file_choice < 1 || file_choice > ${#files[@]} )); then
    echo "Invalid choice. Exiting."
    exit 1
  fi

  # Get the selected file
  FILE_TO_OPEN="${files[$((file_choice - 1))]}"
  open_journal_file "$FILE_TO_OPEN"
  exit 0
fi

# Default behavior: Create a new journal entry
# Set date and time based on configuration
if [ "$TIME_FORMAT" == "12h" ]; then
  TIME=$(date '+%I:%M %p')
else
  TIME=$(date '+%H:%M')
fi

# Format DATE according to the user's DATE_FORMAT for inside the file
DATE=$(date "$DATE_FORMAT")

# Determine the folder structure based on the current year and month
YEAR=$(date '+%Y')
YEAR_MONTH=$(date '+%Y-%m')
ISO_FILENAME=$(date '+%Y-%m-%dT%H:%M:%S').txt
FULL_PATH="${FILES_DIRECTORY}/${YEAR}/${YEAR_MONTH}"

# Create the directory structure if it doesn’t exist
mkdir -p "$FULL_PATH"

# Write initial content to a temporary file before encryption
TEMP_FILE=$(mktemp)
echo -e "DATE: $DATE\nTIME: $TIME\n\n" > "$TEMP_FILE"

# Record the initial checksum of the file
INITIAL_CHECKSUM=$(md5sum "$TEMP_FILE" | awk '{ print $1 }')

# Open file in Vim at line 3
vim +3 "$TEMP_FILE"

# Check if changes were made in Vim by comparing checksums
FINAL_CHECKSUM=$(md5sum "$TEMP_FILE" | awk '{ print $1 }')

if [ "$INITIAL_CHECKSUM" != "$FINAL_CHECKSUM" ]; then
  # If changes were made, move the modified temp file to the target path
  mv "$TEMP_FILE" "$FULL_PATH/$ISO_FILENAME"

  # Encrypt the file using GPG
  echo "$GPG_PASSWORD" | gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo AES256 "$FULL_PATH/$ISO_FILENAME"

  # Remove unencrypted file after encryption
  rm "$FULL_PATH/$ISO_FILENAME"

  echo "File encrypted and saved as ${FULL_PATH}/${ISO_FILENAME}.gpg"
else
  # Remove temp file if no changes were made
  rm "$TEMP_FILE"
  echo "No changes made. File not saved."
fi
