#!/bin/bash

read -p "MySQL User: " USER
read -s -p "MySQL Password: " PASS
echo ""
read -p "Source Database Name: " DB_SOURCE
read -p "Target Database Name: " DB_TARGET

# 1. Calculate estimated database size for progress bar
SIZE_BYTES=$(mysql -u $USER -p$PASS -e "SELECT SUM(data_length + index_length) FROM information_schema.TABLES WHERE table_schema='$DB_SOURCE';" -s --skip-column-names)

echo -e "\n--- Starting Clone: $DB_SOURCE -> $DB_TARGET ---"

# 2. Create target database
mysql -u $USER -p$PASS -e "CREATE DATABASE IF NOT EXISTS $DB_TARGET;"

# 3. Run mysqldump with pv (Pipe Viewer)
# pv -s provides total size estimation for accurate progress bar
mysqldump -u $USER -p$PASS --routines --triggers --events --opt $DB_SOURCE \
| pv -s $SIZE_BYTES -N "Transfer Data" \
| mysql -u $USER -p$PASS $DB_TARGET

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo -e "\n[Success] Database cloned successfully!"
else
    echo -e "\n[Error] An error occurred during the cloning process."
fi
