# MySQL Table Copy Tool (Windows PowerShell)

This PowerShell script allows you to copy a specific table from one MySQL database to another on Windows with progress tracking and "upsert" (replace) support.

## Features

- **Cross-host Support**: Copy tables between different MySQL servers.
- **Interactive Selection**: Lists available databases and tables with their row counts and sizes.
- **Upsert Support**: Uses `REPLACE INTO` logic via `mysqldump --replace`.
- **Progress Tracking**: Uses `Write-Progress` for a native PowerShell progress bar.
- **Security**: Uses `SecureString` for password entry and `MYSQL_PWD` for command authentication.

## Prerequisites

- **PowerShell**: Version 5.1 or higher.
- **MySQL Client**: `mysql` and `mysqldump` must be installed and in your PATH.

## Usage

1. Open PowerShell.
2. Navigate to the script directory.
3. Run the script:
   ```powershell
   .\copy_table.ps1
   ```

## How it Works

1. **Source Connection**: Enter source credentials. Passwords are entered securely.
2. **Selection**: Choose a source database and table from the interactive lists.
3. **Target Connection**: Enter target credentials (defaults to source values).
4. **Data Transfer**:
   - Creates the target database if it doesn't exist.
   - Copies the table structure if missing.
   - Dumps data with `--replace` and imports it to the target.

## Troubleshooting

- **"Access Denied"**: Check your MySQL user privileges (need `SELECT`, `RELOAD`, `REPLACE` permissions).
- **"mysql is not recognized"**: Ensure MySQL `bin` folder is in your system Environment Variables (PATH).
