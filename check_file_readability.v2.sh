#!/bin/bash
#------------------------------------------------------------------------------
# Variables:
LOGFILE="/ifs/systems/scripts/check_file_readability.v2.txt"
TIMEOUT_DURATION=100
DIRECTORY_START_PATH="/ifs/hydra/binaries/ingest_scratch/"
TOTAL_FILES=187340
DISPLAY_PROGRESS_NUMBER=100

# Initialize counters:
COUNT_FILES_PROCESSED=0
COUNT_OF_FAILED_FILES=0

#------------------------------------------------------------------------------
# Write a start timestamp to STDOUT and to the logfile:
start_time=$(date)
echo "Script started at: $start_time"
echo "Script started at: $start_time" >> "$LOGFILE"

#------------------------------------------------------------------------------
# Process each file recursively from DIRECTORY_START_PATH.
# Using process substitution (< <(find ...)) ensures the while loop runs in the current shell.
while IFS= read -r -d '' file; do
    # Try to read the file using a timeout.
    if ! timeout "$TIMEOUT_DURATION" dd if="$file" of=/dev/null bs=4096 count=1 2>/dev/null; then
        echo "$file" >> "$LOGFILE"
        COUNT_OF_FAILED_FILES=$(( COUNT_OF_FAILED_FILES + 1 ))
    fi

    # Increment the processed file count.
    COUNT_FILES_PROCESSED=$(( COUNT_FILES_PROCESSED + 1 ))

#	echo "$COUNT_FILES_PROCESSED"

    # If COUNT_FILES_PROCESSED is a multiple of DISPLAY_PROGRESS_NUMBER, show progress.
    if [ $(( COUNT_FILES_PROCESSED % DISPLAY_PROGRESS_NUMBER )) -eq 0 ]; then
        # Calculate percentage complete using bc.
        progress=$(echo "scale=1; $COUNT_FILES_PROCESSED*100.0/$TOTAL_FILES" | bc)
        echo "$(date)" >> "$LOGFILE"
        echo "Status: ${COUNT_FILES_PROCESSED} of ${TOTAL_FILES} files read [${progress}%] | Number of failed files: ${COUNT_OF_FAILED_FILES}" >> "$LOGFILE"
    fi
done < <(find "$DIRECTORY_START_PATH" -type f -print0)

#------------------------------------------------------------------------------
# Print final progress:
final_progress=$(echo "scale=1; $COUNT_FILES_PROCESSED*100.0/$TOTAL_FILES" | bc)
echo "$(date)" >> "$LOGFILE"
echo "Final Status: ${COUNT_FILES_PROCESSED} of ${TOTAL_FILES} files read [${final_progress}%] | Number of failed files: ${COUNT_OF_FAILED_FILES}" >> "$LOGFILE"

# Write an end timestamp:
end_time=$(date)
echo "Script ended at: $end_time"
echo "Script ended at: $end_time" >> "$LOGFILE"

