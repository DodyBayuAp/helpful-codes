# MySQL Table Copy Tool
# Copies a table from one database to another with progress tracking and upsert support

# Function to display progress
function Show-Progress {
    param(
        [string]$Activity,
        [int]$PercentComplete,
        [string]$Status
    )
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

# --- 1. Source Connection and Selection ---
$sourceConnected = $false
while (-not $sourceConnected) {
    $HostSource = (Read-Host "Source MySQL Host (default: localhost)").Trim()
    if ([string]::IsNullOrWhiteSpace($HostSource)) { $HostSource = "localhost" }

    $UserSource = (Read-Host "Source MySQL User (default: root)").Trim()
    if ([string]::IsNullOrWhiteSpace($UserSource)) { $UserSource = "root" }

    $SecurePasswordSource = Read-Host "Source MySQL Password" -AsSecureString
    $BSTRSource = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePasswordSource)
    $PasswordSource = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTRSource)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTRSource)

    Write-Host "`nConnecting to Source $HostSource..." -ForegroundColor Cyan

    # Set MySQL password as environment variable for source connection
    $env:MYSQL_PWD = $PasswordSource

    # Test connection and list databases
    $listDbs = & mysql -h $HostSource -u $UserSource -e "SHOW DATABASES;" -s --skip-column-names 2>&1
    if ($LASTEXITCODE -eq 0) {
        $sourceConnected = $true
        Write-Host "Connected to Source successfully!" -ForegroundColor Green
    }
    else {
        Write-Host "[Error] Connection to source failed: $listDbs" -ForegroundColor Red
        Write-Host "Please check your host, user, and password.`n" -ForegroundColor Yellow
    }
}

Write-Host "Available Databases on ${HostSource}:" -ForegroundColor Yellow
$listDbs | ForEach-Object { Write-Host " - $_" -ForegroundColor Gray }

$sourceDbValid = $false
while (-not $sourceDbValid) {
    $DbSource = (Read-Host "`nEnter Source Database").Trim()
    
    # List tables in source database with row counts and sizes
    $tableInfoQuery = "SELECT TABLE_NAME, TABLE_ROWS, ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS SIZE_MB FROM information_schema.TABLES WHERE TABLE_SCHEMA='$DbSource';"
    $listTables = & mysql -h $HostSource -u $UserSource -e "$tableInfoQuery" -s --skip-column-names 2>&1
    if ($LASTEXITCODE -eq 0) {
        $sourceDbValid = $true
    }
    else {
        Write-Host "[Error] Failed to access database '$DbSource'. List of databases above." -ForegroundColor Red
    }
}

Write-Host "Available Tables in ${DbSource} (Rows | Size MB):" -ForegroundColor Yellow
$listTables | ForEach-Object {
    $parts = $_ -split "\s+"
    if ($parts.Count -ge 3) {
        $name = $parts[0]
        $rows = $parts[1]
        $size = $parts[2]
        Write-Host (" - {0,-30} | {1,10} rows | {2,8} MB" -f $name, $rows, $size) -ForegroundColor Gray
    }
    else {
        Write-Host " - $_" -ForegroundColor Gray
    }
}

$sourceTableValid = $false
$selectedRows = 0
$selectedSize = 0
while (-not $sourceTableValid) {
    $TableSource = (Read-Host "`nEnter Source Table").Trim()
    # Get info for confirmation
    $infoQuery = "SELECT TABLE_ROWS, ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$DbSource' AND TABLE_NAME='$TableSource';"
    $tableInfo = & mysql -h $HostSource -u $UserSource -e "$infoQuery" -s --skip-column-names 2>&1
    
    if ($LASTEXITCODE -eq 0 -and ![string]::IsNullOrWhiteSpace($tableInfo)) {
        $parts = $tableInfo -split "\s+"
        $selectedRows = $parts[0]
        $selectedSize = $parts[1]
        $sourceTableValid = $true
    }
    else {
        Write-Host "[Error] Table '$TableSource' not found in '$DbSource'. Please check name." -ForegroundColor Red
    }
}

# --- 2. Target Connection and Selection ---
$targetConnected = $false
while (-not $targetConnected) {
    $HostTarget = (Read-Host "`nTarget MySQL Host (default: ${HostSource})").Trim()
    if ([string]::IsNullOrWhiteSpace($HostTarget)) { $HostTarget = $HostSource }

    $UserTarget = (Read-Host "Target MySQL User (default: ${UserSource})").Trim()
    if ([string]::IsNullOrWhiteSpace($UserTarget)) { $UserTarget = $UserSource }

    $SecurePasswordTarget = Read-Host "Target MySQL Password (press Enter if same as source)" -AsSecureString
    $PasswordTarget = ""
    if ($SecurePasswordTarget.Length -eq 0) {
        $PasswordTarget = $PasswordSource
    }
    else {
        $BSTRTarget = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePasswordTarget)
        $PasswordTarget = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTRTarget)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTRTarget)
    }

    Write-Host "Connecting to target host ${HostTarget}..." -ForegroundColor Cyan

    # Test connection to target
    $env:MYSQL_PWD = $PasswordTarget
    $listDbsTarget = & mysql -h $HostTarget -u $UserTarget -e "SHOW DATABASES;" -s --skip-column-names 2>&1
    if ($LASTEXITCODE -eq 0) {
        $targetConnected = $true
        Write-Host "Connected to Target successfully!" -ForegroundColor Green
    }
    else {
        Write-Host "[Error] Connection to target failed: $listDbsTarget" -ForegroundColor Red
        Write-Host "Please check your host, user, and password.`n" -ForegroundColor Yellow
    }
}

Write-Host "Available Databases on ${HostTarget}:" -ForegroundColor Yellow
$listDbsTarget | ForEach-Object { Write-Host " - $_" -ForegroundColor Gray }

$DbTarget = (Read-Host "`nEnter Target Database (or name of new DB)").Trim()

# --- 3. Summary and Confirmation ---
Write-Host "`n===============================================" -ForegroundColor Yellow
Write-Host "        MySQL TABLE COPY RESUME" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Yellow
Write-Host ("SOURCE      : {0}@{1}.{2}.{3}" -f $UserSource, $HostSource, $DbSource, $TableSource)
Write-Host ("TARGET      : {0}@{1}.{2}" -f $UserTarget, $HostTarget, $DbTarget)
Write-Host ("DATA        : {0} rows | {1} MB" -f $selectedRows, $selectedSize)
Write-Host "METHOD      : Create if not exists + Upsert (REPLACE INTO)"
Write-Host "===============================================" -ForegroundColor Yellow

$confirm = Read-Host "Proceed with copy? (y/n)"
if ($confirm.ToLower() -ne "y") {
    Write-Host "`nOperation cancelled by user." -ForegroundColor Red
    $env:MYSQL_PWD = $null
    exit 0
}

# --- 4. Validation and Structure ---
Write-Host "`nStarting copy process..." -ForegroundColor Cyan

# Check/Create Target DB
$env:MYSQL_PWD = $PasswordTarget
$null = & mysql -h $HostTarget -u $UserTarget -e "CREATE DATABASE IF NOT EXISTS \`$DbTarget\`;" 2>&1

# Check if target table exists
$checkTargetTable = & mysql -h $HostTarget -u $UserTarget -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$DbTarget' AND TABLE_NAME='$TableSource';" -s --skip-column-names 2>&1

if ($checkTargetTable -eq 0) {
    Write-Host "Creating target table structure..." -ForegroundColor Yellow
    # Create structure like source
    $env:MYSQL_PWD = $PasswordSource
    & mysqldump -h $HostSource -u $UserSource --no-data "$DbSource" "$TableSource" | 
    ForEach-Object { $env:MYSQL_PWD = $PasswordTarget; $_ } | 
    & mysql -h $HostTarget -u $UserTarget "$DbTarget"
}
else {
    Write-Host "Target table exists on $HostTarget. Will use upsert (REPLACE INTO)." -ForegroundColor Yellow
}

# --- 5. Data Transfer ---
$totalRows = $selectedRows
Write-Host "Transferring data..." -ForegroundColor Cyan
Show-Progress -Activity "Copying Table Data" -Status "Transferring..." -PercentComplete 50

# Use mysqldump with --replace for upsert logic
Write-Host "Dumping data from ${HostSource}..." -ForegroundColor Yellow
$env:MYSQL_PWD = $PasswordSource
$dumpData = & mysqldump -h $HostSource -u $UserSource --replace --no-create-info "$DbSource" "$TableSource" 2>&1

# Check if output contains error messages
if ($LASTEXITCODE -ne 0 -or ($dumpData -ne $null -and ($dumpData.ToString() -match "mysqldump: Error" -or $dumpData.ToString() -match "Couldn't find table"))) {
    Write-Host "`n[Error] Failed to dump data from source: $dumpData" -ForegroundColor Red
    $env:MYSQL_PWD = $null
    exit 1
}

Write-Host "Importing data to ${HostTarget}..." -ForegroundColor Yellow
$env:MYSQL_PWD = $PasswordTarget
$dumpData | & mysql -h $HostTarget -u $UserTarget "$DbTarget"

if ($LASTEXITCODE -eq 0) {
    Show-Progress -Activity "Copying Table Data" -Status "Completed" -PercentComplete 100
    Write-Host "`n[Success] Table copied successfully!" -ForegroundColor Green
}
else {
    Write-Host "`n[Error] Failed to import data to target." -ForegroundColor Red
}

# Cleanup
$env:MYSQL_PWD = $null
Write-Host "`nOperation completed." -ForegroundColor Gray
