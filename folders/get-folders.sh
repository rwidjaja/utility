#!/bin/bash

# Define the variables
jwt=$(curl --insecure -s -X GET -u admin:password "https://ubuntu-atscale.atscaledomain.com:10500/default/auth")
base_url="https://ubuntu-atscale.atscaledomain.com:10500/api/1.0/org/default/folders"

# Get the data, process it with jq, and save the final output to a file
curl --insecure -H "Authorization:Bearer $jwt" "$base_url" | \
jq '
  {
    folders: (
      .response.child_folders | map(
        {
          folder_id: (if .id then .id else "nofolder" end),
          folder_name: .name,
          items: (.items // []) | map({item_id: .id, caption: .caption})
        }
      )
    ),
    NoFolder: (
      .response.items // [] | map({item_id: .id, caption: .caption})
    )
  } ' > file-description.json
curl --insecure -H "Authorization:Bearer $jwt" "$base_url" | \
 jq '
  {
    folders: (
      .response.child_folders | map({
        folder_id: (if .id then .id else "nofolder" end),
        folder_name: .name,
        items_ids: (.items // [] | map(.id))
      })
    ),
    NoFolder: (
      .response.items // [] | map(.id)
    )
  } ' > folder-output.json
