# Database Clone Tool (Windows PowerShell)

A PowerShell script to clone MySQL/MariaDB databases on Windows with progress tracking.

## 📋 Features

- **Interactive Input**: Prompts for MySQL credentials and database names
- **Secure Password Entry**: Password input is hidden using SecureString
- **Smart Error Handling**: Distinguishes between bad passwords and connection errors
- **Database Verification**: Verifies source DB exists and lists available ones if not found
- **Progress Tracking**: Visual progress bar showing clone status
- **Size Calculation**: Displays database size before cloning
- **Complete Clone**: Copies all data, routines, triggers, and events
- **Safe Operation**: Creates target database if it doesn't exist
- **Memory Security**: Clears password from memory and environment variables after use

## 🔧 Dependencies

### Required

- **PowerShell**: Version 5.1 or higher (pre-installed on Windows 10/11)

  ```powershell
  # Check PowerShell version
  $PSVersionTable.PSVersion
  ```

- **MySQL Client**: MySQL command-line tools for Windows

  **Option 1: Install MySQL Server** (includes client tools)
  - Download from: https://dev.mysql.com/downloads/mysql/
  - During installation, ensure "MySQL Client" is selected

  **Option 2: Install MySQL Shell** (standalone client)
  - Download from: https://dev.mysql.com/downloads/shell/

  **Option 3: Using Chocolatey**

  ```powershell
  choco install mysql
  ```

  **Option 4: Using Winget**

  ```powershell
  winget install Oracle.MySQL
  ```

### Verify Installation

After installation, verify MySQL is in your PATH:

```powershell
mysql --version
mysqldump --version
```

If not found, add MySQL to your PATH:

```powershell
# Add to current session
$env:Path += ";C:\Program Files\MySQL\MySQL Server 8.0\bin"

# Add permanently (run as Administrator)
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\MySQL\MySQL Server 8.0\bin", "Machine")
```

## 📦 Installation

1. Navigate to the repository:

   ```powershell
   cd C:\path\to\helpful-codes
   ```

2. The script is ready to use (no need to set execute permissions on Windows)

## 🚀 Usage

### Basic Usage

Run the script in PowerShell:

```powershell
.\clone_db.ps1
```

The script will prompt you for:

1. **MySQL User**: Your MySQL username (e.g., `root`)
2. **MySQL Password**: Your MySQL password (hidden input)
3. **Source Database Name**: The database you want to clone
4. **Target Database Name**: The name for the cloned database

### Example Session

```powershell
PS C:\helpful-codes> .\clone_db.ps1
MySQL User: root
MySQL Password: ********
Source Database Name: production_db
Target Database Name: development_db

--- Starting Clone: production_db -> development_db ---
Verifying source database exists...
Source database verified: production_db
Calculating database size...
Database size: 1250.45 MB
Creating target database...
Target database created successfully

Cloning database...
[Progress Bar: ████████████████████ 100%]

[Success] Database cloned successfully!
Source: production_db -> Target: development_db

Clone operation completed at 2026-02-03 01:30:45
```

## ⚙️ How It Works

1. **User Input**: Collects MySQL credentials using SecureString for password
2. **Validation**: Checks if MySQL client is installed and accessible
3. **Size Calculation**: Queries `information_schema` to determine database size
4. **Database Creation**: Creates the target database if it doesn't exist
5. **Export**: Uses `mysqldump` to export source database to temp file
6. **Import**: Imports data from temp file to target database
7. **Cleanup**: Removes temporary files and clears password from memory
8. **Verification**: Reports success or failure with detailed error messages

## 🔐 Security Considerations

## 🔐 Security Considerations

- **Secure Input**: Password is read as a SecureString to prevent it from being potentially logged or exposed during input.
- **Process Security**: The script uses the process-scoped `MYSQL_PWD` environment variable to authenticate with MySQL commands. This avoids passing the password as a command-line argument and prevents interactive prompts.
- **Cleanup**: The `MYSQL_PWD` environment variable and password variables are explicitly cleared from memory immediately after the operation completes.
- **Temp Files**: Temporary dump files are automatically deleted.
- **Error Messages**: Sensitive information is not exposed in error messages.

### Best Practices

1. **Use MySQL Config File** (more secure):
   Create `C:\Users\YourName\.my.cnf`:

   ```ini
   [client]
   user=your_username
   password=your_password
   ```

   Then modify the script to remove password prompts.

2. **Restrict Script Access**:
   - Store scripts in protected directories
   - Use NTFS permissions to limit access

3. **Network Security**:
   - Use SSL/TLS for remote connections
   - Consider VPN for cross-network cloning

## 🛠️ Troubleshooting

### "mysql : The term 'mysql' is not recognized"

MySQL is not installed or not in your PATH. Solutions:

1. **Install MySQL** (see Dependencies section)
2. **Add MySQL to PATH**:

   ```powershell
   # Find MySQL installation
   Get-ChildItem "C:\Program Files" -Recurse -Filter "mysql.exe" -ErrorAction SilentlyContinue

   # Add to PATH (adjust path as needed)
   $env:Path += ";C:\Program Files\MySQL\MySQL Server 8.0\bin"
   ```

### "Access denied for user"

Verify credentials and permissions:

```sql
-- Grant necessary permissions
GRANT ALL PRIVILEGES ON *.* TO 'username'@'localhost';
FLUSH PRIVILEGES;
```

### "Database already exists"

The script uses `CREATE DATABASE IF NOT EXISTS`, so this shouldn't cause errors. To overwrite:

```powershell
mysql -u root -p -e "DROP DATABASE target_db;"
```

### Script execution is disabled

If you get "running scripts is disabled on this system":

```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy for current user (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or run with bypass (one-time)
PowerShell -ExecutionPolicy Bypass -File .\clone_db.ps1
```

### Progress bar not showing

Ensure you're running in a PowerShell console (not ISE or some IDEs that don't support Write-Progress).

## 📝 Advanced Usage

### Clone to Remote Server

Modify the script to connect to a remote MySQL server:

```powershell
# Add -h parameter to mysql commands
$importResult = Get-Content $tempFile | & mysql -h remote_host -u $User -p"$Password" $DbTarget 2>&1
```

### Clone Specific Tables

To clone only specific tables, modify the mysqldump command:

```powershell
$dumpResult = & mysqldump -u $User -p"$Password" $DbSource table1 table2 table3 2>&1
```

### Automated Cloning (Scheduled Task)

Create a wrapper script with credentials from environment variables:

```powershell
# clone_db_auto.ps1
$env:MYSQL_USER = "root"
$env:MYSQL_PASS = "your_password"
$env:DB_SOURCE = "production_db"
$env:DB_TARGET = "backup_db_$(Get-Date -Format 'yyyyMMdd')"

# Call main script with parameters
# (requires modifying clone_db.ps1 to accept parameters)
```

### Logging

Add logging to track clone operations:

```powershell
# Add at the beginning of the script
$logFile = "clone_db_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $logFile

# Add at the end
Stop-Transcript
```

## 🔗 Related Tools

- [MySQL for Windows](https://dev.mysql.com/downloads/mysql/) - MySQL Server and client tools
- [MySQL Workbench](https://dev.mysql.com/downloads/workbench/) - GUI tool for MySQL
- [HeidiSQL](https://www.heidisql.com/) - Free MySQL client for Windows

## 📄 License

This script is provided as-is for educational and practical purposes.

## ⚠️ Disclaimer

Always test database operations in a safe environment before running them on production data. Ensure you have proper backups before performing any database cloning operations.

---

[← Back to Main README](../README.md)
