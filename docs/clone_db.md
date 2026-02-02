# Database Clone Tool

A simple yet powerful bash script to clone MySQL/MariaDB databases with real-time progress tracking.

## 📋 Features

- **Interactive Input**: Prompts for MySQL credentials and database names
- **Secure Password Entry**: Password input is hidden for security
- **Progress Bar**: Real-time progress tracking using `pv` (Pipe Viewer)
- **Size Estimation**: Automatically calculates database size for accurate progress display
- **Complete Clone**: Copies all data, routines, triggers, and events
- **Error Handling**: Provides clear success/failure messages
- **Safe Operation**: Creates target database if it doesn't exist

## 🔧 Dependencies

### Required

- **bash**: Shell interpreter (usually pre-installed on Linux/macOS)
- **mysql-client**: MySQL command-line tools

  ```bash
  # Ubuntu/Debian
  sudo apt-get install mysql-client

  # CentOS/RHEL
  sudo yum install mysql

  # macOS (Homebrew)
  brew install mysql-client
  ```

- **pv** (Pipe Viewer): Progress monitoring tool

  ```bash
  # Ubuntu/Debian
  sudo apt-get install pv

  # CentOS/RHEL
  sudo yum install pv

  # macOS (Homebrew)
  brew install pv
  ```

### Optional

- **MySQL Server**: Must be running and accessible
- Sufficient disk space for the cloned database
- Appropriate MySQL user permissions (CREATE, SELECT, INSERT, etc.)

## 📦 Installation

1. Navigate to the repository:

   ```bash
   cd helpful-codes
   ```

2. Make the script executable:

   ```bash
   chmod +x clone_db.sh
   ```

3. Ensure all dependencies are installed (see Dependencies section above)

## 🚀 Usage

### Basic Usage

Run the script:

```bash
./clone_db.sh
```

The script will prompt you for:

1. **MySQL User**: Your MySQL username (e.g., `root`)
2. **MySQL Password**: Your MySQL password (hidden input)
3. **Source Database Name**: The database you want to clone
4. **Target Database Name**: The name for the cloned database

### Example Session

```
$ ./clone_db.sh
MySQL User: root
MySQL Password:
Source Database Name: production_db
Target Database Name: development_db

--- Starting Clone: production_db -> development_db ---
Transfer Data: 1.2GiB 0:02:15 [8.9MiB/s] [===============>] 100%

[Success] Database cloned successfully!
```

## ⚙️ How It Works

1. **User Input**: Collects MySQL credentials and database names
2. **Size Calculation**: Queries `information_schema` to determine total database size
3. **Database Creation**: Creates the target database if it doesn't exist
4. **Data Transfer**: Uses `mysqldump` to export data and pipes it through `pv` for progress tracking
5. **Import**: Imports the data into the target database
6. **Verification**: Checks the exit status and reports success or failure

## 🔐 Security Considerations

- **Password Visibility**: While the script uses `-s` flag to hide password input, the password is passed via command-line arguments to MySQL commands. For production use, consider using MySQL configuration files (`~/.my.cnf`) instead.
- **Permissions**: Ensure the script has appropriate file permissions (e.g., `chmod 700`) to prevent unauthorized access.
- **Network**: If cloning across networks, ensure secure connections (SSL/TLS).

## 🛠️ Troubleshooting

### "pv: command not found"

Install the `pv` package (see Dependencies section).

### "Access denied for user"

Verify your MySQL credentials and ensure the user has necessary permissions:

```sql
GRANT ALL PRIVILEGES ON *.* TO 'username'@'localhost';
FLUSH PRIVILEGES;
```

### "Database already exists"

The script uses `CREATE DATABASE IF NOT EXISTS`, so this shouldn't be an issue. If you want to overwrite, manually drop the target database first:

```bash
mysql -u root -p -e "DROP DATABASE target_db;"
```

### Progress bar not showing

Ensure `pv` is installed and the database size calculation is working. You can test manually:

```bash
mysql -u root -p -e "SELECT SUM(data_length + index_length) FROM information_schema.TABLES WHERE table_schema='your_db';"
```

## 📝 Advanced Usage

### Clone to Remote Server

Modify the script to pipe to a remote MySQL server:

```bash
mysqldump -u $USER -p$PASS --routines --triggers --events --opt $DB_SOURCE \
| pv -s $SIZE_BYTES -N "Transfer Data" \
| mysql -h remote_host -u $USER -p$PASS $DB_TARGET
```

### Clone Specific Tables

To clone only specific tables, modify the `mysqldump` command:

```bash
mysqldump -u $USER -p$PASS $DB_SOURCE table1 table2 table3 \
| pv -N "Transfer Data" \
| mysql -u $USER -p$PASS $DB_TARGET
```

### Using MySQL Config File (More Secure)

Create `~/.my.cnf`:

```ini
[client]
user=your_username
password=your_password
```

Then modify the script to remove password prompts:

```bash
mysqldump --routines --triggers --events --opt $DB_SOURCE \
| pv -s $SIZE_BYTES -N "Transfer Data" \
| mysql $DB_TARGET
```

## 🔗 Related Tools

- [mysqldump](https://dev.mysql.com/doc/refman/8.0/en/mysqldump.html) - MySQL backup utility
- [pv](http://www.ivarch.com/programs/pv.shtml) - Pipe Viewer for monitoring data progress
- [mysql](https://dev.mysql.com/doc/refman/8.0/en/mysql.html) - MySQL command-line client

## 📄 License

This script is provided as-is for educational and practical purposes.

## ⚠️ Disclaimer

Always test database operations in a safe environment before running them on production data. Ensure you have proper backups before performing any database cloning operations.

---

[← Back to Main README](../README.md)
