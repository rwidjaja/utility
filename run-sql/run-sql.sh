#!/bin/bash

# Check if all arguments are provided
if [ $# -ne 5 ]; then
  echo "Usage: $0 <USERNAME> <PASSWORD> <QUERY_FILE> <HOSTNAME> <PROJECT_NAME>"
  exit 1
fi

# Define variables
USERNAME=$1
PASSWORD=$2
QUERY_FILE=$3
HOSTNAME=$4
PROJECT_NAME=$5
JWT_URL="https://$HOSTNAME:10500/default/auth"
QUERY_URL="https://$HOSTNAME:10502/query/orgId/default/submit"

# Fetch JWT token
jwt=$(curl --insecure -s -X GET -u $USERNAME:$PASSWORD "$JWT_URL")

# Check if JWT token was fetched successfully
if [ -z "$jwt" ]; then
  echo "Failed to fetch JWT token"
  exit 1
fi

# Check if the query file exists
if [ ! -f "$QUERY_FILE" ]; then
  echo "Query file $QUERY_FILE not found!"
  exit 1
fi

# Read the entire content of the query file
QUERIES=$(<"$QUERY_FILE")

# Split the queries using the separator ###
IFS='###' read -d '' -ra QUERY_ARRAY <<< "$QUERIES"

# Debug: print the number of queries found
echo "Found ${#QUERY_ARRAY[@]} queries."

# Iterate over each query and make the request
for QUERY in "${QUERY_ARRAY[@]}"; do
  # Remove leading and trailing whitespace from the query
  QUERY=$(echo "$QUERY" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Debug: print the current query
  echo "Processing query: $QUERY"

  # Define the payload for the current query
  PAYLOAD=$(cat <<EOM
{
  "language": "SQL",
  "query": "$QUERY",
  "context": {
    "organization": {
      "id": "default"
    },
    "environment": {
      "id": "default"
    },
    "project": {
      "name": "$PROJECT_NAME"
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
  echo "Payload: $PAYLOAD"

  # Make the curl request
  response=$(curl --insecure -s -w "%{http_code}" -o /dev/null -H "Authorization: Bearer $jwt" -H "Content-Type: application/json" -d "$PAYLOAD" -X POST "$QUERY_URL")

  # Check the response code
  if [ "$response" -ne 200 ]; then
    echo "Failed to execute query: $QUERY"
    echo "HTTP response code: $response"
  else
    echo "Successfully executed query: $QUERY"
  fi
done
