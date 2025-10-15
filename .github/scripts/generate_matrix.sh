#!/bin/bash

set -e

# Read environment variables
INPUT_LIST=(${CHANGED_FILES})    # List of changed files from environment variables

# Initialize JSON output as an empty object
OUTPUT='{}'

# Loop through each changed file path
for paths in "${INPUT_LIST[@]}"; do
  # Support trigger on shared secrets change
  if [[ "$paths" =~ ^([^/]+)/secrets ]]; then
    paths=$(find "${BASH_REMATCH[1]}" -type d -name "init" -printf '%h\n' 2>/dev/null || true)
  fi

  for path in $paths; do
    DEPTH=$(echo "$path" | awk -F'/' '{print NF}')
    REQUIRED_DEPTH=$((4 - DEPTH))

    if [[ $REQUIRED_DEPTH -ge 0 ]]; then
      SUBFOLDERS=$(find "$path" -type d -mindepth $REQUIRED_DEPTH -maxdepth $REQUIRED_DEPTH 2>/dev/null || true)
    else
      SUBFOLDERS="$path"
    fi

    for folder in $SUBFOLDERS; do
      IFS='/' read -r workspace region cluster workdir _ <<< "$folder"

      # Initialize array for this workdir if not exists
      if ! echo "$OUTPUT" | jq -e ".\"$workdir\"" >/dev/null 2>&1; then
        OUTPUT=$(echo "$OUTPUT" | jq ".\"$workdir\" = {\"include\": []}")
      fi

      # Append the object to the include array
      OUTPUT=$(echo "$OUTPUT" | jq --arg workspace "$workspace" --arg region "$region" --arg cluster "$cluster" --arg workdir "$workdir" \
        ".\"$workdir\".include += [{\"workspace\": \$workspace, \"region\": \$region, \"cluster\": \$cluster, \"workdir\": \$workdir}]")
    done
  done
done

# Deduplicate each include array
OUTPUT=$(echo "$OUTPUT" | jq -c 'to_entries | map(.value.include |= unique) | from_entries')

# Print final JSON
echo "$OUTPUT"
