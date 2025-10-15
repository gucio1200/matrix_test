#!/bin/bash

# Ensure the script exits immediately if a command exits with a non-zero status
set -e

# Optional workdir filter (second argument)
FILTER="$1"

# Read environment variables
INPUT_LIST=(${CHANGED_FILES})    # List of changed files from environment variables, converted to an array

# Initialize the JSON output with an empty 'include' array
OUTPUT='{"include": []}'

# Loop through each changed file path
for paths in "${INPUT_LIST[@]}"; do
  # Support trigger on shared secrets change
  if [[ "$paths" =~ ^([^/]+)/secrets ]]; then
    # secrets should be handled only by init in its folders...
    paths=$(find "${BASH_REMATCH[1]}" -type d -name "init" -printf '%h\n' 2>/dev/null || true)
  fi


  for path in $paths; do
    # Determine the depth of the current file path based on the number of '/' characters
    DEPTH=$(echo "$path" | awk -F'/' '{print NF}')
    REQUIRED_DEPTH=$((4 - DEPTH))

    # Find subfolders at the required depth relative to the specified directory depth
    if [[ $REQUIRED_DEPTH -ge 0 ]]; then
      SUBFOLDERS=$(find "$path" -type d -mindepth $REQUIRED_DEPTH -maxdepth $REQUIRED_DEPTH 2>/dev/null || true)
    else
      SUBFOLDERS="$path"
    fi

    # Loop through each discovered subfolder
    for folder in $SUBFOLDERS; do
      # Extract workspace, region, and cluster names by splitting the folder path
      IFS='/' read -r workspace region cluster workdir _ <<< "$folder"

      # Apply workdir filter if provided
      if [[ -n "$FILTER" && "$workdir" != "$FILTER" ]]; then
        continue
      fi

      # Append extracted values to the JSON output using jq
      OUTPUT=$(echo "$OUTPUT" | jq --arg workspace "$workspace" --arg region "$region" --arg cluster "$cluster" --arg workdir "$workdir" \
      '.include += [{"workspace": $workspace, "region": $region, "cluster": $cluster, "workdir": $workdir}]')
    done
  done
done
# Remove duplicate entries from the JSON output
OUTPUT=$(echo "$OUTPUT" | jq -c '.include |= unique')

# Print the final JSON output
echo "$OUTPUT"
