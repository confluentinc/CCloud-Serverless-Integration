#!/bin/bash

MISSING_CCLOUD_MESSAGE="confluent is not found. Install Confluent CLI (https://docs.confluent.io/confluent-cli/current/install.html) and try again"
MISSING_GRADLE_MESSAGE="Gradle is not found.  Go to https://gradle.org/install/ for instructions to install and try again"
MISSING_JQ_MESSAGE="jq is not found.  Go to https://stedolan.github.io/jq/download/ to install and try again"
MISSING_AWS_CLI_MESSAGE="AWS CLI not found Go to https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html to install and try again"
MISSING_JAVA_MESSAGE="Java not found Go to https://adoptium.net/ and install Java 11 IMPORTANT this demo won't work if you don't install Java 11"

function validateInstall () {
    if [[ $(type "$1" 2>&1) =~ "not found" ]]; then
        echo "$2"
        exit 1
    fi
}

function compareVersions() {
  echo "$1 $2" | awk '{print ($1 >= $2)}'
}

function validateVersions() {
  BAD_VERSIONS=""

  CONFLUENT_VERSION=$(confluent --version | cut -d v -f 3 )
  GRADLE_VERSION=$(gradle --version | grep Gradle | cut -d ' ' -f 2)
  JQ_VERSION=$(jq --version | cut -d '-' -f 2)
  AWS_VERSION=$( aws --version | cut -d '/' -f 2 | cut -d ' ' -f 1)

  MIN_CONFLUENT=2.10.1
  MIN_GRADLE=7.0
  MIN_JQ=1.6
  MIN_AWS=2.4.0

  if [[ $(compareVersions $CONFLUENT_VERSION $MIN_CONFLUENT) -eq 0 ]]; then
     BAD_VERSIONS="TRUE"
     echo "Confluent min version is ${MIN_CONFLUENT} but version ${CONFLUENT_VERSION} installed currently"
  fi
  
 if [[ $(compareVersions $GRADLE_VERSION $MIN_GRADLE) -eq 0 ]]; then
     BAD_VERSIONS="TRUE"
     echo "Gradle min version is ${MIN_GRADLE} but version ${GRADLE_VERSION} installed currently"
 fi
 
 if [[ $(compareVersions $JQ_VERSION $MIN_JQ) -eq 0 ]]; then
      BAD_VERSIONS="TRUE"
      echo "JQ min version is ${MIN_JQ} but version ${JQ_VERSION} installed currently"
  fi

 if [[ $(compareVersions $AWS_VERSION $MIN_AWS) -eq 0 ]]; then
       BAD_VERSIONS="TRUE"
       echo "AWS CLI min version is ${MIN_AWS} but version ${AWS_VERSION} installed currently"
 fi

  if [[ ! $BAD_VERSIONS == "" ]]; then
      echo "Please update the indicated software to the minimum versions listed in the instructions"
      exit 1
  fi
}


validateInstall confluent "$MISSING_CONFLUENT_MESSAGE"
validateInstall gradle "$MISSING_GRADLE_MESSAGE"
validateInstall jq "$MISSING_JQ_MESSAGE"
validateInstall aws "$MISSING_AWS_CLI_MESSAGE"
validateInstall java "$MISSING_JAVA_MESSAGE"

echo "All required software found, validating versions next"
validateVersions
echo "All versions are good!"

if test ! -f ccloud_library.sh; then
   echo "The ccloud_library script not found.
   Getting it now via wqet command"
   wget -O ccloud_library.sh https://raw.githubusercontent.com/confluentinc/examples/master/utils/ccloud_library.sh
fi

source ./ccloud_library.sh

if [ -z "$CLUSTER_CLOUD" ]; then
   CLUSTER_CLOUD=aws
fi

if [ -z "$CLUSTER_REGION" ]; then
   CLUSTER_REGION=us-west-2
fi

echo "Using Cluster type ${CLUSTER_CLOUD} in region ${CLUSTER_REGION}"
export CLUSTER_CLOUD
export CLUSTER_REGION
export EXAMPLE=ConfluentCloudLambdaIntegration
BUILD_KSQLDB_APP=true
ccloud::create_ccloud_stack $BUILD_KSQLDB_APP
MAX_WAIT=720
echo "Now waiting up to $MAX_WAIT seconds for the ksqlDB cluster to be UP"
ccloud::retry $MAX_WAIT ccloud::validate_ccloud_ksqldb_endpoint_ready "$KSQLDB_ENDPOINT" || exit 1
echo "Successfully created ksqlDB"

echo "Now creating topics"

for topic in stocktrade users user_trades trade-settlements; do
    confluent kafka topic create $topic;
  done

echo "Now generating JSON properties needed for creating datagen connectors and AWS secrets manager"
echo "For this the script is using custom gradle task 'propsToJson' "
echo "The JSON properties for the datagen connectors are "
echo " src/main/resources/stocktrade-datagen.json "
echo " src/main/resources/user-datagen.json"
echo "The JSON file for AWS securitymanager is aws-cli/aws-ccloud-creds.json"

./gradlew  propsToJson

sleep 1
echo "Now creating the stocktrade datagen connector"
confluent connect create --config src/main/resources/stocktrade-datagen.json
echo "Now creating the user datagen connector"
confluent connect create --config src/main/resources/user-datagen.json

echo "Waiting for the stocktrade datagen connector to be up and running will wait up to 600 seconds"
ccloud::wait_for_connector_up  src/main/resources/stocktrade-datagen.json 600

echo "Waiting for the user datagen connector to be up and running will wait up to 600 seconds"
ccloud::wait_for_connector_up  src/main/resources/user-datagen.json 600

./ccloud-ksql-upload-sql.sh src/main/resources/stocktrade-statements.sql

