#!/usr/bin/env bash

# Load configuration from the .env file in the .jrnl directory
source "$HOME/.jrnl/.env"

# Function to display help
show_help() {
  cat << EOF
Usage: jrnl [OPTIONS]

This script is a simple journaling tool that allows you to create encrypted journal entries,
open and edit existing entries, and organize them by date.

Options:
  --open, -o           Open an existing journal entry. Prompts for year, month, and file.
  --date, -d DATE      Specify a custom date for a new entry (format: YYYY-MM-DD).
  --time, -t TIME      Specify a custom time for a new entry (format: HH:MM:SS).
  --help, -h           Display this help message.

Examples:
  jrnl                    Create a new journal entry with the current date and time.
  jrnl --date 2024-11-01  Create a new entry backdated to November 1, 2024.
  jrnl --open             Open an existing entry. Select year, month, and file interactively.

Configuration:
  This script uses the configuration file at ~/.jrnl/.env to manage settings like the preferred
  text editor, encryption password, file storage directory, and date/time format.

Note:
  You can re-run the setup script to change the configuration or reset defaults.
EOF
}

# Check if --help or -h is used
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  show_help
  exit 0
fi


# Default values for custom date and time (use current date and time if not specified)
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

  # Open the decrypted file with the specified text editor
  $TEXT_EDITOR "$TEMP_FILE"

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
      # Ensure the journal directory exists
      if [[ ! -d "$FILES_DIRECTORY" ]]; then
        echo "Journal directory '$FILES_DIRECTORY' does not exist."
        exit 1
      fi

      # Step 1: List available years
      mapfile -t years < <(find "$FILES_DIRECTORY" -mindepth 1 -maxdepth 1 -type d -not -path '*/.*' -exec basename {} \; | sort)
      if [[ ${#years[@]} -eq 0 ]]; then
        echo "No journal entries found."
        exit 1
      fi

      echo "Available years:"
      for i in "${!years[@]}"; do
        echo "$((i + 1)). ${years[$i]}"
      done

      read -p "Enter the number of the year you wish to select: " year_choice
      if ! [[ "$year_choice" =~ ^[0-9]+$ ]] || (( year_choice < 1 || year_choice > ${#years[@]} )); then
        echo "Invalid choice. Exiting."
        exit 1
      fi

      SELECTED_YEAR="${years[$((year_choice - 1))]}"

      # Step 2: List available months within the selected year
      mapfile -t months < <(find "$FILES_DIRECTORY/$SELECTED_YEAR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
      if [[ ${#months[@]} -eq 0 ]]; then
        echo "No journal entries found for the year $SELECTED_YEAR."
        exit 1
      fi

      echo "Available months for $SELECTED_YEAR:"
      for i in "${!months[@]}"; do
        echo "$((i + 1)). ${months[$i]}"
      done

      read -p "Enter the number of the month you wish to select: " month_choice
      if ! [[ "$month_choice" =~ ^[0-9]+$ ]] || (( month_choice < 1 || month_choice > ${#months[@]} )); then
        echo "Invalid choice. Exiting."
        exit 1
      fi

      SELECTED_MONTH="${months[$((month_choice - 1))]}"

      # Step 3: List available files within the selected month
      mapfile -t files < <(find "$FILES_DIRECTORY/$SELECTED_YEAR/$SELECTED_MONTH" -type f -name "*.gpg" | sort)
      if [[ ${#files[@]} -eq 0 ]]; then
        echo "No journal entries found for $SELECTED_YEAR-$SELECTED_MONTH."
        exit 1
      fi

      echo "Available journal files for $SELECTED_YEAR-$SELECTED_MONTH:"
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

# Open file with the specified editor at line 3
$TEXT_EDITOR +4 "$TEMP_FILE"

# Check if changes were made by comparing checksums
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
