#!/bin/bash

# Setup Script for Journal Configuration

echo "Setting up the journal script..."

# Define the target directory for the journal script and configuration files
JRNL_DIR="$HOME/.jrnl"
mkdir -p "$JRNL_DIR"  # Create the .jrnl directory in the home directory if it doesn’t exist

# Prompt for encryption password
read -sp "Enter the password for file encryption: " ENCRYPTION_PASSWORD
echo

# Prompt for the directory to store journal files
read -p "Enter the directory where journal files should be stored: " FILES_DIRECTORY
mkdir -p "$FILES_DIRECTORY"  # Create the directory if it doesn't exist

# Prompt for time format (12-hour or 24-hour)
read -p "Choose time format (12h or 24h): " TIME_FORMAT
if [[ "$TIME_FORMAT" != "12h" && "$TIME_FORMAT" != "24h" ]]; then
  echo "Invalid input. Defaulting to 24-hour format."
  TIME_FORMAT="24h"
fi

# Prompt for date format
echo "Choose a date format for inside the file:"
echo "1. YYYY-MM-DD"
echo "2. DD-MM-YYYY"
echo "3. MM-DD-YYYY"
read -p "Enter the number of your preferred date format (1, 2, or 3): " DATE_OPTION

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

# Write configuration to a .env file in the .jrnl directory
ENV_FILE="$JRNL_DIR/.env"
echo "Writing configuration to ${ENV_FILE}..."

cat > "$ENV_FILE" <<EOL
# Journal Script Configuration
GPG_PASSWORD="${ENCRYPTION_PASSWORD}"
FILES_DIRECTORY="${FILES_DIRECTORY}"
TIME_FORMAT="${TIME_FORMAT}"
DATE_FORMAT="${DATE_FORMAT}"
EOL

# Copy and overwrite the main journal script to the .jrnl directory
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
echo "Alias 'jrnl' has been added to $SHELL_RC. Restart your terminal or source $SHELL_RC to use it."

echo "Setup complete."

