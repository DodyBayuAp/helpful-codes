# MySQL Table Copy Tool

This tool allows you to copy a specific table from one MySQL database to another (even on different hosts) with progress tracking and "upsert" (replace) support.

## Features

- **Cross-host Support**: Copy tables between different MySQL servers.
- **Interactive Selection**: Lists available databases and tables with their row counts and sizes.
- **Upsert Support**: Uses `REPLACE INTO` logic, making it safe to run on existing tables.
- **Progress Tracking**: Real-time progress updates during the transfer.
- **Colorized UI**: Clear visual feedback in the terminal.

## Prerequisites

- **MySQL Client**: `mysql` and `mysqldump` must be installed and in your PATH.
- **Progress tracking (Linux/macOS)**: Install `pv` for a visual progress bar.
  ```bash
  sudo apt install pv  # Ubuntu/Debian
  brew install pv      # macOS
  ```

## Usage

### Windows (PowerShell)

Run the script using PowerShell:

```powershell
./copy_table.ps1
```

### Linux / macOS (Bash)

Make the script executable and run it:

```bash
chmod +x copy_table.sh
./copy_table.sh
```

## How it Works

1. **Source Connection**: Enter source credentials. The script will list available databases.
2. **Source Selection**: Choose a database and then a specific table. It shows the table size and row count for confirmation.
3. **Target Connection**: Enter target credentials (defaults to source if host/user are empty).
4. **Target Selection**: Choose the target database (it will be created if it doesn't exist).
5. **Schema Creation**: If the table doesn't exist in the target database, its structure is copied from the source.
6. **Data Transfer**: Data is dumped from the source using `mysqldump --replace` and piped directly into the target `mysql` instance.

## Error Handling

- Validates connections at each step.
- Checks for table existence before starting the dump.
- Provides specific error messages if the dump or import fails.
- Environment variables are used for passwords (`MYSQL_PWD`) to avoid clear-text passwords in process lists and terminal history.
