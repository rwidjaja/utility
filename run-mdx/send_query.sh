#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 6 ]; then
  echo "Usage: $0 username password project_name cube_name hostname querytxt"
  exit 1
fi

# Assign arguments to variables
username="$1"
password="$2"
project_name="$3"
cube_name="$4"
hostname="$5"
querytxt="$6"

# Fetch JWT token
jwt=$(curl --insecure -s -X GET -u "$username:$password" "https://$hostname:10500/default/auth")

if [ -z "$jwt" ]; then
  echo "Failed to retrieve JWT token"
  exit 1
fi

# Define the endpoint URL
endpoint="https://$hostname:10502/xmla/default"

# Read the entire content of the query file
queries=$(<"$querytxt")

# Split queries based on the delimiter ###
IFS='###' read -d '' -ra query_array <<< "$queries"

# Process each query
for query in "${query_array[@]}"; do
  # Remove leading and trailing whitespace from the query
  query=$(echo "$query" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  if [[ -n "$query" ]]; then
    # XML payload using a heredoc for multi-line content
    xml_payload=$(cat <<EOF
<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">
  <Body>
    <Execute xmlns="urn:schemas-microsoft-com:xml-analysis">
      <Command>
        <Statement><![CDATA[
$query
]]></Statement>
      </Command>
      <Properties>
        <PropertyList>
          <Catalog>$project_name</Catalog>
          <Cube>$cube_name</Cube>
        </PropertyList>
      </Properties>
    </Execute>
  </Body>
</Envelope>
EOF
    )

    # Send the request using curl
    response=$(curl --insecure -s -X POST \
      -H "Authorization: Bearer $jwt" \
      -H "Content-Type: application/xml" \
      -d "$xml_payload" \
      "$endpoint")

    echo "Response for query: $query"
    echo "$response"
    echo "--------------------------------"
  fi
done
