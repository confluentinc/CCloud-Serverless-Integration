#!/bin/bash

SQL_FILE=$1

if [[ "${SQL_FILE}" == "" ]]; then
  echo "Please provide the name of sql file to upload"
  exit
fi

KSQLDB_BASIC_AUTH_USER_INFO=$(jq -r '."ksql.basic.auth.user.info"' < aws-cli/aws-ccloud-creds.json)
KSQLDB_ENDPOINT=$(jq -r '."ksql.endpoint"' < aws-cli/aws-ccloud-creds.json)

echo "Using $KSQLDB_ENDPOINT for the ksql endpoint"

echo -e "\nSubmit KSQL queries for running the AWS Lambda demo from ${SQL_FILE} \n"
properties='"ksql.streams.auto.offset.reset":"earliest","ksql.streams.cache.max.bytes.buffering":"0"'
while read ksqlCmd; do
  echo -e "\n$ksqlCmd\n"
  response=$(curl -X POST "$KSQLDB_ENDPOINT"/ksql \
       -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
       -u "$KSQLDB_BASIC_AUTH_USER_INFO" \
       --silent \
       -d @<(cat <<EOF
{
  "ksql": "$ksqlCmd",
  "streamsProperties": {$properties}
}
EOF
))
  echo "$response"
  if [[ ! "$response" =~ "SUCCESS" ]]; then
    echo -e "\nERROR: KSQL command '$ksqlCmd' did not include \"SUCCESS\" in the response.  Please troubleshoot."
    exit 1
  fi
done < "$SQL_FILE"
echo -e "\nSleeping 20 seconds after submitting KSQL queries\n"
sleep 20