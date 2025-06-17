#!/bin/bash

LOGDIR="/ifs/data/logs/drive_health"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/drive_health_$(date '+%Y%m%d_%H%M%S').log"

echo "=================================================" | tee -a "$LOGFILE"
echo "Isilon Drive Health Report - $(date)" | tee -a "$LOGFILE"
echo "=================================================" | tee -a "$LOGFILE"

# Section 1: isi devices drive list
echo -e "\n--- isi devices drive list --verbose ---" | tee -a "$LOGFILE"
isi devices drive list --verbose | tee -a "$LOGFILE"

# Section 2: SMART Status Summary
echo -e "\n--- SMART Status Summary (Good vs Concern) ---" | tee -a "$LOGFILE"

isi_for_array -s /usr/bin/isi_radish -a 2>&1 | grep -v 'cd: no such file or directory' | \
awk '
  BEGIN { good=0; bad=0 }
  tolower($0) ~ /smart status.*not exceeded/ {
    print "GOOD     : " $0;
    good++;
    next;
  }
  tolower($0) ~ /smart status/ {
    print "WARNING  : " $0;
    bad++;
  }
  END {
    print "\nSMART Summary:";
    printf "  Total GOOD Drives   : %d\n", good;
    printf "  Total WARNINGS      : %d\n", bad;
    if (bad > 0) {
      print "  --> Please investigate drives with warnings.";
    } else if (good > 0) {
      print "  --> All drives report SMART OK.";
    } else {
      print "  --> WARNING: No SMART data was parsed. Check formatting.";
    }
  }
' | tee -a "$LOGFILE"

# Section 3: SSD Endurance Summary
echo -e "\n--- SSD Endurance Summary ---" | tee -a "$LOGFILE"

isi_for_array -s /usr/bin/isi_radish -a 2>&1 | grep -v 'cd: no such file or directory' | \
awk -F: '
  tolower($2) ~ /percentage used endurance indicator/ {
    node = $1;
    # Try to extract a percentage (first number before parentheses)
    split($0, parts, "(");
    value = parts[1];
    gsub(/[^0-9]/, "", value);
    used = value + 0;
    printf "%s: %d%% used endurance\n", node, used;
    if (used >= 50) {
      printf "%s: !!! WARNING: high endurance usage (%d%%) !!!\n", node, used;
    }
  }
' | tee -a "$LOGFILE"

# Section 4: Drives not in HEALTHY state
echo -e "\n--- Drives not in HEALTHY state ---" | tee -a "$LOGFILE"

isi devices drive list --verbose | awk '
  BEGIN {
    RS="--------------------------------------------------------------------------------";
    FS="\n";
  }
  {
    state=""; serial=""; location="";
    for (i = 1; i <= NF; i++) {
      if ($i ~ /State:/)     { split($i, a, ":"); state = a[2]; sub(/^[ \t]+/, "", state); }
      if ($i ~ /Serial:/)    { split($i, a, ":"); serial = a[2]; sub(/^[ \t]+/, "", serial); }
      if ($i ~ /Location:/)  { split($i, a, ":"); location = a[2]; sub(/^[ \t]+/, "", location); }
    }
    if (state != "HEALTHY") {
      key = serial "|" location "|" state;
      bad[key]++;
    }
  }
  END {
    count = 0;
    for (k in bad) {
      split(k, parts, "|");
      printf "NOT HEALTHY: Location: %-10s Serial: %-15s State: %s\n", parts[2], parts[1], parts[3];
      count++;
    }
    print "\nNon-HEALTHY Drive Summary:";
    printf "  Total NON-HEALTHY Drives: %d\n", count;
    if (count > 0) {
      print "  --> Action recommended: check listed drives.";
    } else {
      print "  --> All drives are in HEALTHY state.";
    }
  }
' | tee -a "$LOGFILE"

echo -e "\nDone. Full report written to: $LOGFILE"
