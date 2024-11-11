#!/bin/bash

# Setup Script for Journal Configuration

echo "Setting up the journal script..."

# Define the target directory for the journal script and configuration files
JRNL_DIR="$HOME/.jrnl"
mkdir -p "$JRNL_DIR"  # Create the .jrnl directory in the home directory if it doesn’t exist

# Load existing configuration from .env if it exists
ENV_FILE="$JRNL_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
fi

# Prompt for encryption password (hidden input), showing existing if available
read -sp "Enter the password for file encryption (leave blank to keep existing): " ENCRYPTION_PASSWORD
echo
if [[ -z "$ENCRYPTION_PASSWORD" && -n "$GPG_PASSWORD" ]]; then
  ENCRYPTION_PASSWORD="$GPG_PASSWORD"  # Use existing password if user presses Enter
fi

# Prompt for the directory to store journal files, showing existing if available
default_dir="$HOME/journal"
read -p "Enter the directory where journal files should be stored [${FILES_DIRECTORY:-$default_dir}]: " input_files_dir
FILES_DIRECTORY="${input_files_dir:-${FILES_DIRECTORY:-$default_dir}}"  # Use input if provided, otherwise keep existing or default to $HOME/journal

# Ensure the directory exists or create it
mkdir -p "$FILES_DIRECTORY"

# Prompt for time format (12-hour or 24-hour), showing existing if available
read -p "Choose time format (12h or 24h) [${TIME_FORMAT:-24h}]: " TIME_FORMAT
TIME_FORMAT="${TIME_FORMAT:-$TIME_FORMAT}"  # Use existing or default to 24h
if [[ "$TIME_FORMAT" != "12h" && "$TIME_FORMAT" != "24h" ]]; then
  echo "Invalid input. Defaulting to 24-hour format."
  TIME_FORMAT="24h"
fi

# Prompt for date format with existing value
echo "Choose a date format for inside the file:"
echo "1. YYYY-MM-DD"
echo "2. DD-MM-YYYY"
echo "3. MM-DD-YYYY"
case "$DATE_FORMAT" in
  "+%Y-%m-%d") DEFAULT_DATE_OPTION=1 ;;
  "+%d-%m-%Y") DEFAULT_DATE_OPTION=2 ;;
  "+%m-%d-%Y") DEFAULT_DATE_OPTION=3 ;;
  *) DEFAULT_DATE_OPTION=1 ;;
esac
read -p "Enter the number of your preferred date format (1, 2, or 3) [${DEFAULT_DATE_OPTION}]: " DATE_OPTION
DATE_OPTION="${DATE_OPTION:-$DEFAULT_DATE_OPTION}"  # Default to existing or fallback to 1

# Set DATE_FORMAT based on the user's choice
case "$DATE_OPTION" in
  1)
    DATE_FORMAT="+%Y-%m-%d"
    ;;
  2)
    DATE_FORMAT="+%d-%m-%Y"
    ;;
  3)
    DATE_FORMAT="+%m-%d-%Y"
    ;;
  *)
    echo "Invalid input. Defaulting to YYYY-MM-DD."
    DATE_FORMAT="+%Y-%m-%d"
    ;;
esac

# Prompt for preferred text editor, showing existing value if available
read -p "Choose your preferred text editor (default: ${TEXT_EDITOR:-vim}): " TEXT_EDITOR
TEXT_EDITOR="${TEXT_EDITOR:-${TEXT_EDITOR:-vim}}"  # Default to existing or vim if not specified

# Write configuration to a .env file in the .jrnl directory
echo "Writing configuration to ${ENV_FILE}..."

cat > "$ENV_FILE" <<EOL
# Journal Script Configuration
GPG_PASSWORD="${ENCRYPTION_PASSWORD}"
FILES_DIRECTORY="${FILES_DIRECTORY}"
TIME_FORMAT="${TIME_FORMAT}"
DATE_FORMAT="${DATE_FORMAT}"
TEXT_EDITOR="${TEXT_EDITOR}"
EOL

# Copy the main journal script to the .jrnl directory
SCRIPT_SOURCE_DIR="$(pwd)"
cp -f "$SCRIPT_SOURCE_DIR/jrnl.sh" "$JRNL_DIR/jrnl.sh"  # -f flag to force overwrite

# Setup alias in .bashrc or .zshrc
if [[ -n "$ZSH_VERSION" ]]; then
  SHELL_RC="$HOME/.zshrc"
else
  SHELL_RC="$HOME/.bashrc"
fi

# Remove any existing jrnl alias to avoid duplicates
sed -i '/alias jrnl=/d' "$SHELL_RC"

# Add the new alias to the shell configuration file
echo "alias jrnl='bash $JRNL_DIR/jrnl.sh'" >> "$SHELL_RC"

# Display summary of configuration
echo "Configuration completed successfully."
echo "Summary:"
echo "  Encryption Password: [hidden]"
echo "  Files Directory: $FILES_DIRECTORY"
echo "  Time Format: $TIME_FORMAT"
echo "  Date Format: $DATE_FORMAT"
echo "  Text Editor: $TEXT_EDITOR"
echo "Alias 'jrnl' has been added to $SHELL_RC. Restart your terminal or source $SHELL_RC to use it."

echo "Setup complete."
