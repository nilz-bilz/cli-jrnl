# Command Line journal

## Dependencies
bash
vim/nano (any text editor)
gpg (for encryption)

### Setup:
```bash
git clone <url>.git
```

```bash
cd jrnlapp
```

```bash
bash jrnl-setup.sh
```

### Usage
For current entry:
```bash
jrnl
```

For custom entry:
```bash
jrnl -d 2024-09-09 -t 12:00pm
```

To open files:
```bash
jrnl -o
```