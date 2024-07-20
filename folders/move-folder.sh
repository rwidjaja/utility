#!/bin/bash

# Define the variables
jwt=$(curl --insecure -s -X GET -u admin:password "https://ubuntu-atscale.atscaledomain.com:10500/default/auth")
base_url="https://ubuntu-atscale.atscaledomain.com:10500/api/1.0/org/default/folders"

inputfile="folder-output.json"

# Check if the input file exists
if [ ! -f "$inputfile" ]; then
  echo "File $inputfile not found!"
  exit 1
fi

# Process folders
jq -c '.folders[]' "$inputfile" | while IFS= read -r folder; do
  folder_id=$(echo "$folder" | jq -r '.folder_id')
  items_ids=$(echo "$folder" | jq -r '.items_ids[]')

  for item_id in $items_ids; do
    # Make the curl request for each ID
    echo "Assigning item $item_id to folder $folder_id"
    curl --insecure -X POST -H "Authorization: Bearer $jwt" "$base_url/$folder_id/put/$item_id"
  done
done

echo "NoFolder items processing is skipped."
