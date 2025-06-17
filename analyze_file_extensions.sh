#!/bin/bash
# Selective error handling instead of set -euo pipefail

# ===============================
# Configurable variables
# ===============================
ROOT_DIR="/mnt/libimages2"
LOGFILE="./file_extension_summary.log"
LOG_INTERVAL=10000
PROGRESS_SCAN=1  # Set to 1 to pre-scan total files, 0 to skip

# ===============================
# Internal counters and setup
# ===============================
declare -A ext_counts
declare -A ext_bytes
TOTAL_BYTES=0
TOTAL_FILES=0
TOTAL_FILES_EST=0
START_TIME=$(date +%s)

log_progress() {
    {
        echo "===================== LOG SNAPSHOT ====================="
        echo "Snapshot at: $(date)"
        echo "Files processed: $TOTAL_FILES"
        echo "Extension    Count    Size (TB)"
        for ext in "${!ext_counts[@]}"; do
            count=${ext_counts[$ext]}
            bytes=${ext_bytes[$ext]}
            tb=$(awk "BEGIN { printf \"%.2f\", $bytes / (1024^4) }")
            printf "%-12s %-8d %s\n" "$ext" "$count" "$tb"
        done | sort
        total_tb=$(awk "BEGIN { printf \"%.2f\", $TOTAL_BYTES / (1024^4) }")
        echo "--------------------------------------------------------"
        echo "TOTAL TB USED: $total_tb"
        echo "========================================================"
        echo
    } >> "$LOGFILE"
}

# ===============================
# Begin script
# ===============================
> "$LOGFILE"
echo "Starting script at $(date)" >> "$LOGFILE"
echo "Scanning: $ROOT_DIR" >> "$LOGFILE"
echo "Running as user: $(whoami)" >> "$LOGFILE"

# Check if ROOT_DIR exists and is accessible
if [[ ! -d "$ROOT_DIR" ]]; then
    echo "Error: Directory '$ROOT_DIR' does not exist or is not a directory" >> "$LOGFILE"
    exit 1
fi
if [[ ! -r "$ROOT_DIR" || ! -x "$ROOT_DIR" ]]; then
    echo "Error: No read or execute permissions for '$ROOT_DIR'" >> "$LOGFILE"
    exit 1
fi

# Test find command
echo "Testing find command..." >> "$LOGFILE"
stdbuf -oL find "$ROOT_DIR" -type f -print0 > /dev/null 2>>"$LOGFILE"
FIND_EXIT=$?
echo "test find exit status: $FIND_EXIT" >> "$LOGFILE"
if [[ $FIND_EXIT -ne 0 ]]; then
    echo "Error: Test find command failed with exit code $FIND_EXIT" >> "$LOGFILE"
    exit 1
fi

# Optional: Estimate total files for progress
if [[ $PROGRESS_SCAN -eq 1 ]]; then
    echo "Starting file count estimation..." >> "$LOGFILE"
    echo "Estimating total files..." >> "$LOGFILE"
    TOTAL_FILES_EST=$(stdbuf -oL find "$ROOT_DIR" -type f -print0 2>>"$LOGFILE" | tr -dc '\0' | wc -c)
    echo "Estimated total files: $TOTAL_FILES_EST" >> "$LOGFILE"
    echo "File count estimation completed." >> "$LOGFILE"
fi

# ===============================
# Main loop
# ===============================
echo "Starting main loop..." >> "$LOGFILE"
echo "Entering while loop..." >> "$LOGFILE"
while IFS= read -r -d '' file || [[ -n "$file" ]]; do
    [[ -z "$file" ]] && {
        echo "Empty file path encountered, skipping" >> "$LOGFILE"
        continue
    }
    ((TOTAL_FILES++))

    filename=$(basename "$file" 2>>"$LOGFILE") || {
        echo "Failed to basename: $file" >> "$LOGFILE"
        continue
    }

    ext="${filename##*.}"
    if [[ "$filename" == "$ext" ]]; then
        ext="(noext)"
    fi

    size=$(stdbuf -oL stat -c %s "$file" 2>>"$LOGFILE") || {
        echo "Failed to stat: $file" >> "$LOGFILE"
        continue
    }

    # Initialize arrays if unset
    if [[ -z "${ext_counts[$ext]+set}" ]]; then
        ext_counts["$ext"]=0
    fi
    if [[ -z "${ext_bytes[$ext]+set}" ]]; then
        ext_bytes["$ext"]=0
    fi

    # Increment counts safely
    ext_counts["$ext"]=$(( ext_counts["$ext"] + 1 )) || {
        echo "Failed to increment ext_counts for: $ext" >> "$LOGFILE"
        continue
    }
    ext_bytes["$ext"]=$(( ext_bytes["$ext"] + size )) || {
        echo "Failed to increment ext_bytes for: $ext" >> "$LOGFILE"
        continue
    }
    TOTAL_BYTES=$(( TOTAL_BYTES + size )) || {
        echo "Failed to update TOTAL_BYTES" >> "$LOGFILE"
        continue
    }

    # Progress indicator (terminal only)
    if [[ $(( TOTAL_FILES % LOG_INTERVAL )) -eq 0 ]]; then
        elapsed=$(( $(date +%s) - START_TIME ))
        if [[ $PROGRESS_SCAN -eq 1 && $TOTAL_FILES_EST -gt 0 ]]; then
            percent=$(awk "BEGIN { printf \"%.1f\", ($TOTAL_FILES * 100) / $TOTAL_FILES_EST }")
            printf "\rProcessed %d/%d files (%.1f%%) [%ds]" "$TOTAL_FILES" "$TOTAL_FILES_EST" "$percent" "$elapsed"
        else
            printf "\rProcessed %d files [%ds]" "$TOTAL_FILES" "$elapsed"
        fi
        log_progress
    fi
done < <(stdbuf -oL find "$ROOT_DIR" -type f -print0 2>>"$LOGFILE")

# Clear progress line
echo ""

# Capture find exit status
FIND_EXIT=$?
echo "find in main loop exit status: $FIND_EXIT" >> "$LOGFILE"
if [[ $FIND_EXIT -ne 0 ]]; then
    echo "Error: find command in main loop failed with exit code $FIND_EXIT" >> "$LOGFILE"
    exit 1
fi

# ===============================
# Final summary
# ===============================
log_progress
elapsed=$(( $(date +%s) - START_TIME ))
echo "Total runtime: $elapsed seconds" >> "$LOGFILE"
echo "Script completed successfully at $(date)" >> "$LOGFILE"
