#! /bin/zsh

. ./configs.sh
# This script will update your AWS secrets containing
# the connection information needed by the Lambda for
# working with CCLoud
# This script depends on a JSON file 'aws-cli/aws-ccloud-creds.json'
# that you create by running ./gradlew propsToJson with your
# CCloud credentials saved to src/main/resources/confluent.properties (GitHub ignores confluent.properties)

# clean out results file from any previous runs
true > aws-results.json

echo "Update the AWS secrets config to hold connection information"
aws secretsmanager update-secret --profile "${PROFILE}" --region "${REGION}" \
    --secret-id "${CREDS_NAME}" \
    --secret-string file://aws-ccloud-creds.json  | tee aws-results.json