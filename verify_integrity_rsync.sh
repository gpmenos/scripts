#!/bin/bash
set -euo pipefail

# ================================
# User-configurable variables
# ================================
SOURCE="/path/to/source"
DEST="/path/to/destination"
LOGFILE="/path/to/logfile.log"

# ================================
# Function to log messages with timestamp
# ================================
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') : $*"
}

# ================================
# Start logging
# ================================
{
    log "========================================"
    log "Starting data integrity verification."
    log "Source:      ${SOURCE}"
    log "Destination: ${DEST}"
} >> "$LOGFILE"

# ================================
# Calculate total size of data to verify
# ================================
TOTAL_SIZE=$(du -sb "$SOURCE" 2>/dev/null | awk '{print $1}')
if [[ -z "$TOTAL_SIZE" ]]; then
    log "ERROR: Could not determine total size of ${SOURCE}." >> "$LOGFILE"
    exit 1
fi

{
    log "Total size to verify: ${TOTAL_SIZE} bytes."
    log "Starting rsync dry-run with checksum comparison..."
} >> "$LOGFILE"

# ================================
# Run rsync with checksum, recursive, dry-run, and overall progress
# ================================
# The trailing slash after SOURCE is important so that rsync copies the contents.
# --info=progress2 shows a running overall progress line.
rsync -rcn --info=progress2 "${SOURCE}/" "${DEST}/" 2>&1 | while IFS= read -r line; do
    # Log each rsync output line with a timestamp.
    log "$line" >> "$LOGFILE"
    
    # Attempt to extract a progress percentage from the line.
    if [[ "$line" =~ ([0-9]{1,3})% ]]; then
        PERCENT=${BASH_REMATCH[1]}
        log "Progress: ${PERCENT}% completed." >> "$LOGFILE"
    fi
done

log "Data integrity verification complete." >> "$LOGFILE"
log "========================================" >> "$LOGFILE"
