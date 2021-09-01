#!/bin/bash

if test ! -f ccloud_library.sh; then
   echo "The ccloud_library script not found.
   Getting it now via wqet command"
   wget -O ccloud_library.sh https://raw.githubusercontent.com/confluentinc/examples/latest/utils/ccloud_library.sh
fi

source ./ccloud_library.sh

export CLUSTER_CLOUD=aws
export CLUSTER_REGION=us-west-2
export EXAMPLE=ConfluentCloudLambdaIntegration
BUILD_KSQLDB_APP=true

ccloud::create_ccloud_stack $BUILD_KSQLDB_APP
MAX_WAIT=720
echo "Now waiting up to $MAX_WAIT seconds for the ksqlDB cluster to be UP"
ccloud::retry $MAX_WAIT ccloud::validate_ccloud_ksqldb_endpoint_ready "$KSQLDB_ENDPOINT" || exit 1
echo "Successfully created ksqlDB"
echo "Now creating topics"

for topic in stocktrade stock_users user_trades trade-settlements; do
    ccloud kafka topic create $topic;
  done


echo "Now setting ACLs to all the ksqlDB app to use topics"
ksqlDBAppId=$(ccloud ksql app list | grep "$KSQLDB_ENDPOINT" | awk '{print $1}')
ccloud ksql app configure-acls "$ksqlDBAppId" stocktrade stock_users user_trades trade-settlements
KSQLDB_SERVICE_ACCOUNT_ID=$(ccloud kafka cluster list -o json | jq -r '.[0].name' | awk -F'-' '{print $4;}')
ccloud kafka acl create --allow --service-account "${KSQLDB_SERVICE_ACCOUNT_ID}" --operation READ --topic stocktrade
ccloud kafka acl create --allow --service-account "${KSQLDB_SERVICE_ACCOUNT_ID}" --operation READ --topic stock_users
ccloud kafka acl create --allow --service-account "${KSQLDB_SERVICE_ACCOUNT_ID}" --operation WRITE --topic user_trades
ccloud kafka acl create --allow --service-account "${KSQLDB_SERVICE_ACCOUNT_ID}" --operation READ --topic trade-settlements

echo "Now generating JSON properties needed for creating datagen connectors and AWS secrets manager"
echo "For this the script is using custom gradle task 'propsToJson' "
echo "The JSON properties for the datagen connectors are "
echo " src/main/resources/stocktrade-datagen.json "
echo " src/main/resources/user-datagen.json"
echo "The JSON file for AWS securitymanager is aws-cli/aws-ccloud-creds.json"

./gradlew  propsToJson

sleep 1
echo "Now creating the stocktrade datagen connector"
ccloud connector create --config src/main/resources/stocktrade-datagen.json
echo "Now creating the user datagen connector"
ccloud connector create --config src/main/resources/user-datagen.json

echo "Waiting for the stocktrade datagen connector to be up and running will wait up to 600 seconds"
ccloud::wait_for_connector_up  src/main/resources/stocktrade-datagen.json 600

echo "Waiting for the user datagen connector to be up and running will wait up to 600 seconds"
ccloud::wait_for_connector_up  src/main/resources/user-datagen.json 600

./ccloud-ksql-upload-sql.sh src/main/resources/stocktrade-statements.sql

