#!/bin/bash

# MySQL Table Copy Tool for Linux/macOS
# Copies a specific table between databases/hosts with upsert support

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# --- 1. Source Connection and Selection ---
SOURCE_CONNECTED=false
while [ "$SOURCE_CONNECTED" = false ]; do
    read -p "Source MySQL Host (default: localhost): " HOST_SOURCE
    HOST_SOURCE=${HOST_SOURCE:-localhost}

    read -p "Source MySQL User (default: root): " USER_SOURCE
    USER_SOURCE=${USER_SOURCE:-root}

    read -s -p "Source MySQL Password: " PASS_SOURCE
    echo ""

    echo -e "\n${CYAN}Connecting to Source $HOST_SOURCE...${NC}"
    export MYSQL_PWD="$PASS_SOURCE"

    # Test connection and list databases
    LIST_DBS=$(mysql -h "$HOST_SOURCE" -u "$USER_SOURCE" -e "SHOW DATABASES;" -s --skip-column-names 2>&1)
    if [ $? -eq 0 ]; then
        SOURCE_CONNECTED=true
        echo -e "${GREEN}Connected to Source successfully!${NC}"
    else
        echo -e "${RED}[Error] Connection to source failed: $LIST_DBS${NC}"
        echo -e "${YELLOW}Please check your host, user, and password.${NC}\n"
    fi
done

echo -e "${YELLOW}Available Databases on $HOST_SOURCE:${NC}"
echo "$LIST_DBS" | while read -r db; do echo -e " - ${GRAY}$db${NC}"; done

SOURCE_DB_VALID=false
while [ "$SOURCE_DB_VALID" = false ]; do
    read -p "Enter Source Database: " DB_SOURCE
    
    # List tables in source database with row counts and sizes
    TABLE_INFO_QUERY="SELECT TABLE_NAME, TABLE_ROWS, ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$DB_SOURCE';"
    LIST_TABLES=$(mysql -h "$HOST_SOURCE" -u "$USER_SOURCE" -e "$TABLE_INFO_QUERY" -s --skip-column-names 2>&1)
    if [ $? -eq 0 ]; then
        SOURCE_DB_VALID=true
    else
        echo -e "${RED}[Error] Failed to access database '$DB_SOURCE'. List of databases above.${NC}"
    fi
done

echo -e "\n${YELLOW}Available Tables in $DB_SOURCE (Rows | Size MB):${NC}"
echo "$LIST_TABLES" | while read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    rows=$(echo "$line" | awk '{print $2}')
    size=$(echo "$line" | awk '{print $3}')
    printf " - %-30s | %10s rows | %8s MB\n" "$name" "$rows" "$size"
done | sed "s/^/$(echo -e ${GRAY})/; s/$/$(echo -e ${NC})/"

SOURCE_TABLE_VALID=false
while [ "$SOURCE_TABLE_VALID" = false ]; do
    read -p "Enter Source Table: " TABLE_SOURCE
    # Get info for confirmation
    INFO_QUERY="SELECT TABLE_ROWS, ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$DB_SOURCE' AND TABLE_NAME='$TABLE_SOURCE';"
    TABLE_INFO=$(mysql -h "$HOST_SOURCE" -u "$USER_SOURCE" -e "$INFO_QUERY" -s --skip-column-names 2>&1)
    
    if [ $? -eq 0 ] && [ -n "$TABLE_INFO" ]; then
        SELECTED_ROWS=$(echo "$TABLE_INFO" | awk '{print $1}')
        SELECTED_SIZE_MB=$(echo "$TABLE_INFO" | awk '{print $2}')
        SOURCE_TABLE_VALID=true
    else
        echo -e "${RED}[Error] Table '$TABLE_SOURCE' not found in '$DB_SOURCE'. Please check name.${NC}"
    fi
done

# --- 2. Target Connection and Selection ---
TARGET_CONNECTED=false
while [ "$TARGET_CONNECTED" = false ]; do
    read -p "Target MySQL Host (default: $HOST_SOURCE): " HOST_TARGET
    HOST_TARGET=${HOST_TARGET:-$HOST_SOURCE}

    read -p "Target MySQL User (default: $USER_SOURCE): " USER_TARGET
    USER_TARGET=${USER_TARGET:-$USER_SOURCE}

    read -s -p "Target MySQL Password (press Enter if same as source): " PASS_TARGET
    echo ""
    if [ -z "$PASS_TARGET" ]; then
        PASS_TARGET="$PASS_SOURCE"
    fi

    echo -e "${CYAN}Connecting to target host $HOST_TARGET...${NC}"
    export MYSQL_PWD="$PASS_TARGET"
    LIST_DBS_TARGET=$(mysql -h "$HOST_TARGET" -u "$USER_TARGET" -e "SHOW DATABASES;" -s --skip-column-names 2>&1)
    if [ $? -eq 0 ]; then
        TARGET_CONNECTED=true
        echo -e "${GREEN}Connected to Target successfully!${NC}"
    else
        echo -e "${RED}[Error] Connection to target failed: $LIST_DBS_TARGET${NC}"
        echo -e "${YELLOW}Please check your host, user, and password.${NC}\n"
    fi
done

echo -e "${YELLOW}Available Databases on $HOST_TARGET:${NC}"
echo "$LIST_DBS_TARGET" | while read -r db; do echo -e " - ${GRAY}$db${NC}"; done

read -p "Enter Target Database (or name of new DB): " DB_TARGET

# --- 3. Summary and Confirmation ---
echo -e "\n${YELLOW}===============================================${NC}"
echo -e "        ${CYAN}MySQL TABLE COPY RESUME${NC}"
echo -e "${YELLOW}===============================================${NC}"
echo -e "SOURCE      : $USER_SOURCE@$HOST_SOURCE.$DB_SOURCE.$TABLE_SOURCE"
echo -e "TARGET      : $USER_TARGET@$HOST_TARGET.$DB_TARGET"
echo -e "DATA        : $SELECTED_ROWS rows | $SELECTED_SIZE_MB MB"
echo -e "METHOD      : Create if not exists + Upsert (REPLACE INTO)"
echo -e "${YELLOW}===============================================${NC}"

read -p "Proceed with copy? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "\n${RED}Operation cancelled by user.${NC}"
    unset MYSQL_PWD
    exit 0
fi

# --- 4. Validation and Structure ---
echo -e "\n${CYAN}Starting copy process...${NC}"

# Check/Create Target DB
export MYSQL_PWD="$PASS_TARGET"
mysql -h "$HOST_TARGET" -u "$USER_TARGET" -e "CREATE DATABASE IF NOT EXISTS \`$DB_TARGET\`;" 2>/dev/null

# Check if target table exists
CHECK_TARGET_TABLE=$(mysql -h "$HOST_TARGET" -u "$USER_TARGET" -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$DB_TARGET' AND TABLE_NAME='$TABLE_SOURCE';" -s --skip-column-names 2>&1)

if [ "$CHECK_TARGET_TABLE" -eq 0 ]; then
    echo -e "${YELLOW}Creating target table structure...${NC}"
    export MYSQL_PWD="$PASS_SOURCE"
    mysqldump -h "$HOST_SOURCE" -u "$USER_SOURCE" --no-data "$DB_SOURCE" "$TABLE_SOURCE" | \
    (export MYSQL_PWD="$PASS_TARGET"; mysql -h "$HOST_TARGET" -u "$USER_TARGET" "$DB_TARGET")
else
    echo -e "${YELLOW}Target table exists on $HOST_TARGET. Will use upsert (REPLACE INTO).${NC}"
fi

# --- 5. Data Transfer ---
echo -e "${CYAN}Transferring data...${NC}"

# Calculate bytes for pv
SIZE_BYTES=$(echo "$SELECTED_SIZE_MB * 1024 * 1024" | bc | cut -d. -f1)

if command -v pv &> /dev/null; then
    export MYSQL_PWD="$PASS_SOURCE"
    mysqldump -h "$HOST_SOURCE" -u "$USER_SOURCE" --replace --no-create-info "$DB_SOURCE" "$TABLE_SOURCE" | \
    pv -s "$SIZE_BYTES" -N "Transferring" | \
    (export MYSQL_PWD="$PASS_TARGET"; mysql -h "$HOST_TARGET" -u "$USER_TARGET" "$DB_TARGET")
    
    DUMP_STATUS=${PIPESTATUS[0]}
    IMPORT_STATUS=${PIPESTATUS[2]}
else
    echo -e "${YELLOW}Note: Install 'pv' for progress tracking (sudo apt install pv)${NC}"
    export MYSQL_PWD="$PASS_SOURCE"
    mysqldump -h "$HOST_SOURCE" -u "$USER_SOURCE" --replace --no-create-info "$DB_SOURCE" "$TABLE_SOURCE" | \
    (export MYSQL_PWD="$PASS_TARGET"; mysql -h "$HOST_TARGET" -u "$USER_TARGET" "$DB_TARGET")
    
    DUMP_STATUS=${PIPESTATUS[0]}
    IMPORT_STATUS=${PIPESTATUS[1]}
fi

if [ $DUMP_STATUS -eq 0 ] && [ $IMPORT_STATUS -eq 0 ]; then
    echo -e "\n${GREEN}[Success] Table copied successfully!${NC}"
else
    echo -e "\n${RED}[Error] Failed to copy data.${NC}"
    [ $DUMP_STATUS -ne 0 ] && echo -e "${RED}- Failed to dump data from source.${NC}"
    [ $IMPORT_STATUS -ne 0 ] && echo -e "${RED}- Failed to import data to target.${NC}"
fi

# Cleanup
unset MYSQL_PWD
echo -e "\n${GRAY}Operation completed.${NC}"
