#!/bin/bash

# Database Clone Tool for Linux/macOS
# Clones MySQL/MariaDB databases with progress tracking

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

read -p "MySQL User: " USER
read -s -p "MySQL Password: " PASS
echo ""
read -p "Source Database Name: " DB_SOURCE
read -p "Target Database Name: " DB_TARGET

# Set MySQL password as environment variable to avoid interactive prompt
export MYSQL_PWD="$PASS"

echo -e "\n${CYAN}--- Starting Clone: $DB_SOURCE -> $DB_TARGET ---${NC}"

# Verify source database exists
echo -e "${YELLOW}Verifying source database exists...${NC}"
CHECK_DB_QUERY="SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$DB_SOURCE';"
DB_CHECK=$(mysql -u "$USER" -e "$CHECK_DB_QUERY" -s --skip-column-names 2>&1)

if [ $? -ne 0 ]; then
    # Check if it's an authentication error
    if echo "$DB_CHECK" | grep -q "Access denied\|ERROR 1045"; then
        echo -e "${RED}[Error] Authentication failed - Wrong username or password!${NC}"
        echo -e "${YELLOW}Please check your MySQL credentials${NC}"
    else
        echo -e "${RED}[Error] Failed to connect to MySQL server${NC}"
        echo -e "${YELLOW}Please check your MySQL server status${NC}"
    fi
    echo -e "${RED}Error details: $DB_CHECK${NC}"
    unset MYSQL_PWD
    exit 1
fi

if [ -z "$DB_CHECK" ]; then
    echo -e "${RED}[Error] Source database '$DB_SOURCE' not found!${NC}"
    
    # List available databases to help user
    echo -e "\n${YELLOW}Available databases:${NC}"
    LIST_DB_QUERY="SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys');"
    AVAILABLE_DBS=$(mysql -u "$USER" -e "$LIST_DB_QUERY" -s --skip-column-names 2>&1)
    
    if [ $? -eq 0 ] && [ -n "$AVAILABLE_DBS" ]; then
        echo "$AVAILABLE_DBS" | while read -r db; do
            echo -e "  ${CYAN}- $db${NC}"
        done
    else
        echo -e "  ${NC}(Unable to list databases)${NC}"
    fi
    
    unset MYSQL_PWD
    exit 1
fi

echo -e "${GREEN}Source database verified: $DB_SOURCE${NC}"

# Calculate estimated database size for progress bar
echo -e "${YELLOW}Calculating database size...${NC}"
SIZE_QUERY="SELECT COALESCE(SUM(data_length + index_length), 0) FROM information_schema.TABLES WHERE table_schema='$DB_SOURCE';"
SIZE_BYTES=$(mysql -u "$USER" -e "$SIZE_QUERY" -s --skip-column-names 2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}[Error] Failed to calculate database size${NC}"
    echo -e "${RED}Error: $SIZE_BYTES${NC}"
    unset MYSQL_PWD
    exit 1
fi

SIZE_MB=$(echo "scale=2; $SIZE_BYTES / 1048576" | bc)
echo -e "${GREEN}Database size: ${SIZE_MB} MB${NC}"

# Create target database
echo -e "${YELLOW}Creating target database...${NC}"
CREATE_RESULT=$(mysql -u "$USER" -e "CREATE DATABASE IF NOT EXISTS \`$DB_TARGET\`;" 2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}[Error] Failed to create target database${NC}"
    echo -e "${RED}Error: $CREATE_RESULT${NC}"
    unset MYSQL_PWD
    exit 1
fi

echo -e "${GREEN}Target database created successfully${NC}"

# Clone database with progress tracking
echo -e "\n${CYAN}Cloning database...${NC}"

# Check if pv is available
if command -v pv &> /dev/null; then
    # Use pv for progress bar
    mysqldump -u "$USER" --routines --triggers --events --opt "$DB_SOURCE" 2>&1 \
    | pv -s "$SIZE_BYTES" -N "Transfer Data" \
    | mysql -u "$USER" "$DB_TARGET" 2>&1
    
    DUMP_STATUS=${PIPESTATUS[0]}
    IMPORT_STATUS=${PIPESTATUS[2]}
else
    # Fallback without pv
    echo -e "${YELLOW}Note: Install 'pv' for progress tracking (sudo apt install pv)${NC}"
    mysqldump -u "$USER" --routines --triggers --events --opt "$DB_SOURCE" 2>&1 \
    | mysql -u "$USER" "$DB_TARGET" 2>&1
    
    DUMP_STATUS=${PIPESTATUS[0]}
    IMPORT_STATUS=${PIPESTATUS[1]}
fi

# Check results
if [ $DUMP_STATUS -eq 0 ] && [ $IMPORT_STATUS -eq 0 ]; then
    echo -e "\n${GREEN}[Success] Database cloned successfully!${NC}"
    echo -e "${CYAN}Source: $DB_SOURCE -> Target: $DB_TARGET${NC}"
else
    echo -e "\n${RED}[Error] An error occurred during the cloning process${NC}"
    if [ $DUMP_STATUS -ne 0 ]; then
        echo -e "${RED}Failed to dump source database${NC}"
    fi
    if [ $IMPORT_STATUS -ne 0 ]; then
        echo -e "${RED}Failed to import to target database${NC}"
    fi
    unset MYSQL_PWD
    exit 1
fi

# Clear password from memory
unset MYSQL_PWD

echo -e "\n${NC}Clone operation completed at $(date '+%Y-%m-%d %H:%M:%S')${NC}"
