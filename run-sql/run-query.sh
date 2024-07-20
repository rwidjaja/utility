#!/bin/bash

# Function to reformat SQL query
format_sql() {
    local sql="$1"

    # Remove newlines and extra spaces
    sql=$(echo "$sql" | tr -d '\n' | sed 's/  */ /g')

    # Replace double quotes with backticks
    sql=$(echo "$sql" | sed 's/"\([^"]*\)"/`\1`/g')

    # Handle cases where backticks are needed for keywords
    sql=$(echo "$sql" | sed 's/`\(`*\)`/`\1`/g')

    # Ensure SQL statement is on a single line
    sql=$(echo "$sql" | tr -s ' ')

    # Output the reformatted SQL
    echo "$sql"
}

# Function to execute SQL queries
sql() {
    local username="$1"
    local password="$2"
    local hostname="$3"
    local project_name="$4"
    local query="$5"

    JWT_URL="https://$hostname:10500/default/auth"
    QUERY_URL="https://$hostname:10502/query/orgId/default/submit"

    # Fetch JWT token
    jwt=$(curl --insecure -s -X GET -u "$username:$password" "$JWT_URL")

    # Check if JWT token was fetched successfully
    if [ -z "$jwt" ]; then
        echo "Failed to fetch JWT token"
        return
    fi

    # Reformat SQL query
    query=$(format_sql "$query")

    # Define the payload for the SQL query
    payload=$(cat <<EOM
{
  "language": "SQL",
  "query": "$query",
  "context": {
    "organization": {
      "id": "default"
    },
    "environment": {
      "id": "default"
    },
    "project": {
      "name": "$project_name"
    }
  },
  "aggregation": {
    "useAggregates": false,
    "genAggregates": false
  },
  "fakeResults": false,
  "dryRun": false,
  "useLocalCache": true,
  "timeout": "2.minutes"
}
EOM
)

    # Debug: print the payload
    echo "Payload for SQL query: $payload"

    # Make the curl request
    response=$(curl --insecure -s -w "%{http_code}" -o /dev/null -H "Authorization: Bearer $jwt" -H "Content-Type: application/json" -d "$payload" -X POST "$QUERY_URL")

    # Check the response code
    if [ "$response" -ne 200 ]; then
        echo "Failed to execute SQL query: $query"
        echo "HTTP response code: $response"
    else
        echo "Successfully executed SQL query: $query"
    fi
}

# Function to execute Analytic (MDX/DAX) queries
analytic() {
    local username="$1"
    local password="$2"
    local project_name="$3"
    local cube_name="$4"
    local hostname="$5"
    local query="$6"

    # Define the endpoint URL for Analytic queries
    endpoint="https://$hostname:10502/xmla/default"

    # Fetch JWT token
    jwt=$(curl --insecure -s -X GET -u "$username:$password" "https://$hostname:10500/default/auth")

    # Check if JWT token was fetched successfully
    if [ -z "$jwt" ]; then
        echo "Failed to retrieve JWT token"
        return
    fi

    # Define the XML payload for the Analytic query
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

    echo "Response for Analytic query: $query"
    echo "$response"
    echo "--------------------------------"
}

# Main script starts here

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
query_file="$6"

# Read the entire content of the query file
queries=$(<"$query_file")

# Split queries using the separator ###
IFS='###' read -d '' -ra query_array <<< "$queries"

# Initialize variables
block_type=""

# Iterate over each block
for block in "${query_array[@]}"; do
    # Remove leading and trailing whitespace from the block
    block=$(echo "$block" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Skip empty blocks
    if [ -z "$block" ]; then
        continue
    fi

    # Determine block type and query text
    if [[ "$block" == *"Analytic"* ]]; then
        block_type="Analytic"
        query_text=$(echo "$block" | sed 's/^Analytic//')
        query_text=$(echo "$query_text" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        analytic "$username" "$password" "$project_name" "$cube_name" "$hostname" "$query_text"
    elif [[ "$block" == *"SQL"* ]]; then
        block_type="SQL"
        query_text=$(echo "$block" | sed 's/^SQL//')
        query_text=$(echo "$query_text" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        sql "$username" "$password" "$hostname" "$project_name" "$query_text"
    else
        echo "Unknown block type or empty block."
        echo "--------------------------------"
    fi
done