#! /bin/zsh

. ./configs.sh

# This script will create a Lambda instance with the code from the
# GitHub repository.  It also establishes a CCloud topic as the
# event source for the Lambda.  You really only need to run
# this script once.  If you need to update the Lambda code
# you'll want to run ./gradlew clean build buildZip
# then run the update-lambda-code.sh script 

# clean out results file from any previous runs
true > aws-results.json

echo "Create the lambda"
aws lambda  create-function --profile "${PROFILE}" --region "${REGION}" \
  --function-name "${FUNCTION_NAME}" \
  --memory-size 512 \
  --zip-file fileb://../build/distributions/confluent-lambda-serverless-1.0-SNAPSHOT.zip \
  --handler io.confluent.developer.CCloudRecordHandler::handleRequest \
  --runtime java11  --role arn:aws:iam::343223495109:role/"${ROLE_NAME}" | tee aws-results.json

echo "Adding a CCloud topic as an event source "
aws lambda create-event-source-mapping --profile "${PROFILE}" --region "${REGION}" \
    --topics lambda-test-input \
    --source-access-configuration Type=BASIC_AUTH,URI=arn:aws:secretsmanager:us-west-2:343223495109:secret:"${CREDS_NAME}" \
    --function-name arn:aws:lambda:us-west-2:343223495109:function:"${FUNCTION_NAME}" \
    --self-managed-event-source '{"Endpoints":{"KAFKA_BOOTSTRAP_SERVERS":["'${BOOTSTRAP_SERVERS}'"]}}'  | tee -a aws-results.json


