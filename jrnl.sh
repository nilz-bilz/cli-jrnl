#!/bin/bash

# Load configuration from the .env file in the .jrnl directory
source "$HOME/.jrnl/.env"

# Default values for date and time (use current date and time if not specified)
CUSTOM_DATE=""
CUSTOM_TIME=""

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

# Parse command-line arguments for flags
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --open|-o) # Open an existing journal file
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
      ;;
    --date|-d) # Set custom date for new entry
      CUSTOM_DATE="$2"
      shift 2
      ;;
    --time|-t) # Set custom time for new entry
      CUSTOM_TIME="$2"
      shift 2
      ;;
    *) # Unknown option
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Default behavior: Create a new journal entry with custom or current date/time

# Use custom date if provided, otherwise use today's date
if [[ -n "$CUSTOM_DATE" ]]; then
  ENTRY_DATE="$CUSTOM_DATE"
else
  ENTRY_DATE=$(date '+%Y-%m-%d')
fi

# Use custom time if provided, otherwise use the current time
if [[ -n "$CUSTOM_TIME" ]]; then
  ENTRY_TIME="$CUSTOM_TIME"
else
  ENTRY_TIME=$(date '+%H:%M:%S')
fi

# Use the custom or current date/time to format directory structure and file names
YEAR=$(date -d "$ENTRY_DATE" '+%Y')
YEAR_MONTH=$(date -d "$ENTRY_DATE" '+%Y-%m')
ISO_FILENAME=$(date -d "$ENTRY_DATE $ENTRY_TIME" '+%Y-%m-%dT%H:%M:%S').txt
FULL_PATH="${FILES_DIRECTORY}/${YEAR}/${YEAR_MONTH}"

# Format DATE and TIME to be included inside the file according to configuration
DATE=$(date -d "$ENTRY_DATE" "$DATE_FORMAT")
if [ "$TIME_FORMAT" == "12h" ]; then
  TIME=$(date -d "$ENTRY_TIME" '+%I:%M %p')
else
  TIME=$(date -d "$ENTRY_TIME" '+%H:%M')
fi

# Create the directory structure if it doesn’t exist
mkdir -p "$FULL_PATH"

# Write initial content to a temporary file before encryption
TEMP_FILE=$(mktemp)
echo -e "DATE: $DATE\nTIME: $TIME\n\n" > "$TEMP_FILE"

# Record the initial checksum of the file
INITIAL_CHECKSUM=$(md5sum "$TEMP_FILE" | awk '{ print $1 }')

# Open file in Vim at line 3
vim +4 "$TEMP_FILE"

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
