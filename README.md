# jrnl - A Command Line journal
A command line journal inspired by https://github.com/jrnl-org/jrnl
I wanted to have a minimal journaling system that would store my files encrypted, and be easy to setup across multiple devices without needing too many dependencies. 

The whole program is written in 2 simple bash scripts. I wanted this app to function on most Linux/UNIX based systems with minimal configuration, and be able to rely on it years later, even when the app hasn't been worked on much.

Hence the app tries to rely solely on minimal and popular packages that come bundled with most distributions, such as bash, gpg, and popular text editors like nano or vim/vi.

This program can also be used to store encrypted records for any other purpose.

It uses symmetric AES256 encryption with GPG. The setup script will prompt you for the password.

All files are stored in **ISO 8601** time and date format. 
The program creates a hierarchical structure with folders for years, months,  and timestamped files. 

## Dependencies
- bash
- vim/nano (any cli text editor)
- gpg (for encryption)

## Setup:
```bash
git clone https://github.com/nilz-bilz/cli-jrnl.git
```

```bash
cd cli-jrnl
```

```bash
bash jrnl-setup.sh
```
> After the setup, a folder called .jrnl/ will be created in your home directory. This will contain the script to runn the app, as well as the .env file to store all env variables and secrets. 

> The keyword `jrnl` will be added to your .bashrc or .zshrc to run this script from the .jrnl/ folder

After the setup, restart the terminal or:
```bash
source ~/.bashrc #replace with ~/.zshrc for zsh
``` 

## Usage
For creating a current entry:
```bash
jrnl
```

For custom entry (past or future):
```bash
jrnl --date 2024-09-09 --time 12:00pm
```

To open files:
```bash
jrnl --open
```

This will allow you to navigate the journal directory:
```
Available years:
1. 2023
2. 2024
Enter the number of the year you wish to select: 2
Available months for 2024:
1. 2024-06
2. 2024-08
3. 2024-11
Enter the number of the month you wish to select: 3
Available journal files for 2024-2024-11:
1. 2024-11-10T14:57:34.txt.gpg
2. 2024-11-10T14:58:59.txt.gpg
3. 2024-11-10T14:59:13.txt.gpg
4. 2024-11-10T15:30:14.txt.gpg
Enter the number of the file you wish to open: 
```

For additional help:
```bash
jrnl --help
```

## Backing up
You must backup the following:

`~/.jrnl` folder that contains the main script and .env

`~/.gnupg` folder that holds the encryption keys

The actual destination folder where your entries are stored [`~/journal` by default].
