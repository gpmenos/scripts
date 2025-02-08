#!/bin/bash
set -euo pipefail

# ================================
# User-configurable variables
# ================================
SOURCE="/path/to/source"         # Path to the source directory
DEST="/path/to/destination"      # Path to the destination directory
LOGFILE="/path/to/logfile.log"   # Log file for output messages
MANIFEST="/tmp/source_manifest.txt"  # Temporary manifest file

# ================================
# Function to log messages with timestamp
# ================================
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') : $*"
}

# ================================
# Start Logging
# ================================
{
    log "========================================"
    log "Starting data integrity verification using hashdeep."
    log "Source:      ${SOURCE}"
    log "Destination: ${DEST}"
    log "Manifest:    ${MANIFEST}"
} >> "$LOGFILE"

# ================================
# Generate manifest for the source directory
# ================================
log "Generating manifest for source data..." >> "$LOGFILE"
if ! hashdeep -r "$SOURCE" > "$MANIFEST"; then
    log "ERROR: Failed to generate manifest for ${SOURCE}." >> "$LOGFILE"
    exit 1
fi

# ================================
# Count total number of files from the manifest
# ================================
TOTAL_FILES=$(wc -l < "$MANIFEST")
if [[ -z "$TOTAL_FILES" || "$TOTAL_FILES" -eq 0 ]]; then
    log "ERROR: No files found in manifest for ${SOURCE}." >> "$LOGFILE"
    exit 1
fi
log "Total files in manifest: ${TOTAL_FILES}" >> "$LOGFILE"

# ================================
# Verify the destination against the manifest
# ================================
log "Starting verification of destination using hashdeep..." >> "$LOGFILE"
CURRENT_COUNT=0

# We run hashdeep in audit mode (-a) using the manifest (-k).
# The output is processed line-by-line for logging and progress indication.
hashdeep -r -a -k "$MANIFEST" "$DEST" 2>&1 | while IFS= read -r line; do
    ((CURRENT_COUNT++))
    # Calculate approximate percentage of progress.
    PERCENT=$(( 100 * CURRENT_COUNT / TOTAL_FILES ))
    log "[${CURRENT_COUNT}/${TOTAL_FILES} ~${PERCENT}%] ${line}" >> "$LOGFILE"
done

log "Data integrity verification complete." >> "$LOGFILE"
log "========================================" >> "$LOGFILE"
