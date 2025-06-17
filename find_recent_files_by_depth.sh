#!/bin/bash

# ===================== Configurable Variables =====================
START_DIR="/ifs"            # Root directory to start the search
MAX_DEPTH=4                 # Max directory depth (e.g. 3 levels deep)
DAYS_OLD=20                 # Files modified in the last N days
MAX_FILES=0             # Max number of files to process; 0 means unlimited
LOGFILE="./recent_files.log"
CSVFILE="./recent_files.csv"
SUMMARY_FILE="./summary_by_dir.log"
# ==================================================================

# Start log files
echo "Scan started at $(date)" > "$LOGFILE"
echo "Scanning $START_DIR to depth $MAX_DEPTH for files modified in the last $DAYS_OLD days." >> "$LOGFILE"
if [[ "$MAX_FILES" -gt 0 ]]; then
  echo "Limiting to first $MAX_FILES files." >> "$LOGFILE"
else
  echo "No limit on number of files." >> "$LOGFILE"
fi
echo "" >> "$LOGFILE"

# Headers
echo -e "Date Modified\t\tSize (bytes)\tOwner\t\tGroup\t\tPath" >> "$LOGFILE"
echo "-------------------------------------------------------------------------------------------" >> "$LOGFILE"
echo '"Date Modified","Size (bytes)","Owner","Group","Path"' > "$CSVFILE"

# Initialize counters
COUNT=0
TOTAL_SIZE=0

# Start file loop
find "$START_DIR" -type f -mtime "-$DAYS_OLD" -maxdepth "$MAX_DEPTH" -print0 |
while IFS= read -r -d '' FILE; do
  if lsout=$(ls -ld "$FILE" 2>/dev/null); then
    # Parse with array read to prevent field shifting
    read -r PERMS LINKS OWNER GROUP SIZE MONTH DAY TIME REST <<< "$lsout"

    # Validate that SIZE is a number
    if [[ "$SIZE" =~ ^[0-9]+$ ]]; then
      MOD_DATE="$MONTH $DAY $TIME"
      SIZE_RAW="$SIZE"
      SIZE_FMT=$(printf "%'d" "$SIZE_RAW")

      # Append to log
      printf "%s\t%s\t%-10s\t%-10s\t%s\n" "$MOD_DATE" "$SIZE_FMT" "$OWNER" "$GROUP" "$FILE" >> "$LOGFILE"

      # Append to CSV
      echo "\"$MOD_DATE\",\"$SIZE_RAW\",\"$OWNER\",\"$GROUP\",\"$FILE\"" >> "$CSVFILE"

      COUNT=$((COUNT + 1))
      TOTAL_SIZE=$((TOTAL_SIZE + SIZE_RAW))

      if (( COUNT % 100 == 0 )); then
        echo "Processed $COUNT files..."
      fi
    else
      echo "WARN: Unexpected ls output, could not parse size for: $FILE" >> "$LOGFILE"
    fi
  else
    echo "WARN: ls failed on: $FILE" >> "$LOGFILE"
  fi

  if [[ "$MAX_FILES" -gt 0 && "$COUNT" -ge "$MAX_FILES" ]]; then
    break
  fi
done

# End of scan summary
echo "" >> "$LOGFILE"
echo "Scan completed at $(date)" >> "$LOGFILE"
echo "Found $COUNT files, total size: $(printf "%'d" "$TOTAL_SIZE") bytes." >> "$LOGFILE"

# Summary by directory level
echo "Generating summary by directory..." > "$SUMMARY_FILE"
awk -F'\t' '{print $5}' "$LOGFILE" | awk -F/ -v depth="$MAX_DEPTH" '
{
  path = ""
  for (i=2; i<=depth+1 && i<=NF; i++) {
    path = path "/" $i
  }
  count[path]++
}
END {
  for (dir in count)
    print count[dir], "files in", dir
}' | sort -nr >> "$SUMMARY_FILE"

# Console summary
echo ""
echo "====== Summary ======"
echo "Total files: $COUNT"
echo "Total size : $(printf "%'d" "$TOTAL_SIZE") bytes"
echo "Top directories with recent files:"
head -n 10 "$SUMMARY_FILE"
