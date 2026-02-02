# Database Clone Tool for Windows PowerShell
# Clones MySQL/MariaDB databases with progress tracking

# Function to display progress
function Show-Progress {
    param(
        [string]$Activity,
        [int]$PercentComplete,
        [string]$Status
    )
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

# Get MySQL credentials and database names
$User = Read-Host "MySQL User"
$SecurePassword = Read-Host "MySQL Password" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
$Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

$DbSource = Read-Host "Source Database Name"
$DbTarget = Read-Host "Target Database Name"

Write-Host "`n--- Starting Clone: $DbSource -> $DbTarget ---" -ForegroundColor Cyan

# Check if MySQL is installed
try {
    $null = & mysql --version 2>&1
}
catch {
    Write-Host "[Error] MySQL client is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install MySQL client and add it to your PATH" -ForegroundColor Yellow
    exit 1
}

# Set MySQL password as environment variable to avoid interactive prompt
$env:MYSQL_PWD = $Password

# Verify source database exists
Write-Host "Verifying source database exists..." -ForegroundColor Yellow
$checkDbQuery = "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$DbSource';"
try {
    $dbExists = & mysql -u $User -e $checkDbQuery -s --skip-column-names 2>&1
    if ($LASTEXITCODE -ne 0) {
        # Check if it's an authentication error
        if ($dbExists -match "Access denied" -or $dbExists -match "ERROR 1045") {
            Write-Host "[Error] Authentication failed - Wrong username or password!" -ForegroundColor Red
            Write-Host "Please check your MySQL credentials" -ForegroundColor Yellow
        }
        else {
            Write-Host "[Error] Failed to connect to MySQL server" -ForegroundColor Red
            Write-Host "Please check your MySQL server status" -ForegroundColor Yellow
        }
        Write-Host "Error details: $dbExists" -ForegroundColor Red
        exit 1
    }
    
    if ([string]::IsNullOrWhiteSpace($dbExists) -or $dbExists -notmatch $DbSource) {
        Write-Host "[Error] Source database '$DbSource' not found!" -ForegroundColor Red
        
        # List available databases to help user
        Write-Host "`nAvailable databases:" -ForegroundColor Yellow
        $listDbQuery = "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys');"
        $availableDbs = & mysql -u $User -e $listDbQuery -s --skip-column-names 2>&1
        
        if ($LASTEXITCODE -eq 0 -and ![string]::IsNullOrWhiteSpace($availableDbs)) {
            $availableDbs -split "`n" | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
                Write-Host "  - $_" -ForegroundColor Cyan
            }
        }
        else {
            Write-Host "  (Unable to list databases)" -ForegroundColor Gray
        }
        
        exit 1
    }
    
    Write-Host "Source database verified: $DbSource" -ForegroundColor Green
}
catch {
    Write-Host "[Error] Failed to verify source database: $_" -ForegroundColor Red
    exit 1
}

# Calculate database size for progress estimation
Write-Host "Calculating database size..." -ForegroundColor Yellow
$sizeQuery = "SELECT COALESCE(SUM(data_length + index_length), 0) FROM information_schema.TABLES WHERE table_schema='$DbSource';"
try {
    $sizeBytes = & mysql -u $User -e $sizeQuery -s --skip-column-names 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[Error] Failed to connect to MySQL or query database size" -ForegroundColor Red
        Write-Host "Error: $sizeBytes" -ForegroundColor Red
        exit 1
    }
    $sizeMB = [math]::Round($sizeBytes / 1MB, 2)
    Write-Host "Database size: $sizeMB MB" -ForegroundColor Green
}
catch {
    Write-Host "[Error] Failed to calculate database size: $_" -ForegroundColor Red
    exit 1
}

# Create target database
Write-Host "Creating target database..." -ForegroundColor Yellow
try {
    $createDb = & mysql -u $User -e "CREATE DATABASE IF NOT EXISTS ``$DbTarget``;" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[Error] Failed to create target database" -ForegroundColor Red
        Write-Host "Error: $createDb" -ForegroundColor Red
        exit 1
    }
    Write-Host "Target database created successfully" -ForegroundColor Green
}
catch {
    Write-Host "[Error] Failed to create database: $_" -ForegroundColor Red
    exit 1
}

# Perform the database dump and restore
Write-Host "`nCloning database..." -ForegroundColor Cyan
$tempFile = [System.IO.Path]::GetTempFileName()

try {
    # Export database
    Show-Progress -Activity "Database Clone" -PercentComplete 10 -Status "Exporting source database..."
    $dumpResult = & mysqldump -u $User --routines --triggers --events --opt $DbSource 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[Error] Failed to dump source database" -ForegroundColor Red
        Write-Host "Error: $dumpResult" -ForegroundColor Red
        exit 1
    }
    
    # Save to temp file
    Show-Progress -Activity "Database Clone" -PercentComplete 50 -Status "Processing data..."
    $dumpResult | Out-File -FilePath $tempFile -Encoding UTF8
    
    # Import to target database
    Show-Progress -Activity "Database Clone" -PercentComplete 75 -Status "Importing to target database..."
    $importResult = Get-Content $tempFile | & mysql -u $User $DbTarget 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[Error] Failed to import to target database" -ForegroundColor Red
        Write-Host "Error: $importResult" -ForegroundColor Red
        exit 1
    }
    
    Show-Progress -Activity "Database Clone" -PercentComplete 100 -Status "Complete"
    Write-Host "`n[Success] Database cloned successfully!" -ForegroundColor Green
    Write-Host "Source: $DbSource -> Target: $DbTarget" -ForegroundColor Cyan
    
}
catch {
    Write-Host "`n[Error] An error occurred during the cloning process" -ForegroundColor Red
    Write-Host "Error details: $_" -ForegroundColor Red
    exit 1
}
finally {
    # Clean up temp file
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force
    }
    Write-Progress -Activity "Database Clone" -Completed
}

# Clear password from memory
$Password = $null
$env:MYSQL_PWD = $null
[System.GC]::Collect()

Write-Host "`nClone operation completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
